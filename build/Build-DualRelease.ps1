#Requires -Version 7.6

<#
.SYNOPSIS
    Builds Single-File Executable releases of Win-Debloat with Dual-Layer Signing and SPDX 3.0.1 SBOM.
    
.DESCRIPTION
    Creates standalone single-file executables (Standard/Extras) with embedded compressed payloads,
    high-DPI manifest, optimization (/o+), icon embedding, and multi-architecture platform targeting (x64 / ARM64).
    Generates SHA256 checksums, release notes, SPDX 3.0.1 JSON-LD & SPDX 2.3 Software Bill of Materials (SBOM),
    optional Authenticode Dual-Signing (inner script layer + outer PE binary) with RFC 3161 timestamps,
    and updates distribution manifests.

.PARAMETER Version
    The release version tag (e.g. 1.7.0 or 0.0.0-CI).

.PARAMETER OutputDir
    Output directory for built executables and release artifacts (default: dist).

.PARAMETER Platform
    Target architecture platform: x64, arm64, anycpu, or all (default: all).

.PARAMETER SignCertPath
    Optional path to a code signing PFX certificate for Authenticode dual-signing.

.PARAMETER SignCertPassword
    Optional password for the code signing certificate.

.PARAMETER TimestampServer
    RFC 3161 timestamp server URL (default: http://timestamp.acs.microsoft.com).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version,
    
    [Parameter(Position = 1)]
    [string]$OutputDir = "$PSScriptRoot\..\dist",

    [ValidateSet("x64", "arm64", "anycpu", "all")]
    [string]$Platform = "all",

    [string]$SignCertPath,
    [securestring]$SignCertPassword,
    [string]$TimestampServer = "http://timestamp.acs.microsoft.com"
)

$ErrorActionPreference = "Stop"

function New-DeterministicZip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,
        [Parameter(Mandatory = $true)]
        [string]$DestinationArchive
    )
    if (Test-Path -LiteralPath $DestinationArchive) {
        Remove-Item -LiteralPath $DestinationArchive -Force
    }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $fixedTime = [DateTimeOffset]::new(2026, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
    $zipStream = [System.IO.File]::Create($DestinationArchive)
    $zipArchive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -Path $SourceDirectory -Recurse -File | Sort-Object FullName
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($SourceDirectory.Length).TrimStart('\', '/') -replace '\\', '/'
            $entry = $zipArchive.CreateEntry($relativePath, [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTime
            $entryStream = $entry.Open()
            $fileStream = [System.IO.File]::OpenRead($file.FullName)
            try {
                $fileStream.CopyTo($entryStream)
            }
            finally {
                $fileStream.Dispose()
                $entryStream.Dispose()
            }
        }
    }
    finally {
        $zipArchive.Dispose()
        $zipStream.Dispose()
    }
}

$Root = (Resolve-Path "$PSScriptRoot\..").Path
$DistPath = [System.IO.Path]::GetFullPath($OutputDir)

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Win-Debloat Single-File Builder v2.2 (v1.7.1)           ║" -ForegroundColor Cyan
Write-Host "║      High-DPI • Multi-Arch • Dual-Signing • SPDX 3.0.1 SBOM  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "   Version:     $Version" -ForegroundColor Gray
Write-Host "   Output Dir:  $DistPath" -ForegroundColor Gray
Write-Host "   Platform:    $Platform" -ForegroundColor Gray

# 1. Clean and initialize output directory
if (Test-Path -LiteralPath $DistPath) {
    Write-Host "`n🗑️  Cleaning previous build artifacts..." -ForegroundColor Gray
    Get-ChildItem -LiteralPath $DistPath -Force | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop }
        catch { Write-Warning "Could not remove $($_.Name): file may be in use." }
    }
}
New-Item -Path $DistPath -ItemType Directory -Force | Out-Null

