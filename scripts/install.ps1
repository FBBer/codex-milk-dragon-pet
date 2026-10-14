[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceManifest = Join-Path $RepoRoot "pet.json"
$SourceSprite = Join-Path $RepoRoot "spritesheet.webp"

foreach ($Source in @($SourceManifest, $SourceSprite)) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "安装失败：仓库中的 pet.json 或 spritesheet.webp 缺失。"
    }
    $SourceItem = Get-Item -LiteralPath $Source -Force
    if (($SourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "安装失败：安装来源是链接，已为安全起见停止：$Source"
    }
}

if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $UserHome = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::UserProfile
    )
    if ([string]::IsNullOrWhiteSpace($UserHome)) {
        throw "安装失败：无法确定用户目录，请将 CODEX_HOME 设置为绝对路径。"
    }
    $CodexRoot = Join-Path $UserHome ".codex"
}
else {
    $CodexRoot = $env:CODEX_HOME
}

# A drive-relative path (C:folder), provider path, or current-drive path
# (\folder) must not silently redirect an installation with the working directory.
if ($CodexRoot -notmatch '^[A-Za-z]:[\\/]' -and
    $CodexRoot -notmatch '^\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$)') {
    throw "安装失败：CODEX_HOME 必须是绝对文件系统路径。"
}
try {
    $CodexRoot = [System.IO.Path]::GetFullPath($CodexRoot)
    $PathRoot = [System.IO.Path]::GetPathRoot($CodexRoot)
    if ($CodexRoot.Length -gt $PathRoot.Length) {
        $CodexRoot = $CodexRoot.TrimEnd([char[]]@('\', '/'))
    }
}
catch {
    throw "安装失败：CODEX_HOME 不是有效的文件系统路径。"
}

$PetsRoot = Join-Path $CodexRoot "pets"
$Destination = Join-Path $PetsRoot "milk-dragon"

foreach ($Directory in @($CodexRoot, $PetsRoot, $Destination)) {
    $DirectoryItem = Get-Item -LiteralPath $Directory -Force -ErrorAction SilentlyContinue
    if ($null -ne $DirectoryItem) {
        if (($DirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "安装失败：目标目录是链接，已为安全起见停止：$Directory"
        }
        if (-not $DirectoryItem.PSIsContainer) {
            throw "安装失败：目标位置存在，但不是文件夹：$Directory"
        }
    }
}

if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
    throw "奶龙已经存在：$Destination`n如需更新，请重新运行并添加 -Force。"
}

$DestinationManifest = Join-Path $Destination "pet.json"
$DestinationSprite = Join-Path $Destination "spritesheet.webp"

function Assert-RegularTargetFile {
    param([Parameter(Mandatory = $true)][string]$Target)

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

foreach ($Target in @($DestinationManifest, $DestinationSprite)) {
    Assert-RegularTargetFile -Target $Target
}

# Use the literal filesystem API, so names containing [] are not wildcards.
[System.IO.Directory]::CreateDirectory($Destination) | Out-Null

$TempManifest = Join-Path $Destination (".pet.json.install." + [Guid]::NewGuid().ToString("N"))
$TempSprite = Join-Path $Destination (".spritesheet.webp.install." + [Guid]::NewGuid().ToString("N"))
$OwnedTemporaryFiles = New-Object 'System.Collections.Generic.List[string]'

function Copy-ToNewTemporaryFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Temporary
    )

    $SourceStream = $null
    $TemporaryStream = $null
    $Created = $false
    try {
        try {
            $SourceStream = [System.IO.File]::Open(
                $Source, [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read
            )
            # CreateNew fails on any collision, including a hard link. Never
            # overwrite or clean up a path that this invocation did not create.
            $TemporaryStream = [System.IO.File]::Open(
                $Temporary, [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write, [System.IO.FileShare]::None
            )
            $Created = $true
            $SourceStream.CopyTo($TemporaryStream)
        }
        finally {
            if ($null -ne $TemporaryStream) { $TemporaryStream.Dispose() }
            if ($null -ne $SourceStream) { $SourceStream.Dispose() }
        }
    }
    catch {
        if ($Created) { [System.IO.File]::Delete($Temporary) }
        throw
    }
}

function Install-FileSafely {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Temporary
    )

    Assert-RegularTargetFile -Target $Target
    if ([System.IO.File]::Exists($Target)) {
        # Replace the directory entry instead of writing through a hard link.
        # A backup path is unnecessary and would introduce another collision.
        # Windows PowerShell 5.1 coerces $null to an empty string for this
        # overload. NullString passes an actual null backup path to .NET.
        [System.IO.File]::Replace($Temporary, $Target, [System.Management.Automation.Language.NullString]::Value, $true)
    }
    else {
        [System.IO.File]::Move($Temporary, $Target)
    }
    [void]$OwnedTemporaryFiles.Remove($Temporary)
}

try {
    # Stage both inputs before changing either installed file.
    Copy-ToNewTemporaryFile -Source $SourceManifest -Temporary $TempManifest
    $OwnedTemporaryFiles.Add($TempManifest)
    Copy-ToNewTemporaryFile -Source $SourceSprite -Temporary $TempSprite
    $OwnedTemporaryFiles.Add($TempSprite)

    Install-FileSafely -Target $DestinationManifest -Temporary $TempManifest
    Install-FileSafely -Target $DestinationSprite -Temporary $TempSprite
}
finally {
    foreach ($Temporary in $OwnedTemporaryFiles) {
        [System.IO.File]::Delete($Temporary)
    }
}

Write-Host ""
Write-Host "奶龙安装完成：$Destination"
Write-Host "本地资源已安装；请按 README 的本地模式说明选择宠物。云端 Pets 不会因本地安装自动更新。"
