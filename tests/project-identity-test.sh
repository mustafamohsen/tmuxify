#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMUXIFY="$ROOT_DIR/tmuxify"
TEST_DIR=$(mktemp -d /tmp/tmuxify-identity.XXXXXX)
export HOME="$TEST_DIR/home" XDG_CONFIG_HOME="$TEST_DIR/config" TMPDIR="$TEST_DIR/tmp" TMUX_TMPDIR="$TEST_DIR"
unset TMUX TMUX_PANE
mkdir -p "$HOME" "$TMPDIR" "$TEST_DIR/bin" "$TEST_DIR/repo/.git" "$TEST_DIR/repo/src"
cleanup() {
  "$REAL_TMUX" kill-server >/dev/null 2>&1 || true
  rm -rf "$TEST_DIR"
}
REAL_TMUX=$(command -v tmux)
trap cleanup EXIT
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
run() { "${TMUXIFY_BASH:-bash}" "$TMUXIFY" "$@"; }
contains() { [[ $1 == *"$2"* ]] || fail "expected '$2' in: $1"; }
expect_failure() {
  if run "$@" > "$TEST_DIR/output" 2>&1; then fail "unexpected success: $*"; fi
}
cat > "$TEST_DIR/repo/.tmuxify.yml" <<'YAML'
layout:
  type: horizontal
  splits:
    - id: project_shell
YAML
cd "$TEST_DIR/repo/src"
project_root=$(cd .. && env pwd -P)
output=$(run --dry-run)
contains "$output" "Project root: $project_root"
contains "$output" 'id=project_shell'
echo 'ok - invocation from a worktree child discovers its project root and layout'

mkdir -p "$TEST_DIR/plain/child" "$TEST_DIR/other"
cp "$TEST_DIR/repo/.tmuxify.yml" "$TEST_DIR/plain/.tmuxify.yml"
cd "$TEST_DIR/plain/child"
plain_root=$(cd .. && env pwd -P)
output=$(run --dry-run)
contains "$output" "Project root: $plain_root/child"
contains "$output" 'default 4-pane workspace'
output=$(run --dry-run --root ..)
contains "$output" "Project root: $plain_root"
contains "$output" 'id=project_shell'
# --file stays relative to invocation, not the explicit project root.
cp ../.tmuxify.yml chosen.yml
output=$(run --file chosen.yml --root ../../other --dry-run)
contains "$output" "Project root: ${plain_root%/*}/other"
contains "$output" 'id=project_shell'
for mode in --list --export --update --completion-options; do
  expect_failure --root .. "$mode"
  expect_failure "$mode" --root ..
done
expect_failure --root .. --root ..
expect_failure --root missing
expect_failure --root chosen.yml
expect_failure --root
output=$(run --root .. --list-layouts)
contains "$output" "Project root: $plain_root"
contains "$output" "$plain_root/.tmuxify.yml"
echo 'ok - explicit roots and relative templates are independent and modes reject ambiguous roots'

cd "$TEST_DIR/repo/src"
cp ../.tmuxify.yml .tmuxify.yml
mkdir deep
output=$(cd deep && run --dry-run)
contains "$output" "Project root: $project_root/src"
rm .tmuxify.yml
mkdir .git
output=$(cd deep && run --dry-run)
contains "$output" "Project root: $project_root/src"
contains "$output" 'default 4-pane workspace'
rmdir .git
printf 'gitdir: /shared/metadata\n' > .git
output=$(cd deep && run --dry-run)
contains "$output" "Project root: $project_root/src"
contains "$output" 'default 4-pane workspace'
rm .git
mv ../.tmuxify.yml ../saved.yml
output=$(run --dry-run)
contains "$output" "Project root: $project_root"
contains "$output" 'default 4-pane workspace'
mv ../saved.yml ../.tmuxify.yml
ln -s "$TEST_DIR/repo" "$TEST_DIR/repo-link"
output=$(cd "$TEST_DIR/repo-link/src" && run --dry-run)
contains "$output" "Project root: $project_root"
output=$(GIT_DIR=/wrong GIT_WORK_TREE=/wrong run --dry-run)
contains "$output" "Project root: $project_root"
ln -s /missing .tmuxify.yml
expect_failure --dry-run
output=$(run --file ../.tmuxify.yml --dry-run)
contains "$output" "Project root: $project_root/src"
contains "$output" 'id=project_shell'
rm .tmuxify.yml
mkfifo .git
expect_failure --dry-run
rm .git
mkdir "$TEST_DIR/control"$'\n'
expect_failure --root "$TEST_DIR/control"$'\n' --dry-run
# Case aliases are a property of the host filesystem, not lowercased identities.
mkdir "$TEST_DIR/CaseProject"
if [[ -d "$TEST_DIR/caseproject" ]]; then
  output=$(run --root "$TEST_DIR/caseproject" --dry-run)
  contains "$output" "Project root: ${project_root%/*}/CaseProject"
