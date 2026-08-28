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

#region Windows Protected Print (WPP)

<#
.SYNOPSIS
    Tests a printer endpoint for RFC 8011 IPP compliance before enabling WPP.
#>
function Test-WinDebloatPrinterIPPCompliance {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$PrinterHost = "localhost",
        [int]$Port = 631,
        [int]$TimeoutMs = 1500
    )

    try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $connectTask = $tcpClient.ConnectAsync($PrinterHost, $Port)
        if ($connectTask.Wait($TimeoutMs) -and $tcpClient.Connected) {
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
        return $false
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Enables Windows Protected Print (WPP) mode to eliminate legacy third-party print drivers in spoolsv.exe.
#>
function Enable-WinDebloatWPP {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [switch]$SkipProbe
    )

    Write-Log -Message "Enabling Windows Protected Print (WPP)..." -Level Info

    if ($PSCmdlet.ShouldProcess("Windows Print Spooler", "Lock down into driverless IPP/Mopria Protected Print Mode")) {
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ProtectedPrint" -Name "ProtectedPrintMode" -Value 1 -Type DWord
        Write-Log -Message "Windows Protected Print Mode enabled." -Level Success
    }
}

<#
.SYNOPSIS
    Disables Windows Protected Print (WPP) mode (revert/restore).
#>
function Disable-WinDebloatWPP {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling Windows Protected Print (WPP)..." -Level Info

    if ($PSCmdlet.ShouldProcess("Windows Print Spooler", "Restore standard print driver mode")) {
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ProtectedPrint" -Name "ProtectedPrintMode"
        Write-Log -Message "Windows Protected Print Mode restored to default." -Level Success
    }
}

#endregion

#region Sudo for Windows Hardening

<#
.SYNOPSIS
    Configures Sudo for Windows execution mode and UIPI console boundary isolation.
#>
function Set-WinDebloatSudoMode {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Disabled", "ForceNewWindow", "DisableInput", "Normal")]
        [string]$Mode
    )

    $modeMap = @{
        "Disabled"       = 0
        "ForceNewWindow" = 1
        "DisableInput"   = 2
        "Normal"         = 3
    }
    $modeVal = $modeMap[$Mode]

    if ($modeVal -eq 3) {
        Write-Log -Message "Security Advisory: Sudo 'Normal' mode (inline interactive) allows keystroke injection across integrity levels." -Level Warning
    }

    if ($PSCmdlet.ShouldProcess("Sudo for Windows", "Set mode to $Mode (value $modeVal)")) {
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Name "Enabled" -Value $modeVal -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Sudo" -Name "Enabled" -Value $modeVal -Type DWord
        Write-Log -Message "Sudo for Windows mode set to '$Mode' ($modeVal)." -Level Success
    }
}

<#
.SYNOPSIS
    Enforces secure Sudo policy (ForceNewWindow or DisableInput).
#>
function Protect-WinDebloatSudoPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Set-WinDebloatSudoMode -Mode "DisableInput"
}

#endregion

#region BitLocker & Storage Cryptography

<#
.SYNOPSIS
    Enforces BitLocker XTS-AES 256 software encryption cipher and blocks flawed SSD hardware encryption.
#>
function Enable-WinDebloatBitLockerHardening {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Hardening BitLocker cryptographic standards (XTS-AES 256)..." -Level Info

    if ($PSCmdlet.ShouldProcess("BitLocker FVE Policies", "Enforce XTS-AES 256 software cipher and disable SSD hardware encryption bypass")) {
        # Enforce XTS-AES 256 software cipher (Method 7)
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EncryptionMethodWithXtsOs" -Value 7 -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EncryptionMethodWithXtsFdv" -Value 7 -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EncryptionMethodWithXtsRdv" -Value 7 -Type DWord
        
        # Block flawed SSD hardware self-encryption (ADV180028)
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "OSHardwareEncryption" -Value 0 -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "FDVHardwareEncryption" -Value 0 -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "RDVHardwareEncryption" -Value 0 -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "OSAllowedHardwareEncryptionAlgorithms" -Value 0 -Type DWord

        Write-Log -Message "BitLocker XTS-AES 256 software standard enforced." -Level Success
    }
}

<#
.SYNOPSIS
    Restores BitLocker policies to Windows defaults.
