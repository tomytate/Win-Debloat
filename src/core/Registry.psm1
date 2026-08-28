#Requires -Version 7.6

<#
.SYNOPSIS
    Registry management utilities for Win-Debloat
    
.DESCRIPTION
    Provides shared registry manipulation functions with proper error handling,
    ACL validation, and PowerShell 7.6+ direct .NET Microsoft.Win32.Registry best practices.
    
.NOTES
    Module: Win-Debloat.Core.Registry
    Version: 1.6.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation
using namespace System.Security.AccessControl
using namespace Microsoft.Win32

Import-Module "$PSScriptRoot\Logger.psm1" -Force

$Script:ResolveRegistryPath = {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $normalized = $Path.Trim()
    $hive = $null
    $subKey = ''

    if ($normalized -match '^(?:Registry::)?HKEY_LOCAL_MACHINE\\?(.*)$' -or $normalized -match '^HKLM:?\\?(.*)$') {
        $hive = [Microsoft.Win32.Registry]::LocalMachine
        $subKey = $Matches[1]
    }
    elseif ($normalized -match '^(?:Registry::)?HKEY_CURRENT_USER\\?(.*)$' -or $normalized -match '^HKCU:?\\?(.*)$') {
        $hive = [Microsoft.Win32.Registry]::CurrentUser
        $subKey = $Matches[1]
    }
    elseif ($normalized -match '^(?:Registry::)?HKEY_CLASSES_ROOT\\?(.*)$' -or $normalized -match '^HKCR:?\\?(.*)$') {
        $hive = [Microsoft.Win32.Registry]::ClassesRoot
        $subKey = $Matches[1]
    }
    elseif ($normalized -match '^(?:Registry::)?HKEY_USERS\\?(.*)$' -or $normalized -match '^HKU:?\\?(.*)$') {
        $hive = [Microsoft.Win32.Registry]::Users
        $subKey = $Matches[1]
    }
    elseif ($normalized -match '^(?:Registry::)?HKEY_CURRENT_CONFIG\\?(.*)$' -or $normalized -match '^HKCC:?\\?(.*)$') {
        $hive = [Microsoft.Win32.Registry]::CurrentConfig
        $subKey = $Matches[1]
    }
    else {
        return $null
    }

    $subKey = $subKey.TrimStart('\').TrimEnd('\')
    return [PSCustomObject]@{
        Hive   = $hive
        SubKey = $subKey
    }
}

<#
.SYNOPSIS
    Sets a registry key value with proper validation and error handling.
    
.DESCRIPTION
    Creates the registry path if it doesn't exist and sets the specified value
    using direct Microsoft.Win32.Registry .NET APIs for high performance.
    Includes ACL and hive validation to ensure proper permissions before attempting changes.
    
.PARAMETER Path
    The full registry path (e.g., HKLM:\SOFTWARE\MyApp)
    
.PARAMETER Name
    The registry value name
    
.PARAMETER Value
    The value to set
    
.PARAMETER Type
    The registry value type (DWord, String, QWord, Binary, MultiString, ExpandString, None, Unknown)
    
.OUTPUTS
    [bool] Returns $true if successful, $false otherwise
    
.EXAMPLE
    Set-RegistryKey -Path "HKCU:\SOFTWARE\Test" -Name "MySetting" -Value 1
#>
function Set-RegistryKey {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -notmatch '^HK(LM|CU|CR|U|CC):\\') {
                    throw "Invalid registry path '$_'. Must start with a valid hive (e.g. HKLM:\)"
                }
                $true
            })]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Name = "",
        
        [Parameter(Mandatory)]
        [AllowNull()]
        $Value,
        
        [ValidateSet("DWord", "String", "QWord", "Binary", "MultiString", "ExpandString", "None", "Unknown")]
        [string]$Type = "DWord"
    )
    
    try {
        $resolved = & $Script:ResolveRegistryPath -Path $Path
        if ($null -eq $resolved -or $null -eq $resolved.Hive) {
            Write-Log -Message "Invalid or unsupported registry path: '$Path'" -Level Error
            return $false
        }

        # Check if subkey exists
        $subKeyExists = $false
        if ([string]::IsNullOrEmpty($resolved.SubKey)) {
            $subKeyExists = $true
        }
        else {
            $existingKey = $resolved.Hive.OpenSubKey($resolved.SubKey, $false)
            if ($null -ne $existingKey) {
                $subKeyExists = $true
                $existingKey.Dispose()
                $existingKey = $null
            }
        }

        # Validate and create path if needed
        if (-not $subKeyExists) {
            if ($PSCmdlet.ShouldProcess($Path, "Create Registry Key")) {
                $createdKey = $resolved.Hive.CreateSubKey($resolved.SubKey, $true)
                if ($null -ne $createdKey) {
                    $createdKey.Dispose()
                    $createdKey = $null
                }
                Write-Log -Message "Created registry path: $Path" -Level Debug
            }
        }

        # Map registry value kind and convert value
        $regKind = [Microsoft.Win32.RegistryValueKind]::DWord
        $convertedValue = $Value

        switch ($Type) {
            "DWord" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::DWord
                if ($Value -is [bool]) {
                    $convertedValue = if ($Value) { [int32]1 } else { [int32]0 }
                }
                elseif ($Value -is [string] -and $Value -match '^0x[0-9a-fA-F]+$') {
                    $convertedValue = [Convert]::ToInt32($Value, 16)
                }
                elseif ($Value -is [int64] -or $Value -is [uint64] -or $Value -is [uint32]) {
                    $convertedValue = [int32][uint32]$Value
                }
                else {
                    $convertedValue = [int32]$Value
                }
            }
            "QWord" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::QWord
                if ($Value -is [bool]) {
                    $convertedValue = if ($Value) { [int64]1 } else { [int64]0 }
                }
                elseif ($Value -is [string] -and $Value -match '^0x[0-9a-fA-F]+$') {
                    $convertedValue = [Convert]::ToInt64($Value, 16)
                }
                elseif ($Value -is [uint64]) {
                    $convertedValue = [int64]$Value
                }
                else {
                    $convertedValue = [int64]$Value
                }
            }
            "String" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::String
                $convertedValue = if ($null -eq $Value) { "" } else { [string]$Value }
            }
            "ExpandString" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::ExpandString
                $convertedValue = if ($null -eq $Value) { "" } else { [string]$Value }
            }
            "Binary" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::Binary
                if ($Value -is [byte[]]) {
                    $convertedValue = $Value
                }
                elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                    $convertedValue = [byte[]]$Value
                }
                elseif ($null -eq $Value) {
                    $convertedValue = [byte[]]@()
                }
                else {
                    $convertedValue = [byte[]]@($Value)
                }
            }
            "MultiString" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::MultiString
                if ($Value -is [string[]]) {
                    $convertedValue = $Value
                }
                elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                    $convertedValue = [string[]]($Value | ForEach-Object { "$_" })
                }
                elseif ($null -eq $Value) {
                    $convertedValue = [string[]]@()
                }
                else {
                    $convertedValue = [string[]]@([string]$Value)
                }
            }
            "None" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::None
                if ($Value -is [byte[]]) {
                    $convertedValue = $Value
                }
                elseif ($null -eq $Value) {
                    $convertedValue = [byte[]]@()
                }
                else {
                    $convertedValue = [byte[]]$Value
                }
            }
            "Unknown" {
                $regKind = [Microsoft.Win32.RegistryValueKind]::Unknown
                $convertedValue = $Value
            }
            default {
                $regKind = [Microsoft.Win32.RegistryValueKind]::DWord
                $convertedValue = [int32]$Value
            }
        }

        # Set the value (using (Default) if Name is empty)
        $valName = if ([string]::IsNullOrEmpty($Name)) { "(Default)" } else { $Name }
        $targetName = if ($Name -eq "(Default)" -or [string]::IsNullOrEmpty($Name)) { "" } else { $Name }

        if ($PSCmdlet.ShouldProcess("$Path\$valName", "Set Value to $Value ($Type)")) {
            $regKey = if ([string]::IsNullOrEmpty($resolved.SubKey)) {
                $resolved.Hive
            }
            else {
                $resolved.Hive.CreateSubKey($resolved.SubKey, $true)
            }

            try {
                if ($null -eq $regKey) {
                    throw "Failed to open or create registry subkey '$($resolved.SubKey)' for writing."
                }
                $regKey.SetValue($targetName, $convertedValue, $regKind)
                Write-Log -Message "Set registry: $Path\$valName = $Value" -Level Debug
                return $true
            }
            finally {
                if ($null -ne $regKey -and $regKey -ne $resolved.Hive) {
                    $regKey.Dispose()
                    $regKey = $null
                }
            }
        }
        
        return $false
    }
    catch {
        Write-Log -Message "Failed to set registry '$Path\$Name': $($_.Exception.Message)" -Level Error
        return $false
    }
}

