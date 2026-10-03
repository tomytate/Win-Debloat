#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft Intune Win32 App Detection Script for Win-Debloat.
    
.DESCRIPTION
    Standard custom detection script for Microsoft Intune Win32 Application deployment.
    Evaluates system registry stamp recorded at HKLM:\SOFTWARE\Win-Debloat.
    Emits standard stdout and returns exit code 0 when detected, 1 otherwise.
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "1.7.0"
)

$stampKey = "HKLM:\SOFTWARE\Win-Debloat"

try {
    if (Test-Path -LiteralPath $stampKey) {
        $applied = Get-ItemPropertyValue -Path $stampKey -Name "Applied" -ErrorAction SilentlyContinue
        $version = Get-ItemPropertyValue -Path $stampKey -Name "Version" -ErrorAction SilentlyContinue

        if ($applied -eq 1 -and [string]::Compare($version, $MinimumVersion) -ge 0) {
            Write-Host "Win-Debloat Enterprise Baseline Detected (Version: $version)"
            exit 0
        }
    }
}
catch {
    # Detection script must fail silently with non-zero exit code
}

exit 1
