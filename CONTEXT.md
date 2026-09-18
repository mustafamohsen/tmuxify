# Tmuxify

Vocabulary for project-aware tmux workspaces.

## Language

**Project root**:
The directory that anchors a workspace's project identity and relative startup paths.
_Avoid_: layout directory (a reusable layout can live elsewhere)

**Project layout**:
A `.tmuxify.yml` associated with a project root and describing its initial workspace arrangement.

**Reusable layout**:
A layout used as a template for different projects, independent of the directory in which the template is stored.

**Workspace**:
A project's working context, represented at runtime by a tmux session containing windows and panes. A project can have a default workspace and additional named workspaces.

**Workspace name**:
An optional name that distinguishes a workspace within one project, not a globally unique tmux session name.
_Avoid_: session name (when referring to project-scoped identity)

**Workspace identity**:
The combination of a project root and a default or named workspace selection. Layout contents and running programs are not part of this identity.

**Session name**:
The concrete name of a workspace's tmux session, distinct from the project-scoped workspace name.

**Session**:
The tmux runtime container for a workspace, distinct from the YAML layout used to create it.

**Pane ID**:
An identifier in a layout used to select a pane, distinct from its visible label and tmux's native pane identity.
