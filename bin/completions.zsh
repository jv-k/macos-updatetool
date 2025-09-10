#!/bin/zsh

# This file contains the function that generates dynamic shell completions
#
# Author: John Valai <git@jvk.to>
# License: MIT License

# Emits a zsh completion function for the app, dynamically generated from existing data structures.
shell_completions() {
  # Build dynamic completion data from our existing data structures
  local resource_completions=""
  local command_completions=""
  local sub_command_completions=""
  local brew_subtype_completions=""
  local limited_xcode_system_completions=""
  local limited_all_completions=""
  
  # Generate resource type completions
  for resource in "${RESOURCE_ORDER[@]}"; do
    resource_completions+="    '${resource}:${RESOURCE_DESCRIPTIONS[${resource}]}'\n"
  done
  
  # Generate command completions
  for cmd in "${COMMAND_ORDER[@]}"; do
    command_completions+="    '${cmd}:${COMMAND_DESCRIPTIONS[${cmd}]}'\n"
  done
  
  # Generate sub-command completions
  for sub_cmd in outdated all; do
    if [[ -n "${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}" ]]; then
      sub_command_completions+="    '${sub_cmd}:${SUB_COMMAND_DESCRIPTIONS[${sub_cmd}]}'\n"
    fi
  done
  
  # Generate brew subtype completions
  brew_subtype_completions="    'formulas:command-line tools'\n    'casks:GUI applications'"
  
  # Generate limited command sets for xcode/system
  local -a xcode_cmds
  xcode_cmds=("${(@s: :)RESOURCE_COMMANDS[xcode]}")
  for cmd in "${xcode_cmds[@]}"; do
    limited_xcode_system_completions+="    '${cmd}:${COMMAND_DESCRIPTIONS[${cmd}]}'\n"
  done
  
  # Generate limited command sets for all
  local -a all_cmds
  all_cmds=("${(@s: :)RESOURCE_COMMANDS[all]}")
  for cmd in "${all_cmds[@]}"; do
    limited_all_completions+="    '${cmd}:${COMMAND_DESCRIPTIONS[${cmd}]}'\n"
  done
  
  # Process the template file with our dynamic data
  local template_file="${MODULE_DIR}/completions/_macos-updatetool.template"
  
  if [[ ! -f "${template_file}" ]]; then
    echo "Error: Completion template not found at ${template_file}" >&2
    return 1
  fi
  
  # Use sed to replace placeholders in the template
  sed \
    -e "s|{{NAME}}|${NAME}|g" \
    -e "s|{{RESOURCE_COMPLETIONS}}|${resource_completions%\\n}|g" \
    -e "s|{{COMMAND_COMPLETIONS}}|${command_completions%\\n}|g" \
    -e "s|{{SUB_COMMAND_COMPLETIONS}}|${sub_command_completions%\\n}|g" \
    -e "s|{{BREW_SUBTYPE_COMPLETIONS}}|${brew_subtype_completions}|g" \
    -e "s|{{LIMITED_XCODE_SYSTEM_COMPLETIONS}}|${limited_xcode_system_completions%\\n}|g" \
    -e "s|{{LIMITED_ALL_COMPLETIONS}}|${limited_all_completions%\\n}|g" \
    "${template_file}"
}
