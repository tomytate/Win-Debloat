#Requires -Version 7.6

<#
.SYNOPSIS
    Premium color scheme and branding for Win-Debloat TUI (Cyber-Minimalist Edition)
    
.DESCRIPTION
    Defines the "Neon Cyber" color palette with TrueColor (RGB) support for PowerShell 7+.
    
.NOTES
    Module: Win-Debloat.UI.Colors
    Version: 1.7.1
#>

# Premium Color Scheme - Neon Cyber Palette
$Script:WD7Theme = @{
    # Hex Colors for Modern Terminals
    Colors   = @{
        Primary   = "#00D4FF" # Cyan Neon
        Secondary = "#7B2CBF" # Purple Neon
        Accent    = "#38BDF8" # Sky Blue Neon
        Success   = "#00FF88" # Green Neon
        Warning   = "#FFB800" # Orange Neon
        Error     = "#FF3366" # Red/Pink Neon
        Info      = "#A0A0B0" # Gray Blue
        Dark      = "#606070" # Muted
        White     = "#FFFFFF" # Pure White
    }

    Ansi16   = @{
        Primary   = "$([char]27)[96m"
        Secondary = "$([char]27)[95m"
        Accent    = "$([char]27)[94m"
        Success   = "$([char]27)[92m"
        Warning   = "$([char]27)[93m"
        Error     = "$([char]27)[91m"
        Info      = "$([char]27)[37m"
        Dark      = "$([char]27)[90m"
        White     = "$([char]27)[97m"
    }
    
    # Fallback for Legacy Consoles
    Fallback = @{
        Primary   = "Cyan"
        Secondary = "Magenta"
        Accent    = "Cyan"
        Success   = "Green"
        Warning   = "Yellow"
        Error     = "Red"
        Info      = "Gray"
        Dark      = "DarkGray"
        White     = "White"
    }
}

# Ensure UTF-8 Console Encoding for Braille Spinners & Fractional Unicode Blocks
try {
    if (-not [Console]::IsOutputRedirected -and [Console]::OutputEncoding.CodePage -ne 65001) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
} catch {
    $null = $_
}

try {
    if (-not [Console]::IsInputRedirected -and [Console]::InputEncoding.CodePage -ne 65001) {
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    }
} catch {
    $null = $_
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
║                        Ultimate System Optimizer & Toolbox v1.7.1 "Apex"                         ║
║                             PowerShell 7.6+ | Windows 11 26H2 Ready                             ║
╚═════════════════════════════════════════════════════════════════════════════════════════════════╝
"@

$Script:WD7HeaderCompact = @"
╔══════════════════════════════════════════════════════════════╗
║                  ▄▀▀▀▀▄ Win-Debloat ▄▀▀▀▀▄                   ║
║             Ultimate System Optimizer v1.7.1 "Apex"          ║
╚══════════════════════════════════════════════════════════════╝
"@

<#
.SYNOPSIS
    Tests whether the current terminal supports 24-bit TrueColor sequences.
#>
function Test-WDTrueColorSupport {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Test-WDHeadless) { return $false }
    if ($null -ne $PSStyle -and $PSStyle.OutputRendering -eq [System.Management.Automation.OutputRendering]::PlainText) {
        return $false
    }
    if ($env:WT_SESSION) { return $true }
    if ($env:COLORTERM -in @('truecolor', '24bit')) { return $true }
    if ($env:TERM_PROGRAM -in @('vscode', 'mintty', 'iTerm.app', 'warp', 'Ghostty', 'Alacritty', 'WezTerm', 'Hyper')) { return $true }
    if ($env:ConEmuANSI -eq 'ON') { return $true }
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT -and [System.Environment]::OSVersion.Version.Major -ge 10) {
        return $true
    }
    return $false
}

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
        
        [ValidateSet("Primary", "Secondary", "Accent", "Success", "Warning", "Error", "Info", "Dark", "White")]
        [string]$Color = "Info",
        
        [switch]$NoNewline,
        
        [switch]$Bold
    )
    
    # Check for RGB Support ($PSStyle exists in PS 7.2+)
    $useRgb = ($null -ne $PSStyle -and $PSStyle.OutputRendering -ne [System.Management.Automation.OutputRendering]::PlainText)
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
        $cc = $Script:WD7Theme.Fallback[$Color]
        if ($NoNewline) {
            Write-Host $Message -ForegroundColor $cc -NoNewline
        }
        else {
            Write-Host $Message -ForegroundColor $cc
        }
    }
}

