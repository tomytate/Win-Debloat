#Requires -Version 7.6

<#
.SYNOPSIS
    System Security Hardening module for Win-Debloat
    
.DESCRIPTION
    Applies security best practices.
    Disables SMBv1, Enables PUA Protection, etc.
    
.NOTES
    Module: Win-Debloat.Modules.Security
    Version: 2.0.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force

#region Protocol Hardening

<#
.SYNOPSIS
    Disables SMBv1 Protocol.
#>
function Disable-WinDebloatSMBv1 {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling SMBv1 Protocol..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("SMBv1", "Disable Protocol")) {
        if (Get-Command Set-SmbServerConfiguration -ErrorAction SilentlyContinue) {
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
            Write-Log -Message "SMBv1 Disabled (via Cmdlet)." -Level Success
        }
        else {
            Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -Type DWord
            Write-Log -Message "SMBv1 Disabled (via Registry)." -Level Success
        }
    }
}

<#
.SYNOPSIS
    Enables SMBv1 Protocol (revert/restore).
#>
function Enable-WinDebloatSMBv1 {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Enabling SMBv1 Protocol..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("SMBv1", "Enable Protocol")) {
        if (Get-Command Set-SmbServerConfiguration -ErrorAction SilentlyContinue) {
            Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force -ErrorAction SilentlyContinue
            Write-Log -Message "SMBv1 Enabled (via Cmdlet)." -Level Success
        }
        else {
            Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 1 -Type DWord
            Write-Log -Message "SMBv1 Enabled (via Registry)." -Level Success
        }
    }
}

#endregion

#region Defender Hardening

<#
.SYNOPSIS
    Enables PUA (Potentially Unwanted Application) Protection.
#>
function Enable-WinDebloatPUAProtection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Enabling Defender PUA Protection..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows Defender", "Enable PUA Protection")) {
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
            Write-Log -Message "PUA Protection Enabled." -Level Success
        }
        else {
            Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePua" -Value 1 -Type DWord
            Write-Log -Message "PUA Protection Enabled (via Registry)." -Level Success
        }
    }
}

<#
.SYNOPSIS
    Disables Defender PUA Protection (revert/restore).
#>
function Disable-WinDebloatPUAProtection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling Defender PUA Protection..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows Defender", "Disable PUA Protection")) {
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference -PUAProtection Disabled -ErrorAction SilentlyContinue
            Write-Log -Message "PUA Protection Disabled." -Level Success
        }
        else {
            Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePua"
            Write-Log -Message "PUA Protection Disabled (via Registry)." -Level Success
        }
    }
}

#endregion

#region Security Status

<#
.SYNOPSIS
    Gets the current security hardening status.
#>
function Get-WinDebloatSecurityStatus {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()

    $smb1Enabled = $true
    $regVal = Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SMB1"
    if ($null -ne $regVal) {
        $smb1Enabled = ($regVal -ne 0)
    }
    elseif (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue) {
        $smbConfig = Get-SmbServerConfiguration -ErrorAction SilentlyContinue
        if ($smbConfig) {
            $smb1Enabled = [bool]$smbConfig.EnableSMB1Protocol
        }
    }

    $puaEnabled = $false
    $puaReg = Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" "MpEnablePua"
    if ($null -ne $puaReg) {
        $puaEnabled = ($puaReg -eq 1)
    }
    elseif (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
        $mpPref = Get-MpPreference -ErrorAction SilentlyContinue
        if ($mpPref) {
            $puaEnabled = ($mpPref.PUAProtection -eq 1 -or $mpPref.PUAProtection -eq "Enabled")
        }
    }

    return [pscustomobject]@{
        SMBv1Disabled        = (-not $smb1Enabled)
        PUAProtectionEnabled = [bool]$puaEnabled
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Disable-WinDebloat7SMBv1' -Value 'Disable-WinDebloatSMBv1'
Set-Alias -Name 'Enable-WinDebloat7SMBv1' -Value 'Enable-WinDebloatSMBv1'
Set-Alias -Name 'Enable-WinDebloat7PUAProtection' -Value 'Enable-WinDebloatPUAProtection'
Set-Alias -Name 'Disable-WinDebloat7PUAProtection' -Value 'Disable-WinDebloatPUAProtection'
Set-Alias -Name 'Get-WinDebloat7SecurityStatus' -Value 'Get-WinDebloatSecurityStatus'

Export-ModuleMember -Function @(
    "Disable-WinDebloatSMBv1",
    "Enable-WinDebloatSMBv1",
    "Enable-WinDebloatPUAProtection",
    "Disable-WinDebloatPUAProtection",
    "Get-WinDebloatSecurityStatus"
) -Alias @(
    "Disable-WinDebloat7SMBv1",
    "Enable-WinDebloat7SMBv1",
    "Enable-WinDebloat7PUAProtection",
    "Disable-WinDebloat7PUAProtection",
    "Get-WinDebloat7SecurityStatus"
)
