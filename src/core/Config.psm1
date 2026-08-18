#Requires -Version 7.6

<#
.SYNOPSIS
    Configuration management module for Win-Debloat
    
.DESCRIPTION
    Handles YAML profile loading, validation and schema checking.
    Uses PowerShell 7.5 best practices with user consent for dependencies.
    
.NOTES
    Module: Win-Debloat.Core.Config
    Version: 1.5.0
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76
#>

using namespace System.Management.Automation

Import-Module "$PSScriptRoot\Logger.psm1" -Force

# Schema definition for validation (SEC-004 fix)
$Script:ProfileSchema = @{
    Required             = @('metadata')
    MetadataRequired     = @('name', 'version')
    ValidSections        = @('metadata', 'bloatware', 'privacy', 'performance', 'network', 'system', 'software')
    ValidTelemetryLevels = @('Security', 'Basic', 'Full')
    ValidPowerPlans      = @('Balanced', 'HighPerformance', 'Ultimate')
    ValidVisualEffects   = @('Appearance', 'Performance', 'Custom')
    ValidRemovalModes    = @('None', 'Conservative', 'Moderate', 'Aggressive', 'Custom')
    ValidPackageManagers = @('Winget', 'Chocolatey', 'Auto')
    ValidTargetOS        = @('Windows 10', 'Windows 11')
}

# Static field definitions for performance (avoids repeated heap allocations during import)
$Script:ConfigBooleanFields = @(
    @{ Section = 'privacy';     Field = 'disable_advertising_id' }
    @{ Section = 'privacy';     Field = 'disable_activity_history' }
    @{ Section = 'privacy';     Field = 'disable_location_tracking' }
    @{ Section = 'privacy';     Field = 'disable_copilot' }
    @{ Section = 'privacy';     Field = 'disable_recall' }
    @{ Section = 'privacy';     Field = 'block_telemetry_domains' }
    @{ Section = 'performance'; Field = 'disable_game_bar' }
    @{ Section = 'performance'; Field = 'disable_background_apps' }
    @{ Section = 'performance'; Field = 'gaming_mode' }
    @{ Section = 'network';     Field = 'disable_ipv6' }
    @{ Section = 'system';      Field = 'disable_fast_startup' }
    @{ Section = 'system';      Field = 'prevent_auto_bitlocker' }
    @{ Section = 'system';      Field = 'disable_delivery_optimization' }
    @{ Section = 'system';      Field = 'disable_storage_sense' }
    @{ Section = 'system';      Field = 'no_auto_reboot_updates' }
    @{ Section = 'system';      Field = 'no_early_updates' }
    @{ Section = 'system';      Field = 'disable_sticky_keys_shortcut' }
    @{ Section = 'system';      Field = 'disable_share_drag_tray' }
    @{ Section = 'system';      Field = 'disable_find_my_device' }
    @{ Section = 'system';      Field = 'disable_modern_standby_networking' }
    @{ Section = 'system';      Field = 'disable_widgets' }
    @{ Section = 'system';      Field = 'hide_chat_taskbar' }
    @{ Section = 'system';      Field = 'disable_transparency' }
    @{ Section = 'system';      Field = 'disable_snap_assist' }
    @{ Section = 'system';      Field = 'hide_start_all_apps' }
    @{ Section = 'system';      Field = 'disable_suggestions' }
    @{ Section = 'system';      Field = 'hide_settings_home' }
    @{ Section = 'system';      Field = 'hide_phone_link_start' }
    @{ Section = 'system';      Field = 'debloat_search' }
)

$Script:ConfigListFields = @(
    @{ Section = 'bloatware'; Field = 'custom_list' }
    @{ Section = 'bloatware'; Field = 'exclude_list' }
    @{ Section = 'network';   Field = 'dns_servers' }
    @{ Section = 'software';  Field = 'install_list' }
    @{ Section = 'software';  Field = 'uninstall_list' }
    @{ Section = 'metadata';  Field = 'target_os' }
)

# Section Typo and Alias Map
$Script:SectionTypoMap = @{
    # System aliases & typos
    'system_tweaks'     = 'system'
    'systemTweaks'      = 'system'
    'system-tweaks'     = 'system'
    'system_qol'        = 'system'
    'systemQoL'         = 'system'
    'system-qol'        = 'system'
    'tweaks'            = 'system'
    'qol'               = 'system'
    'sys'               = 'system'
    'System'            = 'system'

    # Software aliases & typos
    'apps'              = 'software'
    'packages'          = 'software'
    'software_packages' = 'software'
    'softwarePackages'  = 'software'
    'software-packages' = 'software'
    'apps_install'      = 'software'
    'appsInstall'       = 'software'
    'apps-install'      = 'software'
    'Software'          = 'software'

    # Privacy aliases & typos
    'telemetry'         = 'privacy'
    'telemetry_config'  = 'privacy'
    'telemetryConfig'   = 'privacy'
    'telemetry-config'  = 'privacy'
    'Privacy'           = 'privacy'

    # Performance aliases & typos
    'perf'              = 'performance'
    'optimization'      = 'performance'
    'tuning'            = 'performance'
    'Performance'       = 'performance'

    # Network aliases & typos
    'net'               = 'network'
    'networking'        = 'network'
    'Network'           = 'network'

    # Metadata aliases & typos
    'meta'              = 'metadata'
    'info'              = 'metadata'
    'Metadata'          = 'metadata'

    # Bloatware aliases & typos
    'bloat'             = 'bloatware'
    'apps_removal'      = 'bloatware'
    'appsRemoval'       = 'bloatware'
    'apps-removal'      = 'bloatware'
    'debloat'           = 'bloatware'
    'Bloatware'         = 'bloatware'
}

