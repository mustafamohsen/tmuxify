#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if ! command -v zsh >/dev/null 2>&1; then
  echo 'ok - zsh completion skipped (zsh unavailable)'
  exit 0
fi
python3 "$ROOT_DIR/tests/zsh-completion.py"
