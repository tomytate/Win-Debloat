#Requires -Version 7.6

<#
.SYNOPSIS
    Registry tweaks module for Win-Debloat.
    
.DESCRIPTION
    Provides granular registry modification functions for AI features, privacy,
    telemetry, and UI customization. Designed for both interactive and Sysprep
    (Default User hive) scenarios.
    
.NOTES
    Module: Win-Debloat.Modules.Tweaks
    Version: 2.0.0
#>

#region AI Feature Tweaks

function Disable-WinDebloatAIRecall {
    <#
    .SYNOPSIS
        Disables Windows AI Recall feature (screenshot history).
    
    .PARAMETER ApplyToDefaultUser
        If specified, applies to Default User hive for Sysprep scenarios.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    $tweaks = @(
        @{
            Path  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
            Name  = "DisableAIDataAnalysis"
            Type  = "DWord"
            Value = 1
        },
        @{
            Path  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
            Name  = "AllowRecallEnablement"
            Type  = "DWord"
            Value = 0
        }
    )

    foreach ($tweak in $tweaks) {
        Set-WinDebloatRegistryValue @tweak
    }

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Policies\Microsoft\Windows\WindowsAI" `
            -Name "DisableAIDataAnalysis" -Type "DWord" -Value 1
    }

    Write-Log -Message "AI Recall disabled" -Level Success
}

function Disable-WinDebloatCopilot {
    <#
    .SYNOPSIS
        Disables Windows Copilot taskbar button and service.
    
    .PARAMETER ApplyToDefaultUser
        If specified, applies to Default User hive for Sysprep scenarios.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    # Machine-level policy
    Set-WinDebloatRegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
        -Name "TurnOffWindowsCopilot" -Type "DWord" -Value 1

    # Current user
    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ShowCopilotButton" -Type "DWord" -Value 0
    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" `
        -Name "TurnOffWindowsCopilot" -Type "DWord" -Value 1

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "ShowCopilotButton" -Type "DWord" -Value 0
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Policies\Microsoft\Windows\WindowsCopilot" `
            -Name "TurnOffWindowsCopilot" -Type "DWord" -Value 1
    }

    Write-Log -Message "Copilot disabled" -Level Success
}

function Disable-WinDebloatClickToDo {
    <#
    .SYNOPSIS
        Disables Windows Click-to-Do AI feature.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ClickToDoEnabled" -Type "DWord" -Value 0

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "ClickToDoEnabled" -Type "DWord" -Value 0
    }

    Write-Log -Message "Click-to-Do disabled" -Level Success
}

function Disable-WinDebloatNotepadAI {
    <#
    .SYNOPSIS
        Disables AI features in Notepad (Cowriter).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Microsoft\Notepad" `
        -Name "EnableAI" -Type "DWord" -Value 0

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Microsoft\Notepad" `
            -Name "EnableAI" -Type "DWord" -Value 0
    }

    Write-Log -Message "Notepad AI disabled" -Level Success
}

function Disable-WinDebloatPaintAI {
    <#
    .SYNOPSIS
        Disables AI features in Paint (Cocreator, Image Creator).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    $regPath = "HKCU:\Software\Microsoft\Paint"
    Set-WinDebloatRegistryValue -Path $regPath -Name "CocreatorEnabled" -Type "DWord" -Value 0
    Set-WinDebloatRegistryValue -Path $regPath -Name "ImageCreatorEnabled" -Type "DWord" -Value 0
    Set-WinDebloatRegistryValue -Path $regPath -Name "GenerativeFillEnabled" -Type "DWord" -Value 0
    Set-WinDebloatRegistryValue -Path $regPath -Name "GenerativeEraseEnabled" -Type "DWord" -Value 0

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        $defaultPath = "HKLM:\$defaultHive\Software\Microsoft\Paint"
        Set-WinDebloatRegistryValue -Path $defaultPath -Name "CocreatorEnabled" -Type "DWord" -Value 0
        Set-WinDebloatRegistryValue -Path $defaultPath -Name "ImageCreatorEnabled" -Type "DWord" -Value 0
        Set-WinDebloatRegistryValue -Path $defaultPath -Name "GenerativeFillEnabled" -Type "DWord" -Value 0
        Set-WinDebloatRegistryValue -Path $defaultPath -Name "GenerativeEraseEnabled" -Type "DWord" -Value 0
    }

    Write-Log -Message "Paint AI features disabled" -Level Success
}

function Disable-WinDebloatEdgeAI {
    <#
    .SYNOPSIS
        Disables AI features in Microsoft Edge.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $edgePolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    Set-WinDebloatRegistryValue -Path $edgePolicies -Name "CopilotCDPPageContext" -Type "DWord" -Value 0
    Set-WinDebloatRegistryValue -Path $edgePolicies -Name "DiscoverPageContextEnabled" -Type "DWord" -Value 0
    Set-WinDebloatRegistryValue -Path $edgePolicies -Name "HubsSidebarEnabled" -Type "DWord" -Value 0

    Write-Log -Message "Edge AI features disabled" -Level Success
}

#endregion

#region Privacy Tweaks

