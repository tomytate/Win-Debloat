# Features & Capabilities

Win-Debloat is a modular Windows optimization and privacy framework. You can run the entire suite using a YAML Profile, or use individual modules via the CLI, TUI, or GUI. Version 1.7.0 includes **297 exported functions** (and 337 backward-compatible aliases) across **30 registered modules** — engineered with zero-data-loss hardening, full preview capabilities, and complete reversibility.

---

## 🖥️ Dual Interface

### GUI (Graphical User Interface)
Launch with `.\Win-Debloat.ps1 -Gui` (or `.\Win-Debloat7.ps1 -Gui`), via `Run.bat`, or via `Win-Debloat.exe`.
- **Asynchronous Non-Blocking 60 FPS Cockpit**: Dedicated background STA (`ApartmentState::STA`) Runspace pipeline with high-precision 33ms DispatcherTimer pump (~30–60 FPS) and live cancellation (`btnCancelOperation`) that terminates background process trees cleanly.
- **In-Window Modal Visual Diff Overlay (`modalDiffOverlay`)**: Syntax-highlighted action plans and dry-run preview (`[+]` green, `[-]` red, `[~]` amber) with direct one-click execution.
- **Window Ergonomics & Theming**: Native DWM immersive dark mode titlebar (`DwmSetWindowAttribute`), rounded window corners (`DWMWCP_ROUND`), slate borders (`#334155`), and caption styling (`#0B1120`).
- **High-DPI Geometries**: Fluent vector Path geometries (`PerMonitorV2` scaling) replacing low-res icons and emoji artifacts.
- **5-Card Telemetry Dashboard**: Real-time cockpit displaying OS & Hardware Architecture (AMD X3D / Intel Lunar Lake / ARM64 / NPU), DirectStorage 1.2+ BypassIO & NVMe TRIM readiness, 11-Vector 100-point graded privacy score, Tiered Bloatware status, and live RAM utilization.
- **26H2 System Tweaks**: Full control suite for physical Copilot key remapping, Taskbar Glomming/Grouping, Low-Latency Timers, UDP Receive Offload (URO), ReFS Dev Drive tuning, Encrypted Client Hello (ECH), and Enterprise SMB Hardening.
- **Declarative Software Catalog**: Curated catalog of 175 applications driven by `config/apps.yaml` with live search, recommended selections, and asynchronous background installation.
- **Tools & Repair**: 4-step industrial system repair with Windows 11 24H2/26H2 checkpoint update safety gates, network reset, Windows Update reset, and safe Explorer restart.
- **Settings & Snapshots**: Theme toggles, DPAPI-encrypted snapshot browser with human-readable `.reg` exports and one-click restore.

### TUI (Terminal User Interface)
Launch with `.\Win-Debloat.ps1` or `.\Run.bat` (default interactive mode).
- **Visual State Diff Viewer (`Show-WinDebloatDiffViewer`)**: Interactive ANSI TrueColor box-border viewer (`╭─╮│╰─╯`) displaying change metrics (`[+] Added`, `[-] Removed`, `[~] Modified`, `[*] Services`).
- **Alternate Screen Buffer**: Uses `DECSET 1049` (`Enter-WDAlternateBuffer` / `Exit-WDAlternateBuffer`) to cleanly preserve the user's terminal shell history upon exit without scroll pollution.
- **Double-Buffered Atomic Rendering**: Double-buffered `DECSET 2026` synchronized output (`Render-WDFrame`) providing zero screen flicker.
- **Sub-Character Smooth Progress Bars**: 8x sub-character fractional block progress bars (`Show-WD7SmoothProgress`) with dynamic TrueColor linear RGB gradients.
- **Indeterminate Braille Spinners**: Non-blocking background runspace execution (`Invoke-WDTaskWithSpinner`) with smooth ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ animation and millisecond timer readouts.
- **Interactive Navigation Engine**: Keyboard arrow navigation (`Show-WDInteractiveMenu`) with Up/Down, Home/End, PageUp/PageDown, Enter selection, and Escape exit.
- **26H2 Dedicated Submenus**: Interactive menus for Silicon Scheduling (Intel Lunar Lake / Thread Director, AMD X3D), Transport Security (URO, ECH, DoH), Storage Health (DirectStorage BypassIO), and Enterprise SMB Hardening.

