Describe "Modules.Software" {
    BeforeAll {
        $src = Join-Path $PSScriptRoot "..\src"
        Import-Module "$src\core\Logger.psm1" -ErrorAction SilentlyContinue
        Import-Module "$src\modules\Software\Software.psm1" -Force -ErrorAction Stop
    }

    Context "Command and Alias Exports" {
        It "Exports Test-PackageManager and Install-PackageManager" {
            (Get-Command "Test-PackageManager" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Install-PackageManager" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }

        It "Exports Invoke-WD7PackageInstall" {
            (Get-Command "Invoke-WD7PackageInstall" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
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

        It "Exports Optimize-WinDebloatWinGetSettings and Optimize-WinDebloat7WinGetSettings alias" {
            (Get-Command "Optimize-WinDebloatWinGetSettings" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Optimize-WinDebloat7WinGetSettings" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }

        It "Exports Reset-WinDebloatWinGetSettings and Reset-WinDebloat7WinGetSettings alias" {
            (Get-Command "Reset-WinDebloatWinGetSettings" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            (Get-Command "Reset-WinDebloat7WinGetSettings" -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }
    }

    Context "Test-PackageManager Provider Support" {
        It "Detects PSResourceGet provider correctly" {
            $hasPSResource = [bool](Get-Command Install-PSResource -ErrorAction SilentlyContinue)
            (Test-PackageManager -Name "PSResourceGet") | Should -Be $hasPSResource
        }

        It "Checks Winget, Chocolatey, Npm, and Msstore without error" {
            { Test-PackageManager -Name "Winget" } | Should -Not -Throw
            { Test-PackageManager -Name "Chocolatey" } | Should -Not -Throw
            { Test-PackageManager -Name "Npm" } | Should -Not -Throw
            { Test-PackageManager -Name "Msstore" } | Should -Not -Throw
        }

        It "Rejects unsupported package manager name" {
            { Test-PackageManager -Name "UnsupportedPackageManager" } | Should -Throw
        }
    }

    Context "Install-PackageManager Provider Support" {
        It "Accepts PSResourceGet as valid parameter" {
            (Get-Command Install-PackageManager).Parameters['Name'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
                ForEach-Object { $_.ValidValues } | Should -Contain "PSResourceGet"
        }

        It "Returns true immediately when package manager is already installed" {
            Mock -ModuleName Software Test-PackageManager { return $true }
            (Install-PackageManager -Name "PSResourceGet" -Force) | Should -Be $true
        }

        It "Downloads and installs Winget with full mock isolation when not installed" {
            Mock -ModuleName Software Test-PackageManager { return $false }
            Mock -ModuleName Software Invoke-RestMethod {
                return [PSCustomObject]@{
                    assets = @(
                        [PSCustomObject]@{
                            name = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
                            browser_download_url = "https://github.com/microsoft/winget-cli/releases/download/v1.0/bundle.msixbundle"
                        }
                    )
                }
            }
            Mock -ModuleName Software Invoke-WebRequest { }
            Mock -ModuleName Software Add-AppxPackage { }
            Mock -ModuleName Software Remove-Item { }

            $result = Install-PackageManager -Name "Winget" -Force
            $result | Should -Be $true
            Should -Invoke -ModuleName Software Invoke-RestMethod -Times 1
            Should -Invoke -ModuleName Software Invoke-WebRequest -Times 1
            Should -Invoke -ModuleName Software Add-AppxPackage -Times 1
        }

        It "Installs Chocolatey with full mock isolation when not installed" {
            Mock -ModuleName Software Test-PackageManager { return $false }
            Mock -ModuleName Software Set-ExecutionPolicy { }
            Mock -ModuleName Software Invoke-WebRequest {
                return [PSCustomObject]@{ Content = "# choco mock install script" }
            }
            Mock -ModuleName Software Remove-Item { }

            $result = Install-PackageManager -Name "Chocolatey" -Force
            $result | Should -Be $true
            Should -Invoke -ModuleName Software Invoke-WebRequest -Times 1
        }
    }

    Context "Invoke-WD7PackageInstall with PSResourceGet" {
        It "Invokes Install-PSResource when PSResourceGet provider is specified" {
            Mock -ModuleName Software Install-PSResource { return $null }
            $code = Invoke-WD7PackageInstall -Provider "PSResourceGet" -PackageId "Sample.Module" -Quiet
            $code | Should -Be 0
            Should -Invoke -ModuleName Software Install-PSResource -Times 1 -ParameterFilter { $Name -eq "Sample.Module" }
        }

        It "Falls back to Update-PSResource when Install-PSResource throws" {
            Mock -ModuleName Software Install-PSResource { throw "Module already exists in repository" }
            Mock -ModuleName Software Update-PSResource { return $null }

            $code = Invoke-WD7PackageInstall -Provider "PSResourceGet" -PackageId "Sample.Module" -Quiet
            $code | Should -Be 0
            Should -Invoke -ModuleName Software Install-PSResource -Times 1
            Should -Invoke -ModuleName Software Update-PSResource -Times 1 -ParameterFilter { $Name -eq "Sample.Module" }
        }

        It "Returns 1 and captures error reason when both Install-PSResource and Update-PSResource fail" {
            Mock -ModuleName Software Install-PSResource { throw "Install failed: not found" }
            Mock -ModuleName Software Update-PSResource { throw "Update failed: network error" }

            $code = Invoke-WD7PackageInstall -Provider "PSResourceGet" -PackageId "Invalid.Package" -Quiet
            $code | Should -Be 1
            $pkgError = $global:LastPackageError
            $pkgError | Should -Not -BeNullOrEmpty
            $pkgError | Should -Match "Install-PSResource failed.*Update-PSResource failed"
        }
    }

    Context "Invoke-WD7PackageInstall with Native Package Installers (winget, choco)" {
        It "Invokes native winget successfully with expected arguments" {
            Mock -ModuleName Software winget {
                $global:LASTEXITCODE = 0
            }

            $code = Invoke-WD7PackageInstall -Provider "Winget" -PackageId "Sample.App" -Quiet
            $code | Should -Be 0
            Should -Invoke -ModuleName Software winget -Times 1
        }

        It "Invokes native choco successfully with expected arguments" {
            Mock -ModuleName Software choco {
                $global:LASTEXITCODE = 0
            }

            $code = Invoke-WD7PackageInstall -Provider "Chocolatey" -PackageId "sample-app" -Quiet
            $code | Should -Be 0
            Should -Invoke -ModuleName Software choco -Times 1
        }

        It "Captures error output via PSRedirectToVariable when native command fails" {
            Mock -ModuleName Software winget {
                Write-Error "Package not found in sources"
                $global:LASTEXITCODE = 1
            }

            $code = Invoke-WD7PackageInstall -Provider "Winget" -PackageId "NonExistentApp" -Quiet
            $code | Should -Be 1
            Should -Invoke -ModuleName Software winget -Times 1
        }
    }

    Context "Install-WinDebloatSoftware Result Object & Error Reasoning" {
        It "Returns comprehensive result object with details on successful installation" {
            Mock -ModuleName Software Test-PackageManager { return $true }
            Mock -ModuleName Software Invoke-WD7PackageInstall { return 0 }

            $res = Install-WinDebloatSoftware -Packages @("Vendor.App1", "Vendor.App2") -PackageManager "Winget" -Quiet
            $res.TotalRequested | Should -Be 2
            $res.Successful | Should -Be 2
            $res.Failed | Should -Be 0
            $res.Details.Count | Should -Be 2
            $res.Details[0].Status | Should -Be "Success"
            $res.Details[0].Package | Should -Be "Vendor.App1"
        }

        It "Captures detailed Error and ErrorReason in result object upon package installation failure" {
            Mock -ModuleName Software Test-PackageManager { return $true }
            Mock -ModuleName Software Invoke-WD7PackageInstall {
                $global:LastPackageError = "Installer returned error: Hash mismatch for downloaded file"
                return 1603
            }

            $res = Install-WinDebloatSoftware -Packages @("Vendor.FailingApp") -PackageManager "Winget" -Quiet
            $res.TotalRequested | Should -Be 1
            $res.Successful | Should -Be 0
            $res.Failed | Should -Be 1
            $res.Details.Count | Should -Be 1

            $failedDetail = $res.Details[0]
            $failedDetail.Status | Should -Be "Failed"
            $failedDetail.ExitCode | Should -Be 1603
            $failedDetail.Error | Should -Match "Hash mismatch"
            $failedDetail.ErrorReason | Should -Match "Hash mismatch"
        }

        It "Supports PSResourceGet provider with ByObject apps parameter" {
            Mock -ModuleName Software Test-PackageManager { return $true }
            Mock -ModuleName Software Invoke-WD7PackageInstall { return 0 }

            $apps = @(
                @{ Name = "PSScriptAnalyzer"; PSResourceGet = "PSScriptAnalyzer" }
            )

            $res = Install-WinDebloatSoftware -Apps $apps -PackageManager "PSResourceGet" -Quiet
            $res.Successful | Should -Be 1
            $res.Failed | Should -Be 0
            $res.Details[0].Provider | Should -Be "PSResourceGet"
            $res.Details[0].Id | Should -Be "PSScriptAnalyzer"
        }

        It "Attempts fallback provider when primary provider fails and captures error if fallback fails" {
            Mock -ModuleName Software Test-PackageManager { return $true }
            $global:callCount = 0
            Mock -ModuleName Software Invoke-WD7PackageInstall {
                $global:callCount++
                if ($global:callCount -eq 1) {
                    $global:LastPackageError = "Winget download failed"
                    return 1
                }
                else {
                    $global:LastPackageError = "Choco download failed"
                    return 2
                }
            }

            $apps = @(
                @{ Name = "DualApp"; Winget = "Dual.App"; Choco = "dual-app" }
            )

            $res = Install-WinDebloatSoftware -Apps $apps -PackageManager "Winget" -Quiet
            $res.Failed | Should -Be 1
            $res.Details[0].Status | Should -Be "Failed"
            $res.Details[0].Error | Should -Match "Choco download failed"
            $res.Details[0].ErrorReason | Should -Match "Choco download failed"
        }
    }

    Context "Update-WinDebloatSoftware" {
        It "Runs winget, choco, and PSResourceGet upgrades when available with full mock isolation" {
            Mock -ModuleName Software Test-PackageManager { return $true }
            Mock -ModuleName Software winget { $global:LASTEXITCODE = 0 }
            Mock -ModuleName Software choco { $global:LASTEXITCODE = 0 }
            Mock -ModuleName Software Update-PSResource { }

            { Update-WinDebloatSoftware } | Should -Not -Throw
            Should -Invoke -ModuleName Software winget -Times 1
            Should -Invoke -ModuleName Software choco -Times 1
            Should -Invoke -ModuleName Software Update-PSResource -Times 1
        }
    }

    Context "Optimize-WinDebloatWinGetSettings and Reset-WinDebloatWinGetSettings" {
        It "Optimizes WinGet settings with full filesystem mock isolation" {
            Mock -ModuleName Software Test-Path { return $false }
            Mock -ModuleName Software New-Item { }
            Mock -ModuleName Software Set-Content { }

            { Optimize-WinDebloatWinGetSettings } | Should -Not -Throw
            Should -Invoke -ModuleName Software New-Item -Times 1
            Should -Invoke -ModuleName Software Set-Content -Times 1
        }

        It "Resets WinGet settings with full filesystem mock isolation" {
            Mock -ModuleName Software Test-Path { return $true }
            Mock -ModuleName Software Remove-Item { }

            { Reset-WinDebloatWinGetSettings } | Should -Not -Throw
            Should -Invoke -ModuleName Software Remove-Item -Times 1
        }
    }

    Context "Get-WinDebloatEssentialsList" {
        It "Returns essentials categorized dictionary with all expected categories" {
            $essentials = Get-WinDebloatEssentialsList
            $essentials | Should -Not -BeNullOrEmpty
            $essentials.ContainsKey("Browsers") | Should -Be $true
            $essentials.ContainsKey("DevTools") | Should -Be $true
            $essentials.ContainsKey("AITools") | Should -Be $true
        }
    }
}
