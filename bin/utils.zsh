#!/bin/zsh

# Utils module
#
# Purpose:
# - Provide core utility functions and infrastructure for the macOS update tool.
# - Handle interactive processes (spinners, confirmation prompts, authentication).
# - Manage package information retrieval and version handling.
# - Offer comprehensive validation and error handling with contextual messaging.
#
# Responsibilities:
# - Execute background commands with visual feedback via animated spinners.
# - Handle sudo authentication caching and privilege escalation safely.
# - Provide user confirmation prompts with customizable defaults.
# - Extract and format package metadata from configuration files (package.json).
# - Validate resource types, commands, and argument combinations with helpful error messages.
# - Implement standardized error handling patterns with consistent formatting and recovery guidance.
# - Check system dependencies and provide clear installation guidance for missing tools.
# - Support text alignment calculations for consistent terminal output formatting.
#
# Public functions (used by main script and other modules):
# - show_spinner(message, command, [timeout])    : run background commands with animated feedback
# - ensure_sudo()                                : cache sudo credentials with user prompting
# - confirm(question, [default])                 : interactive yes/no confirmation prompts
# - show_version()                               : display version information with branding
# - get_package_info(field, [fallback])          : extract metadata from package.json
# - validate_resource_type(resource)             : check if resource type is supported
# - validate_command(command)                    : check if command is supported
# - validate_resource_command(resource, command) : check resource-command compatibility
# - validate_required_argument(context, value, type) : ensure required arguments are provided
# - validate_or_error(type, value, message, context) : validate with contextual error messaging
# - handle_error/warning/guidance(type, message, context) : standardized messaging patterns
# - check_dependencies()                         : verify all required tools are installed
# - get_max_width(text_array)                    : calculate alignment width for formatted output
#
# Flag support:
# - show_spinner supports --show-output (display command output) and --sudo (require privileges)
# - Error handlers support different severity levels and recovery suggestions
# - Validation functions provide contextual help and suggest corrections
#
# Notes:
# - All functions integrate with the messaging system for consistent output formatting.
# - Error handlers follow semantic patterns (config, validation, dependency, filesystem, command).
# - Spinner timeouts default to 1 hour but can be disabled or customized per operation.
# - Authentication state is cached to minimize sudo prompts during batch operations.
#
# Author: John Valai <git@jvk.to>
# License: MIT License

# shellcheck disable=SC2153

source "${MODULE_DIR}/styles.zsh"

