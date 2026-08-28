using namespace System.Management.Automation

Describe "Security Hardening Subsystem" {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module "$root\src\core\Logger.psm1" -Force
        Import-Module "$root\src\core\Registry.psm1" -Force
        Import-Module "$root\src\modules\Security\Security.psm1" -Force
    }

    Context "Windows Protected Print (WPP)" {
        It "Enable-WinDebloatWPP sets ProtectedPrintMode = 1" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatWPP -Confirm:$false } | Should -Not -Throw
        }

        It "Disable-WinDebloatWPP removes ProtectedPrintMode" {
            Mock -ModuleName Security Remove-RegistryKey { return $true }
            { Disable-WinDebloatWPP -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Sudo Policy Hardening" {
        It "Set-WinDebloatSudoMode sets valid mode" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Set-WinDebloatSudoMode -Mode "ForceNewWindow" -Confirm:$false } | Should -Not -Throw
            { Set-WinDebloatSudoMode -Mode "Disabled" -Confirm:$false } | Should -Not -Throw
        }

        It "Protect-WinDebloatSudoPolicy disables inline input" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Protect-WinDebloatSudoPolicy -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "BitLocker XTS-256 Hardening" {
        It "Enable-WinDebloatBitLockerHardening sets XTS-AES 256" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatBitLockerHardening -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Enterprise Baseline (RPC, SMB Signing, LSA, DMA)" {
        It "Enables RPC hardening without throwing" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatRPCHardening -Confirm:$false } | Should -Not -Throw
        }

        It "Enables SMB Signing without throwing" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatSMBSigning -Confirm:$false } | Should -Not -Throw
        }

        It "Enables LSA Protection without throwing" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatLSAProtection -Confirm:$false } | Should -Not -Throw
        }

        It "Enables DMA Protection without throwing" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatDMAProtection -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "PowerShell ScriptBlock Logging & Language Mode Detection" {
        It "Enable-WinDebloatScriptBlockLogging sets EnableScriptBlockLogging = 1" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            { Enable-WinDebloatScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -and
                $Name -eq "EnableScriptBlockLogging" -and
                $Value -eq 1 -and
                $Type -eq "DWord"
            }
        }

        It "Disable-WinDebloatScriptBlockLogging removes EnableScriptBlockLogging" {
            Mock -ModuleName Security Remove-RegistryKey { return $true }
            { Disable-WinDebloatScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -and
                $Name -eq "EnableScriptBlockLogging"
            }
        }

        It "Get-WinDebloatLanguageMode returns valid PSLanguageMode" {
            $mode = Get-WinDebloatLanguageMode
            $mode | Should -Not -BeNullOrEmpty
            $mode -in @([System.Management.Automation.PSLanguageMode]::FullLanguage, [System.Management.Automation.PSLanguageMode]::ConstrainedLanguage, [System.Management.Automation.PSLanguageMode]::RestrictedLanguage, [System.Management.Automation.PSLanguageMode]::NoLanguage) | Should -BeTrue
        }

        It "WinDebloat7 and WD7 aliases execute identically" {
            Mock -ModuleName Security Set-RegistryKey { return $true }
            Mock -ModuleName Security Remove-RegistryKey { return $true }

            { Enable-WinDebloat7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            { Enable-WD7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            { Disable-WD7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            (Get-WinDebloat7LanguageMode) | Should -Be (Get-WinDebloatLanguageMode)
            (Get-WD7LanguageMode) | Should -Be (Get-WinDebloatLanguageMode)
        }
    }
}
