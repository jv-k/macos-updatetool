#!/bin/zsh

# Messages module
#
# Purpose:
# - Provide a unified, flexible messaging system for the macOS update tool.
# - Deliver consistent visual formatting with styled symbols, colors, and indentation.
# - Support flag-based customisation of message appearance (bold, italic, colors, etc).
#
# Responsibilities:
# - Parse and apply styling flags (--bold, --italic, --underline, --upper, --color).
# - Handle message indentation automatically based on leading spaces.
# - Preserve ANSI escape sequences when applying transformations like uppercasing.
# - Provide semantic message types: info, success, warning, error, question, bullet, header.
# - Ensure consistent symbol usage (✔, ✖, !, ?, •, ℹ) across all message output.
# - Support hierarchical headers (h1-h6) with appropriate styling.
#
# Public functions (used by main script and other modules):
# - msg_info(message)        : informational messages with ℹ symbol  
# - msg_success(message)     : success messages with ✔ symbol
# - msg_warning(message)     : warning messages with ! symbol
# - msg_error(message)       : error messages with ✖ symbol  
# - msg_question(message)    : question prompts with ? symbol
# - msg_bullet(message)      : bullet points with • symbol
# - msg_header([h1-h6], message) : styled headers with configurable levels
# - msg_muted(message)       : dimmed/gray messages for less important info
#
# Flag support (available on all message functions):
# - --color  : apply semantic color (info=cyan, success=green, error=red, etc.)
# - --bold   : apply bold formatting
# - --italic : apply italic formatting  
# - --underline : apply underline formatting
# - --upper  : transform text to uppercase while preserving ANSI codes
#
# Notes:
# - All functions automatically handle indentation based on leading spaces in messages.
# - Indentation processing rounds down to nearest even number of spaces for consistent alignment.
#
# Author: John Valai <git@jvk.to>
# License: MIT License

source "${MODULE_DIR}/styles.zsh"

# Parses common styling flags for message helpers and emits variable assignments.
# Usage: eval "$(parse_style_flags defaultColor "$@")"
# Sets: text_color, text_styles, text_upper, remaining_args (array-like)
# @param {string} default_color - Default color style to apply when --color is present.
# @param {...string} args - Flags and message parts.
parse_style_flags() {
  local default_color="$1"
  shift
  local text_color=""
  local text_styles=""
  local text_upper=""

  while [[ $# -gt 0 ]]; do
  case "$1" in
    --color)
    text_color="${default_color}"
    shift
    ;;
    --bold)
    text_styles+="${STYLE[BOLD]}"
    shift
    ;;
    --italic)
    text_styles+="${STYLE[ITALIC]}"
    shift
    ;;
    --underline)
    text_styles+="${STYLE[UNDERLINE]}"
    shift
    ;;
    --upper)
    text_upper="1"
    shift
    ;;
    *)
    break
    ;;
  esac
  done

  # Output variable assignments and remaining args
  printf "text_color=%q\n" "${text_color}"
  printf "text_styles=%q\n" "${text_styles}"
  printf "text_upper=%q\n" "${text_upper}"
  # Build remaining_args string manually to avoid glob issues
  printf "remaining_args=("
  for arg in "$@"; do
  printf " %q" "${arg}"
  done
  printf " )\n"
}

