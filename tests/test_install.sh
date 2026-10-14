#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
INSTALLER="$REPO_DIR/scripts/install.sh"

FIXTURE_PARENT=${TMPDIR:-/tmp}
FIXTURE_ROOT=$(mktemp -d "$FIXTURE_PARENT/milk-dragon-install-tests.XXXXXX")
case "$FIXTURE_ROOT" in
  "$FIXTURE_PARENT"/milk-dragon-install-tests.*)
    ;;
  *)
    printf '%s\n' "Could not create a safe test fixture." >&2
    exit 1
    ;;
esac

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}

trap cleanup 0
trap 'exit 1' 1 2 15

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

TEST_CODEX_ROOT="$FIXTURE_ROOT/奶龙 codex home"
DESTINATION="$TEST_CODEX_ROOT/pets/milk-dragon"

(
  cd "$FIXTURE_ROOT"
  env CODEX_HOME="$TEST_CODEX_ROOT" sh "$INSTALLER"
)
cmp "$REPO_DIR/pet.json" "$DESTINATION/pet.json"
cmp "$REPO_DIR/spritesheet.webp" "$DESTINATION/spritesheet.webp"

if env CODEX_HOME="$TEST_CODEX_ROOT" sh "$INSTALLER" >"$FIXTURE_ROOT/reinstall.log" 2>&1; then
  fail "A protected reinstall unexpectedly succeeded."
fi
env CODEX_HOME="$TEST_CODEX_ROOT" sh "$INSTALLER" --force
cmp "$REPO_DIR/pet.json" "$DESTINATION/pet.json"
cmp "$REPO_DIR/spritesheet.webp" "$DESTINATION/spritesheet.webp"

# The child shell becomes the installer, preserving its PID. This makes each
# collision deterministic without guessing a future installer process ID.
for FILE_NAME in pet.json spritesheet.webp; do
  CASE_ROOT="$FIXTURE_ROOT/collision $FILE_NAME"
  mkdir -p "$CASE_ROOT/pets/milk-dragon"
  if sh -c '
    set -eu
    temporary="$3/pets/milk-dragon/.$4.install.$$"
    cp "$2" "$temporary"
    printf "%s\n" "$temporary" >"$3/collision-path"
    exec env CODEX_HOME="$3" sh "$1" --force
  ' sh "$INSTALLER" "$REPO_DIR/$FILE_NAME" "$CASE_ROOT" "$FILE_NAME" \
    >"$CASE_ROOT/installer.log" 2>&1; then
    fail "A $FILE_NAME temporary-file collision unexpectedly succeeded."
  fi

  IFS= read -r COLLISION_PATH <"$CASE_ROOT/collision-path"
  test -f "$COLLISION_PATH" || fail "The preexisting $FILE_NAME collision file was deleted."
  cmp "$REPO_DIR/$FILE_NAME" "$COLLISION_PATH" ||
    fail "The preexisting $FILE_NAME collision file was changed."
  grep -F '临时文件名冲突' "$CASE_ROOT/installer.log" >/dev/null ||
    fail "The installer did not report the expected temporary-file collision."
  test ! -e "$CASE_ROOT/pets/milk-dragon/pet.json" ||
    fail "The installer partially installed pet.json after a collision."
  test ! -e "$CASE_ROOT/pets/milk-dragon/spritesheet.webp" ||
    fail "The installer partially installed spritesheet.webp after a collision."
done

for LEFTOVER in "$DESTINATION"/.*.install.*; do
  if [ -e "$LEFTOVER" ] || [ -L "$LEFTOVER" ]; then
    fail "The successful installation left a temporary file."
  fi
done

printf '%s\n' "PASS: install, protected reinstall, forced update, and both temporary-file collision regressions."
