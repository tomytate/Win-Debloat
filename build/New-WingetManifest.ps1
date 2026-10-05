#Requires -Version 7.6
<#
.SYNOPSIS
    Generates standard Winget v1.28.0 manifests for Win-Debloat repository releases.
    
.DESCRIPTION
    Creates version, installer, and locale YAML manifests formatted for official
    microsoft/winget-pkgs submissions according to the latest WinGet v1.28.0 specification
    (supported by Windows Package Manager v1.29.380+).
    Includes multi-architecture portable installer metadata (x64 / ARM64) and SHA256 hashes.
#>

[CmdletBinding()]
param(
    [string]$Version = "1.7.0",
    [string]$PackageIdentifier = "TomyTate.WinDebloat",
    [string]$Publisher = "Tomy Tate",
    [string]$PackageName = "Win-Debloat",
    [string]$OutputDirectory = "$PSScriptRoot\winget-manifests"
)

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

$releaseDate = (Get-Date).ToString("yyyy-MM-dd")

# 1. Version Manifest (v1.28.0)
$versionManifest = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.1.28.0.schema.json

PackageIdentifier: $PackageIdentifier
PackageVersion: $Version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.28.0
"@

# 2. Installer Manifest (v1.28.0 - Portable Multi-Arch)
$distDir = Join-Path $PSScriptRoot "..\dist"
$exeX64 = Join-Path $distDir "Win-Debloat.exe"
$exeArm64 = Join-Path $distDir "Win-Debloat-arm64.exe"

$hashX64 = if (Test-Path -LiteralPath $exeX64) { (Get-FileHash -Path $exeX64 -Algorithm SHA256).Hash.ToUpperInvariant() } else { "0000000000000000000000000000000000000000000000000000000000000000" }
$hashArm64 = if (Test-Path -LiteralPath $exeArm64) { (Get-FileHash -Path $exeArm64 -Algorithm SHA256).Hash.ToUpperInvariant() } else { $hashX64 }

$installerManifest = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.1.28.0.schema.json

PackageIdentifier: $PackageIdentifier
PackageVersion: $Version
InstallerType: portable
Commands:
  - win-debloat
ReleaseDate: $releaseDate
Installers:
  - Architecture: x64
    InstallerUrl: https://github.com/tomytate/Win-Debloat/releases/download/v$Version/Win-Debloat.exe
    InstallerSha256: $hashX64
  - Architecture: arm64
    InstallerUrl: https://github.com/tomytate/Win-Debloat/releases/download/v$Version/Win-Debloat-arm64.exe
    InstallerSha256: $hashArm64
ManifestType: installer
ManifestVersion: 1.28.0
"@

# 3. Default Locale Manifest (v1.28.0)
$localeManifest = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.1.28.0.schema.json

PackageIdentifier: $PackageIdentifier
PackageVersion: $Version
PackageLocale: en-US
Publisher: $Publisher
PublisherUrl: https://github.com/tomytate
PublisherSupportUrl: https://github.com/tomytate/Win-Debloat/issues
Author: $Publisher
PackageName: $PackageName
PackageUrl: https://github.com/tomytate/Win-Debloat
License: MIT
LicenseUrl: https://raw.githubusercontent.com/tomytate/Win-Debloat/main/LICENSE
Copyright: Copyright (c) 2026 Tomy Tate. All rights reserved.
ShortDescription: Enterprise-grade Windows 11/10 debloating, optimization, and privacy tuning framework.
Description: |-
  Win-Debloat is a zero-tech-debt, high-performance PowerShell framework designed to debloat,
  harden, and tune Windows 11 and 10 with mathematical AST parity, DPAPI state rollback,
  and native hardware-aware scheduling.
Moniker: win-debloat
Tags:
  - debloat
  - windows-11
  - optimization
  - privacy
  - gaming
  - powershell
ReleaseNotesUrl: https://github.com/tomytate/Win-Debloat/releases/tag/v$Version
ManifestType: defaultLocale
ManifestVersion: 1.28.0
"@

Set-Content -Path (Join-Path $OutputDirectory "$PackageIdentifier.yaml") -Value $versionManifest -Encoding UTF8
Set-Content -Path (Join-Path $OutputDirectory "$PackageIdentifier.installer.yaml") -Value $installerManifest -Encoding UTF8
Set-Content -Path (Join-Path $OutputDirectory "$PackageIdentifier.locale.en-US.yaml") -Value $localeManifest -Encoding UTF8

Write-Host "Generated Winget v1.28.0 manifests in $OutputDirectory for version $Version."
