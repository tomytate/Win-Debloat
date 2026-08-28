#Requires -Version 7.6

<#
.SYNOPSIS
    Centralized logging module for Win-Debloat

.DESCRIPTION
    Provides structured logging to console and file with Win-Debloat Neon Cyber TrueColor branding.
    Includes log rotation, size management (SEC-008 fix), structured error and diagnostic recording,
    and clickable hyperlink terminal support.

.NOTES
    Module: Win-Debloat.Core.Logger
    Version: 1.6.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

class LogEntry {
    [datetime]$Timestamp
    [string]$Level
    [string]$Message
    [string]$Component
    [System.Management.Automation.ErrorRecord]$ErrorRecord
}

# Premium Color Scheme - Neon Cyber Palette TrueColor (24-bit RGB) ANSI Sequences
$Script:NeonColors = @{
    Primary   = "#00D4FF" # Cyan Neon
    Secondary = "#7B2CBF" # Purple Neon
    Success   = "#00FF88" # Green Neon
    Warning   = "#FFB800" # Orange Neon
    Error     = "#FF3366" # Red/Pink Neon
    Info      = "#A0A0B0" # Gray Blue
    Dark      = "#606070" # Muted Dark
    White     = "#FFFFFF" # Pure White
}

# Pre-rendered 24-bit TrueColor ANSI Escape Sequences for high-throughput logging
$Script:NeonAnsi = @{
    Primary   = "$([char]27)[38;2;0;212;255m"   # #00D4FF
    Secondary = "$([char]27)[38;2;123;44;191m"  # #7B2CBF
    Success   = "$([char]27)[38;2;0;255;136m"   # #00FF88
    Warning   = "$([char]27)[38;2;255;184;0m"   # #FFB800
    Error     = "$([char]27)[38;2;255;51;102m"  # #FF3366
    Info      = "$([char]27)[38;2;160;160;176m" # #A0A0B0
    Dark      = "$([char]27)[38;2;96;96;112m"   # #606070
    White     = "$([char]27)[38;2;255;255;255m" # #FFFFFF
    Debug     = "$([char]27)[38;2;96;96;112m"   # #606070
    Header    = "$([char]27)[38;2;0;212;255m"   # #00D4FF
    Reset     = "$([char]27)[0m"
    Bold      = "$([char]27)[1m"
}

# Fallback ConsoleColors for Legacy or PlainText Consoles
$Script:LogColors = @{
    Info    = "Gray"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Debug   = "DarkGray"
    Header  = "Cyan"
}

$Script:LogFile = $null
$Script:MaxLogSizeBytes = 10MB
$Script:MaxLogFiles = 5

<#
.SYNOPSIS
    Formats an ErrorRecord into a structured diagnostic string for file logging.
.PARAMETER ErrorRecord
    The ErrorRecord instance to format.
.OUTPUTS
    [string] Structured diagnostic error string.
