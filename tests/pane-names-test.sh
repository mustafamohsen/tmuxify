#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMUXIFY="$ROOT_DIR/tmuxify"
TEST_DIR=$(mktemp -d /tmp/tmuxify-pane-names.XXXXXX)
export HOME="$TEST_DIR/home" XDG_CONFIG_HOME="$TEST_DIR/config" TMPDIR="$TEST_DIR/tmp" TMUX_TMPDIR="$TEST_DIR"
unset TMUX TMUX_PANE
mkdir -p "$HOME" "$TMPDIR" "$TEST_DIR/bin" "$TEST_DIR/project"
cleanup() {
  tmux kill-server >/dev/null 2>&1 || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
run() { "${TMUXIFY_BASH:-bash}" "$TMUXIFY" "$@"; }
expect_failure() {
  if run "$@" > "$TEST_DIR/output" 2>&1; then fail "unexpected success: $*"; fi
}
cd "$TEST_DIR/project"

cat > "$TEST_DIR/layout.yml" <<'YAML'
session:
  name: labels
layout:
  type: horizontal
  splits:
    - id: editor
      name: [previously, ignored]
    - id: shell
YAML
run --dry-run --file "$TEST_DIR/layout.yml" > "$TEST_DIR/disabled-preview"
yq -i 'del(.layout.splits[0].name)' "$TEST_DIR/layout.yml"
run --dry-run --file "$TEST_DIR/layout.yml" > "$TEST_DIR/plain-preview"
cmp "$TEST_DIR/disabled-preview" "$TEST_DIR/plain-preview" || fail 'ignored names changed preview'
yq -i '.session.pane_names.enabled = false | .session.pane_names.border = "invalid" | .layout.splits[0].name = ["ignored"]' "$TEST_DIR/layout.yml"
run --dry-run --file "$TEST_DIR/layout.yml" > "$TEST_DIR/disabled-preview"
cmp "$TEST_DIR/disabled-preview" "$TEST_DIR/plain-preview" || fail 'disabled feature changed preview'
echo 'ok - absent or disabled opt-in preserves validation and preview'

yq -i '.session.pane_names.enabled = true | .session.pane_names.border = "top"' "$TEST_DIR/layout.yml"
expect_failure --dry-run --file "$TEST_DIR/layout.yml"
grep -q 'non-empty single-line string' "$TEST_DIR/output" || fail 'missing pane-name validation error'
yq -i '.layout.splits[0].name = "Editor"' "$TEST_DIR/layout.yml"
run --dry-run --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
grep -q 'name="Editor"' "$TEST_DIR/output" || fail 'preview omitted pane name'
grep -q 'Pane names: enabled (border: top; requires tmux 3.2+)' "$TEST_DIR/output" || fail 'preview omitted feature requirements'
echo 'ok - opted-in names are validated and previewed'

# Runtime observations use an isolated server, never the developer's workspace.
tmux -f /dev/null new-session -d -s keepalive -x 161 -y 81 'sleep 600'
tmux set-option -g default-shell /bin/bash
tmux set-option -g default-command 'exec env HISTFILE=/dev/null /bin/bash --noprofile --norc'
tmux set-option -g default-size 161x81
tmux set-option -g pane-border-status bottom
tmux set-option -g pane-border-format 'custom #{pane_title}'
run --detach --no-commands --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
editor=$(tmux list-panes -t '=labels' -F '#{pane_id}' | head -n 1)
shell=$(tmux list-panes -t '=labels' -F '#{pane_id}' | tail -n 1)
[[ $(tmux display-message -p -t "$editor" '#{@tmuxify_pane_name}') == Editor ]] || fail 'missing configured name'
[[ $(tmux show-options -wv -t '=labels:' pane-border-status) == top ]] || fail 'requested border was not enabled'
tmux select-pane -t "$editor" -T 'application title'
format=$(tmux show-options -wv -t '=labels:' pane-border-format)
[[ $(tmux display-message -p -t "$editor" "$format") == Editor ]] || fail 'application title overwrote label'
tmux select-pane -t "$shell" -T 'unnamed shell'
[[ $(tmux display-message -p -t "$shell" "$format") == 'unnamed shell' ]] || fail 'unnamed pane lost title fallback'
[[ $(tmux show-options -gwv pane-border-format) == 'custom #{pane_title}' ]] || fail 'changed global format'
[[ $(tmux show-options -Awv -t '=keepalive:' pane-border-status) == bottom ]] || fail 'changed unrelated window'
[[ $(tmux show-options -Awv -t '=keepalive:' pane-border-format) == 'custom #{pane_title}' ]] || fail 'changed unrelated format'
echo 'ok - names survive title updates and borders are scoped to the new window'

# A numeric-looking name is still a literal label, not a format boolean.
yq -i '.session.name = "zero-label" | .layout.splits[0].name = "0"' "$TEST_DIR/layout.yml"
run --detach --no-commands --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
zero=$(tmux list-panes -t '=zero-label' -F '#{pane_id}' | head -n 1)
[[ $(tmux display-message -p -t "$zero" "$format") == 0 ]] || fail 'zero name was treated as false'
echo 'ok - numeric-looking names remain literal labels'

# Validate the original YAML scalar, including trailing controls lost by $(...).
for value in '""' 'null' 'false' '42' '[]' '{}' '"line\n"' '"tab\tname"' '"nul\u0000name"' '"del\u007f"' '"c1\u0085"'; do
  VALUE="$value" yq -i '.layout.splits[0].name = (strenv(VALUE) | from_json)' "$TEST_DIR/layout.yml"
  expect_failure --dry-run --file "$TEST_DIR/layout.yml"
  grep -q 'non-empty single-line string' "$TEST_DIR/output" || fail "wrong name error for $value"
done
yq -i '.layout.splits[0].name = "Editor" | .layout.name = "Container"' "$TEST_DIR/layout.yml"
expect_failure --dry-run --file "$TEST_DIR/layout.yml"
grep -q 'only allowed on leaf panes' "$TEST_DIR/output" || fail 'root container name was accepted'
yq -i 'del(.layout.name)' "$TEST_DIR/layout.yml"
for value in '"left"' 'null' 'true' '[]' '"top\n"' '"bottom\n"' '"preserve\n"'; do
  VALUE="$value" yq -i '.session.pane_names.border = (strenv(VALUE) | from_json)' "$TEST_DIR/layout.yml"
  expect_failure --dry-run --file "$TEST_DIR/layout.yml"
  grep -q 'border must be preserve, top, or bottom' "$TEST_DIR/output" || fail 'wrong border error'
done
echo 'ok - invalid names, container names, and border settings fail validation'

# Names cross shell, tmux argv parsing, format expansion, and style rendering.
for name in ';' 'trailing;' 'backslash\;' '-leading' 'quote " and apostrophe '\''' '日本語 café' 'Literal #[fg=red] #{pane_id} #(touch NEVER_EXECUTE)'; do
  NAME="$name" yq -i '.session.name = "literal" | .session.pane_names.border = "top" | .layout.splits[0].name = strenv(NAME)' "$TEST_DIR/layout.yml"
  run --detach --no-commands --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
  pane=$(tmux list-panes -t '=literal' -F '#{pane_id}' | head -n 1)
  [[ $(tmux display-message -p -t "$pane" '#{@tmuxify_pane_name}') == "$name" ]] || fail "name did not survive literally: $name"
  if [[ $name == Literal* ]]; then
    [[ $(tmux display-message -p -t "$pane" "$format") == 'Literal ##[fg=red] ##{pane_id} ##(touch NEVER_EXECUTE)' ]] || fail 'unsafe style/format expansion'
  fi
  tmux kill-session -t '=literal'
done
[[ ! -e NEVER_EXECUTE ]] || fail 'executed a name as a command'
echo 'ok - punctuation, Unicode, and tmux syntax remain literal name data'

# display-message does not exercise tmux's second, style-rendering stage.
# tmux 3.0/3.1 mishandle escaped hashes here; 3.2+ renders them literally.
cp "$TEST_DIR/layout.yml" "$TEST_DIR/render.yml"
render_name='Literal café #[fg=red] #{pane_id} #(touch NEVER_EXECUTE) ;'
NAME="$render_name" yq -i '.session.name = "render" | .layout.splits = [{"id": "label", "name": strenv(NAME)}]' "$TEST_DIR/render.yml"
run --detach --no-commands --file "$TEST_DIR/render.yml" > "$TEST_DIR/output"
python3 "$ROOT_DIR/tests/pane-names-render.py" render "$render_name"
[[ ! -e NEVER_EXECUTE ]] || fail 'border rendering executed a name as a command'
tmux kill-session -t '=render'
echo 'ok - attached borders render Unicode, hashes, styles, and semicolons literally'

# Default preserve mode records names without taking ownership of border UI.
yq -i '.session.name = "preserve" | del(.session.pane_names.border)' "$TEST_DIR/layout.yml"
run --detach --no-commands --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
[[ $(tmux show-options -Awv -t '=preserve:' pane-border-status) == bottom ]] || fail 'default changed inherited border position'
[[ $(tmux show-options -Awv -t '=preserve:' pane-border-format) == 'custom #{pane_title}' ]] || fail 'default changed inherited format'
pane=$(tmux list-panes -t '=preserve' -F '#{pane_id}' | head -n 1)
[[ $(tmux display-message -p -t "$pane" '#{@tmuxify_pane_name}') == 'Literal #[fg=red] #{pane_id} #(touch NEVER_EXECUTE)' ]] || fail 'preserve mode lost metadata'

# Reuse is attach-only, even if the opted-in configuration is different.
tmux select-pane -t "$pane" -T 'keep this title'
yq -i '.session.pane_names.border = "top" | .layout.splits[0].name = "Changed"' "$TEST_DIR/layout.yml"
run --detach --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
[[ $(tmux display-message -p -t "$pane" '#{pane_title}') == 'keep this title' ]] || fail 'reuse changed title'
[[ $(tmux display-message -p -t "$pane" '#{@tmuxify_pane_name}') != Changed ]] || fail 'reuse changed metadata'
[[ $(tmux show-options -Awv -t '=preserve:' pane-border-format) == 'custom #{pane_title}' ]] || fail 'reuse changed border'
echo 'ok - preserve mode and existing-session reuse leave border configuration alone'

# Opt-in is strictly a YAML boolean; old unknown metadata must remain inert.
for enabled in 'false' '"true"' 'null' '[]'; do
  VALUE="$enabled" yq -i '.session.name = "disabled" | .session.pane_names.enabled = (strenv(VALUE) | from_json) | .session.pane_names.border = "invalid" | .layout.splits[0].name = ["ignored"]' "$TEST_DIR/layout.yml"
  run --detach --no-commands --file "$TEST_DIR/layout.yml" > "$TEST_DIR/output"
  [[ -z $(tmux list-panes -t '=disabled' -F '#{@tmuxify_pane_name}' | tr -d '\n') ]] || fail 'disabled feature added names'
  [[ $(tmux show-options -Awv -t '=disabled:' pane-border-format) == 'custom #{pane_title}' ]] || fail 'disabled feature changed borders'
  [[ $(tmux list-panes -t '=disabled' -F '#{pane_width} #{pane_height} #{pane_active}') == $'80 80 1\n80 80 0' ]] || fail 'disabled feature changed geometry/focus'
  tmux kill-session -t '=disabled'
done
echo 'ok - disabled naming leaves runtime geometry, focus, and options unchanged'

cat > "$TEST_DIR/multi.yml" <<'YAML'
session:
  name: multi
  initial_focus: bottom
  pane_names:
    enabled: true
    border: bottom
windows:
  - id: development
    name: Development
    layout:
      type: horizontal
      splits:
        - id: editor
          name: Repeated label
          command: 'tmux list-panes -s -F "#{@tmuxify_pane_name}" > "$HOME/command-names"'
        - type: vertical
          splits:
            - id: top
              name: Repeated label
            - id: bottom
              name: Bottom
  - id: operations
    name: Operations
    layout:
      type: vertical
      splits:
        - id: logs
          name: Logs
  - id: unlabelled
    name: Unlabelled
    layout:
      type: horizontal
      splits:
        - id: plain
          metadata:
            name: Ignored custom metadata
YAML
tmux set-option -g base-index 5
tmux set-option -g pane-base-index 3
tmux set-option -g renumber-windows on
run --detach --no-commands --file "$TEST_DIR/multi.yml" > "$TEST_DIR/output"
[[ ! -e "$HOME/command-names" ]] || fail '--no-commands dispatched a command'
[[ $(tmux display-message -p -t '=multi:' '#{@tmuxify_pane_name}') == Bottom ]] || fail 'naming broke nested pane focus'
[[ $(tmux list-panes -t '=multi:5' -F '#{@tmuxify_pane_name}') == $'Repeated label\nRepeated label\nBottom' ]] || fail 'nested/duplicate names did not reach their panes'
[[ $(tmux show-options -Awv -t '=multi:6' pane-border-status) == bottom ]] || fail 'second named window lost border'
[[ $(tmux show-options -Awv -t '=multi:7' pane-border-format) == 'custom #{pane_title}' ]] || fail 'unnamed window got managed border'
geometry=$(tmux list-panes -t '=multi:5' -F '#{pane_width} #{pane_height}')
printf '%s\n' "$geometry" | awk '
  $1 != 80 { exit 1 }
  NR == 1 && $2 != 80 { exit 1 }
  NR > 1 { if ($2 < 39 || $2 > 40) exit 1; total += $2 }
  END { if (NR != 3 || total != 79) exit 1 }
' || fail "unexpected named nested geometry: $geometry"
yq -i '.session.name = "commands"' "$TEST_DIR/multi.yml"
run --detach --file "$TEST_DIR/multi.yml" > "$TEST_DIR/output"
for _ in {1..100}; do [[ -e "$HOME/command-names" ]] && break; sleep 0.05; done
[[ -e "$HOME/command-names" ]] || fail 'configured command never ran'
grep -qx Logs "$HOME/command-names" || fail 'commands ran before all windows were named'
echo 'ok - nested multi-window names preserve sizes, focus, indexes, and command ordering'

# Export stays a starter template; it must not harvest labels or shell titles.
active=$(tmux display-message -p -t '=multi:' '#{pane_id}')
export_tmux=$(tmux display-message -p -t "$active" '#{socket_path},#{pid},0')
TMUX="$export_tmux" TMUX_PANE="$active" run --export "$TEST_DIR/export.yml" > "$TEST_DIR/output"
[[ $(yq '.session | has("pane_names")' "$TEST_DIR/export.yml") == false ]] || fail 'export unexpectedly enabled pane names'
[[ $(yq '[.windows[].layout.splits[] | select(has("name"))] | length' "$TEST_DIR/export.yml") == 0 ]] || fail 'export unexpectedly collected pane names'
run --dry-run --file "$TEST_DIR/export.yml" > "$TEST_DIR/output"
echo 'ok - export does not acquire new pane-name behavior'

# tmux is an external boundary: simulate old versions and deterministic failures.
export TMUXIFY_REAL_TMUX
TMUXIFY_REAL_TMUX=$(command -v tmux)
cat > "$TEST_DIR/bin/tmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/tmux-calls"
if [[ $1 == -V && -n ${TMUXIFY_TEST_VERSION:-} ]]; then
  printf 'tmux %s\n' "$TMUXIFY_TEST_VERSION"
  exit 0
fi
case "${TMUXIFY_TEST_FAILURE:-}:$*" in
  border:*'pane-border-status'*|metadata:*'@tmuxify_pane_name'*) exit 1 ;;
  signal:*'@tmuxify_pane_name'*)
    "$TMUXIFY_REAL_TMUX" "$@" || exit $?
    kill -TERM "$PPID"
    exit 0 ;;
esac
exec "$TMUXIFY_REAL_TMUX" "$@"
SH
chmod +x "$TEST_DIR/bin/tmux"
export PATH="$TEST_DIR/bin:$PATH"

rm -f "$HOME/tmux-calls"
run --dry-run --file "$TEST_DIR/multi.yml" > "$TEST_DIR/output"
[[ ! -e "$HOME/tmux-calls" ]] || fail 'dry-run contacted tmux'
echo 'ok - opted-in dry-run remains tmux-free'

export TMUXIFY_TEST_VERSION=2.1
# Reusing an existing session does not need the new feature capabilities.
run --detach --file "$TEST_DIR/multi.yml" > "$TEST_DIR/output"
yq -i '.session.name = "old-version"' "$TEST_DIR/multi.yml"
for version in 2.1 3.0 3.1c; do
  export TMUXIFY_TEST_VERSION="$version"
  rm -f "$HOME/tmux-calls"
  expect_failure --detach --file "$TEST_DIR/multi.yml"
  grep -q 'Pane names require tmux 3.2' "$TEST_DIR/output" || fail 'missing feature-specific version error'
  if grep -q '^new-session' "$HOME/tmux-calls"; then fail 'version rejection created a session'; fi
done
export TMUXIFY_TEST_VERSION=2.1
yq -i '.session.pane_names.enabled = false' "$TEST_DIR/multi.yml"
run --detach --no-commands --file "$TEST_DIR/multi.yml" > "$TEST_DIR/output"
tmux has-session -t '=old-version' || fail 'old-version non-opted-in layout was blocked'
unset TMUXIFY_TEST_VERSION
echo 'ok - only new opted-in workspaces require tmux 3.2'

yq -i '.session.name = "failure" | .session.pane_names.enabled = true' "$TEST_DIR/multi.yml"
rm -f "$HOME/command-names"
for failure in border metadata signal; do
  export TMUXIFY_TEST_FAILURE="$failure"
  expect_failure --detach --file "$TEST_DIR/multi.yml"
  unset TMUXIFY_TEST_FAILURE
  if tmux has-session -t '=failure' 2>/dev/null; then fail "$failure left a partial session"; fi
  [[ ! -e "$HOME/command-names" ]] || fail "$failure dispatched commands"
  [[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail "$failure leaked temporary state"
  tmux has-session -t '=keepalive' || fail "$failure removed an unrelated session"
done
echo 'ok - naming errors and interruption roll back only the new workspace before commands'

tmux set-option -g default-size 10x3
expect_failure --detach --no-commands --file "$TEST_DIR/multi.yml"
if tmux has-session -t '=failure' 2>/dev/null; then fail 'small named layout left a partial session'; fi
tmux has-session -t '=keepalive' || fail 'small named layout removed an unrelated session'
echo 'ok - named layouts that cannot fit fail cleanly'
