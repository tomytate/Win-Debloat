#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Win-Debloat - The Power User's Windows Optimization Platform
    
.DESCRIPTION
    Entry point for the Win-Debloat framework.
    Loads core modules and launches the interactive TUI or applies profiles in CLI mode.
    
.PARAMETER ProfileFile
    Path to a YAML profile to apply. When specified, skips the interactive menu.
    
.PARAMETER Unattended
    Suppresses confirmation prompts. Use with -ProfileFile for automation.
    
.PARAMETER Verbose
    Enables verbose output for debugging.
    
.EXAMPLE
    ./Win-Debloat.ps1
    Launches the interactive menu.
    
.EXAMPLE
    ./Win-Debloat.ps1 -ProfileFile profiles/gaming.yaml
    Applies the gaming profile with confirmation prompts.
    
.EXAMPLE
    ./Win-Debloat.ps1 -ProfileFile profiles/moderate.yaml -Unattended
    Applies the moderate profile without prompts (for automation).
    
.NOTES
    Version: 1.6.0
    Author: tomytate
    License: MIT
    Requires: PowerShell 7.6+, Administrator privileges
    
.LINK
    https://github.com/tomytate/Win-Debloat
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $null = $commandName, $parameterName, $fakeBoundParameters # required by completer signature
            if (-not $commandAst.Extent.File) { return }
            $profilesDir = Join-Path (Split-Path $commandAst.Extent.File -Parent) "profiles"
            if (-not (Test-Path $profilesDir)) { return }
            Get-ChildItem -Path $profilesDir -Filter "*.yaml" |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.FullName, $_.Name, 'ParameterValue', $_.Name)
            }
        })]
    [string]$ProfileFile,

    [switch]$Unattended,
    
    [switch]$Maintenance,
    
    [switch]$Gui
)

