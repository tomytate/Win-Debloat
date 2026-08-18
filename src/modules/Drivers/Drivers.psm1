#Requires -Version 7.6

<#
.SYNOPSIS
    Driver update module for Win-Debloat
    
.DESCRIPTION
    Handles driver enumeration, status checking, and updates via
    Windows Update, Winget, or Snappy Driver Installer.
    
.NOTES
    Module: Win-Debloat.Modules.Drivers
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\Integrations\Integrations.psm1" -Force -ErrorAction SilentlyContinue

#region Driver Status

<#
.SYNOPSIS
    Gets the status of installed drivers.
    
.DESCRIPTION
    Queries Win32_PnPSignedDriver for all signed drivers and
    identifies potential outdated drivers based on date.
    
.PARAMETER Category
    Filter by driver category (Display, Network, Audio, etc.)
    
.OUTPUTS
    [psobject[]] Array of driver information objects.
    
.EXAMPLE
    Get-WinDebloatDriverStatus -Category "Display"
#>
function Get-WinDebloatDriverStatus {
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
        [ValidateSet("All", "Display", "Network", "Audio", "USB", "Storage", "System")]
        [string]$Category = "All"
    )
    
    Write-Log -Message "Scanning installed drivers..." -Level Info
    
    try {
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop |
        Where-Object { $null -ne $_.DriverName } |
        Select-Object @{N = 'DeviceName'; E = { $_.DeviceName } },
        @{N = 'DriverVersion'; E = { $_.DriverVersion } },
        @{N = 'DriverDate'; E = { $_.DriverDate } },
        @{N = 'Manufacturer'; E = { $_.Manufacturer } },
        @{N = 'DeviceClass'; E = { $_.DeviceClass } },
        @{N = 'InfName'; E = { $_.InfName } },
        @{N = 'IsSigned'; E = { $_.IsSigned } }
        
        # Filter by category if specified
        if ($Category -ne "All") {
            $classFilter = switch ($Category) {
                "Display" { "Display" }
                "Network" { "Net" }
                "Audio" { "MEDIA|AudioEndpoint" }
                "USB" { "USB" }
                "Storage" { "DiskDrive|SCSIAdapter|hdc" }
                "System" { "System" }
            }
            $drivers = $drivers | Where-Object { $_.DeviceClass -match $classFilter }
        }
        
        # Calculate age and flag outdated drivers (>1 year old)
        $oneYearAgo = (Get-Date).AddYears(-1)
        $drivers = $drivers | ForEach-Object {
            $isOutdated = ($null -ne $_.DriverDate) -and ($_.DriverDate -is [datetime]) -and ($_.DriverDate -lt $oneYearAgo)
            $_ | Add-Member -NotePropertyName "IsOutdated" -NotePropertyValue $isOutdated -PassThru
        }
        
        $outdatedCount = ($drivers | Where-Object { $_.IsOutdated }).Count
        Write-Log -Message "Found $($drivers.Count) drivers ($outdatedCount potentially outdated)" -Level Info
        
        return $drivers
    }
    catch {
        Write-Log -Message "Failed to enumerate drivers: $($_.Exception.Message)" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Gets detected GPU information.
    
.OUTPUTS
    [psobject] GPU information including vendor
#>
function Get-WinDebloatGPUInfo {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()
    
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1
        
        $vendor = switch -Regex ($gpu.Name) {
            "NVIDIA" { "NVIDIA" }
            "AMD|Radeon" { "AMD" }
            "Intel" { "Intel" }
            default { "Unknown" }
        }
        
        return [pscustomobject]@{
            Name          = $gpu.Name
            Vendor        = $vendor
            DriverVersion = $gpu.DriverVersion
            DriverDate    = $gpu.DriverDate
            AdapterRAM    = [math]::Round($gpu.AdapterRAM / 1GB, 2)
        }
    }
    catch {
        Write-Log -Message "Failed to get GPU info: $($_.Exception.Message)" -Level Warning
        return $null
    }
}

#endregion

#region Driver Updates

<#
.SYNOPSIS
    Updates drivers via Windows Update.
