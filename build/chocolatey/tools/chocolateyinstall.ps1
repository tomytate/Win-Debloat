$ErrorActionPreference = 'Stop'

$packageName = 'win-debloat'
$version     = '1.7.1'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

# Architecture Detection (Native ARM64 vs AMD64)
$isArm64 = $false
try {
    $isArm64 = ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64)
} catch {
    $isArm64 = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')
}
$checksumX64   = "245C8DB9EF305C2C3C8D6D216877464B6F64E8AF581832C063CDFF2C0E4A7A94"
$checksumArm64 = "2E5DEE9415A66F642E6649D3AEBE063B0E86BDCB6665F349D1FE1E2B427FFF25"

if ($isArm64) {
    $binaryName = "Win-Debloat-arm64.exe"
    $checksum   = $checksumArm64
} else {
    $binaryName = "Win-Debloat.exe"
    $checksum   = $checksumX64
}

$url     = "https://github.com/tomytate/Win-Debloat/releases/download/v$version/$binaryName"
$exePath = Join-Path $toolsDir "Win-Debloat.exe"

$packageArgs = @{
    packageName  = $packageName
    fileFullPath = $exePath
    url          = $url
    checksum     = $checksum
    checksumType = 'sha256'
}

Get-ChocolateyWebFile @packageArgs

# Auto-shim creates 'Win-Debloat.exe'.
# Register explicit lowercase CLI alias 'win-debloat' (UseStart prevents GUI from blocking console):
Install-BinFile -Name "win-debloat" -Path $exePath -UseStart

# Create Start Menu Shortcut (All Users)
$startPrograms = [Environment]::GetFolderPath("CommonPrograms")
$shortcutDir   = Join-Path $startPrograms "Win-Debloat"
if (-not (Test-Path -LiteralPath $shortcutDir)) {
    New-Item -Path $shortcutDir -ItemType Directory -Force | Out-Null
}
$shortcutPath = Join-Path $shortcutDir "Win-Debloat.lnk"

Install-ChocolateyShortcut -shortcutFilePath $shortcutPath `
    -targetPath $exePath `
    -workDirectory $toolsDir `
    -description "Launch Win-Debloat Windows Optimization Platform"

Write-Host "✅ Win-Debloat $version installed successfully to $toolsDir" -ForegroundColor Green




