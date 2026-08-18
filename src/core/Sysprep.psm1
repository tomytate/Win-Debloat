#Requires -Version 7.6

<#
.SYNOPSIS
    Handles Sysprep Audit Mode detection and Default User registry operations.
    
.DESCRIPTION
    Provides functions to detect if Windows is in Audit Mode and to mount/dismount
    the Default User registry hive for applying settings to future users (OEM scenarios).
    
.NOTES
    Module: Win-Debloat.Core.Sysprep
    Version: 1.5.0
#>

Import-Module "$PSScriptRoot\Logger.psm1" -Force

function Test-WinDebloatSysprep {
    <#
    .SYNOPSIS
        Checks if the system is currently in Sysprep Audit Mode.
    
    .OUTPUTS
        Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $auditVal = Get-ItemPropertyValue -LiteralPath "HKLM:\SYSTEM\Setup\Status" -Name "AuditBoot" -ErrorAction SilentlyContinue
    if ($auditVal -eq 1) {
        # System is currently in Audit Mode
        return $true
    }
    
    # Fallback check: ImageState
    $imageState = Get-ItemPropertyValue -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" -Name "ImageState" -ErrorAction SilentlyContinue
    if ($imageState -match "IMAGE_STATE_AUDIT|IMAGE_STATE_UNDEPLOYABLE|IMAGE_STATE_GENERALIZE_RESEAL_TO_AUDIT|IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT") {
        return $true
    }

    return $false
}

function Mount-WinDebloatDefaultHive {
    <#
    .SYNOPSIS
        Mounts the Default User registry hive (NTUSER.DAT).
    
    .DESCRIPTION
        Mounts existing default user hive to HKLM\WinDebloat_Default.
        This allows modifying settings for all future users.
        
    .OUTPUTS
        Boolean (True if mounted successfully or already mounted)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $mountPoint = "HKLM\WinDebloat_Default"
    $defaultUserDat = "$env:SystemDrive\Users\Default\NTUSER.DAT"

    if (-not (Test-Path $defaultUserDat)) {
        Write-Log -Message "Default User NTUSER.DAT not found at $defaultUserDat" -Level Error
        return $false
    }

    if ((Test-Path "Registry::$mountPoint") -or (Test-Path "HKLM:\WinDebloat_Default")) {
        Write-Log -Message "Default User hive already mounted." -Level Debug
        return $true
    }

    try {
        Write-Log -Message "Mounting Default User hive to $mountPoint" -Level Info
        $process = Start-Process -FilePath "reg.exe" -ArgumentList "load ""$mountPoint"" ""$defaultUserDat""" -PassThru -NoNewWindow -Wait
        
        if ($process.ExitCode -eq 0) {
            return $true
        }
        else {
            Write-Log -Message "Failed to mount Default User hive. Exit Code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log -Message "Error mounting Default hive: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Dismount-WinDebloatDefaultHive {
    <#
    .SYNOPSIS
        Dismounts the Default User registry hive.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $mountPoints = @("HKLM\WinDebloat_Default", "HKLM\WinDebloat7_Default")

    foreach ($mountPoint in $mountPoints) {
        if (-not (Test-Path "Registry::$mountPoint")) {
            continue
        }

        try {
            Write-Log -Message "Dismounting Default User hive ($mountPoint)..." -Level Info
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            
            $process = Start-Process -FilePath "reg.exe" -ArgumentList "unload ""$mountPoint""" -PassThru -NoNewWindow -Wait
            
            if ($process.ExitCode -ne 0) {
                Write-Log -Message "Failed to unload Default User hive ($mountPoint). Cleanup required." -Level Warning
            }
        }
        catch {
            Write-Log -Message "Error dismounting hive ($mountPoint): $($_.Exception.Message)" -Level Error
        }
    }
}

Set-Alias -Name 'Test-WinDebloat7Sysprep' -Value 'Test-WinDebloatSysprep'
Set-Alias -Name 'Mount-WinDebloat7DefaultHive' -Value 'Mount-WinDebloatDefaultHive'
Set-Alias -Name 'Dismount-WinDebloat7DefaultHive' -Value 'Dismount-WinDebloatDefaultHive'

Export-ModuleMember -Function @('Test-WinDebloatSysprep', 'Mount-WinDebloatDefaultHive', 'Dismount-WinDebloatDefaultHive') -Alias @('Test-WinDebloat7Sysprep', 'Mount-WinDebloat7DefaultHive', 'Dismount-WinDebloat7DefaultHive')
