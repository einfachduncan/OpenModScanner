# OpenModScanner

OpenModScanner ist ein quelloffener Minecraft-Mod-Scanner als einzelnes PowerShell-Skript.

Das Skript scannt einen vom Benutzer angegebenen Mods-Ordner. Es listet die sichtbaren Haupt-Mod-Dateien aus diesem Ordner in einer Tabelle und oeffnet diese `.jar`- und `.zip`-Mods read-only als Archiv. Geflaggt werden konkrete Cheat-, Hack- und Injection-Hinweise, nicht normale Mods nur weil sie unbekannt sind oder normale Fabric-Technik verwenden.

OpenModScanner veraendert keine Dateien, loescht nichts, entpackt nichts dauerhaft und benoetigt keine Administratorrechte. Online-Verifikation ist standardmaessig aktiv: Bei Enter werden SHA1-Dateihashes an Modrinth und Megabase gesendet. Mit `n` bleibt der Scan offline.

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

Beim Start fragt das Skript:

```text
Online verification with Modrinth/Megabase? [Y/n]
```

Bei Enter oder `Y` werden Hashes online geprueft. Bei `n` bleibt der Scan offline.

## Was der Scanner prueft

1. Der Benutzer gibt einen Mods-Ordner ein.
2. Das Skript prueft, ob dieser Ordner existiert.
3. Das Skript fragt, ob Online-Verifikation benutzt werden soll.
4. Das Skript sucht direkt im Mods-Ordner nach `.jar`- und `.zip`-Dateien.
5. Jede gefundene Mod bekommt lokal einen SHA1-Hash.
6. Wenn Online-Verifikation aktiv ist, wird der Hash bei Modrinth und Megabase gesucht.
7. Wenn eine online verifizierte Mod einen unpassenden Dateinamen hat, wird sie als `RENAMED` angezeigt.
8. Jede gefundene Mod wird read-only als Archiv geoeffnet.
9. Der Mod-Dateiname wird auf Cheat-/Hack-Muster geprueft.
10. Interne Archiv-Pfade werden auf Cheat-/Hack-Muster geprueft.
11. Kleine Text-, Metadaten- und `.class`-Dateien im Archiv werden im Arbeitsspeicher gelesen und auf Cheat-/Hack-Muster geprueft.
12. Alle Haupt-Mods werden in einer Tabelle angezeigt.
13. Nur geflaggte Mods erscheinen in den Detailbereichen.

Ein Treffer ist kein Beweis fuer Schadsoftware. Ein Treffer bedeutet: Diese Mod sollte genauer geprueft werden.

## Beispiel-Ausgabe

```text
Found 42 JAR files to analyze

Pass 1 - Hash verification (Modrinth + Megabase)...
Pass 2 - Deep-scanning all 42 mods...
Pass 3 - Bypass/injection scan on all 42 mods...
Pass 4 - Obfuscation analysis on all 42 mods...
Pass 5 - Scanning JVM for agents and injections...
   OK  JVM looks clean

  *  MAIN MODS  (42)
  OK   STATUS     MOD FILE

  FLAGGED  (1)
  !    FLAGGED    cheat-client.jar

  VERIFIED (1)
  ✓    VERIFIED   sodium.jar

  RENAMED  (1)
  ?    RENAMED    random-name.jar
       Expected: Sodium

  REVIEW   (1)
  ?    REVIEW     packed-mod.jar

  CLEAN    (39)
  ✓    CLEAN      example.jar

  *  VERIFIED MODS  (1)
  [ OK ] sodium.jar
         Modrinth: Sodium

  *  SUSPICIOUS MODS  (1)
  FLAGGED   cheat-client.jar

SUMMARY
  Total files scanned: 42
  Verified mods:       1
  Renamed mods:        1
  Clean mods:          40
  Suspicious mods:     1
  Bypass/Injected:     0
  Obfuscated mods:     1
  JVM issues:          0
  Network used:        1
  Files changed:       0
```

## Erklaerung aller Funktionen

### `Write-Info`

Zeigt normale Statusmeldungen im PowerShell-Fenster an. Die Funktion veraendert nichts.

### `Write-WarningMessage`

Zeigt Warnmeldungen an, zum Beispiel wenn ein Ordner nicht gefunden wurde oder ein Archiv nicht gelesen werden kann.