# Runtime Compatibility Check: Windows PowerShell 5.1 -> PowerShell 7.6+ (LTS) Re-launch / Auto-Install
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "⚡ Windows PowerShell $($PSVersionTable.PSVersion) detected. Win-Debloat requires PowerShell 7.6+ (LTS)." -ForegroundColor Cyan
    
    # 1. Resolve pwsh.exe executable
    $pwshPath = $null
    $pwshCmd = Get-Command "pwsh.exe" -CommandType Application -ErrorAction SilentlyContinue
    if ($pwshCmd -and $pwshCmd.Source -and (Test-Path $pwshCmd.Source)) {
        $pwshPath = $pwshCmd.Source
    }
    
    if (-not $pwshPath) {
        $candidatePaths = @(
            [Environment]::ExpandEnvironmentVariables('%ProgramFiles%\PowerShell\7\pwsh.exe'),
            [Environment]::ExpandEnvironmentVariables('%ProgramW6432%\PowerShell\7\pwsh.exe'),
            [Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe'),
            [Environment]::ExpandEnvironmentVariables('%ProgramFiles(x86)%\PowerShell\7\pwsh.exe'),
            [Environment]::ExpandEnvironmentVariables('%ProgramFiles%\PowerShell\7-preview\pwsh.exe')
        )
        foreach ($candidate in $candidatePaths) {
            if ($candidate -and (Test-Path $candidate)) {
                $pwshPath = $candidate
                break
            }
        }
    }
    
    # 2. Prompt or Auto-Install PowerShell 7.6+ LTS if missing
    if (-not $pwshPath) {
        Write-Host "⚠️ PowerShell 7.6+ LTS was not found on this system." -ForegroundColor Yellow
        $installApproved = $false
        if ($Unattended) {
            $installApproved = $true
        }
        elseif ([Environment]::UserInteractive) {
            Write-Host ""
            $userChoice = Read-Host "Would you like to install PowerShell 7.6 LTS automatically now? [Y/N]"
            if ($userChoice -match '^[Yy]') {
                $installApproved = $true
            }
        }
        
        if ($installApproved) {
            Write-Host "⚡ Installing PowerShell 7.6+ LTS automatically..." -ForegroundColor Green
            $installSuccess = $false
            
            # Step A: Attempt silent install via winget (forced WiX/MSI to ensure un-sandboxed admin tooling)
            if (Get-Command "winget.exe" -ErrorAction SilentlyContinue) {
                Write-Host " -> Attempting installation via winget..." -ForegroundColor Cyan
                try {
                    $wingetArgs = "install --id Microsoft.PowerShell --source winget --installer-type wix --accept-source-agreements --accept-package-agreements --silent --disable-interactivity"
                    $wingetProc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
                    if ($wingetProc.ExitCode -eq 0) {
                        $installSuccess = $true
                    }
                }
                catch {
                    Write-Host " -> winget install encountered an issue: $($_.Exception.Message)" -ForegroundColor DarkGray
                }
            }
            
            # Step B: Direct MSI download fallback from official GitHub releases
            if (-not $installSuccess) {
                Write-Host " -> Downloading official PowerShell 7.6 LTS MSI package..." -ForegroundColor Cyan
                $msiFile = $null
                try {
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
                    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'x64' }
                    $fallbackVer = "7.6.5"
                    $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$fallbackVer/PowerShell-$fallbackVer-win-$arch.msi"
                    $msiFile = Join-Path $env:TEMP "PowerShell-$fallbackVer-win-$arch.msi"
                    
                    (New-Object System.Net.WebClient).DownloadFile($msiUrl, $msiFile)
                    
                    Write-Host " -> Running MSI installer..." -ForegroundColor Cyan
                    $msiProc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/package `"$msiFile`" /passive ADD_PATH=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1" -Wait -PassThru
                    if ($msiProc.ExitCode -eq 0 -or $msiProc.ExitCode -eq 3010) {
                        $installSuccess = $true
                    }
                }
                catch {
                    Write-Host "MSI install error: $($_.Exception.Message)" -ForegroundColor Red
                }
                finally {
                    if ($msiFile -and (Test-Path $msiFile)) {
                        Remove-Item $msiFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            # Re-discover pwsh after installation
            $checkPaths = @(
                [Environment]::ExpandEnvironmentVariables('%ProgramFiles%\PowerShell\7\pwsh.exe'),
                [Environment]::ExpandEnvironmentVariables('%ProgramW6432%\PowerShell\7\pwsh.exe'),
                [Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe')
            )
            foreach ($candidate in $checkPaths) {
                if ($candidate -and (Test-Path $candidate)) {
                    $pwshPath = $candidate
                    break
                }
            }
        }
        
        if (-not $pwshPath) {
            Write-Host "❌ PowerShell 7.6+ LTS is required to run Win-Debloat." -ForegroundColor Red
            Write-Host "Please install PowerShell manually from: https://github.com/PowerShell/PowerShell/releases/latest" -ForegroundColor Yellow
            if ([Environment]::UserInteractive -and -not $Unattended) {
                $openBrowser = Read-Host "Open the PowerShell download page in your browser? [Y/N]"
                if ($openBrowser -match '^[Yy]') {
                    Start-Process "https://github.com/PowerShell/PowerShell/releases/latest"
                }
            }
            exit 1
        }
    }
    
    # 3. Build arguments and re-launch into pwsh.exe (elevated)
    $boundArgs = [System.Collections.Generic.List[string]]::new()
    if ($ProfileFile) { $boundArgs.Add("-ProfileFile `"$ProfileFile`"") }
    if ($Unattended) { $boundArgs.Add("-Unattended") }
    if ($Maintenance) { $boundArgs.Add("-Maintenance") }
    if ($Gui) { $boundArgs.Add("-Gui") }
    if ($PSBoundParameters.ContainsKey('Verbose') -and $Verbose) { $boundArgs.Add("-Verbose") }
    foreach ($extra in $args) {
        if ($extra -match '\s') { $boundArgs.Add("`"$extra`"") } else { $boundArgs.Add($extra) }
    }
    
    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($boundArgs.Count -gt 0) { $argString += " " + ($boundArgs -join " ") }
    
    Write-Host "⚡ Launching Win-Debloat in PowerShell 7.6+..." -ForegroundColor Cyan
    $startInfo = @{
        FilePath     = $pwshPath
        ArgumentList = $argString
    }
    if (-not $isAdmin) {
        $startInfo['Verb'] = 'RunAs'
    }
    
    try {
        Start-Process @startInfo -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to launch elevated PowerShell 7: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Auto-elevation check (when already running under PowerShell 7.6+ but not elevated)
if (-not $isAdmin) {
    Write-Host "⚡ Win-Debloat requires Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    $boundArgs = [System.Collections.Generic.List[string]]::new()
    if ($ProfileFile) { $boundArgs.Add("-ProfileFile `"$ProfileFile`"") }
    if ($Unattended) { $boundArgs.Add("-Unattended") }
    if ($Maintenance) { $boundArgs.Add("-Maintenance") }
    if ($Gui) { $boundArgs.Add("-Gui") }
    if ($PSBoundParameters.ContainsKey('Verbose') -and $Verbose) { $boundArgs.Add("-Verbose") }
    foreach ($extra in $args) {
        if ($extra -match '\s') { $boundArgs.Add("`"$extra`"") } else { $boundArgs.Add($extra) }
    }
    
    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($boundArgs.Count -gt 0) { $argString += " " + ($boundArgs -join " ") }
    
    try {
        Start-Process -FilePath "pwsh.exe" -ArgumentList $argString -Verb RunAs -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to request Administrator elevation: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Configure strict error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# Load Core Framework
try {
    Write-Host "Initializing Win-Debloat7 Premium Framework..." -ForegroundColor Cyan
    
    # Load the manifest which defines all nested modules and exports
    $manifestPath = Join-Path $scriptPath "Win-Debloat.psd1"
    if (-not (Test-Path $manifestPath)) {
        $manifestPath = Join-Path $scriptPath "Win-Debloat7.psd1"
    }
    
    if (-not (Test-Path $manifestPath)) {
        throw "Module manifest not found at $manifestPath"
    }
    
    Import-Module $manifestPath -Force -ErrorAction Stop
    
    # Validate critical modules loaded
    $requiredFunctions = @(
        'Write-Log',
        'Import-WinDebloat7Config',
        'Remove-WinDebloat7Bloatware',
        'Set-WinDebloat7Privacy',
        'Set-WinDebloat7Performance',
        'Show-MainMenu'
    )
    $missingFunctions = @()
    
    foreach ($fn in $requiredFunctions) {
        if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
            $missingFunctions += $fn
        }
    }
    
    if ($missingFunctions.Count -gt 0) {
        throw "Missing required functions: $($missingFunctions -join ', '). Try re-extracting the ZIP or check module files."
    }
    
    Start-WD7Logging
    Write-Log -Message "Win-Debloat7 initialized successfully." -Level Success
}
catch {
    Write-Host "CRITICAL ERROR: Failed to load framework." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you extracted ALL files from the ZIP" -ForegroundColor Gray
    Write-Host "  2. Run from the Win-Debloat7 directory" -ForegroundColor Gray
    Write-Host "  3. Verify PowerShell 7.6+ is installed" -ForegroundColor Gray
    Write-Host "  4. Run: Get-Module -ListAvailable | Where Name -like '*yaml*'" -ForegroundColor Gray
    exit 1
}

Write-Host "Framework loaded." -ForegroundColor Gray

# Launch Application
if ($Maintenance) {
    Write-Log -Message "Starting Maintenance Mode..." -Level Info
    Invoke-WinDebloat7Maintenance
    exit 0
}

if ($ProfileFile) {
    # CLI Mode
    # Modules are already loaded by the manifest
    Write-Log -Message "CLI Mode: Processing profile $ProfileFile" -Level Info
    
    $config = Import-WinDebloat7Config -Path $ProfileFile
    
    # Safety confirmation (unless -Unattended)
    if (-not $Unattended) {
        $profileName = [string]$config.metadata.name
        if ($profileName.Length -gt 43) { $profileName = $profileName.Substring(0, 40) + "..." }
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  WARNING: This will modify your system configuration.    ║" -ForegroundColor Yellow
        Write-Host "║  Profile: $($profileName.PadRight(43))║" -ForegroundColor Yellow
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "Continue? [Y/N]"
        if ($confirm -notmatch '^[Yy]') {
            Write-Log -Message "Operation cancelled by user." -Level Warning
            exit 0
        }
    }
    else {
        Write-Log -Message "Unattended mode - skipping confirmation" -Level Info
    }
    
    # Create snapshot before changes (ALWAYS, unless specifically disabled, which isn't a flag yet)
    Write-Log -Message "Creating pre-optimization snapshot..." -Level Info
    New-WinDebloat7Snapshot -Name "Pre-$($config.metadata.name)" -Description "Auto-created before $($config.metadata.name) profile" -Encrypt | Out-Null

    # Benchmark Pre
    Write-Log -Message "Benchmarking system state (Pre-Optimization)..." -Level Info
    $preBench = Measure-WinDebloat7System

    # Apply modules (all profile sections)
    Remove-WinDebloat7Bloatware -Config $config -Confirm:$false
    Set-WinDebloat7Privacy -Config $config -Confirm:$false
    Set-WinDebloat7Security -Config $config -Confirm:$false
    Set-WinDebloat7Performance -Config $config -Confirm:$false
    Set-WinDebloat7Network -Config $config -Confirm:$false
    Set-WinDebloat7SystemTweaks -Config $config -Confirm:$false
    Install-WinDebloat7ProfileSoftware -Config $config -Confirm:$false

    # Benchmark Post
    Write-Log -Message "Benchmarking system state (Post-Optimization)..." -Level Info
    $postBench = Measure-WinDebloat7System
    
    # Generate Report
    $report = Compare-WinDebloat7Benchmarks -Reference $preBench -Difference $postBench
    Write-Host "`n$report" -ForegroundColor Gray
    Write-Log -Message "Optimization Report generated on Desktop." -Level Success
    
    Write-Log -Message "Profile '$($config.metadata.name)' applied successfully." -Level Success
    exit 0
}
else {
    # Interactive Mode
    if ($Gui) {
        # Launch GUI directly
        try {
            Show-WinDebloat7GUI
        }
        catch {
            Write-Log -Message "GUI failed to load, falling back to TUI: $($_.Exception.Message)" -Level Warning
            Show-MainMenu
        }
    }
    else {
        # Default: Launch TUI (Menu)
        Show-MainMenu
    }
}

