#Requires -Version 7.6

<#
.SYNOPSIS
    Builds Single-File Executable releases of Win-Debloat.
    
.DESCRIPTION
    Creates standalone single-file executables (Standard/Extras) with embedded compressed payloads,
    high-DPI manifest, optimization (/o+), icon embedding, and multi-architecture platform targeting (x64 / ARM64).
    Generates SHA256 checksums, release notes, and updates distribution manifests.

.PARAMETER Version
    The release version tag (e.g. 1.0.0 or 0.0.0-CI).

.PARAMETER OutputDir
    Output directory for built executables and release artifacts (default: dist).

.PARAMETER Platform
    Target architecture platform: x64 (default), arm64, anycpu, or all.
    When 'all' is specified, builds both x64 and arm64 single-file executables.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version,
    
    [Parameter(Position = 1)]
    [string]$OutputDir = "$PSScriptRoot\..\dist",

    [ValidateSet("x64", "arm64", "anycpu", "all")]
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path "$PSScriptRoot\..").Path
$DistPath = [System.IO.Path]::GetFullPath($OutputDir)

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Win-Debloat Single-File Builder v2.1                    ║" -ForegroundColor Cyan
Write-Host "║      High-DPI • Optimized • Multi-Arch • Modern Toolchain    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "   Version:     $Version" -ForegroundColor Gray
Write-Host "   Output Dir:  $DistPath" -ForegroundColor Gray
Write-Host "   Platform:    $Platform" -ForegroundColor Gray

# 1. Clean and initialize output directory
if (Test-Path -LiteralPath $DistPath) {
    Write-Host "`n🗑️  Cleaning previous build artifacts..." -ForegroundColor Gray
    Remove-Item -LiteralPath $DistPath -Recurse -Force
}
New-Item -Path $DistPath -ItemType Directory -Force | Out-Null

$compilerScript = Join-Path $PSScriptRoot "Compile-Launcher.ps1"
if (-not (Test-Path -LiteralPath $compilerScript)) {
    throw "Compiler script not found at $compilerScript"
}

$launcherSrc = Join-Path $Root "src\core\LauncherEmbed.cs"
if (-not (Test-Path -LiteralPath $launcherSrc)) {
    throw "Launcher source not found at $launcherSrc"
}

$manifestPath = Join-Path $Root "src\core\app.manifest"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Warning "⚠️ High-DPI manifest not found at $manifestPath. Compiler will attempt fallback."
}

$iconDest = Join-Path $Root "assets\logo.ico"
if (-not (Test-Path -LiteralPath $iconDest)) {
    Write-Warning "⚠️ Icon not found at $iconDest. EXEs will be built without custom icon."
}

# Determine target architectures to build
$targetArchs = if ($Platform -eq "all") {
    @("x64", "arm64")
} else {
    @($Platform)
}

# ═══════════════════════════════════════════════════════════════
# MAIN BUILD LOOP
# ═══════════════════════════════════════════════════════════════