### `Write-Line`

Zeigt eine Trennlinie in der Konsole an.

### `Show-Banner`

Zeigt den Startbildschirm des Scanners an.

### `Get-DefaultModsFolder`

Ermittelt den Standardpfad `%APPDATA%\.minecraft\mods`.

### `Get-ScanFolderFromUser`

Fragt den Benutzer nach dem Mods-Ordner. Die Eingabe wird nur leicht bereinigt, damit kopierte Pfade besser funktionieren.

### `Test-ScanFolder`

Prueft, ob der angegebene Pfad ein vorhandener Ordner ist. Es werden nur Dateisystem-Informationen gelesen.

### `Get-OnlineVerificationChoice`

Fragt, ob die Online-Verifikation aktiviert werden soll. Standard ist `Y`, also online. Mit `n` bleibt der Scan offline.

### `Query-Modrinth`

Fragt die Modrinth-API mit einem SHA1-Dateihash. Diese Funktion wird nur benutzt, wenn Online-Verifikation aktiviert wurde.

### `Query-Megabase`

Fragt die Megabase-API mit einem SHA1-Dateihash, wenn Modrinth keinen Treffer liefert. Diese Funktion wird nur benutzt, wenn Online-Verifikation aktiviert wurde.

### `Get-ModVerification`

Berechnet lokal den SHA1-Hash einer Mod-Datei und sucht ihn optional online bei Modrinth und Megabase.

### `Get-SuspiciousPatterns`

Liefert die sichtbare Suchliste. Die normale Flagliste ist auf Cheat-, Hack-, Utility-Client- und Account-Diebstahl-Hinweise begrenzt.

### `New-Finding`

Erstellt ein einheitliches Ergebnisobjekt fuer Treffer.

### `Find-PatternsInText`

Prueft einen Text gegen alle Suchmuster. Die Suche ist einfache Klartext-Suche und nicht von Gross-/Kleinschreibung abhaengig.

### `Get-ModFiles`

Sucht direkt im angegebenen Mods-Ordner nach `.jar`- und `.zip`-Dateien. Die Funktion listet nur sichtbare Haupt-Mod-Dateien auf.

### `Test-GibberishClassName`

Prueft Klassennamen grob darauf, ob sie wie zufaellige oder verschleierte Namen aussehen.

### `Scan-ModObfuscation`

Untersucht Klassennamen innerhalb einer Mod. Sehr starke Obfuscation wird als `REVIEW` angezeigt, nicht automatisch als Cheat.

### `Get-BypassInjectionPatterns`

Liefert klare Bypass- und Injection-Begriffe. Normale Fabric-Technik wie Mixins oder ASM wird bewusst nicht als Treffer genutzt.

### `Scan-ModBypassInjection`

Sucht in einem Mod-Archiv nach klaren Bypass- oder Injection-Hinweisen.

### `Scan-JvmAgents`

Liest laufende Java-Prozesse aus und sucht nach auffaelligen Agent- oder Injection-Flags. Es werden keine Prozesse beendet.

### `Get-MinecraftUptimeText`

Zeigt an, ob ein Java-/Minecraft-Prozess laeuft und wie lange er schon gestartet ist.

### `Test-EntryShouldBeRead`

Entscheidet, ob eine Datei innerhalb einer Mod gelesen werden soll. Gelesen werden nur kleine Dateien bis 1 MB und typische Text-, Metadaten- oder `.class`-Dateien.

### `Read-ArchiveEntryAsText`

Liest eine kleine Datei aus einer Mod in den Arbeitsspeicher. Die Datei wird nicht auf die Festplatte entpackt und nicht veraendert.

### `Scan-ModArchive`

Oeffnet eine Mod read-only als ZIP/JAR-Archiv. Geprueft werden Mod-Dateiname, interne Archiv-Pfade und kleine lesbare Inhalte.

### `Start-ModScan`

Findet alle Mod-Dateien, startet die Passes und sammelt Verified-, Renamed-, Flagged-, Review- und JVM-Ergebnisse.

### `Show-ScanResults`

