#Requires -Version 7.6

<#
.SYNOPSIS
    Vendor and Hardware Debloat Module for Win-Debloat
    
.DESCRIPTION
    Handles GPU telemetry removal for NVIDIA, AMD, and Intel GPUs,
    and debloating of OEM software suites (ASUS, Razer, MSI, Dell, HP, Lenovo)
    while strictly preserving essential hardware thermal and fan control capabilities.

.NOTES
    Module: Win-Debloat.Modules.Vendor
    Version: 2.0.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force

#region GPU Telemetry

<#
.SYNOPSIS
    Disables GPU telemetry services and scheduled tasks for NVIDIA, AMD, and Intel GPUs.
#>
function Disable-WinDebloatGpuTelemetry {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param()

    Write-Log -Message "Scanning and disabling GPU telemetry services..." -Level Info
    $count = 0

    if ($PSCmdlet.ShouldProcess("System", "Disable GPU Telemetry (NVIDIA/AMD/Intel)")) {
        # 1. NVIDIA Telemetry Services & Tasks
        # Only target telemetry container - preserve NvContainerLocalSystem (which hosts NVIDIA Control Panel & G-Sync)
        $nvServices = @("NvTelemetryContainer")
        foreach ($svc in $nvServices) {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                try {
                    Stop-Service -Name $svc -Force -ErrorAction Stop
                    Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
                    Write-Log -Message "Disabled NVIDIA service: $($svc)" -Level Success
                    $count++
                }
                catch {
                    Write-Log -Message "Failed to disable $($svc): $($_.Exception.Message)" -Level Warning
                }
            }
        }

        # NVIDIA Scheduled Tasks (match across all task folders)
        $nvTasks = @(
            'NvTmMon_*',
            'NvTmRep_*',
            'NvTmRepOnLogon_*',
            'NvNodeLauncher_*',
            'NvDriverUpdateCheckDaily_*',
            'NVIDIA GeForce Experience SelfUpdate_*'
        )
        foreach ($task in $nvTasks) {
            Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | ForEach-Object {
                Disable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Message "Disabled NVIDIA Telemetry task: $($_.TaskName)" -Level Success
                $count++
            }
        }

        # 2. AMD Telemetry & Crash Defender Services
        # Preserve AMD External Events Utility (atiesrxx) for FreeSync/Radeon hotkeys; target true telemetry
        $amdServices = @("AMD Crash Defender Service", "AMD User Experience Program Master", "AUEPMaster", "AUEP")
        foreach ($svc in $amdServices) {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                try {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                    Write-Log -Message "Configured AMD service $($svc) to Manual" -Level Success
                    $count++
                }
                catch {
                    Write-Log -Message "Failed configuring $($svc): $($_.Exception.Message)" -Level Warning
                }
            }
        }

        # AMD Telemetry Tasks
        Get-ScheduledTask -TaskName "*AMD*Telemetry*" -ErrorAction SilentlyContinue | ForEach-Object {
            Disable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Message "Disabled AMD task: $($_.TaskName)" -Level Success
            $count++
        }
        Get-ScheduledTask -TaskName "*AUEP*" -ErrorAction SilentlyContinue | ForEach-Object {
            Disable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Message "Disabled AMD task: $($_.TaskName)" -Level Success
            $count++
        }

        # 3. Intel Telemetry
        # NEVER disable IntelAudioService (High Definition Audio / SST). Target only telemetry.
        $intelServices = @("Intel(R) Telemetry Service", "ESRV_SVC_QUEENCREEK", "USER_ESRV_SVC_QUEENCREEK", "Intel-Cip")
        foreach ($svc in $intelServices) {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                try {
                    Stop-Service -Name $svc -Force -ErrorAction Stop
                    Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
                    Write-Log -Message "Disabled Intel service: $($svc)" -Level Success
                    $count++
                }
                catch {
                    Write-Log -Message "Failed to disable $($svc): $($_.Exception.Message)" -Level Warning
                }
            }
        }

        Write-Log -Message "GPU telemetry optimization complete ($count items adjusted)." -Level Success
    }
}

#endregion

#region OEM Bloatware Removal

<#
.SYNOPSIS
    Removes OEM vendor bloatware background services.
.DESCRIPTION
    Debloats OEM manufacturer background services while preserving critical thermal/fan controllers.
.PARAMETER Vendor
    The OEM vendor to debloat (All, ASUS, Razer, MSI, Dell, HP, Lenovo). Default is All.
