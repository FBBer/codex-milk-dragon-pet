[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 and PowerShell 7 can run this without Pester. Every
# installation stays in this invocation's isolated, uniquely named fixture.
$TestRepository = Split-Path -Parent $PSScriptRoot
$TestInstaller = Join-Path $TestRepository "scripts\install.ps1"
$TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "milk-dragon-install-tests-" + [Guid]::NewGuid().ToString("N")
)
if (Test-Path -LiteralPath $TestRoot) {
    throw "Refusing to use a preexisting test fixture: $TestRoot"
}
[System.IO.Directory]::CreateDirectory($TestRoot) | Out-Null
$TestLinks = New-Object 'System.Collections.Generic.List[string]'
$PreviousCodexHome = $env:CODEX_HOME
$PreviousLocation = Get-Location

function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Assert-Text {
    param([string]$Path, [string]$Expected)
    Assert-Test ([System.IO.File]::ReadAllText($Path) -ceq $Expected) "Changed file: $Path"
}

function Assert-InstallFails {
    param(
        [string]$HomePath,
        [string]$InstallerPath = $TestInstaller,
        [string]$ExpectedMessage = ""
    )
    $env:CODEX_HOME = $HomePath
    $Failed = $false
    try {
        & $InstallerPath -Force | Out-Null
    }
    catch {
        $Failed = $true
        if ($ExpectedMessage) {
            Assert-Test ($_.Exception.Message.Contains($ExpectedMessage)) (
                "Unexpected installer failure: " + $_.Exception.Message
            )
        }
    }
    Assert-Test $Failed "Installer unexpectedly accepted $HomePath"
}

function Assert-NoTemporaryFiles {
    param([string]$DestinationPath)
    if (Test-Path -LiteralPath $DestinationPath -PathType Container) {
        $Leftovers = @(Get-ChildItem -LiteralPath $DestinationPath -Force |
            Where-Object { $_.Name -like ".*.install.*" })
        Assert-Test ($Leftovers.Count -eq 0) "Installer left temporary files in $DestinationPath"
    }
}

function New-TestPackage {
    param([string]$Name)
    $PackagePath = Join-Path $TestRoot $Name
    [System.IO.Directory]::CreateDirectory((Join-Path $PackagePath "scripts")) | Out-Null
    foreach ($FileName in @("pet.json", "spritesheet.webp", "scripts\install.ps1")) {
        [System.IO.File]::Copy(
            (Join-Path $TestRepository $FileName), (Join-Path $PackagePath $FileName)
        )
    }
    return $PackagePath
}

function New-TestLink {
    param([string]$Path, [string]$Target, [string]$Kind)
    New-Item -ItemType $Kind -Path $Path -Target $Target | Out-Null
    if ($Kind -ne "HardLink") { $TestLinks.Add($Path) }
}

