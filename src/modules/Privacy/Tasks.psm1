#Requires -Version 7.6

<#
.SYNOPSIS
    Scheduled task cleanup module for Win-Debloat
    
.DESCRIPTION
    Identifies and disables telemetry-related scheduled tasks that can
    respawn tracking services even after they're disabled.
    
.NOTES
    Module: Win-Debloat.Modules.Privacy.Tasks
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

#region Telemetry Task Definitions

# Tasks to disable - organized by category
$Script:TelemetryTasks = @{
    # Safe to disable - no impact on core Windows functionality
    Safe       = @(
        # Application Experience
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "Microsoft Compatibility Appraiser" }
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "ProgramDataUpdater" }
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "StartupAppTask" }
        
        # Customer Experience Improvement Program
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program"; Name = "Consolidator" }
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program"; Name = "UsbCeip" }
        
        # Feedback
        @{ Path = "\Microsoft\Windows\Feedback\Siuf"; Name = "DmClient" }
        @{ Path = "\Microsoft\Windows\Feedback\Siuf"; Name = "DmClientOnScenarioDownload" }
        
        # Windows Error Reporting
        @{ Path = "\Microsoft\Windows\Windows Error Reporting"; Name = "QueueReporting" }
        
        # Disk Diagnostics
        @{ Path = "\Microsoft\Windows\DiskDiagnostic"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" }
        
        # Maps (if not using Windows Maps)
        @{ Path = "\Microsoft\Windows\Maps"; Name = "MapsToastTask" }
        @{ Path = "\Microsoft\Windows\Maps"; Name = "MapsUpdateTask" }
        
        # Cloud Experience
        @{ Path = "\Microsoft\Windows\CloudExperienceHost"; Name = "CreateObjectTask" }
        
        # User Choice Protection Driver (UCPD) Velocity
        @{ Path = "\Microsoft\Windows\AppxDeploymentClient"; Name = "UcpdVelocity" }
        
        # Application Experience Extensions
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "MareBackup" }
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "PautoRequest" }
        
        # Windows 11 24H2/25H2/26H1 AI / Copilot+ / Flighting Tasks
        @{ Path = "\Microsoft\Windows\WindowsAI"; Name = "ClickToDo" }
        @{ Path = "\Microsoft\Windows\WindowsAI"; Name = "RecallSnapshot" }
        @{ Path = "\Microsoft\Windows\WindowsAI"; Name = "ModelMaintenance" }
        @{ Path = "\Microsoft\Windows\WindowsAI"; Name = "ModelDownloadTask" }
        @{ Path = "\Microsoft\Windows\WindowsAI"; Name = "AIPlatformServiceTask" }
        @{ Path = "\Microsoft\Windows\WindowsAI"; Name = "WorkloadsHostTask" }
        @{ Path = "\Microsoft\Windows\AISystem"; Name = "AIAnalyzer" }
        @{ Path = "\Microsoft\Windows\AISystem"; Name = "ModelUpdateTask" }
        @{ Path = "\Microsoft\Windows\AISystem"; Name = "SemanticIndexTask" }
        @{ Path = "\Microsoft\Windows\NarrativeFlows"; Name = "UserJourneyTracker" }
        @{ Path = "\Microsoft\Windows\Flighting\OneSettings"; Name = "RefreshCache" }
        @{ Path = "\Microsoft\Windows\Flighting\OneSettings"; Name = "QuerySettings" }
        @{ Path = "\Microsoft\Windows\Flighting\FeatureConfig"; Name = "UsageDataReporting" }
        @{ Path = "\Microsoft\Windows\Flighting\FeatureConfig"; Name = "ReconcileFeatures" }
        @{ Path = "\Microsoft\Windows\UNP"; Name = "RunCampaignManager" }
        @{ Path = "\Microsoft\Windows\Setup"; Name = "EOSNotify" }
        @{ Path = "\Microsoft\Windows\Setup"; Name = "EOSNotify2" }
    )
    
    # Aggressive - may impact some features
    Aggressive = @(
        # Autochk (proxy data collection)
        @{ Path = "\Microsoft\Windows\Autochk"; Name = "Proxy" }
        
        # Device Information
        @{ Path = "\Microsoft\Windows\Device Information"; Name = "Device" }
        @{ Path = "\Microsoft\Windows\Device Information"; Name = "Device User" }
        
        # License Validation (may impact Store apps - use with caution)
        @{ Path = "\Microsoft\Windows\License Manager"; Name = "TempSignedLicenseExchange" }
        
        # Maintenance (may impact Windows maintenance)
        @{ Path = "\Microsoft\Windows\Diagnosis"; Name = "Scheduled" }
        @{ Path = "\Microsoft\Windows\Maintenance"; Name = "WinSAT" }
        
        # PI (Privacy Intelligence)
        @{ Path = "\Microsoft\Windows\PI"; Name = "Sqm-Tasks" }
        
        # NetTrace 
        @{ Path = "\Microsoft\Windows\NetTrace"; Name = "GatherNetworkInfo" }
        
        # Power Efficiency Diagnostics
        @{ Path = "\Microsoft\Windows\Power Efficiency Diagnostics"; Name = "AnalyzeSystem" }
        
        # SettingSync & Speech
        @{ Path = "\Microsoft\Windows\SettingSync"; Name = "BackgroundUploadTask" }
        @{ Path = "\Microsoft\Windows\Speech"; Name = "SpeechModelDownloadTask" }
        
        # Shell (some edge cases)
        @{ Path = "\Microsoft\Windows\Shell"; Name = "FamilySafetyMonitor" }
        @{ Path = "\Microsoft\Windows\Shell"; Name = "FamilySafetyRefreshTask" }
        
        # Xbox (if not gaming)
        @{ Path = "\Microsoft\XblGameSave"; Name = "XblGameSaveTask" }
    )
}

