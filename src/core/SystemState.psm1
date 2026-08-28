#Requires -Version 7.6

<#
.SYNOPSIS
    System State Inspection Module
    
.DESCRIPTION
    Reads current system configuration to determine the state of various tweaks.
    Used by the GUI to synchronize checkboxes with actual system state.
    
.NOTES
    Module: Win-Debloat.Core.SystemState
    Version: 1.6.0
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

    $sudoModeVal = Get-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" "Enabled"
    $isSudoUnsafe = ($sudoModeVal -eq 3) # Mode 3 = normal inline interactive (risk of keystroke injection)

    $aiFabricRunning = try {
        @(Get-Service -Name "WSAIFabricSvc", "AIFabricUserSvc*" -ErrorAction SilentlyContinue).Where({ $_.Status -eq 'Running' }).Count -gt 0
    } catch { $false }

    $state = [pscustomobject]@{
        # Customization
        DarkTheme         = (Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme") -eq 0
        ActivityHistory   = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities") -ne 0
        BackgroundApps    = (Get-RegistryKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled") -ne 1
        ClipboardHistory  = (Get-RegistryKey "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory") -eq 1
        Hibernate         = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled") -eq 1
        
        # Privacy & 2026 AI Surface
        Telemetry         = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry") -ne 0
        Location          = (Get-RegistryKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value") -ne "Deny"
        Copilot           = ((Get-RegistryKey "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot") -ne 1) -and ((Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot") -ne 1)
        Recall            = ((Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis") -ne 1) -or $aiFabricRunning
        AdvertisingId     = (Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled") -ne 0
        StartAds          = ((Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled") -ne 0) -or ((Get-RegistryKey "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled") -ne 0)
        AIFabric          = $aiFabricRunning -or ((Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\ModelManagement" "DisableModelDownload") -ne 1)
        SudoUnsafe        = $isSudoUnsafe
        
        # Security
        WPP               = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ProtectedPrint" "ProtectedPrintMode") -eq 1
        BitLockerXTS256   = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\FVE" "EncryptionMethodWithXtsOs") -eq 7
        RPCHardening      = (Get-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" "RestrictRemoteClients") -eq 1
        SMBSigning        = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "RequireSecuritySignature") -eq 1
        LSAProtection     = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL") -eq 1
        
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
        HAGS              = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode") -eq 2
        DirectStorageMem  = (Get-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage") -eq 2
        
        # Updates & Network
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
    Calculates a 0-100 privacy score from the live system state using the 11-Vector Matrix (v1.6.0).

.DESCRIPTION
    Starts at 100 and deducts weighted points for each privacy-relevant setting
    that is still ENABLED. The weights are chosen to sum to exactly 100:

    Weighting (points lost when the risk is active):
        Telemetry ................. 18   (primary telemetry data channel)
        Windows Recall ............ 14   (continuous desktop screenshot indexing)
        Copilot ................... 12   (cloud AI integration)
        Start Ads & Suggestions ... 10   (ContentDeliveryManager ad payloads)
        Advertising ID ............ 10   (cross-app profiling)
        Location tracking ......... 10   (geolocation sensor consent)
        Activity History .......... 08   (timeline synchronization)
        NPU / AI Fabric ........... 08   (Phi-Silica SLM background RAM load)
        Sudo Keystroke Isolation .. 04   (unsafe inline interactive mode)
        Background apps ........... 04   (background execution permissions)
        Clipboard history ......... 02   (cloud clipboard sharing)
        ──────────────────────────────
                                   100
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

    # 11-Vector Matrix Definition
    $criteria = @(
        [pscustomobject]@{ Name = 'Telemetry';          Weight = 18; Active = (& $getProp $State 'Telemetry') }
        [pscustomobject]@{ Name = 'Windows Recall';     Weight = 14; Active = (& $getProp $State 'Recall') }
        [pscustomobject]@{ Name = 'Copilot';            Weight = 12; Active = (& $getProp $State 'Copilot') }
        [pscustomobject]@{ Name = 'Start Suggestions';  Weight = 10; Active = (& $getProp $State 'StartAds') }
        [pscustomobject]@{ Name = 'Advertising ID';     Weight = 10; Active = (& $getProp $State 'AdvertisingId') }
        [pscustomobject]@{ Name = 'Location';           Weight = 10; Active = (& $getProp $State 'Location') }
        [pscustomobject]@{ Name = 'Activity History';   Weight = 8;  Active = (& $getProp $State 'ActivityHistory') }
        [pscustomobject]@{ Name = 'NPU / AI Fabric';    Weight = 8;  Active = (& $getProp $State 'AIFabric') }
        [pscustomobject]@{ Name = 'Sudo Isolation';     Weight = 4;  Active = (& $getProp $State 'SudoUnsafe') }
        [pscustomobject]@{ Name = 'Background Apps';    Weight = 4;  Active = (& $getProp $State 'BackgroundApps') }
        [pscustomobject]@{ Name = 'Clipboard History';  Weight = 2;  Active = (& $getProp $State 'ClipboardHistory') }
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
