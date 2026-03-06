@echo off
REM run_embed.bat
REM Launches embed_middle_cover.ps1 from the folder this BAT file lives in.
REM Originals are never modified; finished files go into a "Thumbnailed" subfolder.

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0embed_middle_cover.ps1"
pause
