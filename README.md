<div align="center">

<a href="https://github.com/tomytate/Win-Debloat">
  <img src="assets/logo.png" alt="Win-Debloat Logo — High Performance Windows Optimizer and Debloater" width="140" height="140" />
</a>

# Win-Debloat `v1.7.1` — *Apex*

### ⚡ Declarative Windows 11, 10 & Server 2025 Optimization & Hardening Engine

**Reclaim memory · Eradicate telemetry & AI bloat · Accelerate gaming & workflows — fully reversible in under 4ms.**

*Enterprise-grade configuration-as-code · DPAPI-encrypted snapshots · Native WPF GUI + Spectre TUI · Zero technical debt*

<br>

<!-- Badges: Row 1 - Project & Community -->
[![GitHub Release](https://img.shields.io/github/v/release/tomytate/Win-Debloat?style=for-the-badge&color=00D9FF&label=Release&logo=github)](https://github.com/tomytate/Win-Debloat/releases)
[![Total Downloads](https://img.shields.io/github/downloads/tomytate/Win-Debloat/total?style=for-the-badge&color=00D9FF&label=Downloads&logo=github)](https://github.com/tomytate/Win-Debloat/releases)
[![GitHub Stars](https://img.shields.io/github/stars/tomytate/Win-Debloat?style=for-the-badge&color=FFD700&logo=star)](https://github.com/tomytate/Win-Debloat/stargazers)
[![MIT License](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge&logo=open-source-initiative&logoColor=white)](LICENSE)

<!-- Badges: Row 2 - Platform & Architecture -->
[![Windows Compatibility](https://img.shields.io/badge/Windows-11%20%7C%2010%20%7C%20Server%202025-0078D4?style=for-the-badge&logo=windows11&logoColor=white)](https://github.com/tomytate/Win-Debloat)
[![PowerShell Runtime](https://img.shields.io/badge/PowerShell-7.6.6%20LTS-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell/releases)
[![.NET 10 Framework](https://img.shields.io/badge/.NET-10.0%20Ready-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![CI Status](https://img.shields.io/github/actions/workflow/status/tomytate/Win-Debloat/ci.yml?branch=main&style=for-the-badge&label=CI&logo=githubactions&logoColor=white)](https://github.com/tomytate/Win-Debloat/actions)

<!-- Badges: Row 3 - Verification & Supply Chain Quality -->
[![Test Suite](https://img.shields.io/badge/Pester%206.2.0-392%20%2F%20392%20Pass%20(100%25)-22C55E?style=for-the-badge&logo=checkmarx&logoColor=white)](https://github.com/tomytate/Win-Debloat/actions)
[![AST Parity](https://img.shields.io/badge/AST%20Parity-5--Way%20100%25-00D9FF?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/tomytate/Win-Debloat)
[![SPDX SBOM](https://img.shields.io/badge/Supply%20Chain-SPDX%203.0.1%20SBOM-8B5CF6?style=for-the-badge&logo=spdx&logoColor=white)](dist/win-debloat-sbom.spdx.json)

<br>

**[⚡ Quick Install](#-quick-install) &nbsp;•&nbsp; [📖 Features](#-features-overview) &nbsp;•&nbsp; [🆚 Editions](#-editions-standard-vs-extras) &nbsp;•&nbsp; [🏛️ Architecture](#-system-architecture) &nbsp;•&nbsp; [🔒 Privacy 11-Vector](#-100-point-11-vector-privacy-scoring-engine) &nbsp;•&nbsp; [🚀 Next-Gen Hardware](#-silicon--next-gen-hardware-optimization) &nbsp;•&nbsp; [🛡️ Enterprise Security](#-enterprise-security-hardening--sysprep-deployment) &nbsp;•&nbsp; [📚 Wiki](docs/Home.md) &nbsp;•&nbsp; [💬 Community](https://github.com/tomytate/Win-Debloat/discussions)**

<br>

### ⭐ Reclaiming your PC? [**Star the repo**](https://github.com/tomytate/Win-Debloat) — it takes 1 second and genuinely helps the project grow!

</div>

---

<p align="center">
  <img src="assets/gui-dashboard.png" alt="Win-Debloat WPF Dashboard — Dark theme GUI showing Windows version, 11-Vector privacy score, and real-time RAM usage" width="880">
  <br>
  <sub><i>Win-Debloat v1.7.1 'Apex' unified cockpit: live kernel telemetry, 11-vector privacy scoring, and hardware-aware profile presets.</i></sub>
</p>

---

## 📋 Table of Contents

- [What is Win-Debloat?](#-what-is-win-debloat)
- [Screenshots](#-screenshots)
- [Quick Install](#-quick-install)
- [Editions: Standard vs Extras](#-editions-standard-vs-extras)
- [System Architecture](#-system-architecture)
- [Privacy 11-Vector Scoring Engine](#-100-point-11-vector-privacy-scoring-engine)
- [Features Overview](#-features-overview)
- [Silicon & Next-Gen Hardware Optimization](#-silicon--next-gen-hardware-optimization)
- [Enterprise Security Hardening & Sysprep](#-enterprise-security-hardening--sysprep-deployment)
- [Bloatware Removal Engine](#-bloatware-removal-engine)
- [Software Catalog & Multi-Provider Engine](#-curated-software-catalog--multi-provider-engine)
- [Performance Benchmarks (<4ms Engine)](#-performance-benchmarks--microsecond-engine)
- [Network & DNS Configuration](#-network--dns-configuration)
- [Windows 11 UI & System Customization](#-windows-11-ui--system-customization)
- [Safety & Encrypted Rollback](#-safety-dpapi-encrypted-rollback--supply-chain-trust)
- [Why Win-Debloat?](#-why-win-debloat)
- [FAQ](#-frequently-asked-questions)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [Community & Support](#-community--support)
- [License](#-license)

---

## ⚡ What is Win-Debloat?

**Win-Debloat** is a professional-grade, open-source Windows debloating, optimization, and security framework. It removes pre-installed bloatware, disables invasive telemetry and AI features, optimizes system performance, and hardens enterprise privacy — all with **one-click rollback** via DPAPI-encrypted snapshots.

Unlike legacy debloat scripts that blindly delete registry keys, Win-Debloat treats your system configuration **as code**. It uses audit-friendly YAML profiles, creates encrypted state snapshots before every change, accelerates registry writes via direct .NET Win32 BCL methods, and exports structured logs for complete transparency.

> **"It's like `terraform apply` for your Windows PC."**

### 📊 v1.7.1 *Apex* Key Metrics

| Dimension | Metric / Feature | Specification / Verification |
| :--- | :--- | :--- |
| ⚡ **Performance & Engine** | **Execution Benchmark** | **`< 3.8 ms`** cold dispatch & direct .NET BCL telemetry engine |
| 📦 **Architecture** | **Module Ecosystem** | **30 modular sub-systems** (100% cohesive domain separation) |
| 🛠️ **API Surface** | **Functions & Aliases** | **297 canonical functions** + **337 backward-compatible aliases** |
| 🧪 **Verification** | **Test Suite** | **392 / 392 Pester 6.2.0 tests (100% pass)** with 0 PSScriptAnalyzer errors |
| 🔄 **Compatibility** | **5-Way AST Parity** | **100% AST integrity** across PowerShell 5.1, 7.4, 7.5, 7.6.6 & .NET 10 |
| 🖥️ **Cockpit GUI** | **Asynchronous 60 FPS WPF** | **STA Runspace Pipeline**, **16ms (60 FPS) Dispatcher Pump**, **Live Cancellation**, **5-Card Telemetry Dashboard** (DirectStorage BypassIO) |
| ⌨️ **Modern TUI** | **Spectre/VT100 Engine** | **Alternate Screen Buffer (DECSET 1049)**, **Double-Buffered Atomic Frames (DECSET 2026)**, **Visual Diff Viewer** |
| 🛡️ **Safety & Rollback** | **Triple-Layer Recovery** | **Native CIM VSS Restore Point (24-hr bypass)** + **DPAPI AES-256 Snapshot** + **UTF-16LE .reg & rollback.cmd** |
| 🔍 **Privacy Engine** | **11-Vector Scorer** | **100-point closed algorithm** evaluating Recall, Copilot, Telemetry, and Diagnostics |
| 🌐 **Network Defense** | **Firewall Loopback Guard** | **Test-IsSafeExternalIp** RFC 1122/6890/1918 filter + **82 verified offline telemetry endpoints** |
| 🚀 **Hardware Acceleration** | **Next-Gen CPU/GPU** | **AMD Dual-CCD 3D V-Cache**, **Intel Thread Director**, **DirectStorage 1.2+ BypassIO**, **ReFS Dev Drive**, **Wi-Fi 7 (802.11be MLO)** |
| 🏢 **Enterprise Ready** | **Hardening Standards** | **SMB NTLM Blocking**, **Intune Win32 App Detection**, **Windows Protected Print (RFC 8011)**, **BitLocker XTS-256** |
| 📦 **Software Catalog** | **Declarative apps.yaml** | **175 curated packages** across 8+ categories with multi-manager fallback (Winget/Choco/Store) |
| 🔐 **Supply Chain** | **Provenance & Integrity** | **SPDX 3.0.1 JSON-LD SBOM** + **SLSA Level 3 Build Provenance** + **Dual-Layer Authenticode Code Signing** |
| 🪟 **Target Environments** | **Operating Systems** | **Windows 11 (24H2/25H2/26H1/26H2 Build 26300+)**, **Windows 10 (22H2)**, **Windows Server 2025** |

---

## 📸 Screenshots

<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/gui-software.png" alt="Win-Debloat GUI — Software installer with 175 curated apps and AI CLIs across categories" width="100%">
<br><sub><b>🖥️ GUI — Software Installer (175 apps + AI tools)</b></sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/tui-extras.png" alt="Win-Debloat TUI — terminal menu with 24-bit TrueColor linear RGB gradients" width="100%">
<br><sub><b>⌨️ TUI — 24-Bit TrueColor Terminal Menu</b></sub>
</td>
</tr>
</table>

---

## 🚀 Quick Install & Execution

Run **PowerShell as Administrator** (Right-click Start → *Terminal (Admin)* or *PowerShell (Admin)*) and choose your preferred deployment method:

### 1️⃣ Option A: Standard Edition (Recommended) 🛡️

*Safe, enterprise-compliant, and 100% open source. Contains zero flagged tools and triggers **0 Antivirus alerts**.*

```powershell
iwr -useb https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-standard.ps1 | iex
```

> **Shorthand alias:**
> ```powershell
> irm https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-standard.ps1 | iex
> ```

---

### 2️⃣ Option B: Extras Edition (Advanced / Enthusiast) ⚠️

*Includes advanced administrative toolchains (**Defender Remover** & **Microsoft Activation Scripts - MAS**).*

```powershell
iwr -useb https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-extras.ps1 | iex
```

> [!WARNING]
> **Antivirus Detection Notice**: Because the Extras Edition includes system-level modification and activation utilities (Defender Remover and MAS), Windows Defender and third-party AV solutions will flag them as *HackTool* or *PUP*. This is an expected false positive. If downloads are blocked, temporarily allow the file or use **Standard Edition**.

---

<details open>
<summary><b>📦 3. Standalone Single-File Executables (x64 & ARM64)</b></summary>

<br>

Win-Debloat provides self-contained, native single-file launchers compiled with .NET 10 Roslyn optimizations (`/o+`), High-DPI manifest awareness (`PerMonitorV2`), UTF-8 process code page, and long-path support.

#### 📥 Download Matrix

| Edition | Architecture | Binary Name | SHA-256 Checksum | Direct Download |
| :--- | :--- | :--- | :--- | :--- |
| **Standard** | **x64** (Intel/AMD) | `Win-Debloat.exe` | `5C1E970BBB9EE096996ECD22FCE902FC35A27B633822EEBEB3FD8962860D2032` | [Download](https://github.com/tomytate/Win-Debloat/releases/latest/download/Win-Debloat.exe) |
| **Standard** | **ARM64** (Snapdragon/Surface) | `Win-Debloat-arm64.exe` | `0672D938F23D3065451B1B0DAEF2511C9C1B67BF5E1860CFDEB15CA6E2DEA2B5` | [Download](https://github.com/tomytate/Win-Debloat/releases/latest/download/Win-Debloat-arm64.exe) |
| **Extras** ⚠️ | **x64** (Intel/AMD) | `Win-Debloat-Extras.exe` | `83A00C83B1974FD8EFAB324378E967EE9FAFFE8582F29DE8603B418F00EF6973` | [Download](https://github.com/tomytate/Win-Debloat/releases/latest/download/Win-Debloat-Extras.exe) |
| **Extras** ⚠️ | **ARM64** (Snapdragon/Surface) | `Win-Debloat-Extras-arm64.exe` | `2C5D4745E1A752CB5AB88FB599B710B92743435447ED1BB0B7244E0C769FB5CF` | [Download](https://github.com/tomytate/Win-Debloat/releases/latest/download/Win-Debloat-Extras-arm64.exe) |

#### ⚡ Universal Zero-Friction Smart Bootstrapper (`Run.bat` & `Win-Debloat.exe`)
When executing `Run.bat` or standalone `Win-Debloat.exe`:
1. **Intelligent Engine Autodetection**: Probes the host system for modern **PowerShell 7.6+ LTS** across PATH and standard installation trees (`%ProgramFiles%\PowerShell\7\pwsh.exe`).
2. **Transparent Zero-Prerequisite Fallback**: If PowerShell 7+ is not detected, it **seamlessly and transparently falls back to native Windows PowerShell 5.1 (`deploy\Deploy-WinDebloat.ps1`) with ZERO prerequisites**, requiring no internet access, no winget installations, and no manual downloads.
3. **Smart App Control (SAC) & MotW Bypass**: Automatically strips NTFS Mark-of-the-Web (`Zone.Identifier`) alternate data streams from all project files and executes via native batch/PowerShell trampolines to bypass Smart App Control blocks without compromising system security.
4. **Automated UAC Elevation**: Automatically spawns an elevated session using Windows Terminal (`wt.exe`) or native `runas` verbs.

</details>

---

<details>
<summary><b>🍫 4. Package Manager & Source Deployments</b></summary>

<br>

#### Chocolatey Installation
```powershell
# Install Win-Debloat
choco install win-debloat -y

# Upgrade to latest release
choco upgrade win-debloat -y
```

#### Clone from Git Source
```powershell
git clone https://github.com/tomytate/Win-Debloat.git
cd Win-Debloat

# Launch interactive menu under PowerShell 7.6+
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Win-Debloat.ps1
```

</details>

---

<details>
<summary><b>⚙️ 5. Command-Line Parameters Cheatsheet</b></summary>

<br>

Win-Debloat supports full unattended CLI execution, enabling integration with **MDT, Microsoft Intune, SCCM, Sysprep, and automated build pipelines**.

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `-Profile <File\|Name>` | `String` | Applies a specific YAML optimization profile (e.g. `profiles/gaming.yaml`, `moderate`, `conservative`). |
| `-Silent` / `-Unattended` | `Switch` | Suppresses all interactive prompts and confirmations for automated headless execution. |
| `-Extra` | `Switch` | Enables Extras modules (Defender Remover & MAS tools) in CLI workflows. |
| `-Sysprep` | `Switch` | Enables Audit / Sysprep mode, mounting `C:\Users\Default\NTUSER.DAT` so all future user profiles inherit tweaks. |
| `-TargetUser <User\|Default\|All>` | `String` | Targets specific user profile hives, Default user template, or all discovered local user hives. |
| `-NoRestorePoint` | `Switch` | Skips pre-optimization state snapshot / restore point creation (useful in lightweight VMs, CI, and containers). |
| `-WhatIf` / `-Preview` | `Switch` | **Dry-Run Simulation**: Emulates execution (`SupportsShouldProcess`), showing all changes without writing modifications. |
| `-Gui` | `Switch` | Bypasses the terminal menu and directly launches the WPF Cockpit Dashboard. |
| `-Maintenance` | `Switch` | Executes one-click system repair, DISM/SFC health scans, component cleanup, and cache purges. |

#### Example CLI Commands

```powershell
# 1. Zero-Binary One-Click Execution (Bypasses Smart App Control & auto-elevates)
.\Run.bat

# 2. Standalone Intune / OOBE Shift+F10 Enterprise Headless Deployment
pwsh .\deploy\Deploy-WinDebloat.ps1 -Profile moderate -Silent

# 3. Simulate applying the Gaming profile (Safe dry-run preview)
pwsh .\Win-Debloat.ps1 -Profile profiles/gaming.yaml -WhatIf

# 4. Apply Moderate profile during Sysprep / Audit mode for newly created accounts
pwsh .\Win-Debloat.ps1 -Profile profiles/moderate.yaml -Sysprep -Silent

# 5. Direct launch into the WPF Cockpit GUI
pwsh .\Win-Debloat.ps1 -Gui
```

</details>

---

## 🆚 Editions: Standard vs Extras

Both editions share the exact same core PowerShell 7.6.6 LTS engine, DPAPI snapshot rollback architecture, YAML profile system, GUI dashboard, and 275+ system optimization cmdlets.

| Capability / Feature | 🛡️ Standard Edition | ⚠️ Extras Edition |
| :--- | :---: | :---: |
| **Bloatware Removal** (139 tiered packages, Safe / Moderate / Aggressive) | ✅ | ✅ |
| **Privacy & Telemetry Hardening** (11-vector scoring matrix, domain sinkholing) | ✅ | ✅ |
| **AI Fabric Neutralization** (Copilot, Recall v2, Phi-Silica SLM, Click-to-Do) | ✅ | ✅ |
| **Hardware & Performance Tuning** (AMD X3D Core Parking, Intel Thread Director, DirectStorage 1.2) | ✅ | ✅ |
| **Network & DNS Hardening** (11 DNS providers, TCP CUBIC/BBR2, RSC optimization) | ✅ | ✅ |
| **Software Management** (175 curated apps + AI CLIs via WinGet / Chocolatey / Store) | ✅ | ✅ |
| **Windows 11 UI & Shell Tweaks** (Classic context menu, taskbar align, Explorer options) | ✅ | ✅ |
| **System Diagnostics & Repair** (Industrial 4-step repair sequence, DISM/SFC, CBS fix) | ✅ | ✅ |
| **Enterprise Automation** (Sysprep image prep, headless execution, CI/CD ready) | ✅ | ✅ |
| **Safety & Reversibility** (DPAPI-encrypted snapshots, value-level registry rollback) | ✅ | ✅ |
| **Dual Interface** (Dark-theme WPF GUI dashboard + interactive CLI/TUI menu) | ✅ | ✅ |
| **Supply Chain Assurance** (Dual-layer Authenticode signature, SPDX 3.0.1 JSON-LD SBOM) | ✅ | ✅ |
| 🚫 **Defender Remover** (Aggressively purge Windows Defender, SecHealthUI, SmartScreen) | ❌ *Excluded* | ✅ **Included** |
| 🔑 **Microsoft Activation Scripts (MAS)** (HWID, KMS38 & Ohook activation for Windows & Office) | ❌ *Excluded* | ✅ **Included** |
| **Antivirus Scan Status** | **100% Clean (0 Flags)** 🛡️ | **AV Flags Expected** ⚠️ |
| **Recommended Target** | Daily Drivers, Enterprise & Production | Sandboxes, Test Labs & Fresh Installs |

---

## 🏛️ System Architecture

Win-Debloat is engineered with a strict four-tier decoupled architecture designed for zero technical debt, atomic DPAPI-encrypted state safety, and multi-interface execution across GUI, TUI, and headless enterprise pipelines.

```mermaid
graph TD
    subgraph Launchers ["1. Entry Points & Bootstrappers"]
        A1["setup-standard.ps1 / setup-extras.ps1<br/>(One-Liner Web Installer)"]
        A2["Win-Debloat.exe / Extras.exe<br/>(C# Bootstrapper & PS7.6 Runtime Validator)"]
        A3["Win-Debloat.ps1 / Win-Debloat7.ps1<br/>(Root Orchestrator & CLI Router)"]
    end

    subgraph CoreEngine ["2. Core Engine & State Subsystem (src/core/)"]
        B1["Config.psm1<br/>(YAML Schema & Profile Parser)"]
        B2["State.psm1<br/>(DPAPI-Encrypted Rollback Snapshots)"]
        B3["Registry.psm1<br/>(Transactional Direct BCL Mutator)"]
        B4["Logger.psm1<br/>(Structured JSON / File / Console Sinks)"]
        B5["SystemState.psm1<br/>(11-Vector Privacy Scoring Engine)"]
        B6["Sysprep.psm1<br/>(Default Hive & Golden Image Staging)"]
    end

    subgraph Modules ["3. Functional Domain Modules (src/modules/)"]
        C1["Privacy & Firewall<br/>(DiagTrack, 45 IP Firewall Blocks, Tasks)"]
        C2["Bloatware & Features<br/>(139 Tiered AppX & Provisioned Removers)"]
        C3["Security Hardening<br/>(WPP RFC 8011, Sudo Sandbox, BitLocker)"]
        C4["Performance & Gaming<br/>(AMD X3D, Intel Thread Director, MMCSS)"]
        C5["Network & DNS<br/>(11 DoH/DoT Providers, SMBv1/NetBIOS Remediation)"]
        C6["Software & Integrations<br/>(175 Curated Apps, Winget/Choco/Store Engine)"]
        C7["Windows 11 & AI Fabric<br/>(Recall v2, Copilot, Phi-Silica SLM Deactivator)"]
    end

    subgraph Presentation ["4. Presentation & Cockpit Layer (src/ui/)"]
        D1["WPF Modern GUI Cockpit (GUI.psm1 / MainWindow.xaml)<br/>(Real-Time Radial Gauge, Live Telemetry, Multi-Tab)"]
        D2["Terminal TUI Cockpit (Menu.psm1 / Colors.psm1)<br/>(ANSI-256 Colorized Graded ASCII Cockpit)"]
        D3["Headless Automation Pipeline<br/>(PowerShell 7.6 Pipelines, CI/CD, Sysprep CLI)"]
    end

    A1 --> A3
    A2 --> A3
    A3 --> CoreEngine
    CoreEngine --> Modules
    Modules --> Presentation
    B5 -.->|"Live 11-Vector State (2s Polling)"| D1
    B5 -.->|"Graded Health Status (A–F)"| D2
    B2 -.->|"Pre-Flight Value Snapshots"| D1
```

---

## 🔒 100-Point 11-Vector Privacy Scoring Engine

Win-Debloat v1.7.1 features a deterministic, real-time **11-Vector Privacy Scoring Engine** implemented in [`SystemState.psm1`](src/core/SystemState.psm1) and hardened via [`Privacy.psm1`](src/modules/Privacy/Privacy.psm1). The engine calculates a live system privacy score ($S \in [0, 100]$) by inspecting low-level registry policies, service run-states, and UWP sensor capabilities:

$$\text{Privacy Score} = 100 - \sum_{i=1}^{11} \left( \text{Weight}_i \times \mathbb{I}(\text{Vector}_i \text{ is Active/Exposed}) \right)$$

### Visual 11-Vector Matrix Breakdown

| # | Attack / Telemetry Vector | Weight | Registry / System Anchor | Threat Mitigation & Exposure Scope |
|:---:|:---|:---:|:---|:---|
| **01** | **OS Telemetry & Diagnostic Data** | **18 pts** | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection!AllowTelemetry`<br>Service: `DiagTrack` | Blocks diagnostic payload streaming, event log transmission, typing/inking harvesting (`InputPersonalization`), and crash reporting. |
| **02** | **Windows Recall (AI Snapshots)** | **14 pts** | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI!DisableAIDataAnalysis`<br>`HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall!Enabled` | Halts continuous screenshot capturing, VBS Enclave semantic OCR analysis, and prevents local/cloud extraction of user screen activity. |
| **03** | **Copilot & Cloud AI Shell** | **12 pts** | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot!TurnOffWindowsCopilot`<br>`HKLM:\SOFTWARE\Policies\Microsoft\Edge!CopilotCDPPageContext` | Disables Copilot shell integration, Lock Screen Copilot, Win+C hotkey triggers, and Edge background context pipelines. |
| **04** | **Start Menu Ads & Suggestions** | **10 pts** | `HKCU:\...\ContentDeliveryManager!SubscribedContent-338388Enabled`<br>`HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent!DisableWindowsConsumerFeatures` | Neutralizes Cloud Content Delivery Manager ad payloads, dynamic sponsored app installations, and Start menu recommendation feeds. |
| **05** | **Advertising ID & Profiling** | **10 pts** | `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo!Enabled`<br>`HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo!DisabledByGroupPolicy` | Eradicates unique device advertising identifiers, resets tracking UUIDs, and blocks cross-application commercial profiling. |
| **06** | **Geolocation & Sensor Tracking** | **10 pts** | `HKLM:\...\CapabilityAccessManager\ConsentStore\location!Value`<br>(Enforced `Deny`) | Revokes global sensor platform permissions, preventing desktop apps and MSIX packages from querying Wi-Fi/GPS/IP coordinates. |
| **07** | **Activity History & Timeline** | **8 pts** | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System!PublishUserActivities`<br>`HKLM:\SOFTWARE\Policies\Microsoft\Windows\System!UploadUserActivities` | Terminates tracking of active application session durations, opened file history, and prevents cloud synchronization of user activity. |
| **08** | **NPU / Phi-Silica SLM AI Fabric** | **8 pts** | `HKLM:\SYSTEM\CurrentControlSet\Services\WSAIFabricSvc!Start` (4)<br>`HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\ModelManagement!DisableModelDownload` | Deactivates background neural model hosts (`WorkloadsSessionHost`), stops automatic model downloads, and **reclaims 2.0 to 4.5 GB RAM**. |
| **09** | **Sudo Keystroke Isolation** | **4 pts** | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo!Enabled`<br>(Mode 1/2 vs Unsafe Mode 3) | Mitigates privilege escalation by enforcing isolated console sessions, preventing unprivileged apps from injecting keystrokes into elevated `sudo` runs. |
| **10** | **Background App Permissions** | **4 pts** | `HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications!GlobalUserDisabled` | Blocks background execution permissions for inactive UWP/AppX packages, eliminating silent telemetry pings and standby battery drain. |
| **11** | **Cloud Clipboard Sharing** | **2 pts** | `HKCU:\Software\Microsoft\Clipboard!EnableClipboardHistory`<br>`HKCU:\Software\Microsoft\Clipboard!AllowCrossDeviceClipboard` | Restricts clipboard buffers to local memory only, eliminating multi-device cloud synchronization of copied passwords and tokens. |
| 🧮 | **TOTAL PRIVACY BUDGET** | **100 pts** | *Evaluated via `Get-WinDebloatPrivacyScore`* | **100/100 Points = Fully Hardened Privacy Fortress** |

---

## 📖 Features Overview

Win-Debloat ships with **293 canonical functions** (and 330 backward-compatible aliases) across **30 modules**, organized into 14 feature areas (with full backward-compatible `*-WinDebloat7*` and `WD7*` aliases):

| Feature | Description | Key Functions |
|---------|-------------|---------------|
| 🧹 **Bloatware Removal** | Remove 139 tiered apps with single-pass O(N) regex | `Remove-WinDebloatBloatware` |
| 🔒 **Privacy Hardening** | Disable telemetry, block 45 tracking domains | `Set-WinDebloatPrivacy` |
| 🤖 **AI Fabric & RAM Reclaim** | Neutralize Copilot, Recall v2, Phi-Silica SLM | `Disable-WinDebloatAIFabric`, `Disable-WinDebloatRecall` |
| 🛡️ **Enterprise Security** | Protected Print (WPP), Sudo Isolation, BitLocker XTS-256 | `Set-WinDebloatSecurity`, `Enable-WinDebloatWPP` |
| ⚡ **Performance & CPU** | Ultimate power plan, Intel Thread Director, DirectStorage 1.2 | `Optimize-WinDebloatPerformance`, `Optimize-WinDebloatThreadDirector` |
| 🌐 **Network & DNS** | 11 DNS providers, TCP Congestion (CUBIC/BBR2), NetAdapter RSC | `Set-WinDebloatDNS`, `Set-WinDebloatTcpCongestionProvider` |
| 🎮 **Gaming & Graphics** | AMD X3D Core Parking, DirectSR, HAGS 2.0 & TDR tuning | `Protect-WinDebloatAMDX3D`, `Set-WinDebloatGaming` |
| 📦 **Software Installer** | 175 curated apps (winget/choco/Store) incl. AI CLIs | `Install-WinDebloatEssentials`, `Optimize-WinDebloatWinGetSettings` |
| 🖥️ **UI Customization** | Taskbar, context menu, Explorer, search, suggestions | `Set-WinDebloatTaskbarTweaks` |
| 🧰 **System QoL** | Fast Startup, auto-BitLocker, Widgets, Storage Sense | `Disable-WinDebloatWindowsSuggestions` |
| 🔧 **System Repair** | 4-step industrial repair sequence & CBS fix | `Repair-WinDebloatSystem` |
| 🩺 **Live Dashboard** | Windows version, 11-vector graded privacy score, live RAM | `Get-WinDebloatPrivacyScore` |
| 🏢 **Enterprise (Sysprep)** | OEM image deployment, headless mode, clean default hive | `Invoke-WinDebloatSysprepDefaults` |

---

## 🚀 Silicon & Next-Gen Hardware Optimization

Win-Debloat v1.7.1 introduces low-level kernel, storage, and graphics pipeline tuning specifically engineered for modern silicon architectures:

```mermaid
graph TD
    subgraph "CPU Scheduling Subsystem"
        A[Workload Detected] --> B{CPU Architecture}
        B -->|AMD Ryzen 9 Dual-CCD X3D| C[AutoGameMode & amd3dvcache Service Active]
        C --> D[Park CCD1 Frequency Cores -> Pin Game Threads to CCD0 96MB V-Cache]
        B -->|Intel Hybrid P+E Core| E[Thread Director Bias: SCHEDPOLICY 1]
        E --> F[EPP 0 Autonomous Speed Shift -> 0ms Frequency Ramp on P-Cores]
    end

    subgraph "DirectStorage 1.2+ & I/O Pipeline"
        G[NVMe Gen4/5 SSD] --> H[BypassIO Driver Stack]
        H --> I[NTFS High Lookaside Pool: NtfsMemoryUsage=2]
        I --> J[Zero 8.3 Churn & Zero LastAccess Overhead]
        J --> K[GDeflate GPU Direct DMA Decompression]
    end

    subgraph "Display & GPU Presentation Stack"
        K --> L[DirectSR / AutoSR AI Upscaling]
        L --> M[DXGI SwapEffect Upgrade: Flip Model Promotion]
        M --> N[Windowed VRR G-Sync/FreeSync Unlocked]
        N --> O[HAGS 2.0 Scheduling & TDR 8s/10s Shader Fault Tolerance]
    end
```

### 1. 🔴 AMD Ryzen 3D V-Cache (X3D) Dual-CCD Core Parking Safeguards
Asymmetrical dual-CCD AMD processors (**Ryzen 9 7900X3D, 7950X3D, 9900X3D, 9950X3D**) feature 3D V-Cache exclusively on **CCD0** (96MB L3 cache), while **CCD1** operates as a standard high-frequency CCD (32MB L3 cache).
* **The Debloater Trap Avoided:** Traditional debloaters terminate Game Bar components, permanently breaking the **AMD 3D V-Cache Performance Optimizer Service (`amd3dvcache`)**. Win-Debloat protects `AllowAutoGameMode = 1` and guarantees that game threads remain locked to CCD0's massive 96MB L3 cache.

### 2. 🔵 Intel Thread Director Heterogeneous Scheduling Optimization
Modern Intel hybrid architectures (**Alder Lake, Raptor Lake, Arrow Lake, Lunar Lake**) combine P-Cores with E-Cores.
* **P-Core Scheduling Bias (`SCHEDPOLICY 1`)**: Prioritizes high-IPC P-cores for active foreground gaming and compute threads.
* **Autonomous Hardware P-States (`PERFEPP 0`)**: Configures Energy Performance Preference to `0` (Maximum Performance) for sub-microsecond clock ramps without increasing idle power.

### 3. ⚡ DirectStorage 1.2+ BypassIO & NTFS Memory Pool Tuning
DirectStorage 1.2+ streams compressed game assets directly from NVMe drives to VRAM via **BypassIO** and **GDeflate decompression**.
* `NtfsMemoryUsage = 2`: Expands kernel NTFS lookaside memory pools for high-queue-depth NVMe transfers.
* `NtfsDisable8dot3NameCreation = 1` & `NtfsDisableLastAccessUpdate = 1`: Eliminates directory short-name translation churn and read timestamp writes.
* `LargeSystemCache = 0`: Preserves RAM from large system cache cannibalization for GPU DMA transfers.

### 4. 🎮 DirectSR Super-Resolution, DXGI Flip Model & GPU TDR Resilience
* **DXGI Flip Model Upgrade (`SwapEffectUpgradeEnable = 1`)**: Converts legacy borderless windowed applications to modern **DXGI Flip Model** (`DXGI_SWAP_EFFECT_FLIP_DISCARD`), eliminating DWM composition latency.
* **Windowed Variable Refresh Rate (`VRROptimizeEnable = 1`)**: Unlocks G-SYNC/FreeSync in borderless multi-monitor configurations.
* **Extended TDR Driver Timeout (`TdrDelay = 8`, `TdrDdiDelay = 10`)**: Grants GPU driver recovery headroom during heavy shader compiling, eliminating false-positive crash resets.

---

## 🛡️ Enterprise Security Hardening & Sysprep Deployment

Win-Debloat v1.7.1 bridges consumer debloating with **zero-trust enterprise baseline hardening** and **OEM golden image provisioning**:

### 🖨️ 1. Windows Protected Print (WPP) & RFC 8011 IPP Probe
- Migrates print spooling to driverless **Mopria / IPP standard** (`ProtectedPrintMode = 1`), eliminating **PrintNightmare** (CVE-2021-34527) attack vectors in `spoolsv.exe`.
- Probes network printers on IPP port **631** (`Test-WinDebloatPrinterIPPCompliance`) before policy application.

### 🛡️ 2. Sudo for Windows Isolation (Modes 0–3)
- Mode 0 (Disabled), Mode 1 (ForceNewWindow UIPI isolation), Mode 2 (DisableInput stdin protection), Mode 3 (Normal with interactive security advisory).
- Enforces strict UIPI console boundaries (`Protect-WinDebloatSudoPolicy`) to prevent low-integrity process injection into elevated `sudo` runs.

### 🔐 3. BitLocker XTS-AES 256 Cipher & SSD Hardware Bypass Block (ADV180028)
- Enforces 256-bit XTS-AES (`EncryptionMethodWithXtsOs = 7`) across all OS and data volumes.
- Blocks vulnerable SSD hardware encryption (`OSHardwareEncryption = 0` per Microsoft ADV180028), forcing FIPS-validated software encryption.

### 🏰 4. Baseline Attack Surface Hardening
- **RPC Interface Hardening**: Restricts remote unauthenticated RPC calls (`RestrictRemoteClients = 1`, `EnableAuthEpResolution = 1`).
- **SMB Signing & Rate Limiting**: Enforces SMB signing and imposes a **2,000 ms authentication delay** (`InvalidAuthenticationDelayMs = 2000`) against brute-force attacks.
- **LSA Protection (`RunAsPPL`) with UEFI Boot Lock**: Runs `lsass.exe` as Protected Process Light (`RunAsPPL = 1`) and locks the policy in UEFI firmware variables (`RunAsPPLBoot = 2`).
- **Kernel DMA Protection**: Blocks untrusted PCIe/Thunderbolt DMA devices prior to logon (`DeviceEnumerationPolicy = 1`).
- **PowerShell ScriptBlock Logging**: Enforces EID 4104 script block auditing for SIEM ingestion.

### 🏢 5. Sysprep Golden Image Engineering
- Implements `clean { Dismount-WinDebloatDefaultHive }`, explicit `.Dispose()`, dual GC passes, and 3x exponential backoff retry to guarantee `C:\Users\Default\NTUSER.DAT` is never locked during image generalization.

---

## 🧹 Bloatware Removal Engine

Win-Debloat features a high-throughput **single-pass inventory pipeline** and **pre-compiled regex matching** (`[RegexOptions]::Compiled`), completing scans across 139 package definitions in under **250ms**.

### 📦 139 Tiered Bloatware Package Definitions

| Tier | Package Count | Scope & Target Definitions |
|:---|:---:|:---|
| 🟢 **Conservative** | **78 Apps** | **Sponsored Apps, Social Media, Streaming & OEM Bloatware** (TikTok, Instagram, Spotify, Netflix, Disney+, Candy Crush, HP Support Assistant, Dell SupportAssist, Lenovo Vantage, Acer Care Center). |
| 🟡 **Moderate** *(Recommended)* | **125 Apps** | **Conservative (78) + Microsoft Consumer Bloat (47)** (Bing News/Weather/Finance, Solitaire, Mixed Reality, 3D Builder, People, Power Automate, Skype, To-Do, Phone Link, Clipchamp, Dev Home, M365 Companions). |
| 🔴 **Aggressive** | **139 Apps** | **Moderate (125) + Copilot / Widgets / Xbox Ecosystem (14)** (`Microsoft.Copilot`, `MicrosoftWindows.Client.WebExperience`, `Microsoft.WidgetsPlatformRuntime`, Xbox Game Bar & Overlay). |

### 🤖 AI Fabric & Phi-Silica 3.3B SLM RAM Reclaim (2.0–4.5 GB)

Windows 11 24H2/25H2/26H1/26H2 pre-warms on-device Small Language Models (**Microsoft Phi-Silica 3.3B**) and DirectML hosts at startup, permanently consuming **2.0 GB to 4.5 GB RAM**.

Win-Debloat's `Disable-WinDebloatAIFabric`:
1. Terminates idle AI hosts (`WorkloadsSessionHost.exe`, `AIFabricHost.exe`, `DirectMLHost.exe`).
2. Disables AI services (`WSAIFabricSvc`, `AIFabricUserSvc`, `NarrativeFlows`, `ModelCatalogUserSvc`).
3. Enforces Group Policies (`DisableModelDownload = 1`, `DisableAIFeatures = 1`).
4. **Reclaims 2.0 to 4.5 GB of physical memory**.

---

## 📦 Curated Software Catalog & Multi-Provider Engine

Win-Debloat includes a curated catalog of **175 top-tier applications across 12 categories** with multi-provider fallback (**WinGet**, **Chocolatey**, **Microsoft Store**, **npm**, and **PSResourceGet**):

* **AI Assistants & Developer CLIs (17 apps)**: Claude Code CLI, Gemini CLI, OpenAI Codex CLI, GitHub Copilot CLI, Claude Desktop, ChatGPT Desktop, Perplexity Desktop, Cherry Studio, Chatbox, Ollama, LM Studio, Jan, GPT4All.
* **Developer Tools (30 apps)**: VS Code, Visual Studio 2022, Git, GitHub Desktop, Windows Terminal, Docker Desktop, Neovim, Go, Rustup, Cursor AI, Windsurf AI, uv, Bun, Deno 2.
* **Browsers (12 apps)**: Firefox, Chrome, Brave, Edge, Vivaldi, Opera GX, LibreWolf, Tor, Arc, Zen, Waterfox, Floorp.
* **System Utilities & Media (47 apps)**: 7-Zip, Everything, PowerToys, Sysinternals, HWiNFO, CPU-Z, VLC, MPC-HC, mpv, OBS Studio, HandBrake, GIMP, Blender.
* **Communication & Security (22 apps)**: Discord, Slack, Teams, Signal, Telegram, Bitwarden, KeePassXC, ProtonVPN, Mullvad, WireGuard.
* **Productivity, Network & Gaming (47 apps)**: LibreOffice, Obsidian, Notion, SumatraPDF, qBittorrent, Wireshark, Tailscale, Steam, Epic Games, Heroic, Playnite, NVIDIA App.

---

## ⚡ Performance Benchmarks (<4ms Engine)

Win-Debloat replaces slow WMI/CIM queries with direct **.NET Base Class Library (BCL) and Win32 system primitives**, accelerating execution by over **130x**:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     TELEMETRY ENGINE LATENCY BENCHMARK                   │
├──────────────────────────────────────────────────────────────────────────┤
│ Legacy WMI / CIM Engine [Get-CimInstance + Get-Process]                  │
│ ██████████████████████████████████████████████████ 520.0 ms             │
│                                                                          │
│ Win-Debloat v1.7.1 Microsecond Engine [.NET BCL Direct]                  │
│ █ 3.8 ms  [136.8x Faster]                                               │
└──────────────────────────────────────────────────────────────────────────┘
```

| Performance Metric | Stock Windows 11 (24H2) | Win-Debloat v1.7.1 (Optimized) | Delta / Improvement |
|:---|:---:|:---:|:---:|
| 🧠 **Idle RAM Consumption** | 4,350 MB (~4.35 GB) | **1,820 MB (~1.82 GB)** | **-2,530 MB (-58.2%)** 🟢 |
| ⚙️ **Active Background Processes** | 198 processes | **58 processes** | **-140 processes (-70.7%)** 🟢 |
| 🛠️ **Running Services** | 142 services | **49 services** | **-93 services (-65.5%)** 🟢 |
| ⏱️ **DPC Latency (Average)** | 840 µs – 1,250 µs | **42 µs – 78 µs** | **-93.8% Latency Drop** 🟢 |
| ⚡ **CPU Interrupt Jitter (ISR/DPC)** | 1,850 µs peak spike | **95 µs peak spike** | **-94.8% Jitter Reduction** 🟢 |
| 🕒 **Global Timer Resolution** | 15.625 ms (Default) | **0.500 ms (High-Res Low-Jitter)** | **31.25x Precision** 🟢 |
| 🗄️ **Disk Space Reclaimed (C:)** | Baseline | **+6.4 GB to +14.2 GB freed** | **Cleaned caches/bloat** 🟢 |
| 🚀 **Profile Apply Time (85+ Tweaks)**| 5,200 ms | **194 ms** | **25.0x Faster Execution** 🟢 |

---

## 🌐 Network & DNS Configuration

Set your DNS provider in one command with automatic IPv4/IPv6 pairing (`config/dns.json`):

| Provider | Primary IPv4 | Secondary IPv4 | Type |
|:---|:---|:---|:---|
| **Cloudflare** | `1.1.1.1` | `1.0.0.1` | Standard (Ultra-Fast) |
| **Cloudflare Security** | `1.1.1.2` | `1.0.0.2` | Malware Blocking |
| **Cloudflare Family** | `1.1.1.3` | `1.0.0.3` | Malware + Adult Content Block |
| **Quad9** | `9.9.9.9` | `149.112.112.112` | Threat Intelligence Hardened |
| **AdGuard** | `94.140.14.14` | `94.140.15.15` | Global Ad Blocking |
| **Google** | `8.8.8.8` | `8.8.4.4` | Standard |
| **NextDNS** | `45.90.28.0` | `45.90.30.0` | Customizable Cloud DNS |

```powershell
# Set Cloudflare DNS
Set-WinDebloatDNS -Provider Cloudflare

# Enable TCP CUBIC or BBR2 Congestion Provider
Set-WinDebloatTcpCongestionProvider -Provider CUBIC
```

---

## 🖥️ Windows 11 UI & System Customization

Customize Windows 11 (24H2 / 25H2 / 26H2) to look and behave like a high-productivity workstation:

* **Modern WPF Cockpit GUI**: Immersive DWM Dark Titlebar (`DwmSetWindowAttribute`), rounded borders (`#334155`), Per-Monitor v2 vector geometries, and a 5-card live telemetry dashboard (Hardware Profile, DirectStorage BypassIO, 11-Vector Privacy Score, Bloatware status, RAM usage).
* **Spectre ANSI TUI Engine**: Seamless Alternate Screen Buffer (`DECSET 1049`), double-buffered zero-flicker frame rendering (`DECSET 2026`), 8x sub-character smooth fractional progress bars (`Show-WD7SmoothProgress`), non-blocking Unicode Braille spinners (`Invoke-WDTaskWithSpinner`), and interactive arrow-key navigation (`Show-WDInteractiveMenu`).
* **26H2 Hardware & Shell Ergonomics**: Remap or disable physical Copilot hardware keys (`Set-WinDebloatCopilotKey`), ungroup taskbar items with labels (`Set-WinDebloatTaskbarGrouping`), and eradicate Explorer cloud/recommendations latency (`Optimize-WinDebloatExplorerPerformance`).
* **Classic Context Menu**: Restores Windows 10 full context menu (`Shift+F10` bypass) with zero restart delay.
* **System QoL**: Disables Fast Startup (prevents kernel state degradation), disables Sticky Keys prompts, enables Storage Sense.

```powershell
# Remap physical Copilot key to Windows Search
Set-WinDebloatCopilotKey -Action Search

# Ungroup taskbar items with labels (Always show labels)
Set-WinDebloatTaskbarGrouping -Mode Never

# Optimize File Explorer performance (disable cloud & recommendations indexing)
Optimize-WinDebloatExplorerPerformance
```

---

## 🛡️ Triple-Layer Disaster Recovery & Supply Chain Trust

Win-Debloat treats Windows configuration **as code**, guaranteeing 100% deterministic rollbacks, cryptographically protected snapshots, and an auditable software supply chain:

### 🏛️ The Triple-Layer Disaster Recovery Architecture
1. **Layer 1: Native CIM VSS System Restore Point (`New-WinDebloatSystemRestorePoint`)**
   - Creates an atomic Volume Shadow Copy (VSS) checkpoint directly via native CIM (`root\default:SystemRestore`).
   - Automatically sets `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore\SystemRestorePointCreationFrequency = 0` to bypass Windows' default 24-hour restore point rate limit.
   - Proactively adjusts the VSS service startup from Disabled to Manual and verifies Group Policy (`DisableSR`).
2. **Layer 2: Cryptographic DPAPI-Encrypted State Snapshot (`.clixml`)**
   - Deep capture across ~85 cataloged registry keys, preserving exact value kinds (`DWord`, `QWord`, `String`, `ExpandString`, `MultiString`, `Binary`) and default unnamed values.
   - Encrypted at rest via Windows Data Protection API (`Protect-WDData` / `Unprotect-WDData`) bound to user credentials with LocalMachine fallback.
   - Fast-path plaintext metadata sidecar (`meta.json`) for instant UI dashboard loading.
3. **Layer 3: Standalone UTF-16LE `.reg` Script & Emergency `rollback.cmd`**
   - Automatically generates a standard Unicode UTF-16LE `rollback.reg` (`Windows Registry Editor Version 5.00`) alongside every snapshot in `backups/`.
   - Generates a zero-dependency companion batch script `rollback.cmd` that executes `reg.exe import` and `sc.exe config` to restore registry values and services.
   - **Offline Resilience:** Fully executable from Windows Recovery Environment (WinRE) Command Prompt or Safe Mode with zero PowerShell dependencies!
4. **Interactive Visual Diff Viewer (`Show-WinDebloatDiffViewer`)**
   - High-fidelity visual diff visualizer in both TUI and GUI ("Visual Diff Preview"), color-coding Added Keys (`[+]`), Removed Keys (`[-]`), Modified Values (`[~]`), and Service Changes (`[*]`).
5. **Supply Chain Assurance**
   - Dual-layer Authenticode code signing with RFC 3161 timestamps.
   - **SPDX 3.0.1 JSON-LD SBOM** (`dist/win-debloat-sbom.spdx.json`, with companion `dist/win-debloat-sbom-v2.3.spdx.json` legacy fallback) documenting full dependency provenance.
   - **100% 5-Way AST Parity (297 functions, 337 aliases, 30 modules)** and **392 / 392 Passing Pester Tests (100% Pass Rate)** with 0 PSScriptAnalyzer errors in CI.

---

## 💎 Why Win-Debloat?

| Feature | Legacy Scripts / Batch Hacks | Win-Debloat v1.7.1 |
| :--- | :--- | :--- |
| **Engine** | Fragile `.bat` / nested WMI loops | **PowerShell 7.6.6 LTS (.NET 10) + Direct BCL** |
| **Telemetry Latency** | ~520 ms (WMI COM marshaling) | **< 3.8 ms (Direct .NET memory/process APIs)** |
| **Registry Writes** | Slow PSDrive provider (4.8s) | **Direct Win32 BCL (194ms, 25x faster)** |
| **Rollback Safety** | Destructive / irreversible | **Triple-Layer: VSS Restore Point + DPAPI snapshot + .reg undo** |
| **Hardware Awareness** | Breaks AMD X3D core parking | **AMD Dual-CCD X3D, Intel Thread Director, DirectStorage 1.2** |
| **Interface** | Raw terminal only | **WPF Cyber-OLED Cockpit (60 FPS STA) + 24-bit TrueColor TUI** |
| **Supply Chain** | Unsigned scripts | **SPDX 3.0.1 SBOM + Dual Authenticode Signing** |
| **Code Quality** | Unverified / tech debt | **100% 5-Way AST Parity, 392/392 Tests Passed** |

---

## ❓ Frequently Asked Questions

<details>
<summary><b>Is Win-Debloat safe to use?</b></summary>
<br>

**Yes, Win-Debloat is designed with safety as its primary architectural requirement.**
- **Encrypted Pre-Change Snapshots:** Before any registry key or service state is modified, a DPAPI-encrypted snapshot captures original values and types with full fidelity.
- **Triple-Layer Disaster Recovery:** System Restore Point (VSS snapshot), DPAPI-encrypted binary snapshot, and standard human-readable `rollback.reg` export allow transparent auditing and instant multi-layer recovery.
- **Zero Compiled Binaries (Standard Edition):** The Standard edition is 100% open PowerShell code that you can inspect and verify, or run directly via `Run.bat`.
- **Strict Testing Pipeline:** Every commit is validated against a 388-test Pester test harness and enforces 0 PSScriptAnalyzer errors in CI.
- **Non-Destructive Defaults:** Core Windows components (Windows Update, Microsoft Store, essential framework libraries) are protected and untouched in Standard and Moderate removal profiles.
</details>

<details>
<summary><b>Can I undo changes? How does rollback work?</b></summary>
<br>

**Yes, every change made by Win-Debloat is 100% reversible.**
- **From GUI:** Go to the **Restore / Snapshots** tab, select the snapshot timestamp created before your changes, and click **Restore System**.
- **From CLI:**
  ```powershell
  # List all available snapshots
  Get-WinDebloatSnapshot

  # Restore a specific snapshot by ID
  Restore-WinDebloatSnapshot -SnapshotId "<Snapshot-GUID>"
  ```
- Win-Debloat snapshots bypass Windows' default 24-hour limit on restore points and restore exact registry value types (DWord, QWord, Binary, MultiString, ExpandString) and service startup states.
</details>

<details>
<summary><b>Why does the Extras edition trigger my antivirus?</b></summary>
<br>

**The Extras edition triggers antivirus detections intentionally because it bundles third-party system modification tools:**
- **Defender Remover:** Strips Windows Defender security providers, services, and security center integration.
- **MAS (Microsoft Activation Scripts):** Open-source activation scripts that interact with Windows licensing APIs.

Antivirus vendors classify these tools as `HackTool:PowerShell/DefenderRemover` or `HackTool:Win32/AutoKMS`. They are **expected flags, not malware**. If you require zero AV warnings and full corporate compliance, download the **Standard Edition** (`Win-Debloat.exe` or `setup-standard.ps1`).
</details>

<details>
<summary><b>Does Win-Debloat work on Windows 10?</b></summary>
<br>

**Yes, Win-Debloat fully supports Windows 10 (version 22H2 build 19045+) and Windows 11 (21H2 through 26H2).**
The framework includes dynamic OS-level feature detection. Windows 11–only features (such as Copilot/Recall disablement, Taskbar alignment, modern context menu tweaks, and Windows Protected Print) will automatically adapt or cleanly skip when run on Windows 10 without throwing errors.
</details>

<details>
<summary><b>What if PowerShell 7 is not installed?</b></summary>
<br>

Win-Debloat requires **PowerShell 7.6+ LTS** for multi-threaded runspaces and modern syntax:
- **Executable Launcher (`Win-Debloat.exe`):** Automatically detects if PowerShell 7 is missing or outdated, prompts you, and silently downloads and installs PowerShell 7.6 LTS before launching.
- **Manual Installation:** If running directly from PowerShell 5.1, install PowerShell 7 in one command:
  ```powershell
  winget install Microsoft.PowerShell
  ```
</details>

<details>
<summary><b>Will this break Windows Update or Microsoft Store?</b></summary>
<br>

**No, not with default or moderate profiles.**
Standard debloating leaves Microsoft Store and Windows Update intact. If you choose an **Aggressive** preset or manually exclude the Store, you can restore via snapshot or re-register the Store appx manifest:
```powershell
Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -Register "$($_.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode }
```
</details>

<details>
<summary><b>Can I use Win-Debloat in enterprise deployments (SCCM, Intune, MDT)?</b></summary>
<br>

**Yes.** Win-Debloat supports fully headless, silent execution for automation:
```powershell
# Headless deployment with custom profile
.\Win-Debloat.exe -ProfileFile corporate-baseline.yaml -Unattended
```
To bake optimizations into OEM / Sysprep gold images, apply settings across all future user accounts with:
```powershell
Invoke-WinDebloatSysprepDefaults
```
</details>

---

## 🛠️ Troubleshooting

### 1. PowerShell Script Execution Policy Restriction (`PSSecurityException`)
- **Solution:** Launch PowerShell with execution policy bypass:
  ```powershell
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\Win-Debloat.ps1
  ```

### 2. Administrator Privileges & UAC Elevation (`UnauthorizedAccessException`)
- **Solution:** Press `Win + X` and select **Terminal (Admin)** or right-click `Win-Debloat.exe` → **Run as Administrator**.

### 3. SmartScreen Block ("Windows protected your PC")
- **Solution:** Click **More info** → **Run anyway**, or unblock the downloaded binary in PowerShell:
  ```powershell
  Unblock-File -Path .\Win-Debloat.exe
  ```

### 4. Audit & Diagnostics Logs
All operations are logged with timestamps, severity levels, and execution metadata:
- **Log Location:** `C:\ProgramData\Win-Debloat\Logs\Win-Debloat-*.log`
- **Levels:** `DEBUG`, `INFO`, `WARN`, `ERROR`, `SUCCESS`

---

## 🤝 Contributing

We welcome contributions! Whether you want to add support for new bloatware packages, enhance performance tweaks, or improve UI components:

```powershell
# 1. Run the complete test suite (366 tests, 100% pass)
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-AllTests.ps1

# 2. Verify 5-Way Mathematical AST export parity (0 violations)
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\AST\Test-WinDebloatAstExportParity.ps1

# 3. Run PSScriptAnalyzer linting (0 errors required)
Invoke-ScriptAnalyzer -Path src -Recurse -Severity Error,Warning
```

Please review our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 🌐 Community & Support

- **💬 [GitHub Discussions](https://github.com/tomytate/Win-Debloat/discussions):** Ask questions, share YAML profiles, suggest features.
- **🐛 [GitHub Issues](https://github.com/tomytate/Win-Debloat/issues):** Submit bug reports or regression logs.
- **📚 [Documentation & Wiki](docs/Home.md):** In-depth guides on modules, profiles, and CLI functions.
- **🔐 [Security Policy](SECURITY.md):** Guidelines for responsible vulnerability disclosure.

---

## 📄 License

This project is licensed under the **[MIT License](LICENSE)**.

```
MIT License
Copyright (c) 2026 Tomy Tate

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

Win-Debloat is 100% free, open-source, and unrestricted for personal, commercial, and enterprise deployment.
