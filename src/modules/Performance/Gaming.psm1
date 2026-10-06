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
    Version: 1.7.1
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

<#
.SYNOPSIS
    Tests whether the current CPU is an AMD Dual-CCD 3D V-Cache processor.
.OUTPUTS
    [bool] True if 7900X3D, 7950X3D, 9900X3D, 9950X3D or equivalent asymmetric cache silicon is detected.
#>
function Test-WinDebloatDualCcdX3D {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$ProcessorNameOverride
    )

    $procName = if ($ProcessorNameOverride) {
        $ProcessorNameOverride
    }
    else {
        try {
            (Get-ItemPropertyValue -Path "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -Name "ProcessorNameString" -ErrorAction Stop).Trim()
        }
        catch {
            $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cpu) { $cpu.Name.Trim() } else { "" }
        }
    }

    return [bool]($procName -match '\b(7900X3D|7950X3D|9900X3D|9950X3D|7945HX3D|9945HX3D)\b')
}

<#
.SYNOPSIS
    Protects AMD Dual-CCD 3D V-Cache CPUs (7900X3D/7950X3D/9900X3D/9950X3D/7945HX3D/9945HX3D) from cross-CCD latency penalties.
#>
function Protect-WinDebloatAMDX3D {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Configuring AMD 3D V-Cache dual-CCD core parking safeguards..." -Level Info

    if ($PSCmdlet.ShouldProcess("AMD 3D V-Cache Subsystem", "Enforce AutoGameMode and verify amd3dvcache driver service")) {
        # AutoGameMode must remain enabled for AMD PPM Provisioning driver to park non-V-Cache CCD
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord
        
        # Ensure amd3dvcache or Amd3DVCacheService is running if present
        $amdService = Get-Service -Name "amd3dvcache", "Amd3DVCacheService" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($amdService) {
            Set-Service -Name $amdService.Name -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $amdService.Name -ErrorAction SilentlyContinue
            Write-Log -Message "AMD 3D V-Cache Optimizer Service ($($amdService.Name)) verified and running." -Level Success
        }
        else {
            Write-Log -Message "AMD 3D V-Cache driver not present on this system (skipped)." -Level Debug
        }

        # If Dual-CCD X3D CPU is detected, enforce CPMINCORES = 0 and CPMINCORES1 = 0 so driver can park standard CCD cores during games
        if (Test-WinDebloatDualCcdX3D) {
            Write-Log -Message "AMD Dual-CCD 3D V-Cache CPU detected. Enforcing core parking headroom (CPMINCORES = 0, CPMINCORES1 = 0)..." -Level Info
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 0 2>$null
            & powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES1 0 2>$null
            & powercfg /setactive SCHEME_CURRENT 2>$null
        }
    }
}

<#
.SYNOPSIS
    Configures Hardware-Accelerated GPU Scheduling (HAGS 2.0) and TDR driver timeout stability.
#>
function Set-WinDebloatHAGSTDR {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [switch]$EnableHAGS = $true,
        [int]$TdrDelaySeconds = 8
    )

    Write-Log -Message "Configuring GPU Scheduling and TDR driver stability..." -Level Info

    if ($PSCmdlet.ShouldProcess("Graphics Subsystem", "Configure HAGS 2.0 and TDR timeout")) {
        # HAGS: 2 = Enabled, 1 = Disabled
        if ($EnableHAGS) {
            Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord
        }

        # TDR Delay: 8s delay, 10s DDI delay (prevents false-positive driver reset on shader compiles)
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Value $TdrDelaySeconds -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -Value ($TdrDelaySeconds + 2) -Type DWord
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrLevel" -Value 3 -Type DWord

        Write-Log -Message "GPU Scheduling and TDR stability configured." -Level Success
    }
}

<#
.SYNOPSIS
    Restores GPU Scheduling and TDR timeouts to Windows defaults.
#>
function Reset-WinDebloatHAGSTDR {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Graphics Subsystem", "Restore default TDR and GPU scheduling values")) {
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay"
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrLevel"
        Write-Log -Message "TDR and GPU scheduling restored to defaults." -Level Success
    }
}

<#
.SYNOPSIS
    Enables DirectX Super Resolution (DirectSR / AutoSR) and VRR windowed optimization.
#>
function Enable-WinDebloatDirectSR {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Enabling DirectX Super Resolution (DirectSR) & Windowed VRR..." -Level Info

    if ($PSCmdlet.ShouldProcess("DirectX Subsystem", "Enable DirectSR and Windowed VRR optimization")) {
        Set-RegistryKey -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Value "SwapEffectUpgradeEnable=1;VRROptimizeEnable=1;DXGIEffects=1028;" -Type String
        Write-Log -Message "DirectSR and Windowed VRR optimizations enabled." -Level Success
    }
}

