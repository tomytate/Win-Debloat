$ErrorActionPreference = 'Stop'

Write-Host "== Win-Debloat7 Installer (Standard Edition) ==" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# 1. Get Latest Release Info from GitHub API
$Repo = "tomytate/Win-Debloat"
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"

try {
    Write-Host " -> Fetching latest version info..." -NoNewline
    $Release = Invoke-RestMethod -Uri $ApiUrl
    Write-Host " [OK] ($($Release.tag_name))" -ForegroundColor Green
}
catch {
    Write-Host " [ERROR]" -ForegroundColor Red
    throw "Failed to fetch release info: $($_.Exception.Message). Check your internet connection."
}

# 2. Find the Standard Edition Asset (Single-File EXE)
$isArm64 = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64
$preferredNames = if ($isArm64) {
    @("Win-Debloat-arm64.exe", "Win-Debloat.exe", "Win-Debloat7.exe")
} else {
    @("Win-Debloat.exe", "Win-Debloat7.exe", "Win-Debloat-arm64.exe")
}

$Asset = $null
foreach ($name in $preferredNames) {
    $Asset = $Release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if ($Asset) { break }
}

if (-not $Asset) {
    throw "Could not find a valid release asset for Standard Edition."
}

# 3. Setup Temp Directory
$TempDir = "$env:TEMP\Win-Debloat7-Install"
$ArtifactPath = "$TempDir\$($Asset.name)"

if (Test-Path -LiteralPath $TempDir) {
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# 4. Download and Verify with Fail-Closed Security
$isVerified = $false

try {
    # 4a. Retrieve Authoritative SHA256 Checksum Manifest
    Write-Host " -> Fetching Checksum Manifest..." -NoNewline
    $SumsAsset = $Release.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1
    if (-not $SumsAsset) {
        Write-Host " [MISSING]" -ForegroundColor Red
        $global:LASTEXITCODE = 1
        throw [System.Security.SecurityException]"CRITICAL SECURITY ERROR: Checksum manifest 'SHA256SUMS.txt' missing from release $($Release.tag_name). Fail-closed policy prevents installation."
    }

    try {
        $SumsContent = (Invoke-RestMethod -Uri $SumsAsset.browser_download_url).Trim()
        Write-Host " [OK]" -ForegroundColor Green
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        $global:LASTEXITCODE = 1
        throw [System.Security.SecurityException]"CRITICAL SECURITY ERROR: Failed to download checksum manifest from $($SumsAsset.browser_download_url): $($_.Exception.Message)"
    }

    # 4b. Parse Authoritative Expected Hash for Target Asset
    $expectedHash = $null
    $lines = $SumsContent -split "[\r\n]+"
    foreach ($line in $lines) {
        if ($line -match '^\s*([a-fA-F0-9]{64})\s+[*]?(.+?)\s*$') {
            $entryHash = $Matches[1].ToUpperInvariant()
            $entryFile = [System.IO.Path]::GetFileName($Matches[2].Trim())
            if ($entryFile.Equals($Asset.name, [System.StringComparison]::OrdinalIgnoreCase)) {
                $expectedHash = $entryHash
                break
            }
        }
    }

    if (-not $expectedHash) {
        $global:LASTEXITCODE = 1
        throw [System.Security.SecurityException]"CRITICAL SECURITY ERROR: No authoritative SHA256 entry found for '$($Asset.name)' in release manifest."
    }

    # 4c. Download Target Binary
    Write-Host " -> Downloading Standard Edition ($($Asset.name))..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $ArtifactPath -UseBasicParsing

    if (-not (Test-Path -LiteralPath $ArtifactPath)) {
        throw [System.IO.FileNotFoundException]"Target download file '$ArtifactPath' does not exist."
    }

    # 4d. Cryptographic Integrity Verification
    Write-Host " -> Verifying Integrity..." -NoNewline
    $actualHash = (Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash.ToUpperInvariant()

    if ($actualHash -ne $expectedHash) {
        Write-Host " [INVALID]" -ForegroundColor Red
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "               CRITICAL SECURITY INTEGRITY ERROR                " -ForegroundColor Red
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "SHA256 checksum mismatch for $($Asset.name)!" -ForegroundColor Red
        Write-Host "  Expected: $expectedHash" -ForegroundColor Red
        Write-Host "  Actual:   $actualHash" -ForegroundColor Red
        Write-Host "The downloaded file is corrupted or may have been tampered with." -ForegroundColor Red
        Write-Host "Installation aborted immediately to prevent running untrusted code." -ForegroundColor Red
        $global:LASTEXITCODE = 1
        throw [System.Security.SecurityException]"Integrity check failed: SHA256 mismatch for '$($Asset.name)'."
    }

    Write-Host " [VALID]" -ForegroundColor Green
    $isVerified = $true
}
finally {
    if (-not $isVerified) {
        # Atomic Cleanup on Mismatch, Interruption, or Failure
        if (Test-Path -LiteralPath $ArtifactPath) {
            Remove-Item -LiteralPath $ArtifactPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $TempDir) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 5. Extract or Run (Guaranteed Verified)
if ($ArtifactPath.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host " -> Launching Installer..." -ForegroundColor Green
    Start-Process -FilePath $ArtifactPath -Verb RunAs
}
else {
    Write-Host " -> Extracting..." -ForegroundColor Yellow
    $destDir = "$env:ProgramFiles\Win-Debloat"
    Expand-Archive -Path $ArtifactPath -DestinationPath $destDir -Force

    $Launcher = "$destDir\Win-Debloat.ps1"
    if (-not (Test-Path $Launcher)) {
        $Launcher = "$destDir\Win-Debloat7.ps1"
    }
    if (Test-Path $Launcher) {
        Write-Host " -> Installation Complete. Running..." -ForegroundColor Green
        Start-Process pwsh -ArgumentList "-ExecutionPolicy Bypass -File `"$Launcher`"" -Verb RunAs
    }
}
