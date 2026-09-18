# Security

Tmuxify is intended for trusted developer workspaces. A layout can run shell commands in your terminal, so treat YAML layouts like shell scripts.

## Trust model

For each pane with a `command`, tmuxify sends the command to tmux as if you typed it and pressed Enter. That command runs with your user account, pane environment, filesystem access, SSH agent, cloud credentials, and resolved project root as its initial working directory.

Tmuxify validates YAML shape, IDs, and sizes. It does not sandbox commands.

## Safe review workflow

For any new or changed layout:

```bash
tmuxify --dry-run --file layout.yml
tmuxify --no-commands --file layout.yml
```

- `--dry-run` validates and prints the plan.
- `--no-commands` creates panes but skips commands.
- For normal command execution on creation, run without `--no-commands` after reviewing the preview. Reusing a workspace created with commands disabled does not subsequently start those commands.

## Project discovery and identity

Launching from a worktree subdirectory can now select an ancestor's `.tmuxify.yml`, but discovery never crosses the nearest `.git` marker. Outside Git there is no ancestor-layout search. `--root` gives an explicit context; `--file` chooses only a template. Review the root and layout source in `--dry-run`, especially after adding a nested layout. Discovery does not run Git or evaluate user hooks.

Session-local identity and readiness prevent accidental reuse, including when a short naming fingerprint collides. They are not authentication: anyone able to control the same tmux server can modify its metadata. Legacy sessions are not adopted. A new scoped session can start duplicate programs alongside legacy work; use command suppression when checking a migration.

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

`tmuxify --update` checks a candidate's Bash shebang, syntax, and embedded numeric version without executing it. It prepares executable permissions before replacing the writable installation and keeps a backup for recovery. If replacement and restoration both fail, the error identifies the retained backup. It does not automatically escalate with `sudo`.

These checks reject malformed downloads; they do not authenticate a release or establish that its code is safe.

For higher-assurance environments, install reviewed releases or pinned commits rather than updating from a mutable branch.

## Shared project layouts

When adding `.tmuxify.yml` to a repository:

- Use relative paths.
- Use safe no-op fallbacks when tools are missing.
- Make privileged or destructive steps opt-in.
- Document required environment variables in the project README.
- Ask teammates to preview with `--dry-run` before first use.