$compilerScript = Join-Path $PSScriptRoot "Compile-Launcher.ps1"
if (-not (Test-Path -LiteralPath $compilerScript)) {
    throw "Compiler script not found at $compilerScript"
}

$launcherSrc = Join-Path $Root "src\core\LauncherEmbed.cs"
if (-not (Test-Path -LiteralPath $launcherSrc)) {
    throw "Launcher source not found at $launcherSrc"
}

$manifestPath = Join-Path $Root "src\core\app.manifest"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Warning "⚠️ High-DPI manifest not found at $manifestPath. Compiler will attempt fallback."
}

$iconDest = Join-Path $Root "assets\logo.ico"
if (-not (Test-Path -LiteralPath $iconDest)) {
    Write-Warning "⚠️ Icon not found at $iconDest. EXEs will be built without custom icon."
}

# Determine target architectures to build
$targetArchs = if ($Platform -eq "all") {
    @("x64", "arm64")
} else {
    @($Platform)
}

# Load signing certificate if specified
$codeSigningCert = $null
if ($SignCertPath -and (Test-Path -LiteralPath $SignCertPath)) {
    Write-Host "`n🔐 Loading Authenticode Signing Certificate..." -ForegroundColor Yellow
    try {
        $codeSigningCert = if ($SignCertPassword) {
            Get-PfxCertificate -FilePath $SignCertPath -Password $SignCertPassword
        } else {
            Get-PfxCertificate -FilePath $SignCertPath
        }
        Write-Host "   ✅ Certificate Loaded: $($codeSigningCert.Subject)" -ForegroundColor Green
    }
    catch {
        Write-Warning "⚠️ Failed to load code signing certificate: $($_.Exception.Message)"
    }
}

# ═══════════════════════════════════════════════════════════════
# MAIN BUILD LOOP
# ═══════════════════════════════════════════════════════════════

