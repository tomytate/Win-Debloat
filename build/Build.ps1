#Requires -Version 7.6
<#
.SYNOPSIS
    Standard Entrypoint for Win-Debloat Release Packaging.
.DESCRIPTION
    Delegates to Build-DualRelease.ps1 to build standalone executables,
    SPDX 2.3 SBOMs, checksums, and package manifests.
#>
[CmdletBinding()]
param(
    [string]$Version = "1.7.0",
    [string]$OutputDir = "$PSScriptRoot\..\dist",
    [ValidateSet("x64", "arm64", "anycpu", "all")]
    [string]$Platform = "all",
    [string]$SignCertPath,
    [securestring]$SignCertPassword,
    [string]$TimestampServer = "http://timestamp.acs.microsoft.com"
)

& "$PSScriptRoot\Build-DualRelease.ps1" @PSBoundParameters