$builtExecutables = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($variant in @("Standard", "Extras")) {
    Write-Host "`n📦 Packaging $variant Edition..." -ForegroundColor Cyan
    
    # 1. Setup Staging Area
    $stageDir = Join-Path $DistPath "Stage_$variant"
    if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force }
    New-Item -Path $stageDir -ItemType Directory -Force | Out-Null
    
    try {
        # 2. Copy Canonical Files to Staging (Explicit inclusion avoids recursive dist copies)
        $includeItems = @(
            "Win-Debloat.ps1",
            "Win-Debloat7.ps1",
            "Win-Debloat.psd1",
            "Win-Debloat7.psd1",
            "setup-standard.ps1",
            "setup-extras.ps1",
            "LICENSE",
            "README.md",
            "CHANGELOG.md",
            "SECURITY.md",
            "CODE_OF_CONDUCT.md",
            "src",
            "config",
            "profiles",
            "assets",
            "docs"
        )

        foreach ($item in $includeItems) {
            $sourceItem = Join-Path $Root $item
            if (Test-Path -LiteralPath $sourceItem) {
                Copy-Item -Path $sourceItem -Destination $stageDir -Recurse -Force
            }
        }
        
        # Standard Cleanup (Ensure Extras module and setup-extras.ps1 are excluded from Standard edition)
        if ($variant -eq "Standard") {
            $extrasDir = Join-Path $stageDir "src\modules\Extras"
            if (Test-Path -LiteralPath $extrasDir) {
                Remove-Item -LiteralPath $extrasDir -Recurse -Force
            }
            $extrasScript = Join-Path $stageDir "setup-extras.ps1"
            if (Test-Path -LiteralPath $extrasScript) {
                Remove-Item -LiteralPath $extrasScript -Force
            }
        }
        
        # 3. Create Payload.zip
        $payloadZip = Join-Path $DistPath "payload_$variant.zip"
        if (Test-Path -LiteralPath $payloadZip) { Remove-Item -LiteralPath $payloadZip -Force }

        # Sanity check: warn (don't fail) if the staged GUI version string differs.
        $stagingGUI = Join-Path $stageDir "src\ui\gui\MainWindow.xaml"
        if (Test-Path -LiteralPath $stagingGUI) {
            $guiContent = Get-Content -LiteralPath $stagingGUI -Raw
            if ($guiContent -notmatch [regex]::Escape("v$Version")) {
                Write-Warning "Staged GUI version string does not match v$Version - update MainWindow.xaml before tagging a release."
            }
            else {
                Write-Host "   ✅ Staging Verified: GUI contains v$Version" -ForegroundColor Green
            }
        }

        Write-Host "   📦 Compressing staged payload to ZIP..." -ForegroundColor DarkGray
        Compress-Archive -Path "$stageDir\*" -DestinationPath $payloadZip -Force -ErrorAction Stop
        $zipSize = [math]::Round((Get-Item -LiteralPath $payloadZip).Length / 1MB, 2)
        Write-Host "   📦 Payload archive created ($zipSize MB)" -ForegroundColor DarkGray

        # 4. Compile Executable(s) for each target architecture
        foreach ($arch in $targetArchs) {
            # Determine canonical executable name
            # Standard/Extras x64 are default Win-Debloat.exe / Win-Debloat-Extras.exe for CI/Release compatibility
            $exeName = switch ($variant) {
                "Standard" {
                    if ($arch -eq "x64" -or ($targetArchs.Count -eq 1 -and $arch -ne "arm64")) {
                        "Win-Debloat.exe"
                    } else {
                        "Win-Debloat-$arch.exe"
                    }
                }
                "Extras" {
                    if ($arch -eq "x64" -or ($targetArchs.Count -eq 1 -and $arch -ne "arm64")) {
                        "Win-Debloat-Extras.exe"
                    } else {
                        "Win-Debloat-Extras-$arch.exe"
                    }
                }
            }

            $exeOut = Join-Path $DistPath $exeName
            Write-Host "   🔨 Building executable: $exeName ($arch)..." -ForegroundColor Gray

            # Prepare compiler invocation parameters
            $compilerParams = @{
                SourceFile = $launcherSrc
                OutputFile = $exeOut
                Resource   = $payloadZip
                Platform   = $arch
                Optimize   = $true
            }

            if ($iconDest -and (Test-Path -LiteralPath $iconDest)) {
                $compilerParams["Icon"] = $iconDest
            }
            if ($manifestPath -and (Test-Path -LiteralPath $manifestPath)) {
                $compilerParams["Manifest"] = $manifestPath
            }

            & $compilerScript @compilerParams

            if (-not (Test-Path -LiteralPath $exeOut)) {
                throw "Failed to compile $exeName (Architecture: $arch): binary not found at $exeOut"
            }

            $exeItem = Get-Item -LiteralPath $exeOut
            $exeSizeMb = [math]::Round($exeItem.Length / 1MB, 2)

            # Sanity check: Ensure payload was actually embedded (size should exceed payload zip size)
            if ($exeItem.Length -lt 100KB) {
                throw "Compiled executable $exeName is unexpectedly small ($($exeItem.Length) bytes). Embedded payload may be missing."
            }

            Write-Host "   ✅ Compiled $exeName ($exeSizeMb MB) [$arch]" -ForegroundColor Green

            $builtExecutables.Add([PSCustomObject]@{
                Name        = $exeName
                Variant     = $variant
                Arch        = $arch
                Path        = $exeOut
                SizeMb      = $exeSizeMb
                LengthBytes = $exeItem.Length
            })
        }
    }
    finally {
        # Clean up temporary staging directory and payload zip
        if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $payloadZip) { Remove-Item -LiteralPath $payloadZip -Force -ErrorAction SilentlyContinue }
    }
}

# ═══════════════════════════════════════════════════════════════
# GENERATE CHECKSUMS
# ═══════════════════════════════════════════════════════════════

Write-Host "`n🔐 Generating cryptographic SHA256 checksums..." -ForegroundColor Cyan

$checksums = @{}
$checksumFile = Join-Path $DistPath "SHA256SUMS.txt"
$sb = [System.Text.StringBuilder]::new()