fi
echo 'ok - discovery respects nested layouts, worktree markers, symlinks, and invalid entries'

cat > "$TEST_DIR/bin/tmux" <<'SH'
#!/bin/sh
printf contacted > "$HOME/tmux-contacted"
exit 1
SH
cp "$TEST_DIR/bin/tmux" "$TEST_DIR/bin/git"
chmod +x "$TEST_DIR/bin/tmux" "$TEST_DIR/bin/git"
PATH="$TEST_DIR/bin:$PATH" run --dry-run > "$TEST_DIR/preview"
[[ ! -e "$HOME/tmux-contacted" ]] || fail 'preview executed tmux or Git'
output=$(PATH=/usr/bin:/bin run --list-layouts)
contains "$output" "$project_root/.tmuxify.yml"
rm "$TEST_DIR/bin/tmux" "$TEST_DIR/bin/git"
echo 'ok - preview and layout listing require neither a tmux connection nor Git execution'

"$REAL_TMUX" -f /dev/null new-session -d -s identity-keepalive -x 161 -y 81 'sleep 1800'
"$REAL_TMUX" set-option -g default-shell /bin/bash
"$REAL_TMUX" set-option -g default-command 'exec env HISTFILE=/dev/null /bin/bash --noprofile --norc'
run --detach --no-commands > "$TEST_DIR/output"
[[ $("$REAL_TMUX" list-panes -a -F '#{session_name} #{pane_current_path}' | grep -v '^identity-keepalive ' | cut -d ' ' -f 2-) == "$project_root" ]] || fail 'pane started outside the discovered root'
echo 'ok - detached creation starts panes in the discovered project root'

mkdir -p "$TEST_DIR/a/api" "$TEST_DIR/b/api"
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach --no-commands > "$TEST_DIR/output"
run --root "$TEST_DIR/b/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach --no-commands > "$TEST_DIR/output"
paths=$("$REAL_TMUX" list-panes -a -F '#{pane_current_path}')
contains "$paths" "${project_root%/*}/a/api"
contains "$paths" "${project_root%/*}/b/api"
managed_id() {
  local session metadata
  for session in $("$REAL_TMUX" list-sessions -F '#{session_id}'); do
    metadata=$("$REAL_TMUX" show-options -qv -t "$session" @tmuxify_workspace_identity)
    if [[ -n $metadata ]] && [[ $(printf '%s' "$metadata" | yq -r '.[1]') == "$1" ]] && [[ $(printf '%s' "$metadata" | yq -r '.[2]') == "$2" ]] && [[ $(printf '%s' "$metadata" | yq -r '.[3]') == "$3" ]]; then
      printf '%s\n' "$session"
    fi
  done
}
first=$(managed_id "${project_root%/*}/a/api" default '')
second=$(managed_id "${project_root%/*}/b/api" default '')
[[ -n $first && -n $second && $first != "$second" ]] || fail 'same-basename projects did not get distinct full identities'
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach --no-commands > "$TEST_DIR/output"
[[ $(managed_id "${project_root%/*}/a/api" default '') == "$first" ]] || fail 'repeat invocation did not reuse the same identity'
"$REAL_TMUX" rename-session -t "$first" renamed-by-user
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach --no-commands > "$TEST_DIR/output"
contains "$(<"$TEST_DIR/output")" renamed-by-user
[[ $(managed_id "${project_root%/*}/a/api" default '') == "$first" ]] || fail 'tmux rename lost workspace identity'
echo 'ok - full identity separates same-basename projects and survives repeat launch and rename'