<#
.SYNOPSIS
    Disables DirectX Super Resolution (DirectSR) customizations.
#>
function Disable-WinDebloatDirectSR {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("DirectX Subsystem", "Restore DirectX User GPU preferences")) {
        Remove-RegistryKey -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings"
        Write-Log -Message "DirectX User GPU preferences restored." -Level Success
    }
}

<#
.SYNOPSIS
    Restores AMD 3D V-Cache AutoGameMode configuration to Windows defaults.
#>
function Reset-WinDebloatAMDX3D {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("AMD 3D V-Cache Subsystem", "Restore default AutoGameMode registry values")) {
        Remove-RegistryKey -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode"
        Remove-RegistryKey -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled"
        Write-Log -Message "AMD 3D V-Cache GameBar defaults restored." -Level Success
    }
}

<#
.SYNOPSIS
    Suppresses the 'You will need a new app to open this ms-gamebar link' popup
    when Xbox Game Bar is removed or disabled.
#>
function Disable-WinDebloatGameBarPopup {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Xbox Game Bar Popups", "Disable ms-gamebar protocol handler prompt")) {
        Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord | Out-Null

        $protocols = @("HKCR:\ms-gamebar", "HKCR:\ms-gamebarservices")
        foreach ($proto in $protocols) {
            Set-RegistryKey -Path $proto -Name "" -Value ($proto -replace '^HKCR:\\', 'URL:') -Type String | Out-Null
            Set-RegistryKey -Path $proto -Name "URL Protocol" -Value "" -Type String | Out-Null
            Set-RegistryKey -Path $proto -Name "NoOpenWith" -Value "" -Type String | Out-Null
            Set-RegistryKey -Path "$proto\shell\open\command" -Name "" -Value "%SystemRoot%\System32\systray.exe" -Type String | Out-Null
        }
        Write-Log -Message "Xbox Game Bar protocol popups disabled." -Level Success
    }
}

<#
.SYNOPSIS
    Restores the standard Windows Xbox Game Bar protocol handlers.
#>
function Enable-WinDebloatGameBarPopup {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Xbox Game Bar Popups", "Restore ms-gamebar protocol handlers")) {
        Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 1 -Type DWord | Out-Null

        $protocols = @("HKCR:\ms-gamebar", "HKCR:\ms-gamebarservices")
        foreach ($proto in $protocols) {
            Remove-RegistryKey -Path $proto -Name "NoOpenWith" | Out-Null
            Remove-RegistryKey -Path "$proto\shell\open\command" -WholeKey | Out-Null
        }
        Write-Log -Message "Xbox Game Bar protocol handlers restored." -Level Success
    }
}

<#
.SYNOPSIS
    Configures Multimedia Class Scheduler Service (MMCSS) network throttling and gaming priority.
#>
function Set-WinDebloatMMCSSPriority {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Configuring MMCSS gaming scheduling and disabling network throttling..." -Level Info

    if ($PSCmdlet.ShouldProcess("Multimedia Class Scheduler", "Configure zero network throttling and high gaming priority")) {
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $tasksGames = "$sysProfile\Tasks\Games"

        Set-RegistryKey -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord | Out-Null
        Set-RegistryKey -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord | Out-Null
        Set-RegistryKey -Path $sysProfile -Name "NoLazyMode" -Value 1 -Type DWord | Out-Null

        Set-RegistryKey -Path $tasksGames -Name "Clock Rate" -Value 10000 -Type DWord | Out-Null
        Set-RegistryKey -Path $tasksGames -Name "GPU Priority" -Value 8 -Type DWord | Out-Null
        Set-RegistryKey -Path $tasksGames -Name "Priority" -Value 6 -Type DWord | Out-Null
        Set-RegistryKey -Path $tasksGames -Name "Scheduling Category" -Value "High" -Type String | Out-Null
        Set-RegistryKey -Path $tasksGames -Name "SFIO Priority" -Value "High" -Type String | Out-Null

        # Low-latency foreground quantum (0x26 = 38 decimal: short, variable, 3:1 foreground boost)
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord | Out-Null

        Write-Log -Message "MMCSS gaming priorities configured with network throttling disabled." -Level Success
    }
}

<#
.SYNOPSIS
    Restores MMCSS network throttling and gaming tasks to Windows defaults.
#>
function Reset-WinDebloatMMCSSPriority {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("Multimedia Class Scheduler", "Restore default MMCSS settings")) {
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-RegistryKey -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord | Out-Null
        Set-RegistryKey -Path $sysProfile -Name "SystemResponsiveness" -Value 20 -Type DWord | Out-Null
        Remove-RegistryKey -Path $sysProfile -Name "NoLazyMode" | Out-Null
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord | Out-Null
        Write-Log -Message "MMCSS defaults restored." -Level Success
    }
}

