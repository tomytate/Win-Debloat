#Requires -Version 7.6

<#
.SYNOPSIS
    Interactive Menu System for Win-Debloat (Cyber-Minimalist Edition)
    
.DESCRIPTION
    Provides the Terminal User Interface (TUI) for navigating Win-Debloat,
    selecting and previewing profiles, managing tweaks, and executing system repairs.
    
.NOTES
    Module: Win-Debloat.UI.Menu
    Version: 1.7.0
#>

using namespace System.Management.Automation

# Extras module (only present in Extras edition)
$extrasModule = "$PSScriptRoot\..\modules\Extras\Extras.psm1"
$extrasAvailable = Test-Path $extrasModule
if ($extrasAvailable) {
    Import-Module $extrasModule -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
# TUI Navigation & Feedback Helpers
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays a breadcrumb navigation trail at the top of a menu screen.
.PARAMETER Path
    Array of string elements representing the navigation hierarchy.
#>
function Show-WD7Breadcrumb {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Terminal TUI styling')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )
    $crumbs = $Path -join " > "
    Write-WD7Host "  [ $crumbs ]" -Color Dark
    Write-Host ""
}

<#
.SYNOPSIS
    Waits for the user to press Enter before proceeding.
.PARAMETER Message
    Custom prompt message text.
#>
function Wait-WD7UserPrompt {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Terminal TUI styling')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$Message = "Press Enter to continue..."
    )
    $null = Read-Host "`n  $Message"
}

<#
.SYNOPSIS
    Renders an action completion or warning summary banner.
.PARAMETER Title
    Summary title message.
.PARAMETER Detail
    Optional detailed information string.
.PARAMETER Status
    Status level (Success, Warning, Error, Info).
#>
function Show-WD7ActionResult {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Terminal TUI styling')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [string]$Detail = "",
        [ValidateSet("Success", "Warning", "Error", "Info")]
        [string]$Status = "Success"
    )
    Write-Host ""
    Show-WD7StatusBadge -Label $Title -Status $Status
    if ($Detail) {
        Write-WD7Host "    $Detail" -Color Info
    }
}

<#
.SYNOPSIS
    Renders an interactive menu with arrow-key navigation, hotkey jumps, and dynamic context help.
#>
function Show-WDInteractiveMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Breadcrumbs,
        [Parameter(Mandatory)][array]$Items,
        [string]$HeaderInfo = ""
    )

    # Headless / Redirected Fallback
    if (Test-WDHeadless) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path $Breadcrumbs
        Show-WD7Separator -Title $Title -Color Secondary
        Write-Host ""
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            Write-Host "  [$($item.Key)] $($item.Label) - $($item.Description)"
        }
        Write-Host "`n  [B] Back"
        $choice = (Read-Host "`n  Enter selection").Trim().ToUpper()
        if ($choice -in "B", "BACK", "0", "") { return $null }
        return ($Items | Where-Object { $_.Key.ToUpper() -eq $choice } | Select-Object -First 1)
    }

    $selectedIndex = 0
    $esc = [char]27

    while ($true) {
        $sb = [System.Text.StringBuilder]::new()

        # Build Header & Breadcrumb in memory
        [void]$sb.AppendLine((Get-WD7GradientText -Text $Script:WD7HeaderCompact -StartColor Primary -EndColor Secondary -LineByLine))
        $crumbs = $Breadcrumbs -join " > "
        [void]$sb.AppendLine("  $esc[38;2;96;96;112m[ $crumbs ]$esc[0m`n")
        
        # Separator
        $sepWidth = 70
        $padLen = [int][math]::Max(0, [math]::Floor(($sepWidth - $Title.Length - 4) / 2))
        $padding = "─" * $padLen
        [void]$sb.AppendLine("  $esc[38;2;123;44;191m$padding $Title $padding$esc[0m")

        if ($HeaderInfo) {
            [void]$sb.AppendLine("  $esc[38;2;160;160;176m$HeaderInfo$esc[0m")
        }
        [void]$sb.AppendLine("")

        # Render Items
        $lastCategory = $null
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]

            if ($item.Category -and $item.Category -ne $lastCategory) {
                [void]$sb.AppendLine("  $esc[38;2;0;212;255m── $($item.Category) " + ("─" * [math]::Max(2, (56 - $item.Category.Length))) + "$esc[0m")
                $lastCategory = $item.Category
            }

            $isHovered = ($i -eq $selectedIndex)
            $pointer = if ($isHovered) { "$esc[38;2;0;212;255m❯$esc[0m " } else { "  " }
            $badgeColor = switch -Regex ($item.Badge) {
                '^(ON|ACTIVE|ENABLED|RECOMMENDED)$' { "38;2;0;255;136" }
                '^(OFF|DISABLED)$'                  { "38;2;96;96;112" }
                '^(WARNING|CAUTION)$'               { "38;2;255;184;0" }
                '^(SECURITY|CRITICAL)$'             { "38;2;255;51;102" }
                default                             { "38;2;0;212;255" }
            }
            $badge = if ($item.Badge) { " $esc[${badgeColor}m[$($item.Badge)]$esc[0m" } else { "" }
            $toggle = if ($item.ContainsKey("IsChecked")) { if ($item.IsChecked) { " $esc[38;2;0;255;136m[✔]$esc[0m" } else { " $esc[38;2;96;96;112m[ ]$esc[0m" } } else { "" }

            if ($isHovered) {
                $row = "  $pointer$esc[1;38;2;255;255;255;48;2;30;40;60m[$($item.Key)] $($item.Label)$esc[0m$badge$toggle"
            }
            else {
                $colorCode = switch ($item.Color) {
                    "Success"   { "38;2;0;255;136" }
                    "Warning"   { "38;2;255;184;0" }
                    "Error"     { "38;2;255;51;102" }
                    "Secondary" { "38;2;123;44;191" }
                    "Dark"      { "38;2;96;96;112" }
                    default     { "38;2;255;255;255" }
                }
                $row = "  $pointer$esc[38;2;96;96;112m[$($item.Key)]$esc[0m $esc[${colorCode}m$($item.Label)$esc[0m$badge$toggle"
            }
            [void]$sb.AppendLine($row)
        }

        [void]$sb.AppendLine("`n  $esc[38;2;96;96;112m[↑/↓] Navigate  [Enter] Select  [Space] Toggle  [Esc/B] Back$esc[0m")
        
        # Context Description Box
        $hoveredItem = $Items[$selectedIndex]
        $desc = if ($hoveredItem.Description) { $hoveredItem.Description } else { "No description available." }
        [void]$sb.AppendLine("  $esc[38;2;123;44;191m──────────────────────────────────────────────────────────────────────$esc[0m")
        [void]$sb.AppendLine("  $esc[38;2;160;160;176mℹ $desc$esc[0m")

        # Atomic Frame Render
        Show-WDFrame -FrameContent $sb.ToString()

        # Input Dispatcher
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $selectedIndex = ($selectedIndex - 1 + $Items.Count) % $Items.Count
            }
            ([System.ConsoleKey]::DownArrow) {
                $selectedIndex = ($selectedIndex + 1) % $Items.Count
            }
            ([System.ConsoleKey]::Home) {
                $selectedIndex = 0
            }
            ([System.ConsoleKey]::End) {
                $selectedIndex = $Items.Count - 1
            }
            ([System.ConsoleKey]::PageUp) {
                $selectedIndex = [math]::Max(0, $selectedIndex - 5)
            }
            ([System.ConsoleKey]::PageDown) {
                $selectedIndex = [math]::Min($Items.Count - 1, $selectedIndex + 5)
            }
            ([System.ConsoleKey]::Spacebar) {
                if ($hoveredItem.ContainsKey("IsChecked")) {
                    $hoveredItem.IsChecked = -not $hoveredItem.IsChecked
                }
            }
            ([System.ConsoleKey]::Enter) {
                return $hoveredItem
            }
            ([System.ConsoleKey]::Escape) {
                return $null
            }
            default {
                $char = $key.KeyChar.ToString().ToUpper()
                if ($char -in "B", "Q") { return $null }
                $matched = $Items | Where-Object { $_.Key.ToUpper() -eq $char } | Select-Object -First 1
                if ($matched) { return $matched }
            }
        }
    }
}

<#
.SYNOPSIS
    Displays the 26H2 Silicon Scheduling and CPU Architecture menu.
#>
function Show-SiliconSchedulingMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $hw = Get-WinDebloatHardwareProfile
    $archTag = if ($hw.HasIntelHybrid) { "Intel Hybrid (P+E+LP-E)" }
               elseif ($hw.HasDualCcdX3D) { "AMD Dual-CCD 3D V-Cache" }
               else { "Standard Monolithic CPU" }

    $headerText = "Detected: $($hw.ProcessorName) | Architecture: $archTag"

    while ($true) {
        $items = @(
            @{
                Key = "1"; Label = "Intel Thread Director 2.0 Tuning"; Category = "CPU Architecture";
                Description = "Optimizes P-core scheduling, unconstrained LP-E core containment (Lunar Lake/Arrow Lake), and sets EPP to 0%.";
                Color = "White"; Badge = if ($hw.HasIntelHybrid) { "RECOMMENDED" } else { $null };
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Configuring Intel Thread Director & EPP..." -ScriptBlock {
                        Optimize-WinDebloatThreadDirector
                    } -SuccessMessage "Thread Director & EPP optimized for maximum responsiveness."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "2"; Label = "AMD 3D V-Cache Core Parking Safeguards"; Category = "CPU Architecture";
                Description = "Enforces AutoGameMode and CPMINCORES headroom to park non-V-Cache CCD cores, avoiding cross-CCD latency penalties.";
                Color = "White"; Badge = if ($hw.HasDualCcdX3D) { "RECOMMENDED" } else { $null };
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Enforcing AMD 3D V-Cache core parking safeguards..." -ScriptBlock {
                        Protect-WinDebloatAMDX3D
                    } -SuccessMessage "AMD 3D V-Cache parking safeguards verified and enforced."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "3"; Label = "Kernel Low-Latency Timers & DPC Distribution"; Category = "Kernel Latency";
                Description = "Enables GlobalTimerResolutionRequests and DistributeTimers to eliminate DPC microstutter in Windows 11 26H2.";
                Color = "White"; Badge = "26H2";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Configuring low-latency kernel timers..." -ScriptBlock {
                        Enable-WinDebloatLowLatencyTimers
                    } -SuccessMessage "Kernel low-latency timers and distributed DPC dispatching active."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "A"; Label = "Apply Complete Silicon Suite for This Hardware"; Category = "Automation";
                Description = "Automatically selects and applies the optimal scheduling and timer settings for your detected CPU.";
                Color = "Success";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Applying automated silicon optimization suite..." -ScriptBlock {
                        if ($hw.HasIntelHybrid) { Optimize-WinDebloatThreadDirector }
                        if ($hw.HasDualCcdX3D) { Protect-WinDebloatAMDX3D }
                        Enable-WinDebloatLowLatencyTimers
                    } -SuccessMessage "Hardware-specific silicon optimizations applied."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "U"; Label = "Revert Silicon Scheduling to Defaults"; Category = "Revert";
                Description = "Restores Thread Director, AMD GameBar, and kernel timer policies to factory Windows settings.";
                Color = "Dark";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Restoring default scheduling settings..." -ScriptBlock {
                        Reset-WinDebloatThreadDirector
                        Reset-WinDebloatAMDX3D
                        Reset-WinDebloatLowLatencyTimers
                    } -SuccessMessage "Silicon scheduling restored to Windows defaults."
                    Wait-WD7UserPrompt
                }
            }
        )

        $choice = Show-WDInteractiveMenu -Title "SILICON SCHEDULING (26H2)" -Breadcrumbs @("Main Menu", "Silicon Scheduling") -Items $items -HeaderInfo $headerText
        if ($null -eq $choice) { break }
        & $choice.Action
    }
}

<#
.SYNOPSIS
    Displays the 26H2 Transport Security & Network Privacy menu.
