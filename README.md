# OpenModScanner

OpenModScanner ist ein vollstaendig quelloffener Minecraft-Mod-Scanner als einzelnes PowerShell-Skript.

Das Skript scannt einen vom Benutzer angegebenen Mods-Ordner. Es sucht nicht nur nach auffaelligen Mod-Dateinamen, sondern oeffnet `.jar`- und `.zip`-Mods read-only als Archiv und prueft auch interne Dateipfade sowie kleine Text-, Metadaten- und `.class`-Dateien auf auffaellige Klartext-Muster.

OpenModScanner veraendert keine Dateien, loescht nichts, entpackt nichts dauerhaft, sendet keine Daten ins Internet und benoetigt keine Administratorrechte.

## Inhalt des Repositorys

- `OpenModScanner.ps1`: Das einzige PowerShell-Skript des Projekts.
- `README.md`: Diese Erklaerung, Sicherheitsanalyse und Pruefanleitung.

## Ausfuehrung

Lokal:

```powershell
powershell -ExecutionPolicy Bypass -File .\OpenModScanner.ps1
```

Direkt ueber GitHub Raw-URL:

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/einfachduncan/OpenModScanner/main/OpenModScanner.ps1')"
```

Hinweis: Der obige Startbefehl laedt das Skript von GitHub. Das Skript selbst enthaelt keine Netzwerkfunktionen.

## Was der Scanner prueft

1. Der Benutzer gibt einen Mods-Ordner ein.
2. Das Skript prueft, ob dieser Ordner existiert.
3. Das Skript sucht rekursiv nach `.jar`- und `.zip`-Dateien.
4. Jede gefundene Mod wird read-only als Archiv geoeffnet.
5. Der Mod-Dateiname wird auf auffaellige Muster geprueft.
6. Interne Archiv-Pfade werden auf auffaellige Muster geprueft.
7. Kleine Text-, Metadaten- und `.class`-Dateien im Archiv werden im Arbeitsspeicher gelesen und auf Klartext-Muster geprueft.
8. Treffer werden mit Risiko, Mod-Datei, Pfad, Fundstelle, Muster und Grund angezeigt.

Ein Treffer ist kein Beweis fuer Schadsoftware. Ein Treffer bedeutet: Diese Mod sollte genauer geprueft werden.

## Beispiel-Ausgabe

Ohne Treffer:

```text
OpenModScanner
Minecraft Mod Security Scanner

Enter path to the mods folder: (press Enter to use default)
PATH: C:\Users\Name\AppData\Roaming\.minecraft\mods

  *  SUSPICIOUS MODS  (0)
  No suspicious mods found.

Analysis complete.
```

Mit Treffern:

```text
  *  SUSPICIOUS MODS  (1)

  FLAGGED   example.jar
  Path:     C:\Minecraft\mods\example.jar

  PATTERNS
    discord.com/api/webhooks  [Hoch]
      Where: Inhalt: fabric.mod.json
      Why:   Discord-Webhooks werden oft fuer Datenabfluss missbraucht.