$builtExecutables = [System.Collections.Generic.List[PSCustomObject]]::new()
$builtArchives    = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($variant in @("Standard", "Extras")) {
    Write-Host "`n📦 Packaging $variant Edition..." -ForegroundColor Cyan
    
    # 1. Setup Staging Area
    $stageDir = Join-Path $DistPath "Stage_$variant"
    if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force }
    New-Item -Path $stageDir -ItemType Directory -Force | Out-Null
    
    try {
        # 2. Copy Canonical Files to Staging
        $includeItems = @(
            "Win-Debloat.ps1",
            "Win-Debloat7.ps1",
            "Win-Debloat.psd1",
            "Win-Debloat7.psd1",
            "setup-standard.ps1",
            "setup-extras.ps1",
            "LICENSE",
            "README.md",
            "CHANGELOG.md",
            "SECURITY.md",
            "CODE_OF_CONDUCT.md",
            "src",
            "config",
            "profiles",
            "assets",
            "docs",
            "deploy",
            "Run.bat"
        )

        foreach ($item in $includeItems) {
            $sourceItem = Join-Path $Root $item
            if (Test-Path -LiteralPath $sourceItem) {
                Copy-Item -Path $sourceItem -Destination $stageDir -Recurse -Force
            }
        }
        
        # Standard Cleanup (Ensure Extras module and setup-extras.ps1 are excluded from Standard edition)
        if ($variant -eq "Standard") {
            $extrasDir = Join-Path $stageDir "src\modules\Extras"
            if (Test-Path -LiteralPath $extrasDir) {
                Remove-Item -LiteralPath $extrasDir -Recurse -Force
            }
            $extrasScript = Join-Path $stageDir "setup-extras.ps1"
            if (Test-Path -LiteralPath $extrasScript) {
                Remove-Item -LiteralPath $extrasScript -Force
            }
        }

        # Sign Inner Staged PowerShell Scripts (Layer 1 Signing)
        if ($codeSigningCert) {
            Write-Host "   🔏 Signing inner staged scripts..." -ForegroundColor DarkGray
            Get-ChildItem -Path $stageDir -Include *.ps1, *.psm1, *.psd1 -Recurse | ForEach-Object {
                try {
                    Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $codeSigningCert -TimestampServer $TimestampServer -HashAlgorithm SHA256 -ErrorAction SilentlyContinue | Out-Null
                } catch {
                    # Continue if timestamping has momentary network lag
                    $null = $_
                }
            }
        }
        
        # 3. Create Payload.zip
        $payloadZip = Join-Path $DistPath "payload_$variant.zip"
        if (Test-Path -LiteralPath $payloadZip) { Remove-Item -LiteralPath $payloadZip -Force }

        Write-Host "   📦 Compressing staged payload to deterministic ZIP..." -ForegroundColor DarkGray
        New-DeterministicZip -SourceDirectory $stageDir -DestinationArchive $payloadZip
        $zipSize = [math]::Round((Get-Item -LiteralPath $payloadZip).Length / 1MB, 2)
        Write-Host "   📦 Payload archive created ($zipSize MB)" -ForegroundColor DarkGray

        # Also copy payload to final release archive
        $finalZipName = switch ($variant) {
            "Standard" { "Win-Debloat-v$Version.zip" }
            "Extras"   { "Win-Debloat-Extras-v$Version.zip" }
        }
        $finalZipPath = Join-Path $DistPath $finalZipName
        Copy-Item -Path $payloadZip -Destination $finalZipPath -Force
        $zipItem = Get-Item -LiteralPath $finalZipPath
        $finalZipSizeMb = [math]::Round($zipItem.Length / 1MB, 2)
        $builtArchives.Add([PSCustomObject]@{
            Name        = $finalZipName
            Variant     = $variant
            Arch        = "universal"
            Path        = $finalZipPath
            SizeMb      = $finalZipSizeMb
            LengthBytes = $zipItem.Length
        })
        Write-Host "   📦 Release archive created: $finalZipName ($finalZipSizeMb MB)" -ForegroundColor DarkGray

        # 4. Compile Executable(s) for each target architecture
        foreach ($arch in $targetArchs) {
            $exeName = switch ($variant) {
                "Standard" {
                    if ($arch -eq "x64") {
                        "Win-Debloat.exe"
                    } else {
                        "Win-Debloat-$arch.exe"
                    }
                }
                "Extras" {
                    if ($arch -eq "x64") {
                        "Win-Debloat-Extras.exe"
                    } else {
                        "Win-Debloat-Extras-$arch.exe"
                    }
                }
            }

            $exeOut = Join-Path $DistPath $exeName
            Write-Host "   🔨 Building executable: $exeName ($arch)..." -ForegroundColor Gray

            $compilerParams = @{
                SourceFile = $launcherSrc
                OutputFile = $exeOut
                Resource   = $payloadZip
                Platform   = $arch
                Optimize   = $true
            }

            if ($iconDest -and (Test-Path -LiteralPath $iconDest)) {
                $compilerParams["Icon"] = $iconDest
            }
            if ($manifestPath -and (Test-Path -LiteralPath $manifestPath)) {
                $compilerParams["Manifest"] = $manifestPath
            }

            & $compilerScript @compilerParams

            if (-not (Test-Path -LiteralPath $exeOut)) {
                throw "Failed to compile $exeName (Architecture: $arch): binary not found at $exeOut"
            }

            # Sign Outer PE Executable (Layer 2 Signing)
            if ($codeSigningCert) {
                Write-Host "   🔏 Signing outer binary $exeName..." -ForegroundColor DarkGray
                try {
                    Set-AuthenticodeSignature -FilePath $exeOut -Certificate $codeSigningCert -TimestampServer $TimestampServer -HashAlgorithm SHA256 | Out-Null
                } catch {
                    Write-Warning "⚠️ Failed to sign binary ${exeName}: $($_.Exception.Message)"
                }
            }

            $exeItem = Get-Item -LiteralPath $exeOut
            $exeSizeMb = [math]::Round($exeItem.Length / 1MB, 2)

            Write-Host "   ✅ Compiled $exeName ($exeSizeMb MB) [$arch]" -ForegroundColor Green

            $builtExecutables.Add([PSCustomObject]@{
                Name        = $exeName
                Variant     = $variant
                Arch        = $arch
                Path        = $exeOut
                SizeMb      = $exeSizeMb
                LengthBytes = $exeItem.Length
            })
        }
    }
    finally {
        if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $payloadZip) { Remove-Item -LiteralPath $payloadZip -Force -ErrorAction SilentlyContinue }
    }
}