#>
function Show-TransportSecurityMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        $echEnabled = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "EncryptedClientHelloEnabled" -ErrorAction SilentlyContinue) -eq 1

        $items = @(
            @{
                Key = "1"; Label = "Encrypted Client Hello (ECH) Policy"; Category = "Transport Security";
                Description = "Enforces TLS 1.3 ECH across Microsoft Edge and Google Chrome to encrypt Server Name Indication (SNI).";
                Color = "White"; Badge = if ($echEnabled) { "ACTIVE" } else { "OFF" };
                Action = {
                    if ($echEnabled) {
                        Invoke-WDTaskWithSpinner -Message "Removing ECH policy overrides..." -ScriptBlock { Disable-WinDebloatECH } -SuccessMessage "ECH policy override removed."
                    } else {
                        Invoke-WDTaskWithSpinner -Message "Enforcing Encrypted Client Hello (ECH)..." -ScriptBlock { Enable-WinDebloatECH } -SuccessMessage "ECH policy enforced across Edge and Chrome."
                    }
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "2"; Label = "UDP Receive Offload (URO) Low-Latency Mode"; Category = "Transport Security";
                Description = "Disables URO packet coalescing on network adapters to eliminate micro-jitter for competitive gaming and VoIP.";
                Color = "White"; Badge = "GAMING";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Disabling URO on network adapters..." -ScriptBlock { Disable-WinDebloatNetAdapterURO } -SuccessMessage "URO disabled (low-latency packet flow active)."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "3"; Label = "DNS-over-HTTPS (DoH) Policy Configuration"; Category = "Encrypted DNS";
                Description = "Configures native Windows 11 DoH enforcement or auto-upgrade template.";
                Color = "White";
                Action = {
                    Show-NetworkPrivacyMenu
                }
            },
            @{
                Key = "4"; Label = "Block Telemetry Endpoints (Windows Firewall)"; Category = "Telemetry Shield";
                Description = "Creates persistent outbound firewall rules blocking known Windows 11 telemetry and tracking domains.";
                Color = "White";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Blocking telemetry domains in Windows Firewall..." -ScriptBlock { Add-WinDebloatFirewallBlock } -SuccessMessage "Firewall telemetry shield applied."
                    Wait-WD7UserPrompt
                }
            }
        )

        $choice = Show-WDInteractiveMenu -Title "TRANSPORT SECURITY & PRIVACY" -Breadcrumbs @("Main Menu", "Transport Security") -Items $items
        if ($null -eq $choice) { break }
        & $choice.Action
    }
}

<#
.SYNOPSIS
    Displays the 26H2 Storage Subsystem & DirectStorage BypassIO menu.
#>
function Show-StorageSubsystemMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        $items = @(
            @{
                Key = "1"; Label = "Run Storage & DirectStorage Diagnostics"; Category = "Diagnostics";
                Description = "Queries DirectStorage 1.2+ BypassIO support via fsutil, verifies TRIM, and checks physical drive SMART health.";
                Color = "Primary";
                Action = {
                    Write-Host ""
                    $health = Invoke-WDTaskWithSpinner -Message "Querying DirectStorage BypassIO & storage health..." -ScriptBlock {
                        Test-WinDebloatStorageHealth -Drive "C:"
                    } -SuccessMessage "Diagnostics completed."
                    
                    Write-Host ""
                    Show-WD7Separator -Title "STORAGE DIAGNOSTIC RESULTS" -Color Secondary
                    Write-WD7Host "  BypassIO Support:  $($health.BypassIoSupported)" -Color $(if ($health.BypassIoSupported) { "Success" } else { "Warning" })
                    Write-WD7Host "  BypassIO Status:   $($health.BypassIoStatus)" -Color Info
                    Write-WD7Host "  TRIM Garbage Coll: $(if ($health.TrimEnabled) { 'Enabled' } else { 'Disabled' })" -Color $(if ($health.TrimEnabled) { "Success" } else { "Error" })
                    if ($health.PhysicalDisks) {
                        Write-Host "`n  Physical Disks:"
                        $health.PhysicalDisks | Format-Table DeviceId, FriendlyName, MediaType, HealthStatus -AutoSize | Out-String | Write-Host
                    }
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "2"; Label = "Optimize ReFS Dev Drive Subsystem"; Category = "Tuning";
                Description = "Configures RefsDisableLastAccessUpdate=1 and RefsEnableLargeWorkingSetTrim=1 for maximum developer I/O.";
                Color = "White"; Badge = "26H2";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Optimizing ReFS developer drives..." -ScriptBlock {
                        Optimize-WinDebloatDevDrive
                    } -SuccessMessage "ReFS Dev Drive optimizations applied."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "3"; Label = "Disable NVMe Autonomous Power Transitions (APST)"; Category = "Tuning";
                Description = "Disables NVMe APST controller sleep hiccups in stornvme to eliminate latency spikes during high I/O workloads.";
                Color = "White"; Badge = "LOW LATENCY";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Disabling NVMe APST latency spikes..." -ScriptBlock {
                        Disable-WinDebloatNVMeAPST
                    } -SuccessMessage "NVMe low-latency mode active."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "U"; Label = "Revert Storage Settings to Defaults"; Category = "Revert";
                Description = "Restores default NVMe APST power policies and Dev Drive cache flags.";
                Color = "Dark";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Restoring default storage subsystem settings..." -ScriptBlock {
                        Enable-WinDebloatNVMeAPST
                    } -SuccessMessage "Storage settings restored to Windows defaults."
                    Wait-WD7UserPrompt
                }
            }
        )

        $choice = Show-WDInteractiveMenu -Title "STORAGE & DIRECTSTORAGE (26H2)" -Breadcrumbs @("Main Menu", "Storage Health") -Items $items
        if ($null -eq $choice) { break }
        & $choice.Action
    }
}

<#
.SYNOPSIS
    Displays Enterprise SMB Hardening menu.
#>
function Show-SMBHardeningMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        $items = @(
            @{
                Key = "1"; Label = "Disable Legacy SMBv1 Protocol"; Category = "Vulnerability Mitigation";
                Description = "Disables SMBv1 protocol driver to eliminate WannaCry / EternalBlue attack surfaces.";
                Color = "Warning";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Disabling SMBv1 protocol..." -ScriptBlock { Disable-WinDebloatSMBv1 } -SuccessMessage "SMBv1 protocol disabled."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "2"; Label = "Enforce Mandatory SMB Signing & Rate Limiting"; Category = "Authentication Hardening";
                Description = "Requires digital signatures for SMB traffic and enforces brute-force authentication rate-limiting.";
                Color = "White";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Enforcing SMB signing & rate limiting..." -ScriptBlock { Enable-WinDebloatSMBSigning } -SuccessMessage "SMB signing enforced."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "3"; Label = "Block NTLM over SMB (Enforce Kerberos)"; Category = "Authentication Hardening";
                Description = "Blocks legacy NTLM authentication over SMB clients, preventing credential coercion and NTLM relay attacks.";
                Color = "White"; Badge = "26H2";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Enforcing Kerberos and blocking NTLM over SMB..." -ScriptBlock { Enable-WinDebloatSMBNTLMBlock } -SuccessMessage "SMB NTLM blocking active."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "4"; Label = "Complete SMB Client Security Hardening"; Category = "Client Hardening";
                Description = "Enforces client encryption, signing, and strictly blocks insecure guest logons.";
                Color = "White";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Applying SMB client security hardening..." -ScriptBlock { Enable-WinDebloatSMBClientHardening } -SuccessMessage "SMB client hardening policies active."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "A"; Label = "Enforce All SMB Hardening Baselines"; Category = "Automation";
                Description = "Applies full enterprise SMB hardening suite (SMBv1 removal, signing, NTLM block, client hardening).";
                Color = "Success";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Applying all SMB hardening baselines..." -ScriptBlock {
                        Disable-WinDebloatSMBv1
                        Enable-WinDebloatSMBSigning
                        Enable-WinDebloatSMBNTLMBlock
                        Enable-WinDebloatSMBClientHardening
                    } -SuccessMessage "Full enterprise SMB hardening baseline applied."
                    Wait-WD7UserPrompt
                }
            },
            @{
                Key = "U"; Label = "Revert SMB Hardening to Defaults"; Category = "Revert";
                Description = "Restores default Windows SMB signing, client settings, and allows legacy NTLM authentication.";
                Color = "Dark";
                Action = {
                    Invoke-WDTaskWithSpinner -Message "Restoring default SMB policies..." -ScriptBlock {
                        Disable-WinDebloatSMBSigning
                        Disable-WinDebloatSMBNTLMBlock
                        Disable-WinDebloatSMBClientHardening
                    } -SuccessMessage "SMB policies restored to default."
                    Wait-WD7UserPrompt
                }
            }
        )

        $choice = Show-WDInteractiveMenu -Title "ENTERPRISE SMB HARDENING" -Breadcrumbs @("Main Menu", "SMB Hardening") -Items $items
        if ($null -eq $choice) { break }
        & $choice.Action
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Menu
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays the Win-Debloat main interactive TUI menu.
.OUTPUTS
    [void]
