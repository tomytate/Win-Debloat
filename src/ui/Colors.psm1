#Requires -Version 7.6

<#
.SYNOPSIS
    Premium color scheme and branding for Win-Debloat TUI (Cyber-Minimalist Edition)
    
.DESCRIPTION
    Defines the "Neon Cyber" color palette with TrueColor (RGB) support for PowerShell 7+.
    
.NOTES
    Module: Win-Debloat.UI.Colors
    Version: 1.5.0
#>

# Premium Color Scheme - Neon Cyber Palette
$Script:WD7Theme = @{
    # Hex Colors for Modern Terminals
    Colors   = @{
        Primary   = "#00D4FF" # Cyan Neon
        Secondary = "#7B2CBF" # Purple Neon
        Success   = "#00FF88" # Green Neon
        Warning   = "#FFB800" # Orange Neon
        Error     = "#FF3366" # Red/Pink Neon
        Info      = "#A0A0B0" # Gray Blue
        Dark      = "#606070" # Muted
        White     = "#FFFFFF" # Pure White
    }
    
    # Fallback for Legacy Consoles
    Fallback = @{
        Primary   = "Cyan"
        Secondary = "Magenta"
        Success   = "Green"
        Warning   = "Yellow"
        Error     = "Red"
        Info      = "Gray"
        Dark      = "DarkGray"
        White     = "White"
    }
}

# Original Classic ASCII Header (Restored)
$Script:WD7Header = @"
╔═════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                                 ║
║     ██╗    ██╗██╗███╗   ██╗      ██████╗ ███████╗██████╗ ██╗      ██████╗  █████╗ ████████╗     ║
║     ██║    ██║██║████╗  ██║      ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗██╔══██╗╚══██╔══╝     ║
║     ██║ █╗ ██║██║██╔██╗ ██║█████╗██║  ██║█████╗  ██████╔╝██║     ██║   ██║███████║   ██║        ║
║     ██║███╗██║██║██║╚██╗██║╚════╝██║  ██║██╔══╝  ██╔══██╗██║     ██║   ██║██╔══██║   ██║        ║
║     ╚███╔███╔╝██║██║ ╚████║      ██████╔╝███████╗██████╔╝███████╗╚██████╔╝██║  ██║   ██║        ║
║      ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝      ╚═════╝ ╚══════╝╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝        ║
║                        Ultimate System Optimizer & Toolbox v1.5.0 "Top G"                       ║
║                             PowerShell 7.6+ | Windows 11 25H2 Ready                             ║
╚═════════════════════════════════════════════════════════════════════════════════════════════════╝
"@

$Script:WD7HeaderCompact = @"
╔══════════════════════════════════════════════════════════════╗
║                  ▄▀▀▀▀▄ Win-Debloat ▄▀▀▀▀▄                   ║
║                  Ultimate System Optimizer                   ║
╚══════════════════════════════════════════════════════════════╝
"@

<#
.SYNOPSIS
    Converts a HEX color code into ANSI TrueColor escape sequence.
.PARAMETER Hex
    Hexadecimal color code string (e.g. #00D4FF).
.OUTPUTS
    [string] ANSI 24-bit color sequence.
#>
function Get-WD7AnsiColor {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Hex)
    
    if ($Hex -notmatch "^#([0-9a-fA-F]{6})$") { return "" }
    
    $r = [Convert]::ToByte($Hex.Substring(1, 2), 16)
    $g = [Convert]::ToByte($Hex.Substring(3, 2), 16)
    $b = [Convert]::ToByte($Hex.Substring(5, 2), 16)
    
    # Return ANSI sequence
    return "$([char]27)[38;2;$r;$g;${b}m"
}

<#
.SYNOPSIS
    Outputs styled message to the host with theme color.
.PARAMETER Message
    The message text to output.
.PARAMETER Color
    Theme color identifier.
.PARAMETER NoNewline
    Whether to omit the trailing newline.
.PARAMETER Bold
    Whether to apply bold formatting.
.OUTPUTS
    [void]
