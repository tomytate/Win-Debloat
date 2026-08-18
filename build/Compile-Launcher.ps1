<#
.SYNOPSIS
    Compiles C# launcher files into standalone Windows executables.

.DESCRIPTION
    Builds single-file or folder launcher executables for Win-Debloat with:
      - Automatic detection of modern .NET SDK (Roslyn csc.dll via dotnet exec)
      - Fallback to Visual Studio / Build Tools Roslyn csc.exe and .NET Framework csc.exe
      - High-DPI application manifest embedding (PerMonitorV2, LongPathAware, UTF-8)
      - Compiler optimization (/o+)
      - Custom icon embedding (/win32icon)
      - Multi-architecture platform targeting (x64, arm64, anycpu, x86)
      - Embedded payload resource embedding (/resource)
      - Robust post-build validation and clean status reporting

.PARAMETER SourceFile
    Path to the C# source file (e.g. src/core/LauncherEmbed.cs).

.PARAMETER OutputFile
    Target output executable path (e.g. dist/Win-Debloat.exe).

.PARAMETER Resource
    Optional path to an embedded resource (e.g. payload.zip).

.PARAMETER Icon
    Optional path to a .ico icon file. Defaults to assets/logo.ico if available.

.PARAMETER Manifest
    Optional path to a Win32 application manifest. Defaults to src/core/app.manifest if available.

.PARAMETER Platform
    Target architecture platform: x64 (default), arm64, anycpu, anycpu32bitpreferred, x86.

.PARAMETER Optimize
    Enable compiler optimization (/o+). Defaults to $true.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SourceFile,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$OutputFile,

    [Parameter(Position = 2)]
    [string]$Resource = "",

    [Parameter(Position = 3)]
    [string]$Icon = "",

    [Parameter(Position = 4)]
    [string]$Manifest = "",

    [ValidateSet("x64", "arm64", "anycpu", "anycpu32bitpreferred", "x86", "AnyCPU", "ARM64", "X64", "X86")]
    [string]$Platform = "x64",

    [bool]$Optimize = $true
)

$ErrorActionPreference = "Stop"

function Find-CSharpCompiler {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TargetPlatform = ""
    )

    $compilers = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- Strategy 1: Modern .NET SDK (dotnet exec Roslyn csc.dll) ---
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        $dotnetPath = $dotnetCmd.Source
        $dotnetRoot = Split-Path -Parent $dotnetPath
        $sdkDir = Join-Path $dotnetRoot "sdk"

        if (Test-Path $sdkDir) {
            $sdkFolders = Get-ChildItem -Path $sdkDir -Directory -ErrorAction SilentlyContinue |
                Sort-Object { [version]($_.Name -replace '-.*$', '') } -Descending

            foreach ($sdk in $sdkFolders) {
                $cscDll = Join-Path $sdk.FullName "Roslyn\bincore\csc.dll"
                if (Test-Path $cscDll) {
                    # Locate reference assemblies for Framework/CLR targeting
                    $refDirs = @(
                        "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319",
                        "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319",
                        "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8",
                        "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.7.2",
                        "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5",
                        "${env:ProgramFiles}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8"
                    )

                    $resolvedRefs = @()
                    foreach ($dir in $refDirs) {
                        if (Test-Path $dir) {
                            $mscorlib = Join-Path $dir "mscorlib.dll"
                            $sys = Join-Path $dir "System.dll"
                            $sysCore = Join-Path $dir "System.Core.dll"
                            if ((Test-Path $mscorlib) -and (Test-Path $sys)) {
                                $resolvedRefs = @($mscorlib, $sys)
                                if (Test-Path $sysCore) { $resolvedRefs += $sysCore }
                                break
                            }
                        }
                    }

                    if ($resolvedRefs.Count -gt 0) {
                        $compilers.Add([PSCustomObject]@{
                            Type        = "DotNetSdk"
                            Name        = ".NET SDK Roslyn (v$($sdk.Name))"
                            Executable  = $dotnetPath
                            RoslynDll   = $cscDll
                            References  = $resolvedRefs
                            SupportsArm64 = $true
                        })
                        break
                    }
                }
            }
        }
    }

    # --- Strategy 2: Visual Studio / Build Tools Roslyn csc.exe ---
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsInstalls = & $vswhere -latest -products * -property installationPath 2>$null
        if ($vsInstalls) {
            foreach ($vsPath in $vsInstalls) {
                $candidates = @(
                    "$vsPath\MSBuild\Current\Bin\Roslyn\csc.exe",
                    "$vsPath\MSBuild\15.0\Bin\Roslyn\csc.exe"
                )
                foreach ($candidate in $candidates) {
                    if (Test-Path $candidate) {
                        $compilers.Add([PSCustomObject]@{
                            Type        = "VisualStudioRoslyn"
                            Name        = "Visual Studio Roslyn csc.exe"
                            Executable  = $candidate
                            RoslynDll   = $null
                            References  = @()
                            SupportsArm64 = $true
                        })
                        break
                    }
                }
            }
        }
    }

    # --- Strategy 3: csc.exe in PATH ---
    $pathCsc = Get-Command csc -ErrorAction SilentlyContinue
    if ($pathCsc -and (Test-Path $pathCsc.Source)) {
        $compilers.Add([PSCustomObject]@{
            Type        = "PathCsc"
            Name        = "PATH csc.exe ($($pathCsc.Source))"
            Executable  = $pathCsc.Source
            RoslynDll   = $null
            References  = @()
            SupportsArm64 = $true
        })
    }

    # --- Strategy 4: Classic .NET Framework csc.exe ---
    $runtimeCsc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) "csc.exe"
    $frameworkPaths = @(
        $runtimeCsc,
        "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
        "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    )

    foreach ($fxPath in $frameworkPaths) {
        if ($fxPath -and (Test-Path $fxPath)) {
            $compilers.Add([PSCustomObject]@{
                Type        = "FrameworkCsc"
                Name        = ".NET Framework csc.exe ($fxPath)"
                Executable  = $fxPath
                RoslynDll   = $null
                References  = @()
                SupportsArm64 = $false
            })
            break
        }
    }

    return $compilers
}

