#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
export PATH="$ROOT_DIR:$PATH"
# shellcheck source=../completions/tmuxify.bash
source "$ROOT_DIR/completions/tmuxify.bash"
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }

COMP_WORDS=(tmuxify --dr)
COMP_CWORD=1
_tmuxify
[[ ${COMPREPLY[*]:-} == --dry-run ]] || fail 'option completion failed'
echo "ok - option completion works on Bash $BASH_VERSION"

COMP_WORDS=(tmuxify -)
COMP_CWORD=1
_tmuxify
candidates=$(printf '%s\n' "${COMPREPLY[@]}")
while IFS= read -r option; do
  grep -Fxq -- "$option" <<< "$candidates" || fail "missing metadata option $option"
done < <(tmuxify --completion-options | tr '|:' '\n' | grep '^-')
echo 'ok - completion includes the CLI metadata options and aliases'

cd "$TEST_DIR"
touch 'layout with spaces.yml' 'layout-other.yaml'
for flag in --file -f --export -e; do
  COMP_WORDS=(tmuxify "$flag" 'layout w')
  COMP_CWORD=2
  _tmuxify
  [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == 'layout with spaces.yml' ]] || fail "$flag split or lost a spaced filename"

  COMP_WORDS=(tmuxify --detach "$flag" layout)
  COMP_CWORD=3
  _tmuxify
  [[ ${#COMPREPLY[@]} -eq 2 ]] || fail "$flag did not complete at a later cursor position"
done
echo 'ok - long and short file options preserve filenames containing spaces'

COMP_WORDS=(tmuxify --file missing)
COMP_CWORD=2
_tmuxify
[[ -z ${COMPREPLY[*]:-} ]] || fail 'unmatched filename retained stale candidates'
COMP_WORDS=(tmuxify --does-not-exist)
COMP_CWORD=1
_tmuxify
[[ -z ${COMPREPLY[*]:-} ]] || fail 'unmatched option retained stale candidates'
COMP_WORDS=(tmuxify '')
COMP_CWORD=1
_tmuxify
[[ -z ${COMPREPLY[*]:-} ]] || fail 'empty argument retained stale candidates'
echo 'ok - unmatched and empty arguments reset completion candidates'