<#
.SYNOPSIS
    Generates a 24-bit TrueColor linear RGB gradient across a string or multiline text.
.PARAMETER Text
    The input text to colorize.
.PARAMETER StartColor
    Starting color hex code (e.g. #00D4FF) or theme color name (e.g. Primary, Secondary, Success, Warning, Error, Info, Dark, White).
.PARAMETER EndColor
    Ending color hex code (e.g. #7B2CBF) or theme color name.
.PARAMETER LineByLine
    When specified, interpolates gradient across lines rather than individual characters.
.OUTPUTS
    [string] ANSI 24-bit TrueColor styled text.
#>
function Get-WD7GradientText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Text,

        [Parameter(Position = 1)]
        [string]$StartColor = "Primary",

        [Parameter(Position = 2)]
        [string]$EndColor = "Secondary",

        [switch]$LineByLine
    )

    process {
        if ([string]::IsNullOrEmpty($Text)) { return "" }

        # Resolve colors (Hex or Theme palette name)
        $startHex = if ($StartColor -match '^#([0-9a-fA-F]{6})$') { $StartColor }
                    elseif ($Script:WD7Theme.Colors.ContainsKey($StartColor)) { $Script:WD7Theme.Colors[$StartColor] }
                    else { $Script:WD7Theme.Colors["Primary"] }

        $endHex = if ($EndColor -match '^#([0-9a-fA-F]{6})$') { $EndColor }
                  elseif ($Script:WD7Theme.Colors.ContainsKey($EndColor)) { $Script:WD7Theme.Colors[$EndColor] }
                  else { $Script:WD7Theme.Colors["Secondary"] }

        # Check for TrueColor RGB support ($PSStyle exists in PS 7.2+)
        $useRgb = ($null -ne $PSStyle -and $PSStyle.OutputRendering -ne [System.Management.Automation.OutputRendering]::PlainText)
        if (-not $useRgb) {
            return $Text
        }

        $r1 = [Convert]::ToByte($startHex.Substring(1, 2), 16)
        $g1 = [Convert]::ToByte($startHex.Substring(3, 2), 16)
        $b1 = [Convert]::ToByte($startHex.Substring(5, 2), 16)

        $r2 = [Convert]::ToByte($endHex.Substring(1, 2), 16)
        $g2 = [Convert]::ToByte($endHex.Substring(3, 2), 16)
        $b2 = [Convert]::ToByte($endHex.Substring(5, 2), 16)

        $esc = [char]27
        $reset = "$esc[0m"

        if ($LineByLine) {
            $lines = $Text -split "\r?\n"
            $lineCount = $lines.Count
            if ($lineCount -le 1) {
                $ansi = "$esc[38;2;$r1;$g1;${b1}m"
                return "$ansi$Text$reset"
            }

            $result = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt $lineCount; $i++) {
                $t = $i / ($lineCount - 1)
                $r = [int][math]::Round($r1 + ($r2 - $r1) * $t)
                $g = [int][math]::Round($g1 + ($g2 - $g1) * $t)
                $b = [int][math]::Round($b1 + ($b2 - $b1) * $t)

                $ansi = "$esc[38;2;$r;$g;${b}m"
                [void]$result.AppendLine("$ansi$($lines[$i])$reset")
            }
            return $result.ToString().TrimEnd("`r`n")
        }
        else {
            $chars = $Text.ToCharArray()
            $charCount = $chars.Count
            if ($charCount -le 1) {
                $ansi = "$esc[38;2;$r1;$g1;${b1}m"
                return "$ansi$Text$reset"
            }

            $sb = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt $charCount; $i++) {
                $t = $i / ($charCount - 1)
                $r = [int][math]::Round($r1 + ($r2 - $r1) * $t)
                $g = [int][math]::Round($g1 + ($g2 - $g1) * $t)
                $b = [int][math]::Round($b1 + ($b2 - $b1) * $t)

                [void]$sb.Append("$esc[38;2;$r;$g;${b}m$($chars[$i])")
            }
            [void]$sb.Append($reset)
            return $sb.ToString()
        }
    }
}

<#
.SYNOPSIS
    Formats text as an OSC 8 terminal hyperlink with fallback for unsupported hosts.
.PARAMETER Text
    The link text to display.
