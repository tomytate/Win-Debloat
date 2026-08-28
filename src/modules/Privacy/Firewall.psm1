#Requires -Version 7.6

<#
.SYNOPSIS
    Firewall management module for Win-Debloat
    
.DESCRIPTION
    Manages Windows Defender Firewall to block telemetry endpoints.
    Replaces the legacy, ineffective hosts file blocking method.
    
.NOTES
    Module: Win-Debloat.Modules.Privacy.Firewall
    Version: 2.0.0
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force

#region Blocked Domains
$Script:HostsFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
$Script:BlockMarkerStart = "# >>> Win-Debloat Telemetry Block Start <<<"
$Script:BlockMarkerEnd = "# >>> Win-Debloat Telemetry Block End <<<"
$Script:LegacyBlockMarkerStart = "# >>> Win-Debloat7 Telemetry Block Start <<<"
$Script:LegacyBlockMarkerEnd = "# >>> Win-Debloat7 Telemetry Block End <<<"
$Script:FirewallRuleName = "WinDebloat-Telemetry-Block"
$Script:LegacyFirewallRuleName = "WinDebloat7-Telemetry-Block"

# Curated list of telemetry domains to block
$Script:TelemetryDomains = @(
    "vortex.data.microsoft.com",
    "vortex-win.data.microsoft.com",
    "telecommand.telemetry.microsoft.com",
    "telecommand.telemetry.microsoft.com.nsatc.net",
    "oca.telemetry.microsoft.com",
    "oca.telemetry.microsoft.com.nsatc.net",
    "sqm.telemetry.microsoft.com",
    "sqm.telemetry.microsoft.com.nsatc.net",
    "watson.telemetry.microsoft.com",
    "watson.telemetry.microsoft.com.nsatc.net",
    "redir.metaservices.microsoft.com",
    "choice.microsoft.com",
    "choice.microsoft.com.nsatc.net",
    "df.telemetry.microsoft.com",
    "reports.wes.df.telemetry.microsoft.com",
    "wes.df.telemetry.microsoft.com",
    "services.wes.df.telemetry.microsoft.com",
    "sqm.df.telemetry.microsoft.com",
    "telemetry.microsoft.com",
    "watson.ppe.telemetry.microsoft.com",
    "telemetry.appex.bing.net",
    "telemetry.urs.microsoft.com",
    "settings-sandbox.data.microsoft.com",
    "settings-win.data.microsoft.com",
    "statsfe2.ws.microsoft.com",
    "statsfe1.ws.microsoft.com",
    "statsfe2.update.microsoft.com.akadns.net",
    "ads.msn.com",
    "ads1.msads.net",
    "ads1.msn.com",
    "a.ads1.msn.com",
    "a.ads2.msn.com",
    "adnexus.net",
    "adnxs.com",
    "az361816.vo.msecnd.net",
    "az512334.vo.msecnd.net",
    "arc.msn.com",
    "g.msn.com",
    "ris.api.iris.microsoft.com",
    "inference.location.live.net",
    "location-inference-westus.cloudapp.net",
    "feedback.windows.com",
    "feedback.microsoft-hohm.com",
    "feedback.search.microsoft.com",
    "activity.windows.com",
    "edge.activity.windows.com",
    "diagnostics.support.microsoft.com",
    "aimodels.microsoft.com",
    "wdcp.microsoft.com",
    "sydney.bing.com",
    "copilot.microsoft.com",
    "edgeservices.bing.com",
    "clarity.ms",
    "onesettings-public.azureedge.net",
    "browser.pipe.aria.microsoft.com",
    "pipe.aria.microsoft.com",
    "mobile.pipe.aria.microsoft.com",
    "us.pipe.aria.microsoft.com",
    "eu.pipe.aria.microsoft.com",
    "az.pipe.aria.microsoft.com",
    "events.data.microsoft.com",
    "self.events.data.microsoft.com",
    "mobile.events.data.microsoft.com",
    "v10.events.data.microsoft.com",
    "v20.events.data.microsoft.com",
    "v10c.events.data.microsoft.com",
    "v20c.events.data.microsoft.com",
    "eu-mobile.events.data.microsoft.com",
    "eu-v10.events.data.microsoft.com",
    "eu-v20.events.data.microsoft.com",
    "v10.vortex-win.data.microsoft.com",
    "vortex-sandbox.data.microsoft.com",
    "vortex-win-sandbox.data.microsoft.com",
    "web.vortex.data.microsoft.com",
    "functional.events.data.microsoft.com",
    "wdcp-ppe.microsoft.com",
    "directml.microsoft.com",
    "models.microsoft.com",
    "aifabric.microsoft.com",
    "ecs.office.com",
    "ecs-edge.office.com",
    "config.edge.skype.com",
    "onesettings-bn2.azureedge.net",
    "onesettings-co2.azureedge.net",
    "widgetcdn.azureedge.net",
    "shell.msn.com",
    "assets.msn.com",
    "watson.live.com",
    "survey.watson.microsoft.com",
    "nexusrules.office.com"
)
#endregion