function Disable-WinDebloatDesktopSpotlight {
    <#
    .SYNOPSIS
        Disables Desktop Spotlight (rotating background images with ads).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" `
        -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Type "DWord" -Value 1
    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
        -Name "EnableLightThemeForConnectedStandby" -Type "DWord" -Value 0

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" `
            -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Type "DWord" -Value 1
    }

    Write-Log -Message "Desktop Spotlight disabled" -Level Success
}

function Disable-WinDebloatSettings365Ads {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    <#
    .SYNOPSIS
        Disables Microsoft 365 ads in Windows Settings.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ApplyToDefaultUser
    )

    Set-WinDebloatRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ShowSyncProviderNotifications" -Type "DWord" -Value 0

    $defaultHive = if (Test-Path "Registry::HKLM\WinDebloat_Default") { "WinDebloat_Default" } elseif (Test-Path "Registry::HKLM\WinDebloat7_Default") { "WinDebloat7_Default" } else { $null }
    if ($ApplyToDefaultUser -and $defaultHive) {
        Set-WinDebloatRegistryValue -Path "HKLM:\$defaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "ShowSyncProviderNotifications" -Type "DWord" -Value 0
    }

    Write-Log -Message "Settings 365 ads disabled" -Level Success
}

#endregion

#region Power & Performance Tweaks