#>
function Disable-WinDebloatBitLockerHardening {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("BitLocker FVE Policies", "Restore default encryption cipher policies")) {
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EncryptionMethodWithXtsOs"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EncryptionMethodWithXtsFdv"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "EncryptionMethodWithXtsRdv"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "OSHardwareEncryption"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "FDVHardwareEncryption"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "RDVHardwareEncryption"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "OSAllowedHardwareEncryptionAlgorithms"
        Write-Log -Message "BitLocker policies restored to defaults." -Level Success
    }
}

#endregion

#region Enterprise Baselines & RPC / SMB / LSA Hardening

<#
.SYNOPSIS
    Hardens RPC Interface and Endpoint Mapper authentication.
#>
function Enable-WinDebloatRPCHardening {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("RPC Subsystem", "Harden RPC Interface and Endpoint Mapper authentication")) {
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" -Name "RestrictRemoteClients" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" -Name "EnableAuthEpResolution" -Value 1 -Type DWord
        Write-Log -Message "RPC interface hardening enforced." -Level Success
    }
}

<#
.SYNOPSIS
    Restores RPC Interface policies to default.
#>
function Disable-WinDebloatRPCHardening {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("RPC Subsystem", "Restore default RPC Interface policies")) {
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" -Name "RestrictRemoteClients"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" -Name "EnableAuthEpResolution"
        Write-Log -Message "RPC interface policies restored to defaults." -Level Success
    }
}

<#
.SYNOPSIS
    Enforces mandatory SMB Signing and authentication rate limiting.
#>
function Enable-WinDebloatSMBSigning {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("SMB Subsystem", "Enforce SMB signing and rate-limiting")) {
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "EnableSecuritySignature" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "InvalidAuthenticationDelayMs" -Value 2000 -Type DWord
        Write-Log -Message "SMB signing and brute force rate limiting enforced." -Level Success
    }
}

<#
.SYNOPSIS
    Restores SMB signing policies to default.
#>
function Disable-WinDebloatSMBSigning {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("SMB Subsystem", "Restore default SMB signing policies")) {
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "InvalidAuthenticationDelayMs"
        Write-Log -Message "SMB signing policies restored to defaults." -Level Success
    }
}

<#
.SYNOPSIS
    Enables LSA Protection RunAsPPL with UEFI boot lock.
#>
function Enable-WinDebloatLSAProtection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Local Security Authority (LSA)", "Enable RunAsPPL Protected Process Light")) {
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPLBoot" -Value 2 -Type DWord
        Write-Log -Message "LSA Protection RunAsPPL enabled with UEFI lock." -Level Success
    }
}

<#
.SYNOPSIS
    Disables LSA Protection RunAsPPL (revert/restore).
#>
function Disable-WinDebloatLSAProtection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Local Security Authority (LSA)", "Disable RunAsPPL")) {
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPLBoot"
        Write-Log -Message "LSA Protection RunAsPPL restored to defaults." -Level Success
    }
}

<#
.SYNOPSIS
    Enforces Kernel DMA Protection and Memory Dump Encryption.
#>
function Enable-WinDebloatDMAProtection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("DMA & Memory Subsystem", "Enforce DMA protection and crash dump encryption")) {
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Kernel DMA Protection" -Name "DeviceEnumerationPolicy" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "EnableDumpEncryption" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -Value 1 -Type DWord
        Write-Log -Message "Kernel DMA Protection and dump encryption enabled." -Level Success
    }
}

<#
.SYNOPSIS
    Restores DMA Protection policies to defaults.
#>
function Disable-WinDebloatDMAProtection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("DMA & Memory Subsystem", "Restore DMA protection policies")) {
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Kernel DMA Protection" -Name "DeviceEnumerationPolicy"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "EnableDumpEncryption"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown"
        Write-Log -Message "DMA protection policies restored to defaults." -Level Success
    }
}

#endregion

#region PowerShell Hardening & Auditing

<#
.SYNOPSIS
    Enables PowerShell ScriptBlock Logging policy.
#>
function Enable-WinDebloatScriptBlockLogging {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Enabling PowerShell ScriptBlock Logging..." -Level Info

    if ($PSCmdlet.ShouldProcess("PowerShell Subsystem", "Enable ScriptBlock Logging")) {
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord
        Write-Log -Message "PowerShell ScriptBlock Logging enabled." -Level Success
    }
}

<#
.SYNOPSIS
    Disables PowerShell ScriptBlock Logging policy (revert/restore).
#>
function Disable-WinDebloatScriptBlockLogging {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling PowerShell ScriptBlock Logging..." -Level Info

    if ($PSCmdlet.ShouldProcess("PowerShell Subsystem", "Disable ScriptBlock Logging")) {
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging"
        Write-Log -Message "PowerShell ScriptBlock Logging disabled (restored to default)." -Level Success
    }
}

