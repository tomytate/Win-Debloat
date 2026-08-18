$here = $PSScriptRoot
$root = Split-Path -Parent $here

Describe "Win-Debloat Compliance" {
    BeforeAll {
        $here = $PSScriptRoot
        $root = Split-Path -Parent $here
        Import-Module "$root\src\core\Logger.psm1" -Force
        Import-Module "$root\src\core\Registry.psm1" -Force
    }
    
    Context "1. Manifest Integrity" {
        It "Win-Debloat.psd1 should show valid module manifest" {
            $manifest = Sort-Object -Unique -InputObject (Test-ModuleManifest -Path "$root\Win-Debloat.psd1" -ErrorAction Stop)
            $manifest.Name | Should -Be "Win-Debloat"
        }

        It "Should not have duplicate NestedModules" {
            $content = Get-Content "$root\Win-Debloat.psd1" -Raw -ErrorAction Stop
            $content | Should -Not -Match "State.psm1.*State.psm1"
        }
    }

    Context "2. Core Hardening" {
        It "Set-RegistryKey should reject invalid hives" {
            { Set-RegistryKey -Path "INVALID:\Foo" -Name "Bar" -Value 1 } | Should -Throw
        }

        It "Set-RegistryKey should accept valid HKLM" {
            # Mock Set-ItemProperty to avoid actual registry write
            Mock Set-ItemProperty {}
            # Mock Test-Path to simulate key existence
            Mock Test-Path { return $true }
             
            # Should not throw
            { Set-RegistryKey -Path "HKLM:\Software\Test" -Name "TestVal" -Value 1 -Type DWord } | Should -Not -Throw
        }
    }
    
    Context "3. Syntax Validation" {
        BeforeDiscovery {
            $filesToTest = Get-ChildItem -Path "$PSScriptRoot\..\src" -Recurse -Filter "*.psm1" | ForEach-Object {
                @{ Name = $_.Name; FullName = $_.FullName }
            }
        }
        
        It "<Name> should pass syntax check" -ForEach $filesToTest {
            $content = Get-Content -LiteralPath $FullName -Raw
            $errs = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errs)
            $errs.Count | Should -Be 0
        }
    }
    
    Context "4. Bloatware Module Optimization" {
        Import-Module "$root\src\modules\Bloatware\Bloatware.psm1" -Force
        
        It "Regex compilation should be valid" {
            $testApps = @("Xbox", "Solitaire", "Weather")
            $regex = ($testApps | ForEach-Object { [regex]::Escape($_) }) -join '|'
            [regex]::new($regex) | Should -Not -BeNullOrEmpty
        }
    }
}
