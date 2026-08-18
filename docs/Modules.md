# Modules Reference

Win-Debloat is built on a modular architecture. Each feature is encapsulated in a standalone PowerShell Module (`.psm1`) located in `src/modules`, `src/core`, or `src/ui`. The standard manifest registers **30 modules** exporting **138 functions**, all engineered with zero-data-loss hardening, full reversibility, and backward-compatible `*-WinDebloat7*` aliases.

---

## 🧩 Feature Modules (`src/modules`)

### **Bloatware** (`src/modules/Bloatware/Bloatware.psm1`)
Identifies and removes pre-installed Appx packages.
- **Exported Functions & Aliases:** `Get-WinDebloatBloatwareList` / `Get-WinDebloat7BloatwareList`, `Remove-WinDebloatBloatware` / `Remove-WinDebloat7Bloatware`, `Uninstall-WinDebloatOneDrive` / `Uninstall-WinDebloat7OneDrive`, `Uninstall-WinDebloatEdge` / `Uninstall-WinDebloat7Edge`, `Uninstall-WinDebloatXbox` / `Uninstall-WinDebloat7Xbox`
- **Logic:** O(N) regex matching against a tiered database of 139 bloatware apps (Conservative, Moderate, Aggressive tiers).
- **Safety:** DPAPI snapshot rollback and profile exclusion support.

### **Privacy & Telemetry** (`src/modules/Privacy/Privacy.psm1`, `Tasks.psm1`, `Firewall.psm1`)
Comprehensive privacy hardening via Registry, Group Policy, Scheduled Tasks, and Windows Firewall.
- **Privacy Core:** `Set-WinDebloatPrivacy` / `Set-WinDebloat7Privacy`, `Enable-WinDebloatPrivacy` / `Enable-WinDebloat7Privacy`, `Disable-WinDebloatAI` / `Disable-WinDebloat7AIandAds`
- **Telemetry Tasks:** `Get-WinDebloatTelemetryTasks` / `Get-WinDebloat7TelemetryTasks`, `Disable-WinDebloatTelemetryTasks` / `Disable-WinDebloat7TelemetryTasks`, `Enable-WinDebloatTelemetryTasks` / `Enable-WinDebloat7TelemetryTasks`
- **Firewall Rules:** `Add-WinDebloatFirewallBlock` / `Add-WinDebloat7FirewallBlock`, `Remove-WinDebloatFirewallBlock` / `Remove-WinDebloat7FirewallBlock`, `Get-WinDebloatFirewallStatus` / `Get-WinDebloat7FirewallStatus`, `Get-WinDebloatTelemetryDomains` / `Get-WinDebloat7TelemetryDomains`
- **Features:** Neutralizes DiagTrack, Connected User Experiences, WaaSMedicSvc, and blocks 45 telemetry domains via Windows Firewall.

### **Performance & Gaming** (`src/modules/Performance/Performance.psm1`, `Gaming.psm1`, `Benchmark.psm1`)
System responsiveness tuning, power management, and hardware benchmarking.
- **Exported Functions & Aliases:** `Set-WinDebloatPerformance` / `Optimize-WinDebloatPerformance` / `Set-WinDebloat7Performance`, `Set-WinDebloatGaming` / `Set-WinDebloat7Gaming`, `Measure-WinDebloatSystem` / `Measure-WinDebloat7System`, `Compare-WinDebloatBenchmarks` / `Compare-WinDebloat7Benchmarks`
- **Features:** Ultimate Performance power plan activation, Nagle's algorithm disablement, Game DVR removal, GPU priority elevation, and system metrics benchmarking.

### **Services** (`src/modules/Performance/Services.psm1`)
JSON-driven Windows service optimization with intelligent presets.
- **Exported Functions & Aliases:** `Set-WinDebloatServices` / `Set-WinDebloat7Services`, `Get-WinDebloatServicePresets` / `Get-WinDebloat7ServicePresets`, `Get-WinDebloatServiceStatus` / `Get-WinDebloat7ServiceStatus`
- **Presets:** Privacy, Performance, Security, Minimal, Gaming (`config/services.json`).

