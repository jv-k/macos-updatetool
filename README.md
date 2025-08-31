# macos-updatetool

A comprehensive macOS package and app management tool that automates the installation and updating of applications from multiple sources using a modern, resource-centric CLI interface.

## Features

- **Multi-source support**: Manages apps from Homebrew (formulas & casks), npm, Mac App Store, Xcode, and system updates
- **Modern CLI interface**: Resource-centric syntax with consistent command patterns
- **Status checking**: Lists all packages with clear status indicators (✔ up-to-date, ! outdated, ✖ not installed)
- **Bulk operations**: Install or update all packages at once or by category
- **YAML configuration**: Easy-to-manage app lists in `applist.yaml`
- **Rich output**: Colorful interface with spinners and progress indicators
- **Smart filtering**: Show only outdated packages with intelligent resource filtering
- **Shell completions**: Context-aware tab completion for all commands and options

## Installation

### Global Installation (Recommended)

```bash
npm install -g macos-updatetool
# or
pnpm install -g macos-updatetool
```

### Local Development

```bash
git clone https://github.com/jv-k/macos-updatetool.git
cd macos-updatetool
npm install
./bin/macos-updatetool help
```

## Prerequisites

- macOS (Darwin)
- Zsh shell
- [Homebrew](https://brew.sh/)
- [mas-cli](https://github.com/mas-cli/mas) (`brew install mas`)
- [Node.js & npm](https://nodejs.org/)
- [yq](https://github.com/mikefarah/yq) (`brew install yq`)

## Configuration

Create or customize `config/applist.yaml` to define which packages to manage:

```yaml
appstore_apps:
  - '497799835' # Xcode
  - '1295203466' # Microsoft Remote Desktop

npm_apps:
  - '@vue/cli'
  - 'typescript'
  - 'eslint'

brew_formulas:
  - 'git'
  - 'node'
  - 'python'

brew_casks:
  - 'visual-studio-code'
  - 'docker'
  - 'firefox'
```

## CLI Syntax

`macos-updatetool <resource-type> [resource-subtype] <command> [sub-command] [pkg-name]`

### Resource Types

- `brew`: Manages Homebrew formulas and casks
- `npm`: Manages global NPM packages
- `appstore`: Manages Mac App Store applications
- `xcode`: Manages updating Xcode
- `system`: Manages macOS system updates and Xcode command-line tools
- `all`: Represents all supported resource types

### Commands

- `list`: Display packages and their current version/installation status
- `install`: Install specified or all tracked packages
- `update`: Update specified or all tracked packages
- `add`: Add a package to the configuration file for tracking (brew, npm, appstore only)
- `remove`: Remove a package from the configuration file (brew, npm, appstore only)

### Sub-Commands

- `outdated`: Restricts list/install commands to only outdated packages (npm, brew, appstore only)
- `all`: Applies the command to all tracked packages (default behavior)

## Usage Examples

### List Commands

```bash
# List all packages with status
macos-updatetool all list

# List specific package types
macos-updatetool npm list
macos-updatetool brew list
macos-updatetool brew formulas list
macos-updatetool brew casks list
macos-updatetool appstore list
macos-updatetool xcode list
macos-updatetool system list

# Show only outdated packages
macos-updatetool all list outdated
macos-updatetool npm list outdated
macos-updatetool brew list outdated
macos-updatetool brew casks list outdated
```

### Update Commands

```bash
# Update everything
macos-updatetool all update

# Update specific package types
macos-updatetool npm update
macos-updatetool brew update
macos-updatetool brew formulas update
macos-updatetool brew casks update
macos-updatetool appstore update
macos-updatetool xcode update
macos-updatetool system update

# Update only outdated packages
macos-updatetool npm update outdated
macos-updatetool brew update outdated
```

### Install Commands

```bash
# Install everything
macos-updatetool all install

# Install specific package types
macos-updatetool npm install
macos-updatetool brew install
macos-updatetool brew formulas install
macos-updatetool brew casks install
macos-updatetool appstore install
macos-updatetool xcode install
macos-updatetool system install
```

### Package Management

````bash
# Add packages to configuration
macos-updatetool npm add typescript
macos-updatetool brew add git
macos-updatetool brew formulas add node
macos-updatetool brew casks add visual-studio-code
macos-updatetool appstore add 497799835

# Remove packages from configuration
macos-updatetool npm remove old-package
macos-updatetool brew remove unwanted-formula
macos-updatetool brew casks remove old-app

## Status Indicators

- ✔ **Up-to-date**: Package is installed and current
- ! **Outdated**: Package is installed but has updates available
- ✖ **Not installed**: Package is defined but not installed

## Shell Completions

Enable intelligent tab completion for Zsh:

```bash
# Add to ~/.zshrc
eval "$(macos-updatetool completions)"

# Then reload your shell
source ~/.zshrc
````

### Completion Features

- **Resource Type Completion**: Tab complete `brew`, `npm`, `appstore`, `xcode`, `system`, `all`
- **Command Completion**: Tab complete `list`, `install`, `update`, `add`, `remove` (context-aware)
- **Sub-Command Completion**: Tab complete `outdated`, `all` where applicable
- **Brew Subtype Completion**: Tab complete `casks`, `formulas` for brew commands

## Help and Documentation

```bash
# Show comprehensive help
macos-updatetool help
macos-updatetool --help
macos-updatetool -h

# Generate shell completions
macos-updatetool completions
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details.

## Author

**John Valai** - [git@jvk.to](mailto:git@jvk.to)

## Acknowledgments

- Built for macOS power users who want automated package management
- Inspired by the need for a unified tool across multiple package managers
- Thanks to the maintainers of Homebrew, mas-cli, and other dependencies
