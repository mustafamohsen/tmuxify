# Layout schema

Tmuxify models a workspace as session → window → recursive layout → pane. Layout YAML has an optional `session` object and exactly one of a legacy recursive `layout` object or a non-empty `windows` collection.

## Zero, legacy, one, and multiple windows

- **No selected configuration:** if no explicit, project, or user-default file exists, tmuxify creates its built-in single-window four-pane workspace.
- **Legacy:** a top-level `layout` creates one window and remains fully supported; no migration is required.
- **One explicit window:** a one-entry `windows` sequence creates exactly one named window.
- **Multiple explicit windows:** entries are created in declaration order within one session.
- **Zero explicit windows:** `windows: []` is invalid. A readable file with neither `layout` nor `windows`, or with both, is also invalid.

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
| `session.name` | No | Project-scoped workspace selector: a nonempty string selects a named workspace; omitted, null, or empty selects the default. Not a literal tmux session name. |
| `session.initial_focus` | No | Window or pane `id` to focus after the layout is built. In legacy layouts it must match a pane ID. |
| `session.pane_names.enabled` | No | Explicit YAML boolean `true` enables pane names. Otherwise all pane-name settings remain ignored. |
| `session.pane_names.border` | No | When enabled: `preserve` (default), `top`, or `bottom`. See [pane names](#pane-names-opt-in). |
| `layout` | One of `layout`/`windows` | Legacy root layout node. |
| `windows` | One of `layout`/`windows` | One or more explicitly configured windows. `layout` and `windows` cannot be combined. |

Workspace names are case-sensitive and literal, without control characters. Non-string/non-null values are invalid. Project root plus selector defines identity; layout contents and path do not. Concrete session names include sanitized labels and an identity suffix, and reuse verifies full session-local metadata. See [naming and migration](configuration.md#session-names). Geometry, commands, and focus syntax remain unchanged.

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

Each window requires all three attributes: a stable `id`, a non-empty string `name`, and a recursive `layout`. IDs must start with a letter and contain only letters, numbers, `_`, or `-`. Window names are presentation only: they may repeat and contain tmux target punctuation, and cannot be used as focus targets. Windows are created in declaration order, and each layout is built independently.

Window IDs and all pane IDs are globally unique in one session-wide focus namespace. `session.initial_focus` resolves an ID, never a visible name or numeric index. A pane-ID match selects its containing window and that pane; a window-ID match selects that window's first pane. When focus is omitted, tmuxify selects the first declared window and its first pane. Legacy focus continues to accept pane IDs. Runtime targeting uses tmux's native IDs, so custom window/pane base indexes and automatic renumbering are supported.

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
| `name` | No | Opt-in visible label for a leaf pane, independent of `id`. Ignored unless `session.pane_names.enabled: true`. |
| `size` | No | Percent from `1%` to `100%`, relative to the containing layout's available width or height. |
| `command` | No | String sent to the pane as shell input after creation. |
| `type` + `splits` | No | If present, the item is a nested layout container. |

A leaf pane with neither `id` nor `command` is allowed, but tmuxify warns because it creates an unnamed empty shell. An enabled, valid `name` also suppresses this warning.

### Pane names (opt-in)

```yaml
session:
  pane_names:
    enabled: true
    border: top
layout:
  type: horizontal
  splits:
    - id: editor
      name: "Editor"
    - id: shell
      name: "Terminal"
```

Names require **tmux 3.2+ only when creating an opted-in workspace** (pane-local metadata plus correct literal style escaping). Existing layouts retain the tmux 2.1 baseline and require no migration. Only the YAML boolean `true` activates the feature; omitted settings, `false`, and even the string `"true"` leave formerly ignored metadata ignored. With naming disabled, pane `name` fields are neither validated nor applied, and existing warnings and preview output remain unchanged.

When enabled:

- A name must be a non-empty, single-line string without control characters. Spaces, Unicode, quotes, and punctuation are allowed and displayed literally, not interpreted as commands, tmux formats, or styles.
- Names may repeat and need no `id`. They never become focus targets. Names are allowed only on leaf panes, including leaves inside nested layouts, not on layout containers.
- `preserve` records names without changing border visibility or formatting. This is the default: names may not be visible until your custom tmux format uses them.
- `top` or `bottom` explicitly replaces the border position and format **only in newly created windows containing named panes**. Unnamed panes in those windows display their normal pane title. Windows without named panes, global options, and other sessions remain untouched.
- Border labels consume terminal space and can affect pane dimensions. The border is configured before sizing; an impossible layout fails and its unfinished session is removed.
- Names are stored in pane-local `@tmuxify_pane_name` (raw text) and `@tmuxify_pane_label` (escaped for tmux style rendering). Application-controlled `pane_title` is never changed. Custom border formats can use `#{@tmuxify_pane_label}`; do not recursively expand it with `E:`.
- `--no-commands` still applies names. `--dry-run` validates and previews them without contacting tmux, and reports the feature's runtime requirement.
- Existing sessions are reused without changing their names or borders. Export remains unchanged and does not export pane names or the opt-in settings.

See [the named panes example](../examples/layouts/named-panes.yml).

### Size allocation

Sizing applies independently within each parent, including the last child. Separator cells are removed from the parent's available extent before allocation. Omitted sizes share the remaining percentage equally; with no explicit sizes, all siblings share equally. If every size is explicit, their percentages are treated as ratios and normalized to fill the parent, even when their sum differs from 100%.

Each child gets at least one cell. If explicit sizes consume 100% or more, omitted children receive that minimum and explicit ratios share the rest. Other sub-cell allocations are also clamped to one cell and the remaining space is redistributed. Fractional cells are rounded cumulatively in declaration order, so feasible ratios can differ by one cell. Existing percentage values remain valid; oversubscribed ratios are fitted rather than rejected.

If the parent cannot fit even one cell per child plus separators, construction fails and the unfinished session is removed. Enlarge the tmux window or reduce the number of splits.

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
- `command` values are strings. Commands are dispatched only after all window/pane structure exists; `--no-commands` suppresses them across every window.
- Window and pane IDs are valid and unique in one shared namespace.
- `session.initial_focus` points at an existing window or pane ID (or an existing pane ID for legacy layouts).
