# Project-scoped workspace identity: implementation plan

Status: **implemented on the project-identity branch; final review and validation are recorded below**.

Baseline: `c4483b0` on `main` (Tmuxify 2.7.1). Planning branch: `plan/project-identity`.

This plan covers project identity, root selection, session naming, safe reuse, and the associated CLI/documentation/test changes. It does not select a release version or authorize publication. See [the domain glossary](../../CONTEXT.md) for terminology.

## 1. Outcome and confirmed decisions

The goal is: **one command opens the intended project's workspace, without confusing a human-readable name with ownership of a running session.** Tmuxify remains a launcher, not a process supervisor or a reconciler.

The owner confirmed these product decisions:

1. **Git-aware, layout-led discovery.** Within a Git worktree, the nearest project layout up to the worktree root determines the project root. Without a project layout, use the worktree root. Outside Git, use the invocation directory unless an explicit root is supplied.
2. **Project-scoped named workspaces.** A project has a default workspace and can have additional named workspaces. Identical names in different projects do not share sessions. Layout contents are not identity.
3. **Leave legacy sessions untouched.** Do not automatically adopt, rename, rebuild, or destroy sessions that lack identity metadata. Create a separate scoped workspace when needed. No adoption command in this scope.

The sections below specify the proposed implementation contract for those decisions, including technical choices not individually presented as owner decisions.

### Success criteria

- Two unrelated directories named `api` cannot accidentally share a session.
- Invocations from different subdirectories of one configured project resolve consistently.
- Separate Git worktrees remain separate, including worktrees of the same repository and branch names that resemble other projects.
- Symlink aliases of a project resolve to the same identity.
- Different named workspaces in one project coexist; repeated invocation of the same identity reuses its session without modifying it or rerunning commands.
- Every newly created pane starts in the resolved project root, regardless of where a reusable layout is stored.
- Metadata disagreement, naming collisions, partial construction, and concurrent launches never cause attachment to an unverified workspace.
- The usual invocation remains `tmuxify`. No daemon, registry, project database, trust prompt, or additional required language runtime is introduced.

## 2. Current behavior and implementation pressure points

At this baseline:

- `WORKDIR=$(pwd)` supplies both local configuration lookup and the working directory passed to tmux.
- The automatic session name is the sanitized basename of that directory.
- `session.name` supplies a server-wide target name instead of a project-scoped selection.
- A successful exact `has-session` check is sufficient to reuse a session; no project ownership is checked.
- New session, window, and pane construction already uses native tmux IDs in important places. Rollback records the native session ID, while attachment still uses the configured session name.
- Export copies the runtime session name into `session.name`.
- Many tests assume that the YAML name is the exact tmux name. Some test cleanup also identifies sessions by a name prefix on a non-isolated server.

Relevant areas in `tmuxify`: option parsing and completion metadata; `list_layouts`; configuration selection; `sanitize_name`; `validate_config`; dry-run output; `export_session`; `attach_or_switch`; existing-session detection; new-session ownership and signal handling; all `-c "$WORKDIR"` arguments.

These are changes to the current contract, not claims that the existing documented behavior was accidentally implemented.

## 3. Scope limits

### Included

- Resolve a project root independently of the selected layout's storage directory.
- Add one option: `--root DIR`.
- Give the existing `session.name` field project-scoped semantics.
- Derive readable, deterministic tmux names and verify full identity through session-local metadata.
- Reuse by identity within the current tmux server, including after a manual tmux session rename.
- Preserve transactional creation, command controls, initial focus, and non-destructive reuse.
- Update preview, listing of layouts, export naming, completions, examples, migration guidance, and tests where the identity change affects them.

### Excluded

- Faithful geometry export, pane-directory capture, or process restoration.
- Per-pane/per-window working directories, environment configuration, hooks, or service dependencies.
- Creating/managing Git worktrees, branch-based identities, or repository-wide identity shared by all checkouts.
- Multiple profiles/configuration merging, a new layout language, a global-name escape mode, or a workspace-name CLI override.
- A registry, daemon, filesystem identity files, or tracking a project across moves automatically.
- Applying changed layouts to running sessions; restarting commands; automatic repair/deletion of abandoned sessions.
- Automatic adoption of legacy sessions or a compatibility mode that reintroduces name-only reuse.
- New tmux-server selection flags. Existing tmux environment/socket selection remains in control.
- Unrelated updater, packaging, release, or completion refactors.

## 4. Project-root resolution

### Inputs and outputs

The resolver receives the invocation directory and optional `--root`. It returns the canonical project root, the reason that root was selected, and any discovered project-layout candidate. Selecting the actual configuration, including applying `--file`, is a separate operation.

