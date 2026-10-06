#Requires -Version 5.1
<#
.SYNOPSIS
    Win-Debloat Enterprise Autopilot & OOBE Deployment Engine
    
.DESCRIPTION
    Zero-dependency, standalone deployment script tailored for Microsoft Intune Win32 App
    deployments and Windows Setup OOBE (Out-Of-Box Experience Shift+F10).
    Hardens telemetry, strips consumer bloatware, enforces security baselines,
    and logs atomically to ProgramData.

.PARAMETER Mode
    Deployment profile preset: Enterprise (default), OOBE, or Kiosk.

.PARAMETER LogPath
    Path to deployment log file (default: %ProgramData%\Win-Debloat\Logs\Deploy.log).
#>

[CmdletBinding()]
param(
    [ValidateSet("Enterprise", "OOBE", "Kiosk")]
    [string]$Mode = "Enterprise",

    [string]$LogPath = "$env:ProgramData\Win-Debloat\Logs\Deploy.log"
)

$ErrorActionPreference = "Continue"

# 1. Setup Logging Directory
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-DeployLog {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    Add-Content -LiteralPath $LogPath -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

Write-DeployLog "=== Win-Debloat Enterprise Deployment Initialized (Mode: $Mode) ===" "Info"
Write-DeployLog "Host: $env:COMPUTERNAME | OS: $([Environment]::OSVersion.VersionString)" "Info"

# 2. Check Administrator Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-DeployLog "CRITICAL: Script must be executed with elevated Administrator privileges." "Error"
    exit 1
}

# 3. Enterprise Telemetry & Privacy Hardening
Write-DeployLog "Applying Enterprise Telemetry & Privacy Hardening..." "Info"
try {
    $privacyPolicies = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableCloudOptimizedContent"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableAIDataAnalysis"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "AllowRecallEnablement"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name = "DisableClickToDo"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "CopilotCDPPageContext"; Value = 0; Type = "DWord" }
    )

    foreach ($p in $privacyPolicies) {
        if (-not (Test-Path $p.Path)) {
            New-Item -Path $p.Path -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -Type $p.Type -Force -ErrorAction SilentlyContinue
    }
    Write-DeployLog "Privacy policies configured successfully." "Success"
}
catch {
    Write-DeployLog "Failed to configure privacy policies: $($_.Exception.Message)" "Warning"
}

# 4. Enterprise Security Baseline
Write-DeployLog "Applying Enterprise Security Baseline..." "Info"
try {
    # Disable SMBv1
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue

    # Enable Microsoft Defender PUA Protection
    Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue

    # Enable PowerShell Script Block & Module Logging
    $psLogging = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    if (-not (Test-Path $psLogging)) { New-Item -Path $psLogging -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $psLogging -Name "EnableScriptBlockLogging" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Restrict RPC to Named Pipes for Spooler & Windows Protected Print (WPP)
    $rpcKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC"
    if (-not (Test-Path $rpcKey)) { New-Item -Path $rpcKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $rpcKey -Name "RpcUseNamedPipeProtocol" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-DeployLog "Security baseline configured successfully." "Success"
}
catch {
    Write-DeployLog "Failed to configure security baseline: $($_.Exception.Message)" "Warning"
}

# 5. Telemetry & DiagTrack Service Tuning
Write-DeployLog "Tuning background telemetry services..." "Info"
$servicesToStop = @("DiagTrack", "dmwappushservice", "RetailDemo")
foreach ($svc in $servicesToStop) {
    try {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-DeployLog "Service '$svc' stopped and disabled." "Success"
        }
    }
    catch {
        Write-DeployLog "Service '$svc' adjustment notice: $($_.Exception.Message)" "Debug"
    }
}

# 6. Remove Sponsored OEM / Consumer AppX Provisioned Packages
Write-DeployLog "Deprovisioning OEM and sponsored consumer bloatware packages..." "Info"
$unwantedPatterns = @(
    "*TikTok*", "*Facebook*", "*Instagram*", "*Spotify*", "*Disney*",
    "*CandyCrush*", "*BubbleWitch*", "*FarmVille*", "*Clipchamp*",
    "*AmazonVideo*", "*Hulu*", "*LinkedIn*", "*EclipseManager*",
    "*AD2F1837*", "*DellSupportAssist*", "*LenovoCompanion*"
)

$removedCount = 0
try {
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($pkg in $provisioned) {
        foreach ($pattern in $unwantedPatterns) {
            if ($pkg.DisplayName -like $pattern -or $pkg.PackageName -like $pattern) {
                Write-DeployLog "Deprovisioning: $($pkg.DisplayName)" "Info"
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
                $removedCount++
                break
            }
        }
    }
    Write-DeployLog "Deprovisioned $removedCount consumer package(s)." "Success"
}
catch {
    Write-DeployLog "AppX deprovisioning encountered an error: $($_.Exception.Message)" "Warning"
}

# 7. Write Intune Detection Registry Stamp
$stampKey = "HKLM:\SOFTWARE\Win-Debloat"
try {
    if (-not (Test-Path $stampKey)) { New-Item -Path $stampKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $stampKey -Name "Applied" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $stampKey -Name "Version" -Value "1.7.1" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $stampKey -Name "Mode" -Value $Mode -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $stampKey -Name "Timestamp" -Value ((Get-Date).ToString("o")) -Type String -Force -ErrorAction SilentlyContinue
    Write-DeployLog "Registry detection stamp recorded at $stampKey." "Success"
}
catch {
    Write-DeployLog "Could not write registry detection stamp: $($_.Exception.Message)" "Warning"
}

# 8. Finalize
Write-DeployLog "=== Win-Debloat Enterprise Deployment Completed Successfully ===" "Success"
if ([Environment]::UserInteractive -and -not $env:UNATTENDED -and -not $env:CI) {
    Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
}
exit 0
