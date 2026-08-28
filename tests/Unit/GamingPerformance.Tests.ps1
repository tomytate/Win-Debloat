Describe "Gaming & Performance Subsystem" {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module "$root\src\core\Logger.psm1" -Force
        Import-Module "$root\src\core\Registry.psm1" -Force
        Import-Module "$root\src\modules\Performance\Gaming.psm1" -Force
        Import-Module "$root\src\modules\Performance\Performance.psm1" -Force
        Import-Module "$root\src\modules\Network\Network.psm1" -Force
        Import-Module "$root\src\modules\Performance\Benchmark.psm1" -Force
        Import-Module "$root\src\modules\Performance\Services.psm1" -Force
    }

    Context "DirectStorage 1.2+ Tuning" {
        It "Optimize-WinDebloatDirectStorage sets NTFS lookaside pool values" {
            Mock -ModuleName Performance Set-RegistryKey { return $true }
            { Optimize-WinDebloatDirectStorage -Confirm:$false } | Should -Not -Throw
        }

        It "Reset-WinDebloatDirectStorage removes NTFS registry overrides" {
            Mock -ModuleName Performance Remove-RegistryKey { return $true }
            { Reset-WinDebloatDirectStorage -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "DirectSR & Windowed VRR" {
        It "Enable-WinDebloatDirectSR sets DirectXUserGlobalSettings" {
            Mock -ModuleName Gaming Set-RegistryKey { return $true }
            { Enable-WinDebloatDirectSR -Confirm:$false } | Should -Not -Throw
        }

        It "Disable-WinDebloatDirectSR cleans up registry setting" {
            Mock -ModuleName Gaming Remove-RegistryKey { return $true }
            { Disable-WinDebloatDirectSR -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "AMD X3D Dual-CCD Safeguards" {
        It "Protect-WinDebloatAMDX3D enables AutoGameMode" {
            Mock -ModuleName Gaming Set-RegistryKey { return $true }
            Mock -ModuleName Gaming Get-Service { return $null }
            { Protect-WinDebloatAMDX3D -Confirm:$false } | Should -Not -Throw
        }

        It "Reset-WinDebloatAMDX3D restores defaults" {
            Mock -ModuleName Gaming Remove-RegistryKey { return $true }
            { Reset-WinDebloatAMDX3D -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "HAGS & TDR Tuning" {
        It "Set-WinDebloatHAGSTDR sets HwSchMode and TdrDelay" {
            Mock -ModuleName Gaming Set-RegistryKey { return $true }
            { Set-WinDebloatHAGSTDR -Confirm:$false } | Should -Not -Throw
        }

        It "Reset-WinDebloatHAGSTDR restores defaults" {
            Mock -ModuleName Gaming Remove-RegistryKey { return $true }
            { Reset-WinDebloatHAGSTDR -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Benchmark Subsystem" {
        It "Measure-WinDebloatSystem captures system metrics accurately and fast" {
            $metrics = Measure-WinDebloatSystem
            $metrics | Should -Not -BeNullOrEmpty
            $metrics.UsedRAM_MB | Should -BeGreaterThan 0
            $metrics.FreeRAM_MB | Should -BeGreaterOrEqual 0
            $metrics.Processes | Should -BeGreaterThan 0
            $metrics.Services | Should -BeGreaterThan 0
            $metrics.DiskFree_GB | Should -BeGreaterThan 0
            $metrics.Timestamp | Should -Not -BeNullOrEmpty
            $metrics.LastBoot | Should -Not -BeNullOrEmpty
        }

        It "Measure-WinDebloat7System alias returns identical structure" {
            $metrics = Measure-WinDebloat7System
            $metrics | Should -Not -BeNullOrEmpty
            $metrics.Processes | Should -BeGreaterThan 0
        }

        It "Compare-WinDebloatBenchmarks generates markdown report correctly" {
            $ref = [pscustomobject]@{
                UsedRAM_MB  = 8000
                FreeRAM_MB  = 8000
                Processes   = 200
                Services    = 100
                DiskFree_GB = 100.0
                LastBoot    = (Get-Date)
            }
            $diff = [pscustomobject]@{
                UsedRAM_MB  = 6000
                FreeRAM_MB  = 10000
                Processes   = 150
                Services    = 80
                DiskFree_GB = 105.5
                LastBoot    = (Get-Date)
            }
            $tempReport = Join-Path ([System.IO.Path]::GetTempPath()) "test_report.md"
            try {
                $report = Compare-WinDebloatBenchmarks -Reference $ref -Difference $diff -ReportPath $tempReport
                $report | Should -Match "2000 MB.*freed"
                $report | Should -Match "50.*fewer"
                $report | Should -Match "20.*disabled"
                $report | Should -Match "5.5 GB.*reclaimed"
            }
            finally {
                if (Test-Path $tempReport) { Remove-Item $tempReport -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    Context "Services Subsystem" {
        It "Get-WinDebloatServicePresets returns expected preset list" {
            $presets = Get-WinDebloatServicePresets
            $presets | Should -Contain "Privacy"
            $presets | Should -Contain "Performance"
            $presets | Should -Contain "Security"
            $presets | Should -Contain "Minimal"
            $presets | Should -Contain "Gaming"
        }

        It "Get-WinDebloatServiceStatus returns service status list using fast collection mapping" {
            $status = Get-WinDebloatServiceStatus
            $status | Should -Not -BeNullOrEmpty
            $status.Count | Should -BeGreaterThan 0
            $status[0].PSObject.Properties['Name'] | Should -Not -BeNullOrEmpty
            $status[0].PSObject.Properties['Status'] | Should -Not -BeNullOrEmpty
            $status[0].PSObject.Properties['CurrentStartup'] | Should -Not -BeNullOrEmpty
            $status[0].PSObject.Properties['RecommendedStartup'] | Should -Not -BeNullOrEmpty
        }

        It "Set-WinDebloatServices executes without error with ShouldProcess" {
            Mock -ModuleName Services Set-Service { }
            Mock -ModuleName Services Stop-Service { }
            { Set-WinDebloatServices -Preset Minimal -Confirm:$false } | Should -Not -Throw
        }
    }
}