The invocation directory is retained separately for resolving relative CLI paths. Do not globally change the CLI process's directory and accidentally reinterpret those paths.

### Canonicalization

- Resolve an existing directory to an absolute physical path, following directory symlinks.
- Use an **external** `pwd -P` after entering the directory in a subshell with `CDPATH` disabled; do not rely solely on Bash's cached logical directory spelling.
- A local planning probe on macOS showed that Bash 3.2's builtin `pwd -P` retained differently cased aliases of the same directory, while `/bin/pwd -P` returned the filesystem's spelling. Cover this with a case-insensitive-filesystem regression where supported.
- Preserve path bytes while capturing output before validation; ordinary command substitution can discard trailing newlines. Reject control characters in root paths with an actionable error instead of hashing a lossy or terminal-unsafe representation. Spaces, Unicode, quotes, punctuation, and leading dashes remain supported. Do not independently case-fold or Unicode-normalize paths.
- Failure to canonicalize is an error, not a fallback to a different root.

### Explicit root

When `--root DIR` is supplied:

1. Resolve relative `DIR` against the invocation directory.
2. Require an accessible directory and canonicalize it.
3. Use exactly that directory as the project root. Do not search its ancestors or infer a different Git root.
4. Consider only `ROOT/.tmuxify.yml` as its project layout.

This is both the non-Git subdirectory workflow and the escape hatch for intentionally treating a repository subdirectory as an independent project without creating a layout there.

### Automatic worktree discovery

Use conventional worktree markers without executing Git:

1. Walk upward from the canonical invocation directory to the filesystem root, looking for the nearest `.git` entry.
2. Its containing directory is the worktree discovery ceiling. A `.git` directory, file, or symlink acts as a marker; do not follow a gitfile to a shared metadata directory and mistake that for the working tree.
3. Look for the nearest `.tmuxify.yml` entry between the invocation directory and that ceiling, inclusive.
4. If found, its containing directory is the project root. Otherwise the ceiling is the project root.
5. If there is no worktree marker, the project root is the invocation directory. Do not search non-Git ancestors for executable layouts.

This supports ordinary repositories, linked worktrees, submodules, nested repositories, and `--separate-git-dir` worktrees without adding Git as a runtime dependency. It identifies a discovery boundary; it does not validate repository health. A stale marker still bounds discovery. Bare repositories and `GIT_DIR`/`GIT_WORK_TREE`-only arrangements have no automatic special treatment; use `--root` when appropriate. Git environment variables do not redirect project selection.

An inaccessible discovery directory or an ambiguous filesystem error fails visibly rather than silently broadening/narrowing the root. An unexpected `.git` entry type must not allow traversal into an outer project; report the problem and offer `--root`.

### Nested project behavior

A nearer `.tmuxify.yml` inside a worktree intentionally creates a separate project scope. Adding or removing that file can therefore change the resolved root and workspace identity. Preview makes this visible; no existing session is migrated.

An outer repository's layout must not leak into a nested repository, linked worktree, or submodule. The nearest worktree marker wins before layout discovery.

### Root/layout selection table

| Invocation/context | Project root | Selected layout, absent `--file` |
|---|---|---|
| Repository root with `.tmuxify.yml` | Repository root | Root project layout |
| Repository child with only a root layout | Repository root | Root project layout |
| Repository child below a nearer nested layout | Nested layout's directory | Nested project layout |
| Repository child with no project layout | Worktree root | User default, then built-in |
| Linked worktree with no project layout | That worktree's root | User default, then built-in |
| Submodule with no local layout, outer repo has one | Submodule root | User default, then built-in; ignore outer layout |
| Non-Git directory with a local layout | Invocation directory | Local project layout |
| Non-Git child with a layout only in an ancestor | Invocation directory | User default, then built-in; no ancestor search |
| Any invocation with `--root R` | Canonical `R` | `R/.tmuxify.yml`, user default, then built-in |
| Any invocation with `--file F` | Resolved independently using the rules above | Explicit `F` |
| Invocation through a directory symlink | Same physical root as direct invocation | Same selection as direct invocation |

## 5. Configuration and working-directory contract

Configuration priority remains conceptually the same, now relative to the resolved project:

1. Explicit `--file FILE`.
2. The discovered project layout, or `ROOT/.tmuxify.yml` for an explicit/non-Git root.
3. `${XDG_CONFIG_HOME:-$HOME/.config}/tmuxify/layouts/default.yml`.
4. The existing built-in workspace.

Rules:

