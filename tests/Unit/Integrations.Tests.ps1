# Pester Unit Tests for Win-Debloat Integrations Module
# Verifies non-destructive execution, download URLs, parameters, and error handling for:
# - Invoke-WinDebloatShutUp10 / Invoke-WinDebloat7ShutUp10
# - Invoke-WinDebloatAdwCleaner / Invoke-WinDebloat7AdwCleaner
# - Update-WinDebloatSDIO / Update-WinDebloat7SDIO

$sut = "$PSScriptRoot/../../src/modules/Integrations/Integrations.psm1"

Import-Module "$PSScriptRoot/../../src/core/Logger.psm1" -Force
Import-Module $sut -Force

Describe "Integrations Module" {

    Context "Invoke-WinDebloatShutUp10 and Invoke-WinDebloat7ShutUp10" {
        BeforeEach {
            Mock -ModuleName Integrations Invoke-WebRequest { }
            Mock -ModuleName Integrations Start-Process { }
        }

        It "Should download ShutUp10++ and launch without -Wait when -Recommended is omitted (cmdlet)" {
            Invoke-WinDebloatShutUp10

            Should -Invoke -CommandName Invoke-WebRequest -ModuleName Integrations -Times 1 -ParameterFilter {
                $Uri -eq "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -and
                $OutFile -like "*\OOSU10.exe"
            }

            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1 -ParameterFilter {
                $FilePath -like "*\OOSU10.exe" -and -not $Wait
            }
        }

        It "Should launch with -Wait when -Recommended switch is passed (alias)" {
            Invoke-WinDebloat7ShutUp10 -Recommended

            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1 -ParameterFilter {
                $FilePath -like "*\OOSU10.exe" -and $Wait -eq $true
            }
        }

        It "Should catch and log download errors gracefully without crashing" {
            Mock -ModuleName Integrations Invoke-WebRequest {
                throw [System.Net.WebException]::new("Mock network failure")
            }

            { Invoke-WinDebloatShutUp10 } | Should -Not -Throw
            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 0
        }
    }

    Context "Invoke-WinDebloatAdwCleaner and Invoke-WinDebloat7AdwCleaner" {
        BeforeEach {
            Mock -ModuleName Integrations Invoke-WebRequest { }
            Mock -ModuleName Integrations Start-Process { }
        }

        It "Should download AdwCleaner and launch with elevated Verb RunAs (cmdlet)" {
            Invoke-WinDebloatAdwCleaner

            Should -Invoke -CommandName Invoke-WebRequest -ModuleName Integrations -Times 1 -ParameterFilter {
                $Uri -eq "https://downloads.malwarebytes.com/file/adwcleaner" -and
                $OutFile -like "*\AdwCleaner.exe"
            }

            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1 -ParameterFilter {
                $FilePath -like "*\AdwCleaner.exe" -and $Verb -eq "RunAs"
            }
        }

        It "Should work via backward-compatible alias" {
            Invoke-WinDebloat7AdwCleaner

            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1 -ParameterFilter {
                $FilePath -like "*\AdwCleaner.exe" -and $Verb -eq "RunAs"
            }
        }

        It "Should catch and log download errors gracefully without crashing" {
            Mock -ModuleName Integrations Invoke-WebRequest {
                throw [System.Net.WebException]::new("Mock connection timeout")
            }

            { Invoke-WinDebloatAdwCleaner } | Should -Not -Throw
            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 0
        }
    }

    Context "Update-WinDebloatSDIO and Update-WinDebloat7SDIO" {
        BeforeEach {
            Mock -ModuleName Integrations Test-Path { return $false }
            Mock -ModuleName Integrations New-Item { }
            Mock -ModuleName Integrations Invoke-WebRequest { }
            Mock -ModuleName Integrations Expand-Archive { }
            Mock -ModuleName Integrations Remove-Item { }
            Mock -ModuleName Integrations Get-ChildItem {
                return [PSCustomObject]@{ FullName = "C:\ProgramData\Win-Debloat\Tools\SDIO\SDIO_x64_R123.exe" }
            }
            Mock -ModuleName Integrations Start-Process { }
        }

        It "Should create destination folder if missing, download ZIP, expand archive, remove zip, and launch x64 binary (cmdlet)" {
            Update-WinDebloatSDIO

            # Folder creation check
            Should -Invoke -CommandName New-Item -ModuleName Integrations -Times 1 -ParameterFilter {
                $ItemType -eq "Directory" -and $Path -like "*Tools\SDIO"
            }

            # Download
            Should -Invoke -CommandName Invoke-WebRequest -ModuleName Integrations -Times 1 -ParameterFilter {
                $Uri -eq "https://www.glenn.delahoy.com/downloads/sdio/SDIO_Latest.zip" -and
                $OutFile -like "*\SDIO.zip"
            }

            # Extraction
            Should -Invoke -CommandName Expand-Archive -ModuleName Integrations -Times 1 -ParameterFilter {
                $Path -like "*\SDIO.zip" -and $DestinationPath -like "*Tools\SDIO"
            }

            # Zip cleanup
            Should -Invoke -CommandName Remove-Item -ModuleName Integrations -Times 1 -ParameterFilter {
                $Path -like "*\SDIO.zip"
            }

            # Binary execution
            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1 -ParameterFilter {
                $FilePath -eq "C:\ProgramData\Win-Debloat\Tools\SDIO\SDIO_x64_R123.exe"
            }
        }

        It "Should execute via Update-WinDebloat7SDIO alias" {
            Update-WinDebloat7SDIO

            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1
        }

        It "Should respect custom -Path parameter" {
            $customPath = "C:\CustomTools\SDIO"
            Mock -ModuleName Integrations Test-Path { return $true }
            Mock -ModuleName Integrations Get-ChildItem {
                return [PSCustomObject]@{ FullName = "$customPath\SDIO_x64_Custom.exe" }
            }

            Update-WinDebloatSDIO -Path $customPath

            Should -Invoke -CommandName New-Item -ModuleName Integrations -Times 0
            Should -Invoke -CommandName Expand-Archive -ModuleName Integrations -Times 1 -ParameterFilter {
                $DestinationPath -eq $customPath
            }
            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 1 -ParameterFilter {
                $FilePath -eq "$customPath\SDIO_x64_Custom.exe"
            }
        }

        It "Should not start process if x64 executable is not found in extraction folder" {
            Mock -ModuleName Integrations Get-ChildItem { return $null }

            Update-WinDebloatSDIO

            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 0
        }

        It "Should catch and log exceptions gracefully without crashing" {
            Mock -ModuleName Integrations Invoke-WebRequest {
                throw [System.InvalidOperationException]::new("Mock archive error")
            }

            { Update-WinDebloatSDIO } | Should -Not -Throw
            Should -Invoke -CommandName Expand-Archive -ModuleName Integrations -Times 0
            Should -Invoke -CommandName Start-Process -ModuleName Integrations -Times 0
        }
    }
}
