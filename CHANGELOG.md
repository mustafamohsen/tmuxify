# Changelog

## [2.5.1] – 2026-05-30

### Changed
- Refined all bundled layout examples with persona-driven feedback from developer, SRE, security, network, data, QA, and streaming workflows.
- Reorganized the examples guide by audience, trust model, readiness level, and contribution standards.

### Fixed
- Removed auto-running risky example commands such as privileged packet capture, vulnerability scans, common-router SSH, and forced sudo firewall checks.
- Replaced placeholder-heavy examples with safer, more realistic commands, environment-variable guidance, and portable fallbacks.

## [2.5.0] – 2026-05-30

### Added
- Added `--dry-run` to validate and preview layouts without creating tmux sessions.
- Added `--no-commands` to create panes without running configured pane commands.
- Added `--detach` for CI, scripts, and remote/headless workflows.
- Added CI and release smoke tests for CLI behavior, schema validation, nested layouts, initial focus, and bundled examples.

### Changed
- Made Bash the explicit runtime and removed the previous hybrid `sh`/Bash/Zsh behavior.
- Reworked layout creation to use tmux pane IDs and build sibling containers before recursing into nested layouts.
- Improved README guidance around installation, trust boundaries, safe preview, dependencies, and troubleshooting.
- Hardened update behavior by validating downloaded candidates and removing automatic sudo escalation.

### Fixed
- Fixed nested-first layouts that previously split inside the first child instead of the parent container.
- Fixed `initial_focus` reliability by replacing fragile shell-variable pane mapping with a temp-file map.
- Fixed shallow schema validation; invalid layouts now fail before session creation.
- Restored the empty `examples/layouts/server-dashboard.yml` example.
- Hardened export to avoid overwriting existing files or following symlinks.

## [2.4.1] – 2025-04-02

### Changed
- Improved clarity of `--export` flag help text regarding simplified output.
- Enhanced README with a direct link encouraging layout contributions.

### Fixed
- Ensured consistent formatting for error messages (prefixed with `❌ Error:`).

## [2.4.0] – 2025-04-02

### Added
- Support for environment variables in commands.
- Session export feature: new `--export/-e [filename]` flag to save current tmux sessions as YAML templates.
- Enhanced validation for YAML files with better error messages.
- Tmux version compatibility checking to prevent issues with older versions.

### Changed
- Improved session name sanitization warnings for both config and directory-based names.
- Better error messaging throughout for easier troubleshooting.

## [2.3.1] – 2025-04-01

### Changed
- Improved code readability by cleaning up unnecessary comments.
- Refined README layout for better clarity and professionalism.
- Added minimal but strategic comments to enhance maintainability.

## [2.3.0] – 2025-03-31

### Added
- Extra layouts organized into folders.

## [2.2.0] – 2025-03-31

### Added
- Custom layout file support with `--file/-f` flag.
- Improved argument handling with more robust validation.

## [2.1.0] – 2025-03-31

### Added
- Session detection: automatically attaches to existing sessions with matching names.
- New `--list` flag to show all active tmux sessions.
- Improved messaging to indicate whether attaching to existing or creating new session.

## [2.0.0] – 2025-03-31

### Added
- Complete redesign of layout system with tree-based structure.
- Support for unlimited panes with arbitrary nesting.
- Initial pane focus control via `initial_focus` property.
- Extensive layout examples library with various templates.
- Detailed documentation and examples for the new layout system.

### Changed
- Layout specification now uses a recursive tree structure.
- Updated `.tmuxify.yml.example` with new format.
- Improved README with comprehensive layout examples.

### Fixed
- Backward compatibility for projects without `.tmuxify.yml`.

## [1.0.0] – 2025-03-31

### Added
- Core pane layout logic with dynamic YAML or default fallback.
- Command-line flags: `--version`, `--update`, `--help`.
- Smart dynamic session names from folder path.
- Default layout with `primary`, `secondary`, `lmicro`, `rmicro`.
