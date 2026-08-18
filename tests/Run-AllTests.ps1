[CmdletBinding()]
param(
    [ValidateSet('Normal', 'Detailed', 'Minimal', 'None')]
    [string]$Output = 'Detailed',
    [switch]$CI
)

$ErrorActionPreference = 'Stop'

# Ensure modern Pester is loaded
Import-Module Pester -MinimumVersion 5.0.0 -Force -ErrorAction SilentlyContinue

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     Starting Win-Debloat Test Suite     " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$testFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.Tests.ps1" -Recurse | Select-Object -ExpandProperty FullName

$loadedPester = Get-Module Pester
$hasPester5 = $loadedPester -and ($loadedPester.Version.Major -ge 5)

if ($hasPester5) {
    $pesterConfig = [PesterConfiguration]::Default
    $pesterConfig.Run.Path = @($PSScriptRoot)
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = $Output

    if ($CI) {
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = Join-Path $PSScriptRoot "TestResults.xml"
        $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
    }

    $result = Invoke-Pester -Configuration $pesterConfig
    $totalCount = $result.TotalCount
    $passedCount = $result.PassedCount
    $failedCount = $result.FailedCount
    $skippedCount = $result.SkippedCount
}
else {
    $result = Invoke-Pester -Script $testFiles -PassThru
    $totalCount = $result.TotalCount
    $passedCount = $result.PassedCount
    $failedCount = $result.FailedCount
    $skippedCount = $result.SkippedCount
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "             FINAL SUMMARY               " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Total Tests: $totalCount"
Write-Host "PASSED:      $passedCount" -ForegroundColor Green
Write-Host "FAILED:      $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
Write-Host "SKIPPED:     $skippedCount" -ForegroundColor Yellow

if ($failedCount -gt 0) {
    Write-Host "`nFAILURE: Some tests failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nSUCCESS: All tests passed." -ForegroundColor Green
exit 0