#>
function Update-DriversViaWindowsUpdate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console feedback')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()
    
    # Check for PSWindowsUpdate module
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log -Message "PSWindowsUpdate module not found." -Level Warning
        
        $response = Read-Host "Install PSWindowsUpdate module? [Y/N]"
        if ($response -match '^[Yy]') {
            try {
                Install-PSResource -Name PSWindowsUpdate -Scope CurrentUser -TrustRepository -ErrorAction Stop
                Import-Module PSWindowsUpdate -ErrorAction Stop
            }
            catch {
                Write-Log -Message "Failed to install PSWindowsUpdate: $($_.Exception.Message)" -Level Error
                return
            }
        }
        else {
            return
        }
    }
    
    if (-not (Get-Module -Name PSWindowsUpdate)) {
        Import-Module PSWindowsUpdate -ErrorAction Stop
    }
    
    Write-Log -Message "Scanning Windows Update for driver updates..." -Level Info
    
    try {
        # Get driver updates
        $updates = Get-WindowsUpdate -Category "Drivers" -ErrorAction Stop
        
        if ($updates.Count -eq 0) {
            Write-Log -Message "No driver updates available from Windows Update." -Level Info
            return
        }
        
        Write-Host "`nAvailable Driver Updates ($($updates.Count)):" -ForegroundColor Cyan
        $updates | Format-Table KB, Title, Size -AutoSize
        
        if ($PSCmdlet.ShouldProcess("Drivers", "Install $($updates.Count) updates via Windows Update")) {
            $confirm = Read-Host "Install all driver updates? [Y/N]"
            if ($confirm -match '^[Yy]') {
                Write-Log -Message "Installing driver updates via Windows Update..." -Level Info
                Install-WindowsUpdate -Category "Drivers" -AcceptAll -IgnoreReboot -ErrorAction Stop
                Write-Log -Message "Driver updates installed successfully." -Level Success
                Write-Log -Message "A system restart is recommended to complete driver installation." -Level Warning
            }
        }
    }
    catch {
        Write-Log -Message "Failed to check/install Windows Update drivers: $($_.Exception.Message)" -Level Error
    }
}

<#
.SYNOPSIS
    Updates GPU drivers via Winget packages.
#>
function Update-GPUDriverViaWinget {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console feedback')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [psobject]$GPUInfo
    )
    
    $gpu = if ($GPUInfo) { $GPUInfo } else { Get-WinDebloatGPUInfo }
    
    if (-not $gpu -or $gpu.Vendor -eq "Unknown") {
        Write-Log -Message "Could not detect GPU vendor or unsupported GPU." -Level Warning
        return
    }
    
    Write-Log -Message "Detected GPU: $($gpu.Name) ($($gpu.Vendor))" -Level Info
    
    $packages = switch ($gpu.Vendor) {
        "NVIDIA" {
            @(
                [pscustomobject]@{ Name = "NVIDIA GeForce Experience"; Id = "Nvidia.GeForceExperience" },
                [pscustomobject]@{ Name = "NVIDIA App (Beta)"; Id = "Nvidia.NvidiaApp" }
            )
        }
        "AMD" {
            @(
                [pscustomobject]@{ Name = "AMD Software: Adrenalin Edition"; Id = "AdvancedMicroDevicesInc.AMDSoftwareAdrenalinEdition" }
            )
        }
        "Intel" {
            @(
                [pscustomobject]@{ Name = "Intel Driver & Support Assistant"; Id = "Intel.IntelDriverAndSupportAssistant" },
                [pscustomobject]@{ Name = "Intel Arc Control"; Id = "Intel.ArcControl" }
            )
        }
        default {
            Write-Log -Message "No winget driver package available for $($gpu.Vendor)." -Level Info
            return
        }
    }
    
    Write-Host "`nGPU Driver Options for $($gpu.Vendor):" -ForegroundColor Cyan
    $i = 1
    foreach ($pkg in $packages) {
        Write-Host "  [$i] $($pkg.Name)" -ForegroundColor White
        $i++
    }
    Write-Host "  [S] Skip GPU driver update" -ForegroundColor Gray
    
    $sel = Read-Host "Select option"
    if ($sel -match '^[Ss]$' -or [string]::IsNullOrWhiteSpace($sel)) { return }
    
    $parsedIdx = 0
    if ([int]::TryParse($sel, [ref]$parsedIdx) -and $parsedIdx -ge 1 -and $parsedIdx -le $packages.Count) {
        $selectedPkg = $packages[$parsedIdx - 1]
    }
    else {
        Write-Log -Message "Invalid selection: $sel" -Level Warning
        return
    }
    
    if ($selectedPkg) {
        if ($PSCmdlet.ShouldProcess($selectedPkg.Name, "Install via Winget")) {
            Write-Log -Message "Installing $($selectedPkg.Name)..." -Level Info
            $result = winget install $selectedPkg.Id --accept-source-agreements --accept-package-agreements 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "$($selectedPkg.Name) installed/updated successfully." -Level Success
            }
            else {
                Write-Log -Message "Installation result: $result" -Level Warning
            }
        }
    }
}

