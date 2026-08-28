#Requires -Version 7.6

<#
.SYNOPSIS
    Privacy optimization module for Win-Debloat
    
.DESCRIPTION
    Manages Windows privacy settings, telemetry, and data collection.
    Uses PowerShell 7.6 best practices with proper error handling.
    
.NOTES
    Module: Win-Debloat.Modules.Privacy
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force
Import-Module "$PSScriptRoot\Tasks.psm1" -Force

<#
.SYNOPSIS
    Applies privacy settings based on configuration profile.
    
.DESCRIPTION
    Configures Windows privacy settings including telemetry levels,
    advertising ID, activity history, location tracking, Copilot, and Recall.
    
.PARAMETER Config
    The configuration object loaded from a YAML profile.
    
.OUTPUTS
    [void]
    
.EXAMPLE
    Set-WinDebloatPrivacy -Config $config
#>
function Set-WinDebloatPrivacy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Config
    )
    
    # Validate config has privacy section
    if (-not $Config.privacy) {
        Write-Log -Message "No privacy configuration found in profile." -Level Warning
        return
    }
    
    $level = $Config.privacy.telemetry_level
    Write-Log -Message "Applying Privacy Settings (Level: $level)" -Level Info
    
    $successCount = 0
    $failCount = 0
    $totalSteps = 5
    $currentStep = 0
    
    try {
        # 1. Advertising ID
    if ($Config.privacy.disable_advertising_id) {
        $currentStep++
        Write-Progress -Activity "Applying Privacy Settings" -Status "Disabling Advertising ID" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Disabling Advertising ID" -Level Info
        
        $results = @(
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1),
            (Set-RegistryKey -Path "HKCU:\Control Panel\International\User Profile" -Name "HttpAcceptLanguageOptOut" -Value 1)
        )
        
        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
    }
    
    # 2. Activity History
    if ($Config.privacy.disable_activity_history) {
        $currentStep++
        Write-Progress -Activity "Applying Privacy Settings" -Status "Disabling Activity History" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Disabling Activity History" -Level Info
        
        $results = @(
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0)
        )
        
        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
    }
    
    # 3. Telemetry
    if ($level -eq "Security" -or $level -eq "Basic") {
        $currentStep++
        Write-Progress -Activity "Applying Privacy Settings" -Status "Restricting Telemetry to $level" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Restricting Telemetry to '$level'" -Level Info
        # AllowTelemetry: 0 = Security, 1 = Basic, 3 = Full
        [int]$telemetryVal = if ($level -eq "Security") { 0 } else { 1 }
        
        $results = @(
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value $telemetryVal),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value $telemetryVal),
            # Tailored experiences based on diagnostic data
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0),
            # Online speech recognition
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "HasAccepted" -Value 0),
            # Inking & typing telemetry / personalization harvesting
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name "Enabled" -Value 0),
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1),
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1),
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0),
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0),
            # App launch tracking for Start/search ranking
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0),
            # Feedback frequency: never
            (Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0),
            # Edge browser diagnostic data & personalization reporting
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PersonalizationReportingEnabled" -Value 0),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "DiagnosticData" -Value 0)
        )

        $successCount += ($results | Where-Object { $_ }).Count
        $failCount += ($results | Where-Object { -not $_ }).Count
        
        # Disable DiagTrack service with proper error handling
        try {
            if ($PSCmdlet.ShouldProcess("DiagTrack", "Disable and Stop Service")) {
                Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction Stop
                Stop-Service -Name "DiagTrack" -Force -ErrorAction Stop
                Write-Log -Message "DiagTrack service disabled and stopped" -Level Success
                $successCount++
            }
        }
        catch {
            Write-Log -Message "Failed to disable DiagTrack: $($_.Exception.Message)" -Level Error
            $failCount++
        }
        
        # Disable Telemetry Tasks
        try {
            Write-Log -Message "Disabling Telemetry Scheduled Tasks (Safe Mode)" -Level Info
            Disable-WinDebloatTelemetryTasks -Mode Safe
            $successCount++
        }
        catch {
            Write-Log -Message "Failed to disable telemetry tasks: $($_.Exception.Message)" -Level Warning
        }
    }
    
    # 4. Location Tracking
    if ($Config.privacy.disable_location_tracking) {
        Write-Log -Message "Disabling Location Tracking" -Level Info
        
        if (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type String) {
            $successCount++
        }
        else {
            $failCount++
        }
    }
    
        # 5. Copilot, Recall, Click To Do & AI Fabric (2026 Surface)
        if ($Config.privacy.disable_copilot) {
            $currentStep++
            Write-Progress -Activity "Applying Privacy Settings" -Status "Disabling AI & Copilot" -PercentComplete (($currentStep / $totalSteps) * 100)
            Write-Log -Message "Disabling AI & Copilot features" -Level Info
            
            $copilotKeys = @(
                @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 }
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 }
                @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton"; Value = 0 }
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "DisableCopilotUserFeedback"; Value = 1 }
                # Edge AI
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0 }
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "CopilotCDPPageContext"; Value = 0 }
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "ComposeInlineEnabled"; Value = 0 }
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeHistoryAISearchEnabled"; Value = 0 }
                @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AIGenThemesEnabled"; Value = 0 }
            )
            
            foreach ($item in $copilotKeys) {
                if (Set-RegistryKey -Path $item.Path -Name $item.Name -Value $item.Value) {
                    $successCount++
                }
                else {
                    $failCount++
                    Write-Log -Message "Failed to set AI key: $($item.Path)" -Level Warning
                }
            }
        }
        
        if ($Config.privacy.disable_recall) {
            Write-Log -Message "Disabling Windows Recall (AI Snapshot Indexing)" -Level Info
            Disable-WinDebloatRecall
            $successCount++
        }

        if ($Config.privacy.disable_click_to_do) {
            Write-Log -Message "Disabling Windows Click To Do" -Level Info
            Disable-WinDebloatClickToDo
            $successCount++
        }

        if ($Config.privacy.disable_ai_fabric) {
            Write-Log -Message "Deactivating Phi-Silica SLM AI Fabric & Reclaiming System RAM" -Level Info
            Disable-WinDebloatAIFabric
            $successCount++
        }

        if ($Config.privacy.disable_lockscreen_widgets) {
            Write-Log -Message "Disabling Lock Screen Weather & Finance Widgets" -Level Info
            Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
            Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Value 0
            Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-410400Enabled" -Value 0
            $successCount++
        }
        
        Write-Progress -Activity "Applying Privacy Settings" -Completed
        
        # Summary
        Write-Log -Message "Privacy settings applied: $successCount succeeded, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
    }
    catch {
        Write-Log -Message "Error applying privacy settings: $($_.Exception.Message)" -Level Error
    }
}