### **Tweaks (AI & Ads)** (`src/modules/Performance/Tweaks.psm1`)
AI disablement and Windows 11 Copilot+ neutralization.
- **AI Disablement:** `Disable-WinDebloatAIRecall` / `Disable-WinDebloat7AIRecall`, `Disable-WinDebloatCopilot` / `Disable-WinDebloat7Copilot`, `Disable-WinDebloatClickToDo` / `Disable-WinDebloat7ClickToDo`, `Disable-WinDebloatNotepadAI` / `Disable-WinDebloat7NotepadAI`, `Disable-WinDebloatPaintAI` / `Disable-WinDebloat7PaintAI`, `Disable-WinDebloatEdgeAI` / `Disable-WinDebloat7EdgeAI`
- **Ad Neutralization:** `Disable-WinDebloatDesktopSpotlight` / `Disable-WinDebloat7DesktopSpotlight`, `Disable-WinDebloatSettings365Ads` / `Disable-WinDebloat7Settings365Ads`
- **Power & Sysprep Helpers:** `Enable-WinDebloatUltimatePower` / `Enable-WinDebloat7UltimatePower`, `Disable-WinDebloatUltimatePower` / `Disable-WinDebloat7UltimatePower`, `Invoke-WinDebloatSysprepDefaults` / `Invoke-WinDebloat7SysprepDefaults`, `Set-WinDebloatRegistryValue` / `Set-WinDebloat7RegistryValue`

### **System QoL Tweaks** (`src/modules/Tweaks/System.psm1`)
System-level Quality of Life tweaks with true per-tweak undo counterparts (removes policy overrides on revert).
- **Master Orchestrator:** `Set-WinDebloatSystemTweaks` / `Set-WinDebloat7SystemTweaks`
- **16 Reversible Tweak Pairs:**
  - `Disable-WinDebloatFastStartup` / `Enable-WinDebloatFastStartup` (`*7` aliases supported)
  - `Disable-WinDebloatModernStandbyNetworking` / `Enable-WinDebloatModernStandbyNetworking`
  - `Disable-WinDebloatAutoBitLocker` / `Enable-WinDebloatAutoBitLocker`
  - `Disable-WinDebloatDeliveryOptimization` / `Enable-WinDebloatDeliveryOptimization`
  - `Disable-WinDebloatStorageSense` / `Enable-WinDebloatStorageSense`
  - `Disable-WinDebloatWindowsSuggestions` / `Enable-WinDebloatWindowsSuggestions`
  - `Disable-WinDebloatSettingsHome` / `Enable-WinDebloatSettingsHome`
  - `Disable-WinDebloatShareDragTray` / `Enable-WinDebloatShareDragTray`
  - `Disable-WinDebloatPhoneLinkStart` / `Enable-WinDebloatPhoneLinkStart`
  - `Disable-WinDebloatStickyKeysShortcut` / `Enable-WinDebloatStickyKeysShortcut`
  - `Disable-WinDebloatFindMyDevice` / `Enable-WinDebloatFindMyDevice`
  - `Disable-WinDebloatTransparency` / `Enable-WinDebloatTransparency`
  - `Disable-WinDebloatSnapAssist` / `Enable-WinDebloatSnapAssist`
  - `Disable-WinDebloatWidgets` / `Enable-WinDebloatWidgets`
  - `Disable-WinDebloatChatTaskbar` / `Enable-WinDebloatChatTaskbar`
  - `Disable-WinDebloatStartAllApps` / `Enable-WinDebloatStartAllApps`
- **Update Behavior:** `Set-WinDebloatUpdateBehavior` / `Set-WinDebloat7UpdateBehavior`

### **UI Customization** (`src/modules/Tweaks/UI.psm1`)
Taskbar, context menu, and File Explorer customization.
- **Exported Functions & Aliases:** `Set-WinDebloatTaskbarAlignment` / `Set-WinDebloat7TaskbarAlignment`, `Set-WinDebloatContextMenu` / `Set-WinDebloat7ContextMenu`, `Set-WinDebloatExplorer` / `Set-WinDebloat7Explorer`, `Set-WinDebloatStartMenu` / `Set-WinDebloat7StartMenu`, `Set-WinDebloatSearch` / `Set-WinDebloat7Search`, `Set-WinDebloatTaskbarTweaks` / `Set-WinDebloat7TaskbarTweaks`, `Set-WinDebloatContextMenuItems` / `Set-WinDebloat7ContextMenuItems`, `Restart-WinDebloatExplorer` / `Restart-WinDebloat7Explorer`