# ═══════════════════════════════════════════════════════════════
# GENERATE CHECKSUMS
# ═══════════════════════════════════════════════════════════════

Write-Host "`n🔐 Generating cryptographic SHA256 checksums..." -ForegroundColor Cyan

$checksums = @{}
$checksumFile = Join-Path $DistPath "SHA256SUMS.txt"
$sb = [System.Text.StringBuilder]::new()
$allArtifacts = @($builtExecutables) + @($builtArchives)

foreach ($art in $allArtifacts) {
    $hash = (Get-FileHash -Path $art.Path -Algorithm SHA256).Hash
    $line = "$hash  $($art.Name)"
    $sb.AppendLine($line) | Out-Null
    Write-Host "   $($art.Name.PadRight(32)): $hash" -ForegroundColor Gray
    
    if ($art.Name -eq "Win-Debloat.exe") {
        $checksums["Standard"] = $hash
    }
    elseif ($art.Name -eq "Win-Debloat-Extras.exe") {
        $checksums["Extras"] = $hash
    }
    elseif ($art.Name -eq "Win-Debloat-v$Version.zip") {
        $checksums["StandardZip"] = $hash
    }
    elseif ($art.Name -eq "Win-Debloat-Extras-v$Version.zip") {
        $checksums["ExtrasZip"] = $hash
    }
}

[System.IO.File]::WriteAllText($checksumFile, $sb.ToString())
Write-Host "   ✅ SHA256SUMS.txt written." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# GENERATE SPDX 3.0.1 JSON-LD & SPDX 2.3 SBOM
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📋 Generating SPDX 3.0.1 JSON-LD & SPDX 2.3 Software Bill of Materials (SBOM)..." -ForegroundColor Cyan

$creationInfoId = "_:creationInfo_0"
$nowUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$docSpdxId = "urn:spdx:doc:win-debloat-v$Version"
$rootPkgId = "urn:spdx:pkg:Win-Debloat"
$licenseMitId = "urn:spdx:license:MIT"
$licenseCc0Id = "urn:spdx:license:CC0-1.0"
$personId = "urn:spdx:agent:person:TomyTate"
$toolId = "urn:spdx:agent:tool:WinDebloat-Builder-2.2"

$graph = [System.Collections.Generic.List[psobject]]::new()

# 1. CreationInfo
$graph.Add([ordered]@{
    "@id"        = $creationInfoId
    type         = "CreationInfo"
    specVersion  = "3.0.1"
    created      = $nowUtc
    createdBy    = @($personId, $toolId)
})

# 2. Agents
$graph.Add([ordered]@{
    spdxId       = $personId
    type         = "Person"
    name         = "Tomy Tate"
    creationInfo = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId       = $toolId
    type         = "Tool"
    name         = "WinDebloat-Builder-2.2"
    creationInfo = $creationInfoId
})

# 3. Licenses
$graph.Add([ordered]@{
    spdxId                             = $licenseCc0Id
    type                               = "simplelicensing_LicenseExpression"
    simplelicensing_licenseExpression = "CC0-1.0"
    creationInfo                       = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId                             = $licenseMitId
    type                               = "simplelicensing_LicenseExpression"
    simplelicensing_licenseExpression = "MIT"
    creationInfo                       = $creationInfoId
})

