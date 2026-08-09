[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceManifest = Join-Path $RepoRoot "pet.json"
$SourceSprite = Join-Path $RepoRoot "spritesheet.webp"

if (-not (Test-Path -LiteralPath $SourceManifest -PathType Leaf) -or
    -not (Test-Path -LiteralPath $SourceSprite -PathType Leaf)) {
    throw "安装失败：仓库中的 pet.json 或 spritesheet.webp 缺失。"
}

if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $UserHome = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::UserProfile
    )
    $CodexRoot = Join-Path $UserHome ".codex"
}
else {
    $CodexRoot = $env:CODEX_HOME
}

$PetsRoot = Join-Path $CodexRoot "pets"
$Destination = Join-Path $PetsRoot "milk-dragon"

if (Test-Path -LiteralPath $Destination) {
    $DestinationItem = Get-Item -LiteralPath $Destination -Force

    if (($DestinationItem.Attributes -band
        [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "安装失败：目标位置是链接，已为安全起见停止。"
    }

    if (-not $DestinationItem.PSIsContainer) {
        throw "安装失败：目标位置存在，但不是文件夹。"
    }

    if (-not $Force) {
        throw "奶龙已经存在：$Destination`n如需更新，请重新运行并添加 -Force。"
    }
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$DestinationManifest = Join-Path $Destination "pet.json"
$DestinationSprite = Join-Path $Destination "spritesheet.webp"

foreach ($Target in @($DestinationManifest, $DestinationSprite)) {
    $TargetItem = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if ($null -ne $TargetItem) {
        if (($TargetItem.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "安装失败：目标文件是链接，已为安全起见停止：$Target"
        }
        if ($TargetItem.PSIsContainer) {
            throw "安装失败：目标文件存在，但不是普通文件：$Target"
        }
    }
}

$TempManifest = Join-Path $Destination (".pet.json.install." + [Guid]::NewGuid().ToString("N"))
$TempSprite = Join-Path $Destination (".spritesheet.webp.install." + [Guid]::NewGuid().ToString("N"))

function Install-FileSafely {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [string]$Temporary
    )

    Copy-Item -LiteralPath $Source -Destination $Temporary
    if ([System.IO.File]::Exists($Target)) {
        [System.IO.File]::Replace($Temporary, $Target, $null, $true)
    }
    else {
        [System.IO.File]::Move($Temporary, $Target)
    }
}

try {
    Install-FileSafely -Source $SourceManifest -Target $DestinationManifest -Temporary $TempManifest
    Install-FileSafely -Source $SourceSprite -Target $DestinationSprite -Temporary $TempSprite
}
finally {
    foreach ($Temporary in @($TempManifest, $TempSprite)) {
        if (Test-Path -LiteralPath $Temporary) {
            Remove-Item -LiteralPath $Temporary -Force
        }
    }
}

Write-Host ""
Write-Host "奶龙安装完成：$Destination"
Write-Host "接下来打开 Settings → Pets，点击 Refresh，选择“奶龙”，再输入 /pet 唤醒。"
