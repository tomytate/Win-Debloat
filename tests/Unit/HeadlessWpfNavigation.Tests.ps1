#Requires -Module Pester

<#
.SYNOPSIS
    Pester Unit & Performance Tests for Win-Debloat WPF UI Navigation.

.DESCRIPTION
    Executes headless WPF navigation tests in an STA thread, verifying that
    btnNavDashboard, btnNavBloatware, btnNavPrivacy, btnNavPerformance, btnNavNetwork,
    btnNavTweaks, and btnNavSettings toggle views cleanly with zero exceptions,
    zero hangs, and under 50ms latency.
#>

Describe "Headless WPF UI Navigation" -Tag "GUI", "Navigation", "Unit" {
    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot/../..").Path
        $runnerScript = Join-Path $root "tests\Test-HeadlessWpfNavigation.ps1"
        
        if (-not (Test-Path $runnerScript)) {
            throw "Test runner not found at: $runnerScript"
        }

        # Run headless WPF navigation test suite
        $script:results = & $runnerScript -LatencyThresholdMs 50 -StressCycles 10
    }

    Context "1. XAML Structure & Headless Loading" {
        It "Loads MainWindow.xaml in STA thread without errors" {
            $loadTest = $script:results | Where-Object { $_.TestName -eq "XAML Headless Load" }
            $loadTest | Should -Not -BeNullOrEmpty
            $loadTest.Passed | Should -Be $true
            $loadTest.Exceptions | Should -Be 0
            $loadTest.Hangs | Should -Be 0
        }
    }

    Context "2. Individual Navigation Buttons (<50ms Latency)" {
        It "Simulates clicking btnNavDashboard cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavDashboard' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }

        It "Simulates clicking btnNavBloatware cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavBloatware' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }

        It "Simulates clicking btnNavPrivacy cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavPrivacy' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }

        It "Simulates clicking btnNavPerformance cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavPerformance' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }

        It "Simulates clicking btnNavNetwork cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavNetwork' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }

        It "Simulates clicking btnNavTweaks cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavTweaks' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }

        It "Simulates clicking btnNavSettings cleanly with zero exceptions, zero hangs, and latency < 50ms" {
            $btnTest = $script:results | Where-Object { $_.TargetControl -eq 'btnNavSettings' }
            $btnTest | Should -Not -BeNullOrEmpty
            $btnTest.Passed | Should -Be $true
            $btnTest.Exceptions | Should -Be 0
            $btnTest.Hangs | Should -Be 0
            $btnTest.DurationMs | Should -BeLessThan 50
            $btnTest.VerifiedState | Should -Be "Clean Visibility Toggle"
        }
    }

    Context "3. Rapid Navigation Cycling Stress Test" {
        It "Performs 70 sequential transitions with zero exceptions and latency < 50ms" {
            $stressTest = $script:results | Where-Object { $_.TestName -like "Rapid Cyclic Stress Test*" }
            $stressTest | Should -Not -BeNullOrEmpty
            $stressTest.Passed | Should -Be $true
            $stressTest.Exceptions | Should -Be 0
            $stressTest.Hangs | Should -Be 0
            $stressTest.DurationMs | Should -BeLessThan 50
        }
    }
}
