$root = (Resolve-Path "$PSScriptRoot\..").Path
$src = Join-Path $root "src"

Describe "Core.SafetySystems" {
    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot\..").Path
        $src = Join-Path $root "src"
        Import-Module "$src\core\Logger.psm1" -Global -Force
        Import-Module "$src\core\Registry.psm1" -Global -Force
        Import-Module "$src\core\State.psm1" -Global -Force
    }

    It "Exports New-WinDebloatSnapshot cmdlet and New-WinDebloat7Snapshot alias" {
        $cmd = Get-Command "New-WinDebloatSnapshot" -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain "Name"
        $cmd.Parameters.Keys | Should -Contain "Description"

        $alias = Get-Command "New-WinDebloat7Snapshot" -ErrorAction SilentlyContinue
        $alias | Should -Not -BeNullOrEmpty
    }

    It "Exports Restore-WinDebloatSnapshot cmdlet and Restore-WinDebloat7Snapshot alias" {
        $cmd = Get-Command "Restore-WinDebloatSnapshot" -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain "SnapshotId"

        $alias = Get-Command "Restore-WinDebloat7Snapshot" -ErrorAction SilentlyContinue
        $alias | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatSnapshot cmdlet and Get-WinDebloat7Snapshot alias" {
        (Get-Command "Get-WinDebloatSnapshot" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7Snapshot" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Compare-WinDebloatSnapshot cmdlet and Compare-WinDebloat7Snapshot alias" {
        (Get-Command "Compare-WinDebloatSnapshot" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Compare-WinDebloat7Snapshot" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatRegistryTargets cmdlet and Get-WinDebloat7RegistryTargets alias" {
        (Get-Command "Get-WinDebloatRegistryTargets" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7RegistryTargets" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Tests registry key existence safely" {
        $root = (Resolve-Path "$PSScriptRoot\..").Path
        $src = Join-Path $root "src"
        Import-Module "$src\core\Registry.psm1" -Force
        Test-RegistryKey -Path "HKCU:\Software" | Should -Be $true
        Test-RegistryKey -Path "HKCU:\Software" -Name "NonExistentValue9999" | Should -Be $false
    }
}
