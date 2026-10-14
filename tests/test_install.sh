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

if env CODEX_HOME="$FIXTURE_ROOT/extra-arguments" sh "$INSTALLER" --force unexpected \
  >"$FIXTURE_ROOT/extra-arguments.log" 2>&1; then
  fail "The installer ignored an extra argument."
fi
test ! -e "$FIXTURE_ROOT/extra-arguments" || fail "Invalid arguments changed the destination."

if (
  cd "$FIXTURE_ROOT"
  env CODEX_HOME="relative codex home" sh "$INSTALLER"
) >"$FIXTURE_ROOT/relative-home.log" 2>&1; then
  fail "A relative CODEX_HOME unexpectedly succeeded."
fi
test ! -e "$FIXTURE_ROOT/relative codex home" || fail "A relative override changed the destination."

# Updating a hard-linked destination must replace its directory entry, not
# overwrite the other linked file outside the installed pet directory.
CANARY="$FIXTURE_ROOT/hardlink-canary"
cp "$REPO_DIR/pet.json" "$CANARY"
rm "$DESTINATION/pet.json"
ln "$CANARY" "$DESTINATION/pet.json"
env CODEX_HOME="$TEST_CODEX_ROOT" sh "$INSTALLER" --force
cmp "$REPO_DIR/pet.json" "$CANARY"
cmp "$REPO_DIR/pet.json" "$DESTINATION/pet.json"
test ! "$CANARY" -ef "$DESTINATION/pet.json" || fail "The forced update kept the destination hard link."

for LINK_KIND in codex-root pets-root destination manifest sprite; do
  CASE_ROOT="$FIXTURE_ROOT/link $LINK_KIND"
  OUTSIDE="$CASE_ROOT/outside"
  LINK_HOME="$CASE_ROOT/codex home"
  mkdir -p "$OUTSIDE"
  cp "$REPO_DIR/pet.json" "$OUTSIDE/canary"
  case "$LINK_KIND" in
    codex-root)
      ln -s "$OUTSIDE" "$LINK_HOME"
      LINK_HOME="$LINK_HOME///"
      ;;
    pets-root)
      mkdir -p "$LINK_HOME"
      ln -s "$OUTSIDE" "$LINK_HOME/pets"
      ;;
    destination)
      mkdir -p "$LINK_HOME/pets"
      ln -s "$OUTSIDE" "$LINK_HOME/pets/milk-dragon"
      ;;
    manifest|sprite)
      mkdir -p "$LINK_HOME/pets/milk-dragon"
      if [ "$LINK_KIND" = manifest ]; then
        LINK_NAME=pet.json
      else
        LINK_NAME=spritesheet.webp
      fi
      ln -s "$OUTSIDE/canary" "$LINK_HOME/pets/milk-dragon/$LINK_NAME"
      ;;
  esac
  if env CODEX_HOME="$LINK_HOME" sh "$INSTALLER" --force >"$CASE_ROOT/installer.log" 2>&1; then
    fail "The installer accepted a linked $LINK_KIND."
  fi
  cmp "$REPO_DIR/pet.json" "$OUTSIDE/canary"
  test ! -e "$OUTSIDE/pet.json" || fail "The installer wrote through a linked $LINK_KIND."
  test ! -e "$OUTSIDE/spritesheet.webp" || fail "The installer wrote through a linked $LINK_KIND."
done

SOURCE_FIXTURE="$FIXTURE_ROOT/linked source package"
mkdir -p "$SOURCE_FIXTURE/scripts"
cp "$INSTALLER" "$SOURCE_FIXTURE/scripts/install.sh"
cp "$REPO_DIR/spritesheet.webp" "$SOURCE_FIXTURE/spritesheet.webp"
ln -s "$REPO_DIR/pet.json" "$SOURCE_FIXTURE/pet.json"
if env CODEX_HOME="$FIXTURE_ROOT/source-link-home" sh "$SOURCE_FIXTURE/scripts/install.sh" \
  >"$SOURCE_FIXTURE/installer.log" 2>&1; then
  fail "The installer accepted a linked source file."
fi
test ! -e "$FIXTURE_ROOT/source-link-home" || fail "A rejected source link changed the destination."

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

printf '%s\n' "PASS: install, protected reinstall, force/hard-link update, argument/path/link rejection, and both temporary-file collision regressions."
