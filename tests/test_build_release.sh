#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
FIXTURE_PARENT=${TMPDIR:-/tmp}
FIXTURE_ROOT=$(mktemp -d "$FIXTURE_PARENT/milk-dragon-build-tests.XXXXXX")
case "$FIXTURE_ROOT" in
  "$FIXTURE_PARENT"/milk-dragon-build-tests.*) ;;
  *) printf '%s\n' "Could not create a safe test fixture." >&2; exit 1 ;;
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

fixture_git() {
  env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git "$@"
}

commit_fixture() {
  fixture_git -C "$1" add -- .
  env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    GIT_AUTHOR_DATE=2026-08-09T05:11:48Z GIT_COMMITTER_DATE=2026-08-09T05:11:48Z \
    git -C "$1" -c user.name='Release test fixture' -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false commit --quiet -m 'Isolated release-test fixture'
}

create_fixture() {
  mkdir -p "$1/scripts" "$1/release"
  for FILE in pet.json spritesheet.webp ASSET-NOTICE.md LICENSE-CODE.md; do
    cp "$REPO_DIR/$FILE" "$1/$FILE"
  done
  for FILE in build-release.sh install.sh install.ps1; do
    cp "$REPO_DIR/scripts/$FILE" "$1/scripts/$FILE"
  done
  cp "$REPO_DIR/release/INSTALL.md" "$1/release/INSTALL.md"
  fixture_git -c init.defaultBranch=main -c init.templateDir= init --quiet "$1"
  commit_fixture "$1"
}

FIXTURE_REPO="$FIXTURE_ROOT/项目 repository"
create_fixture "$FIXTURE_REPO"
BUILDER="$FIXTURE_REPO/scripts/build-release.sh"

for INVALID_VERSION in '' v01.2.3 v1.02.3 v1.2.03 v1.2 v1.2.3.4 \
  v1.2.3-01 v1.2.3-alpha..1 v1.2.3+ v1.2.3+build..1 \
  v1.2.3/../../outside 'v1.2.3"bad' 'v1.2.3 space'; do
  if sh "$BUILDER" "$INVALID_VERSION" "$FIXTURE_ROOT/invalid-output" \
    >"$FIXTURE_ROOT/invalid-version.log" 2>&1; then
    fail "An invalid version was accepted: $INVALID_VERSION"
  fi
  test ! -e "$FIXTURE_ROOT/invalid-output" || fail "An invalid version created output."
done
INVALID_VERSION=$(printf 'v1.0.1\ninvalid')
if sh "$BUILDER" "$INVALID_VERSION" "$FIXTURE_ROOT/newline-output" \
  >"$FIXTURE_ROOT/newline.log" 2>&1; then
  fail "A multiline version was accepted."
fi
test ! -e "$FIXTURE_ROOT/newline-output" || fail "A multiline version created output."
if sh "$BUILDER" v1.0.1 "$FIXTURE_ROOT/extra-output" unexpected \
  >"$FIXTURE_ROOT/extra.log" 2>&1; then
  fail "The builder ignored an extra argument."
fi
test ! -e "$FIXTURE_ROOT/extra-output" || fail "An extra argument created output."

FIRST_OUTPUT="$FIXTURE_ROOT/发布 build one"
SECOND_OUTPUT="$FIXTURE_ROOT/发布 build two"
env TZ=UTC0 sh "$BUILDER" v1.0.1 "$FIRST_OUTPUT"
env TZ=EST5EDT sh "$BUILDER" v1.0.1 "$SECOND_OUTPUT"
ARCHIVE_NAME=milk-dragon-codex-pet-v1.0.1.zip
cmp "$FIRST_OUTPUT/$ARCHIVE_NAME" "$SECOND_OUTPUT/$ARCHIVE_NAME"
cmp "$FIRST_OUTPUT/$ARCHIVE_NAME.sha256" "$SECOND_OUTPUT/$ARCHIVE_NAME.sha256"
(
  cd "$FIRST_OUTPUT"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$ARCHIVE_NAME.sha256"
  else
    shasum -a 256 -c "$ARCHIVE_NAME.sha256"
  fi
)

PACKAGE_NAME=milk-dragon-codex-pet-v1.0.1
EXTRACT_ROOT="$FIXTURE_ROOT/解压 package"
unzip -q "$FIRST_OUTPUT/$ARCHIVE_NAME" -d "$EXTRACT_ROOT"
PACKAGE_ROOT="$EXTRACT_ROOT/$PACKAGE_NAME"
COMMIT_SHA=$(fixture_git -C "$FIXTURE_REPO" rev-parse HEAD)
jq -e --arg commit "$COMMIT_SHA" \
  '.version == "v1.0.1" and .commit == $commit and .petId == "milk-dragon" and .spriteVersionNumber == 2' \
  "$PACKAGE_ROOT/BUILD-INFO.json" >/dev/null
