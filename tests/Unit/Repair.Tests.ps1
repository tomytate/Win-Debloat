# Pester Unit Tests for Win-Debloat Repair Module
# Verifies non-destructive execution, parameters, and error handling for:
# - Repair-WinDebloatSystem / Repair-WinDebloat7System
# - Reset-WinDebloatNetwork / Reset-WinDebloat7Network
# - Reset-WinDebloatUpdate / Reset-WinDebloat7Update

Describe "Repair Module" {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module "$root\src\core\Logger.psm1" -Force
        Import-Module "$root\src\modules\Repair\Repair.psm1" -Force
    }

    Context "Repair-WinDebloatSystem and Repair-WinDebloat7System" {
        BeforeEach {
            Mock -ModuleName Repair Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
        }

        It "Should execute the 4-step sequence (ChkDsk -> SFC -> DISM -> SFC) when confirmed (cmdlet)" {
            Repair-WinDebloatSystem -Confirm:$false

            # Verify ChkDsk (step 1)
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "chkdsk.exe" -and $ArgumentList -contains "/scan" -and $ArgumentList -contains "/perf"
            }

            # Verify SFC (steps 2 & 4)
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 2 -ParameterFilter {
                $FilePath -eq "sfc.exe" -and $ArgumentList -eq "/scannow"
            }

            # Verify DISM (step 3)
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "dism.exe" -and $ArgumentList -contains "/Online" -and $ArgumentList -contains "/RestoreHealth"
            }
        }

        It "Should execute via Repair-WinDebloat7System alias" {
            Repair-WinDebloat7System -Confirm:$false

            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 4
        }

        It "Should handle DISM exit code 3010 (reboot pending) as success" {
            Mock -ModuleName Repair Start-Process -ParameterFilter { $FilePath -eq "dism.exe" } {
                return [PSCustomObject]@{ ExitCode = 3010 }
            }

            { Repair-WinDebloatSystem -Confirm:$false } | Should -Not -Throw
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "dism.exe"
            }
        }

        It "Should handle non-zero exit codes from ChkDsk and DISM gracefully" {
            Mock -ModuleName Repair Start-Process -ParameterFilter { $FilePath -eq "chkdsk.exe" } {
                return [PSCustomObject]@{ ExitCode = 2 }
            }
            Mock -ModuleName Repair Start-Process -ParameterFilter { $FilePath -eq "dism.exe" } {
                return [PSCustomObject]@{ ExitCode = 1 }
            }

            { Repair-WinDebloatSystem -Confirm:$false } | Should -Not -Throw
        }

        It "Should handle process execution exceptions gracefully without crashing" {
            Mock -ModuleName Repair Start-Process {
                throw [System.InvalidOperationException]::new("Mock process failure")
            }

            { Repair-WinDebloatSystem -Confirm:$false } | Should -Not -Throw
        }

        It "Should respect -WhatIf and not launch processes" {
            Repair-WinDebloatSystem -WhatIf

            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 0
        }
    }

    Context "Reset-WinDebloatNetwork and Reset-WinDebloat7Network" {
        BeforeEach {
            Mock -ModuleName Repair Start-Process { return $null }
        }

        It "Should execute all 5 network reset commands when confirmed (cmdlet)" {
            Reset-WinDebloatNetwork -Confirm:$false

            # Total of 5 invocations
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 5

            # 3 ipconfig commands (/release, /flushdns, /renew)
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "ipconfig" -and $ArgumentList -eq "/release"
            }
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "ipconfig" -and $ArgumentList -eq "/flushdns"
            }
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "ipconfig" -and $ArgumentList -eq "/renew"
            }

            # 2 netsh commands (winsock reset, int ip reset)
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "netsh" -and $ArgumentList -eq "winsock reset"
            }
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 1 -ParameterFilter {
                $FilePath -eq "netsh" -and $ArgumentList -like "int ip reset*"
            }
        }

        It "Should work via Reset-WinDebloat7Network alias" {
            Reset-WinDebloat7Network -Confirm:$false
            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 5
        }

        It "Should respect -WhatIf and not run network reset commands" {
            Reset-WinDebloatNetwork -WhatIf

            Should -Invoke -CommandName Start-Process -ModuleName Repair -Times 0
        }
    }

    Context "Reset-WinDebloatUpdate and Reset-WinDebloat7Update" {
        BeforeEach {
            Mock -ModuleName Repair Stop-Service { }
            Mock -ModuleName Repair Start-Service { }
            Mock -ModuleName Repair Start-Sleep { }
            Mock -ModuleName Repair Test-Path { return $true }
            Mock -ModuleName Repair Rename-Item { }
        }

        It "Should stop and start all 5 Windows Update related services (cmdlet)" {
            Reset-WinDebloatUpdate -Confirm:$false

            $expectedServices = @("wuauserv", "cryptSvc", "bits", "dosvc", "msiserver")

            foreach ($svc in $expectedServices) {
                Should -Invoke -CommandName Stop-Service -ModuleName Repair -Times 1 -ParameterFilter {
                    $Name -eq $svc
                }
                Should -Invoke -CommandName Start-Service -ModuleName Repair -Times 1 -ParameterFilter {
                    $Name -eq $svc
                }
            }
        }

        It "Should work via Reset-WinDebloat7Update alias" {
            Reset-WinDebloat7Update -Confirm:$false
            Should -Invoke -CommandName Stop-Service -ModuleName Repair -Times 5
        }

        It "Should rename SoftwareDistribution and catroot2 when they exist" {
            Reset-WinDebloatUpdate -Confirm:$false

            Should -Invoke -CommandName Rename-Item -ModuleName Repair -Times 1 -ParameterFilter {
                $Path -like "*SoftwareDistribution" -and $NewName -like "SoftwareDistribution.bak_*"
            }
            Should -Invoke -CommandName Rename-Item -ModuleName Repair -Times 1 -ParameterFilter {
                $Path -like "*catroot2" -and $NewName -like "catroot2.bak_*"
            }
        }

        It "Should skip renaming folders when they do not exist" {
            Mock -ModuleName Repair Test-Path { return $false }

            Reset-WinDebloatUpdate -Confirm:$false

            Should -Invoke -CommandName Rename-Item -ModuleName Repair -Times 0
            # Services should still be restarted
            Should -Invoke -CommandName Start-Service -ModuleName Repair -Times 5
        }

        It "Should respect -WhatIf and not alter services or filesystem" {
            Reset-WinDebloatUpdate -WhatIf

            Should -Invoke -CommandName Stop-Service -ModuleName Repair -Times 0
            Should -Invoke -CommandName Start-Service -ModuleName Repair -Times 0
            Should -Invoke -CommandName Rename-Item -ModuleName Repair -Times 0
        }
    }
}
