#Requires -Version 7.6

<#
.SYNOPSIS
    Builds Single-File Executable releases of Win-Debloat with Dual-Layer Signing and SPDX SBOM.
    
.DESCRIPTION
    Creates standalone single-file executables (Standard/Extras) with embedded compressed payloads,
    high-DPI manifest, optimization (/o+), icon embedding, and multi-architecture platform targeting (x64 / ARM64).
    Generates SHA256 checksums, release notes, SPDX 2.3 JSON Software Bill of Materials (SBOM),
    optional Authenticode Dual-Signing (inner script layer + outer PE binary) with RFC 3161 timestamps,
    and updates distribution manifests.

.PARAMETER Version
    The release version tag (e.g. 1.6.0 or 0.0.0-CI).

.PARAMETER OutputDir
    Output directory for built executables and release artifacts (default: dist).

.PARAMETER Platform
    Target architecture platform: x64, arm64, anycpu, or all (default: all).

.PARAMETER SignCertPath
    Optional path to a code signing PFX certificate for Authenticode dual-signing.

.PARAMETER SignCertPassword
    Optional password for the code signing certificate.

.PARAMETER TimestampServer
    RFC 3161 timestamp server URL (default: http://timestamp.acs.microsoft.com).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version,
    
    [Parameter(Position = 1)]
    [string]$OutputDir = "$PSScriptRoot\..\dist",

    [ValidateSet("x64", "arm64", "anycpu", "all")]
    [string]$Platform = "all",

    [string]$SignCertPath,
    [securestring]$SignCertPassword,
    [string]$TimestampServer = "http://timestamp.acs.microsoft.com"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path "$PSScriptRoot\..").Path
$DistPath = [System.IO.Path]::GetFullPath($OutputDir)

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Win-Debloat Single-File Builder v2.2 (v1.6.0)           ║" -ForegroundColor Cyan
Write-Host "║      High-DPI • Multi-Arch • Dual-Signing • SPDX 2.3 SBOM    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "   Version:     $Version" -ForegroundColor Gray
Write-Host "   Output Dir:  $DistPath" -ForegroundColor Gray
Write-Host "   Platform:    $Platform" -ForegroundColor Gray

# 1. Clean and initialize output directory
if (Test-Path -LiteralPath $DistPath) {
    Write-Host "`n🗑️  Cleaning previous build artifacts..." -ForegroundColor Gray
    Get-ChildItem -LiteralPath $DistPath -Force | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop }
        catch { Write-Warning "Could not remove $($_.Name): file may be in use." }
    }
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

