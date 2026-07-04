# Security

Tmuxify is intended for trusted developer workspaces. A layout can run shell commands in your terminal, so treat YAML layouts like shell scripts.

## Trust model

For each pane with a `command`, tmuxify sends the command to tmux as if you typed it and pressed Enter. That command runs with your user account, environment, filesystem access, SSH agent, cloud credentials, and current working directory.

Tmuxify validates YAML shape, IDs, and sizes. It does not sandbox commands.

## Safe review workflow

For any new or changed layout:

```bash
tmuxify --dry-run --file layout.yml
tmuxify --no-commands --file layout.yml
tmuxify --file layout.yml
```

- `--dry-run` validates and prints the plan.
- `--no-commands` creates panes but skips commands.
- Run normally only after reviewing commands.

## What not to put in layouts

Avoid committing:

- API keys, passwords, access tokens, or private keys.
- Personal usernames, private hostnames, or customer data.
- Commands that delete, overwrite, migrate, deploy, scan, or change production by default.
- Automatic `sudo`, package-manager, firewall, cloud, or Kubernetes mutations.

Prefer environment variables and manual prompts:

```yaml
command: test -n "$API_TOKEN" && ./scripts/dev-server || echo "Set API_TOKEN first"
command: clear && echo "Manual: run deploy only after checking target"
```

## Updating safely

`tmuxify --update` downloads a candidate script, checks that it is executable and can report a version, backs up the current script, and replaces it only when the install path is writable. It does not automatically escalate with `sudo`.

For higher-assurance environments, install reviewed releases or pinned commits rather than updating from a mutable branch.

## Shared project layouts

When adding `.tmuxify.yml` to a repository:

- Use relative paths.
- Use safe no-op fallbacks when tools are missing.
- Make privileged or destructive steps opt-in.
- Document required environment variables in the project README.
- Ask teammates to preview with `--dry-run` before first use.
