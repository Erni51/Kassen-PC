@echo off
rem ============================================================
rem  ALTER Kassen-PC (Windows 7): alles Wichtige auf den USB-Stick sichern
rem
rem  Diese Datei auf einen USB-Stick legen, Stick am alten PC einstecken.
rem  Am alten PC: Windows-Taste, "cmd" tippen, Enter, dann z. B.
rem      E:\SICHERN-alter-kassen-pc.cmd
rem  (E: durch den Laufwerksbuchstaben des Sticks ersetzen), Enter.
rem
rem  Legt auf dem Stick den Ordner Kassen-PC-Sicherung an mit:
rem   - allen geplanten Aufgaben, deren Name "Lieperts" enthaelt (XML + Klartext)
rem   - dem Ordner, in dem DRUCK-tagesblatt-v2.ps1 liegt (samt Protokollen)
rem   - der Druckerliste
rem  Veraendert am alten PC nichts.
rem ============================================================

set ZIEL=%~d0\Kassen-PC-Sicherung
if not exist "%ZIEL%" mkdir "%ZIEL%"
echo Sichere nach %ZIEL% ...

rem --- geplante Aufgaben ---
schtasks /Query /FO LIST /V > "%ZIEL%\alle-aufgaben.txt"
for /f "tokens=1 delims=," %%a in ('schtasks /Query /FO CSV /NH ^| findstr /I "Lieperts"') do (
    echo   Aufgabe %%~a
    schtasks /Query /TN "%%~a" /XML > "%ZIEL%\aufgabe-%%~na.xml"
)

rem --- Skriptordner suchen und kopieren ---
for /f "delims=" %%f in ('where /R C:\ DRUCK-tagesblatt-v2.ps1 2^>nul') do (
    echo   Skript gefunden: %%f
    echo %%f>> "%ZIEL%\fundorte.txt"
    xcopy "%%~dpf*" "%ZIEL%\skriptordner\" /E /I /Y /Q
)
for /f "delims=" %%f in ('where /R C:\ CRON-lieperts-v1.ps1 2^>nul') do (
    echo %%f>> "%ZIEL%\fundorte.txt"
    copy /Y "%%f" "%ZIEL%\" >nul
)

rem --- Drucker ---
wmic printer get Name,Default,PortName > "%ZIEL%\drucker.txt"

echo.
echo Fertig. Inhalt von %ZIEL%:
dir /B "%ZIEL%"
echo.
echo Stick jetzt abziehen und am neuen PC einstecken.
pause
