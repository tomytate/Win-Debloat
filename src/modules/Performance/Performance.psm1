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
                # Check for laptop / battery presence (AtlasOS / CTT best practice)
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
    
    # 6. Network Throttling
    $currentStep++
    Write-Progress -Activity "Applying Performance Settings" -Status "Disabling Network Throttling" -PercentComplete (($currentStep / $totalSteps) * 100)
    Write-Log -Message "Disabling Network Throttling" -Level Info
    if (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord) {
        $successCount++
    }
    else {
        $failCount++
    }
    
    Write-Progress -Activity "Applying Performance Settings" -Completed
    
    # Summary
    Write-Log -Message "Performance settings applied: $successCount succeeded, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
}

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloatPerformance' -Value 'Optimize-WinDebloatPerformance'
Set-Alias -Name 'Set-WinDebloat7Performance' -Value 'Optimize-WinDebloatPerformance'
Set-Alias -Name 'Optimize-WinDebloat7Performance' -Value 'Optimize-WinDebloatPerformance'

Export-ModuleMember -Function @(
    'Optimize-WinDebloatPerformance'
) -Alias @(
    'Set-WinDebloatPerformance',
    'Set-WinDebloat7Performance',
    'Optimize-WinDebloat7Performance'
)