- Relative `--file` paths resolve against the original invocation directory, even when `--root` points elsewhere. Option order must not change this.
- `--file` chooses a template, not the project root. In particular, choosing a file from `~/.config` must not launch panes in `~/.config`.
- Discovery can identify a nearer project-layout entry to establish the root even when `--file` overrides that file's contents. Do not parse or require valid YAML in an overridden project layout.
- When a selected project-layout entry is unreadable, a directory, or a broken symlink, fail rather than falling back to an ancestor/user/default layout. Treat an existing-but-invalid configuration as an error.
- A symlinked layout is permitted, but its target's directory does not become the project root. Layouts remain trusted executable configuration, not sandboxed data.
- Read a selected configuration once into a temporary snapshot before validation, identity extraction, and construction. Keep its original source path separately for diagnostics. Do not reread a changing `session.name` after creating the session.
- Pass the project root to every tmux `new-session`, `new-window`, and `split-window` working-directory argument. This is the initial directory; shell startup files and configured commands may subsequently change it.
- Shell commands remain shell input in those panes. Do not add implicit `cd` commands or interpolate project/workspace fields into shell command text.
- A valid layout change with the same identity reuses the existing session without applying the change. Invalid selected YAML still fails validation before session mutation, consistent with current behavior.

## 6. Workspace selection and session naming

### Workspace selector

Keep the existing YAML field; do not introduce a parallel `workspace.name` schema:

```yaml
session:
  name: tests  # Named workspace within the resolved project, not a tmux target.
```

- Omitted `session.name`, YAML `null`, and the empty string select the **default workspace**. This retains the meaning of existing `name: null` examples.
- A nonempty YAML string selects a **named workspace**. Its original string is the identity value; comparisons are case-sensitive and do not trim whitespace, Unicode-normalize, or interpret environment/shell expressions. Validate the optional `session` container as a mapping or null before extracting its name.
- Reject non-string/non-null values and control characters explicitly. Do not silently coerce mappings, booleans, arrays, or numbers into identities.
- A named workspace literally called `default` is distinct from the unnamed default workspace. The selector includes its kind, not just its displayed text.
- Different files with the same project root and selector refer to the same workspace. To request two simultaneous workspaces, give them different `session.name` strings. Editing `session.name` selects another identity; it does not rename the previous workspace. A manual tmux session rename, by contrast, changes presentation without changing identity.

The full identity is:

```text
(identity format version, canonical project root, selector kind, original name)
```

For a default workspace, kind is `default` and the original name is empty. For a named workspace, kind is `named`.

Before hashing or storing metadata, the identity module must verify lossless UTF-8/JSON round-tripping of its input fields. Reject invalid UTF-8 rather than replacing bytes and potentially merging identities. This check can use the already-required `yq`; root-only layout listing neither produces an identity nor needs a YAML dependency.

Do not include layout path/content, branch, remote URL, initial focus, pane names, environment, or current application state. Moving a project to a different canonical path changes identity. Reusing the same path after deleting/replacing a project does not constitute a new identity; retire its old session explicitly. Automatic detection of that lifecycle is out of scope.

### Concrete tmux name

Proposed fixed format:

```text
<project-label>--<workspace-label>--<fingerprint>

api--default--<8 hex digits>
api--tests--<8 hex digits>
```

- `project-label`: sanitize the root basename using the existing session-safe character policy; truncate to 24 ASCII characters; use `root` for `/` and `project` if sanitization yields nothing.
- `workspace-label`: `default` for the default selector; otherwise sanitize the original name, truncate to 24 ASCII characters, and use `workspace` if empty after sanitization.
- `fingerprint`: eight lowercase hexadecimal digits from the POSIX `cksum` CRC of the exact byte stream described below. Use portable core utilities, not a new crypto/runtime dependency.
- Every name gets a suffix, even if it is currently unique. Do not make names depend on session creation order or the inventory of other projects.
- Use the full, untruncated root and original workspace name in the fingerprint input.

Fingerprint input is four UTF-8 fields separated **and terminated** by NUL bytes:

```text
"tmuxify-workspace-v1" NUL root NUL kind NUL original-name NUL
```

Stream this directly with `printf` into `cksum`; do not store NUL-delimited data in a Bash variable. Convert only the returned unsigned CRC to hex. Freeze byte-stream and name-generation test vectors on Linux and macOS. Metadata JSON formatting is not an input to the fingerprint.

Planning vectors checked with BSD `cksum` and GNU `gcksum` locally (still run the implementation tests on both target operating systems):

| Root | Kind | Original name | Expected concrete name |
|---|---|---|---|
| `/projects/acme/api` | `default` | empty | `api--default--15b03f1e` |
| `/projects/acme/api` | `named` | `tests` | `api--tests--97124f8c` |
| `/projects/acme/api` | `named` | `default` | `api--default--ade4c2e1` |
| `/projects/other/api` | `default` | empty | `api--default--f653cf40` |

