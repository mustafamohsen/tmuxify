# Configuration

Tmuxify can run with an explicit layout, a project layout, a user default, or its built-in fallback.

## Lookup order

When you run `tmuxify` without `--file`, layout selection is:

1. `--file <path>` if supplied.
2. `.tmuxify.yml` at the resolved project root.
3. `${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/default.yml`.
4. Built-in four-pane layout.

The built-in workspace uses the same preview and command controls as YAML layouts. Its editor pane starts Neovim when available; otherwise it remains a shell with an installation hint. Neovim is optional. `--dry-run` shows all built-in commands, and `--no-commands` suppresses them, including the editor.

## Project root

Inside a conventional Git worktree, tmuxify finds the nearest `.git` marker, then searches for the nearest `.tmuxify.yml` between your current directory and that worktree root. A nearer layout defines a nested project; without a layout, the worktree root is used. Linked worktrees and submodules stay separate. Discovery does not execute Git or follow gitfiles into shared metadata directories.

Outside Git, the current directory remains the root; ancestor layouts are not searched. Use `--root DIR` to explicitly select a project, including from a non-Git subdirectory. The override is authoritative and considers only `DIR/.tmuxify.yml` before user/default layouts.

`--file` selects a layout template, **not** its working directory. Relative `--file` and `--root` paths are resolved from the invocation directory, regardless of option order. Directory symlinks resolve to their physical destination. Selected unreadable or invalid configurations fail rather than silently falling back.

```bash
tmuxify --dry-run --root ../service --file ~/layouts/development.yml
```

Bare repositories and `GIT_DIR`-only setups need an explicit root when the invocation directory is not the intended project. A stale `.git` marker still bounds discovery. Adding/removing a nested `.tmuxify.yml` can change project scope; preview before running changed layouts.

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

from any project without a discovered `.tmuxify.yml`. The reusable layout is applied to that project's root, not its storage directory.

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

Workspace identity is the **canonical project root plus a default or named workspace selector**. Omitted, null, or empty `session.name` selects the default workspace. A nonempty string selects a named workspace within that project. A named workspace literally called `default` is distinct from the unnamed default. Names are case-sensitive, are not shell/environment expressions, and cannot contain control characters; other YAML types are rejected.

Concrete tmux names have the form `project--workspace--fingerprint`, for example `api--tests--97124f8c`. Readable labels are sanitized and truncated to 24 characters each; the eight-hex-digit POSIX CRC includes the full root and original selector. The suffix is not ownership proof: tmuxify always verifies the full session-local identity and ready state. A collision or ambiguous identity fails without changing another session. Use the exact attach command printed by detached creation, or inspect names with `tmuxify --list`.

Changing layout contents does not change identity. Two templates with the same selector reuse the same session. Changing `session.name` selects a different workspace; manually renaming the tmux session changes only its visible name and does not prevent reuse. Running workspaces are never reconciled, refocused, or restarted by reuse.

Separate checkouts/worktrees have distinct roots. A directory symlink resolves to the same physical root; moving a project to another path creates a new identity, while replacing a project at the same path retains its path identity. Retire old sessions deliberately when replacing projects. Paths used for identity must be valid UTF-8 and contain no control characters.

Identity and `building`/`ready` state live in session-local `@tmuxify_workspace_identity` and `@tmuxify_workspace_state` options, not a registry. They prevent accidental confusion, not tampering by another process with access to the tmux server. A partially built or ambiguous workspace requires inspection; it is not adopted, deleted, or repaired automatically.

## Pane names

Pane IDs remain focus identifiers, not visible titles. To display stable names, explicitly set `session.pane_names.enabled: true`, choose `session.pane_names.border: top` or `bottom`, and add `name` to leaf panes. Creating panes with visible labels requires tmux 3.2+; project-scoped workspace names and other layouts keep the tmux 2.1 baseline.

The default border mode is `preserve`, which records names without replacing your tmux border settings. Existing sessions are never renamed or restyled. See [pane name semantics and compatibility](layout-schema.md#pane-names-opt-in) and [the opt-in example](../examples/layouts/named-panes.yml).

## Commands and working directory

Panes are created with the resolved project root as their initial working directory. Shell startup files and configured commands may subsequently change it. The selected layout is snapshotted before validation and creation so one invocation uses one configuration. Each `command` is sent to tmux as shell input, like typing it and pressing Enter.

Useful command patterns:

```yaml
command: test -f package.json && npm run dev || echo "No package.json"
command: command -v lazygit >/dev/null && lazygit || git status
command: clear && echo "Manual pane: start the service when ready"
```

All windows and panes are constructed before any configured command is dispatched. Use `--dry-run` to validate and print the complete window-grouped plan without creating a session. Use `--no-commands` to create every configured window and pane while skipping all commands. `--detach` changes only attachment behavior; construction and final focus are the same.

## Compatibility and migration

Project identity changes session naming and directory discovery, without rewriting layout files:

- Legacy sessions without ownership metadata are left untouched. They remain available through ordinary tmux attachment; there is no automatic adoption or renaming.
- A new scoped workspace may run another copy of programs still running in an old session. Use `--dry-run` to inspect context and `--no-commands` for an initial migration check when that matters.
- A later normal invocation reuses a workspace created with `--no-commands`; it does not start the skipped commands. Start them manually, or save work and explicitly recreate the session.
- Scripts must stop assuming that `session.name` is a literal server-wide tmux target. Use the reported concrete name for direct tmux commands.
- Commands now start at the resolved project root. Check `--dry-run` when invoking from a subdirectory or using a shared template.
- Old sessions occupying a new concrete name, or duplicate/mismatched identity metadata, cause a clear error rather than adoption.

Version 2.6.0 adds `windows` without removing or deprecating top-level `layout`. Existing valid single-window files need no changes. Adopt explicit windows only when you need named or multiple windows; a one-entry `windows` sequence is also useful when you want a stable window focus ID. Do not combine the forms, and do not translate pane focus IDs to visible window names.