.PARAMETER Url
    The target URL (e.g. https://github.com/tomytate/Win-Debloat).
.PARAMETER PlainFallback
    If set, appends the URL in parentheses in PlainText mode rather than returning just the text.
.OUTPUTS
    [string] OSC 8 hyperlink sequence or fallback string.
#>
function Format-WD7Hyperlink {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Url,

        [switch]$PlainFallback
    )

    if ([string]::IsNullOrEmpty($Text)) { return "" }
    if ([string]::IsNullOrEmpty($Url)) { return $Text }

    $useAnsi = ($null -ne $PSStyle -and $PSStyle.OutputRendering -ne [System.Management.Automation.OutputRendering]::PlainText)
    
    if ($useAnsi) {
        # Check if PSStyle has FormatHyperlink built-in (PS 7.2+)
        if ($PSStyle.PSObject.Methods['FormatHyperlink']) {
            try {
                return $PSStyle.FormatHyperlink($Text, [System.Uri]$Url)
            }
            catch {
                # Fall back to manual OSC 8 escape code if URI parsing fails
                $null = $_
            }
        }

        # Standard OSC 8 terminal hyperlink: ESC ] 8 ; ; URL ESC \ TEXT ESC ] 8 ; ; ESC \
        $esc = [char]27
        return "$esc]8;;$Url$esc\$Text$esc]8;;$esc\"
    }
    else {
        if ($PlainFallback) {
            return "$Text ($Url)"
        }
        return $Text
    }
}

<#
.SYNOPSIS
    Tests whether the current PowerShell session is running headless or redirected.
.OUTPUTS
    [bool]
#>
function Test-WDHeadless {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        if ([Console]::IsOutputRedirected -or [Console]::IsInputRedirected) {
            return $true
        }
        if ($null -eq [System.Console]::WindowWidth -or [System.Console]::WindowWidth -le 0) {
            return $true
        }
        return $false
    }
    catch {
        return $true
    }
}

<#
.SYNOPSIS
    Safely clears the console window without throwing exceptions in headless or redirected sessions.
.OUTPUTS
    [void]
#>
function Clear-WDConsoleSafe {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not (Test-WDHeadless)) {
        try {
            [System.Console]::Clear()
        }
        catch {
            try { Clear-Host } catch { $null = $_ }
        }
    }
}

<#
.SYNOPSIS
    Displays the standard styled header banner.
