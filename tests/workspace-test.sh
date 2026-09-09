#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMUXIFY="$ROOT_DIR/tmuxify"
TEST_DIR=$(mktemp -d /tmp/tmuxify-workspace.XXXXXX)
export HOME="$TEST_DIR/home" XDG_CONFIG_HOME="$TEST_DIR/config" TMPDIR="$TEST_DIR/tmp" TMUX_TMPDIR="$TEST_DIR"
unset TMUX TMUX_PANE
mkdir -p "$HOME" "$TMPDIR" "$TEST_DIR/bin" "$TEST_DIR/project"
cleanup() {
  tmux kill-server >/dev/null 2>&1 || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }

tmux -f /dev/null new-session -d -s keepalive -x 161 -y 81
tmux set-option -g default-shell /bin/bash
# Keep host login profiles out of the controlled pane environment.
tmux set-option -g default-command 'exec /bin/bash --noprofile --norc'
tmux set-option -g default-size 161x81
cat > "$TEST_DIR/bin/nvim" <<'SH'
#!/bin/sh
printf 'editor started\n' > "$HOME/editor-started"
sleep 60
SH
chmod +x "$TEST_DIR/bin/nvim"
export PATH="$TEST_DIR/bin:$PATH"
cd "$TEST_DIR/project"

"$TMUXIFY" --detach --no-commands > "$TEST_DIR/output"
[[ ! -e "$HOME/editor-started" ]] || fail '--no-commands launched the built-in editor'
[[ $(tmux list-panes -t '=project' | wc -l) -eq 4 ]] || fail 'expected four default panes'
[[ $(tmux display-message -p -t '=project:' '#{pane_index}') -eq 0 ]] || fail 'expected editor focus'
for pane in $(tmux list-panes -t '=project' -F '#{pane_id}'); do
  text=$(tmux capture-pane -p -t "$pane")
  [[ $text != *'Top Right Pane'* && $text != *'Bottom Right'* ]] || fail '--no-commands sent built-in commands'
done
echo 'ok - built-in workspace suppresses commands and retains structure and focus'

mkdir "$TEST_DIR/editor-project"
(cd "$TEST_DIR/editor-project" && "$TMUXIFY" --detach > "$TEST_DIR/output")
for _ in {1..100}; do [[ -e "$HOME/editor-started" ]] && break; sleep 0.05; done
[[ -e "$HOME/editor-started" ]] || fail 'normal default startup did not launch an available editor'
tmux kill-session -t '=editor-project'
rm "$HOME/editor-started"

real_tmux=$(command -v tmux)
cat > "$TEST_DIR/bin/tmux" <<'SH'
#!/bin/sh
printf 'tmux contacted\n' > "$HOME/tmux-contacted"
exit 1
SH
chmod +x "$TEST_DIR/bin/tmux"
"$TMUXIFY" --dry-run --no-commands > "$TEST_DIR/preview"
[[ ! -e "$HOME/tmux-contacted" && ! -e "$HOME/editor-started" ]] || fail 'preview had side effects'
grep -q 'command=.*nvim' "$TEST_DIR/preview" || fail 'preview omitted built-in editor command'
grep -q 'id=terminal' "$TEST_DIR/preview" || fail 'preview omitted built-in panes'
grep -q 'Commands: disabled' "$TEST_DIR/preview" || fail 'preview omitted command suppression'
rm "$TEST_DIR/bin/tmux"
hash -r

tmux kill-session -t '=project'
mkdir "$TEST_DIR/pane-bin"
ln -s /usr/bin/clear "$TEST_DIR/pane-bin/clear"
# tmux can inject the creating client's PATH even when its global PATH differs.
# Set the absent-tool PATH inside the pane shell, without changing CLI dependencies.
tmux set-option -g default-command "export PATH='$TEST_DIR/pane-bin'; exec /bin/bash --noprofile --norc"
"$TMUXIFY" --detach > "$TEST_DIR/output"
editor=$(tmux list-panes -t '=project' -F '#{pane_id}' | head -n 1)
fallback_message='Install Neovim or use this shell for your editor.'
for _ in {1..100}; do
  text=$(tmux capture-pane -p -t "$editor")
  grep -Fxq "$fallback_message" <<< "$text" && break
  sleep 0.05
done
grep -Fxq "$fallback_message" <<< "$text" || fail "missing-editor fallback was not usable; pane contents: $text"
[[ ! -e "$HOME/editor-started" ]] || fail 'missing-editor fixture launched the editor stub'
[[ $(tmux list-panes -t '=project' | wc -l) -eq 4 ]] || fail 'missing editor removed a pane'
tmux set-option -g default-command 'exec /bin/bash --noprofile --norc'
echo 'ok - built-in preview is safe and normal startup needs no Neovim'

cat > "$TEST_DIR/session.yml" <<'YAML'
session:
  name: api
layout:
  type: horizontal
  splits:
    - id: shell