---

## 🛠️ Core Capabilities

### 1. Bloatware Removal & Third-Party Browser Stripping
Removes pre-installed Appx packages using O(N) regex matching (50x faster than legacy nested-loop scripts).
- **Modes**: Conservative (OEM/sponsored), Moderate (non-essential consumer apps), Aggressive (full strip down to core utilities), Custom (YAML profile driven).
- **Database**: 139 tiered bloatware apps (including HP, Dell, Lenovo, Acer, ASUS OEM bloatware, Copilot App, Microsoft Family, and LG bloat).
- **Advanced Removal**: Deep uninstallation of OneDrive, Edge (preserving WebView2), and Xbox (including background services).
- **Cross-Browser Bloatware Stripping**: Native removal of shopping assistants, sidebars, AI integrations, rewards, and telemetry across **Microsoft Edge**, **Google Chrome**, and **Brave Browser** (`Disable-WinDebloatBrowserBloat`).
- **Safety**: Profile-based exclusion lists, DPAPI-encrypted pre-change state snapshots, and human-readable `rollback.reg` export.

### 2. Privacy Hardening & AI Fabric Neutralization
- **11-Vector Privacy Score**: Dynamic real-time calculation across Telemetry, Windows Recall v2, Copilot, Start Ads, Advertising ID, Location, Activity History, NPU/AI Fabric, Sudo Isolation, Background Apps, and Clipboard History.
- **AI Fabric RAM Reclaim**: Deactivates Phi-Silica 3.3B SLM background hosts and terminates `WorkloadsSessionHost`, `AIFabricHost`, `DirectMLHost` to reclaim 2.0 to 4.5 GB RAM.
- **Windows Recall v2 & Click To Do**: VBS enclave Group Policy lockdown and optional package deprovisioning.
- **Firewall Blocking**: Blocks known Microsoft telemetry domains via Windows Defender Firewall with offline IP cache fallback.
- **Scheduled Tasks**: Neutralizes telemetry tasks and UCPD rollback velocity tasks.

### 3. Enterprise Security Hardening
- **Windows Protected Print (WPP)**: RFC 8011 IPP printer validation and Point-and-Print spooler vulnerability mitigation.
- **Sudo for Windows Isolation**: Enforces safe execution modes (ForceNewWindow / DisableInput) to prevent UIPI keystroke hijacking.
- **BitLocker XTS-AES 256**: Enforces military-grade volume encryption and closes ADV180028 SSD hardware encryption bypass vulnerabilities.
- **Baseline Hardening**: Restricts unauthenticated RPC interfaces, enforces SMB signing, enables LSA RunAsPPL protection, and enables Kernel DMA protections.
- **Enterprise Security Logging**: Enforces comprehensive PowerShell Script Block Logging and Security Audit Logging (`Set-WinDebloatSecurityHardening`).

### 4. Next-Gen Performance & Gaming
- **AMD X3D Dual-CCD Safeguards**: Protects AutoGameMode and AMD 3D V-Cache Optimizer Service (`CPMINCORES = 0` and `CPMINCORES1 = 0`) to eliminate cross-CCD latency penalties on Ryzen 7000X3D/9000X3D.
- **Intel Thread Director Heterogeneous Scheduling**: Upgraded scheduling policies (`SCHEDPOLICY 2`, `HETEROPOLICY 1`, `PERFEPP 0`, `PERFEPP1 0`, containment override) for Lion Cove P-cores and Skymont LP E-cores (Lunar Lake / Arrow Lake).
- **Low-Latency Kernel Timers**: Enforces `GlobalTimerResolutionRequests = 1` and `DistributeTimers = 1` in Session Manager for minimum DPC latency and stable 0.5ms resolution (`Enable-WinDebloatLowLatencyTimers`).
- **Gaming Overlay Decoupling**: Neutralizes intrusive `ms-gamingoverlay` prompt popups (`Disable-WinDebloatGameBarPopup`) while preserving Xbox Game Pass and Xbox Live network authentication.
- **MMCSS Quantum Tuning**: Configures MMCSS high priority and low-latency `Win32PrioritySeparation = 38` (`Set-WinDebloatMMCSSPriority`).
- **DirectStorage 1.2+ & DirectSR**: Expands NTFS lookaside pools, enables Win32 Long Paths, and enables windowed VRR super-resolution.
- **TCP Congestion Control (CUBIC / BBR)**: Configures modern TCP congestion providers with dual IPv4/IPv6 loopback MTU protection and NetAdapter RSC jitter suppression.
- **Power Plans & Benchmarking**: Unlocks Ultimate Performance power schemes and provides before/after system benchmarking.