# Shows a spinner while running a background command, capturing its output.
# Provides visual feedback for potentially long-running operations with timeout support.
# Optionally enforces sudo authentication and displays command output on completion.
# Integrates with the messaging system for consistent success/error reporting.
# Flags: --show-output (display command stdout after completion), --sudo (require privilege escalation)
# @param {string} message - Descriptive text to display alongside the spinner animation.
# @param {string} command - Shell command to execute in the background.
# @param {string} [timeout] - Timeout in seconds (defaults to 3600, use 0 to disable).
# @returns {number} Exit code of the background command (0 for success, non-zero for failure).
show_spinner() {
  local message=""
  local command=""
  local timeout=""
  local show_output="false"
  local use_sudo="false"
  local default_timeout="3600"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
  case "$1" in
    --show-output)
    show_output="true"
    shift
    ;;
    --sudo)
    use_sudo="true"
    shift
    ;;
    *)
    if [[ -z "${message}" ]]; then
      message="$1"
    elif [[ -z "${command}" ]]; then
      command="$1"
    elif [[ -z "${timeout}" ]]; then
      timeout="$1"
    fi
    shift
    ;;
  esac
  done

  # Set timeout: use default if not specified, disable if set to 0
  if [[ -z "${timeout}" ]]; then
  timeout="${default_timeout}"
  fi

  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local temp_file
  local temp_err
  local pid

  temp_file=$(mktemp)
  temp_err=$(mktemp)

  # Handle indentation using the new helper function
  local clean_message="" indent_prefix=""
  eval "$(parse_message_indent "${message}")"

  # Calculate output indentation (2 more spaces than spinner indent)
  local output_indent=""
  if [[ -n "${indent_prefix}" ]]; then
  output_indent="${indent_prefix}  "
  fi

  # Handle sudo authentication if requested
  if [[ "${use_sudo}" == "true" ]]; then
  if ! ensure_sudo; then
    rm -f "${temp_file}" "${temp_err}"
    return 1
  fi
  fi

  # Start command in background
  eval "${command}" > "${temp_file}" 2> "${temp_err}" &
  pid=$!

  # Show spinner while command runs
  local i=0
  while kill -0 "${pid}" 2>/dev/null; do
  local spinner_char=${spinner_chars:$((i % ${#spinner_chars})):1}
  printf "\r%s %s..." "${indent_prefix}$(style_wrap CYAN "${spinner_char}")" "${clean_message}"
  sleep 0.1
  ((i++))

  # Check for timeout (skip if timeout is 0)
  if [[ "${timeout}" != "0" ]] && [[ $((i / 10)) -gt ${timeout} ]]; then
    kill "${pid}" 2>/dev/null
    printf "\r%s %s (timed out)\n" "$(style_wrap RED "${SYMBOL[DANGER]}")" "${clean_message}"
    rm -f "${temp_file}" "${temp_err}"
    return 1
  fi
  done

  # Wait for command to finish and get exit code
  wait "${pid}"
  local exit_code=$?

  # Clear spinner line and show result
  printf "\r"
  if [[ ${exit_code} -eq 0 ]]; then
  msg_success "${indent_prefix}${clean_message}   "
  # Show output only if requested and there is output
  if [[ "${show_output}" == "true" ]]; then
    if [[ -n "${output_indent}" ]] && [[ -s "${temp_file}" ]]; then
    sed "s/^/${output_indent}/" "${temp_file}"
    elif [[ -s "${temp_file}" ]]; then
    cat "${temp_file}"
    fi
  fi
  else
  msg_error "${indent_prefix}${clean_message} failed."
  # Always show error output (but limit to first line)
  if [[ -n "${output_indent}" ]] && [[ -s "${temp_err}" ]]; then
    if [[ "${show_output}" == "true" ]]; then
    echo -e "${STYLE[YELLOW]}$(sed "s/^/${output_indent}/" "${temp_err}")${STYLE[RESET]}"
    else
    echo -e "${STYLE[LIGHT_RED]}$(sed "s/^/${output_indent}/" "${temp_err}" | head -n 1)${STYLE[RESET]}"
    fi
  elif [[ -s "${temp_err}" ]]; then
    if [[ "${show_output}" == "true" ]]; then
    echo -e "${STYLE[YELLOW]}$(cat "${temp_err}")${STYLE[RESET]}"
    else
    echo -e "${STYLE[LIGHT_RED]}$(cat "${temp_err}" | head -n 1)${STYLE[RESET]}"
    fi
  fi
  fi

  rm -f "${temp_file}" "${temp_err}"
  return "${exit_code}"
}

# Ensures sudo credentials are cached for subsequent privileged commands.
# Checks for existing valid sudo access before prompting to minimize user interruptions.
# Prompts user with clear messaging if authentication is required and reports success/failure.
# Integrates with messaging system for consistent authentication status reporting.
# @returns {number} 0 if sudo access is available or successfully obtained, 1 if authentication fails.
ensure_sudo() {
  # Check if we already have sudo access
  if sudo -n true 2>/dev/null; then
  # We already have valid sudo access, no need to prompt
  return 0
  fi

  # Need to authenticate
  msg_info "Administrator privileges required for upcoming operations..."
  if sudo -v; then
  msg_success "Authentication successful"
  return 0
  else
  msg_error "Authentication failed or cancelled"
  return 1
  fi
}

# Prompts the user for interactive yes/no confirmation with customizable defaults.
# Supports case-insensitive responses (y/yes/n/no) and handles empty input gracefully.
# Displays the question with clear default indication and repeats until valid input is received.
# Used for bulk operations, destructive actions, and user preference confirmation.
# @param {string} question - The confirmation question to display to the user.
# @param {string} [default_choice=N] - Default response if user presses Enter ("Y" or "N").
# @returns {number} 0 if user confirms (yes), 1 if user declines (no).
confirm() {
  local question="$1"
  local default_choice="${2:-N}"
  local prompt_suffix

  [[ "${default_choice}" =~ ^[Yy]$ ]] && prompt_suffix="[Y/n]" || prompt_suffix="[y/N]"

  msg_question "${question} ${prompt_suffix}"
  read -r response

  [[ -z "${response}" ]] && response="${default_choice}"
  [[ "${response}" =~ ^[Yy]$ ]] && return 0 || return 1
}

# Displays version information with styled branding and tool metadata.
# Shows ASCII logo, version number, description, and author information.
# Integrates with get_package_info to dynamically retrieve current version data.
# Used for --version/-v flags and help system version references.
# @returns {void} Outputs formatted version information to stdout.
show_version() {
  # Get information from package.json
  local description name version website author
  website=$(get_package_info "homepage" "https://github.com/jv-k/macos-updatetool")
  version=$(get_package_info "version" "development")
  author=$(get_package_info "author" "John Valai")
  echo -e "$(style_wrap DIM "Version: $(style_wrap RESET BOLD "${version}")")"
  # echo -e "$(style_wrap DIM "Author: $(style_wrap RESET BOLD "${author}")")"
  echo -e "$(style_wrap DIM "Homepage: $(style_wrap RESET BOLD "${website}")")"
}

# Retrieves package metadata from package.json configuration file.
# Safely extracts JSON fields using jq with error handling for missing files or fields.
# Supports fallback values to ensure graceful degradation when metadata is unavailable.
# Used for version display, tool naming, and configuration-driven feature detection.
# @param {string} field - The JSON field path to extract (e.g., 'version', 'name', 'description').
# @param {string} [fallback] - Optional fallback value returned if field extraction fails.
# @returns {string} The extracted field value, fallback value, or empty string if unavailable.
get_package_info() {
  local field="$1"
  local fallback="${2:-}"
  local result

  if result=$(jq -r ".${field}" < "${MODULE_DIR}/../package.json" 2>/dev/null) && [[ "${result}" != "null" && -n "${result}" ]]; then
  # Special handling for author field to clean up email
  if [[ "${field}" == "author" ]]; then
    echo "${result}" | sed 's/<.*>//' | sed 's/[[:space:]]*$//'
  else
    echo "${result}"
  fi
  else
  echo "${fallback}"
  fi
}

# Validates if a resource type is recognized and supported by the tool.
# Checks resource name against RESOURCE_ORDER configuration array.
# Used during argument parsing to provide early validation and helpful error messages.
# @param {string} resource - Resource type name to validate (e.g., 'brew', 'npm', 'appstore').
# @returns {number} 0 if resource type is supported, 1 if unsupported.
validate_resource_type() {
  local resource="$1"

  for valid_resource in "${RESOURCE_ORDER[@]}"; do
    if [[ "${resource}" == "${valid_resource}" ]]; then
      return 0
    fi
  done
  return 1
}

# Validates if a command is recognized and supported by the tool.
# Checks command name against COMMAND_ORDER configuration array.
# Used during argument parsing to provide early validation before resource-specific checks.
# @param {string} command - Command name to validate (e.g., 'list', 'install', 'update').
# @returns {number} 0 if command is supported, 1 if unsupported.
validate_command() {
  local command="$1"

  for valid_command in "${COMMAND_ORDER[@]}"; do
    if [[ "${command}" == "${valid_command}" ]]; then
      return 0
    fi
  done
  return 1
}

# Validates compatibility between a resource type and command combination.
# Checks if the specified command is available for the given resource type.
# Provides context-aware validation beyond individual resource and command checks.
# @param {string} resource - Resource type to check (e.g., 'brew', 'npm', 'system').
# @param {string} command - Command to validate against the resource (e.g., 'add', 'remove').
# @returns {number} 0 if combination is valid, 1 if incompatible.
validate_resource_command() {
  local resource="$1"
  local command="$2"

  # shellcheck disable=SC2153
  local resource_commands="${RESOURCE_COMMANDS[${resource}]}"
  [[ "${resource_commands}" == *"${command}"* ]]
}

# Returns array of resource types that support a specific command.
# Filters RESOURCE_COMMANDS configuration to find compatible resources for a given command.
# Used for generating help text and providing suggestions when command-resource mismatches occur.
# @param {string} command - Command to find supporting resources for.
# @returns {array} Array of resource type names that support the command (via stdout).
get_supporting_resources() {
  local command="$1"
  local -a supporting_resources=()

  for resource in "${RESOURCE_ORDER[@]}"; do
    if validate_resource_command "${resource}" "${command}"; then
      supporting_resources+=("${resource}")
    fi
  done

  echo "${supporting_resources[@]}"
}

# Validates presence of required arguments with contextual help integration.
# Provides immediate feedback when mandatory arguments are missing from user input.
# Integrates with help system to show relevant usage patterns and examples.
# @param {string} arg_name - Validation context identifier (e.g., 'resource_type', 'command').
# @param {string} arg_value - Argument value to check for presence and validity.
# @param {string} help_context - Argument type for contextual error messaging.
# @param {...string} help_args - Additional context arguments passed to help system.
# @returns {number} 0 if validation passes, exits with error message if validation fails.
validate_required_argument() {
  local arg_name="$1"
  local arg_value="$2"
  local help_context="$3"
  shift 3
  local help_args=("$@")

  if [[ -z "${arg_value}" ]]; then
    show_contextual_help "${help_context}" "${help_args[@]}"
    exit 0
  fi
}

# Validates argument values with standardized error reporting and contextual help.
# Combines validation logic with consistent error formatting and help system integration.
# Provides specific error messages and suggests valid alternatives when validation fails.
# @param {string} validation_type - Type of validation to perform ('resource', 'command', etc.).
# @param {string} value - Value to validate against the specified type.
# @param {string} error_message - Custom error message to display on validation failure.
# @param {string} help_context - Context identifier for showing relevant help sections.
# @param {...string} help_args - Additional context arguments passed to help system.
# @returns {number} 0 if validation passes, exits with error message if validation fails.
validate_or_error() {
  local validation_type="$1"
  local value="$2"
  local error_message="$3"
  local help_context="$4"
  shift 4
  local help_args=("$@")

  case "${validation_type}" in
    resource)
      if ! validate_resource_type "${value}"; then
        echo
        msg_error --color "${error_message}"
        show_contextual_help "${help_context}" "${help_args[@]}"
        exit 1
      fi
      ;;
    command)
      if ! validate_command "${value}"; then
        echo
        msg_error --color "${error_message}"
        show_contextual_help "${help_context}" "${help_args[@]}"
        exit 1
      fi
      ;;
    resource_command)
      local resource="${help_args[0]}"  # Resource is first help arg
      if ! validate_resource_command "${resource}" "${value}"; then
        local supporting_resources
        supporting_resources=("${(f)"$(get_supporting_resources "${value}")"}")
        echo
        msg_warning --color "The <${value}> command is only available for: $(style_wrap CYAN "${supporting_resources[*]// /, }")"
        show_contextual_help "${help_context}" "${help_args[@]}"
        exit 1
      fi
      ;;
    *)
      ;;
  esac
}

