$sut = "$PSScriptRoot/../../src/core/Config.psm1"
Import-Module $sut -Force

Describe "Config Module" {
    Context "Get-WinDebloatRecommendedProfile and Get-WinDebloat7RecommendedProfile" {
        It "Should recommend Performance for < 8GB RAM (cmdlet and alias)" {
            Mock -ModuleName Config Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' } { 
                [pscustomobject]@{ TotalPhysicalMemory = 4GB } 
            }
            Mock -ModuleName Config Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_VideoController' } { $null }
            
            $result1 = Get-WinDebloatRecommendedProfile
            $result1 | Should -Be "Performance"

            $result2 = Get-WinDebloat7RecommendedProfile
            $result2 | Should -Be "Performance"
        }
        
        It "Should recommend Gaming for >= 16GB RAM + High End GPU" {
            Mock -ModuleName Config Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' } { 
                [pscustomobject]@{ TotalPhysicalMemory = 32GB } 
            }
            Mock -ModuleName Config Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_VideoController' } { 
                @([pscustomobject]@{ Name = "NVIDIA GeForce RTX 4090" }) 
            }
            
            $result = Get-WinDebloatRecommendedProfile
            $result | Should -Be "Gaming"
        }
        
        It "Should recommend Moderate for >= 8GB RAM but no dedicated GPU" {
            Mock -ModuleName Config Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' } { 
                [pscustomobject]@{ TotalPhysicalMemory = 16GB } 
            }
            Mock -ModuleName Config Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_VideoController' } { 
                @([pscustomobject]@{ Name = "Intel UHD Graphics" }) 
            }
            
            $result = Get-WinDebloatRecommendedProfile
            $result | Should -Be "Moderate"
        }
    }

    Context "Typo Map Coverage" {
        It "Contains typo mappings for all 19 system keys" {
            $expectedSystemKeys = @(
                'disable_fast_startup', 'prevent_auto_bitlocker', 'disable_delivery_optimization',
                'disable_storage_sense', 'no_auto_reboot_updates', 'no_early_updates',
                'disable_sticky_keys_shortcut', 'disable_share_drag_tray', 'disable_find_my_device',
                'disable_modern_standby_networking', 'disable_widgets', 'hide_chat_taskbar',
                'disable_transparency', 'disable_snap_assist', 'hide_start_all_apps',
                'disable_suggestions', 'hide_settings_home', 'hide_phone_link_start', 'debloat_search'
            )

            foreach ($key in $expectedSystemKeys) {
                # camelCase test
                $parts = $key -split '_'
                $camel = $parts[0] + (($parts | Select-Object -Skip 1 | ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_) }) -join '')
                $FieldTypoMap.ContainsKey($camel) | Should -Be $true
                $FieldTypoMap[$camel] | Should -Be $key

                # kebab-case test
                $kebab = $key -replace '_', '-'
                $FieldTypoMap.ContainsKey($kebab) | Should -Be $true
                $FieldTypoMap[$kebab] | Should -Be $key
            }
        }

        It "Contains typo mappings for all bloatware, privacy, performance, network, software keys" {
            # Bloatware
            $FieldTypoMap['removalMode'] | Should -Be 'removal_mode'
            $FieldTypoMap['removal-mode'] | Should -Be 'removal_mode'
            $FieldTypoMap['customList'] | Should -Be 'custom_list'
            $FieldTypoMap['custom-list'] | Should -Be 'custom_list'
            $FieldTypoMap['excludeList'] | Should -Be 'exclude_list'
            $FieldTypoMap['exclude-list'] | Should -Be 'exclude_list'
            $FieldTypoMap['whitelist'] | Should -Be 'exclude_list'

            # Privacy
            $FieldTypoMap['telemetryLevel'] | Should -Be 'telemetry_level'
            $FieldTypoMap['telemetry-level'] | Should -Be 'telemetry_level'
            $FieldTypoMap['disableAdvertisingId'] | Should -Be 'disable_advertising_id'
            $FieldTypoMap['disable-advertising-id'] | Should -Be 'disable_advertising_id'
            $FieldTypoMap['disableCopilot'] | Should -Be 'disable_copilot'
            $FieldTypoMap['disableRecall'] | Should -Be 'disable_recall'

            # Performance
            $FieldTypoMap['powerPlan'] | Should -Be 'power_plan'
            $FieldTypoMap['power-plan'] | Should -Be 'power_plan'
            $FieldTypoMap['visualEffects'] | Should -Be 'visual_effects'
            $FieldTypoMap['visual-effects'] | Should -Be 'visual_effects'
            $FieldTypoMap['disableGameBar'] | Should -Be 'disable_game_bar'
            $FieldTypoMap['disableBackgroundApps'] | Should -Be 'disable_background_apps'

            # Network
            $FieldTypoMap['dnsServers'] | Should -Be 'dns_servers'
            $FieldTypoMap['dns-servers'] | Should -Be 'dns_servers'
            $FieldTypoMap['disableIpv6'] | Should -Be 'disable_ipv6'
            $FieldTypoMap['disable-ipv6'] | Should -Be 'disable_ipv6'

            # Software
            $FieldTypoMap['packageManager'] | Should -Be 'package_manager'
            $FieldTypoMap['package-manager'] | Should -Be 'package_manager'
            $FieldTypoMap['installList'] | Should -Be 'install_list'
            $FieldTypoMap['install-list'] | Should -Be 'install_list'
            $FieldTypoMap['uninstallList'] | Should -Be 'uninstall_list'
            $FieldTypoMap['uninstall-list'] | Should -Be 'uninstall_list'
        }

        It "Contains section typo mappings" {
            $SectionTypoMap['system_tweaks'] | Should -Be 'system'
            $SectionTypoMap['tweaks'] | Should -Be 'system'
            $SectionTypoMap['qol'] | Should -Be 'system'
            $SectionTypoMap['apps'] | Should -Be 'software'
            $SectionTypoMap['packages'] | Should -Be 'software'
            $SectionTypoMap['telemetry'] | Should -Be 'privacy'
            $SectionTypoMap['perf'] | Should -Be 'performance'
            $SectionTypoMap['net'] | Should -Be 'network'
            $SectionTypoMap['bloat'] | Should -Be 'bloatware'
        }
    }

    Context "Enum Exhaustiveness & Consistency" {
        It "Defines all valid enums in ProfileSchema" {
            $ProfileSchema.ValidTelemetryLevels | Should -Be @('Security', 'Basic', 'Full')
            $ProfileSchema.ValidPowerPlans | Should -Be @('Balanced', 'HighPerformance', 'Ultimate')
            $ProfileSchema.ValidVisualEffects | Should -Be @('Appearance', 'Performance', 'Custom')
            $ProfileSchema.ValidRemovalModes | Should -Be @('None', 'Conservative', 'Moderate', 'Aggressive', 'Custom')
            $ProfileSchema.ValidPackageManagers | Should -Be @('Winget', 'Chocolatey', 'Auto')
            $ProfileSchema.ValidTargetOS | Should -Be @('Windows 10', 'Windows 11', 'Server 2022', 'Server 2025')
        }
    }

    Context "Profile Loading & Normalization" {
        It "Normalizes typos, booleans, and lists during import" {
            $tempFile = [System.IO.Path]::GetTempFileName() + ".yaml"
            $yamlContent = @"
metadata:
  profile_name: "Test Normalization Profile"
  profile_version: "1.0.0"
  targetOs: "Windows 11"

system_tweaks:
  disableFastStartup: "true"
  disable-storage-sense: "false"
  no_auto_reboot_updates: "1"

bloat:
  removalMode: "moderate"
  exclude-list: "Microsoft.WindowsStore"

telemetry:
  telemetryLevel: "security"
  disableAdvertisingId: "yes"

perf:
  powerPlan: "highperformance"
  visualEffects: "performance"

net:
  dnsServers: "1.1.1.1"
  disable-ipv6: "0"

apps:
  packageManager: "winget"
  installList: "7zip.7zip"
"@
            Set-Content -Path $tempFile -Value $yamlContent

            try {
                $cfg = Import-WinDebloat7Config -Path $tempFile -SkipDependencyCheck

                # Metadata normalization
                $cfg.metadata.name | Should -Be "Test Normalization Profile"
                $cfg.metadata.version | Should -Be "1.0.0"
                $cfg.metadata.target_os | Should -Be @("Windows 11")

                # Section & field remapping
                $cfg.system.disable_fast_startup | Should -Be $true
                $cfg.system.disable_storage_sense | Should -Be $false
                $cfg.system.no_auto_reboot_updates | Should -Be $true

                # Enum casing normalization
                $cfg.bloatware.removal_mode | Should -Be "Moderate"
                $cfg.bloatware.exclude_list | Should -Be @("Microsoft.WindowsStore")

                $cfg.privacy.telemetry_level | Should -Be "Security"
                $cfg.privacy.disable_advertising_id | Should -Be $true

                $cfg.performance.power_plan | Should -Be "HighPerformance"
                $cfg.performance.visual_effects | Should -Be "Performance"

                $cfg.network.dns_servers | Should -Be @("1.1.1.1")
                $cfg.network.disable_ipv6 | Should -Be $false

                $cfg.software.package_manager | Should -Be "Winget"
                $cfg.software.install_list | Should -Be @("7zip.7zip")
            }
            finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }

        It "Throws error when removal_mode is Custom but custom_list is missing" {
            $tempFile = [System.IO.Path]::GetTempFileName() + ".yaml"
            $yamlContent = @"
metadata:
  name: "Invalid Custom"
  version: "1.0.0"
bloatware:
  removal_mode: "Custom"
"@
            Set-Content -Path $tempFile -Value $yamlContent

            try {
                { Import-WinDebloat7Config -Path $tempFile -SkipDependencyCheck } | Should -Throw
            }
            finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }
    }

    Context "Default Profiles" {
        It "Loads all default profiles successfully via cmdlet and alias" {
            $profiles = @('conservative.yaml', 'essentials.yaml', 'gaming.yaml', 'moderate.yaml', 'performance.yaml')
            foreach ($p in $profiles) {
                $path = Join-Path $PSScriptRoot "../../profiles/$p"
                
                # Test primary cmdlet
                $cfg = Import-WinDebloatConfig -Path $path -SkipDependencyCheck
                $cfg | Should -Not -BeNullOrEmpty
                $cfg.metadata.name | Should -Not -BeNullOrEmpty
                $cfg.metadata.version | Should -Not -BeNullOrEmpty
                Test-WinDebloatConfig -Config $cfg | Should -Be $true

                # Test backward-compatible alias
                $cfg7 = Import-WinDebloat7Config -Path $path -SkipDependencyCheck
                $cfg7 | Should -Not -BeNullOrEmpty
                Test-WinDebloat7Config -Config $cfg7 | Should -Be $true
            }
        }
    }
}