<#
.SYNOPSIS
    Disables Autonomous Power State Transitions (APST) on NVMe storage controllers to eliminate gaming latency spikes.
#>
function Disable-WinDebloatNVMeAPST {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling NVMe Autonomous Power State Transitions (APST)..." -Level Info

    if ($PSCmdlet.ShouldProcess("NVMe Storage Subsystem", "Disable APST power state transitions")) {
        $stornvmeKey = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
        Set-RegistryKey -Path $stornvmeKey -Name "DisableAPST" -Value 1 -Type DWord | Out-Null
        Write-Log -Message "NVMe APST disabled (low-latency mode active)." -Level Success
    }
}

<#
.SYNOPSIS
    Enables default Autonomous Power State Transitions (APST) on NVMe storage controllers.
#>
function Enable-WinDebloatNVMeAPST {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess("NVMe Storage Subsystem", "Restore default APST power state transitions")) {
        $stornvmeKey = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
        Remove-RegistryKey -Path $stornvmeKey -Name "DisableAPST" | Out-Null
        Write-Log -Message "NVMe APST restored to Windows default." -Level Success
    }
}

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7Gaming' -Value 'Set-WinDebloatGaming'
Set-Alias -Name 'Optimize-WinDebloatGaming' -Value 'Set-WinDebloatGaming'
Set-Alias -Name 'Optimize-WinDebloat7Gaming' -Value 'Set-WinDebloatGaming'
Set-Alias -Name 'Test-WinDebloat7DualCcdX3D' -Value 'Test-WinDebloatDualCcdX3D'
Set-Alias -Name 'Protect-WinDebloat7AMDX3D' -Value 'Protect-WinDebloatAMDX3D'
Set-Alias -Name 'Reset-WinDebloat7AMDX3D' -Value 'Reset-WinDebloatAMDX3D'
Set-Alias -Name 'Set-WinDebloat7HAGSTDR' -Value 'Set-WinDebloatHAGSTDR'
Set-Alias -Name 'Reset-WinDebloat7HAGSTDR' -Value 'Reset-WinDebloatHAGSTDR'
Set-Alias -Name 'Enable-WinDebloat7DirectSR' -Value 'Enable-WinDebloatDirectSR'
Set-Alias -Name 'Disable-WinDebloat7DirectSR' -Value 'Disable-WinDebloatDirectSR'
Set-Alias -Name 'Disable-WinDebloat7GameBarPopup' -Value 'Disable-WinDebloatGameBarPopup'
Set-Alias -Name 'Enable-WinDebloat7GameBarPopup' -Value 'Enable-WinDebloatGameBarPopup'
Set-Alias -Name 'Set-WinDebloat7MMCSSPriority' -Value 'Set-WinDebloatMMCSSPriority'
Set-Alias -Name 'Reset-WinDebloat7MMCSSPriority' -Value 'Reset-WinDebloatMMCSSPriority'
Set-Alias -Name 'Disable-WinDebloat7NVMeAPST' -Value 'Disable-WinDebloatNVMeAPST'
Set-Alias -Name 'Enable-WinDebloat7NVMeAPST' -Value 'Enable-WinDebloatNVMeAPST'

Export-ModuleMember -Function @(
    'Set-WinDebloatGaming',
    'Test-WinDebloatDualCcdX3D',
    'Protect-WinDebloatAMDX3D',
    'Reset-WinDebloatAMDX3D',
    'Set-WinDebloatHAGSTDR',
    'Reset-WinDebloatHAGSTDR',
    'Enable-WinDebloatDirectSR',
    'Disable-WinDebloatDirectSR',
    'Disable-WinDebloatGameBarPopup',
    'Enable-WinDebloatGameBarPopup',
    'Set-WinDebloatMMCSSPriority',
    'Reset-WinDebloatMMCSSPriority',
    'Disable-WinDebloatNVMeAPST',
    'Enable-WinDebloatNVMeAPST'
) -Alias @(
    'Set-WinDebloat7Gaming',
    'Optimize-WinDebloatGaming',
    'Optimize-WinDebloat7Gaming',
    'Test-WinDebloat7DualCcdX3D',
    'Protect-WinDebloat7AMDX3D',
    'Reset-WinDebloat7AMDX3D',
    'Set-WinDebloat7HAGSTDR',
    'Reset-WinDebloat7HAGSTDR',
    'Enable-WinDebloat7DirectSR',
    'Disable-WinDebloat7DirectSR',
    'Disable-WinDebloat7GameBarPopup',
    'Enable-WinDebloat7GameBarPopup',
    'Set-WinDebloat7MMCSSPriority',
    'Reset-WinDebloat7MMCSSPriority',
    'Disable-WinDebloat7NVMeAPST',
    'Enable-WinDebloat7NVMeAPST'
)