# Validates that package names are provided for commands that require them.
# Ensures add/remove operations have target package names specified by the user.
# Provides clear error messaging when package arguments are missing.
# @param {string} resource - Resource type that requires package names.
# @param {string} command - Command that requires package name validation.
# @param {...string} pkg_names - Array of package names to validate for presence.
# @returns {number} 0 if package names are provided, exits with error if missing.
validate_package_names_required() {
  local resource="$1"
  local command="$2"
  local -a pkg_names=("${@:3}")

  if [[ ${#pkg_names[@]} -eq 0 ]]; then
    show_contextual_help "package_names" "${resource}" "${command}"
    exit 0
  fi
}

# Standard error types with consistent formatting and behavior
declare -gA ERROR_TYPES=(
  [config]="Config Error"
  [validation]="Validation Error"
  [dependency]="Dependency Error"
  [filesystem]="File System Error"
  [network]="Network Error"
  [command]="Command Error"
  [user_input]="Input Error"
  [system]="System Error"
)

declare -gA ERROR_ACTIONS=(
  [fatal]="exit"
  [recoverable]="return"
  [warning]="continue"
)

# Standardized error handler with consistent formatting and contextual messaging.
# Provides semantic error categorization, recovery suggestions, and appropriate exit strategies.
# Integrates with messaging system for consistent error presentation across all modules.
# @param {string} error_type - Error category from ERROR_TYPES array (config, validation, dependency, etc.).
# @param {string} action - Recovery action ('fatal' exits, 'recoverable' returns, 'warning' continues).
# @param {string} message - Primary error message to display to the user.
# @param {string} [context] - Optional contextual information about where/when the error occurred.
# @param {number} [exit_code=1] - Exit code to use for fatal errors.
# @param {string} [suggestion] - Optional recovery suggestion or next steps for the user.
# @returns {number} Exits with specified code for fatal errors, returns exit_code otherwise.
handle_error() {
  local error_type="$1"
  local action="$2"
  local message="$3"
  local context="${4:-}"
  local exit_code="${5:-1}"
  local suggestion="${6:-}"

  # Format error message consistently
  local prefix="${ERROR_TYPES[${error_type}]:-Error}"

  echo >&2
  msg_error --color "${prefix}: ${message}" >&2

  # Add context if provided
  if [[ -n "${context}" ]]; then
    echo "Context: ${context}" >&2
  fi

  # Add suggestion if provided
  if [[ -n "${suggestion}" ]]; then
    echo >&2
    msg_info --color "Suggestion: ${suggestion}" >&2
  fi

  # Take action based on error severity
  case "${action}" in
    fatal)
      exit "${exit_code}"
      ;;
    recoverable)
      return "${exit_code}"
      ;;
    warning)
      # Just display warning, continue execution
      return 0
      ;;
    *)
      ;;
  esac
}

