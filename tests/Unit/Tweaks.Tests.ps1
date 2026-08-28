<#
.SYNOPSIS
    Unit tests for Win-Debloat UI Tweaks Module (src/modules/Tweaks/UI.psm1).
.DESCRIPTION
    Validates taskbar alignment, context menu style, Explorer visibility settings,
    Start Menu configuration, search settings, taskbar extras, context menu item removals,
    Explorer shell restart, and all backward-compatibility WinDebloat7 / Classic aliases.
#>

Describe "Tweaks Module" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\..\src"
        Import-Module "$src\core\Logger.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\core\Registry.psm1" -Force -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Tweaks\UI.psm1" -Force -ErrorAction Stop
    }

    Context "Set-WinDebloatTaskbarAlignment and Set-WinDebloat7TaskbarAlignment" {
        It "Should set alignment to Left (0) via cmdlet" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloatTaskbarAlignment -Alignment Left -Confirm:$false
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and 
                $Name -eq "TaskbarAl" -and 
                $Value -eq 0 -and
                $Type -eq 'DWord'
            }
        }
        
        It "Should set alignment to Center (1) via alias" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloat7TaskbarAlignment -Alignment Center -Confirm:$false
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and 
                $Name -eq "TaskbarAl" -and 
                $Value -eq 1 -and
                $Type -eq 'DWord'
            }
        }

        It "Respects -WhatIf and does not modify registry" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloatTaskbarAlignment -Alignment Left -WhatIf
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 0
        }
    }
    
    Context "Set-WinDebloatStartMenu and Set-WinDebloat7StartMenu" {
        It "Should disable recommended section via cmdlet" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloatStartMenu -DisableRecommended -Confirm:$false
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "HideRecommendedSection" -and
                $Value -eq 1 -and
                $Type -eq 'DWord'
            }
        }

        It "Should disable recommended section via alias" {
            Mock -ModuleName UI Set-RegistryKey { return $true }
            
            Set-WinDebloat7StartMenu -DisableRecommended -Confirm:$false
            
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "HideRecommendedSection" -and
                $Value -eq 1
            }
        }

        It "Should enable recommended section (revert) via cmdlet and alias" {
            Mock -ModuleName UI Remove-RegistryKey { return $true }
            
            Set-WinDebloatStartMenu -EnableRecommended -Confirm:$false
            
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "HideRecommendedSection"
            }

            Set-WinDebloat7StartMenu -EnableRecommended -Confirm:$false
            
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName UI -Times 2 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "HideRecommendedSection"
            }
        }
    }

    Context "Set-WinDebloatContextMenu and Context Menu Aliases" {
        It "Should enable Classic Context Menu via cmdlet and aliases" {
            Mock -ModuleName UI Test-Path { return $false }
            Mock -ModuleName UI New-Item { return $null }
            Mock -ModuleName UI Set-Item { return $null }

            Set-WinDebloatContextMenu -Style Classic -Confirm:$false

            Should -Invoke -CommandName New-Item -ModuleName UI -Times 1
            Should -Invoke -CommandName Set-Item -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -and
                $Value -eq ""
            }

            Set-WinDebloat7ContextMenu -Style Classic -Confirm:$false
            Should -Invoke -CommandName Set-Item -ModuleName UI -Times 2

            Set-WinDebloatClassicContextMenu -Style Classic -Confirm:$false
            Should -Invoke -CommandName Set-Item -ModuleName UI -Times 3
        }

        It "Should restore Modern Context Menu by removing CLSID override" {
            Mock -ModuleName UI Test-Path { return $true }
            Mock -ModuleName UI Remove-Item { return $null }

            Set-WinDebloatContextMenu -Style Modern -Confirm:$false

            Should -Invoke -CommandName Remove-Item -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -and
                $Recurse -eq $true -and
                $Force -eq $true
            }
        }
    }

    Context "Set-WinDebloatExplorer and Set-WinDebloat7Explorer" {
        It "Configures file extensions and hidden files visibility" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloatExplorer -ShowFileExtensions -ShowHiddenFiles -Confirm:$false

            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "HideFileExt" -and
                $Value -eq 0
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "Hidden" -and
                $Value -eq 1
            }
        }

        It "Reverts file extensions and hidden files to Windows defaults" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloat7Explorer -HideFileExtensions -HideHiddenFiles -Confirm:$false

            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "HideFileExt" -and
                $Value -eq 1
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "Hidden" -and
                $Value -eq 2
            }
        }

        It "Configures Explorer default landing page (LaunchTo)" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloatExplorer -LaunchTo ThisPC -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Name -eq "LaunchTo" -and $Value -eq 1
            }

            Set-WinDebloatExplorer -LaunchTo Home -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Name -eq "LaunchTo" -and $Value -eq 2
            }

            Set-WinDebloatExplorer -LaunchTo Downloads -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Name -eq "LaunchTo" -and $Value -eq 3
            }

            Set-WinDebloatExplorer -LaunchTo OneDrive -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Name -eq "LaunchTo" -and $Value -eq 4
            }
        }

        It "Hides and restores OneDrive from Explorer navigation pane" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloatExplorer -HideOneDrive -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -and
                $Name -eq "System.IsPinnedToNameSpaceTree" -and
                $Value -eq 0
            }

            Set-WinDebloatExplorer -ShowOneDrive -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -and
                $Name -eq "System.IsPinnedToNameSpaceTree" -and
                $Value -eq 1
            }
        }

        It "Hides and restores Gallery and Home navigation entries" {
            Mock -ModuleName UI Test-Path { return $true }
            Mock -ModuleName UI New-Item { return $null }
            Mock -ModuleName UI Set-RegistryKey { return $true }
            Mock -ModuleName UI Remove-RegistryKey { return $true }

            Set-WinDebloatExplorer -HideGallery -HideHome -Confirm:$false
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -and
                $Name -eq "System.IsPinnedToNameSpaceTree" -and
                $Value -eq 0
            }

            Set-WinDebloatExplorer -ShowGallery -ShowHome -Confirm:$false
            Should -Invoke -CommandName Remove-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -and
                $Name -eq "System.IsPinnedToNameSpaceTree"
            }
        }

        It "Hides and restores 3D Objects and Music This PC folders" {
            Mock -ModuleName UI Test-Path { return $true }
            Mock -ModuleName UI Remove-Item { return $null }
            Mock -ModuleName UI New-Item { return $null }

            Set-WinDebloatExplorer -Hide3DObjects -HideMusic -Confirm:$false
            Should -Invoke -CommandName Remove-Item -ModuleName UI -Times 4

            Mock -ModuleName UI Test-Path { return $false }
            Set-WinDebloatExplorer -Show3DObjects -ShowMusic -Confirm:$false
            Should -Invoke -CommandName New-Item -ModuleName UI -Times 4
        }
    }

    Context "Set-WinDebloatSearch and Set-WinDebloat7Search" {
        It "Disables Bing search, highlights, and history" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloatSearch -DisableBingSearch -DisableSearchHighlights -DisableSearchHistory -Confirm:$false

            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "DisableSearchBoxSuggestions" -and
                $Value -eq 1
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -and
                $Name -eq "AllowCortana" -and
                $Value -eq 0
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -and
                $Name -eq "IsDynamicSearchBoxEnabled" -and
                $Value -eq 0
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -and
                $Name -eq "IsDeviceSearchHistoryEnabled" -and
                $Value -eq 0
            }
        }

        It "Re-enables Bing search, highlights, and history via alias" {
            Mock -ModuleName UI Remove-RegistryKey { return $true }
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloat7Search -EnableBingSearch -EnableSearchHighlights -EnableSearchHistory -Confirm:$false

            Should -Invoke -CommandName Remove-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -and
                $Name -eq "DisableSearchBoxSuggestions"
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -and
                $Name -eq "IsDynamicSearchBoxEnabled" -and
                $Value -eq 1
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -and
                $Name -eq "IsDeviceSearchHistoryEnabled" -and
                $Value -eq 1
            }
        }
    }

    Context "Set-WinDebloatTaskbarTweaks and Set-WinDebloat7TaskbarTweaks" {
        It "Configures taskbar search mode, Task View button, End Task, and LastActiveClick" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloatTaskbarTweaks -SearchMode Icon -HideTaskView -EnableEndTask -EnableLastActiveClick -Confirm:$false

            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -and
                $Name -eq "SearchboxTaskbarMode" -and
                $Value -eq 1
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "ShowTaskViewButton" -and
                $Value -eq 0
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" -and
                $Name -eq "TaskbarEndTask" -and
                $Value -eq 1
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "LastActiveClick" -and
                $Value -eq 1
            }
        }

        It "Reverts taskbar tweaks to Windows defaults via alias" {
            Mock -ModuleName UI Set-RegistryKey { return $true }

            Set-WinDebloat7TaskbarTweaks -ShowTaskView -DisableEndTask -DisableLastActiveClick -Confirm:$false

            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "ShowTaskViewButton" -and
                $Value -eq 1
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" -and
                $Name -eq "TaskbarEndTask" -and
                $Value -eq 0
            }
            Should -Invoke -CommandName Set-RegistryKey -ModuleName UI -Times 1 -ParameterFilter {
                $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -and
                $Name -eq "LastActiveClick" -and
                $Value -eq 0
            }
        }
    }

    Context "Set-WinDebloatContextMenuItems and Set-WinDebloat7ContextMenuItems" {
        It "Removes Share, Give Access To, and Include in Library handlers" {
            Mock -ModuleName UI Test-Path { return $true }
            Mock -ModuleName UI Remove-Item { return $null }

            Set-WinDebloatContextMenuItems -HideShare -HideGiveAccessTo -HideIncludeInLibrary -Confirm:$false

            # Total targets: 1 (ModernSharing) + 5 (Sharing) + 1 (Library Location) = 7
            Should -Invoke -CommandName Remove-Item -ModuleName UI -Times 7
        }

        It "Executes safely via backward-compatible alias" {
            Mock -ModuleName UI Test-Path { return $true }
            Mock -ModuleName UI Remove-Item { return $null }

            Set-WinDebloat7ContextMenuItems -HideShare -Confirm:$false

            Should -Invoke -CommandName Remove-Item -ModuleName UI -Times 1
        }
    }

    Context "Restart-WinDebloatExplorer and Restart-WinDebloat7Explorer" {
        It "Stops explorer process and relaunches when missing" {
            Mock -ModuleName UI Stop-Process { }
            Mock -ModuleName UI Start-Sleep { }
            Mock -ModuleName UI Get-Process { return $null }
            Mock -ModuleName UI Start-Process { }

            { Restart-WinDebloatExplorer -Confirm:$false } | Should -Not -Throw

            Should -Invoke -CommandName Stop-Process -ModuleName UI -Times 1 -ParameterFilter {
                $Name -eq "explorer" -and $Force -eq $true
            }
            Should -Invoke -CommandName Start-Process -ModuleName UI -Times 1 -ParameterFilter {
                $FilePath -eq "explorer.exe"
            }
        }

        It "Executes restart via alias" {
            Mock -ModuleName UI Stop-Process { }
            Mock -ModuleName UI Start-Sleep { }
            Mock -ModuleName UI Get-Process { return [PSCustomObject]@{ Id = 1234 } }
            Mock -ModuleName UI Start-Process { }

            { Restart-WinDebloat7Explorer -Confirm:$false } | Should -Not -Throw

            Should -Invoke -CommandName Stop-Process -ModuleName UI -Times 1
            Should -Invoke -CommandName Start-Process -ModuleName UI -Times 0
        }
    }

    Context "UI Tweaks Function and Alias Exports" {
        It "Exports all UI tweak cmdlets and their WinDebloat7 / Classic aliases" {
            (Get-Command "Set-WinDebloatTaskbarAlignment" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7TaskbarAlignment" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatContextMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7ContextMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatClassicContextMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatExplorer" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7Explorer" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloatStartMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Set-WinDebloat7StartMenu" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
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
