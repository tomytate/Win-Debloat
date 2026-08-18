#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Win-Debloat7 - The Power User's Windows Optimization Platform
    
.DESCRIPTION
    Entry point for the Win-Debloat7 framework.
    Loads core modules and launches the interactive TUI or applies profiles in CLI mode.
    
.PARAMETER ProfileFile
    Path to a YAML profile to apply. When specified, skips the interactive menu.
    
.PARAMETER Unattended
    Suppresses confirmation prompts. Use with -ProfileFile for automation.
    
.PARAMETER Verbose
    Enables verbose output for debugging.
    
.EXAMPLE
    ./Win-Debloat7.ps1
    Launches the interactive menu.
    
.EXAMPLE
    ./Win-Debloat7.ps1 -ProfileFile profiles/gaming.yaml
    Applies the gaming profile with confirmation prompts.
    
.EXAMPLE
    ./Win-Debloat7.ps1 -ProfileFile profiles/moderate.yaml -Unattended
    Applies the moderate profile without prompts (for automation).
    
.NOTES
    Version: 1.5.0
    Author: tomytate
    License: MIT
    Requires: PowerShell 7.6+, Administrator privileges
    
.LINK
    https://github.com/tomytate/Win-Debloat7
#>

#Requires -Version 7.6

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

# Auto-elevation check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚡ Win-Debloat requires Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    $boundArgs = @()
    if ($ProfileFile) { $boundArgs += "-ProfileFile `"$ProfileFile`"" }
    if ($Unattended) { $boundArgs += "-Unattended" }
    if ($Maintenance) { $boundArgs += "-Maintenance" }
    if ($Gui) { $boundArgs += "-Gui" }
    
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " + ($boundArgs -join " ")
    try {
        Start-Process -FilePath "pwsh.exe" -ArgumentList $argList -Verb RunAs -ErrorAction Stop
    }
    catch {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
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

