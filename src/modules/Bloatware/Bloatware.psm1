#Requires -Version 7.6

<#
.SYNOPSIS
    Bloatware management module for Win-Debloat
    
.DESCRIPTION
    Handles identification and removal of pre-installed Windows apps (UWP).
    Uses PowerShell 7.6 best practices with proper error handling.
    
.NOTES
    Module: Win-Debloat.Modules.Bloatware
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force

#region Bloatware Definitions
# Apps are tiered so removal_mode actually changes behavior:
#   Conservative = ThirdParty (sponsored/OEM junk only)
#   Moderate     = ThirdParty + Microsoft consumer bloat
#   Aggressive   = everything, including Xbox/Copilot ecosystem
$Script:BloatwareCategories = @{
    ThirdParty = @(
        # Sponsored / Streaming / Social
        "Disney", "SpotifyAB.SpotifyMusic", "PandoraMedia", "AmazonVideo.PrimeVideo", "Netflix",
        "Facebook", "Instagram", "Twitter", "TikTok", "CandyCrush", "BubbleWitch", "FarmVille",
        "BytedancePte.Ltd.TikTok", "DolbyLaboratories.DolbyAccess", "Duolingo-LearnLanguagesforFree",
        "EclipseManager", "ActiproSoftwareLLC", "AdobeSystemsIncorporated.AdobePhotoshopExpress",
        "Amazon.com.Amazon", "Flipboard", "iHeartRadio", "HULULLC.HULUPLUS", "SlingTV",
        "TuneInRadio", "WinZipUniversal", "ACGMediaPlayer", "Asphalt8Airborne", "AutodeskSketchBook",
        "CaesarsSlotsFreeCasino", "COOKINGFEVER", "CyberLinkMediaSuiteEssentials", "DrawboardPDF",
        "flaregamesGmbH.RoyalRevolt", "HiddenCity", "MarchofEmpires", "NYTCrossword", "OneCalendar",
        "PhototasticCollage", "PicsArt-PhotoStudio", "PolarrPhotoEditorAcademicEdition",
        "Sidia.LiveWallpaper", "LinkedInforWindows",

        # HP OEM Bloat
        "AD2F1837.HPJumpStarts", "AD2F1837.HPPCHardwareDiagnosticsWindows", "AD2F1837.HPPowerManager",
        "AD2F1837.HPPrivacySettings", "AD2F1837.HPSupportAssistant", "AD2F1837.HPSystemInformation",
        "AD2F1837.HPQuickDrop", "AD2F1837.HPWorkWell", "AD2F1837.HPDesktopSupportUtilities",
        "AD2F1837.myHP", "AD2F1837.HPEasyClean", "AD2F1837.HPAudioCenter", "AD2F1837.HPAIExperienceCenter",
        "AD2F1837.HPConnectedMusic", "AD2F1837.HPConnectedPhotopoweredbySnapfish", "AD2F1837.HPFileViewer",
        "AD2F1837.HPPrinterControl", "AD2F1837.HPQuickTouch", "AD2F1837.HPRegistration",
        "AD2F1837.HPSureShieldAI", "AD2F1837.HPWelcome",

        # Dell OEM Bloat
        "DellInc.DellSupportAssistforPCs", "DellInc.DellPowerManager", "DellInc.DellDigitalDelivery",
        "DellInc.DellCustomerConnect", "DellInc.DellCommandUpdate", "DellInc.DellDigitalLifestyle",
        "DellInc.PartnerPromo", "DellInc.DellOptimizer", "DellInc.DellUpdate", "DellInc.DellMobileConnect",

        # Lenovo OEM Bloat
        "E046963F.LenovoCompanion", "E046963F.LenovoSettings", "LenovoCorporation.LenovoID",
        "LenovoCompanyLimited.LenovoVantageService",

        # Acer OEM Bloat
        "AcerIncorporated.AcerCare", "AcerIncorporated.AcerQuickAccess"
    )

    Microsoft  = @(
        "Microsoft.3DBuilder", "Microsoft.BingFinance", "Microsoft.BingNews", "Microsoft.BingSports",
        "Microsoft.BingWeather", "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub", "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MixedReality.Portal",
        "Microsoft.OneConnect", "Microsoft.People", "Microsoft.PowerAutomateDesktop", "Microsoft.Print3D",
        "Microsoft.SkypeApp", "Microsoft.Todos", "Microsoft.WindowsAlarms", "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps", "Microsoft.WindowsSoundRecorder", "Microsoft.YourPhone",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.Teams", "Microsoft.MSTeams",
        "Microsoft.OutlookForWindows", "Microsoft.Windows.DevHome", "Clipchamp.Clipchamp", "Microsoft.Whiteboard",
        # Cortana (discontinued) & Bing consumer apps
        "Microsoft.549981C3F5F10", "Microsoft.BingFoodAndDrink", "Microsoft.BingHealthAndFitness",
        "Microsoft.BingSearch", "Microsoft.BingTranslator", "Microsoft.BingTravel",
        # Other Microsoft consumer bloat
        "Microsoft.News", "Microsoft.Messaging", "Microsoft.MicrosoftJournal",
        "Microsoft.MicrosoftPowerBIForWindows", "Microsoft.NetworkSpeedTest", "Microsoft.Office.Sway",
        "Microsoft.PCManager", "Microsoft.M365Companions", "Microsoft.StartExperiencesApp",
        "MicrosoftWindows.CrossDevice", "Microsoft.Xbox.TCUI"
    )

    Aggressive = @(
        # AI / Copilot / Widgets ecosystem
        "Microsoft.Copilot", "MicrosoftWindows.Client.CoPilot", "MicrosoftWindows.Client.WebExperience",
        "Microsoft.Windows.Ai.Copilot.Provider", "Microsoft.Windows.AIHub", "Microsoft.WidgetsPlatformRuntime",
        "MicrosoftCorporationII.QuickAssist",

        # Xbox ecosystem
        "Microsoft.XboxApp", "Microsoft.GamingApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay"
    )
}
#endregion

