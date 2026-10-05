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

## 📊 v1.7.0 at a Glance
- **30** registered modules
- **297** exported functions (plus 337 backward-compatible aliases)
- **11-Vector 100-Point Privacy Scoring Engine** with dynamic A–F grading
- **Asynchronous 60 FPS WPF Cockpit GUI & Spectre ANSI TUI**: STA background runspace pump, 16ms message dispatcher, live cancellation, in-window modal visual diff overlay (`modalDiffOverlay`), 5-card live telemetry (DirectStorage BypassIO), Alternate Screen Buffer (DECSET 1049), atomic frame rendering (DECSET 2026), 8x sub-character progress, and Braille spinners
- **Triple-Layer Disaster Recovery**:
  - *Layer 1*: Native CIM (`root\default:SystemRestore`) VSS System Restore Point with 24-hr frequency bypass (`SystemRestorePointCreationFrequency = 0`).
  - *Layer 2*: Cryptographic DPAPI-encrypted state snapshot (`.clixml`) with lightweight JSON metadata sidecars (`meta.json`).
  - *Layer 3*: Standalone UTF-16LE `rollback.reg` with companion zero-dependency `rollback.cmd` for offline recovery in WinRE Command Prompt.
  - *Visual State Diff Viewer*: Colorized interactive diff inspector in both TUI (`Show-WinDebloatDiffViewer`) and GUI.
- **Universal Zero-Friction Smart Bootstrapper**: Double-clicking `Run.bat` or `Win-Debloat.exe` autodetects PowerShell 7+ and falls back seamlessly to native Windows PowerShell 5.1 (`deploy\Deploy-WinDebloat.ps1`) with zero prerequisites.
- **Network Security & Firewall Loopback Guard**: `Test-IsSafeExternalIp` RFC 1122/6890/1918 filter protecting localhost/loopback/private IP blocking + 82 verified offline telemetry endpoints.
- **Declarative Essential Apps Catalog**: Curated `config/apps.yaml` schema with Winget integration, `Get-WinDebloatAppCatalog`, and `Install-WinDebloatAppCatalog`.
- **Enterprise Deployment**: Standalone headless Intune / OOBE Shift+F10 deployment (`deploy/Deploy-WinDebloat.ps1`), custom Intune detection (`deploy/Detect-WinDebloat.ps1`), and zero-binary `Run.bat` launcher
- **Enterprise Security**: SMB Client Hardening, NTLMv2 Enforcement, SMB NTLM Relay Blocking, Windows Protected Print (RFC 8011), Sudo Isolation, BitLocker XTS-256
- **Next-Gen Hardware Tuning**: AMD Dual-CCD X3D Core Parking, Intel Thread Director Heterogeneous Scheduling, Low-Latency Kernel Timers, Server Native NVMe Stack, ReFS Dev Drive, DirectStorage 1.2+ BypassIO, TCP CUBIC/BBR
- **Test Integrity**: Full Pester compliance suite enforced in CI (**100% pass rate, 392/392 tests passed**, 0 failures, 0 skipped)
- **0** PSScriptAnalyzer errors and **100% 5-way AST parity** across all layers
- **11** DNS providers with native Windows 11 DoH encryption
- **139** bloatware apps (tiered removal)
- **5** service optimization presets with WSL2 / Windows Hello runtime protection
- **Supply Chain Security**: SPDX 2.3 JSON SBOM + SLSA Level 3 Build Provenance + Dual-Layer Authenticode Signing

## 👥 The Team
**Lead Maintainer:** [Tomy Tate](https://github.com/tomytate) (Sole Author & Architect)

## 📜 License
Win-Debloat is open-source software licensed under the **MIT License**.
You are free to use, modify, and distribute it, provided you give credit to the original author.

## 🏗️ Tech Stack
*   **Language**: PowerShell 7.6.6+ LTS / Windows PowerShell 5.1
*   **GUI**: Windows Presentation Foundation (WPF) / XAML
*   **TUI**: TrueColor terminal rendering (24-bit ANSI)
*   **Config**: YAML profiles with deep inheritance (`extends:`) and conditional `when:` gates
*   **Testing**: Pester 5/6 + PSScriptAnalyzer + 5-Way AST Parity
*   **Build**: Dual-Layer Roslyn-compiled launcher executables (x64 / ARM64) + Zero-Binary `Run.bat`
*   **Supply Chain**: SPDX 2.3 JSON SBOM (`win-debloat-sbom.spdx.json`)
*   **Distribution**: GitHub Releases, WinGet (TomyTate.WinDebloat), Chocolatey, PowerShell Gallery
