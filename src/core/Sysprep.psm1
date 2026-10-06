#Requires -Version 7.6

<#
.SYNOPSIS
    Handles Sysprep Audit Mode detection and Default User registry operations.
    
.DESCRIPTION
    Provides functions to detect if Windows is in Audit Mode and to mount/dismount
    the Default User registry hive for applying settings to future users (OEM scenarios).
    Guarantees NTUSER.DAT is never left locked via explicit .Dispose(), dual GC passes,
    and exponential retry backoff on hive unloads.
    
.NOTES
    Module: Win-Debloat.Core.Sysprep
    Version: 1.7.1
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
        
    .DESCRIPTION
        Safely dismounts the Default User hive (NTUSER.DAT) across all mount aliases.
        Performs explicit disposal on open subkeys, dual garbage collection cycles,
        and 3x exponential retry backoff to ensure no process locks remain on NTUSER.DAT.
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

            # Explicitly close and dispose any lingering .NET subkey handles before unloading
            $subKeyName = $mountPoint -replace '^HKLM\\', ''
            try {
                $hKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subKeyName, $false)
                if ($null -ne $hKey) {
                    $hKey.Dispose()
                    $hKey = $null
                }
            }
            catch {
                # Non-fatal if opening key fails
                $null = $_
            }

            # 3x exponential retry backoff on reg.exe unload with dual GC collections
            $maxRetries = 3
            $unloaded = $false
            $lastExitCode = -1

            for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
                # Dual GC collect to release any unmanaged registry handles and finalizer queues
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()

                $process = Start-Process -FilePath "reg.exe" -ArgumentList "unload ""$mountPoint""" -PassThru -NoNewWindow -Wait
                $lastExitCode = if ($process) { $process.ExitCode } else { -1 }

                if ($lastExitCode -eq 0) {
                    $unloaded = $true
                    break
                }

                if ($attempt -lt $maxRetries) {
                    $backoffMs = [int]([Math]::Pow(2, $attempt - 1) * 500)
                    Write-Log -Message "Failed to unload Default User hive ($mountPoint) on attempt $attempt (Exit Code: $lastExitCode). Retrying in ${backoffMs}ms..." -Level Warning
                    Start-Sleep -Milliseconds $backoffMs
                }
            }

            if (-not $unloaded) {
                Write-Log -Message "Failed to unload Default User hive ($mountPoint). Cleanup required." -Level Warning
            }
        }
        catch {
            Write-Log -Message "Error dismounting hive ($mountPoint): $($_.Exception.Message)" -Level Error
        }
    }
}

function Get-WinDebloatUserProfiles {
    <#
    .SYNOPSIS
        Discovers all user profiles registered on the system.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $profileListKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    if (-not (Test-Path $profileListKey)) { return @() }

    $profiles = [System.Collections.Generic.List[PSCustomObject]]::new()
    $subKeys = Get-ChildItem -Path $profileListKey -ErrorAction SilentlyContinue

    foreach ($key in $subKeys) {
        $sid = $key.PSChildName
        $path = Get-ItemPropertyValue -Path $key.PSPath -Name "ProfileImagePath" -ErrorAction SilentlyContinue
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }

        $ntuser = Join-Path $path "NTUSER.DAT"
        $userName = Split-Path $path -Leaf
        $isLoaded = Test-Path "Registry::HKEY_USERS\$sid"

        $profiles.Add([PSCustomObject]@{
            SID            = $sid
            UserName       = $userName
            ProfilePath    = $path
            NTUserDatPath  = $ntuser
            IsLoaded       = $isLoaded
            IsDefault      = ($userName -eq 'Default')
        })
    }

    return $profiles.ToArray()
}

