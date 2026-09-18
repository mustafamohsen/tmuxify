#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMUXIFY="$ROOT_DIR/tmuxify"
TEST_DIR=$(mktemp -d /tmp/tmuxify-identity-life.XXXXXX)
export HOME="$TEST_DIR/home" XDG_CONFIG_HOME="$TEST_DIR/config" TMPDIR="$TEST_DIR/tmp" TMUX_TMPDIR="$TEST_DIR"
unset TMUX TMUX_PANE
mkdir -p "$HOME" "$TMPDIR" "$TEST_DIR/bin" "$TEST_DIR/project"
REAL_TMUX=$(command -v tmux)
export TMUXIFY_REAL_TMUX="$REAL_TMUX"
launcher=""
cleanup() {
  [[ -z $launcher ]] || { kill "$launcher" 2>/dev/null || true; wait "$launcher" 2>/dev/null || true; }
  "$REAL_TMUX" kill-server >/dev/null 2>&1 || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
run() { "${TMUXIFY_BASH:-bash}" "$TMUXIFY" --root "$TEST_DIR/project" --file "$TEST_DIR/layout.yml" "$@"; }
expect_failure() {
  if run "$@" > "$TEST_DIR/output" 2>&1; then fail "unexpected success for ${TMUXIFY_FAULT:-no fault}: $*"; fi
}
wait_file() {
  local i
  for ((i=0; i<200; i++)); do [[ -e $1 ]] && return; sleep 0.05; done
  fail "timed out waiting for $1"
}
cat > "$TEST_DIR/layout.yml" <<'YAML'
session:
  name: lifecycle
layout:
  type: horizontal
  splits:
    - id: shell
      command: 'printf "launch\n" >> "$HOME/launches"'
    - id: other
YAML
"$REAL_TMUX" -f /dev/null new-session -d -s keepalive -x 161 -y 81 'sleep 1800'
"$REAL_TMUX" set-option -g default-shell /bin/bash
"$REAL_TMUX" set-option -g default-command 'exec env HISTFILE=/dev/null /bin/bash --noprofile --norc'
proposed=$(run --dry-run | awk '/^Proposed tmux session: / {print $4}')

cat > "$TEST_DIR/bin/tmux" <<'SH'
#!/usr/bin/env bash
case "${TMUXIFY_FAULT:-}:$*" in
  inventory:list-sessions*) echo 'permission denied (injected)' >&2; exit 1 ;;
  metadata:set-option*'@tmuxify_workspace_identity'*) exit 1 ;;
  metadata-signal:set-option*'@tmuxify_workspace_identity'*)
    "$TMUXIFY_REAL_TMUX" "$@" || exit $?
    kill -TERM "$PPID"; exit 0 ;;
  ready-before:set-option*'@tmuxify_workspace_state ready') exit 1 ;;
  ready-after:set-option*'@tmuxify_workspace_state ready'|ready-unreadable:set-option*'@tmuxify_workspace_state ready')
    "$TMUXIFY_REAL_TMUX" "$@" || exit $?
    : > "$HOME/published"; exit 1 ;;
  ready-unreadable:show-options*'@tmuxify_workspace_state')
    [[ ! -e $HOME/published ]] || exit 1 ;;
  ready-signal:set-option*'@tmuxify_workspace_state ready')
    "$TMUXIFY_REAL_TMUX" "$@" || exit $?
    kill -TERM "$PPID"; exit 0 ;;
  barrier:new-session*)
    "$TMUXIFY_REAL_TMUX" "$@" || exit $?
    : > "$HOME/created"
    for _ in {1..400}; do [[ -e $HOME/release ]] && exit 0; sleep 0.05; done
    exit 1 ;;
  late-winner:new-session*)
    PATH="$TMUXIFY_NORMAL_PATH" "$TMUXIFY_PROGRAM" --root "$TMUXIFY_PROJECT" --file "$TMUXIFY_SOURCE_LAYOUT" --detach > "$HOME/late-winner"
    ;;
  snapshot:new-session*)
    # Change the source after the CLI has validated it. The snapshot must win.
    printf 'session: {name: changed}\nlayout: {type: horizontal, splits: [{id: changed, command: "touch $HOME/wrong-command"}]}\n' > "$TMUXIFY_SOURCE_LAYOUT"
    ;;