The fingerprint is a compact disambiguator, **not** a globally unique identifier, an authentication check, or a cryptographic guarantee. Full metadata equality is always required before reuse. A fingerprint/label collision produces an actionable error, never attachment, automatic renaming, or an order-dependent numeric suffix.

This also separates names that sanitize identically, such as `api.dev` and `api_dev`; if their fingerprints ever collide, the metadata guard still prevents accidental reuse.

## 7. Session-local metadata and safe reuse

### Metadata

Use session-local tmux user options, available on the existing baseline; never set global options for identity:

- `@tmuxify_workspace_identity`: a compact JSON array containing the full four-field identity. Encode through `yq`, passing values as data, not expression fragments.
- `@tmuxify_workspace_state`: `building` or `ready`.

Example representation, not a shell command:

```json
["tmuxify-workspace-v1","/projects/acme/api","named","tests"]
```

The version is for the identity contract, not the application release number. It must not change for ordinary feature/patch releases. Compare validated, decoded fields rather than trusting the short name or a JSON string's whitespace.

Read metadata from each session itself, without treating inherited global user options as ownership evidence. Treat values literally: no recursive tmux format expansion, `eval`, shell execution, or regex matching of user paths/names.

Metadata protects against accidental confusion. A user with control of the tmux server can alter it; it is not an authorization or security-isolation mechanism.

### Resolution procedure

1. Resolve root, select/snapshot/validate layout, derive full identity and proposed tmux name.
2. On a runtime invocation, inspect sessions in the current tmux server using native session IDs and session-local metadata. Do not inspect or modify other servers.
3. Find exact full-identity matches independently of their current tmux names.
4. If there is exactly one full-identity match in total and that session is `ready`, reuse that native session ID. Report its actual current name. Do not change windows, panes, labels, commands, metadata, or startup focus.
5. If a matching session is `building`, has missing/invalid readiness, or if multiple sessions claim the same identity, stop with an explanatory error. Do not choose arbitrarily or treat an incomplete match as a usable workspace.
6. If no identity matches, check whether the proposed name is occupied. Unmanaged metadata, another identity, malformed identity, or an unsupported identity format at that name blocks creation. Do not overwrite or adopt it.
7. Otherwise create a new scoped session.

Unrelated sessions with missing/malformed/unsupported metadata are ignored during matching and preserved. Unsupported metadata at the desired concrete name produces an upgrade/inspection diagnostic rather than a guess. Explicitly distinguish a nonexistent tmux server from an inventory/query failure; do not silently reinterpret every query error as an empty server.

A manual `tmux rename-session` changes presentation, not identity. Reuse still works through metadata and native IDs. If someone manually copies identity metadata into a second session, report ambiguity.

### Attachment and messages

- Carry the verified native session ID through attachment/switching and all subsequent session-targeted operations. Do not resolve ownership again using a mutable name.
- Continue cleaning temporary state before the interactive handoff.
- Detached success reports both the workspace/root and actual tmux session name, with a correctly quoted exact-target attach command.
- Do not advertise a successful attachment if the verified session disappeared. Handle that as an ordinary runtime error; never switch to a similarly named session.

## 8. Creation lifecycle, races, and failure handling

Extend the existing native-ID ownership/rollback model rather than introducing a separate lock service:

```text
resolve and validate
  -> inventory/reuse or name-availability check
  -> new-session (record native ownership)
  -> write full identity + building state
  -> construct all windows/panes and apply labels
  -> dispatch enabled commands and set initial focus
  -> publish ready (signal-safe commit)
  -> release rollback ownership, clean temporaries, attach/detach
```

Requirements:

- Write/verify identity metadata immediately after successful creation, before constructing the rest of the workspace or dispatching configured commands. Failure rolls back only the newly owned native session ID. These writes precede publication of `ready`; missing readiness is never interpreted as ready.
- Keep the existing protection for signals during the transition from `new-session` to recorded ownership.
- Make readiness publication and the local rollback-ownership transition signal-safe, using the same deferred-signal approach as creation if necessary. Once `ready` is published successfully, an attachment failure or deferred signal must not remove that completed session. If publication has an ambiguous outcome, verify state by native ID before deciding to roll back; if verification itself is unavailable, fail and report the potentially retained session rather than claiming successful cleanup.
- Structural errors and interruptions before commit remove only the newly created unfinished session. Existing/unrelated sessions remain untouched, including replacements that happen to receive an old name.
- Continue documenting that external effects of already dispatched commands cannot be undone.
- A session left in `building` after SIGKILL/server disruption requires manual inspection; do not automatically delete or resume it on the next invocation.

### Concurrent same-identity launches

