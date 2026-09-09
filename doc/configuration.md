# Configuration

Tmuxify can run with an explicit layout, a project layout, a user default, or its built-in fallback.

## Lookup order

When you run `tmuxify` without `--file`, layout selection is:

1. `--file <path>` if supplied.
2. `.tmuxify.yml` in the current directory.
3. `${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/default.yml`.
4. Built-in four-pane layout.

The built-in workspace uses the same preview and command controls as YAML layouts. Its editor pane starts Neovim when available; otherwise it remains a shell with an installation hint. Neovim is optional. `--dry-run` shows all built-in commands, and `--no-commands` suppresses them, including the editor.

## Project layout

Put a checked-in `.tmuxify.yml` at a project root when the workspace is useful to everyone on the project:

```bash
cp examples/layouts/basic-3-pane.yml .tmuxify.yml
tmuxify --dry-run
```

Keep project layouts portable:

- Use relative paths.
- Avoid user-specific absolute paths.
- Prefer guarded commands such as `test -f package.json && npm test`.
- Do not commit secrets, tokens, private hostnames, or personal usernames.

## User default layout

Use a user default when you want the same layout in many directories:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts"
cp examples/layouts/classic-4-pane.yml \
  "${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/default.yml"
```

Then run:

```bash
tmuxify
```

from any directory without a project `.tmuxify.yml`.

## Config directory

Tmuxify uses:

```bash
${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify
```

Common contents:

- `layouts/default.yml` - your reusable default.
- `layouts/examples/` - examples refreshed by `tmuxify --update`.
- `completions/` - shell completions refreshed by `tmuxify --update`.

## Session names

If `session.name` is missing, tmuxify derives the session name from the current directory. Names are sanitized for tmux compatibility:

- `.` becomes `_`.
- unsupported characters become `_`.
- leading/trailing `_` are trimmed.
- an empty result falls back to `tmuxify_session`.

If a session with the exact name already exists, tmuxify attaches or switches to it instead of rebuilding panes. A longer name with the same prefix is a different workspace.

## Commands and working directory

Panes are created with the directory where `tmuxify` was run as their working directory. Each `command` is sent to tmux as shell input, like typing it and pressing Enter.

Useful command patterns:

```yaml
command: test -f package.json && npm run dev || echo "No package.json"
command: command -v lazygit >/dev/null && lazygit || git status
command: clear && echo "Manual pane: start the service when ready"
```

All windows and panes are constructed before any configured command is dispatched. Use `--dry-run` to validate and print the complete window-grouped plan without creating a session. Use `--no-commands` to create every configured window and pane while skipping all commands. `--detach` changes only attachment behavior; construction and final focus are the same.

## Compatibility and migration

Version 2.6.0 adds `windows` without removing or deprecating top-level `layout`. Existing valid single-window files need no changes. Adopt explicit windows only when you need named or multiple windows; a one-entry `windows` sequence is also useful when you want a stable window focus ID. Do not combine the forms, and do not translate pane focus IDs to visible window names.
