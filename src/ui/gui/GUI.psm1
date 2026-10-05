#Requires -Version 7.6

<#
.SYNOPSIS
    WPF GUI Controller for Win-Debloat (Premium Edition)

.DESCRIPTION
    Loads the XAML interface with sidebar navigation, binds event handlers,
    and bridges GUI actions to backend PowerShell modules.

.NOTES
    Module: Win-Debloat.UI.GUI
    Version: 1.7.0
#>

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Event parameters required by signature')]

$Script:Version = '1.7.0'

# Import Backend Modules
$scriptRoot = $PSScriptRoot
Import-Module "$scriptRoot\..\..\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\core\Config.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\core\SystemState.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\core\State.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\core\Sysprep.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Bloatware\Bloatware.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Privacy\Privacy.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Performance\Performance.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Performance\Gaming.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Performance\Benchmark.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Performance\Tweaks.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Performance\Services.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Drivers\Drivers.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Tweaks\UI.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Tweaks\System.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Software\Software.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Network\Network.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Privacy\Tasks.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Privacy\Firewall.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Windows11\Version-Detection.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Repair\Repair.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Features\Features.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Security\Security.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$scriptRoot\..\..\modules\Maintenance\Maintenance.psm1" -Force -ErrorAction SilentlyContinue

# Ensure canonical *-WinDebloat cmdlets and backward compatibility aliases are available
$canonicalMap = @{
    'Get-WinDebloatSystemState'                 = 'Get-WinDebloat7SystemState'
    'Get-WinDebloatPrivacyScore'                = 'Get-WinDebloat7PrivacyScore'
    'Import-WinDebloatConfig'                   = 'Import-WinDebloat7Config'
    'Get-WinDebloatProfilePlan'                 = 'Get-WinDebloat7ProfilePlan'
    'New-WinDebloatSnapshot'                    = 'New-WinDebloat7Snapshot'
    'Get-WinDebloatSnapshot'                    = 'Get-WinDebloat7Snapshot'
    'Restore-WinDebloatSnapshot'                = 'Restore-WinDebloat7Snapshot'
    'Remove-WinDebloatBloatware'                = 'Remove-WinDebloat7Bloatware'
    'Set-WinDebloatPrivacy'                     = 'Set-WinDebloat7Privacy'
    'Set-WinDebloatPerformance'                 = 'Set-WinDebloat7Performance'
    'Optimize-WinDebloatPerformance'            = 'Set-WinDebloat7Performance'
    'Set-WinDebloatSystemTweaks'                = 'Set-WinDebloat7SystemTweaks'
    'Enable-WinDebloatUltimatePower'            = 'Enable-WinDebloat7UltimatePower'
    'Disable-WinDebloatUltimatePower'           = 'Disable-WinDebloat7UltimatePower'
    'Set-WinDebloatServices'                    = 'Set-WinDebloat7Services'
    'Add-WinDebloatFirewallBlock'               = 'Add-WinDebloat7FirewallBlock'
    'Disable-WinDebloatFastStartup'             = 'Disable-WinDebloat7FastStartup'
    'Enable-WinDebloatFastStartup'              = 'Enable-WinDebloat7FastStartup'
    'Disable-WinDebloatAutoBitLocker'           = 'Disable-WinDebloat7AutoBitLocker'
    'Enable-WinDebloatAutoBitLocker'            = 'Enable-WinDebloat7AutoBitLocker'
    'Disable-WinDebloatDeliveryOptimization'    = 'Disable-WinDebloat7DeliveryOptimization'
    'Enable-WinDebloatDeliveryOptimization'     = 'Enable-WinDebloat7DeliveryOptimization'
    'Disable-WinDebloatStorageSense'            = 'Disable-WinDebloat7StorageSense'
    'Enable-WinDebloatStorageSense'             = 'Enable-WinDebloat7StorageSense'
    'Set-WinDebloatUpdateBehavior'              = 'Set-WinDebloat7UpdateBehavior'
    'Disable-WinDebloatModernStandbyNetworking' = 'Disable-WinDebloat7ModernStandbyNetworking'
    'Enable-WinDebloatModernStandbyNetworking'  = 'Enable-WinDebloat7ModernStandbyNetworking'
    'Disable-WinDebloatFindMyDevice'            = 'Disable-WinDebloat7FindMyDevice'
    'Enable-WinDebloatFindMyDevice'             = 'Enable-WinDebloat7FindMyDevice'
    'Disable-WinDebloatStickyKeysShortcut'      = 'Disable-WinDebloat7StickyKeysShortcut'
    'Enable-WinDebloatStickyKeysShortcut'       = 'Enable-WinDebloat7StickyKeysShortcut'
    'Disable-WinDebloatWidgets'                 = 'Disable-WinDebloat7Widgets'
    'Enable-WinDebloatWidgets'                  = 'Enable-WinDebloat7Widgets'
    'Disable-WinDebloatChatTaskbar'             = 'Disable-WinDebloat7ChatTaskbar'
    'Enable-WinDebloatChatTaskbar'              = 'Enable-WinDebloat7ChatTaskbar'
    'Disable-WinDebloatTransparency'            = 'Disable-WinDebloat7Transparency'
    'Enable-WinDebloatTransparency'             = 'Enable-WinDebloat7Transparency'
    'Disable-WinDebloatSnapAssist'              = 'Disable-WinDebloat7SnapAssist'
    'Enable-WinDebloatSnapAssist'               = 'Enable-WinDebloat7SnapAssist'
    'Disable-WinDebloatStartAllApps'            = 'Disable-WinDebloat7StartAllApps'
    'Enable-WinDebloatStartAllApps'             = 'Enable-WinDebloat7StartAllApps'
    'Set-WinDebloatExplorer'                    = 'Set-WinDebloat7Explorer'
    'Set-WinDebloatContextMenuItems'            = 'Set-WinDebloat7ContextMenuItems'
    'Set-WinDebloatSearch'                      = 'Set-WinDebloat7Search'
    'Disable-WinDebloatWindowsSuggestions'      = 'Disable-WinDebloat7WindowsSuggestions'
    'Enable-WinDebloatWindowsSuggestions'       = 'Enable-WinDebloat7WindowsSuggestions'
    'Disable-WinDebloatSettingsHome'            = 'Disable-WinDebloat7SettingsHome'
    'Enable-WinDebloatSettingsHome'             = 'Enable-WinDebloat7SettingsHome'
    'Disable-WinDebloatTelemetryTasks'          = 'Disable-WinDebloat7TelemetryTasks'
    'Get-WinDebloatEssentialsList'              = 'Get-WinDebloat7EssentialsList'
    'Install-WinDebloatSoftware'                = 'Install-WinDebloat7Software'
    'Set-WinDebloatDNS'                         = 'Set-WinDebloat7DNS'
    'Disable-WinDebloatIPv6'                    = 'Disable-WinDebloat7IPv6'
    'Enable-WinDebloatIPv6'                     = 'Enable-WinDebloat7IPv6'
    'Disable-WinDebloatNetBIOS'                 = 'Disable-WinDebloat7NetBIOS'
    'Enable-WinDebloatNetBIOS'                  = 'Enable-WinDebloat7NetBIOS'
    'Disable-WinDebloatSMBv1'                   = 'Disable-WinDebloat7SMBv1'
    'Enable-WinDebloatSMBv1'                    = 'Enable-WinDebloat7SMBv1'
    'Remove-WinDebloatFirewallBlock'            = 'Remove-WinDebloat7FirewallBlock'
    'Set-WinDebloatTaskbarAlignment'            = 'Set-WinDebloat7TaskbarAlignment'
    'Set-WinDebloatContextMenu'                 = 'Set-WinDebloat7ContextMenu'
    'Restart-WinDebloatExplorer'                = 'Restart-WinDebloat7Explorer'
    'Update-WinDebloatDrivers'                  = 'Update-WinDebloat7Drivers'
    'Repair-WinDebloatSystem'                   = 'Repair-WinDebloat7System'
    'Reset-WinDebloatNetwork'                   = 'Reset-WinDebloat7Network'
    'Reset-WinDebloatUpdate'                    = 'Reset-WinDebloat7Update'
    'Measure-WinDebloatSystem'                  = 'Measure-WinDebloat7System'
}

