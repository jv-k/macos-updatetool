#!/bin/zsh

# Applist module
#
# Purpose:
# - Manage the applist.yaml configuration used by macos-updatetool.
# - Provide safe, testable helpers for creating/validating the applist and
#   for adding/removing package entries with backup/restore semantics.
#
# Responsibilities:
# - Create, validate and manage the applist.yaml configuration file.
# - Create timestamped backups prior to any mutation and offer cleanup helpers.
# - Safely add and remove package entries across resource types and subtypes
#   (e.g., brew formulas/casks, npm, mas, pip in future).
# - Generate minimal and default applist templates for first-time setup.
# - Validate YAML syntax and required keys using yamllint and yq (no network ops).
#
# Public functions (used by main script and other modules):
# - init_configuration               : initialise CONFIG_PATHS and defaults
# - create_config_backup(operation)   : create timestamped backup, returns backup path
# - remove_backup(backup_path)        : remove a single backup and possibly its dir
# - cleanup_backups()                 : interactive deletion of all backup files
# - get_applist_key(resource_type)    : map resource/subtype -> yaml key
# - get_applist_packages(key)         : stream non-empty package names from applist
# - manage_applist(action, subtype, packages...) : add/remove packages with validation
# - create_minimal_applist_template() : emits a minimal YAML template to stdout
# - create_default_applist()          : create a default applist file on disk
# - check_applist_file()              : validate presence, YAML linting and required keys
# - get_config_value(key[, default])  : read configured paths
# - handle_package_operation_error(...) : consistent reporting for package failures
#
# Author: John Valai <git@jvk.to>
# License: MIT License

source "${MODULE_DIR}/styles.zsh"
source "${MODULE_DIR}/messages.zsh"

declare -gA CONFIG_PATHS=()

# Creates a timestamped backup of the configuration file before modifications.
# @param {string} operation - The operation being performed (e.g., "add", "install")
# @returns {string} The full path to the created backup file, or empty string if no backup was created
create_config_backup() {
  local operation="${1:-unknown}"
  local timestamp
  local backup_file

  # Only create backup if the config file exists
  if [[ ! -f "${APPLIST}" ]]; then
    return 0
  fi
  
  # Create backup directory if it doesn't exist
  [[ ! -d "${BACKUP_DIR}" ]] && mkdir -p "${BACKUP_DIR}"
  
  # Generate timestamp in format: YYYY-MM-DD_HH-MM-SS
  timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  backup_file="${BACKUP_DIR}/applist_${operation}_${timestamp}.yaml"
  
  # Create the backup
  cp "${APPLIST}" "${backup_file}";
  echo "${backup_file}"
}

# Removes backup file + folder if no changes were actually made.
# @param {string} backup_file - The full path to the backup file to potentially remove
remove_backup() {
  local backup_file="$1"
  if [[ -n "${backup_file}" && -f "${backup_file}" ]]; then
    rm "${backup_file}"
    # Remove backup directory if it's now empty
    [[ -d "${BACKUP_DIR}" ]] && [[ -z "$(ls -A "${BACKUP_DIR}" 2>/dev/null)" ]] && rmdir "${BACKUP_DIR}" 2>/dev/null
  fi
}

# Removes all backup files with user confirmation.
# This is an undocumented cleanup feature.
cleanup_backups() {
  local backup_count
  
  msg_header --upper --underline "\nBackup File Cleanup"
  echo

  # Count backup files
  backup_count=$(find "${BACKUP_DIR}" -name "applist_*.yaml" -type f 2>/dev/null | wc -l | tr -d ' ')
  # Check if backup directory exists
  if [[ ! -d "${BACKUP_DIR}" ||  "${backup_count}" -eq 0 ]]; then
    msg_warning --color "No backups found - nothing to clean up."
    return 0
  fi
  
  msg_info "Found ${backup_count} backup file(s) in:\n${BACKUP_DIR}"
  echo
  
  # List existing backups
  msg_info "Current backups:"
  find "${BACKUP_DIR}" -name "applist_*.yaml" -type f -exec basename {} \; 2>/dev/null | sort | while read -r file; do
    msg_bullet "  ${file}"
  done
  
  echo
  if confirm "Are you sure you want to delete ALL backup files? This cannot be undone."; then
    if rm -f "${BACKUP_DIR}"/applist_*.yaml 2>/dev/null; then
      echo
      msg_success --color "All backup files have been removed."
      
      # Remove backup directory if empty
      if rmdir "${BACKUP_DIR}" 2>/dev/null; then
        echo
        msg_info "Removed empty backup directory."
      fi
    else
      echo
      msg_error --color "Failed to remove some backup files."
      return 1
    fi
  else
    msg_warning --color "Cleanup cancelled - no files were removed."
  fi
}

