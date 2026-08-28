#Requires -Version 7.6

<#
.SYNOPSIS
    Premium color scheme and branding for Win-Debloat TUI (Cyber-Minimalist Edition)
    
.DESCRIPTION
    Defines the "Neon Cyber" color palette with TrueColor (RGB) support for PowerShell 7+.
    
.NOTES
    Module: Win-Debloat.UI.Colors
    Version: 1.6.0
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
║                        Ultimate System Optimizer & Toolbox v1.6.0 "Apex"                         ║
║                             PowerShell 7.6+ | Windows 11 26H1 Ready                             ║
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
    
    Clear-Host
    
    if ($Compact) {
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

# Aliases for backward compatibility
Set-Alias -Name 'Get-WinDebloatGradientText' -Value 'Get-WD7GradientText'
Set-Alias -Name 'Get-WinDebloat7GradientText' -Value 'Get-WD7GradientText'
Set-Alias -Name 'Format-WinDebloatHyperlink' -Value 'Format-WD7Hyperlink'
Set-Alias -Name 'Format-WinDebloat7Hyperlink' -Value 'Format-WD7Hyperlink'
Set-Alias -Name 'Format-WD7Link' -Value 'Format-WD7Hyperlink'

Export-ModuleMember -Function Write-WD7Host,
    Show-WD7Header,
    Show-WD7Separator,
    Show-WD7Progress,
    Show-WD7StatusBadge,
    Get-WD7AnsiColor,
    Get-WD7GradientText,
    Format-WD7Hyperlink `
    -Alias Get-WinDebloatGradientText,
    Get-WinDebloat7GradientText,
    Format-WinDebloatHyperlink,
    Format-WinDebloat7Hyperlink,
    Format-WD7Link