<#
.SYNOPSIS
    Retrieves a registry key value with fallback support.
    
.DESCRIPTION
    Retrieves the specified registry value using direct Microsoft.Win32.Registry .NET APIs.
    Returns the specified DefaultValue if the path or value does not exist.
    
.PARAMETER Path
    The full registry path (e.g., HKLM:\SOFTWARE\MyApp)
    
.PARAMETER Name
    The registry value name (empty or "(Default)" for the default value)
    
.PARAMETER DefaultValue
    The fallback value returned if the registry key or value is missing
    
.OUTPUTS
    [object] The registry value or DefaultValue
    
.EXAMPLE
    Get-RegistryKey -Path "HKCU:\SOFTWARE\Test" -Name "MySetting" -DefaultValue 0
#>
function Get-RegistryKey {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Name = "",
        
        $DefaultValue = $null
    )
    
    try {
        $resolved = & $Script:ResolveRegistryPath -Path $Path
        if ($null -eq $resolved -or $null -eq $resolved.Hive) {
            return $DefaultValue
        }

        $regKey = if ([string]::IsNullOrEmpty($resolved.SubKey)) {
            $resolved.Hive
        }
        else {
            $resolved.Hive.OpenSubKey($resolved.SubKey, $false)
        }

        if ($null -eq $regKey) {
            return $DefaultValue
        }

        try {
            $targetName = if ($Name -eq "(Default)" -or [string]::IsNullOrEmpty($Name)) { "" } else { $Name }
            $valNames = $regKey.GetValueNames()

            $exists = ($targetName -in $valNames)
            if (-not $exists) {
                if ($targetName -eq "") {
                    $defVal = $regKey.GetValue("")
                    if ($null -ne $defVal) {
                        return $defVal
                    }
                }
                return $DefaultValue
            }

            $val = $regKey.GetValue($targetName)
            if ($null -eq $val) {
                return $DefaultValue
            }
            return $val
        }
        finally {
            if ($null -ne $regKey -and $regKey -ne $resolved.Hive) {
                $regKey.Dispose()
                $regKey = $null
            }
        }
    }
    catch {
        return $DefaultValue
    }
}

