$repair = "$PSScriptRoot/../../src/modules/Repair/Repair.psm1"
$features = "$PSScriptRoot/../../src/modules/Features/Features.psm1"
$security = "$PSScriptRoot/../../src/modules/Security/Security.psm1"

# Mock Logs
function Write-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Test mock')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Mock signature')]
    param($Message, $Level)
    $null = $Message; $null = $Level
}

Import-Module $repair -Force
Import-Module $features -Force
Import-Module $security -Force

# Stub missing cmdlets for test environment if needed
if (-not (Get-Command Set-MpPreference -ErrorAction SilentlyContinue)) { function global:Set-MpPreference { } }
if (-not (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { function global:Get-WindowsOptionalFeature { } }
if (-not (Get-Command Disable-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { function global:Disable-WindowsOptionalFeature { } }
if (-not (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { function global:Enable-WindowsOptionalFeature { } }

Describe "System Integration Tests" {
    
    Context "Repair Module" {
        It "Reset-WinDebloatNetwork and Reset-WinDebloat7Network should invoke netsh commands" {
            Mock -ModuleName Repair Start-Process { return $true }
            Reset-WinDebloatNetwork -Confirm:$false
            Should -Invoke -CommandName Start-Process -Times 5 -ModuleName Repair

            Reset-WinDebloat7Network -Confirm:$false
            Should -Invoke -CommandName Start-Process -Times 10 -ModuleName Repair
        }
    }
    
    Context "Features Module" {
        It "Set-WinDebloatOptionalFeatures and Set-WinDebloat7OptionalFeatures should disable features by default" {
            Mock -ModuleName Features Get-WindowsOptionalFeature { return [PSCustomObject]@{ State = "Enabled"; FeatureName = $FeatureName } }
            Mock -ModuleName Features Disable-WindowsOptionalFeature { }
            
            Set-WinDebloatOptionalFeatures -Features @("FaxServicesClientPackage") -Confirm:$false
            Should -Invoke -CommandName Disable-WindowsOptionalFeature -ModuleName Features -Times 1

            Set-WinDebloat7OptionalFeatures -Features @("FaxServicesClientPackage") -Confirm:$false
            Should -Invoke -CommandName Disable-WindowsOptionalFeature -ModuleName Features -Times 2
        }

        It "Set-WinDebloatOptionalFeatures -Enable should enable features" {
            Mock -ModuleName Features Get-WindowsOptionalFeature { return [PSCustomObject]@{ State = "Disabled"; FeatureName = $FeatureName } }
            Mock -ModuleName Features Enable-WindowsOptionalFeature { }
            
            Set-WinDebloatOptionalFeatures -Features @("FaxServicesClientPackage") -Enable -Confirm:$false
            Should -Invoke -CommandName Enable-WindowsOptionalFeature -ModuleName Features
        }
    }
    
    Context "Security Module" {
        It "Enable-WinDebloatPUAProtection and Enable-WinDebloat7PUAProtection should call Set-MpPreference" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-MpPreference { }
            
            Enable-WinDebloatPUAProtection -Confirm:$false
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 1

            Enable-WinDebloat7PUAProtection -Confirm:$false
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 2
        }
    }
}
