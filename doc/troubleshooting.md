# Troubleshooting

## `yq v4 is required`

Install Mike Farah `yq` v4. The Python package named `yq` is not compatible.

Check:

```bash
yq --version
```

It should mention `mikefarah/yq` or report a v4-style version.

## `tmuxify requires tmux version 2.1 or newer`

Check tmux:

```bash
tmux -V
```

Upgrade tmux through your OS package manager if needed.

## `Missing required layout object`

Your YAML must have a top-level `layout` object:

```yaml
layout:
  type: horizontal
  splits:
    - id: main
      command: clear
```

Validate with:

```bash
tmuxify --dry-run --file layout.yml
```

## `Invalid layout type`

Only these values are valid:

- `horizontal`
- `vertical`

## `Invalid size`

Sizes must be percentages from `1%` through `100%`:

```yaml
size: 50%
```

Sizes are best-effort because tmux may adjust panes based on terminal dimensions.

## `Duplicate pane id` or invalid pane id

Pane IDs must be unique. They must start with a letter and contain only letters, numbers, underscores, or dashes:

```yaml
id: test_runner
id: server-logs
```

## `session.initial_focus ... does not match any pane id`

Set `session.initial_focus` to an existing pane ID or remove it:

```yaml
session:
  initial_focus: editor

layout:
  type: horizontal
  splits:
    - id: editor
```

## Session attaches instead of rebuilding

If a tmux session with the target name already exists, tmuxify attaches or switches to it. Kill or rename the existing session to rebuild:

```bash
tmux kill-session -t <session-name>
```

## Commands ran unexpectedly

Layout commands are shell input. Preview first:

```bash
tmuxify --dry-run --file layout.yml
tmuxify --no-commands --file layout.yml
```

Then run normally only after reviewing commands.

## `--export` refuses to overwrite

Export intentionally refuses to overwrite existing files and symlinks. Choose a new filename:

```bash
tmuxify --export my-new-layout.yml
```

## Panes are not the exact requested size

Tmux sizes depend on current terminal size and tmux's layout engine. Use `size` as a starting ratio, then adjust manually if needed.
