#Requires -Version 7.6

$sutSystemState = "$PSScriptRoot/../../src/core/SystemState.psm1"
$sutState = "$PSScriptRoot/../../src/core/State.psm1"

Import-Module "$PSScriptRoot/../../src/core/Logger.psm1" -Force
Import-Module "$PSScriptRoot/../../src/core/Registry.psm1" -Force
Import-Module $sutSystemState -Force
Import-Module $sutState -Force

Describe "SystemState Module" {
    Context "Get-WinDebloatSystemState and Get-WinDebloat7SystemState" {
        It "Should return a state object with all expected properties (cmdlet and alias)" {
            Mock -ModuleName SystemState Get-RegistryKey { return 1 }
            Mock -ModuleName SystemState Get-NetTCPConnection { return @(1, 2, 3) }
            Mock -ModuleName SystemState Get-Service { return @([PSCustomObject]@{ Status = 'Stopped' }) }
            
            $state1 = Get-WinDebloatSystemState
            $state1.Telemetry | Should -Not -BeNullOrEmpty
            $state1.Copilot | Should -Not -BeNullOrEmpty
            $state1.ActiveConnections | Should -Be 3
            $state1.DarkTheme | Should -Be $false
            $state1.GamingNetwork | Should -Be $true

            $state2 = Get-WinDebloat7SystemState
            $state2.Telemetry | Should -Not -BeNullOrEmpty
            $state2.Copilot | Should -Not -BeNullOrEmpty
            $state2.ActiveConnections | Should -Be 3
        }

        It "Handles missing registry keys and stopped services gracefully" {
            Mock -ModuleName SystemState Get-RegistryKey { return $null }
            Mock -ModuleName SystemState Get-NetTCPConnection { return @() }
            Mock -ModuleName SystemState Get-Service { return $null }

            $state = Get-WinDebloatSystemState

            $state.Telemetry | Should -Be $true
            $state.Copilot | Should -Be $true
            $state.ActiveConnections | Should -Be 0
            $state.GamingNetwork | Should -Be $false
        }
    }

    Context "Get-WinDebloatPrivacyScore and Get-WinDebloat7PrivacyScore" {
        It "Scores 100 with Grade A when all privacy risks are hardened (cmdlet and alias)" {
            $hardenedState = [PSCustomObject]@{
                Telemetry        = $false
                Recall           = $false
                AdvertisingId    = $false
                Copilot          = $false
                ActivityHistory  = $false
                Location         = $false
                BackgroundApps   = $false
                ClipboardHistory = $false
            }

            $score1 = Get-WinDebloatPrivacyScore -State $hardenedState
            $score1.Score | Should -Be 100
            $score1.Grade | Should -Be 'A'
            $score1.Rating | Should -Be 'Excellent'
            ($score1.Breakdown | Measure-Object -Property Lost -Sum).Sum | Should -Be 0

            $score2 = Get-WinDebloat7PrivacyScore -State $hardenedState
            $score2.Score | Should -Be 100
            $score2.Grade | Should -Be 'A'
        }

        It "Scores 0 with Grade F when all privacy risks are active" {
            $exposedState = [PSCustomObject]@{
                Telemetry        = $true
                Recall           = $true
                AdvertisingId    = $true
                Copilot          = $true
                ActivityHistory  = $true
                Location         = $true
                BackgroundApps   = $true
                ClipboardHistory = $true
            }

            $score = Get-WinDebloat7PrivacyScore -State $exposedState
            $score.Score | Should -Be 0
            $score.Grade | Should -Be 'F'
            $score.Rating | Should -Be 'At Risk'
            ($score.Breakdown | Measure-Object -Property Lost -Sum).Sum | Should -Be 100
        }

        It "Correctly deducts weighted points for partial hardening" {
            # Only Telemetry (22) and Recall (16) active = 38 lost -> Score 62 (Grade C)
            $partialState = [PSCustomObject]@{
                Telemetry        = $true
                Recall           = $true
                AdvertisingId    = $false
                Copilot          = $false
                ActivityHistory  = $false
                Location         = $false
                BackgroundApps   = $false
                ClipboardHistory = $false
            }

            $score = Get-WinDebloat7PrivacyScore -State $partialState
            $score.Score | Should -Be 62
            $score.Grade | Should -Be 'C'
            $score.Rating | Should -Be 'Fair'
        }

        It "Handles hashtable state input" {
            $hashState = @{
                Telemetry        = $false
                Recall           = $false
                AdvertisingId    = $false
                Copilot          = $false
                ActivityHistory  = $false
                Location         = $false
                BackgroundApps   = $false
                ClipboardHistory = $false
            }

            $score = Get-WinDebloat7PrivacyScore -State $hashState
            $score.Score | Should -Be 100
            $score.Grade | Should -Be 'A'
        }

        It "Auto-fetches state when -State parameter is omitted" {
            Mock -ModuleName SystemState Get-RegistryKey { return 0 }
            Mock -ModuleName SystemState Get-NetTCPConnection { return @() }
            Mock -ModuleName SystemState Get-Service { return $null }

            $score = Get-WinDebloat7PrivacyScore
            $score.Score | Should -BeOfType [int]
            $score.Breakdown.Count | Should -Be 8
        }
    }
}

