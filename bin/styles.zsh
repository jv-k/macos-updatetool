#!/bin/zsh

# Styles module
#
# Purpose:
# - Provide comprehensive ANSI color codes and text formatting definitions for consistent terminal styling.
# - Offer utilities for combining, chaining, and applying multiple style attributes to text output.
# - Enable dynamic style demonstration and testing capabilities for development and debugging.
#
# Responsibilities:
# - Define extensive color palettes (standard, light, high-intensity, and background colors).
# - Provide text formatting options (bold, italic, underline, strikethrough, etc.).
# - Supply semantic UI symbols for consistent visual communication (✔, ✖, !, ?, •, ℹ).
# - Implement style chaining utilities for combining multiple formatting attributes.
# - Generate header styles (H1-H6) with appropriate visual hierarchy.
# - Offer text wrapping functions that apply styles and automatically reset formatting.
#
# Public functions (used by main script and other modules):
# - style_chain(styles...)        : combine multiple ANSI codes into single escape sequence
# - style_wrap(styles..., text)   : wrap text with styles and automatic reset
# - style_h1-h6(text)             : semantic header functions with predefined styling
# - style_quote(text)             : styled quote formatting
# - style_demo()                  : comprehensive demonstration of all available styles
#
# Public constants:
# - STYLE[key]                    : associative array of ANSI escape codes
# - SYMBOL[key]                   : associative array of UI symbols
# - Header styles (H1-H7, QUOTE)  : pre-configured style combinations
#
# Notes:
# - Interactive detection automatically shows demo when sourced directly in shell.
# - All functions preserve terminal state by including RESET sequences.
# - Style combinations are optimized to avoid conflicting or redundant codes.
# - Designed to work consistently across different terminal emulators and themes.
#
# Author: John Valai <git@jvk.to>
# License: MIT License

# shellcheck disable=SC2128

# Extended color definitions based on ANSI codes
typeset -A STYLE=(
  [DEFAULT_FG]='\e[39m'
  [DEFAULT_BG]='\e[49m'

  [BLACK]='\e[30m'
  [RED]='\e[31m'
  [GREEN]='\e[32m'
  [YELLOW]='\e[33m'
  [BLUE]='\e[34m'
  [PURPLE]='\e[35m'
  [CYAN]='\e[36m'
  [WHITE]='\e[37m'

  [LIGHT_BLACK]='\e[1;30m'
  [LIGHT_RED]='\e[1;31m'
  [LIGHT_GREEN]='\e[1;32m'
  [LIGHT_YELLOW]='\e[1;33m'
  [LIGHT_BLUE]='\e[1;34m'
  [LIGHT_PURPLE]='\e[1;35m'
  [LIGHT_CYAN]='\e[1;36m'
  [LIGHT_WHITE]='\e[1;37m'
  
  [HI_BLACK]='\e[0;90m'
  [HI_RED]='\e[0;91m'
  [HI_GREEN]='\e[0;92m'
  [HI_YELLOW]='\e[0;93m'
  [HI_BLUE]='\e[0;94m'
  [HI_PURPLE]='\e[0;95m'
  [HI_CYAN]='\e[0;96m'
  [HI_WHITE]='\e[0;97m'

  [BG_BLACK]='\e[40m'
  [BG_RED]='\e[41m'
  [BG_GREEN]='\e[42m'
  [BG_ORANGE]='\e[43m'
  [BG_BLUE]='\e[44m'
  [BG_MAGENTA]='\e[45m'
  [BG_CYAN]='\e[46m'
  [BG_LIGHT_GRAY]='\e[47m'
  [BG_DARK_GRAY]='\e[100m'
  [BG_LIGHT_RED]='\e[101m'
  [BG_LIGHT_GREEN]='\e[102m'
  [BG_LIGHT_ORANGE]='\e[103m'
  [BG_LIGHT_BLUE]='\e[104m'
  [BG_LIGHT_MAGENTA]='\e[105m'
  [BG_LIGHT_CYAN]='\e[106m'
  [BG_WHITE]='\e[107m'
    
  # Text formatting definitions
  [BOLD]='\e[1m'
  [ITALIC]='\e[3m'
  [BOLDITALIC]='\e[3m\e[1m'
  [UNDERLINE]='\e[4m'
  [DBLUNDERLINE]='\e[21m'
  [DIM]='\e[2m'
  [INVERT]='\e[7m'
  [STRIKE]='\e[9m'
  [RESET]='\e[0m'
)


