# 奶龙 v1.0.0 安装说明

这是可安装到 ChatGPT/Codex 桌面应用 Pets 功能中的奶龙 v2 自定义宠物包。

## Windows

1. 在资源管理器中解压下载的 ZIP。
2. 打开解压得到的 `milk-dragon-codex-pet-v1.0.0` 文件夹。
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

解压 ZIP，进入 `milk-dragon-codex-pet-v1.0.0` 文件夹后运行：

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
4. 输入 `/pet`，或在命令菜单中选择 **Wake Pet**。

- 宠物名称：奶龙
- 宠物描述：一个老绷带
- 宠物 ID：`milk-dragon`

项目主页：https://github.com/FBBer/codex-milk-dragon-pet
