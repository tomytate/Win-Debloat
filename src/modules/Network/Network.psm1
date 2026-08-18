#Requires -Version 7.6

<#
.SYNOPSIS
    Network configuration module for Win-Debloat
    
.DESCRIPTION
    Handles DNS configuration, IPv6 management, and network privacy settings.
    Supports multiple DNS providers with easy switching.
    
.NOTES
    Module: Win-Debloat.Modules.Network
    Version: 2.0.0
.LINK
    https://learn.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

# Import Core Modules
Import-Module "$PSScriptRoot\..\..\core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\..\..\core\Registry.psm1" -Force

#region DNS Providers

$Script:DNSProviders = @{
    Cloudflare             = @{
        Name          = "Cloudflare (Privacy-Focused)"
        IPv4Primary   = "1.1.1.1"
        IPv4Secondary = "1.0.0.1"
        IPv6Primary   = "2606:4700:4700::1111"
        IPv6Secondary = "2606:4700:4700::1001"
        DoHTemplate   = "https://cloudflare-dns.com/dns-query"
    }
    Cloudflare_Malware     = @{
        Name          = "Cloudflare (Malware Blocking)"
        IPv4Primary   = "1.1.1.2"
        IPv4Secondary = "1.0.0.2"
        IPv6Primary   = "2606:4700:4700::1112"
        IPv6Secondary = "2606:4700:4700::1002"
        DoHTemplate   = "https://security.cloudflare-dns.com/dns-query"
    }
    Cloudflare_Family      = @{
        Name          = "Cloudflare (Family Safe)"
        IPv4Primary   = "1.1.1.3"
        IPv4Secondary = "1.0.0.3"
        IPv6Primary   = "2606:4700:4700::1113"
        IPv6Secondary = "2606:4700:4700::1003"
        DoHTemplate   = "https://family.cloudflare-dns.com/dns-query"
    }
    Google                 = @{
        Name          = "Google Public DNS"
        IPv4Primary   = "8.8.8.8"
        IPv4Secondary = "8.8.4.4"
        IPv6Primary   = "2001:4860:4860::8888"
        IPv6Secondary = "2001:4860:4860::8844"
        DoHTemplate   = "https://dns.google/dns-query"
    }
    Quad9                  = @{
        Name          = "Quad9 (Security-Focused)"
        IPv4Primary   = "9.9.9.9"
        IPv4Secondary = "149.112.112.112"
        IPv6Primary   = "2620:fe::fe"
        IPv6Secondary = "2620:fe::9"
        DoHTemplate   = "https://dns.quad9.net/dns-query"
    }
    AdGuard                = @{
        Name          = "AdGuard DNS (Ad-Blocking)"
        IPv4Primary   = "94.140.14.14"
        IPv4Secondary = "94.140.15.15"
        IPv6Primary   = "2a10:50c0::ad1:ff"
        IPv6Secondary = "2a10:50c0::ad2:ff"
        DoHTemplate   = "https://dns.adguard-dns.com/dns-query"
    }
    AdGuard_Family         = @{
        Name          = "AdGuard DNS (Family Safe)"
        IPv4Primary   = "94.140.14.15"
        IPv4Secondary = "94.140.15.16"
        IPv6Primary   = "2a10:50c0::bad1:ff"
        IPv6Secondary = "2a10:50c0::bad2:ff"
        DoHTemplate   = "https://dns-family.adguard-dns.com/dns-query"
    }
    OpenDNS                = @{
        Name          = "OpenDNS (Cisco)"
        IPv4Primary   = "208.67.222.222"
        IPv4Secondary = "208.67.220.220"
        IPv6Primary   = "2620:119:35::35"
        IPv6Secondary = "2620:119:53::53"
        DoHTemplate   = "https://doh.opendns.com/dns-query"
    }
    CleanBrowsing_Security = @{
        Name          = "CleanBrowsing (Security)"
        IPv4Primary   = "185.228.168.9"
        IPv4Secondary = "185.228.169.9"
        IPv6Primary   = "2a0d:2a00:1::2"
        IPv6Secondary = "2a0d:2a00:2::2"
        DoHTemplate   = "https://doh.cleanbrowsing.org/doh/security-filter/"
    }
    CleanBrowsing_Family   = @{
        Name          = "CleanBrowsing (Family)"
        IPv4Primary   = "185.228.168.168"
        IPv4Secondary = "185.228.169.168"
        IPv6Primary   = "2a0d:2a00:1::1"
        IPv6Secondary = "2a0d:2a00:2::1"
        DoHTemplate   = "https://doh.cleanbrowsing.org/doh/family-filter/"
    }
    NextDNS                = @{
        Name          = "NextDNS (Customizable)"
        IPv4Primary   = "45.90.28.0"
        IPv4Secondary = "45.90.30.0"
        IPv6Primary   = "2a07:a8c0::"
        IPv6Secondary = "2a07:a8c1::"
        DoHTemplate   = "https://dns.nextdns.io"
    }
}

