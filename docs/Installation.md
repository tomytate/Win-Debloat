# Installation Guide

Win-Debloat is designed to run on **Windows 10 (22H2+)** or **Windows 11**.

## Prerequisites

1.  **PowerShell 7.6+**: The script targets PowerShell 7.6 LTS (built on .NET 10).
    *   **Auto-Installed**: If you use `Win-Debloat.exe` (or `Win-Debloat7.exe`), it verifies your installed version and automatically installs PowerShell 7.6 LTS (currently 7.6.3) when missing or outdated.
    *   **Manual**: Only required if running the `.ps1` script directly. [Download Here](https://github.com/PowerShell/PowerShell/releases)

2.  **Administrator Rights**: The script requires elevated privileges to modify registry and services.

---

## ⚡ Method 1: Instant Deploy (Recommended)

Open PowerShell **as Administrator** and paste one command:

### Standard Edition 🛡️
Safe, stable, and compliant. No compiled binaries.
```powershell
iwr -useb https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-standard.ps1 | iex
```

### Extras Edition ⚠️
Includes **Defender Remover** + **MAS**. Will trigger Antivirus warnings.
```powershell
iwr -useb https://raw.githubusercontent.com/tomytate/Win-Debloat/main/setup-extras.ps1 | iex
```

---

## 🍫 Method 2: Chocolatey

For users who prefer Chocolatey package manager.

```powershell
choco install win-debloat
```

---

## 📂 Method 3: Direct Download (Portable)

For portable usage (USB drives) or offline systems.

1.  Go to the **[Releases Page](https://github.com/tomytate/Win-Debloat/releases)**.
2.  Download the **Single-File Executable**:
    *   **Standard**: `Win-Debloat.exe` (Recommended)
    *   **Extras**: `Win-Debloat-Extras.exe`
3.  **Right-click → Run as Administrator.** No extraction needed.
4.  The launcher verifies your PowerShell version and auto-installs PowerShell 7.6 LTS if missing or outdated.

---

## 🛠️ Method 4: From Source (Developers)

```powershell
git clone https://github.com/tomytate/Win-Debloat.git
cd Win-Debloat
.\Win-Debloat.ps1
```

### Verify Integrity
```powershell
# Run test suite
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-AllTests.ps1
```

---

## ⚠️ Extras Edition Notice
The Extras edition contains **Defender Remover** and **MAS** (Activation Scripts), which are flagged by antivirus software as "HackTool" or "PUP". This is **expected behavior**. Use the Standard Edition if you do not need these tools.