# Builds a single ANSI escape sequence by chaining multiple STYLE keys, omitting resets.
# @param {...string} args - Style keys from the STYLE map (e.g., BOLD, RED).
# @returns {string} ANSI sequence printed to stdout without newline.
# Chain styles: usage style_chain BOLD RED
# @param {...string} args - List of style keys from the STYLE associative array
style_chain() {
  local codes=()
  for style in "$@"; do
    local code="${STYLE[${style}]}"
    # Extract numeric codes from \e[XXXm format
    if [[ ${code} =~ $'\\e\\[([0-9;]+)m' ]]; then
      local extracted_codes="${match[1]}"
      # Split by semicolon and filter out reset codes (0) to avoid canceling formatting
      local -a code_parts=("${(s:;:)extracted_codes}")
      for part in "${code_parts[@]}"; do
        # Skip reset codes (0) to avoid canceling previous formatting
        if [[ ${part} != "0" ]]; then
          codes+=("${part}")
        fi
      done
    fi
  done
  # Join all codes with semicolons and create single escape sequence
  if [[ ${#codes[@]} -gt 0 ]]; then
    local combined_codes
    combined_codes=$(IFS=';'; echo "${codes[*]}")
    echo -en "\e[${combined_codes}m"
  fi
}

# Wrap text with styles: usage style_wrap BOLD RED "Hello"
# @param {...string} args - List of style keys followed by the text to style
# @returns {string} Styled string printed to stdout.
style_wrap() {
  local n=${#@}
  local styles=("${@:1:$((n-1))}")
  local text="${*[${n}]}"
  local out=""
  for style in "${styles[@]}"; do
    out+="${STYLE[${style}]}"
  done
  echo -e "${out}${text}${STYLE[RESET]}"
}

# Symbol definitions for consistent UI elements
typeset -A SYMBOL=(
  [BULLET]='•'
  [ARROW]='➔ '
  [SUCCESS]='✔'
  [DANGER]='✖'
  [WARNING]='!'
  [INFO]='ℹ'
  [QUESTION]='?'
)

# Add header styles to the STYLE array
STYLE[H1]="$(style_chain BOLD CYAN)"
STYLE[H2]="$(style_chain BOLD PURPLE)"
STYLE[H3]="$(style_chain BOLD GREEN)"
STYLE[H4]="$(style_chain BOLD YELLOW)"
STYLE[H5]="$(style_chain BOLD LIGHT_RED)"
STYLE[h6]="$(style_chain UNDERLINE GREEN)"
STYLE[H7]="$(style_chain UNDERLINE PURPLE)"
STYLE[QUOTE]="$(style_chain ITALIC CYAN)"

# Functions for headers
# @param {...string} args - Message text to display
style_h1() { style_wrap BOLD UNDERLINE PURPLE "$*"; }
style_h2() { style_wrap BOLD UNDERLINE CYAN "$*"; }
style_h3() { style_wrap BOLD YELLOW "$*"; }
style_h4() { style_wrap BOLD CYAN "$*"; }
style_h5() { style_wrap UNDERLINE GREEN "$*"; }
style_h6() { style_wrap UNDERLINE PURPLE "$*"; }
style_quote() { style_wrap ITALIC CYAN "$*"; }

# Prints a demo of all available styles for interactive shells.
style_demo() {
  echo -e "\n--- STYLES Demo ---"
  typeset -a STYLE_ORDER=(
    DEFAULT_FG BLACK RED GREEN YELLOW BLUE PURPLE CYAN WHITE
    LIGHT_BLACK LIGHT_RED LIGHT_GREEN LIGHT_YELLOW LIGHT_BLUE LIGHT_PURPLE LIGHT_CYAN LIGHT_WHITE
    HI_BLACK HI_RED HI_GREEN HI_YELLOW HI_BLUE HI_PURPLE HI_CYAN HI_WHITE
    DEFAULT_BG BG_BLACK BG_RED BG_GREEN BG_ORANGE BG_BLUE BG_MAGENTA BG_CYAN BG_LIGHT_GRAY
    BG_DARK_GRAY BG_LIGHT_RED BG_LIGHT_GREEN BG_LIGHT_ORANGE BG_LIGHT_BLUE BG_LIGHT_MAGENTA
    BG_LIGHT_CYAN BG_WHITE RESET
    BOLD ITALIC BOLDITALIC UNDERLINE DBLUNDERLINE DIM INVERT STRIKE RESET
  )

  for style in "${STYLE_ORDER[@]}"; do
    echo -e "${STYLE[${style}]}This is ${style}${STYLE[RESET]}"
  done
}

# if sourced directly from the interactive shell (not from another script), show demo
# Check if we're in an interactive shell AND this file is being sourced directly
if [[ -o interactive && ( -z "${ZSH_SCRIPT}" && -z "${BASH_SOURCE}" ) ]]; then
  style_demo
fi