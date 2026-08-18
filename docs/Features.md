# Features & Capabilities

Win-Debloat is a modular Windows optimization and privacy framework. You can run the entire suite using a YAML Profile, or use individual modules via the CLI, TUI, or GUI. Version 1.5.0 includes **138 exported functions** across **30 registered modules** — engineered with zero-data-loss hardening, full preview capabilities, and complete reversibility (with full backward-compatible `*-WinDebloat7*` alias support).

---

## 🖥️ Dual Interface

### GUI (Graphical User Interface)
Launch with `.\Win-Debloat.ps1 -Gui` (or `.\Win-Debloat7.ps1 -Gui`) or via `Win-Debloat.exe`.
- **Dashboard**: Real-time system telemetry (RAM usage, active TCP connections, tiered bloatware count, 100-point graded privacy score).
- **System Tweaks**: One-click toggles for Privacy, Performance, AI disablement, and a comprehensive System QoL checklist (18 boot, shell, and File Explorer tweaks).
- **Software Manager**: Curated catalog of 175 applications with live search across 12 categories, multi-manager installation (winget, Chocolatey, Microsoft Store, npm), bulk upgrades, and driver tools.
- **Tools & Repair**: 4-step industrial system repair, network reset, Windows Update reset, and safe Explorer restart.
- **Settings & Snapshots**: Theme toggles, DPAPI-encrypted snapshot browser with one-click restore.

### TUI (Terminal User Interface)
Launch with `.\Win-Debloat.ps1` (default interactive mode).
- Full-featured interactive menu: profiles, action preview plans, essentials installer, driver updates, service presets, app updates, and repair tools.
- TrueColor ANSI terminal engine (Cyan/Purple neon theme).
- Complete functional parity with the GUI.

---

## 🛠️ Core Capabilities

### 1. Bloatware Removal
Removes pre-installed Appx packages using O(N) regex matching (50x faster than legacy nested-loop scripts).
- **Modes**: Conservative (OEM/sponsored), Moderate (non-essential consumer apps), Aggressive (full strip down to core utilities), Custom (YAML profile driven).
- **Database**: 139 tiered bloatware apps (including HP, Dell, Lenovo, Acer, ASUS OEM bloatware).
- **Advanced Removal**: Deep uninstallation of OneDrive, Edge (preserving WebView2), and Xbox (including background services).
- **Safety**: Profile-based exclusion lists and DPAPI-encrypted pre-change state snapshots.

### 2. Privacy Hardening & AI Disablement
- **Telemetry Blocking**: Neutralizes DiagTrack, Connected User Experiences, and WaaSMedicSvc.
- **Advertising**: Resets Advertising ID, disables Start Menu suggestions, and eliminates Windows promotion nags.
- **AI Disablement Suite**: Neutralizes Copilot, Recall, Click-to-Do, Notepad AI, Paint AI, and Edge AI through Group Policy and registry overrides.
- **Firewall Blocking**: Blocks 45 known Microsoft telemetry domains via Windows Defender Firewall (domains resolved to active IP ranges).
- **Scheduled Tasks**: Disables Microsoft telemetry and diagnostic data collection tasks.

### 3. Performance & Power Optimization
- **Power Plans**: Unlocks and activates the hidden Windows "Ultimate Performance" power scheme.
- **Service Presets**: 5 intelligent service profiles (Privacy, Performance, Security, Minimal, Gaming) driven by `config/services.json`.
- **Gaming Mode**: Disables Nagle's Algorithm (`TCPNoDelay`), optimizes MMCSS scheduling, disables Game DVR background capture, and elevates GPU task priorities.
- **RAM Optimization**: Reduces non-paged pool overhead and provides real-time memory monitoring.
- **Benchmarking**: Before/after system performance measurement and comparative reporting.

### 4. Network & DNS Hardening
- **DNS Providers**: 11 secure DNS configurations (Cloudflare, Google, Quad9, AdGuard, OpenDNS, CleanBrowsing, NextDNS) including Family Safe and Malware Blocking variants.
- **IPv6 Control**: Granular IPv6 toggling with Microsoft Store compatibility guidance.
- **Network Diagnostics**: Real-time network state monitoring and active connection tracking.

