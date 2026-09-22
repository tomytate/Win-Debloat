#Requires -Version 7.6

<#
.SYNOPSIS
    Version detection for Windows 11 and 25H2 support in Win-Debloat.
    
.DESCRIPTION
    Provides functions to detect specific Windows 11 versions and feature updates.
    Includes result caching to prevent repeated CIM queries (PERF-001 fix).
    
.NOTES
    Module: Win-Debloat.Modules.Windows11.VersionDetection
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

class WindowsVersionInfo {
    [string]$ProductName    # Raw CIM caption, e.g. "Microsoft Windows 11 Pro"
    [string]$Edition        # Home / Pro / Enterprise / Education...
    [string]$DisplayVersion # Feature-update label, e.g. "24H2"
    [string]$FriendlyName   # Feature-update label (alias of DisplayVersion)
    [int]$BuildNumber
    [int]$Ubr              # Update Build Revision (the .xxxx after the build)
    [bool]$IsWindows11
    [string]$FullName       # Composed, display-ready, e.g. "Windows 11 Pro"
}

# Cache to prevent repeated CIM queries (PERF-001 fix)
$Script:CachedVersionInfo = $null
$Script:CacheTimestamp = [datetime]::MinValue
$Script:CacheLifetimeMinutes = 5

<#
.SYNOPSIS
    Gets information about the current Windows version.
    
.DESCRIPTION
    Returns a WindowsVersionInfo object containing OS details.
    Results are cached for 5 minutes to improve performance.
    
.PARAMETER Force
    Forces a fresh query, bypassing the cache.
    
.OUTPUTS
    [WindowsVersionInfo]
    
.EXAMPLE
    $ver = Get-WinDebloatVersionInfo
    Write-Host "Running on $($ver.FriendlyName)"
#>
function Get-WinDebloatVersionInfo {
    [CmdletBinding()]
    [OutputType([WindowsVersionInfo])]
    param(
        [switch]$Force,
        [psobject]$TestOS # For Unit Testing
    )
    
    # PERF-001 fix: Return cached result if valid (skip if testing)
    $now = Get-Date
    if (-not $TestOS -and -not $Force -and $Script:CachedVersionInfo -and 
        ($now - $Script:CacheTimestamp).TotalMinutes -lt $Script:CacheLifetimeMinutes) {
        return $Script:CachedVersionInfo
    }
    
    $os = if ($TestOS) { $TestOS } else { Get-CimInstance Win32_OperatingSystem }
    $build = [int]$os.BuildNumber

    $info = [WindowsVersionInfo]::new()
    $info.ProductName = $os.Caption
    $info.BuildNumber = $build
    $info.IsWindows11 = $build -ge 22000

    # Read the registry once for the authoritative feature-update label, edition,
    # and update revision. CIM's Caption is unreliable after in-place upgrades.
    # Skipped under -TestOS so unit tests exercise the build->label fallback map
    # deterministically instead of reading the host's real registry.
    $cvKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $displayVersion = $null
    $editionId = $null
    if (-not $TestOS) {
        try { $displayVersion = Get-ItemPropertyValue -Path $cvKey -Name "DisplayVersion" -ErrorAction Stop } catch { $displayVersion = $null }
        if (-not $displayVersion) {
            # Pre-2004 builds used ReleaseId (e.g. "1909") instead of DisplayVersion
            try { $displayVersion = Get-ItemPropertyValue -Path $cvKey -Name "ReleaseId" -ErrorAction Stop } catch { $displayVersion = $null }
        }
        try { $editionId = Get-ItemPropertyValue -Path $cvKey -Name "EditionID" -ErrorAction Stop } catch { $editionId = $null }
        try { $info.Ubr = [int](Get-ItemPropertyValue -Path $cvKey -Name "UBR" -ErrorAction Stop) } catch { $info.Ubr = $null }
    }

    # Prefer the registry's DisplayVersion; fall back to a correct build->label map
    # (ordered elseif chain - the module's old switch had no 'break' and always
    # collapsed to "21H2" because every -ge condition matched).
    if ($displayVersion) {
        $info.DisplayVersion = $displayVersion
    }
    else {
        $info.DisplayVersion =
        if ($build -ge 27800 -or ($build -ge 26300 -and $build -lt 27000)) { "26H2" }
        elseif ($build -ge 27600) { "26H1" }
        elseif ($build -ge 26200) { "25H2" }
        elseif ($build -ge 26100) { "24H2" }
        elseif ($build -ge 22631) { "23H2" }
        elseif ($build -ge 22621) { "22H2" }
        elseif ($build -ge 22000) { "21H2" }
        elseif ($build -ge 19045) { "22H2" }   # Windows 10
        elseif ($build -ge 19044) { "21H2" }   # Windows 10
        elseif ($build -ge 19043) { "21H1" }   # Windows 10
        elseif ($build -ge 19042) { "20H2" }   # Windows 10
        elseif ($build -ge 19041) { "2004" }   # Windows 10
        elseif ($build -ge 18363) { "1909" }   # Windows 10
        else { "Legacy" }
    }
    $info.FriendlyName = $info.DisplayVersion

    # Edition: prefer EditionID (Core/Professional/Enterprise/...), else parse Caption
    $info.Edition = if ($editionId -like "Core*") { "Home" }
    elseif ($editionId -like "Professional*") { "Pro" }
    elseif ($editionId -like "Enterprise*") { "Enterprise" }
    elseif ($editionId -like "Education*") { "Education" }
    elseif ($editionId -like "Server2025*" -or ($editionId -like "Server*" -and $build -ge 26100)) { "Server 2025" }
    elseif ($editionId -like "Server2022*" -or ($editionId -like "Server*" -and $build -ge 20348)) { "Server 2022" }
    elseif ($editionId -like "ServerStandard*") { "Server Standard" }
    elseif ($editionId -like "ServerDatacenter*") { "Server Datacenter" }
    else {
        $m = [regex]::Match($os.Caption, '(Home|Pro(?:fessional)?|Enterprise|Education|Server\s+\w+)')
        if ($m.Success) { $m.Value -replace 'Professional', 'Pro' } else { "" }
    }

    # Compose a display-ready name; force the "11" label when the build says so
    # even if a stale Caption still reports Windows 10.
    $osFamily = if ($info.IsWindows11) { "Windows 11" }
    elseif ($build -ge 10240) { "Windows 10" }
    else { ($os.Caption -replace '^Microsoft\s+', '').Trim() }
    $info.FullName = (@($osFamily, $info.Edition) | Where-Object { $_ }) -join ' '

    # Update cache
    $Script:CachedVersionInfo = $info
    $Script:CacheTimestamp = $now

    return $info
}

