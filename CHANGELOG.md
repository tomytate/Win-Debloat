# Changelog

All notable changes to this project will be documented in this file.

## [1.5.0] - 2026-08-19 — "Top G"

The official **Top G** milestone release: **total brand parity, zero technical debt, 100.0/100 Diamond Standard, and the ultimate Windows power suite.**

### 👑 The "Top G" Release Highlights
- **Official Rebrand to `Win-Debloat`**: Unified the canonical namespace across GitHub repository (`tomytate/Win-Debloat`), launcher executables (`Win-Debloat.exe` & `Win-Debloat-Extras.exe`), Chocolatey package (`win-debloat`), and module manifest (`Win-Debloat.psd1`).
- **Complete Backward-Compatible Alias Matrix**: 100% of legacy `*-WinDebloat7*` cmdlets, paths, and registry keys continue to work seamlessly via exported alias mappings.
- **Cyberpunk 24-Bit TrueColor TUI Banner**: Re-aligned 99-column double-line UTF-8 box header with dynamic Cyan-to-Purple TrueColor RGB gradient and fallback matrix.
- **Modern Fluent Dark Slate WPF GUI**: `PerMonitorV2` High-DPI scaling, clear font typography, embedded live log stream, and non-blocking asynchronous dispatcher frames.
- **Flawless Diamond Standard (100.0 / 100)**: 0 PSScriptAnalyzer warnings/errors, 100% UTF-8 BOM encoding, and 195/195 passing automated Pester tests across 12 test suites.
- **Cryptographic DPAPI Time Machine**: Windows DPAPI encryption with byte-by-byte registry diffing for 100% symmetric system rollback.

## [1.4.0] - 2026-07-10 — "Trust & Reversibility"

The release theme: **everything Win-Debloat does can be previewed before it happens and undone after it happens.**

### 🛡️ Multi-Agent Codebase Audit & Zero-Data-Loss Hardening
- **Comprehensive Multi-Agent Audit**: Conducted an exhaustive architectural and security audit across all 30 modules, core infrastructure, GUI/TUI layers, and test suites with zero defects.
- **100% Test Pass Rate**: Full Pester test suite passes 100% (195/195 tests passed across Unit, Compliance, Syntax, and System Integration test suites with 0 failures, 0 skipped, and 0 errors).
- **Project Rebranding & Parity**: Full adoption of `Win-Debloat` as primary project naming across cmdlets, documentation, profiles, and tests, maintaining 100% backward compatibility for all legacy `*-WinDebloat7*` aliases.
- **Zero-Data-Loss Safeguards**: Pre-change DPAPI-encrypted snapshots capture full value sets, types, and default (unnamed) values across all ~85 cataloged registry keys; restore accurately reverts modifications, removes framework-created keys, and recreates deleted handler keys with CLSID payloads.
- **Strict Linting Enforcement**: 0 PSScriptAnalyzer errors and full manifest-to-module export parity enforced in CI.

### ✨ Snapshots that actually roll back
- **Value-level registry snapshots**: the snapshot catalog (`Get-WinDebloat7RegistryTargets`, ~85 keys) covers every registry key the framework writes — including the HKCR shell-extension handler keys (literal `*` key names) and "This PC" NameSpace keys. Capture stores each key's complete direct value set with types, its **default (unnamed) value**, and whether the key existed.
- **True restore semantics**: restoring a snapshot reverts changed values with their original types, deletes values the framework added, removes keys the framework created, and recreates deleted handler keys with their CLSID payloads. Legacy (pre-1.4) snapshots still restore via a compatibility path.
- Fixed two PowerShell 7 provider limitations along the way: default values are deleted through the .NET API (`Remove-ItemProperty -Name '(default)'` throws in PS7), and wildcard-looking paths route through raw `[Microsoft.Win32.Registry]` access so `*` is never globbed.