# Specialized error handlers for common error scenarios with predefined behavior patterns.

# Configuration-related error handler for issues with config files, paths, or settings.
# Treats configuration errors as fatal since the tool cannot operate without proper config.
# @param {string} message - Error message describing the configuration issue.
# @param {string} [context] - Optional context about which config caused the error.
# @param {string} [suggestion] - Optional suggestion for fixing the configuration.
# @returns {void} Exits with code 1 (fatal configuration errors cannot be recovered).
handle_config_error() {
  local message="$1"
  local context="${2:-}"
  local suggestion="${3:-}"
  handle_error "config" "fatal" "${message}" "${context}" 1 "${suggestion}"
}

# Validation error handler for user input or argument validation failures.
# Treats validation errors as fatal with immediate termination and help suggestions.
# @param {string} message - Error message describing what validation failed.
# @param {string} [context] - Optional context about which input failed validation.
# @param {string} [suggestion] - Optional suggestion for providing correct input.
# @returns {void} Exits with code 1 (validation errors require user correction).
handle_validation_error() {
  local message="$1"
  local context="${2:-}"
  local suggestion="${3:-}"
  handle_error "validation" "fatal" "${message}" "${context}" 1 "${suggestion}"
}

# Dependency error handler for missing or incompatible system dependencies.
# Treats dependency errors as recoverable to allow graceful degradation when possible.
# @param {string} message - Error message describing the missing or problematic dependency.
# @param {string} [context] - Optional context about what operation requires the dependency.
# @param {string} [suggestion] - Optional suggestion for installing or fixing the dependency.
# @returns {number} Returns 1 to allow caller to handle graceful degradation.
handle_dependency_error() {
  local message="$1"
  local context="${2:-}"
  local suggestion="${3:-}"
  handle_error "dependency" "recoverable" "${message}" "${context}" 1 "${suggestion}"
}