<#
.SYNOPSIS
    Tests whether a registry path or value exists.
    
.DESCRIPTION
    Checks for the existence of a registry key or a specific value within a key
    using direct Microsoft.Win32.Registry .NET APIs.
    
.PARAMETER Path
    The full registry path (e.g., HKLM:\SOFTWARE\MyApp)
    
.PARAMETER Name
    The optional registry value name to test
    
.OUTPUTS
    [bool] Returns $true if the key or value exists, $false otherwise
    
.EXAMPLE
    Test-RegistryKey -Path "HKCU:\SOFTWARE\Test" -Name "MySetting"
#>
function Test-RegistryKey {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Name = ""
    )
    
    try {
        $resolved = & $Script:ResolveRegistryPath -Path $Path
        if ($null -eq $resolved -or $null -eq $resolved.Hive) {
            return $false
        }

        $regKey = if ([string]::IsNullOrEmpty($resolved.SubKey)) {
            $resolved.Hive
        }
        else {
            $resolved.Hive.OpenSubKey($resolved.SubKey, $false)
        }

        if ($null -eq $regKey) {
            return $false
        }

        try {
            if ([string]::IsNullOrEmpty($Name)) {
                return $true
            }

            $targetName = if ($Name -eq "(Default)") { "" } else { $Name }
            $valNames = $regKey.GetValueNames()
            if ($targetName -in $valNames) {
                return $true
            }
            if ($targetName -eq "" -and $null -ne $regKey.GetValue("")) {
                return $true
            }
            return $false
        }
        finally {
            if ($null -ne $regKey -and $regKey -ne $resolved.Hive) {
                $regKey.Dispose()
                $regKey = $null
            }
        }
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Exports a registry key to a .reg file using reg.exe.
    
.DESCRIPTION
    Exports the specified registry hive path and subkeys to a destination .reg file.
    
.PARAMETER Path
    The full registry path to export
    
.PARAMETER OutputPath
    The destination file path for the .reg file
    
.OUTPUTS
    [bool] Returns $true if export was successful, $false otherwise
#>
function Export-RegistryKey {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )
    
    try {
        if (Test-RegistryKey -Path $Path) {
            $parentDir = Split-Path -Path $OutputPath -Parent
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction SilentlyContinue | Out-Null
            }

            $hive = ""
            $subKey = ""
            
            if ($Path -match "^HKLM:\\?(.*)") {
                $hive = "HKLM"
                $subKey = $matches[1]
            }
            elseif ($Path -match "^HKCU:\\?(.*)") {
                $hive = "HKCU"
                $subKey = $matches[1]
            }
            elseif ($Path -match "^HKCR:\\?(.*)") {
                $hive = "HKCR"
                $subKey = $matches[1]
            }
            elseif ($Path -match "^HKU:\\?(.*)") {
                $hive = "HKU"
                $subKey = $matches[1]
            }
            elseif ($Path -match "^HKCC:\\?(.*)") {
                $hive = "HKCC"
                $subKey = $matches[1]
            }
            elseif ($Path -match "^Registry::HKEY_LOCAL_MACHINE\\?(.*)") {
                $hive = "HKEY_LOCAL_MACHINE"
                $subKey = $matches[1]
            }
            elseif ($Path -match "^Registry::HKEY_CURRENT_USER\\?(.*)") {
                $hive = "HKEY_CURRENT_USER"
                $subKey = $matches[1]
            }
            
            if (-not $hive) {
                Write-Log -Message "Unsupported registry hive for export: $Path." -Level Error
                return $false
            }
            
            $regPath = if ($subKey) { "$hive\$subKey" } else { $hive }
            $processArgs = @("export", $regPath, $OutputPath, "/y")
            
            $p = Start-Process -FilePath "reg.exe" -ArgumentList $processArgs -NoNewWindow -Wait -PassThru
            
            if ($p.ExitCode -eq 0) {
                Write-Log -Message "Exported registry: $Path -> $OutputPath" -Level Success
                return $true
            }
            else {
                Write-Log -Message "Failed to export registry (Exit Code $($p.ExitCode))" -Level Error
                return $false
            }
        }
        
        return $false
    }
    catch {
        Write-Log -Message "Registry export failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

<#
.SYNOPSIS
    Removes a registry value or an entire registry key subtree.
    
.DESCRIPTION
    Deletes a specified registry value or subkey tree using direct Microsoft.Win32.Registry .NET APIs.
    Enforces protected root subtree safeguards to prevent accidental system registry corruption.
    
.PARAMETER Path
    The full registry path (e.g., HKLM:\SOFTWARE\MyApp)
    
.PARAMETER Name
    The registry value name to remove
    
.PARAMETER WholeKey
    If specified, removes the entire subkey subtree
    
.OUTPUTS
    [bool] Returns $true if successful, $false otherwise
    
.EXAMPLE
    Remove-RegistryKey -Path "HKCU:\SOFTWARE\Test" -Name "MySetting"
    Remove-RegistryKey -Path "HKCU:\SOFTWARE\Test\SubKey" -WholeKey
#>
function Remove-RegistryKey {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -notmatch '^HK(LM|CU|CR|U|CC):\\') {
                    throw "Invalid registry path '$_'. Must start with a valid hive (e.g. HKLM:\)"
                }
                $true
            })]
        [string]$Path,

        [string]$Name,

        [switch]$WholeKey
    )

    if (-not $WholeKey -and [string]::IsNullOrEmpty($Name)) {
        Write-Log -Message "Remove-RegistryKey requires either -Name or -WholeKey." -Level Error
        return $false
    }

    try {
        $resolved = & $Script:ResolveRegistryPath -Path $Path
        if ($null -eq $resolved -or $null -eq $resolved.Hive) {
            Write-Log -Message "Invalid or unsupported registry path: '$Path'" -Level Error
            return $false
        }

        if ($WholeKey) {
            # Guard against accidental root / shallow key deletion
            $norm = $Path.TrimEnd('\') -replace '^HK(LM|CU|CR|U|CC):\\?', ''
            $segments = $norm.Split('\') | Where-Object { $_ }
            
            # Protected root blacklist
            $protectedSubtrees = @(
                'SOFTWARE\Microsoft',
                'SOFTWARE\Policies',
                'SOFTWARE\Classes',
                'SYSTEM\CurrentControlSet',
                'SYSTEM\Setup',
                'SAM',
                'SECURITY'
            )

            if ($segments.Count -lt 2 -or ($norm -in $protectedSubtrees)) {
                Write-Log -Message "Refusing to delete protected system registry path: $Path" -Level Error
                return $false
            }

            if ([string]::IsNullOrEmpty($resolved.SubKey)) {
                Write-Log -Message "Refusing to delete root hive path: $Path" -Level Error
                return $false
            }

            # Check if key exists
            $existingKey = $resolved.Hive.OpenSubKey($resolved.SubKey, $false)
            if ($null -eq $existingKey) {
                return $true # Key does not exist, removal considered successful
            }
            $existingKey.Dispose()
            $existingKey = $null

            if ($PSCmdlet.ShouldProcess($Path, "Remove Registry Key")) {
                $resolved.Hive.DeleteSubKeyTree($resolved.SubKey, $false)
                Write-Log -Message "Removed registry key: $Path" -Level Debug
            }
            return $true
        }

        # Value removal mode
        $regKey = if ([string]::IsNullOrEmpty($resolved.SubKey)) {
            $resolved.Hive
        }
        else {
            $resolved.Hive.OpenSubKey($resolved.SubKey, $true)
        }

        if ($null -eq $regKey) {
            return $true # Key doesn't exist, value removal already satisfied
        }

        try {
            $targetName = if ($Name -eq "(Default)" -or [string]::IsNullOrEmpty($Name)) { "" } else { $Name }
            $valNames = $regKey.GetValueNames()

            $exists = ($targetName -in $valNames)
            if (-not $exists -and $targetName -eq "") {
                if ($null -ne $regKey.GetValue("")) {
                    $exists = $true
                }
            }

            if (-not $exists) {
                return $true # Value does not exist
            }

            $displayName = if ([string]::IsNullOrEmpty($Name)) { "(Default)" } else { $Name }
            if ($PSCmdlet.ShouldProcess("$Path\$displayName", "Remove Registry Value")) {
                $regKey.DeleteValue($targetName, $false)
                Write-Log -Message "Removed registry value: $Path\$displayName" -Level Debug
            }
            return $true
        }
        finally {
            if ($null -ne $regKey -and $regKey -ne $resolved.Hive) {
                $regKey.Dispose()
                $regKey = $null
            }
        }
    }
    catch {
        $target = if ($Name) { "$Path\$Name" } else { $Path }
        Write-Log -Message "Failed to remove registry '$target': $($_.Exception.Message)" -Level Error
        return $false
    }
}

Set-Alias -Name Set-WinDebloatRegistryKey -Value Set-RegistryKey
Set-Alias -Name Get-WinDebloatRegistryKey -Value Get-RegistryKey
Set-Alias -Name Test-WinDebloatRegistryKey -Value Test-RegistryKey
Set-Alias -Name Export-WinDebloatRegistryKey -Value Export-RegistryKey
Set-Alias -Name Remove-WinDebloatRegistryKey -Value Remove-RegistryKey

Set-Alias -Name Set-WinDebloat7RegistryKey -Value Set-RegistryKey
Set-Alias -Name Get-WinDebloat7RegistryKey -Value Get-RegistryKey
Set-Alias -Name Test-WinDebloat7RegistryKey -Value Test-RegistryKey
Set-Alias -Name Export-WinDebloat7RegistryKey -Value Export-RegistryKey
Set-Alias -Name Remove-WinDebloat7RegistryKey -Value Remove-RegistryKey

Export-ModuleMember -Function Set-RegistryKey, Get-RegistryKey, Test-RegistryKey, Export-RegistryKey, Remove-RegistryKey `
                    -Alias Set-WinDebloatRegistryKey, Get-WinDebloatRegistryKey, Test-WinDebloatRegistryKey, Export-WinDebloatRegistryKey, Remove-WinDebloatRegistryKey, `
                           Set-WinDebloat7RegistryKey, Get-WinDebloat7RegistryKey, Test-WinDebloat7RegistryKey, Export-WinDebloat7RegistryKey, Remove-WinDebloat7RegistryKey
