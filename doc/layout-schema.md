# Layout schema

Tmuxify layouts are YAML files with an optional `session` object and either a legacy recursive `layout` object or a non-empty `windows` collection.

## Minimal layout

```yaml
session:
  name: my-project
  initial_focus: editor

layout:
  type: horizontal
  splits:
    - id: editor
      size: 65%
      command: nvim .
    - id: shell
      command: clear
```

## Top-level keys

| Key | Required | Description |
|---|---:|---|
| `session.name` | No | tmux session name. If omitted, tmuxify uses the current directory name. Invalid tmux characters are sanitized. |
| `session.initial_focus` | No | Window or pane `id` to focus after the layout is built. In legacy layouts it must match a pane ID. |
| `layout` | One of `layout`/`windows` | Legacy root layout node. |
| `windows` | One of `layout`/`windows` | One or more explicitly configured windows. `layout` and `windows` cannot be combined. |

## Explicit windows

```yaml
session:
  name: my-project
  initial_focus: workspace
windows:
  - id: workspace
    name: Development
    layout:
      type: horizontal
      splits:
        - id: editor
        - id: shell
  - id: operations
    name: Operations
    layout:
      type: vertical
      splits:
        - id: logs
        - id: monitor
```

Each window requires a stable `id`, a non-empty visible `name`, and a recursive `layout`. Windows are created in declaration order, and each window's layout is built independently. Window and pane IDs share one unique namespace and the same ID syntax. Focusing a window ID selects that window's first pane; focusing a pane ID selects its containing window and that pane. When focus is omitted, tmuxify selects the first pane of the first declared window. Existing top-level `layout` files remain unchanged. An explicit empty `windows` value is invalid.

## Layout nodes

A layout node describes how its children are split.

```yaml
layout:
  type: horizontal   # or vertical
  splits:
    - ...            # pane or nested layout
```

- `type: horizontal` creates side-by-side panes using tmux horizontal splits.
- `type: vertical` creates stacked panes using tmux vertical splits.
- `splits` must be a non-empty array.
- A split item can be a pane or another layout node.

## Pane keys

| Key | Required | Description |
|---|---:|---|
| `id` | No | Stable pane identifier for focus. Must start with a letter and contain only letters, numbers, `_`, or `-`. IDs must be unique. |
| `size` | No | Percent from `1%` to `100%`. Applied best-effort after the split is created. |
| `command` | No | String sent to the pane as shell input after creation. |
| `type` + `splits` | No | If present, the item is a nested layout container. |

A leaf pane with neither `id` nor `command` is allowed, but tmuxify warns because it creates an unnamed empty shell.

## Nested example

```yaml
session:
  name: fullstack
  initial_focus: editor

layout:
  type: horizontal
  splits:
    - id: editor
      size: 55%
      command: nvim .
    - type: vertical
      size: 45%
      splits:
        - id: server
          size: 50%
          command: npm run dev
        - id: tests
          command: npm test -- --watch
```

## Validation rules

`tmuxify --dry-run --file layout.yml` checks that:

- YAML parses with Mike Farah `yq` v4.
- Exactly one of `.layout` or `.windows` exists; `.windows` is a non-empty sequence of entries with a valid ID, non-empty string name, and layout.
- Every layout node has `type: horizontal` or `type: vertical`.
- Every layout node has a non-empty `splits` array.
- `size` values are percentages from `1%` through `100%`.
- `command` values are strings.
- Window and pane IDs are valid and unique in one shared namespace.
- `session.initial_focus` points at an existing window or pane ID (or an existing pane ID for legacy layouts).
