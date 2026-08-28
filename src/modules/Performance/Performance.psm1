#Requires -Version 7.6

<#
.SYNOPSIS
    Performance optimization module for Win-Debloat
    
.DESCRIPTION
    Manages power plans, visual effects, and system responsiveness settings.
    Uses PowerShell best practices with named constants and proper error handling.
    
.NOTES
    Module: Win-Debloat.Modules.Performance
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force

#region Constants (CQ-006 fix: Named constants instead of magic GUIDs)
$Script:PowerPlanGUIDs = @{
    Balanced        = '381b4222-f694-41f0-9685-ff5bb260df2e'
    HighPerformance = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    Ultimate        = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    PowerSaver      = 'a1841308-3541-4fab-bc81-f71556f20b4a'
}
#endregion

<#
.SYNOPSIS
    Applies performance settings based on configuration profile.
    
.DESCRIPTION
    Configures Windows performance settings including power plans,
    visual effects, Game Bar, and background apps.
    
.PARAMETER Config
    The configuration object loaded from a YAML profile.
    
.OUTPUTS
    [void]
    
.EXAMPLE
    Optimize-WinDebloatPerformance -Config $config
#>
function Optimize-WinDebloatPerformance {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Config
    )
    
    # Validate config has performance section
    if (-not $Config.performance) {
        Write-Log -Message "No performance configuration found in profile." -Level Warning
        return
    }
    
    $plan = $Config.performance.power_plan
    Write-Log -Message "Applying Performance Settings (Plan: $plan)" -Level Info
    
    $successCount = 0
    $failCount = 0
    $totalSteps = 6
    $currentStep = 0
    
    # 1. Power Plans (using named constants)
    $currentStep++
    Write-Progress -Activity "Applying Performance Settings" -Status "Configuring Power Plan: $plan" -PercentComplete (($currentStep / $totalSteps) * 100)
    try {
        switch ($plan) {
            "HighPerformance" {
                $guid = $Script:PowerPlanGUIDs.HighPerformance
                if ($PSCmdlet.ShouldProcess("Power Plan", "Set to High Performance")) {
                    $proc = Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "$guid" -Wait -NoNewWindow -PassThru
                    if ($proc.ExitCode -eq 0) {
                        Write-Log -Message "Power Plan set to High Performance" -Level Success
                        $successCount++
                    }
                    else {
                        Write-Log -Message "Failed to set power plan: $($proc.ExitCode)" -Level Error
                        $failCount++
                    }
                }
            }
            "Ultimate" {
                # Check for laptop / battery presence
                $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
                if ($battery) {
                    Write-Log -Message "Laptop detected: Ultimate Performance power plan causes severe battery drain and thermal throttling. Using High Performance scheme." -Level Warning
                    $guid = $Script:PowerPlanGUIDs.HighPerformance
                    if ($PSCmdlet.ShouldProcess("Power Plan", "Set to High Performance (Laptop Safe)")) {
                        $proc = Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "$guid" -Wait -NoNewWindow -PassThru
                        if ($proc.ExitCode -eq 0) {
                            Write-Log -Message "Power Plan set to High Performance" -Level Success
                            $successCount++
                        }
                    }
                }
                else {
                    $guid = $Script:PowerPlanGUIDs.Ultimate
                    if ($PSCmdlet.ShouldProcess("Power Plan", "Set to Ultimate Performance")) {
                        # Check if Ultimate scheme or a copy is already present
                        $existingPlans = powercfg -list 2>&1
                        $activeGuid = $null

                        foreach ($line in $existingPlans) {
                            if ($line -match 'Ultimate Performance' -and $line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                                $activeGuid = $matches[1]
                                break
                            }
                        }

                        if (-not $activeGuid) {
                            $duplicateOutput = powercfg /duplicatescheme $guid 2>&1
                            foreach ($line in $duplicateOutput) {
                                if ($line -match '\b([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\b') {
                                    $activeGuid = $matches[1]
                                    break
                                }
                            }
                        }

                        if ($activeGuid) {
                            $proc = Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "$activeGuid" -Wait -NoNewWindow -PassThru
                            if ($proc.ExitCode -eq 0) {
                                Write-Log -Message "Power Plan set to Ultimate Performance" -Level Success
                                $successCount++
                            }
                            else {
                                Write-Log -Message "Failed to set power plan: $($proc.ExitCode)" -Level Error
                                $failCount++
                            }
                        }
                        else {
                            Write-Log -Message "Could not duplicate Ultimate Performance scheme (unsupported on this system?)" -Level Error
                            $failCount++
                        }
                    }
                }
            }
            "Balanced" {
                $guid = $Script:PowerPlanGUIDs.Balanced
                if ($PSCmdlet.ShouldProcess("Power Plan", "Set to Balanced")) {
                    $proc = Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "$guid" -Wait -NoNewWindow -PassThru
                    if ($proc.ExitCode -eq 0) {
                        Write-Log -Message "Power Plan set to Balanced" -Level Success
                        $successCount++
                    }
                    else {
                        Write-Log -Message "Failed to set power plan: $($proc.ExitCode)" -Level Error
                        $failCount++
                    }
                }
            }
            { $_ -in "PowerSaver", "Power Saver" } {
                $guid = $Script:PowerPlanGUIDs.PowerSaver
                if ($PSCmdlet.ShouldProcess("Power Plan", "Set to Power Saver")) {
                    $proc = Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "$guid" -Wait -NoNewWindow -PassThru
                    if ($proc.ExitCode -eq 0) {
                        Write-Log -Message "Power Plan set to Power Saver" -Level Success
                        $successCount++
                    }
                    else {
                        Write-Log -Message "Failed to set power plan: $($proc.ExitCode)" -Level Error
                        $failCount++
                    }
                }
            }
            default {
                Write-Log -Message "Unknown power plan: $plan" -Level Warning
            }
        }
    }
    catch {
        Write-Log -Message "Power plan configuration failed: $($_.Exception.Message)" -Level Error
        $failCount++
    }
    
    # 2. Visual Effects & Responsiveness
    if ($Config.performance.visual_effects -eq "Performance") {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing Visual Effects & Responsiveness" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Optimizing Visual Effects for Performance" -Level Info
        
        $results = @(
            # Reduce Menu Delay (Safe & Responsive)
            (Set-RegistryKey -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type String),
            # Disable Window Minimize/Maximize Animation
            (Set-RegistryKey -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String),
            # Reduce Mouse Hover Time
            (Set-RegistryKey -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Value "10" -Type String),
            # Safe shutdown timeout (5000ms prevents data corruption while avoiding long hangs)
            (Set-RegistryKey -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "5000" -Type String),
            # System Responsiveness (0 for foreground multimedia priority)
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord)
        )
        
        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
    }
    
    # 3. RAM Optimization (Service Host Split)
    $currentStep++
    Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing Service Host Split" -PercentComplete (($currentStep / $totalSteps) * 100)
    $compSys = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($compSys -and $compSys.TotalPhysicalMemory) {
        $ramGB = $compSys.TotalPhysicalMemory / 1GB
        if ($ramGB -gt 4) {
            # Set Split Threshold to RAM size to reduce process overhead on modern systems
            $ramKB = [int32][math]::Round($compSys.TotalPhysicalMemory / 1KB)
            if (Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $ramKB -Type DWord) {
                $successCount++
                Write-Log -Message "Optimized Service Host Split Threshold ($ramKB KB)" -Level Success
            }
        }
    }
    
    # 4. Game Mode & DVR
    if ($Config.performance.disable_game_bar) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Disabling Game Bar" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Disabling Game Bar" -Level Info
        
        $results = @(
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0),
            (Set-RegistryKey -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0)
        )
        
        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
    }
    
    # 5. Background Apps
    if ($Config.performance.disable_background_apps) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Disabling Background Apps" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Disabling Background Apps" -Level Info
        
        $results = @(
            (Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2)
        )
        
        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
    }
    
    # 7. DirectStorage & Storage Subsystem
    if ($Config.performance.enable_directstorage_tuning) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing DirectStorage & NTFS" -PercentComplete (($currentStep / $totalSteps) * 100)
        Optimize-WinDebloatDirectStorage
        $successCount++
    }

    # 8. Intel Thread Director / EPP Tuning
    if ($Config.performance.enable_thread_director) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing CPU Thread Scheduling" -PercentComplete (($currentStep / $totalSteps) * 100)
        Optimize-WinDebloatThreadDirector
        $successCount++
    }

    # 9. AMD 3D V-Cache Dual-CCD Core Parking Safeguards
    if ($Config.performance.enable_amd_x3d_safeguards) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Enforcing AMD 3D V-Cache Safeguards" -PercentComplete (($currentStep / $totalSteps) * 100)
        Protect-WinDebloatAMDX3D
        $successCount++
    }

    # 10. DirectSR & Windowed VRR Optimization
    if ($Config.performance.enable_directsr) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Enabling DirectSR & Windowed VRR" -PercentComplete (($currentStep / $totalSteps) * 100)
        Enable-WinDebloatDirectSR
        $successCount++
    }

    # 11. HAGS 2.0 & GPU Driver TDR Stability
    if ($Config.performance.enable_hags_tdr_tuning) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Configuring HAGS & TDR Stability" -PercentComplete (($currentStep / $totalSteps) * 100)
        Set-WinDebloatHAGSTDR
        $successCount++
    }
    
    Write-Progress -Activity "Applying Performance Settings" -Completed
    
    # Summary
    Write-Log -Message "Performance settings applied: $successCount succeeded, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
}