### **Network & DNS** (`src/modules/Network/Network.psm1`)
DNS provider configuration, network diagnostics, and IPv6 toggling.
- **Exported Functions & Aliases:** `Set-WinDebloatDNS` / `Set-WinDebloat7DNS`, `Get-WinDebloatDNSProviders` / `Get-WinDebloat7DNSProviders`, `Disable-WinDebloatIPv6` / `Disable-WinDebloat7IPv6`, `Enable-WinDebloatIPv6` / `Enable-WinDebloat7IPv6`, `Get-WinDebloatNetworkStatus` / `Get-WinDebloat7NetworkStatus`, `Set-WinDebloatNetwork` / `Set-WinDebloat7Network`
- **DNS Database:** 11 DNS providers stored in `config/dns.json` (Cloudflare, Google, Quad9, AdGuard, NextDNS, OpenDNS, CleanBrowsing).

### **Software Installer** (`src/modules/Software/Software.psm1`)
Multi-provider application manager supporting winget, Chocolatey, Microsoft Store, and npm.
- **Exported Functions & Aliases:** `Test-PackageManager`, `Install-PackageManager`, `Get-WinDebloatEssentialsList` / `Get-WinDebloat7EssentialsList`, `Install-WinDebloatSoftware` / `Install-WinDebloat7Software`, `Update-WinDebloatSoftware` / `Update-WinDebloat7Software`, `Install-WinDebloatEssentials` / `Install-WinDebloat7Essentials`, `Install-WinDebloatProfileSoftware` / `Install-WinDebloat7ProfileSoftware`
- **Catalog:** 175 curated applications and AI CLIs across 12 categories.

### **Drivers** (`src/modules/Drivers/Drivers.psm1`)
Hardware and graphics driver inspection and update manager.
- **Exported Functions & Aliases:** `Get-WinDebloatDriverStatus` / `Get-WinDebloat7DriverStatus`, `Get-WinDebloatGPUInfo` / `Get-WinDebloat7GPUInfo`, `Update-WinDebloatDrivers` / `Update-WinDebloat7Drivers`

### **System Repair** (`src/modules/Repair/Repair.psm1`)
Industrial 4-step repair sequence and component resets.
- **Exported Functions & Aliases:** `Repair-WinDebloatSystem` / `Repair-WinDebloat7System`, `Reset-WinDebloatNetwork` / `Reset-WinDebloat7Network`, `Reset-WinDebloatUpdate` / `Reset-WinDebloat7Update`
- **Repair Sequence:** ChkDsk → SFC (first pass) → DISM RestoreHealth → SFC (second pass).

### **Security** (`src/modules/Security/Security.psm1`)
Attack surface reduction and malware protection hardening.
- **Exported Functions & Aliases:** `Disable-WinDebloatSMBv1` / `Disable-WinDebloat7SMBv1`, `Enable-WinDebloatSMBv1` / `Enable-WinDebloat7SMBv1`, `Enable-WinDebloatPUAProtection` / `Enable-WinDebloat7PUAProtection`, `Disable-WinDebloatPUAProtection` / `Disable-WinDebloat7PUAProtection`, `Get-WinDebloatSecurityStatus` / `Get-WinDebloat7SecurityStatus`

### **Windows Features** (`src/modules/Features/Features.psm1`)
Optional Windows features and capabilities management.
- **Exported Functions & Aliases:** `Set-WinDebloatOptionalFeatures` / `Set-WinDebloat7OptionalFeatures`, `Remove-WinDebloatCapabilities` / `Remove-WinDebloat7Capabilities`

### **Maintenance** (`src/modules/Maintenance/Maintenance.psm1`)
Scheduled cleanup and component store compression.
- **Exported Functions & Aliases:** `Register-WinDebloatMaintenance` / `Register-WinDebloat7Maintenance`, `Unregister-WinDebloatMaintenance` / `Unregister-WinDebloat7Maintenance`, `Invoke-WinDebloatMaintenance` / `Invoke-WinDebloat7Maintenance`

### **Integrations** (`src/modules/Integrations/Integrations.psm1`)
Third-party portable utility wrappers with hash verification.
- **Exported Functions & Aliases:** `Invoke-WinDebloatShutUp10` / `Invoke-WinDebloat7ShutUp10`, `Invoke-WinDebloatAdwCleaner` / `Invoke-WinDebloat7AdwCleaner`, `Update-WinDebloatSDIO` / `Update-WinDebloat7SDIO`

