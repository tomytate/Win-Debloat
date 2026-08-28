#Requires -Version 7.6

<#
.SYNOPSIS
    Service optimization module for Win-Debloat.
    
.DESCRIPTION
    Manages Windows service startup types for privacy, performance, and security.
    Uses presets from config/services.json.
    
.NOTES
    Module: Win-Debloat.Modules.Services
    Version: 2.0.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

#region Service Optimization

# Fast startup type mapping dictionary (O(1) lookup, zero per-service hashtable recreation)
$Script:ServiceStartupMapping = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$Script:ServiceStartupMapping["Disabled"]              = "Disabled"
$Script:ServiceStartupMapping["Manual"]                = "Manual"
$Script:ServiceStartupMapping["Automatic"]             = "Automatic"
$Script:ServiceStartupMapping["AutomaticDelayedStart"] = "AutomaticDelayedStart"

function Set-WinDebloatServices {
    <#
    .SYNOPSIS
        Optimizes Windows service startup types based on a preset.

    .PARAMETER Preset
        The optimization preset: Privacy, Performance, Security, or Minimal.

    .PARAMETER ConfigPath
        Optional path to services.json configuration file.

    .OUTPUTS
        [void]

    .EXAMPLE
        Set-WinDebloatServices -Preset Privacy
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Privacy", "Performance", "Security", "Minimal", "Gaming")]
        [string]$Preset,

        [string]$ConfigPath = "$PSScriptRoot\..\..\..\config\services.json"
    )

    # Load services configuration
    if (-not (Test-Path $ConfigPath)) {
        Write-Log -Message "Services configuration not found: $ConfigPath" -Level Error
        return
    }

    try {
        # PS 7.5+: ConvertFrom-Json with standard parsing
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log -Message "Failed to parse services.json: $($_.Exception.Message)" -Level Error
        return
    }

    if (-not $config.presets.$Preset) {
        Write-Log -Message "Preset '$Preset' not found in configuration." -Level Error
        return
    }

    $servicesToOptimize = @($config.presets.$Preset)
    Write-Log -Message "Applying '$Preset' preset ($($servicesToOptimize.Count) services)..." -Level Info
    
    $successCount = 0
    $failCount = 0

    # Optimized: Batch query all services first with fast collection mapping (O(1) lookup vs O(N) per service)
    Write-Log -Message "Querying service states..." -Level Info
    $validationList = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $queriedServices = @(Get-Service -Name $servicesToOptimize -ErrorAction SilentlyContinue)
        $queriedServices.ForEach({
            if ($_) {
                $validationList[$_.Name] = $_
            }
        })
    }
    catch {
        Write-Log -Message "Error querying services: $($_.Exception.Message)" -Level Warning
    }

    $servicesToOptimize.ForEach({
        $serviceName = $_
        $serviceConfig = $config.services.$serviceName

        if (-not $serviceConfig) {
            Write-Log -Message "Service config not found for: $serviceName" -Level Warning
            return
        }

        $targetStartup = $serviceConfig.StartupType

        if ($PSCmdlet.ShouldProcess($serviceConfig.DisplayName, "Set startup to $targetStartup")) {
            try {
                if ($validationList.ContainsKey($serviceName)) {
                    $service = $validationList[$serviceName]
                }
                else {
                    # Fallback check if not found in batch (maybe stopped/hidden?)
                    $service = Get-Service -Name $serviceName -ErrorAction Stop
                }

                # Validate service can be modified - stop running services before disabling
                if ($service.Status -eq 'Running' -and $targetStartup -eq 'Disabled') {
                    Write-Log -Message "Stopping $serviceName before disabling..." -Level Info
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                }

                $mappedStartup = if ($Script:ServiceStartupMapping.ContainsKey($targetStartup)) {
                    $Script:ServiceStartupMapping[$targetStartup]
                }
                else {
                    "Manual" # Default fallback
                }

                Set-Service -Name $serviceName -StartupType $mappedStartup -ErrorAction Stop
                Write-Log -Message "Set $serviceName to $mappedStartup" -Level Success
                $successCount++
            }
            catch {
                Write-Log -Message "Failed to configure $serviceName : $($_.Exception.Message)" -Level Warning
                $failCount++
            }
        }
    })

    Write-Log -Message "Service optimization complete: $successCount succeeded, $failCount failed." -Level Info
}

function Get-WinDebloatServicePresets {
    <#
    .SYNOPSIS
        Gets available service optimization presets.

    .OUTPUTS
        [string[]] List of preset names.

    .EXAMPLE
        Get-WinDebloatServicePresets
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return [string[]]@("Privacy", "Performance", "Security", "Minimal", "Gaming")
}

function Get-WinDebloatServiceStatus {
    <#
    .SYNOPSIS
        Gets the current status of optimizable services.

    .PARAMETER ConfigPath
        Optional path to services.json configuration file.

    .OUTPUTS
        [psobject[]] Service status objects.

    .EXAMPLE
        Get-WinDebloatServiceStatus
    #>
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\..\..\config\services.json"
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Log -Message "Services configuration not found: $ConfigPath" -Level Error
        return [psobject[]]@()
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $results = [System.Collections.Generic.List[psobject]]::new()
    $serviceNames = @($config.services.PSObject.Properties.Name)

    # Batch query all target services in one call with fast collection mapping (O(1) lookup vs N sequential queries)
    $serviceMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $queriedServices = @(Get-Service -Name $serviceNames -ErrorAction SilentlyContinue)
        $queriedServices.ForEach({
            if ($_) {
                $serviceMap[$_.Name] = $_
            }
        })
    }
    catch {
        Write-Log -Message "Error batch querying services: $($_.Exception.Message)" -Level Debug
    }

    $serviceNames.ForEach({
        $serviceName = $_
        $serviceConfig = $config.services.$serviceName

        if ($serviceMap.ContainsKey($serviceName)) {
            $service = $serviceMap[$serviceName]
            $currentStartup = if ($service.StartType) { $service.StartType.ToString() } else { "Unknown" }

            $results.Add([pscustomobject]@{
                    Name               = $serviceName
                    DisplayName        = $serviceConfig.DisplayName
                    Status             = $service.Status
                    CurrentStartup     = $currentStartup
                    RecommendedStartup = $serviceConfig.StartupType
                    Category           = $serviceConfig.Category
                    Description        = $serviceConfig.Description
                })
        }
        else {
            Write-Verbose "Service $serviceName not found on this system."
        }
    })

    return [psobject[]]$results.ToArray()
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7Services' -Value 'Set-WinDebloatServices'
Set-Alias -Name 'Optimize-WinDebloatServices' -Value 'Set-WinDebloatServices'
Set-Alias -Name 'Optimize-WinDebloat7Services' -Value 'Set-WinDebloatServices'
Set-Alias -Name 'Get-WinDebloat7ServicePresets' -Value 'Get-WinDebloatServicePresets'
Set-Alias -Name 'Get-WinDebloat7ServiceStatus' -Value 'Get-WinDebloatServiceStatus'

Export-ModuleMember -Function @(
    'Set-WinDebloatServices',
    'Get-WinDebloatServicePresets',
    'Get-WinDebloatServiceStatus'
) -Alias @(
    'Set-WinDebloat7Services',
    'Optimize-WinDebloatServices',
    'Optimize-WinDebloat7Services',
    'Get-WinDebloat7ServicePresets',
    'Get-WinDebloat7ServiceStatus'
)
