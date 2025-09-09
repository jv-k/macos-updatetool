#!/bin/zsh

# Helpsystem module
#
# Provides a dynamic, context-aware help system for the macOS update tool.
# Responsibilities:
# - Build and render usage text, examples and options based on the runtime
#   resource and command configuration (RESOURCE_ORDER, RESOURCE_COMMANDS, etc.).
# - Detect resource capabilities (subtypes, package management, outdated support)
#   and adapt help output accordingly.
# - Render aligned, styled sections: resource types, commands, sub-commands,
#   package requirements and examples.
# - Offer contextual helpers for incomplete or invalid user input (resource,
#   command, package names, sub-commands).
#
# Public functions (used by main script and other modules):
# - show_help                : Render full help screen.
# - show_contextual_help     : Render help for a specific context (resource, command, package_names, sub_command).
# - show_resource_types_section, show_commands_section,
#   show_sub_commands_section : Helpers to render individual sections.
# - get_resource_capabilities, get_resource_subtypes, get_all_sub_commands: Helpers used to generate dynamic help.
##
# Author: John Valai <git@jvk.to>
# License: MIT License

source "${MODULE_DIR}/styles.zsh"
source "${MODULE_DIR}/utils.zsh"

# Generic help section renderer
render_help_section() {
  local section_type="$1"
  local context="$2"
  shift 2
  local -a args=("$@")

  case "${section_type}" in
    resource_types)
      render_resource_types_help "${context}"
      ;;
    commands)
      render_commands_help "${context}" "${args[@]}"
      ;;
    sub_commands)
      render_sub_commands_help "${context}" "${args[@]}"
      ;;
    package_requirements)
      render_package_requirements_help "${context}"
      ;;
    *)
      ;;
  esac
}

# Get resource capabilities dynamically
# @param {string} resource - Resource name
# @returns {array} List of capabilities
get_resource_capabilities() {
  local resource="$1"
  local capabilities=()
  
  # Check if resource supports subtypes (like brew -> formulas/casks)
  if [[ -n "${APPLIST_REQUIRED_KEYS[${resource}_formulas]:-}" && -n "${APPLIST_REQUIRED_KEYS[${resource}_casks]:-}" ]]; then
    capabilities+=("has_subtypes")
  fi
  
  # Check if resource supports outdated sub-command
  local sub_commands="${RESOURCE_SUB_COMMANDS[${resource}]:-}"
  if [[ "${sub_commands}" == *"outdated"* ]]; then
    capabilities+=("supports_outdated")
  fi
  
  # Check if resource supports package management
  local commands="${RESOURCE_COMMANDS[${resource}]:-}"
  if [[ "${commands}" == *"add"* && "${commands}" == *"remove"* ]]; then
    capabilities+=("supports_packages")
  fi
  
  echo "${capabilities[@]}"
}

# Get resource subtypes dynamically
# @param {string} resource - Resource name
# @returns {array} List of subtypes
get_resource_subtypes() {
  local resource="$1"
  local -a subtypes=()
  
  # Look for resource-specific keys in APPLIST_REQUIRED_KEYS
  for key in "${!APPLIST_REQUIRED_KEYS[@]}"; do
    if [[ "${key}" == "${resource}_"* ]]; then
      local subtype="${key#${resource}_}"
      subtypes+=("${subtype}")
    fi
  done
  
  echo "${subtypes[@]}"
}

# Build dynamic sub-command list from all resources
# @returns {array} Unique list of sub-commands
get_all_sub_commands() {
  local -a sub_cmd_keys=()
  for resource in "${RESOURCE_ORDER[@]}"; do
    local sub_commands="${RESOURCE_SUB_COMMANDS[${resource}]:-}"
    if [[ -n "${sub_commands}" ]]; then
      local -a resource_subcmds=("${(@s: :)sub_commands}")
      for subcmd in "${resource_subcmds[@]}"; do
        [[ ! " ${sub_cmd_keys[*]} " =~ " ${subcmd} " ]] && sub_cmd_keys+=("${subcmd}")
      done
    fi
  done
  echo "${sub_cmd_keys[@]}"
}

