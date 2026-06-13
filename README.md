# OpenModScanner

OpenModScanner ist ein vollständig quelloffener Minecraft-Mod-Scanner als einzelnes PowerShell-Skript.

Das Skript sucht in einem vom Benutzer angegebenen Ordner nach verdächtigen Begriffen in Mod-Dateinamen. Es prüft nur Dateinamen und Pfade. Es verändert keine Dateien, löscht nichts, sendet keine Daten ins Internet und benötigt keine Administratorrechte.

## Inhalt des Repositorys

- `OpenModScanner.ps1`: Das einzige PowerShell-Skript des Projekts.
- `README.md`: Diese Erklärung, Sicherheitsanalyse und Prüfanleitung.

## Ausführung

Lokal:

```powershell
powershell -ExecutionPolicy Bypass -File .\OpenModScanner.ps1
```

Später über GitHub Raw-URL:

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'RAW_GITHUB_URL_HIER')"
```

Ersetze `RAW_GITHUB_URL_HIER` durch die Raw-URL zu `OpenModScanner.ps1` im GitHub-Repository.

Hinweis: Der obige Befehl lädt das Skript über PowerShell aus GitHub. Das Skript selbst enthält keine Netzwerkfunktionen. Wer maximale Sicherheit möchte, sollte den Code zuerst öffnen, vollständig lesen und dann lokal ausführen.

## Was der Scanner macht

1. Der Benutzer gibt einen Ordnerpfad ein.
2. Das Skript prüft, ob dieser Pfad ein vorhandener Ordner ist.
3. Das Skript durchsucht diesen Ordner und seine Unterordner nach Dateien.
4. Das Skript prüft nur die Dateinamen auf sichtbare verdächtige Begriffe.
5. Treffer werden mit Dateiname, vollständigem Pfad und gefundenem Muster angezeigt.

Ein Treffer bedeutet nicht automatisch, dass eine Mod schädlich ist. Ein Treffer bedeutet nur: Dieser Dateiname sollte genauer geprüft werden.

## Erklärungen aller Funktionen

### `Write-Info`

Gibt normale Statusmeldungen im PowerShell-Fenster aus. Die Funktion nimmt einen Text entgegen und zeigt ihn in Cyan an. Sie speichert nichts, sendet nichts und verändert keine Dateien.

### `Write-WarningMessage`

Gibt Warnmeldungen im PowerShell-Fenster aus. Sie wird benutzt, wenn zum Beispiel kein gültiger Ordner angegeben wurde. Auch diese Funktion zeigt nur Text an.

### `Get-ScanFolderFromUser`

Fragt den Benutzer nach dem Ordner, der gescannt werden soll. Die Eingabe wird leicht bereinigt, indem äußere Leerzeichen und äußere Anführungszeichen entfernt werden. Dadurch funktionieren kopierte Pfade besser. Die Funktion erstellt keinen Ordner und greift nicht schreibend auf Dateien zu.

### `Test-ScanFolder`

Prüft, ob der angegebene Pfad existiert und ein Ordner ist. Dafür wird `Test-Path` mit `-PathType Container` verwendet. Diese Prüfung liest nur Dateisystem-Informationen.

### `Get-SuspiciousNamePatterns`

Liefert die sichtbare Liste verdächtiger Begriffe. Beispiele sind `token`, `grabber`, `stealer`, `keylogger`, `webhook`, `payload` und `miner`. Die Liste steht im Klartext im Skript, damit jeder sie prüfen und nachvollziehen kann.

### `Find-SuspiciousModFiles`

Durchsucht den angegebenen Ordner rekursiv nach Dateien. Dafür wird `Get-ChildItem` mit `-File` und `-Recurse` verwendet. Die Funktion liest nur Dateinamen und Pfade. Für jede Datei wird geprüft, ob der Dateiname eines der verdächtigen Muster enthält. Bei einem Treffer wird ein einfaches Ergebnisobjekt mit Dateiname, Pfad und Muster erzeugt.

### `Show-ScanResults`

Zeigt die Treffer an. Wenn keine Treffer gefunden wurden, gibt die Funktion eine grüne Entwarnung aus. Wenn Treffer gefunden wurden, zeigt sie pro Treffer Dateiname, Pfad und Muster an. Sie löscht und verändert nichts.

### `Start-OpenModScanner`

Ist der Hauptablauf des Skripts. Diese Funktion zeigt den Starttext, fragt den Ordner ab, prüft den Ordner, lädt die Suchmuster, startet die Suche und zeigt die Ergebnisse an.

## Sicherheitsanalyse

OpenModScanner ist absichtlich klein und direkt prüfbar.

- Keine Löschbefehle: Das Skript verwendet kein `Remove-Item`.
- Keine Dateiänderungen: Das Skript verwendet kein `Set-Content`, `Add-Content`, `Out-File`, `Move-Item`, `Copy-Item` oder ähnliche Schreibaktionen.
- Keine Netzwerkfunktionen im Skript: Das Skript verwendet kein `Invoke-WebRequest`, kein `Invoke-RestMethod`, keine Sockets und keine WebClient-Klassen.
- Keine Registry-Änderungen: Das Skript verwendet keine Registry-Pfade und keine Registry-Cmdlets.
- Keine Autostarts: Das Skript legt keine geplanten Aufgaben, Dienste, Startup-Verknüpfungen oder Run-Keys an.
- Keine Hintergrundprozesse: Das Skript verwendet kein `Start-Process` und erstellt keine Jobs.
- Keine Adminrechte nötig: Das Skript arbeitet nur mit normalen Lesezugriffen auf den vom Benutzer angegebenen Ordner.
- Keine Verschleierung: Alle Suchmuster und Funktionen stehen im Klartext.

## So kann man den gesamten Code prüfen

1. Öffne `OpenModScanner.ps1` in einem Texteditor.
2. Lies die Datei von oben nach unten.
3. Suche nach gefährlichen oder unerwarteten Befehlen:

```powershell
Select-String -Path .\OpenModScanner.ps1 -Pattern "Invoke-WebRequest|Invoke-RestMethod|Remove-Item|Set-Content|Add-Content|Out-File|Start-Process|Start-Job|Register-ScheduledTask|New-Service|Set-ItemProperty|New-ItemProperty"
```

Bei diesem Projekt sollten keine solchen Befehle im Skript gefunden werden.

4. Prüfe, welche Dateien im Repository liegen:

```powershell
Get-ChildItem -File
```

Es sollten nur `OpenModScanner.ps1` und `README.md` sichtbar sein.

5. Prüfe, ob das Skript syntaktisch korrekt ist:

```powershell
powershell -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('OpenModScanner.ps1', [ref]$null, [ref]$null); 'Syntax OK'"
```

## Netzwerkhinweis

Das Skript selbst verwendet keine Netzwerkfunktionen. Es gibt keine Telemetrie, keine versteckten Downloads und keine Datenübertragung.

Nur die optionale Ausführungsform mit `Invoke-RestMethod 'RAW_GITHUB_URL_HIER'` lädt das Skript von GitHub herunter. Dieser Download ist Teil des Startbefehls, nicht Teil von `OpenModScanner.ps1`.

## Grenzen des Scanners

OpenModScanner prüft nur Dateinamen. Er analysiert keine `.jar`-Inhalte, keinen Bytecode und kein Verhalten einer Mod. Dadurch bleibt das Skript transparent und ungefährlich, erkennt aber nicht jede schädliche Mod.

Für eine gründlichere Prüfung sollte man verdächtige Dateien zusätzlich manuell untersuchen, Hashes vergleichen und nur Mods aus vertrauenswürdigen Quellen verwenden.
