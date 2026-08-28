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

    # Fast path: High-performance .NET APIs (<4ms) with graceful fallback to CIM/WMI
    $os = $null
    
    # 1. RAM / Memory via [System.GC]::GetGCMemoryInfo() with CIM fallback
    $usedRamMB = 0
    $freeRamMB = 0
    try {
        $gcInfo = [System.GC]::GetGCMemoryInfo()
        if ($gcInfo.MemoryLoadBytes -eq 0) {
            [System.GC]::Collect(0, [System.GCCollectionMode]::Optimized)
            $gcInfo = [System.GC]::GetGCMemoryInfo()
        }
        if ($gcInfo.TotalAvailableMemoryBytes -gt 0 -and $gcInfo.MemoryLoadBytes -gt 0) {
            $totalRamMB = [math]::Round($gcInfo.TotalAvailableMemoryBytes / 1MB, 0)
            $usedRamMB = [math]::Round($gcInfo.MemoryLoadBytes / 1MB, 0)
            $freeRamMB = [math]::Max(0, ($totalRamMB - $usedRamMB))
        }
        else {
            throw "Invalid GCMemoryInfo"
        }
    }
    catch {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $freeRamMB = if ($os -and $os.FreePhysicalMemory) { [math]::Round($os.FreePhysicalMemory / 1KB, 0) } else { 0 }
        $totalRamMB = if ($os -and $os.TotalVisibleMemorySize) { [math]::Round($os.TotalVisibleMemorySize / 1KB, 0) } else { 0 }
        $usedRamMB = [math]::Max(0, ($totalRamMB - $freeRamMB))
    }

    # 2. Process Count via [System.Diagnostics.Process]::GetProcesses().Length with fallback
    $procs = try {
        [System.Diagnostics.Process]::GetProcesses().Length
    }
    catch {
        (Get-Process -ErrorAction SilentlyContinue).Count
    }

    # 3. Running Services Count via fast ServiceController enumeration with fallback
    $services = try {
        $svcCount = 0
        foreach ($svc in [System.ServiceProcess.ServiceController]::GetServices()) {
            if ($svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                $svcCount++
            }
        }
        $svcCount
    }
    catch {
        (Get-Service -ErrorAction SilentlyContinue | Where-Object Status -eq 'Running').Count
    }

    # 4. Free Disk Space (GB) via [System.IO.DriveInfo] with PSDrive fallback
    $driveName = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { "C" }
    $diskFreeGB = try {
        $drive = [System.IO.DriveInfo]::new($driveName)
        if ($drive.IsReady) {
            [math]::Round($drive.AvailableFreeSpace / 1GB, 2)
        }
        else {
            throw "Drive $driveName is not ready"
        }
    }
    catch {
        $driveObj = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
        if ($driveObj -and $driveObj.Free) { [math]::Round($driveObj.Free / 1GB, 2) } else { 0 }
    }

    # 5. Last Boot Time via [System.Environment]::TickCount64 with CIM fallback
    $lastBoot = try {
        [System.DateTime]::UtcNow.AddMilliseconds(-[System.Environment]::TickCount64).ToLocalTime()
    }
    catch {
        if (-not $os) { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue }
        if ($os) { $os.LastBootUpTime } else { $null }
    }

    return [pscustomobject]@{
        Timestamp   = [System.DateTime]::Now
        UsedRAM_MB  = $usedRamMB
        FreeRAM_MB  = $freeRamMB
        Processes   = $procs
        Services    = $services
        DiskFree_GB = $diskFreeGB
        LastBoot    = $lastBoot
    }
}

function Compare-WinDebloatBenchmarks {
    <#
    .SYNOPSIS
        Compares two benchmark objects and generates a report.

    .PARAMETER Reference
        The pre-optimization benchmark measurement object.

    .PARAMETER Difference
        The post-optimization benchmark measurement object.

    .PARAMETER ReportPath
        The destination path for the markdown benchmark report file.

    .OUTPUTS
        [string] The formatted markdown benchmark report.

    .EXAMPLE
        Compare-WinDebloatBenchmarks -Reference $before -Difference $after
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
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