# Filesystem error handler for file I/O, permission, and storage-related issues.
# Treats filesystem errors as fatal since they usually indicate system-level problems.
# @param {string} message - Error message describing the filesystem issue.
# @param {string} [context] - Optional context about which file/directory caused the error.
# @param {string} [suggestion] - Optional suggestion for resolving filesystem issues.
# @returns {void} Exits with code 1 (filesystem errors typically require manual intervention).
handle_filesystem_error() {
  local message="$1"
  local context="${2:-}"
  local suggestion="${3:-}"
  handle_error "filesystem" "fatal" "${message}" "${context}" 1 "${suggestion}"
}

# Command execution error handler for issues with external commands or processes.
# Treats command errors as recoverable to allow alternative approaches or graceful degradation.
# @param {string} message - Error message describing the command execution failure.
# @param {string} [context] - Optional context about which command failed and why.
# @param {string} [suggestion] - Optional suggestion for alternative approaches or fixes.
# @returns {number} Returns 1 to allow caller to implement fallback strategies.
handle_command_error() {
  local message="$1"
  local context="${2:-}"
  local suggestion="${3:-}"
  handle_error "command" "recoverable" "${message}" "${context}" 1 "${suggestion}"
}

# Standard warning handler for non-fatal issues that deserve user attention.
# Displays warnings with optional recovery tips but allows execution to continue.
# Used for deprecated features, sub-optimal configurations, or minor inconsistencies.
# @param {string} category - Warning category for grouping related warnings.
# @param {string} message - Warning message describing the issue.
# @param {string} [suggestion] - Optional tip for resolving or avoiding the warning.
# @returns {number} Always returns 0 to allow continued execution.
handle_warning() {
  local category="$1"
  local message="$2"
  local suggestion="${3:-}"

  msg_warning --color "${message}"

  if [[ -n "${suggestion}" ]]; then
    msg_info "Tip: ${suggestion}"
  fi
}

