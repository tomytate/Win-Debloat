# Pester Unit Tests for Win-Debloat Sysprep Module
# Verifies non-destructive execution, registry logic, and image state detection for:
# - Test-WinDebloatSysprep (and alias Test-WinDebloat7Sysprep)
# - Mount-WinDebloatDefaultHive (and alias Mount-WinDebloat7DefaultHive)
# - Dismount-WinDebloatDefaultHive (and alias Dismount-WinDebloat7DefaultHive)

Describe "Sysprep Module" {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module "$root\src\core\Logger.psm1" -Force
        Import-Module "$root\src\core\Sysprep.psm1" -Force
    }

    Context "Test-WinDebloatSysprep" {
        It "Should return `$true when AuditBoot DWORD is 1" {
            Mock -ModuleName Sysprep Get-ItemPropertyValue -ParameterFilter {
                $LiteralPath -eq "HKLM:\SYSTEM\Setup\Status" -and $Name -eq "AuditBoot"
            } { return 1 }

            $result = Test-WinDebloatSysprep
            $result | Should -Be $true

            $aliasResult = Test-WinDebloat7Sysprep
            $aliasResult | Should -Be $true
        }

        It "Should return `$true when AuditBoot is not 1 but ImageState is '<State>'" -TestCases @(
            @{ State = "IMAGE_STATE_AUDIT" },
            @{ State = "IMAGE_STATE_UNDEPLOYABLE" },
            @{ State = "IMAGE_STATE_GENERALIZE_RESEAL_TO_AUDIT" },
            @{ State = "IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT" }
        ) {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester test case parameter')]
            param($State)
            $null = $State

            Mock -ModuleName Sysprep Get-ItemPropertyValue -ParameterFilter {
                $LiteralPath -eq "HKLM:\SYSTEM\Setup\Status" -and $Name -eq "AuditBoot"
            } { return 0 }

            Mock -ModuleName Sysprep Get-ItemPropertyValue -ParameterFilter {
                $LiteralPath -eq "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" -and $Name -eq "ImageState"
            } { return $State }

            $result = Test-WinDebloatSysprep
            $result | Should -Be $true
        }

        It "Should return `$false when AuditBoot is 0 and ImageState is 'IMAGE_STATE_COMPLETE'" {
            Mock -ModuleName Sysprep Get-ItemPropertyValue -ParameterFilter {
                $LiteralPath -eq "HKLM:\SYSTEM\Setup\Status" -and $Name -eq "AuditBoot"
            } { return 0 }

            Mock -ModuleName Sysprep Get-ItemPropertyValue -ParameterFilter {
                $LiteralPath -eq "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" -and $Name -eq "ImageState"
            } { return "IMAGE_STATE_COMPLETE" }

            $result = Test-WinDebloatSysprep
            $result | Should -Be $false
        }

        It "Should return `$false when registry properties do not exist or return `$null" {
            Mock -ModuleName Sysprep Get-ItemPropertyValue { return $null }

            $result = Test-WinDebloatSysprep
            $result | Should -Be $false
        }
    }

    Context "Mount-WinDebloatDefaultHive" {
        BeforeEach {
            Mock -ModuleName Sysprep Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
        }

        It "Should return `$false and not mount if NTUSER.DAT does not exist" {
            Mock -ModuleName Sysprep Test-Path { return $false }

            $result = Mount-WinDebloatDefaultHive
            $result | Should -Be $false

            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 0
        }

        It "Should return `$true immediately if hive is already mounted" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*NTUSER.DAT"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*WinDebloat*_Default"
            } { return $true }

            $result = Mount-WinDebloatDefaultHive
            $result | Should -Be $true

            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 0
        }

        It "Should invoke reg.exe load and return `$true on exit code 0" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*NTUSER.DAT"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*WinDebloat*_Default"
            } { return $false }

            $result = Mount-WinDebloatDefaultHive
            $result | Should -Be $true

            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 1 -ParameterFilter {
                $FilePath -eq "reg.exe" -and $ArgumentList -like 'load "HKLM\WinDebloat_Default"*'
            }
        }

        It "Should return `$false when reg.exe load returns non-zero exit code" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*NTUSER.DAT"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*WinDebloat*_Default"
            } { return $false }

            Mock -ModuleName Sysprep Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }

            $result = Mount-WinDebloatDefaultHive
            $result | Should -Be $false
        }

        It "Should return `$false when reg.exe process throws an exception" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*NTUSER.DAT"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*WinDebloat*_Default"
            } { return $false }

            Mock -ModuleName Sysprep Start-Process {
                throw [System.InvalidOperationException]::new("Process execution failed")
            }

            $result = Mount-WinDebloatDefaultHive
            $result | Should -Be $false
        }
    }

    Context "Dismount-WinDebloatDefaultHive" {
        It "Should return immediately if hive is not mounted" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -like "*WinDebloat*_Default"
            } { return $false }

            Mock -ModuleName Sysprep Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            { Dismount-WinDebloatDefaultHive } | Should -Not -Throw
            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 0
        }

        It "Should invoke reg.exe unload when hive is mounted" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -eq "Registry::HKLM\WinDebloat_Default"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -eq "Registry::HKLM\WinDebloat7_Default"
            } { return $false }

            Mock -ModuleName Sysprep Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            { Dismount-WinDebloatDefaultHive } | Should -Not -Throw
            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 1 -ParameterFilter {
                $FilePath -eq "reg.exe" -and $ArgumentList -eq 'unload "HKLM\WinDebloat_Default"'
            }
        }

        It "Should handle non-zero exit code or process failure gracefully without throwing" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -eq "Registry::HKLM\WinDebloat_Default"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -eq "Registry::HKLM\WinDebloat7_Default"
            } { return $false }

            Mock -ModuleName Sysprep Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }

            { Dismount-WinDebloatDefaultHive } | Should -Not -Throw
        }

        It "Should catch and log exceptions during dismount without throwing" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -eq "Registry::HKLM\WinDebloat_Default"
            } { return $true }

            Mock -ModuleName Sysprep Test-Path -ParameterFilter {
                $Path -eq "Registry::HKLM\WinDebloat7_Default"
            } { return $false }

            Mock -ModuleName Sysprep Start-Process {
                throw [System.InvalidOperationException]::new("Dismount exception")
            }

            { Dismount-WinDebloatDefaultHive } | Should -Not -Throw
        }
    }

    Context "Get-WinDebloatUserProfiles" {
        It "Should query ProfileList and return discovered user profiles" {
            Mock -ModuleName Sysprep Test-Path { return $true }
            Mock -ModuleName Sysprep Get-ChildItem {
                return @(
                    [PSCustomObject]@{ PSChildName = "S-1-5-21-12345"; PSPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-12345" }
                )
            }
            Mock -ModuleName Sysprep Get-ItemPropertyValue { return "C:\Users\TestUser" }

            $profiles = Get-WinDebloatUserProfiles
            $profiles.Count | Should -Be 1
            $profiles[0].UserName | Should -Be "TestUser"
            $profiles[0].SID | Should -Be "S-1-5-21-12345"
            $profiles[0].IsDefault | Should -Be $false
        }
    }

    Context "Mount-WinDebloatUserHive and Dismount-WinDebloatUserHive" {
        It "Mounts offline profile hive via reg.exe" {
            Mock -ModuleName Sysprep Test-Path -ParameterFilter { ($Path -like "*NTUSER.DAT") -or ($LiteralPath -like "*NTUSER.DAT") } { return $true }
            Mock -ModuleName Sysprep Test-Path -ParameterFilter { ($Path -like "*WinDebloat_Test*") -or ($LiteralPath -like "*WinDebloat_Test*") } { return $false }
            Mock -ModuleName Sysprep Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }

            $mounted = Mount-WinDebloatUserHive -ProfilePath "C:\Users\TestUser" -MountName "WinDebloat_Test"
            $mounted | Should -Be $true
            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 1
        }

        It "Dismounts offline profile hive via reg.exe with retry" {
            Mock -ModuleName Sysprep Test-Path { return $true }
            Mock -ModuleName Sysprep Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }

            { Dismount-WinDebloatUserHive -MountName "WinDebloat_Test" } | Should -Not -Throw
            Should -Invoke -CommandName Start-Process -ModuleName Sysprep -Times 1
        }
    }

    Context "Invoke-WinDebloatWithTargetUserHive" {
        It "Invokes scriptblock with Default hive when TargetUser is Default" {
            Mock -ModuleName Sysprep Mount-WinDebloatDefaultHive { return $true }
            Mock -ModuleName Sysprep Dismount-WinDebloatDefaultHive { }

            $targetHive = $null
            Invoke-WinDebloatWithTargetUserHive -TargetUser "Default" -ScriptBlock {
                param($hive)
                $script:targetHive = $hive
            }

            $script:targetHive | Should -Be "HKLM\WinDebloat_Default"
            Should -Invoke -CommandName Dismount-WinDebloatDefaultHive -ModuleName Sysprep -Times 1
        }
    }
}
