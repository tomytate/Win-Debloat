#Requires -Version 7.6

<#
.SYNOPSIS
    Windows Features Management module for Win-Debloat
    
.DESCRIPTION
    Manages Windows Optional Features and Capabilities.
    Disables unused features (Fax, IIS) and removes legacy capabilities (WordPad, Math Recognizer).
    
.NOTES
    Module: Win-Debloat.Modules.Features
    Version: 2.0.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

#region Optional Features

<#
.SYNOPSIS
    Disables specified Optional Features.
    
.PARAMETER Features
    List of features to disable.
#>
function Set-WinDebloatOptionalFeatures {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [string[]]$Features = @(
            "FaxServicesClientPackage",
            "IIS-WebServerRole",
            "LegacyComponents",
            "MicrosoftWindowsPowerShellV2",
            "MicrosoftWindowsPowerShellV2Root",
            "WorkFolders-Client",
            "Printing-XPSServices-Features",
            "TelnetClient",
            "SMB1Protocol"
        ),
        [switch]$Enable
    )

    $action = if ($Enable) { "Enable" } else { "Disable" }
    Write-Log -Message "$action Windows Features..." -Level Info
    $restartRequired = $false

    if ($PSCmdlet.ShouldProcess("Optional Features", "$action List")) {
        foreach ($feat in $Features) {
            try {
                $featureObj = Get-WindowsOptionalFeature -Online -FeatureName $feat -ErrorAction SilentlyContinue
                if ($featureObj) {
                    if ($Enable) {
                        $res = Enable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -ErrorAction Stop
                        Write-Log -Message "Enabled: $feat" -Level Info
                        if ($res -and $res.RestartNeeded) { $restartRequired = $true }
                    }
                    else {
                        $res = Disable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -ErrorAction Stop
                        Write-Log -Message "Disabled: $feat" -Level Info
                        if ($res -and $res.RestartNeeded) { $restartRequired = $true }
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to $action feature '$feat': $($_.Exception.Message)" -Level Warning
            }
        }
        
        if ($restartRequired) {
            Write-Log -Message "Optional Features processed. A system restart is required to finalize changes." -Level Warning
        }
        else {
            Write-Log -Message "Optional Features processed successfully." -Level Success
        }
    }
}

#endregion

#region Capabilities

<#
.SYNOPSIS
    Removes specified Windows Capabilities.
    
.PARAMETER Capabilities
    List of capabilities to remove.
#>
function Remove-WinDebloatCapabilities {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [string[]]$Capabilities = @(
            "App.StepsRecorder*",
            "Browser.InternetExplorer*",
            "MathRecognizer*",
            "Microsoft.Windows.WordPad*",
            "Print.Fax.Scan*",
            "XPS.Viewer*"
        )
    )

    Write-Log -Message "Querying installed Windows Capabilities..." -Level Info
    $restartRequired = $false

    if ($PSCmdlet.ShouldProcess("Capabilities", "Remove List")) {
        try {
            $installedCaps = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.State -eq 'Installed' }
            foreach ($capName in $Capabilities) {
                $matched = $installedCaps | Where-Object { $_.Name -like $capName }
                foreach ($c in $matched) {
                    try {
                        Write-Log -Message "Removing: $($c.Name)" -Level Info
                        $res = Remove-WindowsCapability -Online -Name $c.Name -ErrorAction Stop
                        if ($res -and $res.RestartNeeded) { $restartRequired = $true }
                    }
                    catch {
                        Write-Log -Message "Failed to remove capability '$($c.Name)': $($_.Exception.Message)" -Level Warning
                    }
                }
            }

            if ($restartRequired) {
                Write-Log -Message "Capabilities removal complete. A reboot is required to finalize removal." -Level Warning
            }
            else {
                Write-Log -Message "Capabilities removal complete." -Level Success
            }
        }
        catch {
            Write-Log -Message "Error querying Windows Capabilities: $($_.Exception.Message)" -Level Error
        }
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7OptionalFeatures' -Value 'Set-WinDebloatOptionalFeatures'
Set-Alias -Name 'Remove-WinDebloat7Capabilities' -Value 'Remove-WinDebloatCapabilities'
Set-Alias -Name 'Set-WinDebloatFeatures' -Value 'Set-WinDebloatOptionalFeatures'
Set-Alias -Name 'Set-WinDebloat7Features' -Value 'Set-WinDebloatOptionalFeatures'
Set-Alias -Name 'Remove-WinDebloatCapability' -Value 'Remove-WinDebloatCapabilities'
Set-Alias -Name 'Remove-WinDebloat7Capability' -Value 'Remove-WinDebloatCapabilities'

Export-ModuleMember -Function @(
    'Set-WinDebloatOptionalFeatures',
    'Remove-WinDebloatCapabilities'
) -Alias @(
    'Set-WinDebloat7OptionalFeatures',
    'Remove-WinDebloat7Capabilities',
    'Set-WinDebloatFeatures',
    'Set-WinDebloat7Features',
    'Remove-WinDebloatCapability',
    'Remove-WinDebloat7Capability'
)