<#
.SYNOPSIS
    Gets the list of bloatware apps that can be removed.

.PARAMETER Mode
    Removal tier to return: Conservative, Moderate, or Aggressive (default: all).

.OUTPUTS
    [string[]] Array of app package names.
#>
function Get-WinDebloatBloatwareList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [ValidateSet("Conservative", "Moderate", "Aggressive")]
        [string]$Mode = "Aggressive"
    )

    switch ($Mode) {
        "Conservative" { return $Script:BloatwareCategories.ThirdParty }
        "Moderate" { return $Script:BloatwareCategories.ThirdParty + $Script:BloatwareCategories.Microsoft }
        default { return $Script:BloatwareCategories.ThirdParty + $Script:BloatwareCategories.Microsoft + $Script:BloatwareCategories.Aggressive }
    }
}

<#
.SYNOPSIS
    Removes bloatware applications based on configuration.
    
.DESCRIPTION
    Removes UWP apps from the current user and all users,
    plus removes provisioned packages to prevent reinstallation.
    
.PARAMETER Config
    The configuration object loaded from a YAML profile.
    
.OUTPUTS
    [void]
    
.EXAMPLE
    Remove-WinDebloatBloatware -Config $config
#>
function Remove-WinDebloatBloatware {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Config
    )
    
    # Validate config has bloatware section
    if (-not $Config.bloatware) {
        Write-Log -Message "No bloatware configuration found in profile." -Level Warning
        return
    }
    
    $removalMode = $Config.bloatware.removal_mode
    $excludeList = $Config.bloatware.exclude_list ?? @()
    
    Write-Log -Message "Starting Bloatware Removal (Mode: $removalMode)" -Level Info
    
    if ($removalMode -eq "None") {
        Write-Log -Message "Removal Mode is None. Skipping." -Level Warning
        return
    }

    # Performance: Fetch all packages ONCE instead of loop-by-loop (already optimized)
    Write-Log -Message "Scanning installed packages (this may take a moment)..." -Level Info
    
    try {
        $currentPackages = Get-AppxPackage -AllUsers -ErrorAction Stop
        $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction Stop
    }
    catch {
        Write-Log -Message "Failed to enumerate packages: $($_.Exception.Message)" -Level Error
        return
    }
    
    # Track results
    $successCount = 0
    $failCount = 0
    $skippedCount = 0
    
    # Determine which apps to target (custom_list or built-in tier for the removal mode)
    $targetApps = if ($Config.bloatware.custom_list -and $Config.bloatware.custom_list.Count -gt 0) {
        Write-Log -Message "Using custom bloatware list from profile ($($Config.bloatware.custom_list.Count) apps)" -Level Info
        $Config.bloatware.custom_list
    }
    elseif ($removalMode -in @("Conservative", "Moderate", "Aggressive")) {
        Get-WinDebloatBloatwareList -Mode $removalMode
    }
    else {
        Get-WinDebloatBloatwareList -Mode Moderate
    }
    
    $total = [math]::Max(1, ($currentPackages.Count + $provisionedPackages.Count))
    $current = 0
    
    # Protected immutable system whitelist
    $immutableWhitelistRegex = '^(Microsoft\.(WindowsStore|DesktopAppInstaller|StorePurchaseApp|SecHealthUI|WindowsTerminal|Windows\.ShellExperienceHost|Windows\.StartMenuExperienceHost|Windows\.AccountsControl|AAD\.BrokerPlugin|Windows\.CloudExperienceHost|Windows\.Search|VCLibs|NET\.Native|UI\.Xaml|Services\.Store\.Engagement|WindowsAppRuntime|DirectX|HEIFImageExtension|VP9VideoExtensions|WebMediaExtensions|WebpImageExtension|RawImageExtension|AV1VideoExtension|Windows\.Apprep\.ChxApp|Windows\.CapturePicker))'
    $whitelistCompiled = [regex]::new($immutableWhitelistRegex, [RegexOptions]::Compiled -bor [RegexOptions]::IgnoreCase)

    # Pre-compiled regex options
    $regexOptions = [RegexOptions]::Compiled -bor [RegexOptions]::IgnoreCase

    # Helper scriptblock to convert glob patterns (*, ?) to pre-compiled regex objects
    $convertGlobToRegex = {
        param([string[]]$Patterns)
        if (-not $Patterns -or $Patterns.Count -eq 0) { return $null }
        $patternStr = ($Patterns | ForEach-Object { 
            if ($_ -match '\*|\?') {
                [regex]::Escape($_).Replace('\*', '.*').Replace('\?', '.')
            }
            else {
                [regex]::Escape($_)
            }
        }) -join '|'
        return [regex]::new($patternStr, $regexOptions)
    }

    # Build pre-compiled regex patterns for matching with glob support
    $excludeRegex = & $convertGlobToRegex $excludeList
    $targetsRegex = & $convertGlobToRegex $targetApps
    if (-not $targetsRegex) { return }

    # Iterate packages once
    foreach ($pkg in $currentPackages) {
        $current++
        if ($current % 50 -eq 0) { Write-Progress -Activity "Removing Bloatware" -Status "Scanning $($pkg.Name)" -PercentComplete ([math]::Round(($current / $total) * 100)) }

        # Check immutable whitelist first
        if ($pkg.Name -and $whitelistCompiled.IsMatch($pkg.Name)) {
            continue
        }

        if ($pkg.Name -and $targetsRegex.IsMatch($pkg.Name)) {
            # Double check exclusion pattern
            if ($excludeRegex -and $excludeRegex.IsMatch($pkg.Name)) {
                $skippedCount++
                continue
            }
            
            if ($PSCmdlet.ShouldProcess($pkg.Name, "Remove Bloatware")) {
                try {
                    Write-Log -Message "Removing: $($pkg.Name)" -Level Info
                    $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    $successCount++
                }
                catch {
                    Write-Log -Message "Failed to remove '$($pkg.Name)': $($_.Exception.Message)" -Level Warning
                    $failCount++
                }
            }
        }
    }
    
    # Iterate provisioned once
    foreach ($pkg in $provisionedPackages) {
        $current++
        $dispName = if ($pkg.DisplayName) { $pkg.DisplayName } else { $pkg.PackageName }
        if ($current % 50 -eq 0) { 
            Write-Progress -Activity "Removing Bloatware" -Status "Checking $dispName" -PercentComplete ([math]::Round(($current / $total) * 100))
        }

        # Check immutable whitelist first
        if (($dispName -and $whitelistCompiled.IsMatch($dispName)) -or ($pkg.PackageName -and $whitelistCompiled.IsMatch($pkg.PackageName))) {
            continue
        }

        if (($dispName -and $targetsRegex.IsMatch($dispName)) -or ($pkg.PackageName -and $targetsRegex.IsMatch($pkg.PackageName))) {
            if ($excludeRegex -and (($dispName -and $excludeRegex.IsMatch($dispName)) -or ($pkg.PackageName -and $excludeRegex.IsMatch($pkg.PackageName)))) {
                $skippedCount++
                continue
            }
            
            if ($PSCmdlet.ShouldProcess($dispName, "Deprovision Bloatware")) {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                    Write-Log -Message "Deprovisioned: $dispName" -Level Info
                }
                catch {
                    Write-Log -Message "Failed deprovision '$dispName': $($_.Exception.Message)" -Level Debug
                }
            }
        }
    }
    
    Write-Progress -Activity "Removing Bloatware" -Completed
    
    # Summary
    Write-Log -Message "Bloatware removal complete: $successCount removed, $skippedCount preserved, $failCount failed" -Level ($failCount -eq 0 ? "Success" : "Warning")
}