# Exhaustive Field Typo Map (camelCase, kebab-case, snake_case, PascalCase, aliases)
$Script:FieldTypoMap = @{
    # ── Bloatware Section ──
    # removal_mode
    'removalMode'                       = 'removal_mode'
    'removal-mode'                      = 'removal_mode'
    'removal_level'                     = 'removal_mode'
    'removalLevel'                      = 'removal_mode'
    'removal-level'                     = 'removal_mode'
    'removal_preset'                    = 'removal_mode'
    'removalPreset'                     = 'removal_mode'
    'removal-preset'                    = 'removal_mode'
    'mode'                              = 'removal_mode'
    # custom_list
    'customList'                        = 'custom_list'
    'custom-list'                       = 'custom_list'
    'custom_apps'                       = 'custom_list'
    'customApps'                        = 'custom_list'
    'custom-apps'                       = 'custom_list'
    'apps_list'                         = 'custom_list'
    'appsList'                          = 'custom_list'
    'apps-list'                         = 'custom_list'
    # exclude_list
    'excludeList'                       = 'exclude_list'
    'exclude-list'                      = 'exclude_list'
    'whitelist'                         = 'exclude_list'
    'white_list'                        = 'exclude_list'
    'white-list'                        = 'exclude_list'
    'preserve_list'                     = 'exclude_list'
    'preserveList'                      = 'exclude_list'
    'preserve-list'                     = 'exclude_list'
    'preserve'                          = 'exclude_list'
    'excluded'                          = 'exclude_list'
    'excludes'                          = 'exclude_list'

    # ── Privacy Section ──
    # telemetry_level
    'telemetryLevel'                    = 'telemetry_level'
    'telemetry-level'                   = 'telemetry_level'
    'telemetry'                         = 'telemetry_level'
    'telemetry_mode'                    = 'telemetry_level'
    'telemetryMode'                     = 'telemetry_level'
    'telemetry-mode'                    = 'telemetry_level'
    # disable_advertising_id
    'disableAdvertisingId'              = 'disable_advertising_id'
    'disable-advertising-id'            = 'disable_advertising_id'
    'disable_advertising'               = 'disable_advertising_id'
    'disableAdvertising'                = 'disable_advertising_id'
    'disable-advertising'               = 'disable_advertising_id'
    'advertising_id'                    = 'disable_advertising_id'
    'advertisingId'                     = 'disable_advertising_id'
    'advertising-id'                    = 'disable_advertising_id'
    'disable_ad_id'                     = 'disable_advertising_id'
    'disableAdId'                       = 'disable_advertising_id'
    'disable-ad-id'                     = 'disable_advertising_id'
    # disable_activity_history
    'disableActivityHistory'            = 'disable_activity_history'
    'disable-activity-history'          = 'disable_activity_history'
    'activity_history'                  = 'disable_activity_history'
    'activityHistory'                   = 'disable_activity_history'
    'activity-history'                  = 'disable_activity_history'
    'disable_activity'                  = 'disable_activity_history'
    'disableActivity'                   = 'disable_activity_history'
    'disable-activity'                  = 'disable_activity_history'
    # disable_location_tracking
    'disableLocationTracking'           = 'disable_location_tracking'
    'disable-location-tracking'         = 'disable_location_tracking'
    'location_tracking'                 = 'disable_location_tracking'
    'locationTracking'                  = 'disable_location_tracking'
    'location-tracking'                 = 'disable_location_tracking'
    'disable_location'                  = 'disable_location_tracking'
    'disableLocation'                   = 'disable_location_tracking'
    'disable-location'                  = 'disable_location_tracking'
    # disable_copilot
    'disableCopilot'                    = 'disable_copilot'
    'disable-copilot'                   = 'disable_copilot'
    'copilot'                           = 'disable_copilot'
    'disable_ai'                        = 'disable_copilot'
    'disableAi'                         = 'disable_copilot'
    'disable-ai'                        = 'disable_copilot'
    # disable_recall
    'disableRecall'                     = 'disable_recall'
    'disable-recall'                    = 'disable_recall'
    'recall'                            = 'disable_recall'
    'disable_windows_recall'            = 'disable_recall'
    'disableWindowsRecall'              = 'disable_recall'
    'disable-windows-recall'            = 'disable_recall'
    # block_telemetry_domains
    'blockTelemetryDomains'             = 'block_telemetry_domains'
    'block-telemetry-domains'           = 'block_telemetry_domains'

    # ── Performance Section ──
    # power_plan
    'powerPlan'                         = 'power_plan'
    'power-plan'                        = 'power_plan'
    'power_mode'                        = 'power_plan'
    'powerMode'                         = 'power_plan'
    'power-mode'                        = 'power_plan'
    # visual_effects
    'visualEffects'                     = 'visual_effects'
    'visual-effects'                    = 'visual_effects'
    'visual_effect'                     = 'visual_effects'
    'visualEffect'                      = 'visual_effects'
    'visual-effect'                     = 'visual_effects'
    'visuals'                           = 'visual_effects'
    # disable_game_bar
    'disableGameBar'                    = 'disable_game_bar'
    'disable-game-bar'                  = 'disable_game_bar'
    'game_bar'                          = 'disable_game_bar'
    'gameBar'                           = 'disable_game_bar'
    'game-bar'                          = 'disable_game_bar'
    'disable_xbox_game_bar'             = 'disable_game_bar'
    'disableXboxGameBar'                = 'disable_game_bar'
    'disable-xbox-game-bar'             = 'disable_game_bar'
    'disable_gamebar'                   = 'disable_game_bar'
    'disable-gamebar'                   = 'disable_game_bar'
    # disable_background_apps
    'disableBackgroundApps'             = 'disable_background_apps'
    'disable-background-apps'           = 'disable_background_apps'
    'background_apps'                   = 'disable_background_apps'
    'backgroundApps'                    = 'disable_background_apps'
    'background-apps'                   = 'disable_background_apps'
    'disable_background_applications'   = 'disable_background_apps'
    'disableBackgroundApplications'     = 'disable_background_apps'
    'disable-background-applications'   = 'disable_background_apps'
    # gaming_mode
    'gamingMode'                        = 'gaming_mode'
    'gaming-mode'                       = 'gaming_mode'

    # ── Network Section ──
    # dns_servers
    'dnsServers'                        = 'dns_servers'
    'dns-servers'                       = 'dns_servers'
    'dns_server'                        = 'dns_servers'
    'dnsServer'                         = 'dns_servers'
    'dns-server'                        = 'dns_servers'
    'dns'                               = 'dns_servers'
    'nameservers'                       = 'dns_servers'
    'name-servers'                      = 'dns_servers'
    # disable_ipv6
    'disableIpv6'                       = 'disable_ipv6'
    'disable-ipv6'                      = 'disable_ipv6'
    'ipv6_disabled'                     = 'disable_ipv6'
    'ipv6Disabled'                      = 'disable_ipv6'
    'ipv6-disabled'                     = 'disable_ipv6'
    'disable_ipv_6'                     = 'disable_ipv6'
    'disableIpv_6'                      = 'disable_ipv6'
    'disable-ipv-6'                     = 'disable_ipv6'

    # ── System & QoL Section (All 19 keys) ──
    # 1. disable_fast_startup
    'disableFastStartup'                = 'disable_fast_startup'
    'disable-fast-startup'              = 'disable_fast_startup'
    'fast_startup'                      = 'disable_fast_startup'
    'fastStartup'                       = 'disable_fast_startup'
    'fast-startup'                      = 'disable_fast_startup'
    # 2. prevent_auto_bitlocker
    'preventAutoBitlocker'              = 'prevent_auto_bitlocker'
    'prevent-auto-bitlocker'            = 'prevent_auto_bitlocker'
    'disable_auto_bitlocker'            = 'prevent_auto_bitlocker'
    'disableAutoBitlocker'              = 'prevent_auto_bitlocker'
    'disable-auto-bitlocker'            = 'prevent_auto_bitlocker'
    'disable_bitlocker'                 = 'prevent_auto_bitlocker'
    'disableBitlocker'                  = 'prevent_auto_bitlocker'
    'disable-bitlocker'                 = 'prevent_auto_bitlocker'
    'auto_bitlocker'                    = 'prevent_auto_bitlocker'
    'autoBitlocker'                     = 'prevent_auto_bitlocker'
    'auto-bitlocker'                    = 'prevent_auto_bitlocker'
    # 3. disable_delivery_optimization
    'disableDeliveryOptimization'       = 'disable_delivery_optimization'
    'disable-delivery-optimization'     = 'disable_delivery_optimization'
    'delivery_optimization'             = 'disable_delivery_optimization'
    'deliveryOptimization'              = 'disable_delivery_optimization'
    'delivery-optimization'             = 'disable_delivery_optimization'
    # 4. disable_storage_sense
    'disableStorageSense'               = 'disable_storage_sense'
    'disable-storage-sense'             = 'disable_storage_sense'
    'storage_sense'                     = 'disable_storage_sense'
    'storageSense'                      = 'disable_storage_sense'
    'storage-sense'                     = 'disable_storage_sense'
    # 5. no_auto_reboot_updates
    'noAutoRebootUpdates'               = 'no_auto_reboot_updates'
    'no-auto-reboot-updates'            = 'no_auto_reboot_updates'
    'disable_auto_reboot'               = 'no_auto_reboot_updates'
    'disableAutoReboot'                 = 'no_auto_reboot_updates'
    'disable-auto-reboot'               = 'no_auto_reboot_updates'
    'disable_auto_reboot_updates'       = 'no_auto_reboot_updates'
    'disableAutoRebootUpdates'          = 'no_auto_reboot_updates'
    'disable-auto-reboot-updates'       = 'no_auto_reboot_updates'
    'no_auto_reboot'                    = 'no_auto_reboot_updates'
    'noAutoReboot'                      = 'no_auto_reboot_updates'
    'no-auto-reboot'                    = 'no_auto_reboot_updates'
    # 6. no_early_updates
    'noEarlyUpdates'                    = 'no_early_updates'
    'no-early-updates'                  = 'no_early_updates'
    'disable_early_updates'             = 'no_early_updates'
    'disableEarlyUpdates'               = 'no_early_updates'
    'disable-early-updates'             = 'no_early_updates'
    'early_updates'                     = 'no_early_updates'
    'earlyUpdates'                      = 'no_early_updates'
    'early-updates'                     = 'no_early_updates'
    # 7. disable_sticky_keys_shortcut
    'disableStickyKeysShortcut'         = 'disable_sticky_keys_shortcut'
    'disable-sticky-keys-shortcut'      = 'disable_sticky_keys_shortcut'
    'disable_sticky_keys'               = 'disable_sticky_keys_shortcut'
    'disableStickyKeys'                 = 'disable_sticky_keys_shortcut'
    'disable-sticky-keys'               = 'disable_sticky_keys_shortcut'
    'sticky_keys_shortcut'              = 'disable_sticky_keys_shortcut'
    'stickyKeysShortcut'                = 'disable_sticky_keys_shortcut'
    'sticky-keys-shortcut'              = 'disable_sticky_keys_shortcut'
    'sticky_keys'                       = 'disable_sticky_keys_shortcut'
    'stickyKeys'                        = 'disable_sticky_keys_shortcut'
    'sticky-keys'                       = 'disable_sticky_keys_shortcut'
    # 8. disable_share_drag_tray
    'disableShareDragTray'              = 'disable_share_drag_tray'
    'disable-share-drag-tray'           = 'disable_share_drag_tray'
    'disable_drag_tray'                 = 'disable_share_drag_tray'
    'disableDragTray'                   = 'disable_share_drag_tray'
    'disable-drag-tray'                 = 'disable_share_drag_tray'
    'share_drag_tray'                   = 'disable_share_drag_tray'
    'shareDragTray'                     = 'disable_share_drag_tray'
    'share-drag-tray'                   = 'disable_share_drag_tray'
    # 9. disable_find_my_device
    'disableFindMyDevice'               = 'disable_find_my_device'
    'disable-find-my-device'            = 'disable_find_my_device'
    'find_my_device'                    = 'disable_find_my_device'
    'findMyDevice'                      = 'disable_find_my_device'
    'find-my-device'                    = 'disable_find_my_device'
    # 10. disable_modern_standby_networking
    'disableModernStandbyNetworking'    = 'disable_modern_standby_networking'
    'disable-modern-standby-networking' = 'disable_modern_standby_networking'
    'disable_modern_standby'            = 'disable_modern_standby_networking'
    'disableModernStandby'              = 'disable_modern_standby_networking'
    'disable-modern-standby'            = 'disable_modern_standby_networking'
    'modern_standby_networking'         = 'disable_modern_standby_networking'
    'modernStandbyNetworking'           = 'disable_modern_standby_networking'
    'modern-standby-networking'         = 'disable_modern_standby_networking'
    # 11. disable_widgets
    'disableWidgets'                    = 'disable_widgets'
    'disable-widgets'                   = 'disable_widgets'
    'widgets'                           = 'disable_widgets'
    # 12. hide_chat_taskbar
    'hideChatTaskbar'                   = 'hide_chat_taskbar'
    'hide-chat-taskbar'                 = 'hide_chat_taskbar'
    'disable_chat_taskbar'              = 'hide_chat_taskbar'
    'disableChatTaskbar'                = 'hide_chat_taskbar'
    'disable-chat-taskbar'              = 'hide_chat_taskbar'
    'disable_chat'                      = 'hide_chat_taskbar'
    'disableChat'                       = 'hide_chat_taskbar'
    'disable-chat'                      = 'hide_chat_taskbar'
    'hide_chat'                         = 'hide_chat_taskbar'
    'hideChat'                          = 'hide_chat_taskbar'
    'hide-chat'                         = 'hide_chat_taskbar'
    'chat_taskbar'                      = 'hide_chat_taskbar'
    'chatTaskbar'                       = 'hide_chat_taskbar'
    'chat-taskbar'                      = 'hide_chat_taskbar'
    # 13. disable_transparency
    'disableTransparency'               = 'disable_transparency'
    'disable-transparency'              = 'disable_transparency'
    'transparency'                      = 'disable_transparency'
    # 14. disable_snap_assist
    'disableSnapAssist'                 = 'disable_snap_assist'
    'disable-snap-assist'               = 'disable_snap_assist'
    'snap_assist'                       = 'disable_snap_assist'
    'snapAssist'                        = 'disable_snap_assist'
    'snap-assist'                       = 'disable_snap_assist'
    # 15. hide_start_all_apps
    'hideStartAllApps'                  = 'hide_start_all_apps'
    'hide-start-all-apps'               = 'hide_start_all_apps'
    'disable_start_all_apps'            = 'hide_start_all_apps'
    'disableStartAllApps'               = 'hide_start_all_apps'
    'disable-start-all-apps'            = 'hide_start_all_apps'
    'start_all_apps'                    = 'hide_start_all_apps'
    'startAllApps'                      = 'hide_start_all_apps'
    'start-all-apps'                    = 'hide_start_all_apps'
    # 16. disable_suggestions
    'disableSuggestions'                = 'disable_suggestions'
    'disable-suggestions'               = 'disable_suggestions'
    'suggestions'                       = 'disable_suggestions'
    'disable_ads'                       = 'disable_suggestions'
    'disableAds'                        = 'disable_suggestions'
    'disable-ads'                       = 'disable_suggestions'
    'disable_windows_suggestions'       = 'disable_suggestions'
    'disableWindowsSuggestions'         = 'disable_suggestions'
    'disable-windows-suggestions'       = 'disable_suggestions'
    # 17. hide_settings_home
    'hideSettingsHome'                  = 'hide_settings_home'
    'hide-settings-home'                = 'hide_settings_home'
    'disable_settings_home'             = 'hide_settings_home'
    'disableSettingsHome'               = 'hide_settings_home'
    'disable-settings-home'             = 'hide_settings_home'
    'settings_home'                     = 'hide_settings_home'
    'settingsHome'                      = 'hide_settings_home'
    'settings-home'                     = 'hide_settings_home'
    # 18. hide_phone_link_start
    'hidePhoneLinkStart'                = 'hide_phone_link_start'
    'hide-phone-link-start'             = 'hide_phone_link_start'
    'disable_phone_link_start'          = 'hide_phone_link_start'
    'disablePhoneLinkStart'             = 'hide_phone_link_start'
    'disable-phone-link-start'          = 'hide_phone_link_start'
    'hide_phone_link'                   = 'hide_phone_link_start'
    'hidePhoneLink'                     = 'hide_phone_link_start'
    'hide-phone-link'                   = 'hide_phone_link_start'
    'phone_link_start'                  = 'hide_phone_link_start'
    'phoneLinkStart'                    = 'hide_phone_link_start'
    'phone-link-start'                  = 'hide_phone_link_start'
    # 19. debloat_search
    'debloatSearch'                     = 'debloat_search'
    'debloat-search'                    = 'debloat_search'
    'disable_bing_search'               = 'debloat_search'
    'disableBingSearch'                 = 'debloat_search'
    'disable-bing-search'               = 'debloat_search'
    'disable_search_highlights'         = 'debloat_search'
    'disableSearchHighlights'           = 'debloat_search'
    'disable-search-highlights'         = 'debloat_search'
    'search_debloat'                    = 'debloat_search'
    'searchDebloat'                     = 'debloat_search'
    'search-debloat'                    = 'debloat_search'

    # ── Software Section ──
    # package_manager
    'packageManager'                    = 'package_manager'
    'package-manager'                   = 'package_manager'
    'pkg_manager'                       = 'package_manager'
    'pkgManager'                        = 'package_manager'
    'pkg-manager'                       = 'package_manager'
    'manager'                           = 'package_manager'
    # install_list
    'installList'                       = 'install_list'
    'install-list'                      = 'install_list'
    'install_apps'                      = 'install_list'
    'installApps'                       = 'install_list'
    'install-apps'                      = 'install_list'
    'install'                           = 'install_list'
    'packages'                          = 'install_list'
    # uninstall_list
    'uninstallList'                     = 'uninstall_list'
    'uninstall-list'                    = 'uninstall_list'
    'uninstall_apps'                    = 'uninstall_list'
    'uninstallApps'                     = 'uninstall_list'
    'uninstall-apps'                    = 'uninstall_list'
    'uninstall'                         = 'uninstall_list'
    'remove_list'                       = 'uninstall_list'
    'removeList'                        = 'uninstall_list'
    'remove-list'                       = 'uninstall_list'
    'remove_apps'                       = 'uninstall_list'
    'removeApps'                        = 'uninstall_list'
    'remove-apps'                       = 'uninstall_list'

    # ── Metadata Section ──
    'Name'                              = 'name'
    'profile_name'                      = 'name'
    'profileName'                       = 'name'
    'profile-name'                      = 'name'
    'Version'                           = 'version'
    'profile_version'                   = 'version'
    'profileVersion'                    = 'version'
    'profile-version'                   = 'version'
    'Author'                            = 'author'
    'created_by'                        = 'author'
    'createdBy'                         = 'author'
    'created-by'                        = 'author'
    'Description'                       = 'description'
    'desc'                              = 'description'
    'targetOs'                          = 'target_os'
    'target-os'                         = 'target_os'
    'target_operating_system'           = 'target_os'
    'targetOperatingSystem'             = 'target_os'
    'target-operating-system'           = 'target_os'
    'os'                                = 'target_os'
    'minBuild'                          = 'min_build'
    'min-build'                         = 'min_build'
    'minimum_build'                     = 'min_build'
    'minimumBuild'                      = 'min_build'
    'minimum-build'                     = 'min_build'
    'min_version'                       = 'min_build'
    'minVersion'                        = 'min_build'
    'min-version'                       = 'min_build'
}

