$ErrorActionPreference = 'SilentlyContinue'

$packageName = 'win-debloat'

# 1. Clean up manual shim created via Install-BinFile
Uninstall-BinFile -Name "win-debloat"

# 2. Clean up Start Menu Shortcut and Folder
$startPrograms = [Environment]::GetFolderPath("CommonPrograms")
$shortcutDir   = Join-Path $startPrograms "Win-Debloat"
if (Test-Path -LiteralPath $shortcutDir) {
    Remove-Item -LiteralPath $shortcutDir -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. Clean up any remaining files in tools directory
$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$exePath  = Join-Path $toolsDir "Win-Debloat.exe"
if (Test-Path -LiteralPath $exePath) {
    Remove-Item -LiteralPath $exePath -Force -ErrorAction SilentlyContinue
}

Write-Host "✅ Win-Debloat uninstalled successfully." -ForegroundColor Green
