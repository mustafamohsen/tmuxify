# Changelog

## [Unreleased]

### Added
- Project-root discovery bounded by conventional Git worktree markers, with an authoritative `--root DIR` override and directory completion in Bash and Zsh.
- Project-scoped default and named workspaces, deterministic readable tmux names, full session-local identity verification, and committed readiness for safe reuse.
- Public identity, concurrency/failure, and attached-client tests; real tmux 2.1 and Bash 3.2 compatibility coverage.

### Changed
- `session.name` now selects a workspace within a canonical project root, not a literal server-wide tmux name. Existing legacy sessions are left untouched; first migration can start duplicate programs, so preview and consider `--no-commands`.
- All new panes start at the resolved project root. Layout templates remain independent of root selection and are snapshotted for each invocation.
- Reuse follows full identity through manual tmux renames and never reconciles or restarts a running workspace. Collisions, ambiguous ownership, and incomplete construction fail explicitly.
- Preview/layout listing expose project context. Export preserves portable workspace selectors without embedding generated names or roots, while retaining its simplified geometry and active-focus contract.
- The integration suite owns a private tmux server instead of cleaning up sessions by a shared-server name prefix.

## [2.7.1] – 2026-09-18

### Fixed
- Fixed zsh Tab completion rejecting literal brace-wrapped option specifications. Each long and short alias now has a valid specification, preserving file completion ([#23](https://github.com/mustafamohsen/tmuxify/issues/23)).

### Tests
- Added real zsh Tab-completion coverage on Linux and macOS for option listing, prefix expansion, and spaced filenames with long and short file options.

## [2.7.0] – 2026-09-18

### Added
- Added explicit `session.pane_names.enabled: true` opt-in and optional leaf-pane `name` labels, separate from focus IDs and stable across application title updates ([#21](https://github.com/mustafamohsen/tmuxify/issues/21)). Thanks to Marco ([@fscaptain](https://github.com/fscaptain)) for the feature request.
- Added `preserve` (default), `top`, and `bottom` border modes, scoped to newly created windows with named panes. Managed borders consume terminal space; existing sessions and global settings are not modified.
- Added name validation, dry-run previews, a safe example, and focused CLI/tmux regressions for compatibility, literal rendering, nested layouts, focus, command controls, version gating, export, and rollback.

### Compatibility
- Existing layouts, ignored name fields, default workspace, and export behavior remain unchanged without the explicit opt-in. Pane naming requires tmux 3.2+ only for new opted-in workspaces; other configurations retain the tmux 2.1 and Bash 3.2 baselines.

## [2.6.1] – 2026-09-09

### Fixed
- Made the built-in four-pane workspace honor `--no-commands` and show its commands in `--dry-run`; it remains usable as a shell when Neovim is unavailable.
- Calculated pane percentages within their parent layout, including final-child sizes, omitted sizes, separator cells, and minimum dimensions. Existing YAML remains valid, but corrected sizing can change the geometry of existing layouts.
- Reused and attached only to exactly matching session names instead of accepting prefix matches.
- Cleaned temporary files before attachment and rolled back unfinished sessions on HUP, INT, and TERM. Native session IDs keep rollback tied to the owned session across renames, while completed and unrelated workspaces are preserved.
- Rejected update candidates with invalid Bash syntax or version metadata without executing them. Staged replacements preserve readable executable permissions; failed replacement restores the previous version or reports a retained recovery backup if restoration fails.
- Restored Bash 3.2 option and filename completion, including paths containing spaces, without adding dependencies.

### Tests
- Added focused public-CLI regressions for workspace construction and cleanup, offline update failures and recovery, and shell completion behavior.
- Preserved the full suite's TAP plan when discovering focused regression scripts.
- Added actual Bash 3.2 completion coverage in macOS CI and expanded ShellCheck coverage to completions and tests.
- Restricted CI to read-only repository permissions without persisting checkout credentials.

## [2.6.0] – 2026-07-23

### Added
- Added explicit one- and multi-window layout configuration with required stable window IDs, visible names, recursive layouts, declaration-order creation, and session-wide pane/window focus.
- Added a safe bundled multi-window development example and authoritative schema, command-control, migration, export, troubleshooting, and development-check documentation.

### Changed
- Expanded simplified export to enumerate every window, preserve order and visible names, generate safe unique IDs, and represent active focus while retaining atomic overwrite/symlink protections.
- Kept legacy top-level `layout` files and the no-config built-in workspace fully supported; explicit empty windows and mixed legacy/window schemas are rejected.
- Made multi-window construction transactional, native-ID based, and structure-first so custom indexes/renumbering are safe and commands run only after all windows and panes exist.

### Tests
- Added integration coverage for schema validation, legacy/one/multiple-window runtime behavior, focus, command controls, custom indexes, rollback, complete export, and bundled-example validation.
- Verified Bash syntax, ShellCheck, the full integration suite, and all-example public dry runs for release preparation.

## [2.5.6] – 2026-06-07

### Added
- Added Bash and Zsh completion scripts under `completions/`.
- Added `tmuxify --completion-options` for machine-readable option metadata used by completions and tests.
- Added `tmuxify --update` support for refreshing completions under `${XDG_CONFIG_HOME:-~/.config}/tmuxify/completions/`.

### Changed
- Documented shell completion setup for Bash and Zsh.

### Tests
- Added completion parsing checks and coverage that compares documented help flags with completion metadata to prevent drift.

## [2.5.5] – 2026-06-07

### Added
- Added `tmuxify --list-layouts` to list project, global default, and downloaded example layout files.

### Changed
- Documented the layout listing flag in the command options and safe workflow examples.

### Tests
- Added coverage for listing project and user layout files.

## [2.5.4] – 2026-06-07

### Added
- Added an XDG-compatible user config directory at `${XDG_CONFIG_HOME:-~/.config}/tmuxify`.
- Added global default layout lookup at `${XDG_CONFIG_HOME:-~/.config}/tmuxify/layouts/default.yml` when no project `.tmuxify.yml` exists.
- Added `tmuxify --update` support for creating config/layout directories and refreshing bundled examples under `layouts/examples/`.

### Changed
- Documented the new layout lookup priority and reusable user-level layout setup.

### Tests
- Added coverage for global default lookup, project and explicit-file precedence, update-time example refreshes, and pane-base-index-safe focus assertions.

## [2.5.3] – 2026-05-31

### Fixed
- Fixed `tmuxify --update` installs reporting an older version when a stale sidecar `VERSION` file is present or when the script is installed standalone.
- Updated release version detection during self-update to read the embedded script version.

### Tests
- Added coverage ensuring `tmuxify --version` reports the embedded release version even next to a stale `VERSION` file.

## [2.5.2] – 2026-05-31

### Fixed
- Fixed session creation for tmux configurations that use `base-index 1` by avoiding hard-coded window `0` targets.
- Made initial pane detection compatible with custom `pane-base-index` settings.

### Tests
- Added an isolated regression test covering `base-index 1` and `pane-base-index 1` tmux configurations.

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
