# Usage

## Common workflows

Create or attach to the workspace for the current directory:

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
tmux attach -t <session-name>
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
| `--export [FILE]` | `-e` | Export the current tmux session to a simplified YAML template. |
| `--dry-run` | | Validate and preview the selected layout only. |
| `--detach` | | Create the session without attaching or switching to it. |
| `--no-commands` | | Create panes but skip pane commands. |
| `--completion-options` | | Print machine-readable completion metadata. |

## Layout lookup priority

When no `--file` is provided, tmuxify chooses a layout in this order:

1. `--file <path>` if provided.
2. `.tmuxify.yml` in the current directory.
3. `${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/default.yml`.
4. Built-in four-pane default layout.

## Safe workflow

For any layout you did not write yourself:

```bash
tmuxify --list-layouts
tmuxify --dry-run --file layout.yml
tmuxify --no-commands --file layout.yml
tmuxify --file layout.yml
```

Use `--dry-run` to inspect structure and commands. Use `--no-commands` when you want to verify pane creation before executing anything.

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

Export writes a simplified starter layout and refuses to overwrite existing files or symlinks.
