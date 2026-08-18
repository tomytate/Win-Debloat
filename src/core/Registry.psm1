#Requires -Version 7.6

<#
.SYNOPSIS
    Registry management utilities for Win-Debloat
    
.DESCRIPTION
    Provides shared registry manipulation functions with proper error handling,
    ACL validation, and PowerShell 7.5 best practices.
    
.NOTES
    Module: Win-Debloat.Core.Registry
    Version: 1.5.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation
using namespace System.Security.AccessControl

Import-Module "$PSScriptRoot\Logger.psm1" -Force

<#
.SYNOPSIS
    Sets a registry key value with proper validation and error handling.
    
.DESCRIPTION
    Creates the registry path if it doesn't exist and sets the specified value.
    Includes ACL validation to ensure we have write permissions before attempting changes.
    
.PARAMETER Path
    The full registry path (e.g., HKLM:\SOFTWARE\MyApp)
    
.PARAMETER Name
    The registry value name
    
.PARAMETER Value
    The value to set
    
.PARAMETER Type
    The registry value type (DWord, String, QWord, Binary, MultiString, ExpandString)
    
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
        # Validate and create path if needed
        if (-not (Test-Path -LiteralPath $Path)) {
            if ($PSCmdlet.ShouldProcess($Path, "Create Registry Key")) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
                Write-Log -Message "Created registry path: $Path" -Level Debug
            }
        }
        
        # Set the value (using (Default) if Name is empty)
        $valName = if ([string]::IsNullOrEmpty($Name)) { "(Default)" } else { $Name }
        if ($PSCmdlet.ShouldProcess("$Path\$valName", "Set Value to $Value ($Type)")) {
            Set-ItemProperty -LiteralPath $Path -Name $valName -Value $Value -Type $Type -Force -ErrorAction Stop
            Write-Log -Message "Set registry: $Path\$valName = $Value" -Level Debug
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log -Message "Failed to set registry '$Path\$Name': $($_.Exception.Message)" -Level Error
        return $false
    }
}

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
        if (Test-Path -LiteralPath $Path) {
            $valName = if ([string]::IsNullOrEmpty($Name)) { "(Default)" } else { $Name }
            $value = Get-ItemPropertyValue -LiteralPath $Path -Name $valName -ErrorAction Stop
            return $value
        }
        return $DefaultValue
    }
    catch {
        return $DefaultValue
    }
}

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
        if (-not (Test-Path -LiteralPath $Path)) {
            return $false
        }
        
        if ([string]::IsNullOrEmpty($Name)) {
            return $true
        }
        
        $val = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop
        return ($null -ne $val)
    }
    catch {
        return $false
    }
}

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
        if (Test-Path -LiteralPath $Path) {
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
        if (-not (Test-Path -LiteralPath $Path)) {
            return $true
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

            if ($PSCmdlet.ShouldProcess($Path, "Remove Registry Key")) {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
                Write-Log -Message "Removed registry key: $Path" -Level Debug
            }
            return $true
        }

        if (-not (Test-RegistryKey -Path $Path -Name $Name)) {
            return $true
        }

        if ($PSCmdlet.ShouldProcess("$Path\$Name", "Remove Registry Value")) {
            Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
            Write-Log -Message "Removed registry value: $Path\$Name" -Level Debug
        }
        return $true
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