foreach ($canonical in $canonicalMap.Keys) {
    $legacy = $canonicalMap[$canonical]
    if (-not (Get-Command $canonical -ErrorAction SilentlyContinue)) {
        if (Get-Command $legacy -ErrorAction SilentlyContinue) {
            Set-Alias -Name $canonical -Value $legacy -Scope Script -ErrorAction SilentlyContinue
        }
    }
    elseif (-not (Get-Command $legacy -ErrorAction SilentlyContinue)) {
        Set-Alias -Name $legacy -Value $canonical -Scope Script -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Launches the Win-Debloat graphical user interface (WPF).
.OUTPUTS
    [void]
#>
function Show-WinDebloatGUI {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    # Headless / CI Guard
    if ($env:WIN_DEBLOAT_HEADLESS -eq '1' -or ($env:CI -eq 'true' -and [System.Environment]::UserInteractive -eq $false)) {
        Write-Verbose "Headless or non-interactive environment detected. Skipping interactive WPF modal execution."
        return
    }

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
    if (-not (Test-Path $xamlPath)) {
        Write-Warning "MainWindow.xaml not found at $xamlPath"
        return
    }

    try {
        [xml]$xaml = Get-Content $xamlPath -Raw
        $reader = (New-Object System.Xml.XmlNodeReader $xaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)

        # ═══════════════════════════════════════════════════════════════════════
        # NATIVE DWM WINDOW ERGONOMICS (IMMERSIVE DARK TITLEBAR & ROUNDED CHROME)
        # ═══════════════════════════════════════════════════════════════════════
        try {
            if (-not ([System.Management.Automation.PSTypeName]'WinDebloatDwm').Type) {
                Add-Type -TypeDefinition @'
                using System;
                using System.Runtime.InteropServices;

                public class WinDebloatDwm {
                    [DllImport("dwmapi.dll")]
                    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
                }
'@ -ErrorAction SilentlyContinue
            }

            if (-not ([System.Management.Automation.PSTypeName]'WinDebloatSoftwareAppItem').Type) {
                Add-Type -TypeDefinition @'
                using System;
                using System.Collections.Generic;

                public class WinDebloatSoftwareAppItem {
                    public string Name { get; set; }
                    public string PackageId { get; set; }
                    public string ChocoId { get; set; }
                    public string MsstoreId { get; set; }
                    public string NpmId { get; set; }
                    public bool Recommended { get; set; }
                    public string Description { get; set; }
                    public bool IsSelected { get; set; }
                }

                public class WinDebloatSoftwareCategoryItem {
                    public string CategoryName { get; set; }
                    public List<WinDebloatSoftwareAppItem> Apps { get; set; }
                }
'@ -ErrorAction SilentlyContinue
            }

            $interopHelper = [System.Windows.Interop.WindowInteropHelper]::new($window)
            $hwnd = $interopHelper.EnsureHandle()

            $darkMode = 1
            [WinDebloatDwm]::DwmSetWindowAttribute($hwnd, 20, [ref]$darkMode, 4) # DWMWA_USE_IMMERSIVE_DARK_MODE
            $cornerPref = 2 # DWMWCP_ROUND
            [WinDebloatDwm]::DwmSetWindowAttribute($hwnd, 33, [ref]$cornerPref, 4) # DWMWA_WINDOW_CORNER_PREFERENCE
            $darkBorder = 0x00334155 # BGR #334155
            [WinDebloatDwm]::DwmSetWindowAttribute($hwnd, 34, [ref]$darkBorder, 4) # DWMWA_BORDER_COLOR
            $darkCaption = 0x0020110B # BGR #0B1120
            [WinDebloatDwm]::DwmSetWindowAttribute($hwnd, 35, [ref]$darkCaption, 4) # DWMWA_CAPTION_COLOR
        }
        catch {
            Write-Verbose "DWM ergonomics initialization skipped: $($_.Exception.Message)"
        }

        # Helper to get controls
        $getCtrl = { param($name) $window.FindName($name) }

        # Get controls
        $txtStatus = & $getCtrl "txtStatus"

        # Initialize lower-left sidebar version badge
        $txtSidebarVersion = & $getCtrl "txtSidebarVersion"
        if ($txtSidebarVersion) {
            $verString = if ($Script:Version) { if ($Script:Version -like "v*") { $Script:Version } else { "v$Script:Version" } } else { "v1.7.0" }
            $txtSidebarVersion.Text = "$verString `"Apex`" • PowerShell 7.6+"
        }

        # Load and set official logo on Window icon, sidebar header, and About card
        $logoCandidates = @(
            (Join-Path $PSScriptRoot "..\..\..\assets\logo.png"),
            (Join-Path $PSScriptRoot "..\..\assets\logo.png"),
            (Join-Path $PSScriptRoot "assets\logo.png"),
            (Join-Path (Get-Location) "assets\logo.png"),
            (Join-Path $PSScriptRoot "..\..\..\assets\logo.ico"),
            (Join-Path $PSScriptRoot "..\..\assets\logo.ico"),
            (Join-Path $PSScriptRoot "assets\logo.ico"),
            (Join-Path (Get-Location) "assets\logo.ico")
        )
        $logoPath = $logoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($logoPath) {
            try {
                $absLogoPath = [System.IO.Path]::GetFullPath($logoPath)
                $logoUri = [Uri]::new($absLogoPath)
                $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new($logoUri)
                $window.Icon = $bitmap

                $imgAppLogo = & $getCtrl "imgAppLogo"
                if ($imgAppLogo) { $imgAppLogo.Source = $bitmap }

                $imgAboutLogo = & $getCtrl "imgAboutLogo"
                if ($imgAboutLogo) { $imgAboutLogo.Source = $bitmap }
            }
            catch {
                Write-Verbose "Could not load official logo image: $($_.Exception.Message)"
            }
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # SIDEBAR NAVIGATION
        # ═══════════════════════════════════════════════════════════════════════════════
        $views = @{
            'navDashboard'    = 'viewDashboard'
            'navSystemTweaks' = 'viewSystemTweaks'
            'navSoftware'     = 'viewSoftware'
            'navBackups'      = 'viewBackups'
            'navTools'        = 'viewTools'
            'navSettings'     = 'viewSettings'
        }

        foreach ($navName in $views.Keys) {
            $nav = & $getCtrl $navName
            if ($nav) {
                $nav.Add_Checked({
                        param($s, $e)
                        $null = $s; $null = $e # Suppress unused parameter warning
                        # Hide all views
                        foreach ($vn in $views.Values) {
                            $v = $window.FindName($vn)
                            if ($v) { $v.Visibility = 'Collapsed' }
                        }
                        # Show selected view
                        $targetViewName = $views[$s.Name]
                        $targetView = $window.FindName($targetViewName)
                        if ($targetView) { $targetView.Visibility = 'Visible' }
                    })
            }
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # POPULATE DASHBOARD - Fixed version detection and counting
        # ═══════════════════════════════════════════════════════════════════════════════

        # Helper to force UI update (fixes freezing feeling) and run safely
        $updateGui = {
            [System.Windows.Threading.DispatcherFrame]$frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [Action[System.Windows.Threading.DispatcherFrame]] { param($f) $f.Continue = $false },
                $frame
            ) | Out-Null
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # ASYNC SYSTEM & HARDWARE PROBE ENGINE (NON-BLOCKING)
        # ═══════════════════════════════════════════════════════════════════════════════

        # 1. Instant, non-blocking initial OS detection via registry (<1ms, no CIM block)
        try {
            $cvKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $dispVer = Get-ItemPropertyValue -Path $cvKey -Name "DisplayVersion" -ErrorAction SilentlyContinue
            if (-not $dispVer) { $dispVer = Get-ItemPropertyValue -Path $cvKey -Name "ReleaseId" -ErrorAction SilentlyContinue }
            $buildNum = Get-ItemPropertyValue -Path $cvKey -Name "CurrentBuildNumber" -ErrorAction SilentlyContinue
            $ubrVal = Get-ItemPropertyValue -Path $cvKey -Name "UBR" -ErrorAction SilentlyContinue
            $prodName = Get-ItemPropertyValue -Path $cvKey -Name "ProductName" -ErrorAction SilentlyContinue
            $edition = Get-ItemPropertyValue -Path $cvKey -Name "EditionID" -ErrorAction SilentlyContinue

            $osFamily = if ($buildNum -and [int]$buildNum -ge 22000) { "Windows 11" }
            elseif ($buildNum -and [int]$buildNum -ge 10240) { "Windows 10" }
            else { if ($prodName) { $prodName -replace '^Microsoft\s+', '' } else { "Windows" } }

            $editionClean = if ($edition -like "Core*") { "Home" }
            elseif ($edition -like "Professional*") { "Pro" }
            elseif ($edition -like "Enterprise*") { "Enterprise" }
            elseif ($edition -like "Education*") { "Education" }
            else { $edition }

            $fullOsName = (@($osFamily, $editionClean) | Where-Object { $_ }) -join ' '
            $ubrText = if ($ubrVal) { ".$ubrVal" } else { "" }
            $buildText = if ($buildNum) { "Build $buildNum$ubrText" } else { "Detecting..." }
            $dispText = if ($dispVer) { "$dispVer · " } else { "" }

            (& $getCtrl "txtOSName").Text = if ($fullOsName) { $fullOsName } else { "Windows" }
            (& $getCtrl "txtOSVersion").Text = "$dispText$buildText"
        }
        catch {
            (& $getCtrl "txtOSName").Text = "Windows"
            (& $getCtrl "txtOSVersion").Text = "Detecting..."
        }

        # 2. Asynchronous Live System Probe State (RAM, TCP Connections, Privacy, System State)
        $corePath = (Resolve-Path (Join-Path $scriptRoot "..\..\core")).Path
        $modulesPath = (Resolve-Path (Join-Path $scriptRoot "..\..\modules")).Path

        $liveProbeState = [hashtable]::Synchronized(@{
            IsRunning     = $false
            PowerShell    = $null
            Runspace      = $null
            AsyncHandle   = $null
            FirstRun      = $true
            LastCompleted = [datetime]::MinValue
            TotalRamGB    = 0
        })

        $probeScriptBlock = {
            param($coreDir, $modulesDir)
            try {
                Import-Module "$coreDir\Registry.psm1" -Force -ErrorAction SilentlyContinue
                Import-Module "$coreDir\SystemState.psm1" -Force -ErrorAction SilentlyContinue
                Import-Module "$modulesDir\Windows11\Version-Detection.psm1" -Force -ErrorAction SilentlyContinue
                Import-Module "$modulesDir\Performance\Performance.psm1" -Force -ErrorAction SilentlyContinue
                Import-Module "$modulesDir\Repair\Repair.psm1" -Force -ErrorAction SilentlyContinue

                # Live RAM metrics via CIM in background runspace (non-blocking to UI)
                $osm = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
                $totalMB = if ($osm -and $osm.TotalVisibleMemorySize) { $osm.TotalVisibleMemorySize / 1KB } else { 0 }
                $freeMB = if ($osm -and $osm.FreePhysicalMemory) { $osm.FreePhysicalMemory / 1KB } else { 0 }
                $ramTotalGB = if ($cs -and $cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 0) } 
                              elseif ($totalMB -gt 0) { [math]::Round($totalMB / 1024, 0) } 
                              else { 0 }
                $usedGB = if ($totalMB -gt 0) { [math]::Round(($totalMB - $freeMB) / 1KB, 1) } else { 0 }
                $usedPct = if ($totalMB -gt 0) { [math]::Round((($totalMB - $freeMB) / $totalMB) * 100) } else { 0 }

                # Active Network Connections (non-blocking)
                $conns = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue).Count

                # Full System State & Privacy Score (Registry + Powercfg + Services in background)
                $sysState = Get-WinDebloatSystemState
                $ps = Get-WinDebloatPrivacyScore -State $sysState

                # OS version verification
                $verInfo = Get-WinDebloatVersionInfo

                # DirectStorage BypassIO Telemetry
                $storageHealth = try { Test-WinDebloatStorageHealth } catch { $null }
                $bypassStatus = if ($storageHealth -and $storageHealth.BypassIoSupported) { "BypassIO Ready" }
                                elseif ($storageHealth) { "NVMe Standard" }
                                else { "DirectStorage" }
                $bypassDetail = if ($storageHealth -and $storageHealth.TrimEnabled) { "TRIM Active · Low Latency" }
                                else { "Storage Subsystem OK" }

                return [pscustomobject]@{
                    Success        = $true
                    RamTotalGB     = $ramTotalGB
                    RamUsedGB      = $usedGB
                    RamUsedPct     = $usedPct
                    ConnsCount     = $conns
                    SysState       = $sysState
                    PrivacyScore   = $ps
                    VersionInfo    = $verInfo
                    BypassIoStatus = $bypassStatus
                    BypassIoDetail = $bypassDetail
                }
            }
            catch {
                return [pscustomobject]@{
                    Success = $false
                    Error   = $_.Exception.Message
                }
            }
        }

        $startLiveProbe = {
            if ($liveProbeState.IsRunning) { return }
            try {
                $rs = [runspacefactory]::CreateRunspace()
                $rs.Open()
                $ps = [powershell]::Create().AddScript($probeScriptBlock).AddArgument($corePath).AddArgument($modulesPath)
                $ps.Runspace = $rs

                $liveProbeState.PowerShell  = $ps
                $liveProbeState.Runspace    = $rs
                $liveProbeState.AsyncHandle = $ps.BeginInvoke()
                $liveProbeState.IsRunning   = $true
            }
            catch {
                Write-Verbose "Could not start async live probe: $($_.Exception.Message)"
                $liveProbeState.IsRunning = $false
            }
        }

        # Dispatcher Timer for non-blocking UI updates and periodic 5-second polling
        $probeTimer = [System.Windows.Threading.DispatcherTimer]::new()
        $probeTimer.Interval = [TimeSpan]::FromMilliseconds(250)
        $probeTimer.Add_Tick({
            if ($liveProbeState.IsRunning -and $liveProbeState.AsyncHandle -and $liveProbeState.AsyncHandle.IsCompleted) {
                try {
                    $results = $liveProbeState.PowerShell.EndInvoke($liveProbeState.AsyncHandle)
                    $liveProbeState.PowerShell.Dispose()
                    $liveProbeState.Runspace.Dispose()
                    $liveProbeState.PowerShell = $null
                    $liveProbeState.Runspace = $null
                    $liveProbeState.AsyncHandle = $null
                    $liveProbeState.IsRunning = $false
                    $liveProbeState.LastCompleted = Get-Date

                    $data = if ($results) { $results[-1] } else { $null }
                    if ($data -and $data.Success) {
                        if ($data.RamTotalGB -gt 0) {
                            $liveProbeState.TotalRamGB = $data.RamTotalGB
                        }
                        $totalRam = if ($liveProbeState.TotalRamGB -gt 0) { $liveProbeState.TotalRamGB } else { $data.RamTotalGB }

                        # Update RAM UI
                        (& $getCtrl "txtRAM").Text = "$($data.RamUsedPct)"
                        (& $getCtrl "txtRAMDetail").Text = "$($data.RamUsedGB) / $totalRam GB · $($data.ConnsCount) conns"
                        (& $getCtrl "txtRAM").Foreground =
                            if ($data.RamUsedPct -ge 85) { [System.Windows.Media.Brushes]::OrangeRed }
                            elseif ($data.RamUsedPct -ge 70) { [System.Windows.Media.Brushes]::Gold }
                            else { [System.Windows.Media.Brushes]::White }

                        # Update DirectStorage / BypassIO UI
                        if ($data.BypassIoStatus) {
                            $txtBypass = & $getCtrl "txtBypassIoStatus"
                            if ($txtBypass) { $txtBypass.Text = $data.BypassIoStatus }
                            $txtBypassDet = & $getCtrl "txtBypassIoDetail"
                            if ($txtBypassDet) { $txtBypassDet.Text = $data.BypassIoDetail }
                        }

                        # Update Privacy Score UI
                        $ps = $data.PrivacyScore
                        if ($ps) {
                            $scoreBrush =
                                if ($ps.Score -ge 75) { [System.Windows.Media.Brushes]::LimeGreen }
                                elseif ($ps.Score -ge 40) { [System.Windows.Media.Brushes]::Gold }
                                else { [System.Windows.Media.Brushes]::OrangeRed }

                            (& $getCtrl "txtPrivacyScore").Text = "$($ps.Score)"
                            (& $getCtrl "txtPrivacyScore").Foreground = $scoreBrush
                            (& $getCtrl "txtPrivacyGrade").Text = "$($ps.Grade) · $($ps.Rating)"
                            (& $getCtrl "txtPrivacyGrade").Foreground = $scoreBrush

                            $active = @($ps.Breakdown | Where-Object { $_.Active })
                            $tip = if ($active.Count -eq 0) { "Fully hardened - no active privacy risks." }
                            else { "Points lost (hover breakdown):`n" + (($active | ForEach-Object { "  - $($_.Name):  -$($_.Weight)" }) -join "`n") }
                            (& $getCtrl "txtPrivacyScore").ToolTip = $tip
                            (& $getCtrl "txtPrivacyGrade").ToolTip = $tip
                            (& $getCtrl "txtPrivacyLabel").ToolTip = $tip
                        }

                        # Update Status indicators
                        $sysState = $data.SysState
                        if ($sysState) {
                            (& $getCtrl "txtTelemetryStatus").Text = if ($sysState.Telemetry) { "Enabled" } else { "Disabled" }
                            (& $getCtrl "indicatorTelemetry").Fill = if ($sysState.Telemetry) { [System.Windows.Media.Brushes]::Orange } else { [System.Windows.Media.Brushes]::LimeGreen }
                            (& $getCtrl "txtCopilotStatus").Text = if ($sysState.Copilot) { "Enabled" } else { "Disabled" }
                            (& $getCtrl "indicatorCopilot").Fill = if ($sysState.Copilot) { [System.Windows.Media.Brushes]::Orange } else { [System.Windows.Media.Brushes]::LimeGreen }
                            (& $getCtrl "txtRecallStatus").Text = if ($sysState.Recall) { "Enabled" } else { "Disabled" }
                            (& $getCtrl "indicatorRecall").Fill = if ($sysState.Recall) { [System.Windows.Media.Brushes]::Orange } else { [System.Windows.Media.Brushes]::LimeGreen }

                            # Sync checkboxes on first completed run
                            if ($liveProbeState.FirstRun) {
                                $checkboxStateMap = @{
                                    chkDarkTheme        = $sysState.DarkTheme
                                    chkActivityHistory  = $sysState.ActivityHistory
                                    chkBackgroundApps   = $sysState.BackgroundApps
                                    chkClipboardHistory = $sysState.ClipboardHistory
                                    chkHibernate        = $sysState.Hibernate
                                    chkLocation         = $sysState.Location
                                    chkCopilot          = $sysState.Copilot
                                    chkRecall           = $sysState.Recall
                                    chkWindowsUpdate    = $sysState.WindowsUpdate
                                    chkTelemetry        = $sysState.Telemetry
                                    chkGamingNetwork    = $sysState.GamingNetwork
                                    chkGamingInput      = $sysState.GamingInput
                                    chkGamingMMCSS      = $sysState.GamingMMCSS
                                    chkVisualEffects    = $sysState.VisualEffects
                                    chkUltimatePlan     = $sysState.UltimatePlan
                                    chkDisableIPv6      = $sysState.IPv6Disabled
                                    chkDisableSMBv1     = $sysState.SMBv1Disabled
                                    chkDisableNetBIOS   = $sysState.NetBIOSDisabled
                                    chkLowLatencyTimers = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue).GlobalTimerResolutionRequests -eq 1
                                    chkUdpReceiveOffload = $true
                                    chkEnableECH        = $true
                                    chkEnterpriseSMB    = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue).RequireSecuritySignature -eq 1
                                }
                                foreach ($ctrlName in $checkboxStateMap.Keys) {
                                    $ctrl = & $getCtrl $ctrlName
                                    if ($ctrl) { $ctrl.IsChecked = [bool]$checkboxStateMap[$ctrlName] }
                                }
                                # Synchronize active power plan radio buttons
                                if ($sysState.PowerPlan -eq "Ultimate" -or $sysState.UltimatePlan) {
                                    $radUlt = & $getCtrl "radUltimate"
                                    if ($radUlt) { $radUlt.IsChecked = $true }
                                }
                                elseif ($sysState.PowerPlan -eq "HighPerformance") {
                                    $radHigh = & $getCtrl "radHighPerf"
                                    if ($radHigh) { $radHigh.IsChecked = $true }
                                }
                                else {
                                    $radBal = & $getCtrl "radBalanced"
                                    if ($radBal) { $radBal.IsChecked = $true }
                                }
                                $liveProbeState.FirstRun = $false
                            }
                        }

                        # Update verified OS details if available
                        if ($data.VersionInfo) {
                            $v = $data.VersionInfo
                            if ($v.FullName) { (& $getCtrl "txtOSName").Text = $v.FullName }
                            $ubr = if ($v.Ubr) { ".$($v.Ubr)" } else { "" }
                            if ($v.DisplayVersion -and $v.BuildNumber) {
                                (& $getCtrl "txtOSVersion").Text = "$($v.DisplayVersion) · Build $($v.BuildNumber)$ubr"
                            }
                        }
                    }
                }
                catch {
                    Write-Verbose "Error processing async live probe results: $($_.Exception.Message)"
                    $liveProbeState.IsRunning = $false
                }
            }
            elseif (-not $liveProbeState.IsRunning) {
                # Schedule next probe after 5s interval
                $elapsed = ((Get-Date) - $liveProbeState.LastCompleted).TotalSeconds
                if ($elapsed -ge 5 -or $liveProbeState.LastCompleted -eq [datetime]::MinValue) {
                    & $startLiveProbe
                }
            }
        })
        $probeTimer.Start()

        # Kick off initial probe immediately in background
        & $startLiveProbe

        # 3. Bloatware count - Async Implementation (Optimization)
        (& $getCtrl "txtBloatwareCount").Text = "..."

        $bloatwarePatterns = @(
            '*3DBuilder*', '*BingNews*', '*BingWeather*', '*Clipchamp*', '*Disney*',
            '*Duolingo*', '*Facebook*', '*Flipboard*', '*Spotify*', '*Twitter*',
            '*TikTok*', '*CandyCrush*', '*BubbleWitch*', '*MarchofEmpires*',
            '*Solitaire*', '*OfficeHub*', '*OneConnect*', '*People*', '*Skype*',
            '*Zune*', '*MixedReality*', '*Copilot*', '*LinkedIn*', '*Cortana*',
            '*FeedbackHub*', '*GetHelp*', '*Maps*', '*Messaging*', '*YourPhone*'
        )

        $bloatRs = [runspacefactory]::CreateRunspace()
        $bloatRs.Open()
        $bloatPsStr = {
            param($patterns)
            try {
                Import-Module Appx -ErrorAction SilentlyContinue
                $apps = @(Get-AppxPackage -AllUsers -ErrorAction Stop)
                $count = 0
                foreach ($p in $patterns) {
                    $count += $apps.PSWhere({ $_.Name -like $p }).Count
                }
                return $count
            }
            catch {
                return -1 # Error indicator
            }
        }
        $bloatPs = [powershell]::Create().AddScript($bloatPsStr).AddArgument($bloatwarePatterns)
        $bloatPs.Runspace = $bloatRs
        $bloatHandle = $bloatPs.BeginInvoke()

        # Non-blocking check for bloatware count completion using Dispatcher
        $bloatCheckTimer = [System.Windows.Threading.DispatcherTimer]::new()
        $bloatCheckTimer.Interval = [TimeSpan]::FromMilliseconds(150)
        $bloatCheckTimer.Add_Tick({
                if ($bloatHandle.IsCompleted) {
                    $bloatCheckTimer.Stop()
                    try {
                        $results = $bloatPs.EndInvoke($bloatHandle)
                        $bloatPs.Dispose()
                        $bloatRs.Dispose()

                        $finalCount = if ($results) { $results[-1] } else { 0 }
                        (& $getCtrl "txtBloatwareCount").Text = if ($finalCount -ge 0) { "$finalCount" } else { "?" }
                    }
                    catch {
                        (& $getCtrl "txtBloatwareCount").Text = "?"
                    }
                }
            })
        $bloatCheckTimer.Start()

        # Stop timers and cleanly dispose background resources on window close
        $window.Add_Closed({
            $probeTimer.Stop()
            $bloatCheckTimer.Stop()
            if ($liveProbeState.IsRunning) {
                try { $liveProbeState.PowerShell.Dispose() } catch { Write-Verbose "PowerShell dispose: $($_.Exception.Message)" }
                try { $liveProbeState.Runspace.Dispose() } catch { Write-Verbose "Runspace dispose: $($_.Exception.Message)" }
            }
        })

        # ═══════════════════════════════════════════════════════════════════════════════
        # ASYNC TASK RUNNER WITH FLUID 60 FPS DISPATCHER PUMP & PROGRESS ANIMATION
        # ═══════════════════════════════════════════════════════════════════════════════
        $script:ctsCurrentTask = $null
        $script:isTaskRunning = $false

        $runBackgroundTask = {
            param(
                [string]$TaskName,
                [scriptblock]$WorkBlock,
                [hashtable]$Variables = @{},
                [scriptblock]$OnCompleted = $null
            )

            if ($script:isTaskRunning) {
                [System.Windows.MessageBox]::Show(
                    "An optimization task is already in progress. Please wait for it to complete or click Cancel.",
                    "Task Busy",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $script:isTaskRunning = $true
            $txtStatus.Text = "$TaskName in progress..."
            
            $pbGlobal = $window.FindName("pbGlobal")
            if ($pbGlobal) {
                $pbGlobal.Visibility = 'Visible'
                $pbGlobal.IsIndeterminate = $true
            }

            $btnCancel = $window.FindName("btnCancelOperation")
            if ($btnCancel) {
                $btnCancel.Visibility = 'Visible'
            }

            $script:ctsCurrentTask = [System.Threading.CancellationTokenSource]::new()
            $cts = $script:ctsCurrentTask

            $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $runspace.ApartmentState = [System.Threading.ApartmentState]::STA
            $runspace.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
            $runspace.Open()

            $runspace.SessionStateProxy.SetVariable('PSScriptRoot', $scriptRoot)
            $runspace.SessionStateProxy.SetVariable('scriptRoot', $scriptRoot)
            if ($Variables) {
                foreach ($varKey in $Variables.Keys) {
                    $runspace.SessionStateProxy.SetVariable($varKey, $Variables[$varKey])
                }
            }

            $initScript = "
                Import-Module '$scriptRoot\..\..\core\Logger.psm1' -Force
                Import-Module '$scriptRoot\..\..\core\Config.psm1' -Force
                Import-Module '$scriptRoot\..\..\core\Registry.psm1' -Force
                Import-Module '$scriptRoot\..\..\core\SystemState.psm1' -Force
                Import-Module '$scriptRoot\..\..\core\State.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Bloatware\Bloatware.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Privacy\Privacy.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Privacy\Firewall.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Performance\Performance.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Performance\Gaming.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Tweaks\UI.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Tweaks\System.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Repair\Repair.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Software\Software.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Network\Network.psm1' -Force
                Import-Module '$scriptRoot\..\..\modules\Security\Security.psm1' -Force
            "
            $initPs = [powershell]::Create()
            $initPs.Runspace = $runspace
            [void]$initPs.AddScript($initScript)
            [void]$initPs.Invoke()
            $initPs.Dispose()

            $ps = [powershell]::Create()
            $ps.Runspace = $runspace
            [void]$ps.AddScript($WorkBlock)

            $asyncResult = $ps.BeginInvoke()

            $taskTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $taskTimer.Interval = [TimeSpan]::FromMilliseconds(33)

            $taskTimer.Add_Tick({
                if ($cts.IsCancellationRequested) {
                    $taskTimer.Stop()
                    $txtStatus.Text = "$TaskName cancelled."
                    try {
                        Get-CimInstance Win32_Process -Filter "ParentProcessId = $PID" -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -match '^(winget|dism|sfc|chkdsk|msiexec|powershell|pwsh)\.exe$' } |
                            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                    } catch { $null = $_ }
                    try { $ps.Stop() } catch { $null = $_ }
                    try { $ps.Dispose() } catch { $null = $_ }
                    try { $runspace.Dispose() } catch { $null = $_ }
                    $script:isTaskRunning = $false
                    if ($pbGlobal) { $pbGlobal.Visibility = 'Collapsed'; $pbGlobal.IsIndeterminate = $false }
                    if ($btnCancel) { $btnCancel.Visibility = 'Collapsed' }
                    return
                }

                if ($asyncResult.IsCompleted) {
                    $taskTimer.Stop()
                    try {
                        $output = $ps.EndInvoke($asyncResult)
                        $txtStatus.Text = "$TaskName Complete!"
                        if ($OnCompleted) {
                            & $OnCompleted $output
                        }
                    }
                    catch {
                        $txtStatus.Text = "Error in $TaskName`: $($_.Exception.Message)"
                    }
                    finally {
                        try { $ps.Dispose() } catch { $null = $_ }
                        try { $runspace.Dispose() } catch { $null = $_ }
                        $script:isTaskRunning = $false
                        if ($pbGlobal) { $pbGlobal.Visibility = 'Collapsed'; $pbGlobal.IsIndeterminate = $false }
                        if ($btnCancel) { $btnCancel.Visibility = 'Collapsed' }
                    }
                }
            })

            $taskTimer.Start()
        }

        # Wire global cancel button
        $btnCancel = $window.FindName("btnCancelOperation")
        if ($btnCancel) {
            $btnCancel.Add_Click({
                if ($script:ctsCurrentTask -and -not $script:ctsCurrentTask.IsCancellationRequested) {
                    $script:ctsCurrentTask.Cancel()
                    $txtStatus.Text = "Cancelling task..."
                }
            })
        }

        # Helper: Render In-Window Modal Visual Diff Plan
        $showModalDiff = {
            param([string]$ProfileName = "Moderate", [string]$ProfileFile = "moderate.yaml")
            try {
                $profilePath = Join-Path $scriptRoot "..\..\..\profiles\$ProfileFile"
                if (-not (Test-Path $profilePath)) {
                    $txtStatus.Text = "Error: $ProfileFile profile not found."
                    return
                }
                $config = Import-WinDebloatConfig -Path $profilePath -SkipDependencyCheck
                $plan = Get-WinDebloatProfilePlan -Config $config

                $doc = [System.Windows.Documents.FlowDocument]::new()
                $doc.ColumnWidth = [double]::PositiveInfinity
                $doc.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x0B, 0x11, 0x20))
                $doc.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xF8, 0xFA, 0xFC))
                $doc.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code, Segoe UI")
                $doc.FontSize = 13.0
                $doc.PagePadding = [System.Windows.Thickness]::new(16)

                # Title paragraph
                $pHeader = [System.Windows.Documents.Paragraph]::new()
                $pHeader.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
                $rTitle = [System.Windows.Documents.Run]::new("Target Profile: $ProfileName (Dry-Run Action Plan)`n")
                $rTitle.FontWeight = [System.Windows.FontWeights]::Bold
                $rTitle.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x38, 0xBD, 0xF8))
                [void]$pHeader.Inlines.Add($rTitle)
                [void]$doc.Blocks.Add($pHeader)

                # Groups
                foreach ($grp in ($plan | Group-Object Section)) {
                    $pSec = [System.Windows.Documents.Paragraph]::new()
                    $pSec.Margin = [System.Windows.Thickness]::new(0, 8, 0, 4)
                    
                    $rSec = [System.Windows.Documents.Run]::new("[$($grp.Name.ToUpper())]`n")
                    $rSec.FontWeight = [System.Windows.FontWeights]::Bold
                    $rSec.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x38, 0xBD, 0xF8))
                    [void]$pSec.Inlines.Add($rSec)

                    foreach ($item in $grp.Group) {
                        $actionText = $item.Action
                        $prefix = "  [~] "
                        $color = [System.Windows.Media.Color]::FromRgb(0xF5, 0x9E, 0x0B) # Amber

                        if ($actionText -match '(?i)(remove|disable|uninstall|purge|block)') {
                            $prefix = "  [-] "
                            $color = [System.Windows.Media.Color]::FromRgb(0xEF, 0x44, 0x44) # Red
                        }
                        elseif ($actionText -match '(?i)(enable|install|add|create|protect|enforce|restore)') {
                            $prefix = "  [+] "
                            $color = [System.Windows.Media.Color]::FromRgb(0x22, 0xC5, 0x5E) # Green
                        }

                        $rItem = [System.Windows.Documents.Run]::new("$prefix$actionText`n")
                        $rItem.Foreground = [System.Windows.Media.SolidColorBrush]::new($color)
                        [void]$pSec.Inlines.Add($rItem)
                    }

                    [void]$doc.Blocks.Add($pSec)
                }

                # Safety footer
                $pSafety = [System.Windows.Documents.Paragraph]::new()
                $pSafety.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)
                $rSafetyTitle = [System.Windows.Documents.Run]::new("SAFETY & RECOVERY LAYERS:`n")
                $rSafetyTitle.FontWeight = [System.Windows.FontWeights]::Bold
                $rSafetyTitle.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x22, 0xC5, 0x5E))
                [void]$pSafety.Inlines.Add($rSafetyTitle)

                $rSafety1 = [System.Windows.Documents.Run]::new("  • Layer 1: Windows System Restore point (VSS checkpoint with 24-hr bypass)`n  • Layer 2: Cryptographic DPAPI snapshot (snapshot.clixml)`n  • Layer 3: Standalone emergency rollback.reg & rollback.cmd script`n")
                $rSafety1.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x94, 0xA3, 0xB8))
                [void]$pSafety.Inlines.Add($rSafety1)
                [void]$doc.Blocks.Add($pSafety)

                $fdsv = $window.FindName("fdsvDiffContent")
                if ($fdsv) {
                    $fdsv.Document = $doc
                }

                $overlay = $window.FindName("modalDiffOverlay")
                if ($overlay) {
                    $overlay.Visibility = 'Visible'
                }
            }
            catch {
                $txtStatus.Text = "Error generating diff: $($_.Exception.Message)"
            }
        }

        # Wire Modal Diff Close and Apply Buttons
        $overlay = $window.FindName("modalDiffOverlay")
        $btnCloseDiffTop = $window.FindName("btnCloseDiffTop")
        if ($btnCloseDiffTop -and $overlay) {
            $btnCloseDiffTop.Add_Click({ $overlay.Visibility = 'Collapsed' })
        }
        $btnCloseDiff = $window.FindName("btnCloseDiff")
        if ($btnCloseDiff -and $overlay) {
            $btnCloseDiff.Add_Click({ $overlay.Visibility = 'Collapsed' })
        }
        $btnApplyDiff = $window.FindName("btnApplyDiff")
        if ($btnApplyDiff -and $overlay) {
            $btnApplyDiff.Add_Click({
                $overlay.Visibility = 'Collapsed'
                $btnQuick = & $getCtrl "btnQuickOptimize"
                if ($btnQuick) {
                    $btnQuick.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                }
            })
        }

        # Wire global Escape key to dismiss modal diff overlay
        $window.Add_KeyDown({
            param($sender, $e)
            if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
                if ($overlay -and $overlay.Visibility -eq 'Visible') {
                    $overlay.Visibility = 'Collapsed'
                    $e.Handled = $true
                }
            }
        })

        # Wire Visual Diff Preview button
        $btnPreview = $window.FindName("btnPreviewDiff")
        if ($btnPreview) {
            $btnPreview.Add_Click({
                & $showModalDiff -ProfileName "Moderate" -ProfileFile "moderate.yaml"
            })
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # DASHBOARD BUTTONS
        # ═══════════════════════════════════════════════════════════════════════════════
        (& $getCtrl "btnQuickOptimize").Add_Click({
                try {
                    $profilePath = Join-Path $scriptRoot "..\..\..\profiles\moderate.yaml"
                    if (-not (Test-Path $profilePath)) {
                        $txtStatus.Text = "Error: moderate.yaml profile not found."
                        return
                    }
                    $config = Import-WinDebloatConfig -Path $profilePath -SkipDependencyCheck

                    $plan = Get-WinDebloatProfilePlan -Config $config
                    $planText = ($plan | Group-Object Section | ForEach-Object {
                            "$($_.Name):`n" + (($_.Group | ForEach-Object { "  - $($_.Action)" }) -join "`n")
                        }) -join "`n`n"
                    $answer = [System.Windows.MessageBox]::Show(
                        "Quick Optimize will apply the 'Moderate' profile:`n`n$planText`n`nProceed?",
                        "Preview - Quick Optimize",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Question)
                    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
                        $txtStatus.Text = "Quick Optimize cancelled - nothing was changed."
                        return
                    }

                    & $runBackgroundTask -TaskName "Quick Optimize" -WorkBlock {
                        $config = Import-WinDebloatConfig -Path $profilePath -SkipDependencyCheck
                        New-WinDebloatSnapshot -Name "Auto-QuickOptimize" -Description "Created before Quick Optimize" -Encrypt | Out-Null
                        Remove-WinDebloatBloatware -Config $config -Confirm:$false
                        Set-WinDebloatPrivacy -Config $config -Confirm:$false
                        Set-WinDebloatPerformance -Config $config -Confirm:$false
                        Set-WinDebloatSystemTweaks -Config $config -Confirm:$false
                    } -Variables @{ profilePath = $profilePath }
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
            })

        (& $getCtrl "btnRemoveBloatware").Add_Click({
                & $runBackgroundTask "Bloatware Removal" {
                    $config = [pscustomobject]@{ bloatware = @{ removal_mode = "Moderate" } }
                    Remove-WinDebloatBloatware -Config $config -Confirm:$false
                }
            })

        (& $getCtrl "btnInstallEssentials").Add_Click({
                (& $getCtrl "navSoftware").IsChecked = $true
            })

        # ═══════════════════════════════════════════════════════════════════════════════
        # TWEAKS BUTTONS - GENERAL & PRIVACY
        # ═══════════════════════════════════════════════════════════════════════════════
        (& $getCtrl "btnApplyTweaks").Add_Click({
                $txtStatus.Text = "Applying System Tweaks..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    # 1. Dark Theme
                    $useDark = (& $getCtrl "chkDarkTheme").IsChecked
                    $themeVal = if ($useDark) { 0 } else { 1 }
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value $themeVal -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value $themeVal -Force -ErrorAction SilentlyContinue

                    # 2. Hibernate
                    if ((& $getCtrl "chkHibernate").IsChecked) { Start-Process -FilePath "powercfg.exe" -ArgumentList "/h", "on" -Wait -NoNewWindow } else { Start-Process -FilePath "powercfg.exe" -ArgumentList "/h", "off" -Wait -NoNewWindow }

                    # 3. Clipboard History
                    $clipVal = if ((& $getCtrl "chkClipboardHistory").IsChecked) { 1 } else { 0 }
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Clipboard" -Name "EnableClipboardHistory" -Value $clipVal -Force -ErrorAction SilentlyContinue

                    # 4. Activity History, Location & Telemetry (Privacy Module)
                    $disableActivity = -not (& $getCtrl "chkActivityHistory").IsChecked
                    $disableLocation = -not (& $getCtrl "chkLocation").IsChecked
                    $disableCopilot = -not (& $getCtrl "chkCopilot").IsChecked
                    $disableRecall = -not (& $getCtrl "chkRecall").IsChecked
                    # Unchecked telemetry toggle = restrict to Security level; checked = leave as-is
                    $telemetryLevel = if ((& $getCtrl "chkTelemetry").IsChecked) { $null } else { "Security" }

                    $config = [pscustomobject]@{
                        privacy = [pscustomobject]@{
                            telemetry_level           = $telemetryLevel
                            disable_activity_history  = $disableActivity
                            disable_location_tracking = $disableLocation
                            disable_copilot           = $disableCopilot
                            disable_recall            = $disableRecall
                        }
                    }
                    Set-WinDebloatPrivacy -Config $config -Confirm:$false

                    # 5. Background Apps (Performance Module)
                    if ((& $getCtrl "chkBackgroundApps").IsChecked) {
                        # Checked = Enabled (Allow Background Apps)
                        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 0 -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Force -ErrorAction SilentlyContinue
                    }

                    # 6. Automatic Updates
                    if ((& $getCtrl "chkWindowsUpdate").IsChecked) {
                        # Enabled
                        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        # Disabled
                        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
                            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
                        }
                        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    }

                    # 7. Taskbar Grouping (Never Combine)
                    $chkGlom = & $getCtrl "chkTaskbarGlom"
                    if ($chkGlom -and $chkGlom.IsChecked) {
                        Set-WinDebloatTaskbarGrouping -GlomLevel Never
                    }
                    elseif ($chkGlom) {
                        Set-WinDebloatTaskbarGrouping -GlomLevel Always
                    }

                    # 8. Copilot Hardware Key Remap (26H2)
                    $cmbCopilot = & $getCtrl "cmbCopilotKeyRemap"
                    if ($cmbCopilot) {
                        switch ($cmbCopilot.SelectedIndex) {
                            0 { Enable-WinDebloatCopilotKey }
                            1 { Set-WinDebloatCopilotKeyRemap }
                            2 { Set-WinDebloatCopilotKeyRemap -CustomAppPath "shell:::{3080F90E-D7AD-11D9-BD98-0000947B0257}" }
                            3 { Disable-WinDebloatCopilotKey }
                        }
                    }

                    $txtStatus.Text = "General Tweaks Applied!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            })

        # ═══════════════════════════════════════════════════════════════════════════════
        # PERFORMANCE BUTTONS
        # ═══════════════════════════════════════════════════════════════════════════════
        $btnApplyPerf = $window.FindName("btnApplyPerformance")
        if ($btnApplyPerf) {
            $btnApplyPerf.Add_Click({
                    $txtStatus.Text = "Applying Performance Settings..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        # Power Plan
                        $radHigh = & $getCtrl "radHighPerf"
                        $radUlt = & $getCtrl "radUltimate"
                        if ($radHigh -and $radHigh.IsChecked) {
                            Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Wait -NoNewWindow
                            Write-Log -Message "Set power plan to High Performance" -Level Info
                        }
                        elseif ($radUlt -and $radUlt.IsChecked) {
                            Enable-WinDebloatUltimatePower
                        }
                        else {
                            Start-Process -FilePath "powercfg.exe" -ArgumentList "-SetActive", "381b4222-f694-41f0-9685-ff5bb260df2e" -Wait -NoNewWindow
                            Write-Log -Message "Set power plan to Balanced" -Level Info
                        }

                        # Gaming Network Tweaks (TCPNoDelay across all active interfaces)
                        if ((& $getCtrl "chkGamingNetwork").IsChecked) {
                            Set-WinDebloatGaming -EnableNetworkOptimization -Confirm:$false
                        }

                        # Mouse Input (Disable Acceleration)
                        if ((& $getCtrl "chkGamingInput").IsChecked) {
                            Set-WinDebloatGaming -EnableInputOptimization -Confirm:$false
                        }

                        # Multimedia Class Scheduler (MMCSS Gaming Priority)
                        if ((& $getCtrl "chkGamingMMCSS").IsChecked) {
                            Set-WinDebloatGaming -EnableMultimediaOptimization -Confirm:$false
                        }

                        # Visual Effects & Responsiveness
                        $chkVisual = & $getCtrl "chkVisualEffects"
                        if ($chkVisual -and $chkVisual.IsChecked) {
                            Set-RegistryKey -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type String | Out-Null
                            Set-RegistryKey -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String | Out-Null
                            Set-RegistryKey -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Value "10" -Type String | Out-Null
                            Set-RegistryKey -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "5000" -Type String | Out-Null
                            Write-Log -Message "Visual effects and animations optimized" -Level Success
                        }

                        # Unlock Ultimate Plan checkbox (if not already activated via radio button)
                        if ((& $getCtrl "chkUltimatePlan").IsChecked -and -not ($radUlt -and $radUlt.IsChecked)) {
                            Enable-WinDebloatUltimatePower
                        }

                        # Low-Latency Kernel Timers (0.5ms resolution)
                        $chkTimers = & $getCtrl "chkLowLatencyTimers"
                        if ($chkTimers -and $chkTimers.IsChecked) {
                            Enable-WinDebloatLowLatencyTimers
                        }
                        elseif ($chkTimers) {
                            Disable-WinDebloatLowLatencyTimers
                        }

                        # UDP Receive Offload (URO - 26H2)
                        $chkUro = & $getCtrl "chkUdpReceiveOffload"
                        if ($chkUro -and $chkUro.IsChecked) {
                            Enable-WinDebloatURO
                        }
                        elseif ($chkUro) {
                            Disable-WinDebloatURO
                        }

                        # Dev Drive ReFS Storage Cache
                        $chkDev = & $getCtrl "chkDevDriveOpt"
                        if ($chkDev -and $chkDev.IsChecked) {
                            Optimize-WinDebloatDevDrive
                        }

                        $txtStatus.Text = "Performance Optimized!"
                    }
                    catch {
                        $txtStatus.Text = "Performance Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # Service Optimizer preset (config/services.json)
        $btnApplyServices = $window.FindName("btnApplyServices")
        if ($btnApplyServices) {
            $btnApplyServices.Add_Click({
                    $presetItem = ($window.FindName("cmbServicePreset")).SelectedItem
                    if (-not $presetItem) {
                        $txtStatus.Text = "Select a service preset first."
                        return
                    }
                    $preset = [string]$presetItem.Content

                    $txtStatus.Text = "Applying '$preset' service preset..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        Set-WinDebloatServices -Preset $preset -Confirm:$false
                        $txtStatus.Text = "'$preset' service preset applied!"
                    }
                    catch {
                        $txtStatus.Text = "Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # PRIVACY BUTTONS
        # ═══════════════════════════════════════════════════════════════════════════════
        (& $getCtrl "btnBlockTelemetry").Add_Click({
                $txtStatus.Text = "Blocking Telemetry..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    Add-WinDebloatFirewallBlock -Confirm:$false
                    $txtStatus.Text = "Telemetry Blocked!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            })

        # System QoL tab — apply checked tweaks
        $btnApplyQoL = $window.FindName("btnApplyQoL")
        if ($btnApplyQoL) {
            $btnApplyQoL.Add_Click({
                    $txtStatus.Text = "Applying System QoL tweaks..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    $applied = 0
                    try {
                        if ((& $getCtrl "chkQolFastStartup").IsChecked) { Disable-WinDebloatFastStartup -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolBitlocker").IsChecked) { Disable-WinDebloatAutoBitLocker -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolDeliveryOpt").IsChecked) { Disable-WinDebloatDeliveryOptimization -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolStorageSense").IsChecked) { Disable-WinDebloatStorageSense -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolNoAutoReboot").IsChecked) { Set-WinDebloatUpdateBehavior -NoAutoReboot -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolNoEarlyUpdates").IsChecked) { Set-WinDebloatUpdateBehavior -NoEarlyUpdates -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolModernStandby").IsChecked) { Disable-WinDebloatModernStandbyNetworking -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolFindMyDevice").IsChecked) { Disable-WinDebloatFindMyDevice -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolStickyKeys").IsChecked) { Disable-WinDebloatStickyKeysShortcut -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolWidgets").IsChecked) { Disable-WinDebloatWidgets -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolChat").IsChecked) { Disable-WinDebloatChatTaskbar -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolTransparency").IsChecked) { Disable-WinDebloatTransparency -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolSnapAssist").IsChecked) { Disable-WinDebloatSnapAssist -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolStartAllApps").IsChecked) { Disable-WinDebloatStartAllApps -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolFileExt").IsChecked) { Set-WinDebloatExplorer -ShowFileExtensions -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolHiddenFiles").IsChecked) { Set-WinDebloatExplorer -ShowHiddenFiles -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolHideOneDrive").IsChecked) { Set-WinDebloatExplorer -HideOneDrive -Confirm:$false; $applied++ }
                        if ((& $getCtrl "chkQolContextClean").IsChecked) { Set-WinDebloatContextMenuItems -HideShare -HideGiveAccessTo -HideIncludeInLibrary -Confirm:$false; $applied++ }

                        $txtStatus.Text = if ($applied -gt 0) { "$applied System QoL tweak(s) applied! Restart Explorer to see UI changes." } else { "No QoL tweaks selected." }
                    }
                    catch {
                        $txtStatus.Text = "Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # System QoL tab — revert checked tweaks back to Windows defaults
        $btnRevertQoL = $window.FindName("btnRevertQoL")
        if ($btnRevertQoL) {
            $btnRevertQoL.Add_Click({
                    $txtStatus.Text = "Reverting System QoL tweaks..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    $reverted = 0
                    try {
                        if ((& $getCtrl "chkQolFastStartup").IsChecked) { Enable-WinDebloatFastStartup -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolBitlocker").IsChecked) { Enable-WinDebloatAutoBitLocker -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolDeliveryOpt").IsChecked) { Enable-WinDebloatDeliveryOptimization -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolStorageSense").IsChecked) { Enable-WinDebloatStorageSense -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolNoAutoReboot").IsChecked) { Set-WinDebloatUpdateBehavior -AllowAutoReboot -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolNoEarlyUpdates").IsChecked) { Set-WinDebloatUpdateBehavior -AllowEarlyUpdates -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolModernStandby").IsChecked) { Enable-WinDebloatModernStandbyNetworking -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolFindMyDevice").IsChecked) { Enable-WinDebloatFindMyDevice -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolStickyKeys").IsChecked) { Enable-WinDebloatStickyKeysShortcut -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolWidgets").IsChecked) { Enable-WinDebloatWidgets -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolChat").IsChecked) { Enable-WinDebloatChatTaskbar -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolTransparency").IsChecked) { Enable-WinDebloatTransparency -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolSnapAssist").IsChecked) { Enable-WinDebloatSnapAssist -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolStartAllApps").IsChecked) { Enable-WinDebloatStartAllApps -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolFileExt").IsChecked) { Set-WinDebloatExplorer -HideFileExtensions -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolHiddenFiles").IsChecked) { Set-WinDebloatExplorer -HideHiddenFiles -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolHideOneDrive").IsChecked) { Set-WinDebloatExplorer -ShowOneDrive -Confirm:$false; $reverted++ }
                        if ((& $getCtrl "chkQolContextClean").IsChecked) {
                            $txtStatus.Text = "Context-menu handlers must be restored from a snapshot (Snapshots view)."
                        }

                        if ($reverted -gt 0) { $txtStatus.Text = "$reverted System QoL tweak(s) reverted to Windows defaults! Restart Explorer to see UI changes." }
                        elseif (-not (& $getCtrl "chkQolContextClean").IsChecked) { $txtStatus.Text = "No QoL tweaks selected to revert." }
                    }
                    catch {
                        $txtStatus.Text = "Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        (& $getCtrl "btnDebloatSearch").Add_Click({
                $txtStatus.Text = "Debloating Windows Search..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    Set-WinDebloatSearch -DisableBingSearch -DisableSearchHighlights -DisableSearchHistory -Confirm:$false
                    $txtStatus.Text = "Search debloated (Bing results, highlights, and history disabled)!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            })

        (& $getCtrl "btnDisableSuggestions").Add_Click({
                $txtStatus.Text = "Disabling Windows suggestions and ads..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    Disable-WinDebloatWindowsSuggestions -Confirm:$false
                    Disable-WinDebloatSettingsHome -Confirm:$false
                    $txtStatus.Text = "Suggestions and ad surfaces disabled!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            })

        # Restore Search & Suggestions to Windows defaults
        $btnRestoreSearchSuggestions = $window.FindName("btnRestoreSearchSuggestions")
        if ($btnRestoreSearchSuggestions) {
            $btnRestoreSearchSuggestions.Add_Click({
                    $txtStatus.Text = "Restoring Search & Suggestions defaults..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        Set-WinDebloatSearch -EnableBingSearch -EnableSearchHighlights -EnableSearchHistory -Confirm:$false
                        Enable-WinDebloatWindowsSuggestions -Confirm:$false
                        Enable-WinDebloatSettingsHome -Confirm:$false
                        $txtStatus.Text = "Search and suggestion surfaces restored to Windows defaults!"
                    }
                    catch {
                        $txtStatus.Text = "Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        (& $getCtrl "btnDisableTasks").Add_Click({
                $txtStatus.Text = "Disabling Tasks (Safe)..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    Disable-WinDebloatTelemetryTasks -Mode Safe -Confirm:$false
                    $txtStatus.Text = "Safe Tasks Disabled!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            })

        (& $getCtrl "btnAggressiveTasks").Add_Click({
                $txtStatus.Text = "Disabling Tasks (Aggressive)..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    Disable-WinDebloatTelemetryTasks -Mode Aggressive -Confirm:$false
                    $txtStatus.Text = "Aggressive Tasks Disabled!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
                finally {
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                }
            })

        # ═══════════════════════════════════════════════════════════════════════════════
        # SOFTWARE TAB
        # ═══════════════════════════════════════════════════════════════════════════════
        try {
            $icSoftware = & $getCtrl "icSoftwareCategories"
            $catalog = Get-WinDebloatAppCatalog
            $categoriesList = [System.Collections.Generic.List[WinDebloatSoftwareCategoryItem]]::new()

            if ($catalog -and $catalog.categories) {
                foreach ($cat in $catalog.categories) {
                    $catItem = [WinDebloatSoftwareCategoryItem]::new()
                    $catItem.CategoryName = [string]$cat.name
                    $catItem.Apps = [System.Collections.Generic.List[WinDebloatSoftwareAppItem]]::new()

                    foreach ($app in $cat.apps) {
                        $appItem = [WinDebloatSoftwareAppItem]::new()
                        $appItem.Name        = [string]$app.name
                        $appItem.PackageId   = [string]$app.winget
                        $appItem.ChocoId     = [string]$app.choco
                        $appItem.MsstoreId   = ""
                        $appItem.NpmId       = ""
                        $appItem.Recommended = [bool]$app.recommended
                        $appItem.Description = [string]$app.description
                        $appItem.IsSelected  = [bool]$app.recommended
                        $catItem.Apps.Add($appItem)
                    }
                    $categoriesList.Add($catItem)
                }
            }
            else {
                $essentials = Get-WinDebloatEssentialsList
                foreach ($catKey in ($essentials.Keys | Sort-Object)) {
                    $catItem = [WinDebloatSoftwareCategoryItem]::new()
                    $catItem.CategoryName = [string]$essentials[$catKey].DisplayName
                    $catItem.Apps = [System.Collections.Generic.List[WinDebloatSoftwareAppItem]]::new()

                    foreach ($appDef in $essentials[$catKey].Apps) {
                        $appItem = [WinDebloatSoftwareAppItem]::new()
                        $appItem.Name        = [string]$appDef.Name
                        $appItem.PackageId   = [string]$appDef.Winget
                        $appItem.ChocoId     = [string]$appDef.Choco
                        $appItem.MsstoreId   = [string]$appDef.Msstore
                        $appItem.NpmId       = [string]$appDef.Npm
                        $appItem.Recommended = $false
                        $appItem.Description = ""
                        $appItem.IsSelected  = $false
                        $catItem.Apps.Add($appItem)
                    }
                    $categoriesList.Add($catItem)
                }
            }
            $icSoftware.ItemsSource = $categoriesList
        }
        catch {
            Write-Warning "Software list failed to load: $($_.Exception.Message)"
        }

        # Live search filter
        $txtSearch = $window.FindName("txtSoftwareSearch")
        if ($txtSearch) {
            $txtSearch.Add_TextChanged({
                    $filter = $txtSearch.Text
                    if ([string]::IsNullOrWhiteSpace($filter)) {
                        $icSoftware.ItemsSource = $categoriesList
                        return
                    }
                    $filtered = [System.Collections.Generic.List[WinDebloatSoftwareCategoryItem]]::new()
                    foreach ($cat in $categoriesList) {
                        $matchingApps = [System.Collections.Generic.List[WinDebloatSoftwareAppItem]]::new()
                        foreach ($app in $cat.Apps) {
                            if ($app.Name -like "*$filter*" -or $app.PackageId -like "*$filter*") {
                                $matchingApps.Add($app)
                            }
                        }
                        if ($matchingApps.Count -gt 0) {
                            $catMatch = [WinDebloatSoftwareCategoryItem]::new()
                            $catMatch.CategoryName = $cat.CategoryName
                            $catMatch.Apps = $matchingApps
                            $filtered.Add($catMatch)
                        }
                    }
                    $icSoftware.ItemsSource = $filtered
                })
        }

        # Select/Deselect All
        $btnSelectAll = $window.FindName("btnSelectAllApps")
        if ($btnSelectAll) {
            $btnSelectAll.Add_Click({
                    $currentView = $icSoftware.ItemsSource
                    foreach ($cat in $currentView) {
                        foreach ($app in $cat.Apps) { $app.IsSelected = $true }
                    }
                    $icSoftware.ItemsSource = $null
                    $icSoftware.ItemsSource = $currentView
                })
        }

        $btnDeselectAll = $window.FindName("btnDeselectAllApps")
        if ($btnDeselectAll) {
            $btnDeselectAll.Add_Click({
                    $currentView = $icSoftware.ItemsSource
                    foreach ($cat in $currentView) {
                        foreach ($app in $cat.Apps) { $app.IsSelected = $false }
                    }
                    $icSoftware.ItemsSource = $null
                    $icSoftware.ItemsSource = $currentView
                })
        }

        (& $getCtrl "btnInstallSoftware").Add_Click({
                $selectedApps = @()
                foreach ($cat in $categoriesList) {
                    foreach ($app in $cat.Apps) {
                        if ($app.IsSelected) {
                            $selectedApps += @{ Name = $app.Name; Winget = $app.PackageId; Choco = $app.ChocoId; Msstore = $app.MsstoreId; Npm = $app.NpmId }
                        }
                    }
                }

                if ($selectedApps.Count -eq 0) {
                    $txtStatus.Text = "No apps selected."
                    return
                }

                $count = $selectedApps.Count
                & $runBackgroundTask -TaskName "Install Software ($count packages)" -WorkBlock {
                    Install-WinDebloatSoftware -Apps $appsToInstall -Quiet
                } -Variables @{ appsToInstall = $selectedApps }
            })

        # ═══════════════════════════════════════════════════════════════════════════════
        # NETWORK TAB (viewNetwork)
        # ═══════════════════════════════════════════════════════════════════════════════
        $btnApplyDNS = $window.FindName("btnApplyDNS")
        if ($btnApplyDNS) {
            $btnApplyDNS.Add_Click({
                    $cmbDns = $window.FindName("cmbDnsProvider")
                    $provider = switch ($cmbDns.SelectedIndex) {
                        0 { "Reset" }
                        1 { "Cloudflare" }
                        2 { "Cloudflare_Malware" }
                        3 { "Cloudflare_Family" }
                        4 { "Google" }
                        5 { "Quad9" }
                        6 { "AdGuard" }
                        7 { "AdGuard_Family" }
                        8 { "OpenDNS" }
                        9 { "CleanBrowsing_Security" }
                        10 { "CleanBrowsing_Family" }
                        11 { "NextDNS" }
                        default { "Reset" }
                    }

                    $txtStatus.Text = "Applying DNS settings: $provider..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        $enableDoH = [bool](& $getCtrl "chkEnableDoH").IsChecked
                        $includeIPv6 = [bool](& $getCtrl "chkIncludeIPv6DNS").IsChecked

                        if ($provider -eq "Reset") {
                            Set-WinDebloatDNS -Provider "Reset"
                        }
                        else {
                            Set-WinDebloatDNS -Provider $provider -EnableDoH:$enableDoH -IncludeIPv6:$includeIPv6
                        }

                        $chkIPv6 = $window.FindName("chkDisableIPv6")
                        if ($chkIPv6 -and $chkIPv6.IsChecked) {
                            Disable-WinDebloatIPv6 -Confirm:$false
                        }
                        else {
                            Enable-WinDebloatIPv6 -Confirm:$false
                        }

                        # Encrypted Client Hello (ECH - 26H2 Anti-SNI Leak)
                        $chkEch = $window.FindName("chkEnableECH")
                        if ($chkEch -and $chkEch.IsChecked) {
                            Enable-WinDebloatECH
                        }
                        elseif ($chkEch) {
                            Disable-WinDebloatECH
                        }

                        $txtStatus.Text = "DNS and protocol settings applied successfully!"
                    }
                    catch {
                        $txtStatus.Text = "DNS Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # Network Security & Protocol Hardening (SMBv1, NetBIOS, Enterprise SMB)
        $btnApplyNetSec = $window.FindName("btnApplyNetSecurity")
        if ($btnApplyNetSec) {
            $btnApplyNetSec.Add_Click({
                    $txtStatus.Text = "Applying network security hardening..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        # 1. SMBv1 Protocol
                        $chkSMB = $window.FindName("chkDisableSMBv1")
                        if ($chkSMB -and $chkSMB.IsChecked) {
                            Disable-WinDebloatSMBv1 -Confirm:$false
                        }
                        else {
                            Enable-WinDebloatSMBv1 -Confirm:$false
                        }

                        # 2. NetBIOS over TCP/IP
                        $chkNetBT = $window.FindName("chkDisableNetBIOS")
                        if ($chkNetBT -and $chkNetBT.IsChecked) {
                            Disable-WinDebloatNetBIOS -Confirm:$false
                        }
                        else {
                            Enable-WinDebloatNetBIOS -Confirm:$false
                        }

                        # 3. Enterprise SMB Hardening Suite (Signing, NTLM Blocking, Client Security)
                        $chkEntSMB = $window.FindName("chkEnterpriseSMB")
                        if ($chkEntSMB -and $chkEntSMB.IsChecked) {
                            Disable-WinDebloatSMBv1
                            Enable-WinDebloatSMBSigning
                            Enable-WinDebloatSMBNTLMBlock
                            Enable-WinDebloatSMBClientHardening
                        }
                        elseif ($chkEntSMB) {
                            Disable-WinDebloatSMBSigning
                            Disable-WinDebloatSMBNTLMBlock
                            Disable-WinDebloatSMBClientHardening
                        }

                        $txtStatus.Text = "Network security hardening applied!"
                    }
                    catch {
                        $txtStatus.Text = "Security Hardening Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # Telemetry Firewall Block (Network Tab Quick Action)
        $btnBlockNet = $window.FindName("btnBlockTelemetryNet")
        if ($btnBlockNet) {
            $btnBlockNet.Add_Click({
                    $txtStatus.Text = "Blocking telemetry domains via Firewall..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        Add-WinDebloatFirewallBlock -Confirm:$false
                        $txtStatus.Text = "Telemetry domains blocked via Windows Firewall!"
                    }
                    catch {
                        $txtStatus.Text = "Firewall Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # Remove Telemetry Firewall Block (Network Tab Quick Action)
        $btnRestoreNet = $window.FindName("btnRestoreFirewallNet")
        if ($btnRestoreNet) {
            $btnRestoreNet.Add_Click({
                    $txtStatus.Text = "Removing telemetry firewall blocks..."
                    & $updateGui
                    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                    try {
                        Remove-WinDebloatFirewallBlock -Confirm:$false
                        $txtStatus.Text = "Telemetry firewall blocks removed successfully!"
                    }
                    catch {
                        $txtStatus.Text = "Firewall Error: $($_.Exception.Message)"
                    }
                    finally {
                        [System.Windows.Input.Mouse]::OverrideCursor = $null
                    }
                })
        }

        # Network Reset (Network Tab Quick Action)
        $btnResetNetQuick = $window.FindName("btnResetNetworkQuick")
        if ($btnResetNetQuick) {
            $btnResetNetQuick.Add_Click({
                & $runBackgroundTask -TaskName "Reset Network Stack" -WorkBlock {
                    Reset-WinDebloatNetwork -Confirm:$false
                }
            })
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # SNAPSHOTS TAB
        # ═══════════════════════════════════════════════════════════════════════════════
        try {
            $lstSnapshotsInit = & $getCtrl "lstSnapshots"
            foreach ($snap in (Get-WinDebloatSnapshot)) {
                $lstSnapshotsInit.Items.Add("$($snap.Timestamp) - $($snap.Name) [$($snap.Id)]") | Out-Null
            }
        }
        catch {
            Write-Verbose "Could not populate snapshot list: $($_.Exception.Message)"
        }

        (& $getCtrl "btnCreateSnapshot").Add_Click({
                & $runBackgroundTask -TaskName "Create Snapshot" -WorkBlock {
                    New-WinDebloatSnapshot -Name "GUI-Snapshot" -Description "Created via GUI" -Encrypt | Out-Null
                } -OnCompleted {
                    $lstSnapshots = $window.FindName("lstSnapshots")
                    if ($lstSnapshots) {
                        $snaps = Get-WinDebloatSnapshot
                        $lstSnapshots.Items.Clear()
                        foreach ($snap in $snaps) {
                            $lstSnapshots.Items.Add("$($snap.Timestamp) - $($snap.Name) [$($snap.Id)]")
                        }
                    }
                }
            })

        $btnRestore = $window.FindName("btnRestoreSnapshot")
        if ($btnRestore) {
            $btnRestore.Add_Click({
                    $lstSnapshots = $window.FindName("lstSnapshots")
                    if ($lstSnapshots -and $lstSnapshots.SelectedItem) {
                        if ($lstSnapshots.SelectedItem -match '\[(.*?)\]$') {
                            $snapId = $matches[1]
                            & $runBackgroundTask -TaskName "Restore Snapshot ($snapId)" -WorkBlock {
                                Restore-WinDebloatSnapshot -SnapshotId $snapId -Confirm:$false
                            } -Variables @{ snapId = $snapId }
                        }
                    }
                })
        }

        # ═══════════════════════════════════════════════════════════════════════════════
        # TOOLS TAB
        # ═══════════════════════════════════════════════════════════════════════════════

        # 1. Interface Tweaks
        (& $getCtrl "btnApplyUITweaks").Add_Click({
                $txtStatus.Text = "Applying UI Tweaks..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                try {
                    # Taskbar
                    $align = if ((& $getCtrl "radTaskbarLeft").IsChecked) { "Left" } else { "Center" }
                    Set-WinDebloatTaskbarAlignment -Alignment $align -Confirm:$false

                    # Context Menu
                    $ctx = if ((& $getCtrl "radCtxClassic").IsChecked) { "Classic" } else { "Modern" }
                    Set-WinDebloatContextMenu -Style $ctx -Confirm:$false

                    # Explorer
                    $hideGallery = (& $getCtrl "chkHideGallery").IsChecked
                    $hideHome = (& $getCtrl "chkHideHome").IsChecked
                    Set-WinDebloatExplorer -HideGallery:$hideGallery -HideHome:$hideHome -Confirm:$false

                    $txtStatus.Text = "UI Tweaks Applied! Restart Explorer to see changes."
                }
                catch { $txtStatus.Text = "Error: $($_.Exception.Message)" }
                finally { [System.Windows.Input.Mouse]::OverrideCursor = $null }
            })

        # 2. Maintenance Tools
        (& $getCtrl "btnRestartExplorer").Add_Click({
                $txtStatus.Text = "Restarting Explorer..."
                & $updateGui
                try {
                    Restart-WinDebloatExplorer -Confirm:$false
                    $txtStatus.Text = "Explorer restarted."
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
            })

        (& $getCtrl "btnUpdateDrivers").Add_Click({
                $txtStatus.Text = "Launching Driver Update Center..."
                & $updateGui
                try {
                    # The spawned pwsh has no modules loaded - import the manifest first
                    $manifestCandidate = Join-Path $scriptRoot "..\..\..\Win-Debloat.psd1"
                    if (-not (Test-Path $manifestCandidate)) {
                        $manifestCandidate = Join-Path $scriptRoot "..\..\..\Win-Debloat7.psd1"
                    }
                    $manifestPath = (Resolve-Path $manifestCandidate).Path
                    $driverCmd = "Import-Module '$manifestPath' -Force; Update-WinDebloatDrivers -Method Interactive"
                    Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-NoExit", "-Command", $driverCmd -Verb RunAs
                    $txtStatus.Text = "Driver Update Center Launched!"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
            })

        (& $getCtrl "btnRepairSystem").Add_Click({
                & $runBackgroundTask -TaskName "System Repair (SFC / DISM)" -WorkBlock {
                    Repair-WinDebloatSystem -Confirm:$false
                }
            })

        (& $getCtrl "btnResetNetwork").Add_Click({
                & $runBackgroundTask -TaskName "Reset Network Stack" -WorkBlock {
                    Reset-WinDebloatNetwork -Confirm:$false
                }
            })

        (& $getCtrl "btnWinUpdateReset").Add_Click({
                & $runBackgroundTask -TaskName "Reset Update Components" -WorkBlock {
                    Reset-WinDebloatUpdate -Confirm:$false
                }
            })

        # 3. Analysis (Benchmark) - Async Non-Blocking Runspace
        (& $getCtrl "btnRunBenchmark").Add_Click({
                $btn = & $getCtrl "btnRunBenchmark"
                $btn.IsEnabled = $false
                $txtStatus.Text = "Running System Benchmark (Async)..."
                & $updateGui
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait

                $benchRs = [runspacefactory]::CreateRunspace()
                $benchRs.Open()
                $benchPs = [powershell]::Create()
                $benchPs.Runspace = $benchRs
                $benchScript = {
                    param($benchModulePath)
                    Import-Module $benchModulePath -Force -ErrorAction SilentlyContinue
                    return Measure-WinDebloatSystem
                }
                $benchModule = (Resolve-Path (Join-Path $scriptRoot "..\..\modules\Performance\Benchmark.psm1")).Path
                $benchPs.AddScript($benchScript).AddArgument($benchModule) | Out-Null
                $benchHandle = $benchPs.BeginInvoke()

                $benchTimer = [System.Windows.Threading.DispatcherTimer]::new()
                $benchTimer.Interval = [TimeSpan]::FromMilliseconds(200)
                $benchTimer.Add_Tick({
                        if ($benchHandle.IsCompleted) {
                            $benchTimer.Stop()
                            try {
                                $benchResults = $benchPs.EndInvoke($benchHandle)
                                $benchPs.Dispose()
                                $benchRs.Dispose()

                                $metrics = if ($benchResults) { $benchResults[-1] } else { $null }
                                if ($metrics) {
                                    $desktopDir = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
                                    if (-not $desktopDir -or -not (Test-Path $desktopDir)) {
                                        $desktopDir = "$env:USERPROFILE\Desktop"
                                    }
                                    if (-not (Test-Path $desktopDir)) {
                                        $desktopDir = $env:TEMP
                                    }
                                    $reportPath = Join-Path $desktopDir "Win-Debloat_Benchmark_$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
                                    $reportContent = @"
======================================================================
 WIN-DEBLOAT SYSTEM BENCHMARK & TELEMETRY REPORT
======================================================================
 Timestamp:          $($metrics.Timestamp)
 Used RAM:           $($metrics.UsedRAM_MB) MB
 Free RAM:           $($metrics.FreeRAM_MB) MB
 Running Processes:  $($metrics.Processes)
 Running Services:   $($metrics.Services)
 Free Disk Space:    $($metrics.DiskFree_GB) GB
 Last Boot Time:     $($metrics.LastBoot)
======================================================================
 Generated by Win-Debloat Performance Suite
"@
                                    $reportContent | Set-Content -Path $reportPath -Encoding UTF8
                                    $txtStatus.Text = "Benchmark Saved to: $reportPath"
                                    Start-Process "notepad.exe" $reportPath
                                }
                                else {
                                    $txtStatus.Text = "Benchmark completed (no metrics returned)."
                                }
                            }
                            catch {
                                $txtStatus.Text = "Benchmark Error: $($_.Exception.Message)"
                            }
                            finally {
                                [System.Windows.Input.Mouse]::OverrideCursor = $null
                                $btn.IsEnabled = $true
                            }
                        }
                    })
                $benchTimer.Start()
            })

        # ═══════════════════════════════════════════════════════════════════════════════
        # SETTINGS TAB
        # ═══════════════════════════════════════════════════════════════════════════════
        (& $getCtrl "btnViewLogs").Add_Click({
                $logPath = "$env:ProgramData\Win-Debloat\Logs"
                if (-not (Test-Path $logPath)) {
                    $legacyPath = "$env:ProgramData\Win-Debloat7\Logs"
                    if (Test-Path $legacyPath) { $logPath = $legacyPath }
                }

                # Create logs directory if it doesn't exist
                if (-not (Test-Path $logPath)) {
                    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
                    $txtStatus.Text = "Log directory created: $logPath"
                }

                # Try to open the folder
                try {
                    Start-Process "explorer.exe" -ArgumentList $logPath
                    $txtStatus.Text = "Opened log folder"
                }
                catch {
                    $txtStatus.Text = "Error opening logs: $($_.Exception.Message)"
                }
            })

        # Status bar show log button
        $btnShowLog = $window.FindName("btnShowLog")
        if ($btnShowLog) {
            $btnShowLog.Add_Click({
                    $logPath = "$env:ProgramData\Win-Debloat\Logs"
                    if (-not (Test-Path $logPath)) {
                        $legacyPath = "$env:ProgramData\Win-Debloat7\Logs"
                        if (Test-Path $legacyPath) { $logPath = $legacyPath }
                    }
                    if (Test-Path $logPath) { Start-Process "explorer.exe" -ArgumentList $logPath }
                })
        }

        (& $getCtrl "btnCheckUpdates").Add_Click({
                $txtStatus.Text = "Checking for updates..."
                try {
                    Start-Process "https://github.com/tomytate/Win-Debloat/releases"
                    $txtStatus.Text = "Opened releases page"
                }
                catch {
                    $txtStatus.Text = "Error: $($_.Exception.Message)"
                }
            })

        # Show window
        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Warning "Failed to load GUI: $($_.Exception.Message)"
        throw
    }
}

Set-Alias -Name 'Show-WinDebloat7GUI' -Value 'Show-WinDebloatGUI'

Export-ModuleMember -Function Show-WinDebloatGUI -Alias Show-WinDebloat7GUI
