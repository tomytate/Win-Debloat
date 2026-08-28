Describe "Config Profile Inheritance and When Gates" {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module "$root\src\core\Logger.psm1" -Force
        Import-Module "$root\src\core\Config.psm1" -Force
    }

    Context "Test-WinDebloatWhenGate Evaluation" {
        It "Should return true for null or empty condition" {
            Test-WinDebloatWhenGate -WhenCondition $null | Should -Be $true
        }

        It "Should match valid build bounds" {
            $cond = @{ min_build = 22000; max_build = 26200 }
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetBuild 22631 | Should -Be $true
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetBuild 19045 | Should -Be $false
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetBuild 27600 | Should -Be $false
        }

        It "Should match target OS correctly" {
            $cond = @{ target_os = @("Windows 11", "Server 2025") }
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetOS "Windows 11" | Should -Be $true
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetOS "Windows 10" | Should -Be $false
        }

        It "Should match architecture correctly" {
            $cond = @{ arch = @("x64") }
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetArch "x64" | Should -Be $true
            Test-WinDebloatWhenGate -WhenCondition $cond -TargetArch "arm64" | Should -Be $false
        }
    }

    Context "Merge-WinDebloatConfigDictionaries" {
        It "Should deep merge child properties over base properties" {
            $base = [ordered]@{
                privacy = [ordered]@{
                    disable_copilot = $false
                    telemetry_level = "Basic"
                }
            }
            $override = [ordered]@{
                privacy = [ordered]@{
                    disable_copilot = $true
                }
            }
            $merged = Merge-WinDebloatConfigDictionaries -BaseDict $base -OverrideDict $override
            $merged.privacy.disable_copilot | Should -Be $true
            $merged.privacy.telemetry_level | Should -Be "Basic"
        }

        It "Should perform set union on array lists" {
            $base = [ordered]@{
                bloatware = [ordered]@{
                    exclude_list = @("Microsoft.WindowsStore", "Microsoft.WindowsCalculator")
                }
            }
            $override = [ordered]@{
                bloatware = [ordered]@{
                    exclude_list = @("Microsoft.WindowsTerminal", "Microsoft.WindowsStore")
                }
            }
            $merged = Merge-WinDebloatConfigDictionaries -BaseDict $base -OverrideDict $override
            $merged.bloatware.exclude_list.Count | Should -Be 3
            $merged.bloatware.exclude_list | Should -Contain "Microsoft.WindowsTerminal"
        }
    }
}
