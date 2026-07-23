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
  if [ -d "/tmp/${TEST_PREFIX}_base_index_sock" ]; then
    env -u TMUX TMUX_TMPDIR="/tmp/${TEST_PREFIX}_base_index_sock" tmux kill-server >/dev/null 2>&1 || true
  fi
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

echo "1..18"

output=$(run_expect_success "$TMUXIFY" --help)
assert_contains "$output" "--dry-run"
assert_contains "$output" "--no-commands"
assert_contains "$output" "--list-layouts"
echo "ok 1 - help documents safe workflow flags"

completion_options=$(run_expect_success "$TMUXIFY" --completion-options)
while IFS= read -r flag; do
  [[ -z "$flag" ]] && continue
  assert_contains "$completion_options" "$flag"
done < <(printf '%s\n' "$output" | grep -oE -- '--[a-z0-9-]+' | sort -u)
bash -n "$ROOT_DIR/completions/tmuxify.bash"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$ROOT_DIR/completions/_tmuxify"
fi
echo "ok 2 - completion metadata covers help flags and scripts parse"

expected_version=$(<"$ROOT_DIR/VERSION")
output=$(run_expect_success "$TMUXIFY" --version)
assert_contains "$output" "tmuxify version $expected_version"
echo "ok 3 - version works"

stale_install_dir="$TMP_DIR/stale-install"
mkdir -p "$stale_install_dir"
cp "$TMUXIFY" "$stale_install_dir/tmuxify"
echo "0.0.0" > "$stale_install_dir/VERSION"
output=$(run_expect_success "$stale_install_dir/tmuxify" --version)
assert_contains "$output" "tmuxify version $expected_version"
echo "ok 4 - script version ignores stale sidecar VERSION file"

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
echo "ok 5 - dry-run validates nested config"

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
echo "ok 6 - invalid initial focus is rejected"

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
echo "ok 7 - duplicate pane IDs are rejected"

run_expect_success "$TMUXIFY" --file "$TMP_DIR/valid.yml" --detach --no-commands >/dev/null
pane_count=$(tmux list-panes -t "${TEST_PREFIX}_nested" | wc -l | tr -d ' ')
[[ "$pane_count" == "4" ]] || fail "expected 4 panes, got $pane_count"
active_pane=$(tmux display-message -p -t "${TEST_PREFIX}_nested" '#{pane_index}')
first_pane=$(tmux list-panes -t "${TEST_PREFIX}_nested" -F '#{pane_index}' | head -n 1)
[[ "$active_pane" == "$first_pane" ]] || fail "expected editor pane to be active, got pane $active_pane"
echo "ok 8 - detached nested session creates expected panes and focus"

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
echo "ok 9 - detached session works with tmux base-index 1"

xdg_home="$TMP_DIR/xdg"
global_project="$TMP_DIR/global-project"
mkdir -p "$xdg_home/tmuxify/layouts" "$global_project"
cat > "$xdg_home/tmuxify/layouts/default.yml" <<YAML
session:
  name: ${TEST_PREFIX}_global_default
layout:
  type: horizontal
  splits:
    - id: global_editor
      size: 50%
    - id: global_shell
      size: 50%
YAML
output=$(run_expect_success env XDG_CONFIG_HOME="$xdg_home" bash -c 'cd "$1" && "$2" --dry-run' _ "$global_project" "$TMUXIFY")
assert_contains "$output" "Using global default layout file"
assert_contains "$output" "Session: ${TEST_PREFIX}_global_default"
echo "ok 10 - global default layout is used when project config is absent"

cat > "$global_project/.tmuxify.yml" <<YAML
session:
  name: ${TEST_PREFIX}_project_override
layout:
  type: horizontal
  splits:
    - id: project_editor
      size: 50%
    - id: project_shell
      size: 50%
YAML
output=$(run_expect_success env XDG_CONFIG_HOME="$xdg_home" bash -c 'cd "$1" && "$2" --dry-run' _ "$global_project" "$TMUXIFY")
assert_contains "$output" "Session: ${TEST_PREFIX}_project_override"
echo "ok 11 - project layout overrides global default layout"

cat > "$TMP_DIR/file-override.yml" <<YAML
session:
  name: ${TEST_PREFIX}_file_override