# Standard informational guidance handler for user education and assistance.
# Provides helpful information, tips, and guidance for common user scenarios.
# Used to proactively educate users about tool features, best practices, and shortcuts.
# @param {string} situation - Situation identifier for contextual guidance selection.
# @param {string} [guidance_message] - Optional custom guidance message.
# @returns {number} Always returns 0 since guidance is purely informational.
provide_guidance() {
  local situation="$1"
  local guidance="$2"
  local example="${3:-}"

  echo
  msg_info --color "${guidance}"

  if [[ -n "${example}" ]]; then
    msg_info "Example: ${example}"
  fi
}

# Calculates the maximum display width of text items for consistent alignment.
# Processes arrays of text strings to determine the longest item for formatting purposes.
# Used to create aligned columns in help text, package lists, and tabular output.
# Handles ANSI escape sequences by measuring visible character count only.
# @param {...string} items - Array of text strings to measure.
# @returns {number} Maximum visible character width among all provided items (via stdout).
get_max_width() {
  local -a items=("$@")
  local max_width=0

  for item in "${items[@]}"; do
    if (( ${#item} > max_width )); then
      max_width=${#item}
    fi
  done

  echo $((max_width + 4))  # Add padding
}

# Comprehensive dependency checker for all external tools and environments required by the tool.
# Validates availability of package managers, CLI tools, and runtime environments.
# Provides clear error messages and installation guidance for any missing dependencies.
# Integrates with error handling system to give users actionable next steps.
# @returns {number} 0 if all dependencies are available, 1 if any are missing.
check_dependencies() {
  # Check for Zsh environment
  if [ -z "${ZSH_VERSION}" ]; then
    msg_error "Error: This script is designed to be run with Zsh.\n" >&2
    return 1
  fi
  # Check required CLI tools
  local -a missing_deps
  local -a dependencies=("brew" "mas" "npm" "pip3" "xcode-select" "yq")

  # Check Oh My Zsh installation
  if [[ ! -d "${HOME}/.oh-my-zsh" ]] && [[ ! -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    missing_deps+=("omz (Oh My Zsh)")
  fi
  
  # Check Zinit installation
  if [[ ! -d "${HOME}/.local/share/zinit" ]] && [[ ! -d "${HOME}/.zinit" ]] && [[ ! -f "${HOME}/.local/share/zinit/zinit.zsh" ]]; then
    missing_deps+=("zinit")
  fi

  for dep in "${dependencies[@]}"; do
    if ! command -v "${dep}" &> /dev/null; then
      missing_deps+=("${dep}")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    msg_error --color "Missing required command-line tools. Please install the following:" >&2
    for dep in "${missing_deps[@]}"; do
      msg_bullet "  ${STYLE[RED]}${dep}" >&2
    done
    echo
    return 1
  fi

  # msg_success "Dependencies check OK."
}