#region Firewall Functions

<#
.SYNOPSIS
    Cleans up the deprecated hosts file block if it exists.
#>
function Remove-LegacyWinDebloatHostsBlock {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    try {
        if (-not (Test-Path $Script:HostsFilePath)) { return }
        if (-not $PSCmdlet.ShouldProcess($Script:HostsFilePath, "Remove legacy telemetry block")) { return }
        $content = Get-Content $Script:HostsFilePath -Raw -ErrorAction SilentlyContinue
        $hasBlock = ($content -match [regex]::Escape($Script:BlockMarkerStart)) -or ($content -match [regex]::Escape($Script:LegacyBlockMarkerStart))
        if ($hasBlock) {
            Write-Log -Message "Found legacy hosts file telemetry block. Cleaning up..." -Level Info
            $pattern1 = "$([regex]::Escape($Script:BlockMarkerStart))[\s\S]*?$([regex]::Escape($Script:BlockMarkerEnd))"
            $pattern2 = "$([regex]::Escape($Script:LegacyBlockMarkerStart))[\s\S]*?$([regex]::Escape($Script:LegacyBlockMarkerEnd))"
            $newContent = $content -replace $pattern1, ""
            $newContent = $newContent -replace $pattern2, ""
            $newContent = $newContent -replace "(\r?\n){3,}", "`n`n"
            Set-Content -Path $Script:HostsFilePath -Value $newContent.Trim() -Encoding UTF8
            Clear-DnsClientCache
            Write-Log -Message "Legacy hosts block removed successfully." -Level Success
        }
    }
    catch {
        Write-Log -Message "Failed to clean legacy hosts file: $($_.Exception.Message)" -Level Warning
    }
}

<#
.SYNOPSIS
    Adds telemetry blocking entries via Windows Defender Firewall.
#>
function Add-WinDebloatFirewallBlock {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()
    
    Remove-LegacyWinDebloatHostsBlock
    
    Write-Log -Message "Adding telemetry blocks via Windows Firewall..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows Firewall", "Block $($Script:TelemetryDomains.Count) telemetry domains")) {
        try {
            $existingRules = Get-NetFirewallRule -DisplayName $Script:FirewallRuleName -ErrorAction SilentlyContinue
            if ($existingRules) {
                Remove-NetFirewallRule -DisplayName $Script:FirewallRuleName -ErrorAction SilentlyContinue
            }
            $legacyRules = Get-NetFirewallRule -DisplayName $Script:LegacyFirewallRuleName -ErrorAction SilentlyContinue
            if ($legacyRules) {
                Remove-NetFirewallRule -DisplayName $Script:LegacyFirewallRuleName -ErrorAction SilentlyContinue
            }
            
            # Resolve the domains to IPs concurrently for maximum responsiveness.
            $ipsToBlock = [System.Collections.Generic.List[string]]::new()
            Write-Log -Message "Resolving telemetry domains to IPs..." -Level Info
            
            $tasks = foreach ($domain in $Script:TelemetryDomains) {
                $cleanDomain = $domain -replace ':\d+$', ''
                [pscustomobject]@{
                    Domain = $cleanDomain
                    Task   = [System.Net.Dns]::GetHostAddressesAsync($cleanDomain)
                }
            }
            
            # Wait up to 6 seconds max for all DNS queries to complete in parallel
            $allTasks = @($tasks | ForEach-Object { $_.Task })
            if ($allTasks.Count -gt 0) {
                [System.Threading.Tasks.Task]::WaitAll($allTasks, 6000) | Out-Null
            }
            
            foreach ($t in $tasks) {
                if ($t.Task.IsCompletedSuccessfully) {
                    foreach ($ip in $t.Task.Result) {
                        $ipsToBlock.Add($ip.IPAddressToString)
                    }
                }
                else {
                    Write-Verbose "Domain not resolvable (or blocked): $($t.Domain)"
                }
            }
            
            $uniqueIps = @($ipsToBlock | Select-Object -Unique)
            
            if ($uniqueIps.Count -gt 0) {
                # Split into chunks of 1000 IPs to avoid WMI command length limits
                $chunks = [Math]::Ceiling($uniqueIps.Count / 1000)
                for ($i = 0; $i -lt $chunks; $i++) {
                    $chunkIps = $uniqueIps | Select-Object -Skip ($i * 1000) -First 1000
                    New-NetFirewallRule -DisplayName $Script:FirewallRuleName -Direction Outbound -Action Block -RemoteAddress $chunkIps -ErrorAction Stop | Out-Null
                }
                Write-Log -Message "Added firewall rules blocking $($uniqueIps.Count) telemetry IP addresses." -Level Success
            } else {
                Write-Log -Message "Could not resolve any telemetry domains. They may already be blocked at the DNS level." -Level Warning
            }
        }
        catch {
            Write-Log -Message "Failed to add firewall rules: $($_.Exception.Message)" -Level Error
        }
    }
}