# Alias for backward-compatibility
$Script:typoMap = $Script:FieldTypoMap

<#
.SYNOPSIS
    Imports and validates a Win-Debloat configuration profile.
    
.DESCRIPTION
    Loads a YAML configuration file, validates against the schema,
    normalizes types/lists/booleans, corrects typos, and returns
    a structured configuration object.
    
.PARAMETER Path
    Full path to the YAML profile file.
    
.PARAMETER SkipDependencyCheck
    If specified, skips the dependency check for powershell-yaml.
    
.OUTPUTS
    [psobject] The validated configuration object.
    
.EXAMPLE
    $config = Import-WinDebloatConfig -Path "profiles/moderate.yaml"
#>
function Import-WinDebloatConfig {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,
        
        [switch]$SkipDependencyCheck
    )
    
    Write-Log -Message "Loading profile: $Path" -Level Info
    
    # Check for vendored powershell-yaml module
    $vendorPath = "$PSScriptRoot\..\modules\Vendor\powershell-yaml"
    if (Test-Path $vendorPath) {
        # Try to find the .psd1 file recursively in the vendor directory (handling version subfolders)
        $moduleManifest = Get-ChildItem -Path $vendorPath -Filter "powershell-yaml.psd1" -Recurse | Select-Object -First 1
        
        if ($moduleManifest) {
            Write-Log -Message "Loading vendored 'powershell-yaml' from $($moduleManifest.FullName)" -Level Debug
            Import-Module $moduleManifest.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    # Check for powershell-yaml module with user consent (SEC-001 fix)
    if (-not $SkipDependencyCheck) {
        if (-not (Get-Module -Name "powershell-yaml" -ErrorAction SilentlyContinue) -and -not (Get-Module -ListAvailable -Name "powershell-yaml")) {
            Write-Log -Message "Module 'powershell-yaml' not found." -Level Warning
            
            # Prompt for user consent - security best practice
            $response = Read-Host "Install 'powershell-yaml' from PowerShell Gallery? [Y/N]"
            
            if ($response -match '^[Yy]') {
                try {
                    Write-Log -Message "Installing 'powershell-yaml' via PSResourceGet..." -Level Info
                    # PS 7.5+ prefers Install-PSResource over Install-Module
                    Install-PSResource -Name "powershell-yaml" -Scope CurrentUser -TrustRepository -ErrorAction Stop
                    Import-Module "powershell-yaml" -ErrorAction Stop
                    Write-Log -Message "Successfully installed 'powershell-yaml'." -Level Success
                }
                catch {
                    Write-Log -Message "Failed to install 'powershell-yaml'. Error: $($_.Exception.Message)" -Level Error
                    throw "Dependency 'powershell-yaml' is missing and installation failed."
                }
            }
            else {
                throw "Dependency 'powershell-yaml' is required. Please install it manually: Install-PSResource powershell-yaml"
            }
        }
        elseif (-not (Get-Module -Name "powershell-yaml" -ErrorAction SilentlyContinue)) {
            Import-Module "powershell-yaml" -ErrorAction Stop
        }
    }
    
    try {
        $Content = Get-Content $Path -Raw -ErrorAction Stop
        $Config = $Content | ConvertFrom-Yaml -ErrorAction Stop
        
        # 1. Section Normalization & Typo Remapping
        if ($Config -is [System.Collections.IDictionary]) {
            foreach ($secKey in @($Config.Keys)) {
                if ($secKey -notin $Script:ProfileSchema.ValidSections) {
                    if ($Script:SectionTypoMap.ContainsKey($secKey)) {
                        $canonicalSec = $Script:SectionTypoMap[$secKey]
                        Write-Log -Message "Config section typo: '$secKey' normalized to '$canonicalSec'" -Level Warning
                        if (-not $Config.Contains($canonicalSec) -or $null -eq $Config[$canonicalSec]) {
                            $Config[$canonicalSec] = $Config[$secKey]
                        }
                    }
                    else {
                        Write-Log -Message "Unknown section '$secKey' in profile (Valid sections: $($Script:ProfileSchema.ValidSections -join ', '))" -Level Warning
                    }
                }
            }
        }

        # 2. Key Typo Normalization (remap typo keys to canonical snake_case)
        if ($Config -is [System.Collections.IDictionary]) {
            foreach ($sectionName in @($Config.Keys)) {
                $section = $Config[$sectionName]
                if ($section -is [System.Collections.IDictionary]) {
                    foreach ($key in @($section.Keys)) {
                        if ($Script:FieldTypoMap.ContainsKey($key)) {
                            $canonicalKey = $Script:FieldTypoMap[$key]
                            if ($key -cne $canonicalKey) {
                                Write-Log -Message "Config typo: '$key' should be '$canonicalKey' in [$sectionName]" -Level Warning
                                if (-not $section.Contains($canonicalKey) -or $null -eq $section[$canonicalKey]) {
                                    $section[$canonicalKey] = $section[$key]
                                }
                            }
                        }
                    }
                }
            }
        }

        # 3. Boolean Normalization (converts string booleans "true"/"false"/"yes"/"no"/"1"/"0" to real [bool])
        foreach ($item in $Script:ConfigBooleanFields) {
            $sec = $item.Section
            $fld = $item.Field
            if ($Config.$sec -and $null -ne $Config.$sec.$fld) {
                $rawVal = $Config.$sec.$fld
                if ($rawVal -is [string]) {
                    if ($rawVal -match '^(true|1|yes|on|enabled)$') {
                        $Config.$sec.$fld = $true
                    }
                    elseif ($rawVal -match '^(false|0|no|off|disabled|none)$') {
                        $Config.$sec.$fld = $false
                    }
                }
                elseif ($rawVal -isnot [bool]) {
                    $Config.$sec.$fld = [bool]$rawVal
                }
            }
        }
        
        # 4. Normalize Lists (Force Array) to prevent iteration errors
        foreach ($item in $Script:ConfigListFields) {
            $sec = $item.Section
            $fld = $item.Field
            
            if ($Config.$sec -and $null -ne $Config.$sec.$fld) {
                if ($Config.$sec.$fld -isnot [Array]) {
                    # Convert single string/item to single-item array
                    $Config.$sec.$fld = @($Config.$sec.$fld)
                }
            }
        }

        # 5. Schema Validation & Enum Normalization (SEC-004 fix)
        $validationErrors = [System.Collections.Generic.List[string]]::new()
        
        # 5a. Check required sections and metadata
        if (-not $Config.metadata) {
            $validationErrors.Add("Missing required 'metadata' section")
        }
        else {
            foreach ($field in $Script:ProfileSchema.MetadataRequired) {
                if (-not $Config.metadata.$field) {
                    $validationErrors.Add("Missing required metadata field: '$field'")
                }
            }
        }
        
        # 5b. Validate & normalize telemetry level if specified
        if ($Config.privacy -and $Config.privacy.telemetry_level) {
            $matchedLevel = $Script:ProfileSchema.ValidTelemetryLevels | Where-Object { $_ -ieq $Config.privacy.telemetry_level }
            if (-not $matchedLevel) {
                $validationErrors.Add("Invalid telemetry_level: '$($Config.privacy.telemetry_level)'. Valid: $($Script:ProfileSchema.ValidTelemetryLevels -join ', ')")
            }
            else {
                $Config.privacy.telemetry_level = $matchedLevel
            }
        }
        
        # 5c. Validate & normalize power plan if specified
        if ($Config.performance -and $Config.performance.power_plan) {
            $matchedPlan = $Script:ProfileSchema.ValidPowerPlans | Where-Object { $_ -ieq $Config.performance.power_plan }
            if (-not $matchedPlan) {
                $validationErrors.Add("Invalid power_plan: '$($Config.performance.power_plan)'. Valid: $($Script:ProfileSchema.ValidPowerPlans -join ', ')")
            }
            else {
                $Config.performance.power_plan = $matchedPlan
            }
        }

        # 5d. Validate & normalize visual effects if specified
        if ($Config.performance -and $Config.performance.visual_effects) {
            $matchedFx = $Script:ProfileSchema.ValidVisualEffects | Where-Object { $_ -ieq $Config.performance.visual_effects }
            if (-not $matchedFx) {
                $validationErrors.Add("Invalid visual_effects: '$($Config.performance.visual_effects)'. Valid: $($Script:ProfileSchema.ValidVisualEffects -join ', ')")
            }
            else {
                $Config.performance.visual_effects = $matchedFx
            }
        }
        
        # 5e. Validate & normalize removal mode if specified
        if ($Config.bloatware -and $Config.bloatware.removal_mode) {
            $matchedMode = $Script:ProfileSchema.ValidRemovalModes | Where-Object { $_ -ieq $Config.bloatware.removal_mode }
            if (-not $matchedMode) {
                $validationErrors.Add("Invalid removal_mode: '$($Config.bloatware.removal_mode)'. Valid: $($Script:ProfileSchema.ValidRemovalModes -join ', ')")
            }
            else {
                $Config.bloatware.removal_mode = $matchedMode
            }
            
            # GOLD STANDARD: Enforce custom_list requirement
            if ($Config.bloatware.removal_mode -eq 'Custom' -and (-not $Config.bloatware.custom_list -or @($Config.bloatware.custom_list).Count -eq 0)) {
                $validationErrors.Add("Removal mode is 'Custom' but 'custom_list' is missing or empty.")
            }
        }

        # 5f. Validate & normalize package manager if specified
        if ($Config.software -and $Config.software.package_manager) {
            $matchedPkgMgr = $Script:ProfileSchema.ValidPackageManagers | Where-Object { $_ -ieq $Config.software.package_manager }
            if (-not $matchedPkgMgr) {
                $validationErrors.Add("Invalid package_manager: '$($Config.software.package_manager)'. Valid: $($Script:ProfileSchema.ValidPackageManagers -join ', ')")
            }
            else {
                $Config.software.package_manager = $matchedPkgMgr
            }
        }

        # 5g. Validate target_os if specified
        if ($Config.metadata -and $Config.metadata.target_os) {
            foreach ($os in @($Config.metadata.target_os)) {
                if ($os -notin $Script:ProfileSchema.ValidTargetOS) {
                    Write-Log -Message "Notice: target_os '$os' is not in standard list ($($Script:ProfileSchema.ValidTargetOS -join ', '))" -Level Warning
                }
            }
        }
        
        # Report validation errors
        if ($validationErrors.Count -gt 0) {
            foreach ($err in $validationErrors) {
                Write-Log -Message "Validation Error: $err" -Level Error
            }
            throw "Profile validation failed with $($validationErrors.Count) error(s)"
        }
        
        Write-Log -Message "Profile loaded: $($Config.metadata.name) v$($Config.metadata.version)" -Level Success
        return $Config
        
    }
    catch {
        Write-Log -Message "Failed to load profile: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Validates a configuration against the schema.
    
.PARAMETER Config
    The configuration object to validate.
    
.OUTPUTS
    [bool] True if valid, false otherwise.
#>
function Test-WinDebloatConfig {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Config
    )
    
    try {
        if (-not $Config.metadata) { return $false }
        if (-not $Config.metadata.name) { return $false }
        if (-not $Config.metadata.version) { return $false }

        # Validate enums if present
        if ($Config.privacy -and $Config.privacy.telemetry_level) {
            if ($Config.privacy.telemetry_level -notin $Script:ProfileSchema.ValidTelemetryLevels) { return $false }
        }
        if ($Config.performance -and $Config.performance.power_plan) {
            if ($Config.performance.power_plan -notin $Script:ProfileSchema.ValidPowerPlans) { return $false }
        }
        if ($Config.performance -and $Config.performance.visual_effects) {
            if ($Config.performance.visual_effects -notin $Script:ProfileSchema.ValidVisualEffects) { return $false }
        }
        if ($Config.bloatware -and $Config.bloatware.removal_mode) {
            if ($Config.bloatware.removal_mode -notin $Script:ProfileSchema.ValidRemovalModes) { return $false }
        }
        if ($Config.software -and $Config.software.package_manager) {
            if ($Config.software.package_manager -notin $Script:ProfileSchema.ValidPackageManagers) { return $false }
        }

        return $true
    }
    catch {
        return $false
    }
}


<#
.SYNOPSIS
    Analyzes hardware to recommend an optimization profile.
    
.DESCRIPTION
    Checks RAM and GPU to suggest 'Gaming', 'Performance', or 'Moderate'.
    
.OUTPUTS
    [string] The recommended profile name.
#>
function Get-WinDebloatRecommendedProfile {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        # Check RAM (GB)
        $ramObj = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $totalRamGB = if ($ramObj) { [math]::Round($ramObj.TotalPhysicalMemory / 1GB) } else { 8 }
        
        # Check GPU
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue 
        $hasHighEndGpu = $false
        if ($gpus) {
            foreach ($gpu in $gpus) {
                if ($gpu.Name -match 'NVIDIA|AMD|Radeon|GeForce|RTX|GTX') {
                    $hasHighEndGpu = $true
                    break
                }
            }
        }
        
        # Logic
        if ($totalRamGB -lt 8) {
            return "Performance"
        }
        elseif ($totalRamGB -ge 16 -and $hasHighEndGpu) {
            return "Gaming"
        }
        else {
            return "Moderate"
        }
    }
    catch {
        Write-Log -Message "Failed to detect hardware for recommendation: $($_.Exception.Message)" -Level Warning
        return "Moderate" # Fallback
    }
}

<#
.SYNOPSIS
    Builds a read-only "what would this profile do" action plan (v1.4 preview).

.DESCRIPTION
    Derives every action a profile would take purely from its configuration -
    nothing on the system is touched or even queried for state. Each row is a
    [pscustomobject] with Section and Action, ready for the TUI/GUI to render
    before the user commits to applying.

.PARAMETER Config
    The configuration object loaded from a YAML profile.

.OUTPUTS
    [pscustomobject[]] Planned actions grouped by section.

.EXAMPLE
    Get-WinDebloatProfilePlan -Config $config | Format-Table -GroupBy Section
#>
function Get-WinDebloatProfilePlan {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Config
    )

    $plan = [System.Collections.Generic.List[pscustomobject]]::new()
    $add = { param($Section, $Action) $plan.Add([pscustomobject]@{ Section = $Section; Action = $Action }) }

    # ── Bloatware ───────────────────────────────────────────────────────
    if ($Config.bloatware -and $Config.bloatware.removal_mode -and $Config.bloatware.removal_mode -ne 'None') {
        $mode = $Config.bloatware.removal_mode
        $apps = if ($Config.bloatware.custom_list -and $Config.bloatware.custom_list.Count -gt 0) {
            $Config.bloatware.custom_list
        }
        else {
            # Resolve the built-in tier list if the Bloatware module is loaded
            $listCmd = (Get-Command Get-WinDebloatBloatwareList -ErrorAction SilentlyContinue) ?? (Get-Command Get-WinDebloat7BloatwareList -ErrorAction SilentlyContinue)
            if ($listCmd) { & $listCmd -Mode $(if ($mode -in 'Conservative', 'Moderate', 'Aggressive') { $mode } else { 'Moderate' }) } else { $null }
        }
        $excluded = @($Config.bloatware.exclude_list).Count
        $desc = if ($apps) { "Remove $(@($apps).Count) bloatware app(s) [$mode]" } else { "Remove bloatware [$mode]" }
        if ($excluded) { $desc += " - $excluded app(s) preserved via exclude_list" }
        & $add 'Bloatware' $desc
    }

    # ── Privacy ─────────────────────────────────────────────────────────
    if ($Config.privacy) {
        $p = $Config.privacy
        if ($p.telemetry_level) { & $add 'Privacy' "Restrict telemetry to '$($p.telemetry_level)' level" }
        if ($p.disable_advertising_id) { & $add 'Privacy' 'Disable advertising ID & tailored experiences' }
        if ($p.disable_activity_history) { & $add 'Privacy' 'Disable activity history publishing/upload' }
        if ($p.disable_location_tracking) { & $add 'Privacy' 'Disable location tracking' }
        if ($p.disable_copilot) { & $add 'Privacy' 'Disable Windows Copilot' }
        if ($p.disable_recall) { & $add 'Privacy' 'Disable Windows Recall snapshots' }
    }

    # ── Performance ─────────────────────────────────────────────────────
    if ($Config.performance) {
        $perf = $Config.performance
        if ($perf.power_plan) { & $add 'Performance' "Set power plan to '$($perf.power_plan)'" }
        if ($perf.visual_effects) { & $add 'Performance' "Set visual effects to '$($perf.visual_effects)'" }
        if ($perf.disable_game_bar) { & $add 'Performance' 'Disable Xbox Game Bar' }
        if ($perf.disable_background_apps) { & $add 'Performance' 'Restrict background apps' }
    }

    # ── Network ─────────────────────────────────────────────────────────
    if ($Config.network) {
        if ($Config.network.dns_servers) { & $add 'Network' "Set DNS servers to $($Config.network.dns_servers -join ', ')" }
        if ($Config.network.disable_ipv6) { & $add 'Network' 'Disable IPv6 bindings' }
    }

    # ── System & QoL (v1.4) ─────────────────────────────────────────────
    if ($Config.system) {
        $sysMap = [ordered]@{
            disable_fast_startup              = 'Disable Fast Startup (clean full shutdowns)'
            prevent_auto_bitlocker            = 'Prevent automatic BitLocker device encryption'
            disable_delivery_optimization     = 'Disable Delivery Optimization (P2P updates)'
            disable_storage_sense             = 'Disable Storage Sense'
            no_auto_reboot_updates            = 'Prevent auto-reboot after updates while signed in'
            no_early_updates                  = "Turn off 'get latest updates as soon as available'"
            disable_sticky_keys_shortcut      = 'Disable Sticky Keys shortcut (5x Shift)'
            disable_share_drag_tray           = 'Disable drag-to-share tray'
            disable_find_my_device            = 'Disable Find My Device'
            disable_modern_standby_networking = 'Disable Modern Standby networking'
            disable_widgets                   = 'Disable taskbar Widgets'
            hide_chat_taskbar                 = 'Hide Chat / Meet Now taskbar icon'
            disable_transparency              = 'Disable transparency effects'
            disable_snap_assist               = 'Disable Snap Assist suggestions'
            hide_start_all_apps               = "Hide Start menu 'All Apps' list"
            disable_suggestions               = 'Disable ALL Windows suggestions & ads'
            hide_settings_home                = "Hide the Settings 'Home' page"
            hide_phone_link_start             = 'Hide Phone Link panel in Start'
            debloat_search                    = 'Debloat Search (Bing results, highlights, history)'
        }
        foreach ($key in $sysMap.Keys) {
            if ($Config.system.$key) { & $add 'System QoL' $sysMap[$key] }
        }
    }

    # ── Software ────────────────────────────────────────────────────────
    if ($Config.software) {
        $sw = $Config.software
        if ($sw.install_list -and @($sw.install_list).Count -gt 0) {
            & $add 'Software' "Install $(@($sw.install_list).Count) app(s): $($sw.install_list -join ', ')"
        }
        if ($sw.uninstall_list -and @($sw.uninstall_list).Count -gt 0) {
            & $add 'Software' "Uninstall $(@($sw.uninstall_list).Count) app(s): $($sw.uninstall_list -join ', ')"
        }
    }

    # A safety snapshot always precedes changes
    & $add 'Safety' 'Create encrypted registry snapshot before any change (restorable from Snapshots menu)'

    return $plan.ToArray()
}

Set-Alias -Name 'Import-WinDebloat7Config' -Value 'Import-WinDebloatConfig'
Set-Alias -Name 'Test-WinDebloat7Config' -Value 'Test-WinDebloatConfig'
Set-Alias -Name 'Get-WinDebloat7RecommendedProfile' -Value 'Get-WinDebloatRecommendedProfile'
Set-Alias -Name 'Get-WinDebloat7ProfilePlan' -Value 'Get-WinDebloatProfilePlan'

Export-ModuleMember -Function @('Import-WinDebloatConfig', 'Test-WinDebloatConfig', 'Get-WinDebloatRecommendedProfile', 'Get-WinDebloatProfilePlan') `
                    -Alias @('Import-WinDebloat7Config', 'Test-WinDebloat7Config', 'Get-WinDebloat7RecommendedProfile', 'Get-WinDebloat7ProfilePlan') `
                    -Variable @('ProfileSchema', 'SectionTypoMap', 'FieldTypoMap', 'typoMap')