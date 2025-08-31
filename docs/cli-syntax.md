# `macos-updatetool` CLI Interface Reference

`macos-updatetool` command-line interface implements a consistent, resource-centric syntax argument parsing logic and command execution flow.

## Command Syntax

`macos-updatetool <resource-type> [resource-subtype] <command> [sub-command] [pkg-name]`

### 1. Resource Types (`<resource-type>`)

- `brew`: Manages Homebrew formulas and casks.
- `npm`: Manages global NPM packages.
- `appstore`: Manages Mac App Store applications.
- `xcode`: Manages updating Xcode.
- `system`: Manages macOS system updates and Xcode command-line tools.
- `all`: Represents all supported resource types.

### 2. Resource Sub-types (`[resource-subtype]`)

- Applies only to the `brew` resource type.
- Values: `casks`, `formulas` (default is to act on both).

### 3. Commands (`<command>`)

- `list`: Display packages and their current version/installation status.
- `install`: Install specified or all tracked packages.
- `update`: Update specified or all tracked packages.
- `add`: Add a package to the configuration file for tracking.
- `remove`: Remove a package from the configuration file.

### 4. Sub-Commands (`[sub-command]`)

- `outdated`: Restricts `list`, or `install` commands to only outdated `npm`, `brew`, and `appstore` packages.
- `all`: Applies the command to all tracked packages (this is the default behavior when no sub-command is specified).

### 5. Special Commands

- `help`, `--help`, `-h`: Display comprehensive help information and command syntax.
- `completions`: Generate shell completion script for installation.

## Implementation Details

- **Argument Parsing:** Centralize and rewrite the argument parsing logic in the `main` function to strictly enforce the new syntax.
- **Command & Resource Logic:**
  - The `add` and `remove` commands must apply only to `brew`, `npm`, and `appstore` resources.
  - For `brew add` or `brew remove` commands, the `<resource-subtype>` is optional and defaults to `formulas` when omitted.
    - _Examples:_ `macos-updatetool brew add git` (defaults to formulas), `macos-updatetool brew casks add visual-studio-code`
  - For `list`, `install`, and `update` commands on the `brew` resource, the `<resource-subtype>` is optional. If omitted, the command applies to both `casks` and `formulas`.
  - The `outdated` sub-command does not apply to `xcode` or `system` resources.
- **User Confirmation:** Implement a mandatory user confirmation prompt (`This updates/installs all packages in the configuration file. Are you sure? [y/N]`) before executing any `update all` or `install all` operation to prevent accidental bulk changes.
- **Error Handling:** Implement robust error handling to provide clear, informative messages for invalid syntax, unknown resources, or unsupported command/resource combinations.
- **Help Messages:** Update all help and usage documentation to accurately reflect the new command structure and options.
- **Completions:** Implement command-line completions for all resource types, commands, and sub-commands.

## Example Syntax

- `macos-updatetool brew list` - Lists all installed formulas and casks.
- `macos-updatetool brew casks list outdated` - Lists only outdated casks.
- `macos-updatetool appstore update` - Updates all App Store apps.
- `macos-updatetool system list` - Shows status of system and Xcode command-line tools.
- `macos-updatetool npm update outdated` - Updates all outdated global npm packages.
- `macos-updatetool all update` - Updates all resources, prompting for confirmation.
- `macos-updatetool all list outdated` - Lists only outdated packages from npm, brew, and appstore (excludes xcode/system).

## Shell Completions

`macos-updatetool` provides intelligent tab completion for all commands, resource types, and sub-commands when used with compatible shells.

### Installation

To enable shell completions, run:

```bash
# For zsh (add to ~/.zshrc)
eval "$(macos-updatetool completions)"

# For bash (add to ~/.bashrc or ~/.bash_profile)
eval "$(macos-updatetool completions)"
```

### Features

- **Resource Type Completion:** Tab complete `brew`, `npm`, `appstore`, `xcode`, `system`, `all`
- **Command Completion:** Tab complete `list`, `install`, `update`, `add`, `remove`
- **Sub-Command Completion:** Tab complete `outdated`, `all` where applicable
- **Brew Subtype Completion:** Tab complete `casks`, `formulas` for brew commands
- **Context-Aware:** Completions adapt based on the resource type and command being used
- **Package Name Completion:** Tab complete package names for `add` and `remove` commands

### Usage Examples

```bash
macos-updatetool <TAB>          # Shows: brew, npm, appstore, xcode, system, all
macos-updatetool brew <TAB>     # Shows: casks, formulas, list, install, update, add, remove
macos-updatetool brew list <TAB> # Shows: outdated, all
```
