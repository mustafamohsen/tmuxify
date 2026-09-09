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

## Missing or empty layout/windows errors

Your YAML must have either a top-level `layout` object:

```yaml
layout:
  type: horizontal
  splits:
    - id: main
      command: clear
```

or a non-empty `windows` sequence. `windows: []` and files containing both forms are rejected. Validate with:

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

## Duplicate or invalid ID

Window and pane IDs share one session-wide namespace, so duplicates across windows and a window ID matching a pane ID are invalid. IDs must start with a letter and contain only letters, numbers, underscores, or dashes:

```yaml
id: test_runner
id: server-logs
```

## `session.initial_focus` does not match an ID

Set `session.initial_focus` to an existing pane or window ID, not a visible window name or tmux index, or remove it:

```yaml
session:
  initial_focus: editor

layout:
  type: horizontal
  splits:
    - id: editor
```

For explicit windows, a window ID focuses its first pane; a pane ID focuses that exact pane. With no value, the first window's first pane is selected.

## Custom indexes or renumbering seem to select the wrong target

Tmuxify uses native tmux window and pane IDs and does not assume index zero. If results appear stale, check whether a same-named session already exists; existing sessions are reused without reconciliation.

## A creation failure occurred

A detected structural failure or HUP/INT/TERM interruption during setup removes the newly created unfinished session and temporary files. Existing and unrelated sessions are preserved. Once setup is complete, attachment or client-switching failure leaves the workspace available to attach later. Temporary files are cleaned before handing control to tmux.

Tmuxify cannot undo external side effects of programs whose commands were already sent, even when an interrupted setup removes their panes.

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

Sizes are allocated within each parent layout, not the whole window. Separators, minimum pane dimensions, and integer-cell rounding affect the result. Omitted sizes share the remaining space; oversubscribed percentages are fitted as ratios. See [size allocation](layout-schema.md#size-allocation). If there is not enough room for all panes, enlarge the window or reduce the splits.
