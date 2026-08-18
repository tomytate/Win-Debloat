#Requires -Version 7.6

<#
.SYNOPSIS
    Captures and compares system performance metrics.
    
.NOTES
    Module: Win-Debloat.Modules.Performance.Benchmark
    Version: 2.0.0
#>

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force -ErrorAction SilentlyContinue

function Measure-WinDebloatSystem {
    <#
    .SYNOPSIS
        Captures current system performance metrics.
        
    .OUTPUTS
        [pscustomobject] Containing RAM, Process count, etc.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $freeRamMB = if ($os -and $os.FreePhysicalMemory) { [math]::Round($os.FreePhysicalMemory / 1KB, 0) } else { 0 }
    $totalRamMB = if ($os -and $os.TotalVisibleMemorySize) { [math]::Round($os.TotalVisibleMemorySize / 1KB, 0) } else { 0 }
    $usedRamMB = [math]::Max(0, ($totalRamMB - $freeRamMB))
    
    $procs = (Get-Process -ErrorAction SilentlyContinue).Count
    $services = (Get-Service -ErrorAction SilentlyContinue | Where-Object Status -eq 'Running').Count
    
    $driveName = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { "C" }
    $driveObj = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    $diskFreeGB = if ($driveObj -and $driveObj.Free) { [math]::Round($driveObj.Free / 1GB, 2) } else { 0 }
    $lastBoot = if ($os) { $os.LastBootUpTime } else { $null }
    
    return [pscustomobject]@{
        Timestamp   = Get-Date
        UsedRAM_MB  = $usedRamMB
        FreeRAM_MB  = $freeRamMB
        Processes   = $procs
        Services    = $services
        DiskFree_GB = $diskFreeGB
        LastBoot    = $lastBoot
    }
}

function Compare-WinDebloatBenchmarks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    <#
    .SYNOPSIS
        Compares two benchmark objects and generates a report.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] $Reference,
        [Parameter(Mandatory)] $Difference,
        [string]$ReportPath = "$env:USERPROFILE\Desktop\Win-Debloat_Benchmark_Report.md"
    )

    $ramDiff = $Reference.UsedRAM_MB - $Difference.UsedRAM_MB
    $procDiff = $Reference.Processes - $Difference.Processes
    $servDiff = $Reference.Services - $Difference.Services
    $diskDiff = $Difference.DiskFree_GB - $Reference.DiskFree_GB

    # Generate Report
    $sb = [System.Text.StringBuilder]::new()
    $sb.AppendLine("# Win-Debloat Optimization Report") | Out-Null
    $sb.AppendLine("Generated on $(Get-Date)") | Out-Null
    $sb.AppendLine("") | Out-Null
    
    $sb.AppendLine("| Metric | Before | After | Improvement |") | Out-Null
    $sb.AppendLine("| :--- | :--- | :--- | :--- |") | Out-Null
    $sb.AppendLine("| **Used RAM** | $($Reference.UsedRAM_MB) MB | $($Difference.UsedRAM_MB) MB | **$($ramDiff) MB** freed |") | Out-Null
    $sb.AppendLine("| **Processes** | $($Reference.Processes) | $($Difference.Processes) | **$($procDiff)** fewer |") | Out-Null
    $sb.AppendLine("| **Running Services** | $($Reference.Services) | $($Difference.Services) | **$($servDiff)** disabled |") | Out-Null
    $sb.AppendLine("| **Free Disk (C:)** | $($Reference.DiskFree_GB) GB | $($Difference.DiskFree_GB) GB | **$($diskDiff) GB** reclaimed |") | Out-Null
    
    $report = $sb.ToString()
    
    try {
        $report | Set-Content -Path $ReportPath -Encoding UTF8
        Write-Log -Message "Benchmark report saved to $ReportPath" -Level Success
    }
    catch {
        Write-Log -Message "Could not save benchmark report: $($_.Exception.Message)" -Level Warning
    }

    return $report
}

# Aliases for backward compatibility
Set-Alias -Name 'Measure-WinDebloat7System' -Value 'Measure-WinDebloatSystem'
Set-Alias -Name 'Compare-WinDebloat7Benchmarks' -Value 'Compare-WinDebloatBenchmarks'
Set-Alias -Name 'Compare-WinDebloatBenchmark' -Value 'Compare-WinDebloatBenchmarks'
Set-Alias -Name 'Compare-WinDebloat7Benchmark' -Value 'Compare-WinDebloatBenchmarks'

Export-ModuleMember -Function @(
    'Measure-WinDebloatSystem',
    'Compare-WinDebloatBenchmarks'
) -Alias @(
    'Measure-WinDebloat7System',
    'Compare-WinDebloat7Benchmarks',
    'Compare-WinDebloatBenchmark',
    'Compare-WinDebloat7Benchmark'
)
