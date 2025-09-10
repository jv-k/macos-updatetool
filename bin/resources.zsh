#!/bin/zsh

# Resources module
#
# Purpose:
# - Define and manage all resource type configurations for the macOS update tool.
# - Provide centralized data structures for resource metadata, command mappings, and help content.
# - Establish the canonical definitions that drive dynamic help generation and validation logic.
#
# Responsibilities:
# - Define resource types with descriptions and capabilities.
# - Map commands to compatible resource types with detailed command descriptions.
# - Specify sub-command availability and restrictions per resource type.
# - Provide usage examples and help text templates for dynamic help generation.
# - Define applist.yaml configuration structure and key mappings.
# - Supply package requirement information and installation guidance.
#
# Data Structures:
# - RESOURCE_* arrays: Core resource type definitions, descriptions, and ordering
# - COMMAND_* arrays: Command definitions, descriptions, and resource-specific details
# - RESOURCE_COMMANDS/SUB_COMMANDS: Mapping of available commands and sub-commands per resource
# - USAGE_EXAMPLES: Template-based examples for help system and contextual guidance
# - APPLIST_* arrays: Configuration file structure and key descriptions
# - HELP_* arrays: Extended help system configuration for comprehensive documentation
#
# Notes:
# - Resource ordering in RESOURCE_ORDER determines display sequence in help and operations
# - Command compatibility is enforced through RESOURCE_COMMANDS mappings
# - Example templates use {TOOLNAME} placeholder for dynamic tool name substitution
#
# Author: John Valai <git@jvk.to>
# License: MIT License

# shellcheck disable=SC2034  # These arrays are used by other modules

# Constants for application-specific identifiers
# Used by package management functions to identify specific applications
readonly XCODE_APP_ID="497799835"  # Mac App Store ID for Xcode

# Core resource type definitions
# Primary resource descriptions used in general help and validation
# Each resource represents a different package management system or update mechanism
typeset -A RESOURCE_DESCRIPTIONS=(
  [brew]="Manages Homebrew formulas and casks."
  [npm]="Manages global NPM packages."
  [appstore]="Manages Mac App Store applications."
  [xcode]="Manages updating Xcode."
  [system]="Manages macOS system updates and Xcode command-line tools."
  [all]="Represents all supported resource types."
)

# Detailed resource descriptions for comprehensive help display
# Provides more context about what each resource type encompasses
typeset -A RESOURCE_DETAILS=(
  [brew]="Command-line tools and GUI applications via Homebrew package manager."
  [npm]="Global Node.js packages installed via npm."
  [appstore]="Applications from the Mac App Store using mas-cli."
  [xcode]="Apple's integrated development environment."
  [system]="System software updates and development tools."
  [all]="Performs operations across all resource types simultaneously."
)

# Command definitions and descriptions
# Defines the core operations available in the tool
typeset -A COMMAND_DESCRIPTIONS=(
  [list]="Display packages and their current version/installation status."
  [install]="Install all tracked packages."
  [update]="Update all tracked packages."
  [add]="Add one or more packages to the configuration file for tracking."
  [remove]="Remove one or more packages from the configuration file."
)

# Resource-specific command details for contextual help
# Provides tailored descriptions based on resource-command combinations
# Format: [command_resource] for specific resource context
typeset -A COMMAND_DETAILS=(
  [list_brew]="Display formulas and casks with status"
  [install_brew]="Install tracked formulas and casks"
  [update_brew]="Update tracked formulas and casks"
  [add_brew]="Add packages to configuration"
  [remove_brew]="Remove packages from configuration"
  [list_npm]="Display packages with status"
  [install_npm]="Install tracked packages"
  [update_npm]="Update tracked packages"
  [add_npm]="Add packages to configuration"
  [remove_npm]="Remove packages from configuration"
  [list_appstore]="Display packages with status"
  [install_appstore]="Install tracked packages"
  [update_appstore]="Update tracked packages"
  [add_appstore]="Add packages to configuration"
  [remove_appstore]="Remove packages from configuration"
  [list_xcode]="Display status"
  [install_xcode]="Install if not present"
  [update_xcode]="Update to latest version"
  [list_system]="Display status"
  [install_system]="Install if not present"
  [update_system]="Update to latest version"
  [list_all]="Display all packages with status"
  [install_all]="Install all tracked packages"
  [update_all]="Update all tracked packages"
)

# Sub-command definitions and behaviors
# Describes how sub-commands modify the behavior of main commands
typeset -A SUB_COMMAND_DESCRIPTIONS=(
  [outdated]="Restricts list, or install commands to only outdated npm, brew, and appstore packages."
  [all]="Applies the command to all tracked packages (this is the default behavior when no sub-command is specified)."
)