# Show usage dynamically based on resource capabilities
# @param {string} resource_type - Resource type
show_usage_for_resource() {
  local resource_type="$1"
  local capabilities=($(get_resource_capabilities "${resource_type}"))
  
  if [[ " ${capabilities[*]} " =~ " has_subtypes " ]]; then
    # Dynamically build subtype list
    local -a subtypes=($(get_resource_subtypes "${resource_type}"))
    echo -e "  $(style_wrap BOLD "${NAME} ${resource_type} [${subtypes[*]// /|}] <command> [sub-command] [pkg-name...]")\n"
    
    msg_header h3 --upper "Available subtypes for $(style_wrap CYAN BOLD "${resource_type}")"
    for subtype in "${subtypes[@]}"; do
      local description="${APPLIST_KEY_DESCRIPTIONS[${resource_type}_${subtype}]:-"${subtype} packages"}"
      echo "  $(style_wrap CYAN "${subtype}")    ${description}"
    done
    echo "  $(style_wrap DIM "none")         Process all subtypes"
  elif [[ " ${capabilities[*]} " =~ " supports_packages " ]]; then
    echo -e "  $(style_wrap BOLD "${NAME} ${resource_type} <command> [outdated] [pkg-name...]")\n"
  else
    echo -e  "  $(style_wrap BOLD "${NAME} ${resource_type} <command>")\n"
  fi
}

# Show resource-specific notes dynamically
# @param {string} resource_type - Resource type  
show_resource_notes() {
  local resource_type="$1"
  local capabilities=($(get_resource_capabilities "${resource_type}"))
  
  if [[ ! " ${capabilities[*]} " =~ " supports_outdated " ]]; then
    echo
    msg_info --italic "Note: $(style_wrap CYAN "outdated") sub-command is not available for ${resource_type}"
  elif [[ "${resource_type}" == "all" ]]; then
    echo  
    msg_info --italic "Note: Bulk operations require confirmation"
  fi
}

# Show usage for package names dynamically
# @param {string} resource_type - Resource type
# @param {string} command - Command
show_package_usage() {
  local resource_type="$1"
  local command="$2"
  local capabilities=($(get_resource_capabilities "${resource_type}"))
  
  msg_header h3 --upper "Usage"
  if [[ " ${capabilities[*]} " =~ " has_subtypes " ]]; then
    local -a subtypes=($(get_resource_subtypes "${resource_type}"))
    echo -e "  $(style_wrap BOLD "${NAME} ${resource_type} [${subtypes[*]// /|}] ${command} [pkg-name...]")\n"
  else
    echo -e "  $(style_wrap BOLD "${NAME} ${resource_type} ${command} [pkg-name...]")\n"
  fi
}

# Show available sub-commands dynamically
# @param {string} resource_type - Resource type
# @param {string} command - Command
show_available_subcommands() {
  local resource_type="$1"
  local command="$2"
  local capabilities=($(get_resource_capabilities "${resource_type}"))
  
  if [[ ! " ${capabilities[*]} " =~ " supports_outdated " ]]; then
    echo
    msg_warning --color "The $(style_wrap BOLD "outdated") sub-command is not available for $(style_wrap CYAN "${resource_type}")."
    local available_commands="${RESOURCE_COMMANDS[${resource_type}]}"
    msg_info "Available commands for ${resource_type}: ${available_commands// /, }"
  else
    # Show available sub-commands dynamically
    local sub_commands="${RESOURCE_SUB_COMMANDS[${resource_type}]}"
    if [[ -n "${sub_commands}" ]]; then
      echo
      msg_header h3 --upper "Available sub-commands for $(style_wrap CYAN "${resource_type} ${command}")"
      local -a sub_cmds=("${(@s: :)sub_commands}")
      for sub_cmd in "${sub_cmds[@]}"; do
        if [[ -n "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}" ]]; then
          echo "  $(style_wrap CYAN "${sub_cmd}")$(printf "%*s" $((12 - ${#sub_cmd})) "")${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}"
        fi
      done
    fi
  fi
}

# Render resource types section
render_resource_types_help() {
  local format="$1"

  local max_width
  max_width=$(get_max_width "${RESOURCE_ORDER[@]}")

  if [[ "${format}" == "comprehensive" ]]; then
    msg_header h3 --upper "Resource Types"
    for resource in "${RESOURCE_ORDER[@]}"; do
      printf "  $(style_wrap CYAN BOLD "%s")%*s%s\n" "${resource}" $((max_width - ${#resource})) "" "${RESOURCE_DETAILS[${resource}]}"
    done
    echo
  else
    msg_header h3 --upper "Resource types"
    for resource in "${RESOURCE_ORDER[@]}"; do
      printf "  $(style_wrap CYAN BOLD "%s")%*s%s\n" "${resource}" $((max_width - ${#resource})) "" "${RESOURCE_DESCRIPTIONS[${resource}]}"
    done
    echo

    # Show commands by resource type in contextual mode
    if [[ "${format}" == "contextual" ]]; then
      msg_header h3 --upper "Commands by resource type"
      for resource in "${RESOURCE_ORDER[@]}"; do
        local commands="${RESOURCE_COMMANDS[${resource}]}"
        if [[ -n "${commands}" ]]; then
          printf "  $(style_wrap CYAN "%s")%*s%s\n" "${resource}" $((max_width - ${#resource})) "" "${commands// /, }"
        fi
      done
      echo

      msg_header h3 --upper "Available sub-commands (for applicable commands)"
      local -a sub_cmd_keys=($(get_all_sub_commands))
      local max_subcmd_width
      max_subcmd_width=$(get_max_width "${sub_cmd_keys[@]}")

      for sub_cmd in "${sub_cmd_keys[@]}"; do
        if [[ -n "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}" ]]; then
          printf "  $(style_wrap CYAN "%s")%*s%s\n" "${sub_cmd}" $((max_subcmd_width - ${#sub_cmd})) "" "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}"
        fi
      done
    fi
  fi
}

# Render commands section
render_commands_help() {
  local resource="$1"
  local format="$2"

  if [[ "${format}" == "comprehensive" ]]; then
    local max_width
    max_width=$(get_max_width "${COMMAND_ORDER[@]}")

    msg_header h3 --upper "Commands"
    for cmd in "${COMMAND_ORDER[@]}"; do
      printf "  $(style_wrap CYAN BOLD "%s")%*s%s.\n" "${cmd}" $((max_width - ${#cmd})) "" "${COMMAND_DESCRIPTIONS[${cmd}]}"
    done
    echo
  else
    echo
    msg_header h3 --upper "Available commands for $(style_wrap CYAN BOLD "${resource}")"

    local -a commands=("${(@s: :)RESOURCE_COMMANDS[${resource}]}")
    local max_width
    max_width=$(get_max_width "${commands[@]}")

    for cmd in "${commands[@]}"; do
      local detail_key="${cmd}_${resource}"
      if [[ -n "${COMMAND_DETAILS[${detail_key}]}" ]]; then
        printf "  $(style_wrap CYAN BOLD "%s")%*s%s\n" "${cmd}" $((max_width - ${#cmd})) "" "${COMMAND_DETAILS[${detail_key}]}"
      else
        printf "  $(style_wrap CYAN BOLD "%s")%*s%s\n" "${cmd}" $((max_width - ${#cmd})) "" "${COMMAND_DESCRIPTIONS[${cmd}]}"
      fi
    done

    # Show sub-commands if available
    local sub_commands="${RESOURCE_SUB_COMMANDS[${resource}]}"
    if [[ -n "${sub_commands}" ]]; then
      echo
      msg_header h3 --upper "Available sub-commands"
      local -a sub_cmds=("${(@s: :)sub_commands}")
      local max_subcmd_width
      max_subcmd_width=$(get_max_width "${sub_cmds[@]}")

      for sub_cmd in "${sub_cmds[@]}"; do
        printf s"  $(style_wrap CYAN "%s")%*s%s\n" "${sub_cmd}" $((max_subcmd_width - ${#sub_cmd})) "" "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}"
      done
    fi
  fi
}

# Render sub-commands section
render_sub_commands_help() {
  local resource="$1"
  local command="$2"

  local sub_commands="${RESOURCE_SUB_COMMANDS[${resource}]}"
  if [[ -n "${sub_commands}" ]]; then
    msg_header h3 --upper "Available sub-commands for $(style_wrap CYAN "${resource} ${command}")"

    local -a sub_cmds=("${(@s: :)sub_commands}")
    local max_width
    max_width=$(get_max_width "${sub_cmds[@]}")

    for sub_cmd in "${sub_cmds[@]}"; do
      if [[ -n "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}" ]]; then
        printf "  $(style_wrap CYAN "%s")%*s%s\n" "${sub_cmd}" $((max_width - ${#sub_cmd})) "" "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}"
      fi
    done
  fi
  echo
}

# Render package requirements section
render_package_requirements_help() {
  local resource="$1"

  if [[ -n "${PACKAGE_REQUIREMENTS[${resource}]}" ]]; then
    msg_header h3 --upper "Package requirements for $(style_wrap CYAN BOLD "${resource}")"
    # Split on | and display each requirement
    local requirements="${PACKAGE_REQUIREMENTS[${resource}]}"
    echo "${requirements}" | tr '|' '\n' | sed 's/^/  /'
    echo
  fi
}



# Helper function to display <resource-types> help section
# @param {string} format - "comprehensive" for full help, "contextual" for contextual help

show_resource_types_section() {
  local format="$1"
  render_help_section "resource_types" "${format}"
}


# Helper function to display <commands> help section.
# @param {string} resource_type - The resource type to show commands for ("all" for comprehensive)
# @param {string} format - "comprehensive" for full help, "contextual" for contextual help

show_commands_section() {
  local resource_type="$1"
  local format="$2"
  
  if [[ "${format}" == "comprehensive" ]]; then
    # Calculate max command width for alignment
    local max_cmd_width=0
    for cmd in "${COMMAND_ORDER[@]}"; do
      if (( ${#cmd} > max_cmd_width )); then
        max_cmd_width=${#cmd}
      fi
    done
    ((max_cmd_width += 4)) # Add padding
    
    msg_header h3 --upper "Commands"
    for cmd in "${COMMAND_ORDER[@]}"; do
      echo "  $(style_wrap CYAN BOLD "${cmd}")$(printf "%*s" $((max_cmd_width - ${#cmd})) "")${COMMAND_DESCRIPTIONS[${cmd}]}."
    done
    echo
  else
    echo
    msg_header h3 --upper "Available commands for $(style_wrap CYAN BOLD "${resource_type}")"
    local -a commands
    commands=("${(@s: :)RESOURCE_COMMANDS[${resource_type}]}")
    
    # Calculate max command width for this resource's commands
    local max_cmd_width=0
    for cmd in "${commands[@]}"; do
      if (( ${#cmd} > max_cmd_width )); then
        max_cmd_width=${#cmd}
      fi
    done
    ((max_cmd_width += 4)) # Add padding
    
    for cmd in "${commands[@]}"; do
      local detail_key="${cmd}_${resource_type}"
      if [[ -n "${COMMAND_DETAILS[${detail_key}]}" ]]; then
        echo "  $(style_wrap CYAN BOLD "${cmd}")$(printf "%*s" $((max_cmd_width - ${#cmd})) "")${COMMAND_DETAILS[${detail_key}]}"
      else
        echo "  $(style_wrap CYAN BOLD "${cmd}")$(printf "%*s" $((max_cmd_width - ${#cmd})) "")${COMMAND_DESCRIPTIONS[${cmd}]}"
      fi
    done
    
    # Show sub-commands if available
    local sub_commands="${RESOURCE_SUB_COMMANDS[${resource_type}]}"
    if [[ -n "${sub_commands}" ]]; then
      echo
      msg_header h3 --upper "Available sub-commands"
      local -a sub_cmds
      sub_cmds=("${(@s: :)sub_commands}")
      
      # Calculate max sub-command width for alignment
      local max_subcmd_width=0
      for sub_cmd in "${sub_cmds[@]}"; do
        if (( ${#sub_cmd} > max_subcmd_width )); then
          max_subcmd_width=${#sub_cmd}
        fi
      done
      ((max_subcmd_width += 4)) # Add padding
      
      for sub_cmd in "${sub_cmds[@]}"; do
        echo "  $(style_wrap CYAN "${sub_cmd}")$(printf "%*s" $((max_subcmd_width - ${#sub_cmd})) "")${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}"
      done
    fi
    
    # Show additional contextual info based on resource capabilities

    # Show general examples for this resource type
    echo
    msg_header h3 --upper "Examples"
    local resource_examples="${USAGE_EXAMPLES[${resource_type}]}"
    if [[ -n "${resource_examples}" ]]; then
      local -a example_pairs
      example_pairs=("${(@s:!!:)resource_examples}")
      
      # Calculate max command width for alignment
      local max_width=0
      for pair in "${example_pairs[@]}"; do
        if [[ "${pair}" == *"||"* ]]; then
          local cmd="${pair%%||*}"
          if (( ${#cmd} > max_width )); then
            max_width=${#cmd}
          fi
        fi
      done
      ((max_width += 4)) # Add padding
      
      local count=0
      for pair in "${example_pairs[@]}"; do
        if [[ "${pair}" == *"||"* ]]; then
          local cmd="${pair%%||*}"
          local desc="${pair##*||}"
          echo "  $(style_wrap CYAN "${cmd//\{TOOLNAME\}/${NAME}}")$(printf "%*s" $((max_width - ${#cmd})) "")${desc}"
          ((count++))
          [[ ${count} -ge 4 ]] && break
        fi
      done
    fi
    
    # Show package management info for resources that support add/remove
    local resource_commands="${RESOURCE_COMMANDS[${resource_type}]}"
    if [[ "${resource_commands}" == *"add"* && "${resource_commands}" == *"remove"* ]]; then
      echo
      msg_header h3 --upper "Package names (for add/remove)"
      echo "  Multiple package names can be specified:"
      
      # Show add-specific examples for this resource type
      if [[ -n "${resource_examples}" ]]; then
        local -a example_pairs
        example_pairs=("${(@s:!!:)resource_examples}")
        local count=0
        for pair in "${example_pairs[@]}"; do
          if [[ "${pair}" == *"||"* && "${pair}" == *"add"* ]]; then
            local cmd="${pair%%||*}"
            echo "  $(style_wrap CYAN "${cmd//\{TOOLNAME\}/${NAME}}")"
            ((count++))
            [[ ${count} -ge 2 ]] && break
          fi
        done
      fi
    fi
    
    # Show resource-specific notes
    show_resource_notes "${resource_type}"
  fi
}


# Helper function to display <sub-commands> help section.
# @param {string} format - "comprehensive" for full help, "contextual" for contextual help

show_sub_commands_section() {
  local format="$1"
  
  if [[ "${format}" == "comprehensive" ]]; then
    local -a sub_cmd_keys=($(get_all_sub_commands))
    
    # Calculate max sub-command width for alignment  
    local max_subcmd_width=0
    for sub_cmd in "${sub_cmd_keys[@]}"; do
      if (( ${#sub_cmd} > max_subcmd_width )); then
        max_subcmd_width=${#sub_cmd}
      fi
    done
    ((max_subcmd_width += 4)) # Add padding
    
    msg_header h3 --upper "Sub-Commands"
    for sub_cmd in "${sub_cmd_keys[@]}"; do
      echo "  $(style_wrap CYAN BOLD "${sub_cmd}")$(printf "%*s" $((max_subcmd_width - ${#sub_cmd})) "")${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}"
    done
    echo
  fi
}

# Helper function to display the examples help section
# @param {string} context - Context for examples ("general", "package_names", "sub_command")
# @param {string} resource_type - Resource type for contextual examples
# @param {string} command - Command for contextual examples
show_examples_section() {
  local context="$1"
  local resource_type="$2"
  local command="$3"
  
  msg_header h3 --upper "Examples"
  
  case "${context}" in
    general)
      local examples="${USAGE_EXAMPLES[general]}"
      if [[ -n "${examples}" ]]; then
        local -a example_pairs
        example_pairs=("${(@s:!!:)examples}")
        
        # Calculate max command width for alignment
        local max_width=0
        for pair in "${example_pairs[@]}"; do
          if [[ "${pair}" == *"||"* ]]; then
            local cmd="${pair%%||*}"
            if (( ${#cmd} > max_width )); then
              max_width=${#cmd}
            fi
          fi
        done
        ((max_width += 4)) # Add padding
        
        for pair in "${example_pairs[@]}"; do
          if [[ "${pair}" == *"||"* ]]; then
            local cmd="${pair%%||*}"
            local desc="${pair##*||}"
            printf "  $(style_wrap BOLD "${cmd//\{TOOLNAME\}/${NAME}}")$(printf "%*s" $((max_width - ${#cmd})) "")%s\n" "${desc}"
          fi
        done
        echo
      fi
      ;;
    package_names | sub_command)
      local examples="${USAGE_EXAMPLES[${resource_type}]}"
      if [[ -n "${examples}" ]]; then
        local -a example_pairs
        example_pairs=("${(@s:!!:)examples}")
        for pair in "${example_pairs[@]}"; do
          if [[ "${pair}" == *"||"* ]]; then
            local cmd="${pair%%||*}"
            local desc="${pair##*||}"
            echo "  $(style_wrap BOLD "${cmd}")  # ${desc}"
          fi
        done
    fi
      ;;
    *)
  esac
}

# Helper function to display package requirements help section.
# @param {string} resource_type - Resource type to show requirements for
show_package_requirements_section() {
  local resource_type="$1"
  
  msg_header h3 --upper "Package name requirements"
  echo "  • At least one package name is required"
  echo "  • Multiple package names can be separated by spaces"
  
  local requirements="${PACKAGE_REQUIREMENTS[${resource_type}]}"
  if [[ -n "${requirements}" ]]; then
    echo "${requirements}" | tr '|' '\n' | sed 's/^/  /'
  fi
}

# Shows contextual help based on current command context.
# @param {string} context - The context for help (e.g., "resource_type", "command", "package_names")
# @param {string} resource_type - Current resource type if applicable
# @param {string} command - Current command if applicable
show_contextual_help() {
  local context="$1"
  local resource_type="$2"
  local command="$3"
  
  case "${context}" in
    resource_type)
      echo
      msg_header h3 --upper "Usage"
      echo -e "  $(style_wrap BOLD "${NAME} <resource-type> <command> [sub-command] [pkg-name...]")"
      echo
      show_resource_types_section "contextual"
      ;;
      
    command)
      echo
      msg_header h3 --upper "Usage"
      show_usage_for_resource "${resource_type}"
      show_commands_section "${resource_type}" "contextual"
      ;;      
    package_names)
      echo
      msg_error --color "You didn't specify any package name(s) to <${command}> to <${resource_type}>."
      echo
      show_package_usage "${resource_type}" "${command}"
      show_package_requirements_section "${resource_type}"
      echo
      show_examples_section "package_names" "${resource_type}" "${command}"
      ;;
    sub_command)
      echo
      msg_header h3 --upper "Usage"
      echo -e "  $(style_wrap BOLD "${NAME} ${resource_type} ${command} [sub-command]")"
      show_available_subcommands "${resource_type}" "${command}"
      echo
      show_examples_section "sub_command" "${resource_type}" "${command}"
      ;;
    *)
    # Something went wrong - show general help
    msg_warning "Unknown help context. Showing general usage."
    echo
    msg_header h3 --upper "General Usage"
    echo -e "  $(style_wrap BOLD "${NAME} <resource-type> [subtype] <command> [sub-command] [pkg-names...]")"
    ;;
  esac

  echo -e "\nType $(style_wrap BOLD "${NAME}") or $(style_wrap BOLD "${NAME} --help") for complete help."
}

# Displays contextual help including usage, options, resource types, subtypes, commands, and examples.
show_help() {
  # Get description from package.json using get_package_info function
  description=$(get_package_info "description")
  echo
  show_apple_logo
  echo
  show_logo
  show_version
  style_wrap ITALIC M "\n${description}\n"
  msg_header h3 --upper "Usage"
  echo -e "  $(style_wrap BOLD "${NAME} <resource-type> [resource-subtype] <command> [sub-command] [pkg-name...]")\n"

  show_resource_types_section "comprehensive"

  # Show dynamic resource subtypes
  msg_header h3 --upper "Resource Subtypes"
  local -a resources_with_subtypes=()
  for resource in "${RESOURCE_ORDER[@]}"; do
    local capabilities=($(get_resource_capabilities "${resource}"))
    if [[ " ${capabilities[*]} " =~ " has_subtypes " ]]; then
      resources_with_subtypes+=("${resource}")
    fi
  done
  
  if [[ ${#resources_with_subtypes[@]} -gt 0 ]]; then
    echo -e "  Applies to these resource types (if omitted, defaults to all subtypes):"
    for resource in "${resources_with_subtypes[@]}"; do
      local -a subtypes=($(get_resource_subtypes "${resource}"))
      echo -e "  $(style_wrap CYAN BOLD "${resource}"):"
      for subtype in "${subtypes[@]}"; do
        echo -e "    $(style_wrap CYAN BOLD "${subtype}")  # ${APPLIST_KEY_DESCRIPTIONS[${resource}_${subtype}]:-"${subtype} packages"}"
      done
    done
    echo
  else
    echo -e "  No resources currently support subtypes.\n"
  fi
  
  show_commands_section "all" "comprehensive"
  
  show_sub_commands_section "comprehensive"

  msg_header h3 --upper "Global Options"
  echo -e "  $(style_wrap CYAN "--help")         Show this help message."
  echo -e "  $(style_wrap CYAN "--version")      Show version information with logo."
  echo -e "  $(style_wrap CYAN "--config")       Show configuration file location and status."
  echo -e "  $(style_wrap CYAN "--cleanup")      Remove all backup files (requires confirmation)."
  echo -e "  $(style_wrap CYAN "--completions")    Generate shell completion script.\n"

  show_examples_section "general"

  # msg_header h3 --upper "Notes"
  # echo -e "  • The $(style_wrap BOLD "add") and $(style_wrap BOLD "remove") commands must apply only to $(style_wrap BOLD "brew"), $(style_wrap BOLD "npm"), and $(style_wrap BOLD "appstore") resources."
  # echo -e "  • For $(style_wrap BOLD "brew add") or $(style_wrap BOLD "brew remove") commands, the resource-subtype is optional and defaults to $(style_wrap BOLD "formulas") when omitted."
  # echo -e "    If omitted, the command applies to both $(style_wrap BOLD "casks") and $(style_wrap BOLD "formulas")."
  # echo -e "  • For $(style_wrap BOLD "list"), $(style_wrap BOLD "install"), and $(style_wrap BOLD "update") commands on the $(style_wrap BOLD "brew") resource, the resource-subtype is optional."
  # echo -e "  • The $(style_wrap BOLD "outdated") sub-command does not apply to $(style_wrap BOLD "xcode") or $(style_wrap BOLD "system") resources."
  # echo -e "  • User confirmation is implemented for any $(style_wrap BOLD "update all") or $(style_wrap BOLD "install all") operation."
  # echo -e "  • Enable intelligent tab completion by adding this to your shell configuration:"
  # echo -e "    $(style_wrap BOLD "eval (${name} completions)")"
}