YAML
tmux new-session -d -s api-worker -n Existing
"$TMUXIFY" --detach --no-commands --file "$TEST_DIR/session.yml" > "$TEST_DIR/output"
tmux has-session -t '=api' || fail 'prefix match prevented exact session creation'
tmux kill-session -t '=api'
tmux new-session -d -s api-server -n Unrelated
"$TMUXIFY" --detach --no-commands --file "$TEST_DIR/session.yml" > "$TEST_DIR/output"
tmux has-session -t '=api' || fail 'multiple prefix matches prevented session creation'
tmux rename-window -t '=api:' Preserved
"$TMUXIFY" --detach --file "$TEST_DIR/session.yml" > "$TEST_DIR/output"
[[ $(tmux list-windows -t '=api' -F '#{window_name}') == Preserved ]] || fail 'exact reuse rebuilt a session'
[[ $(tmux list-windows -t '=api-worker' -F '#{window_name}') == Existing ]] || fail 'changed prefix session'
[[ $(tmux list-windows -t '=api-server' -F '#{window_name}') == Unrelated ]] || fail 'changed unrelated session'
echo 'ok - only exactly matching sessions are reused'

cat > "$TEST_DIR/geometry.yml" <<'YAML'
session:
  name: geometry
layout:
  type: horizontal
  splits:
    - id: editor
      size: 60%
    - type: vertical
      size: 40%
      splits:
        - id: top
          size: 50%
        - type: horizontal
          size: 50%
          splits:
            - id: left
              size: 50%
            - id: right
              size: 50%
YAML
"$TMUXIFY" --detach --no-commands --file "$TEST_DIR/geometry.yml" > "$TEST_DIR/output"
geometry=$(tmux list-panes -t '=geometry' -F '#{pane_width} #{pane_height} #{pane_left} #{pane_top}')
printf '%s\n' "$geometry" | awk '
  NR == 1 { if ($1 < 95 || $1 > 97) exit 1 }
  NR == 2 { top_height=$2 }
  NR == 3 { left_width=$1; bottom_height=$2 }
  NR == 4 { if ($1 < 30 || $1 > 33 || left_width-$1 > 1 || $1-left_width > 1 || top_height-bottom_height > 1 || bottom_height-top_height > 1) exit 1 }
  END { if (NR != 4) exit 1 }
' || fail "nested parent-relative 50/50 geometry is wrong: $geometry"
echo 'ok - nested horizontal and vertical sizes use their parent dimensions'

for scenario in final mixed automatic oversubscribed; do
  case "$scenario" in
    final) sizes=$'    - id: first\n    - id: last\n      size: 75%' ;;
    mixed) sizes=$'    - id: first\n      size: 25%\n    - id: middle\n    - id: last\n      size: 25%' ;;
    automatic) sizes=$'    - id: first\n    - id: middle\n    - id: last' ;;
    oversubscribed) sizes=$'    - id: first\n      size: 100%\n    - id: middle\n      size: 100%\n    - id: last' ;;
  esac
  printf 'session:\n  name: %s\nlayout:\n  type: horizontal\n  splits:\n%s\n' "$scenario" "$sizes" > "$TEST_DIR/sizing.yml"
  "$TMUXIFY" --detach --no-commands --file "$TEST_DIR/sizing.yml" > "$TEST_DIR/output"
  widths=$(tmux list-panes -t "=$scenario" -F '#{pane_width}' | paste -sd, -)
  case "$scenario:$widths" in
    final:40,120|mixed:39,80,40|automatic:53,53,53|oversubscribed:79,79,1) ;;
    *) fail "unexpected $scenario allocation: $widths" ;;
  esac
done
echo 'ok - final sizes, omitted sizes, and infeasible ratios have deterministic allocations'

# Attachment is an external boundary: inspect the handoff without needing a TTY.
export TMUXIFY_REAL_TMUX="$real_tmux"
cat > "$TEST_DIR/bin/tmux" <<'SH'
#!/usr/bin/env bash
case "$1" in
  attach|switch-client)
    printf '%s\n' "$@" > "$HOME/handoff"
    find "$TMPDIR" -type f > "$HOME/handoff-files"
    exit "${TMUXIFY_ATTACH_STATUS:-0}"
    ;;
esac
if [[ "$1" == "${TMUXIFY_INTERRUPT_AT:-}" ]]; then
  "$TMUXIFY_REAL_TMUX" "$@" || exit $?
  if [[ -n "${TMUXIFY_RENAME_DURING_CREATION:-}" ]]; then
    "$TMUXIFY_REAL_TMUX" rename-session -t '=interrupted' renamed-owned
    "$TMUXIFY_REAL_TMUX" new-session -d -s interrupted -n Replacement
  fi
  kill -s "$TMUXIFY_SIGNAL" "$PPID"
  exit 0
