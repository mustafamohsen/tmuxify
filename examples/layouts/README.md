# Tmuxify Layout Examples

This folder contains example layout configurations for Tmuxify. Copy any of these examples to your project as `.tmuxify.yml` to use them.

## Basic Layouts
- `basic-2-pane.yml` - Simple side-by-side editor and terminal
- `basic-3-pane.yml` - Editor with terminal and git panes
- `classic-4-pane.yml` - The classic Tmuxify layout with editor, assistant, git, and terminal

## Development Layouts
- `fullstack-dev.yml` - Frontend, backend, and terminal panes
- `data-science.yml` - Jupyter, database, and terminal layout
- `golang-dev.yml` - Specialized for Go development

## Monitoring Layouts
- `system-monitor.yml` - System monitoring dashboard
- `log-viewer.yml` - Multi-log viewer
- `server-dashboard.yml` - Server monitoring layout

## Complex Layouts
- `6-pane-grid.yml` - Complex grid layout
- `nested-dev.yml` - Deeply nested development environment
- `asymmetric.yml` - Asymmetric pane arrangement

## Usage

To use any of these layouts:

```bash
# Copy to your project
cp examples/layouts/basic-2-pane.yml ./.tmuxify.yml

# Run tmuxify
tmuxify
```

Feel free to modify these examples to fit your specific needs.