### 5. Network & DNS Hardening
- **DNS Providers**: 11 secure DNS configurations (Cloudflare, Google, Quad9, AdGuard, OpenDNS, CleanBrowsing, NextDNS) including Family Safe and Malware Blocking variants.
- **DNS-over-HTTPS (DoH) Policies**: Native Windows 11 DoH enforcement and fallback control (`Set-WinDebloatDoHPolicy`).
- **Encrypted Client Hello (ECH)**: Enforces TLS ECH for Microsoft Edge and Google Chrome to prevent SNI eavesdropping (`Enable-WinDebloatECH`).
- **UDP Receive Offload (URO)**: Eliminates packet reassembly latency hitches on modern network adapters (`Disable-WinDebloatNetAdapterURO`).
- **IPv6 Control**: Granular IPv6 toggling with Microsoft Store compatibility guidance.
- **Network Diagnostics**: Real-time network state monitoring and active connection tracking.

### 6. Industrial System Repair with 24H2/26H2 Checkpoint Safeguards & Storage Health
Standardized sequence for resolving OS corruption:
1. **ChkDsk** — File system integrity check and volume scan
2. **SFC /scannow** — First-pass System File Checker verification
3. **DISM /Online /Cleanup-Image /RestoreHealth** — Component store remediation with built-in Windows 11 24H2/26H2 Build 26100+ checkpoint update safety gates (`0x800f081f` protection)
4. **SFC /scannow** — Second-pass verification using the repaired component store
5. **DirectStorage & Storage Health Diagnostics** — DirectStorage BypassIO driver inspection, TRIM validation, and physical disk health verification (`Test-WinDebloatStorageHealth`)

### 7. Multi-Provider Software & Driver Management
- **Multi-Source Engine**: Automatic fallback across `winget` → `Chocolatey` → `Microsoft Store` → `npm`.
- **AI Tools & CLIs**: One-click install of AI CLI tools (Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot CLI) and desktop assistants (Claude, ChatGPT, Microsoft Copilot, Perplexity, Cherry Studio, Chatbox, Ollama, LM Studio).
- **Essentials Catalog**: 175 curated applications across 12 categories with automated monthly package-ID validation in CI.
- **Driver Updates**: Windows Update driver scanning, GPU vendor driver updates (NVIDIA/AMD), and Snappy Driver Installer Origin (SDIO) integration.

### 8. Windows 11 UI & System QoL Customization
- **Taskbar & Start**: Center/Left taskbar alignment, search box modes, Task View toggle, Widgets disablement, Chat icon removal, End Task menu shortcut, and Start Menu "Recommended" section removal.
- **Context Menus**: Classic Windows 10 vs Modern Windows 11 context menus; removal of legacy clutter ("Share", "Give access to", "Include in library").
- **File Explorer**: Hide Gallery/Home/OneDrive from navigation pane, display file extensions, show hidden files, configure default landing page.
- **Navigation Pane & Drive Letters**: Suppress duplicate removable drives in Explorer (`Set-WinDebloatDuplicateRemovableDrives`) and position drive letters before/after drive labels (`Set-WinDebloatDriveLetterPosition`).
- **Ergonomics**: Disable mouse acceleration (Enhance Pointer Precision) for 1:1 raw mouse input (`Disable-WinDebloatMouseAcceleration`).
- **System QoL (Reversible)**: 18 reversible tweak pairs including Fast Startup, automatic BitLocker, Delivery Optimization P2P, Storage Sense, update auto-reboot control, Sticky Keys pop-up, drag-share tray, Find My Device, and window Snap Assist.

