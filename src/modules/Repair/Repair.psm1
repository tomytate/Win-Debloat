#Requires -Version 7.6

<#
.SYNOPSIS
    System Repair module for Win-Debloat
    
.DESCRIPTION
    Provides on-demand tools to repair Windows components.
    Includes SFC, DISM, Network Reset, and Update Reset.
    
.NOTES
    Module: Win-Debloat.Modules.Repair
    Version: 2.0.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

#region System Repair

<#
.SYNOPSIS
    Runs comprehensive system repair (enhanced 4-step sequence).
    
.DESCRIPTION
    Source: Win-Debloat Internal.
    Sequence: ChkDsk (performance mode) → SFC → DISM RestoreHealth → SFC (using repaired image).
#>
function Repair-WinDebloatSystem {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()

    Write-Log -Message "Starting Enhanced System Repair (4-Step Sequence)..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows System", "Full Repair (ChkDsk + SFC + DISM + SFC)")) {
        
        # Step 1: ChkDsk (Performance Mode)
        Write-Log -Message "[1/4] Running ChkDsk (scan mode)..." -Level Info
        try {
            $drive = if ($env:SystemDrive) { "$($env:SystemDrive)" } else { "C:" }
            $chkdsk = Start-Process -FilePath "chkdsk.exe" -ArgumentList $drive, "/scan", "/perf" -Wait -PassThru -NoNewWindow
            if ($chkdsk.ExitCode -eq 0) {
                Write-Log -Message "ChkDsk completed successfully." -Level Success
            }
            else {
                Write-Log -Message "ChkDsk returned exit code: $($chkdsk.ExitCode)" -Level Warning
            }
        }
        catch {
            Write-Log -Message "ChkDsk failed: $($_.Exception.Message)" -Level Warning
        }

        # Step 2: SFC First Pass
        Write-Log -Message "[2/4] Running SFC (first pass)..." -Level Info
        try {
            $sfc = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
            if ($sfc.ExitCode -eq 0) {
                Write-Log -Message "SFC first pass completed." -Level Success
            }
            else {
                Write-Log -Message "SFC first pass returned exit code: $($sfc.ExitCode)" -Level Warning
            }
        }
        catch {
            Write-Log -Message "SFC first pass failed: $($_.Exception.Message)" -Level Warning
        }

        # Step 3: DISM RestoreHealth
        Write-Log -Message "[3/4] Running DISM RestoreHealth (this may take 10-30 minutes)..." -Level Info
        try {
            $dism = Start-Process -FilePath "dism.exe" -ArgumentList "/Online", "/Cleanup-Image", "/RestoreHealth" -Wait -PassThru -NoNewWindow
            if ($dism.ExitCode -eq 0 -or $dism.ExitCode -eq 3010) {
                Write-Log -Message "DISM RestoreHealth completed successfully." -Level Success
            }
            else {
                Write-Log -Message "DISM RestoreHealth returned exit code: $($dism.ExitCode)" -Level Warning
            }
        }
        catch {
            Write-Log -Message "DISM failed: $($_.Exception.Message)" -Level Error
        }

        # Step 4: SFC Second Pass (uses repaired component store)
        Write-Log -Message "[4/4] Running SFC (second pass with repaired image)..." -Level Info
        try {
            $sfc2 = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
            if ($sfc2.ExitCode -eq 0) {
                Write-Log -Message "SFC second pass completed." -Level Success
            }
            else {
                Write-Log -Message "SFC second pass returned exit code: $($sfc2.ExitCode)" -Level Warning
            }
        }
        catch {
            Write-Log -Message "SFC second pass failed: $($_.Exception.Message)" -Level Warning
        }
        
        Write-Log -Message "Enhanced system repair complete." -Level Success
    }
}

#endregion

#region Network Reset

<#
.SYNOPSIS
    Resets Network Stack (IP, DNS, Winsock).