# Dynamically merge with config/dns.json if available
$jsonPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "config\dns.json"
if (Test-Path -LiteralPath $jsonPath) {
    try {
        $jsonContent = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
        $providerEntries = if ($jsonContent.providers) { $jsonContent.providers.PSObject.Properties } else { $jsonContent.PSObject.Properties }
        foreach ($prop in $providerEntries) {
            if (-not $Script:DNSProviders.ContainsKey($prop.Name)) {
                $val = $prop.Value
                $primary4 = if ($val.Primary) { $val.Primary } elseif ($val.primary) { $val.primary } else { $val.IPv4Primary }
                $secondary4 = if ($val.Secondary) { $val.Secondary } elseif ($val.secondary) { $val.secondary } else { $val.IPv4Secondary }
                $primary6 = if ($val.Primary6) { $val.Primary6 } elseif ($val.ipv6_primary) { $val.ipv6_primary } else { $val.IPv6Primary }
                $secondary6 = if ($val.Secondary6) { $val.Secondary6 } elseif ($val.ipv6_secondary) { $val.ipv6_secondary } else { $val.IPv6Secondary }
                $desc = if ($val.Description) { $val.Description } elseif ($val.name) { $val.name } else { $prop.Name }
                $doh = if ($val.DoHTemplate) { $val.DoHTemplate } elseif ($val.doh_template) { $val.doh_template } else { $null }

                $Script:DNSProviders[$prop.Name] = @{
                    Name          = $desc
                    IPv4Primary   = $primary4
                    IPv4Secondary = $secondary4
                    IPv6Primary   = $primary6
                    IPv6Secondary = $secondary6
                    DoHTemplate   = $doh
                }
            }
        }
    }
    catch {
        Write-Log -Message "Could not parse config/dns.json: $($_.Exception.Message)" -Level Debug
    }
}

#endregion

#region DNS Configuration

<#
.SYNOPSIS
    Sets custom DNS servers for all active network adapters.
    
.DESCRIPTION
    Configures DNS servers on all enabled and connected network adapters.
    Supports popular secure DNS providers (Cloudflare, Google, Quad9, AdGuard)
    with native Windows 11 DNS-over-HTTPS (DoH) auto-upgrade where supported.