cp "$TEST_DIR/repo/.tmuxify.yml" "$TEST_DIR/named.yml"
yq -i '.session.name = "tests"' "$TEST_DIR/named.yml"
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/named.yml" --detach --no-commands > "$TEST_DIR/output"
named=$(managed_id "${project_root%/*}/a/api" named tests)
[[ -n $named && $named != "$first" ]] || fail 'named workspace replaced default workspace'
yq -i '.session.name = "default"' "$TEST_DIR/named.yml"
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/named.yml" --detach --no-commands > "$TEST_DIR/output"
[[ $(managed_id "${project_root%/*}/a/api" named default) != "$first" ]] || fail 'named default aliased unnamed default'
for value in 'false' '42' '[]' '{}' '"line\n"' '"nul\u0000name"'; do
  VALUE="$value" yq -i '.session.name = (strenv(VALUE) | from_json)' "$TEST_DIR/named.yml"
  expect_failure --root "$TEST_DIR/a/api" --file "$TEST_DIR/named.yml" --dry-run
done
for value in 'null' '""'; do
  VALUE="$value" yq -i '.session.name = (strenv(VALUE) | from_json)' "$TEST_DIR/named.yml"
  run --root "$TEST_DIR/a/api" --file "$TEST_DIR/named.yml" --detach --no-commands > "$TEST_DIR/output"
  contains "$(<"$TEST_DIR/output")" renamed-by-user
done
echo 'ok - workspace selectors distinguish named/default identities and reject invalid names'

export_managed() {
  local pane socket
  pane=$("$REAL_TMUX" display-message -p -t "${3:-$1}" '#{pane_id}')
  # socket_path is not a tmux 2.1 format. Use this fixture's known private socket.
  socket="$TEST_DIR/tmux-$(id -u)/default,$("$REAL_TMUX" display-message -p -t "$1" '#{pid}'),${1#\$}"
  TMUX="$socket" TMUX_PANE="$pane" run --export "$2" > "$TEST_DIR/output"
}
export_managed "$first" "$TEST_DIR/export-default.yml"
[[ $(yq -r '.session.name' "$TEST_DIR/export-default.yml") == null ]] || fail 'default export captured concrete session name'
export_managed "$named" "$TEST_DIR/export-named.yml"
[[ $(yq -r '.session.name' "$TEST_DIR/export-named.yml") == tests ]] || fail 'named export lost original selector'
if grep -Fq -- "${project_root%/*}/a/api" "$TEST_DIR/export-named.yml"; then fail 'export embedded project identity'; fi
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/export-named.yml" --detach --no-commands > "$TEST_DIR/output"
[[ $(managed_id "${project_root%/*}/a/api" named tests) == "$named" ]] || fail 'export changed workspace identity'
echo 'ok - export preserves portable selectors, including manually renamed sessions'

saved_identity=$("$REAL_TMUX" show-options -qv -t "$named" @tmuxify_workspace_identity)
for malformed in '' 'broken' '["future", "/root", "default", ""]'; do
  "$REAL_TMUX" set-option -t "$named" @tmuxify_workspace_identity "$malformed"
  if export_managed "$named" "$TEST_DIR/export-malformed.yml" 2> "$TEST_DIR/export-error"; then fail 'export guessed a selector from malformed identity metadata'; fi
  contains "$(<"$TEST_DIR/export-error")" 'malformed or unsupported workspace identity'
  [[ ! -e "$TEST_DIR/export-malformed.yml" ]] || fail 'malformed metadata left an export file'
