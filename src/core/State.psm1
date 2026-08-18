#Requires -Version 7.6

<#
.SYNOPSIS
    State management and snapshot module for Win-Debloat

.DESCRIPTION
    Creates comprehensive, restorable system snapshots and performs true
    value-level rollback. The snapshot captures the full value-set of every
    registry key the framework can modify (see Get-WinDebloatRegistryTargets)
    plus the state of the relevant services, so a restore returns the system
    to exactly the captured state:
      * changed values are re-set to their prior data and type,
      * values the framework added are deleted,
      * keys the framework created are removed.

.NOTES
    Module: Win-Debloat.Core.State
    Version: 1.5.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Security.Cryptography

Import-Module "$PSScriptRoot\Logger.psm1" -Force
Import-Module "$PSScriptRoot\Registry.psm1" -Force

class SystemSnapshot {
    [string]$Id
    [datetime]$Timestamp
    [string]$Name
    [string]$Description
    [hashtable]$Registry
    [array]$Services
    [string]$Version = "1.5.0"
}

#region Registry target catalog

# The single source of truth for every registry key the framework may write.
# Derived from all Set-RegistryKey / Set-ItemProperty / Set-WinDebloat7RegistryValue
# call sites across the modules. Snapshots capture the direct values of these keys
# (not their subkeys), which keeps captures small while covering every change the
# framework makes. Keep this in sync when a module writes a new key.
$Script:RegistrySnapshotTargets = @(
    # ── Privacy / telemetry ─────────────────────────────────────────────
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'
    'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'
    'HKCU:\SOFTWARE\Microsoft\Input\TIPC'
    'HKCU:\SOFTWARE\Microsoft\InputPersonalization'
    'HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore'
    'HKCU:\SOFTWARE\Microsoft\Personalization\Settings'
    'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
    'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice'
    'HKCU:\Control Panel\International\User Profile'

    # ── AI / Copilot / Recall ───────────────────────────────────────────
    'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    'HKCU:\Software\Microsoft\Notepad'
    'HKCU:\Software\Microsoft\Paint'

    # ── Suggestions / ads / spotlight ───────────────────────────────────
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Mobility'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

    # ── Performance / gaming ────────────────────────────────────────────
    'HKCU:\Control Panel\Desktop'
    'HKCU:\Control Panel\Desktop\WindowMetrics'
    'HKCU:\Control Panel\Mouse'
    'HKLM:\SYSTEM\CurrentControlSet\Control'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'
    'HKCU:\System\GameConfigStore'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    'HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters'

    # ── System QoL / boot / updates ─────────────────────────────────────
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
    'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9'
    'HKCU:\Control Panel\Accessibility\StickyKeys'
    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdate'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'

    # ── Search / shell / Explorer / taskbar ─────────────────────────────
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
    'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Clipboard'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe'
    'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
    'HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
    # Gallery / Home navigation-pane pins (Set-WinDebloat7Explorer)
    'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-ed25316e9424}'
    'HKLM:\SOFTWARE\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-ed25316e9424}'
    'HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}'
    # "This PC" folder entries removed by Hide3DObjects / HideMusic
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'
    # Shell context-menu handler keys deleted by Set-WinDebloat7ContextMenuItems.
    # Their identity lives in the DEFAULT (unnamed) value = handler CLSID, which
    # the snapshot captures so restore can recreate the handler. The '*' below is
    # a literal registry key name, not a wildcard - all snapshot operations use
    # -LiteralPath / raw .NET access.
    'Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\ModernSharing'
    'Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing'
    'Registry::HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers\Sharing'
    'Registry::HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers\Sharing'
    'Registry::HKEY_CLASSES_ROOT\Drive\shellex\ContextMenuHandlers\Sharing'
    'Registry::HKEY_CLASSES_ROOT\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing'
    'Registry::HKEY_CLASSES_ROOT\Folder\ShellEx\ContextMenuHandlers\Library Location'
)

<#
.SYNOPSIS
    Returns the list of registry keys the framework may modify (and that
    snapshots therefore capture and restore).
#>
function Get-WinDebloatRegistryTargets {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return $Script:RegistrySnapshotTargets
}

# Maps a RegistryValueKind name to a Set-ItemProperty -Type value.
function ConvertTo-WDRegistryType {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Kind)
    switch ($Kind) {
        'DWord' { 'DWord' }
        'QWord' { 'QWord' }
        'Binary' { 'Binary' }
        'MultiString' { 'MultiString' }
        'ExpandString' { 'ExpandString' }
        'String' { 'String' }
        default { 'String' }  # None / Unknown fall back to String
    }
}

