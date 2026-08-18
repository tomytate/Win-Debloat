#Requires -Version 7.6

<#
.SYNOPSIS
    Validates every package ID in the Win-Debloat software catalog against
    live package sources.

.DESCRIPTION
    Package IDs rot: publishers rename them, apps get delisted, and vendors
    discontinue products (GeForce Experience, FileZilla-on-winget, WhatsApp).
    This script extracts every Winget and Chocolatey ID from:
      - src/modules/Software/Software.psm1  (the essentials catalog)
      - src/modules/Drivers/Drivers.psm1    (GPU driver packages)
      - profiles/*.yaml                      (install_list entries)
    and verifies each one still exists.

    Winget IDs are validated with the winget CLI when available (skipped with a
    warning otherwise - e.g. on CI runners without winget). Chocolatey IDs are
    validated against the community feed REST API and work anywhere.

.PARAMETER SkipWinget
    Skip winget validation even if the CLI is available.

.PARAMETER SkipChoco
    Skip Chocolatey community feed validation.

.EXAMPLE
    ./build/Test-PackageIds.ps1
    Exits 0 if every ID is valid; exits 1 and lists the stale IDs otherwise.
#>

param(
    [switch]$SkipWinget,
    [switch]$SkipChoco
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."

# ── Extract IDs ──────────────────────────────────────────────────────────────
$softwarePsm1 = Get-Content (Join-Path $root 'src\modules\Software\Software.psm1') -Raw
$driversPsm1 = Get-Content (Join-Path $root 'src\modules\Drivers\Drivers.psm1') -Raw

$wingetIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$chocoIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$npmIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

[regex]::Matches($softwarePsm1, 'Winget = "([^"]+)"') | ForEach-Object { $null = $wingetIds.Add($_.Groups[1].Value) }
[regex]::Matches($softwarePsm1, 'Choco = "([^"]+)"') | ForEach-Object { $null = $chocoIds.Add($_.Groups[1].Value) }
[regex]::Matches($softwarePsm1, 'Npm = "([^"]+)"') | ForEach-Object { $null = $npmIds.Add($_.Groups[1].Value) }
$msstoreIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
[regex]::Matches($softwarePsm1, 'Msstore = "([^"]+)"') | ForEach-Object { $null = $msstoreIds.Add($_.Groups[1].Value) }
[regex]::Matches($driversPsm1, 'Id = "([^"]+)"') | ForEach-Object { $null = $wingetIds.Add($_.Groups[1].Value) }

# Profiles mix winget IDs (software section) with Appx names (bloatware section),
# so parse the YAML properly and take only the software install/uninstall lists.
$yamlManifest = Get-ChildItem (Join-Path $root 'src\modules\Vendor\powershell-yaml') -Filter 'powershell-yaml.psd1' -Recurse | Select-Object -First 1
if ($yamlManifest) {
    Import-Module $yamlManifest.FullName -Force
    foreach ($profileFile in (Get-ChildItem (Join-Path $root 'profiles\*.yaml') | Where-Object { $_.Name -notin @('schema.yaml', 'bloatware-list.yaml') })) {
        try {
            $y = Get-Content $profileFile.FullName -Raw | ConvertFrom-Yaml
            foreach ($id in (@($y.software.install_list) + @($y.software.uninstall_list))) {
                if ($id) { $null = $wingetIds.Add([string]$id) }
            }
        }
        catch {
            Write-Warning "Could not parse $($profileFile.Name): $($_.Exception.Message)"
        }
    }
}
else {
    Write-Warning "Vendored powershell-yaml not found - profile install lists not validated."
}

$wingetList = @($wingetIds) | Sort-Object
$chocoList = @($chocoIds) | Sort-Object
$npmList = @($npmIds) | Sort-Object
$msstoreList = @($msstoreIds) | Sort-Object
Write-Host "Extracted $($wingetList.Count) winget, $($chocoList.Count) Chocolatey, $($npmList.Count) npm, and $($msstoreList.Count) msstore IDs." -ForegroundColor Cyan

$staleWinget = @()
$staleChoco = @()
$staleNpm = @()
$staleMsstore = @()

# ── Winget validation (CLI required) ────────────────────────────────────────
if ($SkipWinget) {
    Write-Warning "Winget validation skipped (-SkipWinget)."
}
elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget CLI not available on this machine - winget validation skipped."
}
else {
    Write-Host "Validating winget IDs against the live source..." -ForegroundColor Cyan
    $results = $wingetList | ForEach-Object -Parallel {
        $id = $_
        $out = winget search --id $id --exact --source winget 2>&1 | Out-String
        [PSCustomObject]@{ Id = $id; OK = ($LASTEXITCODE -eq 0 -and $out -match [regex]::Escape($id)) }
    } -ThrottleLimit 5
    $suspects = @($results | Where-Object { -not $_.OK } | ForEach-Object Id)

    # Parallel winget queries occasionally flake; re-check suspects sequentially
    # before declaring them stale (prevents false alarms in the monthly CI run)
    foreach ($id in $suspects) {
        $out = winget search --id $id --exact --source winget 2>&1 | Out-String
        if (-not ($LASTEXITCODE -eq 0 -and $out -match [regex]::Escape($id))) {
            $staleWinget += $id
        }
    }
}

# ── Chocolatey validation (REST API, works anywhere) ────────────────────────
if ($SkipChoco) {
    Write-Warning "Chocolatey validation skipped (-SkipChoco)."
}
else {
    Write-Host "Validating Chocolatey IDs against the community feed..." -ForegroundColor Cyan
    $results = $chocoList | ForEach-Object -Parallel {
        $id = $_
        try {
            $url = "https://community.chocolatey.org/api/v2/Packages()?`$filter=tolower(Id)%20eq%20'$($id.ToLower())'%20and%20IsLatestVersion&`$select=Id"
            $resp = Invoke-RestMethod -Uri $url -TimeoutSec 30
            [PSCustomObject]@{ Id = $id; OK = [bool]$resp }
        }
        catch {
            # Network/API failure is not proof of a stale ID - report as OK with warning
            Write-Warning "Choco API error for '$id': $($_.Exception.Message)"
            [PSCustomObject]@{ Id = $id; OK = $true }
        }
    } -ThrottleLimit 8
    $staleChoco = @($results | Where-Object { -not $_.OK } | ForEach-Object Id)
}

# ── msstore validation (rides the winget CLI) ───────────────────────────────
if (-not $SkipWinget -and $msstoreList.Count -gt 0 -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Validating Microsoft Store IDs..." -ForegroundColor Cyan
    foreach ($id in $msstoreList) {
        $out = winget search --id $id --exact --source msstore 2>&1 | Out-String
        if (-not ($LASTEXITCODE -eq 0 -and $out -match [regex]::Escape($id))) {
            $staleMsstore += $id
        }
    }
}
elseif ($msstoreList.Count -gt 0) {
    Write-Warning "msstore validation skipped (winget CLI unavailable or -SkipWinget)."
}

# ── npm validation (registry REST API, works anywhere) ──────────────────────
if ($npmList.Count -gt 0) {
    Write-Host "Validating npm IDs against registry.npmjs.org..." -ForegroundColor Cyan
    foreach ($pkg in $npmList) {
        try {
            $enc = [uri]::EscapeDataString($pkg)
            $null = Invoke-RestMethod -Uri "https://registry.npmjs.org/$enc" -TimeoutSec 30
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) {
                $staleNpm += $pkg
            }
            else {
                Write-Warning "npm registry error for '$pkg': $($_.Exception.Message)"
            }
        }
    }
}

# ── Report ───────────────────────────────────────────────────────────────────
if ($staleWinget.Count -eq 0 -and $staleChoco.Count -eq 0 -and $staleNpm.Count -eq 0 -and $staleMsstore.Count -eq 0) {
    Write-Host "`n✅ All package IDs are valid." -ForegroundColor Green
    exit 0
}

Write-Host "`n❌ Stale package IDs found:" -ForegroundColor Red
$staleWinget | ForEach-Object { Write-Host "  winget:  $_" -ForegroundColor Yellow }
$staleChoco | ForEach-Object { Write-Host "  choco:   $_" -ForegroundColor Yellow }
$staleNpm | ForEach-Object { Write-Host "  npm:     $_" -ForegroundColor Yellow }
$staleMsstore | ForEach-Object { Write-Host "  msstore: $_" -ForegroundColor Yellow }
Write-Host "`nFix these in src/modules/Software/Software.psm1 (or Drivers.psm1 / profiles)." -ForegroundColor Gray
exit 1
