# Tmuxify

**Instantly launch fully customized `tmux` workspaces.**

Tmuxify creates dynamic, modular, and highly customizable tmux sessions configured through YAML.  
It auto-detects the current folder and builds your workspace — even without any config file.

---

## 🚀 Features

- **Modular**: Define any layout using `.tmuxify.yml`
- **Smart Defaults**: Works out-of-the-box without config
- **Dynamic Session Naming**: Based on full folder path
- **CLI Flags**: Built-in `--version`, `--update`, `--help`
- **Shell-Independent**: Works on macOS, Linux, WSL

---

## 📦 Installation

### Prerequisites

- [`tmux`](https://github.com/tmux/tmux)
- [`yq`](https://github.com/mikefarah/yq)

### One-liner install or update:

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
A default layout is used automatically (see below).

---

## 🧰 Command-line Flags

```sh
tmuxify --version    # Show version
tmuxify --update     # Download and install the latest version
tmuxify --help       # Show usage instructions
```

---

## 🛠 Default Layout (used if no `.tmuxify.yml`)

```yaml
session:
  name: null
  main_pane: "primary"

layout:
  left_pane_width_percent: 50
  right_top_height_percent: 50
  right_bottom_left_width_percent: 50

panes:
  primary:
    command: "nvim ."
  secondary:
    command: "aider"
  lmicro:
    command: "lazygit"
  rmicro:
    command: "clear"
```

### Layout Overview:

```
|------------------------------------------------|
|                   |         secondary          |
|                   |----------------------------|
|      primary      |   lmicro      |   rmicro   |
|                   |               |            |
|------------------------------------------------|
```

- `primary`: Code editor (left half)
- `secondary`: AI assistant or helper (top right)
- `lmicro`: Git or logs (bottom right-left)
- `rmicro`: Terminal or REPL (bottom right-right)

---

## 🧩 Custom Layout

To customize your dev environment:

1. Create a `.tmuxify.yml` file in your project root
2. Define layout, pane commands, and sizes
3. Run `tmuxify`

See `.tmuxify.yml.example` for reference.

---

## 📚 Contribute

PRs and suggestions are welcome!

- File issues for bugs or feature requests
- Open a PR to add a layout mode, plugin, or integration

---

## 📃 License

MIT License
