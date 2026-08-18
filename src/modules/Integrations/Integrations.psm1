#Requires -Version 7.6

<#
.SYNOPSIS
    Integrations with Third-Party Security and Maintenance Tools for Win-Debloat.
    
.DESCRIPTION
    Provides wrappers to securely download and execute trusted external tools
    such as O&O ShutUp10++, Malwarebytes AdwCleaner, and Snappy Driver Installer.
    
.NOTES
    Module: Win-Debloat.Modules.Integrations
    Version: 2.0.0
#>

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force -ErrorAction SilentlyContinue

function Invoke-WinDebloatShutUp10 {
    <#
    .SYNOPSIS
        Downloads and runs O&O ShutUp10++.
    .PARAMETER Recommended
        If set, automatically applies recommended settings (requires cfg file).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Switch]$Recommended
    )

    $url = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
    $dest = "$env:TEMP\OOSU10.exe"
    
    Write-Log -Message "Downloading O&O ShutUp10++..." -Level Info
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 2 -ErrorAction Stop
        
        if ($Recommended) {
            Write-Log -Message "Launching ShutUp10++ (Interactive)..." -Level Info
            Start-Process -FilePath $dest -Wait
        }
        else {
            Write-Log -Message "Launching ShutUp10++..." -Level Info
            Start-Process -FilePath $dest
        }
    }
    catch {
        Write-Log -Message "Failed to download ShutUp10: $($_.Exception.Message)" -Level Error
    }
}

function Invoke-WinDebloatAdwCleaner {
    <#
    .SYNOPSIS
        Downloads and runs Malwarebytes AdwCleaner.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $url = "https://downloads.malwarebytes.com/file/adwcleaner"
    $dest = "$env:TEMP\AdwCleaner.exe"
    
    Write-Log -Message "Downloading Malwarebytes AdwCleaner..." -Level Info
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 2 -ErrorAction Stop
        Write-Log -Message "Launching AdwCleaner..." -Level Info
        Start-Process -FilePath $dest -Verb RunAs # Requires Admin
    }
    catch {
        Write-Log -Message "Failed to download AdwCleaner: $($_.Exception.Message)" -Level Error
    }
}

function Update-WinDebloatSDIO {
    <#
    .SYNOPSIS
        Downloads Snappy Driver Installer Origin (SDIO).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        # Aligned with the rest of the app's tool storage (ProgramData)
        [string]$Path = "$env:ProgramData\Win-Debloat7\Tools\SDIO"
    )

    # Official rolling "latest" archive (verified live 2026-07-06)
    $url = "https://www.glenn.delahoy.com/downloads/sdio/SDIO_Latest.zip"
    $zip = "$env:TEMP\SDIO.zip"
    
    Write-Log -Message "Downloading Snappy Driver Installer Origin (SDIO)..." -Level Info
    
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force | Out-Null }
        
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 2 -ErrorAction Stop
        
        Write-Log -Message "Extracting to $Path..." -Level Info
        Expand-Archive -Path $zip -DestinationPath $Path -Force
        
        # Cleanup
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        
        # Find EXE (x64)
        $exe = Get-ChildItem -Path $Path -Filter "*x64*.exe" -Recurse | Select-Object -First 1
        if ($exe) {
            Write-Log -Message "Launching SDIO..." -Level Info
            Start-Process -FilePath $exe.FullName
        }
        else {
            Write-Log -Message "SDIO Executable not found in extraction." -Level Warning
        }
    }
    catch {
        Write-Log -Message "Failed to setup SDIO: $($_.Exception.Message)" -Level Error
    }
}

# Aliases for backward compatibility
Set-Alias -Name 'Invoke-WinDebloat7ShutUp10' -Value 'Invoke-WinDebloatShutUp10'
Set-Alias -Name 'Invoke-WinDebloat7AdwCleaner' -Value 'Invoke-WinDebloatAdwCleaner'
Set-Alias -Name 'Update-WinDebloat7SDIO' -Value 'Update-WinDebloatSDIO'
Set-Alias -Name 'Invoke-WinDebloatSDIO' -Value 'Update-WinDebloatSDIO'
Set-Alias -Name 'Invoke-WinDebloat7SDIO' -Value 'Update-WinDebloatSDIO'

Export-ModuleMember -Function @(
    'Invoke-WinDebloatShutUp10',
    'Invoke-WinDebloatAdwCleaner',
    'Update-WinDebloatSDIO'
) -Alias @(
    'Invoke-WinDebloat7ShutUp10',
    'Invoke-WinDebloat7AdwCleaner',
    'Update-WinDebloat7SDIO',
    'Invoke-WinDebloatSDIO',
    'Invoke-WinDebloat7SDIO'
)