#endregion

#region Task Functions

<#
.SYNOPSIS
    Gets telemetry-related scheduled tasks.
    
.PARAMETER Mode
    Which set of tasks to return: Safe, Aggressive, or All.
    
.OUTPUTS
    [psobject[]] Array of task objects with current state.
#>
function Get-WinDebloatTelemetryTasks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
        [ValidateSet("Safe", "Aggressive", "All")]
        [string]$Mode = "All"
    )
    
    Write-Log -Message "Scanning telemetry scheduled tasks..." -Level Info
    
    $taskDefs = switch ($Mode) {
        "Safe" { $Script:TelemetryTasks.Safe }
        "Aggressive" { $Script:TelemetryTasks.Aggressive }
        "All" { $Script:TelemetryTasks.Safe + $Script:TelemetryTasks.Aggressive }
    }
    
    $results = @()
    
    foreach ($taskDef in $taskDefs) {
        try {
            $fullPath = "$($taskDef.Path)\$($taskDef.Name)"
            $task = Get-ScheduledTask -TaskPath "$($taskDef.Path)\" -TaskName $taskDef.Name -ErrorAction SilentlyContinue
            
            if ($task) {
                $results += [pscustomobject]@{
                    TaskName = $taskDef.Name
                    TaskPath = $taskDef.Path
                    FullPath = $fullPath
                    State    = $task.State
                    Enabled  = ($task.State -ne "Disabled")
                    Category = if ($taskDef -in $Script:TelemetryTasks.Safe) { "Safe" } else { "Aggressive" }
                }
            }
        }
        catch {
            # Task doesn't exist - skip
            Write-Verbose "Task not found during scan: $($taskDef.Name)"
        }
    }
    
    $enabledCount = ($results | Where-Object { $_.Enabled }).Count
    Write-Log -Message "Found $($results.Count) telemetry tasks ($enabledCount currently enabled)" -Level Info
    
    return $results
}

<#
.SYNOPSIS
    Disables telemetry scheduled tasks.
    
.PARAMETER Mode
    Which set of tasks to disable: Safe (recommended), Aggressive, or All.
    
.EXAMPLE
    Disable-WinDebloatTelemetryTasks -Mode Safe
