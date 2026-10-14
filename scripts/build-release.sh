#!/bin/sh
set -eu

VERSION=${1:-}
REQUESTED_OUTPUT_DIR=${2:-}

usage() {
  printf '%s\n' "用法：sh scripts/build-release.sh v1.0.1 [输出目录]（版本必须符合 SemVer）" >&2
  exit 2
}

[ "$#" -le 2 ] || usage
# Reject newlines and path separators before matching the complete SemVer tag.
case "$VERSION" in
  ""|*[!0-9A-Za-z.+-]*) usage ;;
esac
SEMVER_NUMBER='(0|[1-9][0-9]*)'
SEMVER_PRERELEASE="($SEMVER_NUMBER|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
SEMVER_BUILD='[0-9A-Za-z-]+'
SEMVER_PATTERN="^v$SEMVER_NUMBER\\.$SEMVER_NUMBER\\.$SEMVER_NUMBER(-$SEMVER_PRERELEASE(\\.$SEMVER_PRERELEASE)*)?(\\+$SEMVER_BUILD(\\.$SEMVER_BUILD)*)?$"
printf '%s\n' "$VERSION" | LC_ALL=C grep -Eq "$SEMVER_PATTERN" || usage

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)

GIT_ROOT=$(git -C "$REPO_DIR" rev-parse --show-toplevel) || exit 1
if [ "$GIT_ROOT" != "$REPO_DIR" ]; then
  printf '%s\n' "构建失败：脚本必须位于此项目的 Git 仓库根目录下。" >&2
  exit 1
fi
GIT_STATUS=$(git -C "$REPO_DIR" status --porcelain --untracked-files=normal) || exit 1
if [ -n "$GIT_STATUS" ]; then
  printf '%s\n' "构建失败：Git 工作区必须干净，确保安装包与当前提交完全一致。" >&2
  exit 1
fi

for SOURCE in \
  "$REPO_DIR/pet.json" \
  "$REPO_DIR/spritesheet.webp" \
  "$REPO_DIR/scripts/install.sh" \
  "$REPO_DIR/scripts/install.ps1" \
  "$REPO_DIR/release/INSTALL.md" \
  "$REPO_DIR/ASSET-NOTICE.md" \
  "$REPO_DIR/LICENSE-CODE.md"; do
  if [ ! -f "$SOURCE" ] || [ -L "$SOURCE" ]; then
    printf '%s\n' "构建失败：文件缺失、不是普通文件或是符号链接：$SOURCE" >&2
    exit 1
  fi
done

for SOURCE_DIRECTORY in "$REPO_DIR/scripts" "$REPO_DIR/release"; do
  if [ -L "$SOURCE_DIRECTORY" ]; then
    printf '%s\n' "构建失败：源文件夹是符号链接：$SOURCE_DIRECTORY" >&2
    exit 1
  fi
done

if ! command -v zip >/dev/null 2>&1; then
  printf '%s\n' "构建失败：需要 zip 命令。" >&2
  exit 1
fi

if [ -n "$REQUESTED_OUTPUT_DIR" ]; then
  mkdir -p "$REQUESTED_OUTPUT_DIR"
  OUTPUT_DIR=$(CDPATH= cd -- "$REQUESTED_OUTPUT_DIR" && pwd -P)
else
  mkdir -p "$REPO_DIR/dist"
  OUTPUT_DIR="$REPO_DIR/dist"
fi
PACKAGE_NAME="milk-dragon-codex-pet-$VERSION"
ARCHIVE="$OUTPUT_DIR/$PACKAGE_NAME.zip"
ARCHIVE_CHECKSUM="$ARCHIVE.sha256"

if [ -e "$ARCHIVE" ] || [ -L "$ARCHIVE" ] ||
   [ -e "$ARCHIVE_CHECKSUM" ] || [ -L "$ARCHIVE_CHECKSUM" ]; then
  printf '%s\n' "构建失败：输出已存在，请先移走旧文件：$ARCHIVE" >&2
  exit 1
fi

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/milk-dragon-release.XXXXXX")
case "$TEMP_ROOT" in
  "${TMPDIR:-/tmp}"/milk-dragon-release.*)
    ;;
  *)
    printf '%s\n' "构建失败：无法创建安全的临时目录。" >&2
    exit 1
    ;;
esac
PACKAGE_DIR="$TEMP_ROOT/$PACKAGE_NAME"
OUTPUT_STAGE=""
ARCHIVE_PUBLISHED=0
BUILD_COMPLETED=0

