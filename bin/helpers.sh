#!/bin/zsh

# Output utilities for clean messages
# This file contains all message formatting functions for macos-updatetool

# Import styles
source "${0:A:h}/styles.zsh"

# Helper function to parse common styling flags
# Usage: eval "$(parse_style_flags "$default_color" "$@")"
# Sets: text_color, text_styles, text_upper, remaining_args
parse_style_flags() {
  local default_color="$1"
  shift
  local text_color=""
  local text_styles=""
  local text_upper=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --color)
        text_color="$default_color"
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
  printf "text_color=%q\n" "$text_color"
  printf "text_styles=%q\n" "$text_styles"
  printf "text_upper=%q\n" "$text_upper"
  # Build remaining_args string manually to avoid glob issues
  printf "remaining_args=("
  for arg in "$@"; do
    printf " %q" "$arg"
  done
  printf " )\n"
}

# Helper function to parse indentation from message text
# Extracts leading spaces in multiples of 2 and returns cleaned message and indent
# @param {string} message - The message text that may start with spaces
# @returns Sets: clean_message, indent_prefix
parse_message_indent() {
  local message="$1"
  local clean_message="$message"
  local indent_prefix=""
  
  # Count leading spaces and extract them in multiples of 2
  local leading_spaces=""
  while [[ $clean_message == " "* ]]; do
    leading_spaces+=" "
    clean_message="${clean_message:1}"
  done
  
  # Calculate indent based on multiples of 2 spaces
  local space_count=${#leading_spaces}
  local indent_count=$((space_count / 2 * 2))  # Round down to nearest even number
  
  if [[ $indent_count -gt 0 ]]; then
    indent_prefix=$(printf "%*s" $indent_count "")
    # Remove the processed spaces from message
    clean_message="${message:$indent_count}"
  fi
  
  # Output the results
  printf "clean_message=%q\n" "$clean_message"
  printf "indent_prefix=%q\n" "$indent_prefix"
}

# Helper function to apply text styles dynamically
# @param {string} text_color - The color style code (can be empty)
# @param {string} text_styles - The style codes (can be empty)
# @param {string} message - The message text
# @param {string} text_upper - Whether to uppercase the text (can be empty)
apply_text_styles() {
  local text_color="$1"
  local text_styles="$2"
  local message="$3"
  local text_upper="$4"
  
  # Apply uppercase if requested
  if [[ -n "$text_upper" ]]; then
    message="${message:u}"
  fi
  
  if [[ -n "$text_color" || -n "$text_styles" ]]; then
    echo -e "${text_color}${text_styles}${message}${STYLE[RESET]}"
  else
    echo -e "$message"
  fi
}

# @param {...string} args - Message text to display
# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic  
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  echo -e "$indent_prefix$(style_wrap CYAN "${SYMBOL[INFO]}") $(apply_text_styles "$text_color" "$text_styles" "${clean_message## }" "$text_upper")"
}

# @param {string} [level=h1] - Header level (h1-h6), optional, defaults to h1
# @param {string} styled_text - Text to be styled with the header level
# @param {string} [default_text] - Optional text in default style to append
# @param --bold - Optional flag to add bold to the header text
# @param --italic - Optional flag to add italic to the header text
# @param --underline - Optional flag to add underline to the header text
# @param --upper - Optional flag to make the header text uppercase
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
  styled_text="${remaining_args[1]}"
  
  # Get any remaining text as default text
  default_text=""
  if [[ ${#remaining_args[@]} -gt 1 ]]; then
    default_text="${remaining_args[2,-1]}"
  fi
  
  # Convert escape sequences to actual characters before processing
  styled_text=$(printf "%b" "$styled_text")
  
  # Handle indentation for styled text using the new helper
  local clean_message="" indent_prefix=""
  eval "$(parse_message_indent "$styled_text")"
  styled_text="$clean_message"
  indent="$indent_prefix"
  
  # Apply uppercase if requested
  if [[ -n "$text_upper" ]]; then
    styled_text="${styled_text:u}"
  fi
  
  # Get the header style and combine with additional styles from flags
  local header_style="${STYLE[${header_level:u}]}${text_styles}"
  
  # Build the output with proper newline handling
  local output="$indent${header_style}${styled_text## }${STYLE[RESET]}"
  
  # Add default text if provided
  if [[ -n "$default_text" ]]; then
    output+=" ${default_text}"
  fi
  
  # Use printf to properly handle escape sequences instead of echo -e
  printf "%b\n" "$output"
}

# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  # Create combined style with HI_BLACK as base
  local combined_style="${STYLE[HI_BLACK]}${text_color}${text_styles}"
  echo -e "$indent_prefix$(apply_text_styles "$combined_style" "" "${clean_message## }" "$text_upper")"
}

# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  echo -e "$indent_prefix$(style_wrap GREEN "${SYMBOL[SUCCESS]}") $(apply_text_styles "$text_color" "$text_styles" "${clean_message## }" "$text_upper")"
}

# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  echo -e "$indent_prefix$(style_wrap YELLOW "${SYMBOL[WARNING]}") $(apply_text_styles "$text_color" "$text_styles" "${clean_message## }" "$text_upper")"
}

# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  echo -e "$indent_prefix$(style_wrap RED "${SYMBOL[DANGER]}") $(apply_text_styles "$text_color" "$text_styles" "${clean_message## }" "$text_upper")"
}

# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  echo -e "$indent_prefix$(style_wrap PURPLE "${SYMBOL[BULLET]}") $(apply_text_styles "$text_color" "$text_styles" "${clean_message## }" "$text_upper")"
}

# @param --color - Optional flag to make the entire message text colored
# @param --bold - Optional flag to make the message text bold
# @param --italic - Optional flag to make the message text italic
# @param --underline - Optional flag to make the message text underlined
# @param --upper - Optional flag to make the message text uppercase
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
  message="$remaining_args"
  
  # Parse indentation from message
  eval "$(parse_message_indent "$message")"
  
  echo -e "$indent_prefix$(style_wrap YELLOW "${SYMBOL[QUESTION]}") $(apply_text_styles "$text_color" "$text_styles" "${clean_message## }" "$text_upper")"
}

# Shows a spinner while a background command is running
# @param {string} message - Message to display with spinner
# @param {string} command - Command to run in background
# @param {string} [timeout] - Optional timeout in seconds (default: 30)
# @param {string} [--show-output] - Optional flag to show command output on success
# @param {string} [--sudo] - Optional flag to ensure sudo authentication before running command
# Note: If message starts with spaces, indent is moved to spinner and output is further indented
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
        if [[ -z "$message" ]]; then
          message="$1"
        elif [[ -z "$command" ]]; then
          command="$1"
        elif [[ -z "$timeout" ]]; then
          timeout="$1"
        fi
        shift
        ;;
    esac
  done
  
  # Set timeout: use default if not specified, disable if set to 0
  if [[ -z "$timeout" ]]; then
    timeout="$default_timeout"
  fi
  
  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local temp_file
  local temp_err
  local pid
  
  temp_file=$(mktemp)
  temp_err=$(mktemp)

  # Handle indentation using the new helper function
  local clean_message="" indent_prefix=""
  eval "$(parse_message_indent "$message")"
  
  # Calculate output indentation (2 more spaces than spinner indent)
  local output_indent=""
  if [[ -n "$indent_prefix" ]]; then
    output_indent="${indent_prefix}  "
  fi

  # Handle sudo authentication if requested
  if [[ "$use_sudo" == "true" ]]; then
    if ! ensure_sudo; then
      rm -f "$temp_file" "$temp_err"
      return 1
    fi
  fi

  # Start command in background
  eval "$command" > "$temp_file" 2> "$temp_err" &
  pid=$!

  # Show spinner while command runs
  local i=0
  while kill -0 $pid 2>/dev/null; do
    local spinner_char=${spinner_chars:$((i % ${#spinner_chars})):1}
    printf "\r${indent_prefix}$(style_wrap CYAN "$spinner_char") $clean_message..."
    sleep 0.1
    ((i++))
    
    # Check for timeout (skip if timeout is 0)
    if [[ "$timeout" != "0" ]] && [[ $((i / 10)) -gt $timeout ]]; then
      kill $pid 2>/dev/null
      printf "\r${indent_prefix}$(style_wrap RED "${SYMBOL[DANGER]}") $clean_message (timed out)\n"
      rm -f "$temp_file" "$temp_err"
      return 1
    fi
  done

  # Wait for command to finish and get exit code
  wait $pid
  local exit_code=$?

  # Clear spinner line and show result
  printf "\r"
  if [[ $exit_code -eq 0 ]]; then
    msg_success "${indent_prefix}$clean_message   "
    # Show output only if requested and there is output
    if [[ "$show_output" == "true" ]]; then
      if [[ -n "$output_indent" ]] && [[ -s "$temp_file" ]]; then
        sed "s/^/$output_indent/" "$temp_file"
      elif [[ -s "$temp_file" ]]; then
        cat "$temp_file"
      fi
    fi
  else
    msg_error "${indent_prefix}$clean_message failed."
    # Always show error output (but limit to first line)
    if [[ -n "$output_indent" ]] && [[ -s "$temp_err" ]]; then
      if [[ "$show_output" == "true" ]]; then
        echo -e "${STYLE[YELLOW]}$(sed "s/^/$output_indent/" "$temp_err")${STYLE[RESET]}"
      else
        echo -e "${STYLE[LIGHT_RED]}$(sed "s/^/$output_indent/" "$temp_err" | head -n 1)${STYLE[RESET]}"
      fi
    elif [[ -s "$temp_err" ]]; then
      if [[ "$show_output" == "true" ]]; then
        echo -e "${STYLE[YELLOW]}$(cat "$temp_err")${STYLE[RESET]}"
      else
        echo -e "${STYLE[LIGHT_RED]}$(cat "$temp_err" | head -n 1)${STYLE[RESET]}"
      fi
    fi
  fi

  rm -f "$temp_file" "$temp_err"
  return $exit_code
}

# Ensures sudo authentication is available for subsequent commands
# This allows commands requiring sudo to run in show_spinner without prompting
# @returns {number} 0 on success, 1 if user cancels or authentication fails
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