#>
function Set-WinDebloatDNS {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(
            "Cloudflare", "Cloudflare_Malware", "Cloudflare_Family",
            "Google", "Quad9", "AdGuard", "AdGuard_Default", "AdGuard_Family",
            "OpenDNS", "CleanBrowsing_Security", "CleanBrowsing_Family",
            "NextDNS", "Custom", "Reset", "DHCP", "Default"
        )]
        [string]$Provider,
        
        [string]$CustomPrimary,
        [string]$CustomSecondary,
        [switch]$IncludeIPv6,
        [switch]$EnableDoH
    )

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    if (-not $adapters) {
        Write-Log -Message "No active network adapters found." -Level Warning
        return
    }

    if ($Provider -in @("Reset", "DHCP", "Default")) {
        foreach ($adapter in $adapters) {
            if ($PSCmdlet.ShouldProcess($adapter.Name, "Reset DNS to DHCP (Automatic)")) {
                try {
                    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction Stop
                    Write-Log -Message "Reset DNS on $($adapter.Name) to DHCP (Automatic)" -Level Success
                }
                catch {
                    Write-Log -Message "Failed to reset DNS on $($adapter.Name): $($_.Exception.Message)" -Level Error
                }
            }
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Log -Message "DNS reset to DHCP complete." -Level Success
        return
    }

    $primary = $null
    $secondary = $null
    $providerName = $Provider
    $dohTemplate = $null

    if ($Provider -eq "Custom") {
        if (-not $CustomPrimary) {
            Write-Log -Message "Custom DNS requires at least -CustomPrimary." -Level Error
            return
        }
        $primary = $CustomPrimary
        $secondary = $CustomSecondary
    }
    else {
        $dns = $Script:DNSProviders[$Provider]
        if (-not $dns) {
            Write-Log -Message "Unknown DNS provider: $Provider" -Level Error
            return
        }
        $primary = $dns.IPv4Primary
        $secondary = $dns.IPv4Secondary
        $providerName = $dns.Name
        $dohTemplate = $dns.DoHTemplate
    }
    
    $dnsServers = @($primary)
    if ($secondary) { $dnsServers += $secondary }
    
    # Configure native Windows 11 DoH if available (CTT WinUtil pattern)
    $hasDoHCmdlet = Get-Command "Add-DnsClientDohServerAddress" -ErrorAction SilentlyContinue
    if ($hasDoHCmdlet -and $dohTemplate -and ($EnableDoH.IsPresent -or -not $PSBoundParameters.ContainsKey("EnableDoH"))) {
        try {
            $allDohTargets = @($dnsServers)
            if ($IncludeIPv6 -and $Provider -ne "Custom") {
                $dns = $Script:DNSProviders[$Provider]
                $ipv6Targets = @($dns.IPv6Primary, $dns.IPv6Secondary) | Where-Object { $_ }
                $allDohTargets += $ipv6Targets
            }

            foreach ($ip in $allDohTargets) {
                Add-DnsClientDohServerAddress -ServerAddress $ip -DnsOverHttpsTemplate $dohTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue | Out-Null
            }
            Write-Log -Message "Registered native DNS-over-HTTPS template for $providerName" -Level Info
        }
        catch {
            Write-Log -Message "DoH registration notice: $($_.Exception.Message)" -Level Debug
        }
    }

    foreach ($adapter in $adapters) {
        if ($PSCmdlet.ShouldProcess($adapter.Name, "Set DNS to $providerName")) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers
                Write-Log -Message "Set DNS on $($adapter.Name) to $providerName ($($dnsServers -join ', '))" -Level Success
                
                # IPv6 if requested
                if ($IncludeIPv6 -and $Provider -ne "Custom") {
                    $dns = $Script:DNSProviders[$Provider]
                    $ipv6Servers = @($dns.IPv6Primary, $dns.IPv6Secondary) | Where-Object { $_ }
                    if ($ipv6Servers.Count -gt 0) {
                        try {
                            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ($dnsServers + $ipv6Servers)
                            Write-Log -Message "Added IPv6 DNS servers ($($ipv6Servers -join ', '))" -Level Debug
                        }
                        catch {
                            Write-Log -Message "Failed to set IPv6 DNS: $($_.Exception.Message)" -Level Warning
                        }
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to set DNS on $($adapter.Name): $($_.Exception.Message)" -Level Error
            }
        }
    }
    
    # Flush DNS cache
    Write-Log -Message "Flushing DNS cache..." -Level Info
    Clear-DnsClientCache
    Write-Log -Message "DNS configuration complete." -Level Success
}

<#
.SYNOPSIS
    Gets the list of available DNS providers.
#>
function Get-WinDebloatDNSProviders {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Standard framework cmdlet')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    return $Script:DNSProviders
}

#endregion

#region IPv6 Management

<#
.SYNOPSIS
    Safely prefers IPv4 over IPv6 via prefix policy without breaking loopback or UWP apps.
#>
function Disable-WinDebloatIPv6 {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param()
    
    Write-Log -Message "Configuring system to prefer IPv4 over IPv6 (Microsoft standard 0x20)..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("TCP/IP Stack", "Prefer IPv4 over IPv6")) {
        # Value 0x20 (decimal 32) configures IPv4 as preferred over IPv6 in RFC 3484 prefix policies
        # without unbinding adapter components (which breaks WSL2, UWP localhost, and VPNs)
        Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 32 -Type DWord
        Write-Log -Message "IPv4 preferred over IPv6 policy applied successfully." -Level Success
    }
}

<#
.SYNOPSIS
    Enables native IPv6 default behavior.
#>
function Enable-WinDebloatIPv6 {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()
    
    Write-Log -Message "Restoring standard IPv6 behavior..." -Level Info
    
    if ($PSCmdlet.ShouldProcess("TCP/IP Stack", "Enable Default IPv6")) {
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents"
        
        # Ensure all adapters have ms_tcpip6 bound
        Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
            Enable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
        }
        Write-Log -Message "Default IPv6 restored." -Level Success
    }
}

#endregion

#region NetBIOS Management

<#
.SYNOPSIS
    Disables NetBIOS over TCP/IP across all network adapters to mitigate NBT-NS poisoning and broadcast leakage.