# Maps resource types to their corresponding applist.yaml keys
# @param {string} resource_type - The resource type (brew subtype or direct resource)
# @returns {string} The corresponding YAML key name
get_applist_key() {
  local resource_type="$1"
  local key=""
  
  # Check if it's a direct match in APPLIST_REQUIRED_KEYS
  if [[ -n "${APPLIST_REQUIRED_KEYS[${resource_type}]:-}" ]]; then
    key="${APPLIST_REQUIRED_KEYS[${resource_type}]}"
  else
    # Handle special brew subtypes
    case "${resource_type}" in
      "formulas") key="${APPLIST_REQUIRED_KEYS[brew_formulas]}" ;;
      "casks") key="${APPLIST_REQUIRED_KEYS[brew_casks]}" ;;
      *) 
        msg_error "Unknown resource type: ${resource_type}"
        return 1
        ;;
    esac
  fi
  
  echo "${key}"
}

# Safely extracts non-empty package names from applist.yaml for a given key
# @param {string} key - The YAML key to extract packages from
# @returns {array} Array of non-empty package names (via stdout)
get_applist_packages() {
  local key="$1"
  
  # Check if the key exists and is an array
  if ! yq -e ".${key}" "${APPLIST}" &> /dev/null; then
    return 0  # Return empty if key doesn't exist
  fi
  
  # Extract packages and filter out empty/null values
  yq -r ".${key}[]?" "${APPLIST}" 2>/dev/null | while IFS= read -r pkg; do
    # Skip empty strings, null values, and whitespace-only entries
    if [[ -n "${pkg}" && "${pkg}" != "null" && "${pkg}" =~ [^[:space:]] ]]; then
      echo "${pkg}"
    fi
  done
}

