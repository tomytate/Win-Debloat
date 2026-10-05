#Requires -Version 7.6

<#
.SYNOPSIS
    Performance optimization module for Win-Debloat
    
.DESCRIPTION
    Manages power plans, visual effects, and system responsiveness settings.
    Uses PowerShell best practices with named constants and proper error handling.
    
.NOTES
    Module: Win-Debloat.Modules.Performance
    Version: 1.7.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force
if (-not (Get-Command Enable-WinDebloatDirectSR -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\Gaming.psm1" -Global
}

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
    # Dynamically calculate total steps based on active profile configuration
    $totalSteps = [math]::Max(1, @(
        $true                                                  # 1. Power Plan (unconditional)
        ($Config.performance.visual_effects -eq "Performance") # 2. Visual Effects & Responsiveness
        $true                                                  # 3. RAM Optimization (unconditional)
        [bool]$Config.performance.disable_game_bar             # 4. Game Mode & DVR
        [bool]$Config.performance.disable_background_apps      # 5. Background Apps
        [bool]$Config.performance.enable_directstorage_tuning  # 6. DirectStorage & Storage Subsystem
        [bool]$Config.performance.enable_thread_director       # 7. Intel Thread Director / EPP
        [bool]$Config.performance.enable_amd_x3d_safeguards    # 8. AMD 3D V-Cache Safeguards
        [bool]$Config.performance.enable_directsr              # 9. DirectSR & Windowed VRR
        [bool]$Config.performance.enable_hags_tdr_tuning       # 10. HAGS 2.0 & GPU Driver TDR
        [bool]$Config.performance.disable_energy_saver_ac_throttling # 11. Energy Saver AC Throttling
    ).Where({ $_ }).Count)
    $currentStep = 0
    
    # 1. Power Plans (using named constants)
    $currentStep++
    Write-Progress -Activity "Applying Performance Settings" -Status "Configuring Power Plan: $plan" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
    try {
        if ($plan -in "HighPerformance", "Ultimate") {
            if (Test-WinDebloatDualCcdX3D) {
                Write-Log -Message "AMD Dual-CCD 3D V-Cache CPU detected. Ultimate/High schemes disable core parking and cause high inter-CCD gaming latency. Applying Balanced plan with core parking enabled." -Level Warning
                $plan = "Balanced"
            }
        }

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
        Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing Visual Effects & Responsiveness" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
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
    Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing Service Host Split" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
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
        Write-Progress -Activity "Applying Performance Settings" -Status "Disabling Game Bar" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
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
        Write-Progress -Activity "Applying Performance Settings" -Status "Disabling Background Apps" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Write-Log -Message "Disabling Background Apps" -Level Info
        
        $results = @(
            (Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2)
        )
        
        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
    }
    
    # 6. DirectStorage & Storage Subsystem
    if ($Config.performance.enable_directstorage_tuning) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing DirectStorage & NTFS" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Optimize-WinDebloatDirectStorage
        $successCount++
    }

    # 7. Intel Thread Director / EPP Tuning
    if ($Config.performance.enable_thread_director) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Optimizing CPU Thread Scheduling" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Optimize-WinDebloatThreadDirector
        $successCount++
    }

    # 8. AMD 3D V-Cache Dual-CCD Core Parking Safeguards
    if ($Config.performance.enable_amd_x3d_safeguards) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Enforcing AMD 3D V-Cache Safeguards" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Protect-WinDebloatAMDX3D
        $successCount++
    }

    # 9. DirectSR & Windowed VRR Optimization
    if ($Config.performance.enable_directsr) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Enabling DirectSR & Windowed VRR" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Enable-WinDebloatDirectSR
        $successCount++
    }

    # 10. HAGS 2.0 & GPU Driver TDR Stability
    if ($Config.performance.enable_hags_tdr_tuning) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Configuring HAGS & TDR Stability" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Set-WinDebloatHAGSTDR
        $successCount++
    }

    # 11. Energy Saver AC Throttling (Windows 11 24H2+)
    if ($Config.performance.disable_energy_saver_ac_throttling) {
        $currentStep++
        Write-Progress -Activity "Applying Performance Settings" -Status "Disabling Energy Saver AC Throttling" -PercentComplete ([math]::Clamp([int][math]::Round(($currentStep / [math]::Max(1, $totalSteps)) * 100), 0, 100))
        Disable-WinDebloatEnergySaverAcThrottling
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
            # Prefer performant cores (P-cores) for thread scheduling (SCHEDPOLICY 2 = Prefer performant processors)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SCHEDPOLICY 2 2>$null
            # Prefer performant cores for short burst threads (SHORTSCHEDPOLICY 2 = Prefer performant processors)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SHORTSCHEDPOLICY 2 2>$null
            # Heterogeneous thread scheduling policy (1 = All processors, prioritize performance)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROPOLICY 1 2>$null
            # Autonomous mode performance bias (EPP 0% = Max Performance across P/E/LP-E cores)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 0 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP1 0 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6865 0 2>$null
            # Heterogeneous containment policy (0 = Unconstrained, avoid thread trapping on LP E-cores)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 60fbe21b-efd9-49f2-b066-8674d8e9f423 0 2>$null
            # Apply changes
            & powercfg /setactive SCHEME_CURRENT 2>$null
            Write-Log -Message "CPU scheduling (P-core preference, EPP 0, unconstrained containment) applied." -Level Success
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
            # Reset SCHEDPOLICY to 5 (Automatic / Windows Default)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SCHEDPOLICY 5 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SHORTSCHEDPOLICY 5 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROPOLICY 0 2>$null
            # Reset EPP to 50% (Balanced default)
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 50 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP1 50 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6865 50 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 60fbe21b-efd9-49f2-b066-8674d8e9f423 0 2>$null
            # Apply changes
            & powercfg /setactive SCHEME_CURRENT 2>$null
            Write-Log -Message "CPU scheduling and EPP restored to default." -Level Success
        }
        catch {
            Write-Log -Message "Could not restore powercfg scheduling: $($_.Exception.Message)" -Level Warning
        }
    }
}