Describe "Core.State Module - DPAPI Encryption & Edge Cases" {
    Context "Protect-WD7Data and Unprotect-WD7Data" {
        It "Successfully protects and unprotects arbitrary byte data" {
            $original = [System.Text.Encoding]::UTF8.GetBytes("Secret snapshot payload content 12345")
            $encrypted = Protect-WD7Data -Data $original
            $encrypted | Should -Not -BeNullOrEmpty
            $encrypted | Should -Not -Be $original

            $decrypted = Unprotect-WD7Data -EncryptedData $encrypted
            $decryptedString = [System.Text.Encoding]::UTF8.GetString($decrypted)
            $decryptedString | Should -Be "Secret snapshot payload content 12345"
        }

        It "Throws ArgumentException on null or empty byte array to protect" {
            { Protect-WD7Data -Data $null } | Should -Throw
            { Protect-WD7Data -Data @() } | Should -Throw
        }

        It "Throws ArgumentException on null or empty byte array to unprotect" {
            { Unprotect-WD7Data -EncryptedData $null } | Should -Throw
            { Unprotect-WD7Data -EncryptedData @() } | Should -Throw
        }

        It "Throws CryptographicException on corrupted or truncated encrypted data" {
            $corrupted = [byte[]]@(0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08)
            { Unprotect-WD7Data -EncryptedData $corrupted } | Should -Throw
        }
    }

    Context "Get-WinDebloat7Snapshot Metadata & Sidecar Resilience" {
        BeforeAll {
            $testSnapDir = Join-Path $env:TEMP "WD7_Test_Snapshots_$([guid]::NewGuid().ToString('N'))"
            $wd7Snapshots = Join-Path $testSnapDir "Win-Debloat7\Snapshots"
            New-Item -Path $wd7Snapshots -ItemType Directory -Force | Out-Null
        }

        AfterAll {
            if (Test-Path $testSnapDir) {
                Remove-Item -Path $testSnapDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "Parses valid unencrypted snapshot clixml" {
            $snapId = [guid]::NewGuid().ToString()
            $folder = Join-Path $testSnapDir "Win-Debloat7\Snapshots\$snapId"
            New-Item -Path $folder -ItemType Directory -Force | Out-Null

            $snapObj = [PSCustomObject]@{
                Id          = $snapId
                Name        = "Test-Snapshot-Plain"
                Description = "Plain snapshot test"
                Timestamp   = (Get-Date)
                Registry    = @{}
                Services    = @()
                Version     = "1.5.0"
            }
            $snapObj | ConvertTo-CliXml | Out-File -FilePath (Join-Path $folder "snapshot.clixml") -Encoding UTF8

            try {
                $origProgData = $env:ProgramData
                $env:ProgramData = $testSnapDir

                $list = Get-WinDebloat7Snapshot
                $found = $list | Where-Object { $_.Id -eq $snapId }
                $found | Should -Not -BeNullOrEmpty
                $found.Name | Should -Be "Test-Snapshot-Plain"
            }
            finally {
                $env:ProgramData = $origProgData
            }
        }

        It "Gracefully recovers from corrupted meta.json sidecar and falls back" {
            $snapId = [guid]::NewGuid().ToString()
            $folder = Join-Path $testSnapDir "Win-Debloat7\Snapshots\$snapId"
            New-Item -Path $folder -ItemType Directory -Force | Out-Null

            # Corrupted meta.json (malformed JSON)
            "INVALID_JSON_{{{bad_data" | Out-File -FilePath (Join-Path $folder "meta.json") -Encoding UTF8
            # Valid encrypted file dummy
            [byte[]]@(1,2,3,4) | Set-Content -Path (Join-Path $folder "snapshot.encrypted") -AsByteStream

            try {
                $origProgData = $env:ProgramData
                $env:ProgramData = $testSnapDir

                $list = Get-WinDebloat7Snapshot
                $found = $list | Where-Object { $_.Id -eq $snapId }
                $found | Should -Not -BeNullOrEmpty
                $found.Encrypted | Should -Be $true
            }
            finally {
                $env:ProgramData = $origProgData
            }
        }

        It "Returns empty array when snapshots directory does not exist" {
            try {
                $origProgData = $env:ProgramData
                $env:ProgramData = Join-Path $env:TEMP "NonExistentPath_$([guid]::NewGuid().ToString('N'))"

                $list = Get-WinDebloat7Snapshot
                $list.Count | Should -Be 0
            }
            finally {
                $env:ProgramData = $origProgData
            }
        }
    }
}

Describe "Core.State Module - Registry Diffing & Fidelity" {
    Context "Test-WD7RegistryValueEqual" {
        It "Compares DWord values with 100% fidelity" {
            Test-WD7RegistryValueEqual -Value1 0 -Kind1 'DWord' -Value2 0 -Kind2 'DWord' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 1 -Kind1 'DWord' -Value2 1 -Kind2 'DWord' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 ([int]42) -Kind1 'DWord' -Value2 ([int64]42) -Kind2 'DWord' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 0 -Kind1 'DWord' -Value2 1 -Kind2 'DWord' | Should -Be $false
        }

        It "Compares QWord values with 100% fidelity" {
            $q1 = [int64]9876543210123
            $q2 = [int64]9876543210123
            $q3 = [int64]9876543210124
            Test-WD7RegistryValueEqual -Value1 $q1 -Kind1 'QWord' -Value2 $q2 -Kind2 'QWord' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 $q1 -Kind1 'QWord' -Value2 $q3 -Kind2 'QWord' | Should -Be $false
        }

        It "Compares Binary blobs byte-by-byte with 100% fidelity" {
            $b1 = [byte[]]@(0xDE, 0xAD, 0xBE, 0xEF)
            $b2 = [byte[]]@(0xDE, 0xAD, 0xBE, 0xEF)
            $b3 = [byte[]]@(0xDE, 0xAD, 0x00, 0xEF)
            $b4 = [byte[]]@(0xDE, 0xAD, 0xBE)

            Test-WD7RegistryValueEqual -Value1 $b1 -Kind1 'Binary' -Value2 $b2 -Kind2 'Binary' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 $b1 -Kind1 'Binary' -Value2 $b3 -Kind2 'Binary' | Should -Be $false
            Test-WD7RegistryValueEqual -Value1 $b1 -Kind1 'Binary' -Value2 $b4 -Kind2 'Binary' | Should -Be $false
        }

        It "Compares MultiString string arrays element-by-element with 100% fidelity" {
            $m1 = [string[]]@('Alpha', 'Beta', 'Gamma')
            $m2 = [string[]]@('Alpha', 'Beta', 'Gamma')
            $m3 = [string[]]@('Alpha', 'Beta', 'Delta')
            $m4 = [string[]]@('Alpha', 'Beta')

            Test-WD7RegistryValueEqual -Value1 $m1 -Kind1 'MultiString' -Value2 $m2 -Kind2 'MultiString' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 $m1 -Kind1 'MultiString' -Value2 $m3 -Kind2 'MultiString' | Should -Be $false
            Test-WD7RegistryValueEqual -Value1 $m1 -Kind1 'MultiString' -Value2 $m4 -Kind2 'MultiString' | Should -Be $false
        }

        It "Compares Default unnamed values ('') with 100% fidelity" {
            $def1 = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
            $def2 = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
            $def3 = "{018D5C66-4533-4307-9B53-224DE2ED1FE6}"

            Test-WD7RegistryValueEqual -Value1 $def1 -Kind1 'String' -Value2 $def2 -Kind2 'String' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 $def1 -Kind1 'String' -Value2 $def3 -Kind2 'String' | Should -Be $false
        }

        It "Compares ExpandString without expanding variables" {
            Test-WD7RegistryValueEqual -Value1 "%SystemRoot%\system32" -Kind1 'ExpandString' -Value2 "%SystemRoot%\system32" -Kind2 'ExpandString' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 "%SystemRoot%\system32" -Kind1 'ExpandString' -Value2 "%ProgramFiles%\app" -Kind2 'ExpandString' | Should -Be $false
        }

        It "Rejects equality when registry kinds/types differ" {
            Test-WD7RegistryValueEqual -Value1 1 -Kind1 'DWord' -Value2 "1" -Kind2 'String' | Should -Be $false
            Test-WD7RegistryValueEqual -Value1 ([byte[]]@(1)) -Kind1 'Binary' -Value2 1 -Kind2 'DWord' | Should -Be $false
        }

        It "Handles nulls correctly" {
            Test-WD7RegistryValueEqual -Value1 $null -Kind1 'String' -Value2 $null -Kind2 'String' | Should -Be $true
            Test-WD7RegistryValueEqual -Value1 "Val" -Kind1 'String' -Value2 $null -Kind2 'String' | Should -Be $false
        }
    }

    Context "Compare-WinDebloat7Snapshot" {
        It "Detects key additions, key removals, value changes across all types, and service diffs" {
            $refSnap = [PSCustomObject]@{
                Id        = "Snap-Ref"
                Name      = "Before Changes"
                Registry  = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                        Existed   = $true
                        RegValues = @{
                            'AllowTelemetry' = @{ Value = 1; Kind = 'DWord' }
                            'BinaryBlob'     = @{ Value = [byte[]]@(0x01, 0x02, 0x03); Kind = 'Binary' }
                            'StringArray'    = @{ Value = [string[]]@('A', 'B'); Kind = 'MultiString' }
                            ''               = @{ Value = '{CLSID-ORIGINAL}'; Kind = 'String' }
                        }
                    }
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovedKey' = @{
                        Existed   = $true
                        RegValues = @{ 'SomeVal' = @{ Value = 'old'; Kind = 'String' } }
                    }
                }
                Services  = @(
                    [PSCustomObject]@{ Name = 'DiagTrack'; StartType = 'Automatic'; Status = 'Running' }
                )
            }

            $diffSnap = [PSCustomObject]@{
                Id        = "Snap-Diff"
                Name      = "After Changes"
                Registry  = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                        Existed   = $true
                        RegValues = @{
                            'AllowTelemetry' = @{ Value = 0; Kind = 'DWord' }                       # Modified DWord
                            'BinaryBlob'     = @{ Value = [byte[]]@(0x01, 0x02, 0x99); Kind = 'Binary' } # Modified Binary
                            'StringArray'    = @{ Value = [string[]]@('A', 'B', 'C'); Kind = 'MultiString' } # Modified MultiString
                            ''               = @{ Value = '{CLSID-MODIFIED}'; Kind = 'String' }     # Modified Default unnamed value
                            'NewlyAddedVal'  = @{ Value = 42; Kind = 'DWord' }                      # Added Value
                        }
                    }
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovedKey' = @{
                        Existed   = $false
                        RegValues = @{}
                    }
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NewKey' = @{
                        Existed   = $true
                        RegValues = @{ 'NewKeyVal' = @{ Value = 100; Kind = 'DWord' } }
                    }
                }
                Services  = @(
                    [PSCustomObject]@{ Name = 'DiagTrack'; StartType = 'Disabled'; Status = 'Stopped' }
                )
            }

            $diff = Compare-WinDebloat7Snapshot -ReferenceSnapshot $refSnap -DifferenceSnapshot $diffSnap

            $diff.HasChanges | Should -Be $true
            $diff.RegistryDiffs.Count | Should -BeGreaterThan 0

            # Verify specific diff records
            $telDiff = $diff.RegistryDiffs | Where-Object { $_.Path -like '*DataCollection' -and $_.ValueName -eq 'AllowTelemetry' }
            $telDiff.ChangeType | Should -Be 'ValueModified'
            $telDiff.OldValue | Should -Be 1
            $telDiff.NewValue | Should -Be 0

            $binDiff = $diff.RegistryDiffs | Where-Object { $_.ValueName -eq 'BinaryBlob' }
            $binDiff.ChangeType | Should -Be 'ValueModified'

            $strArrDiff = $diff.RegistryDiffs | Where-Object { $_.ValueName -eq 'StringArray' }
            $strArrDiff.ChangeType | Should -Be 'ValueModified'

            $defDiff = $diff.RegistryDiffs | Where-Object { $_.Path -like '*DataCollection' -and $_.ValueName -eq '' }
            $defDiff.ChangeType | Should -Be 'ValueModified'

            $remKeyDiff = $diff.RegistryDiffs | Where-Object { $_.Path -like '*RemovedKey' }
            $remKeyDiff.ChangeType | Should -Be 'KeyRemoved'

            $addKeyDiff = $diff.RegistryDiffs | Where-Object { $_.Path -like '*NewKey' -and $_.ChangeType -eq 'KeyAdded' }
            $addKeyDiff | Should -Not -BeNullOrEmpty

            # Verify Service diff
            $svcDiff = $diff.ServiceDiffs | Where-Object { $_.ServiceName -eq 'DiagTrack' }
            $svcDiff.ChangeType | Should -Be 'ServiceModified'
            $svcDiff.OldStartType | Should -Be 'Automatic'
            $svcDiff.NewStartType | Should -Be 'Disabled'
        }

        It "Returns HasChanges = $false when snapshots are identical" {
            $identicalSnap1 = [PSCustomObject]@{
                Id        = "Snap-1"
                Name      = "Identical 1"
                Registry  = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                        Existed   = $true
                        RegValues = @{
                            'AllowTelemetry' = @{ Value = 0; Kind = 'DWord' }
                            'StringArray'    = @{ Value = [string[]]@('X', 'Y'); Kind = 'MultiString' }
                        }
                    }
                }
                Services  = @(
                    [PSCustomObject]@{ Name = 'BITS'; StartType = 'Automatic'; Status = 'Running' }
                )
            }

            $identicalSnap2 = [PSCustomObject]@{
                Id        = "Snap-2"
                Name      = "Identical 2"
                Registry  = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                        Existed   = $true
                        RegValues = @{
                            'AllowTelemetry' = @{ Value = 0; Kind = 'DWord' }
                            'StringArray'    = @{ Value = [string[]]@('X', 'Y'); Kind = 'MultiString' }
                        }
                    }
                }
                Services  = @(
                    [PSCustomObject]@{ Name = 'BITS'; StartType = 'Automatic'; Status = 'Running' }
                )
            }

            $diff = Compare-WinDebloat7Snapshot -ReferenceSnapshot $identicalSnap1 -DifferenceSnapshot $identicalSnap2
            $diff.HasChanges | Should -Be $false
            $diff.TotalChanges | Should -Be 0
        }

        It "Includes unchanged values when -IncludeUnchanged switch is provided" {
            $snap1 = [PSCustomObject]@{
                Id        = "Snap-1"
                Name      = "Test"
                Registry  = @{
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
                        Existed   = $true
                        RegValues = @{ 'AllowTelemetry' = @{ Value = 0; Kind = 'DWord' } }
                    }
                }
                Services  = @()
            }

            $diff = Compare-WinDebloat7Snapshot -ReferenceSnapshot $snap1 -DifferenceSnapshot $snap1 -IncludeUnchanged
            $diff.HasChanges | Should -Be $false
            $unchanged = $diff.RegistryDiffs | Where-Object { $_.ChangeType -eq 'Unchanged' }
            $unchanged | Should -Not -BeNullOrEmpty
            $unchanged.ValueName | Should -Be 'AllowTelemetry'
        }
    }
}

