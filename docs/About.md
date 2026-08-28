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

## 📊 v1.6.0 at a Glance
- **30** registered modules
- **227** exported functions (plus 256 backward-compatible aliases)
- **11-Vector 100-Point Privacy Scoring Engine** with dynamic A–F grading
- **Full reversibility**: every tweak has a revert counterpart; value-level DPAPI-encrypted snapshots before any change
- **Preview before apply**: profiles show a read-only action plan and require confirmation
- **Enterprise Security**: Windows Protected Print (RFC 8011), Sudo Isolation, BitLocker XTS-256
- **Next-Gen Hardware Tuning**: AMD X3D Core Parking, Intel Thread Director, DirectStorage 1.2, TCP CUBIC/BBR2
- Pester compliance suite + PSScriptAnalyzer enforced in CI (100% pass rate, 269/269 tests passed)
- **0** PSScriptAnalyzer errors
- **11** DNS providers with native Windows 11 DoH encryption
- **139** bloatware apps (tiered removal)
- **5** service optimization presets
- **Supply Chain Security**: SPDX 2.3 JSON SBOM + Dual-Layer Authenticode Signing

## 👥 The Team
**Lead Maintainer:** [Tomy Tate](https://github.com/tomytate)

## 📜 License
Win-Debloat is open-source software licensed under the **MIT License**.
You are free to use, modify, and distribute it, provided you give credit to the original authors.

## 🏗️ Tech Stack
*   **Language**: PowerShell 7.6+ LTS
*   **GUI**: Windows Presentation Foundation (WPF) / XAML
*   **TUI**: TrueColor terminal rendering (24-bit ANSI)
*   **Config**: YAML profiles with deep inheritance (`extends:`) and conditional `when:` gates
*   **Testing**: Pester 5/6 + PSScriptAnalyzer + 5-Way AST Parity
*   **Build**: Dual-Layer Roslyn-compiled launcher executables (x64 / ARM64)
*   **Supply Chain**: SPDX 2.3 JSON SBOM (`win-debloat-sbom.spdx.json`)
*   **Distribution**: GitHub Releases, Chocolatey, PowerShell Gallery
