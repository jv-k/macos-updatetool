#!/bin/zsh

# Terminal styling definitions for macos-updatetool
#
# This file contains ANSI color codes, text formatting, and symbol definitions
# for consistent styling across the macos-updatetool utility.
#
# Author: John Valai <git@jvk.to>
# License: MIT License

# Extended color definitions based on ANSI codes
typeset -A COLORS=(
    [DEFAULT_FG]='\e[39m'
    [BLACK]='\e[30m'
    [RED]='\e[31m'
    [GREEN]='\e[32m'
    [YELLOW]='\e[33m'
    [BLUE]='\e[34m'
    [MAGENTA]='\e[35m'
    [CYAN]='\e[36m'
    [LIGHT_GRAY]='\e[37m'
    [DARK_GRAY]='\e[90m'
    [LIGHT_RED]='\e[91m'
    [LIGHT_GREEN]='\e[92m'
    [LIGHT_YELLOW]='\e[93m'
    [LIGHT_BLUE]='\e[94m'
    [LIGHT_MAGENTA]='\e[95m'
    [LIGHT_CYAN]='\e[96m'
    [WHITE]='\e[97m'
    
    [DEFAULT_BG]='\e[49m'
    [BG_BLACK]='\e[40m'
    [BG_RED]='\e[41m'
    [BG_GREEN]='\e[42m'
    [BG_YELLOW]='\e[43m'
    [BG_BLUE]='\e[44m'
    [BG_MAGENTA]='\e[45m'
    [BG_CYAN]='\e[46m'
    [BG_LIGHT_GRAY]='\e[47m'
    [BG_DARK_GRAY]='\e[100m'
    [BG_LIGHT_RED]='\e[101m'
    [BG_LIGHT_GREEN]='\e[102m'
    [BG_LIGHT_YELLOW]='\e[103m'
    [BG_LIGHT_BLUE]='\e[104m'
    [BG_LIGHT_MAGENTA]='\e[105m'
    [BG_LIGHT_CYAN]='\e[106m'
    [BG_WHITE]='\e[107m'
    
    [RESET]='\e[0m'
)

# Text formatting definitions
typeset -A TEXT=(
  [UNDERLINE]='\e[4m'
  [ITALIC]='\e[3m'
  [BOLD]='\e[1m'
  [HIGHLIGHT]='\e[7m'
  [RESET]='\e[0m'
  [INVERT]="\e[7m"
)

# Symbol definitions for consistent UI elements
typeset -A SYMBOLS=(
  [BULLET]='•'
  [ARROW]='➔ '
  [SUCCESS]='✔'
  [DANGER]='✖'
  [WARNING]='!'
  [INFO]='ℹ'
  [QUESTION]='?'
)
