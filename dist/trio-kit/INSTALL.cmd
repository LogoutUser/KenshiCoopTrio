@echo off
REM KenshiCoopTrio - double-click installer.
REM Thin wrapper so friends never have to touch PowerShell's execution policy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