<#
.SYNOPSIS
    Opens Snappy Driver Installer Origin for comprehensive driver updates.
    
.DESCRIPTION
    SDIO is a portable, open-source driver updater with offline driver packs.
    This function downloads and launches SDIO if not present.
#>
function Start-SnappyDriverInstaller {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console feedback')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    # Single SDIO implementation lives in the Integrations module
    if ($PSCmdlet.ShouldProcess("SDIO", "Download and launch")) {
        if (Get-Command Update-WinDebloatSDIO -ErrorAction SilentlyContinue) {
            Update-WinDebloatSDIO
        }
        elseif (Get-Command Update-WinDebloat7SDIO -ErrorAction SilentlyContinue) {
            Update-WinDebloat7SDIO
        }
    }
}

<#
.SYNOPSIS
    Main driver update function with multiple options.
    
.DESCRIPTION
    Provides interactive driver update experience with multiple sources:
    - Windows Update
    - GPU drivers via Winget
    - Snappy Driver Installer Origin
    
.PARAMETER Method
    Update method: WindowsUpdate, GPU, SDIO, or Interactive (menu).
#>
function Update-WinDebloatDrivers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console feedback')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [ValidateSet("WindowsUpdate", "GPU", "SDIO", "Interactive")]
        [string]$Method = "Interactive"
    )
    
    switch ($Method) {
        "WindowsUpdate" { Update-DriversViaWindowsUpdate }
        "GPU" { Update-GPUDriverViaWinget }
        "SDIO" { Start-SnappyDriverInstaller }
        "Interactive" {
            Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║         Driver Update Center              ║" -ForegroundColor Cyan
            Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
            
            # Show current driver status
            $gpu = Get-WinDebloatGPUInfo
            if ($gpu) {
                Write-Host "`nCurrent GPU: $($gpu.Name)" -ForegroundColor White
                Write-Host "Driver Version: $($gpu.DriverVersion)" -ForegroundColor Gray
            }
            
            $outdated = (Get-WinDebloatDriverStatus | Where-Object { $_.IsOutdated }).Count
            Write-Host "Potentially Outdated Drivers: $outdated" -ForegroundColor $(if ($outdated -gt 5) { "Yellow" } else { "Gray" })
            
            Write-Host "`nUpdate Options:" -ForegroundColor Cyan
            Write-Host "  [1] Windows Update - Official Microsoft drivers" -ForegroundColor White
            Write-Host "  [2] GPU Driver - NVIDIA/AMD/Intel via Winget" -ForegroundColor White
            Write-Host "  [3] Snappy Driver Installer - Comprehensive offline drivers" -ForegroundColor White
            Write-Host "  [4] View All Drivers" -ForegroundColor White
            Write-Host "  [B] Back" -ForegroundColor Gray
            
            $choice = Read-Host "`nSelect option"
            
            switch ($choice) {
                "1" { Update-DriversViaWindowsUpdate }
                "2" { Update-GPUDriverViaWinget }
                "3" { Start-SnappyDriverInstaller }
                "4" {
                    $drivers = Get-WinDebloatDriverStatus
                    $drivers | Sort-Object DeviceClass | Format-Table DeviceName, DriverVersion, IsOutdated -AutoSize | Out-Host
                    Read-Host "Press Enter to continue..."
                }
            }
        }
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Get-WinDebloat7DriverStatus' -Value 'Get-WinDebloatDriverStatus'
Set-Alias -Name 'Get-WinDebloat7GPUInfo' -Value 'Get-WinDebloatGPUInfo'
Set-Alias -Name 'Get-WinDebloatGpuInfo' -Value 'Get-WinDebloatGPUInfo'
Set-Alias -Name 'Get-WinDebloat7GpuInfo' -Value 'Get-WinDebloatGPUInfo'
Set-Alias -Name 'Update-WinDebloat7Drivers' -Value 'Update-WinDebloatDrivers'
Set-Alias -Name 'Update-WinDebloatDriver' -Value 'Update-WinDebloatDrivers'
Set-Alias -Name 'Update-WinDebloat7Driver' -Value 'Update-WinDebloatDrivers'

Export-ModuleMember -Function @(
    'Get-WinDebloatDriverStatus',
    'Get-WinDebloatGPUInfo',
    'Update-WinDebloatDrivers'
) -Alias @(
    'Get-WinDebloat7DriverStatus',
    'Get-WinDebloat7GPUInfo',
    'Get-WinDebloatGpuInfo',
    'Get-WinDebloat7GpuInfo',
    'Update-WinDebloat7Drivers',
    'Update-WinDebloatDriver',
    'Update-WinDebloat7Driver'
)