#>
$Script:FormatStructuredError = {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Justification = 'Diagnostic inspection is non-fatal')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("  [ERROR DETAILS]")
    [void]$sb.AppendLine("  Timestamp:             $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff'))")

    if ($null -ne $ErrorRecord.Exception) {
        [void]$sb.AppendLine("  Exception Type:        $($ErrorRecord.Exception.GetType().FullName)")
        [void]$sb.AppendLine("  Exception Message:     $($ErrorRecord.Exception.Message)")
        [void]$sb.AppendLine("  HResult:               $($ErrorRecord.Exception.HResult)")
    }

    if (-not [string]::IsNullOrEmpty($ErrorRecord.FullyQualifiedErrorId)) {
        [void]$sb.AppendLine("  FullyQualifiedErrorId: $($ErrorRecord.FullyQualifiedErrorId)")
    }

    if ($null -ne $ErrorRecord.CategoryInfo) {
        [void]$sb.AppendLine("  CategoryInfo:          $($ErrorRecord.CategoryInfo.ToString())")
    }

    if ($null -ne $ErrorRecord.TargetObject) {
        [void]$sb.AppendLine("  TargetObject:          $($ErrorRecord.TargetObject)")
    }

    if ($null -ne $ErrorRecord.InvocationInfo) {
        [void]$sb.AppendLine("  InvocationInfo:")
        if (-not [string]::IsNullOrEmpty($ErrorRecord.InvocationInfo.MyCommand)) {
            [void]$sb.AppendLine("    Command:             $($ErrorRecord.InvocationInfo.MyCommand)")
        }
        if (-not [string]::IsNullOrEmpty($ErrorRecord.InvocationInfo.ScriptName)) {
            [void]$sb.AppendLine("    Script:              $($ErrorRecord.InvocationInfo.ScriptName)")
        }
        [void]$sb.AppendLine("    Line Number:         $($ErrorRecord.InvocationInfo.ScriptLineNumber)")
        [void]$sb.AppendLine("    Offset:              $($ErrorRecord.InvocationInfo.OffsetInLine)")
        if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.InvocationInfo.Line)) {
            [void]$sb.AppendLine("    Line Text:           $($ErrorRecord.InvocationInfo.Line.Trim())")
        }
        if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.InvocationInfo.PositionMessage)) {
            $pos = $ErrorRecord.InvocationInfo.PositionMessage.Trim() -replace '\r?\n', "`n    "
            [void]$sb.AppendLine("    Position:            $pos")
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ScriptStackTrace)) {
        $sst = $ErrorRecord.ScriptStackTrace.Trim() -replace '\r?\n', "`n    "
        [void]$sb.AppendLine("  Script StackTrace:")
        [void]$sb.AppendLine("    $sst")
    }

    if ($null -ne $ErrorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.Exception.StackTrace)) {
        $est = $ErrorRecord.Exception.StackTrace.Trim() -replace '\r?\n', "`n    "
        [void]$sb.AppendLine("  Exception StackTrace:")
        [void]$sb.AppendLine("    $est")
    }

    # Inner exceptions traversal
    if ($null -ne $ErrorRecord.Exception) {
        $inner = $ErrorRecord.Exception.InnerException
        $innerDepth = 1
        while ($null -ne $inner) {
            [void]$sb.AppendLine("  InnerException [$innerDepth]:")
            [void]$sb.AppendLine("    Type:                $($inner.GetType().FullName)")
            [void]$sb.AppendLine("    Message:             $($inner.Message)")
            [void]$sb.AppendLine("    HResult:             $($inner.HResult)")
            if (-not [string]::IsNullOrWhiteSpace($inner.StackTrace)) {
                $ist = $inner.StackTrace.Trim() -replace '\r?\n', "`n      "
                [void]$sb.AppendLine("    StackTrace:")
                [void]$sb.AppendLine("      $ist")
            }
            $inner = $inner.InnerException
            $innerDepth++
        }
    }

    # Get-Error Extended Diagnostic Data
    try {
        if (Get-Command Get-Error -ErrorAction SilentlyContinue) {
            $getErrOutput = (Get-Error -InputObject $ErrorRecord -ErrorAction SilentlyContinue | Out-String -Width 120).TrimEnd()
            if (-not [string]::IsNullOrWhiteSpace($getErrOutput)) {
                [void]$sb.AppendLine("  --- Extended Diagnostic Data (Get-Error) ---")
                [void]$sb.AppendLine($getErrOutput)
                [void]$sb.AppendLine("  -------------------------------------------")
            }
        }
    }
    catch {
        Write-Verbose "Extended diagnostic capture skipped: $($_.Exception.Message)"
    }

    return $sb.ToString().TrimEnd()
}

<#
.SYNOPSIS
    Initializes the logging system.

.PARAMETER Path
    Directory path for log files.

.PARAMETER MaxSizeBytes
    Maximum log file size before rotation. Default: 10MB.

.PARAMETER MaxFiles
    Maximum number of rotated log files to keep. Default: 5.
