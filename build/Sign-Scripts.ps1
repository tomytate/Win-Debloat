#Requires -Version 7.6

param(
    [string]$CertificatePath,
    [string]$TargetDir = "$PSScriptRoot\.."
)

if ([string]::IsNullOrEmpty($CertificatePath)) {
    Write-Host "No certificate provided. Skipping signing." -ForegroundColor Yellow
    exit 0
}

Write-Host "Signing scripts in $TargetDir..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $TargetDir -Recurse -Include *.ps1, *.psm1, *.psd1

foreach ($f in $files) {
    Write-Host "Signing: $($f.Name)" -ForegroundColor Gray
    Set-AuthenticodeSignature -FilePath $f.FullName -Certificate (Get-PfxCertificate $CertificatePath) -TimestampServer "http://timestamp.digicert.com"
}

Write-Host "Signing Complete." -ForegroundColor Green
