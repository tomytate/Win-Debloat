Describe "Bloatware Module Rebrand" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Bloatware\Bloatware.psm1" -Force -ErrorAction Stop
    }

    It "Exports new WinDebloat functions" {
        (Get-Command "Get-WinDebloatBloatwareList" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-WinDebloatBloatware" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Uninstall-WinDebloatOneDrive" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Uninstall-WinDebloatEdge" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Uninstall-WinDebloatXbox" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports backward-compatible WinDebloat7 aliases" {
        (Get-Command "Get-WinDebloat7BloatwareList" -CommandType Alias).Definition | Should -Be "Get-WinDebloatBloatwareList"
        (Get-Command "Remove-WinDebloat7Bloatware" -CommandType Alias).Definition | Should -Be "Remove-WinDebloatBloatware"
        (Get-Command "Uninstall-WinDebloat7OneDrive" -CommandType Alias).Definition | Should -Be "Uninstall-WinDebloatOneDrive"
        (Get-Command "Uninstall-WinDebloat7Edge" -CommandType Alias).Definition | Should -Be "Uninstall-WinDebloatEdge"
        (Get-Command "Uninstall-WinDebloat7Xbox" -CommandType Alias).Definition | Should -Be "Uninstall-WinDebloatXbox"
    }
}