cleanup() {
  if [ "$ARCHIVE_PUBLISHED" -eq 1 ] && [ "$BUILD_COMPLETED" -eq 0 ]; then
    rm -f "$ARCHIVE"
  fi
  if [ -n "$OUTPUT_STAGE" ]; then
    rm -rf "$OUTPUT_STAGE"
  fi
  rm -rf "$TEMP_ROOT"
}

handle_signal() {
  cleanup
  trap - 0 1 2 15
  exit 1
}

trap cleanup 0
trap handle_signal 1 2 15

OUTPUT_STAGE=$(mktemp -d "$OUTPUT_DIR/.milk-dragon-release.XXXXXX")
STAGED_ARCHIVE="$OUTPUT_STAGE/$PACKAGE_NAME.zip"
STAGED_CHECKSUM="$STAGED_ARCHIVE.sha256"
mkdir -p "$PACKAGE_DIR/scripts" "$OUTPUT_DIR"
cp "$REPO_DIR/pet.json" "$PACKAGE_DIR/pet.json"
cp "$REPO_DIR/spritesheet.webp" "$PACKAGE_DIR/spritesheet.webp"
cp "$REPO_DIR/scripts/install.sh" "$PACKAGE_DIR/scripts/install.sh"
cp "$REPO_DIR/scripts/install.ps1" "$PACKAGE_DIR/scripts/install.ps1"
cp "$REPO_DIR/release/INSTALL.md" "$PACKAGE_DIR/README.md"
cp "$REPO_DIR/ASSET-NOTICE.md" "$PACKAGE_DIR/ASSET-NOTICE.md"
cp "$REPO_DIR/LICENSE-CODE.md" "$PACKAGE_DIR/LICENSE-CODE.md"
find "$PACKAGE_DIR" -type d -exec chmod 0755 {} \;
find "$PACKAGE_DIR" -type f -exec chmod 0644 {} \;
chmod 0755 "$PACKAGE_DIR/scripts/install.sh"

COMMIT_SHA=$(git -C "$REPO_DIR" rev-parse HEAD)
printf '{\n  "version": "%s",\n  "commit": "%s",\n  "petId": "milk-dragon",\n  "spriteVersionNumber": 2\n}\n' \
  "$VERSION" "$COMMIT_SHA" >"$PACKAGE_DIR/BUILD-INFO.json"

CHECKSUM_FILES="ASSET-NOTICE.md
BUILD-INFO.json
LICENSE-CODE.md
README.md
pet.json
scripts/install.ps1
scripts/install.sh
spritesheet.webp"

if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$PACKAGE_DIR"
    printf '%s\n' "$CHECKSUM_FILES" | while IFS= read -r FILE; do
      sha256sum "$FILE"
    done
  ) >"$PACKAGE_DIR/SHA256SUMS"
else
  (
    cd "$PACKAGE_DIR"
    printf '%s\n' "$CHECKSUM_FILES" | while IFS= read -r FILE; do
      shasum -a 256 "$FILE"
    done
  ) >"$PACKAGE_DIR/SHA256SUMS"
fi

find "$PACKAGE_DIR" -type f -exec chmod 0644 {} \;
chmod 0755 "$PACKAGE_DIR/scripts/install.sh"

FIXED_TIMESTAMP=$(TZ=UTC git -C "$REPO_DIR" show -s \
  --format=%cd --date=format-local:%Y%m%d%H%M.%S HEAD)
find "$PACKAGE_DIR" -exec touch -t "$FIXED_TIMESTAMP" {} \;

(
  cd "$TEMP_ROOT"
  find "$PACKAGE_NAME" -print | LC_ALL=C sort | zip -X -0 -q "$STAGED_ARCHIVE" -@
)

if command -v sha256sum >/dev/null 2>&1; then
  ARCHIVE_HASH=$(sha256sum "$STAGED_ARCHIVE" | awk '{print $1}')
else
  ARCHIVE_HASH=$(shasum -a 256 "$STAGED_ARCHIVE" | awk '{print $1}')
fi

printf '%s  %s\n' "$ARCHIVE_HASH" "$(basename "$ARCHIVE")" >"$STAGED_CHECKSUM"

# Publish only complete files; hard links on the same output filesystem also
# refuse an existing destination rather than overwriting it in a concurrent run.
ln "$STAGED_ARCHIVE" "$ARCHIVE"
ARCHIVE_PUBLISHED=1
ln "$STAGED_CHECKSUM" "$ARCHIVE_CHECKSUM"
BUILD_COMPLETED=1

trap - 0 1 2 15
cleanup

printf 'archive=%s\nchecksum=%s\nsha256=%s\n' \
  "$ARCHIVE" "$ARCHIVE_CHECKSUM" "$ARCHIVE_HASH"
