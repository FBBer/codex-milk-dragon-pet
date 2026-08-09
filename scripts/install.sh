#!/bin/sh
set -eu

FORCE=0

case "${1:-}" in
  "")
    ;;
  --force)
    FORCE=1
    ;;
  -h|--help)
    printf '%s\n' "用法：sh scripts/install.sh [--force]"
    exit 0
    ;;
  *)
    printf '%s\n' "未知参数：$1" >&2
    printf '%s\n' "用法：sh scripts/install.sh [--force]" >&2
    exit 2
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

SOURCE_MANIFEST="$REPO_DIR/pet.json"
SOURCE_SPRITE="$REPO_DIR/spritesheet.webp"

if [ ! -f "$SOURCE_MANIFEST" ] || [ ! -f "$SOURCE_SPRITE" ]; then
  printf '%s\n' "安装失败：仓库中的 pet.json 或 spritesheet.webp 缺失。" >&2
  exit 1
fi

if [ -n "${CODEX_HOME:-}" ]; then
  CODEX_ROOT=$CODEX_HOME
else
  : "${HOME:?无法确定用户目录}"
  CODEX_ROOT="$HOME/.codex"
fi

DESTINATION="$CODEX_ROOT/pets/milk-dragon"

if [ -L "$DESTINATION" ]; then
  printf '%s\n' "安装失败：目标位置是符号链接，已为安全起见停止。" >&2
  exit 1
fi

if [ -e "$DESTINATION" ]; then
  if [ ! -d "$DESTINATION" ]; then
    printf '%s\n' "安装失败：目标位置存在，但不是文件夹。" >&2
    exit 1
  fi

  if [ "$FORCE" -ne 1 ]; then
    printf '%s\n' "奶龙已经存在：$DESTINATION" >&2
    printf '%s\n' "如需更新，请运行：sh scripts/install.sh --force" >&2
    exit 1
  fi
fi

mkdir -p "$DESTINATION"

DESTINATION_MANIFEST="$DESTINATION/pet.json"
DESTINATION_SPRITE="$DESTINATION/spritesheet.webp"

for TARGET in "$DESTINATION_MANIFEST" "$DESTINATION_SPRITE"; do
  if [ -L "$TARGET" ]; then
    printf '%s\n' "安装失败：目标文件是符号链接，已为安全起见停止：$TARGET" >&2
    exit 1
  fi
  if [ -e "$TARGET" ] && [ ! -f "$TARGET" ]; then
    printf '%s\n' "安装失败：目标文件存在，但不是普通文件：$TARGET" >&2
    exit 1
  fi
done

TEMP_MANIFEST="$DESTINATION/.pet.json.install.$$"
TEMP_SPRITE="$DESTINATION/.spritesheet.webp.install.$$"

cleanup() {
  rm -f "$TEMP_MANIFEST" "$TEMP_SPRITE"
}

handle_signal() {
  cleanup
  trap - 0 1 2 15
  exit 1
}

trap cleanup 0
trap handle_signal 1 2 15

if [ -e "$TEMP_MANIFEST" ] || [ -L "$TEMP_MANIFEST" ] ||
   [ -e "$TEMP_SPRITE" ] || [ -L "$TEMP_SPRITE" ]; then
  printf '%s\n' "安装失败：临时文件名冲突，请重新运行安装。" >&2
  exit 1
fi

cp "$SOURCE_MANIFEST" "$TEMP_MANIFEST"
cp "$SOURCE_SPRITE" "$TEMP_SPRITE"
chmod 0644 "$TEMP_MANIFEST" "$TEMP_SPRITE" 2>/dev/null || true
mv -f "$TEMP_MANIFEST" "$DESTINATION_MANIFEST"
mv -f "$TEMP_SPRITE" "$DESTINATION_SPRITE"

trap - 0 1 2 15

printf '\n%s\n' "奶龙安装完成：$DESTINATION"
printf '%s\n' "接下来打开 Settings → Pets，点击 Refresh，选择“奶龙”，再输入 /pet 唤醒。"
