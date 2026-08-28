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
    Verbosity of test runner output: Detailed, Normal, Minimal, None, Diagnostic.
.PARAMETER CI
    Enable CI mode with NUnit XML export and GitHub Step Summary generation.
.PARAMETER CodeCoverage
    Enable Code Coverage analysis across src/core and src/modules.
.PARAMETER Tag
    Optional tag filter array for Pester tests.
.PARAMETER ExcludeTag
    Optional tag exclusion filter array for Pester tests.
.PARAMETER FullName
    Optional wildcard filter for test full names.
.PARAMETER Direct
    Force direct in-process execution under Windows PowerShell without pwsh bootstrap.
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'AST', 'Integration')]
    [string]$Suite = 'All',

    [ValidateSet('Detailed', 'Normal', 'Minimal', 'None', 'Diagnostic')]
    [string]$Output = 'Detailed',

    [switch]$CI,
    [switch]$CodeCoverage,

    [string[]]$Tag,
    [string[]]$ExcludeTag,
    [string]$FullName,

    [switch]$Direct
)

$ErrorActionPreference = 'Stop'

# --- 1. PowerShell < 7.0 Bootstrap & Diagnostics ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    # Check if Pester 5.5+ is already available locally in Windows PowerShell
    $hasLocalPester55 = $false
    $localPester = Get-Module -ListAvailable -Name Pester |
        Where-Object { $_.Version -ge [version]'5.5.0' } |
        Select-Object -First 1
    if ($localPester) {
        $hasLocalPester55 = $true
    }

    # If Suite is Unit and local Pester 5.5+ is present (or -Direct specified), allow PS 5.1 direct execution
    $canRunDirectPS5 = ($Suite -eq 'Unit' -and $hasLocalPester55) -or $Direct

    if (-not $canRunDirectPS5) {
        # Locate pwsh executable
        $pwshExe = $null
        $pwshCmd = Get-Command -Name 'pwsh' -CommandType Application -ErrorAction SilentlyContinue
        if ($pwshCmd) {
            $pwshExe = $pwshCmd.Source
        }
        else {
            $candidatePaths = @(
                (Join-Path $env:USERPROFILE '.dotnet\tools\pwsh.exe'),
                (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
                (Join-Path ${env:ProgramFiles(x86)} 'PowerShell\7\pwsh.exe'),
                (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe')
            )
            foreach ($candidate in $candidatePaths) {
                if ($candidate -and (Test-Path -LiteralPath $candidate)) {
                    $pwshExe = $candidate
                    break
                }
            }
        }

        if ($pwshExe) {
            Write-Host "[Runner] PowerShell $($PSVersionTable.PSVersion) detected. Bootstrapping test execution under PowerShell 7+ ($pwshExe)..." -ForegroundColor Cyan
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
            foreach ($key in $PSBoundParameters.Keys) {
                $val = $PSBoundParameters[$key]
                if ($val -is [switch] -or $val -is [bool]) {
                    if ($val) { $argList += "-$key" }
                }
                elseif ($val -is [array]) {
                    $argList += "-$key"
                    $argList += ($val -join ',')
                }
                else {
                    $argList += "-$key"
                    $argList += "`"$val`""
                }
            }
            $proc = Start-Process -FilePath $pwshExe -ArgumentList $argList -NoNewWindow -PassThru -Wait
            exit $proc.ExitCode
        }
        else {
            Write-Warning "[Runner] PowerShell $($PSVersionTable.PSVersion) detected and pwsh.exe was not found in PATH or standard locations."
            Write-Warning "[Runner] Full test suites (AST Parity and Integration) require PowerShell 7.6+."
            Write-Warning "[Runner] To install PowerShell 7+: Run 'winget install Microsoft.PowerShell' or 'dotnet tool install --global PowerShell'."

            if (-not $hasLocalPester55) {
                Write-Error @"
[Runner] Neither PowerShell 7+ (pwsh) nor Pester 5.5.0+ was found.
Windows PowerShell built-in Pester (v3.4.0) is not supported.
To run tests under Windows PowerShell 5.1, install Pester 5.5+ via:
    Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
"@
                exit 1
            }
        }
    }
}

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "     Win-Debloat v1.6.0 Enterprise Test Harness        " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Suite: $Suite | Output: $Output | CI: $CI | PS: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# --- 2. Run AST Static Parity Engine if Suite is AST or All ---
if ($Suite -in @('All', 'AST')) {
    $astScript = Join-Path $PSScriptRoot "AST\Test-WinDebloatAstExportParity.ps1"
    if (Test-Path -LiteralPath $astScript) {
        Write-Host "`n[AST Engine] Executing 5-Way Parity Verification..." -ForegroundColor Yellow
        try {
            & $astScript
            Write-Host "[AST Engine] [OK] Parity Verification Passed." -ForegroundColor Green
        }
        catch {
            Write-Host "[AST Engine] [FAIL] Parity Verification Failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($CI) { exit 1 }
        }
    }
    if ($Suite -eq 'AST') { exit 0 }
}

# --- 3. Resolve Test Paths Based on Suite Filter ---
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

# --- 4. Explicit Import of Pester 5.5+ (Prevent Legacy 3.4.0 Fallback) ---
$loadedPester = Get-Module -Name Pester
if ($loadedPester -and ($loadedPester.Version -lt [version]'5.5.0')) {
    Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
}

$pesterMod = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge [version]'5.5.0' } |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1

if ($pesterMod) {
    Import-Module -Name $pesterMod.Path -Force -ErrorAction Stop
}
else {
    Import-Module -Name Pester -MinimumVersion 5.5.0 -Force -ErrorAction SilentlyContinue
}

$loadedPester = Get-Module -Name Pester
if (-not ($loadedPester -and ($loadedPester.Version -ge [version]'5.5.0'))) {
    $foundVer = if ($loadedPester) { $loadedPester.Version.ToString() } else { "none" }
    Write-Error @"
[Runner] Pester 5.5.0 or higher is strictly required (found: $foundVer).
Windows PowerShell built-in Pester (v3.4.0) is not supported.
Please install the latest Pester module by running:
    Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
"@
    exit 1
}

# --- 5. Clean Pester 5 Configuration Container Construction ---
$pesterConfig = New-PesterConfiguration

# Run options
$pesterConfig.Run.Path = $testPaths
$pesterConfig.Run.PassThru = $true
$pesterConfig.Run.Exit = $false

# Filter options
if ($Tag) {
    $pesterConfig.Filter.Tag = $Tag
}
if ($ExcludeTag) {
    $pesterConfig.Filter.ExcludeTag = $ExcludeTag
}
if ($FullName) {
    $pesterConfig.Filter.FullName = $FullName
}

# Output options
$pesterConfig.Output.Verbosity = $Output
if ($CI) {
    $pesterConfig.Output.CIFormat = 'GithubActions'
}

# TestResult options
if ($CI) {
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $PSScriptRoot "TestResults.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
    $pesterConfig.TestResult.TestSuiteName = 'Win-Debloat'
}

# CodeCoverage options
if ($CodeCoverage) {
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = @(
        Join-Path $PSScriptRoot "..\src\core\*.psm1",
        Join-Path $PSScriptRoot "..\src\modules\**\*.psm1"
    )
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $PSScriptRoot "Coverage.xml"
    $pesterConfig.CodeCoverage.OutputFormat = 'Cobertura'
}

# --- 6. Execute Test Suite ---
$result = Invoke-Pester -Configuration $pesterConfig
$totalCount   = $result.TotalCount
$passedCount  = $result.PassedCount
$failedCount  = $result.FailedCount
$skippedCount = $result.SkippedCount

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