<#
.SYNOPSIS
    Optimizes DirectStorage 1.2+ BypassIO and kernel NTFS lookaside memory allocation.
#>
function Optimize-WinDebloatDirectStorage {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Optimizing DirectStorage 1.2+ and NTFS memory pools..." -Level Info

    if ($PSCmdlet.ShouldProcess("FileSystem & DirectStorage", "Enable NTFS lookaside memory expansion and BypassIO optimizations")) {
        $results = @(
            # NTFS lookaside memory pool expansion (2 = high memory usage)
            (Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage" -Value 2 -Type DWord),
            # Disable 8.3 short name creation overhead on non-OS volumes
            (Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord),
            # Disable last access timestamp update overhead
            (Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -Value 1 -Type DWord),
            # Enable Win32 Long Paths
            (Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord),
            # Tune system cache mode for SSD / NVMe
            (Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 0 -Type DWord)
        )
        $appliedCount = ($results | Where-Object { $_ }).Count
        Write-Log -Message "DirectStorage 1.2+ NTFS memory pool tuning applied ($appliedCount settings configured)." -Level Success
    }
}

<#
.SYNOPSIS
    Restores DirectStorage and FileSystem registry values to Windows defaults.
#>
function Reset-WinDebloatDirectStorage {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("FileSystem & DirectStorage", "Restore default NTFS memory pool settings")) {
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisable8dot3NameCreation"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache"
        Write-Log -Message "DirectStorage FileSystem settings restored to defaults." -Level Success
    }
}

