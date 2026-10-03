@echo off
setlocal EnableDelayedExpansion

:: Win-Debloat Zero-Binary UAC Bootstrap Launcher
:: Bypasses Smart App Control restrictions and launches elevated session.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%Win-Debloat.ps1"
set "LOGS_DIR=%SCRIPT_DIR%Logs"
set "LOG_FILE=%LOGS_DIR%\Win-Debloat-Run.log"

if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" 2>nul

:: Resolve PowerShell 7.6+ (pwsh.exe) or Windows PowerShell 5.1 (powershell.exe)
set "PS_EXE="
where pwsh.exe >nul 2>nul
if %errorlevel% equ 0 (
    set "PS_EXE=pwsh.exe"
) else (
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
        set "PS_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
    ) else if exist "%ProgramW6432%\PowerShell\7\pwsh.exe" (
        set "PS_EXE=%ProgramW6432%\PowerShell\7\pwsh.exe"
    ) else if exist "%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe" (
        set "PS_EXE=%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe"
    ) else (
        set "PS_EXE=powershell.exe"
    )
)

:: Unblock script directory (Strip Mark-of-the-Web Zone.Identifier)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%SCRIPT_DIR:~0,-1%' -Recurse -File -Filter '*.ps*1' -ErrorAction SilentlyContinue | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }" >nul 2>nul

:: Check if running with Administrator privileges
net session >nul 2>nul
if %errorlevel% equ 0 (
    :: Already elevated, run directly
    "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
    goto :EOF
)

:: Not elevated - launch elevated process via UAC RunAs
set "WT_EXE="
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" (
    set "WT_EXE=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
)

if defined WT_EXE (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH:'=''%'; $w='%WT_EXE:'=''%'; $ps='%PS_EXE:'=''%'; $args='%*'; Start-Process -FilePath $w -ArgumentList ('-- ' + $ps + ' -NoProfile -ExecutionPolicy Bypass -File \"' + $p + '\" ' + $args) -Verb RunAs" >> "%LOG_FILE%" 2>&1
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH:'=''%'; $ps='%PS_EXE:'=''%'; $args='%*'; Start-Process -FilePath $ps -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"' + $p + '\" ' + $args) -Verb RunAs" >> "%LOG_FILE%" 2>&1
)

if %errorlevel% neq 0 (
    echo [ERROR] Failed to launch Win-Debloat with elevated privileges.
    echo Check log at %LOG_FILE%
    pause
)

goto :EOF