# 4. SpdxDocument
$graph.Add([ordered]@{
    spdxId       = $docSpdxId
    type         = "SpdxDocument"
    name         = "Win-Debloat-v$Version-SBOM"
    dataLicense  = $licenseCc0Id
    rootElement  = @($rootPkgId)
    creationInfo = $creationInfoId
})

# 5. Root Package (Win-Debloat)
$graph.Add([ordered]@{
    spdxId                    = $rootPkgId
    type                      = "software_Package"
    name                      = "Win-Debloat"
    software_packageVersion   = $Version
    software_downloadLocation = "https://github.com/tomytate/Win-Debloat/releases/tag/v$Version"
    software_copyrightText    = "Copyright (c) 2026 Tomy Tate"
    software_primaryPurpose   = "application"
    creationInfo              = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId           = "urn:spdx:rel:doc-describes-root"
    type             = "Relationship"
    relationshipType = "describes"
    from             = $docSpdxId
    to               = @($rootPkgId)
    completeness     = "complete"
    creationInfo     = $creationInfoId
})

# 6. Vendored dependencies (powershell-yaml and YamlDotNet)
$yamlPkgId = "urn:spdx:pkg:powershell-yaml-0.4.12"
$graph.Add([ordered]@{
    spdxId                    = $yamlPkgId
    type                      = "software_Package"
    name                      = "powershell-yaml"
    software_packageVersion   = "0.4.12"
    software_downloadLocation = "https://github.com/cloudbase/powershell-yaml"
    software_copyrightText    = "Copyright (c) 2018 Cloudbase Solutions Srl"
    software_primaryPurpose   = "library"
    creationInfo              = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId           = "urn:spdx:rel:root-contains-powershell-yaml"
    type             = "Relationship"
    relationshipType = "contains"
    from             = $rootPkgId
    to               = @($yamlPkgId)
    completeness     = "complete"
    creationInfo     = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId           = "urn:spdx:rel:powershell-yaml-hasConcludedLicense"
    type             = "Relationship"
    relationshipType = "hasConcludedLicense"
    from             = $yamlPkgId
    to               = @($licenseMitId)
    creationInfo     = $creationInfoId
})

$yamlDotNetPkgId = "urn:spdx:pkg:yamldotnet-13.7.1"
$graph.Add([ordered]@{
    spdxId                    = $yamlDotNetPkgId
    type                      = "software_Package"
    name                      = "YamlDotNet"
    software_packageVersion   = "13.7.1"
    software_downloadLocation = "https://github.com/aaubry/YamlDotNet"
    software_copyrightText    = "Copyright (c) 2008-2024 Antoine Aubry and contributors"
    software_primaryPurpose   = "library"
    creationInfo              = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId           = "urn:spdx:rel:powershell-yaml-dependsOn-yamldotnet"
    type             = "Relationship"
    relationshipType = "dependsOn"
    from             = $yamlPkgId
    to               = @($yamlDotNetPkgId)
    completeness     = "complete"
    creationInfo     = $creationInfoId
})

$graph.Add([ordered]@{
    spdxId           = "urn:spdx:rel:yamldotnet-hasConcludedLicense"
    type             = "Relationship"
    relationshipType = "hasConcludedLicense"
    from             = $yamlDotNetPkgId
    to               = @($licenseMitId)
    creationInfo     = $creationInfoId
})

# 7. Artifact Packages & Relationships
$legacyPackages = [System.Collections.Generic.List[psobject]]::new()
$legacyRelationships = [System.Collections.Generic.List[psobject]]::new()

# Legacy vendored packages
$legacyPackages.Add([ordered]@{
    SPDXID           = "SPDXRef-Package-powershell-yaml"
    name             = "powershell-yaml"
    versionInfo      = "0.4.12"
    downloadLocation = "https://github.com/cloudbase/powershell-yaml"
    filesAnalyzed    = $false
    licenseConcluded = "MIT"
    licenseDeclared  = "MIT"
    copyrightText    = "Copyright (c) 2018 Cloudbase Solutions Srl"
    description      = "Vendored YAML parser and serializer module for PowerShell"
})

