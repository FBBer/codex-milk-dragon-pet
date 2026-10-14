# 奶龙 · Codex 桌面宠物

[![Validate repository](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate.yml/badge.svg)](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate.yml)
[![Validate release](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate-release.yml/badge.svg)](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate-release.yml)

<p align="center">
  <img src="preview/static-preview.png" alt="奶龙静态预览" width="320">
</p>

> 一个老绷带

这是一个可以安装到 ChatGPT/Codex 桌面应用 Pets 功能中的非官方社区自制宠物。本仓库提供本地安装包；支持云端 Pets 的客户端也可以使用账号中的云端宠物记录。

## 最新修复版本：下载主分支

不需要安装 Git，可以下载当前主分支的源代码 ZIP：

1. [下载当前奶龙项目 ZIP](https://github.com/FBBer/codex-milk-dragon-pet/archive/refs/heads/main.zip)。
2. 解压 ZIP，并进入解压得到的 `codex-milk-dragon-pet-main` 文件夹。
3. Windows 在该文件夹中打开 PowerShell，运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
   ```

4. macOS / Linux 在该文件夹中打开终端，运行：

   ```bash
   sh scripts/install.sh
   ```

历史 [v1.0.0 Release](https://github.com/FBBer/codex-milk-dragon-pet/releases/tag/v1.0.0) 保留用于追溯，未包含本次图集和安装脚本修复；需要最新版本请使用主分支。本次变更见 [修复说明](release/2026-10-14-sync.md)。

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
4. 输入 `/pet`，或在命令菜单中选择 **Wake Pet**。

本地安装脚本只更新本机的 `milk-dragon` 文件夹，不会自动更新账号中的云端宠物。若同时使用 Mac、Windows 和云端 Pets，应在各端选择同一只已有云端宠物，并更新该记录；不要重复创建同名宠物。本地 ID 和账号生成的云端 ID 不相同。客户端的窗口位置与大小仍可独立设置。

## 宠物信息

- 名字：奶龙
- 描述：一个老绷带
- 宠物 ID：`milk-dragon`
- 精灵图版本：v2
- 图集规格：`1536 × 2288`，`8 × 11` 帧格
- macOS / Linux 安装位置：`${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon`
- Windows 安装位置：`%CODEX_HOME%\pets\milk-dragon`；未设置 `CODEX_HOME` 时使用用户目录下的 `.codex\pets\milk-dragon`

这个仓库提供 v2 宠物包。使用云端时，请通过支持 v2 的 Pets 工具或客户端入口上传/更新，并验证最终资源；旧版网页上传入口的限制可能不同，见 [OpenAI 官方 Pets 文档](https://learn.chatgpt.com/docs/pets)。

## 质量检查

- v2 图集结构验证通过：无错误、无警告
- 57 个标准动作帧与 16 个观察方向已检查；跳跃峰值离地 12 px，落地基线误差 0 px
- 完整质量门禁通过；四个主方向经三份独立盲测确认，中间方向的细微差异保留为已复核提示，未宣称零提示
- [查看完整动作表](qa/contact-sheet.png)
- [查看观察方向检查图](qa/look-directions.png)
- [查看公开验证摘要](qa/validation-summary.json)
- [查看完整质量门禁结果](qa/pet-quality.json)
- [查看跳跃动画](qa/previews/idle-jump-idle.gif) · [查看全部动作 GIF](qa/previews/all-states.gif) · [查看 MP4](qa/previews/all-states.mp4)
- [查看文件校验值](SHA256SUMS)
- GitHub Actions 在 macOS、Linux 和 Windows 上分别复测仓库安装和严格图集/质量门禁；历史 Release 附件另有独立安装检查

本地复测（Python 3.12 + Pillow）：

```bash
python3 -m pip install 'Pillow>=12,<14'
python3 scripts/check_quality.py --output-dir /tmp/milk-dragon-quality
python3 tests/test_quality.py
sh tests/test_install.sh
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

仓库中的宠物视觉资源仅供个人、非商业的本地安装与使用；安装脚本采用 MIT License。详情见 [ASSET-NOTICE.md](ASSET-NOTICE.md) 与 [LICENSE-CODE.md](LICENSE-CODE.md)。
