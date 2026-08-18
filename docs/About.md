# About Win-Debloat

## 📖 Description
**Win-Debloat** is a professional-grade Windows 10/11 optimization framework tailored for power users, gamers, and system administrators. It streamlines the removal of pre-installed bloatware, hardens system privacy by disabling invasive telemetry, and tunes performance settings—all while prioritizing **safety** and **reversibility** via encrypted snapshots.

## 🛡️ The Philosophy
Win-Debloat was born from a simple frustration: Windows optimization scripts are often **opaque**, **destructive**, and **outdated**.

We built Win-Debloat to be the **"Gold Standard"**:
1.  **Transparency**: Every tweak is visible in the code. No compiled binaries (in Standard edition).
2.  **Safety**: We use official Microsoft APIs (PowerShell, DISM, Group Policy) rather than hacking registry keys blindly.
3.  **Modernity**: Built strictly for **PowerShell 7.6+**, leveraging `clean` blocks, parallel loops, and improved security.
4.  **Performance**: O(N) regex-based processing, O(1) batch service queries, and modern collection handling.

## 📊 v1.5.0 at a Glance
- **30** registered modules
- **138** exported functions
- **Full reversibility**: every tweak has a revert counterpart; value-level DPAPI-encrypted snapshots before any change
- **Preview before apply**: profiles show a read-only action plan and require confirmation
- Pester compliance suite + PSScriptAnalyzer enforced in CI (100% pass rate)
- **0** PSScriptAnalyzer errors
- **11** DNS providers with native Windows 11 DoH encryption
- **139** bloatware apps (tiered removal)
- **5** service optimization presets

## 👥 The Team
**Lead Maintainer:** [Tomy Tate](https://github.com/tomytate)

## 📜 License
Win-Debloat is open-source software licensed under the **MIT License**.
You are free to use, modify, and distribute it, provided you give credit to the original authors.

## 🏗️ Tech Stack
*   **Language**: PowerShell 7.6+
*   **GUI**: Windows Presentation Foundation (WPF) / XAML
*   **TUI**: TrueColor terminal rendering (24-bit ANSI)
*   **Config**: YAML profiles with schema validation
*   **Testing**: Pester 5/6 + PSScriptAnalyzer
*   **Build**: Single-file EXE via PS2EXE, Dual-Release architecture
*   **Distribution**: GitHub Releases, Chocolatey

## 🌟 Acknowledgements & Open-Source Credits
Special thanks and gratitude to the open-source community and the following pioneer projects whose research, techniques, and ideas contributed to Win-Debloat:
*   **Chris Titus Tech ([`winutil`](https://github.com/ChrisTitusTech/winutil))**: Inspiring the asynchronous Runspace WPF threading architecture, multi-provider package hub, and native Windows 11 DNS-over-HTTPS (DoH) configuration.
*   **Raphire ([`Win11Debloat`](https://github.com/Raphire/Win11Debloat))**: Windows 11 24H2/25H2 Copilot+ AI disablement research, live system state inspection, and safe Explorer restart loops.
*   **farag2 ([`Sophia-Script-for-Windows`](https://github.com/farag2/Sophia-Script-for-Windows))**: Task Scheduler telemetry whitelist strategies, GPO policy registry patterns, and mock verification techniques.
*   **AtlasOS / ReviOS Team**: MMCSS multimedia network scheduling latency research and hardware-aware CPU topology profiling.
*   **Massgravel ([`MAS`](https://github.com/massgravel/Microsoft-Activation-Scripts))** & **LeDragoX**: Windows activation helpers and debloat optimization benchmarks.
