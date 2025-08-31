# TODO

## Features to Add

- [ ] **Backup/restore**: Create backups of current package states
- [ ] **Selective updates**: Interactive mode to choose which packages to update
- [ ] **Parallel processing**: Run multiple package managers simultaneously
- [ ] **Dry run mode**: Show what would be updated without making changes
- [ ] **Custom package sources**: Support for additional package managers
- [ ] **Update scheduling**: Cron-like scheduling for automatic updates
- [ ] **Rollback capability**: Undo recent package changes
- [ ] **Python system-wide package support**: Add support for pip packages
  - [ ] **List installed packages**: Show all installed pip packages
  - [ ] **Update packages**: Update all or specific pip packages
  - [ ] **Install packages**: Install new pip packages from requirements.txt

## Improvements

- [ ] **Performance**: Cache package information to reduce API calls
- [ ] **Logging**: Optional detailed logging to file
- [ ] **Configuration management**: Multiple config file support
- [ ] **Dependency resolution**: Handle package dependencies intelligently
- [ ] **Package name completion**: Tab complete actual package names for add/remove commands

## Code Quality

- [ ] **Testing**: Add unit tests for all functions
- [ ] **Documentation**: Add JSDoc comments throughout
- [ ] **Linting**: Add shellcheck and other linters
- [ ] **CI/CD**: GitHub Actions for testing and releases
- [ ] **Modularization**: Split large functions into smaller modules

## Platform Support

- [ ] **Linux support**: Extend to support Linux package managers
- [ ] **Windows support**: Add support for Windows package managers
- [ ] **Cross-platform config**: Unified config format across platforms

## Completed

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
- [x] **Package grouping**: Organized packages by resource types with proper categorization
