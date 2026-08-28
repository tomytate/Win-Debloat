#Requires -Version 7.6

<#
.SYNOPSIS
    Software and package management module for Win-Debloat7
    
.DESCRIPTION
    Handles Winget and Chocolatey package installation with a comprehensive
    curated essentials list. Supports both package managers with auto-detection.
    
.NOTES
    Module: Win-Debloat.Modules.Software
    Version: 1.6.0
.LINK
    https://learn.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation
using namespace System.Collections.Generic

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

#region Package Manager Detection

<#
.SYNOPSIS
    Tests if a package manager is installed.
    
.PARAMETER Name
    The package manager to check: Winget or Chocolatey.
    
.OUTPUTS
    [bool] True if installed.
#>
function Test-PackageManager {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Winget", "Chocolatey", "Npm", "Msstore", "PSResourceGet")]
        [string]$Name
    )

    switch ($Name) {
        "Winget" {
            try {
                $null = Get-Command winget -ErrorAction Stop
                return $true
            }
            catch {
                return $false
            }
        }
        "Chocolatey" {
            try {
                $null = Get-Command choco -ErrorAction Stop
                return $true
            }
            catch {
                return $false
            }
        }
        "Npm" {
            if (Get-Command npm -ErrorAction SilentlyContinue) { return $true }
            # PATH may be stale right after a Node.js install
            return (Test-Path (Join-Path $env:ProgramFiles "nodejs\npm.cmd"))
        }
        "Msstore" {
            # Microsoft Store installs ride the winget CLI (--source msstore)
            return [bool](Get-Command winget -ErrorAction SilentlyContinue)
        }
        "PSResourceGet" {
            try {
                $null = Get-Command Install-PSResource -ErrorAction Stop
                return $true
            }
            catch {
                return $false
            }
        }
    }
    return $false
}

<#
.SYNOPSIS
    Installs a package manager if not present.
    
.PARAMETER Name
    Package manager to install: Winget, Chocolatey, Npm (installs Node.js LTS), or PSResourceGet.

.PARAMETER Force
    Skip confirmation prompt.
#>
function Install-PackageManager {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Winget", "Chocolatey", "Npm", "Msstore", "PSResourceGet")]
        [string]$Name,

        [switch]$Force
    )
    
    if ($Name -eq "Msstore") { $Name = "Winget" } # Store installs just need winget

    if (Test-PackageManager -Name $Name) {
        Write-Log -Message "$Name is already installed." -Level Info
        return $true
    }
    
    if (-not $Force) {
        $response = Read-Host "Install $Name? [Y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-Log -Message "User declined $Name installation." -Level Warning
            return $false
        }
    }
    
    switch ($Name) {
        "Winget" {
            Write-Log -Message "Installing Winget via Microsoft Store..." -Level Info
            try {
                # Winget comes with App Installer - trigger store update
                if ($PSCmdlet.ShouldProcess("Winget", "Install via Add-AppxPackage")) {
                    # Download latest release from GitHub
                    $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
                    $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
                    $msixUrl = $release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1 -ExpandProperty browser_download_url
                    
                    $tempPath = "$env:TEMP\winget.msixbundle"
                    # PS 7.5+ Retry Logic
                    Invoke-WebRequest -Uri $msixUrl -OutFile $tempPath -MaximumRetryCount 3 -RetryIntervalSec 5 -ErrorAction Stop
                    Add-AppxPackage -Path $tempPath -ErrorAction Stop
                    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
                    
                    Write-Log -Message "Winget installed successfully." -Level Success
                    return $true
                }
            }
            catch {
                Write-Log -Message "Failed to install Winget: $($_.Exception.Message)" -Level Error
                return $false
            }
        }
        "Chocolatey" {
            Write-Log -Message "Installing Chocolatey..." -Level Info
            try {
                if ($PSCmdlet.ShouldProcess("Chocolatey", "Install via official script")) {
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    
                    # Modern PS 7.5+ Installation (Resilient)
                    $chocoScript = Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -MaximumRetryCount 3 -RetryIntervalSec 5 -UseBasicParsing -ErrorAction Stop
                    $scriptPath = "$env:TEMP\choco_install_$(New-Guid).ps1"
                    $chocoScript.Content | Set-Content -Path $scriptPath -Force
                    & $scriptPath
                    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
                    
                    Write-Log -Message "Chocolatey installed successfully." -Level Success
                    return $true
                }
            }
            catch {
                Write-Log -Message "Failed to install Chocolatey: $($_.Exception.Message)" -Level Error
                return $false
            }
        }
        "Npm" {
            Write-Log -Message "Installing Node.js LTS (provides npm)..." -Level Info
            try {
                if ($PSCmdlet.ShouldProcess("Node.js LTS", "Install via winget")) {
                    $exitCode = Invoke-WD7PackageInstall -Provider Winget -PackageId "OpenJS.NodeJS.LTS" -Quiet
                    if ($exitCode -eq 0 -and (Test-PackageManager -Name Npm)) {
                        Write-Log -Message "Node.js LTS installed successfully." -Level Success
                        return $true
                    }
                    Write-Log -Message "Node.js installation failed (Exit: $exitCode)." -Level Error
                    return $false
                }
            }
            catch {
                Write-Log -Message "Failed to install Node.js: $($_.Exception.Message)" -Level Error
                return $false
            }
        }
        "PSResourceGet" {
            Write-Log -Message "Installing PSResourceGet..." -Level Info
            try {
                if ($PSCmdlet.ShouldProcess("PSResourceGet", "Install via Install-Module")) {
                    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                    Write-Log -Message "PSResourceGet installed successfully." -Level Success
                    return $true
                }
            }
            catch {
                Write-Log -Message "Failed to install PSResourceGet: $($_.Exception.Message)" -Level Error
                return $false
            }
        }
    }

    return $false
}

#endregion

#region Essentials List