Do not add an indefinite `wait-for` lock or automatic command retries:

- The deterministic concrete name makes `new-session` the atomic creation contention point.
- If creation loses a race, resolve the identity again once. Reuse only a verified `ready` session; otherwise report construction/name contention and ask the caller to retry later.
- A session visible in the small interval before metadata is published is not reusable. Treat it as unverified/busy, not as ownership evidence.
- A losing invocation must never queue commands or roll back the winner's session.
- Renaming a workspace in the middle of its creation is not a supported concurrent operation. Preserve native-ID rollback safety, detect ambiguity on subsequent lookups, and do not claim full transactional isolation against arbitrary external tmux mutation.

## 9. Public interface changes

### `--root DIR`

Add directory completion metadata (`--root:directory`) and document the override. No short alias is necessary.

```bash
tmuxify                         # Discover context and open default/configured workspace.
tmuxify --root ../service        # Explicit project context, including outside Git.
tmuxify --root ../service --file ~/layouts/tests.yml
tmuxify --dry-run --root ../service
```

Missing/nonexistent/non-directory/inaccessible root arguments fail before contacting tmux. Relative root and file arguments are both interpreted from the invocation directory. Reject repeated `--root` options rather than silently choosing one. Paths beginning with `-` can be supplied as absolute paths or with `./`, consistent with the existing file-taking interface.

Root resolution applies to launch, `--dry-run`, and `--list-layouts`. Help/version, completion metadata, update, active-session listing, and export do not need project discovery. Keep their existing standalone behavior; `--root` combined with an operational mode that does not use a project (`--update`, `--list`, `--export`, `--completion-options`) should fail explicitly rather than imply that it scoped the operation. Help/version may retain their conventional immediate-exit behavior. Defer the current immediate `--list` operation until argument collection is complete so these errors do not depend on option order. This is a narrow parser change, not a redesign of all existing mode combinations.

### Preview

Add a compact context header to `--dry-run`:

```text
Project root: /projects/acme/api
Root source: project layout within worktree
Layout source: /projects/acme/api/.tmuxify.yml
Workspace: named "tests"
Proposed tmux session: api--tests--<fingerprint>
```

Then retain the existing layout/command plan. State that preview does not inspect existing sessions and that runtime reuse leaves a matching session unchanged. The proposed name can differ from a manually renamed matching session.

Preview remains tmux-free and command-free. It may read filesystem metadata and YAML; it does not run Git, configured commands, or user-provided discovery hooks. Its context header must explain why a different root/layout was selected after adding/removing a nested project layout.

### Listing

- `--list-layouts` uses the same project discovery rules, shows the resolved project root, and lists the effective project/default/example locations. Do not invent a second discovery algorithm. Keep it independent of tmux and YAML parsing.
- `--list` remains an ordinary listing of all active sessions in the current tmux server. Do not silently turn it into a project-filtered listing.

### Export naming only

A generated runtime name must not become a new workspace selector on each export:

- For a managed, supported identity, export the original named selector into `session.name`; omit it (or emit `null`) for the default selector. Do this even after a manual tmux rename.
- Never export the canonical root, fingerprint, metadata, or readiness state into a portable layout.
- For an unmanaged legacy/manual session, retain the current behavior of exporting its visible name as a named-workspace suggestion. When used, that name is now project-scoped.
- If identity metadata is present but malformed/unsupported on the session being exported, fail with an explicit diagnostic instead of guessing a selector.
- Preserve window enumeration, focus, YAML encoding, file protections, and the current simplified-geometry contract. Do not add pane labels or geometry preservation as part of this identity work.

### Completions

Extend the shared metadata kind rather than hardcoding a new option list. Bash uses directory completion while preserving spaced paths under Bash 3.2; Zsh uses directory-only `_files` behavior and its existing one-specification-per-alias structure. Existing file-taking flags must remain unchanged. Add real Zsh Tab regressions as well as Bash function tests.

## 10. Legacy-session migration and user communication

Old unscoped sessions are not proof of project ownership. Do not infer ownership from pane cwd, session creation directory, name similarity, commands, or matching layout geometry.

- Leave all legacy sessions untouched and usable through ordinary tmux attachment.
- When creating a new scoped session, if the old-style name is occupied by an unmanaged session, emit a concise notice that it was left untouched. Do not assert that it belongs to this project.
- Explain that creating the new scoped session can start another copy of layout commands while old programs are still running. Recommend `--dry-run`, then `--no-commands` for the first migration check when duplication would matter.
- Preserve the existing rule that a later invocation does not run commands omitted during a `--no-commands` creation. Documentation must not imply that simply running `tmuxify` again starts them. Start commands manually or intentionally recreate the workspace after reviewing it.
- Never silently rename old sessions, kill programs, remove files, or ask an interactive trust/adoption question during ordinary launch.
- A legacy/manual session occupying the exact new concrete name is a collision error, not a migration opportunity.