Zeigt zuerst eine Haupt-Mod-Uebersicht, die `! FLAGGED`, `✓ VERIFIED`, `? RENAMED`, `? REVIEW` und `✓ CLEAN` getrennt gruppiert. Danach zeigt es nur relevante Detailbereiche.

### `Show-ClosingCredits`

Zeigt am Ende einen Abschlussbereich mit Projektname, Ersteller und GitHub-Link. Diese Funktion ist rein optisch.

### `Start-OpenModScanner`

Ist der Hauptablauf des Skripts. Diese Funktion startet die Anzeige, laedt die ZIP-Unterstuetzung, fragt Ordner und Online-Modus ab, startet den Scan und zeigt die Ergebnisse.

## Sicherheitsanalyse

OpenModScanner ist transparent und lokal-first.

- Keine Loeschbefehle im Skript.
- Keine Schreibbefehle im Skript.
- Keine Registry-Aenderungen.
- Keine Autostarts.
- Keine Hintergrundprozesse.
- Keine dauerhafte Entpackung von Mods.
- Keine Adminrechte noetig.
- Keine Verschleierung.
- Alle Suchmuster stehen im Klartext.
- Netzwerk fuer Online-Verifikation standardmaessig aktiv, aber mit `n` deaktivierbar.

Wenn Online-Verifikation aktiviert wird, sendet das Skript SHA1-Dateihashes an:

- `https://api.modrinth.com`
- `https://megabase.vercel.app`

Es werden keine Mod-Dateien hochgeladen.

Das Skript verwendet `System.IO.Compression.ZipFile` nur, um `.jar`- und `.zip`-Dateien read-only zu oeffnen. Minecraft-Mods sind meistens `.jar`-Dateien, und `.jar` ist technisch ein ZIP-Archiv.

## So kann man den gesamten Code pruefen

1. Oeffne `OpenModScanner.ps1` in einem Texteditor.
2. Lies die Datei von oben nach unten.
3. Suche nach unerwuenschten Schreib-, Loesch- und Autostart-Befehlen:

```powershell
Select-String -Path .\OpenModScanner.ps1 -Pattern "Remove-Item|Set-Content|Add-Content|Out-File|Start-Process|Start-Job|Register-ScheduledTask|New-Service|Set-ItemProperty|New-ItemProperty"
```

4. Pruefe die Netzwerkstellen:

```powershell
Select-String -Path .\OpenModScanner.ps1 -Pattern "Invoke-RestMethod|api.modrinth.com|megabase.vercel.app"
```

5. Pruefe, welche Dateien im Repository liegen:

```powershell
Get-ChildItem -File
```

Es sollten nur `OpenModScanner.ps1` und `README.md` sichtbar sein.

6. Pruefe die Syntax:

```powershell
powershell -NoProfile -Command "$errors = $null; $tokens = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile('OpenModScanner.ps1', [ref]$tokens, [ref]$errors); if ($errors.Count -eq 0) { 'Syntax OK' } else { $errors }"
```

## Netzwerkhinweis

Standardmaessig verwendet das Skript die Online-Verifikation. Wenn der Benutzer bei `Online verification with Modrinth/Megabase? [Y/n]` nur Enter drueckt, werden SHA1-Hashes bei Modrinth und Megabase geprueft.

Wenn der Benutzer `n` eingibt, bleibt der Scan offline. Es gibt keine Telemetrie, keine versteckten Downloads und keine Mod-Datei-Uploads.

Die optionale Ausfuehrung mit `Invoke-RestMethod` im Startbefehl laedt zusaetzlich das Skript von GitHub.

## Grenzen des Scanners

OpenModScanner ist ein statischer Read-only-Scanner. Er kann bekannte Hashes verifizieren und auffaellige Klartext-Muster finden, aber er beweist nicht automatisch, ob eine Mod gut oder schlecht ist.

Die Online-Verifikation prueft bekannte Mods ueber Modrinth und Megabase. Bekannte Client-Namen und Features wie Meteor, Wurst, Krypton/Crypton, CevAPI, Freecam, NoClip, LiquidBounce oder RusherHack werden lokal ueber Signaturen in Dateinamen, Archiv-Pfaden und kleinen Textinhalten erkannt.

Er fuehrt keine Mod aus, dekompiliert keinen Java-Code vollstaendig und ersetzt keine professionelle Malware-Analyse.