esac
exec "$TMUXIFY_REAL_TMUX" "$@"
SH
chmod +x "$TEST_DIR/bin/tmux"

for fault in inventory metadata metadata-signal ready-before; do
  TMUXIFY_FAULT="$fault" PATH="$TEST_DIR/bin:$PATH" expect_failure --detach --no-commands
  if "$REAL_TMUX" has-session -t "=$proposed" 2>/dev/null; then fail "$fault retained an uncommitted workspace"; fi
  [[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail "$fault leaked temporary state"
  "$REAL_TMUX" has-session -t '=keepalive' || fail "$fault removed unrelated work"
done
echo 'ok - query, metadata, interruption, and pre-commit failures fail safely'

for fault in ready-after ready-unreadable ready-signal; do
  rm -f "$HOME/published"
  TMUXIFY_FAULT="$fault" PATH="$TEST_DIR/bin:$PATH" expect_failure --detach --no-commands
  "$REAL_TMUX" has-session -t "=$proposed" || fail "$fault removed a committed workspace"
  [[ $("$REAL_TMUX" show-options -qv -t "=$proposed:" @tmuxify_workspace_state) == ready ]] || fail 'retained session was not ready'
  [[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail "$fault leaked temporary state"
  "$REAL_TMUX" kill-session -t "=$proposed"
done
echo 'ok - committed sessions survive failed acknowledgement and deferred signals'

TMUXIFY_FAULT=barrier PATH="$TEST_DIR/bin:$PATH" run --detach > "$TEST_DIR/winner-output" 2>&1 &
launcher=$!
wait_file "$HOME/created"
# The winner owns the name, but has not received its native ID or published metadata.
expect_failure --detach
"$REAL_TMUX" has-session -t "=$proposed" || fail 'losing launcher destroyed the winner'
[[ ! -e $HOME/launches ]] || fail 'losing launcher dispatched commands'
touch "$HOME/release"
wait "$launcher" || fail 'winning launcher failed'
launcher=""
wait_file "$HOME/launches"
run --detach > "$TEST_DIR/output"
[[ $(wc -l < "$HOME/launches" | tr -d ' ') == 1 ]] || fail 'concurrent/repeated launch dispatched commands twice'
[[ $("$REAL_TMUX" list-panes -t "=$proposed" | wc -l | tr -d ' ') == 2 ]] || fail 'winner did not complete its structure'
echo 'ok - concurrent same-identity launch never adopts partial work or duplicates commands'

"$REAL_TMUX" kill-session -t "=$proposed"
rm "$HOME/launches"
normal_path=$PATH
TMUXIFY_NORMAL_PATH="$normal_path" TMUXIFY_PROGRAM="$TMUXIFY" TMUXIFY_PROJECT="$TEST_DIR/project" TMUXIFY_SOURCE_LAYOUT="$TEST_DIR/layout.yml" TMUXIFY_FAULT=late-winner PATH="$TEST_DIR/bin:$normal_path" run --detach > "$TEST_DIR/output" 2>&1
wait_file "$HOME/launches"
[[ $(wc -l < "$HOME/launches" | tr -d ' ') == 1 ]] || fail 'creation race reran winner commands'
"$REAL_TMUX" has-session -t "=$proposed" || fail 'creation loser removed ready winner'
echo 'ok - a launcher losing atomic creation reuses only the committed winner'

"$REAL_TMUX" kill-session -t "=$proposed"
rm "$HOME/launches"
TMUXIFY_SOURCE_LAYOUT="$TEST_DIR/layout.yml" TMUXIFY_FAULT=snapshot PATH="$TEST_DIR/bin:$PATH" run --detach > "$TEST_DIR/output"
wait_file "$HOME/launches"
[[ ! -e $HOME/wrong-command ]] || fail 'changed source bypassed validated snapshot'
"$REAL_TMUX" has-session -t "=$proposed" || fail 'source mutation changed workspace identity mid-launch'
[[ $("$REAL_TMUX" list-panes -t "=$proposed" | wc -l | tr -d ' ') == 2 ]] || fail 'source mutation changed planned structure'
echo 'ok - identity, structure, and commands all use the validated configuration snapshot'