# Comprehensive curated app list by category
$Script:EssentialsApps = @{
    # === BROWSERS ===
    Browsers      = @{
        DisplayName = "Web Browsers"
        Apps        = @(
            @{ Name = "Mozilla Firefox"; Winget = "Mozilla.Firefox"; Choco = "firefox" }
            @{ Name = "Google Chrome"; Winget = "Google.Chrome"; Choco = "googlechrome" }
            @{ Name = "Brave Browser"; Winget = "Brave.Brave"; Choco = "brave" }
            @{ Name = "Microsoft Edge"; Winget = "Microsoft.Edge"; Choco = "microsoft-edge" }
            @{ Name = "Vivaldi"; Winget = "Vivaldi.Vivaldi"; Choco = "vivaldi" }
            @{ Name = "Opera GX"; Winget = "Opera.OperaGX"; Choco = "opera-gx" }
            @{ Name = "LibreWolf"; Winget = "LibreWolf.LibreWolf"; Choco = "librewolf" }
            @{ Name = "Tor Browser"; Winget = "TorProject.TorBrowser"; Choco = "tor-browser" }
            @{ Name = "Arc Browser"; Winget = "TheBrowserCompany.Arc"; Choco = "" }
            @{ Name = "Zen Browser"; Winget = "Zen-Team.Zen-Browser"; Choco = "" }
            @{ Name = "Waterfox"; Winget = "Waterfox.Waterfox"; Choco = "waterfox" }
            @{ Name = "Floorp"; Winget = "Ablaze.Floorp"; Choco = "floorp" }
        )
    }
    
    # === RUNTIMES ===
    Runtimes      = @{
        DisplayName = "Runtimes & Frameworks"
        Apps        = @(
            @{ Name = ".NET 8 Desktop Runtime"; Winget = "Microsoft.DotNet.DesktopRuntime.8"; Choco = "dotnet-8.0-desktopruntime" }
            @{ Name = ".NET 9 Desktop Runtime"; Winget = "Microsoft.DotNet.DesktopRuntime.9"; Choco = "dotnet-9.0-desktopruntime" }
            @{ Name = "VC++ 2015-2022 Redist"; Winget = "Microsoft.VCRedist.2015+.x64"; Choco = "vcredist140" }
            @{ Name = "VC++ 2015-2022 Redist (x86)"; Winget = "Microsoft.VCRedist.2015+.x86"; Choco = "vcredist140" }
            @{ Name = "Java Runtime (Temurin)"; Winget = "EclipseAdoptium.Temurin.21.JRE"; Choco = "temurin21jre" }
            @{ Name = "Java Development Kit"; Winget = "EclipseAdoptium.Temurin.21.JDK"; Choco = "temurin21" }
            @{ Name = "Node.js LTS"; Winget = "OpenJS.NodeJS.LTS"; Choco = "nodejs-lts" }
            @{ Name = "Python 3.12"; Winget = "Python.Python.3.12"; Choco = "python312" }
            @{ Name = "DirectX Runtime"; Winget = ""; Choco = "directx" }
            @{ Name = ".NET 10 Desktop Runtime"; Winget = "Microsoft.DotNet.DesktopRuntime.10"; Choco = "dotnet-10.0-desktopruntime" }
            @{ Name = "Python 3.13"; Winget = "Python.Python.3.13"; Choco = "python313" }
        )
    }
    
    # === UTILITIES ===
    Utilities     = @{
        DisplayName = "System Utilities"
        Apps        = @(
            @{ Name = "7-Zip"; Winget = "7zip.7zip"; Choco = "7zip" }
            @{ Name = "WinRAR"; Winget = "RARLab.WinRAR"; Choco = "winrar" }
            @{ Name = "Everything Search"; Winget = "voidtools.Everything"; Choco = "everything" }
            @{ Name = "PowerToys"; Winget = "Microsoft.PowerToys"; Choco = "powertoys" }
            @{ Name = "Sysinternals Suite"; Winget = "Microsoft.Sysinternals.Suite"; Choco = "sysinternals" }
            @{ Name = "Process Explorer"; Winget = "Microsoft.Sysinternals.ProcessExplorer"; Choco = "procexp" }
            @{ Name = "HWiNFO"; Winget = "REALiX.HWiNFO"; Choco = "hwinfo" }
            @{ Name = "CPU-Z"; Winget = "CPUID.CPU-Z"; Choco = "cpu-z" }
            @{ Name = "GPU-Z"; Winget = "TechPowerUp.GPU-Z"; Choco = "gpu-z" }
            @{ Name = "CrystalDiskInfo"; Winget = "CrystalDewWorld.CrystalDiskInfo"; Choco = "crystaldiskinfo" }
            @{ Name = "TreeSize Free"; Winget = "JAMSoftware.TreeSize.Free"; Choco = "treesizefree" }
            @{ Name = "WizTree"; Winget = "AntibodySoftware.WizTree"; Choco = "wiztree" }
            @{ Name = "Revo Uninstaller"; Winget = "RevoUninstaller.RevoUninstaller"; Choco = "revo-uninstaller" }
            @{ Name = "BleachBit"; Winget = "BleachBit.BleachBit"; Choco = "bleachbit" }
            @{ Name = "Rufus"; Winget = "Rufus.Rufus"; Choco = "rufus" }
            @{ Name = "balenaEtcher"; Winget = "Balena.Etcher"; Choco = "etcher" }
            @{ Name = "UniGetUI (winget GUI)"; Winget = "Devolutions.UniGetUI"; Choco = "wingetui" }
            @{ Name = "NanaZip"; Winget = "M2Team.NanaZip"; Choco = "nanazip" }
            @{ Name = "FanControl"; Winget = "Rem0o.FanControl"; Choco = "" }
            @{ Name = "CrystalDiskMark"; Winget = "CrystalDewWorld.CrystalDiskMark"; Choco = "crystaldiskmark" }
            @{ Name = "EarTrumpet"; Winget = "File-New-Project.EarTrumpet"; Choco = "eartrumpet" }
            @{ Name = "Twinkle Tray"; Winget = "xanderfrangos.twinkletray"; Choco = "twinkle-tray" }
            @{ Name = "AutoHotkey"; Winget = "AutoHotkey.AutoHotkey"; Choco = "autohotkey" }
            @{ Name = "Flow Launcher"; Winget = "Flow-Launcher.Flow-Launcher"; Choco = "flow-launcher" }
            @{ Name = "Ditto Clipboard"; Winget = "Ditto.Ditto"; Choco = "ditto" }
            @{ Name = "LocalSend"; Winget = "LocalSend.LocalSend"; Choco = "localsend" }
        )
    }
    
    # === MEDIA ===
    Media         = @{
        DisplayName = "Media & Graphics"
        Apps        = @(
            @{ Name = "VLC Media Player"; Winget = "VideoLAN.VLC"; Choco = "vlc" }
            @{ Name = "MPC-HC"; Winget = "clsid2.mpc-hc"; Choco = "mpc-hc" }
            @{ Name = "mpv"; Winget = "mpv.net"; Choco = "mpv" }
            @{ Name = "Spotify"; Winget = "Spotify.Spotify"; Choco = "spotify" }
            @{ Name = "foobar2000"; Winget = "PeterPawlowski.foobar2000"; Choco = "foobar2000" }
            @{ Name = "ImageGlass"; Winget = "DuongDieuPhap.ImageGlass"; Choco = "imageglass" }
            @{ Name = "IrfanView"; Winget = "IrfanSkiljan.IrfanView"; Choco = "irfanview" }
            @{ Name = "ShareX"; Winget = "ShareX.ShareX"; Choco = "sharex" }
            @{ Name = "OBS Studio"; Winget = "OBSProject.OBSStudio"; Choco = "obs-studio" }
            @{ Name = "HandBrake"; Winget = "HandBrake.HandBrake"; Choco = "handbrake" }
            @{ Name = "Audacity"; Winget = "Audacity.Audacity"; Choco = "audacity" }
            @{ Name = "GIMP"; Winget = "GIMP.GIMP"; Choco = "gimp" }
            @{ Name = "Krita"; Winget = "KDE.Krita"; Choco = "krita" }
            @{ Name = "Inkscape"; Winget = "Inkscape.Inkscape"; Choco = "inkscape" }
            @{ Name = "Blender"; Winget = "BlenderFoundation.Blender"; Choco = "blender" }
            @{ Name = "paint.net"; Winget = "dotPDN.PaintDotNet"; Choco = "paint.net" }
            @{ Name = "Shotcut"; Winget = "Meltytech.Shotcut"; Choco = "shotcut" }
            @{ Name = "Kdenlive"; Winget = "KDE.Kdenlive"; Choco = "kdenlive" }
            @{ Name = "Greenshot"; Winget = "Greenshot.Greenshot"; Choco = "greenshot" }
            @{ Name = "Plex"; Winget = "Plex.Plex"; Choco = "plex" }
            @{ Name = "Jellyfin Media Player"; Winget = "Jellyfin.JellyfinMediaPlayer"; Choco = "jellyfin-media-player" }
        )
    }
    
    # === COMMUNICATION ===
    Communication = @{
        DisplayName = "Communication & Social"
        Apps        = @(
            @{ Name = "Discord"; Winget = "Discord.Discord"; Choco = "discord" }
            @{ Name = "Slack"; Winget = "SlackTechnologies.Slack"; Choco = "slack" }
            @{ Name = "Microsoft Teams (Work)"; Winget = "Microsoft.Teams"; Choco = "microsoft-teams" }
            @{ Name = "Microsoft Teams (Classic)"; Winget = "Microsoft.Teams.Classic"; Choco = "microsoft-teams" }
            @{ Name = "Zoom"; Winget = "Zoom.Zoom"; Choco = "zoom" }
            @{ Name = "Telegram"; Winget = "Telegram.TelegramDesktop"; Choco = "telegram" }
            @{ Name = "Signal"; Winget = "OpenWhisperSystems.Signal"; Choco = "signal" }
            @{ Name = "Thunderbird"; Winget = "Mozilla.Thunderbird"; Choco = "thunderbird" }
            @{ Name = "Element (Matrix)"; Winget = "Element.Element"; Choco = "element-desktop" }
            @{ Name = "TeamSpeak"; Winget = "TeamSpeakSystems.TeamSpeakClient"; Choco = "teamspeak" }
        )
    }
    
    # === SECURITY ===
    Security      = @{
        DisplayName = "Security & Privacy"
        Apps        = @(
            @{ Name = "Bitwarden"; Winget = "Bitwarden.Bitwarden"; Choco = "bitwarden" }
            @{ Name = "KeePassXC"; Winget = "KeePassXCTeam.KeePassXC"; Choco = "keepassxc" }
            @{ Name = "Malwarebytes"; Winget = "Malwarebytes.Malwarebytes"; Choco = "malwarebytes" }
            @{ Name = "ProtonVPN"; Winget = "Proton.ProtonVPN"; Choco = "protonvpn" }
            @{ Name = "Mullvad VPN"; Winget = "MullvadVPN.MullvadVPN"; Choco = "mullvad-app" }
            @{ Name = "WireGuard"; Winget = "WireGuard.WireGuard"; Choco = "wireguard" }
            @{ Name = "VeraCrypt"; Winget = "IDRIX.VeraCrypt"; Choco = "veracrypt" }
            @{ Name = "Gpg4win"; Winget = "GnuPG.Gpg4win"; Choco = "gpg4win" }
            @{ Name = "KeePass"; Winget = "DominikReichl.KeePass"; Choco = "keepass" }
            @{ Name = "Cryptomator"; Winget = "Cryptomator.Cryptomator"; Choco = "cryptomator" }
            @{ Name = "NordVPN"; Winget = "NordSecurity.NordVPN"; Choco = "nordvpn" }
            @{ Name = "AdGuard"; Winget = "AdGuard.AdGuard"; Choco = "" }
        )
    }
    
    # === DEV TOOLS ===
    DevTools      = @{
        DisplayName = "Developer Tools"
        Apps        = @(
            @{ Name = "Visual Studio Code"; Winget = "Microsoft.VisualStudioCode"; Choco = "vscode" }
            @{ Name = "Visual Studio 2022 Community"; Winget = "Microsoft.VisualStudio.2022.Community"; Choco = "visualstudio2022community" }

            @{ Name = "JetBrains Toolbox"; Winget = "JetBrains.Toolbox"; Choco = "jetbrainstoolbox" }
            @{ Name = "Sublime Text"; Winget = "SublimeHQ.SublimeText.4"; Choco = "sublimetext4" }
            @{ Name = "Notepad++"; Winget = "Notepad++.Notepad++"; Choco = "notepadplusplus" }
            @{ Name = "Git"; Winget = "Git.Git"; Choco = "git" }
            @{ Name = "GitHub Desktop"; Winget = "GitHub.GitHubDesktop"; Choco = "github-desktop" }
            @{ Name = "Windows Terminal"; Winget = "Microsoft.WindowsTerminal"; Choco = "microsoft-windows-terminal" }
            @{ Name = "PowerShell 7"; Winget = "Microsoft.PowerShell"; Choco = "powershell-core" }
            @{ Name = "Docker Desktop"; Winget = "Docker.DockerDesktop"; Choco = "docker-desktop" }
            @{ Name = "Postman"; Winget = "Postman.Postman"; Choco = "postman" }
            @{ Name = "HeidiSQL"; Winget = "HeidiSQL.HeidiSQL"; Choco = "heidisql" }
            @{ Name = "DBeaver"; Winget = "DBeaver.DBeaver.Community"; Choco = "dbeaver" }
            @{ Name = "WinSCP"; Winget = "WinSCP.WinSCP"; Choco = "winscp" }
            @{ Name = "PuTTY"; Winget = "PuTTY.PuTTY"; Choco = "putty" }
            @{ Name = "FileZilla"; Winget = ""; Choco = "filezilla" }
            @{ Name = "GitHub CLI"; Winget = "GitHub.cli"; Choco = "gh" }
            @{ Name = "Oh My Posh"; Winget = "JanDeDobbeleer.OhMyPosh"; Choco = "oh-my-posh" }
            @{ Name = "Neovim"; Winget = "Neovim.Neovim"; Choco = "neovim" }
            @{ Name = "Go"; Winget = "GoLang.Go"; Choco = "golang" }
            @{ Name = "Rust (rustup)"; Winget = "Rustlang.Rustup"; Choco = "rustup.install" }
            @{ Name = "Insomnia"; Winget = "Insomnia.Insomnia"; Choco = "insomnia-rest-api-client" }
            @{ Name = "Cursor"; Winget = "Anysphere.Cursor"; Choco = "" }
            @{ Name = "Windsurf"; Winget = "Codeium.Windsurf"; Choco = "" }
            @{ Name = "uv (Fast Python)"; Winget = "astral-sh.uv"; Choco = "uv" }
            @{ Name = "Bun (JS Runtime)"; Winget = "Oven-sh.Bun"; Choco = "bun" }
            @{ Name = "Deno 2"; Winget = "DenoLand.Deno"; Choco = "deno" }
            @{ Name = "OpenTofu"; Winget = "OpenTofu.OpenTofu"; Choco = "opentofu" }
            @{ Name = "Podman Desktop"; Winget = "RedHat.PodmanDesktop"; Choco = "podman-desktop" }
        )
    }
    
    # === GAMING ===
    Gaming        = @{
        DisplayName = "Gaming & Game Launchers"
        Apps        = @(
            @{ Name = "Steam"; Winget = "Valve.Steam"; Choco = "steam" }
            @{ Name = "Epic Games Launcher"; Winget = "EpicGames.EpicGamesLauncher"; Choco = "epicgameslauncher" }
            @{ Name = "GOG Galaxy"; Winget = "GOG.Galaxy"; Choco = "goggalaxy" }
            @{ Name = "EA App"; Winget = "ElectronicArts.EADesktop"; Choco = "ea-app" }
            @{ Name = "Ubisoft Connect"; Winget = "Ubisoft.Connect"; Choco = "ubisoft-connect" }
            @{ Name = "Battle.net"; Winget = "Blizzard.BattleNet"; Choco = "" }
            @{ Name = "Playnite"; Winget = "Playnite.Playnite"; Choco = "playnite" }
            @{ Name = "Heroic Games Launcher"; Winget = "HeroicGamesLauncher.HeroicGamesLauncher"; Choco = "heroic-games-launcher" }
            @{ Name = "MSI Afterburner"; Winget = "Guru3D.Afterburner"; Choco = "msiafterburner" }
            @{ Name = "RTSS"; Winget = "Guru3D.RTSS"; Choco = "" }
            @{ Name = "Prism Launcher"; Winget = "PrismLauncher.PrismLauncher"; Choco = "prismlauncher" }
            @{ Name = "Parsec"; Winget = "Parsec.Parsec"; Choco = "parsec" }
            @{ Name = "Moonlight (game streaming)"; Winget = "MoonlightGameStreamingProject.Moonlight"; Choco = "moonlight-qt" }
            @{ Name = "Sunshine (game host)"; Winget = "LizardByte.Sunshine"; Choco = "sunshine" }
        )
    }
    
    # === PRODUCTIVITY ===
    Productivity  = @{
        DisplayName = "Productivity & Office"
        Apps        = @(
            @{ Name = "Microsoft Office 365 (Online)"; Winget = "Microsoft.Office"; Choco = "office365business" }
            @{ Name = "LibreOffice"; Winget = "TheDocumentFoundation.LibreOffice"; Choco = "libreoffice-fresh" }
            @{ Name = "ONLYOFFICE"; Winget = "ONLYOFFICE.DesktopEditors"; Choco = "onlyoffice" }
            @{ Name = "Notion"; Winget = "Notion.Notion"; Choco = "notion" }
            @{ Name = "Obsidian"; Winget = "Obsidian.Obsidian"; Choco = "obsidian" }
            @{ Name = "Evernote"; Winget = "Evernote.Evernote"; Choco = "evernote" }
            @{ Name = "Adobe Reader DC"; Winget = "Adobe.Acrobat.Reader.64-bit"; Choco = "adobereader" }
            @{ Name = "Foxit Reader"; Winget = "Foxit.FoxitReader"; Choco = "foxitreader" }
            @{ Name = "SumatraPDF"; Winget = "SumatraPDF.SumatraPDF"; Choco = "sumatrapdf" }
            @{ Name = "Calibre"; Winget = "calibre.calibre"; Choco = "calibre" }
            @{ Name = "Joplin"; Winget = "Joplin.Joplin"; Choco = "joplin" }
            @{ Name = "Anki"; Winget = "Anki.Anki"; Choco = "anki" }
            @{ Name = "Zotero"; Winget = "DigitalScholar.Zotero"; Choco = "zotero" }
            @{ Name = "draw.io"; Winget = "JGraph.Draw"; Choco = "drawio" }
        )
    }
    
    # === NETWORK ===
    Network       = @{
        DisplayName = "Network & Download Tools"
        Apps        = @(
            @{ Name = "qBittorrent"; Winget = "qBittorrent.qBittorrent"; Choco = "qbittorrent" }
            @{ Name = "Free Download Manager"; Winget = "SoftDeluxe.FreeDownloadManager"; Choco = "freedownloadmanager" }
            @{ Name = "JDownloader"; Winget = "AppWork.JDownloader"; Choco = "jdownloader" }
            @{ Name = "Wireshark"; Winget = "WiresharkFoundation.Wireshark"; Choco = "wireshark" }
            @{ Name = "Nmap"; Winget = "Insecure.Nmap"; Choco = "nmap" }
            @{ Name = "Advanced IP Scanner"; Winget = "Famatech.AdvancedIPScanner"; Choco = "advanced-ip-scanner" }
            @{ Name = "Angry IP Scanner"; Winget = "angryziber.AngryIPScanner"; Choco = "angryip" }
            @{ Name = "Tailscale"; Winget = "Tailscale.Tailscale"; Choco = "tailscale" }
            @{ Name = "Syncthing"; Winget = "Syncthing.Syncthing"; Choco = "syncthing" }
            @{ Name = "RustDesk"; Winget = ""; Choco = "rustdesk" }
            @{ Name = "AnyDesk"; Winget = "AnyDesk.AnyDesk"; Choco = "anydesk" }
        )
    }
    
    # === DRIVERS ===
    Drivers       = @{
        DisplayName = "GPU Drivers & Tools"
        Apps        = @(
            @{ Name = "NVIDIA App"; Winget = ""; Choco = "nvidia-app" }
            @{ Name = "Intel Driver & Support Assistant"; Winget = "Intel.IntelDriverAndSupportAssistant"; Choco = "intel-dsa" }
            @{ Name = "DDU (Display Driver Uninstaller)"; Winget = "Wagnardsoft.DisplayDriverUninstaller"; Choco = "ddu" }
            @{ Name = "NVCleanstall"; Winget = "TechPowerUp.NVCleanstall"; Choco = "" }
            @{ Name = "Snappy Driver Installer Origin"; Winget = "GlennDelahoy.SnappyDriverInstallerOrigin"; Choco = "sdio" }
        )
    }

    # === AI TOOLS ===
    # CLIs published only to npm carry an Npm ID (Node.js LTS is provisioned
    # automatically); Store-only official apps (ChatGPT, Microsoft Copilot)
    # carry an Msstore ID. All IDs validated live 2026-07-06.
    AITools       = @{
        DisplayName = "AI Assistants & CLIs"
        Apps        = @(
            # CLIs / coding agents
            @{ Name = "Claude Code (CLI)"; Winget = "Anthropic.ClaudeCode"; Choco = ""; Npm = "@anthropic-ai/claude-code" }
            @{ Name = "Gemini CLI"; Winget = ""; Choco = "gemini-cli"; Npm = "@google/gemini-cli" }
            @{ Name = "OpenAI Codex (CLI)"; Winget = "OpenAI.Codex"; Choco = ""; Npm = "@openai/codex" }
            @{ Name = "GitHub Copilot CLI"; Winget = ""; Choco = ""; Npm = "@github/copilot" }

            # Official desktop assistants
            @{ Name = "Claude Desktop"; Winget = "Anthropic.Claude"; Choco = "claude" }
            @{ Name = "ChatGPT Desktop"; Winget = ""; Choco = ""; Msstore = "9NT1R1C2HH7J" }
            @{ Name = "Microsoft Copilot"; Winget = ""; Choco = ""; Msstore = "XP9CXNGPPJ97XX" }
            @{ Name = "Perplexity Desktop"; Winget = "Perplexity.Perplexity"; Choco = "" }
            @{ Name = "Perplexity Comet (AI browser)"; Winget = "Perplexity.Comet"; Choco = "" }

            # Multi-model clients & local LLM runners
            @{ Name = "Cherry Studio (multi-model)"; Winget = "kangfenmao.CherryStudio"; Choco = "" }
            @{ Name = "Chatbox (multi-model)"; Winget = "Bin-Huang.Chatbox"; Choco = "" }
            @{ Name = "Msty (local LLMs)"; Winget = "CloudStack.Msty"; Choco = "" }
            @{ Name = "Ollama (local LLMs)"; Winget = "Ollama.Ollama"; Choco = "ollama" }
            @{ Name = "LM Studio"; Winget = "ElementLabs.LMStudio"; Choco = "lm-studio" }
            @{ Name = "Jan"; Winget = "Jan.Jan"; Choco = "" }
            @{ Name = "GPT4All"; Winget = ""; Choco = "gpt4all" }
        )
    }
}

