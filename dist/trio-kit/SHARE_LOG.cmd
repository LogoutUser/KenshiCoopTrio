@echo off
REM Collect this machine's KenshiCoop logs so they can be shared for diagnosis.
REM Run it right after something goes wrong and BEFORE relaunching Kenshi -
REM the game truncates its logs on every launch, so a restart destroys the
REM evidence.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ShareLog.ps1"
REM If PowerShell died before its own "Press Enter" prompt, hold the window open
REM anyway - otherwise the error scrolls past as the console closes and the user
REM just sees "it didn't work".
if errorlevel 1 (
  echo.
  echo The collector exited with an error - the text above is what went wrong.
  pause
)