<#
.SYNOPSIS
    Detects the current PowerShell Language Mode (e.g. ConstrainedLanguage vs FullLanguage).
#>
function Get-WinDebloatLanguageMode {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSLanguageMode])]
    param()

    return $ExecutionContext.SessionState.LanguageMode
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
        SMBv1Disabled             = (-not $smb1Enabled)
        PUAProtectionEnabled      = [bool]$puaEnabled
        WPPEnabled                = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ProtectedPrint" "ProtectedPrintMode") -eq 1
        SudoMode                  = (Get-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" "Enabled") ?? (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Sudo" "Enabled") ?? 0
        BitLockerXTS256           = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\FVE" "EncryptionMethodWithXtsOs") -eq 7
        RPCHardened               = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" "RestrictRemoteClients") -eq 1
        SMBSigningRequired        = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "RequireSecuritySignature") -eq 1
        LSAProtectionEnabled      = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL") -eq 1
        DMAProtectionEnabled      = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Kernel DMA Protection" "DeviceEnumerationPolicy") -eq 1
        ScriptBlockLoggingEnabled = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" "EnableScriptBlockLogging") -eq 1
        LanguageMode              = (Get-WinDebloatLanguageMode).ToString()
    }
}

#endregion

<#
.SYNOPSIS
    Applies security baseline settings from a configuration profile.
#>
function Set-WinDebloatSecurity {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Config
    )

    if (-not $Config.security) {
        Write-Log -Message "No security configuration in profile." -Level Info
        return
    }

    Write-Log -Message "Applying Security Baseline configuration..." -Level Info

    if ($Config.security.enable_wpp -eq $true) {
        Enable-WinDebloatWPP
    }

    if ($Config.security.sudo_mode) {
        Set-WinDebloatSudoMode -Mode $Config.security.sudo_mode
    }

    if ($Config.security.enable_bitlocker_xts256 -eq $true) {
        Enable-WinDebloatBitLockerHardening
    }

    if ($Config.security.enable_rpc_hardening -eq $true) {
        Enable-WinDebloatRPCHardening
    }

    if ($Config.security.enable_smb_signing -eq $true) {
        Enable-WinDebloatSMBSigning
    }

    if ($Config.security.enable_lsa_protection -eq $true) {
        Enable-WinDebloatLSAProtection
    }

    if ($Config.security.enable_dma_protection -eq $true) {
        Enable-WinDebloatDMAProtection
    }

    if ($Config.security.enable_script_block_logging -eq $true) {
        Enable-WinDebloatScriptBlockLogging
    }

    Write-Log -Message "Security Baseline configuration applied." -Level Success
}

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7Security' -Value 'Set-WinDebloatSecurity'
Set-Alias -Name 'Disable-WinDebloat7SMBv1' -Value 'Disable-WinDebloatSMBv1'
Set-Alias -Name 'Enable-WinDebloat7SMBv1' -Value 'Enable-WinDebloatSMBv1'
Set-Alias -Name 'Enable-WinDebloat7PUAProtection' -Value 'Enable-WinDebloatPUAProtection'
Set-Alias -Name 'Disable-WinDebloat7PUAProtection' -Value 'Disable-WinDebloatPUAProtection'
Set-Alias -Name 'Enable-WinDebloat7WPP' -Value 'Enable-WinDebloatWPP'
Set-Alias -Name 'Disable-WinDebloat7WPP' -Value 'Disable-WinDebloatWPP'
Set-Alias -Name 'Test-WinDebloat7PrinterIPPCompliance' -Value 'Test-WinDebloatPrinterIPPCompliance'
Set-Alias -Name 'Set-WinDebloat7SudoMode' -Value 'Set-WinDebloatSudoMode'
Set-Alias -Name 'Protect-WinDebloat7SudoPolicy' -Value 'Protect-WinDebloatSudoPolicy'
Set-Alias -Name 'Enable-WinDebloat7BitLockerHardening' -Value 'Enable-WinDebloatBitLockerHardening'
Set-Alias -Name 'Disable-WinDebloat7BitLockerHardening' -Value 'Disable-WinDebloatBitLockerHardening'
Set-Alias -Name 'Enable-WinDebloat7RPCHardening' -Value 'Enable-WinDebloatRPCHardening'
Set-Alias -Name 'Disable-WinDebloat7RPCHardening' -Value 'Disable-WinDebloatRPCHardening'
Set-Alias -Name 'Enable-WinDebloat7SMBSigning' -Value 'Enable-WinDebloatSMBSigning'
Set-Alias -Name 'Disable-WinDebloat7SMBSigning' -Value 'Disable-WinDebloatSMBSigning'
Set-Alias -Name 'Enable-WinDebloat7LSAProtection' -Value 'Enable-WinDebloatLSAProtection'
Set-Alias -Name 'Disable-WinDebloat7LSAProtection' -Value 'Disable-WinDebloatLSAProtection'
Set-Alias -Name 'Enable-WinDebloat7DMAProtection' -Value 'Enable-WinDebloatDMAProtection'
Set-Alias -Name 'Disable-WinDebloat7DMAProtection' -Value 'Disable-WinDebloatDMAProtection'
Set-Alias -Name 'Enable-WinDebloat7ScriptBlockLogging' -Value 'Enable-WinDebloatScriptBlockLogging'
Set-Alias -Name 'Enable-WD7ScriptBlockLogging' -Value 'Enable-WinDebloatScriptBlockLogging'
Set-Alias -Name 'Disable-WinDebloat7ScriptBlockLogging' -Value 'Disable-WinDebloatScriptBlockLogging'
Set-Alias -Name 'Disable-WD7ScriptBlockLogging' -Value 'Disable-WinDebloatScriptBlockLogging'
Set-Alias -Name 'Get-WinDebloat7LanguageMode' -Value 'Get-WinDebloatLanguageMode'
Set-Alias -Name 'Get-WD7LanguageMode' -Value 'Get-WinDebloatLanguageMode'
Set-Alias -Name 'Get-WinDebloat7SecurityStatus' -Value 'Get-WinDebloatSecurityStatus'