function Mount-WinDebloatUserHive {
    <#
    .SYNOPSIS
        Mounts an offline user NTUSER.DAT into HKLM.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter(Mandatory)]
        [string]$MountName
    )

    $ntuser = Join-Path $ProfilePath "NTUSER.DAT"
    if (-not (Test-Path $ntuser)) {
        Write-Log -Message "NTUSER.DAT not found at $ntuser" -Level Error
        return $false
    }

    $mountPoint = "HKLM\$MountName"
    if (Test-Path "Registry::$mountPoint") {
        Write-Log -Message "Hive $mountPoint already mounted." -Level Debug
        return $true
    }

    try {
        Write-Log -Message "Mounting user hive to $mountPoint..." -Level Info
        $proc = Start-Process -FilePath "reg.exe" -ArgumentList "load `"$mountPoint`" `"$ntuser`"" -PassThru -NoNewWindow -Wait
        return ($proc.ExitCode -eq 0)
    }
    catch {
        Write-Log -Message "Error mounting user hive: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Dismount-WinDebloatUserHive {
    <#
    .SYNOPSIS
        Dismounts an offline user hive with garbage collection and exponential retry backoff.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$MountName
    )

    $mountPoint = "HKLM\$MountName"
    if (-not (Test-Path "Registry::$mountPoint")) { return }

    try {
        Write-Log -Message "Dismounting user hive ($mountPoint)..." -Level Info
        $subKeyName = $MountName
        try {
            $hKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subKeyName, $false)
            if ($null -ne $hKey) {
                $hKey.Dispose()
                $hKey = $null
            }
        }
        catch {
            $null = $_
        }

        $maxRetries = 3
        for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            $process = Start-Process -FilePath "reg.exe" -ArgumentList "unload `"$mountPoint`"" -PassThru -NoNewWindow -Wait
            if ($process.ExitCode -eq 0) { break }

            if ($attempt -lt $maxRetries) {
                $backoffMs = [int]([Math]::Pow(2, $attempt - 1) * 500)
                Start-Sleep -Milliseconds $backoffMs
            }
        }
    }
    catch {
        Write-Log -Message "Error dismounting user hive ($mountPoint): $($_.Exception.Message)" -Level Error
    }
}

function Invoke-WinDebloatWithTargetUserHive {
    <#
    .SYNOPSIS
        Executes a scriptblock within the context of a target user's hive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetUser,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    if ($TargetUser -eq 'Default') {
        $mounted = Mount-WinDebloatDefaultHive
        try {
            & $ScriptBlock "HKLM\WinDebloat_Default"
        }
        finally {
            if ($mounted) { Dismount-WinDebloatDefaultHive }
        }
        return
    }

    $allProfiles = Get-WinDebloatUserProfiles
    $targetProfile = $allProfiles | Where-Object { $_.UserName -eq $TargetUser -or $_.SID -eq $TargetUser } | Select-Object -First 1

    if (-not $targetProfile) {
        throw "Target user profile '$TargetUser' could not be resolved."
    }

    if ($targetProfile.IsLoaded) {
        & $ScriptBlock "HKU:\$($targetProfile.SID)"
    }
    else {
        $mountName = "WinDebloat_User_$($targetProfile.UserName)"
        $mounted = Mount-WinDebloatUserHive -ProfilePath $targetProfile.ProfilePath -MountName $mountName
        try {
            & $ScriptBlock "HKLM\$mountName"
        }
        finally {
            if ($mounted) { Dismount-WinDebloatUserHive -MountName $mountName }
        }
    }
}

Set-Alias -Name 'Test-WinDebloat7Sysprep' -Value 'Test-WinDebloatSysprep'
Set-Alias -Name 'Mount-WinDebloat7DefaultHive' -Value 'Mount-WinDebloatDefaultHive'
Set-Alias -Name 'Dismount-WinDebloat7DefaultHive' -Value 'Dismount-WinDebloatDefaultHive'
Set-Alias -Name 'Get-WinDebloat7UserProfiles' -Value 'Get-WinDebloatUserProfiles'
Set-Alias -Name 'Mount-WinDebloat7UserHive' -Value 'Mount-WinDebloatUserHive'
Set-Alias -Name 'Dismount-WinDebloat7UserHive' -Value 'Dismount-WinDebloatUserHive'
Set-Alias -Name 'Invoke-WinDebloat7WithTargetUserHive' -Value 'Invoke-WinDebloatWithTargetUserHive'

Export-ModuleMember -Function @(
    'Test-WinDebloatSysprep',
    'Mount-WinDebloatDefaultHive',
    'Dismount-WinDebloatDefaultHive',
    'Get-WinDebloatUserProfiles',
    'Mount-WinDebloatUserHive',
    'Dismount-WinDebloatUserHive',
    'Invoke-WinDebloatWithTargetUserHive'
) -Alias @(
    'Test-WinDebloat7Sysprep',
    'Mount-WinDebloat7DefaultHive',
    'Dismount-WinDebloat7DefaultHive',
    'Get-WinDebloat7UserProfiles',
    'Mount-WinDebloat7UserHive',
    'Dismount-WinDebloat7UserHive',
    'Invoke-WinDebloat7WithTargetUserHive'
)