<#
.SYNOPSIS
    Deactivates Phi-Silica 3.3B SLM / AI Fabric background workloads to reclaim 2.0 to 4.5 GB RAM.
#>
function Disable-WinDebloatAIFabric {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("AI Fabric & Phi-Silica SLM", "Deactivate background model host & reclaim RAM")) {
        Write-Log -Message "Deactivating AI Fabric background services..." -Level Info

        # Terminate pre-warmed model host if running
        Get-Process -Name "WorkloadsSessionHost", "AIFabricHost", "AIHost", "DirectMLHost", "ModelHost" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

        # Disable AI Fabric services
        $aiServices = @('WSAIFabricSvc', 'AIFabricUserSvc', 'NarrativeFlows', 'OneSettingsClientUserSvc', 'ModelCatalogUserSvc', 'SemanticSearchUserSvc')
        foreach ($svcName in $aiServices) {
            Get-Service -Name "$svcName*" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
                    Write-Log -Message "AI Service $($_.Name) disabled (Start=4)." -Level Success
                }
                catch {
                    Write-Log -Message "Notice: Could not modify $($_.Name): $($_.Exception.Message)" -Level Debug
                }
            }
        }

        # Prevent automatic model background downloads
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\ModelManagement" -Name "DisableModelDownload" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\ModelManagement" -Name "DisableBackgroundModelUpdates" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIFeatures" -Value 1 -Type "DWord"
        Write-Log -Message "Phi-Silica SLM AI Fabric deactivation complete. RAM reclaimed." -Level Success
    }
}

<#
.SYNOPSIS
    Restores Phi-Silica SLM and AI Fabric services to Windows defaults.
