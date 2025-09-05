# TODO

## High Priority Features

- [ ] **Backup/restore**: Create backups of current package states.
- [ ] **Dry run mode**: Show what would be updated without making changes.
- [ ] **Rollback capability**: Undo recent package changes (?)

- [ ] **Python system-wide package support**: Add support for pip packages.
  - [ ] **List installed packages**: Show all installed pip packages.
  - [ ] **Update packages**: Update all or specific pip packages.
  - [ ] **Install packages**: Install new pip packages from requirements.txt.

- [ ] **Interactive CLI GUI mode**:
  - [ ] **Selective updates**: Interactive mode to choose which packages to update.
  - [ ] Use `fzf` or similar for interactive package selection.
  - [ ] UI with panes for package types, details, and system info.
  - [ ] Navigate and select packages to update/install/remove.
  - [ ] Preview package details before actions.
  - [ ] Confirm selections before applying changes.
  - [ ] System info page, showing as per below metrics.

- [ ] **System Info**: Display system information relevant to package management:
  - [ ] **OS Information**: Show details about the operating system.
  - [ ] **System Architecture**: Display information about the system architecture (e.g., x86_64, arm64).
  - [ ] **Installed Package Managers**: List all available package managers.
  - [ ] **Disk Space**: Current disk space used for all + per package manager.

## Medium Priority Features

- [ ] **Performance**: Cache package information to reduce API calls (?)
- [ ] **Configuration management**: Multiple config file support (?)
- [ ] **Custom package sources**: Support for additional package managers.
- [ ] **Parallel processing**: Run multiple package managers simultaneously.
- [ ] **Update scheduling**: Cron-like scheduling for automatic updates.
- [ ] **Package name completion**: Tab complete actual package names for add/remove commands.

## Code Quality & Development

- [x] **Testing**: Add comprehensive test suite (unit, integration, e2e, config, completions).
- [x] **Linting**: Add shellcheck linting with pnpm scripts.
- [x] **Auto-fix capability**: Added automated shellcheck fix application.
- [x] **Development scripts**: Added lint helpers, auto-fix, and validation scripts.
- [ ] **CI/CD**: GitHub Actions for testing and releases.
- [ ] **Documentation**: Add JSDoc comments throughout.
- [ ] **Modularization**: Split large functions into smaller modules

## Performance & Configuration

- [ ] **Logging**: Optional detailed logging to file.
- [ ] **Configuration**: Generate JSON configuration files.

## Recently Completed ✅

- [x] **Bug: version/description/name in help**: Fix incorrect version/description/name in help output, due to CWD issue.
- [x] **Multiple package support**: Added ability to add/remove multiple packages in single commands.
- [x] **Environment variable config override**: Added MACOS_UPDATETOOL_CONFIG for safe testing.

- [x] **Comprehensive testing infrastructure**:
  - [x] BATS test framework integration.
  - [x] Unit tests for CLI, multiple packages, and core functionality.
  - [x] Integration tests for workflows and real command execution.
  - [x] End-to-end tests for complete scenarios.
  - [x] Configuration validation tests.
  - [x] Shell completion tests with syntax validation.

- [x] **Advanced linting and validation**:.
  - [x] Shellcheck integration with bash compatibility mode.
  - [x] Automated fix application with `lint:fix:patch`.
  - [x] Zsh syntax validation.
  - [x] Multiple helper scripts for linting and fixing.

- [x] **Configuration validation**: JSON schema validation with ajv.
- [x] **Documentation improvements**: Added detailed technical articles.
- [x] **Development workflow**: Added setup scripts and development helpers.

## Previously Completed ✅

- [x] Extract shared logic from list functions.
- [x] Move Xcode functions to dedicated modules.
- [x] Remove redundant wrapper functions.
- [x] Create standalone npm package.
- [x] Preserve Git history during extraction.
- [x] Add comprehensive README.
- [x] Set up proper project structure.
- [x] **Modern CLI Interface**: Implemented resource-centric syntax (`<resource-type> <command>`).
- [x] **Comprehensive argument parsing**: Centralized validation with proper error handling.
- [x] **Context-aware shell completions**: Intelligent tab completion for all commands.
- [x] **Resource-specific command support**: Different commands available per resource type.
- [x] **Smart "outdated" filtering**: Intelligent exclusion of incompatible resources.
- [x] **Help system**: Comprehensive help documentation with examples.
- [x] **Command validation**: Proper validation of command/resource combinations.
- [x] **Install/update/list separation**: Clean separation of concerns for different operations.
- [x] **All resource type**: Smart handling of bulk operations across multiple resource types.
- [x] **Configuration validation**: Added --config switch with YAML validation and status checking.
- [x] **Update notifications**: Added --version switch showing tool version, author, and website info.
- [x] **Package search**: Can search/list packages across all sources with comprehensive filtering.
- [x] **Error handling**: Significantly improved error messages with clear usage guidance and styling.
- [x] **Progress indicators**: Added detailed package counters (1/43 style) for all update/install operations.