# Opens (or creates) a registry key through the .NET API using a fully literal
# path. Required for cataloged keys whose names contain '*' (HKCR\*\shellex\...)
# where the PowerShell provider would treat the name as a wildcard, and for
# setting/removing DEFAULT (unnamed) values, which Set-RegistryKey cannot address.
# Returns a writable RegistryKey (caller must Close it) or $null.
function Get-WDRawRegistryKey {
    [CmdletBinding()]
    [OutputType([Microsoft.Win32.RegistryKey])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Create
    )

    $hive = $null
    $subKey = $null
    if ($Path -match '^HKLM:\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::LocalMachine; $subKey = $Matches[1] }
    elseif ($Path -match '^HKCU:\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::CurrentUser; $subKey = $Matches[1] }
    elseif ($Path -match '^HKCR:\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::ClassesRoot; $subKey = $Matches[1] }
    elseif ($Path -match '^HKU:\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::Users; $subKey = $Matches[1] }
    elseif ($Path -match '^HKCC:\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::CurrentConfig; $subKey = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_LOCAL_MACHINE\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::LocalMachine; $subKey = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_CURRENT_USER\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::CurrentUser; $subKey = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_CLASSES_ROOT\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::ClassesRoot; $subKey = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_USERS\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::Users; $subKey = $Matches[1] }
    elseif ($Path -match '^Registry::HKEY_CURRENT_CONFIG\\?(.*)$') { $hive = [Microsoft.Win32.Registry]::CurrentConfig; $subKey = $Matches[1] }
    else { return $null }

    try {
        if ($Create) { return $hive.CreateSubKey($subKey, $true) }
        return $hive.OpenSubKey($subKey, $true)
    }
    catch {
        Write-Verbose "Raw registry key open failed for '$Path': $($_.Exception.Message)"
        return $null
    }
}

# Protects data using DPAPI with robust validation and error reporting.
function Protect-WDData {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Data,

        [System.Security.Cryptography.DataProtectionScope]$Scope = [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )

    if ($null -eq $Data -or $Data.Length -eq 0) {
        throw [System.ArgumentException]::new("Data to protect cannot be null or empty.")
    }

    try {
        return [System.Security.Cryptography.ProtectedData]::Protect($Data, $null, $Scope)
    }
    catch [System.Security.Cryptography.CryptographicException] {
        Write-Log -Message "DPAPI encryption failed: $($_.Exception.Message). Ensure current user profile is loaded." -Level Error
        throw
    }
    catch {
        Write-Log -Message "Data protection error: $($_.Exception.Message)" -Level Error
        throw
    }
}

# Unprotects DPAPI encrypted data with diagnostic error handling.
function Unprotect-WDData {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$EncryptedData,

        [System.Security.Cryptography.DataProtectionScope]$Scope = [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )

    if ($null -eq $EncryptedData -or $EncryptedData.Length -eq 0) {
        throw [System.ArgumentException]::new("Encrypted data cannot be null or empty.")
    }

    try {
        return [System.Security.Cryptography.ProtectedData]::Unprotect($EncryptedData, $null, $Scope)
    }
    catch [System.Security.Cryptography.CryptographicException] {
        Write-Log -Message "DPAPI decryption failed: $($_.Exception.Message). Snapshot may have been encrypted under a different user account or non-elevated context." -Level Error
        throw
    }
    catch {
        Write-Log -Message "Data unprotection error: $($_.Exception.Message)" -Level Error
        throw
    }
}

# High-fidelity equality comparison for registry values across all types
# (DWord, QWord, Binary blobs, MultiString string arrays, ExpandString, Default unnamed values).
function Test-WDRegistryValueEqual {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        $Value1,

        [string]$Kind1,

        [AllowNull()]
        $Value2,

        [string]$Kind2
    )

    if ($null -eq $Value1 -and $null -eq $Value2) {
        return $true
    }
    if ($null -eq $Value1 -or $null -eq $Value2) {
        return $false
    }

    if ([string]::IsNullOrEmpty($Kind1)) { $Kind1 = 'String' }
    if ([string]::IsNullOrEmpty($Kind2)) { $Kind2 = 'String' }

    if ($Kind1 -ne $Kind2) {
        return $false
    }

    switch ($Kind1) {
        'Binary' {
            $b1 = [byte[]]$Value1
            $b2 = [byte[]]$Value2
            if ($b1.Length -ne $b2.Length) { return $false }
            for ($i = 0; $i -lt $b1.Length; $i++) {
                if ($b1[$i] -ne $b2[$i]) { return $false }
            }
            return $true
        }
        'MultiString' {
            $s1 = [string[]]$Value1
            $s2 = [string[]]$Value2
            if ($s1.Length -ne $s2.Length) { return $false }
            for ($i = 0; $i -lt $s1.Length; $i++) {
                if ($s1[$i] -cne $s2[$i]) { return $false }
            }
            return $true
        }
        'DWord' {
            try {
                return [int64]$Value1 -eq [int64]$Value2
            }
            catch {
                return "$Value1" -eq "$Value2"
            }
        }
        'QWord' {
            try {
                return [decimal]$Value1 -eq [decimal]$Value2
            }
            catch {
                return "$Value1" -eq "$Value2"
            }
        }
        'ExpandString' {
            return [string]$Value1 -eq [string]$Value2
        }
        default {
            return [string]$Value1 -eq [string]$Value2
        }
    }
}

# Captures the direct values of one registry key: whether it exists, and each
# value's data + kind. The default (unnamed) value is captured under the key ''
# - it carries the payload for shell-extension handler keys (CLSID string).
function Get-WDRegistryKeyState {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string]$Path)

    # Note: key is named 'RegValues' (not 'Values') to avoid colliding with the
    # built-in Hashtable.Values property, which member access would resolve first.
    $state = @{ Existed = $false; RegValues = @{} }
    try {
        if (Test-Path -LiteralPath $Path) {
            $state['Existed'] = $true
            $raw = Get-WDRawRegistryKey -Path $Path
            if ($null -ne $raw) {
                try {
                    foreach ($valueName in $raw.GetValueNames()) {
                        $valKind = $raw.GetValueKind($valueName)
                        $valData = $raw.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        $state['RegValues'][$valueName] = @{
                            Value = $valData
                            Kind  = $valKind.ToString()
                        }
                    }
                }
                finally {
                    $raw.Close()
                }
            }
            else {
                $key = Get-Item -LiteralPath $Path -ErrorAction Stop
                foreach ($valueName in $key.GetValueNames()) {
                    $state['RegValues'][$valueName] = @{
                        Value = $key.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        Kind  = $key.GetValueKind($valueName).ToString()
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Snapshot capture failed for '$Path': $($_.Exception.Message)"
    }
    return $state
}

# Restores a single registry key to a captured state. Returns @{ Success; Fail }.
# Factored out of Restore-WinDebloatSnapshot so the rollback logic is unit-testable.
function Restore-WDRegistryKey {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $SnapState   # v1.4 hashtable { Existed; Values } OR legacy flat property object
    )

    $result = @{ Success = 0; Fail = 0 }

    # ── v1.4 value-level format ─────────────────────────────────────────
    # Use IDictionary + indexer access so it works whether $SnapState is a live
    # hashtable or one rehydrated from CLIXML.
    if ($SnapState -is [System.Collections.IDictionary] -and $SnapState.Contains('Existed')) {

        # (a) The framework created this key — remove it to fully revert.
        if (-not $SnapState['Existed']) {
            if (Test-Path -LiteralPath $Path) {
                if ($PSCmdlet.ShouldProcess($Path, "Remove framework-created key")) {
                    try {
                        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
                        Write-Log -Message "Removed created key: $Path" -Level Info
                        $result.Success++
                    }
                    catch {
                        Write-Log -Message "Failed to remove key '$Path': $($_.Exception.Message)" -Level Warning
                        $result.Fail++
                    }
                }
            }
            return $result
        }

        # (b) The key existed — make its values match the snapshot exactly.
        $snapValues = $SnapState['RegValues']

        # b1. Re-set each captured value to its prior data + type
        foreach ($valueName in @($snapValues.Keys)) {
            $entry = $snapValues[$valueName]
            $type = ConvertTo-WDRegistryType -Kind $entry['Kind']
            $data = $entry['Value']
            # Coerce array types that CLIXML may have widened on deserialization
            if ($type -eq 'Binary' -and $null -ne $data) { $data = [byte[]]$data }
            elseif ($type -eq 'MultiString' -and $null -ne $data) { $data = [string[]]$data }

            # Default (unnamed) values, Registry::-prefixed paths, and paths with
            # literal wildcard characters ('*' key names) can't go through
            # Set-RegistryKey / the -Path provider - use the .NET API.
            if ([string]::IsNullOrEmpty($valueName) -or $Path -notmatch '^HK(LM|CU|CR|U|CC):\\' -or $Path -match '[\*\?\[\]]') {
                $display = if ([string]::IsNullOrEmpty($valueName)) { "$Path\(default)" } else { "$Path\$valueName" }
                if ($PSCmdlet.ShouldProcess($display, "Restore value")) {
                    $raw = $null
                    try {
                        $raw = Get-WDRawRegistryKey -Path $Path -Create
                        if ($null -eq $raw) { throw "Unsupported registry hive in path" }
                        $raw.SetValue($valueName, $data, [Microsoft.Win32.RegistryValueKind]$entry['Kind'])
                        $result.Success++
                    }
                    catch {
                        Write-Log -Message "Failed to restore '$display': $($_.Exception.Message)" -Level Warning
                        $result.Fail++
                    }
                    finally {
                        if ($raw) { $raw.Close() }
                    }
                }
            }
            else {
                if (Set-RegistryKey -Path $Path -Name $valueName -Value $data -Type $type) { $result.Success++ }
                else { $result.Fail++ }
            }
        }

        # b2. Delete values present now but absent from the snapshot (framework-added)
        try {
            if (Test-Path -LiteralPath $Path) {
                $nowKey = Get-Item -LiteralPath $Path -ErrorAction Stop
                foreach ($valueName in $nowKey.GetValueNames()) {
                    if (-not $snapValues.Contains($valueName)) {
                        if ([string]::IsNullOrEmpty($valueName)) {
                            # PS7's registry provider can't address the default value
                            # by name for removal - delete it through the .NET API.
                            if ($PSCmdlet.ShouldProcess("$Path\(default)", "Remove framework-added value")) {
                                $raw = Get-WDRawRegistryKey -Path $Path
                                if ($raw) {
                                    try { $raw.DeleteValue('', $false); $result.Success++ }
                                    finally { $raw.Close() }
                                }
                            }
                        }
                        else {
                            if ($PSCmdlet.ShouldProcess("$Path\$valueName", "Remove framework-added value")) {
                                Remove-ItemProperty -LiteralPath $Path -Name $valueName -Force -ErrorAction SilentlyContinue
                                $result.Success++
                            }
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not prune added values at '$Path': $($_.Exception.Message)"
        }

        return $result
    }

    # ── Legacy format (pre-1.4 snapshots stored a flat property object) ─
    if ($SnapState) {
        foreach ($prop in $SnapState.PSObject.Properties) {
            if ($prop.Name -notmatch '^PS') {
                $regType = switch ($prop.Value) {
                    { $_ -is [long] -or $_ -is [uint64] } { "QWord" }
                    { $_ -is [int] -or $_ -is [uint32] -or $_ -is [byte] -or $_ -is [int16] } { "DWord" }
                    { $_ -is [byte[]] } { "Binary" }
                    { $_ -is [string[]] } { "MultiString" }
                    default { "String" }
                }
                if (Set-RegistryKey -Path $Path -Name $prop.Name -Value $prop.Value -Type $regType) { $result.Success++ }
                else { $result.Fail++ }
            }
        }
    }

    return $result
}

function Get-WinDebloatSnapshotDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Create
    )
    $localAppData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { "$env:USERPROFILE\AppData\Local" }
    $primaryPath = Join-Path $localAppData "Win-Debloat\Snapshots"
    if ($Create -and -not (Test-Path -LiteralPath $primaryPath)) {
        New-Item -Path $primaryPath -ItemType Directory -Force | Out-Null
    }
    return $primaryPath
}

function Get-WinDebloatSnapshotSearchPaths {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns multiple candidate search paths')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $paths = [System.Collections.Generic.List[string]]::new()
    $localAppData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { "$env:USERPROFILE\AppData\Local" }
    $progData = if ($env:ProgramData) { $env:ProgramData } else { "$env:SystemDrive\ProgramData" }
    
    $candidates = @(
        (Join-Path $localAppData "Win-Debloat\Snapshots"),
        (Join-Path $localAppData "Win-Debloat7\Snapshots"),
        (Join-Path $progData "Win-Debloat\Snapshots"),
        (Join-Path $progData "Win-Debloat7\Snapshots")
    )
    foreach ($cand in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($cand) -and -not $paths.Contains($cand)) {
            $paths.Add($cand)
        }
    }
    return $paths.ToArray()
}

<#
.SYNOPSIS
    Compares two system snapshots or compares a snapshot against the live system.

.DESCRIPTION
    Performs high-fidelity registry and service diffing across all captured targets.
    Accurately diffs:
      * DWORDs and QWORDs (numeric equivalence)
      * Binary blobs (byte-by-byte sequence comparison)
      * MultiString / string arrays (exact element sequence comparison)
      * ExpandString (unexpanded environment string preservation)
      * Default unnamed values ('')
      * Key additions, deletions, and value modifications
      * Service status and startup type changes

.PARAMETER ReferenceSnapshot
    The base snapshot object, hashtable, or snapshot ID.

.PARAMETER DifferenceSnapshot
    The comparison snapshot object, hashtable, or snapshot ID.
    If omitted or $null, compares against the live system registry and services.

.PARAMETER ReferenceId
    The base snapshot ID to look up from disk.

.PARAMETER DifferenceId
    The comparison snapshot ID to look up from disk.

.PARAMETER IncludeUnchanged
    If specified, unchanged values will also be returned in the diff collection.

.OUTPUTS
    [PSCustomObject] containing diff summaries, RegistryDiffs, and ServiceDiffs.
#>
function Compare-WinDebloatSnapshot {
    [CmdletBinding(DefaultParameterSetName = 'Snapshots')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Snapshots', Position = 0)]
        [object]$ReferenceSnapshot,

        [Parameter(Mandatory = $false, ParameterSetName = 'Snapshots', Position = 1)]
        [object]$DifferenceSnapshot = $null,

        [Parameter(Mandatory, ParameterSetName = 'Ids')]
        [string]$ReferenceId,

        [Parameter(Mandatory = $false, ParameterSetName = 'Ids')]
        [string]$DifferenceId,

        [switch]$IncludeUnchanged
    )

    $resolveSnap = {
        param($inputObj, $idStr)
        if ($idStr) {
            foreach ($searchDir in (Get-WinDebloatSnapshotSearchPaths)) {
                $base = Join-Path $searchDir $idStr
                $clixml = Join-Path $base "snapshot.clixml"
                $enc = Join-Path $base "snapshot.encrypted"
                if (Test-Path -LiteralPath $clixml) {
                    return (Get-Content -LiteralPath $clixml -Raw) | ConvertFrom-CliXml
                }
                elseif (Test-Path -LiteralPath $enc) {
                    $encBytes = [System.IO.File]::ReadAllBytes($enc)
                    $decBytes = Unprotect-WDData -EncryptedData $encBytes
                    return [System.Text.Encoding]::UTF8.GetString($decBytes) | ConvertFrom-CliXml
                }
            }
            throw "Snapshot ID not found: $idStr"
        }
        if ($inputObj -is [string]) {
            return & $resolveSnap $null $inputObj
        }
        return $inputObj
    }

    $ref = & $resolveSnap $ReferenceSnapshot $ReferenceId
    if ($null -eq $ref) {
        throw "Reference snapshot could not be resolved."
    }

    $diff = $null
    $isLiveComparison = $false
    if ($DifferenceId) {
        $diff = & $resolveSnap $null $DifferenceId
    }
    elseif ($null -ne $DifferenceSnapshot) {
        $diff = & $resolveSnap $DifferenceSnapshot $null
    }
    else {
        $isLiveComparison = $true
    }

    $refName = if ($ref.Name) { $ref.Name } else { "Reference" }
    $refId = if ($ref.Id) { $ref.Id } else { "Ref" }
    $refReg = if ($ref.Registry) { $ref.Registry } else { @{} }

    $diffName = if ($isLiveComparison) { "Live System" } elseif ($diff.Name) { $diff.Name } else { "Difference" }
    $diffId = if ($isLiveComparison) { "LIVE" } elseif ($diff.Id) { $diff.Id } else { "Diff" }
    
    # If comparing to live system, capture live state for all keys in reference + target catalog
    $diffReg = @{}
    if ($isLiveComparison) {
        $keysToCapture = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($k in $refReg.Keys) { [void]$keysToCapture.Add($k) }
        foreach ($k in $Script:RegistrySnapshotTargets) { [void]$keysToCapture.Add($k) }
        foreach ($k in $keysToCapture) {
            $diffReg[$k] = Get-WDRegistryKeyState -Path $k
        }
    }
    else {
        $diffReg = if ($diff.Registry) { $diff.Registry } else { @{} }
    }

    $allRegKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($k in $refReg.Keys) { [void]$allRegKeys.Add($k) }
    foreach ($k in $diffReg.Keys) { [void]$allRegKeys.Add($k) }

    $regDiffs = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($regPath in $allRegKeys) {
        $refState = $refReg[$regPath]
        $diffState = $diffReg[$regPath]

        $refExisted = ($null -ne $refState) -and ($refState['Existed'] -eq $true)
        $diffExisted = ($null -ne $diffState) -and ($diffState['Existed'] -eq $true)

        if ($refExisted -and -not $diffExisted) {
            $regDiffs.Add([PSCustomObject]@{
                Path       = $regPath
                ValueName  = ""
                ChangeType = "KeyRemoved"
                OldValue   = "(Key Existed)"
                OldKind    = "Key"
                NewValue   = $null
                NewKind    = $null
            })
            continue
        }

        if (-not $refExisted -and $diffExisted) {
            $regDiffs.Add([PSCustomObject]@{
                Path       = $regPath
                ValueName  = ""
                ChangeType = "KeyAdded"
                OldValue   = $null
                OldKind    = $null
                NewValue   = "(Key Existed)"
                NewKind    = "Key"
            })
            # Also enumerate values in the added key
            $diffVals = $diffState['RegValues']
            if ($diffVals) {
                foreach ($vn in $diffVals.Keys) {
                    $vEntry = $diffVals[$vn]
                    $regDiffs.Add([PSCustomObject]@{
                        Path       = $regPath
                        ValueName  = $vn
                        ChangeType = "ValueAdded"
                        OldValue   = $null
                        OldKind    = $null
                        NewValue   = $vEntry['Value']
                        NewKind    = $vEntry['Kind']
                    })
                }
            }
            continue
        }

        if ($refExisted -and $diffExisted) {
            $refVals = if ($refState['RegValues']) { $refState['RegValues'] } else { @{} }
            $diffVals = if ($diffState['RegValues']) { $diffState['RegValues'] } else { @{} }

            $allValNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($vn in $refVals.Keys) { [void]$allValNames.Add($vn) }
            foreach ($vn in $diffVals.Keys) { [void]$allValNames.Add($vn) }

            foreach ($vn in $allValNames) {
                $hasRefVal = $refVals.Contains($vn)
                $hasDiffVal = $diffVals.Contains($vn)

                if ($hasRefVal -and -not $hasDiffVal) {
                    $rEntry = $refVals[$vn]
                    $regDiffs.Add([PSCustomObject]@{
                        Path       = $regPath
                        ValueName  = $vn
                        ChangeType = "ValueRemoved"
                        OldValue   = $rEntry['Value']
                        OldKind    = $rEntry['Kind']
                        NewValue   = $null
                        NewKind    = $null
                    })
                }
                elseif (-not $hasRefVal -and $hasDiffVal) {
                    $dEntry = $diffVals[$vn]
                    $regDiffs.Add([PSCustomObject]@{
                        Path       = $regPath
                        ValueName  = $vn
                        ChangeType = "ValueAdded"
                        OldValue   = $null
                        OldKind    = $null
                        NewValue   = $dEntry['Value']
                        NewKind    = $dEntry['Kind']
                    })
                }
                else {
                    $rEntry = $refVals[$vn]
                    $dEntry = $diffVals[$vn]
                    $isEqual = Test-WDRegistryValueEqual -Value1 $rEntry['Value'] -Kind1 $rEntry['Kind'] -Value2 $dEntry['Value'] -Kind2 $dEntry['Kind']

                    if (-not $isEqual) {
                        $regDiffs.Add([PSCustomObject]@{
                            Path       = $regPath
                            ValueName  = $vn
                            ChangeType = "ValueModified"
                            OldValue   = $rEntry['Value']
                            OldKind    = $rEntry['Kind']
                            NewValue   = $dEntry['Value']
                            NewKind    = $dEntry['Kind']
                        })
                    }
                    elseif ($IncludeUnchanged) {
                        $regDiffs.Add([PSCustomObject]@{
                            Path       = $regPath
                            ValueName  = $vn
                            ChangeType = "Unchanged"
                            OldValue   = $rEntry['Value']
                            OldKind    = $rEntry['Kind']
                            NewValue   = $dEntry['Value']
                            NewKind    = $dEntry['Kind']
                        })
                    }
                }
            }
        }
    }

    # Service diffing
    $svcDiffs = [System.Collections.Generic.List[PSCustomObject]]::new()
    $refSvcs = @{}
    if ($ref.Services) {
        foreach ($s in $ref.Services) {
            $refSvcs[$s.Name] = $s
        }
    }

    $diffSvcs = @{}
    if ($isLiveComparison) {
        try {
            foreach ($s in (Get-Service -ErrorAction SilentlyContinue)) {
                $diffSvcs[$s.Name] = [PSCustomObject]@{
                    Name        = $s.Name
                    Status      = $s.Status.ToString()
                    StartType   = $s.StartType.ToString()
                    DisplayName = $s.DisplayName
                }
            }
        }
        catch {
            Write-Verbose "Could not query live services for diff: $($_.Exception.Message)"
        }
    }
    elseif ($diff.Services) {
        foreach ($s in $diff.Services) {
            $diffSvcs[$s.Name] = $s
        }
    }

    $allSvcNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($sn in $refSvcs.Keys) { [void]$allSvcNames.Add($sn) }
    if (-not $isLiveComparison) {
        foreach ($sn in $diffSvcs.Keys) { [void]$allSvcNames.Add($sn) }
    }

    foreach ($sn in $allSvcNames) {
        $rSvc = $refSvcs[$sn]
        $dSvc = $diffSvcs[$sn]

        if ($rSvc -and -not $dSvc) {
            $svcDiffs.Add([PSCustomObject]@{
                ServiceName  = $sn
                ChangeType   = "ServiceRemoved"
                OldStartType = $rSvc.StartType
                NewStartType = $null
                OldStatus    = $rSvc.Status
                NewStatus    = $null
            })
        }
        elseif (-not $rSvc -and $dSvc) {
            $svcDiffs.Add([PSCustomObject]@{
                ServiceName  = $sn
                ChangeType   = "ServiceAdded"
                OldStartType = $null
                NewStartType = $dSvc.StartType
                OldStatus    = $null
                NewStatus    = $dSvc.Status
            })
        }
        elseif ($rSvc -and $dSvc) {
            $startTypeChanged = "$($rSvc.StartType)" -ne "$($dSvc.StartType)"
            if ($startTypeChanged) {
                $svcDiffs.Add([PSCustomObject]@{
                    ServiceName  = $sn
                    ChangeType   = "ServiceModified"
                    OldStartType = $rSvc.StartType
                    NewStartType = $dSvc.StartType
                    OldStatus    = $rSvc.Status
                    NewStatus    = $dSvc.Status
                })
            }
            elseif ($IncludeUnchanged) {
                $svcDiffs.Add([PSCustomObject]@{
                    ServiceName  = $sn
                    ChangeType   = "Unchanged"
                    OldStartType = $rSvc.StartType
                    NewStartType = $dSvc.StartType
                    OldStatus    = $rSvc.Status
                    NewStatus    = $dSvc.Status
                })
            }
        }
    }

    $totalChanges = $regDiffs.Where({ $_.ChangeType -ne "Unchanged" }).Count + $svcDiffs.Where({ $_.ChangeType -ne "Unchanged" }).Count

    return [PSCustomObject]@{
        ReferenceId    = $refId
        ReferenceName  = $refName
        DifferenceId   = $diffId
        DifferenceName = $diffName
        Timestamp      = Get-Date
        RegistryDiffs  = @($regDiffs)
        ServiceDiffs   = @($svcDiffs)
        TotalChanges   = $totalChanges
        HasChanges     = ($totalChanges -gt 0)
    }
}

<#
.SYNOPSIS
    Creates a comprehensive, restorable system snapshot.

.DESCRIPTION
    Captures the direct values of every registry key the framework can modify
    plus the state of the relevant services, and also creates a Windows System
    Restore point as a second safety net.

.PARAMETER Name
    A friendly name for the snapshot.

.PARAMETER Description
    Optional description of the snapshot.

.PARAMETER Encrypt
    If specified, encrypts the snapshot using DPAPI (CurrentUser scope).

.OUTPUTS
    [SystemSnapshot] The created snapshot object.

.EXAMPLE
    New-WinDebloatSnapshot -Name "Pre-Optimization" -Encrypt
#>
function New-WinDebloatSnapshot {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([SystemSnapshot])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Name = "Auto-Snapshot",

        [string]$Description,

        [switch]$Encrypt
    )

    Write-Log -Message "Creating system snapshot: $Name" -Level Info

    $snapshot = [SystemSnapshot]::new()
    $snapshot.Id = [guid]::NewGuid().ToString()
    $snapshot.Timestamp = Get-Date
    $snapshot.Name = $Name
    $snapshot.Description = $Description

    # Bypass the 24-hour restore point creation limit, then create one as a
    # second safety net alongside the framework's own registry snapshot.
    $rpKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    try {
        if (Test-Path $rpKey) {
            Write-Log -Message "Bypassing Restore Point frequency limit..." -Level Debug
            Set-ItemProperty -Path $rpKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        }
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "$Name ($Description)" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log -Message "Restore point created successfully." -Level Success
    }
    catch {
        Write-Log -Message "Restore point creation failed (non-critical): $($_.Exception.Message)" -Level Warning
    }

    # 1. Capture services (filtered to the ones the framework may change)
    $servicesJsonPath = Join-Path $PSScriptRoot "..\..\config\services.json"
    $relevantServicePatterns = @('BITS', 'wuauserv', 'UsoSvc', 'Xbox*', 'Copilot', 'Connected*', 'DiagTrack', 'AIFabric*', 'dmwappushservice', 'WaaSMedicSvc')
    if (Test-Path $servicesJsonPath) {
        try {
            $servicesDb = Get-Content $servicesJsonPath -Raw | ConvertFrom-Json
            $relevantServicePatterns += $servicesDb.services.psobject.properties.Name
        }
        catch {
            Write-Verbose "Could not load services.json for snapshot filtering: $($_.Exception.Message)"
        }
    }

    $serviceFilter = {
        $svc = $_.Name
        $relevantServicePatterns | Where-Object { $svc -like $_ }
    }

    try {
        $snapshot.Services = @(
            Get-Service -ErrorAction SilentlyContinue | Where-Object $serviceFilter |
            Select-Object Name, Status, StartType, DisplayName
        )
        Write-Log -Message "Captured $($snapshot.Services.Count) relevant services" -Level Debug
    }
    catch {
        Write-Log -Message "Failed to capture services: $($_.Exception.Message)" -Level Warning
        $snapshot.Services = @()
    }

    # 2. Capture the full value-set of every registry target (true rollback)
    $snapshot.Registry = @{}
    $capturedKeys = 0
    $capturedValues = 0
    foreach ($regPath in $Script:RegistrySnapshotTargets) {
        $keyState = Get-WDRegistryKeyState -Path $regPath
        $snapshot.Registry[$regPath] = $keyState
        if ($keyState['Existed']) {
            $capturedKeys++
            $capturedValues += $keyState['RegValues'].Count
        }
    }
    Write-Log -Message "Captured $capturedValues values across $capturedKeys of $($Script:RegistrySnapshotTargets.Count) registry keys" -Level Debug

    # 3. Save to disk
    $snapshotDir = Get-WinDebloatSnapshotDirectory -Create
    $basePath = Join-Path $snapshotDir $snapshot.Id
    try {
        if ($PSCmdlet.ShouldProcess($basePath, "Create Snapshot")) {
            New-Item -Path $basePath -ItemType Directory -Force | Out-Null

            $cliXml = $snapshot | ConvertTo-CliXml

            if ($Encrypt) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($cliXml)
                $encrypted = Protect-WDData -Data $bytes
                [System.IO.File]::WriteAllBytes("$basePath\snapshot.encrypted", $encrypted)
                Write-Log -Message "Snapshot saved (encrypted): $($snapshot.Id)" -Level Success
            }
            else {
                $cliXml | Out-File -FilePath "$basePath\snapshot.clixml" -Encoding UTF8
                Write-Log -Message "Snapshot saved: $($snapshot.Id)" -Level Success
            }

            # Metadata sidecar so listings work fast and for encrypted snapshots too
            [ordered]@{
                Id          = $snapshot.Id
                Name        = $snapshot.Name
                Description = $snapshot.Description
                Timestamp   = $snapshot.Timestamp.ToString("o")
                Encrypted   = [bool]$Encrypt
                Version     = $snapshot.Version
            } | ConvertTo-Json | Set-Content -Path "$basePath\meta.json" -Encoding UTF8
        }
    }
    catch {
        Write-Log -Message "Failed to save snapshot: $($_.Exception.Message)" -Level Error
        throw
    }

    return $snapshot
}

<#
.SYNOPSIS
    Restores a previously created system snapshot (true value-level rollback).

.PARAMETER SnapshotId
    The unique ID of the snapshot to restore.

.OUTPUTS
    [void]
#>
function Restore-WinDebloatSnapshot {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SnapshotId
    )

    $clixmlPath = $null
    $encryptedPath = $null

    foreach ($searchDir in (Get-WinDebloatSnapshotSearchPaths)) {
        $candidateFolder = Join-Path $searchDir $SnapshotId
        if (Test-Path -LiteralPath $candidateFolder) {
            $candXml = Join-Path $candidateFolder "snapshot.clixml"
            $candEnc = Join-Path $candidateFolder "snapshot.encrypted"
            if (Test-Path -LiteralPath $candXml) {
                $clixmlPath = $candXml
                break
            }
            elseif (Test-Path -LiteralPath $candEnc) {
                $encryptedPath = $candEnc
                break
            }
        }
    }

    # Load snapshot (plain or DPAPI-encrypted)
    $snapshot = $null
    if ($clixmlPath -and (Test-Path -LiteralPath $clixmlPath)) {
        try {
            $rawContent = Get-Content -LiteralPath $clixmlPath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($rawContent)) {
                throw "Snapshot clixml file is empty."
            }
            $snapshot = $rawContent | ConvertFrom-CliXml -ErrorAction Stop
            if ($null -eq $snapshot) {
                throw "Failed to deserialize snapshot object."
            }
        }
        catch {
            Write-Log -Message "Failed to load snapshot: $($_.Exception.Message)" -Level Error
            throw "Snapshot ID not found or corrupted: $SnapshotId"
        }
    }
    elseif ($encryptedPath -and (Test-Path -LiteralPath $encryptedPath)) {
        try {
            $encrypted = [System.IO.File]::ReadAllBytes($encryptedPath)
            if ($null -eq $encrypted -or $encrypted.Length -eq 0) {
                throw "Encrypted snapshot file is empty."
            }
            $decrypted = Unprotect-WDData -EncryptedData $encrypted
            if ($null -eq $decrypted -or $decrypted.Length -eq 0) {
                throw "Decryption resulted in empty payload."
            }
            $clixml = [System.Text.Encoding]::UTF8.GetString($decrypted)
            $snapshot = $clixml | ConvertFrom-CliXml -ErrorAction Stop
            if ($null -eq $snapshot) {
                throw "Failed to deserialize decrypted snapshot object."
            }
        }
        catch {
            Write-Log -Message "Failed to decrypt snapshot: $($_.Exception.Message)" -Level Error
            throw "Snapshot decryption failed for: $SnapshotId"
        }
    }
    else {
        throw "Snapshot ID not found: $SnapshotId"
    }

    Write-Log -Message "Restoring Snapshot: $($snapshot.Name) ($($snapshot.Timestamp))" -Level Info

    $successCount = 0
    $failCount = 0

    # 1. Restore services
    foreach ($svc in $snapshot.Services) {
        try {
            $current = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($current -and $current.StartType -ne $svc.StartType) {
                if ($PSCmdlet.ShouldProcess($svc.Name, "Restore Service to $($svc.StartType)")) {
                    Write-Log -Message "Restoring Service: $($svc.Name) to $($svc.StartType)" -Level Info
                    Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction Stop
                    $successCount++
                }
            }
        }
        catch {
            Write-Log -Message "Failed to restore service $($svc.Name): $($_.Exception.Message)" -Level Warning
            $failCount++
        }
    }

    # 2. Restore registry (per-key logic lives in the testable Restore-WDRegistryKey)
    foreach ($regPath in $snapshot.Registry.Keys) {
        $r = Restore-WDRegistryKey -Path $regPath -SnapState $snapshot.Registry[$regPath]
        $successCount += $r.Success
        $failCount += $r.Fail
    }

    Write-Log -Message "Restore completed: $successCount change(s) applied, $failCount failed" -Level $(if ($failCount -eq 0) { "Success" } else { "Warning" })
}

<#
.SYNOPSIS
    Lists all available snapshots.

.OUTPUTS
    [SystemSnapshot[]] Array of snapshot objects.
#>
function Get-WinDebloatSnapshot {
    [CmdletBinding()]
    [OutputType([SystemSnapshot[]])]
    param()

    $searchPaths = Get-WinDebloatSnapshotSearchPaths
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $snapshots = [System.Collections.Generic.List[object]]::new()

    foreach ($basePath in $searchPaths) {
        if (-not (Test-Path -LiteralPath $basePath)) {
            continue
        }

        $dirs = Get-ChildItem -LiteralPath $basePath -Directory -ErrorAction SilentlyContinue
        foreach ($folder in $dirs) {
            if ($seenIds.Contains($folder.Name)) {
                continue
            }

            $clixmlPath = Join-Path $folder.FullName "snapshot.clixml"
            $encryptedPath = Join-Path $folder.FullName "snapshot.encrypted"
            $metaPath = Join-Path $folder.FullName "meta.json"
            $snapObj = $null

            # 1. Try unencrypted clixml
            if (Test-Path -LiteralPath $clixmlPath) {
                try {
                    $raw = Get-Content -LiteralPath $clixmlPath -Raw -ErrorAction Stop
                    if (-not [string]::IsNullOrWhiteSpace($raw)) {
                        $snapObj = $raw | ConvertFrom-CliXml -ErrorAction Stop
                    }
                }
                catch {
                    Write-Log -Message "Could not read snapshot clixml: $($folder.FullName)" -Level Debug
                }
            }

            # 2. Try metadata sidecar
            if ($null -eq $snapObj -and (Test-Path -LiteralPath $metaPath)) {
                try {
                    $metaRaw = Get-Content -LiteralPath $metaPath -Raw -ErrorAction Stop
                    if (-not [string]::IsNullOrWhiteSpace($metaRaw)) {
                        $meta = $metaRaw | ConvertFrom-Json -ErrorAction Stop
                        if ($meta.Id -and $meta.Timestamp) {
                            $snapObj = [PSCustomObject]@{
                                Id          = [string]$meta.Id
                                Name        = [string]$meta.Name
                                Description = [string]$meta.Description
                                Timestamp   = [datetime]$meta.Timestamp
                                Encrypted   = [bool]$meta.Encrypted
                                Version     = [string]$meta.Version
                            }
                        }
                    }
                }
                catch {
                    Write-Log -Message "Could not read snapshot metadata sidecar: $metaPath" -Level Debug
                }
            }

            # 3. Fallback for encrypted snapshot without valid metadata sidecar
            if ($null -eq $snapObj -and (Test-Path -LiteralPath $encryptedPath)) {
                $snapObj = [PSCustomObject]@{
                    Id          = $folder.Name
                    Name        = "(Encrypted)"
                    Description = ""
                    Timestamp   = $folder.CreationTime
                    Encrypted   = $true
                    Version     = "Unknown"
                }
            }

            # 4. Fallback for damaged snapshot folder
            if ($null -eq $snapObj -and ((Test-Path -LiteralPath $clixmlPath) -or (Test-Path -LiteralPath $metaPath))) {
                $snapObj = [PSCustomObject]@{
                    Id          = $folder.Name
                    Name        = "(Corrupted Snapshot)"
                    Description = "Snapshot files are damaged or unreadable"
                    Timestamp   = $folder.CreationTime
                    Encrypted   = $false
                    Version     = "Unknown"
                }
            }

            if ($null -ne $snapObj) {
                $snapId = if ($snapObj.Id) { $snapObj.Id } else { $folder.Name }
                [void]$seenIds.Add($snapId)
                $snapshots.Add($snapObj)
            }
        }
    }

    return $snapshots.ToArray()
}

# ── Backward-Compatibility Aliases ───────────────────────────────────
Set-Alias -Name New-WinDebloat7Snapshot -Value New-WinDebloatSnapshot
Set-Alias -Name Restore-WinDebloat7Snapshot -Value Restore-WinDebloatSnapshot
Set-Alias -Name Get-WinDebloat7Snapshot -Value Get-WinDebloatSnapshot
Set-Alias -Name Compare-WinDebloat7Snapshot -Value Compare-WinDebloatSnapshot
Set-Alias -Name Get-WinDebloat7RegistryTargets -Value Get-WinDebloatRegistryTargets

Set-Alias -Name Protect-WD7Data -Value Protect-WDData
Set-Alias -Name Protect-WinDebloatData -Value Protect-WDData
Set-Alias -Name Protect-WinDebloat7Data -Value Protect-WDData

Set-Alias -Name Unprotect-WD7Data -Value Unprotect-WDData
Set-Alias -Name Unprotect-WinDebloatData -Value Unprotect-WDData
Set-Alias -Name Unprotect-WinDebloat7Data -Value Unprotect-WDData

Set-Alias -Name Test-WD7RegistryValueEqual -Value Test-WDRegistryValueEqual
Set-Alias -Name Test-WinDebloatRegistryValueEqual -Value Test-WDRegistryValueEqual
Set-Alias -Name Test-WinDebloat7RegistryValueEqual -Value Test-WDRegistryValueEqual

Set-Alias -Name Get-WD7RegistryKeyState -Value Get-WDRegistryKeyState
Set-Alias -Name Get-WinDebloatRegistryKeyState -Value Get-WDRegistryKeyState
Set-Alias -Name Get-WinDebloat7RegistryKeyState -Value Get-WDRegistryKeyState

Set-Alias -Name Restore-WD7RegistryKey -Value Restore-WDRegistryKey
Set-Alias -Name Restore-WinDebloatRegistryKey -Value Restore-WDRegistryKey
Set-Alias -Name Restore-WinDebloat7RegistryKey -Value Restore-WDRegistryKey

Set-Alias -Name ConvertTo-WD7RegistryType -Value ConvertTo-WDRegistryType
Set-Alias -Name ConvertTo-WinDebloatRegistryType -Value ConvertTo-WDRegistryType

Set-Alias -Name Get-WD7RawRegistryKey -Value Get-WDRawRegistryKey
Set-Alias -Name Get-WinDebloatRawRegistryKey -Value Get-WDRawRegistryKey

Export-ModuleMember -Function New-WinDebloatSnapshot, Restore-WinDebloatSnapshot, Get-WinDebloatSnapshot, Compare-WinDebloatSnapshot, `
                              Get-WinDebloatRegistryTargets, Protect-WDData, Unprotect-WDData, Test-WDRegistryValueEqual, `
                              Restore-WDRegistryKey, Get-WDRegistryKeyState, ConvertTo-WDRegistryType, Get-WDRawRegistryKey, `
                              Get-WinDebloatSnapshotDirectory, Get-WinDebloatSnapshotSearchPaths `
                    -Alias New-WinDebloat7Snapshot, Restore-WinDebloat7Snapshot, Get-WinDebloat7Snapshot, Compare-WinDebloat7Snapshot, `
                           Get-WinDebloat7RegistryTargets, Protect-WD7Data, Protect-WinDebloatData, Protect-WinDebloat7Data, `
                           Unprotect-WD7Data, Unprotect-WinDebloatData, Unprotect-WinDebloat7Data, Test-WD7RegistryValueEqual, `
                           Test-WinDebloatRegistryValueEqual, Test-WinDebloat7RegistryValueEqual, Get-WD7RegistryKeyState, `
                           Get-WinDebloatRegistryKeyState, Get-WinDebloat7RegistryKeyState, Restore-WD7RegistryKey, `
                           Restore-WinDebloatRegistryKey, Restore-WinDebloat7RegistryKey, ConvertTo-WD7RegistryType, `
                           ConvertTo-WinDebloatRegistryType, Get-WD7RawRegistryKey, Get-WinDebloatRawRegistryKey