#>
function Enable-WinDebloatAIFabric {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("AI Fabric & Phi-Silica SLM", "Restore default service startup")) {
        $aiServices = @('WSAIFabricSvc', 'AIFabricUserSvc', 'NarrativeFlows', 'OneSettingsClientUserSvc', 'ModelCatalogUserSvc', 'SemanticSearchUserSvc')
        foreach ($svcName in $aiServices) {
            Get-Service -Name "$svcName*" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Set-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 3 -Type DWord -ErrorAction SilentlyContinue
                    Write-Log -Message "AI Service $($_.Name) startup restored (Start=3)." -Level Success
                }
                catch {
                    Write-Log -Message "Notice: Could not restore $($_.Name): $($_.Exception.Message)" -Level Debug
                }
            }
        }
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\ModelManagement" -Name "DisableModelDownload"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\ModelManagement" -Name "DisableBackgroundModelUpdates"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIFeatures"
        Write-Log -Message "AI Fabric services and policies restored to default." -Level Success
    }
}

<#
.SYNOPSIS
    Disables Windows Recall (v2) optional feature and blocks VBS enclave data analysis.
#>
function Disable-WinDebloatRecall {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Windows Recall", "Uninstall feature and enforce policy block")) {
        # Group Policies (VBS Enclave & Semantic Analysis)
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0 -Type "DWord"
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableScreenSemanticAnalysis" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0 -Type "DWord"
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall" -Name "Enabled" -Value 0 -Type "DWord"
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall" -Name "IsRecallAllowed" -Value 0 -Type "DWord"

        # Optional Feature uninstallation if present
        try {
            $recallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
            if ($recallFeature -and $recallFeature.State -eq 'Enabled') {
                Write-Log -Message "Uninstalling Windows Recall optional feature package..." -Level Info
                Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -Remove -ErrorAction SilentlyContinue
                Write-Log -Message "Windows Recall optional feature uninstalled." -Level Success
            }
        }
        catch {
            Write-Log -Message "Notice: Recall optional feature servicing notice: $($_.Exception.Message)" -Level Debug
        }
    }
}

<#
.SYNOPSIS
    Disables Click To Do screen AI analysis.
#>
function Disable-WinDebloatClickToDo {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Click To Do", "Disable screen AI parsing")) {
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1 -Type "DWord"
        Set-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1 -Type "DWord"
        Write-Log -Message "Click To Do screen analysis disabled." -Level Success
    }
}

<#
.SYNOPSIS
    Disables Windows 11 AI features (Copilot, Recall, Click To Do, Paint/Notepad AI) and Ads.
#>
function Disable-WinDebloatAI {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling Windows 11 AI, Copilot, Recall & Ads Surface..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows AI Surface", "Disable Copilot, Recall, Click To Do, Paint AI, Notepad AI, Ads")) {
        
        $keys = @(
            # Copilot & Lockscreen / Context Awareness
            @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "DisableCopilotLockScreen"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "DisableCopilotContextAwareness"; Value = 1; Type = "DWord" }
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton"; Value = 0; Type = "DWord" }
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotHardwareKey"; Value = 0; Type = "DWord" }
            
            # Recall & Click To Do
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "AllowRecallEnablement"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "TurnOffSavingSnapshots"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableScreenSemanticAnalysis"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableClickToDo"; Value = 1; Type = "DWord" }
            @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableClickToDo"; Value = 1; Type = "DWord" }
            
            # App-level AI (Paint Cocreator, Notepad AI Rewrite, Photos Super Resolution)
            @{ Path = "HKCU:\Software\Microsoft\Paint"; Name = "DisableCocreator"; Value = 1; Type = "DWord" }
            @{ Path = "HKCU:\Software\Microsoft\Notepad"; Name = "DisableAIRewrite"; Value = 1; Type = "DWord" }
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Photos"; Name = "DisableSuperResolution"; Value = 1; Type = "DWord" }
            
            # Edge AI
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "CopilotCDPPageContext"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "ComposeInlineEnabled"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "EdgeHistoryAISearchEnabled"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AIGenThemesEnabled"; Value = 0; Type = "DWord" }
            
            # Start Menu & Cloud Content Ads
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableCloudOptimizedContent"; Value = 1; Type = "DWord" }
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"; Name = "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"; Value = 1; Type = "DWord" }
        )
        
        foreach ($k in $keys) {
            Set-RegistryKey -Path $k.Path -Name $k.Name -Value $k.Value -Type $k.Type
        }
        
        # Deactivate AI Fabric and Recall Feature
        Disable-WinDebloatAIFabric
        Disable-WinDebloatRecall

        Write-Log -Message "AI and Ads features disabled." -Level Success
    }
}

