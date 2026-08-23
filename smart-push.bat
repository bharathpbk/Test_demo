@echo off
REM ============================================================
REM smart-push.bat — universal wrapper for smart-push.sh
REM Works from: cmd.exe, PowerShell, or Git Bash
REM
REM USAGE (cmd):
REM   smart-push.bat "feat: added login validation"
REM
REM USAGE (PowerShell):
REM   .\smart-push.bat "feat: added login validation"
REM
REM USAGE (Git Bash):
REM   ./smart-push.bat "feat: added login validation"
REM ============================================================

set "SCRIPT_DIR=%~dp0"

REM Try common Git for Windows install locations
set "GITBASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%GITBASH%" set "GITBASH=C:\Program Files (x86)\Git\bin\bash.exe"

REM Fallback: try to find bash via PATH (works if Git\bin or Git\usr\bin is on PATH)
if not exist "%GITBASH%" (
    for /f "delims=" %%B in ('where bash 2^>nul') do set "GITBASH=%%B"
)

if not exist "%GITBASH%" (
    echo ERROR: Could not find Git Bash / bash.exe on this machine.
    echo Please install Git for Windows from https://git-scm.com/download/win
    exit /b 1
)

"%GITBASH%" "%SCRIPT_DIR%smart-push.sh" %*
exit /b %errorlevel%