#>
function Show-MainMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Enter-WDAlternateBuffer
    try {
        while ($true) {
            Show-WD7Header
            Show-WD7Breadcrumb -Path @("Win-Debloat", "Main Menu")
            
            Show-WD7Separator -Title "MAIN MENU" -Color Primary
            Write-Host ""

            # Section: Automated & Profiles
            Write-WD7Host "  [1] Quick Debloat (Recommended Profile)" -Color Success
            Write-WD7Host "  [2] Launch Premium GUI" -Color Primary
            Write-WD7Host "  [3] Select Profile..." -Color White
            Write-Host ""

            # Section: Core Modules
            Write-WD7Host "  [4] Software Catalog & Essential Apps" -Color White
            Write-WD7Host "  [5] Update Drivers" -Color White
            Write-WD7Host "  [6] Network & Privacy Settings" -Color White
            Write-WD7Host "  [7] Benchmark System" -Color White
            Write-WD7Host "  [8] System Info" -Color White
            Write-WD7Host "  [9] Snapshots / Rollback" -Color White
            Write-Host ""

            # Section: 26H2 Silicon, Transport & Storage
            Write-WD7Host "  [H] Silicon Scheduling (Intel Thread Director / AMD X3D)" -Color Accent
            Write-WD7Host "  [N] Transport Security & ECH (26H2 Baseline)" -Color Accent
            Write-WD7Host "  [K] Storage Health & DirectStorage BypassIO" -Color Accent
            Write-Host ""

            # Section: Advanced & System
            Write-WD7Host "  [X] Tweaks & Customization" -Color Secondary
            Write-WD7Host "  [S] Service Optimizer (Presets)" -Color White
            Write-WD7Host "  [U] Update All Apps" -Color White
            Write-WD7Host "  [R] System Repair Tools" -Color Warning
            Write-WD7Host "  [F] Windows Features Manager" -Color White
            Write-WD7Host "  [T] Third Party Tools" -Color White
            
            # Section: Extras (if available)
            if ($extrasAvailable) {
                Write-Host ""
                Show-WD7Separator -Title "ADVANCED TOOLS" -Color Warning
                Write-WD7Host "  [D] Defender Remover ⚠️" -Color Warning
                Write-WD7Host "  [A] Windows Activation ⚠️" -Color Warning
            }
            
            Write-Host ""
            Show-WD7Separator
            Write-WD7Host "  [0] Register Weekly Maintenance" -Color Dark
            Write-WD7Host "  [Q] Quit" -Color Dark
            
            Write-Host ""
            Show-WDCursor
            $rawChoice = Read-Host "  Enter selection"
            if ($null -eq $rawChoice) { return }
            $choice = $rawChoice.Trim().ToUpper()
            
            switch ($choice) {
                "1" {
                    Invoke-Profile "$PSScriptRoot\..\..\profiles\moderate.yaml"
                }
                { $_ -in "2", "G", "GUI" } {
                    try {
                        Import-Module "$PSScriptRoot\gui\GUI.psm1" -Force
                        Show-WinDebloat7GUI
                    }
                    catch {
                        Show-WD7ActionResult -Title "Failed to launch GUI" -Detail $_.Exception.Message -Status Error
                        Start-Sleep -Seconds 2
                    }
                }
                { $_ -in "3", "P", "PROFILE", "PROFILES" } {
                    Show-ProfileSelection
                }
                { $_ -in "4", "E", "ESSENTIALS", "CATALOG", "APPS" } {
                    try {
                        Show-SoftwareCatalogMenu
                    }
                    catch {
                        Show-WD7ActionResult -Title "Error opening software catalog" -Detail $_.Exception.Message -Status Error
                        Wait-WD7UserPrompt "Press Enter to return to main menu..."
                    }
                }
                "5" {
                    try {
                        Update-WinDebloat7Drivers
                    }
                    catch {
                        Show-WD7ActionResult -Title "Error updating drivers" -Detail $_.Exception.Message -Status Error
                    }
                    Wait-WD7UserPrompt "Press Enter to return to main menu..."
                }
                "6" {
                    Show-NetworkPrivacyMenu
                }
                { $_ -in "7", "BENCHMARK" } {
                    Invoke-WinDebloat7Benchmark
                }
                { $_ -in "8", "I", "INFO" } {
                    Show-SystemInfo
                }
                "9" {
                    Show-SnapshotMenu
                }
                { $_ -in "H", "SILICON" } {
                    Show-SiliconSchedulingMenu
                }
                { $_ -in "N", "TRANSPORT" } {
                    Show-TransportSecurityMenu
                }
                { $_ -in "K", "STORAGE", "BYPASSIO" } {
                    Show-StorageSubsystemMenu
                }
                "X" {
                    Show-TweaksMenu
                }
                "S" {
                    Show-ServicesMenu
                }
                "U" {
                    try {
                        Update-WinDebloat7Software
                    }
                    catch {
                        Show-WD7ActionResult -Title "Error updating apps" -Detail $_.Exception.Message -Status Error
                    }
                    Wait-WD7UserPrompt "Press Enter to return to main menu..."
                }
                "R" {
                    Show-RepairMenu
                }
                "F" {
                    Show-FeaturesMenu
                }
                "T" {
                    Show-IntegrationsMenu
                }
                "D" {
                    if ($extrasAvailable) {
                        try {
                            Invoke-WinDebloat7DefenderRemover
                        }
                        catch {
                            Show-WD7ActionResult -Title "Defender Remover Error" -Detail $_.Exception.Message -Status Error
                        }
                        Wait-WD7UserPrompt "Press Enter to continue..."
                    }
                    else {
                        Write-WD7Host "`n  Extras module not installed. Download Extras edition for this feature." -Color Warning
                        Start-Sleep -Seconds 2
                    }
                }
                "A" {
                    if ($extrasAvailable) {
                        try {
                            Invoke-WinDebloat7Activation
                        }
                        catch {
                            Show-WD7ActionResult -Title "Activation Error" -Detail $_.Exception.Message -Status Error
                        }
                        Wait-WD7UserPrompt "Press Enter to continue..."
                    }
                    else {
                        Write-WD7Host "`n  Extras module not installed. Download Extras edition for this feature." -Color Warning
                        Start-Sleep -Seconds 2
                    }
                }
                { $_ -in "0", "M", "MAINTENANCE" } {
                    try {
                        Register-WinDebloat7Maintenance
                        Show-WD7ActionResult -Title "Weekly maintenance registered successfully." -Status Success
                    }
                    catch {
                        Show-WD7ActionResult -Title "Error registering maintenance" -Detail $_.Exception.Message -Status Error
                    }
                    Wait-WD7UserPrompt "Press Enter to continue..."
                }
                { $_ -in "Q", "QUIT", "EXIT" } {
                    Write-WD7Host "`n  Exiting Win-Debloat. Goodbye!" -Color Info
                    return
                }
                default {
                    if (-not [string]::IsNullOrWhiteSpace($choice)) {
                        Write-WD7Host "`n  [!] Invalid selection '$choice'. Please choose a valid menu option." -Color Warning
                        Start-Sleep -Milliseconds 1200
                    }
                }
            }
        }
    }
    finally {
        Exit-WDAlternateBuffer
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Tweaks & Customization
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays the system tweaks and customization menu.
.OUTPUTS
    [void]
#>
function Show-TweaksMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Tweaks & Customization")
        Show-WD7Separator -Title "TWEAKS & CUSTOMIZATION" -Color Secondary
        Write-Host ""
        
        Write-WD7Host "  [1] UI Customization (Taskbar, Context Menu, Explorer, Start)" -Color White
        Write-WD7Host "  [2] Advanced Removal (OneDrive, Edge, Xbox, Copilot/Recall)" -Color White
        Write-WD7Host "  [3] Search & Suggestions (Bing Search, Highlights, Ads, Tips)" -Color White
        Write-WD7Host "  [4] System QoL Tweaks (Fast Startup, BitLocker, Updates, Power)" -Color White
        Write-Host ""
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""
        Show-WD7Separator

        $sel = (Read-Host "  Select option").Trim()

        switch ($sel.ToUpper()) {
            "1" { Show-UICustomizationMenu }
            "2" { Show-AdvancedRemovalMenu }
            "3" { Show-SearchSuggestionsMenu }
            "4" { Show-SystemQoLMenu }
            { $_ -in "B", "BACK", "0" } { return }
            "" { return }
            default {
                Write-WD7Host "`n  [!] Invalid option '$sel'. Please choose 1-4, or B to return." -Color Warning
                Start-Sleep -Milliseconds 1000
            }
        }
    }
}

<#
.SYNOPSIS
    Displays the UI customization submenu.
.OUTPUTS
    [void]