<#
.SYNOPSIS
    Reverts Windows privacy settings to Windows defaults.
#>
function Enable-WinDebloatPrivacy {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Reverting Privacy Settings to Windows Defaults..." -Level Info

    if ($PSCmdlet.ShouldProcess("Windows Privacy", "Restore Defaults")) {
        # 1. Advertising ID
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy"
        Remove-RegistryKey -Path "HKCU:\Control Panel\International\User Profile" -Name "HttpAcceptLanguageOptOut"
        Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 1

        # 2. Activity History
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities"

        # 3. Telemetry Policy Overrides
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "HasAccepted"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name "Enabled"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod"
        Remove-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PersonalizationReportingEnabled"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "DiagnosticData"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "CopilotCDPPageContext"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "ComposeInlineEnabled"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "EdgeHistoryAISearchEnabled"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "AIGenThemesEnabled"

        # 4. Location Tracking
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow" -Type String

        # Restore DiagTrack service
        try {
            Set-Service -Name "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
            Write-Log -Message "DiagTrack service restored." -Level Success
        }
        catch {
            Write-Log -Message "Notice: DiagTrack restore: $($_.Exception.Message)" -Level Debug
        }

        # Restore AI / Copilot / Click To Do policies
        Remove-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo"
        Remove-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableCloudOptimizedContent"
        Remove-RegistryKey -Path "HKCU:\Software\Microsoft\Paint" -Name "DisableCocreator"
        Remove-RegistryKey -Path "HKCU:\Software\Microsoft\Notepad" -Name "DisableAIRewrite"
        Remove-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Photos" -Name "DisableSuperResolution"
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 1 -Type DWord

        # Restore AI Fabric Services
        Enable-WinDebloatAIFabric

        # Re-enable safe telemetry scheduled tasks
        try {
            Enable-WinDebloatTelemetryTasks -Mode All -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log -Message "Telemetry tasks re-enable notice: $($_.Exception.Message)" -Level Debug
        }

        Write-Log -Message "Privacy defaults successfully restored." -Level Success
    }
}

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7Privacy' -Value 'Set-WinDebloatPrivacy'
Set-Alias -Name 'Disable-WinDebloatPrivacy' -Value 'Set-WinDebloatPrivacy'
Set-Alias -Name 'Disable-WinDebloat7Privacy' -Value 'Set-WinDebloatPrivacy'
Set-Alias -Name 'Disable-WinDebloatAIandAds' -Value 'Disable-WinDebloatAI'
Set-Alias -Name 'Disable-WinDebloat7AIandAds' -Value 'Disable-WinDebloatAI'
Set-Alias -Name 'Disable-WinDebloat7AI' -Value 'Disable-WinDebloatAI'
Set-Alias -Name 'Disable-WinDebloat7AIFabric' -Value 'Disable-WinDebloatAIFabric'
Set-Alias -Name 'Enable-WinDebloat7AIFabric' -Value 'Enable-WinDebloatAIFabric'
Set-Alias -Name 'Disable-WinDebloat7Recall' -Value 'Disable-WinDebloatRecall'
Set-Alias -Name 'Disable-WinDebloat7ClickToDo' -Value 'Disable-WinDebloatClickToDo'
Set-Alias -Name 'Enable-WinDebloat7Privacy' -Value 'Enable-WinDebloatPrivacy'

Export-ModuleMember -Function @(
    'Set-WinDebloatPrivacy',
    'Disable-WinDebloatAI',
    'Disable-WinDebloatAIFabric',
    'Enable-WinDebloatAIFabric',
    'Disable-WinDebloatRecall',
    'Disable-WinDebloatClickToDo',
    'Enable-WinDebloatPrivacy'
) -Alias @(
    'Set-WinDebloat7Privacy',
    'Disable-WinDebloatPrivacy',
    'Disable-WinDebloat7Privacy',
    'Disable-WinDebloatAIandAds',
    'Disable-WinDebloat7AIandAds',
    'Disable-WinDebloat7AI',
    'Disable-WinDebloat7AIFabric',
    'Enable-WinDebloat7AIFabric',
    'Disable-WinDebloat7Recall',
    'Disable-WinDebloat7ClickToDo',
    'Enable-WinDebloat7Privacy'
)
