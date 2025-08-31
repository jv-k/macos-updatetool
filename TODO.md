# TODO

## Features to Add

- [ ] **Configuration validation**: Validate applist.yaml schema on startup
- [ ] **Backup/restore**: Create backups of current package states
- [ ] **Selective updates**: Interactive mode to choose which packages to update
- [ ] **Update notifications**: Check for tool updates
- [ ] **Parallel processing**: Run multiple package managers simultaneously
- [ ] **Dry run mode**: Show what would be updated without making changes
- [ ] **Custom package sources**: Support for additional package managers
- [ ] **Package search**: Search for packages across all sources
- [ ] **Update scheduling**: Cron-like scheduling for automatic updates
- [ ] **Rollback capability**: Undo recent package changes

## Improvements

- [ ] **Performance**: Cache package information to reduce API calls
- [ ] **Error handling**: Better error messages and recovery
- [ ] **Logging**: Optional detailed logging to file
- [ ] **Progress indicators**: More detailed progress for long operations
- [ ] **Configuration management**: Multiple config file support
- [ ] **Package grouping**: Organize packages into custom groups
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
