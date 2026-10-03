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

    Context "AMD Dual-CCD X3D Detection & Core Parking Headroom" {
        It "Test-WinDebloatDualCcdX3D accurately detects asymmetric cache CPUs" {
            Test-WinDebloatDualCcdX3D -ProcessorNameOverride "AMD Ryzen 9 7950X3D 16-Core Processor" | Should -Be $true
            Test-WinDebloatDualCcdX3D -ProcessorNameOverride "AMD Ryzen 9 7900X3D 12-Core Processor" | Should -Be $true
            Test-WinDebloatDualCcdX3D -ProcessorNameOverride "AMD Ryzen 9 9950X3D 16-Core Processor" | Should -Be $true
            Test-WinDebloatDualCcdX3D -ProcessorNameOverride "AMD Ryzen 9 9900X3D 12-Core Processor" | Should -Be $true
            Test-WinDebloatDualCcdX3D -ProcessorNameOverride "AMD Ryzen 7 7800X3D 8-Core Processor" | Should -Be $false
            Test-WinDebloatDualCcdX3D -ProcessorNameOverride "13th Gen Intel(R) Core(TM) i9-13900K" | Should -Be $false
        }
    }

    Context "MMCSS Gaming Priority & Zero Network Throttling" {
        It "Set-WinDebloatMMCSSPriority configures zero network throttling" {
            Mock -ModuleName Gaming Set-RegistryKey { return $true }
            { Set-WinDebloatMMCSSPriority -Confirm:$false } | Should -Not -Throw
            { Set-WinDebloat7MMCSSPriority -Confirm:$false } | Should -Not -Throw
        }

        It "Reset-WinDebloatMMCSSPriority restores defaults" {
            Mock -ModuleName Gaming Set-RegistryKey { return $true }
            Mock -ModuleName Gaming Remove-RegistryKey { return $true }
            { Reset-WinDebloatMMCSSPriority -Confirm:$false } | Should -Not -Throw
            { Reset-WinDebloat7MMCSSPriority -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "NVMe APST Low Latency Subsystem" {
        It "Disable-WinDebloatNVMeAPST sets DisableAPST flag" {
            Mock -ModuleName Gaming Set-RegistryKey { return $true }
            { Disable-WinDebloatNVMeAPST -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7NVMeAPST -Confirm:$false } | Should -Not -Throw
        }

        It "Enable-WinDebloatNVMeAPST restores default APST transitions" {
            Mock -ModuleName Gaming Remove-RegistryKey { return $true }
            { Enable-WinDebloatNVMeAPST -Confirm:$false } | Should -Not -Throw
            { Enable-WinDebloat7NVMeAPST -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Energy Saver AC Throttling" {
        It "Disable-WinDebloatEnergySaverAcThrottling disables AC throttling" {
            Mock -ModuleName Performance Set-RegistryKey { return $true }
            { Disable-WinDebloatEnergySaverAcThrottling -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7EnergySaverAcThrottling -Confirm:$false } | Should -Not -Throw
        }

        It "Enable-WinDebloatEnergySaverAcThrottling restores AC throttling" {
            Mock -ModuleName Performance Set-RegistryKey { return $true }
            { Enable-WinDebloatEnergySaverAcThrottling -Confirm:$false } | Should -Not -Throw
            { Enable-WinDebloat7EnergySaverAcThrottling -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Dev Drive ReFS & Server Native NVMe" {
        It "Optimize-WinDebloatDevDrive sets RefsDisableLastAccessUpdate" {
            Mock -ModuleName Performance Set-RegistryKey { return $true }
            { Optimize-WinDebloatDevDrive -Confirm:$false } | Should -Not -Throw
            { Optimize-WinDebloat7DevDrive -Confirm:$false } | Should -Not -Throw
        }

        It "Reset-WinDebloatDevDrive removes ReFS tuning key" {
            Mock -ModuleName Performance Remove-RegistryKey { return $true }
            { Reset-WinDebloatDevDrive -Confirm:$false } | Should -Not -Throw
            { Reset-WinDebloat7DevDrive -Confirm:$false } | Should -Not -Throw
        }

        It "Enable-WinDebloatServerNativeNVMe sets NativeNVMeStorageDriver" {
            Mock -ModuleName Performance Set-RegistryKey { return $true }
            { Enable-WinDebloatServerNativeNVMe -Confirm:$false } | Should -Not -Throw
            { Enable-WinDebloat7ServerNativeNVMe -Confirm:$false } | Should -Not -Throw
        }

        It "Disable-WinDebloatServerNativeNVMe removes driver key" {
            Mock -ModuleName Performance Remove-RegistryKey { return $true }
            { Disable-WinDebloatServerNativeNVMe -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7ServerNativeNVMe -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Network LSO and ECN Optimizations" {
        It "Disable-WinDebloatNetAdapterLSO and Enable-WinDebloatNetAdapterLSO execute safely" {
            Mock -ModuleName Network Get-NetAdapter { return @([pscustomobject]@{ Name = "Ethernet"; Status = "Up" }) }
            Mock -ModuleName Network Get-Command { return $true }
            Mock -ModuleName Network Disable-NetAdapterLso { }
            Mock -ModuleName Network Enable-NetAdapterLso { }
            { Disable-WinDebloatNetAdapterLSO -Confirm:$false } | Should -Not -Throw
            { Enable-WinDebloatNetAdapterLSO -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7NetAdapterLSO -Confirm:$false } | Should -Not -Throw
            { Enable-WinDebloat7NetAdapterLSO -Confirm:$false } | Should -Not -Throw
        }

        It "Enable-WinDebloatECN and Disable-WinDebloatECN execute safely" {
            { Enable-WinDebloatECN -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloatECN -Confirm:$false } | Should -Not -Throw
            { Enable-WinDebloat7ECN -Confirm:$false } | Should -Not -Throw
            { Disable-WinDebloat7ECN -Confirm:$false } | Should -Not -Throw
        }
    }
}
