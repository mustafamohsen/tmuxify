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

## Design references

- [Domain glossary](../CONTEXT.md) - terminology for project-aware workspaces.
- [Project identity implementation plan](plans/project-identity.md) - design decisions, root/naming contract, migration, and validation matrix.

## Local checks

Run the syntax check first:

```bash
bash -n tmuxify
```

Run static analysis and the full integration suite when local dependencies are available:

```bash
shellcheck tmuxify completions/tmuxify.bash tests/*.sh
bash tests/run.sh
```

ShellCheck should pass without behavior-changing rewrites. If a deliberate `bash -c` string must defer expansion to the child shell, use the narrowest inline suppression and document why rather than broad suppression.

Focused regression scripts named `tests/*-test.sh` can also be run individually; the full suite discovers them automatically. Completion behavior is tested on current Bash and on the advertised Bash 3.2 baseline in macOS CI. On macOS, run `/bin/bash tests/completion-test.sh` to check the system Bash directly; completion tests need neither tmux nor yq. Real zsh Tab completion is covered by `bash tests/zsh-completion-test.sh`, using zsh and Python 3 with an isolated pseudo-terminal. CI runs this on Linux and macOS; locally it skips when zsh is unavailable.

The script itself needs Bash, tmux, and Mike Farah `yq` v4. The pane-name tests additionally need tmux 3.2+ and Python 3 (standard library only) to verify literal border rendering through a real attached pseudo-terminal. Python is a test dependency, not a tmuxify runtime dependency. Some tests may stub dependencies, but installing the real tools is best for end-to-end checks.

Run `TMUXIFY_BASH=/bin/bash /bin/bash tests/pane-names-test.sh` on macOS to check the feature against Bash 3.2. CI exercises both completion and pane names on that baseline.

## Project identity checks

The public CLI and observable tmux state remain the test seam. `tests/project-identity-test.sh` covers discovery, selectors, verified reuse, collisions, migration, and portable exports. `tests/identity-lifecycle-test.sh` injects tmux failures and coordinates concurrent launchers to verify ownership and readiness. `tests/identity-attach-test.sh` uses Python's standard-library pseudo-terminal support for real CLI attachment/client switching.

Every runtime suite uses its own HOME/configuration and private tmux server. Do not simulate an attached environment with an invalid `TMUX` value: use that private server's actual socket. Tests query full metadata/native IDs instead of duplicating the production naming algorithm or assuming YAML names are concrete session names.

Run focused suites while changing behavior. CI additionally builds checksum-pinned tmux 2.1 and runs these three identity suites against it; macOS CI runs them with actual Bash 3.2. Preserve both baselines. An oldest-version string stub is not a substitute for this runtime coverage.

## Manual layout validation

Validate every bundled example with public dry runs:

```bash
while IFS= read -r example; do
  tmuxify --dry-run --file "$example"
done < <(find examples/layouts -type f -name '*.yml' -print | sort)
```

The integration suite also performs this all-example check. For an attached smoke test, preview a uniquely named temporary layout and run it normally; for detached coverage run `tmuxify --detach --file <layout>` and inspect the session with tmux before removing it. Never run unfamiliar example commands without previewing them.

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