#>
function Show-UICustomizationMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Tweaks & Customization", "UI Customization")
        Show-WD7Separator -Title "UI CUSTOMIZATION" -Color Secondary
        Write-Host ""

        Write-WD7Host "  ── Taskbar & Start Menu ─────────────────────────────────────" -Color Primary
        Write-WD7Host "  [1] Align Taskbar: Left                  [2] Align Taskbar: Center" -Color White
        Write-WD7Host "  [7] Disable Start Menu 'Recommended'    [13] Hide Task View button" -Color White
        Write-WD7Host "  [11] Hide Taskbar search box             [12] Search icon only" -Color White
        Write-WD7Host "  [14] Enable 'End Task' in Taskbar menu   [15] Taskbar click focuses active window" -Color White
        Write-WD7Host "  [16] Disable Widgets                     [17] Hide Chat / Meet Now icon" -Color White
        Write-WD7Host "  [24] Start: Hide 'All Apps' list" -Color White
        Write-Host ""

        Write-WD7Host "  ── File Explorer & Context Menu ─────────────────────────────" -Color Primary
        Write-WD7Host "  [3] Context Menu: Classic (Win10)        [4] Context Menu: Modern (Win11)" -Color White
        Write-WD7Host "  [5] Hide 'Gallery' from Explorer         [6] Hide 'Home' from Explorer" -Color White
        Write-WD7Host "  [8] Explorer: Show file extensions       [9] Explorer: Show hidden files" -Color White
        Write-WD7Host "  [10] Explorer: Open to 'This PC'        [18] Explorer: Hide OneDrive" -Color White
        Write-WD7Host "  [19] Explorer: Hide 3D Objects          [20] Explorer: Hide Music folder" -Color White
        Write-WD7Host "  [21] Context Menu: Remove Share / Give Access / Include in Library" -Color White
        Write-Host ""

        Write-WD7Host "  ── Visuals & Window Management ──────────────────────────────" -Color Primary
        Write-WD7Host "  [22] Disable Transparency Effects        [23] Disable Snap Assist" -Color White
        Write-Host ""

        Write-WD7Host "  ── 26H2 Hardware Ergonomics & Explorer ───────────────────────" -Color Primary
        Write-WD7Host "  [25] Remap Copilot Hardware Key          [26] Disable Copilot Hardware Key" -Color White
        Write-WD7Host "  [27] Taskbar: Never Combine (Always)     [28] Taskbar: Combine When Full" -Color White
        Write-WD7Host "  [29] Suppress Explorer Recommendations & Cloud Indexing" -Color White
        Write-WD7Host "  [R]  Restart Explorer (apply pending visual changes)" -Color Success
        Write-Host ""

        Show-WD7Separator
        Write-WD7Host "  Undo: Prefix with 'U' to revert (e.g. U8 hides extensions, U16 restores Widgets)" -Color Info
        Write-WD7Host "  [B] Back to Tweaks Menu" -Color Dark
        Write-Host ""

        Show-WDCursor
        $sel = (Read-Host "  Select tweak to apply (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $upperSel = $sel.ToUpper()
        $handled = $true

        try {
            switch ($upperSel) {
                "1" { Set-WinDebloat7TaskbarAlignment -Alignment Left; Show-WD7ActionResult "Taskbar aligned to Left." }
                "2" { Set-WinDebloat7TaskbarAlignment -Alignment Center; Show-WD7ActionResult "Taskbar aligned to Center." }
                "3" { Set-WinDebloat7ContextMenu -Style Classic; Show-WD7ActionResult "Classic Windows 10 context menu enabled." }
                "4" { Set-WinDebloat7ContextMenu -Style Modern; Show-WD7ActionResult "Modern Windows 11 context menu restored." }
                "5" { Set-WinDebloat7Explorer -HideGallery; Show-WD7ActionResult "Gallery hidden from File Explorer." }
                "6" { Set-WinDebloat7Explorer -HideHome; Show-WD7ActionResult "Home hidden from File Explorer." }
                "7" { Set-WinDebloat7StartMenu -DisableRecommended; Show-WD7ActionResult "Start Menu Recommended section disabled." }
                "8" { Set-WinDebloat7Explorer -ShowFileExtensions; Show-WD7ActionResult "File extensions are now visible." }
                "9" { Set-WinDebloat7Explorer -ShowHiddenFiles; Show-WD7ActionResult "Hidden files are now visible." }
                "10" { Set-WinDebloat7Explorer -LaunchTo ThisPC; Show-WD7ActionResult "Explorer configured to open to 'This PC'." }
                "11" { Set-WinDebloat7TaskbarTweaks -SearchMode Hidden; Show-WD7ActionResult "Taskbar search hidden." }
                "12" { Set-WinDebloat7TaskbarTweaks -SearchMode Icon; Show-WD7ActionResult "Taskbar search set to icon only." }
                "13" { Set-WinDebloat7TaskbarTweaks -HideTaskView; Show-WD7ActionResult "Task View button hidden." }
                "14" { Set-WinDebloat7TaskbarTweaks -EnableEndTask; Show-WD7ActionResult "'End Task' right-click option enabled." }
                "15" { Set-WinDebloat7TaskbarTweaks -EnableLastActiveClick; Show-WD7ActionResult "Taskbar click focuses last active window." }
                "16" { Disable-WinDebloat7Widgets; Show-WD7ActionResult "Windows Widgets disabled." }
                "17" { Disable-WinDebloat7ChatTaskbar; Show-WD7ActionResult "Chat / Meet Now taskbar icon hidden." }
                "18" { Set-WinDebloat7Explorer -HideOneDrive; Show-WD7ActionResult "OneDrive hidden from Explorer navigation pane." }
                "19" { Set-WinDebloat7Explorer -Hide3DObjects; Show-WD7ActionResult "3D Objects folder hidden from Explorer." }
                "20" { Set-WinDebloat7Explorer -HideMusic; Show-WD7ActionResult "Music folder hidden from Explorer." }
                "21" { Set-WinDebloat7ContextMenuItems -HideShare -HideGiveAccessTo -HideIncludeInLibrary; Show-WD7ActionResult "Legacy context menu items removed." }
                "22" { Disable-WinDebloat7Transparency; Show-WD7ActionResult "Transparency effects disabled." }
                "23" { Disable-WinDebloat7SnapAssist; Show-WD7ActionResult "Snap Assist suggestions disabled." }
                "24" { Disable-WinDebloat7StartAllApps; Show-WD7ActionResult "Start menu 'All Apps' list hidden." }
                "25" {
                    $target = (Read-Host "  Enter app path/URL to launch on Copilot key (or press Enter for Search)").Trim()
                    if ([string]::IsNullOrWhiteSpace($target)) { Set-WinDebloatCopilotKeyRemap; Show-WD7ActionResult "Copilot key remapped to Search." }
                    else { Set-WinDebloatCopilotKeyRemap -CustomAppPath $target; Show-WD7ActionResult "Copilot key remapped to '$target'." }
                }
                "26" { Disable-WinDebloatCopilotKey; Show-WD7ActionResult "Copilot hardware key disabled." }
                "27" { Set-WinDebloatTaskbarGrouping -GlomLevel Never; Show-WD7ActionResult "Taskbar buttons set to Never Combine." }
                "28" { Set-WinDebloatTaskbarGrouping -GlomLevel WhenFull; Show-WD7ActionResult "Taskbar buttons set to Combine When Full." }
                "29" { Optimize-WinDebloatExplorerPerformance; Show-WD7ActionResult "Explorer recommendations & cloud indexing suppressed." }
                "R" { Restart-WinDebloat7Explorer; Show-WD7ActionResult "Windows Explorer restarted." }

                # Undo actions
                "U5" { Set-WinDebloat7Explorer -ShowGallery; Show-WD7ActionResult "Gallery restored in File Explorer." }
                "U6" { Set-WinDebloat7Explorer -ShowHome; Show-WD7ActionResult "Home restored in File Explorer." }
                "U7" { Set-WinDebloat7StartMenu -EnableRecommended; Show-WD7ActionResult "Start Menu Recommended section enabled." }
                "U8" { Set-WinDebloat7Explorer -HideFileExtensions; Show-WD7ActionResult "File extensions hidden." }
                "U9" { Set-WinDebloat7Explorer -HideHiddenFiles; Show-WD7ActionResult "Hidden files hidden." }
                "U10" { Set-WinDebloat7Explorer -LaunchTo Home; Show-WD7ActionResult "Explorer configured to open to 'Home'." }
                "U11" { Set-WinDebloat7TaskbarTweaks -SearchMode Box; Show-WD7ActionResult "Taskbar search box restored." }
                "U12" { Set-WinDebloat7TaskbarTweaks -SearchMode Box; Show-WD7ActionResult "Taskbar search box restored." }
                "U13" { Set-WinDebloat7TaskbarTweaks -ShowTaskView; Show-WD7ActionResult "Task View button restored." }
                "U14" { Set-WinDebloat7TaskbarTweaks -DisableEndTask; Show-WD7ActionResult "'End Task' option disabled." }
                "U15" { Set-WinDebloat7TaskbarTweaks -DisableLastActiveClick; Show-WD7ActionResult "Taskbar click behavior restored." }
                "U16" { Enable-WinDebloat7Widgets; Show-WD7ActionResult "Windows Widgets enabled." }
                "U17" { Enable-WinDebloat7ChatTaskbar; Show-WD7ActionResult "Chat / Meet Now icon restored." }
                "U18" { Set-WinDebloat7Explorer -ShowOneDrive; Show-WD7ActionResult "OneDrive restored in Explorer." }
                "U19" { Set-WinDebloat7Explorer -Show3DObjects; Show-WD7ActionResult "3D Objects folder restored." }
                "U20" { Set-WinDebloat7Explorer -ShowMusic; Show-WD7ActionResult "Music folder restored." }
                "U21" {
                    Show-WD7ActionResult -Title "Revert Context Menu Items" -Detail "Context-menu handler keys were deleted. Restore them from a snapshot via Snapshot Management." -Status Warning
                }
                "U22" { Enable-WinDebloat7Transparency; Show-WD7ActionResult "Transparency effects enabled." }
                "U23" { Enable-WinDebloat7SnapAssist; Show-WD7ActionResult "Snap Assist suggestions enabled." }
                "U24" { Enable-WinDebloat7StartAllApps; Show-WD7ActionResult "Start menu 'All Apps' list restored." }
                "U25" { Enable-WinDebloatCopilotKey; Show-WD7ActionResult "Copilot hardware key restored to default." }
                "U26" { Enable-WinDebloatCopilotKey; Show-WD7ActionResult "Copilot hardware key restored to default." }
                "U27" { Set-WinDebloatTaskbarGrouping -GlomLevel Always; Show-WD7ActionResult "Taskbar grouping restored to default." }
                "U28" { Set-WinDebloatTaskbarGrouping -GlomLevel Always; Show-WD7ActionResult "Taskbar grouping restored to default." }
                "U29" { Disable-WinDebloatExplorerPerformance; Show-WD7ActionResult "Explorer recommendations & cloud indexing restored." }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Unknown tweak '$sel'. Valid options are 1-29, R, U-prefixed numbers, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Write-WD7Host "  Tip: Press [R] to restart Explorer and apply visual changes immediately." -Color Dark
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error applying tweak" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

<#
.SYNOPSIS
    Displays the search suggestions and privacy submenu.
.OUTPUTS
    [void]
#>
function Show-SearchSuggestionsMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Tweaks & Customization", "Search & Suggestions")
        Show-WD7Separator -Title "SEARCH & SUGGESTIONS" -Color Secondary
        Write-Host ""

        Write-WD7Host "  [1] Disable Bing web results & Cortana in Start search" -Color White
        Write-WD7Host "  [2] Disable Search Highlights (branded search content & icons)" -Color White
        Write-WD7Host "  [3] Disable device search history" -Color White
        Write-WD7Host "  [4] Disable ALL Windows suggestions & ads (Start, Settings," -Color White
        Write-WD7Host "      lock screen tips, promoted app installs, nag toasts)" -Color White
        Write-WD7Host "  [5] Hide the Settings 'Home' page" -Color White
        Write-WD7Host "  [6] Hide Phone Link panel in Start menu" -Color White
        Write-Host ""
        Write-WD7Host "  [A] Apply ALL of the above (Recommended for Privacy)" -Color Success
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  Undo: Prefix with 'U' (e.g. U4 restores suggestions, UA reverts all)" -Color Info
        Write-WD7Host "  [B] Back to Tweaks Menu" -Color Dark
        Write-Host ""

        $sel = (Read-Host "  Select tweak to apply (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $upperSel = $sel.ToUpper()
        $handled = $true

        try {
            switch ($upperSel) {
                "1" { Set-WinDebloat7Search -DisableBingSearch; Show-WD7ActionResult "Bing search in Start disabled." }
                "2" { Set-WinDebloat7Search -DisableSearchHighlights; Show-WD7ActionResult "Search Highlights disabled." }
                "3" { Set-WinDebloat7Search -DisableSearchHistory; Show-WD7ActionResult "Device search history disabled." }
                "4" { Disable-WinDebloat7WindowsSuggestions; Show-WD7ActionResult "Windows suggestions and ads disabled." }
                "5" { Disable-WinDebloat7SettingsHome; Show-WD7ActionResult "Settings Home page hidden." }
                "6" { Disable-WinDebloat7PhoneLinkStart; Show-WD7ActionResult "Phone Link panel in Start hidden." }
                "A" {
                    Set-WinDebloat7Search -DisableBingSearch -DisableSearchHighlights -DisableSearchHistory
                    Disable-WinDebloat7WindowsSuggestions
                    Disable-WinDebloat7SettingsHome
                    Disable-WinDebloat7PhoneLinkStart
                    Show-WD7ActionResult "All Search & Suggestion debloat tweaks applied."
                }
                "U1" { Set-WinDebloat7Search -EnableBingSearch; Show-WD7ActionResult "Bing search in Start restored." }
                "U2" { Set-WinDebloat7Search -EnableSearchHighlights; Show-WD7ActionResult "Search Highlights restored." }
                "U3" { Set-WinDebloat7Search -EnableSearchHistory; Show-WD7ActionResult "Search history restored." }
                "U4" { Enable-WinDebloat7WindowsSuggestions; Show-WD7ActionResult "Windows suggestions and tips restored." }
                "U5" { Enable-WinDebloat7SettingsHome; Show-WD7ActionResult "Settings Home page restored." }
                "U6" { Enable-WinDebloat7PhoneLinkStart; Show-WD7ActionResult "Phone Link panel in Start restored." }
                "UA" {
                    Set-WinDebloat7Search -EnableBingSearch -EnableSearchHighlights -EnableSearchHistory
                    Enable-WinDebloat7WindowsSuggestions
                    Enable-WinDebloat7SettingsHome
                    Enable-WinDebloat7PhoneLinkStart
                    Show-WD7ActionResult "All Search & Suggestion tweaks reverted to defaults."
                }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid choice '$sel'. Please choose 1-6, A, U-code, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error applying search tweak" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

<#
.SYNOPSIS
    Displays the system Quality-of-Life tweaks submenu.
.OUTPUTS
    [void]
#>
function Show-SystemQoLMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Tweaks & Customization", "System QoL Tweaks")
        Show-WD7Separator -Title "SYSTEM QOL TWEAKS" -Color Secondary
        Write-Host ""

        Write-WD7Host "  [1]  Disable Fast Startup (clean full shutdowns, fixes dual-boot & wake issues)" -Color White
        Write-WD7Host "  [2]  Prevent automatic BitLocker device encryption (24H2+ installs)" -Color White
        Write-WD7Host "  [3]  Disable Delivery Optimization (P2P Windows Update sharing)" -Color White
        Write-WD7Host "  [4]  Disable Storage Sense (automatic background disk cleanup)" -Color White
        Write-WD7Host "  [5]  Prevent auto-reboot after updates while user is signed in" -Color White
        Write-WD7Host "  [6]  Turn off 'Get latest updates as soon as available'" -Color White
        Write-WD7Host "  [7]  Disable Sticky Keys shortcut popup (5x Shift press in games)" -Color White
        Write-WD7Host "  [8]  Disable drag-to-share tray (Windows 11 24H2+)" -Color White
        Write-WD7Host "  [9]  Disable Find My Device location beacon" -Color White
        Write-WD7Host "  [10] Disable Modern Standby networking (prevents battery drain during sleep)" -Color White
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  Undo: Prefix with 'U' to revert (e.g. U1 re-enables Fast Startup, U5 allows auto-reboot)" -Color Info
        Write-WD7Host "  [B] Back to Tweaks Menu" -Color Dark
        Write-Host ""

        $sel = (Read-Host "  Select tweak to apply (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $upperSel = $sel.ToUpper()
        $handled = $true

        try {
            switch ($upperSel) {
                "1" { Disable-WinDebloat7FastStartup; Show-WD7ActionResult "Fast Startup disabled." }
                "2" { Disable-WinDebloat7AutoBitLocker; Show-WD7ActionResult "Automatic BitLocker device encryption prevented." }
                "3" { Disable-WinDebloat7DeliveryOptimization; Show-WD7ActionResult "Delivery Optimization P2P sharing disabled." }
                "4" { Disable-WinDebloat7StorageSense; Show-WD7ActionResult "Storage Sense disabled." }
                "5" { Set-WinDebloat7UpdateBehavior -NoAutoReboot; Show-WD7ActionResult "Auto-reboot after updates while signed in prevented." }
                "6" { Set-WinDebloat7UpdateBehavior -NoEarlyUpdates; Show-WD7ActionResult "'Get latest updates early' turned off." }
                "7" { Disable-WinDebloat7StickyKeysShortcut; Show-WD7ActionResult "Sticky Keys 5x Shift shortcut disabled." }
                "8" { Disable-WinDebloat7ShareDragTray; Show-WD7ActionResult "Drag-to-share tray disabled." }
                "9" { Disable-WinDebloat7FindMyDevice; Show-WD7ActionResult "Find My Device beacon disabled." }
                "10" { Disable-WinDebloat7ModernStandbyNetworking; Show-WD7ActionResult "Modern Standby sleep networking disabled." }

                "U1" { Enable-WinDebloat7FastStartup; Show-WD7ActionResult "Fast Startup restored." }
                "U2" { Enable-WinDebloat7AutoBitLocker; Show-WD7ActionResult "Automatic BitLocker setting restored." }
                "U3" { Enable-WinDebloat7DeliveryOptimization; Show-WD7ActionResult "Delivery Optimization restored." }
                "U4" { Enable-WinDebloat7StorageSense; Show-WD7ActionResult "Storage Sense restored." }
                "U5" { Set-WinDebloat7UpdateBehavior -AllowAutoReboot; Show-WD7ActionResult "Auto-reboot setting restored to Windows defaults." }
                "U6" { Set-WinDebloat7UpdateBehavior -AllowEarlyUpdates; Show-WD7ActionResult "Early update setting restored." }
                "U7" { Enable-WinDebloat7StickyKeysShortcut; Show-WD7ActionResult "Sticky Keys shortcut restored." }
                "U8" { Enable-WinDebloat7ShareDragTray; Show-WD7ActionResult "Drag-to-share tray restored." }
                "U9" { Enable-WinDebloat7FindMyDevice; Show-WD7ActionResult "Find My Device beacon restored." }
                "U10" { Enable-WinDebloat7ModernStandbyNetworking; Show-WD7ActionResult "Modern Standby sleep networking restored." }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid selection '$sel'. Choose 1-10, U1-U10, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error applying QoL tweak" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

<#
.SYNOPSIS
    Displays the advanced component removal menu.
.OUTPUTS
    [void]
#>
function Show-AdvancedRemovalMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Tweaks & Customization", "Advanced Removal")
        Show-WD7Separator -Title "ADVANCED REMOVAL" -Color Warning
        Write-Host ""
        
        Write-WD7Host "  [1] Uninstall OneDrive (Complete removal & explorer clean-up)" -Color White
        Write-WD7Host "  [2] Uninstall Xbox Apps & Gaming Services" -Color White
        Write-WD7Host "  [3] Uninstall Microsoft Edge (Warning: Experimental)" -Color Error
        Write-WD7Host "  [4] Disable Windows 11 AI & Ads (Copilot, Recall, Windows Spotlight)" -Color White
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Tweaks Menu" -Color Dark
        Write-Host ""
        
        $sel = (Read-Host "  Select removal option (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $handled = $true

        try {
            switch ($sel.ToUpper()) {
                "1" {
                    $confirm = (Read-Host "  Are you sure you want to completely uninstall OneDrive? [Y/N]").Trim()
                    if ($confirm -match '^[Yy]') {
                        Uninstall-WinDebloat7OneDrive
                        Show-WD7ActionResult "OneDrive uninstalled."
                    }
                    else {
                        Show-WD7ActionResult -Title "Operation cancelled." -Status Info
                    }
                }
                "2" {
                    $confirm = (Read-Host "  Are you sure you want to uninstall Xbox apps & services? [Y/N]").Trim()
                    if ($confirm -match '^[Yy]') {
                        Uninstall-WinDebloat7Xbox
                        Show-WD7ActionResult "Xbox apps & services removed."
                    }
                    else {
                        Show-WD7ActionResult -Title "Operation cancelled." -Status Info
                    }
                }
                "3" {
                    Write-WD7Host "`n  ⚠️ WARNING: Removing Edge is experimental and may affect WebView2 applications." -Color Error
                    $confirm = (Read-Host "  Type 'YES' to confirm Microsoft Edge removal").Trim()
                    if ($confirm -eq 'YES') {
                        Uninstall-WinDebloat7Edge
                        Show-WD7ActionResult "Microsoft Edge uninstalled."
                    }
                    else {
                        Show-WD7ActionResult -Title "Operation cancelled." -Status Info
                    }
                }
                "4" {
                    Disable-WinDebloat7AIandAds
                    Show-WD7ActionResult "Windows 11 AI & Ad components disabled."
                }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid choice '$sel'. Choose 1-4, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error executing removal" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Service Optimizer
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays the Windows service optimization menu.
.OUTPUTS
    [void]
#>
function Show-ServicesMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Service Optimizer")
        Show-WD7Separator -Title "SERVICE OPTIMIZER" -Color Secondary
        Write-Host ""

        Write-WD7Host "  Preset-based service tuning (managed via config/services.json):" -Color Info
        Write-Host ""
        Write-WD7Host "  [1] Privacy     - Disable telemetry, diagnostics & error reporting services" -Color White
        Write-WD7Host "  [2] Performance - Trim background services (Search indexing, Sensors, Maps)" -Color White
        Write-WD7Host "  [3] Security    - Disable risky legacy services (RemoteRegistry, UPnP, SMBv1)" -Color White
        Write-WD7Host "  [4] Minimal     - Bare essentials only (RetailDemo, Fax, WMP Sharing)" -Color White
        Write-WD7Host "  [5] Gaming      - Trim Xbox services for non-gamers & disable DVR telemetry" -Color White
        Write-Host ""
        Write-WD7Host "  [V] View current status of all managed services" -Color Primary
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""

        $sel = (Read-Host "  Select option (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        if ($sel -match '^[Vv]$') {
            Write-WD7Host "`n  Querying services (this may take a moment)..." -Color Info
            Get-WinDebloat7ServiceStatus | Sort-Object Category, Name |
                Format-Table Name, Status, CurrentStartup, RecommendedStartup, Category -AutoSize | Out-Host
            Wait-WD7UserPrompt "Press Enter to return to services menu..."
            continue
        }

        $preset = switch ($sel) {
            "1" { "Privacy" }
            "2" { "Performance" }
            "3" { "Security" }
            "4" { "Minimal" }
            "5" { "Gaming" }
            default { $null }
        }

        if ($preset) {
            $confirm = (Read-Host "  Apply the '$preset' service preset now? [Y/N]").Trim()
            if ($confirm -match '^[Yy]') {
                try {
                    Set-WinDebloat7Services -Preset $preset -Confirm:$false
                    Show-WD7ActionResult -Title "'$preset' service preset applied successfully."
                }
                catch {
                    Show-WD7ActionResult -Title "Error applying service preset" -Detail $_.Exception.Message -Status Error
                }
            }
            else {
                Show-WD7ActionResult -Title "Operation cancelled." -Status Info
            }
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
        else {
            Write-WD7Host "`n  [!] Invalid choice '$sel'. Choose 1-5, V, or B to return." -Color Warning
            Start-Sleep -Milliseconds 1200
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Profile Selector UX & Preview
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Retrieves metadata and description for a profile YAML file.
.PARAMETER FilePath
    Full path to the profile YAML file.
.OUTPUTS
    [pscustomobject]
#>
function Get-WinDebloatProfileSummary {
    [CmdletBinding()]
    param([string]$FilePath)
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $estTimes = @{
        'conservative' = '~1-2 min'
        'moderate'     = '~2-3 min'
        'gaming'       = '~3-5 min'
        'performance'  = '~2-3 min'
        'essentials'   = '~3-8 min'
    }
    
    $summary = [ordered]@{
        BaseName    = $baseName
        Name        = (Get-Culture).TextInfo.ToTitleCase($baseName)
        Description = ""
        TargetOS    = "Windows 10, Windows 11"
        EstTime     = if ($estTimes.ContainsKey($baseName.ToLower())) { $estTimes[$baseName.ToLower()] } else { "~2-4 min" }
        Mode        = "Custom"
        FilePath    = $FilePath
    }

    try {
        if (Get-Command Import-WinDebloat7Config -ErrorAction SilentlyContinue) {
            $cfg = Import-WinDebloat7Config -Path $FilePath -SkipDependencyCheck
            if ($cfg.metadata) {
                if ($cfg.metadata.name) { $summary.Name = $cfg.metadata.name }
                if ($cfg.metadata.description) { $summary.Description = $cfg.metadata.description }
                if ($cfg.metadata.target_os) { $summary.TargetOS = ($cfg.metadata.target_os -join ", ") }
            }
            if ($cfg.bloatware -and $cfg.bloatware.removal_mode) {
                $summary.Mode = "$($cfg.bloatware.removal_mode) Bloatware Removal"
            }
            elseif ($cfg.software -and $cfg.software.install_list) {
                $summary.Mode = "Software Installer ($(@($cfg.software.install_list).Count) packages)"
            }
        }
    }
    catch {
        Write-Verbose "Could not parse profile YAML for summary: $($_.Exception.Message)"
    }
    
    if (-not $summary.Description) {
        $summary.Description = switch ($baseName.ToLower()) {
            'conservative' { "Minimal changes for maximum stability. Best for work and enterprise environments." }
            'moderate'     { "Recommended balance of performance and functionality. Removes common bloat." }
            'gaming'       { "Maximum performance for gamers. Aggressive bloatware removal with gaming settings." }
            'performance'  { "Optimized for low-RAM systems, VMs, and maximum responsiveness." }
            'essentials'   { "One-click post-debloat setup: installs recommended runtimes, browsers, and tools." }
            default        { "Custom configuration profile." }
        }
    }

    return [pscustomobject]$summary
}

<#
.SYNOPSIS
    Displays the configuration profile selection menu with rich metadata.
.OUTPUTS
    [void]
#>
function Show-ProfileSelection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Profile Selection")
        Show-WD7Separator -Title "SELECT OPTIMIZATION PROFILE" -Color Secondary
        Write-Host ""
        
        $profileFiles = Get-ChildItem "$PSScriptRoot\..\..\profiles\*.yaml" |
            Where-Object { $_.BaseName -notin @('schema', 'bloatware-list') } |
            Sort-Object Name

        # Detect hardware recommendation
        $recProfile = ""
        try {
            if (Get-Command Get-WinDebloat7RecommendedProfile -ErrorAction SilentlyContinue) {
                $recProfile = Get-WinDebloat7RecommendedProfile
            }
        }
        catch {
            Write-Verbose "Could not detect recommended profile: $($_.Exception.Message)"
        }

        $i = 1
        $profileMap = @{}
        
        foreach ($pFile in $profileFiles) {
            $pSummary = Get-WinDebloat7ProfileSummary -FilePath $pFile.FullName
            $isRec = ($pSummary.Name -ieq $recProfile -or $pSummary.BaseName -ieq $recProfile)

            Write-WD7Host "  [$i] $($pSummary.Name)" -Color White -NoNewline
            if ($isRec) {
                Write-WD7Host "  ★ RECOMMENDED FOR THIS SYSTEM ★" -Color Success
            }
            else {
                Write-Host ""
            }

            Write-WD7Host "      Description: $($pSummary.Description)" -Color Info
            Write-WD7Host "      Target OS:   $($pSummary.TargetOS) | Est. Time: $($pSummary.EstTime)" -Color Dark
            Write-WD7Host "      Scope:       $($pSummary.Mode)" -Color Dark
            Write-Host ""

            $profileMap[$i] = $pFile.FullName
            $i++
        }
        
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""

        $sel = (Read-Host "  Select Profile number (or 'B' to return)").Trim()
        
        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        if ($sel -match '^\d+$' -and $profileMap.ContainsKey([int]$sel)) {
            Invoke-Profile $profileMap[[int]$sel]
        }
        else {
            Write-WD7Host "`n  [!] Invalid selection '$sel'. Please enter a number between 1 and $($profileFiles.Count), or B to return." -Color Warning
            Start-Sleep -Milliseconds 1200
        }
    }
}

<#
.SYNOPSIS
    Displays the preview action plan for a loaded profile.
.OUTPUTS
    [void]
#>
function Show-ProfilePreview {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][object]$Config)

    Show-WD7Header
    Show-WD7Breadcrumb -Path @("Main Menu", "Profile Selection", "Preview: $($Config.metadata.name)")
    Show-WD7Separator -Title "PREVIEW: $($Config.metadata.name)" -Color Secondary
    Write-Host ""
    Write-WD7Host "  Read-only action plan - no system changes have been made yet." -Color Info
    Write-Host ""

    $plan = Get-WinDebloat7ProfilePlan -Config $Config
    $lastSection = $null
    foreach ($row in $plan) {
        if ($row.Section -ne $lastSection) {
            Write-Host ""
            Write-WD7Host "  [$($row.Section)]" -Color Primary -Bold
            $lastSection = $row.Section
        }
        Write-WD7Host "    • " -Color Secondary -NoNewline
        Write-WD7Host "$($row.Action)" -Color White
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Applies an optimization profile after user confirmation.
.OUTPUTS
    [void]
#>
function Invoke-Profile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][string]$Path)

    try {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Profile Selection", "Loading Profile")
        Write-WD7Host "  Loading Profile: $Path" -Color Info
        $config = Import-WinDebloat7Config -Path $Path

        # Preview first: show the full action plan, then confirm
        Show-ProfilePreview -Config $config
        
        Write-WD7Host "  ─────────────────────────────────────────────────────────────────────────────" -Color Dark
        $confirm = (Read-Host "  Apply this profile now? [Y/N]").Trim()
        if ($confirm -notmatch '^[Yy]') {
            Show-WD7ActionResult -Title "Optimization cancelled." -Detail "No changes were made to your system." -Status Info
            Wait-WD7UserPrompt "Press Enter to return to profile menu..."
            return
        }

        Write-Host ""
        Show-WD7Separator -Title "APPLYING OPTIMIZATION" -Color Primary
        Write-WD7Host "`n  Applying profile '$($config.metadata.name)'..." -Color Primary
        Write-Host ""

        # 1. Safety snapshot
        Write-WD7Host "  [1/7] Creating encrypted safety snapshot..." -Color Info
        New-WinDebloat7Snapshot -Name "Pre-$($config.metadata.name)" -Description "Before applying profile $($config.metadata.name)" -Encrypt | Out-Null
        Write-WD7Host "        ✔ Registry safety snapshot recorded." -Color Success

        # 2. Modules execution
        Write-WD7Host "  [2/7] Removing bloatware packages..." -Color Info
        Remove-WinDebloat7Bloatware -Config $config

        Write-WD7Host "  [3/7] Applying privacy & telemetry hardening..." -Color Info
        Set-WinDebloat7Privacy -Config $config

        Write-WD7Host "  [4/7] Applying system security & attack surface reduction..." -Color Info
        Set-WinDebloat7Security -Config $config

        Write-WD7Host "  [5/7] Tuning performance & power settings..." -Color Info
        Set-WinDebloat7Performance -Config $config

        Write-WD7Host "  [6/7] Configuring network & DNS privacy..." -Color Info
        Set-WinDebloat7Network -Config $config

        Write-WD7Host "  [7/7] Applying system & QoL customizations..." -Color Info
        Set-WinDebloat7SystemTweaks -Config $config

        if ($config.software -and $config.software.install_list -and @($config.software.install_list).Count -gt 0) {
            Write-WD7Host "  [+] Installing profile software packages..." -Color Info
            Install-WinDebloat7ProfileSoftware -Config $config
        }

        Write-Host ""
        Show-WD7Separator -Title "OPTIMIZATION COMPLETE" -Color Success
        Write-WD7Host "  ✔ Profile '$($config.metadata.name)' was applied successfully!" -Color Success
        Write-WD7Host "  ℹ A restore snapshot was saved. You can rollback anytime via Snapshot Management." -Color Info
        Write-WD7Host "  ℹ Some tweaks may require a sign-out or Explorer restart to take full effect." -Color Dark
        Wait-WD7UserPrompt "Press Enter to return to menu..."

    }
    catch {
        Write-Host ""
        Show-WD7Separator -Title "OPTIMIZATION ERROR" -Color Error
        Write-WD7Host "  ✖ Error applying profile: $($_.Exception.Message)" -Color Error
        Wait-WD7UserPrompt "Press Enter to continue..."
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# System Information & Benchmark
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays hardware and operating system details.
.OUTPUTS
    [void]
#>
function Show-SystemInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Show-WD7Header
    Show-WD7Breadcrumb -Path @("Main Menu", "System Information")
    $ver = Get-WindowsVersionInfo
    
    Show-WD7Separator -Title "SYSTEM INFORMATION" -Color Secondary
    Write-Host ""
    Write-WD7Host "  OS Edition:      " -Color Info -NoNewline
    Write-WD7Host $ver.ProductName -Color White
    Write-WD7Host "  Release Version: " -Color Info -NoNewline
    Write-WD7Host "$($ver.DisplayVersion) ($($ver.FriendlyName))" -Color White
    Write-WD7Host "  OS Build Number: " -Color Info -NoNewline
    Write-WD7Host $ver.BuildNumber -Color White
    Write-WD7Host "  Windows 11:      " -Color Info -NoNewline
    Write-WD7Host $(if ($ver.IsWindows11) { "Yes" } else { "No" }) -Color White
    Write-Host ""
    Show-WD7Separator
    
    Wait-WD7UserPrompt "Press Enter to return to main menu..."
}

<#
.SYNOPSIS
    Runs the built-in system benchmark suite.
.OUTPUTS
    [void]
#>
function Invoke-WinDebloatBenchmark {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Show-WD7Header
    Show-WD7Breadcrumb -Path @("Main Menu", "System Benchmark")
    Show-WD7Separator -Title "BENCHMARKING" -Color Secondary
    Write-Host ""
    Write-WD7Host "  Captures current system metrics and saves a benchmark report to your Desktop." -Color Info
    Write-WD7Host "  For accurate comparison, run this before and after optimization." -Color Info
    Write-Host ""
    
    $run = (Read-Host "  Run Benchmark now? [Y/N]").Trim()
    if ($run -notmatch '^[Yy]') {
        Show-WD7ActionResult -Title "Benchmark cancelled." -Status Info
        Wait-WD7UserPrompt "Press Enter to return to main menu..."
        return
    }
    
    try {
        Write-WD7Host "`n  Measuring system performance..." -Color Primary
        $metrics = Measure-WinDebloat7System
        
        Write-Host ""
        Show-WD7Separator -Title "BENCHMARK RESULTS" -Color Success
        $metrics | Format-List | Out-String | Write-Host
        
        # Save benchmark report to Desktop
        $reportPath = "$env:USERPROFILE\Desktop\Win-Debloat_Benchmark_$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        $metrics | Out-File $reportPath
        Show-WD7ActionResult -Title "Benchmark completed." -Detail "Report saved to: $reportPath" -Status Success
    }
    catch {
        Show-WD7ActionResult -Title "Error executing benchmark" -Detail $_.Exception.Message -Status Error
    }
    
    Wait-WD7UserPrompt "Press Enter to return to main menu..."
}

# ─────────────────────────────────────────────────────────────────────────────
# Snapshot & Rollback Management
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays the system snapshot and rollback management menu.
.OUTPUTS
    [void]
#>
function Show-SnapshotMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Snapshot Management")
        Show-WD7Separator -Title "SNAPSHOT MANAGEMENT" -Color Secondary
        Write-Host ""
        
        $snaps = @(Get-WinDebloat7Snapshot)
        if ($snaps.Count -eq 0) {
            Write-WD7Host "  No saved snapshots found." -Color Info
        }
        else {
            Write-WD7Host "  Saved Snapshots ($($snaps.Count)):" -Color Primary
            Write-Host ""
            $snaps | Format-Table @{Label="Timestamp"; Expression={$_.Timestamp}}, @{Label="Name"; Expression={$_.Name}}, @{Label="Snapshot ID"; Expression={$_.Id}} -AutoSize | Out-String | Write-Host
        }
        
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [1] Create New Snapshot   [2] Restore Snapshot   [3] Visual Diff Viewer   [B] Back" -Color White
        Write-WD7Host "  (Shortcuts: [C] Create, [R] Restore, [D] Diff Viewer, [B] Back)" -Color Dark
        Write-Host ""

        $c = (Read-Host "  Select option").Trim().ToUpper()
        
        switch ($c) {
            { $_ -in "1", "C", "CREATE" } {
                $snapName = (Read-Host "`n  Enter snapshot name (default: Manual-User)").Trim()
                if (-not $snapName) { $snapName = "Manual-User" }
                try {
                    $newSnap = New-WinDebloat7Snapshot -Name $snapName -Description "Created via interactive menu" -Encrypt
                    Show-WD7ActionResult -Title "Snapshot created successfully." -Detail "ID: $($newSnap.Id)" -Status Success
                }
                catch {
                    Show-WD7ActionResult -Title "Error creating snapshot" -Detail $_.Exception.Message -Status Error
                }
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
            { $_ -in "2", "R", "RESTORE" } {
                if ($snaps.Count -eq 0) {
                    Write-WD7Host "`n  [!] No snapshots available to restore." -Color Warning
                    Start-Sleep -Milliseconds 1200
                    continue
                }
                $id = (Read-Host "`n  Enter Snapshot ID to restore (or Enter to cancel)").Trim()
                if ($id) {
                    $matched = $snaps | Where-Object { $_.Id -eq $id -or $_.Id -like "$id*" } | Select-Object -First 1
                    if ($matched) {
                        $confirm = (Read-Host "  Confirm restore of snapshot '$($matched.Name)' ($($matched.Id))? [Y/N]").Trim()
                        if ($confirm -match '^[Yy]') {
                            try {
                                Restore-WinDebloat7Snapshot -SnapshotId $matched.Id
                                Show-WD7ActionResult -Title "Snapshot restored successfully." -Status Success
                            }
                            catch {
                                Show-WD7ActionResult -Title "Error restoring snapshot" -Detail $_.Exception.Message -Status Error
                            }
                        }
                        else {
                            Show-WD7ActionResult -Title "Restore cancelled." -Status Info
                        }
                    }
                    else {
                        Show-WD7ActionResult -Title "Snapshot not found" -Detail "No snapshot matching ID '$id' was found." -Status Warning
                    }
                    Wait-WD7UserPrompt "Press Enter to continue..."
                }
            }
            { $_ -in "3", "D", "DIFF" } {
                if ($snaps.Count -eq 0) {
                    Write-WD7Host "`n  [!] No snapshots available to compare against current state." -Color Warning
                    Start-Sleep -Milliseconds 1200
                    continue
                }
                $id = (Read-Host "`n  Enter Baseline Snapshot ID (or press Enter for most recent)").Trim()
                if (-not $id) {
                    $selected = $snaps | Select-Object -Last 1
                }
                else {
                    $selected = $snaps | Where-Object { $_.Id -eq $id -or $_.Id -like "$id*" } | Select-Object -First 1
                }
                if ($selected) {
                    Show-WinDebloatDiffViewer -BaseSnapshot $selected.Id
                }
                else {
                    Show-WD7ActionResult -Title "Snapshot not found" -Detail "No snapshot matching ID '$id' was found." -Status Warning
                    Wait-WD7UserPrompt "Press Enter to continue..."
                }
            }
            { $_ -in "B", "BACK", "0", "" } {
                return
            }
            default {
                Write-WD7Host "`n  [!] Invalid choice '$c'. Choose 1 (Create), 2 (Restore), or B to return." -Color Warning
                Start-Sleep -Milliseconds 1000
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Network & Privacy Settings
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays network and DNS privacy settings menu.
.OUTPUTS
    [void]
#>
function Show-NetworkPrivacyMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Network & Privacy")
        Show-WD7Separator -Title "NETWORK & PRIVACY" -Color Secondary
        Write-Host ""
        
        # Current status readout
        $netStatus = Get-WinDebloat7NetworkStatus | Select-Object -First 1
        $hostsStatus = Get-WinDebloat7FirewallStatus
        $tasks = @(Get-WinDebloat7TelemetryTasks -Mode All)
        $enabledTasks = ($tasks | Where-Object { $_.Enabled }).Count
        
        Write-WD7Host "  Current Status:" -Color Primary
        Write-WD7Host "    • DNS Provider:      $($netStatus.DNSProvider)" -Color Info
        Write-WD7Host "    • IPv6 Enabled:      $($netStatus.IPv6Enabled)" -Color Info
        Write-WD7Host "    • Firewall Blocking: $(if ($hostsStatus.TelemetryBlocked) { 'Active' } else { 'Inactive' })" -Color Info
        Write-WD7Host "    • Telemetry Tasks:   $enabledTasks enabled" -Color Info
        Write-Host ""
        
        Write-WD7Host "  Options:" -Color Primary
        Write-WD7Host "  [1] Change DNS Server (Cloudflare, Google, Quad9, AdGuard, OpenDNS, DHCP)" -Color White
        Write-WD7Host "  [2] Disable IPv6" -Color White
        Write-WD7Host "  [3] Block Telemetry Domains (Windows Firewall)" -Color White
        Write-WD7Host "  [4] Disable Telemetry Scheduled Tasks (Safe Mode)" -Color White
        Write-WD7Host "  [5] Disable Telemetry Scheduled Tasks (Aggressive Mode)" -Color White
        Write-WD7Host "  [6] View Blocked Telemetry Domains" -Color White
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""
        
        $sel = (Read-Host "  Select option (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $handled = $true

        try {
            switch ($sel.ToUpper()) {
                "1" {
                    Show-WD7Header
                    Show-WD7Breadcrumb -Path @("Main Menu", "Network & Privacy", "DNS Configuration")
                    Show-WD7Separator -Title "DNS PROVIDERS" -Color Secondary
                    Write-Host ""
                    Write-WD7Host "  [1] Cloudflare (1.1.1.1 - Fast & Privacy-focused)" -Color White
                    Write-WD7Host "  [2] Google (8.8.8.8 - High Reliability)" -Color White
                    Write-WD7Host "  [3] Quad9 (9.9.9.9 - Security & Threat-blocking)" -Color White
                    Write-WD7Host "  [4] AdGuard (94.140.14.14 - Ad & Tracker Blocking)" -Color White
                    Write-WD7Host "  [5] OpenDNS (208.67.222.222)" -Color White
                    Write-WD7Host "  [6] Reset to Automatic (DHCP)" -Color White
                    Write-Host ""
                    Write-WD7Host "  [B] Cancel & Back" -Color Dark
                    Write-Host ""
                    
                    $dns = (Read-Host "  Select DNS provider").Trim().ToUpper()
                    switch ($dns) {
                        "1" { Set-WinDebloat7DNS -Provider Cloudflare; Show-WD7ActionResult "DNS set to Cloudflare (1.1.1.1)." }
                        "2" { Set-WinDebloat7DNS -Provider Google; Show-WD7ActionResult "DNS set to Google (8.8.8.8)." }
                        "3" { Set-WinDebloat7DNS -Provider Quad9; Show-WD7ActionResult "DNS set to Quad9 (9.9.9.9)." }
                        "4" { Set-WinDebloat7DNS -Provider AdGuard; Show-WD7ActionResult "DNS set to AdGuard (Ad-blocking)." }
                        "5" { Set-WinDebloat7DNS -Provider OpenDNS; Show-WD7ActionResult "DNS set to OpenDNS." }
                        "6" { Set-WinDebloat7DNS -Provider Reset; Show-WD7ActionResult "DNS reset to DHCP (Automatic)." }
                        { $_ -in "B", "BACK", "0", "" } { Show-WD7ActionResult -Title "DNS configuration unchanged." -Status Info }
                        default { Write-WD7Host "`n  [!] Invalid choice '$dns'." -Color Warning }
                    }
                }
                "2" {
                    Disable-WinDebloat7IPv6
                    Show-WD7ActionResult "IPv6 bindings disabled."
                }
                "3" {
                    Add-WinDebloat7FirewallBlock
                    Show-WD7ActionResult "Telemetry domains blocked via Windows Firewall."
                }
                "4" {
                    Disable-WinDebloat7TelemetryTasks -Mode Safe
                    Show-WD7ActionResult "Safe telemetry scheduled tasks disabled."
                }
                "5" {
                    Disable-WinDebloat7TelemetryTasks -Mode Aggressive
                    Show-WD7ActionResult "Aggressive telemetry scheduled tasks disabled."
                }
                "6" {
                    $domains = Get-WinDebloat7TelemetryDomains
                    Show-WD7Header
                    Show-WD7Breadcrumb -Path @("Main Menu", "Network & Privacy", "Telemetry Domains")
                    Show-WD7Separator -Title "BLOCKED TELEMETRY DOMAINS ($($domains.Count))" -Color Secondary
                    Write-Host ""
                    $domains | ForEach-Object { Write-WD7Host "    • $_" -Color Dark }
                }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid choice '$sel'. Choose 1-6, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error in Network & Privacy" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# System Repair, Features & Third-Party Tools
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Displays the Windows system and network repair menu.
.OUTPUTS
    [void]
#>
function Show-RepairMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "System Repair Tools")
        Show-WD7Separator -Title "SYSTEM REPAIR TOOLS" -Color Warning
        Write-Host ""
        
        Write-WD7Host "  [1] Repair Windows Component Store (SFC + DISM RestoreHealth)" -Color White
        Write-WD7Host "  [2] Reset Network Stack (IP / DNS / Winsock reset)" -Color White
        Write-WD7Host "  [3] Reset Windows Update Components & Cache" -Color White
        Write-WD7Host "  [4] Enable Defender PUA Protection (Potentially Unwanted Apps)" -Color White
        Write-WD7Host "  [5] Disable SMBv1 Protocol (Legacy vulnerability mitigation)" -Color White
        Write-WD7Host "  [6] Enterprise SMB Hardening Suite (Signing, NTLM Blocking, Client Security)" -Color Primary
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""
        
        $sel = (Read-Host "  Select repair option (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $handled = $true

        try {
            switch ($sel.ToUpper()) {
                "1" {
                    Write-WD7Host "`n  Running SFC & DISM repair (this may take several minutes)..." -Color Primary
                    Repair-WinDebloat7System
                    Show-WD7ActionResult "Windows system image repair completed."
                }
                "2" {
                    Reset-WinDebloat7Network
                    Show-WD7ActionResult "Network stack reset completed."
                }
                "3" {
                    Reset-WinDebloat7Update
                    Show-WD7ActionResult "Windows Update components reset."
                }
                "4" {
                    Enable-WinDebloat7PUAProtection
                    Show-WD7ActionResult "Defender PUA Protection enabled."
                }
                "5" {
                    Disable-WinDebloat7SMBv1
                    Show-WD7ActionResult "SMBv1 protocol disabled."
                }
                "6" {
                    Show-SMBHardeningMenu
                }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid choice '$sel'. Choose 1-6, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error running repair tool" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

<#
.SYNOPSIS
    Displays the Windows optional features management menu.
.OUTPUTS
    [void]
#>
function Show-FeaturesMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Windows Features Manager")
        Show-WD7Separator -Title "WINDOWS FEATURES" -Color Secondary
        Write-Host ""
        
        Write-WD7Host "  [1] Disable Bloated Optional Features (Fax, IIS, WorkFolders, XPS)" -Color White
        Write-WD7Host "  [2] Enable Optional Features (Revert to default enabled state)" -Color White
        Write-WD7Host "  [3] Remove Legacy Capabilities (WordPad, Math Recognizer, Steps Recorder)" -Color White
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""
        
        $sel = (Read-Host "  Select option (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $handled = $true

        try {
            switch ($sel.ToUpper()) {
                "1" {
                    Set-WinDebloat7OptionalFeatures
                    Show-WD7ActionResult "Bloated optional features disabled."
                }
                "2" {
                    Set-WinDebloat7OptionalFeatures -Enable
                    Show-WD7ActionResult "Optional features re-enabled."
                }
                "3" {
                    Remove-WinDebloat7Capabilities
                    Show-WD7ActionResult "Legacy capabilities removed."
                }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid choice '$sel'. Choose 1-3, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error managing features" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

<#
.SYNOPSIS
    Displays third-party debloating and driver integration tools menu.
.OUTPUTS
    [void]
#>
function Show-IntegrationsMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Main Menu", "Third Party Tools")
        Show-WD7Separator -Title "THIRD PARTY TOOLS" -Color Warning
        Write-Host ""
        
        Write-WD7Host "  [1] O&O ShutUp10++ (Advanced Privacy & Telemetry Hardening)" -Color White
        Write-WD7Host "  [2] Malwarebytes AdwCleaner (Adware & PUP Removal)" -Color White
        Write-WD7Host "  [3] Snappy Driver Installer Origin (Automated Driver Updates)" -Color White
        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""
        
        $sel = (Read-Host "  Select tool to launch (or 'B' to return)").Trim()

        if ($sel -match '^(B|BACK|0)$' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }

        $handled = $true

        try {
            switch ($sel.ToUpper()) {
                "1" {
                    Invoke-WinDebloat7ShutUp10
                    Show-WD7ActionResult "O&O ShutUp10++ finished."
                }
                "2" {
                    Invoke-WinDebloat7AdwCleaner
                    Show-WD7ActionResult "Malwarebytes AdwCleaner finished."
                }
                "3" {
                    Update-WinDebloat7SDIO
                    Show-WD7ActionResult "Snappy Driver Installer Origin finished."
                }
                default {
                    $handled = $false
                    Write-WD7Host "`n  [!] Invalid choice '$sel'. Choose 1-3, or B to return." -Color Warning
                    Start-Sleep -Milliseconds 1200
                }
            }

            if ($handled) {
                Wait-WD7UserPrompt "Press Enter to continue..."
            }
        }
        catch {
            Show-WD7ActionResult -Title "Error launching integration tool" -Detail $_.Exception.Message -Status Error
            Wait-WD7UserPrompt "Press Enter to continue..."
        }
    }
}

<#
.SYNOPSIS
    Displays a colorized visual diff between two system states or previews changes.
.DESCRIPTION
    Renders changes with ANSI syntax coloring (Green = Added, Red = Removed, Yellow = Modified).
    Works in both interactive TUI environments and non-interactive CI tests (returns diff object).
.PARAMETER BaseSnapshot
    The baseline snapshot object or snapshot ID.
.PARAMETER TargetSnapshot
    The target snapshot object or snapshot ID (defaults to current system state if omitted).
.PARAMETER PassThru
    If specified, returns the raw structured diff object.
#>
function Show-WinDebloatDiffViewer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI Diff Visualizer')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Alias('Diff', 'DiffItems', 'Baseline')]
        $BaseSnapshot,

        [Parameter(Position = 1)]
        [Alias('Current')]
        $TargetSnapshot,

        [switch]$PassThru
    )

    if ($BaseSnapshot -is [string]) {
        $BaseSnapshot = Get-WinDebloat7Snapshot -Id $BaseSnapshot
    }
    if ($TargetSnapshot -is [string]) {
        $TargetSnapshot = Get-WinDebloat7Snapshot -Id $TargetSnapshot
    }

    if ($BaseSnapshot -and ($BaseSnapshot.PSObject.Properties['AddedKeys'] -or $BaseSnapshot.PSObject.Properties['ModifiedValues'])) {
        $diff = $BaseSnapshot
    }
    elseif ($BaseSnapshot -is [System.Collections.IEnumerable] -and $BaseSnapshot -isnot [string] -and ($BaseSnapshot.GetType().Name -ne 'SystemSnapshot')) {
        $diff = [PSCustomObject]@{
            AddedKeys       = @()
            RemovedKeys     = @()
            ModifiedValues  = @($BaseSnapshot)
            ServicesChanged = @()
        }
    }
    elseif (-not $TargetSnapshot -and $BaseSnapshot) {
        $diff = Compare-WinDebloat7Snapshot -Baseline $BaseSnapshot
    }
    elseif ($BaseSnapshot -and $TargetSnapshot) {
        $diff = Compare-WinDebloat7Snapshot -Baseline $BaseSnapshot -Current $TargetSnapshot
    }
    else {
        $diff = [PSCustomObject]@{
            AddedKeys       = @()
            RemovedKeys     = @()
            ModifiedValues  = @()
            ServicesChanged = @()
        }
    }

    if ($PassThru -or (Test-WDHeadless) -or [Console]::IsOutputRedirected) {
        return $diff
    }

    # Format diff into structured text lines
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("")
    $lines.Add("  Comparing Snapshot State: $($BaseSnapshot.Name ?? 'Baseline') ──► $($TargetSnapshot.Name ?? 'Current System')")
    $lines.Add("")

    $addedCount = if ($diff.AddedKeys) { $diff.AddedKeys.Count } else { 0 }
    $removedCount = if ($diff.RemovedKeys) { $diff.RemovedKeys.Count } else { 0 }
    $modifiedCount = if ($diff.ModifiedValues) { $diff.ModifiedValues.Count } else { 0 }
    $servicesCount = if ($diff.ServicesChanged) { $diff.ServicesChanged.Count } else { 0 }
    $hasChanges = ($addedCount + $removedCount + $modifiedCount + $servicesCount) -gt 0

    $cyan = "$([char]27)[38;2;0;212;255m"
    $green = "$([char]27)[38;2;0;255;136m"
    $red = "$([char]27)[38;2;255;51;102m"
    $yellow = "$([char]27)[38;2;255;170;0m"
    $magenta = "$([char]27)[38;2;123;44;191m"
    $reset = "$([char]27)[0m"

    $lines.Add("  ${cyan}╭────────────────────────────────────────────────────────────────────────────╮${reset}")
    $lines.Add("  ${cyan}│${reset} ${green}[+] Added: $addedCount${reset}  ${cyan}│${reset}  ${red}[-] Removed: $removedCount${reset}  ${cyan}│${reset}  ${yellow}[~] Modified: $modifiedCount${reset}  ${cyan}│${reset}  ${magenta}[*] Services: $servicesCount${reset} ${cyan}│${reset}")
    $lines.Add("  ${cyan}╰────────────────────────────────────────────────────────────────────────────╯${reset}")
    $lines.Add("")

    if ($diff.AddedKeys -and $diff.AddedKeys.Count -gt 0) {
        $lines.Add("  ${green}[+] Added Registry Keys ($($diff.AddedKeys.Count)):${reset}")
        foreach ($k in $diff.AddedKeys) {
            $lines.Add("      ${green}+ $k${reset}")
        }
        $lines.Add("")
    }

    if ($diff.RemovedKeys -and $diff.RemovedKeys.Count -gt 0) {
        $lines.Add("  ${red}[-] Removed Registry Keys ($($diff.RemovedKeys.Count)):${reset}")
        foreach ($k in $diff.RemovedKeys) {
            $lines.Add("      ${red}- $k${reset}")
        }
        $lines.Add("")
    }

    if ($diff.ModifiedValues -and $diff.ModifiedValues.Count -gt 0) {
        $lines.Add("  ${yellow}[~] Modified Registry Values ($($diff.ModifiedValues.Count)):${reset}")
        foreach ($v in $diff.ModifiedValues) {
            $key = $v.Key
            $val = $v.ValueName
            $old = $v.BaselineValue
            $new = $v.CurrentValue
            $lines.Add("      ${yellow}~ $key\$($val): '$old' ──► '$new'${reset}")
        }
        $lines.Add("")
    }

    if ($diff.ServicesChanged -and $diff.ServicesChanged.Count -gt 0) {
        $lines.Add("  ${cyan}[*] Service Startup Changes ($($diff.ServicesChanged.Count)):${reset}")
        foreach ($s in $diff.ServicesChanged) {
            $lines.Add("      ${cyan}* $($s.Name): $($s.BaselineStartType) ──► $($s.CurrentStartType)${reset}")
        }
        $lines.Add("")
    }

    if (-not $hasChanges) {
        $lines.Add("  ${green}✔ Baseline and target state are identical (100% matched - no differences).${reset}")
        $lines.Add("")
    }

    # Render Header
    Show-WD7Header
    Show-WD7Breadcrumb -Path @("Main Menu", "Disaster Recovery", "Visual Diff Viewer")
    Show-WD7Separator -Title "VISUAL STATE DIFF VIEWER" -Color Secondary

    # Viewport determination
    $winHeight = 24
    try {
        if ([Console]::WindowHeight -gt 12) {
            $winHeight = [Console]::WindowHeight - 6
        }
    } catch {
        $null = $_
    }

    if ($lines.Count -le $winHeight) {
        foreach ($l in $lines) { Write-Host $l }
        Wait-WD7UserPrompt "Press Enter to return..."
        return $diff
    }

    # Interactive scrollable viewport pager
    $topLine = 0
    $maxTop = [Math]::Max(0, $lines.Count - $winHeight)

    Hide-WDCursor
    try {
        while ($true) {
            Show-WD7Header
            Show-WD7Breadcrumb -Path @("Main Menu", "Disaster Recovery", "Visual Diff Viewer")
            Show-WD7Separator -Title "VISUAL STATE DIFF VIEWER" -Color Secondary

            $endLine = [Math]::Min($lines.Count - 1, $topLine + $winHeight - 1)
            for ($i = $topLine; $i -le $endLine; $i++) {
                Write-Host $lines[$i]
            }

            $pct = [int]((($endLine + 1) / $lines.Count) * 100)
            Write-Host "$([char]27)[7m  [↑/↓, PgUp/PgDn, Home/End: Scroll | Lines $($topLine + 1)-$($endLine + 1) of $($lines.Count) ($pct%) | Q/Esc/Enter: Return]  $([char]27)[0m"

            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($topLine -gt 0) { $topLine-- }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($topLine -lt $maxTop) { $topLine++ }
                }
                ([ConsoleKey]::PageUp) {
                    $topLine = [Math]::Max(0, $topLine - $winHeight)
                }
                ([ConsoleKey]::PageDown) {
                    $topLine = [Math]::Min($maxTop, $topLine + $winHeight)
                }
                ([ConsoleKey]::Home) {
                    $topLine = 0
                }
                ([ConsoleKey]::End) {
                    $topLine = $maxTop
                }
                { $_ -in [ConsoleKey]::Q, [ConsoleKey]::Escape, [ConsoleKey]::Enter } {
                    return $diff
                }
            }
        }
    }
    catch {
        foreach ($l in $lines) { Write-Host $l }
        Wait-WD7UserPrompt "Press Enter to return..."
    }
    finally {
        Show-WDCursor
    }

    return $diff
}

<#
.SYNOPSIS
    Interactive Modern TUI for declarative software and essential app installation.
.DESCRIPTION
    Loads config/apps.yaml, presents categories, allows multi-select checkboxes,
    and installs selected packages silently via Winget or Chocolatey.
.OUTPUTS
    [void]
#>
function Show-SoftwareCatalogMenu {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive TUI')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (Test-WDHeadless) { return }

    $catalog = Get-WinDebloatAppCatalog
    if (-not $catalog -or -not $catalog.categories) {
        Show-WD7ActionResult -Title "Application Catalog Not Found" -Detail "Unable to load config/apps.yaml." -Status Error
        Wait-WD7UserPrompt "Press Enter to return..."
        return
    }

    $selectionState = [System.Collections.Generic.Dictionary[string, bool]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($cat in $catalog.categories) {
        foreach ($app in $cat.apps) {
            $selectionState[$app.id] = [bool]$app.recommended
        }
    }

    while ($true) {
        Show-WD7Header
        Show-WD7Breadcrumb -Path @("Win-Debloat", "Main Menu", "Software Catalog")
        Show-WD7Separator -Title "SOFTWARE CATALOG & ESSENTIAL APPS" -Color Primary
        Write-Host ""

        $selectedCount = ($selectionState.Values | Where-Object { $_ -eq $true }).Count
        $totalApps = $selectionState.Count

        Write-WD7Host "  Select a category to customize applications, or install all recommended packages." -Color White
        Write-WD7Host "  Currently Selected: $selectedCount of $totalApps applications" -Color Primary
        Write-Host ""

        $catIndex = 1
        $catMap = @{}
        foreach ($cat in $catalog.categories) {
            $catSelected = ($cat.apps | Where-Object { $selectionState[$_.id] -eq $true }).Count
            $catTotal = @($cat.apps).Count
            $catMap["$catIndex"] = $cat

            $badge = if ($catSelected -eq $catTotal -and $catTotal -gt 0) { "ALL SELECTED" }
                     elseif ($catSelected -gt 0) { "$catSelected/$catTotal SELECTED" }
                     else { "NONE" }

            Write-WD7Host "  [$catIndex] " -Color White -NoNewline
            Write-WD7Host ("{0,-28}" -f $cat.name) -Color Primary -NoNewline
            Write-WD7Host " ($catTotal apps) " -Color Dark -NoNewline
            Show-WD7StatusBadge -Label $badge -Status (if ($catSelected -gt 0) { "Success" } else { "Info" })
            $catIndex++
        }

        Write-Host ""
        Show-WD7Separator
        Write-WD7Host "  [I] Install Selected via Winget ($selectedCount apps)   [R] Select All Recommended" -Color Success
        Write-WD7Host "  [A] Select ALL Apps                                   [C] Clear All Selections" -Color White
        Write-WD7Host "  [B] Back to Main Menu" -Color Dark
        Write-Host ""

        Show-WDCursor
        $rawChoice = Read-Host "  Select option or category [1-$($catalog.categories.Count), I, R, A, C, B]"
        if ($null -eq $rawChoice) { return }
        $c = $rawChoice.Trim().ToUpper()

        switch ($c) {
            { $_ -in "B", "BACK", "0", "Q" } {
                return
            }
            { $_ -in "R", "REC", "RECOMMENDED" } {
                foreach ($cat in $catalog.categories) {
                    foreach ($app in $cat.apps) {
                        $selectionState[$app.id] = [bool]$app.recommended
                    }
                }
                Show-WD7ActionResult -Title "Recommended Selections Applied" -Detail "Reset selections to default recommended packages." -Status Success
                Start-Sleep -Milliseconds 800
            }
            { $_ -in "A", "ALL" } {
                foreach ($key in @($selectionState.Keys)) {
                    $selectionState[$key] = $true
                }
                Show-WD7ActionResult -Title "All Apps Selected" -Detail "All $totalApps applications marked for installation." -Status Success
                Start-Sleep -Milliseconds 800
            }
            { $_ -in "C", "CLEAR", "NONE" } {
                foreach ($key in @($selectionState.Keys)) {
                    $selectionState[$key] = $false
                }
                Show-WD7ActionResult -Title "Selections Cleared" -Detail "All selections removed." -Status Info
                Start-Sleep -Milliseconds 800
            }
            { $_ -in "I", "INSTALL" } {
                $toInstall = @($selectionState.Keys | Where-Object { $selectionState[$_] -eq $true })
                if ($toInstall.Count -eq 0) {
                    Show-WD7ActionResult -Title "No Packages Selected" -Detail "Please select at least one application to install." -Status Warning
                    Wait-WD7UserPrompt "Press Enter to return..."
                    continue
                }

                Write-Host ""
                Show-WD7Separator -Title "CONFIRM INSTALLATION" -Color Primary
                Write-WD7Host "  Applications to install ($($toInstall.Count)):" -Color White
                foreach ($appId in $toInstall) {
                    Write-Host "    • $appId" -ForegroundColor Cyan
                }
                Write-Host ""
                $confirm = (Read-Host "  Proceed with silent installation via Winget? [Y/N]").Trim()
                if ($confirm -match '^[Yy]') {
                    try {
                        Install-WinDebloatAppCatalog -PackageIds $toInstall -Provider "Winget"
                        Show-WD7ActionResult -Title "Software Installation Complete" -Detail "Installed $($toInstall.Count) application(s)." -Status Success
                    }
                    catch {
                        Show-WD7ActionResult -Title "Installation Error" -Detail $_.Exception.Message -Status Error
                    }
                    Wait-WD7UserPrompt "Press Enter to continue..."
                }
            }
            default {
                if ($catMap.ContainsKey($c)) {
                    $chosenCat = $catMap[$c]
                    while ($true) {
                        Show-WD7Header
                        Show-WD7Breadcrumb -Path @("Win-Debloat", "Software Catalog", $chosenCat.name)
                        Show-WD7Separator -Title "$($chosenCat.name.ToUpper())" -Color Secondary
                        Write-Host ""

                        $appIndex = 1
                        $appMap = @{}
                        foreach ($app in $chosenCat.apps) {
                            $appMap["$appIndex"] = $app
                            $isChecked = $selectionState[$app.id]
                            $box = if ($isChecked) { "$([char]27)[38;2;0;255;136m[✔]$([char]27)[0m" } else { "$([char]27)[38;2;96;96;112m[ ]$([char]27)[0m" }
                            $recTag = if ($app.recommended) { " $([char]27)[38;2;0;212;255m★ Recommended$([char]27)[0m" } else { "" }

                            Write-Host "  $box [$appIndex] $($app.name)$recTag"
                            Write-Host "      $([char]27)[38;2;148;163;184m$($app.description)$([char]27)[0m"
                            $appIndex++
                        }

                        Write-Host ""
                        Show-WD7Separator
                        Write-WD7Host "  [1-$($chosenCat.apps.Count)] Toggle Application   [A] Toggle Category   [B] Back to Categories" -Color White
                        Write-Host ""

                        Show-WDCursor
                        $catChoice = (Read-Host "  Enter option").Trim().ToUpper()
                        if ($catChoice -in "B", "BACK", "") { break }
                        if ($catChoice -eq "A") {
                            $allInCatSelected = ($chosenCat.apps | Where-Object { -not $selectionState[$_.id] }).Count -eq 0
                            foreach ($app in $chosenCat.apps) {
                                $selectionState[$app.id] = -not $allInCatSelected
                            }
                            continue
                        }
                        if ($appMap.ContainsKey($catChoice)) {
                            $targetApp = $appMap[$catChoice]
                            $selectionState[$targetApp.id] = -not $selectionState[$targetApp.id]
                        }
                    }
                }
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Aliases & Module Exports
# ─────────────────────────────────────────────────────────────────────────────

Set-Alias -Name 'Get-WinDebloat7ProfileSummary' -Value 'Get-WinDebloatProfileSummary'
Set-Alias -Name 'Invoke-WinDebloat7Benchmark' -Value 'Invoke-WinDebloatBenchmark'
Set-Alias -Name 'Show-WD7InteractiveMenu' -Value 'Show-WDInteractiveMenu'
Set-Alias -Name 'Show-WinDebloat7DiffViewer' -Value 'Show-WinDebloatDiffViewer'
Set-Alias -Name 'Show-WD7DiffViewer' -Value 'Show-WinDebloatDiffViewer'
Set-Alias -Name 'Show-WinDebloat7SoftwareCatalogMenu' -Value 'Show-SoftwareCatalogMenu'
Set-Alias -Name 'Show-WD7SoftwareCatalogMenu' -Value 'Show-SoftwareCatalogMenu'

Export-ModuleMember -Function Show-MainMenu,
    Show-TweaksMenu,
    Show-UICustomizationMenu,
    Show-SearchSuggestionsMenu,
    Show-SystemQoLMenu,
    Show-AdvancedRemovalMenu,
    Show-ServicesMenu,
    Show-ProfileSelection,
    Show-ProfilePreview,
    Invoke-Profile,
    Show-SystemInfo,
    Show-SnapshotMenu,
    Show-NetworkPrivacyMenu,
    Invoke-WinDebloatBenchmark,
    Get-WinDebloatProfileSummary,
    Show-RepairMenu,
    Show-FeaturesMenu,
    Show-IntegrationsMenu,
    Show-WD7Breadcrumb,
    Wait-WD7UserPrompt,
    Show-WD7ActionResult,
    Show-WDInteractiveMenu,
    Show-SiliconSchedulingMenu,
    Show-TransportSecurityMenu,
    Show-StorageSubsystemMenu,
    Show-SMBHardeningMenu,
    Show-WinDebloatDiffViewer,
    Show-SoftwareCatalogMenu `
    -Alias Get-WinDebloat7ProfileSummary,
    Invoke-WinDebloat7Benchmark,
    Show-WD7InteractiveMenu,
    Show-WinDebloat7DiffViewer,
    Show-WD7DiffViewer,
    Show-WinDebloat7SoftwareCatalogMenu,
    Show-WD7SoftwareCatalogMenu
