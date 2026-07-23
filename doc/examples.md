# Examples

Example layouts live in `examples/layouts/`. They are starters: copy one, preview it, then edit commands for your project.

## Recommended workflow

```bash
cp examples/layouts/basic-3-pane.yml .tmuxify.yml
tmuxify --dry-run
tmuxify --no-commands
tmuxify
```

After `tmuxify --update`, bundled examples are also refreshed under:

```bash
${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/examples
```

## Good first layouts

| Layout | Use case |
|---|---|
| `basic-2-pane.yml` | Editor plus shell. |
| `basic-3-pane.yml` | Editor, Git/status, shell. |
| `classic-4-pane.yml` | Editor, assistant/scratch, Git, terminal. |
| `fullstack-dev.yml` | Backend/frontend monorepo starter. |
| `golang-dev.yml` | Go project workbench. |
| `multi-window-development.yml` | Safe two-window development, tests, and logs starter. |

## Multi-window starter

`multi-window-development.yml` demonstrates the session → window → nested layout → pane hierarchy. Its `initial_focus: editor` targets a pane; change it to `tests` to see window-ID focus select that window's first pane. Commands only open an available editor, show status, or print instructions—tests and log tailing remain manual.

## Shape demos

Use these to learn nested split structure:

- `6-pane-grid.yml`
- `asymmetric.yml`
- `nested-dev.yml`

## Category directories

The repository includes practical examples for:

- `dev-frontend/` - React, Vue, and generic frontend workflows.
- `dev-backend/` - Go, Node.js, and Flask workflows.
- `data-science/` - notebooks, ML training, Spark.
- `devops/` and `ci-cd/` - local CI, containers, infrastructure, pipeline monitors.
- `system-monitoring/` - disk, network, and resource dashboards.
- `security/` and `networking/` - inspection-oriented layouts with safer defaults.
- `multi-ssh/` - remote maintenance and environment comparison starters.
- `testing/` - unit, integration, and coverage dashboards.
- `streaming/` - OBS and chat monitoring layouts.

See [`../examples/layouts/README.md`](../examples/layouts/README.md) for the full catalog.

## Adapting examples

Before committing a layout:

- Rename pane IDs to match your workflow.
- Replace placeholder commands and hosts.
- Keep destructive or production-changing commands manual.
- Use environment variables for credentials.
- Validate with `tmuxify --dry-run --file <layout>`.
