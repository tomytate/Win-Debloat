<#
.SYNOPSIS
    Unit tests for Win-Debloat v1.7.1 Forensic Upgrades:
    - Test-IsSafeExternalIp (RFC 1122/6890/1918 loopback & private guardrails)
    - New-WinDebloatSystemRestorePoint & Test-WinDebloatSystemRestore (VSS snapshot engine)
    - Export-WinDebloatRollbackReg (UTF-16LE Windows Registry Editor 5.00 rollback engine)
    - Invoke-WinDebloatAsync (STA Runspace asynchronous pipeline)
    - Get-WinDebloatAppCatalog & Install-WinDebloatAppCatalog (Declarative Winget catalog)
    - Show-WinDebloatDiffViewer (Visual diff preview component)
#>

Describe "Forensic Upgrades Module Tests (v1.7.1)" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\State.psm1" -Force -ErrorAction Stop
        Import-Module "$src\modules\Privacy\Firewall.psm1" -Force -ErrorAction Stop
        Import-Module "$src\modules\Software\Software.psm1" -Force -ErrorAction Stop
        Import-Module "$src\ui\Colors.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\ui\Menu.psm1" -Force -ErrorAction SilentlyContinue
    }

    Context "Test-IsSafeExternalIp (Loopback & Private Range Guards)" {
        It "Approves valid public IPv4 addresses" {
            Test-IsSafeExternalIp -IpAddress "20.189.173.1" | Should -Be $true
            Test-IsSafeExternalIp -IpAddress "13.107.4.52" | Should -Be $true
            Test-IsSafeExternalIp -IpAddress "52.167.248.88" | Should -Be $true
        }

        It "Rejects loopback IPv4 addresses (127.0.0.0/8)" {
            Test-IsSafeExternalIp -IpAddress "127.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "127.0.0.254" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "127.255.255.255" | Should -Be $false
        }

        It "Rejects loopback IPv6 addresses (::1)" {
            Test-IsSafeExternalIp -IpAddress "::1" | Should -Be $false
        }

        It "Rejects IPv4-compatible IPv6 loopback and private addresses (::w.x.y.z)" {
            Test-IsSafeExternalIp -IpAddress "::127.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "::192.168.1.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "::10.0.0.1" | Should -Be $false
        }

        It "Rejects IPv4-mapped IPv6 loopback and private addresses (::ffff:w.x.y.z)" {
            Test-IsSafeExternalIp -IpAddress "::ffff:127.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "::ffff:192.168.1.1" | Should -Be $false
        }

        It "Rejects NAT64 well-known prefix loopback (64:ff9b::w.x.y.z)" {
            Test-IsSafeExternalIp -IpAddress "64:ff9b::127.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "64:ff9b::10.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "64:ff9b::8.8.8.8" | Should -Be $true
        }

        It "Rejects unspecified addresses (0.0.0.0 and ::)" {
            Test-IsSafeExternalIp -IpAddress "0.0.0.0" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "::" | Should -Be $false
        }

        It "Rejects broadcast address (255.255.255.255)" {
            Test-IsSafeExternalIp -IpAddress "255.255.255.255" | Should -Be $false
        }

        It "Rejects multicast addresses (224.0.0.0/4)" {
            Test-IsSafeExternalIp -IpAddress "224.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "239.255.255.250" | Should -Be $false
        }

        It "Rejects RFC 1918 private IPv4 addresses" {
            Test-IsSafeExternalIp -IpAddress "10.0.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "192.168.1.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "172.16.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "172.31.255.255" | Should -Be $false
        }

        It "Rejects link-local addresses (169.254.0.0/16 and fe80::)" {
            Test-IsSafeExternalIp -IpAddress "169.254.1.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "fe80::1" | Should -Be $false
        }

        It "Rejects benchmarking, protocol assignment, and documentation ranges (RFC 2544, RFC 6890, RFC 3849)" {
            Test-IsSafeExternalIp -IpAddress "198.18.0.1" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "192.0.0.170" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "2001:db8::1" | Should -Be $false
        }

        It "Rejects malformed strings gracefully without throwing" {
            Test-IsSafeExternalIp -IpAddress "not-an-ip" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "" | Should -Be $false
            Test-IsSafeExternalIp -IpAddress "999.999.999.999" | Should -Be $false
        }

        It "All backward compatibility aliases resolve to Test-IsSafeExternalIp" {
            Test-WinDebloatSafeExternalIp -IpAddress "20.189.173.1" | Should -Be $true
            Test-WinDebloat7SafeExternalIp -IpAddress "127.0.0.1" | Should -Be $false
            Test-WDSafeExternalIp -IpAddress "127.0.0.1" | Should -Be $false
        }
    }

    Context "System Restore & Disaster Recovery (State Engine)" {
        It "Exports Test-WinDebloatSystemRestore and checks status safely" {
            $status = Test-WinDebloatSystemRestore
            ($status -eq $true -or $status -eq $false) | Should -Be $true
        }

        It "Exports New-WinDebloatSystemRestorePoint and handles execution gracefully" {
            # In test environments without elevation or VSS enabled, it must return a structured object without fatal crash
            $res = New-WinDebloatSystemRestorePoint -Description "Pester Test Snapshot" -ErrorAction SilentlyContinue
            $res | Should -Not -BeNullOrEmpty
            $res.ContainsKey('Success') | Should -Be $true
            $res.ContainsKey('Error') | Should -Be $true
        }

        It "Exports Export-WinDebloatRollbackReg and generates standard .reg file" {
            $tempDir = Join-Path $env:TEMP "WD7_RegTest_$([guid]::NewGuid().ToString('N'))"
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

            try {
                $mockRegChanges = @(
                    [PSCustomObject]@{
                        Key       = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                        Name      = "AllowTelemetry"
                        OldValue  = 3
                        ValueKind = "DWord"
                        Action    = "Modified"
                    },
                    [PSCustomObject]@{
                        Key       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                        Name      = "SubscribedContent-338387Enabled"
                        OldValue  = 1
                        ValueKind = "DWord"
                        Action    = "Modified"
                    },
                    [PSCustomObject]@{
                        Key       = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                        Name      = "CreatedKeyForTest"
                        OldValue  = $null
                        ValueKind = $null
                        Action    = "Created"
                    }
                )

                $regFile = Join-Path $tempDir "rollback.reg"
                $result = Export-WinDebloatRollbackReg -RegistryChanges $mockRegChanges -OutFile $regFile

                $result | Should -Not -BeNullOrEmpty
                Test-Path -LiteralPath $regFile | Should -Be $true

                # Read raw bytes to check for UTF-16LE BOM (0xFF, 0xFE)
                $bytes = [System.IO.File]::ReadAllBytes($regFile)
                $bytes.Length | Should -BeGreaterThan 2
                $bytes[0] | Should -Be 0xFF
                $bytes[1] | Should -Be 0xFE

                # Read content as Unicode
                $content = [System.IO.File]::ReadAllText($regFile, [System.Text.Encoding]::Unicode)
                $content | Should -Match "Windows Registry Editor Version 5\.00"
                $content | Should -Match "HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection"
                $content | Should -Match '"AllowTelemetry"=dword:00000003'
                $content | Should -Match "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager"
                $content | Should -Match '"SubscribedContent-338387Enabled"=dword:00000001'
                $content | Should -Match '"CreatedKeyForTest"=-'

                # Companion batch file
                $cmdFile = Join-Path $tempDir "rollback.cmd"
                Test-Path -LiteralPath $cmdFile | Should -Be $true
                $cmdContent = Get-Content -LiteralPath $cmdFile -Raw
                $cmdContent | Should -Match "reg\.exe import"
            }
            finally {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Invoke-WinDebloatAsync (STA Runspace Engine)" {
        It "Executes a scriptblock asynchronously and returns output" {
            $task = {
                param($val)
                return "AsyncResult_$val"
            }

            $output = Invoke-WinDebloatAsync -ScriptBlock $task -ArgumentList @(42) -TimeoutSeconds 10
            $output | Should -Be "AsyncResult_42"
        }

        It "Passes hashtable parameters to background scope" {
            $task = {
                return "$prefix-$suffix"
            }

            $params = @{ prefix = "Debloat"; suffix = "v1.7" }
            $output = Invoke-WinDebloatAsync -ScriptBlock $task -Parameters $params -TimeoutSeconds 10
            $output | Should -Be "Debloat-v1.7"
        }
    }

    Context "Get-WinDebloatAppCatalog & Install-WinDebloatAppCatalog (Software Module)" {
        It "Loads apps catalog from config/apps.yaml" {
            $catalog = Get-WinDebloatAppCatalog
            $catalog | Should -Not -BeNullOrEmpty
            $catalog.categories | Should -Not -BeNullOrEmpty
            $catalog.categories.Count | Should -BeGreaterThan 0

            # Verify catalog schema
            $sample = $catalog.categories[0].apps[0]
            $sample.id | Should -Not -BeNullOrEmpty
            $sample.name | Should -Not -BeNullOrEmpty
            $sample.winget | Should -Not -BeNullOrEmpty
        }

        It "Filters catalog by Category correctly" {
            $browsers = Get-WinDebloatAppCatalog -Category "Browsers"
            $browsers | Should -Not -BeNullOrEmpty
            $browsers.Count | Should -BeGreaterThan 0
            $browsers[0].id | Should -Not -BeNullOrEmpty
        }

        It "All backward compatibility aliases resolve to Get-WinDebloatAppCatalog" {
            $c1 = Get-WinDebloat7AppCatalog
            $c2 = Get-WD7AppCatalog
            $c1 | Should -Not -BeNullOrEmpty
            $c2 | Should -Not -BeNullOrEmpty
        }

        It "Install-WinDebloatAppCatalog supports -WhatIf" {
            { Install-WinDebloatAppCatalog -AppIds @("Brave.Brave") -WhatIf } | Should -Not -Throw
        }
    }

    Context "Show-WinDebloatDiffViewer (Visual Diff Engine)" {
        It "Exports Show-WinDebloatDiffViewer and aliases" {
            (Get-Command -Name Show-WinDebloatDiffViewer -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command -Name Show-WinDebloat7DiffViewer -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command -Name Show-WD7DiffViewer -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }

        It "Renders a diff preview for registry items without throwing" {
            $sampleDiff = @(
                [PSCustomObject]@{
                    Category     = "Telemetry"
                    Target       = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                    Property     = "AllowTelemetry"
                    CurrentValue = 3
                    NewValue     = 0
                    Action       = "Modify"
                },
                [PSCustomObject]@{
                    Category     = "Services"
                    Target       = "DiagTrack"
                    Property     = "StartupType"
                    CurrentValue = "Automatic"
                    NewValue     = "Disabled"
                    Action       = "Disable"
                }
            )

            # In non-interactive test mode, passing sample items should succeed cleanly
            { Show-WinDebloatDiffViewer -DiffItems $sampleDiff -PassThru } | Should -Not -Throw
        }
    }
}
