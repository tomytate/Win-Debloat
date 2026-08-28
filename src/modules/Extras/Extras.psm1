#Requires -Version 7.6

<#
.SYNOPSIS
    Extras module for Win-Debloat (Advanced Edition)
    
.DESCRIPTION
    Provides integrations for third-party tools like MAS and Defender Remover.
    These tools are NOT included in the Standard edition due to AV flags.
    
.NOTES
    Module: Win-Debloat.Modules.Extras
    Version: 1.6.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

<#
.SYNOPSIS
    Downloads and runs the latest Defender Remover.
#>
function Invoke-WinDebloat7DefenderRemover {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Log -Message "Launching Defender Remover..." -Level Info
    
    Write-Warning "AV INTERVENTION REQUIRED: Defender Remover is an aggressive tool that will be flagged by Windows Defender."
    Write-Warning "You MUST pause Real-time Protection AND Tamper Protection before proceeding."
    $proceed = Read-Host "Have you paused Tamper Protection? Type 'YES' to continue"
    if ($proceed -ne 'YES') {
        Write-Log -Message "Defender Remover execution aborted by user." -Level Warning
        return
    }

    # Check connectivity
    if (-not (Test-Connection "api.github.com" -Count 1 -Quiet)) {
        Write-Log -Message "Internet connection required for Defender Remover." -Level Error
        return
    }

    $destPath = $null
    try {
        Write-Host "Fetching latest release from GitHub..." -ForegroundColor Cyan
        $apiUrl = "https://api.github.com/repos/ionuttbara/windows-defender-remover/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        
        $asset = $release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
        if (-not $asset) { throw "Executable asset not found." }
        
        $dlUrl = $asset.browser_download_url
        $tempBase = [System.IO.Path]::GetTempFileName()
        $destPath = "$tempBase.exe"
        Remove-Item $tempBase -ErrorAction SilentlyContinue # Remove the 0-byte file created by GetTempFileName
        
        Write-Host "Downloading $($asset.name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $dlUrl -OutFile $destPath -MaximumRetryCount 3 -RetryIntervalSec 5 -ErrorAction Stop
        
        Write-Host "Running Defender Remover..." -ForegroundColor Green
        Start-Process -FilePath $destPath -Wait
        
        Write-Log -Message "Defender Remover execution finished." -Level Success
    }
    catch {
        Write-Log -Message "Error launching Defender Remover: $($_.Exception.Message)" -Level Error
        Start-Process "https://github.com/ionuttbara/windows-defender-remover/releases/latest"
    }
    finally {
        if ($destPath -and (Test-Path $destPath)) {
            Remove-Item $destPath -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Runs Microsoft Activation Scripts (MAS).
#>
function Invoke-WinDebloat7Activation {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Log -Message "Launching Microsoft Activation Scripts (MAS)..." -Level Info
    
    Write-Warning "AV INTERVENTION REQUIRED: MAS is considered a 'HackTool' by Windows Defender."
    Write-Warning "You MUST pause Real-time Protection before proceeding."
    $proceed = Read-Host "Have you paused Real-time Protection? Type 'YES' to continue"
    if ($proceed -ne 'YES') {
        Write-Log -Message "MAS execution aborted by user." -Level Warning
        return
    }

    if (-not (Test-Connection "get.activated.win" -Count 1 -Quiet)) {
        Write-Log -Message "Internet connection required for MAS." -Level Error
        return
    }

    $tempBase = [System.IO.Path]::GetTempFileName()
    $scriptPath = "$tempBase.ps1"
    Remove-Item $tempBase -ErrorAction SilentlyContinue
    
    try {
        Write-Host "Downloading MAS script..." -ForegroundColor Green
        Invoke-RestMethod -Uri "https://get.activated.win" -OutFile $scriptPath -ErrorAction Stop
        
        Write-Host "Executing MAS..." -ForegroundColor Green
        & $scriptPath
        
        Write-Log -Message "MAS execution completed." -Level Success
    }
    catch {
        Write-Log -Message "Error running MAS: $($_.Exception.Message)" -Level Error
        throw
    }
    finally {
        if (Test-Path $scriptPath) { Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue }
    }
}

# Aliases for backward compatibility and rebranding
Set-Alias -Name 'Invoke-WinDebloatDefenderRemover' -Value 'Invoke-WinDebloat7DefenderRemover'
Set-Alias -Name 'Invoke-WinDebloatActivation' -Value 'Invoke-WinDebloat7Activation'

Export-ModuleMember -Function Invoke-WinDebloat7DefenderRemover, Invoke-WinDebloat7Activation `
                    -Alias Invoke-WinDebloatDefenderRemover, Invoke-WinDebloatActivation