# Extracts leading indentation (multiples of 2 spaces) from a message.
# Emits: clean_message, indent_prefix
# @param {string} message - The message text that may start with spaces.
parse_message_indent() {
  local message="$1"
  local clean_message="${message}"
  local indent_prefix=""

  # Count leading spaces and extract them in multiples of 2
  local leading_spaces=""
  while [[ ${clean_message} == " "* ]]; do
  leading_spaces+=" "
  clean_message="${clean_message:1}"
  done

  # Calculate indent based on multiples of 2 spaces
  local space_count=${#leading_spaces}
  local indent_count=$((space_count / 2 * 2))  # Round down to nearest even number

  if [[ ${indent_count} -gt 0 ]]; then
  indent_prefix=$(printf "%*s" "${indent_count}" "")
  # Remove the processed spaces from message
  clean_message="${message:${indent_count}}"
  fi

  # Output the results
  printf "clean_message=%q\n" "${clean_message}"
  printf "indent_prefix=%q\n" "${indent_prefix}"
}

# Applies uppercase transformation while preserving ANSI escape sequences.
# This function processes text character by character, preserving escape sequences.
# @param {string} text - Text that may contain ANSI escape sequences.
# @returns {string} Text with uppercase applied to visible characters only.
apply_uppercase_preserving_ansi() {
  local text="$1"
  local result=""
  local i=1
  local in_escape=0

  while [[ ${i} -le ${#text} ]]; do
  local char="${text[${i}]}"

  if [[ "${char}" == $'\x1b' ]]; then
    # Start of escape sequence
    in_escape=1
    result+="${char}"
  elif [[ ${in_escape} -eq 1 ]]; then
    # In escape sequence, preserve as-is
    result+="${char}"
    # Check if this is the end of the escape sequence (letter character)
    if [[ "${char}" =~ [a-zA-Z] ]]; then
    in_escape=0
    fi
  else
    # Regular character, apply uppercase
    result+="${char:u}"
  fi

  ((i++))
  done

  echo "${result}"
}

# Applies color and style sequences to a message and optionally uppercases it.
# @param {string} text_color - Color escape (can be empty).
# @param {string} text_styles - Style escapes (can be empty).
# @param {string} message - Message text.
# @param {string} text_upper - Non-empty string triggers uppercasing.
# @returns {string} Styled message printed to stdout.
apply_text_styles() {
  local text_color="$1"
  local text_styles="$2"
  local message="$3"
  local text_upper="$4"

  # Apply uppercase if requested
  if [[ -n "${text_upper}" ]]; then
  message="${message:u}"
  fi

  if [[ -n "${text_color}" || -n "${text_styles}" ]]; then
  echo -e "${text_color}${text_styles}${message}${STYLE[RESET]}"
  else
  echo -e "${message}"
  fi
}

# Prints an informational message with an ℹ symbol and optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_info() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[CYAN]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  echo -e "${indent_prefix}$(style_wrap CYAN "${SYMBOL[INFO]}") $(apply_text_styles "${text_color}" "${text_styles}" "${clean_message## }" "${text_upper}")"
}

# Prints a styled header line with configurable level (h1-h6).
# Flags: --bold, --italic, --underline, --upper
# @param {string} [level=h1] - Header level (h1-h6).
# @param {...string} args - Header text and optional default text.
msg_header() {
  local header_level="h1"
  local styled_text=""
  local default_text=""
  local indent=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Check if first argument is a header level
  if [[ "$1" =~ ^h[1-6]$ ]]; then
  header_level="$1"
  shift
  fi

  # Parse style flags using the unified function
  eval "$(parse_style_flags "" "$@")"

  # remaining_args is now an array, extract the elements safely
  styled_text="${remaining_args}"

  # Get any remaining text as default text
  default_text=""
  if [[ ${#remaining_args[@]} -gt 1 ]]; then
  default_text="${remaining_args[2,-1]}"
  fi

  # Convert escape sequences to actual characters before processing
  styled_text=$(printf "%b" "${styled_text}")

  # Handle indentation for styled text using the new helper
  local clean_message="" indent_prefix=""
  eval "$(parse_message_indent "${styled_text}")"
  styled_text="${clean_message}"
  indent="${indent_prefix}"

  # Apply uppercase if requested
  if [[ -n "${text_upper}" ]]; then
  styled_text="$(apply_uppercase_preserving_ansi "${styled_text}")"
  fi

  # Get the header style and combine with additional styles from flags
  local header_style="${STYLE[${header_level:u}]}${text_styles}"

  # Build the output with proper newline handling
  local output="${indent}${header_style}${styled_text## }${STYLE[RESET]}"

  # Add default text if provided
  if [[ -n "${default_text}" ]]; then
  output+=" ${default_text}"
  fi

  # Use printf to properly handle escape sequences instead of echo -e
  printf "%b\n" "${output}"
}

# Prints a muted (dim/gray) message, preserving optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_muted() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[HI_BLACK]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  # Create combined style with HI_BLACK as base
  local combined_style="${STYLE[HI_BLACK]}${text_color}${text_styles}"
  echo -e "${indent_prefix}$(apply_text_styles "${combined_style}" "" "${clean_message## }" "${text_upper}")"
}

# Prints a success message with a ✔ symbol and optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_success() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[GREEN]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  echo -e "${indent_prefix}$(style_wrap GREEN "${SYMBOL[SUCCESS]}") $(apply_text_styles "${text_color}" "${text_styles}" "${clean_message## }" "${text_upper}")"
}

# Prints a warning message with a ! symbol and optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_warning() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[YELLOW]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  echo -e "${indent_prefix}$(style_wrap YELLOW "${SYMBOL[WARNING]}") $(apply_text_styles "${text_color}" "${text_styles}" "${clean_message## }" "${text_upper}")"
}

# Prints an error message with a ✖ symbol and optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_error() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[RED]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  echo -e "${indent_prefix}$(style_wrap RED "${SYMBOL[DANGER]}") $(apply_text_styles "${text_color}" "${text_styles}" "${clean_message## }" "${text_upper}")"
}

# Prints a bullet list entry with • symbol and optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_bullet() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[PURPLE]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  echo -e "${indent_prefix}$(style_wrap PURPLE "${SYMBOL[BULLET]}") $(apply_text_styles "${text_color}" "${text_styles}" "${clean_message## }" "${text_upper}")"
}

# Prints a question message with a ? symbol and optional styles.
# Flags: --color, --bold, --italic, --underline, --upper
# @param {...string} args - Message and optional style flags.
msg_question() {
  local message=""
  local clean_message=""
  local indent_prefix=""
  local text_color=""
  local text_styles=""
  local text_upper=""
  local remaining_args=""

  # Parse style flags
  eval "$(parse_style_flags "${STYLE[YELLOW]}" "$@")"
  message="${remaining_args}"

  # Parse indentation from message
  eval "$(parse_message_indent "${message}")"

  echo -e "${indent_prefix}$(style_wrap YELLOW "${SYMBOL[QUESTION]}") $(apply_text_styles "${text_color}" "${text_styles}" "${clean_message## }" "${text_upper}")"
}
