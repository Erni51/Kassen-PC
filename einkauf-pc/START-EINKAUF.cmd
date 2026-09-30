@echo off
rem ============================================================
rem  Lieperts Einkauf (live): Einrichtung starten (Doppelklick reicht)
rem  Holt sich selbst Administrator-Rechte und startet EINKAUF-EINRICHTEN.ps1.
rem ============================================================

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EINKAUF-EINRICHTEN.ps1"
echo.
pause
