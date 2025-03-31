# Tmuxify

**Instantly launch fully customized `tmux` workspaces.**

Tmuxify creates dynamic, modular, and highly customizable tmux sessions configured through YAML.  
It auto-detects the current folder and builds your workspace — even without any config file.

---

## 🚀 Features

- **Smart Session Management**: Auto-detects and attaches to existing sessions
- **Fully Modular Layout System**: Create any pane arrangement with a simple tree structure
- **Dynamic Sizing**: Flexible percentage-based sizing for all panes
- **Unlimited Panes**: No restrictions on layout complexity or number of panes
- **Smart Defaults**: Works out-of-the-box without config
- **Dynamic Session Naming**: Based on full folder path
- **Initial Focus Control**: Specify which pane to focus on startup
- **CLI Flags**: Built-in `--version`, `--update`, `--help`, `--list`
- **Shell-Independent**: Works on macOS, Linux, WSL
- **Example Library**: Ready-to-use layout templates for various workflows

---

## 📦 Installation

### Prerequisites

- [`tmux`](https://github.com/tmux/tmux)
- [`yq`](https://github.com/mikefarah/yq)

### First time install
#### macOS and linux

```sh
curl -fsSL https://raw.githubusercontent.com/mustafamohsen/tmuxify/main/tmuxify \
  -o /usr/local/bin/tmuxify && chmod +x /usr/local/bin/tmuxify
```

### One-liner update

```sh
tmuxify --update
```

> `tmuxify` is now self-updating — no installer script required!

---

## ⚙️ Usage

From any project directory, just run:

```sh
tmuxify
```

### With Config (`.tmuxify.yml`):
Custom layout and commands are loaded.

### Without Config:
A default layout is used automatically.

### Session Management:
If a tmux session already exists for your current directory, Tmuxify will automatically attach to it instead of creating a new one.

---

## 🧰 Command-line Flags

```sh
tmuxify --version    # Show version
tmuxify --update     # Download and install the latest version
tmuxify --help       # Show usage instructions
tmuxify --list       # List all active tmux sessions
```

---

## 🛠 Layout System

Tmuxify uses a tree-based layout system to define pane structures. The layout is defined by:

1. **Split Type**: `horizontal` (side-by-side) or `vertical` (top/bottom)
2. **Split Items**: Each split contains either terminal panes or nested splits
3. **Size Control**: Define each pane's size as a percentage
4. **Commands**: Specify what command runs in each pane
5. **Identifiers**: Reference panes by ID for initial focus

### Example Layout

```yaml
session:
  name: null  # Auto-generate from folder
  initial_focus: editor  # Focus this pane when starting

layout:
  type: horizontal  # First split horizontally
  splits:
    - id: editor
      size: 60%
      command: "nvim ."
    - type: vertical
      size: 40%
      splits:
        - id: assistant
          size: 70%
          command: "aider"
        - id: terminal
          size: 30%
          command: "clear"
```

This creates:
```
|--------------------------------------|
|                    |                 |
|                    |   assistant     |
|      editor        |                 |
|                    |-----------------|
|                    |   terminal      |
|--------------------------------------|
```

You can nest splits arbitrarily deep to create complex layouts.

---

## 📚 Example Layouts

Check out the `examples/layouts/` directory for ready-to-use templates:

- **Basic** layouts (2-pane, 3-pane, classic 4-pane)
- **Development** layouts (fullstack, data science, golang)
- **Monitoring** layouts (system monitoring, log viewing)
- **Complex** layouts (grid patterns, asymmetric arrangements)

To use an example layout:

```bash
# Copy to your project
cp examples/layouts/basic-2-pane.yml ./.tmuxify.yml

# Run tmuxify
tmuxify
```

---

## 🧩 Backward Compatibility

For users of version 1.x, Tmuxify will automatically handle the old layout format with a compatibility mode, maintaining the classic 4-pane layout.

---

## 📚 Contribute

PRs and suggestions are welcome!

- File issues for bugs or feature requests
- Open a PR to add a layout mode, plugin, or integration
- Share your custom layout configurations

---

## 📃 License

MIT License