#>
function Reset-WinDebloatNetwork {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()

    Write-Log -Message "Starting Network Reset..." -Level Info

    if ($PSCmdlet.ShouldProcess("Network Stack", "Reset (IP/DNS/Winsock)")) {
        $tempDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $commands = @(
            "ipconfig /release",
            "ipconfig /flushdns",
            "ipconfig /renew",
            "netsh winsock reset",
            "netsh int ip reset `"$tempDir\netsh_reset.log`""
        )
        
        foreach ($cmd in $commands) {
            Write-Log -Message "Executing: $cmd" -Level Info
            $parts = $cmd -split ' ', 2
            $exe = $parts[0]
            $procArgs = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            try {
                $proc = Start-Process -FilePath $exe -ArgumentList $procArgs -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                if ($null -ne $proc -and $null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) {
                    Write-Log -Message "$cmd returned exit code: $($proc.ExitCode)" -Level Warning
                }
            }
            catch {
                Write-Log -Message "Execution notice for '$cmd': $($_.Exception.Message)" -Level Debug
            }
        }
        
        Write-Log -Message "Network reset complete. You may need to restart." -Level Success
    }
}
#endregion

#region Update Reset

<#
.SYNOPSIS
    Resets Windows Update components.
#>
function Reset-WinDebloatUpdate {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()

    begin {
        $services = @("wuauserv", "cryptSvc", "bits", "dosvc", "msiserver")
        $stoppedServices = [System.Collections.Generic.List[string]]::new()
    }

    process {
        Write-Log -Message "Starting Windows Update Reset..." -Level Info
        
        if ($PSCmdlet.ShouldProcess("Windows Update", "Reset Components")) {
            # Stop Services
            foreach ($svc in $services) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                $stoppedServices.Add($svc)
            }
            
            # Wait a moment for file locks to release
            Start-Sleep -Seconds 2
            
            # Rename Folders with leaf name to prevent path exception
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $folders = @("$env:systemroot\SoftwareDistribution", "$env:systemroot\System32\catroot2")
            foreach ($folder in $folders) {
                if (Test-Path $folder) {
                    $leaf = Split-Path $folder -Leaf
                    Rename-Item -Path $folder -NewName "$leaf.bak_$timestamp" -Force -ErrorAction SilentlyContinue
                }
            }
            
            Write-Log -Message "Windows Update components reset." -Level Success
        }
    }

    clean {
        # Guarantee stopped services are restarted even if cancelled by user (Ctrl+C) or on terminating error
        if ($stoppedServices -and $stoppedServices.Count -gt 0) {
            foreach ($svc in $stoppedServices) {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion

#region Component Store & DISM Servicing

<#
.SYNOPSIS
    Cleans up and compresses the Windows Component Store (WinSxS) with a strict 5-point safety gate.
#>
function Optimize-WinDebloatComponentStore {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [switch]$ResetBase,
        [switch]$Force
    )

    Write-Log -Message "Analyzing Windows Component Store (WinSxS)..." -Level Info

    # 5-Point Safety Gate for -ResetBase (irreversible superseded package cleanup)
    if ($ResetBase) {
        Write-Log -Message "Evaluating 5-Point Safety Gate for /ResetBase..." -Level Info

        # Gate 1: Pending Reboot Verification
        $pendingReboot = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
                         (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")
        if ($pendingReboot -and -not $Force) {
            Write-Log -Message "Safety Gate 1 Failed: System has a pending reboot. Restart system before running /ResetBase." -Level Error
            return
        }

        # Gate 2: Component Store Health Check
        Write-Log -Message "Safety Gate 2: Checking Component Store health..." -Level Info
        try {
            dism.exe /Online /Cleanup-Image /CheckHealth 2> variable:dismErrors
            if ($LASTEXITCODE -ne 0 -and -not $Force) {
                $diag = if ($dismErrors) { " Diagnostics: $($dismErrors -join ' | ')" } else { "" }
                Write-Log -Message "Safety Gate 2 Failed: Component Store has corruption.$diag Run Repair-WinDebloatSystem first." -Level Error
                return
            }
        }
        catch {
            Write-Log -Message "Safety Gate 2 CheckHealth failed: $($_.Exception.Message)" -Level Error
            if (-not $Force) { return }
        }

        # Gate 3: Free Disk Space Check (Minimum 5 GB on System Drive)
        $sysDrive = [System.IO.DriveInfo]::new($env:SystemDrive)
        $freeGB = $sysDrive.AvailableFreeSpace / 1GB
        if ($freeGB -lt 5.0 -and -not $Force) {
            Write-Log -Message "Safety Gate 3 Failed: Insufficient free disk space ($([math]::Round($freeGB, 2)) GB available, 5.0 GB required)." -Level Error
            return
        }

        # Gate 4: LCU Grace Period Notice
        Write-Log -Message "Safety Gate 4: /ResetBase makes current cumulative updates permanent (uninstallation will be disabled)." -Level Warning

        # Gate 5: ShouldProcess Confirmation
        if (-not $PSCmdlet.ShouldProcess("WinSxS Component Store", "Deep cleanup with /ResetBase (permanent superseded package purge)")) {
            return
        }

        Write-Log -Message "Executing DISM /StartComponentCleanup /ResetBase..." -Level Info
        try {
            dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2> variable:dismErrors
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "Component store /ResetBase optimization completed successfully." -Level Success
            }
            else {
                $diag = if ($dismErrors) { " Diagnostics: $($dismErrors -join ' | ')" } else { "" }
                Write-Log -Message "DISM /ResetBase returned exit code $LASTEXITCODE.$diag" -Level Warning
            }
        }
        catch {
            Write-Log -Message "DISM /ResetBase failed: $($_.Exception.Message)" -Level Error
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess("WinSxS Component Store", "Standard component cleanup")) {
            Write-Log -Message "Executing standard DISM /StartComponentCleanup..." -Level Info
            try {
                dism.exe /Online /Cleanup-Image /StartComponentCleanup 2> variable:dismErrors
                if ($LASTEXITCODE -eq 0) {
                    Write-Log -Message "Standard component store cleanup completed successfully." -Level Success
                }
                else {
                    $diag = if ($dismErrors) { " Diagnostics: $($dismErrors -join ' | ')" } else { "" }
                    Write-Log -Message "DISM returned exit code $LASTEXITCODE.$diag" -Level Warning
                }
            }
            catch {
                Write-Log -Message "DISM cleanup failed: $($_.Exception.Message)" -Level Error
            }
        }
    }
}

#endregion

#region Shell & Icon Cache Reset

<#
.SYNOPSIS
    Purges corrupted icon cache, thumbnail cache, and font cache files, restarting Explorer cleanly.
#>
function Reset-WinDebloatShellCache {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param()

    Write-Log -Message "Resetting Explorer Shell, Icon, Thumbnail, and Font Caches..." -Level Info

    if ($PSCmdlet.ShouldProcess("Windows Explorer", "Terminate process, purge shell/icon/font caches, and restart Explorer")) {
        # 1. Stop Explorer gracefully
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800

        # 2. Delete icon and thumbnail caches
        $explorerCacheDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Explorer"
        if (Test-Path -LiteralPath $explorerCacheDir) {
            Get-ChildItem -Path $explorerCacheDir -Filter "iconcache_*.db" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $explorerCacheDir -Filter "thumbcache_*.db" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        $legacyIconDb = Join-Path $env:LOCALAPPDATA "IconCache.db"
        if (Test-Path -LiteralPath $legacyIconDb) {
            Remove-Item -LiteralPath $legacyIconDb -Force -ErrorAction SilentlyContinue
        }

        # 3. Clear Font Cache
        $fontCacheDir = Join-Path $env:LOCALAPPDATA "Microsoft\FontCache"
        if (Test-Path -LiteralPath $fontCacheDir) {
            Get-ChildItem -Path $fontCacheDir -Filter "*.dat" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        # 4. Restart Explorer
        Start-Process -FilePath "$env:windir\explorer.exe" -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        # 5. Broadcast SHChangeNotify (with CLM guard and ie4uinit.exe fallback)
        $isConstrainedLanguage = ($ExecutionContext.SessionState.LanguageMode -eq [System.Management.Automation.PSLanguageMode]::ConstrainedLanguage) -or ($ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage')
        if (-not $isConstrainedLanguage) {
            try {
                $type = 'WinDebloat.Native.ShellNotificationHelper' -as [type]
                if (-not $type) {
                    $type = Add-Type -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);' -Name "ShellNotificationHelper" -Namespace "WinDebloat.Native" -PassThru -ErrorAction SilentlyContinue
                }
                if ($type) {
                    $type::SHChangeNotify(0x08000000, 0x0000, [System.IntPtr]::Zero, [System.IntPtr]::Zero) # SHCNE_ASSOCCHANGED, SHCNF_FLUSH
                }
                else {
                    Start-Process -FilePath "ie4uinit.exe" -ArgumentList "-show" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Log -Message "Shell notification broadcast notice: $($_.Exception.Message)" -Level Debug
                try {
                    Start-Process -FilePath "ie4uinit.exe" -ArgumentList "-show" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Log -Message "ie4uinit fallback notice: $($_.Exception.Message)" -Level Debug
                }
            }
        }
        else {
            Write-Log -Message "ConstrainedLanguage mode detected. Using ie4uinit.exe fallback for shell notification." -Level Debug
            try {
                Start-Process -FilePath "ie4uinit.exe" -ArgumentList "-show" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log -Message "ie4uinit fallback notice: $($_.Exception.Message)" -Level Debug
            }
        }

        Write-Log -Message "Shell, Icon, and Font caches reset successfully." -Level Success
    }
}

#endregion

#region Windows Update Error Remediation

<#
.SYNOPSIS
    Repairs common Windows Update error codes (0x80070002, 0x800f081f, 0x80073701).
#>
function Repair-WinDebloatUpdateError {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("0x80070002", "0x800f081f", "0x80073701", "Auto")]
        [string]$ErrorCode = "Auto"
    )

    Write-Log -Message "Running Windows Update Error Remediation (Target: $ErrorCode)..." -Level Info

    if ($PSCmdlet.ShouldProcess("Windows Update Subsystem", "Remediate update and servicing state")) {
        # 1. Reset services & distribution cache
        Reset-WinDebloatUpdate

        # 2. If payload missing error (0x800f081f / 0x80073701), execute component repair
        if ($ErrorCode -in @("0x800f081f", "0x80073701", "Auto")) {
            Write-Log -Message "Executing DISM image health restoration..." -Level Info
            try {
                dism.exe /Online /Cleanup-Image /RestoreHealth 2> variable:dismErrors
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
                    Write-Log -Message "DISM image health restoration completed successfully." -Level Success
                }
                else {
                    $diag = if ($dismErrors) { " Diagnostics: $($dismErrors -join ' | ')" } else { "" }
                    Write-Log -Message "DISM image health restoration returned exit code: $LASTEXITCODE.$diag" -Level Warning
                }
            }
            catch {
                Write-Log -Message "DISM image health restoration failed: $($_.Exception.Message)" -Level Error
            }
        }

        # 3. Flush BITS queue
        try {
            $bitsProc = Start-Process -FilePath "bitsadmin.exe" -ArgumentList "/reset", "/allusers" -Wait -PassThru -NoNewWindow
            if ($bitsProc.ExitCode -eq 0) {
                Write-Log -Message "BITS transfer queue cleared." -Level Success
            }
        }
        catch {
            Write-Log -Message "BITS reset notice: $($_.Exception.Message)" -Level Debug
        }

        Write-Log -Message "Windows Update error remediation completed." -Level Success
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Repair-WinDebloat7System' -Value 'Repair-WinDebloatSystem'
Set-Alias -Name 'Reset-WinDebloat7Network' -Value 'Reset-WinDebloatNetwork'
Set-Alias -Name 'Reset-WinDebloat7Update' -Value 'Reset-WinDebloatUpdate'
Set-Alias -Name 'Reset-WinDebloatWindowsUpdate' -Value 'Reset-WinDebloatUpdate'
Set-Alias -Name 'Reset-WinDebloat7WindowsUpdate' -Value 'Reset-WinDebloatUpdate'
Set-Alias -Name 'Optimize-WinDebloat7ComponentStore' -Value 'Optimize-WinDebloatComponentStore'
Set-Alias -Name 'Reset-WinDebloat7ShellCache' -Value 'Reset-WinDebloatShellCache'
Set-Alias -Name 'Repair-WinDebloat7UpdateError' -Value 'Repair-WinDebloatUpdateError'

Export-ModuleMember -Function @(
    'Repair-WinDebloatSystem',
    'Reset-WinDebloatNetwork',
    'Reset-WinDebloatUpdate',
    'Optimize-WinDebloatComponentStore',
    'Reset-WinDebloatShellCache',
    'Repair-WinDebloatUpdateError'
) -Alias @(
    'Repair-WinDebloat7System',
    'Reset-WinDebloat7Network',
    'Reset-WinDebloat7Update',
    'Reset-WinDebloatWindowsUpdate',
    'Reset-WinDebloat7WindowsUpdate',
    'Optimize-WinDebloat7ComponentStore',
    'Reset-WinDebloat7ShellCache',
    'Repair-WinDebloat7UpdateError'
)