foreach ($exe in $builtExecutables) {
    $hash = (Get-FileHash -Path $exe.Path -Algorithm SHA256).Hash
    $line = "$hash  $($exe.Name)"
    $sb.AppendLine($line) | Out-Null
    Write-Host "   $($exe.Name.PadRight(30)): $hash" -ForegroundColor Gray
    
    if ($exe.Name -eq "Win-Debloat.exe") {
        $checksums["Standard"] = $hash
    }
    elseif ($exe.Name -eq "Win-Debloat-Extras.exe") {
        $checksums["Extras"] = $hash
    }
}

[System.IO.File]::WriteAllText($checksumFile, $sb.ToString())
Write-Host "   ✅ SHA256SUMS.txt written." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# CREATE RELEASE NOTES
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📝 Generating release notes..." -ForegroundColor Cyan

$ReleaseNotes = @"
# Win-Debloat v$Version

## 🚀 Standalone Single-File Distributions

### ✅ Standard Edition (`Win-Debloat.exe` / `Win-Debloat-arm64.exe`)
Safe, clean Windows optimization and debloating. Contains zero flagged tools.
Self-extracts and runs under PowerShell 7.6+ LTS (auto-installs if missing).

### ⚠️ Extras Edition (`Win-Debloat-Extras.exe` / `Win-Debloat-Extras-arm64.exe`)
Includes advanced tools such as Defender Remover and MAS.
*Note: Contains specialized administrative tools flagged by some Antivirus solutions.*

## ⚙️ Binary Features
- **Modern .NET Toolchain**: Compiled with high performance optimization (`/o+`)
- **High-DPI Aware**: Native PerMonitorV2 scaling support for 4K / Multi-Monitor setups
- **UTF-8 & Long Paths**: Full modern Windows path and UTF-8 encoding support
- **Architecture**: Native x64 / ARM64 targeting

## 📋 Requirements
- Windows 10 (Build 19041+) or Windows 11
- PowerShell 7.6+ LTS (Launcher installs or updates automatically if missing)
- Administrator Privileges

## 🔐 Cryptographic Checksums (SHA-256)
``````
$($sb.ToString().Trim())
``````
"@

$ReleaseNotes | Set-Content (Join-Path $DistPath "RELEASE_NOTES.md") -Encoding UTF8
Write-Host "   ✅ RELEASE_NOTES.md written." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# UPDATE MANIFESTS (CHOCOLATEY & WINGET)
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📝 Updating package distribution manifests..." -ForegroundColor Cyan

# 1. Update Chocolatey NuSpec
$nuspecPath = Join-Path $Root "build\chocolatey\Win-Debloat.nuspec"
if (-not (Test-Path -LiteralPath $nuspecPath)) {
    $oldNuspec = Join-Path $Root "build\chocolatey\Win-Debloat7.nuspec"
    if (Test-Path -LiteralPath $oldNuspec) { $nuspecPath = $oldNuspec }
}
if (Test-Path -LiteralPath $nuspecPath) {
    (Get-Content -LiteralPath $nuspecPath) -replace "<version>.*</version>", "<version>$Version</version>" |
        Set-Content -LiteralPath $nuspecPath -Encoding UTF8
    Write-Host "   ✅ Updated Chocolatey NuSpec version to $Version" -ForegroundColor Gray
}

# 2. Update Chocolatey Install Script
$chocoInstallPath = Join-Path $Root "build\chocolatey\tools\chocolateyinstall.ps1"
if (Test-Path -LiteralPath $chocoInstallPath) {
    $content = Get-Content -LiteralPath $chocoInstallPath -Raw
    $content = $content -replace "(?m)^\s*\`$version\s*=\s*'.*'", "`$version     = '$Version'"
    if ($checksums["Standard"]) {
        $content = $content -replace "(?m)^\s*\`$checksum\s*=\s*`".*`"", "`$checksum    = `"$($checksums["Standard"])`""
    }
    Set-Content -LiteralPath $chocoInstallPath -Value $content -Encoding UTF8
    Write-Host "   ✅ Updated Chocolatey install script version & checksum" -ForegroundColor Gray
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "🎉 BUILD SUCCEEDED: Win-Debloat v$Version" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
foreach ($exe in $builtExecutables) {
    Write-Host "   📦 $($exe.Name.PadRight(30)) | $($exe.Arch.PadRight(8)) | $($exe.SizeMb) MB" -ForegroundColor White
}
Write-Host "   📁 Artifacts directory: $DistPath`n" -ForegroundColor Gray
