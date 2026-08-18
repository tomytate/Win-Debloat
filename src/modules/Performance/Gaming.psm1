#Requires -Version 7.6

<#
.SYNOPSIS
    Gaming optimization module for Win-Debloat
    
.DESCRIPTION
    Advanced low-level optimizations for gaming and esports performance.
    Enhances network latency (TCPNoDelay), input lag (Mouse Acceleration),
    and system responsiveness (MMCSS).
    
.NOTES
    Module: Win-Debloat.Modules.Performance.Gaming
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force

#region Gaming Optimizations

<#
.SYNOPSIS
    Applies strict gaming-focused optimizations.
    
.DESCRIPTION
    Configures critical low-latency settings:
    - TCPNoDelay (Nagle's Algorithm)
    - SystemResponsiveness
    - Multimedia Class Scheduler (MMCSS)
    - Mouse Acceleration (1:1 Input)
    
.PARAMETER EnableNetworkOptimization
    Disables Nagle's Algorithm and throttles network for gaming.
    
.PARAMETER EnableInputOptimization
    Disables Windows mouse acceleration for raw input.
    
.PARAMETER EnableMultimediaOptimization
    Prioritizes 'Games' profile in MMCSS.
#>
function Set-WinDebloatGaming {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [switch]$EnableNetworkOptimization,
        [switch]$EnableInputOptimization,
        [switch]$EnableMultimediaOptimization
    )
    
    Write-Log -Message "Applying Gaming Optimizations..." -Level Info
    
    if (-not $PSCmdlet.ShouldProcess("System", "Apply Gaming Optimizations")) {
        return
    }
    
    $successCount = 0
    
    # 1. Network Optimizations (Nagle's Fix)
    if ($EnableNetworkOptimization) {
        Write-Log -Message "Optimizing Network for Gaming (Low Latency)" -Level Info
        
        # Get active NICs
        $nics = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($nic in $nics) {
            # TCPNoDelay / TcpAckFrequency
            # Find registry key for this interface
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($nic.InterfaceGuid)"
            
            $results = @(
                (Set-RegistryKey -Path $regPath -Name "TcpAckFrequency" -Value 1 -Type DWord),
                (Set-RegistryKey -Path $regPath -Name "TCPNoDelay" -Value 1 -Type DWord),
                (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters" -Name "TCPNoDelay" -Value 1 -Type DWord)
            )
            $successCount += ($results | Where-Object { $_ }).Count
        }
    }
    
    # 2. Input Optimizations (Mouse Accel)
    if ($EnableInputOptimization) {
        Write-Log -Message "Disabling Mouse Acceleration (1:1 Input)" -Level Info
        
        $results = @(
            (Set-RegistryKey -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String),
            (Set-RegistryKey -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String),
            (Set-RegistryKey -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String)
        )
        $successCount += ($results | Where-Object { $_ }).Count
    }
    
    # 3. Multimedia Class Scheduler (MMCSS)
    if ($EnableMultimediaOptimization) {
        Write-Log -Message "Tuning MMCSS for Gaming Priority" -Level Info
        
        $results = @(
            # Prioritize 'Games' profile
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority" -Value 8 -Type DWord),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6 -Type DWord),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High" -Type String),
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "SFIO Priority" -Value "High" -Type String),
            
            # Global System Profile
            (Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord)
        )
        $successCount += ($results | Where-Object { $_ }).Count
    }
    
    Write-Log -Message "Gaming optimizations applied: $successCount settings changed." -Level Success
}

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7Gaming' -Value 'Set-WinDebloatGaming'
Set-Alias -Name 'Optimize-WinDebloatGaming' -Value 'Set-WinDebloatGaming'
Set-Alias -Name 'Optimize-WinDebloat7Gaming' -Value 'Set-WinDebloatGaming'

Export-ModuleMember -Function @(
    'Set-WinDebloatGaming'
) -Alias @(
    'Set-WinDebloat7Gaming',
    'Optimize-WinDebloatGaming',
    'Optimize-WinDebloat7Gaming'
)