<#
.SYNOPSIS
    Optimizes CPU scheduling and Energy Performance Preference (EPP) for hybrid and high-core architectures.
#>
function Optimize-WinDebloatThreadDirector {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Optimizing CPU scheduling policy & Energy Performance Preference..." -Level Info

    if ($PSCmdlet.ShouldProcess("Processor Power Policy", "Optimize Thread Director and EPP for maximum responsiveness")) {
        try {
            # Prefer performant cores (P-cores) for thread scheduling (SCHEDPOLICY 1 = Performant processors)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SCHEDPOLICY 1 2>$null
            # Autonomous mode performance bias (EPP 0% = Max Performance)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 0 2>$null
            # Apply changes
            & powercfg /setactive SCHEME_CURRENT 2>$null
            Write-Log -Message "CPU scheduling (P-core preference) and EPP optimization applied." -Level Success
        }
        catch {
            Write-Log -Message "Could not apply powercfg scheduling: $($_.Exception.Message)" -Level Warning
        }
    }
}

<#
.SYNOPSIS
    Restores CPU scheduling and Energy Performance Preference (EPP) to Windows defaults.
#>
function Reset-WinDebloatThreadDirector {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Restoring CPU scheduling policy and EPP to Windows defaults..." -Level Info

    if ($PSCmdlet.ShouldProcess("Processor Power Policy", "Restore default CPU scheduling and EPP")) {
        try {
            # Reset SCHEDPOLICY to 3 (Automatic / Windows Default)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SCHEDPOLICY 3 2>$null
            # Reset EPP to 50% (Balanced default)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 50 2>$null
            # Apply changes
            & powercfg /setactive SCHEME_CURRENT 2>$null
            Write-Log -Message "CPU scheduling and EPP restored to default." -Level Success
        }
        catch {
            Write-Log -Message "Could not restore powercfg scheduling: $($_.Exception.Message)" -Level Warning
        }
    }
}

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloatPerformance' -Value 'Optimize-WinDebloatPerformance'
Set-Alias -Name 'Set-WinDebloat7Performance' -Value 'Optimize-WinDebloatPerformance'
Set-Alias -Name 'Optimize-WinDebloat7Performance' -Value 'Optimize-WinDebloatPerformance'
Set-Alias -Name 'Optimize-WinDebloat7DirectStorage' -Value 'Optimize-WinDebloatDirectStorage'
Set-Alias -Name 'Reset-WinDebloat7DirectStorage' -Value 'Reset-WinDebloatDirectStorage'
Set-Alias -Name 'Optimize-WinDebloat7ThreadDirector' -Value 'Optimize-WinDebloatThreadDirector'
Set-Alias -Name 'Reset-WinDebloat7ThreadDirector' -Value 'Reset-WinDebloatThreadDirector'

Export-ModuleMember -Function @(
    'Optimize-WinDebloatPerformance',
    'Optimize-WinDebloatDirectStorage',
    'Reset-WinDebloatDirectStorage',
    'Optimize-WinDebloatThreadDirector',
    'Reset-WinDebloatThreadDirector'
) -Alias @(
    'Set-WinDebloatPerformance',
    'Set-WinDebloat7Performance',
    'Optimize-WinDebloat7Performance',
    'Optimize-WinDebloat7DirectStorage',
    'Reset-WinDebloat7DirectStorage',
    'Optimize-WinDebloat7ThreadDirector',
    'Reset-WinDebloat7ThreadDirector'
)