# Manages the applist.yaml file.
# Acceptable categories are defined in APPLIST_KEYS_ORDER in resources.zsh
# @param {string} action - The action to perform ('add' or 'remove').
# Manages the applist.yaml file with support for multiple packages.
# Valid resource types are dynamically determined from RESOURCE_ORDER and RESOURCE_COMMANDS
# @param {string} action - The action to perform ('add' or 'remove').
# @param {string} subtype - The resource subtype (determined dynamically from available resources).
# @param {array} app_names - Array of application names.
# @returns {number} 0 on success, 1 on error
manage_applist() {
  local action="$1" subtype="$2"
  shift 2
  local -a app_names=("$@")
  
  # Generate valid subtypes dynamically from resources that support add/remove
  local -a valid_subtypes=()
  for resource in "${RESOURCE_ORDER[@]}"; do
    # shellcheck disable=SC2153  # RESOURCE_COMMANDS defined in resources.zsh
    local commands="${RESOURCE_COMMANDS[${resource}]}"
    if [[ "${commands}" == *"add"* && "${commands}" == *"remove"* ]]; then
      if [[ "${resource}" == "brew" ]]; then
        # Brew has special subtypes
        valid_subtypes+=("formulas" "casks")
      elif [[ -n "${APPLIST_REQUIRED_KEYS[${resource}]:-}" ]]; then
        # Only add resource if it has a corresponding applist key
        valid_subtypes+=("${resource}")
      fi
    fi
  done
  
  local key

  # Validate action
  if [[ "${action}" != "add" && "${action}" != "remove" ]]; then
    handle_validation_error "Invalid action '${action}'" "Action must be 'add' or 'remove'" "Use: ${NAME} ${resource_type} ${subtype} [add|remove] <package-names>"
    return 1
  fi

  # Validate subtype
  if [[ ! " ${valid_subtypes[*]} " =~  ${subtype}  ]]; then
    handle_validation_error "Invalid subtype '${subtype}'" "Subtype validation for ${resource_type}" "Valid subtypes are: ${valid_subtypes[*]}"
    return 1
  fi

  # Validate we have package names
  if [[ ${#app_names[@]} -eq 0 ]]; then
    handle_validation_error "No package names provided for '${action}' command" "Package name validation" "Specify at least one package name"
    return 1
  fi

  # Create backup before making any changes and capture the file path
  local backup_file_path
  backup_file_path=$(create_config_backup "${action}")

  # Set the YAML key based on the subtype
  key=$(get_applist_key "${subtype}")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local -a successful_packages=()
  local -a skipped_packages=()
  local -a failed_packages=()

  # Process each package
  for app_name in "${app_names[@]}"; do
    # Existence check - safely handle empty arrays
    local exists=false
    local existing_packages
    existing_packages=$(get_applist_packages "${key}")
    
    if [[ -n "${existing_packages}" ]]; then
      if echo "${existing_packages}" | grep -Fxq "${app_name}"; then
        exists=true
      fi
    fi

    if [[ "${exists}" == true ]]; then
      if [[ "${action}" == "add" ]]; then
        skipped_packages+=("${app_name}")
        continue
      fi
    else
      if [[ "${action}" == "remove" ]]; then
        skipped_packages+=("${app_name}")
        continue
      fi
    fi

    # Perform action with proper quoting
    if [[ "${action}" == "add" ]]; then
      if yq -i '
        .'"${key}"' += ["'"${app_name}"'"] |
        .'"${key}"'[-1] style="single"
      ' "${APPLIST}" 2>/dev/null; then
        successful_packages+=("${app_name}")
      else
        failed_packages+=("${app_name}")
      fi
    else
      if yq -i '
        del(.'"${key}"'[] | select(. == "'"${app_name}"'"))
      ' "${APPLIST}" 2>/dev/null; then
        successful_packages+=("${app_name}")
      else
        failed_packages+=("${app_name}")
      fi
    fi
  done

  # Report results
  
  if [[ ${#successful_packages[@]} -gt 0 ]]; then
    echo
    if [[ ${#successful_packages[@]} -eq 1 ]]; then
      msg_success --color "Successfully ${action}ed '${successful_packages[1]}' to ${subtype}."
    else
      msg_success --color "Successfully ${action}ed ${#successful_packages[@]} packages to ${subtype}:"
      for pkg in "${successful_packages[@]}"; do
        msg_success --color "  ${pkg}"
      done
    fi
  fi

  if [[ ${#skipped_packages[@]} -gt 0 ]]; then
    echo
    if [[ "${action}" == "add" ]]; then
      local verb="already in"
      msg_warning --color "Skipped ${#skipped_packages[@]} package(s) (${verb} ${subtype}):"
    else
      msg_warning --color "Skipped ${#skipped_packages[@]} package(s) (not found in ${subtype}):"
    fi
    for pkg in "${skipped_packages[@]}"; do
      msg_bullet "  ${pkg}"
    done
  fi

  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    handle_package_operation_error "${action}" "${resource_type}" "${failed_packages[@]}"
    return 1
  fi

  # If no successful changes were made, remove the temp backup file
  if [[ ${#successful_packages[@]} -eq 0 ]]; then
    remove_backup "${backup_file_path}"
  fi
  return 0
}

# Generate minimal YAML template with required keys only
# @returns {void} Outputs minimal YAML template to stdout
create_minimal_applist_template() {
  cat << 'EOF'
---
# macOS Application and Package List
# This file defines the apps and packages to be tracked.

EOF

  for key in "${APPLIST_KEYS_ORDER[@]}"; do
    echo "# ${APPLIST_KEY_DESCRIPTIONS[${key}]}"
    echo "${key}:"
  done
}

# Creates a default applist.yaml file with common applications
# @returns {number} 0 on success, 1 on error
create_default_applist() {
  local applist_dir
  applist_dir="$(dirname "${APPLIST}")"

  # Create directory if it doesn't exist
  if [ ! -d "${applist_dir}" ]; then
    if ! mkdir -p "${applist_dir}"; then
      handle_filesystem_error "Failed to create directory: ${applist_dir}" "Directory creation for applist.yaml" "Check directory permissions: $(dirname "${applist_dir}")"
      return 1
    fi
  fi

  # Create default applist.yaml
  if create_minimal_applist_template > "${APPLIST}"; then
    msg_success "  Created default applist.yaml at: ${APPLIST}\n"
    msg_info "  You can now edit this file to customize your application list.\n"
    return 0
  else
    handle_filesystem_error "Failed to create default applist.yaml" "File creation operation" "Check write permissions: ${applist_dir}"
    return 1
  fi
}

# Checks the applist file for existence, YAML validity, and required sections.
# @returns {number} 0 if all checks pass, 1 if any check fails
check_applist_file() {
  # Check for applist file existence
  if [ ! -f "${APPLIST}" ]; then
    handle_config_error "Applist file not found at <${APPLIST}>" "File system check" "Create an applist.yaml file or use --config to specify a different location"
    
    echo
    msg_question --color "Would you like to create a default applist.yaml file? (y/N)"
    read -r response
    case "${response}" in
      [yY][eE][sS]|[yY])
        if create_default_applist; then
          msg_success --color "Default applist.yaml created successfully!"
          echo
        else
          handle_filesystem_error "Failed to create applist file" "File creation operation"
        fi
        ;;
      *)
        msg_info "Skipping applist creation. You can create it manually later.\n"
        handle_config_error "Cannot proceed without applist file" "Required configuration missing"
        ;;
    esac
  fi

  # Validate applist.yaml using yamllint
  local yamllint_output
  yamllint_output=$(yamllint "${APPLIST}" 2>&1)
  local yamllint_exit_code=$?
  
  if [[ ${yamllint_exit_code} -ne 0 ]]; then
    handle_validation_error "YAML Validation Error in: ${APPLIST}" "${yamllint_output}" "Check YAML syntax and formatting"
  fi

  # 3. Check if yq can parse the applist file and if required keys exist  
  local -a required_keys=("${APPLIST_KEYS_ORDER[@]}")
  local -a missing_keys
  for key in "${required_keys[@]}"; do
    # Check if the key exists (allow empty arrays)
    if ! yq -e "has(\"${key}\")" "${APPLIST}" &> /dev/null; then
      missing_keys+=("${key}")
    fi
  done

  if [[ ${#missing_keys[@]} -gt 0 ]]; then
    msg_error "Config Error: The following keys are missing from the applist file:" >&2
    for key in "${missing_keys[@]}"; do
      msg_bullet "  ${key}" >&2
    done
    exit 1
  fi
  msg_success "Loaded config: $(style_wrap DIM "<${APPLIST}>")"
}

# Initialize configuration paths
# Sets default values for configuration paths
init_configuration() {
  local module_dir="${0:A:h}/.."

  CONFIG_PATHS[module_dir]="${module_dir}"
  CONFIG_PATHS[applist]="${MACOS_UPDATETOOL_CONFIG:-${HOME}/.config/macos-updatetool/applist.yaml}"
  CONFIG_PATHS[backup_dir]="$(dirname "${CONFIG_PATHS[applist]}")/backups"

  # Ensure backup directory exists
  if [[ ! -d "${CONFIG_PATHS[backup_dir]}" ]]; then
    mkdir -p "${CONFIG_PATHS[backup_dir]}" 2>/dev/null || true
  fi
}

# Get configuration value with fallback support
get_config_value() {
  local key="$1"
  local default_value="${2:-}"

  case "${key}" in
    applist_path)
      echo "${CONFIG_PATHS[applist]}"
      ;;
    backup_dir)
      echo "${CONFIG_PATHS[backup_dir]}"
      ;;
    module_dir)
      echo "${CONFIG_PATHS[module_dir]}"
      ;;
    *)
      if [[ -n "${default_value}" ]]; then
        echo "${default_value}"
      else
        handle_config_error "Unknown configuration key: ${key}" "Configuration retrieval"
        return 1
      fi
      ;;
  esac
}

# Package operation error handler with consistent reporting
handle_package_operation_error() {
  local operation="$1"
  local resource="$2"
  local -a failed_packages=("${@:3}")

  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    handle_error "command" "recoverable" "Failed to ${operation} ${#failed_packages[@]} ${resource} package(s)" "Package operation failure"

    for pkg in "${failed_packages[@]}"; do
      msg_error "  ${pkg}" >&2
    done

    # Provide resource-specific suggestions
    case "${resource}" in
      brew)
        provide_guidance "Brew operation failed" "Try running 'brew doctor' to diagnose issues" "brew doctor"
        ;;
      npm)
        provide_guidance "NPM operation failed" "Try running 'npm doctor' to diagnose issues" "npm doctor"
        ;;
      mas)
        provide_guidance "App Store operation failed" "Check if you're signed in to the App Store" "mas account"
        ;;
      *)
        ;;
    esac

    return 1
  fi
  return 0
}

# Shows configuration file location and status
show_config() {
  echo
  msg_header h2 --upper "Configuration"
  echo
  msg_info --color "Configuration file location:"
  echo "  $(style_wrap BOLD "${APPLIST}")"
  echo
  
  if [[ -f "${APPLIST}" ]]; then
    msg_success --color "Configuration file exists"
    echo
    
    # Validate YAML only
    if command -v yamllint >/dev/null 2>&1; then
      if yamllint "${APPLIST}" &> /dev/null; then
        msg_success --color "Configuration file is valid YAML"
      else
        msg_error --color "Configuration file contains invalid YAML"
        echo
        msg_info "Run $(style_wrap CYAN "yamllint \"${APPLIST}\"") for details"
      fi
    else
      msg_warning --color "yamllint not found - cannot validate YAML syntax"
      echo
      msg_info "Install with: $(style_wrap CYAN "brew install yamllint")"
    fi
  else
    msg_warning --color "Configuration file does not exist"
    echo
    msg_info "You can create it by running any install command, or manually create:"
    echo "  $(style_wrap DIM "mkdir -p $(dirname "${APPLIST}")")"
    echo "  $(style_wrap DIM "touch \"${APPLIST}\"")"
  fi
}
