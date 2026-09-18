#!/usr/bin/env bash

proposed_session() {
  "$TMUXIFY" --dry-run --file "$1" | awk '/^Proposed tmux session: / { print $4 }'
}

# Public tmux-state lookup for fixtures with a named workspace. Never compute
# the production naming algorithm here: test ownership and target actual state.
workspace_session() {
  local native metadata match result count
  result=""
  count=0
  while IFS= read -r native; do
    metadata=$(tmux show-options -qv -t "$native" @tmuxify_workspace_identity)
    [[ -n $metadata ]] || continue
    match=$(printf '%s' "$metadata" | EXPECTED_WORKSPACE="$1" yq -p=json -r '.[2] == "named" and .[3] == strenv(EXPECTED_WORKSPACE)')
    if [[ $match == true ]]; then
      result=$(tmux display-message -p -t "$native" '#{session_name}')
      count=$((count + 1))
    fi
  done < <(tmux list-sessions -F '#{session_id}')
  [[ $count == 1 ]] || { printf 'Expected one workspace named %s, found %s\n' "$1" "$count" >&2; return 1; }
  printf '%s\n' "$result"
}

default_workspace_session() {
  local native metadata expected
  expected=$(cd "$1" && env pwd -P) || return 1
  while IFS= read -r native; do
    metadata=$(tmux show-options -qv -t "$native" @tmuxify_workspace_identity)
    [[ -n $metadata ]] || continue
    if [[ $(printf '%s' "$metadata" | EXPECTED_ROOT="$expected" yq -p=json -r '.[2] == "default" and .[1] == strenv(EXPECTED_ROOT)') == true ]]; then
      tmux display-message -p -t "$native" '#{session_name}'
      return
    fi
  done < <(tmux list-sessions -F '#{session_id}')
  return 1
}