<#
.SYNOPSIS
    Disables Windows 11 24H2+ Energy Saver AC Throttling to prevent performance caps when plugged in.
#>
function Disable-WinDebloatEnergySaverAcThrottling {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling Energy Saver AC Throttling..." -Level Info

    if ($PSCmdlet.ShouldProcess("Energy Saver Subsystem", "Disable AC power throttling")) {
        $pwrPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
        Set-RegistryKey -Path $pwrPath -Name "EcoModeState" -Value 2 -Type DWord | Out-Null
        Set-RegistryKey -Path $pwrPath -Name "EnergySaverState" -Value 2 -Type DWord | Out-Null
        Set-RegistryKey -Path "$pwrPath\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord | Out-Null
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord | Out-Null
        Write-Log -Message "Energy Saver AC Throttling disabled." -Level Success
    }
}

<#
.SYNOPSIS
    Restores default Windows Energy Saver AC Throttling behavior.
#>
function Enable-WinDebloatEnergySaverAcThrottling {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Energy Saver Subsystem", "Restore default AC power throttling")) {
        $pwrPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
        Set-RegistryKey -Path $pwrPath -Name "EcoModeState" -Value 0 -Type DWord | Out-Null
        Set-RegistryKey -Path $pwrPath -Name "EnergySaverState" -Value 0 -Type DWord | Out-Null
        Remove-RegistryKey -Path "$pwrPath\PowerThrottling" -Name "PowerThrottlingOff" | Out-Null
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerThrottling" -Name "PowerThrottlingOff" | Out-Null
        Write-Log -Message "Energy Saver AC Throttling restored to default." -Level Success
    }
}

<#
.SYNOPSIS
    Optimizes ReFS Dev Drive performance and memory utilization.
#>
function Optimize-WinDebloatDevDrive {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Optimizing ReFS Dev Drive performance..." -Level Info

    if ($PSCmdlet.ShouldProcess("Dev Drive ReFS", "Disable last access update overhead for Dev Drives")) {
        $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        Set-RegistryKey -Path $fsPath -Name "RefsDisableLastAccessUpdate" -Value 1 -Type DWord | Out-Null
        Set-RegistryKey -Path $fsPath -Name "RefsEnableLargeWorkingSetTrim" -Value 1 -Type DWord | Out-Null
        Write-Log -Message "Dev Drive ReFS performance tuning applied." -Level Success
    }
}

<#
.SYNOPSIS
    Restores ReFS Dev Drive settings to Windows defaults.
#>
function Reset-WinDebloatDevDrive {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Dev Drive ReFS", "Restore default ReFS settings")) {
        $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        Remove-RegistryKey -Path $fsPath -Name "RefsDisableLastAccessUpdate" | Out-Null
        Remove-RegistryKey -Path $fsPath -Name "RefsEnableLargeWorkingSetTrim" | Out-Null
        Write-Log -Message "Dev Drive ReFS settings restored to defaults." -Level Success
    }
}

<#
.SYNOPSIS
    Enables Windows Server native high-performance NVMe storage driver.
