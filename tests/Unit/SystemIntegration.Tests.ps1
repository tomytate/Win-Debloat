# Pester Integration Tests for Win-Debloat Modules
# Verifies cross-module interactions and functionality for Repair, Features, and Security modules.

Describe "System Integration Tests" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force
        Import-Module "$src\core\Registry.psm1" -Force
        Import-Module "$src\modules\Repair\Repair.psm1" -Force
        Import-Module "$src\modules\Features\Features.psm1" -Force
        Import-Module "$src\modules\Security\Security.psm1" -Force

        # Stub missing cmdlets for test environment if not present on current host/platform
        if (-not (Get-Command Set-MpPreference -ErrorAction SilentlyContinue)) { function global:Set-MpPreference { } }
        if (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) { function global:Get-MpPreference { } }
        if (-not (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { function global:Get-WindowsOptionalFeature { } }
        if (-not (Get-Command Disable-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { function global:Disable-WindowsOptionalFeature { } }
        if (-not (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue)) { function global:Enable-WindowsOptionalFeature { } }
        if (-not (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue)) { function global:Get-WindowsCapability { } }
        if (-not (Get-Command Remove-WindowsCapability -ErrorAction SilentlyContinue)) { function global:Remove-WindowsCapability { } }
    }

    BeforeEach {
        Mock -ModuleName Repair Write-Log { }
        Mock -ModuleName Features Write-Log { }
        Mock -ModuleName Security Write-Log { }
    }

    Context "Repair Module" {
        It "Reset-WinDebloatNetwork and Reset-WinDebloat7Network should invoke netsh commands" {
            Mock -ModuleName Repair Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }

            Reset-WinDebloatNetwork -Confirm:$false
            Should -Invoke -CommandName Start-Process -Times 5 -ModuleName Repair

            Reset-WinDebloat7Network -Confirm:$false
            Should -Invoke -CommandName Start-Process -Times 10 -ModuleName Repair
        }

        It "Repair-WinDebloatSystem and Repair-WinDebloat7System should invoke 4-step repair sequence" {
            Mock -ModuleName Repair Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }

            Repair-WinDebloatSystem -Confirm:$false
            Should -Invoke -CommandName Start-Process -Times 4 -ModuleName Repair

            Repair-WinDebloat7System -Confirm:$false
            Should -Invoke -CommandName Start-Process -Times 8 -ModuleName Repair
        }
    }
    
    Context "Features Module" {
        It "Set-WinDebloatOptionalFeatures and Set-WinDebloat7OptionalFeatures should disable features by default" {
            Mock -ModuleName Features Get-WindowsOptionalFeature { return [PSCustomObject]@{ State = "Enabled"; FeatureName = $FeatureName } }
            Mock -ModuleName Features Disable-WindowsOptionalFeature { return [PSCustomObject]@{ RestartNeeded = $false } }
            
            Set-WinDebloatOptionalFeatures -Features @("FaxServicesClientPackage") -Confirm:$false
            Should -Invoke -CommandName Disable-WindowsOptionalFeature -ModuleName Features -Times 1

            Set-WinDebloat7OptionalFeatures -Features @("FaxServicesClientPackage") -Confirm:$false
            Should -Invoke -CommandName Disable-WindowsOptionalFeature -ModuleName Features -Times 2
        }

        It "Set-WinDebloatOptionalFeatures -Enable should enable features" {
            Mock -ModuleName Features Get-WindowsOptionalFeature { return [PSCustomObject]@{ State = "Disabled"; FeatureName = $FeatureName } }
            Mock -ModuleName Features Enable-WindowsOptionalFeature { return [PSCustomObject]@{ RestartNeeded = $false } }
            
            Set-WinDebloatOptionalFeatures -Features @("FaxServicesClientPackage") -Enable -Confirm:$false
            Should -Invoke -CommandName Enable-WindowsOptionalFeature -ModuleName Features -Times 1
        }

        It "Remove-WinDebloatCapabilities and Remove-WinDebloat7Capabilities should remove matching capabilities" {
            Mock -ModuleName Features Get-WindowsCapability {
                return @(
                    [PSCustomObject]@{ Name = "MathRecognizer~~~~0.0.1.0"; State = "Installed" }
                    [PSCustomObject]@{ Name = "Microsoft.Windows.WordPad~~~~0.0.1.0"; State = "Installed" }
                )
            }
            Mock -ModuleName Features Remove-WindowsCapability { return [PSCustomObject]@{ RestartNeeded = $false } }

            Remove-WinDebloatCapabilities -Capabilities @("MathRecognizer*") -Confirm:$false
            Should -Invoke -CommandName Remove-WindowsCapability -ModuleName Features -Times 1

            Remove-WinDebloat7Capabilities -Capabilities @("MathRecognizer*") -Confirm:$false
            Should -Invoke -CommandName Remove-WindowsCapability -ModuleName Features -Times 2
        }
    }
    
    Context "Security Module" {
        It "Enable-WinDebloatPUAProtection and Enable-WinDebloat7PUAProtection should call Set-MpPreference" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-MpPreference { }
            Mock -ModuleName Security Set-RegistryKey { return $true }
            
            Enable-WinDebloatPUAProtection -Confirm:$false
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 1

            Enable-WinDebloat7PUAProtection -Confirm:$false
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 2
        }

        It "Disable-WinDebloatPUAProtection and Disable-WinDebloat7PUAProtection should call Set-MpPreference" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-MpPreference { }
            Mock -ModuleName Security Remove-RegistryKey { return $true }

            Disable-WinDebloatPUAProtection -Confirm:$false
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 1

            Disable-WinDebloat7PUAProtection -Confirm:$false
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 2
        }
    }
}