#>
function Start-WinDebloatLogging {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Path = "$env:ProgramData\Win-Debloat\Logs",

        [long]$MaxSizeBytes = 10MB,

        [int]$MaxFiles = 5
    )

    $Script:MaxLogSizeBytes = $MaxSizeBytes
    $Script:MaxLogFiles = $MaxFiles

    if (-not (Test-Path -LiteralPath $Path)) {
        if ($PSCmdlet.ShouldProcess($Path, "Create Log Directory")) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Script:LogFile = "$Path\Win-Debloat-$timestamp.log"

    # Clean old logs (SEC-008 fix: Log rotation)
    try {
        if (Test-Path -LiteralPath $Path) {
            $existingLogs = @(Get-ChildItem -LiteralPath $Path -Filter "Win-Debloat*.log" -ErrorAction Stop |
                Sort-Object CreationTime -Descending)

            if ($existingLogs.Count -gt $Script:MaxLogFiles) {
                $toDelete = $existingLogs | Select-Object -Skip $Script:MaxLogFiles
                foreach ($oldLog in $toDelete) {
                    if ($PSCmdlet.ShouldProcess($oldLog.FullName, "Rotate and Remove Old Log")) {
                        Remove-Item -LiteralPath $oldLog.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    catch {
        # Non-fatal - continue without cleanup
        Write-Verbose "Log cleanup skipped: $($_.Exception.Message)"
    }

    # Format clickable file:/// hyperlink if supported (PSStyle in PS 7.2+)
    $logDisplayPath = $Script:LogFile
    try {
        if ($null -ne $PSStyle -and ($PSStyle | Get-Member -Name "FormatHyperlink") -and $PSStyle.OutputRendering -ne [System.Management.Automation.OutputRendering]::PlainText) {
            $fullLogPath = [System.IO.Path]::GetFullPath($Script:LogFile)
            $logUri = [System.Uri]::new("file:///$($fullLogPath -replace '\\', '/')")
            $logDisplayPath = $PSStyle.FormatHyperlink($Script:LogFile, $logUri)
        }
    }
    catch {
        $logDisplayPath = $Script:LogFile
    }

    Write-Log -Message "Logging started: $logDisplayPath" -Level Info
}

<#
.SYNOPSIS
    Writes a log message to console and file.

.PARAMETER Message
    The message to log. If omitted when -ErrorRecord is specified, defaults to the error message.

.PARAMETER Level
    Log level: Info, Success, Warning, Error, Debug, Header.

.PARAMETER Component
    Optional component name for categorization.

.PARAMETER ErrorRecord
    Optional ErrorRecord capturing structured exception details, stack traces, and Get-Error extended diagnostic data.
#>
function Write-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Framework standard logging function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Logger outputs directly to console by design')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [ValidateSet("Info", "Success", "Warning", "Error", "Debug", "Header")]
        [string]$Level = "Info",

        [string]$Component,

        [Parameter(Position = 1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        if ($null -ne $ErrorRecord) {
            $Message = if ($ErrorRecord.Exception -and $ErrorRecord.Exception.Message) {
                $ErrorRecord.Exception.Message
            }
            else {
                $ErrorRecord.ToString()
            }
        }
        else {
            $Message = ""
        }
    }

    if (-not $PSBoundParameters.ContainsKey('Level') -and $null -ne $ErrorRecord) {
        $Level = "Error"
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $useAnsi = ($null -ne $PSStyle -and $PSStyle.OutputRendering -ne [System.Management.Automation.OutputRendering]::PlainText)

    # Console Output with Neon Cyber 24-bit TrueColor
    if ($useAnsi) {
        $cDark  = $Script:NeonAnsi.Dark
        $cReset = $Script:NeonAnsi.Reset
        $cLvl   = if ($Script:NeonAnsi.ContainsKey($Level)) { $Script:NeonAnsi[$Level] } else { $Script:NeonAnsi.Info }

        $lvlFormatted = if ($Level -eq "Header") {
            "$($Script:NeonAnsi.Bold)$cLvl$Level$cReset"
        }
        else {
            "$cLvl$Level$cReset"
        }

        $prefix = "$cDark[$timestamp]$cReset $cDark[$lvlFormatted$cDark]$cReset"

        if ($Component) {
            $cComp = $Script:NeonAnsi.Secondary
            $prefix += " $cDark[$cComp$Component$cDark]$cReset"
        }

        $cMsg = switch ($Level) {
            "Error"   { $Script:NeonAnsi.Error }
            "Warning" { $Script:NeonAnsi.Warning }
            "Success" { $Script:NeonAnsi.Success }
            "Header"  { "$($Script:NeonAnsi.Bold)$($Script:NeonAnsi.Primary)" }
            "Debug"   { $Script:NeonAnsi.Debug }
            default   { $Script:NeonAnsi.White }
        }

        Write-Host "$prefix $cMsg$Message$cReset"
    }
    else {
        # Fallback to ConsoleColor for Legacy or PlainText Consoles
        $color = if ($Script:LogColors.ContainsKey($Level)) { $Script:LogColors[$Level] } else { "Gray" }
        $prefix = "[$timestamp] [$Level]"
        if ($Component) { $prefix += " [$Component]" }

        # Clean any ANSI escape sequences from message in PlainText mode
        $plainMsg = $Message -replace '\x1b\[[0-9;]*[a-zA-Z]|\x1b\]8;;.*?\x1b\\', ''
        Write-Host "$prefix " -NoNewline -ForegroundColor DarkGray
        Write-Host $plainMsg -ForegroundColor $color
    }

    # File Output
    if ($Script:LogFile) {
        # Check file size and rotate if needed (SEC-008 fix) using direct .NET IO for speed
        try {
            if ([System.IO.File]::Exists($Script:LogFile)) {
                $fi = [System.IO.FileInfo]::new($Script:LogFile)
                if ($fi.Length -gt $Script:MaxLogSizeBytes) {
                    $basePath = Split-Path $Script:LogFile -Parent
                    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
                    $Script:LogFile = "$basePath\Win-Debloat-$ts.log"
                }
            }

            $filePrefix = if ($Component) { "[$Level] [$Component]" } else { "[$Level]" }
            $cleanMessage = $Message -replace '\x1b\[[0-9;]*[a-zA-Z]|\x1b\]8;;.*?\x1b\\', ''
            $logLine = "$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')) $filePrefix $cleanMessage$([Environment]::NewLine)"

            if ($null -ne $ErrorRecord) {
                $errDetails = & $Script:FormatStructuredError -ErrorRecord $ErrorRecord
                $logLine += "$errDetails$([Environment]::NewLine)"
            }

            [System.IO.File]::AppendAllText($Script:LogFile, $logLine, [System.Text.Encoding]::UTF8)
        }
        catch {
            # Silent fail for log writes - don't disrupt main operation
            Write-Verbose "Log write failed: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Gets the current log file path.
#>
function Get-WinDebloatLogPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $Script:LogFile
}

Set-Alias -Name Start-WD7Logging -Value Start-WinDebloatLogging
Set-Alias -Name Start-WinDebloat7Logging -Value Start-WinDebloatLogging
Set-Alias -Name Start-WDLogging -Value Start-WinDebloatLogging
Set-Alias -Name Get-WD7LogPath -Value Get-WinDebloatLogPath
Set-Alias -Name Get-WinDebloat7LogPath -Value Get-WinDebloatLogPath
Set-Alias -Name Get-WDLogPath -Value Get-WinDebloatLogPath

Export-ModuleMember -Function Start-WinDebloatLogging, Write-Log, Get-WinDebloatLogPath `
                    -Alias Start-WD7Logging, Start-WinDebloat7Logging, Start-WDLogging, Get-WD7LogPath, Get-WinDebloat7LogPath, Get-WDLogPath