#>
function Disable-WinDebloatTelemetryTasks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [ValidateSet("Safe", "Aggressive", "All")]
        [string]$Mode = "Safe"
    )
    
    Write-Log -Message "Disabling telemetry tasks (Mode: $Mode)..." -Level Info
    
    $tasks = Get-WinDebloatTelemetryTasks -Mode $Mode | Where-Object { $_.Enabled }
    
    if ($tasks.Count -eq 0) {
        Write-Log -Message "No enabled telemetry tasks to disable." -Level Info
        return
    }
    
    $successCount = 0
    $failCount = 0
    $total = $tasks.Count
    $current = 0
    
    foreach ($task in $tasks) {
        $current++
        $percent = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Disabling Telemetry Tasks" -Status "[$current/$total] $($task.TaskName)" -PercentComplete $percent
        
        if ($PSCmdlet.ShouldProcess($task.FullPath, "Disable Scheduled Task")) {
            try {
                Disable-ScheduledTask -TaskPath "$($task.TaskPath)\" -TaskName $task.TaskName -ErrorAction Stop | Out-Null
                Write-Log -Message "Disabled: $($task.TaskName)" -Level Success
                $successCount++
            }
            catch {
                Write-Log -Message "Failed to disable $($task.TaskName): $($_.Exception.Message)" -Level Warning
                $failCount++
            }
        }
    }
    
    Write-Progress -Activity "Disabling Telemetry Tasks" -Completed
    Write-Log -Message "Task cleanup complete: $successCount disabled, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
}

<#
.SYNOPSIS
    Re-enables previously disabled telemetry tasks.
    
.PARAMETER Mode
    Which set of tasks to enable: Safe, Aggressive, or All.
#>
function Enable-WinDebloatTelemetryTasks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [ValidateSet("Safe", "Aggressive", "All")]
        [string]$Mode = "All"
    )
    
    Write-Log -Message "Re-enabling telemetry tasks (Mode: $Mode)..." -Level Info
    
    $tasks = Get-WinDebloatTelemetryTasks -Mode $Mode | Where-Object { -not $_.Enabled }
    
    if ($tasks.Count -eq 0) {
        Write-Log -Message "No disabled telemetry tasks to enable." -Level Info
        return
    }
    
    $successCount = 0
    $failCount = 0
    $total = $tasks.Count
    $current = 0
    
    foreach ($task in $tasks) {
        $current++
        $percent = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Enabling Telemetry Tasks" -Status "[$current/$total] $($task.TaskName)" -PercentComplete $percent
        
        if ($PSCmdlet.ShouldProcess($task.FullPath, "Enable Scheduled Task")) {
            try {
                Enable-ScheduledTask -TaskPath "$($task.TaskPath)\" -TaskName $task.TaskName -ErrorAction Stop | Out-Null
                Write-Log -Message "Enabled: $($task.TaskName)" -Level Success
                $successCount++
            }
            catch {
                Write-Log -Message "Failed to enable $($task.TaskName): $($_.Exception.Message)" -Level Warning
                $failCount++
            }
        }
    }
    
    Write-Progress -Activity "Enabling Telemetry Tasks" -Completed
    Write-Log -Message "Task restore complete: $successCount enabled, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Get-WinDebloat7TelemetryTasks' -Value 'Get-WinDebloatTelemetryTasks'
Set-Alias -Name 'Disable-WinDebloat7TelemetryTasks' -Value 'Disable-WinDebloatTelemetryTasks'
Set-Alias -Name 'Set-WinDebloatTelemetryTasks' -Value 'Disable-WinDebloatTelemetryTasks'
Set-Alias -Name 'Set-WinDebloat7TelemetryTasks' -Value 'Disable-WinDebloatTelemetryTasks'
Set-Alias -Name 'Enable-WinDebloat7TelemetryTasks' -Value 'Enable-WinDebloatTelemetryTasks'

Export-ModuleMember -Function @(
    'Get-WinDebloatTelemetryTasks',
    'Disable-WinDebloatTelemetryTasks',
    'Enable-WinDebloatTelemetryTasks'
) -Alias @(
    'Get-WinDebloat7TelemetryTasks',
    'Disable-WinDebloat7TelemetryTasks',
    'Set-WinDebloatTelemetryTasks',
    'Set-WinDebloat7TelemetryTasks',
    'Enable-WinDebloat7TelemetryTasks'
)