#>
function Write-WD7Host {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Terminal TUI styling')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,
        
        [ValidateSet("Primary", "Secondary", "Success", "Warning", "Error", "Info", "Dark", "White")]
        [string]$Color = "Info",
        
        [switch]$NoNewline,
        
        [switch]$Bold
    )
    
    # Check for RGB Support ($PSStyle exists in PS 7.2+)
    $useRgb = $null -ne $PSStyle
    $ansi = ""
    $reset = ""
    
    if ($useRgb) {
        $hex = $Script:WD7Theme.Colors[$Color]
        $ansi = Get-WD7AnsiColor -Hex $hex
        $reset = "$([char]27)[0m"
        
        if ($Bold) {
            $ansi += "$([char]27)[1m"
        }
        
        # Write directly to host to strict control
        if ($NoNewline) {
            Write-Host "$ansi$Message$reset" -NoNewline
        }
        else {
            Write-Host "$ansi$Message$reset"
        }
    }
    else {
        # Fallback to ConsoleColor
        $consoleColor = $Script:WD7Theme.Fallback[$Color]
        if ($NoNewline) {
            Write-Host $Message -ForegroundColor $consoleColor -NoNewline
        }
        else {
            Write-Host $Message -ForegroundColor $consoleColor
        }
    }
}

<#
.SYNOPSIS
    Renders the Win-Debloat ASCII header banner.
.PARAMETER Compact
    Whether to render the compact single-box header.
.OUTPUTS
    [void]
#>
function Show-WD7Header {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Terminal TUI styling')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$Compact
    )
    
    Clear-Host
    
    if ($Compact) {
        # Compact Art
        $lines = $Script:WD7HeaderCompact -split "`n"
        foreach ($line in $lines) { Write-WD7Host $line -Color Primary }
    }
    else {
        $lines = $Script:WD7Header -split "`n"
        
        # Original gradient logic (approximate mapping)
        # Top border -> Primary
        # Logos -> Primary to Secondary gradient
        # Bottom -> White/Info
        
        $i = 0
        foreach ($line in $lines) {
            if ($i -eq 0) { Write-WD7Host $line -Color Info } # Top Border
            elseif ($i -lt 5) { Write-WD7Host $line -Color Primary } # Top half logo
            elseif ($i -lt 9) { Write-WD7Host $line -Color Secondary } # Bottom half logo
            elseif ($i -lt 11) { Write-WD7Host $line -Color White } # Text
            else { Write-WD7Host $line -Color Info } # Bottom Border
            $i++
        }
    }
    
    Write-Host ""
}

<#
.SYNOPSIS
    Renders a styled divider or section title separator.
.PARAMETER Title
    Optional centered title string.
.PARAMETER Color
    Theme color identifier.
.OUTPUTS
    [void]
#>
function Show-WD7Separator {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$Title = "",
        [ValidateSet("Primary", "Secondary", "Success", "Warning", "Error", "Info", "Dark", "White")]
        [string]$Color = "Info"
    )
    
    $width = 99 # Match header width roughly
    $lineChar = "─"
    
    if ([string]::IsNullOrEmpty($Title)) {
        Write-WD7Host (" " * 2 + $lineChar * ($width - 4)) -Color $Color
    }
    else {
        # Centered visual separator
        $padLen = [math]::Max(0, ($width - $Title.Length - 6) / 2)
        $padding = $lineChar * $padLen
        Write-WD7Host (" " * 2 + "$padding $Title $padding") -Color $Color
    }
}

<#
.SYNOPSIS
    Renders an inline graphical progress bar.
.PARAMETER Percent
    Percentage completed (0-100).
.PARAMETER Width
    Width of the bar characters in the console.
.PARAMETER Label
    Optional progress label text.
.OUTPUTS
    [void]
#>
function Show-WD7Progress {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Terminal TUI styling')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [int]$Percent,
        [int]$Width = 40,
        [string]$Label = ""
    )
    
    $filled = [math]::Round($Width * $Percent / 100)
    $empty = $Width - $filled
    
    # Modern progress block
    $bar = "█" * $filled + "░" * $empty 
    $display = "$Label [$bar] $Percent%"
    
    # Clear line (CR) and write
    Write-Host "`r$display" -NoNewline -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Renders a status badge with an icon and label.
.PARAMETER Label
    Status label text.
.PARAMETER Status
    Status level (Success, Warning, Error, Info).
.OUTPUTS
    [void]
#>
function Show-WD7StatusBadge {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$Label,
        [ValidateSet("Success", "Warning", "Error", "Info")]
        [string]$Status
    )
    
    $icon = switch ($Status) {
        "Success" { "✔" }
        "Warning" { "⚠" }
        "Error" { "✖" }
        "Info" { "ℹ" }
    }
    
    Write-WD7Host "  $icon " -Color $Status -NoNewline
    Write-WD7Host $Label -Color White
}

Export-ModuleMember -Function Write-WD7Host, Show-WD7Header, Show-WD7Separator, Show-WD7Progress, Show-WD7StatusBadge