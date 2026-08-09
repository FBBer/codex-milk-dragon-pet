# 奶龙 · Codex 桌面宠物

[![Validate](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate.yml/badge.svg)](https://github.com/FBBer/codex-milk-dragon-pet/actions/workflows/validate.yml)

<p align="center">
  <img src="preview/static-preview.png" alt="奶龙静态预览" width="320">
</p>

> 一个老绷带

这是一个可以安装到 ChatGPT/Codex 桌面应用 Pets 功能中的非官方社区自制宠物。安装后，宠物文件只保存在你的电脑上。

## 安装

### macOS / Linux

打开终端，依次运行：

```bash
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
git clone https://github.com/FBBer/codex-milk-dragon-pet.git
Set-Location codex-milk-dragon-pet
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

如果电脑里已经装过同名奶龙，更新时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Force
```

不使用 Git 的用户也可以在 GitHub 页面点击 **Code → Download ZIP**，解压后在项目文件夹中运行对应的安装脚本。

## 在应用中启用

1. 打开桌面应用的 **Settings → Pets**。
2. 点击 **Refresh**。
3. 选择 **奶龙**。
4. 输入 `/pet`，或在命令菜单中选择 **Wake Pet**。

按照 [OpenAI 官方 Pets 文档](https://learn.chatgpt.com/docs/pets)，桌面端自定义宠物保存在本机，不会自动同步到 ChatGPT 网页版。

## 宠物信息

- 名字：奶龙
- 描述：一个老绷带
- 宠物 ID：`milk-dragon`
- 精灵图版本：v2
- 图集规格：`1536 × 2288`，`8 × 11` 帧格
- macOS / Linux 安装位置：`${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon`
- Windows 安装位置：`%CODEX_HOME%\pets\milk-dragon`；未设置 `CODEX_HOME` 时使用用户目录下的 `.codex\pets\milk-dragon`

这个仓库提供的是桌面端本地 v2 宠物包。官方文档所述的网页版 **Upload pet** 当前要求 `1536 × 1872` 图集，因此不要把这里的 v2 图集直接上传到网页版。

## 质量检查

- v2 图集结构验证通过：无错误、无警告
- 标准动作与 16 个观察方向已完成视觉检查
- [查看完整动作表](qa/contact-sheet.png)
- [查看观察方向检查图](qa/look-directions.png)
- [查看公开验证摘要](qa/validation-summary.json)
- [查看文件校验值](SHA256SUMS)
- GitHub Actions 会在 macOS、Linux 和 Windows 上复测安装流程

## 手动安装

安装脚本所做的事情只是把根目录中的 `pet.json` 和 `spritesheet.webp` 复制到本地宠物目录。macOS / Linux 也可以手动运行：

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon"
cp pet.json spritesheet.webp "${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon/"
```

## 性质与权利说明

这是非官方社区项目，与 OpenAI、ChatGPT、Codex、抖音、哔哩哔哩或相关角色权利人不存在隶属、合作、赞助或认可关系。

仓库中的宠物视觉资源仅供个人、非商业的本地安装与使用；安装脚本采用 MIT License。详情见 [ASSET-NOTICE.md](ASSET-NOTICE.md) 与 [LICENSE-CODE.md](LICENSE-CODE.md)。