Call out intentional compatibility changes: `session.name` is no longer the literal tmux target; commands now start at a resolved project root; parent project layouts can be discovered within a worktree; `--list-layouts` follows that root. Scripts that attach by old unqualified names must adapt. No promise of byte-identical CLI output is made.

## 11. Implementation shape and file touchpoints

Keep the single-file Bash distribution. Introduce a few cohesive internal modules through functions and explicit values, not a framework or extra runtime executables:

| Module | Interface responsibility | Hidden implementation |
|---|---|---|
| Project context | Resolve invocation/root inputs into root, discovery reason, and project-layout candidate | Canonicalization, worktree markers, bounded ancestor traversal |
| Workspace identity | Resolve validated selector + root into full identity and a proposed name | Normalization rules, serialization, safe labels, fingerprint |
| Session resolution | Resolve full identity into ready native ID, absent, busy, collision, or ambiguity | Inventory, session-local metadata parsing, renamed sessions |
| Creation lifecycle | Create and commit one workspace or remove its own partial result | Metadata publication, command ordering, signals, readiness |

Keep the public CLI as the primary test seam. Do not expose helper-function names as public features. Diagnostics must not contaminate machine-consumed function output. Preserve original layout-source paths separately from temporary snapshots.

Expected files:

- `tmuxify`: the modules above, `--root`, option metadata, context preview/listing, export selector handling, native-ID attachment.
- `tests/project-identity-test.sh` (new): focused public-CLI identity/root/migration tests against private servers.
- `tests/run.sh`, `tests/workspace-test.sh`, `tests/pane-names-test.sh`: adapt exact-name assumptions while retaining their existing behavioral assertions.
- `tests/completion-test.sh`, `tests/zsh-completion.py`, and the two completion scripts: directory argument support.
- `.github/workflows/ci.yml`: run the focused identity suite under actual macOS Bash 3.2 in addition to the full Linux suite; verify baseline tmux capability as described below.
- `README.md`, `doc/configuration.md`, `doc/usage.md`, `doc/layout-schema.md`, `doc/security.md`, `doc/troubleshooting.md`, `doc/development.md`, and example documentation: the new contract and migration.
- Example YAML: retain valid existing workspace names unless a starter is intentionally switched to the default workspace; remove comments equating `session.name` with an exact tmux target.

Do not update `VERSION` or publish tags as part of implementing this plan without a separate release decision.

## 12. Test plan

All runtime tests use dedicated temporary HOME/XDG directories and private tmux servers. No developer session may be selected or killed. First remove existing suite dependencies on session-name-prefix cleanup of a shared server; new qualified names make that unsafe/incomplete.

Tests find managed sessions through public tmux state and known fixture identities, not internal Bash functions. Independently specified fixed naming vectors test the fingerprint contract; do not duplicate the entire production implementation in a test helper.

### Root and configuration tests

- Local project layout, user default, built-in fallback, and explicit-file precedence.
- Root/subdirectory invocation convergence inside a normal repository.
- Repository without a project layout still uses its worktree root.
- Nearer nested layout creates an intentional separate scope.
- Nested repository and submodule ceilings exclude outer layouts.
- Linked worktrees and `.git` files do not resolve to the shared Git metadata directory.
- Stale markers stay boundaries; unsupported/inaccessible marker situations do not silently cross into an outer project.
- No Git executable in PATH: all conventional marker-based discovery still works.
- `GIT_DIR`/`GIT_WORK_TREE` environment variables do not redirect discovery.
- Non-Git ancestor layout is not auto-discovered; `--root` opts into it.
- Explicit root is authoritative, including a repository subdirectory without a local layout.
- Relative `--file` and `--root` retain invocation-directory semantics in either order.
- Overridden project layout is not parsed; a selected unreadable/malformed/broken layout fails without fallback.
- Symlinked invocation/root and layout-file aliases behave as specified.
- Paths with spaces, Unicode, punctuation, leading dashes, and platform-supported case aliases; control-character paths fail validation, and invalid-UTF-8 identity inputs fail during preview/runtime planning before tmux contact. Canonicalization must not lose trailing bytes before rejecting an unsupported path.
- Adding/removing a nested layout changes the preview root but never mutates a prior session.
- No tmux calls during preview/layout listing; metadata/help/version remain dependency-light.
- Every pane in legacy, explicit-window, and multi-window forms starts in the resolved root, including `--no-commands` and external templates.

### Identity and naming tests

