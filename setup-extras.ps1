$ErrorActionPreference = 'Stop'

Write-Host "== Win-Debloat7 Installer (EXTRAS EDITION) ==" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "[!] NOTE: This edition includes tools that MAY trigger Antivirus alerts." -ForegroundColor Red
Write-Host "    Please disable Real-Time Protection locally if installation fails." -ForegroundColor Gray
Start-Sleep -Seconds 3

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

# 2. Find the Extras Edition Asset
$isArm64 = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64
$preferredNames = if ($isArm64) {
    @("Win-Debloat-Extras-arm64.exe", "Win-Debloat-Extras.exe", "Win-Debloat7-Extras.exe")
} else {
    @("Win-Debloat-Extras.exe", "Win-Debloat7-Extras.exe", "Win-Debloat-Extras-arm64.exe")
}

$Asset = $null
foreach ($name in $preferredNames) {
    $Asset = $Release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if ($Asset) { break }
}

if (-not $Asset) {
    throw "Could not find a valid release asset for Extras Edition."
}

# 3. Download to Temp
$DownloadUrl = $Asset.browser_download_url
$TempDir = "$env:TEMP\Win-Debloat-Extras-Install"
$ZipPath = "$TempDir\$($Asset.name)"

if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
New-Item -ItemType Directory -Path $TempDir | Out-Null

Write-Host " -> Downloading Extras Edition..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# 4. Extract or Run
if ($ZipPath.EndsWith(".exe")) {
    Write-Host " -> Launching Installer..." -ForegroundColor Green
    Start-Process -FilePath $ZipPath -Verb RunAs
}
else {
    Write-Host " -> Extracting..." -ForegroundColor Yellow
    $destDir = "$env:ProgramFiles\Win-Debloat-Extras"
    Expand-Archive -Path $ZipPath -DestinationPath $destDir -Force

    $Launcher = "$destDir\Win-Debloat.ps1"
    if (-not (Test-Path $Launcher)) {
        $Launcher = "$destDir\Win-Debloat7.ps1"
    }
    if (Test-Path $Launcher) {
        Write-Host " -> Installation Complete. Running..." -ForegroundColor Green
        Start-Process pwsh -ArgumentList "-ExecutionPolicy Bypass -File `"$Launcher`"" -Verb RunAs
    }
}