$legacyPackages.Add([ordered]@{
    SPDXID           = "SPDXRef-Package-YamlDotNet"
    name             = "YamlDotNet"
    versionInfo      = "13.7.1"
    downloadLocation = "https://github.com/aaubry/YamlDotNet"
    filesAnalyzed    = $false
    licenseConcluded = "MIT"
    licenseDeclared  = "MIT"
    copyrightText    = "Copyright (c) 2008-2024 Antoine Aubry and contributors"
    description      = "Vendored .NET library for YAML"
})

$legacyRelationships.Add([ordered]@{
    spdxElementId      = "SPDXRef-DOCUMENT"
    relationshipType   = "DESCRIBES"
    relatedSpdxElement = "SPDXRef-Package-powershell-yaml"
})
$legacyRelationships.Add([ordered]@{
    spdxElementId      = "SPDXRef-DOCUMENT"
    relationshipType   = "DESCRIBES"
    relatedSpdxElement = "SPDXRef-Package-YamlDotNet"
})
$legacyRelationships.Add([ordered]@{
    spdxElementId      = "SPDXRef-Package-powershell-yaml"
    relationshipType   = "DEPENDS_ON"
    relatedSpdxElement = "SPDXRef-Package-YamlDotNet"
})

foreach ($art in $allArtifacts) {
    $hash = (Get-FileHash -Path $art.Path -Algorithm SHA256).Hash
    $cleanId = $art.Name -replace '[^a-zA-Z0-9]', '-'
    $pkgId = "urn:spdx:pkg:$cleanId"

    # SPDX 3.0.1 JSON-LD Graph Node
    $graph.Add([ordered]@{
        spdxId                    = $pkgId
        type                      = "software_Package"
        name                      = $art.Name
        software_packageVersion   = $Version
        software_downloadLocation = "https://github.com/tomytate/Win-Debloat/releases/download/v$Version/$($art.Name)"
        software_copyrightText    = "Copyright (c) 2026 Tomy Tate"
        software_primaryPurpose   = "application"
        verifiedUsing             = @(
            [ordered]@{
                type      = "Hash"
                algorithm = "sha256"
                hashValue = $hash
            }
        )
        creationInfo              = $creationInfoId
    })

    $graph.Add([ordered]@{
        spdxId           = "urn:spdx:rel:root-contains-$cleanId"
        type             = "Relationship"
        relationshipType = "contains"
        from             = $rootPkgId
        to               = @($pkgId)
        completeness     = "complete"
        creationInfo     = $creationInfoId
    })

    $graph.Add([ordered]@{
        spdxId           = "urn:spdx:rel:doc-describes-$cleanId"
        type             = "Relationship"
        relationshipType = "describes"
        from             = $docSpdxId
        to               = @($pkgId)
        completeness     = "complete"
        creationInfo     = $creationInfoId
    })

    $graph.Add([ordered]@{
        spdxId           = "urn:spdx:rel:$cleanId-hasConcludedLicense"
        type             = "Relationship"
        relationshipType = "hasConcludedLicense"
        from             = $pkgId
        to               = @($licenseMitId)
        creationInfo     = $creationInfoId
    })

    $graph.Add([ordered]@{
        spdxId           = "urn:spdx:rel:$cleanId-hasDeclaredLicense"
        type             = "Relationship"
        relationshipType = "hasDeclaredLicense"
        from             = $pkgId
        to               = @($licenseMitId)
        creationInfo     = $creationInfoId
    })

    # Legacy SPDX 2.3 Package Node
    $legacyPackages.Add([ordered]@{
        SPDXID           = "SPDXRef-Package-$cleanId"
        name             = $art.Name
        versionInfo      = $Version
        downloadLocation = "https://github.com/tomytate/Win-Debloat/releases/download/v$Version/$($art.Name)"
        filesAnalyzed    = $false
        checksums        = @(
            @{
                algorithm     = "SHA256"
                checksumValue = $hash
            }
        )
        licenseConcluded = "MIT"
        licenseDeclared  = "MIT"
        copyrightText    = "Copyright (c) 2026 Tomy Tate"
        description      = "$($art.Variant) Edition release artifact ($($art.Name))"
    })

    $legacyRelationships.Add([ordered]@{
        spdxElementId      = "SPDXRef-DOCUMENT"
        relationshipType   = "DESCRIBES"
        relatedSpdxElement = "SPDXRef-Package-$cleanId"
    })
}

