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
}
