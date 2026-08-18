$sut = "$PSScriptRoot/../../src/modules/Tweaks/UI.psm1"

Import-Module "$PSScriptRoot/../../src/core/Logger.psm1" -Force
Import-Module "$PSScriptRoot/../../src/core/Registry.psm1" -Force
Import-Module $sut -Force

Describe "Tweaks Module" {
    Context "Set-WinDebloatTaskbarAlignment and Set-WinDebloat7TaskbarAlignment" {
        It "Should set alignment to Left (0) via cmdlet" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloatTaskbarAlignment -Alignment Left
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and 
                $Name -eq "TaskbarAl" -and 
                $Value -eq 0
            }
        }
        
        It "Should set alignment to Center (1) via alias" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloat7TaskbarAlignment -Alignment Center
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -ParameterFilter {
                $Value -eq 1
            }
        }
    }
    
    Context "Set-WinDebloatStartMenu and Set-WinDebloat7StartMenu" {
        It "Should disable recommended section via cmdlet" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloatStartMenu -DisableRecommended
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "HideRecommendedSection" -and
                $Value -eq 1
            }
        }

        It "Should disable recommended section via alias" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloat7StartMenu -DisableRecommended
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -ParameterFilter {
                $Value -eq 1
            }
        }
    }

    Context "UI Tweaks Function and Alias Exports" {
        It "Exports all UI tweak cmdlets and their WinDebloat7 aliases" {
            (Get-Command "Set-WinDebloatContextMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7ContextMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatExplorer" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7Explorer" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatSearch" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7Search" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatTaskbarTweaks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7TaskbarTweaks" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatContextMenuItems" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7ContextMenuItems" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Restart-WinDebloatExplorer" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Restart-WinDebloat7Explorer" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }
    }
}