- Same basename in unrelated roots produces separate managed sessions.
- Same named template in different projects produces separate sessions.
- Repeated same-root/default and same-root/named invocation reuses the same native ID.
- Default versus named `default`; two names in one project; case-sensitive names.
- Two different templates with the same selector reuse rather than silently fork.
- Layout-content, pane-name, command, focus, and Git branch changes do not change identity.
- Null/empty/omitted names; invalid scalar/container types; control-character rejection.
- Names that sanitize identically, very long names, empty sanitized labels, and YAML/tmux-looking punctuation are handled literally.
- Fixed byte-stream/CRC/name vectors agree across Linux/macOS and Bash 3.2/current Bash.
- A forced short-name collision with different full metadata fails without reuse or mutation.
- A project move yields a new identity; the old session survives. Same-path replacement retains the documented path identity.

### Runtime ownership and migration tests

- Missing, malformed, unsupported, or globally inherited metadata cannot establish ownership.
- Exact match survives manual tmux rename; actual native ID is used for attach/switch.
- Duplicate full identities fail clearly; matching `building` or invalid readiness is not reused.
- A legacy unqualified session remains untouched while a new scoped session is created.
- An unmanaged session at the proposed new name blocks creation.
- Existing valid workspaces retain windows, focus, pane labels, and running commands across reuse.
- Changing selected YAML to invalid content fails without mutating a matching workspace.
- `--detach`, attach, switch-client, custom indexes, and automatic renumbering retain behavior.
- Owned rollback follows native IDs through renames and preserves a replacement with the previous name.
- Metadata/readiness-write failures and HUP/INT/TERM at creation/commit transitions have deterministic outcomes.
- Completed sessions survive attachment failure; temporary snapshots/maps are cleaned before handoff.
- An abandoned `building` session receives a diagnostic, not repair or deletion.
- Two deterministic concurrent same-identity launches never dispatch commands twice; loser reports busy or reuses only a committed winner. Use controlled barriers/failure injection rather than timing guesses.
- Query/attachment failures do not redirect to a similarly named or different-identity session.

### Adjacent interface regressions

- Managed default/named export preserves the selector without embedding the root or adding a generated suffix to it, including after a session rename.
- Unmanaged export keeps a portable visible-name suggestion; malformed managed identity fails explicitly.
- Existing simplified export geometry, multi-window/focus behavior, YAML encoding, overwrite refusal, and symlink protection remain intact.
- Bash 3.2 directory completion and real Zsh Tab completion handle spaces, option order, and unmatched paths; file completion remains unchanged.
- `--root` missing/duplicate/invalid arguments and unsupported mode combinations fail consistently regardless of order.
- Bundled layouts continue to validate through public dry runs.

### Compatibility gate

Retain Bash 3.2 and tmux 2.1 for ordinary layouts; pane naming keeps its existing tmux 3.2 requirement. Confirm session-local user-option reads/writes, native session targets, inventory, and readiness behavior against a real tmux 2.1 build before relying on them. A version-string stub alone is not evidence. If an intended operation is unavailable, adapt it to the existing baseline rather than silently raising requirements.

## 13. Delivery sequence

Each implementation commit includes the tests for its behavior. Do not leave a series of unrelated red commits or weaken old tests to get new naming through.

### A. Isolate tests and freeze current lifecycle guarantees

Suggested commit: `test: isolate workspace suites for scoped session identities`.

- Ensure the main integration suite also owns a private tmux server and cleanup cannot depend on configurable name prefixes.
- Introduce small public-state test helpers where they remove repetition, without binding tests to production Bash functions.
- Preserve all current command suppression, geometry, focus, rollback, and completion assertions.
- Verify the required tmux baseline operations in a controlled environment.

Exit: the existing suite passes without touching a developer server; the test environment can safely observe both legacy and new session models.

### B. Resolve project context end to end

Suggested commit: `feat: resolve project roots within worktree boundaries`.

- Implement canonicalization, marker-bounded discovery, authoritative `--root`, configuration selection/snapshotting, context previews, and consistent pane working directories.
- Add root directory completion in both shells and argument/mode validation.
- Update layout listing to use the resolver.
- Add discovery/configuration/working-directory tests and the corresponding documentation.

Exit: users can preview and create the right context from a subdirectory or explicit root. This commit does not claim to have solved identity collisions yet.

### C. Introduce scoped identity, naming, and verified reuse together

Suggested commit: `feat: scope workspace sessions to project identity`.

