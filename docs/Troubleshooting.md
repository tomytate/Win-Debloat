# Troubleshooting & FAQ

## Common Issues

### "Operation Canceled" or "Access Denied" on WaaSMedicSvc
*   **Cause**: You tried to stop a protected Windows service.
*   **Fix**: This is normal behavior. Win-Debloat handles this error gracefully in logs. Rebooting usually forces the service into the disabled state if registry keys were set.

### "PowerShell 7.6 required"
*   **Cause**: You are running in legacy Windows PowerShell 5.1 (blue icon).
*   **Fix**: Install PowerShell 7 (black icon) from the [Microsoft Store](https://apps.microsoft.com/detail/9mz1sn7389xv) or [GitHub](https://github.com/PowerShell/PowerShell/releases).

### "Windows protected your PC" or Smart App Control Block
*   **Cause**: Windows 11 Smart App Control (SAC) or Microsoft Defender SmartScreen blocks unsigned binaries downloaded from the internet.
*   **Fix**: 
    1.  **Recommended Fix (Zero-Binary Launcher)**: Simply run `Run.bat` from the root directory. It executes purely through native Windows batch and PowerShell, automatically strips Mark-of-the-Web (MotW) NTFS alternate data streams, auto-elevates with a UAC trampoline, and completely bypasses Smart App Control without needing to disable system security.
    2.  If using the single-file executable: Click **More info** -> **Run anyway** on the SmartScreen prompt.
    3.  If extracting manually without `Run.bat`: Right-click the downloaded `.zip` -> **Properties** -> Check **Unblock** -> Apply, or run `Unblock-File .\Win-Debloat.ps1`.

### Windows 11 24H2 DISM Error 0x800f081f
*   **Cause**: On Windows 11 24H2 / 25H2 (Build 26100+), executing `dism /online /cleanup-image /startcomponentcleanup /resetbase` breaks Checkpoint Cumulative Updates, causing subsequent update failures (`0x800f081f`).
*   **Fix**: Win-Debloat v1.6.0 includes built-in checkpoint safety gates (`Repair.psm1`) that automatically detect Build 26100+ and execute safe component cleanup without `/ResetBase`, preventing update corruption.

### WSL2 Network NAT or Windows Hello PIN Inactivity
*   **Cause**: Disabling `SharedAccess` breaks WSL2/Hyper-V network address translation; disabling `WbioSrvc` disables biometric and PIN authentication.
*   **Fix**: Win-Debloat dynamically probes running hypervisors and Windows Hello enrollment status, automatically preserving `SharedAccess` and `WbioSrvc` when in active use.

### "Extras ZIP flagged as virus"
*   **Cause**: The Extras edition contains **Defender Remover** and **MAS**, which are "HackTools".
*   **Fix**: Pause Real-time protection / Tamper Protection to run the tool. **Use the Standard Edition if you do not strictly need these tools.**

### Microsoft Store / Xbox not working after debloat
*   **Cause**: The Store framework or Xbox services were removed during Aggressive bloatware removal.
*   **Fix**: Restore from your snapshot (see below), or reinstall the Store:
    ```powershell
    Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -Register "$($_.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode }
    ```

### Bloatware count shows "?" in the GUI
*   **Cause**: The background runspace failed to enumerate Appx packages (usually a permissions issue).
*   **Fix**: Ensure you are running as Administrator. If the issue persists, run the default TUI mode (`.\Win-Debloat.ps1` or `.\Run.bat` without `-Gui`) as a workaround.

### IPv6 toggle causes Store issues
*   **Cause**: Microsoft Store requires IPv6 for some CDN endpoints.
*   **Fix**: Re-enable IPv6 if you need Store downloads:
    ```powershell
    Enable-WinDebloatIPv6
    ```

---

## How to Restore

If a tweak broke something (e.g., Xbox Login, Store):

1.  Open Win-Debloat GUI.
2.  Go to the **Restore / Snapshots** tab.
3.  Select the snapshot created *before* you applied the tweak.
4.  Click **Restore System**.
5.  Reboot.

### Restore via Dual-Layer Human-Readable `.reg` File
Every snapshot automatically generates a standard Windows Registry Editor (`rollback.reg`) file in the `backups/` folder:
- **Inspect**: Open `backups\<Snapshot-Id>\rollback.reg` in Notepad to inspect every exact key and value.
- **Apply**: Double-click `rollback.reg` or run `reg import backups\<Snapshot-Id>\rollback.reg` from an elevated prompt.

### Restore via CLI
If the GUI is inaccessible:
```powershell
# List available snapshots
Get-WinDebloatSnapshot

# Restore a specific snapshot
Restore-WinDebloatSnapshot -SnapshotId "<Id from Get-WinDebloatSnapshot>"
```

---

## 📝 Logs

All actions are logged for auditing purposes.
*   **Location**: `C:\ProgramData\Win-Debloat\Logs` (and `C:\ProgramData\Win-Debloat7\Logs`)
*   **Format**: `.log` (Text files with ISO timestamps and severity levels)
*   **Levels**: Debug, Info, Warning, Error, Success

Attach the latest log file when [reporting an issue](https://github.com/tomytate/Win-Debloat/issues).

---

## 🧪 Self-Verification

Run the built-in test suite to verify your installation:
```powershell
# 1. Run complete Pester test suite (336 tests, 100% pass)
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-AllTests.ps1

# 2. Verify 5-Way Mathematical AST export parity (0 violations)
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\AST\Test-WinDebloatAstExportParity.ps1
```
All 336 tests should pass with 0 failures and 0 AST violations. If any fail, your installation may be corrupted — re-download from the [Releases Page](https://github.com/tomytate/Win-Debloat/releases).

