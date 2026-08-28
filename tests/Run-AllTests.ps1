<#
.SYNOPSIS
    Universal Test Runner for Win-Debloat Test Suite (v1.6.0).
.DESCRIPTION
    Runs unit, integration, and AST parity test suites across PowerShell 5.1 and 7.6+.
    Supports Pester 5.5+/6.x configurations, code coverage metrics, NUnit XML export,
    Cobertura code coverage XML, and GitHub Actions step summaries.
.PARAMETER Suite
    Test suite to run: Unit, AST, Integration, or All (default).
.PARAMETER Output
    Verbosity of test runner output: Detailed, Normal, Minimal, None.
.PARAMETER CI
    Enable CI mode with NUnit XML export and GitHub Step Summary generation.
.PARAMETER CodeCoverage
    Enable Code Coverage analysis across src/core and src/modules.
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'AST', 'Integration')]
    [string]$Suite = 'All',

    [ValidateSet('Detailed', 'Normal', 'Minimal', 'None')]
    [string]$Output = 'Detailed',

    [switch]$CI,
    [switch]$CodeCoverage
)

$ErrorActionPreference = 'Stop'

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "     Win-Debloat v1.6.0 Enterprise Test Harness        " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Suite: $Suite | Output: $Output | CI: $CI | PS: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# 1. Run AST Static Parity Engine if Suite is AST or All
if ($Suite -in @('All', 'AST')) {
    $astScript = Join-Path $PSScriptRoot "AST\Test-WinDebloatAstExportParity.ps1"
    if (Test-Path $astScript) {
        Write-Host "`n[AST Engine] Executing 5-Way Parity Verification..." -ForegroundColor Yellow
        try {
            & $astScript
            Write-Host "[AST Engine] ✅ Parity Verification Passed." -ForegroundColor Green
        }
        catch {
            Write-Host "[AST Engine] ❌ Parity Verification Failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($CI) { exit 1 }
        }
    }
    if ($Suite -eq 'AST') { exit 0 }
}

# 2. Resolve Test Files Based on Suite Filter
$testPaths = @()
switch ($Suite) {
    'Unit' {
        $testPaths = @(Join-Path $PSScriptRoot "Unit")
    }
    'Integration' {
        $testPaths = @(Get-ChildItem -Path $PSScriptRoot -Filter "*.Tests.ps1" | Where-Object { $_.DirectoryName -eq $PSScriptRoot } | Select-Object -ExpandProperty FullName)
    }
    'All' {
        $testPaths = @($PSScriptRoot)
    }
}

# Ensure Pester 5/6+ is loaded
$pesterMod = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1
if ($pesterMod) {
    Import-Module $pesterMod.Path -Force -ErrorAction SilentlyContinue
}
else {
    Import-Module Pester -MinimumVersion 5.0.0 -Force -ErrorAction SilentlyContinue
}
$loadedPester = Get-Module Pester
$hasPester5 = $loadedPester -and ($loadedPester.Version.Major -ge 5)

if ($hasPester5) {
    $pesterConfig = [PesterConfiguration]::Default
    $pesterConfig.Run.Path = $testPaths
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = $Output

    if ($CI) {
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = Join-Path $PSScriptRoot "TestResults.xml"
        $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
    }

    if ($CodeCoverage) {
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @(
            Join-Path $PSScriptRoot "..\src\core\*.psm1",
            Join-Path $PSScriptRoot "..\src\modules\**\*.psm1"
        )
        $pesterConfig.CodeCoverage.OutputPath = Join-Path $PSScriptRoot "Coverage.xml"
        $pesterConfig.CodeCoverage.OutputFormat = 'Cobertura'
    }

    $result = Invoke-Pester -Configuration $pesterConfig
    $totalCount   = $result.TotalCount
    $passedCount  = $result.PassedCount
    $failedCount  = $result.FailedCount
    $skippedCount = $result.SkippedCount
}
else {
    $testFiles = Get-ChildItem -Path $testPaths -Filter "*.Tests.ps1" -Recurse | Select-Object -ExpandProperty FullName
    $result = Invoke-Pester -Script $testFiles -PassThru
    $totalCount   = $result.TotalCount
    $passedCount  = $result.PassedCount
    $failedCount  = $result.FailedCount
    $skippedCount = $result.SkippedCount
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "                 TEST HARNESS SUMMARY                  " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $totalCount"
Write-Host "PASSED:      $passedCount" -ForegroundColor Green
Write-Host "FAILED:      $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
Write-Host "SKIPPED:     $skippedCount" -ForegroundColor Yellow

# GitHub Actions Step Summary
if ($CI -and $env:GITHUB_STEP_SUMMARY) {
    $summaryMd = @"
## 🧪 Win-Debloat Test Suite Results (v1.6.0)

| Metric | Count | Status |
| :--- | :--- | :--- |
| **Total Tests** | `$totalCount` | ℹ️ |
| **Passed** | `$passedCount` | ✅ |
| **Failed** | `$failedCount` | $(if ($failedCount -gt 0) { '❌' } else { '✅' }) |
| **Skipped** | `$skippedCount` | ⚠️ |

*PowerShell Version: `$($PSVersionTable.PSVersion)` on `$($env:OS)`*
"@
    Set-Content -Path $env:GITHUB_STEP_SUMMARY -Value $summaryMd -Encoding UTF8
}

if ($failedCount -gt 0) {
    Write-Host "`nFAILURE: $failedCount test(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nSUCCESS: All tests passed with zero defects." -ForegroundColor Green
exit 0
