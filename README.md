# Tmuxify

**Instantly launch fully customized `tmux` workspaces.**

Tmuxify creates dynamic, modular, and highly customizable tmux sessions configured through YAML.  
It auto-detects the current folder and builds your workspace even if no configuration is present.

---

## 🚀 Features

- **Modular**: Define any layout using `.tmuxify.yml`.
- **Smart Defaults**: Works out-of-the-box with a built-in default layout.
- **Dynamic Session Names**: Session names are based on the full folder path.
- **Shell Independent**: Works on macOS, Linux, WSL.

---

## 📦 Installation

### Prerequisites

- [`tmux`](https://github.com/tmux/tmux)
- [`yq`](https://github.com/mikefarah/yq)

### Quick Install

```sh
curl -fsSL https://raw.githubusercontent.com/mustafamohsen/tmuxify/refs/heads/main/tmuxify \
  -o /usr/local/bin/tmuxify && chmod +x /usr/local/bin/tmuxify
```

---

## ⚙️ Usage

Run this from any folder:

```sh
tmuxify
```

### 🔹 If `.tmuxify.yml` exists:
Tmuxify uses it to create your custom workspace layout.

### 🔹 If `.tmuxify.yml` is missing:
Tmuxify uses the **built-in default layout**.

---

## 🛠 Default Layout (No YAML Required)

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

### Layout Explained:

```
|------------------------------------------------|
|                   |         secondary          |
|                   |----------------------------|
|      primary      |   lmicro      |   rmicro   |
|                   |               |            |
|------------------------------------------------|
```

- `primary`: Code editor (left half)
- `secondary`: AI assistant (top right)
- `lmicro`: Git or log viewer (bottom right-left)
- `rmicro`: Shell or micro-tool (bottom right-right)

---

## 🧩 Custom Layout

To override the defaults, create a `.tmuxify.yml` file in your project folder with your own pane definitions and layout structure.

---

## 📚 Contribute

PRs and suggestions are welcome!  
To propose features or improvements, open an issue or submit a PR.

---

## 📃 License

MIT License
