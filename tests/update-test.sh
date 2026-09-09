#!/usr/bin/env bash
set -euo pipefail
umask 022

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d /tmp/tmuxify-update-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT
export HOME="$TEST_DIR/home" XDG_CONFIG_HOME="$TEST_DIR/config" TMPDIR="$TEST_DIR/tmp"
mkdir -p "$HOME" "$TMPDIR" "$TEST_DIR/install" "$TEST_DIR/archive/tmuxify/examples/layouts" "$TEST_DIR/archive/tmuxify/completions"
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }

printf 'layout: {type: horizontal, splits: [{id: shell}]}\n' > "$TEST_DIR/archive/tmuxify/examples/layouts/example.yml"
cp "$ROOT_DIR"/completions/* "$TEST_DIR/archive/tmuxify/completions/"
(cd "$TEST_DIR/archive" && tar -czf "$TEST_DIR/assets.tar.gz" tmuxify)
export TMUXIFY_EXAMPLES_ARCHIVE_URL="file://$TEST_DIR/assets.tar.gz"
export TMUXIFY_COMPLETIONS_ARCHIVE_URL="$TMUXIFY_EXAMPLES_ARCHIVE_URL"
export TMUXIFY_REPO_URL="file://$TEST_DIR/candidate"

cp "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify"
printf '#!/usr/bin/env bash\nVERSION="9.9.9"\nif (\n' > "$TEST_DIR/candidate"
if "$TEST_DIR/install/tmuxify" --update > "$TEST_DIR/output" 2>&1; then
  fail 'syntactically invalid candidate replaced a working installation'
fi
cmp -s "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify" || fail 'rejected candidate changed the installation'
echo 'ok - update rejects invalid Bash before replacing the installation'

for invalid in empty not-script wrong-shell missing-version malformed-version duplicate-version; do
  case "$invalid" in
    empty) : > "$TEST_DIR/candidate" ;;
    not-script) printf 'VERSION="9.9.9"\n' > "$TEST_DIR/candidate" ;;
    wrong-shell) printf '#!/bin/sh\nVERSION="9.9.9"\n' > "$TEST_DIR/candidate" ;;
    missing-version) printf '#!/usr/bin/env bash\necho missing\n' > "$TEST_DIR/candidate" ;;
    malformed-version) printf '#!/usr/bin/env bash\nVERSION="9..9"\n' > "$TEST_DIR/candidate" ;;
    duplicate-version) printf '#!/usr/bin/env bash\nVERSION="9.9.9"\nVERSION="1.2.3"\n' > "$TEST_DIR/candidate" ;;
  esac
  if "$TEST_DIR/install/tmuxify" --update > "$TEST_DIR/output" 2>&1; then fail "$invalid candidate was accepted"; fi
  cmp -s "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify" || fail "$invalid candidate changed the installation"
  grep -q 'Error:' "$TEST_DIR/output" || fail 'rejection had no error message'
  [[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'rejected update leaked temporary files'
done

cat > "$TEST_DIR/candidate" <<'SH'
#!/usr/bin/env bash
VERSION="9.9.9"
printf 'candidate executed\n' > "$HOME/candidate-executed"
SH
"$TEST_DIR/install/tmuxify" --update > "$TEST_DIR/output"
cmp -s "$TEST_DIR/candidate" "$TEST_DIR/install/tmuxify" || fail 'valid candidate was not installed'
[[ -x "$TEST_DIR/install/tmuxify" ]] || fail 'installed candidate is not executable'
[[ -n $(find "$TEST_DIR/install/tmuxify" -perm 0755 -print) ]] || fail 'staging changed script readability'
[[ ! -e "$HOME/candidate-executed" ]] || fail 'validation executed the downloaded program'
[[ -f "$XDG_CONFIG_HOME/tmuxify/layouts/examples/example.yml" ]] || fail 'update omitted examples'
[[ -f "$XDG_CONFIG_HOME/tmuxify/completions/tmuxify.bash" && -f "$XDG_CONFIG_HOME/tmuxify/completions/_tmuxify" ]] || fail 'update omitted completions'
grep -q 'version 9.9.9' "$TEST_DIR/output" || fail 'update reported wrong version'
[[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'successful update leaked temporary files'
echo 'ok - candidate metadata is validated without execution and assets still refresh'

mkdir "$TEST_DIR/bin"
export TMUXIFY_REAL_MV
TMUXIFY_REAL_MV=$(command -v mv)
export TMUXIFY_TEST_INSTALL="$TEST_DIR/install/tmuxify"
cat > "$TEST_DIR/bin/mv" <<'SH'
#!/usr/bin/env bash
if [[ "$2" == "$TMUXIFY_TEST_INSTALL" ]]; then
  case "$1" in
    *backup*|*.bak.*)
      [[ "$TMUXIFY_MOVE_FAILURE" == rollback ]] && exit 1
      ;;
    *)
      if [[ "$TMUXIFY_MOVE_FAILURE" != before ]]; then "$TMUXIFY_REAL_MV" "$@" || exit $?; fi
      exit 1
      ;;
  esac
fi
exec "$TMUXIFY_REAL_MV" "$@"
SH
chmod +x "$TEST_DIR/bin/mv"
for failure in before after rollback; do
  cp "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify"
  if PATH="$TEST_DIR/bin:$PATH" TMUXIFY_MOVE_FAILURE="$failure" "$TEST_DIR/install/tmuxify" --update > "$TEST_DIR/output" 2>&1; then
    fail 'replacement failure unexpectedly succeeded'
  fi
  if [[ "$failure" == rollback ]]; then
    grep -q 'backup retained at' "$TEST_DIR/output" || fail 'failed rollback did not report retained recovery backup'
    backup=$(find "$TEST_DIR/install" -type f ! -name tmuxify | head -n 1)
    [[ -n "$backup" ]] || fail 'failed rollback lost the recovery backup'
    cmp -s "$ROOT_DIR/tmuxify" "$backup" || fail 'failed rollback lost the previous installation'
    rm "$backup"
  else
    cmp -s "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify" || fail 'replacement failure did not preserve previous installation'
    [[ $(find "$TEST_DIR/install" -type f | wc -l) -eq 1 ]] || fail 'recoverable failure leaked staging or backup files'
  fi
  [[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'replacement failure leaked download files'
done
echo 'ok - replacement failures recover or explicitly retain the previous installation'

export TMUXIFY_REAL_CHMOD
TMUXIFY_REAL_CHMOD=$(command -v chmod)
cat > "$TEST_DIR/bin/chmod" <<'SH'
#!/usr/bin/env bash
case "$*" in *.tmuxify-update.*) exit 1 ;; esac
exec "$TMUXIFY_REAL_CHMOD" "$@"
SH
chmod +x "$TEST_DIR/bin/chmod"
cp "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify"
if PATH="$TEST_DIR/bin:$PATH" "$TEST_DIR/install/tmuxify" --update > "$TEST_DIR/output" 2>&1; then
  fail 'staging permission failure unexpectedly succeeded'
fi
cmp -s "$ROOT_DIR/tmuxify" "$TEST_DIR/install/tmuxify" || fail 'staging failure changed installed script'
[[ $(find "$TEST_DIR/install" -type f | wc -l) -eq 1 ]] || fail 'staging failure leaked install artifacts'
[[ -z $(find "$TMPDIR" -mindepth 1 -print) ]] || fail 'staging failure leaked download files'
echo 'ok - executable permissions are prepared before replacement'
