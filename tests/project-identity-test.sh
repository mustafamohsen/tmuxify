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
