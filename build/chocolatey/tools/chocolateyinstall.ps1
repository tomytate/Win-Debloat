$packageName = 'win-debloat'
$version     = '1.5.0'
$url = "https://github.com/tomytate/Win-Debloat/releases/download/v$version/Win-Debloat.exe"
$checksum    = "FA85F54D02DBDBF79C22F65B98493EB1CE5E6C20EEF0010B886C4EE4135FA431" 
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$exePath = Join-Path $toolsDir "Win-Debloat.exe"

$packageArgs = @{
    packageName  = $packageName
    fileType     = 'exe'
    url          = $url
    checksum     = $checksum
    checksumType = 'sha256'
    FileFullPath = $exePath
}

Get-ChocolateyWebFile @packageArgs

# Chocolatey auto-shims EXEs in tools/; also register a lowercase alias
Install-BinFile -Name "win-debloat" -Path $exePath

# Create Start Menu Shortcut
$shortcutDir = Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "Win-Debloat"
if (! (Test-Path $shortcutDir)) { New-Item $shortcutDir -ItemType Directory -Force | Out-Null }
$shortcutPath = Join-Path $shortcutDir "Win-Debloat.lnk"

Install-ChocolateyShortcut -ShortcutFilePath $shortcutPath `
    -TargetPath "$exePath" `
    -Description "Launch Win-Debloat" `
    -WindowStyle Maximize

Write-Host "Win-Debloat installed to $toolsDir"
