#>
function Enable-WinDebloatServerNativeNVMe {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Enabling Windows Server Native NVMe storage driver..." -Level Info

    if ($PSCmdlet.ShouldProcess("Storage Subsystem", "Enable native NVMe driver stack")) {
        $stornvmeKey = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
        Set-RegistryKey -Path $stornvmeKey -Name "NativeNVMeStorageDriver" -Value 1 -Type DWord | Out-Null
        Write-Log -Message "Windows Server Native NVMe driver stack enabled." -Level Success
    }
}

<#
.SYNOPSIS
    Restores standard Windows NVMe storage driver.
#>
function Disable-WinDebloatServerNativeNVMe {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Storage Subsystem", "Restore default NVMe driver stack")) {
        $stornvmeKey = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
        Remove-RegistryKey -Path $stornvmeKey -Name "NativeNVMeStorageDriver" | Out-Null
        Write-Log -Message "Windows standard NVMe driver stack restored." -Level Success
    }
}

<#
.SYNOPSIS
    Enables low-latency global timer resolution and distributed DPC timer handling.
#>
function Enable-WinDebloatLowLatencyTimers {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Configuring low-latency timer resolution and distributed DPC dispatching..." -Level Info

    if ($PSCmdlet.ShouldProcess("Kernel Timers", "Enable global timer resolution requests and distribute timers")) {
        $kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        Set-RegistryKey -Path $kernelPath -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord | Out-Null
        Set-RegistryKey -Path $kernelPath -Name "DistributeTimers" -Value 1 -Type DWord | Out-Null
        Write-Log -Message "Low-latency kernel timer policies configured." -Level Success
    }
}

<#
.SYNOPSIS
    Restores kernel timer resolution and timer dispatching to Windows defaults.
#>
function Reset-WinDebloatLowLatencyTimers {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Kernel Timers", "Restore default kernel timer settings")) {
        $kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        Remove-RegistryKey -Path $kernelPath -Name "GlobalTimerResolutionRequests" | Out-Null
        Remove-RegistryKey -Path $kernelPath -Name "DistributeTimers" | Out-Null
        Write-Log -Message "Kernel timer settings restored to default." -Level Success
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
Set-Alias -Name 'Disable-WinDebloat7EnergySaverAcThrottling' -Value 'Disable-WinDebloatEnergySaverAcThrottling'
Set-Alias -Name 'Enable-WinDebloat7EnergySaverAcThrottling' -Value 'Enable-WinDebloatEnergySaverAcThrottling'
Set-Alias -Name 'Optimize-WinDebloat7DevDrive' -Value 'Optimize-WinDebloatDevDrive'
Set-Alias -Name 'Reset-WinDebloat7DevDrive' -Value 'Reset-WinDebloatDevDrive'
Set-Alias -Name 'Enable-WinDebloat7ServerNativeNVMe' -Value 'Enable-WinDebloatServerNativeNVMe'
Set-Alias -Name 'Disable-WinDebloat7ServerNativeNVMe' -Value 'Disable-WinDebloatServerNativeNVMe'
Set-Alias -Name 'Enable-WinDebloat7LowLatencyTimers' -Value 'Enable-WinDebloatLowLatencyTimers'
Set-Alias -Name 'Reset-WinDebloat7LowLatencyTimers' -Value 'Reset-WinDebloatLowLatencyTimers'

Export-ModuleMember -Function @(
    'Optimize-WinDebloatPerformance',
    'Optimize-WinDebloatDirectStorage',
    'Reset-WinDebloatDirectStorage',
    'Optimize-WinDebloatThreadDirector',
    'Reset-WinDebloatThreadDirector',
    'Disable-WinDebloatEnergySaverAcThrottling',
    'Enable-WinDebloatEnergySaverAcThrottling',
    'Optimize-WinDebloatDevDrive',
    'Reset-WinDebloatDevDrive',
    'Enable-WinDebloatServerNativeNVMe',
    'Disable-WinDebloatServerNativeNVMe',
    'Enable-WinDebloatLowLatencyTimers',
    'Reset-WinDebloatLowLatencyTimers'
) -Alias @(
    'Set-WinDebloatPerformance',
    'Set-WinDebloat7Performance',
    'Optimize-WinDebloat7Performance',
    'Optimize-WinDebloat7DirectStorage',
    'Reset-WinDebloat7DirectStorage',
    'Optimize-WinDebloat7ThreadDirector',
    'Reset-WinDebloat7ThreadDirector',
    'Disable-WinDebloat7EnergySaverAcThrottling',
    'Enable-WinDebloat7EnergySaverAcThrottling',
    'Optimize-WinDebloat7DevDrive',
    'Reset-WinDebloat7DevDrive',
    'Enable-WinDebloat7ServerNativeNVMe',
    'Disable-WinDebloat7ServerNativeNVMe',
    'Enable-WinDebloat7LowLatencyTimers',
    'Reset-WinDebloat7LowLatencyTimers'
)
