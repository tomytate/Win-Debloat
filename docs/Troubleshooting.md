# Troubleshooting & FAQ

## Common Issues

### "Operation Canceled" or "Access Denied" on WaaSMedicSvc
*   **Cause**: You tried to stop a protected Windows service.
*   **Fix**: This is normal behavior. Win-Debloat handles this error gracefully in logs. Rebooting usually forces the service into the disabled state if registry keys were set.

### "PowerShell 7.6 required"
*   **Cause**: You are running in legacy Windows PowerShell 5.1 (blue icon).
*   **Fix**: Install PowerShell 7 (black icon) from the [Microsoft Store](https://apps.microsoft.com/detail/9mz1sn7389xv) or [GitHub](https://github.com/PowerShell/PowerShell/releases).

### "Windows protected your PC" or Smart App Control Block
*   **Cause**: Win-Debloat is intentionally left unsigned (no code-signing certificate) to remain a free, open-source community project. Windows 11 Smart App Control or Microsoft Defender SmartScreen will block unsigned executables downloaded from the internet.
*   **Fix**: 
    1.  Click **More info** -> **Run anyway** on the SmartScreen prompt.
    2.  If Smart App Control is strictly blocking it: Go to **Settings > Privacy & security > Windows Security > App & browser control > Smart App Control settings** and set it to **Off**.
    3.  Alternatively, you can run the tool via PowerShell directly instead of using the `.exe`:
        * Right-click the downloaded `.zip` -> **Properties** -> Check **Unblock** -> Apply.
        * Extract the folder, open PowerShell as Administrator in that folder, and run `.\Win-Debloat.ps1`.

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
*   **Fix**: Ensure you are running as Administrator. If the issue persists, run the default TUI mode (`.\Win-Debloat.ps1` without `-Gui`) as a workaround.

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

### Restore via CLI
If the GUI is inaccessible:
```powershell
# List available snapshots
Get-WinDebloatSnapshot
# (or Get-WinDebloat7Snapshot)

# Restore a specific snapshot
Restore-WinDebloatSnapshot -SnapshotId "<Id from Get-WinDebloatSnapshot>"
```

---

## 📝 Logs

All actions are logged for auditing purposes.
*   **Location**: `C:\ProgramData\Win-Debloat\Logs` (and `C:\ProgramData\Win-Debloat7\Logs`)
*   **Format**: `.log` (Text files with timestamps and severity levels)
*   **Levels**: Debug, Info, Warning, Error, Success

Attach the latest log file when [reporting an issue](https://github.com/tomytate/Win-Debloat/issues).

---

## 🧪 Self-Verification

Run the built-in test suite to verify your installation:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-AllTests.ps1
```
All tests should pass. If any fail, your installation may be corrupted — re-download from the [Releases Page](https://github.com/tomytate/Win-Debloat/releases).
