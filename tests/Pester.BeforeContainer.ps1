#Requires -Version 7.6
<#
.SYNOPSIS
    Pester 6.2.0 Cascaded Container Setup for Win-Debloat Test Suite.
.DESCRIPTION
    Leverages Pester 6.2.0 folder-scoped Pester.BeforeContainer.ps1 architecture to provide
    clean runspace initialization and Windows Server command stub isolation before any test container executes.
#>

BeforeAll {
    # Ensure client-only external CLI tools and cmdlets exist as dynamic stubs for headless / Windows Server runners
    $serverStubs = @(
        'winget',
        'choco',
        'Add-AppxPackage',
        'Get-AppxPackage',
        'Remove-AppxPackage',
        'Get-AppxProvisionedPackage',
        'Remove-AppxProvisionedPackage',
        'Disable-NetAdapterUro',
        'Enable-NetAdapterUro',
        'Disable-NetAdapterLso',
        'Enable-NetAdapterLso'
    )

    foreach ($stubName in $serverStubs) {
        if (-not (Get-Command -Name $stubName -ErrorAction SilentlyContinue)) {
            Set-Item -Path "Function:\global:$stubName" -Value {
                [CmdletBinding()]
                param([Parameter(ValueFromRemainingArguments = $true)]$IgnoredArgs)
                return $null
            }
        }
    }
}