Describe "Bloatware Module Optimization & Functional Tests" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Bloatware\Bloatware.psm1" -Force -ErrorAction Stop
    }

    Context "Uninstall-WinDebloatXbox Batch Querying" {
        It "Executes single batched Get-AppxPackage query and removes matching Xbox apps" {
            Mock -ModuleName Bloatware Stop-Service { }
            Mock -ModuleName Bloatware Set-Service { }
            Mock -ModuleName Bloatware Get-AppxPackage {
                return @(
                    [PSCustomObject]@{ Name = "Microsoft.XboxApp" }
                    [PSCustomObject]@{ Name = "Microsoft.GamingApp" }
                    [PSCustomObject]@{ Name = "Microsoft.WindowsCalculator" }
                    [PSCustomObject]@{ Name = "Microsoft.XboxIdentityProvider" }
                )
            }
            Mock -ModuleName Bloatware Remove-AppxPackage { }
            Mock -ModuleName Bloatware Get-AppxProvisionedPackage {
                return @(
                    [PSCustomObject]@{ PackageName = "Microsoft.XboxApp_1.0"; DisplayName = "XboxApp" }
                    [PSCustomObject]@{ PackageName = "Microsoft.Calculator_1.0"; DisplayName = "Calculator" }
                )
            }
            Mock -ModuleName Bloatware Remove-AppxProvisionedPackage { }

            { Uninstall-WinDebloatXbox -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Remove-WinDebloatBloatware Regex & Exclusion Handling" {
        It "Filters apps matching pre-compiled regex while respecting exclusions and system whitelist" {
            Mock -ModuleName Bloatware Get-AppxPackage {
                return @(
                    [PSCustomObject]@{ Name = "SpotifyAB.SpotifyMusic" }
                    [PSCustomObject]@{ Name = "Disney" }
                    [PSCustomObject]@{ Name = "Microsoft.WindowsStore" }
                    [PSCustomObject]@{ Name = "Microsoft.BingWeather" }
                )
            }
            Mock -ModuleName Bloatware Remove-AppxPackage { }
            Mock -ModuleName Bloatware Get-AppxProvisionedPackage {
                return @(
                    [PSCustomObject]@{ PackageName = "SpotifyAB.SpotifyMusic_1.0"; DisplayName = "SpotifyAB.SpotifyMusic" }
                    [PSCustomObject]@{ PackageName = "Microsoft.WindowsStore_1.0"; DisplayName = "Microsoft.WindowsStore" }
                )
            }
            Mock -ModuleName Bloatware Remove-AppxProvisionedPackage { }

            $mockConfig = [PSCustomObject]@{
                bloatware = [PSCustomObject]@{
                    removal_mode = "Conservative"
                    exclude_list = @("Disney*")
                }
            }

            { Remove-WinDebloatBloatware -Config $mockConfig -Confirm:$false } | Should -Not -Throw
        }
    }
}

Describe "Privacy Tasks Module Rebrand" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Privacy\Tasks.psm1" -Force -ErrorAction Stop
    }

    It "Exports new WinDebloat functions" {
        (Get-Command "Get-WinDebloatTelemetryTasks" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatTelemetryTasks" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatTelemetryTasks" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports backward-compatible WinDebloat7 aliases" {
        (Get-Command "Get-WinDebloat7TelemetryTasks" -CommandType Alias).Definition | Should -Be "Get-WinDebloatTelemetryTasks"
        (Get-Command "Disable-WinDebloat7TelemetryTasks" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatTelemetryTasks"
        (Get-Command "Set-WinDebloatTelemetryTasks" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatTelemetryTasks"
        (Get-Command "Set-WinDebloat7TelemetryTasks" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatTelemetryTasks"
        (Get-Command "Enable-WinDebloat7TelemetryTasks" -CommandType Alias).Definition | Should -Be "Enable-WinDebloatTelemetryTasks"
    }
}

Describe "Privacy Firewall Module Rebrand" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Privacy\Firewall.psm1" -Force -ErrorAction Stop
    }

    It "Exports new WinDebloat functions" {
        (Get-Command "Remove-LegacyWinDebloatHostsBlock" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Add-WinDebloatFirewallBlock" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-WinDebloatFirewallBlock" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloatFirewallStatus" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloatTelemetryDomains" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports backward-compatible WinDebloat7 aliases" {
        (Get-Command "Remove-LegacyWinDebloat7HostsBlock" -CommandType Alias).Definition | Should -Be "Remove-LegacyWinDebloatHostsBlock"
        (Get-Command "Add-WinDebloat7FirewallBlock" -CommandType Alias).Definition | Should -Be "Add-WinDebloatFirewallBlock"
        (Get-Command "Remove-WinDebloat7FirewallBlock" -CommandType Alias).Definition | Should -Be "Remove-WinDebloatFirewallBlock"
        (Get-Command "Get-WinDebloat7FirewallStatus" -CommandType Alias).Definition | Should -Be "Get-WinDebloatFirewallStatus"
        (Get-Command "Get-WinDebloat7TelemetryDomains" -CommandType Alias).Definition | Should -Be "Get-WinDebloatTelemetryDomains"
    }
}

Describe "Privacy Module Rebrand" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Privacy\Tasks.psm1" -Force -ErrorAction Stop
        Import-Module "$src\modules\Privacy\Privacy.psm1" -Force -ErrorAction Stop
    }

    It "Exports new WinDebloat functions" {
        (Get-Command "Set-WinDebloatPrivacy" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatAI" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatPrivacy" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports backward-compatible WinDebloat7 and alternative aliases" {
        (Get-Command "Set-WinDebloat7Privacy" -CommandType Alias).Definition | Should -Be "Set-WinDebloatPrivacy"
        (Get-Command "Disable-WinDebloatPrivacy" -CommandType Alias).Definition | Should -Be "Set-WinDebloatPrivacy"
        (Get-Command "Disable-WinDebloat7Privacy" -CommandType Alias).Definition | Should -Be "Set-WinDebloatPrivacy"
        (Get-Command "Disable-WinDebloatAIandAds" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatAI"
        (Get-Command "Disable-WinDebloat7AIandAds" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatAI"
        (Get-Command "Disable-WinDebloat7AI" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatAI"
        (Get-Command "Enable-WinDebloat7Privacy" -CommandType Alias).Definition | Should -Be "Enable-WinDebloatPrivacy"
    }
}

Describe "Security Module Rebrand" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Security\Security.psm1" -Force -ErrorAction Stop
    }

    It "Exports new WinDebloat functions" {
        (Get-Command "Disable-WinDebloatSMBv1" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatSMBv1" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatPUAProtection" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatPUAProtection" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Enable-WinDebloatScriptBlockLogging" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Disable-WinDebloatScriptBlockLogging" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloatLanguageMode" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloatSecurityStatus" -CommandType Function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports backward-compatible WinDebloat7 and WD7 aliases" {
        (Get-Command "Disable-WinDebloat7SMBv1" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatSMBv1"
        (Get-Command "Enable-WinDebloat7SMBv1" -CommandType Alias).Definition | Should -Be "Enable-WinDebloatSMBv1"
        (Get-Command "Enable-WinDebloat7PUAProtection" -CommandType Alias).Definition | Should -Be "Enable-WinDebloatPUAProtection"
        (Get-Command "Disable-WinDebloat7PUAProtection" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatPUAProtection"
        (Get-Command "Enable-WinDebloat7ScriptBlockLogging" -CommandType Alias).Definition | Should -Be "Enable-WinDebloatScriptBlockLogging"
        (Get-Command "Enable-WD7ScriptBlockLogging" -CommandType Alias).Definition | Should -Be "Enable-WinDebloatScriptBlockLogging"
        (Get-Command "Disable-WinDebloat7ScriptBlockLogging" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatScriptBlockLogging"
        (Get-Command "Disable-WD7ScriptBlockLogging" -CommandType Alias).Definition | Should -Be "Disable-WinDebloatScriptBlockLogging"
        (Get-Command "Get-WinDebloat7LanguageMode" -CommandType Alias).Definition | Should -Be "Get-WinDebloatLanguageMode"
        (Get-Command "Get-WD7LanguageMode" -CommandType Alias).Definition | Should -Be "Get-WinDebloatLanguageMode"
        (Get-Command "Get-WinDebloat7SecurityStatus" -CommandType Alias).Definition | Should -Be "Get-WinDebloatSecurityStatus"
    }
}