.PARAMETER Compact
    Display compact single-line style.
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
    
    Clear-WDConsoleSafe

    $termWidth = 100
    try {
        if (-not (Test-WDHeadless) -and [Console]::WindowWidth -gt 0) {
            $termWidth = [Console]::WindowWidth
        }
    } catch {
        $null = $_
    }
    
    if ($Compact -or $termWidth -lt 100) {
        # Compact Art with TrueColor Gradient
        $gradientCompact = Get-WD7GradientText -Text $Script:WD7HeaderCompact -StartColor Primary -EndColor Secondary -LineByLine
        Write-Host $gradientCompact
    }
    else {
        $lines = $Script:WD7Header -split "\r?\n"
        
        # Linear TrueColor gradient across logo lines (lines 2 to 7)
        # Border -> Info
        # ASCII Logo -> Primary (#00D4FF) to Secondary (#7B2CBF) gradient
        # Subtitle -> White
        
        $logoLines = [System.Collections.Generic.List[string]]::new()
        for ($k = 2; $k -le 7; $k++) {
            if ($k -lt $lines.Count) {
                $logoLines.Add($lines[$k])
            }
        }
        
        $gradientLogo = (Get-WD7GradientText -Text ($logoLines -join "`n") -StartColor Primary -EndColor Secondary -LineByLine) -split "\r?\n"
        
        $i = 0
        $logoIdx = 0
        foreach ($line in $lines) {
            if ($i -eq 0 -or $i -eq 1) { 
                Write-WD7Host $line -Color Info 
            }
            elseif ($i -ge 2 -and $i -le 7) { 
                if ($logoIdx -lt $gradientLogo.Count) {
                    Write-Host $gradientLogo[$logoIdx]
                    $logoIdx++
                }
                else {
                    Write-WD7Host $line -Color Primary
                }
            }
            elseif ($i -lt 10) { 
                Write-WD7Host $line -Color White 
            }
            else { 
                Write-WD7Host $line -Color Info 
            }
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
        [ValidateSet("Primary", "Secondary", "Accent", "Success", "Warning", "Error", "Info", "Dark", "White")]
        [string]$Color = "Info"
    )
    
    $width = 99
    try {
        if (-not (Test-WDHeadless) -and [Console]::WindowWidth -gt 20) {
            $width = [math]::Clamp([Console]::WindowWidth - 4, 38, 99)
        }
    } catch {
        $null = $_
    }

    $lineChar = "─"
    
    if ([string]::IsNullOrEmpty($Title)) {
        Write-WD7Host (" " * 2 + $lineChar * ($width - 4)) -Color $Color
    }
    else {
        # Centered visual separator
        $padLen = [int][math]::Max(0, [math]::Floor(($width - $Title.Length - 6) / 2))
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
    
    $filled = [int][math]::Round($Width * $Percent / 100)
    $empty = [int]($Width - $filled)
    
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

# ─────────────────────────────────────────────────────────────────────────────
# Virtual Terminal Sequences & Buffer Lifecycle Management
# ─────────────────────────────────────────────────────────────────────────────

$Script:VT = @{
    AltBufferEnter  = "$([char]27)[?1049h"
    AltBufferExit   = "$([char]27)[?1049l"
    CursorHide      = "$([char]27)[?25l"
    CursorShow      = "$([char]27)[?25h"
    CursorHome      = "$([char]27)[H"
    ClearBelow      = "$([char]27)[J"
    ClearLine       = "$([char]27)[2K"
    ClearLineEnd    = "$([char]27)[K"
    SyncUpdateBegin = "$([char]27)[?2026h" # DECSET 2026 Synchronized Output
    SyncUpdateEnd   = "$([char]27)[?2026l"
}

$Script:InAlternateBuffer = $false
$Script:CancelKeyHandler = $null
$Script:ProcessExitHandler = $null

<#
.SYNOPSIS
    Shows the terminal cursor.
#>
function Show-WDCursor {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not (Test-WDHeadless)) {
        try { [Console]::Out.Write("$([char]27)[?25h"); [Console]::Out.Flush() } catch { $null = $_ }
    }
}

<#
.SYNOPSIS
    Hides the terminal cursor.
#>
function Hide-WDCursor {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not (Test-WDHeadless)) {
        try { [Console]::Out.Write("$([char]27)[?25l"); [Console]::Out.Flush() } catch { $null = $_ }
    }
}

<#
.SYNOPSIS
    Enters the terminal alternate screen buffer, preserving shell history.
#>
function Enter-WDAlternateBuffer {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if ((Test-WDHeadless) -or $Script:InAlternateBuffer) { return }

    # Switch to Alternate Buffer and Hide Cursor
    try {
        [Console]::Out.Write("$($Script:VT.AltBufferEnter)$($Script:VT.CursorHide)")
        [Console]::Out.Flush()
    }
    catch {
        $null = $_
    }
    $Script:InAlternateBuffer = $true

    # Thread-safe CancelKeyPress handler
    $Script:CancelKeyHandler = [System.ConsoleCancelEventHandler]{
        param($sender, $eventArgs)
        try {
            [Console]::Out.Write("$([char]27)[?25h$([char]27)[?1049l")
            [Console]::Out.Flush()
        }
        catch {
            $null = $_
        }
        $Script:InAlternateBuffer = $false
    }
    try { [System.Console]::add_CancelKeyPress($Script:CancelKeyHandler) } catch { $null = $_ }

    # Thread-safe ProcessExit handler
    $Script:ProcessExitHandler = [System.EventHandler]{
        param($sender, $eventArgs)
        try {
            [Console]::Out.Write("$([char]27)[?25h$([char]27)[?1049l")
            [Console]::Out.Flush()
        }
        catch {
            $null = $_
        }
        $Script:InAlternateBuffer = $false
    }
    try { [System.AppDomain]::CurrentDomain.add_ProcessExit($Script:ProcessExitHandler) } catch { $null = $_ }
}

<#
.SYNOPSIS
    Exits the alternate screen buffer and restores the original terminal session.
