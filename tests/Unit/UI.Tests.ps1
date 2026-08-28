#Requires -Version 7.6

<#
.SYNOPSIS
    Unit tests for Win-Debloat UI Modules (Colors.psm1 & Menu.psm1).
#>

Describe "UI.Colors Module" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\ui\Colors.psm1" -Force -ErrorAction Stop
    }

    Context "Get-WD7AnsiColor" {
        It "Converts valid 6-digit hex string to ANSI 24-bit TrueColor escape sequence" {
            $ansi = Get-WD7AnsiColor -Hex "#00D4FF"
            $ansi | Should -Be "$([char]27)[38;2;0;212;255m"
        }

        It "Converts pure white and black hex codes" {
            $white = Get-WD7AnsiColor -Hex "#FFFFFF"
            $white | Should -Be "$([char]27)[38;2;255;255;255m"

            $black = Get-WD7AnsiColor -Hex "#000000"
            $black | Should -Be "$([char]27)[38;2;0;0;0m"
        }

        It "Returns empty string for invalid hex values" {
            Get-WD7AnsiColor -Hex "INVALID" | Should -Be ""
            Get-WD7AnsiColor -Hex "#12345" | Should -Be ""
            Get-WD7AnsiColor -Hex "123456" | Should -Be ""
        }
    }

    Context "Get-WD7GradientText" {
        It "Interpolates linear RGB gradient across string characters" {
            $grad = Get-WD7GradientText -Text "Apex" -StartColor "#000000" -EndColor "#FFFFFF"
            $grad | Should -Not -BeNullOrEmpty
            $grad | Should -Match "\e\[38;2;0;0;0m"
            $grad | Should -Match "\e\[38;2;255;255;255m"
            $grad | Should -Match "\e\[0m"
        }

        It "Resolves named theme colors correctly" {
            $grad = Get-WD7GradientText -Text "Win-Debloat" -StartColor "Primary" -EndColor "Secondary"
            $grad | Should -Not -BeNullOrEmpty
            ($grad -replace "\e\[[0-9;]*m", "") | Should -Be "Win-Debloat"
        }

        It "Supports LineByLine mode for multiline text blocks" {
            $multiline = "Line 1`nLine 2`nLine 3"
            $grad = Get-WD7GradientText -Text $multiline -StartColor "Primary" -EndColor "Secondary" -LineByLine
            $lines = $grad -split "\r?\n"
            $lines.Count | Should -Be 3
        }

        It "Handles single character or empty string gracefully" {
            Get-WD7GradientText -Text "" | Should -Be ""
            $single = Get-WD7GradientText -Text "X" -StartColor "Primary" -EndColor "Secondary"
            $single | Should -Match "X"
        }
    }

    Context "Format-WD7Hyperlink" {
        It "Generates valid OSC 8 terminal hyperlink sequence" {
            $link = Format-WD7Hyperlink -Text "Win-Debloat Docs" -Url "https://github.com/tomytate/Win-Debloat"
            $link | Should -Not -BeNullOrEmpty
            $link | Should -Match "Win-Debloat Docs"
        }

        It "Handles empty or null inputs gracefully" {
            Format-WD7Hyperlink -Text "" -Url "https://example.com" | Should -Be ""
            Format-WD7Hyperlink -Text "Label" -Url "" | Should -Be "Label"
        }
    }

    Context "UI.Colors Helper Cmdlets and Aliases" {
        It "Exports all expected functions and backward-compatible aliases" {
            (Get-Command "Get-WD7AnsiColor" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Get-WD7GradientText" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Get-WinDebloatGradientText" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Get-WinDebloat7GradientText" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Format-WD7Hyperlink" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Format-WinDebloatHyperlink" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Format-WinDebloat7Hyperlink" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Write-WD7Host" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-WD7Header" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-WD7Separator" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-WD7Progress" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-WD7StatusBadge" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }

        It "Executes Show-WD7Separator and Show-WD7StatusBadge without error" {
            { Show-WD7Separator -Title "TEST SEPARATOR" -Color "Primary" } | Should -Not -Throw
            { Show-WD7StatusBadge -Label "All Systems Operational" -Status "Success" } | Should -Not -Throw
        }
    }
}

Describe "UI.Menu Module" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\core\Config.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\ui\Colors.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\ui\Menu.psm1" -Force -ErrorAction Stop
    }

    Context "TUI Breadcrumbs and Feedback Helpers" {
        It "Renders Show-WD7Breadcrumb without error" {
            { Show-WD7Breadcrumb -Path @("Main Menu", "Tweaks", "UI") } | Should -Not -Throw
        }

        It "Renders Show-WD7ActionResult card without error" {
            { Show-WD7ActionResult -Title "Tweak Applied" -Detail "Context menu restored" -Status "Success" } | Should -Not -Throw
            { Show-WD7ActionResult -Title "Warning Notice" -Detail "Snapshot required" -Status "Warning" } | Should -Not -Throw
            { Show-WD7ActionResult -Title "Error Encountered" -Detail "Access denied" -Status "Error" } | Should -Not -Throw
        }
    }

    Context "Get-WinDebloatProfileSummary" {
        It "Retrieves metadata summary for known default profiles" {
            $modProfile = Join-Path $PSScriptRoot "..\..\profiles\moderate.yaml"
            if (Test-Path $modProfile) {
                $summary = Get-WinDebloatProfileSummary -FilePath $modProfile
                $summary | Should -Not -BeNullOrEmpty
                $summary.BaseName | Should -Be "moderate"
                $summary.EstTime | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Menu Module Exports & Aliases" {
        It "Exports all menu functions and aliases" {
            (Get-Command "Show-MainMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-TweaksMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-UICustomizationMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-SearchSuggestionsMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-SystemQoLMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-AdvancedRemovalMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-ServicesMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-ProfileSelection" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-ProfilePreview" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Invoke-Profile" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-SystemInfo" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-SnapshotMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-NetworkPrivacyMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-RepairMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-FeaturesMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Show-IntegrationsMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Get-WinDebloatProfileSummary" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Get-WinDebloat7ProfileSummary" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Invoke-WinDebloatBenchmark" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Invoke-WinDebloat7Benchmark" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }
    }
}