layout:
  type: horizontal
  splits:
    - id: file_editor
      size: 50%
    - id: file_shell
      size: 50%
YAML
output=$(run_expect_success env XDG_CONFIG_HOME="$xdg_home" bash -c 'cd "$1" && "$2" --dry-run --file "$3"' _ "$global_project" "$TMUXIFY" "$TMP_DIR/file-override.yml")
assert_contains "$output" "Session: ${TEST_PREFIX}_file_override"
echo "ok 12 - explicit file layout overrides project and global layouts"

update_install_dir="$TMP_DIR/update-install"
update_xdg_home="$TMP_DIR/update-xdg"
archive_root="$TMP_DIR/archive/tmuxify-main/examples/layouts"
archive_completions="$TMP_DIR/archive/tmuxify-main/completions"
mkdir -p "$update_install_dir" "$archive_root" "$archive_completions"
cp "$TMUXIFY" "$update_install_dir/tmuxify"
chmod +x "$update_install_dir/tmuxify"
cat > "$archive_root/example.yml" <<YAML
session:
  name: archive_example
layout:
  type: horizontal
  splits:
    - id: editor
      size: 50%
    - id: shell
      size: 50%
YAML
cp "$ROOT_DIR/completions/tmuxify.bash" "$archive_completions/tmuxify.bash"
cp "$ROOT_DIR/completions/_tmuxify" "$archive_completions/_tmuxify"
(cd "$TMP_DIR/archive" && tar -czf "$TMP_DIR/examples.tar.gz" tmuxify-main)
output=$(run_expect_success env XDG_CONFIG_HOME="$update_xdg_home" TMUXIFY_REPO_URL="file://$TMUXIFY" TMUXIFY_EXAMPLES_ARCHIVE_URL="file://$TMP_DIR/examples.tar.gz" TMUXIFY_COMPLETIONS_ARCHIVE_URL="file://$TMP_DIR/examples.tar.gz" "$update_install_dir/tmuxify" --update)
assert_contains "$output" "Example layouts installed"
assert_contains "$output" "Completions installed"
[[ -d "$update_xdg_home/tmuxify/layouts" ]] || fail "expected update to create layouts directory"
[[ -f "$update_xdg_home/tmuxify/layouts/examples/example.yml" ]] || fail "expected update to install example layouts"
[[ -f "$update_xdg_home/tmuxify/completions/tmuxify.bash" ]] || fail "expected update to install bash completions"
[[ -f "$update_xdg_home/tmuxify/completions/_tmuxify" ]] || fail "expected update to install zsh completions"
echo "ok 13 - update creates config folders and refreshes examples and completions"

output=$(run_expect_success env XDG_CONFIG_HOME="$update_xdg_home" bash -c 'cd "$1" && "$2" --list-layouts' _ "$global_project" "$TMUXIFY")
assert_contains "$output" "Available tmuxify layouts"
assert_contains "$output" "project"
assert_contains "$output" "example"
assert_contains "$output" "example.yml"
echo "ok 14 - list-layouts shows project and user layouts"

while IFS= read -r example; do
  run_expect_success "$TMUXIFY" --dry-run --file "$example" >/dev/null
done < <(find "$ROOT_DIR/examples/layouts" -type f -name '*.yml' -print | sort)
echo "ok 15 - bundled examples validate"

run_expect_success env PATH="/usr/bin:/bin" "$TMUXIFY" --completion-options >/dev/null
echo "ok 16 - completion metadata does not require optional dependencies"

cat > "$TMP_DIR/one-window.yml" <<YAML
session:
  name: ${TEST_PREFIX}_one_window
  initial_focus: workspace
windows:
  - id: workspace
    name: Development
    layout:
      type: horizontal
      splits:
        - id: editor
          size: 60%
        - id: shell
          size: 40%