#>
function Exit-WDAlternateBuffer {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not $Script:InAlternateBuffer) {
        Show-WDCursor
        return
    }

    if ($null -ne $Script:CancelKeyHandler) {
        try { [System.Console]::remove_CancelKeyPress($Script:CancelKeyHandler) } catch { $null = $_ }
        $Script:CancelKeyHandler = $null
    }

    if ($null -ne $Script:ProcessExitHandler) {
        try { [System.AppDomain]::CurrentDomain.remove_ProcessExit($Script:ProcessExitHandler) } catch { $null = $_ }
        $Script:ProcessExitHandler = $null
    }

    try {
        [Console]::Out.Write("$($Script:VT.CursorShow)$($Script:VT.AltBufferExit)")
        [Console]::Out.Flush()
    }
    catch {
        try { Write-Host -NoNewline "$($Script:VT.CursorShow)$($Script:VT.AltBufferExit)" } catch { $null = $_ }
    }
    $Script:InAlternateBuffer = $false
}

<#
.SYNOPSIS
    Renders an entire TUI frame atomically using synchronized double buffering.
#>
function Show-WDFrame {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$FrameContent
    )

    if (Test-WDHeadless) {
        Write-Host $FrameContent
        return
    }

    # Viewport boundary clamping to prevent terminal scrolling/flicker
    $maxLines = 0
    try {
        if ([Console]::WindowHeight -gt 0) { $maxLines = [Console]::WindowHeight }
    } catch {
        $null = $_
    }

    $lines = $FrameContent -split "\r?\n"
    if ($maxLines -gt 2 -and $lines.Count -ge $maxLines) {
        $FrameContent = ($lines[0..($maxLines - 1)] -join "`n")
    }

    # Atomic write: Begin sync -> Home cursor -> Frame -> Erase leftover rows -> End sync
    $atomicBuffer = "$($Script:VT.SyncUpdateBegin)$($Script:VT.CursorHome)$FrameContent$($Script:VT.ClearBelow)$($Script:VT.SyncUpdateEnd)"
    try {
        [Console]::Out.Write($atomicBuffer)
        [Console]::Out.Flush()
    }
    catch {
        Write-Host $FrameContent
    }
}

<#
.SYNOPSIS
    Renders an 8x sub-character smooth fractional progress bar with TrueColor gradient.
#>
function Show-WD7SmoothProgress {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [int]$Percent,
        [int]$Width = 28,
        [string]$Label = "",
        [string]$Detail = ""
    )

    $clampedPercent = [math]::Clamp($Percent, 0, 100)
    $subBlocks = @(' ', '▏', '▎', '▍', '▌', '▋', '▊', '▉', '█')

    $totalEighths = [math]::Round(($clampedPercent / 100) * ($Width * 8))
    $fullBlocks   = [math]::Floor($totalEighths / 8)
    $rem          = $totalEighths % 8
    $emptyBlocks  = [math]::Max(0, ($Width - $fullBlocks - ($rem -gt 0 ? 1 : 0)))
    $fractionChar = ($rem -gt 0 ? $subBlocks[$rem] : '')

    $filledText = ('█' * $fullBlocks) + $fractionChar
    $emptyText  = '░' * $emptyBlocks

    # TrueColor Gradient: Primary (#00D4FF) to Success (#00FF88)
    $coloredFilled = Get-WD7GradientText -Text $filledText -StartColor Primary -EndColor Success
    $coloredEmpty  = "$([char]27)[38;2;96;96;112m$emptyText$([char]27)[0m"

    $esc = [char]27
    $pctText = "$clampedPercent%".PadLeft(4)
    $line = "  $esc[1m$Label$esc[0m [$coloredFilled$coloredEmpty] $esc[38;2;0;212;255m$pctText$esc[0m $(if ($Detail) { "($Detail)" })"

    if (Test-WDHeadless) {
        Write-Host $line
    }
    else {
        Write-Host -NoNewline "`r$line$($Script:VT.ClearLineEnd)"
    }
}

<#
.SYNOPSIS
    Executes a scriptblock asynchronously with an interactive live Braille spinner.