# 8. Write Primary SPDX 3.0.1 JSON-LD SBOM
$sbom3 = [ordered]@{
    "@context" = "https://spdx.org/rdf/3.0.1/spdx-context.jsonld"
    "@graph"   = $graph
}
$sbom3Path = Join-Path $DistPath "win-debloat-sbom.spdx.json"
$sbom3 | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sbom3Path -Encoding UTF8
Write-Host "   ✅ win-debloat-sbom.spdx.json written (SPDX 3.0.1 JSON-LD)." -ForegroundColor Green

# 9. Write Legacy Fallback SPDX 2.3 JSON SBOM
$sbomLegacy = [ordered]@{
    '$schema'          = "https://spdx.org/schema/2.3/spdx-json-schema.json"
    spdxVersion        = "SPDX-2.3"
    dataLicense        = "CC0-1.0"
    SPDXID             = "SPDXRef-DOCUMENT"
    name               = "Win-Debloat-v$Version-SBOM"
    documentNamespace  = "https://github.com/tomytate/Win-Debloat/releases/tag/v$Version/win-debloat-sbom-v2.3.spdx.json"
    creationInfo       = [ordered]@{
        created            = $nowUtc
        creators           = @("Tool: WinDebloat-Builder-2.2", "Organization: Win-Debloat Project", "Person: Tomy Tate")
        licenseListVersion = "3.22"
    }
    packages           = $legacyPackages
    relationships      = $legacyRelationships
}
$sbomLegacyPath = Join-Path $DistPath "win-debloat-sbom-v2.3.spdx.json"
$sbomLegacy | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sbomLegacyPath -Encoding UTF8
Write-Host "   ✅ win-debloat-sbom-v2.3.spdx.json written (SPDX 2.3 Legacy Fallback)." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# CREATE RELEASE NOTES
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📝 Generating release notes..." -ForegroundColor Cyan

$ReleaseNotes = @"
# Win-Debloat v$Version

## 🚀 Standalone Single-File Distributions

### ✅ Standard Edition (`Win-Debloat.exe` / `Win-Debloat-arm64.exe`)
Safe, clean Windows optimization, AI Fabric RAM reclaiming, and debloating. Contains zero flagged tools.
Self-extracts and runs under PowerShell 7.6+ LTS / Windows PowerShell 5.1 (auto-installs if missing).

### ⚠️ Extras Edition (`Win-Debloat-Extras.exe` / `Win-Debloat-Extras-arm64.exe`)
Includes advanced tools such as Defender Remover and MAS.
*Note: Contains specialized administrative tools flagged by some Antivirus solutions.*

## ⚙️ Binary Features
- **Modern .NET Toolchain**: Compiled with high performance optimization (`/o+`)
- **High-DPI Aware**: Native PerMonitorV2 scaling support for 4K / Multi-Monitor setups
- **UTF-8 & Long Paths**: Full modern Windows path and UTF-8 encoding support
- **Architecture**: Native x64 / ARM64 targeting
- **Supply Chain Security**: Dual-Layer Authenticode Signing & SPDX 3.0.1 JSON-LD SBOM (with SPDX 2.3 fallback)

