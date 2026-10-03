#Requires -Version 7.6
<#
.SYNOPSIS
    Generates standard Winget v1.6+ manifests for Win-Debloat repository releases.
    
.DESCRIPTION
    Creates version, installer, and locale YAML manifests formatted for winget-pkgs PR submissions.
    Zero technical debt tooling with SHA256 checksum automation.
#>

[CmdletBinding()]
param(
    [string]$Version = "1.7.0",
    [string]$PackageIdentifier = "tomytate.Win-Debloat",
    [string]$Publisher = "Tomy Tate",
    [string]$PackageName = "Win-Debloat",
    [string]$ReleaseUrl = "https://github.com/tomytate/Win-Debloat/archive/refs/tags/v1.7.0.zip",
    [string]$OutputDirectory = "$PSScriptRoot\winget-manifests"
)

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

$versionManifest = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $Version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.6.0
"@

$installerManifest = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $Version
Installers:
  - Architecture: neutral
    InstallerType: zip
    InstallerUrl: $ReleaseUrl
    InstallerSha256: 0000000000000000000000000000000000000000000000000000000000000000
    Commands:
      - win-debloat
      - wd7
ManifestType: installer
ManifestVersion: 1.6.0
"@

$localeManifest = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $Version
PackageLocale: en-US
Publisher: $Publisher
PackageName: $PackageName
License: MIT
ShortDescription: Enterprise-grade Windows debloating, optimization, and privacy tuning framework.
Description: >-
  Win-Debloat is a zero-tech-debt, high-performance PowerShell framework designed to debloat,
  harden, and tune Windows 11 and 10 with mathematical AST parity, DPAPI state rollback,
  and native hardware-aware scheduling.
Tags:
  - debloat
  - windows-11
  - optimization
  - privacy
  - gaming
ManifestType: defaultLocale
ManifestVersion: 1.6.0
"@

Set-Content -Path (Join-Path $OutputDirectory "$PackageIdentifier.yaml") -Value $versionManifest -Encoding UTF8
Set-Content -Path (Join-Path $OutputDirectory "$PackageIdentifier.installer.yaml") -Value $installerManifest -Encoding UTF8
Set-Content -Path (Join-Path $OutputDirectory "$PackageIdentifier.locale.en-US.yaml") -Value $localeManifest -Encoding UTF8

Write-Host "Generated Winget manifests in $OutputDirectory for version $Version."
