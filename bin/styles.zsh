#!/bin/zsh

# Terminal styling definitions
#
# This file contains ANSI color codes, text formatting, and symbol definitions
# for consistent styling across the macos-updatetool utility.
#
# Author: John Valai <git@jvk.to>
# License: MIT License

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
      local -a code_parts=(${(s:;:)extracted_codes})
      for part in "${code_parts[@]}"; do
        # Skip reset codes (0) to avoid canceling previous formatting
        if [[ ${part} != "0" ]]; then
          codes+=(${part})
        fi
      done
    fi
  done
  # Join all codes with semicolons and create single escape sequence
  if [[ ${#codes[@]} -gt 0 ]]; then
    local combined_codes=$(IFS=';'; echo "${codes[*]}")
    echo -en "\e[${combined_codes}m"
  fi
}

# Wrap text with styles: usage style_wrap BOLD RED "Hello"
# @param {...string} args - List of style keys followed by the text to style
# @param {string} text - The text to apply the styles to
style_wrap() {
  local n=${#@}
  local styles=("${@:1:$((n-1))}")
  local text="${@[${n}]}"
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

# Demo
style_demo() {
  echo "\n--- STYLES Demo ---"
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

# if sourced from the interactive shell, show demo
[[ -o interactive ]] && style_demo