#>
function Disable-WinDebloatNetBIOS {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param()

    Write-Log -Message "Disabling NetBIOS over TCP/IP..." -Level Info

    if ($PSCmdlet.ShouldProcess("NetBIOS over TCP/IP", "Disable NetBIOS across all interfaces")) {
        try {
            # 1. Update registry for all existing interfaces (NetbiosOptions = 2: Disabled)
            $ifaceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
            if (Test-Path $ifaceKey) {
                Get-ChildItem -Path $ifaceKey -ErrorAction SilentlyContinue | ForEach-Object {
                    Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }

            # 2. Update via WMI/CIM where available (2 = Disable)
            Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" -ErrorAction SilentlyContinue | ForEach-Object {
                Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]2 } -ErrorAction SilentlyContinue | Out-Null
            }

            Write-Log -Message "NetBIOS over TCP/IP disabled successfully." -Level Success
        }
        catch {
            Write-Log -Message "Failed to disable NetBIOS: $($_.Exception.Message)" -Level Error
        }
    }
}

<#
.SYNOPSIS
    Restores default NetBIOS over TCP/IP behavior (DHCP / enabled).
#>
function Enable-WinDebloatNetBIOS {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    Write-Log -Message "Restoring default NetBIOS over TCP/IP behavior..." -Level Info

    if ($PSCmdlet.ShouldProcess("NetBIOS over TCP/IP", "Restore default NetBIOS settings")) {
        try {
            # NetbiosOptions = 0: Use DHCP setting (Default)
            $ifaceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
            if (Test-Path $ifaceKey) {
                Get-ChildItem -Path $ifaceKey -ErrorAction SilentlyContinue | ForEach-Object {
                    Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }

            Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" -ErrorAction SilentlyContinue | ForEach-Object {
                Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]0 } -ErrorAction SilentlyContinue | Out-Null
            }

            Write-Log -Message "NetBIOS over TCP/IP restored to default." -Level Success
        }
        catch {
            Write-Log -Message "Failed to restore NetBIOS: $($_.Exception.Message)" -Level Error
        }
    }
}

<#
.SYNOPSIS
    Gets the current NetBIOS configuration status.
#>
function Get-WinDebloatNetBIOSStatus {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()

    $disabledCount = 0
    $totalCount = 0

    $ifaceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
    if (Test-Path $ifaceKey) {
        $ifaces = Get-ChildItem -Path $ifaceKey -ErrorAction SilentlyContinue
        foreach ($iface in $ifaces) {
            $val = (Get-ItemProperty -Path $iface.PSPath -Name "NetbiosOptions" -ErrorAction SilentlyContinue).NetbiosOptions
            $totalCount++
            if ($val -eq 2) { $disabledCount++ }
        }
    }

    $isNetbiosDisabled = ($totalCount -gt 0 -and $disabledCount -eq $totalCount)

    return [pscustomobject]@{
        NetBIOSDisabled = $isNetbiosDisabled
        DisabledCount   = $disabledCount
        TotalInterfaces = $totalCount
    }
}

#endregion

#region Network Status

<#
.SYNOPSIS
    Gets the current network configuration status.
    
    .OUTPUTS
        [psobject[]] Network adapter status objects.
#>
function Get-WinDebloatNetworkStatus {
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param()
    
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    
    $results = foreach ($adapter in $adapters) {
        $dnsServers = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        $ipv6Enabled = (Get-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue).Enabled
        
        # Try to identify DNS provider
        $provider = "Unknown"
        foreach ($providerName in $Script:DNSProviders.Keys) {
            $p = $Script:DNSProviders[$providerName]
            if ($dnsServers -contains $p.IPv4Primary) {
                $provider = $providerName
                break
            }
        }
        if (-not $dnsServers -or $dnsServers.Count -eq 0) { $provider = "DHCP" }
        
        [pscustomobject]@{
            Adapter     = $adapter.Name
            Status      = $adapter.Status
            DNSServers  = if ($dnsServers) { $dnsServers -join ", " } else { "Automatic (DHCP)" }
            DNSProvider = $provider
            IPv6Enabled = [bool]$ipv6Enabled
        }
        
        Write-Log -Message "Adapter '$($adapter.Name)': DNS provider detected as $provider ($($dnsServers -join ', '))" -Level Debug
    }

    return $results
}

<#
.SYNOPSIS
    Applies network settings from a profile configuration.
    
.PARAMETER Config
    The configuration object loaded from a YAML profile.