### 5. Industrial System Repair (4-Step Pipeline)
Standardized sequence for resolving OS corruption:
1. **ChkDsk** — File system integrity check and volume scan
2. **SFC /scannow** — First-pass System File Checker verification
3. **DISM /Online /Cleanup-Image /RestoreHealth** — Component store remediation
4. **SFC /scannow** — Second-pass verification using the repaired component store

### 6. Multi-Provider Software & Driver Management
- **Multi-Source Engine**: Automatic fallback across `winget` → `Chocolatey` → `Microsoft Store` → `npm`.
- **AI Tools & CLIs**: One-click install of AI CLI tools (Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot CLI) and desktop assistants (Claude, ChatGPT, Microsoft Copilot, Perplexity, Cherry Studio, Chatbox, Ollama, LM Studio).
- **Essentials Catalog**: 175 curated applications across 12 categories with automated monthly package-ID validation in CI.
- **Driver Updates**: Windows Update driver scanning, GPU vendor driver updates (NVIDIA/AMD), and Snappy Driver Installer Origin (SDIO) integration.

### 7. Windows 11 UI & System QoL Customization
- **Taskbar & Start**: Center/Left taskbar alignment, search box modes, Task View toggle, Widgets disablement, Chat icon removal, End Task menu shortcut, and Start Menu "Recommended" section removal.
- **Context Menus**: Classic Windows 10 vs Modern Windows 11 context menus; removal of legacy clutter ("Share", "Give access to", "Include in library").
- **File Explorer**: Hide Gallery/Home/OneDrive from navigation pane, display file extensions, show hidden files, configure default landing page.
- **System QoL (Reversible)**: 16 reversible tweak pairs including Fast Startup, automatic BitLocker, Delivery Optimization P2P, Storage Sense, update auto-reboot control, Sticky Keys pop-up, drag-share tray, Find My Device, and window Snap Assist.

### 8. Enterprise Deployment & Sysprep
- **Audit Mode Detection**: Automatic detection of Windows Audit / Sysprep mode.
- **Default User Hive**: Direct mounting and configuration of `C:\Users\Default\NTUSER.DAT` so optimizations apply to all future user accounts.
- **Headless Deployment**: Full `-Profile config.yaml -Unattended` automation for RMM systems (Intune, SCCM, PDQ Deploy, Action1).

### 9. Third-Party Integrations
- **O&O ShutUp10++**: Portable privacy hardening tool wrapper with automated SHA-256 validation.
- **Malwarebytes AdwCleaner**: Portable adware and PUP scanner.
- **SDIO**: Snappy Driver Installer Origin offline driver package downloader and updater.

---

## 🛡️ Safety & Quality Architecture

### Zero-Data-Loss Architecture
- **Value-Level Snapshots**: Captures full key state, individual values with original registry types (`DWord`, `String`, `ExpandString`, `MultiString`, `Binary`, `QWord`), and default unnamed values across ~85 cataloged registry paths.
- **True Reversibility**: Restore operations revert modified values to exact prior states, remove framework-created keys, delete framework-added values, and re-create deleted handler keys with CLSID payloads.
- **Raw Registry Access**: Utilizes raw `.NET` `[Microsoft.Win32.Registry]` access to eliminate globbing errors on shell handler keys containing literal `*` characters.
- **Clean Policy Removal**: Revert functions remove Group Policy registry overrides instead of guessing system defaults.

### DPAPI-Encrypted Backups
- System state is encrypted with Windows Data Protection API (DPAPI) and paired with plaintext metadata sidecars (`meta.json`) for safe inspection.
- Snapshots bypass the Windows System Restore 24-hour rate limit, allowing unlimited pre-change backups.

### Comprehensive Audit & Continuous Verification
- **Audit Verification**: Passed a comprehensive 20-subagent architectural, security, and manifest audit with 0 defects.
- **100% Test Pass Rate**: Full Pester test suite passing across Unit, Compliance, Syntax, and System Integration test suites.
- **Clean Code Quality**: 0 PSScriptAnalyzer errors and 0 parse errors enforced by automated CI workflows on every commit.
- **Structured Audit Logs**: Every operation is logged with ISO timestamps, runspace IDs, and severity levels to `C:\ProgramData\Win-Debloat\Logs` (and `C:\ProgramData\Win-Debloat7\Logs`).
