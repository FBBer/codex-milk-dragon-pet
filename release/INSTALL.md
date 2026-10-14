# 奶龙 v1.0.1 安装说明

这是可安装到支持本地自定义 Pets 的 ChatGPT/Codex 客户端中的奶龙 v2 宠物包。安装包版本为 v1.0.1，精灵图格式版本为 v2，两者含义不同。

请从 [v1.0.1 Release](https://github.com/FBBer/codex-milk-dragon-pet/releases/tag/v1.0.1) 下载 `milk-dragon-codex-pet-v1.0.1.zip`。同名 `.zip.sha256` 文件用于核对整个 ZIP；包内 `SHA256SUMS` 用于核对包内文件，`BUILD-INFO.json` 记录版本和构建提交。

## Windows

1. 在资源管理器中解压下载的 ZIP。
2. 打开解压得到的 `milk-dragon-codex-pet-v1.0.1` 文件夹。
3. 在该文件夹中打开 PowerShell，不需要管理员权限。
4. 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

如果已经安装过同名奶龙，更新时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Force
```

## macOS / Linux

解压 ZIP，进入 `milk-dragon-codex-pet-v1.0.1` 文件夹后运行：

```bash
sh scripts/install.sh
```

如果已经安装过同名奶龙，更新时运行：

```bash
sh scripts/install.sh --force
```

## 在应用中启用

1. 打开桌面应用的 **Settings → Pets**。
2. 点击 **Refresh**。
3. 选择 **奶龙**。
4. 输入 `/pet`，或在命令菜单中选择 **Show pet**（显示宠物）。

上述悬浮窗口入口适用于 macOS / Windows 桌面应用。Linux 脚本只安装资源文件，不会安装桌面应用或提供悬浮窗口。客户端入口与可用性以 [OpenAI 官方 Pets 文档](https://learn.chatgpt.com/docs/pets) 及你的客户端为准。

- 宠物名称：奶龙
- 宠物描述：一个老绷带
- 本地宠物 ID：`milk-dragon`
- 图集规格：`1536 × 2288`，透明 WebP，v2
- macOS / Linux 安装位置：`${CODEX_HOME:-$HOME/.codex}/pets/milk-dragon`
- Windows 安装位置：`%CODEX_HOME%\pets\milk-dragon`；未设置 `CODEX_HOME` 时使用用户目录下的 `.codex\pets\milk-dragon`

## 本地安装与云端 Pets

安装脚本只复制本机目录中的 `pet.json` 和 `spritesheet.webp`。更新时的 `--force` / `-Force` 会替换这两个文件，不会更新账号云端记录，也不会调整其他客户端的窗口位置与大小。

本地 ID 与账号生成的云端 ID 不同，不能互换。若你已有支持 v2 的云端宠物，应通过支持 v2 的 Pets 工具更新同一条记录，再重新下载比较解码后的 RGBA 像素。普通网页上传入口要求 `1536 × 1872`，不能直接上传本包的 `1536 × 2288` 图集。

## 验证范围与权利说明

[仓库公开 QA 记录](https://github.com/FBBer/codex-milk-dragon-pet/blob/v1.0.1/qa/validation-summary.json) 确认 4 个主方向通过，跳跃峰值离地 12 px、落地基线误差 0 px；中间方向的语义与连续性提示已复核并保留，未宣称零警告。图片与安装检查不等同于具体电脑上悬浮窗口的实时显示确认。

请保留并阅读包内 `ASSET-NOTICE.md` 与 `LICENSE-CODE.md`。本项目为非官方社区项目，视觉资源的使用受权利说明限制。

项目主页：[codex-milk-dragon-pet](https://github.com/FBBer/codex-milk-dragon-pet)
