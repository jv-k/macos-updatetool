# TODO

## High Priority Features

- [ ] **Backup/restore**: Create backups of current package states
- [ ] **Selective updates**: Interactive mode to choose which packages to update
- [ ] **Dry run mode**: Show what would be updated without making changes
- [ ] **Rollback capability**: Undo recent package changes
- [ ] **Python system-wide package support**: Add support for pip packages
  - [ ] **List installed packages**: Show all installed pip packages
  - [ ] **Update packages**: Update all or specific pip packages
  - [ ] **Install packages**: Install new pip packages from requirements.txt

## Medium Priority Features

- [ ] **Performance**: Cache package information to reduce API calls
- [ ] **Configuration management**: Multiple config file support
- [ ] **Custom package sources**: Support for additional package managers
- [ ] **Parallel processing**: Run multiple package managers simultaneously
- [ ] **Update scheduling**: Cron-like scheduling for automatic updates
- [ ] **Package name completion**: Tab complete actual package names for add/remove commands

## Code Quality & Development

- [ ] **Testing**: Add unit tests for all functions
- [x] **Linting**: Add shellcheck linting with pnpm scripts
- [x] **Auto-fix capability**: Added automated shellcheck fix application
- [x] **Development scripts**: Added lint helpers, auto-fix, and validation scripts
- [ ] **CI/CD**: GitHub Actions for testing and releases
- [ ] **Documentation**: Add JSDoc comments throughout
- [ ] **Modularization**: Split large functions into smaller modules

## Performance & Configuration

- [ ] **Logging**: Optional detailed logging to file

## Platform Support

- [ ] **Linux support**: Extend to support Linux package managers
- [ ] **Windows support**: Add support for Windows package managers
- [ ] **Cross-platform config**: Unified config format across platforms

## Recently Completed ✅

- [x] **Multiple package support**: Added ability to add/remove multiple packages in single commands
- [x] **Advanced linting and validation**:
  - [x] Shellcheck integration with bash compatibility mode
  - [x] Automated fix application with `lint:fix:patch`
  - [x] Zsh syntax validation
  - [x] Multiple helper scripts for linting and fixing
- [x] **Configuration validation**: JSON schema validation with ajv
- [x] **Documentation improvements**: Added detailed technical articles
- [x] **Development workflow**: Added setup scripts and development helpers

## Previously Completed

- [x] Extract shared logic from list functions
- [x] Move Xcode functions to dedicated modules
- [x] Remove redundant wrapper functions
- [x] Create standalone npm package
- [x] Preserve Git history during extraction
- [x] Add comprehensive README
- [x] Set up proper project structure
- [x] **Modern CLI Interface**: Implemented resource-centric syntax (`<resource-type> <command>`)
- [x] **Comprehensive argument parsing**: Centralized validation with proper error handling
- [x] **Context-aware shell completions**: Intelligent tab completion for all commands
- [x] **Resource-specific command support**: Different commands available per resource type
- [x] **Smart "outdated" filtering**: Intelligent exclusion of incompatible resources
- [x] **Help system**: Comprehensive help documentation with examples
- [x] **Command validation**: Proper validation of command/resource combinations
- [x] **Install/update/list separation**: Clean separation of concerns for different operations
- [x] **All resource type**: Smart handling of bulk operations across multiple resource types
- [x] **Configuration validation**: Added --config switch with YAML validation and status checking
- [x] **Update notifications**: Added --version switch showing tool version, author, and website info
- [x] **Package search**: Can search/list packages across all sources with comprehensive filtering
- [x] **Error handling**: Significantly improved error messages with clear usage guidance and styling
- [x] **Progress indicators**: Added detailed package counters (1/43 style) for all update/install operations