- Add selector validation, deterministic naming, session-local identity/readiness metadata, and inventory matching.
- Carry native IDs through reuse/attachment and the creation commit transition.
- Deliver busy/collision/ambiguity handling, legacy preservation notices, and concurrent-creation protection in the same slice; do not ship name hashing without the full-identity guard.
- Adapt existing exact-name tests using public-state discovery while retaining their safety assertions.
- Update export's selector behavior in this slice so managed sessions never export their generated names as new selectors.

Exit: same-root reuse and cross-root separation work end to end, including migration and failure/race tests.

### D. Close user-facing documentation and compatibility coverage

Suggested commit: `docs: explain project-scoped workspace behavior and migration` (with a separate focused test commit if needed).

- Update examples and all affected CLI/schema/security/troubleshooting guidance.
- Explain non-Git behavior, `--file` versus `--root`, explicit-name scope, default selection, renamed sessions, and first-upgrade duplicate-command risk.
- Add the actual Bash 3.2 CI identity run and retain Linux, Zsh, pane-label, and all-example checks.
- Record the behavior change in the changelog without choosing a release number prematurely.

Exit: the documentation describes the implemented contract, no stale promise equates a workspace name with a literal tmux target, and the complete validation matrix passes.

## 14. Final validation and stop conditions

Run Bash syntax checks, ShellCheck across the script/completions/tests, the full integration suite, the focused identity suite under actual Bash 3.2, real Zsh completion tests, and all-example public dry runs. Perform attached and switched-client smoke checks against a private server, not the user's current workspace. Retain evidence of real tmux baseline testing.

Record passing counts and tested versions at implementation time; the earlier project review's test results do not validate this unimplemented plan.

Stop and revisit the design rather than work around it if implementation requires:

- dropping the advertised Bash/tmux baseline;
- attaching based only on a name or shortened fingerprint;
- crossing a worktree discovery ceiling or silently selecting a fallback after a real error;
- mutating/adopting an existing unverified session;
- adding a persistent registry, indefinite lock, or background process;
- broadening this work into layout reconciliation, process restoration, or richer export.

The owner authorized implementation after approving this plan. Remote publication remains a separate action.

## Implementation evidence

- The CLI now implements the root, selector, naming, metadata, and lifecycle contracts above without a release-version change.
- Public tests live in `tests/project-identity-test.sh`, `tests/identity-lifecycle-test.sh`, and `tests/identity-attach-test.sh`; existing layout/focus/geometry tests were adapted to inspect scoped runtime state.
- Focused tests run locally on actual Bash 3.2, tmux 3.5a, and a locally built tmux 2.1. Baseline testing caught and corrected export's dependence on untargeted current-session lookup; it now identifies the calling session explicitly while preserving session-active focus.
- PTY tests verify real CLI attachment and client switching, with bounded drain/detach cleanup.
- CI is configured for the full Linux suite, the three identity suites against checksum-pinned tmux 2.1, and the identity suites on macOS Bash 3.2.
- Final runtime validation at `ef88c82`: all **28 integration groups passed** on macOS with Bash 3.2.57 and tmux 3.5a. This includes all bundled examples, real Bash/Zsh completion, attached-client switching, lifecycle failures/concurrency, and existing pane-name/layout regressions. Syntax checks and ShellCheck passed.
- The three identity suites also passed at `ef88c82` with actual Bash 3.2.57 and locally compiled **tmux 2.1**. The host filesystem rejects invalid UTF-8 directory names itself, so that runtime rejection case was explicitly skipped on macOS.
- Local Linux validation was interrupted during container dependency setup, before tests began. No Linux pass or remote CI result is claimed; that platform's configured CI gate remains outstanding.

### Independent review

The user-approved baseline was `a165c8f`; independent, fresh-context Standards and Spec reviewers examined the diff through `0b27e7d` in parallel.

- **Standards:** no hard documented-standard breaches. One non-blocking **possible Duplicated Code** note identified repeated metadata lookup in `tests/workspace-helpers.sh` and `tests/project-identity-test.sh`. Deferred: these helpers currently make different cardinality assertions, and sharing their inventory operation is a future test-maintenance cleanup, not a runtime correctness fix.
- **Spec:** three findings were reproduced through the public CLI and corrected test-first: discovered roots ending in semicolons (`5f765c7`), readiness values with trailing newlines (`fc7be8b`), and export with explicitly empty identity metadata (`ef88c82`). Each regression failed before its fix and passed afterward, including on tmux 2.1.
- The retained Spec reviewer checked the corrective diff through `ef88c82`, confirmed all three findings resolved, and found no new defect within that change scope. The final full-suite and baseline runs above completed after the fixes.

Review workflow: `a7b4c693-1b1f-4d76-a3df-ac11d0e552be`; Spec follow-up: `552ae501-5610-4746-a04c-9ed965b6121a`. Runtime remains 2.7.1; no remote publication or release was performed.
