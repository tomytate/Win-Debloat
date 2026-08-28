$srcRun = Join-Path $PSScriptRoot "..\src"
Write-Host "Source Root: $srcRun"

$root = (Resolve-Path "$PSScriptRoot\..").Path
$src = Join-Path $root "src"
Write-Host "Loading modules from: $src"

# Preload
Import-Module "$src\core\Logger.psm1" -Force
Import-Module "$src\core\Config.psm1" -Force
Import-Module "$src\core\Registry.psm1" -Force

Describe "Core.Config" {
    It "Validates Schema Correctly with both cmdlet and alias" {
        $config = [PSCustomObject]@{
            metadata  = @{ name = "Test"; version = "1.0" }
            bloatware = @{ removal_mode = "Custom"; custom_list = "App1" }
        }
        
        # Test primary cmdlet
        $res = Test-WinDebloatConfig -Config $config
        $res | Should -Be $true

        # Test backward-compatible alias
        $res7 = Test-WinDebloat7Config -Config $config
        $res7 | Should -Be $true
    }

    It "Exports Import-WinDebloatConfig and Import-WinDebloat7Config" {
        (Get-Command "Import-WinDebloatConfig" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Import-WinDebloat7Config" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatProfilePlan and Get-WinDebloat7ProfilePlan" {
        (Get-Command "Get-WinDebloatProfilePlan" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7ProfilePlan" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Detects Invalid Bloatware Mode" {
        $Script:ProfileSchema.ValidRemovalModes | Should -Not -Contain "DestroyEverything"
    }
}

Describe "Core.Registry" {
    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot\..").Path
        $src = Join-Path $root "src"
        Import-Module "$src\core\Registry.psm1" -Force
        $Script:TestRegPath = "HKCU:\Software\WinDebloatUnitTest_$([Guid]::NewGuid().ToString('N'))"
    }

    AfterAll {
        if ($Script:TestRegPath) {
            Remove-RegistryKey -Path $Script:TestRegPath -WholeKey -ErrorAction SilentlyContinue | Out-Null
        }
    }

    It "Exports Export-RegistryKey and accepts parameters" {
        $cmd = Get-Command "Export-RegistryKey" -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain "Path"
        $cmd.Parameters.Keys | Should -Contain "OutputPath"
    }

    It "Exports Set-RegistryKey, Get-RegistryKey, Test-RegistryKey, and Remove-RegistryKey" {
        (Get-Command "Set-RegistryKey" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-RegistryKey" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Test-RegistryKey" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Remove-RegistryKey" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Sets, retrieves, and tests registry values across types with direct .NET calls" {
        # DWord
        Set-RegistryKey -Path $Script:TestRegPath -Name "DWordVal" -Value 42 -Type DWord | Should -Be $true
        Get-RegistryKey -Path $Script:TestRegPath -Name "DWordVal" | Should -Be 42
        Test-RegistryKey -Path $Script:TestRegPath -Name "DWordVal" | Should -Be $true

        # String
        Set-RegistryKey -Path $Script:TestRegPath -Name "StringVal" -Value "Hello Win-Debloat" -Type String | Should -Be $true
        Get-RegistryKey -Path $Script:TestRegPath -Name "StringVal" | Should -Be "Hello Win-Debloat"

        # QWord
        Set-RegistryKey -Path $Script:TestRegPath -Name "QWordVal" -Value 9876543210 -Type QWord | Should -Be $true
        Get-RegistryKey -Path $Script:TestRegPath -Name "QWordVal" | Should -Be 9876543210

        # MultiString
        $arr = @("Alpha", "Beta", "Gamma")
        Set-RegistryKey -Path $Script:TestRegPath -Name "MultiVal" -Value $arr -Type MultiString | Should -Be $true
        $retMulti = Get-RegistryKey -Path $Script:TestRegPath -Name "MultiVal"
        $retMulti | Should -Be $arr

        # Default (unnamed) value
        Set-RegistryKey -Path $Script:TestRegPath -Name "" -Value "DefaultData" -Type String | Should -Be $true
        Get-RegistryKey -Path $Script:TestRegPath | Should -Be "DefaultData"
        Get-RegistryKey -Path $Script:TestRegPath -Name "(Default)" | Should -Be "DefaultData"

        # Missing value fallback
        Get-RegistryKey -Path $Script:TestRegPath -Name "NonExistentVal" -DefaultValue "Fallback" | Should -Be "Fallback"
    }

    It "Preserves ShouldProcess -WhatIf without applying changes" {
        Set-RegistryKey -Path "$Script:TestRegPath\WhatIfKey" -Name "WhatIfVal" -Value 123 -Type DWord -WhatIf | Should -Be $false
        Test-RegistryKey -Path "$Script:TestRegPath\WhatIfKey" | Should -Be $false
    }

    It "Removes individual values and whole subkey trees cleanly" {
        $subKey = "$Script:TestRegPath\SubTreeTest"
        Set-RegistryKey -Path $subKey -Name "Val1" -Value 1 -Type DWord | Should -Be $true
        Set-RegistryKey -Path $subKey -Name "Val2" -Value 2 -Type DWord | Should -Be $true
        Test-RegistryKey -Path $subKey | Should -Be $true

        # Remove single value
        Remove-RegistryKey -Path $subKey -Name "Val1" | Should -Be $true
        Test-RegistryKey -Path $subKey -Name "Val1" | Should -Be $false
        Test-RegistryKey -Path $subKey -Name "Val2" | Should -Be $true

        # Remove whole key tree
        Remove-RegistryKey -Path $subKey -WholeKey | Should -Be $true
        Test-RegistryKey -Path $subKey | Should -Be $false
    }

    It "Refuses to delete protected system registry paths" {
        Remove-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft" -WholeKey | Should -Be $false
        Remove-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet" -WholeKey | Should -Be $false
    }
}

Describe "Core.Logger" {
    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot\..").Path
        $src = Join-Path $root "src"
        Import-Module "$src\core\Logger.psm1" -Force
    }

    It "Exports Start-WinDebloatLogging, Write-Log, Get-WinDebloatLogPath and backward-compatible aliases" {
        (Get-Command "Start-WinDebloatLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Write-Log" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloatLogPath" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty

        (Get-Command "Start-WD7Logging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Start-WinDebloat7Logging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Start-WDLogging" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WD7LogPath" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7LogPath" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WDLogPath" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Accepts -ErrorRecord parameter on Write-Log" {
        $cmd = Get-Command "Write-Log"
        $cmd.Parameters.Keys | Should -Contain "ErrorRecord"
        $cmd.Parameters["ErrorRecord"].ParameterType | Should -Be ([System.Management.Automation.ErrorRecord])
    }

    It "Initializes logging and returns valid log path with Get-WinDebloatLogPath" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinDebloat-LoggerTest-$([Guid]::NewGuid().ToString('N'))"
        try {
            Start-WinDebloatLogging -Path $tempDir
            $logPath = Get-WinDebloatLogPath
            $logPath | Should -Not -BeNullOrEmpty
            (Test-Path -LiteralPath $logPath) | Should -Be $true
        }
        finally {
            if (Test-Path -LiteralPath $tempDir) {
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It "Logs standard messages across levels to file" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinDebloat-LoggerTest-$([Guid]::NewGuid().ToString('N'))"
        try {
            Start-WinDebloatLogging -Path $tempDir
            $logPath = Get-WinDebloatLogPath

            Write-Log -Message "Testing Info level" -Level Info -Component "TestComp"
            Write-Log -Message "Testing Success level" -Level Success
            Write-Log -Message "Testing Warning level" -Level Warning
            Write-Log -Message "Testing Header level" -Level Header

            $content = Get-Content -LiteralPath $logPath -Raw
            $content | Should -Match "\[Info\] \[TestComp\] Testing Info level"
            $content | Should -Match "\[Success\] Testing Success level"
            $content | Should -Match "\[Warning\] Testing Warning level"
            $content | Should -Match "\[Header\] Testing Header level"
        }
        finally {
            if (Test-Path -LiteralPath $tempDir) {
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It "Captures structured exception details, stack traces, and Get-Error diagnostics when -ErrorRecord is provided" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinDebloat-LoggerTest-$([Guid]::NewGuid().ToString('N'))"
        try {
            Start-WinDebloatLogging -Path $tempDir
            $logPath = Get-WinDebloatLogPath

            $capturedError = try {
                [int]::Parse("NotANumber")
            }
            catch {
                $_
            }

            $capturedError | Should -Not -BeNullOrEmpty
            Write-Log -Message "Custom parse failure message" -Level Error -Component "Parser" -ErrorRecord $capturedError

            $content = Get-Content -LiteralPath $logPath -Raw
            $content | Should -Match "\[Error\] \[Parser\] Custom parse failure message"
            $content | Should -Match "\[ERROR DETAILS\]"
            $content | Should -Match "Exception Type:\s+System.Management.Automation.MethodInvocationException"
            $content | Should -Match "Exception Message:"
            $content | Should -Match "FullyQualifiedErrorId:\s+FormatException"
            $content | Should -Match "Script StackTrace:"
            $content | Should -Match "InnerException \[1\]:"
            $content | Should -Match "Type:\s+System.FormatException"
            $content | Should -Match "Extended Diagnostic Data \(Get-Error\)"
        }
        finally {
            if (Test-Path -LiteralPath $tempDir) {
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It "Defaults Message and Level to Error when only -ErrorRecord is passed" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "WinDebloat-LoggerTest-$([Guid]::NewGuid().ToString('N'))"
        try {
            Start-WinDebloatLogging -Path $tempDir
            $logPath = Get-WinDebloatLogPath

            $capturedError = try {
                1 / 0
            }
            catch {
                $_
            }

            Write-Log -ErrorRecord $capturedError

            $content = Get-Content -LiteralPath $logPath -Raw
            $content | Should -Match "\[Error\] Attempted to divide by zero"
            $content | Should -Match "\[ERROR DETAILS\]"
            $content | Should -Match "DivideByZeroException"
        }
        finally {
            if (Test-Path -LiteralPath $tempDir) {
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