YAML
output=$(run_expect_success "$TMUXIFY" --dry-run --file "$TMP_DIR/one-window.yml")
assert_contains "$output" "Window: workspace (Development)"
run_expect_success "$TMUXIFY" --file "$TMP_DIR/one-window.yml" --detach --no-commands >/dev/null
window_count=$(tmux list-windows -t "${TEST_PREFIX}_one_window" | wc -l | tr -d ' ')
[[ "$window_count" == "1" ]] || fail "expected one configured window, got $window_count"
window_name=$(tmux display-message -p -t "${TEST_PREFIX}_one_window" '#{window_name}')
[[ "$window_name" == "Development" ]] || fail "expected configured window name Development, got $window_name"
pane_count=$(tmux list-panes -t "${TEST_PREFIX}_one_window" | wc -l | tr -d ' ')
[[ "$pane_count" == "2" ]] || fail "expected 2 panes in configured window, got $pane_count"
active_pane=$(tmux display-message -p -t "${TEST_PREFIX}_one_window" '#{pane_id}')
first_pane=$(tmux list-panes -t "${TEST_PREFIX}_one_window" -F '#{pane_id}' | head -n 1)
[[ "$active_pane" == "$first_pane" ]] || fail "expected window focus to select its first pane"

for invalid_case in empty nonsequence mixed missing badid badname nolayout collision duplicate_windows cross_window_collision; do
  case "$invalid_case" in
    empty) invalid_yaml='windows: []' ;;
    nonsequence) invalid_yaml='windows: invalid' ;;
    mixed) invalid_yaml=$'layout:\n  type: horizontal\n  splits:\n    - id: editor\nwindows:\n  - id: workspace\n    name: Development\n    layout:\n      type: horizontal\n      splits:\n        - id: shell' ;;
    missing) invalid_yaml=$'session:\n  name: invalid' ;;
    badid) invalid_yaml=$'windows:\n  - id: 1bad\n    name: Development\n    layout:\n      type: horizontal\n      splits:\n        - id: editor' ;;
    badname) invalid_yaml=$'windows:\n  - id: workspace\n    name: ""\n    layout:\n      type: horizontal\n      splits:\n        - id: editor' ;;
    nolayout) invalid_yaml=$'windows:\n  - id: workspace\n    name: Development' ;;
    collision) invalid_yaml=$'windows:\n  - id: workspace\n    name: Development\n    layout:\n      type: horizontal\n      splits:\n        - id: workspace' ;;
    duplicate_windows) invalid_yaml=$'windows:\n  - id: shared\n    name: Development\n    layout:\n      type: horizontal\n      splits:\n        - id: editor\n  - id: shared\n    name: Operations\n    layout:\n      type: vertical\n      splits:\n        - id: monitor' ;;
    cross_window_collision) invalid_yaml=$'windows:\n  - id: workspace\n    name: Development\n    layout:\n      type: horizontal\n      splits:\n        - id: shared\n  - id: shared\n    name: Operations\n    layout:\n      type: vertical\n      splits:\n        - id: monitor' ;;
  esac
  printf '%s\n' "$invalid_yaml" > "$TMP_DIR/one-window-${invalid_case}.yml"
  run_expect_failure "$TMUXIFY" --dry-run --file "$TMP_DIR/one-window-${invalid_case}.yml" >/dev/null
done
fallback_dir="$TMP_DIR/fallback"
fallback_xdg="$TMP_DIR/fallback-xdg"
mkdir -p "$fallback_dir" "$fallback_xdg"
output=$(run_expect_success env XDG_CONFIG_HOME="$fallback_xdg" bash -c 'cd "$1" && "$2" --dry-run' _ "$fallback_dir" "$TMUXIFY")
assert_contains "$output" "default 4-pane workspace"
echo "ok 17 - public CLI supports one explicit named window and rejects invalid schema forms"

cat > "$TMP_DIR/multi-window.yml" <<YAML
session:
  name: ${TEST_PREFIX}_multi_window
  initial_focus: logs
windows:
  - id: workspace
    name: Development
    layout:
      type: horizontal
      splits:
        - id: editor
          command: "printf editor > '$TMP_DIR/editor-command'"
        - id: shell
  - id: operations
    name: Operations
    layout:
      type: vertical
      splits:
        - id: monitor
        - type: horizontal
          splits:
            - id: logs
              command: "printf logs > '$TMP_DIR/logs-command'; sleep 30"
            - id: deploy
