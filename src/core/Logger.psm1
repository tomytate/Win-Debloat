#Requires -Version 7.6

<#
.SYNOPSIS
    Centralized logging module for Win-Debloat
    
.DESCRIPTION
    Provides structured logging to console and file with Win-Debloat branding colors.
    Includes log rotation and size management (SEC-008 fix).
    
.NOTES
    Module: Win-Debloat.Core.Logger
    Version: 1.5.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

class LogEntry {
    [datetime]$Timestamp
    [string]$Level
    [string]$Message
    [string]$Component
}

# Define Branding Colors
$Script:LogColors = @{
    Info    = "Gray"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Debug   = "DarkGray"
    Header  = "Blue"
}

$Script:LogFile = $null
$Script:MaxLogSizeBytes = 10MB
$Script:MaxLogFiles = 5

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
    
    Write-Log -Message "Logging started: $Script:LogFile" -Level Info
}

<#
.SYNOPSIS
    Writes a log message to console and file.
    
.PARAMETER Message
    The message to log.
    
.PARAMETER Level
    Log level: Info, Success, Warning, Error, Debug, Header.
    
.PARAMETER Component
    Optional component name for categorization.
#>
function Write-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Framework standard logging function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Logger outputs directly to console by design')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug", "Header")]
        [string]$Level = "Info",
        
        [string]$Component
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = if ($Script:LogColors.ContainsKey($Level)) { $Script:LogColors[$Level] } else { "Gray" }
    
    # Console Output
    $prefix = "[$timestamp] [$Level]"
    if ($Component) { $prefix += " [$Component]" }
    
    Write-Host "$prefix " -NoNewline -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor $color
    
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
            $logLine = "$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')) $filePrefix $Message$([Environment]::NewLine)"
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
