# Tmuxify documentation

Tmuxify is a single-file Bash CLI that creates or attaches to tmux workspaces from YAML layouts. A layout describes panes, nested splits, optional pane commands, and startup focus.

## Start here

- [Installation](installation.md) - requirements, install/update, completions, config paths.
- [Usage](usage.md) - common workflows, CLI options, lookup priority, safe previews.
- [Layout schema](layout-schema.md) - YAML structure, validation rules, annotated examples.
- [Configuration](configuration.md) - project and global layouts, examples, session behavior.
- [Examples](examples.md) - bundled layout categories and copying workflow.
- [Security](security.md) - command execution trust model and safe-use checklist.
- [Development](development.md) - repository structure, tests, CI, releases.
- [Troubleshooting](troubleshooting.md) - common errors and fixes.

## Quick example

```bash
tmuxify --list-layouts
tmuxify --dry-run --file examples/layouts/basic-2-pane.yml
tmuxify --file examples/layouts/basic-2-pane.yml
```

Layout commands are sent to tmux as shell input. Review unfamiliar YAML before running it.
