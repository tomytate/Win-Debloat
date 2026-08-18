#Requires -Version 7.6

param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "$PSScriptRoot\..\dist"
)

$Root = Resolve-Path "$PSScriptRoot\.."
$DistPath = "$OutputDir\Win-Debloat-v$Version"
$ZipPath = "$OutputDir\Win-Debloat-v$Version.zip"

Write-Host "Starting Build for Win-Debloat v$Version..." -ForegroundColor Cyan

# 1. Clean Output Directory
if (Test-Path $OutputDir) {
    Remove-Item -Path $OutputDir -Recurse -Force
}
New-Item -Path $DistPath -ItemType Directory -Force | Out-Null

# 2. Copy Runtime Files
$Exclusions = @(".git", ".vs", ".vscode", "dist", "tests", "build", "*.zip", "*.md")
Write-Host "Copying files to $DistPath..." -ForegroundColor Gray

Get-ChildItem -Path $Root -Exclude $Exclusions | Copy-Item -Destination $DistPath -Recurse -Force

# 3. Create Zip
Write-Host "Creating Release Package: $ZipPath" -ForegroundColor Cyan
Compress-Archive -Path "$DistPath\*" -DestinationPath $ZipPath -Force

Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "Artifact: $ZipPath" -ForegroundColor Gray