done
"$REAL_TMUX" set-option -t "$named" @tmuxify_workspace_identity "$saved_identity"
echo 'ok - export rejects present but empty or malformed identity metadata'

# Identity, readiness, and duplicates are public ownership checks, not name guesses.
identity=$("$REAL_TMUX" show-options -qv -t "$first" @tmuxify_workspace_identity)
for state in building invalid '' $'ready\n'; do
  "$REAL_TMUX" set-option -t "$first" @tmuxify_workspace_state "$state"
  expect_failure --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach
  contains "$(<"$TEST_DIR/output")" readiness
done
"$REAL_TMUX" set-option -t "$first" @tmuxify_workspace_state ready
copy=$("$REAL_TMUX" new-session -d -s copied-identity -P -F '#{session_id}')
"$REAL_TMUX" set-option -t "$copy" @tmuxify_workspace_identity "$identity"
"$REAL_TMUX" set-option -t "$copy" @tmuxify_workspace_state building
expect_failure --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach
contains "$(<"$TEST_DIR/output")" 'Multiple sessions'
"$REAL_TMUX" kill-session -t "$copy"
# JSON formatting does not alter the underlying identity fields.
pretty=$(printf '%s' "$identity" | yq -p=json -o=json -I=2 '.')
"$REAL_TMUX" set-option -t "$first" @tmuxify_workspace_identity "$pretty"
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach > "$TEST_DIR/output"
contains "$(<"$TEST_DIR/output")" renamed-by-user
"$REAL_TMUX" set-option -t "$first" @tmuxify_workspace_identity "$identity"
echo 'ok - reuse requires one full identity and committed readiness'

mkdir -p "$TEST_DIR/c/api"
proposed=$(run --root "$TEST_DIR/c/api" --file "$TEST_DIR/repo/.tmuxify.yml" --dry-run | awk '/^Proposed tmux session: / { print $4 }')
occupied=$("$REAL_TMUX" new-session -d -s "$proposed" -P -F '#{session_id}')
for metadata in '' 'broken' '["future", "/root", "default", ""]' "$identity"; do
  "$REAL_TMUX" set-option -t "$occupied" @tmuxify_workspace_identity "$metadata"
  expect_failure --root "$TEST_DIR/c/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach
  contains "$(<"$TEST_DIR/output")" 'occupied without a matching identity'
  "$REAL_TMUX" has-session -t "$occupied" || fail 'collision removed an unrelated session'
done
"$REAL_TMUX" kill-session -t "$occupied"
legacy=$("$REAL_TMUX" new-session -d -s api -n Legacy -P -F '#{session_id}')
"$REAL_TMUX" set-option -g @tmuxify_workspace_identity "$identity"
"$REAL_TMUX" set-option -g @tmuxify_workspace_state ready
run --root "$TEST_DIR/c/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach --no-commands > "$TEST_DIR/output"
contains "$(<"$TEST_DIR/output")" "Unmanaged session 'api' was left untouched"
[[ $("$REAL_TMUX" display-message -p -t "$legacy" '#{window_name}') == Legacy ]] || fail 'legacy session was changed'
[[ -n $(managed_id "${project_root%/*}/c/api" default '') ]] || fail 'global metadata was accepted as ownership'
"$REAL_TMUX" set-option -gu @tmuxify_workspace_identity
"$REAL_TMUX" set-option -gu @tmuxify_workspace_state
echo 'ok - name collisions fail closed and unmanaged legacy sessions stay untouched'

