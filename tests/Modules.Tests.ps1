Describe "Modules.Windows11.VersionDetection" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Windows11\Version-Detection.psm1" -ErrorAction Stop
    }

    It "Exports Get-WindowsVersionInfo" {
        $cmd = Get-Command "Get-WindowsVersionInfo" -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
    }

    It "Exports Test-Windows11Version" {
        $cmd = Get-Command "Test-Windows11Version" -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
    }

    It "Exports Clear-WindowsVersionCache" {
        $cmd = Get-Command "Clear-WindowsVersionCache" -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Bloatware" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\core\Config.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Bloatware\Bloatware.psm1" -ErrorAction Stop
    }

    It "Includes Critical 25H2 Bloatware Apps via cmdlet and alias" {
        $list1 = Get-WinDebloatBloatwareList
        $list1.Count | Should -BeGreaterThan 0

        $list2 = Get-WinDebloat7BloatwareList
        $list2.Count | Should -BeGreaterThan 0
    }

    It "Exports Remove-WinDebloatBloatware and Remove-WinDebloat7Bloatware alias" {
        (Get-Command "Remove-WinDebloatBloatware" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-WinDebloat7Bloatware" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Uninstall-WinDebloatOneDrive and Uninstall-WinDebloat7OneDrive alias" {
        (Get-Command "Uninstall-WinDebloatOneDrive" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Uninstall-WinDebloat7OneDrive" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Uninstall-WinDebloatEdge and Uninstall-WinDebloat7Edge alias" {
        (Get-Command "Uninstall-WinDebloatEdge" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Uninstall-WinDebloat7Edge" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Uninstall-WinDebloatXbox and Uninstall-WinDebloat7Xbox alias" {
        (Get-Command "Uninstall-WinDebloatXbox" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Uninstall-WinDebloat7Xbox" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Privacy" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Privacy\Privacy.psm1" -ErrorAction Stop
    }
    
    It "Exports Set-WinDebloatPrivacy and Set-WinDebloat7Privacy alias" {
        (Get-Command "Set-WinDebloatPrivacy" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7Privacy" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Enable-WinDebloatPrivacy and Enable-WinDebloat7Privacy alias" {
        (Get-Command "Enable-WinDebloatPrivacy" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7Privacy" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Disable-WinDebloatAI and Disable-WinDebloat7AIandAds alias" {
        (Get-Command "Disable-WinDebloatAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7AIandAds" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Privacy.Tasks" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Privacy\Tasks.psm1" -ErrorAction Stop
    }

    It "Exports Get-WinDebloatTelemetryTasks and Get-WinDebloat7TelemetryTasks alias" {
        (Get-Command "Get-WinDebloatTelemetryTasks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7TelemetryTasks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Disable-WinDebloatTelemetryTasks and Disable-WinDebloat7TelemetryTasks alias" {
        (Get-Command "Disable-WinDebloatTelemetryTasks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7TelemetryTasks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Enable-WinDebloatTelemetryTasks and Enable-WinDebloat7TelemetryTasks alias" {
        (Get-Command "Enable-WinDebloatTelemetryTasks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7TelemetryTasks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Privacy.Firewall" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Privacy\Firewall.psm1" -ErrorAction Stop
    }

    It "Exports Add-WinDebloatFirewallBlock and Add-WinDebloat7FirewallBlock alias" {
        (Get-Command "Add-WinDebloatFirewallBlock" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Add-WinDebloat7FirewallBlock" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Remove-WinDebloatFirewallBlock and Remove-WinDebloat7FirewallBlock alias" {
        (Get-Command "Remove-WinDebloatFirewallBlock" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-WinDebloat7FirewallBlock" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatFirewallStatus and Get-WinDebloat7FirewallStatus alias" {
        (Get-Command "Get-WinDebloatFirewallStatus" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7FirewallStatus" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatTelemetryDomains and Get-WinDebloat7TelemetryDomains alias" {
        $domains1 = Get-WinDebloatTelemetryDomains
        $domains1.Count | Should -BeGreaterThan 10

        $domains2 = Get-WinDebloat7TelemetryDomains
        $domains2.Count | Should -BeGreaterThan 10
    }
}

Describe "Modules.Security" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Security\Security.psm1" -ErrorAction Stop
    }

    It "Exports Disable-WinDebloatSMBv1 and Disable-WinDebloat7SMBv1" {
        (Get-Command "Disable-WinDebloatSMBv1" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7SMBv1" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Enable-WinDebloatSMBv1 and Enable-WinDebloat7SMBv1" {
        (Get-Command "Enable-WinDebloatSMBv1" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7SMBv1" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Enable-WinDebloatPUAProtection and Enable-WinDebloat7PUAProtection" {
        (Get-Command "Enable-WinDebloatPUAProtection" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7PUAProtection" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Disable-WinDebloatPUAProtection and Disable-WinDebloat7PUAProtection" {
        (Get-Command "Disable-WinDebloatPUAProtection" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7PUAProtection" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Enable-WinDebloatScriptBlockLogging, Disable-WinDebloatScriptBlockLogging and aliases" {
        (Get-Command "Enable-WinDebloatScriptBlockLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7ScriptBlockLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WD7ScriptBlockLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatScriptBlockLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7ScriptBlockLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WD7ScriptBlockLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatLanguageMode and aliases" {
        (Get-Command "Get-WinDebloatLanguageMode" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7LanguageMode" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WD7LanguageMode" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatSecurityStatus and Get-WinDebloat7SecurityStatus" {
        $status = Get-WinDebloatSecurityStatus
        $status | Should -Not -BeNullOrEmpty
        $status.PSObject.Properties['SMBv1Disabled'] | Should -Not -BeNullOrEmpty
        $status.PSObject.Properties['PUAProtectionEnabled'] | Should -Not -BeNullOrEmpty
        $status.PSObject.Properties['ScriptBlockLoggingEnabled'] | Should -Not -BeNullOrEmpty
        $status.PSObject.Properties['LanguageMode'] | Should -Not -BeNullOrEmpty

        $status7 = Get-WinDebloat7SecurityStatus
        $status7 | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Performance" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Performance\Performance.psm1" -ErrorAction Stop
        Import-Module "$src\modules\Performance\Benchmark.psm1" -ErrorAction Stop
        Import-Module "$src\modules\Performance\Gaming.psm1" -ErrorAction Stop
        Import-Module "$src\modules\Performance\Services.psm1" -ErrorAction Stop
    }

    It "Exports Measure-WinDebloatSystem and Measure-WinDebloat7System" {
        (Get-Command "Measure-WinDebloatSystem" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Measure-WinDebloat7System" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Compare-WinDebloatBenchmarks and Compare-WinDebloat7Benchmarks" {
        (Get-Command "Compare-WinDebloatBenchmarks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Compare-WinDebloat7Benchmarks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Optimize-WinDebloatPerformance and Set-WinDebloatPerformance" {
        (Get-Command "Optimize-WinDebloatPerformance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloatPerformance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7Performance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Set-WinDebloatGaming and Set-WinDebloat7Gaming" {
        (Get-Command "Set-WinDebloatGaming" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7Gaming" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Set-WinDebloatServices and Set-WinDebloat7Services" {
        (Get-Command "Set-WinDebloatServices" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7Services" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatServicePresets and Get-WinDebloat7ServicePresets" {
        (Get-Command "Get-WinDebloatServicePresets" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7ServicePresets" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Network" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Network\Network.psm1" -ErrorAction Stop
    }

    It "Exports Set-WinDebloatDNS and Set-WinDebloat7DNS" {
        (Get-Command "Set-WinDebloatDNS" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7DNS" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatDNSProviders and Get-WinDebloat7DNSProviders" {
        (Get-Command "Get-WinDebloatDNSProviders" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7DNSProviders" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Disable-WinDebloatIPv6, Enable-WinDebloatIPv6 and aliases" {
        (Get-Command "Disable-WinDebloatIPv6" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7IPv6" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatIPv6" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7IPv6" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Disable-WinDebloatNetBIOS, Enable-WinDebloatNetBIOS, Get-WinDebloatNetBIOSStatus and aliases" {
        (Get-Command "Disable-WinDebloatNetBIOS" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7NetBIOS" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatNetBIOS" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7NetBIOS" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloatNetBIOSStatus" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7NetBIOSStatus" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatNetworkStatus and Set-WinDebloatNetwork" {
        (Get-Command "Get-WinDebloatNetworkStatus" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7NetworkStatus" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloatNetwork" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7Network" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Set-WinDebloatTcpCongestionProvider, Disable-WinDebloatNetAdapterRSC, Enable-WinDebloatNetAdapterRSC and aliases" {
        (Get-Command "Set-WinDebloatTcpCongestionProvider" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7TcpCongestionProvider" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatNetAdapterRSC" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7NetAdapterRSC" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatNetAdapterRSC" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7NetAdapterRSC" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Supports TCP congestion provider options (cubic, bbr2, newreno, default)" {
        { Set-WinDebloatTcpCongestionProvider -Provider cubic -WhatIf } | Should -Not -Throw
        { Set-WinDebloatTcpCongestionProvider -Provider bbr2 -WhatIf } | Should -Not -Throw
        { Set-WinDebloatTcpCongestionProvider -Provider newreno -WhatIf } | Should -Not -Throw
        { Set-WinDebloatTcpCongestionProvider -Provider default -WhatIf } | Should -Not -Throw
    }
}

Describe "Modules.Tweaks" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Performance\Tweaks.psm1" -ErrorAction Stop
    }

    It "Exports AI disablement functions and WinDebloat7 aliases" {
        (Get-Command "Disable-WinDebloatAIRecall" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7AIRecall" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatCopilot" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7Copilot" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatClickToDo" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7ClickToDo" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatNotepadAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7NotepadAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatPaintAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7PaintAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatEdgeAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7EdgeAI" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Power, Sysprep, and Ad tweak functions and aliases" {
        (Get-Command "Enable-WinDebloatUltimatePower" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloat7UltimatePower" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatUltimatePower" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7UltimatePower" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Invoke-WinDebloatSysprepDefaults" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Invoke-WinDebloat7SysprepDefaults" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatDesktopSpotlight" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7DesktopSpotlight" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatSettings365Ads" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7Settings365Ads" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Vendor" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Vendor\Vendor.psm1" -ErrorAction Stop
    }

    It "Exports Disable-WinDebloatGpuTelemetry and Disable-WinDebloat7GpuTelemetry" {
        (Get-Command "Disable-WinDebloatGpuTelemetry" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloat7GpuTelemetry" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Remove-WinDebloatOemBloat and Remove-WinDebloat7OemBloat" {
        (Get-Command "Remove-WinDebloatOemBloat" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-WinDebloat7OemBloat" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Maintenance" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Maintenance\Maintenance.psm1" -ErrorAction Stop
    }

    It "Exports Register-WinDebloatMaintenance, Unregister-WinDebloatMaintenance, Invoke-WinDebloatMaintenance and aliases" {
        (Get-Command "Register-WinDebloatMaintenance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Register-WinDebloat7Maintenance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Unregister-WinDebloatMaintenance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Unregister-WinDebloat7Maintenance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Invoke-WinDebloatMaintenance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Invoke-WinDebloat7Maintenance" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}

Describe "Modules.Features" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Features\Features.psm1" -ErrorAction Stop
    }

    It "Exports Set-WinDebloatOptionalFeatures and Set-WinDebloat7OptionalFeatures" {
        (Get-Command "Set-WinDebloatOptionalFeatures" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Set-WinDebloat7OptionalFeatures" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Remove-WinDebloatCapabilities and Remove-WinDebloat7Capabilities" {
        (Get-Command "Remove-WinDebloatCapabilities" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-WinDebloat7Capabilities" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}