# Load signing certificate if specified
$codeSigningCert = $null
if ($SignCertPath -and (Test-Path -LiteralPath $SignCertPath)) {
    Write-Host "`n🔐 Loading Authenticode Signing Certificate..." -ForegroundColor Yellow
    try {
        $codeSigningCert = if ($SignCertPassword) {
            Get-PfxCertificate -FilePath $SignCertPath -Password $SignCertPassword
        } else {
            Get-PfxCertificate -FilePath $SignCertPath
        }
        Write-Host "   ✅ Certificate Loaded: $($codeSigningCert.Subject)" -ForegroundColor Green
    }
    catch {
        Write-Warning "⚠️ Failed to load code signing certificate: $($_.Exception.Message)"
    }
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
        # 2. Copy Canonical Files to Staging
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

        # Sign Inner Staged PowerShell Scripts (Layer 1 Signing)
        if ($codeSigningCert) {
            Write-Host "   🔏 Signing inner staged scripts..." -ForegroundColor DarkGray
            Get-ChildItem -Path $stageDir -Include *.ps1, *.psm1, *.psd1 -Recurse | ForEach-Object {
                try {
                    Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $codeSigningCert -TimestampServer $TimestampServer -HashAlgorithm SHA256 -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    # Continue if timestamping has momentary network lag
                }
            }
        }
        
        # 3. Create Payload.zip
        $payloadZip = Join-Path $DistPath "payload_$variant.zip"
        if (Test-Path -LiteralPath $payloadZip) { Remove-Item -LiteralPath $payloadZip -Force }

        Write-Host "   📦 Compressing staged payload to ZIP..." -ForegroundColor DarkGray
        Compress-Archive -Path "$stageDir\*" -DestinationPath $payloadZip -Force -ErrorAction Stop
        $zipSize = [math]::Round((Get-Item -LiteralPath $payloadZip).Length / 1MB, 2)
        Write-Host "   📦 Payload archive created ($zipSize MB)" -ForegroundColor DarkGray

        # 4. Compile Executable(s) for each target architecture
        foreach ($arch in $targetArchs) {
            $exeName = switch ($variant) {
                "Standard" {
                    if ($arch -eq "x64") {
                        "Win-Debloat.exe"
                    } else {
                        "Win-Debloat-$arch.exe"
                    }
                }
                "Extras" {
                    if ($arch -eq "x64") {
                        "Win-Debloat-Extras.exe"
                    } else {
                        "Win-Debloat-Extras-$arch.exe"
                    }
                }
            }

            $exeOut = Join-Path $DistPath $exeName
            Write-Host "   🔨 Building executable: $exeName ($arch)..." -ForegroundColor Gray

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

            # Sign Outer PE Executable (Layer 2 Signing)
            if ($codeSigningCert) {
                Write-Host "   🔏 Signing outer binary $exeName..." -ForegroundColor DarkGray
                try {
                    Set-AuthenticodeSignature -FilePath $exeOut -Certificate $codeSigningCert -TimestampServer $TimestampServer -HashAlgorithm SHA256 | Out-Null
                } catch {
                    Write-Warning "⚠️ Failed to sign binary ${exeName}: $($_.Exception.Message)"
                }
            }

            $exeItem = Get-Item -LiteralPath $exeOut
            $exeSizeMb = [math]::Round($exeItem.Length / 1MB, 2)

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
# GENERATE SPDX 2.3 JSON SBOM
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📋 Generating SPDX 2.3 JSON Software Bill of Materials (SBOM)..." -ForegroundColor Cyan
$sbomPackages = [System.Collections.Generic.List[psobject]]::new()

foreach ($exe in $builtExecutables) {
    $hash = (Get-FileHash -Path $exe.Path -Algorithm SHA256).Hash
    $sbomPackages.Add([ordered]@{
        SPDXID           = "SPDXRef-Package-$($exe.Name -replace '[^a-zA-Z0-9]', '-')"
        name             = $exe.Name
        versionInfo      = $Version
        downloadLocation = "https://github.com/tomytate/Win-Debloat/releases/download/v$Version/$($exe.Name)"
        filesAnalyzed    = $false
        checksums        = @(
            @{
                algorithm = "SHA256"
                checksumValue = $hash
            }
        )
        licenseConcluded = "MIT"
        licenseDeclared  = "MIT"
        copyrightText    = "Copyright (c) 2026 Tomy Tate"
        description      = "$($exe.Variant) Edition standalone binary for Windows ($($exe.Arch))"
    })
}

$sbom = [ordered]@{
    spdxVersion    = "SPDX-2.3"
    dataLicense    = "CC0-1.0"
    SPDXID         = "SPDXRef-DOCUMENT"
    name           = "Win-Debloat-v$Version-SBOM"
    documentNamespace = "https://github.com/tomytate/Win-Debloat/releases/tag/v$Version/sbom.spdx.json"
    creationInfo   = [ordered]@{
        created  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        creators = @("Tool: WinDebloat-Builder-2.2", "Organization: Win-Debloat Team")
    }
    packages       = $sbomPackages
}

$sbomPath = Join-Path $DistPath "win-debloat-sbom.spdx.json"
$sbom | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sbomPath -Encoding UTF8
Write-Host "   ✅ win-debloat-sbom.spdx.json written." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# CREATE RELEASE NOTES
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📝 Generating release notes..." -ForegroundColor Cyan

$ReleaseNotes = @"
# Win-Debloat v$Version

## 🚀 Standalone Single-File Distributions

### ✅ Standard Edition (`Win-Debloat.exe` / `Win-Debloat-arm64.exe`)
Safe, clean Windows optimization, AI Fabric RAM reclaiming, and debloating. Contains zero flagged tools.
Self-extracts and runs under PowerShell 7.6+ LTS / Windows PowerShell 5.1 (auto-installs if missing).

### ⚠️ Extras Edition (`Win-Debloat-Extras.exe` / `Win-Debloat-Extras-arm64.exe`)
Includes advanced tools such as Defender Remover and MAS.
*Note: Contains specialized administrative tools flagged by some Antivirus solutions.*

## ⚙️ Binary Features
- **Modern .NET Toolchain**: Compiled with high performance optimization (`/o+`)
- **High-DPI Aware**: Native PerMonitorV2 scaling support for 4K / Multi-Monitor setups
- **UTF-8 & Long Paths**: Full modern Windows path and UTF-8 encoding support
- **Architecture**: Native x64 / ARM64 targeting
- **Supply Chain Security**: Dual-Layer Authenticode Signing & SPDX 2.3 JSON SBOM

## 📋 Requirements
- Windows 10 (Build 19041+) or Windows 11 (23H2 / 24H2 / 25H2 / 26H1)
- PowerShell 7.6+ LTS or Windows PowerShell 5.1
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
