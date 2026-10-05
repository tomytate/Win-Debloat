@echo off
setlocal EnableDelayedExpansion

:: Win-Debloat Zero-Friction Universal Smart Bootstrapper
:: Detects PowerShell 7+ and falls back seamlessly to native Windows PowerShell 5.1
:: Author: Tomy Tate

set "SCRIPT_DIR=%~dp0"
set "LOGS_DIR=%SCRIPT_DIR%Logs"
set "LOG_FILE=%LOGS_DIR%\Win-Debloat-Run.log"

if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" 2>nul

:: 1. Check for PowerShell 7.6+ (pwsh.exe) in PATH and standard installation paths
set "PWSH_EXE="
where pwsh.exe >nul 2>nul
if %errorlevel% equ 0 (
    set "PWSH_EXE=pwsh.exe"
) else (
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
        set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
    ) else if exist "%ProgramW6432%\PowerShell\7\pwsh.exe" (
        set "PWSH_EXE=%ProgramW6432%\PowerShell\7\pwsh.exe"
    ) else if exist "%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe" (
        set "PWSH_EXE=%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe"
    )
)

:: 2. Choose script engine and target based on environment
if defined PWSH_EXE (
    set "RUNNER=%PWSH_EXE%"
    set "TARGET_SCRIPT=%SCRIPT_DIR%Win-Debloat.ps1"
) else (
    echo [!] Modern PowerShell 7 not detected. Launching Native Windows Engine (PS 5.1)...
    set "RUNNER=powershell.exe"
    set "TARGET_SCRIPT=%SCRIPT_DIR%deploy\Deploy-WinDebloat.ps1"
)

:: Unblock script directory (Strip Mark-of-the-Web Zone.Identifier)
set "SD_ESC=%SCRIPT_DIR:'=''%
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%SD_ESC:~0,-1%' -Recurse -File -Filter '*.ps*1' -ErrorAction SilentlyContinue | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }" >nul 2>nul

:: 3. Check for Administrator privileges
net session >nul 2>nul
if %errorlevel% equ 0 (
    :: Already elevated, run directly
    "%RUNNER%" -NoProfile -ExecutionPolicy Bypass -File "%TARGET_SCRIPT%" %*
    goto :EOF
)

:: 4. Not elevated - launch elevated process via UAC RunAs
set "WT_EXE="
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" (
    set "WT_EXE=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
)

if defined WT_EXE (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%TARGET_SCRIPT:'=''%'; $w='%WT_EXE:'=''%'; $r='%RUNNER:'=''%'; $args='%*'; Start-Process -FilePath $w -ArgumentList ('-- ' + $r + ' -NoProfile -ExecutionPolicy Bypass -File \"' + $p + '\" ' + $args) -Verb RunAs" >> "%LOG_FILE%" 2>&1
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%TARGET_SCRIPT:'=''%'; $r='%RUNNER:'=''%'; $args='%*'; Start-Process -FilePath $r -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"' + $p + '\" ' + $args) -Verb RunAs" >> "%LOG_FILE%" 2>&1
)

if %errorlevel% neq 0 (
    echo [ERROR] Failed to launch Win-Debloat with elevated privileges.
    echo Check log at %LOG_FILE%
    if not defined UNATTENDED if not defined CI pause
)

goto :EOF
