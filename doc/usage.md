# Usage

## Common workflows

Create or attach to the workspace for the resolved project:

```bash
tmuxify
```

Use a specific layout:

```bash
tmuxify --file path/to/layout.yml
```

Preview without creating a tmux session:

```bash
tmuxify --dry-run --file path/to/layout.yml
```

Create panes without running configured commands:

```bash
tmuxify --no-commands --file path/to/layout.yml
```

Create in the background for scripts:

```bash
tmuxify --detach --file path/to/layout.yml
# Use the exact attach command printed by tmuxify.
```

## Option reference

| Option | Alias | Description |
|---|---:|---|
| `--version` | `-v` | Print the tmuxify version. |
| `--update` | `-u` | Safely download and install the latest script. |
| `--help` | `-h` | Show help. |
| `--list` | `-l` | List active tmux sessions. |
| `--list-layouts` | | List project and user layout files. |
| `--file FILE` | `-f` | Use a specific YAML layout. |
| `--root DIR` | | Override the project root (directory, not layout location). |
| `--export [FILE]` | `-e` | Export the current tmux session to a simplified YAML template. |
| `--dry-run` | | Validate and preview the selected layout only. |
| `--detach` | | Create the session without attaching or switching to it. |
| `--no-commands` | | Create panes but skip pane commands. |
| `--completion-options` | | Print machine-readable completion metadata. |

## Layout lookup priority

When no `--file` is provided, tmuxify chooses a layout in this order:

1. `--file <path>` if provided.
2. `.tmuxify.yml` at the resolved project root.
3. `${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/default.yml`.
4. Built-in four-pane default layout.

Within a Git worktree, the nearest project layout defines the root; without one, the worktree root is used. Outside Git, use the current directory or explicitly select `--root DIR`. See [root discovery](configuration.md#project-root). `--file` paths remain relative to the invocation directory. `--root` supports launch, preview, and layout listing, not update/export/active-session listing/completion metadata.

## Safe workflow

For any layout you did not write yourself:

```bash
tmuxify --list-layouts
tmuxify --dry-run --file layout.yml
tmuxify --no-commands --file layout.yml
```

Use `--dry-run` to inspect the resolved root, layout source, workspace selector, proposed session name, structure, and commands. Preview does not inspect running sessions or predict whether runtime will reuse one. Use `--no-commands` when you want only the structure; a later normal invocation reuses it without starting skipped commands. To run commands on creation, choose `tmuxify --file layout.yml` instead after reviewing the preview.

## List and export

List active tmux sessions:

```bash
tmuxify --list
```

List discovered layouts:

```bash
tmuxify --list-layouts
```

Export the current tmux session:

```bash
tmuxify --export
# or
tmuxify --export my-layout.yml
```

Export enumerates every window in deterministic tmux order, preserves visible window names, generates unique window/pane IDs, and records the active pane as `session.initial_focus`. User-controlled names are YAML encoded safely. It retains atomic-write and existing-file/symlink protections.

For managed workspaces, export preserves the original workspace selector (`null` for default), even after a tmux rename; it does not embed the project root or generated suffix. An unmanaged session's visible name becomes a project-scoped name suggestion. Malformed/unsupported identity metadata causes an explicit export error.

The result is a simplified starter template, not a backup: export does not recover commands, shell state/history, working directories, environment, exact pane geometry, or opt-in pane names and border settings. Review and adapt the generated file, then validate it with `tmuxify --dry-run --file <file>`.

## Existing sessions and creation failures

Tmuxify reuses exactly one ready session whose full project/workspace identity matches, regardless of its current tmux name. It does not reconcile windows, rerun commands, or reset focus. Legacy sessions are left untouched; see [migration](configuration.md#compatibility-and-migration).

Schema validation precedes tmux changes. Structural failures before commit roll back only the newly owned session. Concurrent launchers either reuse a committed winner or report a busy/collision error; they do not attach to unfinished work. Once readiness is committed, attachment failure or interruption preserves the workspace. If commit acknowledgement cannot be verified, the error reports the potentially retained native session for inspection. Successfully dispatched programs and their external effects are not monitored or rolled back.
