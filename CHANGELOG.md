# Changelog

## [2.4.1] – 2025-04-02

### Changed
- Improved clarity of `--export` flag help text regarding simplified output.
- Enhanced README with a direct link encouraging layout contributions.

### Fixed
- Ensured consistent formatting for error messages (prefixed with `❌ Error:`).

## [2.4.0] – 2025-04-02

### Added
- Support for environment variables in commands: `command: "$EDITOR ."` now expands shell variables
- Session export feature: new `--export/-e [filename]` flag to save current tmux sessions as YAML templates
- Enhanced validation for YAML files with better error messages
- Tmux version compatibility checking to prevent issues with older versions

### Changed
- Improved session name sanitization warnings for both config and directory-based names
- Better error messaging throughout for easier troubleshooting

## [2.3.1] – 2025-04-01

### Changed
- Improved code readability by cleaning up unnecessary comments
- Refined README layout for better clarity and professionalism
- Added minimal but strategic comments to enhance maintainability

## [2.3.0] – 2025-03-31

### Added
- Extra layouts organized into folders

## [2.2.0] – 2025-03-31

### Added
- Custom layout file support with `--file/-f` flag
- Improved argument handling with more robust validation

## [2.1.0] – 2025-03-31

### Added
- Session detection: Automatically attaches to existing sessions with matching names
- New `--list` flag to show all active tmux sessions
- Improved messaging to indicate whether attaching to existing or creating new session

## [2.0.0] – 2025-03-31

### Added
- Complete redesign of layout system with tree-based structure
- Support for unlimited panes with arbitrary nesting
- Initial pane focus control via `initial_focus` property
- Extensive layout examples library with various templates
- Detailed documentation and examples for the new layout system

### Changed
- Layout specification now uses a recursive tree structure
- Updated `.tmuxify.yml.example` with new format
- Improved README with comprehensive layout examples

### Fixed
- Backward compatibility for projects without `.tmuxify.yml`

## [1.0.0] – 2025-03-31

### Added
- Core pane layout logic with dynamic YAML or default fallback
- Command-line flags: `--version`, `--update`, `--help`
- Smart dynamic session names from folder path
- Default layout with `primary`, `secondary`, `lmicro`, `rmicro`# Changelog

## [2.4.1] – 2024-07-29

### Changed
- Improved clarity of `--export` flag help text regarding simplified output.
- Enhanced README with a direct link encouraging layout contributions.

### Fixed
- Ensured consistent formatting for error messages (prefixed with `❌ Error:`).

## [2.4.0] – 2025-04-02

### Added
- Support for environment variables in commands: `command: "$EDITOR ."` now expands shell variables
- Session export feature: new `--export/-e [filename]` flag to save current tmux sessions as YAML templates
- Enhanced validation for YAML files with better error messages
- Tmux version compatibility checking to prevent issues with older versions

### Changed
- Improved session name sanitization warnings for both config and directory-based names
- Better error messaging throughout for easier troubleshooting

## [2.3.1] – 2025-04-01

### Changed
- Improved code readability by cleaning up unnecessary comments
- Refined README layout for better clarity and professionalism
- Added minimal but strategic comments to enhance maintainability

## [2.3.0] – 2025-03-31

### Added
- Extra layouts organized into folders

## [2.2.0] – 2025-03-31

### Added
- Custom layout file support with `--file/-f` flag
- Improved argument handling with more robust validation

## [2.1.0] – 2025-03-31

### Added
- Session detection: Automatically attaches to existing sessions with matching names
- New `--list` flag to show all active tmux sessions
- Improved messaging to indicate whether attaching to existing or creating new session

## [2.0.0] – 2025-03-31

### Added
- Complete redesign of layout system with tree-based structure
- Support for unlimited panes with arbitrary nesting
- Initial pane focus control via `initial_focus` property
- Extensive layout examples library with various templates
- Detailed documentation and examples for the new layout system

### Changed
- Layout specification now uses a recursive tree structure
- Updated `.tmuxify.yml.example` with new format
- Improved README with comprehensive layout examples

### Fixed
- Backward compatibility for projects without `.tmuxify.yml`

## [1.0.0] – 2025-03-31

### Added
- Core pane layout logic with dynamic YAML or default fallback
- Command-line flags: `--version`, `--update`, `--help`
- Smart dynamic session names from folder path
- Default layout with `primary`, `secondary`, `lmicro`, `rmicro`