try {
    Set-Location -LiteralPath $TestRoot

    # Literal brackets, spaces, and non-ASCII text must identify one directory.
    $LiteralHome = Join-Path $TestRoot "奶龙 codex [literal] home"
    $LiteralDestination = Join-Path $LiteralHome "pets\milk-dragon"
    $env:CODEX_HOME = $LiteralHome
    & $TestInstaller
    foreach ($FileName in @("pet.json", "spritesheet.webp")) {
        Assert-Test (
            (Get-FileHash -LiteralPath (Join-Path $TestRepository $FileName)).Hash -eq
            (Get-FileHash -LiteralPath (Join-Path $LiteralDestination $FileName)).Hash
        ) "Installed $FileName differs from the package."
    }
    $UserFile = Join-Path $LiteralDestination "user-notes.txt"
    [System.IO.File]::WriteAllText($UserFile, "keep-user-data")
    & $TestInstaller -Force
    Assert-Text $UserFile "keep-user-data"
    Assert-NoTemporaryFiles $LiteralDestination

    foreach ($InvalidHome in @("relative-home", "C:drive-relative", "\current-drive", "Registry::HKEY_CURRENT_USER")) {
        Assert-InstallFails $InvalidHome -ExpectedMessage "绝对文件系统路径"
    }
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $TestRoot "relative-home"))) (
        "Relative input created a directory in the working directory."
    )

    # Existing files at each directory boundary must be left untouched.
    foreach ($Boundary in @("root", "pets", "destination")) {
        $BoundaryHome = Join-Path $TestRoot ("file-boundary-" + $Boundary)
        $BoundaryPath = $BoundaryHome
        if ($Boundary -eq "pets") {
            [System.IO.Directory]::CreateDirectory($BoundaryHome) | Out-Null
            $BoundaryPath = Join-Path $BoundaryHome "pets"
        }
        elseif ($Boundary -eq "destination") {
            [System.IO.Directory]::CreateDirectory((Join-Path $BoundaryHome "pets")) | Out-Null
            $BoundaryPath = Join-Path $BoundaryHome "pets\milk-dragon"
        }
        [System.IO.File]::WriteAllText($BoundaryPath, "boundary-canary")
        Assert-InstallFails $BoundaryHome -ExpectedMessage "不是文件夹"
        Assert-Text $BoundaryPath "boundary-canary"
    }

    # Junctions need no symbolic-link privilege. Check every direct writable
    # boundary, including a configured root with a trailing separator.
    foreach ($Boundary in @("root", "pets", "destination")) {
        $JunctionHome = Join-Path $TestRoot ("junction-boundary-" + $Boundary)
        $Outside = Join-Path $TestRoot ("outside-" + $Boundary)
        [System.IO.Directory]::CreateDirectory($Outside) | Out-Null
        $OutsideCanary = Join-Path $Outside "canary.txt"
        [System.IO.File]::WriteAllText($OutsideCanary, "outside-canary")
        $JunctionPath = $JunctionHome
        if ($Boundary -eq "pets") {
            [System.IO.Directory]::CreateDirectory($JunctionHome) | Out-Null
            $JunctionPath = Join-Path $JunctionHome "pets"
        }
        elseif ($Boundary -eq "destination") {
            [System.IO.Directory]::CreateDirectory((Join-Path $JunctionHome "pets")) | Out-Null
            $JunctionPath = Join-Path $JunctionHome "pets\milk-dragon"
        }
        New-TestLink $JunctionPath $Outside "Junction"
        Assert-InstallFails ($JunctionHome + "\") -ExpectedMessage "目标目录是链接"
        Assert-Text $OutsideCanary "outside-canary"
        Assert-Test (@(Get-ChildItem -LiteralPath $Outside -Force).Count -eq 1) (
            "A linked directory redirected installation outside its home."
        )
    }

    # A blocked second output must not change the first output during preflight.
    foreach ($BlockedFile in @("pet.json", "spritesheet.webp")) {
        $BlockedHome = Join-Path $TestRoot ("blocked-output-" + $BlockedFile)
        $BlockedDestination = Join-Path $BlockedHome "pets\milk-dragon"
        [System.IO.Directory]::CreateDirectory($BlockedDestination) | Out-Null
        $OtherFile = if ($BlockedFile -eq "pet.json") { "spritesheet.webp" } else { "pet.json" }
        $OtherPath = Join-Path $BlockedDestination $OtherFile
        [System.IO.File]::WriteAllText($OtherPath, "installed-canary")
        [System.IO.Directory]::CreateDirectory((Join-Path $BlockedDestination $BlockedFile)) | Out-Null
        Assert-InstallFails $BlockedHome -ExpectedMessage "不是普通文件"
        Assert-Text $OtherPath "installed-canary"
        Assert-NoTemporaryFiles $BlockedDestination
    }

    # Missing input and linked input must fail before creating an install home.
    # File symbolic links require Developer Mode or symlink privilege on Windows;
    # the GitHub-hosted Windows runner supplies that privilege.
    foreach ($FileName in @("pet.json", "spritesheet.webp")) {
        $MissingPackage = New-TestPackage ("missing-source-" + $FileName)
        [System.IO.File]::Delete((Join-Path $MissingPackage $FileName))
        $MissingHome = Join-Path $TestRoot ("missing-home-" + $FileName)
        Assert-InstallFails $MissingHome (Join-Path $MissingPackage "scripts\install.ps1") "缺失"
        Assert-Test (-not (Test-Path -LiteralPath $MissingHome)) "Missing input created an install home."

        $LinkedPackage = New-TestPackage ("linked-source-" + $FileName)
        $LinkedSource = Join-Path $LinkedPackage $FileName
        $SourceCanary = Join-Path $TestRoot ("source-canary-" + $FileName)
        [System.IO.File]::WriteAllText($SourceCanary, "source-canary")
        [System.IO.File]::Delete($LinkedSource)
        New-TestLink $LinkedSource $SourceCanary "SymbolicLink"
        $LinkedHome = Join-Path $TestRoot ("linked-source-home-" + $FileName)
        Assert-InstallFails $LinkedHome (Join-Path $LinkedPackage "scripts\install.ps1") "安装来源是链接"
        Assert-Text $SourceCanary "source-canary"
        Assert-Test (-not (Test-Path -LiteralPath $LinkedHome)) "Linked input created an install home."
    }

    # Deterministically collide with each temporary path by replacing only the
    # GUID expression in a fixture copy. No test-only hook enters the installer.
    $CollisionPackage = New-TestPackage "collision-package"
    $CollisionInstaller = Join-Path $CollisionPackage "scripts\install.ps1"
    $InstallerText = [System.IO.File]::ReadAllText($CollisionInstaller)
    $GuidExpression = '[Guid]::NewGuid().ToString("N")'
    Assert-Test (
        [regex]::Matches($InstallerText, [regex]::Escape($GuidExpression)).Count -eq 2
    ) "Temporary-path test needs exactly two GUID expressions."
    $FixedGuid = "00000000000000000000000000000000"
    $InstallerText = $InstallerText.Replace($GuidExpression, ('"' + $FixedGuid + '"'))
    [System.IO.File]::WriteAllText($CollisionInstaller, $InstallerText, (New-Object System.Text.UTF8Encoding($true)))
    foreach ($FileName in @("pet.json", "spritesheet.webp")) {
        $CollisionHome = Join-Path $TestRoot ("collision-home-" + $FileName)
        $CollisionDestination = Join-Path $CollisionHome "pets\milk-dragon"
        [System.IO.Directory]::CreateDirectory($CollisionDestination) | Out-Null
        foreach ($InstalledFile in @("pet.json", "spritesheet.webp")) {
            [System.IO.File]::WriteAllText((Join-Path $CollisionDestination $InstalledFile), "old-install")
        }
        $CollisionPath = Join-Path $CollisionDestination ("." + $FileName + ".install." + $FixedGuid)
        $CollisionCanary = Join-Path $TestRoot ("collision-canary-" + $FileName)
        [System.IO.File]::WriteAllText($CollisionCanary, "collision-canary")
        New-TestLink $CollisionPath $CollisionCanary "HardLink"
        Assert-InstallFails $CollisionHome $CollisionInstaller
        Assert-Text $CollisionCanary "collision-canary"
        Assert-Text $CollisionPath "collision-canary"
        foreach ($InstalledFile in @("pet.json", "spritesheet.webp")) {
            Assert-Text (Join-Path $CollisionDestination $InstalledFile) "old-install"
        }
        $Leftovers = @(Get-ChildItem -LiteralPath $CollisionDestination -Force |
            Where-Object { $_.Name -like ".*.install.*" })
        Assert-Test ($Leftovers.Count -eq 1 -and $Leftovers[0].FullName -eq $CollisionPath) (
            "Collision cleanup deleted a foreign path or leaked an owned temporary."
        )
    }

    Write-Host "PASS: Windows path, source, directory boundary, preflight, and temporary hard-link collision regressions."
}
finally {
    $env:CODEX_HOME = $PreviousCodexHome
    Set-Location -LiteralPath $PreviousLocation.Path
    # Remove each link directly before recursive cleanup: never traverse a
    # fixture junction or symbolic link on Windows PowerShell 5.1.
    foreach ($LinkPath in $TestLinks) {
        $LinkItem = Get-Item -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $LinkItem -and
            ($LinkItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            if ($LinkItem.PSIsContainer) { [System.IO.Directory]::Delete($LinkPath) }
            else { [System.IO.File]::Delete($LinkPath) }
        }
    }
    [System.IO.Directory]::Delete($TestRoot, $true)
}