### 9. Enterprise Deployment & Multi-User Sysprep
- **Audit Mode & Multi-User Support**: Automatic detection of Windows Audit / Sysprep mode (`-Sysprep`).
- **Profile Hive Target Resolution**: Mounts and configures `C:\Users\Default\NTUSER.DAT` and offline user hives (`-TargetUser <User|Default|All>`), ensuring newly provisioned accounts inherit optimizations.
- **Zero-Binary SAC Trampoline (`Run.bat`)**: One-click UAC elevation trampoline that completely bypasses Windows 11 Smart App Control and unblocks Mark-of-the-Web.
- **Enterprise Standalone Headless Deployment (`deploy/Deploy-WinDebloat.ps1`)**: Zero-dependency standalone deployment engine for Microsoft Intune Win32 Apps, SCCM, and OOBE Shift+F10 unattended installations.

### 10. Third-Party Integrations
- **O&O ShutUp10++**: Portable privacy hardening tool wrapper with automated SHA-256 validation.
- **Malwarebytes AdwCleaner**: Portable adware and PUP scanner.
- **SDIO**: Snappy Driver Installer Origin offline driver package downloader and updater.

---

## 🛡️ Safety & Quality Architecture

### Triple-Layer Disaster Recovery Architecture
- **Layer 1: Native CIM VSS System Restore Point**: Creates an atomic Volume Shadow Copy (VSS) checkpoint directly via native CIM (`root\default:SystemRestore`), bypassing the 24-hr frequency rate limit (`SystemRestorePointCreationFrequency = 0`) and managing VSS service startup.
- **Layer 2: Cryptographic DPAPI-Encrypted Snapshots**: Captures full key state, individual values with original registry types (`DWord`, `String`, `ExpandString`, `MultiString`, `Binary`, `QWord`), and default unnamed values across ~85 cataloged registry paths, encrypted at rest via Windows DPAPI with plaintext metadata sidecars (`meta.json`).
- **Layer 3: Standalone UTF-16LE .reg Script & Emergency rollback.cmd**: Exports a standard human-readable Windows Registry Editor (`rollback.reg`) file alongside a zero-dependency `rollback.cmd` script in `backups/`, enabling full offline recovery in Windows Recovery Environment (WinRE) Command Prompt.
- **Visual State Diff Viewer**: Interactive pre- and post-apply diffing in both TUI (`Show-WinDebloatDiffViewer`) and GUI ("Visual Diff Preview") categorizing Added Keys (`[+]`), Removed Keys (`[-]`), Modified Values (`[~]`), and Service Changes (`[*]`).
- **Raw Registry Access**: Utilizes raw `.NET` `[Microsoft.Win32.Registry]` access to eliminate globbing errors on shell handler keys containing literal `*` characters.
- **Clean Policy Removal**: Revert functions remove Group Policy registry overrides instead of guessing system defaults.

### Comprehensive Audit & Continuous Verification
- **Audit Verification**: Passed a comprehensive forensic architectural, security, and manifest audit with a perfect 100 / 100 quality score and 0 technical debt.
- **100% Test Pass Rate**: Full Pester test suite passing across all test suites (**388 / 388 tests passed**, 0 failures, 0 skipped).
- **100% 5-Way AST Parity**: Verified 0 parity violations across defined AST functions (293), exported module functions (293), exported manifest functions (293), exported module aliases (330), and exported manifest aliases (330).
- **Clean Code Quality**: 0 PSScriptAnalyzer errors and 0 parse errors enforced by automated CI workflows on every commit.
- **Structured Audit Logs**: Every operation is logged with ISO timestamps, runspace IDs, and severity levels to `C:\ProgramData\Win-Debloat\Logs`.

