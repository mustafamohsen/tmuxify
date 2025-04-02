# Tmuxify

**Instantly launch customized tmux workspaces using simple YAML configuration.**

Tmuxify automates the creation and management of tmux sessions with complex layouts defined declaratively, adapting to your project context with or without configuration.

## Features

- **Declarative Layouts:** Define complex, nested pane structures with intuitive YAML
- **Smart Session Management:** Auto-generates session names and seamlessly attaches to existing sessions
- **Flexible Sizing:** Uses percentage-based pane dimensions that adapt to window resizing
- **Custom Commands:** Specify initial commands for each pane on creation
- **Zero Config Option:** Provides sensible default layout if no configuration exists
- **CLI Flexibility:** Override layouts with command-line options
- **Self-Updating:** Built-in command to fetch the latest version

## Installation

**Prerequisites:**
- [tmux](https://github.com/tmux/tmux)
- [yq](https://github.com/mikefarah/yq) (v4+)

**Install to /usr/local/bin (requires sudo):**
```bash
sudo curl -fsSL https://raw.githubusercontent.com/mustafamohsen/tmuxify/main/tmuxify \
  -o /usr/local/bin/tmuxify && sudo chmod +x /usr/local/bin/tmuxify
```

**Install to ~/bin (no sudo required):**
```bash
curl -fsSL https://raw.githubusercontent.com/mustafamohsen/tmuxify/main/tmuxify \
  -o ~/bin/tmuxify && chmod +x ~/bin/tmuxify
```

**Update:**
```bash
tmuxify --update
```

## Usage

Navigate to your project directory and run:
```bash
tmuxify
```

**Configuration Priority:**
1. **`--file <path>`:** Uses the specified YAML file
2. **`.tmuxify.yml`:** Uses the configuration file in the current directory
3. **Default Layout:** Creates a standard 4-pane layout if no config exists

## Command-Line Options

| Option           | Alias | Description                                     |
|------------------|-------|-------------------------------------------------|
| `--version`      | `-v`  | Show Tmuxify version                            |
| `--update`       | `-u`  | Download and install the latest version         |
| `--help`         | `-h`  | Display usage instructions                      |
| `--list`         | `-l`  | List all active tmux sessions                   |
| `--file FILE`    | `-f`  | Use a specific layout file                      |

## Layout Configuration

Define layouts in YAML using a nested tree structure:

```yaml
session:
  name: my-project            # Optional: Uses directory name if omitted
  initial_focus: editor       # Optional: Focus this pane on startup

layout:
  type: horizontal            # horizontal (side-by-side) or vertical (top/bottom)
  splits:
    - id: editor              # Unique identifier for this pane
      size: 60%               # Percentage of available space
      command: "nvim ."       # Command to run in this pane
    - type: vertical          # Nested layout section
      size: 40%
      splits:
        - id: tests
          size: 50%
          command: "npm test -- --watch"
        - id: terminal
          # Size omitted: takes remaining space
          command: "clear"
```

This creates:
```
|--------------------------------------|
|                    |      tests      |
|                    |-----------------|
|      editor        |     terminal    |
|      (60%)         |    (40% H)      |
|                    | (50% V | 50% V) |
|--------------------------------------|
```

## Example Layouts

Explore `examples/layouts/` for pre-built configurations organized by use case.

**Use an example directly:**
```bash
tmuxify --file examples/layouts/golang-dev.yml
```

You can learn more about creating your own custom layouts using (this guide)[https://github.com/mustafamohsen/tmuxify/wiki/Creating-Custom-Layout]

## Contributing

Contributions are welcome and appreciated! Here are several ways you can contribute:

### Bug Reports
- Use the GitHub issue tracker to report bugs
- Describe what happened and what you expected
- Include steps to reproduce the issue
- Mention your OS, tmux version, and shell environment

### Feature Requests
- Open an issue describing the feature and its value
- Tag it as an enhancement
- If possible, include examples of how you'd use the feature

### Pull Requests
Before creating a pull request, please open an issue and discuss the fix or improvement

### Layout Contributions
We especially welcome contributions of new layout templates!
- Add your layout to the `examples/layouts/` directory
- Include a descriptive comment header explaining the layout's purpose
- Make sure to add ASCII art showing the resulting layout

Thank you for helping make Tmuxify better!

## Backward Compatibility

Tmuxify v2+ automatically handles the legacy layout format of v1.x, applying the classic 4-pane structure for projects without a `.tmuxify.yml` file.

## License

MIT License
