# Development

Tmuxify is a single Bash script plus examples, completions, tests, and documentation.

## Repository map

- `tmuxify` - main CLI script.
- `tests/run.sh` - shell test suite.
- `examples/layouts/` - bundled layout examples.
- `completions/` - shell completion files.
- `doc/` - documentation.
- `README.md` - project overview.
- `CHANGELOG.md` and `VERSION` - release metadata.

## Local checks

Run the syntax check first:

```bash
bash -n tmuxify
```

Run tests when local dependencies are available:

```bash
tests/run.sh
```

The script itself needs Bash, tmux, and Mike Farah `yq` v4. Some tests may stub dependencies, but installing the real tools is best for end-to-end checks.

## Manual layout validation

Validate examples with dry runs:

```bash
tmuxify --dry-run --file examples/layouts/basic-2-pane.yml
tmuxify --dry-run --file examples/layouts/nested-dev.yml
```

For command safety testing:

```bash
tmuxify --no-commands --file examples/layouts/basic-3-pane.yml
```

## Contribution guidelines

When changing the CLI:

- Keep Bash portable; macOS ships older Bash versions.
- Quote paths and user-provided values.
- Validate before creating tmux sessions where possible.
- Prefer clear errors over silent fallbacks.
- Keep command execution explicit and previewable.

When adding examples:

- Use meaningful pane IDs.
- Include `session.initial_focus` when useful.
- Avoid secrets and hardcoded private infrastructure.
- Prefer guarded commands with safe fallbacks.
- Confirm `tmuxify --dry-run --file <example>` succeeds.

When editing docs:

- Use relative links.
- Keep the docs folder named `doc/`.
- Keep pages concise and task-oriented.