```

## Erklaerung aller Funktionen

### `Write-Info`

Zeigt normale Statusmeldungen im PowerShell-Fenster an. Die Funktion veraendert nichts.

### `Write-WarningMessage`

Zeigt Warnmeldungen an, zum Beispiel wenn ein Ordner nicht gefunden wurde oder ein Archiv nicht gelesen werden kann.

### `Get-ScanFolderFromUser`

Fragt den Benutzer nach dem Mods-Ordner. Die Eingabe wird nur leicht bereinigt, damit kopierte Pfade besser funktionieren.

### `Test-ScanFolder`

Prueft, ob der angegebene Pfad ein vorhandener Ordner ist. Es werden nur Dateisystem-Informationen gelesen.

### `Get-SuspiciousPatterns`

Liefert die komplette sichtbare Suchliste. Jedes Muster enthaelt einen Suchtext, eine grobe Risiko-Einschaetzung und eine Erklaerung.

### `New-Finding`

Erstellt ein einheitliches Ergebnisobjekt fuer Treffer. Dadurch sehen alle Treffer gleich aus.

### `Find-PatternsInText`

Prueft einen Text gegen alle Suchmuster. Die Suche ist einfache Klartext-Suche und nicht von Gross-/Kleinschreibung abhaengig.

### `Get-ModFiles`

Sucht im angegebenen Ordner rekursiv nach `.jar`- und `.zip`-Dateien. Die Funktion listet nur Dateien auf.

### `Test-EntryShouldBeRead`

Entscheidet, ob eine Datei innerhalb einer Mod gelesen werden soll. Gelesen werden nur kleine Dateien bis 1 MB und typische Text-, Metadaten- oder `.class`-Dateien.

### `Read-ArchiveEntryAsText`

Liest eine kleine Datei aus einer Mod in den Arbeitsspeicher. Die Datei wird nicht auf die Festplatte entpackt und nicht veraendert.

### `Scan-ModArchive`

Oeffnet eine Mod read-only als ZIP/JAR-Archiv. Geprueft werden Mod-Dateiname, interne Archiv-Pfade und kleine lesbare Inhalte.

### `Start-ModScan`

Findet alle Mod-Dateien und scannt sie einzeln. Die Funktion sammelt alle Treffer in einer Liste.

### `Show-ScanResults`

Zeigt die Ergebnisse kurz und uebersichtlich an. Ohne Treffer wird eine klare Entwarnung angezeigt. Mit Treffern werden die Hinweise pro Mod gruppiert.

### `Start-OpenModScanner`

Ist der Hauptablauf des Skripts. Diese Funktion startet die Anzeige, laedt die ZIP-Unterstuetzung, fragt den Ordner ab, startet den Scan und zeigt die Ergebnisse.

## Sicherheitsanalyse

OpenModScanner ist absichtlich transparent und lokal.

- Keine Loeschbefehle im Skript.
- Keine Schreibbefehle im Skript.
- Keine Netzwerkfunktionen im Skript.
- Keine Registry-Aenderungen.
- Keine Autostarts.
- Keine Hintergrundprozesse.
- Keine dauerhafte Entpackung von Mods.
- Keine Adminrechte noetig.
- Keine Verschleierung.
- Alle Suchmuster stehen im Klartext.

Das Skript verwendet `System.IO.Compression.ZipFile` nur, um `.jar`- und `.zip`-Dateien read-only zu oeffnen. Minecraft-Mods sind meistens `.jar`-Dateien, und `.jar` ist technisch ein ZIP-Archiv.

## So kann man den gesamten Code pruefen

1. Oeffne `OpenModScanner.ps1` in einem Texteditor.
2. Lies die Datei von oben nach unten.
3. Suche nach unerwuenschten Befehlen:

```powershell
Select-String -Path .\OpenModScanner.ps1 -Pattern "Remove-Item|Set-Content|Add-Content|Out-File|Start-Process|Start-Job|Register-ScheduledTask|New-Service|Set-ItemProperty|New-ItemProperty"
```

4. Pruefe, welche Dateien im Repository liegen:

```powershell
Get-ChildItem -File
```

Es sollten nur `OpenModScanner.ps1` und `README.md` sichtbar sein.

5. Pruefe die Syntax:

```powershell
powershell -NoProfile -Command "$errors = $null; $tokens = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile('OpenModScanner.ps1', [ref]$tokens, [ref]$errors); if ($errors.Count -eq 0) { 'Syntax OK' } else { $errors }"
```

## Netzwerkhinweis

Das Skript selbst verwendet keine Netzwerkfunktionen. Es gibt keine Telemetrie, keine versteckten Downloads und keine Datenuebertragung.

Nur die optionale Ausfuehrung mit `Invoke-RestMethod` im Startbefehl laedt das Skript von GitHub. Dieser Download ist Teil des Befehls, nicht Teil des Skripts.

## Grenzen des Scanners

OpenModScanner ist ein statischer Read-only-Scanner. Er kann auffaellige Klartext-Muster finden, aber er beweist nicht automatisch, ob eine Mod gut oder schlecht ist.

Er fuehrt keine Mod aus, dekompiliert keinen Java-Code vollstaendig und ersetzt keine professionelle Malware-Analyse.
