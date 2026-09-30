' Startet das Einkaufs-Programm ohne sichtbares Fenster.
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Lieperts\einkauf\EINKAUF-LAUF.ps1""", 0, False