#>
function Set-WinDebloatNetwork {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Config
    )
    
    if (-not $Config.network) {
        Write-Log -Message "No network configuration in profile." -Level Info
        return
    }
    
    # DNS Configuration
    if ($Config.network.dns_servers -and $Config.network.dns_servers.Count -gt 0) {
        $primary = $Config.network.dns_servers[0]
        $secondary = if ($Config.network.dns_servers.Count -gt 1) { $Config.network.dns_servers[1] } else { $null }
        
        # Check if it matches a known provider
        $matchedProvider = $null
        foreach ($providerName in $Script:DNSProviders.Keys) {
            if ($Script:DNSProviders[$providerName].IPv4Primary -eq $primary) {
                $matchedProvider = $providerName
                break
            }
        }
        
        if ($matchedProvider) {
            Set-WinDebloatDNS -Provider $matchedProvider
        }
        else {
            Set-WinDebloatDNS -Provider Custom -CustomPrimary $primary -CustomSecondary $secondary
        }
    }
    
    # IPv6
    if ($Config.network.disable_ipv6 -eq $true) {
        Disable-WinDebloatIPv6
    }

    # NetBIOS
    if ($Config.network.disable_netbios -eq $true) {
        Disable-WinDebloatNetBIOS
    }
}

#endregion

# Aliases for backward compatibility
Set-Alias -Name 'Set-WinDebloat7DNS' -Value 'Set-WinDebloatDNS'
Set-Alias -Name 'Set-WinDebloatDns' -Value 'Set-WinDebloatDNS'
Set-Alias -Name 'Set-WinDebloat7Dns' -Value 'Set-WinDebloatDNS'
Set-Alias -Name 'Get-WinDebloatDNSProviders' -Value 'Get-WinDebloatDNSProviders'
Set-Alias -Name 'Get-WinDebloat7DNSProviders' -Value 'Get-WinDebloatDNSProviders'
Set-Alias -Name 'Get-WinDebloatDnsProviders' -Value 'Get-WinDebloatDNSProviders'
Set-Alias -Name 'Get-WinDebloat7DnsProviders' -Value 'Get-WinDebloatDNSProviders'
Set-Alias -Name 'Disable-WinDebloat7IPv6' -Value 'Disable-WinDebloatIPv6'
Set-Alias -Name 'Enable-WinDebloat7IPv6' -Value 'Enable-WinDebloatIPv6'
Set-Alias -Name 'Disable-WinDebloatNetBIOS' -Value 'Disable-WinDebloatNetBIOS'
Set-Alias -Name 'Disable-WinDebloat7NetBIOS' -Value 'Disable-WinDebloatNetBIOS'
Set-Alias -Name 'Enable-WinDebloatNetBIOS' -Value 'Enable-WinDebloatNetBIOS'
Set-Alias -Name 'Enable-WinDebloat7NetBIOS' -Value 'Enable-WinDebloatNetBIOS'
Set-Alias -Name 'Get-WinDebloatNetBIOSStatus' -Value 'Get-WinDebloatNetBIOSStatus'
Set-Alias -Name 'Get-WinDebloat7NetBIOSStatus' -Value 'Get-WinDebloatNetBIOSStatus'
Set-Alias -Name 'Get-WinDebloat7NetworkStatus' -Value 'Get-WinDebloatNetworkStatus'
Set-Alias -Name 'Set-WinDebloat7Network' -Value 'Set-WinDebloatNetwork'

Export-ModuleMember -Function @(
    'Set-WinDebloatDNS',
    'Get-WinDebloatDNSProviders',
    'Disable-WinDebloatIPv6',
    'Enable-WinDebloatIPv6',
    'Disable-WinDebloatNetBIOS',
    'Enable-WinDebloatNetBIOS',
    'Get-WinDebloatNetBIOSStatus',
    'Get-WinDebloatNetworkStatus',
    'Set-WinDebloatNetwork'
) -Alias @(
    'Set-WinDebloat7DNS',
    'Set-WinDebloatDns',
    'Set-WinDebloat7Dns',
    'Get-WinDebloat7DNSProviders',
    'Get-WinDebloatDnsProviders',
    'Get-WinDebloat7DnsProviders',
    'Disable-WinDebloat7IPv6',
    'Enable-WinDebloat7IPv6',
    'Disable-WinDebloat7NetBIOS',
    'Enable-WinDebloat7NetBIOS',
    'Get-WinDebloat7NetBIOSStatus',
    'Get-WinDebloat7NetworkStatus',
    'Set-WinDebloat7Network'
)