#>
function Invoke-WDTaskWithSpinner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$SuccessMessage = "Completed successfully.",
        [string]$ErrorMessage = "Operation failed."
    )

    if (Test-WDHeadless) {
        Write-WD7Host "  [i] Starting: $Message..." -Color Info
        try {
            $result = & $ScriptBlock
            Write-WD7Host "  [✔] $SuccessMessage" -Color Success
            return $result
        }
        catch {
            Write-WD7Host "  [✖] ${ErrorMessage}: $($_.Exception.Message)" -Color Error
            throw
        }
    }

    $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # Launch task in lightweight background runspace
    $ps = [powershell]::Create()
    $null = $ps.AddScript($ScriptBlock)
    $async = $ps.BeginInvoke()

    $idx = 0
    try {
        while (-not $async.IsCompleted) {
            $elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            $frameChar = $frames[$idx]
            Write-Host -NoNewline "`r  $([char]27)[38;2;0;212;255m$frameChar$([char]27)[0m $Message $([char]27)[38;2;96;96;112m[${elapsed}s]$([char]27)[0m$($Script:VT.ClearLineEnd)"
            $idx = ($idx + 1) % $frames.Count
            Start-Sleep -Milliseconds 80
        }

        $result = $ps.EndInvoke($async)
        $sw.Stop()
        $totalSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        Write-Host "`r  $([char]27)[38;2;0;255;136m✔$([char]27)[0m $SuccessMessage $([char]27)[38;2;96;96;112m(${totalSec}s)$([char]27)[0m$($Script:VT.ClearLineEnd)"
        return $result
    }
    catch {
        $sw.Stop()
        $totalSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        Write-Host "`r  $([char]27)[38;2;255;51;102m✖$([char]27)[0m ${ErrorMessage}: $($_.Exception.Message) $([char]27)[38;2;96;96;112m(${totalSec}s)$([char]27)[0m$($Script:VT.ClearLineEnd)"
        throw
    }
    finally {
        $ps.Dispose()
    }
}

# Aliases for backward compatibility
Set-Alias -Name 'Get-WinDebloatGradientText' -Value 'Get-WD7GradientText'
Set-Alias -Name 'Get-WinDebloat7GradientText' -Value 'Get-WD7GradientText'
Set-Alias -Name 'Format-WinDebloatHyperlink' -Value 'Format-WD7Hyperlink'
Set-Alias -Name 'Format-WinDebloat7Hyperlink' -Value 'Format-WD7Hyperlink'
Set-Alias -Name 'Format-WD7Link' -Value 'Format-WD7Hyperlink'
Set-Alias -Name 'Test-WD7Headless' -Value 'Test-WDHeadless'
Set-Alias -Name 'Test-WD7TrueColorSupport' -Value 'Test-WDTrueColorSupport'
Set-Alias -Name 'Clear-WD7ConsoleSafe' -Value 'Clear-WDConsoleSafe'
Set-Alias -Name 'Enter-WD7AlternateBuffer' -Value 'Enter-WDAlternateBuffer'
Set-Alias -Name 'Exit-WD7AlternateBuffer' -Value 'Exit-WDAlternateBuffer'
Set-Alias -Name 'Show-WD7Cursor' -Value 'Show-WDCursor'
Set-Alias -Name 'Hide-WD7Cursor' -Value 'Hide-WDCursor'
Set-Alias -Name 'Show-WD7Frame' -Value 'Show-WDFrame'
Set-Alias -Name 'Render-WDFrame' -Value 'Show-WDFrame'
Set-Alias -Name 'Render-WD7Frame' -Value 'Show-WDFrame'
Set-Alias -Name 'Show-WinDebloat7SmoothProgress' -Value 'Show-WD7SmoothProgress'
Set-Alias -Name 'Invoke-WD7TaskWithSpinner' -Value 'Invoke-WDTaskWithSpinner'

Export-ModuleMember -Function Write-WD7Host,
    Show-WD7Header,
    Show-WD7Separator,
    Show-WD7Progress,
    Show-WD7SmoothProgress,
    Show-WD7StatusBadge,
    Get-WD7AnsiColor,
    Get-WD7GradientText,
    Format-WD7Hyperlink,
    Test-WDHeadless,
    Test-WDTrueColorSupport,
    Clear-WDConsoleSafe,
    Enter-WDAlternateBuffer,
    Exit-WDAlternateBuffer,
    Show-WDCursor,
    Hide-WDCursor,
    Show-WDFrame,
    Invoke-WDTaskWithSpinner `
    -Alias Get-WinDebloatGradientText,
    Get-WinDebloat7GradientText,
    Format-WinDebloatHyperlink,
    Format-WinDebloat7Hyperlink,
    Format-WD7Link,
    Test-WD7Headless,
    Test-WD7TrueColorSupport,
    Clear-WD7ConsoleSafe,
    Enter-WD7AlternateBuffer,
    Exit-WD7AlternateBuffer,
    Show-WD7Cursor,
    Hide-WD7Cursor,
    Show-WD7Frame,
    Render-WDFrame,
    Render-WD7Frame,
    Show-WinDebloat7SmoothProgress,
    Invoke-WD7TaskWithSpinner