Describe "Core.State Module - Rollback & Restoration" {
    Context "Restore-WD7RegistryKey" {
        It "Reverts modified values to their prior types and data" {
            Mock -ModuleName State Set-RegistryKey { return $true }
            Mock -ModuleName State Test-Path { return $true }
            Mock -ModuleName State Get-Item {
                return [PSCustomObject]@{
                    GetValueNames = { return @('AllowTelemetry') }
                }
            }

            $capturedState = @{
                Existed   = $true
                RegValues = @{
                    'AllowTelemetry' = @{ Value = 1; Kind = 'DWord' }
                    'Blob'           = @{ Value = [byte[]]@(0x01, 0x02); Kind = 'Binary' }
                    'Tags'           = @{ Value = [string[]]@('Tag1', 'Tag2'); Kind = 'MultiString' }
                }
            }

            $res = Restore-WD7RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -SnapState $capturedState
            $res.Success | Should -BeGreaterThan 0
            $res.Fail | Should -Be 0
        }

        It "Deletes framework-added values not present in snapshot" {
            Mock -ModuleName State Set-RegistryKey { return $true }
            Mock -ModuleName State Test-Path { return $true }
            Mock -ModuleName State Remove-ItemProperty { return $null }
            Mock -ModuleName State Get-Item {
                return [PSCustomObject]@{
                    # Registry now contains ExtraAddedVal not in snapshot
                    GetValueNames = { return @('AllowTelemetry', 'ExtraAddedVal') }
                }
            }

            $capturedState = @{
                Existed   = $true
                RegValues = @{
                    'AllowTelemetry' = @{ Value = 1; Kind = 'DWord' }
                }
            }

            $res = Restore-WD7RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -SnapState $capturedState
            $res.Success | Should -BeGreaterThan 0
        }

        It "Removes created key when Existed is false" {
            Mock -ModuleName State Test-Path { return $true }
            Mock -ModuleName State Remove-Item { return $null }

            $capturedState = @{
                Existed   = $false
                RegValues = @{}
            }

            $res = Restore-WD7RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NewCreatedKey' -SnapState $capturedState
            $res.Success | Should -Be 1
            $res.Fail | Should -Be 0
        }
    }

    Context "Restore-WinDebloatSnapshot and Restore-WinDebloat7Snapshot" {
        It "Throws when SnapshotId is not found (cmdlet and alias)" {
            { Restore-WinDebloatSnapshot -SnapshotId "NonExistent-Snapshot-999" } | Should -Throw -ExpectedMessage "*Snapshot ID not found*"
            { Restore-WinDebloat7Snapshot -SnapshotId "NonExistent-Snapshot-999" } | Should -Throw -ExpectedMessage "*Snapshot ID not found*"
        }

        It "Throws when snapshot file is corrupted" {
            $testSnapDir = Join-Path $env:TEMP "WD7_Test_CorruptedSnap_$([guid]::NewGuid().ToString('N'))"
            $snapId = "Corrupted-Snap-001"
            $folder = Join-Path $testSnapDir "Win-Debloat7\Snapshots\$snapId"
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
            "" | Out-File -FilePath (Join-Path $folder "snapshot.clixml") -Encoding UTF8

            try {
                $origProgData = $env:ProgramData
                $env:ProgramData = $testSnapDir

                { Restore-WinDebloatSnapshot -SnapshotId $snapId } | Should -Throw
                { Restore-WinDebloat7Snapshot -SnapshotId $snapId } | Should -Throw
            }
            finally {
                $env:ProgramData = $origProgData
                Remove-Item -Path $testSnapDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
