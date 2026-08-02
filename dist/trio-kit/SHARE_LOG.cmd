@echo off
REM Collect this machine's KenshiCoop logs so they can be shared for diagnosis.
REM Run it right after something goes wrong and BEFORE relaunching Kenshi -
REM the game truncates its logs on every launch, so a restart destroys the
REM evidence.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ShareLog.ps1"
