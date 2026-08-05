@echo off
rem novrix.cmd — Windows launcher for the novrix CLI.
rem Requires Git Bash (https://git-scm.com), MSYS2, Cygwin or WSL on PATH.
rem Place next to the `novrix` script, or copy both into a directory on PATH.

setlocal
where bash >nul 2>nul
if errorlevel 1 goto :nobash

bash "%~dp0novrix" %*
exit /b %errorlevel%

:nobash
echo [novrix] bash was not found.
echo Install Git for Windows: https://git-scm.com
echo or WSL:                  https://learn.microsoft.com/windows/wsl
echo then re-run this launcher inside Git Bash.
exit /b 1
