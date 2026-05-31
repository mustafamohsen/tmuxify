#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMUXIFY="$ROOT_DIR/tmuxify"
TEST_PREFIX="tmuxify_ci_$$"
TMP_DIR=$(mktemp -d)

cleanup() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${TEST_PREFIX}" | while read -r session; do
    tmux kill-session -t "$session" 2>/dev/null || true
  done
  rm -rf "$TMP_DIR" "/tmp/${TEST_PREFIX}_base_index_sock"
}
trap cleanup EXIT

fail() {
  echo "not ok - $*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain '$needle'; got: $haystack"
  fi
}

run_expect_success() {
  local output
  output=$("$@" 2>&1) || fail "command failed: $*\n$output"
  printf '%s' "$output"
}

run_expect_failure() {
  local output status
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    fail "command unexpectedly succeeded: $*\n$output"
  fi
  printf '%s' "$output"
}

echo "1..8"

output=$(run_expect_success "$TMUXIFY" --help)
assert_contains "$output" "--dry-run"
assert_contains "$output" "--no-commands"
echo "ok 1 - help documents safe workflow flags"

output=$(run_expect_success "$TMUXIFY" --version)
assert_contains "$output" "tmuxify version"
echo "ok 2 - version works"

cat > "$TMP_DIR/valid.yml" <<YAML
session:
  name: ${TEST_PREFIX}_nested
  initial_focus: editor
layout:
  type: horizontal
  splits:
    - type: vertical
      size: 60%
      splits:
        - id: editor
          size: 50%
          command: "printf editor"
        - id: terminal
          size: 50%
          command: "printf terminal"
    - type: vertical
      size: 40%
      splits:
        - id: tests
          size: 50%
          command: "printf tests"
        - id: docs
          size: 50%
          command: "printf docs"
YAML

output=$(run_expect_success "$TMUXIFY" --dry-run --file "$TMP_DIR/valid.yml")
assert_contains "$output" "Configuration is valid"
assert_contains "$output" "Layout plan"
echo "ok 3 - dry-run validates nested config"

cat > "$TMP_DIR/invalid-focus.yml" <<YAML
session:
  name: ${TEST_PREFIX}_bad_focus
  initial_focus: missing
layout:
  type: horizontal
  splits:
    - id: editor
      size: 50%
    - id: shell
      size: 50%
YAML
output=$(run_expect_failure "$TMUXIFY" --dry-run --file "$TMP_DIR/invalid-focus.yml")
assert_contains "$output" "does not match any pane id"
echo "ok 4 - invalid initial focus is rejected"

cat > "$TMP_DIR/duplicate.yml" <<YAML
session:
  name: ${TEST_PREFIX}_duplicate
layout:
  type: horizontal
  splits:
    - id: editor
      size: 50%
    - id: editor
      size: 50%
YAML
output=$(run_expect_failure "$TMUXIFY" --dry-run --file "$TMP_DIR/duplicate.yml")
assert_contains "$output" "Duplicate pane id"
echo "ok 5 - duplicate pane IDs are rejected"

run_expect_success "$TMUXIFY" --file "$TMP_DIR/valid.yml" --detach --no-commands >/dev/null
pane_count=$(tmux list-panes -t "${TEST_PREFIX}_nested" | wc -l | tr -d ' ')
[[ "$pane_count" == "4" ]] || fail "expected 4 panes, got $pane_count"
active_pane=$(tmux display-message -p -t "${TEST_PREFIX}_nested" '#{pane_index}')
[[ "$active_pane" == "0" ]] || fail "expected editor pane to be active, got pane $active_pane"
echo "ok 6 - detached nested session creates expected panes and focus"

cat > "$TMP_DIR/base-index.yml" <<YAML
session:
  name: ${TEST_PREFIX}_base_index
  initial_focus: editor
layout:
  type: horizontal
  splits:
    - id: editor
      size: 50%
    - id: shell
      size: 50%
YAML
base_index_sockdir="/tmp/${TEST_PREFIX}_base_index_sock"
rm -rf "$base_index_sockdir"
mkdir -p "$base_index_sockdir"
env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux new-session -d -s "${TEST_PREFIX}_keepalive"
env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux set-option -g base-index 1
env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux set-window-option -g pane-base-index 1
run_expect_success env -u TMUX TMUX_TMPDIR="$base_index_sockdir" "$TMUXIFY" --file "$TMP_DIR/base-index.yml" --detach --no-commands >/dev/null
window_index=$(env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux list-windows -t "${TEST_PREFIX}_base_index" -F '#{window_index}')
[[ "$window_index" == "1" ]] || fail "expected first window index 1 with base-index enabled, got $window_index"
pane_count=$(env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux list-panes -t "${TEST_PREFIX}_base_index" | wc -l | tr -d ' ')
[[ "$pane_count" == "2" ]] || fail "expected 2 panes with base-index enabled, got $pane_count"
pane_indices=$(env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux list-panes -t "${TEST_PREFIX}_base_index" -F '#{pane_index}' | paste -sd, -)
[[ "$pane_indices" == "1,2" ]] || fail "expected pane indices 1,2 with pane-base-index enabled, got $pane_indices"
env -u TMUX TMUX_TMPDIR="$base_index_sockdir" tmux kill-server >/dev/null 2>&1 || true
echo "ok 7 - detached session works with tmux base-index 1"

while IFS= read -r example; do
  run_expect_success "$TMUXIFY" --dry-run --file "$example" >/dev/null
done < <(find "$ROOT_DIR/examples/layouts" -type f -name '*.yml' -print | sort)
echo "ok 8 - bundled examples validate"