# Package-specific requirements and formatting notes
# Provides guidance on how to specify package names for each resource type
# Format uses | as separator for multiple requirement lines
typeset -A PACKAGE_REQUIREMENTS=(
  [brew]="• Formula names are usually lowercase with hyphens|• Cask names may differ from the application name"
  [npm]="• Scoped packages (e.g., @types/node) are supported"
  [appstore]="• App Store apps should be quoted if they contain spaces"
)

# Resource-command compatibility matrix
# Defines which commands are available for each resource type
# Used for validation and help generation
typeset -A RESOURCE_COMMANDS=(
  [brew]="list install update add remove"
  [npm]="list install update add remove"
  [appstore]="list install update add remove"
  [xcode]="list install update"
  [system]="list install update"
  [all]="list install update"
)

# Resource sub-command availability
# Maps which sub-commands are supported by each resource type
# Empty string indicates no sub-commands available
typeset -A RESOURCE_SUB_COMMANDS=(
  [brew]="outdated all"
  [npm]="outdated all"
  [appstore]="outdated all"
  [xcode]=""
  [system]=""
  [all]="outdated all"
)

# Usage examples with dynamic tool name substitution
# Template-based examples for help system and contextual guidance
# Format: command||description separated by !! for multiple examples
# {TOOLNAME} placeholder is replaced with actual tool name at runtime
typeset -A USAGE_EXAMPLES=(
  [brew]="{TOOLNAME} brew list||Show all formulas and casks!!{TOOLNAME} brew list outdated||Show only outdated packages!!{TOOLNAME} brew formulas list||Show only formulas!!{TOOLNAME} brew casks list||Show only casks!!{TOOLNAME} brew add git curl||Add multiple formulas!!{TOOLNAME} brew casks add visual-studio-code||Add a cask!!{TOOLNAME} brew remove old-package||Remove a formula!!{TOOLNAME} brew update||Update all brew packages"
  [npm]="{TOOLNAME} npm list||Show all npm packages!!{TOOLNAME} npm list outdated||Show only outdated packages!!{TOOLNAME} npm add typescript eslint||Add multiple packages!!{TOOLNAME} npm add @types/node||Add scoped package!!{TOOLNAME} npm remove old-package||Remove a package!!{TOOLNAME} npm update||Update all npm packages!!{TOOLNAME} npm update outdated||Update only outdated packages"
  [appstore]="{TOOLNAME} appstore list||Show all App Store apps!!{TOOLNAME} appstore list outdated||Show only outdated apps!!{TOOLNAME} appstore add \"Xcode\"||Add a single app (quoted)!!{TOOLNAME} appstore add \"Logic Pro\" \"Final Cut Pro\"||Add multiple apps!!{TOOLNAME} appstore remove \"Old App\"||Remove an app!!{TOOLNAME} appstore update||Update all apps!!{TOOLNAME} appstore update outdated||Update only outdated apps"
  [xcode]="{TOOLNAME} xcode list||Show Xcode status!!{TOOLNAME} xcode install||Install Xcode!!{TOOLNAME} xcode update||Update Xcode to latest version"
  [system]="{TOOLNAME} system list||Show Command Line Tools status!!{TOOLNAME} system install||Install Command Line Tools!!{TOOLNAME} system update||Update Command Line Tools"
  [all]="{TOOLNAME} all list||Show all packages status!!{TOOLNAME} all list outdated||Show only outdated packages!!{TOOLNAME} all install||Install all packages!!{TOOLNAME} all update||Update all packages!!{TOOLNAME} all update outdated||Update only outdated packages"
  [general]="{TOOLNAME} brew list||Lists all installed formulas and casks!!{TOOLNAME} brew casks list outdated||Lists only outdated casks!!{TOOLNAME} appstore update||Updates all App Store apps!!{TOOLNAME} system list||Shows status of system and Xcode command-line tools!!{TOOLNAME} npm update outdated||Updates all outdated global npm packages!!{TOOLNAME} all update||Updates all resources, prompting for confirmation!!{TOOLNAME} all list outdated||Lists only outdated packages from npm, brew, and appstore!!{TOOLNAME} brew add git curl jq||Adds multiple formulas to configuration!!{TOOLNAME} npm add typescript nodemon||Adds multiple npm packages to configuration"
)