# Freeze the externally visible naming contract against the plan's worked vectors.
cat > "$TEST_DIR/bin/pwd" <<'SH'
#!/bin/sh
printf '%s\n' /projects/acme/api
SH
chmod +x "$TEST_DIR/bin/pwd"
cp "$TEST_DIR/repo/.tmuxify.yml" "$TEST_DIR/golden.yml"
for selector in unnamed tests default; do
  case "$selector" in
    unnamed) expected=api--default--15b03f1e; yq -i 'del(.session.name)' "$TEST_DIR/golden.yml" ;;
    tests) expected=api--tests--97124f8c; yq -i '.session.name = "tests"' "$TEST_DIR/golden.yml" ;;
    default) expected=api--default--ade4c2e1; yq -i '.session.name = "default"' "$TEST_DIR/golden.yml" ;;
  esac
  output=$(PATH="$TEST_DIR/bin:$PATH" run --root "$TEST_DIR/a/api" --file "$TEST_DIR/golden.yml" --dry-run)
  contains "$output" "Proposed tmux session: $expected"
done
rm "$TEST_DIR/bin/pwd"
if mkdir "$TEST_DIR/invalid"$'\xff' 2>/dev/null; then
  expect_failure --root "$TEST_DIR/invalid"$'\xff' --dry-run
  contains "$(<"$TEST_DIR/output")" 'UTF-8'
else
  echo '# filesystem itself rejects invalid UTF-8 paths'
fi
echo 'ok - fixed identity vectors are portable and invalid path bytes cannot alias'

# tmux display-message can return success with empty output for a vanished target.
export TMUXIFY_REAL_TMUX="$REAL_TMUX"
cat > "$TEST_DIR/bin/tmux" <<'SH'
#!/usr/bin/env bash
if [[ $1 == display-message && $* == *"${TMUXIFY_EMPTY_SESSION:?}"* && $* == *'#{session_name}'* ]]; then
  exit 0
fi
exec "$TMUXIFY_REAL_TMUX" "$@"
SH
chmod +x "$TEST_DIR/bin/tmux"
TMUXIFY_EMPTY_SESSION="$first" PATH="$TEST_DIR/bin:$PATH" expect_failure --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach
contains "$(<"$TEST_DIR/output")" 'disappeared'
rm "$TEST_DIR/bin/tmux"
echo 'ok - vanished targets cannot produce detached success'

mkdir -p "$TEST_DIR/space project;/src" "$TEST_DIR/space project;/.git"
cat > "$TEST_DIR/cwd.yml" <<'YAML'
session: {name: 'cwd: #literal;'}
windows:
  - id: first
    name: First
    layout: {type: horizontal, splits: [{id: left}, {id: right}]}
  - id: second
    name: Second
    layout: {type: vertical, splits: [{id: bottom}]}
YAML
(cd "$TEST_DIR/space project;/src" && run --file "$TEST_DIR/cwd.yml" --detach --no-commands) > "$TEST_DIR/output"
cwd_session=$(managed_id "${project_root%/*}/space project;" named 'cwd: #literal;')
[[ -n $cwd_session ]] || fail 'literal workspace name did not survive metadata encoding'
paths=$("$REAL_TMUX" list-panes -s -t "$cwd_session" -F '#{pane_current_path}')
[[ $(printf '%s\n' "$paths" | wc -l | tr -d ' ') == 3 ]] || fail 'expected three panes across two windows'
[[ $(printf '%s\n' "$paths" | sort -u) == "${project_root%/*}/space project;" ]] || fail 'multi-window root was not applied to every pane'
echo 'ok - all windows use the discovered punctuation-containing root and workspace names stay literal data'
inactive=$("$REAL_TMUX" list-panes -s -t "$cwd_session" -F '#{pane_id}' | tail -n 1)
export_managed "$cwd_session" "$TEST_DIR/export-inactive.yml" "$inactive"
[[ $(yq -r '.session.initial_focus' "$TEST_DIR/export-inactive.yml") == window1_pane1 ]] || fail 'export captured caller pane instead of session active focus'
echo 'ok - export locates the calling session but preserves its active focus'

"$REAL_TMUX" kill-server
run --root "$TEST_DIR/a/api" --file "$TEST_DIR/repo/.tmuxify.yml" --detach --no-commands > "$TEST_DIR/output"
[[ -n $(managed_id "${project_root%/*}/a/api" default '') ]] || fail 'no-server state was not handled as new creation'
echo 'ok - first launch creates a workspace when no tmux server exists'