fi
if [[ "$1" == "${TMUXIFY_FAIL_AT:-}" ]]; then exit 1; fi
exec "$TMUXIFY_REAL_TMUX" "$@"
SH
chmod +x "$TEST_DIR/bin/tmux"
"$TMUXIFY" --file "$TEST_DIR/session.yml" > "$TEST_DIR/output"
[[ ! -s "$HOME/handoff-files" ]] || fail 'attachment leaked temporary files'
grep -qx '=api' "$HOME/handoff" || fail 'attachment did not use an exact session target'
TMUX=simulated "$TMUXIFY" --file "$TEST_DIR/session.yml" > "$TEST_DIR/output"
[[ ! -s "$HOME/handoff-files" ]] || fail 'client switching leaked temporary files'
grep -qx 'switch-client' "$HOME/handoff" || fail 'expected client switch'
grep -qx '=api' "$HOME/handoff" || fail 'client switching did not use an exact target'
echo 'ok - attachment and switching clean temporary files before exact-target handoff'

sed 's/name: api/name: interrupted/' "$TEST_DIR/session.yml" > "$TEST_DIR/interrupted.yml"
for point in new-session set-window-option; do
  for signal in HUP INT TERM; do
    if TMUXIFY_INTERRUPT_AT="$point" TMUXIFY_SIGNAL="$signal" "$TMUXIFY" --detach --no-commands --file "$TEST_DIR/interrupted.yml" > "$TEST_DIR/output" 2>&1; then
      fail "$signal at $point unexpectedly succeeded"
    fi
    if tmux has-session -t '=interrupted' 2>/dev/null; then fail "$signal at $point left an unfinished session"; fi
    [[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail "$signal at $point leaked temporary state"
    tmux has-session -t '=api-worker' || fail 'interruption removed an unrelated session'
    tmux has-session -t '=api' || fail 'interruption removed an existing session'
  done
done
if TMUXIFY_FAIL_AT=set-window-option "$TMUXIFY" --detach --file "$TEST_DIR/interrupted.yml" > "$TEST_DIR/output" 2>&1; then
  fail 'construction failure unexpectedly succeeded'
fi
if tmux has-session -t '=interrupted' 2>/dev/null; then fail 'construction failure left an unfinished session'; fi
[[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'construction failure leaked temporary state'
echo 'ok - signals and structural failures roll back only unfinished owned sessions'

if TMUXIFY_ATTACH_STATUS=7 "$TMUXIFY" --no-commands --file "$TEST_DIR/interrupted.yml" > "$TEST_DIR/output" 2>&1; then
  fail 'attachment failure unexpectedly succeeded'
fi
tmux has-session -t '=interrupted' || fail 'attachment failure removed a completed workspace'
[[ ! -s "$HOME/handoff-files" ]] || fail 'new-session attachment leaked temporary state'
"$TMUXIFY" --dry-run --file "$TEST_DIR/interrupted.yml" > "$TEST_DIR/output"
[[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'dry-run leaked temporary state'
echo 'ok - completed workspaces survive attachment failure and dry-run cleans up'

tmux kill-session -t '=interrupted'
if TMUXIFY_INTERRUPT_AT=new-session TMUXIFY_SIGNAL=TERM TMUXIFY_RENAME_DURING_CREATION=1 "$TMUXIFY" --detach --file "$TEST_DIR/interrupted.yml" > "$TEST_DIR/output" 2>&1; then
  fail 'interrupted renamed creation unexpectedly succeeded'
fi
if tmux has-session -t '=renamed-owned' 2>/dev/null; then fail 'rollback lost track of the renamed owned session'; fi
[[ $(tmux list-windows -t '=interrupted' -F '#{window_name}') == Replacement ]] || fail 'rollback removed a replacement session with the same name'
echo 'ok - rollback follows native session identity across a rename'

cat > "$TEST_DIR/vertical.yml" <<'YAML'
session:
  name: vertical
  initial_focus: bottom
windows:
  - id: workspace
    name: Sizes
    layout:
      type: vertical
      splits:
        - id: editor
          size: 60%
        - type: horizontal
          size: 40%
          splits:
            - id: left
              size: 50%
            - type: vertical
              size: 50%
              splits:
                - id: top
                  size: 50%
                - id: bottom
                  size: 50%
YAML
"$TMUXIFY" --detach --no-commands --file "$TEST_DIR/vertical.yml" > "$TEST_DIR/output"
heights=$(tmux list-panes -t '=vertical' -F '#{pane_height}' | paste -sd, -)
[[ $heights == 48,32,15,16 ]] || fail "nested explicit-window vertical geometry is wrong: $heights"
[[ $(tmux display-message -p -t '=vertical:' '#{pane_index}') -eq 3 ]] || fail 'geometry changes lost explicit-window focus'
tmux set-option -g default-size 4x4
sed 's/name: oversubscribed/name: too-small/' "$TEST_DIR/sizing.yml" > "$TEST_DIR/small.yml"
if "$TMUXIFY" --detach --no-commands --file "$TEST_DIR/small.yml" > "$TEST_DIR/output" 2>&1; then fail 'physically impossible layout unexpectedly succeeded'; fi
grep -q 'Not enough room' "$TEST_DIR/output" || fail 'impossible layout did not explain the size limit'
if tmux has-session -t '=too-small' 2>/dev/null; then fail 'impossible layout left an unfinished session'; fi
[[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'impossible layout leaked temporary state'
echo 'ok - explicit-window vertical geometry preserves focus and impossible layouts fail cleanly'