# Applist configuration file structure definitions
# Maps resource types to their corresponding YAML keys in applist.yaml
# Used by applist management functions for key lookups and validation
typeset -A APPLIST_REQUIRED_KEYS=(
  [appstore]="appstore_apps"
  [npm]="npm_apps" 
  [brew_formulas]="brew_formulas"
  [brew_casks]="brew_casks"
)

# Ordered sequence of applist keys for consistent processing
# Defines the order in which keys appear in generated configuration files
typeset -a APPLIST_KEYS_ORDER=(appstore_apps npm_apps brew_formulas brew_casks)

# Human-readable descriptions for applist configuration keys
# Used in help generation and configuration file comments
typeset -A APPLIST_KEY_DESCRIPTIONS=(
  [appstore_apps]="Mac App Store applications (use app names as they appear in the store)"
  [npm_apps]="Global npm packages" 
  [brew_formulas]="Homebrew formulas (command-line tools)"
  [brew_casks]="Homebrew casks (GUI applications)"
)

# Global ordering arrays for consistent iteration and display
# These arrays determine the sequence in which resources and commands appear in help and operations
typeset -a RESOURCE_ORDER=(brew npm appstore xcode system all)
typeset -a COMMAND_ORDER=(list install update add remove)

# Extended help system configuration
# These arrays support comprehensive help generation with additional resource types and commands
# Used for future extensibility and enhanced help documentation

# Enhanced resource descriptions for comprehensive help system
declare -gA HELP_RESOURCE_DESCRIPTIONS=(
    [help]="Show contextual help"
    [brew]="Homebrew packages (formulae and casks)"
    [mas]="Mac App Store applications"
    [npm]="Node.js packages"
    [xcode]="Xcode and command line tools"
    [applist]="Application configuration file management"
    [config]="Configuration and system checks"
)

# Detailed help resource descriptions with operational context
declare -gA HELP_RESOURCE_DETAILS=(
    [help]="Show contextual help information for commands and resources"
    [brew]="Manage Homebrew formulae and casks (includes both packages and applications)"
    [mas]="Manage Mac App Store applications using mas-cli"
    [npm]="Manage global Node.js packages"
    [xcode]="Manage Xcode applications and command line tools"
    [applist]="Create and manage application configuration files (applist.yaml)"
    [config]="Show configuration, check system requirements, and validate setup"
)

# Resource display order for help system
declare -ga HELP_RESOURCE_ORDER=(
    help
    brew
    mas
    npm
    xcode
    applist
    config
)

# Extended command descriptions for comprehensive help
# Supports additional commands beyond the core set for future extensibility
declare -gA HELP_COMMAND_DESCRIPTIONS=(
    [list]="List installed packages or applications"
    [update]="Update package indices and check for updates"
    [install]="Install new packages or applications"
    [search]="Search for packages or applications"
    [upgrade]="Upgrade installed packages or applications"
    [backup]="Backup current package lists to applist.yaml"
    [restore]="Restore packages from applist.yaml"
    [uninstall]="Remove installed packages or applications"
    [check]="Check system requirements and configuration"
    [create]="Create new applist.yaml configuration"
    [validate]="Validate applist.yaml file"
    [show]="Display configuration or system information"
)

# Command display order for help system
declare -ga HELP_COMMAND_ORDER=(
    list
    update
    install
    search
    upgrade
    backup
    restore
    uninstall
    check
    create
    validate
    show
)

# Extended resource-command mappings for help system
# Supports additional resources and commands for comprehensive documentation
declare -gA RESOURCE_COMMANDS=(
    [brew]="list update install add remove"
    [mas]="list update install add remove"
    [npm]="list update install add remove"
    [xcode]="list update install"
    [applist]="create validate backup restore show"
    [config]="check show"
)

# Extended sub-command configurations for help system
# Supports additional sub-commands and operational modes
declare -gA RESOURCE_SUB_COMMANDS=(
    [applist]="interactive silent force"
    [backup]="interactive silent"
)

# Extended sub-command descriptions including operational modes
declare -gA SUB_COMMAND_DESCRIPTIONS=(
    [interactive]="Interactive mode with prompts"
    [silent]="Silent mode without prompts"
    [force]="Force operation without confirmation"
    [dry-run]="Show what would be done without executing"
)

# Extended package requirements with installation guidance
# Provides comprehensive dependency information and installation commands
declare -gA PACKAGE_REQUIREMENTS=(
    [brew]="Requires: Homebrew to be installed|Install via: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    [mas]="Requires: mas-cli to be installed|Install via: brew install mas"
    [npm]="Requires: Node.js and npm to be installed|Install via: brew install node"
    [xcode]="Requires: Xcode or Command Line Tools|Install via: xcode-select --install"
)