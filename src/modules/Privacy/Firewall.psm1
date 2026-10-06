#Requires -Version 7.6

<#
.SYNOPSIS
    Firewall management module for Win-Debloat
    
.DESCRIPTION
    Manages Windows Defender Firewall to block telemetry endpoints.
    Replaces the legacy, ineffective hosts file blocking method.
    
.NOTES
    Module: Win-Debloat.Modules.Privacy.Firewall
    Version: 1.7.1
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
    Validates whether an IP address is a safe, routable public external IP.
.DESCRIPTION
    Strictly filters out loopback (127.0.0.0/8, ::1), unspecified (0.0.0.0, ::),
    broadcast (255.255.255.255), multicast (224.0.0.0/4, ff00::/8), link-local
    (169.254.0.0/16, fe80::/10), CGNAT (100.64.0.0/10), and RFC 1918 private ranges
    (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) to ensure localhost, internal services,
    and gateway routing are never inadvertently blocked by Windows Defender Firewall.
.PARAMETER IpAddress
    The IP address string to validate.
.OUTPUTS
    [bool] True if the IP is a safe, routable public address; otherwise False.
#>
function Test-IsSafeExternalIp {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$IpAddress
    )

    process {
        if ([string]::IsNullOrWhiteSpace($IpAddress)) {
            return $false
        }

        $ip = $null
        if (-not [System.Net.IPAddress]::TryParse($IpAddress.Trim(), [ref]$ip)) {
            return $false
        }

        # Check .NET built-in loopback check
        if ([System.Net.IPAddress]::IsLoopback($ip)) {
            return $false
        }

        # Handle IPv4-mapped IPv6 addresses (e.g., ::ffff:127.0.0.1)
        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6 -and $ip.IsIPv4MappedToIPv6) {
            $ip = $ip.MapToIPv4()
        }

        # IPv4 Checks
        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            $bytes = $ip.GetAddressBytes()

            # 0.0.0.0/8 (Current network / "This host")
            if ($bytes[0] -eq 0) { return $false }

            # 127.0.0.0/8 (Loopback)
            if ($bytes[0] -eq 127) { return $false }

            # 255.255.255.255 (Limited Broadcast)
            if ($bytes[0] -eq 255 -and $bytes[1] -eq 255 -and $bytes[2] -eq 255 -and $bytes[3] -eq 255) { return $false }

            # 224.0.0.0/4 (Multicast: 224.0.0.0 to 239.255.255.255)
            if ($bytes[0] -ge 224 -and $bytes[0] -le 239) { return $false }

            # 240.0.0.0/4 (Reserved for future use: 240.0.0.0 to 255.255.255.254)
            if ($bytes[0] -ge 240) { return $false }

            # 169.254.0.0/16 (Link-Local / APIPA)
            if ($bytes[0] -eq 169 -and $bytes[1] -eq 254) { return $false }

            # RFC 1918 Private ranges:
            # 10.0.0.0/8
            if ($bytes[0] -eq 10) { return $false }
            # 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
            if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) { return $false }
            # 192.168.0.0/16
            if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) { return $false }

            # RFC 6598 Shared Address Space / CGNAT: 100.64.0.0/10 (100.64.0.0 - 100.127.255.255)
            if ($bytes[0] -eq 100 -and $bytes[1] -ge 64 -and $bytes[1] -le 127) { return $false }

            # RFC 6890 / RFC 7335 / RFC 7600: 192.0.0.0/24 (IETF Protocol Assignments)
            if ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0) { return $false }

            # RFC 5737 Documentation ranges:
            # 192.0.2.0/24 (TEST-NET-1)
            if ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -eq 2) { return $false }
            # 198.51.100.0/24 (TEST-NET-2)
            if ($bytes[0] -eq 198 -and $bytes[1] -eq 51 -and $bytes[2] -eq 100) { return $false }
            # 203.0.113.0/24 (TEST-NET-3)
            if ($bytes[0] -eq 203 -and $bytes[1] -eq 0 -and $bytes[2] -eq 113) { return $false }

            # RFC 2544 / RFC 6815: 198.18.0.0/15 (Benchmarking)
            if ($bytes[0] -eq 198 -and ($bytes[1] -eq 18 -or $bytes[1] -eq 19)) { return $false }

            # RFC 3068 / RFC 7526: 192.88.99.0/24 (6to4 Relay Anycast)
            if ($bytes[0] -eq 192 -and $bytes[1] -eq 88 -and $bytes[2] -eq 99) { return $false }

            return $true
        }

        # IPv6 Checks
        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            if ($ip.IsIPv6LinkLocal -or $ip.IsIPv6Multicast -or $ip.IsIPv6SiteLocal) {
                return $false
            }

            $ipStr = $ip.ToString()
            if ($ipStr -eq "::" -or $ipStr -eq "::1") {
                return $false
            }

            $v6Bytes = $ip.GetAddressBytes()

            # Deprecated IPv4-Compatible IPv6: ::/96 (RFC 4291 Section 2.5.5.1)
            $allFirst12Zero = $true
            for ($idx = 0; $idx -lt 12; $idx++) {
                if ($v6Bytes[$idx] -ne 0) {
                    $allFirst12Zero = $false
                    break
                }
            }
            if ($allFirst12Zero) {
                $embeddedIpv4 = [System.Net.IPAddress]::new([byte[]]$v6Bytes[12..15])
                return (Test-IsSafeExternalIp -IpAddress $embeddedIpv4.ToString())
            }

            # NAT64 Well-Known Prefix 64:ff9b::/96 (RFC 6052 / RFC 6890)
            if ($v6Bytes[0] -eq 0x00 -and $v6Bytes[1] -eq 0x64 -and $v6Bytes[2] -eq 0xFF -and $v6Bytes[3] -eq 0x9B) {
                $isNat64Prefix = $true
                for ($idx = 4; $idx -lt 12; $idx++) {
                    if ($v6Bytes[$idx] -ne 0) {
                        $isNat64Prefix = $false
                        break
                    }
                }
                if ($isNat64Prefix) {
                    $embeddedIpv4 = [System.Net.IPAddress]::new([byte[]]$v6Bytes[12..15])
                    return (Test-IsSafeExternalIp -IpAddress $embeddedIpv4.ToString())
                }
            }

            # fc00::/7 (Unique Local Address - ULA: fc00.. or fd00..)
            if (($v6Bytes[0] -band 0xFE) -eq 0xFC) {
                return $false
            }
            # fe80::/10 (Link-Local)
            if ($v6Bytes[0] -eq 0xFE -and ($v6Bytes[1] -band 0xC0) -eq 0x80) {
                return $false
            }
            # 100::/64 (Discard prefix, RFC 6666)
            if ($v6Bytes[0] -eq 0x01 -and $v6Bytes[1] -eq 0x00) {
                $isDiscard = $true
                for ($idx = 2; $idx -lt 8; $idx++) {
                    if ($v6Bytes[$idx] -ne 0) { $isDiscard = $false; break }
                }
                if ($isDiscard) { return $false }
            }
            # 2001:db8::/32 (Documentation prefix, RFC 3849)
            if ($v6Bytes[0] -eq 0x20 -and $v6Bytes[1] -eq 0x01 -and $v6Bytes[2] -eq 0x0D -and $v6Bytes[3] -eq 0xB8) {
                return $false
            }
            # 2001:2::/48 (Benchmarking, RFC 5180)
            if ($v6Bytes[0] -eq 0x20 -and $v6Bytes[1] -eq 0x01 -and $v6Bytes[2] -eq 0x00 -and $v6Bytes[3] -eq 0x02 -and $v6Bytes[4] -eq 0x00 -and $v6Bytes[5] -eq 0x00) {
                return $false
            }

            return $true
        }

        return $false
    }
}