## 📋 Requirements
- Windows 10 (Build 19041+), Windows 11 (23H2 / 24H2 / 25H2 / 26H1 / 26H2), or Windows Server 2025
- PowerShell 7.6+ LTS or Windows PowerShell 5.1
- Administrator Privileges

## 🔐 Cryptographic Checksums (SHA-256)
``````
$($sb.ToString().Trim())
``````
"@

$ReleaseNotes | Set-Content (Join-Path $DistPath "RELEASE_NOTES.md") -Encoding UTF8
Write-Host "   ✅ RELEASE_NOTES.md written." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# UPDATE MANIFESTS (CHOCOLATEY & WINGET)
# ═══════════════════════════════════════════════════════════════

Write-Host "`n📝 Updating package distribution manifests..." -ForegroundColor Cyan

# 1. Update Chocolatey NuSpec
$nuspecPath = Join-Path $Root "build\chocolatey\Win-Debloat.nuspec"
if (-not (Test-Path -LiteralPath $nuspecPath)) {
    $oldNuspec = Join-Path $Root "build\chocolatey\Win-Debloat7.nuspec"
    if (Test-Path -LiteralPath $oldNuspec) { $nuspecPath = $oldNuspec }
}
if (Test-Path -LiteralPath $nuspecPath) {
    (Get-Content -LiteralPath $nuspecPath) -replace "<version>.*</version>", "<version>$Version</version>" |
        Set-Content -LiteralPath $nuspecPath -Encoding UTF8
    Write-Host "   ✅ Updated Chocolatey NuSpec version to $Version" -ForegroundColor Gray
}

# 2. Update Chocolatey Install Script
$chocoInstallPath = Join-Path $Root "build\chocolatey\tools\chocolateyinstall.ps1"
if (Test-Path -LiteralPath $chocoInstallPath) {
    $content = Get-Content -LiteralPath $chocoInstallPath -Raw
    $content = $content -replace "(?m)^\s*\`$version\s*=\s*'.*'", "`$version     = '$Version'"
    if ($checksums["Standard"]) {
        $content = $content -replace "(?m)^\s*\`$checksumX64\s*=\s*`".*`"", "`$checksumX64   = `"$($checksums["Standard"])`""
    }
    $arm64StandardExe = $builtExecutables | Where-Object { $_.Name -eq "Win-Debloat-arm64.exe" } | Select-Object -First 1
    if ($arm64StandardExe) {
        $arm64Hash = (Get-FileHash -Path $arm64StandardExe.Path -Algorithm SHA256).Hash
        $content = $content -replace "(?m)^\s*\`$checksumArm64\s*=\s*`".*`"", "`$checksumArm64 = `"$arm64Hash`""
    }
    Set-Content -LiteralPath $chocoInstallPath -Value $content -Encoding UTF8
    Write-Host "   ✅ Updated Chocolatey install script version & dual-arch checksums" -ForegroundColor Gray
}

# 3. Update Winget Manifests
$wingetScript = Join-Path $PSScriptRoot "New-WingetManifest.ps1"
if (Test-Path -LiteralPath $wingetScript) {
    & $wingetScript -Version $Version -OutputDirectory (Join-Path $DistPath "winget-manifests")
    $buildWingetDir = Join-Path $PSScriptRoot "winget-manifests"
    & $wingetScript -Version $Version -OutputDirectory $buildWingetDir
    Write-Host "   ✅ Generated Winget v1.28.0 manifests in dist and build" -ForegroundColor Gray
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "🎉 BUILD SUCCEEDED: Win-Debloat v$Version" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
foreach ($art in $allArtifacts) {
    $archLabel = if ($art.PSObject.Properties['Arch']) { $art.Arch } else { "universal" }
    Write-Host "   📦 $($art.Name.PadRight(32)) | $([string]$archLabel.PadRight(10)) | $($art.SizeMb) MB" -ForegroundColor White
}
Write-Host "   📁 Artifacts directory: $DistPath`n" -ForegroundColor Gray