<#
.SYNOPSIS
    Tests if the current Windows version meets a minimum requirement.
    
.PARAMETER MinimumVersion
    The minimum Windows 11 version to check for.
    
.OUTPUTS
    [bool] True if current version meets or exceeds minimum.
    
.EXAMPLE
    if (Test-WinDebloat11Version -MinimumVersion "23H2") { ... }
#>
function Test-WinDebloat11Version {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("21H2", "22H2", "23H2", "24H2", "25H2", "26H1", "26H2")]
        [string]$MinimumVersion,
        
        [psobject]$TestOS # For Unit Testing
    )
    
    $current = Get-WinDebloatVersionInfo -TestOS $TestOS
    if (-not $current.IsWindows11) { return $false }
    
    $minBuild = switch ($MinimumVersion) {
        "21H2" { 22000 }
        "22H2" { 22621 }
        "23H2" { 22631 }
        "24H2" { 26100 }
        "25H2" { 26200 }
        "26H1" { 27600 }
        "26H2" { if ($current.BuildNumber -ge 27000) { 27800 } else { 26300 } }
    }
    
    return $current.BuildNumber -ge $minBuild
}

<#
.SYNOPSIS
    Clears the version info cache.
#>
function Clear-WinDebloatVersionCache {
    [CmdletBinding()]
    [OutputType([void])]
    param()
    
    $Script:CachedVersionInfo = $null
    $Script:CacheTimestamp = [datetime]::MinValue
}

# Aliases for backward compatibility
Set-Alias -Name 'Get-WindowsVersionInfo' -Value 'Get-WinDebloatVersionInfo'
Set-Alias -Name 'Get-WinDebloat7VersionInfo' -Value 'Get-WinDebloatVersionInfo'
Set-Alias -Name 'Test-Windows11Version' -Value 'Test-WinDebloat11Version'
Set-Alias -Name 'Test-WinDebloatWindows11Version' -Value 'Test-WinDebloat11Version'
Set-Alias -Name 'Test-WinDebloat7Windows11Version' -Value 'Test-WinDebloat11Version'
Set-Alias -Name 'Test-WinDebloat711Version' -Value 'Test-WinDebloat11Version'
Set-Alias -Name 'Test-WinDebloatVersion' -Value 'Test-WinDebloat11Version'
Set-Alias -Name 'Test-WinDebloat7Version' -Value 'Test-WinDebloat11Version'
Set-Alias -Name 'Clear-WindowsVersionCache' -Value 'Clear-WinDebloatVersionCache'
Set-Alias -Name 'Clear-WinDebloat7VersionCache' -Value 'Clear-WinDebloatVersionCache'

Export-ModuleMember -Function @(
    'Get-WinDebloatVersionInfo',
    'Test-WinDebloat11Version',
    'Clear-WinDebloatVersionCache'
) -Alias @(
    'Get-WindowsVersionInfo',
    'Get-WinDebloat7VersionInfo',
    'Test-Windows11Version',
    'Test-WinDebloatWindows11Version',
    'Test-WinDebloat7Windows11Version',
    'Test-WinDebloat711Version',
    'Test-WinDebloatVersion',
    'Test-WinDebloat7Version',
    'Clear-WindowsVersionCache',
    'Clear-WinDebloat7VersionCache'
)