<#
.SYNOPSIS
    Adds telemetry blocking entries via Windows Defender Firewall.
#>
function Add-WinDebloatFirewallBlock {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$CachePath = (Join-Path $PSScriptRoot "..\..\..\config\resolved-telemetry-ips.json")
    )
    
    Remove-LegacyWinDebloatHostsBlock
    
    Write-Log -Message "Adding telemetry blocks via Windows Firewall..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("Windows Firewall", "Block $($Script:TelemetryDomains.Count) telemetry domains")) {
        try {
            # Canonicalize cache path
            $resolvedCachePath = if (Test-Path -Path $CachePath) {
                (Resolve-Path -Path $CachePath).Path
            } else {
                [System.IO.Path]::GetFullPath($CachePath)
            }

            # Prepare parallel resolution
            $ipsToBlock = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            Write-Log -Message "Resolving telemetry domains to IPs (asynchronous parallel lookup)..." -Level Info
            
            $tasks = foreach ($domain in $Script:TelemetryDomains) {
                $cleanDomain = ($domain -replace ':\d+$', '').Trim()
                if ([string]::IsNullOrWhiteSpace($cleanDomain)) { continue }
                [pscustomobject]@{
                    Domain = $cleanDomain
                    Task   = [System.Net.Dns]::GetHostAddressesAsync($cleanDomain)
                }
            }
            
            # Wait up to 6 seconds max for all DNS queries to complete in parallel.
            # Catch and tolerate AggregateException / MethodInvocationException caused by defunct or sinkholed hosts.
            $allTasks = @($tasks | ForEach-Object { $_.Task })
            if ($allTasks.Count -gt 0) {
                try {
                    [System.Threading.Tasks.Task]::WaitAll($allTasks, 6000) | Out-Null
                }
                catch [System.AggregateException], [System.Management.Automation.MethodInvocationException] {
                    Write-Verbose "Parallel DNS WaitAll finished with expected non-resolvable domain faults."
                }
                catch {
                    Write-Verbose "Parallel DNS encountered non-terminating wait notice: $($_.Exception.Message)"
                }
            }
            
            # Safely harvest IPs strictly from completed tasks
            $resolvedCount = 0
            foreach ($t in $tasks) {
                if ($t.Task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) {
                    $resolvedCount++
                    foreach ($ip in $t.Task.Result) {
                        $ipStr = $ip.IPAddressToString
                        if (-not [string]::IsNullOrWhiteSpace($ipStr) -and (Test-IsSafeExternalIp -IpAddress $ipStr)) {
                            [void]$ipsToBlock.Add($ipStr)
                        }
                    }
                }
                else {
                    Write-Verbose "Domain unresolvable or timed out: $($t.Domain) (Status: $($t.Task.Status))"
                }
            }
            
            Write-Log -Message "Successfully resolved $resolvedCount of $($tasks.Count) domains ($($ipsToBlock.Count) unique IPs)." -Level Info
            
            # Cache Integration (Dual-Mode: Online Sync & Offline Fallback)
            if ($ipsToBlock.Count -gt 0) {
                # Merge existing cache entries into active set to retain historical CDN IPs
                if (Test-Path -Path $resolvedCachePath) {
                    try {
                        $cachedJson = Get-Content -Path $resolvedCachePath -Raw -ErrorAction Stop | ConvertFrom-Json
                        if ($cachedJson -and $cachedJson.IPs) {
                            foreach ($cachedIp in $cachedJson.IPs) {
                                if (-not [string]::IsNullOrWhiteSpace($cachedIp) -and (Test-IsSafeExternalIp -IpAddress $cachedIp)) {
                                    [void]$ipsToBlock.Add([string]$cachedIp)
                                }
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Could not read existing cache file: $($_.Exception.Message)"
                    }
                }

                # Update cache on disk
                try {
                    $cacheDir = Split-Path -Path $resolvedCachePath -Parent
                    if (-not (Test-Path -Path $cacheDir)) {
                        New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
                    }
                    
                    $cachePayload = [ordered]@{
                        Version     = "1.0.0"
                        LastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                        Description = "Locally cached telemetry IPs for Win-Debloat offline resilience"
                        TotalIPs    = $ipsToBlock.Count
                        IPs         = @($ipsToBlock | Sort-Object)
                    }
                    $jsonContent = $cachePayload | ConvertTo-Json -Depth 4
                    Set-Content -Path $resolvedCachePath -Value $jsonContent -Encoding UTF8 -Force
                    Write-Verbose "Persisted $($ipsToBlock.Count) telemetry IPs to local cache ($resolvedCachePath)."
                }
                catch {
                    Write-Log -Message "Notice: Could not persist DNS cache to disk: $($_.Exception.Message)" -Level Debug
                }
            }
            else {
                # Offline / DNS sinkholed mode: Fall back to persistent disk cache
                Write-Log -Message "Network DNS resolution yielded 0 IPs. Falling back to local offline cache..." -Level Warning
                if (Test-Path -Path $resolvedCachePath) {
                    try {
                        $cachedJson = Get-Content -Path $resolvedCachePath -Raw -ErrorAction Stop | ConvertFrom-Json
                        if ($cachedJson -and $cachedJson.IPs) {
                            foreach ($cachedIp in $cachedJson.IPs) {
                                if (-not [string]::IsNullOrWhiteSpace($cachedIp) -and (Test-IsSafeExternalIp -IpAddress $cachedIp)) {
                                    [void]$ipsToBlock.Add([string]$cachedIp)
                                }
                            }
                            Write-Log -Message "Loaded $($ipsToBlock.Count) telemetry IPs from local cache." -Level Info
                        }
                    }
                    catch {
                        Write-Log -Message "Failed to load offline telemetry IP cache: $($_.Exception.Message)" -Level Error
                    }
                }
                else {
                    Write-Log -Message "Local cache file not found at $resolvedCachePath. Cannot block offline." -Level Warning
                }
            }
            
            $uniqueIps = @($ipsToBlock | Where-Object { Test-IsSafeExternalIp -IpAddress $_ })
            if ($uniqueIps.Count -eq 0) {
                Write-Log -Message "Could not resolve or recover any telemetry IPs. No firewall rules were applied." -Level Warning
                return
            }

            # Atomic Rule Replacement: Remove old rules only when we have valid IPs to replace them
            $existingRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { 
                $_.DisplayName -like "$($Script:FirewallRuleName)*" 
            }
            if ($existingRules) {
                $existingRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            }
            $legacyRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { 
                $_.DisplayName -like "$($Script:LegacyFirewallRuleName)*" 
            }
            if ($legacyRules) {
                $legacyRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            }
            
            # Split into chunks of 1000 IPs to avoid WMI / NetSecurity buffer limits
            $chunkSize = 1000
            $totalChunks = [Math]::Ceiling($uniqueIps.Count / $chunkSize)
            for ($i = 0; $i -lt $totalChunks; $i++) {
                $chunkIps = $uniqueIps | Select-Object -Skip ($i * $chunkSize) -First $chunkSize
                $ruleSuffix = if ($totalChunks -gt 1) { " (Part $($i + 1)/$totalChunks)" } else { "" }
                New-NetFirewallRule -DisplayName "$($Script:FirewallRuleName)$ruleSuffix" `
                                    -Direction Outbound `
                                    -Action Block `
                                    -RemoteAddress $chunkIps `
                                    -ErrorAction Stop | Out-Null
            }
            
            Write-Log -Message "Added firewall rules blocking $($uniqueIps.Count) telemetry IP addresses across $totalChunks chunk(s)." -Level Success
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
            $existingRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { 
                $_.DisplayName -like "$($Script:FirewallRuleName)*" -or $_.DisplayName -like "$($Script:LegacyFirewallRuleName)*" 
            }
            if ($existingRules) {
                $existingRules | Remove-NetFirewallRule -ErrorAction Stop
                Write-Log -Message "Telemetry firewall blocks removed successfully." -Level Success
            } else {
                Write-Log -Message "No telemetry firewall blocks found." -Level Info
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
Set-Alias -Name 'Test-WinDebloatSafeExternalIp' -Value 'Test-IsSafeExternalIp'
Set-Alias -Name 'Test-WinDebloat7SafeExternalIp' -Value 'Test-IsSafeExternalIp'
Set-Alias -Name 'Test-WDSafeExternalIp' -Value 'Test-IsSafeExternalIp'

Export-ModuleMember -Function @(
    'Remove-LegacyWinDebloatHostsBlock',
    'Add-WinDebloatFirewallBlock',
    'Remove-WinDebloatFirewallBlock',
    'Get-WinDebloatFirewallStatus',
    'Get-WinDebloatTelemetryDomains',
    'Test-IsSafeExternalIp'
) -Alias @(
    'Remove-LegacyWinDebloat7HostsBlock',
    'Add-WinDebloat7FirewallBlock',
    'Remove-WinDebloat7FirewallBlock',
    'Get-WinDebloat7FirewallStatus',
    'Get-WinDebloat7TelemetryDomains',
    'Test-WinDebloatSafeExternalIp',
    'Test-WinDebloat7SafeExternalIp',
    'Test-WDSafeExternalIp'
)
