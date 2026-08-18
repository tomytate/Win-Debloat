Describe "Modules.Software" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Software\Software.psm1" -ErrorAction Stop
    }

    It "Exports Test-PackageManager and Install-PackageManager" {
        (Get-Command "Test-PackageManager" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Install-PackageManager" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Get-WinDebloatEssentialsList and Get-WinDebloat7EssentialsList alias" {
        (Get-Command "Get-WinDebloatEssentialsList" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Get-WinDebloat7EssentialsList" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Install-WinDebloatSoftware and Install-WinDebloat7Software alias" {
        (Get-Command "Install-WinDebloatSoftware" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Install-WinDebloat7Software" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Update-WinDebloatSoftware and Update-WinDebloat7Software alias" {
        (Get-Command "Update-WinDebloatSoftware" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Update-WinDebloat7Software" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Install-WinDebloatEssentials and Install-WinDebloat7Essentials alias" {
        (Get-Command "Install-WinDebloatEssentials" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Install-WinDebloat7Essentials" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It "Exports Install-WinDebloatProfileSoftware and Install-WinDebloat7ProfileSoftware alias" {
        (Get-Command "Install-WinDebloatProfileSoftware" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command "Install-WinDebloat7ProfileSoftware" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }
}
