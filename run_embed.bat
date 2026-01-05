@echo off
REM Simple wrapper to run the PowerShell script from double-click
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0embed_middle_cover.ps1"
pause