#region Advanced Removal

<#
.SYNOPSIS
    Removes OneDrive completely and safely without deleting user files.
#>
function Uninstall-WinDebloatOneDrive {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()

    Write-Log -Message "Starting OneDrive Removal..." -Level Info

    if ($PSCmdlet.ShouldProcess("System", "Uninstall OneDrive")) {
        # 1. Kill Processes
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        
        # 2. Run Uninstaller
        $uninstallers = @(
            "$env:systemroot\System32\OneDriveSetup.exe",
            "$env:systemroot\SysWOW64\OneDriveSetup.exe"
        )
        
        foreach ($exe in $uninstallers) {
            if (Test-Path $exe) {
                Write-Log -Message "Running uninstaller: $exe" -Level Info
                Start-Process -FilePath $exe -ArgumentList "/uninstall" -Wait -WindowStyle Hidden
            }
        }
        
        # 3. Cleanup Files (Application directories only - NEVER delete $env:userprofile\OneDrive to protect user docs)
        $paths = @(
            "$env:localappdata\Microsoft\OneDrive",
            "$env:programdata\Microsoft OneDrive"
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # 4. Registry Disable
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1 -Type DWord
        
        Write-Log -Message "OneDrive removed and disabled." -Level Success
    }
}

<#
.SYNOPSIS
    Removes Microsoft Edge (Advanced/Risky).
#>
function Uninstall-WinDebloatEdge {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()

    Write-Log -Message "Starting Edge Removal (Warning: This may break WebViews)..." -Level Warning

    if ($PSCmdlet.ShouldProcess("Microsoft Edge", "Force Uninstall")) {
        # 1. Prevent Reinstall
        Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\EdgeUpdate" -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord

        # 2. Find and Run Check for setup.exe in Program Files
        $installerPattern = "$env:SystemDrive\Program Files (x86)\Microsoft\Edge\Application\*\Installer\setup.exe"
        $installers = Get-ChildItem -Path $installerPattern -ErrorAction SilentlyContinue

        if ($installers) {
            foreach ($setup in $installers) {
                Write-Log -Message "Running Edge uninstaller..." -Level Info
                Start-Process -FilePath $setup.FullName -ArgumentList "--uninstall", "--system-level", "--verbose-logging", "--force-uninstall" -Wait -WindowStyle Hidden
            }
            Write-Log -Message "Edge uninstalled." -Level Success
        }
        else {
            Write-Log -Message "Edge installer not found (could be already removed)." -Level Info
        }
        
        # 3. Remove Appx
        Get-AppxPackage -AllUsers *MicrosoftEdge* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Removes Xbox Apps and Services.
#>
function Uninstall-WinDebloatXbox {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()

    Write-Log -Message "Starting Xbox Removal..." -Level Info

    if ($PSCmdlet.ShouldProcess("Xbox Services & Apps", "Uninstall")) {
        # 1. Services
        $services = @("XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc")
        foreach ($svc in $services) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        }

        # 2. Apps (Installed & Provisioned)
        $apps = @(
            "*XboxApp*", "*XboxGameOverlay*", "*XboxGamingOverlay*", "*XboxSpeechToTextOverlay*", 
            "*GamingApp*", "*GamingServices*", "*XboxIdentityProvider*"
        )
        $xboxRegexOptions = [RegexOptions]::Compiled -bor [RegexOptions]::IgnoreCase
        $xboxPattern = ($apps | ForEach-Object { [regex]::Escape($_).Replace('\*', '.*') }) -join '|'
        $xboxRegex = [regex]::new($xboxPattern, $xboxRegexOptions)

        # Single batched query instead of per-app loop
        $installedPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        if ($installedPackages) {
            $installedPackages | Where-Object { $_.Name -and $xboxRegex.IsMatch($_.Name) } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }

        # 3. Deprovision
        try {
            $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            if ($provisioned) {
                $provisioned | Where-Object { 
                    ($_.PackageName -and $xboxRegex.IsMatch($_.PackageName)) -or 
                    ($_.DisplayName -and $xboxRegex.IsMatch($_.DisplayName)) 
                } | ForEach-Object {
                    Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
        catch {
            Write-Verbose "Could not deprovision Xbox packages: $($_.Exception.Message)"
        }
        
        Write-Log -Message "Xbox apps and services removed." -Level Success
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Get-WinDebloat7BloatwareList' -Value 'Get-WinDebloatBloatwareList'
Set-Alias -Name 'Remove-WinDebloat7Bloatware' -Value 'Remove-WinDebloatBloatware'
Set-Alias -Name 'Uninstall-WinDebloat7OneDrive' -Value 'Uninstall-WinDebloatOneDrive'
Set-Alias -Name 'Uninstall-WinDebloat7Edge' -Value 'Uninstall-WinDebloatEdge'
Set-Alias -Name 'Uninstall-WinDebloat7Xbox' -Value 'Uninstall-WinDebloatXbox'

Export-ModuleMember -Function @(
    "Get-WinDebloatBloatwareList", 
    "Remove-WinDebloatBloatware",
    "Uninstall-WinDebloatOneDrive",
    "Uninstall-WinDebloatEdge",
    "Uninstall-WinDebloatXbox"
) -Alias @(
    "Get-WinDebloat7BloatwareList",
    "Remove-WinDebloat7Bloatware",
    "Uninstall-WinDebloat7OneDrive",
    "Uninstall-WinDebloat7Edge",
    "Uninstall-WinDebloat7Xbox"
)