#>
function Remove-WinDebloatOemBloat {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [ValidateSet("All", "ASUS", "Razer", "MSI", "Dell", "HP", "Lenovo")]
        [string]$Vendor = "All"
    )

    Write-Log -Message "Scanning for OEM vendor bloatware ($Vendor)..." -Level Info
    $count = 0

    if ($PSCmdlet.ShouldProcess("System", "Debloat OEM Vendor Software ($Vendor)")) {
        # ASUS Armoury Crate / Aura background telemetry (preserves AsusAppService for fan/battery control)
        if ($Vendor -in @("All", "ASUS")) {
            $asusServices = @("ASUSLinkNear", "ASUSLinkRemote", "ASUSSoftwareManager", "ASUSSwitch", "ASUSSystemAnalysis", "ASUSSystemDiagnosis")
            foreach ($svc in $asusServices) {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Log -Message "Disabled ASUS background telemetry: $($svc)" -Level Success
                    $count++
                }
            }
        }

        # Razer Synapse telemetry
        if ($Vendor -in @("All", "Razer")) {
            $razerServices = @("Razer Game Scanner", "Razer Chroma SDK Server")
            foreach ($svc in $razerServices) {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                    Write-Log -Message "Configured Razer service $($svc) to Manual" -Level Success
                    $count++
                }
            }
        }

        # MSI Dragon Center background telemetry
        if ($Vendor -in @("All", "MSI")) {
            $msiServices = @("MSI Central Service", "MSI NB Foundation Service")
            foreach ($svc in $msiServices) {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                    Write-Log -Message "Configured MSI service $($svc) to Manual" -Level Success
                    $count++
                }
            }
        }

        # Dell telemetry (preserve Dell SupportAssist OS Recovery & Thermal management)
        if ($Vendor -in @("All", "Dell")) {
            $dellServices = @("Dell Client Management Service", "Dell Digital Delivery Service", "DDVDataCollector", "DDVRulesProcessor", "DDVCollectorSvcApi")
            foreach ($svc in $dellServices) {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                    Write-Log -Message "Configured Dell service $($svc) to Manual" -Level Success
                    $count++
                }
            }
        }

        # HP telemetry
        if ($Vendor -in @("All", "HP")) {
            $hpServices = @("HP Analytics service", "HP Insights Analytics", "HP Network Optimizer", "HPSupportSolutionsFrameworkService", "TouchpointAnalyticsService")
            foreach ($svc in $hpServices) {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Log -Message "Disabled HP telemetry service: $($svc)" -Level Success
                    $count++
                }
            }
        }

        # Lenovo telemetry (preserves Lenovo Thermal Management / LnvvSvc and Legion Toolkit)
        if ($Vendor -in @("All", "Lenovo")) {
            $lenovoServices = @("LenovoLeSettingHub", "LenovoLeSettingHubElevation", "LenovoVantageService")
            foreach ($svc in $lenovoServices) {
                if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                    Write-Log -Message "Configured Lenovo service $($svc) to Manual" -Level Success
                    $count++
                }
            }
        }

        Write-Log -Message "OEM debloat finished ($count items adjusted)." -Level Success
    }
}

#endregion

<#
.SYNOPSIS
    Restores GPU telemetry services and scheduled tasks to Windows defaults.
#>
function Enable-WinDebloatGpuTelemetry {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param()

    Write-Log -Message "Restoring GPU telemetry services and tasks..." -Level Info

    if ($PSCmdlet.ShouldProcess("System", "Restore GPU Telemetry (NVIDIA/AMD/Intel)")) {
        # NVIDIA
        if (Get-Service -Name "NvTelemetryContainer" -ErrorAction SilentlyContinue) {
            Set-Service -Name "NvTelemetryContainer" -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name "NvTelemetryContainer" -ErrorAction SilentlyContinue
        }
        $nvTasks = @('NvTmMon_*', 'NvTmRep_*', 'NvTmRepOnLogon_*', 'NvNodeLauncher_*', 'NvDriverUpdateCheckDaily_*', 'NVIDIA GeForce Experience SelfUpdate_*')
        foreach ($task in $nvTasks) {
            Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | ForEach-Object {
                Enable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
            }
        }

        # AMD
        Get-ScheduledTask -TaskName "*AMD*Telemetry*" -ErrorAction SilentlyContinue | ForEach-Object {
            Enable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
        }
        Get-ScheduledTask -TaskName "*AUEP*" -ErrorAction SilentlyContinue | ForEach-Object {
            Enable-ScheduledTask -TaskName $_.TaskName -ErrorAction SilentlyContinue | Out-Null
        }

        # Intel
        $intelServices = @("Intel(R) Telemetry Service", "ESRV_SVC_QUEENCREEK", "USER_ESRV_SVC_QUEENCREEK", "Intel-Cip")
        foreach ($svc in $intelServices) {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
            }
        }

        Write-Log -Message "GPU telemetry services and tasks restored." -Level Success
    }
}

# Aliases for backward compatibility
Set-Alias -Name 'Disable-WinDebloat7GpuTelemetry' -Value 'Disable-WinDebloatGpuTelemetry'
Set-Alias -Name 'Disable-WinDebloat7GPUTelemetry' -Value 'Disable-WinDebloatGpuTelemetry'
Set-Alias -Name 'Enable-WinDebloat7GpuTelemetry' -Value 'Enable-WinDebloatGpuTelemetry'
Set-Alias -Name 'Enable-WinDebloat7GPUTelemetry' -Value 'Enable-WinDebloatGpuTelemetry'
Set-Alias -Name 'Remove-WinDebloat7OemBloat' -Value 'Remove-WinDebloatOemBloat'
Set-Alias -Name 'Remove-WinDebloat7OEMBloat' -Value 'Remove-WinDebloatOemBloat'

Export-ModuleMember -Function @(
    'Disable-WinDebloatGpuTelemetry',
    'Enable-WinDebloatGpuTelemetry',
    'Remove-WinDebloatOemBloat'
) -Alias @(
    'Disable-WinDebloat7GpuTelemetry',
    'Disable-WinDebloat7GPUTelemetry',
    'Enable-WinDebloat7GpuTelemetry',
    'Enable-WinDebloat7GPUTelemetry',
    'Remove-WinDebloat7OemBloat',
    'Remove-WinDebloat7OEMBloat'
)