try {
    # 1. Validate Source File
    if (-not (Test-Path -LiteralPath $SourceFile)) {
        throw "Source file not found: $SourceFile"
    }
    $resolvedSource = (Resolve-Path -LiteralPath $SourceFile).Path
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputFile)
    $normalizedPlatform = $Platform.ToLowerInvariant()

    # Ensure output parent directory exists
    $outputDir = Split-Path -Parent $resolvedOutput
    if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "🔨 Win-Debloat Launcher Compiler" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   Source:   $resolvedSource" -ForegroundColor Gray
    Write-Host "   Output:   $resolvedOutput" -ForegroundColor Gray
    Write-Host "   Target:   $normalizedPlatform" -ForegroundColor Gray

    # 2. Resolve High-DPI Manifest
    $manifestPath = $Manifest
    if (-not $manifestPath -or -not (Test-Path -LiteralPath $manifestPath)) {
        $defaultManifest = Join-Path $PSScriptRoot "..\src\core\app.manifest"
        if (Test-Path -LiteralPath $defaultManifest) {
            $manifestPath = (Resolve-Path -LiteralPath $defaultManifest).Path
        }
    }

    # 3. Resolve Application Icon
    $iconPath = $Icon
    if (-not $iconPath -or -not (Test-Path -LiteralPath $iconPath)) {
        $defaultIcon = Join-Path $PSScriptRoot "..\assets\logo.ico"
        if (Test-Path -LiteralPath $defaultIcon) {
            $iconPath = (Resolve-Path -LiteralPath $defaultIcon).Path
        }
    }

    # 4. Discover Compilers
    $availableCompilers = Find-CSharpCompiler -TargetPlatform $normalizedPlatform

    if ($availableCompilers.Count -eq 0) {
        throw "No suitable C# compiler found! Please install the .NET SDK or .NET Framework 4.8."
    }

    # 5. Compile with fallback handling
    $compilationSuccess = $false
    $lastErrorMessage = ""

    foreach ($compiler in $availableCompilers) {
        Write-Host "   Toolchain: $($compiler.Name)" -ForegroundColor Magenta

        # Determine platform flag for compiler
        $compilerPlatform = $normalizedPlatform
        if ($compiler.Type -eq "FrameworkCsc" -and $normalizedPlatform -eq "arm64") {
            Write-Host "   ℹ️  Classic csc.exe lacks native /platform:arm64 - compiling as AnyCPU (ARM64 compatible)" -ForegroundColor Yellow
            $compilerPlatform = "anycpu"
        }

        # Build compiler arguments
        $cArgs = [System.Collections.Generic.List[string]]::new()

        if ($compiler.Type -eq "DotNetSdk") {
            $cArgs.Add("exec")
            $cArgs.Add($compiler.RoslynDll)
        }

        $cArgs.Add("/target:exe")
        $cArgs.Add("/nologo")

        # Optimization
        if ($Optimize) {
            $cArgs.Add("/o+")
            Write-Host "   Optimization: Enabled (/o+)" -ForegroundColor DarkGray
        }
        else {
            $cArgs.Add("/o-")
        }

        # Platform targeting
        $cArgs.Add("/platform:$compilerPlatform")

        # High-DPI Manifest
        if ($manifestPath -and (Test-Path -LiteralPath $manifestPath)) {
            $cArgs.Add("/win32manifest:$manifestPath")
            Write-Host "   Manifest: $manifestPath (High-DPI / UTF-8)" -ForegroundColor DarkGray
        }

        # Win32 Icon
        if ($iconPath -and (Test-Path -LiteralPath $iconPath)) {
            $cArgs.Add("/win32icon:$iconPath")
            Write-Host "   Icon:     $iconPath" -ForegroundColor DarkGray
        }
        elseif ($Icon) {
            Write-Warning "Specified icon not found: $Icon"
        }

        # Embedded Resource (Payload zip)
        if ($Resource) {
            if (-not (Test-Path -LiteralPath $Resource)) {
                throw "Resource file to embed not found: $Resource"
            }
            $resolvedResource = (Resolve-Path -LiteralPath $Resource).Path
            $cArgs.Add("/resource:$resolvedResource")
            Write-Host "   Resource: $resolvedResource" -ForegroundColor DarkGray
        }

        # Standard assembly references (for Roslyn dotnet exec)
        if ($compiler.References.Count -gt 0) {
            foreach ($ref in $compiler.References) {
                $cArgs.Add("/r:$ref")
            }
        }

        # Output and Source
        $cArgs.Add("/out:$resolvedOutput")
        $cArgs.Add($resolvedSource)

        # Clean existing target binary before build to prevent false positive validation
        if (Test-Path -LiteralPath $resolvedOutput) {
            Remove-Item -LiteralPath $resolvedOutput -Force -ErrorAction SilentlyContinue
        }

        # Run compilation
        Write-Host "   Executing compilation..." -ForegroundColor DarkGray
        $procInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $procInfo.FileName = $compiler.Executable
        $procInfo.UseShellExecute = $false
        $procInfo.RedirectStandardOutput = $true
        $procInfo.RedirectStandardError = $true
        $procInfo.CreateNoWindow = $true

        foreach ($arg in $cArgs) {
            $procInfo.ArgumentList.Add($arg)
        }

        $proc = [System.Diagnostics.Process]::Start($procInfo)
        $stdOut = $proc.StandardOutput.ReadToEnd()
        $stdErr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $resolvedOutput)) {
            $compilationSuccess = $true
            break
        }
        else {
            $lastErrorMessage = "Compiler exited with code $($proc.ExitCode). Output: $stdOut $stdErr".Trim()
            Write-Warning "Compilation with $($compiler.Name) failed: $lastErrorMessage. Attempting fallback if available..."
        }
    }

    if (-not $compilationSuccess) {
        throw "All C# compilers failed to build $OutputFile. Last error: $lastErrorMessage"
    }

    # 6. Post-build Validation and Status Reporting
    if (-not (Test-Path -LiteralPath $resolvedOutput)) {
        throw "Build finished but output binary is missing: $resolvedOutput"
    }

    $outItem = Get-Item -LiteralPath $resolvedOutput
    $sizeBytes = $outItem.Length
    $sizeFormatted = if ($sizeBytes -ge 1MB) {
        "$([math]::Round($sizeBytes / 1MB, 2)) MB"
    } else {
        "$([math]::Round($sizeBytes / 1KB, 1)) KB"
    }

    Write-Host "✅ SUCCESS: Binary created successfully." -ForegroundColor Green
    Write-Host "   Path:     $($outItem.FullName)" -ForegroundColor Green
    Write-Host "   Size:     $sizeFormatted ($sizeBytes bytes)" -ForegroundColor Green
    Write-Host "   Platform: $normalizedPlatform" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}
catch {
    Write-Error "❌ Launcher Compilation Failed: $($_.Exception.Message)"
    exit 1
}
