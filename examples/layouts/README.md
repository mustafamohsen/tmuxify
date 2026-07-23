# Tmuxify Layout Examples

This folder contains example layout configurations for Tmuxify. They are meant to be copied, edited, and adapted to your own projects.

Before running an unfamiliar layout, preview it:

```bash
tmuxify --dry-run --file examples/layouts/basic-2-pane.yml
```

If you want only the panes first, run:

```bash
tmuxify --no-commands --file examples/layouts/basic-2-pane.yml
```

## Trust and safety

Tmuxify sends each pane's `command` to tmux as if you typed it. Treat layout files like shell scripts:

- Review commands before running examples from unfamiliar sources.
- Keep API tokens, passwords, and service credentials in environment variables or secret managers, not YAML.
- Privileged, destructive, scanning, packet-capture, and production-changing commands should be manual by default.
- Most examples use safe status commands or explicit placeholders where real infrastructure details are required.

## Ready-to-use starters

These are the best first layouts to copy into a project as `.tmuxify.yml`:

| Layout | Use case | Notes |
|---|---|---|
| `basic-2-pane.yml` | Editor + shell | Minimal daily driver. |
| `basic-3-pane.yml` | Editor + Git + shell | Falls back to `git status` if `lazygit` is unavailable. |
| `classic-4-pane.yml` | Editor + assistant/scratch + Git + terminal | Assistant pane is intentionally manual. |
| `fullstack-dev.yml` | Monorepo with `backend/` and `frontend/` | Runs guarded backend/frontend dev panes. |
| `multi-window-development.yml` | Two-window development workspace | Nested panes, pane focus, and safe/manual test and log commands. Change focus to `tests` to demonstrate window focus. |

## Development layouts

| Layout | Audience | Assumptions |
|---|---|---|
| `dev-frontend/general-frontend.yml` | Generic frontend | Current directory is the frontend app. |
| `dev-frontend/react-dev.yml` | React/Vite/CRA-style apps | Uses `npm run dev` or `npm start` fallback. |
| `dev-frontend/vue-dev.yml` | Vue/Vite/Vue CLI apps | Uses `npm run dev` or `npm run serve` fallback. |
| `dev-backend/go-backend.yml` | Go backend | Current directory is a Go module. |
| `dev-backend/node-backend.yml` | Node.js backend | Uses `npm run dev`, tests, and safe log tailing. |
| `dev-backend/python-flask.yml` | Flask backend | Uses `python -m flask` and `python -m pytest`. |
| `golang-dev.yml` | Go project workbench | Editor, terminal, tests, and run pane. |

## Data and ML layouts

| Layout | Use case |
|---|---|
| `data-science.yml` | Jupyter, REPL, data browser, shell, monitor. |
| `data-science/jupyter-research.yml` | Focused notebook research. |
| `data-science/ml-training.yml` | ML code, intentional training command, metrics, accelerator monitor. |
| `data-science/spark-cluster.yml` | Existing Spark cluster shell/log workflow. |

## Operations, CI, and monitoring layouts

| Layout | Use case |
|---|---|
| `devops/build-pipeline.yml` | Local CI/debug command center. |
| `devops/container-management.yml` | Docker/Kubernetes status. |
| `devops/infra-automation.yml` | Ansible/Terraform validation-first workspace. |
| `ci-cd/circleci-check.yml` | CircleCI API v2 starter using env vars. |
| `ci-cd/gitlab-runner.yml` | GitLab pipeline and optional runner-host status. |
| `ci-cd/jenkins-monitor.yml` | Jenkins job status/console starter using env vars. |
| `system-monitor.yml` | Cross-platform-ish system dashboard. |
| `system-monitoring/disk-monitor.yml` | Disk and I/O monitoring. |
| `system-monitoring/net-monitor.yml` | Network connection view with manual bandwidth hints. |
| `system-monitoring/sys-resource.yml` | Resource and log monitoring. |
| `log-viewer.yml` | Env-configurable app/error/access logs. |
| `server-dashboard.yml` | Logs, shell, metrics, and alerts for server work. |

## Security, networking, and remote access layouts

| Layout | Use case |
|---|---|
| `security/firewall-check.yml` | Manual firewall inspection commands. |
| `security/intrusion-monitor.yml` | Auth logs and Fail2ban status. |
| `security/vulnerability-scan.yml` | Authorized-target scan notes and scan-log pane. |
| `networking/diag-tools.yml` | Ping/traceroute plus manual packet-capture guidance. |
| `networking/multi-vpn.yml` | VPN status panes. |
| `networking/router-config.yml` | Router shell/log guidance without hitting common live routers. |
| `multi-ssh/environment-compare.yml` | Dev/staging/prod SSH comparison. |
| `multi-ssh/remote-maintenance.yml` | Two-host maintenance. |
| `multi-ssh/triple-ssh.yml` | Bastion/jump-host SSH example. |

## QA and streaming layouts

| Layout | Use case |
|---|---|
| `testing/unit-tests.yml` | Focused TDD loop. |
| `testing/integration-tests.yml` | Integration runner plus log pane. |
| `testing/test-dashboard.yml` | Tests, coverage, and artifacts. |
| `streaming/stream-monitor.yml` | Chat, encoder logs, and OBS status notes. |
| `streaming/obs-dashboard.yml` | OBS log/status, chat, and system stats. |
| `streaming/multi-platform-chat.yml` | Twitch/YouTube/Discord relay chat monitor. |

## Shape demos

These files are primarily for learning tmuxify's recursive layout syntax. They are useful starting points, but you should customize the pane names and commands for your workflow:

- `6-pane-grid.yml`
- `asymmetric.yml`
- `nested-dev.yml`

## Contributing examples

High-quality layout contributions are welcome. The best examples:

1. Solve a real user workflow for a specific persona.
2. Use safe defaults and avoid automatic destructive/privileged actions.
3. Prefer environment-variable placeholders over hardcoded tokens, hosts, or paths.
4. Include meaningful pane IDs and `initial_focus`.
5. Validate with:

```bash
tmuxify --dry-run --file path/to/layout.yml
```