YAML
output=$(run_expect_success "$TMUXIFY" --dry-run --file "$TMP_DIR/multi-window.yml")
assert_contains "$output" "Window: workspace (Development)"
assert_contains "$output" "Window: operations (Operations)"
assert_contains "$output" "command=printf editor"
assert_contains "$output" "command=printf logs"
run_expect_success "$TMUXIFY" --file "$TMP_DIR/multi-window.yml" --detach >/dev/null
window_names=$(tmux list-windows -t "${TEST_PREFIX}_multi_window" -F '#{window_name}' | paste -sd, -)
[[ "$window_names" == "Development,Operations" ]] || fail "expected windows in declaration order, got $window_names"
pane_counts=$(tmux list-windows -t "${TEST_PREFIX}_multi_window" -F '#{window_id}' | while read -r window; do tmux list-panes -t "$window" -F '#{pane_id}' | wc -l | tr -d ' '; done | paste -sd, -)
[[ "$pane_counts" == "2,3" ]] || fail "expected pane counts 2,3, got $pane_counts"
for marker in editor-command logs-command; do
  for _ in {1..20}; do [[ -f "$TMP_DIR/$marker" ]] && break; sleep 0.05; done
  [[ -f "$TMP_DIR/$marker" ]] || fail "expected routed command marker $marker"
done
active_window=$(tmux display-message -p -t "${TEST_PREFIX}_multi_window" '#{window_name}')
active_pane=$(tmux display-message -p -t "${TEST_PREFIX}_multi_window" '#{pane_id}')
logs_pane=$(tmux list-panes -t "${TEST_PREFIX}_multi_window:Operations" -F '#{pane_id} #{pane_current_command}' | awk '$2 == "sleep" { print $1 }' | head -n 1)
[[ "$active_window" == "Operations" ]] || fail "expected Operations focused, got $active_window"
[[ -n "$logs_pane" && "$active_pane" == "$logs_pane" ]] || fail "expected configured logs pane focused"

sed "s/${TEST_PREFIX}_multi_window/${TEST_PREFIX}_multi_window_safe/" "$TMP_DIR/multi-window.yml" > "$TMP_DIR/multi-window-safe.yml"
rm -f "$TMP_DIR/editor-command" "$TMP_DIR/logs-command"
run_expect_success "$TMUXIFY" --file "$TMP_DIR/multi-window-safe.yml" --detach --no-commands >/dev/null
sleep 0.1
[[ ! -e "$TMP_DIR/editor-command" && ! -e "$TMP_DIR/logs-command" ]] || fail "expected --no-commands to suppress commands in every window"

sed -e '/initial_focus: logs/d' -e "s/${TEST_PREFIX}_multi_window/${TEST_PREFIX}_multi_window_default/" "$TMP_DIR/multi-window.yml" > "$TMP_DIR/multi-window-default.yml"
run_expect_success "$TMUXIFY" --file "$TMP_DIR/multi-window-default.yml" --detach --no-commands >/dev/null
default_window=$(tmux display-message -p -t "${TEST_PREFIX}_multi_window_default" '#{window_name}')
default_active_pane=$(tmux display-message -p -t "${TEST_PREFIX}_multi_window_default" '#{pane_id}')
default_first_pane=$(tmux list-panes -t "${TEST_PREFIX}_multi_window_default:Development" -F '#{pane_id}' | head -n 1)
[[ "$default_window" == "Development" && "$default_active_pane" == "$default_first_pane" ]] || fail "expected omitted focus to restore first window and pane"

sed -e 's/initial_focus: logs/initial_focus: operations/' -e "s/${TEST_PREFIX}_multi_window/${TEST_PREFIX}_multi_window_window_focus/" "$TMP_DIR/multi-window.yml" > "$TMP_DIR/multi-window-window-focus.yml"
run_expect_success "$TMUXIFY" --file "$TMP_DIR/multi-window-window-focus.yml" --detach --no-commands >/dev/null
window_focus_window=$(tmux display-message -p -t "${TEST_PREFIX}_multi_window_window_focus" '#{window_name}')
window_focus_active_pane=$(tmux display-message -p -t "${TEST_PREFIX}_multi_window_window_focus" '#{pane_id}')
window_focus_first_pane=$(tmux list-panes -t "${TEST_PREFIX}_multi_window_window_focus:Operations" -F '#{pane_id}' | head -n 1)
[[ "$window_focus_window" == "Operations" && "$window_focus_active_pane" == "$window_focus_first_pane" ]] || fail "expected operations window ID to focus its first pane"

echo "ok 18 - public CLI builds multiple windows, validates IDs, routes commands, and focuses across windows"
