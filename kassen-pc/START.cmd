@echo off
rem ============================================================
rem  Neuer Kassen-PC: Einrichtung starten (Doppelklick oder Enter reicht)
rem  Holt sich selbst Administrator-Rechte und sucht die Sicherung vom
rem  alten PC auf einem USB-Stick (Ordner Kassen-PC-Sicherung).
rem ============================================================

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set SICH=
for %%L in (D E F G H I J K) do if exist "%%L:\Kassen-PC-Sicherung" set SICH=%%L:\Kassen-PC-Sicherung
if defined SICH (echo Sicherung gefunden: %SICH%) else (echo Keine Sicherung vom alten PC gefunden - es geht trotzdem.)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EINRICHTEN.ps1" -Sicherung "%SICH%"
echo.
pause