<#
.SYNOPSIS
    Removes Win-Debloat telemetry blocks from Windows Firewall.
#>
function Remove-WinDebloatFirewallBlock {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()
    
    Write-Log -Message "Removing telemetry firewall blocks..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows Firewall", "Remove telemetry blocks")) {
        try {
            $existingRules = Get-NetFirewallRule -DisplayName $Script:FirewallRuleName -ErrorAction SilentlyContinue
            if ($existingRules) {
                Remove-NetFirewallRule -DisplayName $Script:FirewallRuleName -ErrorAction Stop
                Write-Log -Message "Telemetry firewall blocks removed successfully." -Level Success
            } else {
                Write-Log -Message "No telemetry firewall blocks found." -Level Info
            }
            
            $legacyRules = Get-NetFirewallRule -DisplayName $Script:LegacyFirewallRuleName -ErrorAction SilentlyContinue
            if ($legacyRules) {
                Remove-NetFirewallRule -DisplayName $Script:LegacyFirewallRuleName -ErrorAction Stop
                Write-Log -Message "Legacy telemetry firewall blocks removed successfully." -Level Success
            }
            
            Remove-LegacyWinDebloatHostsBlock
        }
        catch {
            Write-Log -Message "Failed to remove firewall rules: $($_.Exception.Message)" -Level Error
        }
    }
}

<#
.SYNOPSIS
    Gets the current status of firewall blocking.
    
.OUTPUTS
    [psobject] Status object.
#>
function Get-WinDebloatFirewallStatus {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()
    
    $existingRules = @(Get-NetFirewallRule -DisplayName $Script:FirewallRuleName -ErrorAction SilentlyContinue)
    $legacyRules = @(Get-NetFirewallRule -DisplayName $Script:LegacyFirewallRuleName -ErrorAction SilentlyContinue)
    $allRules = @($existingRules + $legacyRules | Where-Object { $_ })
    $isBlocked = ($allRules.Count -gt 0)
    
    $blockedCount = 0
    if ($isBlocked) {
        $blockedCount = $allRules.Count # Represents rule chunks, not raw IPs
    }
    
    return [pscustomobject]@{
        FirewallRuleName        = $Script:FirewallRuleName
        TelemetryBlocked        = $isBlocked
        BlockedDomainCount      = $blockedCount
        AvailableDomainsToBlock = $Script:TelemetryDomains.Count
    }
}

<#
.SYNOPSIS
    Gets the list of domains that will be blocked.
#>
function Get-WinDebloatTelemetryDomains {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    
    return $Script:TelemetryDomains
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Remove-LegacyWinDebloat7HostsBlock' -Value 'Remove-LegacyWinDebloatHostsBlock'
Set-Alias -Name 'Add-WinDebloat7FirewallBlock' -Value 'Add-WinDebloatFirewallBlock'
Set-Alias -Name 'Remove-WinDebloat7FirewallBlock' -Value 'Remove-WinDebloatFirewallBlock'
Set-Alias -Name 'Get-WinDebloat7FirewallStatus' -Value 'Get-WinDebloatFirewallStatus'
Set-Alias -Name 'Get-WinDebloat7TelemetryDomains' -Value 'Get-WinDebloatTelemetryDomains'

Export-ModuleMember -Function @(
    'Remove-LegacyWinDebloatHostsBlock',
    'Add-WinDebloatFirewallBlock',
    'Remove-WinDebloatFirewallBlock',
    'Get-WinDebloatFirewallStatus',
    'Get-WinDebloatTelemetryDomains'
) -Alias @(
    'Remove-LegacyWinDebloat7HostsBlock',
    'Add-WinDebloat7FirewallBlock',
    'Remove-WinDebloat7FirewallBlock',
    'Get-WinDebloat7FirewallStatus',
    'Get-WinDebloat7TelemetryDomains'
)
