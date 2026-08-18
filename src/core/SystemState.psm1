#Requires -Version 7.6

<#
.SYNOPSIS
    System State Inspection Module
    
.DESCRIPTION
    Reads current system configuration to determine the state of various tweaks.
    Used by the GUI to synchronize checkboxes with actual system state.
    
.NOTES
    Module: Win-Debloat.Core.SystemState
    Version: 1.5.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\Registry.psm1" -Force

function Get-WinDebloatSystemState {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()
    
    # Fast registry lookup for active power scheme (avoids spawning powercfg.exe every tick)
    $activeScheme = try {
        (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" -Name "ActivePowerScheme" -ErrorAction SilentlyContinue).ActivePowerScheme
    }
    catch {
        ""
    }
    if (-not $activeScheme) {
        $activeScheme = try { (powercfg /getactivescheme 2>$null) | Out-String } catch { "" }
    }

    $state = [pscustomobject]@{
        # Customization
        DarkTheme         = (Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme") -eq 0
        ActivityHistory   = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities") -ne 0
        BackgroundApps    = (Get-RegistryKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled") -ne 1
        ClipboardHistory  = (Get-RegistryKey "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory") -eq 1
        Hibernate         = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled") -eq 1
        
        # Privacy
        Telemetry         = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry") -ne 0
        Location          = (Get-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value") -ne "Deny"
        Copilot           = ((Get-RegistryKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot") -ne 1) -and ((Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot") -ne 1)
        Recall            = ((Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis") -ne 1) -or 
                            (@(Get-Service "AIFabric*" -ErrorAction SilentlyContinue).Where({ $_.Status -eq 'Running' }).Count -gt 0)
        AdvertisingId     = (Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled") -ne 0
        
        # Performance / Gaming
        GameMode          = (Get-RegistryKey "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode") -ne 0
        GameBar           = (Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled") -ne 0
        PowerPlan         = if ($activeScheme -match "e9a42b02-d5df-448d-aa00-03f14749eb61|Ultimate") { "Ultimate" }
                            elseif ($activeScheme -match "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c|High") { "HighPerformance" }
                            else { "Balanced" }
        
        # Gaming Optimizations
        GamingNetwork     = (Get-RegistryKey "HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters" "TCPNoDelay") -eq 1
        GamingInput       = (Get-RegistryKey "HKCU:\Control Panel\Mouse" "MouseSpeed") -eq "0"
        GamingMMCSS       = (Get-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness") -eq 0
        VisualEffects     = (Get-RegistryKey "HKCU:\Control Panel\Desktop" "MenuShowDelay") -eq "0"
        UltimatePlan      = [bool]($activeScheme -match "e9a42b02-d5df-448d-aa00-03f14749eb61|Ultimate")
        
        # Updates
        WindowsUpdate     = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate") -ne 1
        IPv6              = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents") -ne 255
        IPv6Disabled      = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents") -eq 32 -or (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents") -eq 255
        SMBv1Disabled     = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SMB1") -eq 0
        NetBIOSDisabled   = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" "NetbiosOptions") -eq 2
        
        # Real-time Stats
        ActiveConnections = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue).Count
    }
    
    return $state
}

<#
.SYNOPSIS
    Calculates a 0-100 privacy score from the live system state.

.DESCRIPTION
    Starts at 100 and deducts weighted points for each privacy-relevant setting
    that is still ENABLED. The weights are chosen to sum to exactly 100, so a
    fully-hardened system scores 100 and a fully-exposed one scores 0.

    Weighting (points lost when the risk is active):
        Telemetry ............. 22   (the biggest data channel)
        Windows Recall ........ 16   (records screenshots of everything)
        Advertising ID ........ 14   (cross-app ad tracking)
        Copilot ............... 12   (cloud AI integration)
        Activity History ...... 12   (timeline sent to Microsoft)
        Location tracking ..... 12
        Background apps ....... 07
        Clipboard history ..... 05
        ──────────────────────────
                                100

.PARAMETER State
    An existing state object from Get-WinDebloatSystemState or custom object/hashtable.
    If omitted, the state is fetched fresh.

.OUTPUTS
    [pscustomobject] with Score (int 0-100), Grade (A-F), Rating (text),
    and Breakdown (per-item Name / Weight / Active / Lost).
#>
function Get-WinDebloatPrivacyScore {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [object]$State
    )

    if ($null -eq $State) {
        $State = Get-WinDebloatSystemState
    }

    $getProp = {
        param($obj, [string]$name)
        if ($obj -is [System.Collections.IDictionary]) {
            return [bool]$obj[$name]
        }
        if ($obj.PSObject.Properties[$name]) {
            return [bool]$obj.$name
        }
        return $false
    }

    # Name => @(weight, isActive-risk). "Active" means the privacy risk is ON.
    $criteria = @(
        [pscustomobject]@{ Name = 'Telemetry';         Weight = 22; Active = (& $getProp $State 'Telemetry') }
        [pscustomobject]@{ Name = 'Windows Recall';    Weight = 16; Active = (& $getProp $State 'Recall') }
        [pscustomobject]@{ Name = 'Advertising ID';    Weight = 14; Active = (& $getProp $State 'AdvertisingId') }
        [pscustomobject]@{ Name = 'Copilot';           Weight = 12; Active = (& $getProp $State 'Copilot') }
        [pscustomobject]@{ Name = 'Activity History';  Weight = 12; Active = (& $getProp $State 'ActivityHistory') }
        [pscustomobject]@{ Name = 'Location';          Weight = 12; Active = (& $getProp $State 'Location') }
        [pscustomobject]@{ Name = 'Background Apps';   Weight = 7;  Active = (& $getProp $State 'BackgroundApps') }
        [pscustomobject]@{ Name = 'Clipboard History';  Weight = 5;  Active = (& $getProp $State 'ClipboardHistory') }
    )

    $breakdown = foreach ($c in $criteria) {
        [pscustomobject]@{
            Name   = $c.Name
            Weight = $c.Weight
            Active = $c.Active
            Lost   = if ($c.Active) { $c.Weight } else { 0 }
        }
    }

    $lost = ($breakdown | Measure-Object -Property Lost -Sum).Sum
    $score = [Math]::Max(0, [Math]::Min(100, 100 - $lost))

    if ($score -ge 90) { $grade = 'A'; $rating = 'Excellent' }
    elseif ($score -ge 75) { $grade = 'B'; $rating = 'Good' }
    elseif ($score -ge 60) { $grade = 'C'; $rating = 'Fair' }
    elseif ($score -ge 40) { $grade = 'D'; $rating = 'Poor' }
    else { $grade = 'F'; $rating = 'At Risk' }

    return [pscustomobject]@{
        Score     = [int]$score
        Grade     = $grade
        Rating    = $rating
        Breakdown = $breakdown
    }
}

Set-Alias -Name Get-WinDebloat7SystemState -Value Get-WinDebloatSystemState
Set-Alias -Name Get-WinDebloat7PrivacyScore -Value Get-WinDebloatPrivacyScore

Export-ModuleMember -Function Get-WinDebloatSystemState, Get-WinDebloatPrivacyScore `
                    -Alias Get-WinDebloat7SystemState, Get-WinDebloat7PrivacyScore