function Enable-WinDebloatUltimatePower {
    <#
    .SYNOPSIS
        Enables and activates the Ultimate Performance power plan.
        
    .DESCRIPTION
        Duplicates the hidden Ultimate Performance power scheme and sets it as active.
        Source: winutil (ChrisTitusTech)
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    try {
        $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        
        # Check if already exists in power schemes
        $existingPlan = powercfg -list | Select-String -Pattern "Win-Debloat Ultimate|Win-Debloat7 Ultimate|Ultimate Performance"
        if ($existingPlan) {
            foreach ($line in ($existingPlan | Out-String -Stream)) {
                if ($line -match '\b([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\b') {
                    $existingGuid = $matches[1]
                    Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "$existingGuid" -Wait -NoNewWindow
                    Write-Log -Message "Ultimate Performance plan activated ($existingGuid)" -Level Success
                    return
                }
            }
        }

        # Duplicate the Ultimate Performance power plan
        $duplicateOutput = powercfg /duplicatescheme $ultimateGUID 2>&1

        $guid = $null
        foreach ($line in $duplicateOutput) {
            if ($line -match '\b([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\b') {
                $guid = $matches[1]
                break
            }
        }

        if (-not $guid) {
            Write-Log -Message "Failed to create Ultimate Performance plan - GUID not found" -Level Error
            return
        }

        # Rename the plan
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/changename", "$guid", "`"Win-Debloat Ultimate`"", "`"Ultimate Performance plan`"" -Wait -NoNewWindow

        # Set as active
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "$guid" -Wait -NoNewWindow

        Write-Log -Message "Ultimate Performance plan installed and activated ($guid)" -Level Success
    }
    catch {
        Write-Log -Message "Error enabling Ultimate Power: $($_.Exception.Message)" -Level Error
    }
}

function Disable-WinDebloatUltimatePower {
    <#
    .SYNOPSIS
        Removes the Ultimate Performance power plan and reverts to Balanced.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    try {
        $installedPlan = powercfg -list | Select-String -Pattern "Win-Debloat Ultimate|Win-Debloat7 Ultimate"
        
        if ($installedPlan) {
            $ultimatePlanGUID = ($installedPlan -split '\s+')[3]
            
            # Revert to Balanced
            $balancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"
            Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "$balancedGUID" -Wait -NoNewWindow
            
            # Delete Ultimate plan
            Start-Process -FilePath "powercfg.exe" -ArgumentList "/delete", "$ultimatePlanGUID" -Wait -NoNewWindow
            
            Write-Log -Message "Ultimate Performance plan uninstalled, Balanced active" -Level Success
        }
        else {
            Write-Log -Message "Ultimate Performance plan not found" -Level Info
        }
    }
    catch {
        Write-Log -Message "Error disabling Ultimate Power: $($_.Exception.Message)" -Level Error
    }
}

#endregion

#region Sysprep Batch Apply

function Invoke-WinDebloatSysprepDefaults {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    <#
    .SYNOPSIS
        Applies all Sysprep-compatible tweaks to the Default User hive.
        
    .DESCRIPTION
        Mounts the Default User registry hive and applies all AI, privacy,
        and UI tweaks for OEM image deployment.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    # Verify we're in Sysprep/Audit mode or user confirmed
    $inAuditMode = if (Get-Command Test-WinDebloatSysprep -ErrorAction SilentlyContinue) {
        Test-WinDebloatSysprep
    }
    elseif (Get-Command Test-WinDebloat7Sysprep -ErrorAction SilentlyContinue) {
        Test-WinDebloat7Sysprep
    }
    else {
        $false
    }

    if (-not $inAuditMode) {
        Write-Log -Message "Warning: Not in Audit Mode. Tweaks will apply to Default User anyway." -Level Warning
    }

    # Mount Default User hive
    $mounted = if (Get-Command Mount-WinDebloatDefaultHive -ErrorAction SilentlyContinue) {
        Mount-WinDebloatDefaultHive
    }
    elseif (Get-Command Mount-WinDebloat7DefaultHive -ErrorAction SilentlyContinue) {
        Mount-WinDebloat7DefaultHive
    }
    else {
        $false
    }

    if (-not $mounted) {
        Write-Log -Message "Failed to mount Default User hive" -Level Error
        return
    }

    try {
        Write-Log -Message "Applying Sysprep defaults to Default User..." -Level Info
        
        # Apply all AI tweaks
        Disable-WinDebloatAIRecall -ApplyToDefaultUser
        Disable-WinDebloatCopilot -ApplyToDefaultUser
        Disable-WinDebloatClickToDo -ApplyToDefaultUser
        Disable-WinDebloatNotepadAI -ApplyToDefaultUser
        Disable-WinDebloatPaintAI -ApplyToDefaultUser
        
        # Apply privacy tweaks
        Disable-WinDebloatDesktopSpotlight -ApplyToDefaultUser
        Disable-WinDebloatSettings365Ads -ApplyToDefaultUser
        
        Write-Log -Message "Sysprep defaults applied successfully" -Level Success
    }
    finally {
        if (Get-Command Dismount-WinDebloatDefaultHive -ErrorAction SilentlyContinue) {
            Dismount-WinDebloatDefaultHive
        }
        elseif (Get-Command Dismount-WinDebloat7DefaultHive -ErrorAction SilentlyContinue) {
            Dismount-WinDebloat7DefaultHive
        }
    }
}

#endregion

#region Helper Functions

function Set-WinDebloatRegistryValue {
    <#
    .SYNOPSIS
        Sets a registry value, creating the key path if it doesn't exist.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Type,
        
        [Parameter(Mandatory)]
        $Value
    )

    if (-not $PSCmdlet.ShouldProcess("$Path\$Name", "Set value to $Value")) {
        return
    }

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Verbose "Set $Path\$Name = $Value"
    }
    catch {
        Write-Log -Message "Failed to set registry: $Path\$Name - $($_.Exception.Message)" -Level Warning
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Disable-WinDebloat7AIRecall' -Value 'Disable-WinDebloatAIRecall'
Set-Alias -Name 'Disable-WinDebloat7Copilot' -Value 'Disable-WinDebloatCopilot'
Set-Alias -Name 'Disable-WinDebloat7ClickToDo' -Value 'Disable-WinDebloatClickToDo'
Set-Alias -Name 'Disable-WinDebloat7NotepadAI' -Value 'Disable-WinDebloatNotepadAI'
Set-Alias -Name 'Disable-WinDebloat7PaintAI' -Value 'Disable-WinDebloatPaintAI'
Set-Alias -Name 'Disable-WinDebloat7EdgeAI' -Value 'Disable-WinDebloatEdgeAI'
Set-Alias -Name 'Disable-WinDebloat7DesktopSpotlight' -Value 'Disable-WinDebloatDesktopSpotlight'
Set-Alias -Name 'Disable-WinDebloat7Settings365Ads' -Value 'Disable-WinDebloatSettings365Ads'
Set-Alias -Name 'Enable-WinDebloat7UltimatePower' -Value 'Enable-WinDebloatUltimatePower'
Set-Alias -Name 'Disable-WinDebloat7UltimatePower' -Value 'Disable-WinDebloatUltimatePower'
Set-Alias -Name 'Invoke-WinDebloat7SysprepDefaults' -Value 'Invoke-WinDebloatSysprepDefaults'
Set-Alias -Name 'Set-WinDebloat7RegistryValue' -Value 'Set-WinDebloatRegistryValue'

Export-ModuleMember -Function @(
    # AI Tweaks
    'Disable-WinDebloatAIRecall',
    'Disable-WinDebloatCopilot',
    'Disable-WinDebloatClickToDo',
    'Disable-WinDebloatNotepadAI',
    'Disable-WinDebloatPaintAI',
    'Disable-WinDebloatEdgeAI',
    # Privacy Tweaks
    'Disable-WinDebloatDesktopSpotlight',
    'Disable-WinDebloatSettings365Ads',
    # Power Tweaks
    'Enable-WinDebloatUltimatePower',
    'Disable-WinDebloatUltimatePower',
    # Sysprep
    'Invoke-WinDebloatSysprepDefaults',
    # Helper
    'Set-WinDebloatRegistryValue'
) -Alias @(
    'Disable-WinDebloat7AIRecall',
    'Disable-WinDebloat7Copilot',
    'Disable-WinDebloat7ClickToDo',
    'Disable-WinDebloat7NotepadAI',
    'Disable-WinDebloat7PaintAI',
    'Disable-WinDebloat7EdgeAI',
    'Disable-WinDebloat7DesktopSpotlight',
    'Disable-WinDebloat7Settings365Ads',
    'Enable-WinDebloat7UltimatePower',
    'Disable-WinDebloat7UltimatePower',
    'Invoke-WinDebloat7SysprepDefaults',
    'Set-WinDebloat7RegistryValue'
)