cmp "$FIXTURE_REPO/pet.json" "$PACKAGE_ROOT/pet.json"
cmp "$FIXTURE_REPO/spritesheet.webp" "$PACKAGE_ROOT/spritesheet.webp"
cmp "$FIXTURE_REPO/release/INSTALL.md" "$PACKAGE_ROOT/README.md"
(
  cd "$PACKAGE_ROOT"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c SHA256SUMS
  else
    shasum -a 256 -c SHA256SUMS
  fi
)
unzip -Z1 "$FIRST_OUTPUT/$ARCHIVE_NAME" | sed 's#/$##' | LC_ALL=C sort >"$FIXTURE_ROOT/actual-entries"
printf '%s\n' "$PACKAGE_NAME" "$PACKAGE_NAME/ASSET-NOTICE.md" "$PACKAGE_NAME/BUILD-INFO.json" \
  "$PACKAGE_NAME/LICENSE-CODE.md" "$PACKAGE_NAME/README.md" "$PACKAGE_NAME/SHA256SUMS" \
  "$PACKAGE_NAME/pet.json" "$PACKAGE_NAME/scripts" "$PACKAGE_NAME/scripts/install.ps1" \
  "$PACKAGE_NAME/scripts/install.sh" "$PACKAGE_NAME/spritesheet.webp" | LC_ALL=C sort \
  >"$FIXTURE_ROOT/expected-entries"
cmp "$FIXTURE_ROOT/expected-entries" "$FIXTURE_ROOT/actual-entries"

for VALID_VERSION in v0.0.0 v1.2.3-alpha.1+build.007; do
  VALID_OUTPUT="$FIXTURE_ROOT/valid $VALID_VERSION"
  sh "$BUILDER" "$VALID_VERSION" "$VALID_OUTPUT" >"$FIXTURE_ROOT/valid.log"
  unzip -p "$VALID_OUTPUT/milk-dragon-codex-pet-$VALID_VERSION.zip" \
    "milk-dragon-codex-pet-$VALID_VERSION/BUILD-INFO.json" |
    jq -e --arg version "$VALID_VERSION" '.version == $version' >/dev/null
done

if sh "$BUILDER" v1.0.1 "$FIRST_OUTPUT" >"$FIXTURE_ROOT/existing.log" 2>&1; then
  fail "An existing release archive was overwritten."
fi
cmp "$FIRST_OUTPUT/$ARCHIVE_NAME" "$SECOND_OUTPUT/$ARCHIVE_NAME"
cmp "$FIRST_OUTPUT/$ARCHIVE_NAME.sha256" "$SECOND_OUTPUT/$ARCHIVE_NAME.sha256"
SIDECAR_OUTPUT="$FIXTURE_ROOT/existing-sidecar"
mkdir -p "$SIDECAR_OUTPUT"
cp "$FIRST_OUTPUT/$ARCHIVE_NAME.sha256" "$SIDECAR_OUTPUT/$ARCHIVE_NAME.sha256"
if sh "$BUILDER" v1.0.1 "$SIDECAR_OUTPUT" >"$FIXTURE_ROOT/sidecar.log" 2>&1; then
  fail "An existing standalone checksum was overwritten."
fi
cmp "$FIRST_OUTPUT/$ARCHIVE_NAME.sha256" "$SIDECAR_OUTPUT/$ARCHIVE_NAME.sha256"
test ! -e "$SIDECAR_OUTPUT/$ARCHIVE_NAME" || fail "A checksum collision created an archive."
for SUFFIX in '' .sha256; do
  LINK_OUTPUT="$FIXTURE_ROOT/dangling-link$SUFFIX"
  mkdir -p "$LINK_OUTPUT"
  ln -s "$LINK_OUTPUT/outside-target" "$LINK_OUTPUT/$ARCHIVE_NAME$SUFFIX"
  if sh "$BUILDER" v1.0.1 "$LINK_OUTPUT" >"$FIXTURE_ROOT/link.log" 2>&1; then
    fail "A dangling release output symlink was accepted."
  fi
  test -L "$LINK_OUTPUT/$ARCHIVE_NAME$SUFFIX" || fail "The dangling output link was changed."
  test ! -e "$LINK_OUTPUT/outside-target" || fail "The builder wrote through a dangling output link."
done

