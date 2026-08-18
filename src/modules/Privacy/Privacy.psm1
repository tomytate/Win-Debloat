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
    
    # 5. Copilot & Recall (25H2 Readiness)
    if ($Config.privacy.disable_copilot) {
        $currentStep++
        Write-Progress -Activity "Applying Privacy Settings" -Status "Disabling AI & Copilot" -PercentComplete (($currentStep / $totalSteps) * 100)
        Write-Log -Message "Disabling AI & Copilot features" -Level Info
        
        $copilotKeys = @(
            @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1 }
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton"; Value = 0 }
            # Edge AI
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "CopilotCDPPageContext"; Value = 0 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "ComposeInlineEnabled"; Value = 0 }
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
        Write-Log -Message "Disabling Windows Recall (AI Analysis)" -Level Info
        
        $aiKeys = @(
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis"; Value = 1 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "AllowRecallEnablement"; Value = 0 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "TurnOffSavingSnapshots"; Value = 1 }
        )
        foreach ($item in $aiKeys) {
            if (Set-RegistryKey -Path $item.Path -Name $item.Name -Value $item.Value) {
                $successCount++
            }
        }
    }
    
    Write-Progress -Activity "Applying Privacy Settings" -Completed
    
    # Summary
    Write-Log -Message "Privacy settings applied: $successCount succeeded, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
}

<#
.SYNOPSIS
    Disables Windows 11 AI features (Copilot, Recall) and Ads.
    (Moved from Bloatware module for cohesion)
#>
function Disable-WinDebloatAI {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling Windows 11 AI & Ads..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows AI", "Disable Copilot, Recall, Ads")) {
        
        # Repeating specific keys for standalone execution is safer to avoid Config dependency.
        $keys = @(
            # Copilot
            @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1; Type = "DWord" }
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowCopilotButton"; Value = 0; Type = "DWord" }
            
            # Recall
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis"; Value = 1; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "AllowRecallEnablement"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "TurnOffSavingSnapshots"; Value = 1; Type = "DWord" }
            
            # Edge AI
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "CopilotCDPPageContext"; Value = 0; Type = "DWord" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "ComposeInlineEnabled"; Value = 0; Type = "DWord" }
            
            # Start Menu Ads
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1; Type = "DWord" }
        )
        
        foreach ($k in $keys) {
            Set-RegistryKey -Path $k.Path -Name $k.Name -Value $k.Value -Type $k.Type
        }
        
        # Disable AI Services (24H2/25H2+)
        Get-Service -Name "AIFabric*" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
                Write-Log -Message "AI service $($_.Name) disabled." -Level Success
            }
            catch {
                Write-Log -Message "Could not disable $($_.Name): $($_.Exception.Message)" -Level Warning
            }
        }

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

        # Restore AI / Copilot policies
        Remove-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots"
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures"
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 1 -Type DWord

        # Restore AI Services (24H2/25H2+)
        Get-Service -Name "AIFabric*" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Set-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -Name "Start" -Value 3 -Type DWord -ErrorAction SilentlyContinue
                Write-Log -Message "AI service $($_.Name) startup restored." -Level Success
            }
            catch {
                Write-Log -Message "Notice: Could not restore $($_.Name): $($_.Exception.Message)" -Level Debug
            }
        }

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
Set-Alias -Name 'Enable-WinDebloat7Privacy' -Value 'Enable-WinDebloatPrivacy'

Export-ModuleMember -Function @(
    'Set-WinDebloatPrivacy',
    'Disable-WinDebloatAI',
    'Enable-WinDebloatPrivacy'
) -Alias @(
    'Set-WinDebloat7Privacy',
    'Disable-WinDebloatPrivacy',
    'Disable-WinDebloat7Privacy',
    'Disable-WinDebloatAIandAds',
    'Disable-WinDebloat7AIandAds',
    'Disable-WinDebloat7AI',
    'Enable-WinDebloat7Privacy'
)
