# Installation Guide

Win-Debloat is designed to run on **Windows 10 (22H2+)**, **Windows 11 (23H2 / 24H2 / 25H2 / 26H1 / 26H2)**, and **Windows Server 2025**.

## Prerequisites & Runtime Compatibility

1.  **Operating System**: Windows 10 (22H2+), Windows 11 (23H2 / 24H2 / 25H2 / 26H1 / 26H2 Build 26300+), or Windows Server 2025.
2.  **Administrator Rights**: Administrative elevation is required to modify registry policies, system services, and Appx packages.
3.  **PowerShell Engine Compatibility**:
    *   **Modern Engine (Recommended)**: PowerShell 7.6+ LTS (built on .NET 10) provides highest throughput and parallel runspaces.
    *   **Native Engine (Zero-Prerequisite Fallback)**: Windows PowerShell 5.1 is natively supported via `deploy\Deploy-WinDebloat.ps1`.
    *   **Universal Smart Bootstrapper**: When using `Run.bat` or `Win-Debloat.exe`, the engine automatically detects PowerShell 7+. If absent, it **transparently falls back to native Windows PowerShell 5.1 with ZERO prerequisites**, requiring no internet connection and no manual runtime installations.

---

## ⚡ Method 1: Instant Deploy (Web / Remote)

Open PowerShell **as Administrator** and paste one command:

### Standard Edition 🛡️
Safe, enterprise-compliant, and 100% open source. Contains zero flagged tools.
```powershell
iwr -useb https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-standard.ps1 | iex
```

### Extras Edition ⚠️
Includes **Defender Remover** + **MAS**. Triggers expected antivirus heuristic detections.
```powershell
iwr -useb https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-extras.ps1 | iex
```

---

## 🚀 Method 2: Zero-Binary Local Execution (`Run.bat`)

For downloaded ZIP archives or offline local environments:
1. Double-click `Run.bat` in the root folder (or execute `.\Run.bat` in Terminal/CMD).
2. **Features**:
   - **Universal Smart Bootstrapper**: Detects PowerShell 7+; transparently routes to native Windows PowerShell 5.1 (`deploy\Deploy-WinDebloat.ps1`) if modern PowerShell is not installed.
   - **Bypasses Windows 11 Smart App Control (SAC)**: Avoids untrusted binary blocks by executing purely through native batch and PowerShell scripts.
   - **Unblocks Mark-of-the-Web (MotW)**: Recursively strips NTFS alternate data streams (`Zone.Identifier`) from all project scripts automatically.
   - **UAC Elevation Trampoline**: Automatically requests administrative elevation via Windows Terminal (`wt.exe`) or native PowerShell.

---

## 🏢 Method 3: Enterprise & Intune Headless Deployment

For IT administrators deploying via **Microsoft Intune Win32 Apps**, SCCM, or Windows Setup **OOBE (Shift+F10)**:

```powershell
# Silent unattended deployment with Moderate profile
pwsh -NoProfile -ExecutionPolicy Bypass -File .\deploy\Deploy-WinDebloat.ps1 -Profile moderate -Silent

# Audit / Sysprep mode for Golden Master images
pwsh -NoProfile -ExecutionPolicy Bypass -File .\deploy\Deploy-WinDebloat.ps1 -Profile sysprep -Sysprep -Silent
```

---

## 🍫 Method 4: Chocolatey Package Manager

```powershell
choco install win-debloat
```

---

## 📂 Method 5: Portable Single-File Executables

1.  Go to the **[Releases Page](https://github.com/tomytate/Win-Debloat/releases)**.
2.  Download the **Single-File Executable**:
    *   **Standard**: `Win-Debloat.exe` (x64) or `Win-Debloat-arm64.exe` (ARM64)
    *   **Extras**: `Win-Debloat-Extras.exe` (x64) or `Win-Debloat-Extras-arm64.exe` (ARM64)
3.  **Right-click → Run as Administrator.** No extraction needed.
4.  The launcher verifies your PowerShell version and auto-installs PowerShell 7.6 LTS if missing.

---

## 🛠️ Method 6: From Source (Developers)

```powershell
git clone https://github.com/tomytate/Win-Debloat.git
cd Win-Debloat

# Launch interactive menu under PowerShell 7.6+
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Win-Debloat.ps1
```

### Verify Integrity & AST Parity
```powershell
# 1. Run complete Pester test suite (388 tests)
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-AllTests.ps1

# 2. Verify 5-Way Mathematical AST export parity
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\AST\Test-WinDebloatAstExportParity.ps1
```

---

## ⚠️ Extras Edition Notice
The Extras edition contains **Defender Remover** and **MAS** (Activation Scripts), which are flagged by antivirus software as "HackTool" or "PUP". This is **expected behavior**. Use the Standard Edition if you do not need these tools.