SOURCE_REPO="$FIXTURE_ROOT/linked-source-repository"
create_fixture "$SOURCE_REPO"
rm "$SOURCE_REPO/pet.json"
ln -s "$FIXTURE_REPO/pet.json" "$SOURCE_REPO/pet.json"
commit_fixture "$SOURCE_REPO"
if sh "$SOURCE_REPO/scripts/build-release.sh" v1.0.1 "$FIXTURE_ROOT/source-output" \
  >"$FIXTURE_ROOT/source.log" 2>&1; then
  fail "A linked package source was accepted."
fi
test ! -e "$FIXTURE_ROOT/source-output" || fail "A rejected source link created output."

DIR_REPO="$FIXTURE_ROOT/linked-source-directory"
create_fixture "$DIR_REPO"
mv "$DIR_REPO/release" "$FIXTURE_ROOT/outside-release"
ln -s "$FIXTURE_ROOT/outside-release" "$DIR_REPO/release"
commit_fixture "$DIR_REPO"
if sh "$DIR_REPO/scripts/build-release.sh" v1.0.1 "$FIXTURE_ROOT/directory-output" \
  >"$FIXTURE_ROOT/directory.log" 2>&1; then
  fail "A linked source directory was accepted."
fi
test ! -e "$FIXTURE_ROOT/directory-output" || fail "A rejected source directory created output."

DIRTY_REPO="$FIXTURE_ROOT/dirty-repository"
create_fixture "$DIRTY_REPO"
cp "$REPO_DIR/pet.json" "$DIRTY_REPO/untracked.json"
if sh "$DIRTY_REPO/scripts/build-release.sh" v1.0.1 "$FIXTURE_ROOT/dirty-output" \
  >"$FIXTURE_ROOT/dirty.log" 2>&1; then
  fail "A dirty repository was accepted."
fi
test ! -e "$FIXTURE_ROOT/dirty-output" || fail "A dirty repository created output."

# Simulate a tool that creates a partial ZIP before failing. Only the temporary
# output stage may contain it; the user-visible archive pair must stay absent.
FAKE_BIN="$FIXTURE_ROOT/failing tools"
mkdir -p "$FAKE_BIN"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" partial >"$4"' 'exit 23' >"$FAKE_BIN/zip"
chmod 0755 "$FAKE_BIN/zip"
FAILED_OUTPUT="$FIXTURE_ROOT/failed-zip-output"
if env PATH="$FAKE_BIN:$PATH" sh "$BUILDER" v1.0.1 "$FAILED_OUTPUT" \
  >"$FIXTURE_ROOT/failed-zip.log" 2>&1; then
  fail "A failed ZIP command was reported as a successful release."
fi
test ! -e "$FAILED_OUTPUT/$ARCHIVE_NAME" || fail "A failed ZIP left a partial final archive."
test ! -e "$FAILED_OUTPUT/$ARCHIVE_NAME.sha256" || fail "A failed ZIP left a final checksum."

PUBLISH_BIN="$FIXTURE_ROOT/failing publication tools"
mkdir -p "$PUBLISH_BIN"
printf '%s\n' '#!/bin/sh' 'case "$2" in *.sha256) exit 24 ;; esac' \
  'exec /bin/ln "$@"' >"$PUBLISH_BIN/ln"
chmod 0755 "$PUBLISH_BIN/ln"
PUBLISH_OUTPUT="$FIXTURE_ROOT/failed-publication-output"
if env PATH="$PUBLISH_BIN:$PATH" sh "$BUILDER" v1.0.1 "$PUBLISH_OUTPUT" \
  >"$FIXTURE_ROOT/failed-publication.log" 2>&1; then
  fail "A failed checksum publication was reported as successful."
fi
test ! -e "$PUBLISH_OUTPUT/$ARCHIVE_NAME" || fail "A failed checksum publication left an archive."
test ! -e "$PUBLISH_OUTPUT/$ARCHIVE_NAME.sha256" || fail "A failed checksum publication left a checksum."

for OUTPUT in "$FIRST_OUTPUT" "$SECOND_OUTPUT" "$FAILED_OUTPUT" "$PUBLISH_OUTPUT"; do
  for LEFTOVER in "$OUTPUT"/.milk-dragon-release.*; do
    if [ -e "$LEFTOVER" ] || [ -L "$LEFTOVER" ]; then
      fail "The builder left an output staging directory."
    fi
  done
done

printf '%s\n' "PASS: SemVer/path validation, package contents/hashes, timezone-independent reproducibility, source/output links, dirty tree, and failed-ZIP cleanup."