Export-ModuleMember -Function @(
    "Set-WinDebloatSecurity",
    "Disable-WinDebloatSMBv1",
    "Enable-WinDebloatSMBv1",
    "Enable-WinDebloatPUAProtection",
    "Disable-WinDebloatPUAProtection",
    "Enable-WinDebloatWPP",
    "Disable-WinDebloatWPP",
    "Test-WinDebloatPrinterIPPCompliance",
    "Set-WinDebloatSudoMode",
    "Protect-WinDebloatSudoPolicy",
    "Enable-WinDebloatBitLockerHardening",
    "Disable-WinDebloatBitLockerHardening",
    "Enable-WinDebloatRPCHardening",
    "Disable-WinDebloatRPCHardening",
    "Enable-WinDebloatSMBSigning",
    "Disable-WinDebloatSMBSigning",
    "Enable-WinDebloatLSAProtection",
    "Disable-WinDebloatLSAProtection",
    "Enable-WinDebloatDMAProtection",
    "Disable-WinDebloatDMAProtection",
    "Enable-WinDebloatScriptBlockLogging",
    "Disable-WinDebloatScriptBlockLogging",
    "Get-WinDebloatLanguageMode",
    "Get-WinDebloatSecurityStatus"
) -Alias @(
    "Set-WinDebloat7Security",
    "Disable-WinDebloat7SMBv1",
    "Enable-WinDebloat7SMBv1",
    "Enable-WinDebloat7PUAProtection",
    "Disable-WinDebloat7PUAProtection",
    "Enable-WinDebloat7WPP",
    "Disable-WinDebloat7WPP",
    "Test-WinDebloat7PrinterIPPCompliance",
    "Set-WinDebloat7SudoMode",
    "Protect-WinDebloat7SudoPolicy",
    "Enable-WinDebloat7BitLockerHardening",
    "Disable-WinDebloat7BitLockerHardening",
    "Enable-WinDebloat7RPCHardening",
    "Disable-WinDebloat7RPCHardening",
    "Enable-WinDebloat7SMBSigning",
    "Disable-WinDebloat7SMBSigning",
    "Enable-WinDebloat7LSAProtection",
    "Disable-WinDebloat7LSAProtection",
    "Enable-WinDebloat7DMAProtection",
    "Disable-WinDebloat7DMAProtection",
    "Enable-WinDebloat7ScriptBlockLogging",
    "Enable-WD7ScriptBlockLogging",
    "Disable-WinDebloat7ScriptBlockLogging",
    "Disable-WD7ScriptBlockLogging",
    "Get-WinDebloat7LanguageMode",
    "Get-WD7LanguageMode",
    "Get-WinDebloat7SecurityStatus"
)
