# 奶龙 · Codex 桌面宠物

[![Validate repository](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate.yml/badge.svg)](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate.yml)
[![Validate release](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate-release.yml/badge.svg)](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate-release.yml)

<p align="center">
  <img src="preview/static-preview.png" alt="奶龙静态预览" width="320">
</p>

> 一个老绷带

这是一个可以安装到支持本地自定义 Pets 的 ChatGPT/Codex 客户端中的非官方社区自制宠物。本仓库提供本地安装包；账号中的云端 Pets 是独立记录，不会随本地安装或 GitHub 发布自动更新。

## v1.0.1 下载与安装

不需要安装 Git，本次版本使用精简安装包：

1. 在 [v1.0.1 Release](https://github.com/FBBer/codex-milk-dragon-pet/releases/tag/v1.0.1) 下载 [milk-dragon-codex-pet-v1.0.1.zip](https://github.com/FBBer/codex-milk-dragon-pet/releases/download/v1.0.1/milk-dragon-codex-pet-v1.0.1.zip)。可同时下载 [ZIP 校验文件](https://github.com/FBBer/codex-milk-dragon-pet/releases/download/v1.0.1/milk-dragon-codex-pet-v1.0.1.zip.sha256)。
2. 解压 ZIP，并进入解压得到的 `milk-dragon-codex-pet-v1.0.1` 文件夹。
3. Windows 在该文件夹中打开 PowerShell，运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
   ```

4. macOS / Linux 在该文件夹中打开终端，运行：

   ```bash
   sh scripts/install.sh
   ```

已安装同名奶龙时，需要添加 `-Force`（Windows）或 `--force`（macOS / Linux），见下文。完整步骤见 [安装说明](release/INSTALL.md)，本次变更见 [v1.0.1 发布说明](release/v1.0.1.md) 与 [图集修复记录](release/2026-10-14-sync.md)。

历史 [v1.0.0 Release](https://github.com/FBBer/codex-milk-dragon-pet/releases/tag/v1.0.0) 保留原附件用于追溯，未包含本次修复。也可以下载 [当前主分支源码 ZIP](https://github.com/FBBer/codex-milk-dragon-pet/archive/refs/heads/main.zip)，但主分支可能包含晚于 v1.0.1 的变更；源码 ZIP 的解压目录为 `codex-milk-dragon-pet-main`。

## 从仓库安装

### macOS / Linux

打开终端，依次运行：

```bash
cd "$HOME"
git clone https://github.com/FBBer/codex-milk-dragon-pet.git
cd codex-milk-dragon-pet
sh scripts/install.sh
```

如果电脑里已经装过同名奶龙，更新时运行：

```bash
sh scripts/install.sh --force
```

### Windows

打开 PowerShell，依次运行：

```powershell
Set-Location $HOME
git clone https://github.com/FBBer/codex-milk-dragon-pet.git
Set-Location codex-milk-dragon-pet
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

如果电脑里已经装过同名奶龙，更新时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Force
```

不需要管理员权限；关键是先进入个人目录或解压后的项目文件夹，不要在 `C:\Windows\System32` 中克隆仓库。

## 在应用中启用

1. 打开桌面应用的 **Settings → Pets**。
2. 点击 **Refresh**。
3. 选择 **奶龙**。
4. 输入 `/pet`，或在命令菜单中选择 **Show pet**（显示宠物）。

上述悬浮窗口入口适用于 macOS / Windows 桌面应用。Linux 安装脚本只安装资源文件，不会安装桌面应用或提供悬浮窗口。

本地安装脚本只更新本机 `milk-dragon` 目录中的 `pet.json` 和 `spritesheet.webp`，不会自动更新账号中的云端宠物，也不会调整其他客户端的窗口位置与大小。[OpenAI 官方 Pets 文档](https://learn.chatgpt.com/docs/pets) 同样说明本地自定义宠物不会自动同步到网页端。

若已有支持 v2 的云端 Pets 记录，更新时应使用支持 v2 的 Pets 工具更新同一只已有宠物，并重新下载核对图集；不要仅为更新图片重复创建同名记录。本地 ID `milk-dragon` 与账号生成的云端 ID 不同，不能互换。PNG 与 WebP 的文件哈希可以不同；同步一致性应比较解码后的 RGBA 像素。

## 宠物信息

- 名字：奶龙
- 描述：一个老绷带
- 本地宠物 ID：`milk-dragon`
- 安装包版本：v1.0.1（与精灵图格式版本 v2 不同）
- 精灵图版本：v2
- 图集规格：`1536 × 2288`，`8 × 11` 帧格
- macOS / Linux 安装位置：`${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon`
- Windows 安装位置：`%CODEX_HOME%\pets\milk-dragon`；未设置 `CODEX_HOME` 时使用用户目录下的 `.codex\pets\milk-dragon`

这个仓库提供 `1536 × 2288` 的 v2 宠物包。官方文档描述的普通网页上传入口要求 `1536 × 1872`，不能直接使用本图集；支持 v2 的账号 Pets 工具是另一条路径，不应混用。发布 GitHub 安装包本身不执行云端上传。

## 质量检查

- 仓库公开 QA 报告记录：v2 图集结构验证通过，无结构错误、无结构警告；73 个必需帧完整，15 个未使用格透明
- 57 个标准动作帧与 16 个观察方向已检查；跳跃峰值离地 12 px，落地基线误差 0 px
- 四个主方向经三份独立盲测确认；完整质量门禁通过，但保留 6 条中间方向语义提示和 3 条连续性提示，不是“零警告”结论
- 最终 `spritesheet.webp` 文件 SHA-256：`d909d5f9de11e015e44564c76be3713edd078a8acfea88c54e4228d71ae2fbc9`（编码文件哈希，不是解码 RGBA 像素哈希）
- [查看完整动作表](qa/contact-sheet.png)
- [查看观察方向检查图](qa/look-directions.png)
- [查看公开验证摘要](qa/validation-summary.json)
- [查看完整质量门禁结果](qa/pet-quality.json)
- [查看跳跃动画](qa/previews/idle-jump-idle.gif) · [查看全部动作 GIF](qa/previews/all-states.gif) · [查看 MP4](qa/previews/all-states.mp4)
- [查看文件校验值](SHA256SUMS)
- 仓库工作流配置为在 macOS、Linux 和 Windows 上复测安装与严格图集/质量门禁；Release 工作流下载实际发布的 ZIP 并独立检查校验值和安装行为。各版本的实际运行结果以对应 GitHub Actions 记录为准

本地复测（Python 3.12 + Pillow）：

```bash
python3 -m pip install 'Pillow>=12,<14'
python3 scripts/check_quality.py --output-dir /tmp/milk-dragon-quality
python3 tests/test_quality.py
python3 tests/test_quality_evidence.py
sh tests/test_install.sh
sh tests/test_build_release.sh
```

这些检查验证资源、动作几何和安装行为，不代替具体电脑上实时悬浮窗口的画面确认。

## 手动安装

安装脚本所做的事情只是把根目录中的 `pet.json` 和 `spritesheet.webp` 复制到本地宠物目录。macOS / Linux 也可以手动运行：

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon"
cp pet.json spritesheet.webp "${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon/"
```

## 性质与权利说明

这是非官方社区项目，与 OpenAI、ChatGPT、Codex、抖音、哔哩哔哩或相关角色权利人不存在隶属、合作、赞助或认可关系。

仓库中的宠物视觉资源仅供个人、非商业安装与显示；安装脚本采用 MIT License，质量校验脚本的来源与适用范围见代码许可说明。详情见 [ASSET-NOTICE.md](ASSET-NOTICE.md) 与 [LICENSE-CODE.md](LICENSE-CODE.md)。