### **Vendor & OEM Debloat** (`src/modules/Vendor/Vendor.psm1`)
Hardware telemetry disablement and OEM bloatware cleanup.
- **Exported Functions & Aliases:** `Disable-WinDebloatGpuTelemetry` / `Disable-WinDebloat7GpuTelemetry`, `Remove-WinDebloatOemBloat` / `Remove-WinDebloat7OemBloat`

### **Windows 11 Version Detection** (`src/modules/Windows11/Version-Detection.psm1`)
Authoritative Windows build and edition identification engine.
- **Exported Functions:** `Get-WindowsVersionInfo`, `Test-Windows11Version`, `Clear-WindowsVersionCache`

### **Extras Module** (`src/modules/Extras/Extras.psm1`) ⚠️
*Shipped exclusively in the Extras Edition release.*
- **Exported Functions & Aliases:** `Invoke-WinDebloatDefenderRemover` / `Invoke-WinDebloat7DefenderRemover`, `Invoke-WinDebloatActivation` / `Invoke-WinDebloat7Activation`

---

## ⚙️ Core Infrastructure (`src/core`)

These modules provide the foundational runtime engine for configuration, logging, safety, and system state:

| Module | File | Purpose | Exported Functions & Aliases |
|--------|------|---------|-------------------|
| **Logger** | `src/core/Logger.psm1` | Thread-safe logging with rotation | `Start-WinDebloatLogging` / `Start-WD7Logging`, `Write-Log`, `Get-WinDebloatLogPath` / `Get-WD7LogPath` |
| **Config** | `src/core/Config.psm1` | YAML profile parsing, schema validation & preview | `Import-WinDebloatConfig` / `Import-WinDebloat7Config`, `Test-WinDebloatConfig` / `Test-WinDebloat7Config`, `Get-WinDebloatRecommendedProfile` / `Get-WinDebloat7RecommendedProfile`, `Get-WinDebloatProfilePlan` / `Get-WinDebloat7ProfilePlan` |
| **Registry** | `src/core/Registry.psm1` | Raw .NET registry operations, hive validation & key removal | `Set-RegistryKey`, `Get-RegistryKey`, `Test-RegistryKey`, `Export-RegistryKey`, `Remove-RegistryKey` |
| **State** | `src/core/State.psm1` | DPAPI-encrypted snapshots & value-level restore | `New-WinDebloatSnapshot` / `New-WinDebloat7Snapshot`, `Restore-WinDebloatSnapshot` / `Restore-WinDebloat7Snapshot`, `Get-WinDebloatSnapshot` / `Get-WinDebloat7Snapshot`, `Compare-WinDebloatSnapshot` / `Compare-WinDebloat7Snapshot`, `Get-WinDebloatRegistryTargets` / `Get-WinDebloat7RegistryTargets` |
| **SystemState** | `src/core/SystemState.psm1` | Live system detection & 100-point privacy scoring | `Get-WinDebloatSystemState` / `Get-WinDebloat7SystemState`, `Get-WinDebloatPrivacyScore` / `Get-WinDebloat7PrivacyScore` |
| **Sysprep** | `src/core/Sysprep.psm1` | Audit mode detection & Default User hive mounting | `Test-WinDebloatSysprep` / `Test-WinDebloat7Sysprep`, `Mount-WinDebloatDefaultHive` / `Mount-WinDebloat7DefaultHive`, `Dismount-WinDebloatDefaultHive` / `Dismount-WinDebloat7DefaultHive` |

---

## 🖼️ UI Layer (`src/ui`)

| Module | File | Purpose | Exported Functions |
|--------|------|---------|-------------------|
| **Colors** | `src/ui/Colors.psm1` | TrueColor ANSI engine & formatted UI output | `Write-WD7Host`, `Show-WD7Header`, `Show-WD7Separator`, `Show-WD7Progress`, `Show-WD7StatusBadge` |
| **Menu** | `src/ui/Menu.psm1` | Interactive Terminal User Interface (TUI) | `Show-MainMenu` |
| **GUI** | `src/ui/gui/GUI.psm1` | WPF Graphical User Interface (GUI) controller | `Show-WinDebloatGUI` / `Show-WinDebloat7GUI` |