<#
.SYNOPSIS
    Gets the complete list of essential apps organized by category.
    
.OUTPUTS
    [hashtable] The essentials app dictionary.
#>
function Get-WinDebloatEssentialsList {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    return $Script:EssentialsApps
}

#endregion

#region Installation Functions

<#
.SYNOPSIS
    Runs a single package install via Winget, Chocolatey, Npm, Msstore, or PSResourceGet. (Internal helper)

.OUTPUTS
    [int] The installer process exit code (0 = success).
#>
function Invoke-WD7PackageInstall {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Dual-scope LastPackageError handling for caller scripts')]
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Winget", "Chocolatey", "Npm", "Msstore", "PSResourceGet")]
        [string]$Provider,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [switch]$Quiet
    )

    $Script:LastPackageError = $null
    $pkgError = $null
    $exitCode = 0

    switch ($Provider) {
        "Winget" {
            $cmdArgs = @("install", "--id", $PackageId, "--source", "winget", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity")
            if ($Quiet) { $cmdArgs += "--silent" }
            try {
                $null = & winget @cmdArgs 2> variable:pkgError
                $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            catch {
                $pkgError = $_.Exception.Message
                $exitCode = 1
            }
        }
        "Chocolatey" {
            $cmdArgs = @("install", $PackageId, "-y")
            if ($Quiet) { $cmdArgs += "--no-progress" }
            try {
                $null = & choco @cmdArgs 2> variable:pkgError
                $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            catch {
                $pkgError = $_.Exception.Message
                $exitCode = 1
            }
        }
        "Npm" {
            # Resolve npm even when PATH is stale right after a Node.js install
            $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
            $exe = if ($npmCmd) { $npmCmd.Source } else { Join-Path $env:ProgramFiles "nodejs\npm.cmd" }
            $cmdArgs = @("install", "--global", $PackageId)
            if ($Quiet) { $cmdArgs += @("--no-fund", "--no-audit") }
            try {
                $null = & $exe @cmdArgs 2> variable:pkgError
                $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            catch {
                $pkgError = $_.Exception.Message
                $exitCode = 1
            }
        }
        "Msstore" {
            # Official Microsoft Store channel via winget (free apps install
            # without a Microsoft account)
            $cmdArgs = @("install", "--id", $PackageId, "--source", "msstore", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity")
            if ($Quiet) { $cmdArgs += "--silent" }
            try {
                $null = & winget @cmdArgs 2> variable:pkgError
                $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            catch {
                $pkgError = $_.Exception.Message
                $exitCode = 1
            }
        }
        "PSResourceGet" {
            try {
                $null = Install-PSResource -Name $PackageId -TrustRepository -Quiet:$Quiet -Scope CurrentUser -ErrorAction Stop
                $exitCode = 0
            }
            catch {
                $installError = $_.Exception.Message
                try {
                    $null = Update-PSResource -Name $PackageId -TrustRepository -Quiet:$Quiet -Scope CurrentUser -ErrorAction Stop
                    $exitCode = 0
                }
                catch {
                    $updateError = $_.Exception.Message
                    $pkgError = "Install-PSResource failed: $installError; Update-PSResource failed: $updateError"
                    Write-Log -Message "PSResourceGet install failed for '$PackageId': $pkgError" -Level Error
                    $exitCode = 1
                }
            }
        }
    }

    if ($pkgError) {
        $errorStr = ($pkgError | Out-String).Trim()
        $Script:LastPackageError = $errorStr
        $global:LastPackageError = $errorStr
        if ($exitCode -ne 0) {
            Write-Log -Message "Installer error output for '$PackageId' via $Provider`: $errorStr" -Level Warning
        }
    }
    else {
        $Script:LastPackageError = $null
        $global:LastPackageError = $null
    }

    return $exitCode
}

<#
.SYNOPSIS
    Installs software packages using Winget, Chocolatey, or PSResourceGet.
    
.PARAMETER Packages
    Array of package IDs to install (Winget format: "Publisher.Package").
    
.PARAMETER PackageManager
    Which package manager to use. Default: Auto-detect (Winget preferred).
    
.PARAMETER Quiet
    Suppress installation prompts where possible.
    
.OUTPUTS
    [psobject] Installation results summary.
#>
function Install-WinDebloatSoftware {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Dual-scope LastPackageError handling for caller scripts')]
    [CmdletBinding(DefaultParameterSetName = "ById", SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([psobject])]
    param(
        [Parameter(ParameterSetName = "ById", Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Packages,

        [Parameter(ParameterSetName = "ByObject", Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]$Apps,
        
        [ValidateSet("Winget", "Chocolatey", "PSResourceGet", "Auto")]
        [string]$PackageManager = "Auto",
        
        [switch]$Quiet
    )
    
    # Auto-detect package manager if needed
    if ($PackageManager -eq "Auto") {
        if (Test-PackageManager -Name "Winget") {
            $PackageManager = "Winget"
        }
        elseif (Test-PackageManager -Name "Chocolatey") {
            $PackageManager = "Chocolatey"
        }
        elseif (Test-PackageManager -Name "PSResourceGet") {
            $PackageManager = "PSResourceGet"
        }
        else {
            Write-Log -Message "No package manager found. Installing Winget..." -Level Warning
            if (-not (Install-PackageManager -Name "Winget" -Force)) {
                # Fallback to Choco installation attempt if Winget fails to install
                Write-Log -Message "Winget installation failed. Trying Chocolatey..." -Level Warning
                if (-not (Install-PackageManager -Name "Chocolatey" -Force)) {
                    throw "Failed to install any package manager"
                }
                $PackageManager = "Chocolatey"
            }
            else {
                $PackageManager = "Winget"
            }
        }
    }
    
    # Normalize input into a list of objects: { Name, PrimaryID, PrimaryProvider, FallbackID, FallbackProvider }
    $itemsToProcess = [List[psobject]]::new()

    if ($PSCmdlet.ParameterSetName -eq "ById") {
        foreach ($p in $Packages) {
            $itemsToProcess.Add([PSCustomObject]@{
                    Name             = $p
                    PrimaryID        = $p
                    PrimaryProvider  = $PackageManager
                    FallbackID       = $null
                    FallbackProvider = $null
                })
        }
    }
    else {
        # ByObject: each app hashtable carries provider IDs (keys: Winget / Choco /
        # Msstore / Npm / PSResourceGet). Candidates are ordered by session preference;
        # the Microsoft Store and npm act as last resorts.
        foreach ($app in $Apps) {
            $wingetId = [string]$app["Winget"]
            $chocoId = [string]$app["Choco"]
            $msstoreId = [string]$app["Msstore"]
            $npmId = [string]$app["Npm"]
            $psresourceId = [string]($app["PSResourceGet"] ?? $app["PSResource"])

            $candidates = [List[object]]::new()
            if ($PackageManager -eq "Winget") {
                if (-not [string]::IsNullOrWhiteSpace($wingetId)) { $candidates.Add(@("Winget", $wingetId)) }
                if (-not [string]::IsNullOrWhiteSpace($chocoId)) { $candidates.Add(@("Chocolatey", $chocoId)) }
                if (-not [string]::IsNullOrWhiteSpace($psresourceId)) { $candidates.Add(@("PSResourceGet", $psresourceId)) }
            }
            elseif ($PackageManager -eq "Chocolatey") {
                if (-not [string]::IsNullOrWhiteSpace($chocoId)) { $candidates.Add(@("Chocolatey", $chocoId)) }
                if (-not [string]::IsNullOrWhiteSpace($wingetId)) { $candidates.Add(@("Winget", $wingetId)) }
                if (-not [string]::IsNullOrWhiteSpace($psresourceId)) { $candidates.Add(@("PSResourceGet", $psresourceId)) }
            }
            elseif ($PackageManager -eq "PSResourceGet") {
                if (-not [string]::IsNullOrWhiteSpace($psresourceId)) { $candidates.Add(@("PSResourceGet", $psresourceId)) }
                if (-not [string]::IsNullOrWhiteSpace($wingetId)) { $candidates.Add(@("Winget", $wingetId)) }
                if (-not [string]::IsNullOrWhiteSpace($chocoId)) { $candidates.Add(@("Chocolatey", $chocoId)) }
            }
            else {
                if (-not [string]::IsNullOrWhiteSpace($wingetId)) { $candidates.Add(@("Winget", $wingetId)) }
                if (-not [string]::IsNullOrWhiteSpace($chocoId)) { $candidates.Add(@("Chocolatey", $chocoId)) }
                if (-not [string]::IsNullOrWhiteSpace($psresourceId)) { $candidates.Add(@("PSResourceGet", $psresourceId)) }
            }
            if (-not [string]::IsNullOrWhiteSpace($msstoreId)) { $candidates.Add(@("Msstore", $msstoreId)) }
            if (-not [string]::IsNullOrWhiteSpace($npmId)) { $candidates.Add(@("Npm", $npmId)) }

            if ($candidates.Count -eq 0) {
                Write-Log -Message "Skipping '$($app["Name"])': no package ID for any provider." -Level Warning
                continue
            }

            $itemsToProcess.Add([PSCustomObject]@{
                    Name             = $app["Name"]
                    PrimaryID        = $candidates[0][1]
                    PrimaryProvider  = $candidates[0][0]
                    FallbackID       = if ($candidates.Count -gt 1) { $candidates[1][1] } else { $null }
                    FallbackProvider = if ($candidates.Count -gt 1) { $candidates[1][0] } else { $null }
                })
        }
    }

    Write-Log -Message "Installing $($itemsToProcess.Count) packages..." -Level Info
    
    $results = @{
        PackageManager = $PackageManager # Preferred provider; individual items may fall back to the other
        TotalRequested = $itemsToProcess.Count
        Successful     = 0
        Failed         = 0
        Skipped        = 0
        Details        = @()
    }
    
    $current = 0
    foreach ($item in $itemsToProcess) {
        $current++
        $percent = [math]::Round(($current / $itemsToProcess.Count) * 100)

        $pkgName = $item.Name
        $pkgId = $item.PrimaryID
        $currentProv = $item.PrimaryProvider

        Write-Progress -Activity "Installing Software" -Status "[$current/$($itemsToProcess.Count)] $pkgName ($pkgId)" -PercentComplete $percent

        try {
            if ($PSCmdlet.ShouldProcess($pkgName, "Install via $currentProv")) {

                # The per-item provider may differ from the session default
                # (e.g. Chocolatey-only apps under a Winget-preferred run)
                if (-not (Test-PackageManager -Name $currentProv)) {
                    $null = Install-PackageManager -Name $currentProv -Force
                }

                $Script:LastPackageError = $null
                $global:LastPackageError = $null
                $attemptExitCode = Invoke-WD7PackageInstall -Provider $currentProv -PackageId $pkgId -Quiet:$Quiet

                if ($attemptExitCode -eq 0) {
                    Write-Log -Message "Installed: $pkgName ($pkgId)" -Level Success
                    $results.Successful++
                    $results.Details += @{ Package = $pkgName; Id = $pkgId; Status = "Success"; Provider = $currentProv }
                }
                elseif ($item.FallbackID -and $item.FallbackProvider -and $item.FallbackProvider -ne $currentProv) {
                    $primaryError = $Script:LastPackageError ?? $global:LastPackageError
                    Write-Log -Message "Failed to install '$pkgName' via $currentProv (Exit: $attemptExitCode). Attempting fallback to $($item.FallbackProvider)..." -Level Warning

                    # Ensure fallback provider is installed
                    if (-not (Test-PackageManager -Name $item.FallbackProvider)) {
                        $null = Install-PackageManager -Name $item.FallbackProvider -Force
                    }

                    if (Test-PackageManager -Name $item.FallbackProvider) {
                        $Script:LastPackageError = $null
                        $global:LastPackageError = $null
                        $fbExitCode = Invoke-WD7PackageInstall -Provider $item.FallbackProvider -PackageId $item.FallbackID -Quiet:$Quiet

                        if ($fbExitCode -eq 0) {
                            Write-Log -Message "Installed: $pkgName ($($item.FallbackID)) via $($item.FallbackProvider)" -Level Success
                            $results.Successful++
                            $results.Details += @{ Package = $pkgName; Id = $item.FallbackID; Status = "Success (Fallback)"; Provider = $item.FallbackProvider }
                        }
                        else {
                            Write-Log -Message "Failed to install '$pkgName' via fallback ($($item.FallbackProvider)). Exit: $fbExitCode" -Level Error
                            $results.Failed++
                            $fbError = $Script:LastPackageError ?? $global:LastPackageError
                            $combinedErrMsg = if ($fbError) { $fbError } elseif ($primaryError) { $primaryError } else { "Primary and Fallback failed" }
                            $detailObj = @{
                                Package     = $pkgName
                                Id          = $pkgId
                                Status      = "Failed"
                                ExitCode    = $fbExitCode
                                Provider    = $item.FallbackProvider
                                Error       = $combinedErrMsg
                                ErrorReason = $combinedErrMsg
                            }
                            $results.Details += $detailObj
                        }
                    }
                    else {
                        Write-Log -Message "Fallback provider unavailable." -Level Error
                        $results.Failed++
                        $detailObj = @{
                            Package     = $pkgName
                            Id          = $pkgId
                            Status      = "Failed"
                            Provider    = $item.FallbackProvider
                            Error       = "Primary failed, Fallback provider unavailable"
                            ErrorReason = if ($primaryError) { $primaryError } else { "Primary failed, Fallback provider unavailable" }
                        }
                        $results.Details += $detailObj
                    }
                }
                else {
                    Write-Log -Message "Failed to install: $pkgName - Exit code: $attemptExitCode" -Level Error
                    $results.Failed++
                    $detailObj = @{
                        Package  = $pkgName
                        Id       = $pkgId
                        Status   = "Failed"
                        ExitCode = $attemptExitCode
                        Provider = $currentProv
                    }
                    $errText = $Script:LastPackageError ?? $global:LastPackageError
                    if ($errText) {
                        $detailObj.Error = $errText
                        $detailObj.ErrorReason = $errText
                    }
                    else {
                        $detailObj.Error = "Exit code: $attemptExitCode"
                        $detailObj.ErrorReason = "Exit code: $attemptExitCode"
                    }
                    $results.Details += $detailObj
                }
            }
        }
        catch {
            Write-Log -Message "Exception installing $pkgName`: $($_.Exception.Message)" -Level Error
            $results.Failed++
            $results.Details += @{ Package = $pkgName; Status = "Error"; Error = $_.Exception.Message; ErrorReason = $_.Exception.Message }
        }
    }
    
    Write-Progress -Activity "Installing Software" -Completed
    
    Write-Log -Message "Installation complete: $($results.Successful) installed, $($results.Skipped) skipped, $($results.Failed) failed" -Level $(if ($results.Failed -eq 0) { "Success" } else { "Warning" })
    
    return [pscustomobject]$results
}
<#
.SYNOPSIS
    Installs essential apps by category with interactive selection.
    
.PARAMETER Categories
    Array of category names to install. If omitted, shows interactive menu.
    
.PARAMETER PackageManager
    Which package manager to use.
    
.PARAMETER InstallAll
    Install all apps from selected categories without prompting.
    
.EXAMPLE
    Install-WinDebloat7Essentials -Categories Browsers, Utilities
    
.EXAMPLE
    Install-WinDebloat7Essentials -InstallAll
#>
function Install-WinDebloatEssentials {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [ValidateSet("Browsers", "Runtimes", "Utilities", "Media", "Communication",
            "Security", "DevTools", "Gaming", "Productivity", "Network", "Drivers", "AITools")]
        [string[]]$Categories,
        
        [ValidateSet("Winget", "Chocolatey", "PSResourceGet", "Auto")]
        [string]$PackageManager = "Auto",
        
        [switch]$InstallAll
    )
    
    $essentials = Get-WinDebloat7EssentialsList
    
    # Determine package manager
    if ($PackageManager -eq "Auto") {
        $PackageManager = if (Test-PackageManager -Name "Winget") { "Winget" } elseif (Test-PackageManager -Name "Chocolatey") { "Chocolatey" } else { "PSResourceGet" }
    }
    
    # If no categories specified, show interactive menu
    if (-not $Categories) {
        Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║       Essential Apps Installer            ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host "Using: $PackageManager`n" -ForegroundColor Gray
        
        $i = 1
        $categoryMap = @{}
        foreach ($cat in $essentials.Keys | Sort-Object) {
            $count = $essentials[$cat].Apps.Count
            Write-Host "  [$i] $($essentials[$cat].DisplayName) ($count apps)" -ForegroundColor White
            $categoryMap[$i] = $cat
            $i++
        }
        Write-Host "  [A] Install ALL Categories" -ForegroundColor Yellow
        Write-Host "  [Q] Cancel`n" -ForegroundColor Gray
        
        $selection = Read-Host "Select categories (comma-separated, e.g., 1,3,5)"
        
        if ($selection -match '^[Qq]$') { return }
        
        if ($selection -match '^[Aa]$') {
            $Categories = $essentials.Keys
        }
        else {
            $Categories = @()
            foreach ($num in ($selection -split ',')) {
                $num = $num.Trim()
                if ($num -match '^\d+$' -and $categoryMap.ContainsKey([int]$num)) {
                    $Categories += $categoryMap[[int]$num]
                }
            }
        }
    }
    
    if ($Categories.Count -eq 0) {
        Write-Log -Message "No categories selected." -Level Warning
        return
    }
    
    # Collect packages from selected categories
    $appsToInstall = @()
    
    foreach ($cat in $Categories) {
        if (-not $essentials.ContainsKey($cat)) { continue }
        
        $catData = $essentials[$cat]
        Write-Host "`n$($catData.DisplayName):" -ForegroundColor Cyan
        
        if ($InstallAll) {
            foreach ($app in $catData.Apps) {
                $appsToInstall += $app
                Write-Host "  [+] $($app.Name)" -ForegroundColor Green
            }
        }
        else {
            # Show individual app selection
            $j = 1
            $appMap = @{}
            foreach ($app in $catData.Apps) {
                Write-Host "  [$j] $($app.Name)" -ForegroundColor White
                $appMap[$j] = $app
                $j++
            }
            Write-Host "  [A] All in category  [S] Skip category" -ForegroundColor Gray
            
            $appSel = Read-Host "Select apps (comma-separated)"
            
            if ($appSel -match '^[Ss]$') { continue }
            
            if ($appSel -match '^[Aa]$') {
                foreach ($app in $catData.Apps) {
                    $appsToInstall += $app
                }
            }
            else {
                foreach ($num in ($appSel -split ',')) {
                    $num = $num.Trim()
                    if ($num -match '^\d+$' -and $appMap.ContainsKey([int]$num)) {
                        $appsToInstall += $appMap[[int]$num]
                    }
                }
            }
        }
    }
    
    if ($appsToInstall.Count -eq 0) {
        Write-Log -Message "No packages selected for installation." -Level Warning
        return
    }
    
    Write-Host "`nInstalling $($appsToInstall.Count) packages..." -ForegroundColor Cyan
    
    $result = Install-WinDebloatSoftware -Apps $appsToInstall -PackageManager $PackageManager -Quiet
    
    Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║         Installation Complete             ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "  Installed: $($result.Successful)" -ForegroundColor Green
    Write-Host "  Skipped:   $($result.Skipped)" -ForegroundColor Yellow
    Write-Host "  Failed:    $($result.Failed)" -ForegroundColor $(if ($result.Failed -gt 0) { "Red" } else { "Gray" })
}

<#
.SYNOPSIS
    Installs packages from a profile configuration.
    
.PARAMETER Config
    The configuration object loaded from a YAML profile.
#>
function Install-WinDebloatProfileSoftware {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Config
    )
    
    if (-not $Config.software) {
        Write-Log -Message "No software configuration in profile." -Level Info
        return
    }

    $pkgMgr = $Config.software.package_manager ?? "Winget"
    $installList = @($Config.software.install_list ?? @())
    $uninstallList = @($Config.software.uninstall_list ?? @())

    if ($installList.Count -eq 0 -and $uninstallList.Count -eq 0) {
        Write-Log -Message "No packages specified in profile install_list/uninstall_list." -Level Info
        return
    }

    if ($installList.Count -gt 0) {
        Write-Log -Message "Installing profile software via $pkgMgr..." -Level Info
        Install-WinDebloatSoftware -Packages $installList -PackageManager $pkgMgr
    }

    foreach ($pkg in $uninstallList) {
        if ($PSCmdlet.ShouldProcess($pkg, "Uninstall via $pkgMgr")) {
            try {
                $pkgError = $null
                $uninstExitCode = 0
                if ($pkgMgr -eq "Chocolatey") {
                    & choco uninstall $pkg -y 2> variable:pkgError
                    $uninstExitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
                }
                elseif ($pkgMgr -eq "PSResourceGet") {
                    Uninstall-PSResource -Name $pkg -Quiet -ErrorAction Stop
                    $uninstExitCode = 0
                }
                else {
                    & winget uninstall --id $pkg --silent --accept-source-agreements --disable-interactivity 2> variable:pkgError
                    $uninstExitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
                }

                if ($uninstExitCode -eq 0) {
                    Write-Log -Message "Uninstalled: $pkg" -Level Success
                }
                else {
                    $errDetail = if ($pkgError) { ": " + ($pkgError | Out-String).Trim() } else { "" }
                    Write-Log -Message "Uninstall skipped or failed for '$pkg' (Exit: $($uninstExitCode)$errDetail - may not be installed)" -Level Warning
                }
            }
            catch {
                Write-Log -Message "Uninstall error for '$pkg': $($_.Exception.Message)" -Level Warning
            }
        }
    }
}

#endregion

#region Update Functions

<#
.SYNOPSIS
    Updates all installed packages using Winget, Chocolatey, or PSResourceGet.
    
.DESCRIPTION
    Runs 'winget upgrade --all', 'choco upgrade all', and 'Update-PSResource' to update software packages.
#>
function Update-WinDebloatSoftware {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()
    
    $hasWinget = Test-PackageManager -Name "Winget"
    $hasChoco = Test-PackageManager -Name "Chocolatey"
    $hasPSResource = Test-PackageManager -Name "PSResourceGet"
    
    if (-not $hasWinget -and -not $hasChoco -and -not $hasPSResource) {
        Write-Log -Message "No package managers installed." -Level Warning
        return
    }

    Write-Log -Message "Checking for software updates..." -Level Info
    
    # 1. Winget Update
    if ($hasWinget) {
        if ($PSCmdlet.ShouldProcess("All Packages", "Update via Winget")) {
            try {
                Write-Log -Message "Running Winget upgrade..." -Level Info
                $pkgError = $null
                & winget upgrade --all --source winget --accept-source-agreements --accept-package-agreements 2> variable:pkgError
                if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0 -and $pkgError) {
                    Write-Log -Message "Winget upgrade completed with exit code $LASTEXITCODE`: $(($pkgError | Out-String).Trim())" -Level Warning
                }
            }
            catch {
                Write-Log -Message "Winget update failed: $($_.Exception.Message)" -Level Error
            }
        }
    }
    
    # 2. Chocolatey Update
    if ($hasChoco) {
        if ($PSCmdlet.ShouldProcess("All Packages", "Update via Chocolatey")) {
            try {
                Write-Log -Message "Running Chocolatey upgrade..." -Level Info
                $pkgError = $null
                & choco upgrade all -y 2> variable:pkgError
                if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0 -and $pkgError) {
                    Write-Log -Message "Chocolatey upgrade completed with exit code $LASTEXITCODE`: $(($pkgError | Out-String).Trim())" -Level Warning
                }
            }
            catch {
                Write-Log -Message "Chocolatey update failed: $($_.Exception.Message)" -Level Error
            }
        }
    }
    
    # 3. PSResourceGet Update
    if ($hasPSResource) {
        if ($PSCmdlet.ShouldProcess("All PSResources", "Update via PSResourceGet")) {
            try {
                Write-Log -Message "Running PSResourceGet upgrade..." -Level Info
                Update-PSResource -TrustRepository -Quiet -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log -Message "PSResourceGet update failed: $($_.Exception.Message)" -Level Error
            }
        }
    }
    
    Write-Log -Message "Software update process finished." -Level Success
}

#endregion

#region WinGet Optimization

<#
.SYNOPSIS
    Optimizes WinGet client settings by deploying wininet downloader and disabling telemetry.
#>
function Optimize-WinDebloatWinGetSettings {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Optimizing WinGet settings (wininet downloader & telemetry disable)..." -Level Info

    if ($PSCmdlet.ShouldProcess("WinGet Configuration", "Deploy optimized settings.json")) {
        $settingsDir = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState"
        if (-not (Test-Path -LiteralPath $settingsDir)) {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        }

        $settingsPath = Join-Path $settingsDir "settings.json"
        $settingsObj = [ordered]@{
            "`$schema" = "https://aka.ms/winget-settings.schema.json"
            "source"   = [ordered]@{
                "autoUpdateIntervalInMinutes" = 720
            }
            "visual"   = [ordered]@{
                "progressBar" = "rainbow"
            }
            "installBehavior" = [ordered]@{
                "preferences" = [ordered]@{
                    "scope" = "user"
                }
                "portablePackageUserRoot" = "%LOCALAPPDATA%\Microsoft\WinGet\Packages"
            }
            "network" = [ordered]@{
                "downloader" = "wininet"
            }
            "telemetry" = [ordered]@{
                "disable" = $true
            }
            "experimentalFeatures" = [ordered]@{
                "localManifestFiles" = $true
            }
        }

        try {
            $json = $settingsObj | ConvertTo-Json -Depth 5
            Set-Content -LiteralPath $settingsPath -Value $json -Encoding UTF8 -Force
            Write-Log -Message "WinGet settings.json optimized successfully." -Level Success
        }
        catch {
            Write-Log -Message "Failed to write WinGet settings: $($_.Exception.Message)" -Level Error
        }
    }
}

<#
.SYNOPSIS
    Restores default WinGet client settings.
#>
function Reset-WinDebloatWinGetSettings {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("WinGet Configuration", "Reset settings.json to default")) {
        $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
        if (Test-Path -LiteralPath $settingsPath) {
            Remove-Item -LiteralPath $settingsPath -Force -ErrorAction SilentlyContinue
            Write-Log -Message "WinGet settings.json reset to default." -Level Success
        }
    }
}

#endregion

# Aliases for backward compatibility and rebranding
Set-Alias -Name 'Get-WinDebloat7EssentialsList' -Value 'Get-WinDebloatEssentialsList'
Set-Alias -Name 'Install-WinDebloat7Software' -Value 'Install-WinDebloatSoftware'
Set-Alias -Name 'Update-WinDebloat7Software' -Value 'Update-WinDebloatSoftware'
Set-Alias -Name 'Install-WinDebloat7Essentials' -Value 'Install-WinDebloatEssentials'
Set-Alias -Name 'Install-WinDebloat7ProfileSoftware' -Value 'Install-WinDebloatProfileSoftware'
Set-Alias -Name 'Optimize-WinDebloat7WinGetSettings' -Value 'Optimize-WinDebloatWinGetSettings'
Set-Alias -Name 'Reset-WinDebloat7WinGetSettings' -Value 'Reset-WinDebloatWinGetSettings'

Export-ModuleMember -Function @(
    'Test-PackageManager',
    'Install-PackageManager',
    'Invoke-WD7PackageInstall',
    'Get-WinDebloatEssentialsList',
    'Install-WinDebloatSoftware',
    'Update-WinDebloatSoftware',
    'Install-WinDebloatEssentials',
    'Install-WinDebloatProfileSoftware',
    'Optimize-WinDebloatWinGetSettings',
    'Reset-WinDebloatWinGetSettings'
) -Alias @(
    'Get-WinDebloat7EssentialsList',
    'Install-WinDebloat7Software',
    'Update-WinDebloat7Software',
    'Install-WinDebloat7Essentials',
    'Install-WinDebloat7ProfileSoftware',
    'Optimize-WinDebloat7WinGetSettings',
    'Reset-WinDebloat7WinGetSettings'
)
