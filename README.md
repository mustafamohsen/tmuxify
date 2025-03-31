# Tmuxify

**Instantly launch customized `tmux` workspaces using simple YAML configuration.**

Tmuxify automates the creation and management of `tmux` sessions, allowing you to define complex layouts and commands declaratively. It automatically detects project contexts and can run with or without a dedicated configuration file.

---

## Features

*   **Declarative Layouts:** Define complex, nested pane structures using an intuitive YAML format.
*   **Session Management:** Automatically generates session names or uses custom ones; attaches to existing sessions seamlessly.
*   **Flexible Sizing:** Uses percentage-based pane dimensions that adapt to window resizing (`aggressive-resize`).
*   **Custom Commands:** Specify initial commands to run in each pane upon creation.
*   **Zero Config Option:** Provides a sensible default layout if no configuration file is found.
*   **Configuration Override:** Specify layout files directly via command-line flag.
*   **Self-Updating:** Includes a built-in command to fetch the latest version.
*   **Helper Utilities:** Flags for version display, help, and listing sessions.

---

## Installation

**Prerequisites:**

*   [`tmux`](https://github.com/tmux/tmux)
*   [`yq`](https://github.com/mikefarah/yq) (v4+)

**Install / Update:**

```sh
# First time install (macOS/Linux)
curl -fsSL https://raw.githubusercontent.com/mustafamohsen/tmuxify/main/tmuxify \
  -o /usr/local/bin/tmuxify && chmod +x /usr/local/bin/tmuxify

# Update to the latest version
tmuxify --update
```

---

## Usage

Navigate to your project directory and run:

```sh
tmuxify
```

**Configuration Priority:**

1.  **`--file <path>`:** Uses the specified YAML file.
    ```sh
    tmuxify --file path/to/custom-layout.yml
    ```
2.  **`.tmuxify.yml`:** Uses the configuration file found in the current directory.
3.  **Default Layout:** If neither of the above is found, creates a standard 4-pane layout.

Tmuxify will attach to an existing `tmux` session if one matches the target session name (either specified in the config or auto-generated from the directory name).

---

## Command-Line Flags

| Flag            | Alias | Description                                         |
| --------------- | ----- | --------------------------------------------------- |
| `--version`     | `-v`  | Show Tmuxify version.                               |
| `--update`      | `-u`  | Download and install the latest version.            |
| `--help`        | `-h`  | Display usage instructions.                         |
| `--list`        | `-l`  | List all active tmux sessions.                      |
| `--file FILE`   | `-f`  | Use a specific layout file (overrides `.tmuxify.yml`). |

---

## Layout Configuration

Define layouts in YAML using a nested tree structure.

**Core Concepts:**

*   **`session`:** Top-level key for session settings (`name`, `initial_focus`).
*   **`layout`:** Defines the root pane split.
    *   **`type`:** `horizontal` (side-by-side) or `vertical` (top/bottom).
    *   **`splits`:** An array of items within the current layout block.
        *   **Pane:** An object defining a terminal pane (`id`, `size`, `command`).
        *   **Nested Layout:** An object defining further splits (`type`, `size`, `splits`).
*   **`id`:** An optional unique identifier for a pane (used for `initial_focus`).
*   **`size`:** Percentage of the available space for the pane/split (e.g., `60%`). The last item in a `splits` array takes the remaining space.
*   **`command`:** The shell command to execute in the pane upon creation.

**Example (`.tmuxify.yml`):**

```yaml
session:
  name: my-project # Optional: Uses directory name if null/omitted
  initial_focus: editor # Optional: Focus pane with id 'editor' on start

layout:
  type: horizontal
  splits:
    - id: editor
      size: 60%
      command: "nvim ."
    - type: vertical
      size: 40% # Takes 40% of the remaining horizontal space
      splits:
        - id: tests
          size: 50% # Takes 50% of the vertical space in this section
          command: "make test-watch"
        - id: console
          # size omitted: takes remaining 50% vertical space
          command: "clear"
```

This creates:

```
|--------------------------------------|
|                    |      tests      |
|                    |-----------------|
|      editor        |     console     |
|      (60%)         |    (40% H)      |
|                    | (50% V | 50% V) |
|--------------------------------------|
```

---

## Example Layouts

Explore the `examples/layouts/` directory for various pre-built configurations (basic, development, monitoring).

**To use an example directly:**

```bash
tmuxify --file examples/layouts/golang-dev.yml
```

---

## Backward Compatibility

Tmuxify v2+ automatically handles the legacy layout format of v1.x, applying the classic 4-pane structure for projects without a `.tmuxify.yml` file.

---

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to open a pull request or submit an issue on the project repository.

---

## License

[MIT License](LICENSE) # Assuming you have a LICENSE file, otherwise remove link