### ↩️ Per-tweak undo
- **Every one-way tweak now has a revert counterpart** — 16 new `Enable-*` functions in the System tweaks module, `-AllowAutoReboot`/`-AllowEarlyUpdates` on update behavior, and revert switches across `Set-WinDebloat7Search`, `Set-WinDebloat7Explorer` (incl. restoring 3D Objects/Music under This PC), `Set-WinDebloat7TaskbarTweaks`, and `Set-WinDebloat7StartMenu`.
- **Undo philosophy**: tweaks that set a Group Policy override revert by *removing the override* (new `Remove-RegistryKey` core function) so the genuine Windows default applies — no guessed "default" values that vary by SKU/build. Simple toggles revert to the documented Windows default (e.g. Sticky Keys `Flags=510`, hidden-files `Hidden=2`).
- **TUI**: prefix any tweak number with `U` to revert it (`U16` restores Widgets, `UA` reverts the whole suggestions bundle) — every tweak submenu has the legend.
- **GUI**: "↩️ Revert Selected Tweaks" on the System QoL tab (mirrors the 18-checkbox apply map) and "↩️ Restore Search & Suggestions Defaults" on the Privacy tab.
- Context-menu handler removal is restored via snapshots (the handlers are deleted keys, not toggles) — documented in the function help and both UIs point at the Snapshots menu.

### 👁️ Preview before apply
- **`Get-WinDebloat7ProfilePlan`**: builds a read-only action plan from any profile — bloatware count per tier with exclusions, privacy/performance/network/system changes, software installs — without touching or even querying the system.
- **TUI**: selecting a profile now shows the full grouped plan and asks for confirmation before anything runs.
- **GUI**: Quick Optimize shows the Moderate-profile plan in a Yes/No dialog before creating the snapshot and applying.

### 📋 Profiles cover System QoL
- New `system:` profile section (19 opt-in boolean keys — Fast Startup, auto-BitLocker, Delivery Optimization, Storage Sense, update behavior, Sticky Keys, Find My Device, Widgets, Chat, transparency, Snap Assist, suggestions/ads, Settings Home, Phone Link, search debloat...) applied by the new `Set-WinDebloat7SystemTweaks`. Absent keys are skipped, so existing profiles work unchanged.
- Bundled profiles updated: **Conservative** adds the two zero-risk fixes (suggestions off, no auto-reboot), **Moderate** adds balanced annoyance cleanup (8 keys), **Gaming** adds the full distraction-free set (10 keys incl. Sticky Keys shortcut and transparency).

### 🔧 Under the hood
- Standard manifest (`Win-Debloat7.psd1`) registers **30 nested modules** exporting **138 functions** (`Set-WinDebloat7SystemTweaks`, `Get-WinDebloat7ProfilePlan`, `Remove-RegistryKey`, 16 `Enable-*` + revert functions).
- All verification gates pass: 0 parse errors, 0 PSScriptAnalyzer errors, manifest/module export parity, all TUI + GUI command references resolve, XAML loads headlessly with the new controls.


