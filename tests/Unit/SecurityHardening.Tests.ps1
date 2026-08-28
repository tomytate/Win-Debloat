using namespace System.Management.Automation

Describe "Security Hardening Subsystem" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force
        Import-Module "$src\core\Registry.psm1" -Force
        Import-Module "$src\modules\Security\Security.psm1" -Force

        # Stub missing cmdlets for test environment if needed
        if (-not (Get-Command Set-MpPreference -ErrorAction SilentlyContinue)) { function global:Set-MpPreference { } }
        if (-not (Get-Command Get-MpPreference -ErrorAction SilentlyContinue)) { function global:Get-MpPreference { } }
        if (-not (Get-Command Set-SmbServerConfiguration -ErrorAction SilentlyContinue)) { function global:Set-SmbServerConfiguration { } }
        if (-not (Get-Command Get-SmbServerConfiguration -ErrorAction SilentlyContinue)) { function global:Get-SmbServerConfiguration { } }
    }

    BeforeEach {
        Mock -ModuleName Security Write-Log { }
        Mock -ModuleName Security Set-RegistryKey { return $true }
        Mock -ModuleName Security Remove-RegistryKey { return $true }
        Mock -ModuleName Security Get-RegistryKey { return $null }
    }

    Context "Protocol Hardening (SMBv1)" {
        It "Disable-WinDebloatSMBv1 disables protocol via cmdlet when available" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-SmbServerConfiguration { }

            { Disable-WinDebloatSMBv1 -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-SmbServerConfiguration -ModuleName Security -Times 1 -ParameterFilter {
                $EnableSMB1Protocol -eq $false
            }
        }

        It "Disable-WinDebloatSMBv1 falls back to registry when cmdlet unavailable" {
            Mock -ModuleName Security Get-Command { return $false }

            { Disable-WinDebloatSMBv1 -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -and
                $Name -eq "SMB1" -and
                $Value -eq 0 -and
                $Type -eq "DWord"
            }
        }

        It "Enable-WinDebloatSMBv1 enables protocol via cmdlet when available" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-SmbServerConfiguration { }

            { Enable-WinDebloatSMBv1 -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-SmbServerConfiguration -ModuleName Security -Times 1 -ParameterFilter {
                $EnableSMB1Protocol -eq $true
            }
        }

        It "Enable-WinDebloatSMBv1 falls back to registry when cmdlet unavailable" {
            Mock -ModuleName Security Get-Command { return $false }

            { Enable-WinDebloatSMBv1 -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -and
                $Name -eq "SMB1" -and
                $Value -eq 1 -and
                $Type -eq "DWord"
            }
        }
    }

    Context "Defender Hardening (PUA Protection)" {
        It "Enable-WinDebloatPUAProtection enables PUA via cmdlet when available" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-MpPreference { }

            { Enable-WinDebloatPUAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 1 -ParameterFilter {
                $PUAProtection -eq "Enabled"
            }
        }

        It "Enable-WinDebloatPUAProtection falls back to registry when cmdlet unavailable" {
            Mock -ModuleName Security Get-Command { return $false }

            { Enable-WinDebloatPUAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -and
                $Name -eq "MpEnablePua" -and
                $Value -eq 1
            }
        }

        It "Disable-WinDebloatPUAProtection disables PUA via cmdlet when available" {
            Mock -ModuleName Security Get-Command { return $true }
            Mock -ModuleName Security Set-MpPreference { }

            { Disable-WinDebloatPUAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-MpPreference -ModuleName Security -Times 1 -ParameterFilter {
                $PUAProtection -eq "Disabled"
            }
        }

        It "Disable-WinDebloatPUAProtection falls back to registry removal when cmdlet unavailable" {
            Mock -ModuleName Security Get-Command { return $false }

            { Disable-WinDebloatPUAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -and
                $Name -eq "MpEnablePua"
            }
        }
    }

    Context "Windows Protected Print (WPP)" {
        It "Enable-WinDebloatWPP sets ProtectedPrintMode = 1" {
            { Enable-WinDebloatWPP -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ProtectedPrint" -and
                $Name -eq "ProtectedPrintMode" -and
                $Value -eq 1 -and
                $Type -eq "DWord"
            }
        }

        It "Disable-WinDebloatWPP removes ProtectedPrintMode" {
            { Disable-WinDebloatWPP -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\ProtectedPrint" -and
                $Name -eq "ProtectedPrintMode"
            }
        }

        It "Test-WinDebloatPrinterIPPCompliance returns boolean without throwing" {
            $res = Test-WinDebloatPrinterIPPCompliance -PrinterHost "127.0.0.1" -Port 65534 -TimeoutMs 100
            $res | Should -BeOfType [bool]
        }
    }

    Context "Sudo Policy Hardening" {
        It "Set-WinDebloatSudoMode sets valid mode" {
            { Set-WinDebloatSudoMode -Mode "ForceNewWindow" -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 2 -ParameterFilter {
                $Name -eq "Enabled" -and $Value -eq 1 -and $Type -eq "DWord"
            }

            { Set-WinDebloatSudoMode -Mode "Disabled" -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 2 -ParameterFilter {
                $Name -eq "Enabled" -and $Value -eq 0 -and $Type -eq "DWord"
            }
        }

        It "Protect-WinDebloatSudoPolicy disables inline input" {
            { Protect-WinDebloatSudoPolicy -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 2 -ParameterFilter {
                $Name -eq "Enabled" -and $Value -eq 2 -and $Type -eq "DWord"
            }
        }
    }

    Context "BitLocker XTS-256 Hardening" {
        It "Enable-WinDebloatBitLockerHardening sets XTS-AES 256" {
            { Enable-WinDebloatBitLockerHardening -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 7
        }

        It "Disable-WinDebloatBitLockerHardening removes FVE policy overrides" {
            { Disable-WinDebloatBitLockerHardening -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 7
        }
    }

    Context "Enterprise Baseline (RPC, SMB Signing, LSA, DMA)" {
        It "Enables and disables RPC hardening without throwing" {
            { Enable-WinDebloatRPCHardening -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 2

            { Disable-WinDebloatRPCHardening -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 2
        }

        It "Enables and disables SMB Signing without throwing" {
            { Enable-WinDebloatSMBSigning -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 4

            { Disable-WinDebloatSMBSigning -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 3
        }

        It "Enables and disables LSA Protection without throwing" {
            { Enable-WinDebloatLSAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 2

            { Disable-WinDebloatLSAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 2
        }

        It "Enables and disables DMA Protection without throwing" {
            { Enable-WinDebloatDMAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 3

            { Disable-WinDebloatDMAProtection -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName Security -Times 3
        }
    }

    Context "PowerShell ScriptBlock Logging & Language Mode Detection" {
        It "Enable-WinDebloatScriptBlockLogging sets EnableScriptBlockLogging = 1" {
            { Enable-WinDebloatScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Set-RegistryKey -ModuleName Security -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -and
                $Name -eq "EnableScriptBlockLogging" -and
                $Value -eq 1 -and
                $Type -eq "DWord"
            }
        }

        It "Disable-WinDebloatScriptBlockLogging removes EnableScriptBlockLogging" {
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
            { Enable-WinDebloat7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            { Enable-WD7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            { Disable-WD7ScriptBlockLogging -Confirm:$false } | Should -Not -Throw
            (Get-WinDebloat7LanguageMode) | Should -Be (Get-WinDebloatLanguageMode)
            (Get-WD7LanguageMode) | Should -Be (Get-WinDebloatLanguageMode)
        }
    }

    Context "Security Status Reporting & Profile Configuration" {
        It "Get-WinDebloatSecurityStatus returns structured security health object" {
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "ProtectedPrintMode" } { return 1 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "EncryptionMethodWithXtsOs" } { return 7 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "RestrictRemoteClients" } { return 1 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "RequireSecuritySignature" } { return 1 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "RunAsPPL" } { return 1 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "DeviceEnumerationPolicy" } { return 1 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "EnableScriptBlockLogging" } { return 1 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "SMB1" } { return 0 }
            Mock -ModuleName Security Get-RegistryKey -ParameterFilter { $Name -eq "MpEnablePua" } { return 1 }

            $status = Get-WinDebloatSecurityStatus
            $status | Should -Not -BeNullOrEmpty
            $status.WPPEnabled | Should -BeTrue
            $status.BitLockerXTS256 | Should -BeTrue
            $status.RPCHardened | Should -BeTrue
            $status.SMBSigningRequired | Should -BeTrue
            $status.LSAProtectionEnabled | Should -BeTrue
            $status.DMAProtectionEnabled | Should -BeTrue
            $status.ScriptBlockLoggingEnabled | Should -BeTrue
            $status.SMBv1Disabled | Should -BeTrue
            $status.PUAProtectionEnabled | Should -BeTrue
        }

        It "Set-WinDebloatSecurity applies full security baseline from profile config" {
            $config = [PSCustomObject]@{
                security = [PSCustomObject]@{
                    enable_wpp                  = $true
                    sudo_mode                   = "ForceNewWindow"
                    enable_bitlocker_xts256     = $true
                    enable_rpc_hardening        = $true
                    enable_smb_signing          = $true
                    enable_lsa_protection       = $true
                    enable_dma_protection       = $true
                    enable_script_block_logging = $true
                }
            }

            { Set-WinDebloatSecurity -Config $config -Confirm:$false } | Should -Not -Throw
        }

        It "Set-WinDebloatSecurity handles empty or missing security config gracefully" {
            $config = [PSCustomObject]@{ tweaks = @{} }
            { Set-WinDebloatSecurity -Config $config -Confirm:$false } | Should -Not -Throw
        }
    }
}
