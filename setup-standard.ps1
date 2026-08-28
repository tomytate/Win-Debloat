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
    throw "Failed to fetch release info. Check your internet connection."
}

# 2. Find the Standard Edition Asset (Single-File EXE)
$Asset = $Release.assets | Where-Object { $_.name -eq "Win-Debloat7.exe" } | Select-Object -First 1

if (-not $Asset) {
    throw "Could not find a valid release asset for Standard Edition."
}

# 3. Download to Temp
$DownloadUrl = $Asset.browser_download_url
$TempDir = "$env:TEMP\Win-Debloat7-Install"
$ZipPath = "$TempDir\$($Asset.name)"

if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
New-Item -ItemType Directory -Path $TempDir | Out-Null

Write-Host " -> Downloading Standard Edition..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# 4. Verify SHA256 Checksum
try {
    Write-Host " -> Verifying Integrity..." -NoNewline
    $SumsAsset = $Release.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1

    if ($SumsAsset) {
        $SumsContent = (Invoke-RestMethod -Uri $SumsAsset.browser_download_url).Trim()
        $FileHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

        if ($SumsContent -match "$FileHash\s+$($Asset.name)") {
            Write-Host " [VALID]" -ForegroundColor Green
        }
        else {
            Write-Host " [INVALID]" -ForegroundColor Red
            throw "Hash mismatch! The file may be corrupted or tampered with."
        }
    }
    else {
        Write-Host " [SKIPPED] (Checksum file not found)" -ForegroundColor DarkGray
    }
}
catch {
    Write-Host " [WARNING] (Verification check failed)" -ForegroundColor Yellow
}

# 5. Extract or Run
if ($ZipPath.EndsWith(".exe")) {
    Write-Host " -> Launching Installer..." -ForegroundColor Green
    Start-Process -FilePath $ZipPath -Verb RunAs
}
else {
    Write-Host " -> Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $ZipPath -DestinationPath "$env:ProgramFiles\Win-Debloat7" -Force

    $Launcher = "$env:ProgramFiles\Win-Debloat7\Win-Debloat7.ps1"
    if (Test-Path $Launcher) {
        Write-Host " -> Installation Complete. Running..." -ForegroundColor Green
        Start-Process pwsh -ArgumentList "-ExecutionPolicy Bypass -File `"$Launcher`"" -Verb RunAs
    }
}
