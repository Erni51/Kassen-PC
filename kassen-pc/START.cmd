@echo off
rem ============================================================
rem  Neuer Kassen-PC: Einrichtung starten (Doppelklick reicht)
rem  Holt sich selbst Administrator-Rechte und startet EINRICHTEN.ps1.
rem ============================================================

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EINRICHTEN.ps1"
echo.
pause