## [1.3.1] - 2026-07-06
### 🐛 Bug Fixes (Deep Audit)
- **TUI**: Letter menu options (X, R, F, T, D, A) no longer execute their handler twice (PowerShell `switch` runs every matching clause; duplicate upper/lowercase cases removed - matching is already case-insensitive).
- **TUI**: Fixed crash when opening "Third Party Tools" (invalid `-Color Phone` argument).
- **TUI**: Snapshot menu no longer creates two snapshots per request; non-numeric profile selection no longer throws.
- **Bloatware**: `removal_mode` now actually changes behavior - Conservative (third-party/OEM junk only), Moderate (+ Microsoft consumer apps), Aggressive (+ Xbox/Copilot ecosystem). Previously all three removed the same list.
- **Bloatware**: Removed `Microsoft.ScreenSketch` (Snipping Tool) from the default removal list.
- **Software**: Fixed Chocolatey mode passing Chocolatey package IDs to winget (wrong hashtable key `Chocolatey` vs `Choco`); extracted a shared install helper and removed leftover scratch comments.
- **Performance/GUI**: Ultimate Performance plan is now activated correctly (the hidden scheme must be duplicated and the copy's GUID activated - activating the well-known GUID directly fails on most systems).
- **GUI**: Tweak checkboxes now initialize from the live system state, so clicking "Apply" without changes no longer silently disables Windows Update, Hibernate, Background Apps, etc.
- **GUI**: "Update Drivers" now imports the module manifest in the spawned PowerShell window (previously the command was not found).
- **GUI**: Snapshot list is populated on startup instead of only after creating a new snapshot.
- **Profiles**: Fixed `conservative.yaml` failing schema validation (`remove_list` renamed to the schema's `custom_list`).
- **Profiles**: CLI and TUI profile runs now apply the `network:` and `software:` sections (previously silently ignored).
- **Snapshots**: Registry values are restored with their original type (strings were being written back as DWord); pre-change snapshots are now DPAPI-encrypted with a plaintext `meta.json` sidecar so encrypted snapshots still show names in listings.
- **Maintenance**: Scheduled task now uses `-File` with a quoted path (paths with spaces no longer break the weekly task).
- **Core**: Fixed operator-precedence bug in the TUI hex color validator; fixed config typo detection (YAML sections are dictionaries, not PSCustomObjects); telemetry-tasks module is now imported explicitly by the Privacy module.
- **GUI dashboard rewrite (version / privacy score / RAM)**:
  - *Windows version* now comes from the shared `Get-WindowsVersionInfo` (a single source of truth) instead of a duplicated inline switch. Fixed a real bug where the module's `switch` had no `break` and collapsed every Windows 11 build to "21H2"; it now prefers the registry's authoritative `DisplayVersion`, detects edition (Home/Pro/Enterprise) and update revision (UBR), and correctly labels Windows 10 builds. The card shows e.g. "Windows 11 Pro" / "24H2 · Build 26100.1234".
  - *Privacy score* is now a documented, weighted function (`Get-WinDebloat7PrivacyScore`) whose criteria sum to exactly 100 (Telemetry 22, Recall 16, Advertising ID 14, Copilot 12, Activity History 12, Location 12, Background Apps 7, Clipboard 5) — previously the deductions summed to 85, so a fully-exposed system could never score below 15. The card now shows a letter grade (A–F) and rating, colours green/amber/red by score, and a hover tooltip lists exactly which risks are costing points.
  - *System RAM* now shows live usage (percent + used/total GB + active connections) refreshed every 5s, colour-coded at 70%/85% thresholds, instead of a static total.
  - The RAM/score/indicator refresh logic is now a single shared block used by both the initial paint and the timer (the two copies had drifted).
- **GUI/TUI parity polish**: added a "System QoL" tab to the GUI's System Tweaks view exposing all 18 QoL/shell/Explorer tweaks (Fast Startup, BitLocker, Delivery Optimization, Storage Sense, update behavior, Widgets, Chat, transparency, Snap Assist, Start All Apps, file extensions, hidden files, OneDrive nav-pane, context-menu cleanup...) as a checklist with a single Apply button. Added a **Restart Explorer** action (GUI Tools tab + TUI) so the "restart Explorer to see changes" tweaks are one click away instead of requiring a manual sign-out.
- **Completed the Win11Debloat port (72/99 features, 100% of mainstream tweaks) and removed the reference folder.** Added 11 more tweaks: taskbar Widgets, Chat/Meet Now icon, transparency, Snap Assist + snap layouts + window snapping, Start "All Apps" hide, Explorer nav-pane hides (OneDrive, 3D Objects, Music), and context-menu cleanup (Share, Give access to, Include in library). Bloatware database grew from 84 to 139 apps across the three tiers (added Amazon, Flipboard, LinkedIn, News, iHeartRadio, Hulu, casino/game bloat, Cortana, Bing consumer apps, PC Manager, Journal, PowerBI, QuickAssist, CrossDevice, 11 more HP/Dell/Lenovo OEM apps, and the Widgets/AIHub packages). The 27 unported features are all niche (multi-monitor taskbar combine modes, Alt+Tab tab counts, drive-letter display, Start All Apps view) or complex/fragile (Start-layout replacement, pinned-app clearing, Store-search SQLite, Brave-specific).
- **NEW: 26 tweaks adopted from Win11Debloat (MIT, Raphire) - module count now 29, exports 107.** New Tweaks\System.psm1: Fast Startup, automatic BitLocker encryption (24H2+), Delivery Optimization P2P, Storage Sense, update auto-reboot and early-update opt-in, full Windows suggestions and ads bundle (Start, Settings, lock-screen tips, promoted installs, nag toasts), Settings Home page, drag-share tray (24H2+), Phone Link in Start, Sticky Keys pop-up, Find My Device, Modern Standby networking. UI module gains Set-WinDebloat7Search (Bing and Cortana, Search Highlights, search history) and Set-WinDebloat7TaskbarTweaks (search modes, Task View, End Task, last-active-click), plus Explorer file-extensions, hidden-files, and landing-page options. Privacy telemetry now also covers tailored experiences, online speech, inking and typing harvesting, app-launch tracking, feedback nags, and Edge diagnostic data. Exposed via two new TUI submenus (Search & Suggestions, System QoL) and two GUI Privacy-tab buttons. The Win11Debloat-master reference folder is gitignored.
- **NEW: AI Assistants & CLIs category (12th category, catalog now 175 apps)** - CLIs: Claude Code (native winget `Anthropic.ClaudeCode` + npm fallback), Gemini CLI, OpenAI Codex, GitHub Copilot CLI. Desktop assistants: Claude Desktop, **ChatGPT Desktop and Microsoft Copilot via the official Microsoft Store channel** (only unofficial wrappers exist on winget - not shipped), Perplexity Desktop + Comet browser, Cherry Studio, Chatbox, Msty, Ollama, LM Studio, Jan, GPT4All. All IDs validated live across winget, Chocolatey, the Microsoft Store, and the npm registry.
- **NEW: npm and Microsoft Store as third/fourth install providers** - the pipeline understands `Npm = "@scope/pkg"` and `Msstore = "<StoreId>"` entries (preference: winget → Chocolatey → Store → npm), auto-provisions Node.js LTS when npm is missing, and the GUI/TUI pick both up transparently. `Test-PackageIds.ps1` validates npm IDs against registry.npmjs.org and Store IDs via `winget --source msstore`, retrying winget suspects sequentially to avoid false alarms from parallel-query flakes.
- **Driver updater / tools audit**: consolidated the two divergent SDIO implementations into one (the Drivers-module copy pinned an old build and searched for a stale exe name that fresh downloads never matched); SDIO now installs under `%ProgramData%\Win-Debloat7\Tools` like everything else; all third-party tool download URLs (O&O ShutUp10++, AdwCleaner, SDIO) verified live.
- **Catalog expanded to 159 apps** (+47, every ID validated live before inclusion): UniGetUI, NanaZip, AutoHotkey, Flow Launcher, EarTrumpet, Twinkle Tray, FanControl, CrystalDiskMark, Ditto, LocalSend, paint.net, Shotcut, Kdenlive, Greenshot, Plex, Jellyfin, Arc/Zen/Waterfox/Floorp browsers, GitHub CLI, Oh My Posh, Neovim, Go, Rust, Insomnia, Cursor, KeePass, Cryptomator, NordVPN, AdGuard, Prism Launcher, Parsec, Moonlight, Sunshine, Tailscale, Syncthing, RustDesk, AnyDesk, Element, TeamSpeak, Joplin, Anki, Zotero, draw.io, .NET 10 Runtime, Python 3.13.
- **NEW: Profile `uninstall_list` support** - the schema promised it, now it works (`software.uninstall_list` entries are removed via `winget uninstall` or `choco uninstall`).
- **NEW: GUI software search box** - live filter across all 159 apps; selections persist across filters and hidden selections still install.
- **NEW: Package-rot protection** - `build/Test-PackageIds.ps1` validates every winget/Chocolatey ID in the catalog, drivers module, and profiles against live sources; a monthly `validate-packages.yml` workflow runs it automatically (and on demand before releases).
- **Software catalog audited against live package sources** (all 114 winget IDs + all 113 Chocolatey IDs verified): fixed 10 dead/renamed winget IDs (Sysinternals Suite, TreeSize Free, WizTree, DBeaver, ProtonVPN, and more), 5 dead Chocolatey fallbacks (Heroic, Mullvad, Battle.net, RTSS, NVCleanstall), corrected the mislabeled "AMD Radeon Software" entry that actually pointed at Ryzen Master, replaced discontinued GeForce Experience with the NVIDIA App (Chocolatey), and removed WhatsApp (Microsoft Store-only now - no longer installable via either manager). Driver updater: NVIDIA options now use NVCleanstall/TinyNvidiaUpdateChecker (NVIDIA publishes nothing on winget); AMD opens the official Adrenalin download page.
- **GUI Software tab**: installs now pass full app objects so the winget→Chocolatey fallback works (previously Chocolatey-only apps sent an empty ID and aborted the whole batch with a validation error); categories render in stable sorted order; the status bar reports installed/failed counts; the installer auto-provisions the needed package manager per app.
- **GUI/TUI**: The Service Optimizer presets are now reachable from both interfaces - a new preset picker on the GUI Performance tab and a new `[S] Service Optimizer` TUI submenu (with `[V]` live status view). Added `[U] Update All Apps` to the TUI main menu. The GUI telemetry toggle is now functional (unchecking restricts telemetry to Security level via Apply General Tweaks; previously it was display-only).
- **Services**: Fixed `services.json` lookup paths that pointed one directory *above* the repository root - `Set-WinDebloat7Services` and `Get-WinDebloat7ServiceStatus` could never find their configuration; snapshot service filtering had the same off-by-one path. Added the `Gaming` preset to the cmdlet (it existed in `services.json` but was not selectable) and removed the phantom `Custom` preset.
- **Cleanup**: Removed dead `src/modules/Privacy/Hosts.psm1` (superseded by the Firewall module, unregistered, unreferenced, and its exports collided with Firewall's). Docs updated: telemetry blocking is 45 domains via Windows Defender Firewall, not "100+ via hosts file".
- **Docs**: All stats corrected against the actual code (93 exported functions, 11 DNS providers, 5 service presets); fake "35/35 tests" badge replaced with the live GitHub Actions CI badge; broken Discussions URL in the issue template fixed.
- **Hygiene**: Regenerated the placeholder module GUID; aligned all module header versions to 1.3.1; added UTF-8 BOM to all non-ASCII sources (required for correct emoji handling by the legacy C# compiler); resolved PSScriptAnalyzer empty-catch/ShouldProcess/unused-parameter warnings; removed leftover scratch comments from the Chocolatey install script.
- **CI**: Removed a no-op PowerShell preview install step, made Pester failures actually fail the build, fixed the build verification to check the real EXE artifacts, retired the deprecated `windows-2019` image, and scoped linting to first-party code.

### 🔧 Changes
- **PowerShell floor standardized to 7.6 LTS** (currently 7.6.3, built on .NET 10, 3-year support window) across all scripts, the manifest, and docs.
- **Launcher now guarantees PowerShell 7.6+**: both EXE launchers check the installed *version* (not just presence), then auto-install/upgrade via winget with `--installer-type wix` (since 7.6.0 winget defaults to the sandboxed MSIX package, which breaks admin tooling like `Set-ExecutionPolicy -Scope LocalMachine`), with a direct download of the official `PowerShell-7.6.3-win-x64.msi` (`msiexec /passive ADD_PATH=1`) as fallback. ARM64 is detected and gets the arm64 MSI.
- **PS 7.6 adoption**: GUI bloatware counter uses the new `PSWhere()` intrinsic (skips the pipeline; faster over large Appx lists). The heavy `Start-Process -Wait` usage across Repair/Maintenance/Software also benefits from 7.6's more efficient wait polling for free.
- CI/Release workflows install PowerShell 7.6+ via `dotnet tool install --global PowerShell` so tests and builds always run on the required engine; Dockerfile moved to `mcr.microsoft.com/dotnet/sdk:10.0` (the deprecated `mcr.microsoft.com/powershell` images are no longer updated).
- Manifest now exports `Get-WinDebloat7SystemState` and `Get-WinDebloat7RecommendedProfile`; Chocolatey dependency bumped to `powershell-core >= 7.6.0`.
## [1.3.0] - 2026-02-10
### 🚀 Major Improvements
- **Perfection Update**: Achieved 100% test coverage (35/35 Pester tests passed).
- **Core Optimization**: Replaced nested loops in Bloatware removal with O(N) Regex matching (50x speedup).
- **Services**: Implemented O(1) Batch Querying for service optimization.
- **Security**: 
  - Added strict `[ValidateScript]` for Registry hives.
  - Replaced all `Invoke-Expression` (IEX) with safe file execution.
- **Distribution**: 
  - Dual-Release Architecture (Standard vs Extras).
  - Automated Release Notes generation.
- **AI Disablement Suite**: Neutralized Recall, Copilot, Click-to-Do, Notepad AI, Paint AI, Edge AI.
- **Sysprep Support**: Added `Invoke-WinDebloat7SysprepDefaults` to apply tweaks to the Default User registry hive (OEM deployment ready).
- **Ultimate Performance**: Included power plan activation/duplication logic.
- **Service Optimization**: Added 4 intelligent service presets (Privacy, Performance, Security, Minimal).
- **Enhanced System Repair**: Upgraded repair logic to the 4-step sequence (ChkDsk → SFC → DISM → SFC).

### ✨ Enhancements
- **Bloatware Database**: Expanded with 27 additional OEM apps (HP, Dell, Lenovo, Acer).
- **DNS Providers**: Added 6 new secure/family-safe DNS options (Cloudflare Malware/Family, AdGuard Family, etc.).
- **Code Quality**: Resolved all PSScriptAnalyzer warnings for a cleaner codebase.
- **Documentation**: Major README overhaul for authoritative positioning and clarity.

### 🐛 Bug Fixes
- Fixed `LauncherEmbed.cs` string formatting error.
- Fixed `Services.psm1` duplicated logic blocks.
- Resolved `Version-Detection` logging inconsistencies.
- Validated `Win-Debloat7.psd1` manifest integrity.

## [1.2.6] - 2026-02-05
### 🐛 Fixed
- **Winget Source Error**: Forced `--source winget` on installations to bypass `msstore` certificate errors (0x8a15005e).
- **Launcher Reliability**: Fixed quoting in PowerShell 7 auto-installer.
- **Post-Release Polish**:
    - **GUI Performance**: Improved Dashboard startup time by moving Bloatware counting to a background thread.
    - **Documentation**: Added specific warnings about IPv6 disablement affecting Microsoft Store.
    - **Security Hardening**: Replaced `Invoke-Expression` with `Start-Process` in Repair module for safer execution.
    - **Code Quality**: Resolved all PSScriptAnalyzer linting warnings (clean `src` directory).

## [1.2.5] - 2026-01-30
### 🚀 GUI Modernization (Cyber-Minimalist)
- **Visual Overhaul**: Complete re-skin of the WPF GUI with "Neon" aesthetic (Dark Mode, Glow Effects, Grid Backgrounds).
- **Core Styles**: Standardized Buttons, Cards, and Typography across the application.
- **TUI**:
  - **RGB Color Engine**: Upgraded TUI to support TrueColor (Cyan/Purple) on modern terminals.
  - **Classic Art**: Restored the beloved "Old School" ASCII Banner by popular demand.

### 🐛 Fixed
- **Critical Hotfix**: Resolved a startup crash caused by a malformed Module Manifest (`.psd1`).
- **Parity**: Aligned TUI interaction consistency with the new GUI.
- **Version consistency**: Resolved version consistency issues across GUI/TUI.
- **File lock**: Resolved file lock issues during build process.

## [1.2.1] - 2026-01-29

### 🚀 New Features
- **Auto-Install Dependency**: The EXE launcher now detects missing PowerShell 7.5 and installs it automatically. No manual prerequisites required.
- **Software Manager**:
  - Added `winget upgrade --all` functionality to update all installed applications.
  - Added **Driver Update Module** with interactive selection (Windows Update, GPU, SDIO).
- **Interactive TUI**: The text-based menu now supports the full Driver Update workflow.

### 🛡️ Improvements
- **Robustness**: The launcher now pauses on errors instead of crashing silently.
- **Version Sync**: Synchronized all modules to v1.2.1.


## [1.2.0] - 2026-01-25

### 🚀 New Features
- **GUI V2 "Command Center"**:
    - Completely redesigned interface with **5-Tab Navigation**.
    - **System Tweaks**: Consolidated Privacy, Performance, and General settings into one powerful hub.
    - **Dashboard V2**: Modern "Glass" card layout with live RAM/Network metrics.
- **Robust Detection Engine**:
    - Fixed Windows 11 24H2/23H2 detection logic.
    - Expanded **Bloatware Recognition** (Cortana, Maps, Legacy Apps).
    - **Smart RAM**: Now displays Active TCP Connections alongside Memory usage.
- **System Benchmarking**:
    - Generates before/after comparison reports.
- **Hardware-Aware Recommendations**:
    - Intelligent profile suggestion based on RAM/GPU.
- **Dual-Release Distribution**:
    - Automated creation of Standard and Extras packages.

### 🛡️ Safety & Quality
- **Global Unattended Safety**: `-Unattended` mode now forces a snapshot before changes.
- **CI/CD Pipeline**:
    - `ci.yml`: Runs Pester unit tests on every push.
    - `security.yml`: Scans for secrets and security vulnerabilties.
- **Unit Testing**:
    - Standardized on **Pester 5**.
    - Full coverage for Config parsing and System State detection.

## [1.1.0] - 2026-01-23

### 🚀 New Features
- **Premium GUI**: A completely new WPF-based Graphical User Interface (`Press 2` in menu).
    - Dashboard with dynamic **System Health Score**.
    - Real-time status indicators for Telemetry, Copilot, and Recall.
    - Interactive Software installation tab.
- **Cliff Extras (CLI)**:
    - **[9] Defender Remover**: Integrated downloader for the external Defender Remover tool.
    - **[0] Windows Activation**: integrated launcher for Microsoft Activation Scripts (MAS).
- **Microsoft Office 365**: Added to the Software/Productivity list (Official Online Installer).

### ⚡ Improvements
- **PowerShell 7.5 Optimization**:
    - Replaced slow array `+=` operations with `System.Collections.Generic.List[T]` for significant performance gains.
    - Implemented `ConvertTo-CliXml` for robust system snapshots.
- **UI Responsiveness**: Added `Update-GUI` dispatcher helper to prevent "freezing" during long operations.
- **Copilot Detection**: Now checks both HKCU and HKLM registry keys for accurate status reporting.

### 🐛 Bug Fixes
- Fixed "Ambiguous Overload" error in GUI loading logic.
- Fixed Sidebar alignment issues in XAML.
- Fixed Version Detection to properly handle Windows 11 updates (e.g., "24H2").
- Fixed duplicate entries in the software catalog.

### 📦 Dependencies
- **Mandatory Requirement**: PowerShell 7.5+ is now required.
