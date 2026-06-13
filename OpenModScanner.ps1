<#
OpenModScanner.ps1

Ein quelloffener, bewusst einfacher Scanner fuer Minecraft-Mod-Dateinamen.

Wichtig:
- Dieses Skript liest nur Dateinamen und Pfade.
- Dieses Skript veraendert, verschiebt oder loescht keine Dateien.
- Dieses Skript nutzt keine Netzwerkfunktionen.
- Dieses Skript braucht keine Administratorrechte.
- Dieses Skript startet keine Hintergrundprozesse.
#>

Set-StrictMode -Version Latest

<#
Funktion: Write-Info

Diese kleine Hilfsfunktion gibt normale Statusmeldungen aus.
Sie ist nur dafuer da, Texte einheitlich in einer neutralen Farbe anzuzeigen.
Die Funktion speichert nichts, sendet nichts und veraendert keine Dateien.
#>
function Write-Info {
    param (
        # Der Text, der im PowerShell-Fenster angezeigt werden soll.
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Cyan
}

<#
Funktion: Write-WarningMessage

Diese Hilfsfunktion gibt Warnungen aus.
Sie wird verwendet, wenn eine Eingabe fehlt oder ein Ordner nicht gefunden wird.
Auch diese Funktion zeigt nur Text an und fuehrt keine Aenderungen am System aus.
#>
function Write-WarningMessage {
    param (
        # Der Warntext, der im PowerShell-Fenster angezeigt werden soll.
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Yellow
}

<#
Funktion: Get-ScanFolderFromUser

Diese Funktion fragt den Benutzer nach dem Ordner, der gescannt werden soll.
Der Benutzer kann den Pfad selbst eintippen oder per Kopieren/Einfuegen einsetzen.
Die Funktion entfernt nur aeussere Anfuehrungszeichen und Leerzeichen, damit
Pfade wie "C:\Users\Name\AppData\Roaming\.minecraft\mods" funktionieren.
Es wird kein Ordner erstellt und keine Datei veraendert.
#>
function Get-ScanFolderFromUser {
    $rawInput = Read-Host "Bitte den zu scannenden Mod-Ordner eingeben"
    $cleanInput = $rawInput.Trim().Trim('"')

    return $cleanInput
}

<#
Funktion: Test-ScanFolder

Diese Funktion prueft, ob der angegebene Pfad wirklich ein vorhandener Ordner ist.
Test-Path fragt nur Informationen vom Dateisystem ab.
Die Funktion schreibt nichts, loescht nichts und braucht keine Adminrechte.
#>
function Test-ScanFolder {
    param (
        # Der Ordnerpfad, den der Benutzer eingegeben hat.
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        return $false
    }

    return (Test-Path -LiteralPath $FolderPath -PathType Container)
}

<#
Funktion: Get-SuspiciousNamePatterns

Diese Funktion liefert eine Liste verdächtiger Begriffe und Muster.
Geprueft werden nur Dateinamen, nicht der Inhalt der Dateien.
Die Liste ist absichtlich sichtbar im Klartext, damit jeder sie leicht pruefen,
erweitern oder entfernen kann.

Die Muster sind nicht automatisch ein Beweis fuer Schadsoftware.
Sie sind nur Hinweise auf Dateinamen, die man genauer anschauen sollte.
#>
function Get-SuspiciousNamePatterns {
    return @(
        "token",
        "grabber",
        "stealer",
        "logger",
        "keylogger",
        "rat",
        "backdoor",
        "remote",
        "webhook",
        "discord",
        "inject",
        "payload",
        "miner",
        "crypto",
        "trojan",
        "malware",
        "virus",
        "session",
        "cookie",
        "credential",
        "password",
        "auth",
        "spy",
        "exfil",
        "dropper",
        "loader",
        "silent",
        "hidden"
    )
}

<#
Funktion: Find-SuspiciousModFiles

Diese Funktion durchsucht den angegebenen Ordner rekursiv nach Dateien.
Rekursiv bedeutet: Auch Unterordner werden mit durchsucht.

Get-ChildItem wird hier nur lesend verwendet:
- Es listet Dateien auf.
- Es oeffnet keine Datei zur Bearbeitung.
- Es loescht keine Datei.
- Es sendet keine Daten.

Danach wird der Dateiname in Kleinbuchstaben umgewandelt, damit die Suche
nicht an Gross- oder Kleinschreibung scheitert.
Wenn ein Dateiname einen der sichtbaren Suchbegriffe enthaelt, wird ein Treffer
als einfaches Objekt mit Dateiname, Pfad und gefundenem Muster zurueckgegeben.
#>
function Find-SuspiciousModFiles {
    param (
        # Der vorhandene Ordner, der durchsucht werden soll.
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,

        # Die Klartext-Muster, nach denen in Dateinamen gesucht wird.
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $matches = New-Object System.Collections.Generic.List[object]
    $files = Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $lowerName = $file.Name.ToLowerInvariant()

        foreach ($pattern in $Patterns) {
            if ($lowerName.Contains($pattern.ToLowerInvariant())) {
                $matches.Add([PSCustomObject]@{
                    FileName = $file.Name
                    FullPath = $file.FullName
                    MatchedPattern = $pattern
                })

                break
            }
        }
    }

    return $matches
}

<#
Funktion: Show-ScanResults

Diese Funktion zeigt die gefundenen Treffer im PowerShell-Fenster an.
Angezeigt werden:
- der Dateiname
- der vollstaendige Pfad
- das Suchmuster, das im Dateinamen gefunden wurde

Die Funktion ist nur Ausgabe. Sie nimmt keine Aenderungen an Dateien vor.
#>
function Show-ScanResults {
    param (
        # Die Trefferliste, die von Find-SuspiciousModFiles erzeugt wurde.
        # Eine leere Liste ist erlaubt, weil ein sauberer Scan ohne Treffer
        # ein normales Ergebnis ist und keinen Fehler ausloesen soll.
        [AllowEmptyCollection()]
        [object[]]$Matches = @()
    )

    # Falls PowerShell aus irgendeinem Grund $null uebergibt, behandeln wir
    # das genauso wie eine leere Trefferliste.
    if ($null -eq $Matches) {
        $Matches = @()
    }

    if ($Matches.Count -eq 0) {
        Write-Host ""
        Write-Host "Keine verdaechtigen Dateinamen gefunden." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "Verdaechtige Dateinamen gefunden:" -ForegroundColor Red
    Write-Host ""

    foreach ($match in $Matches) {
        Write-Host ("Datei:  {0}" -f $match.FileName) -ForegroundColor White
        Write-Host ("Pfad:   {0}" -f $match.FullPath) -ForegroundColor White
        Write-Host ("Muster: {0}" -f $match.MatchedPattern) -ForegroundColor White
        Write-Host ""
    }
}

<#
Funktion: Start-OpenModScanner

Diese Funktion ist der Hauptablauf des Programms.
Sie verbindet die anderen Funktionen in einer klaren Reihenfolge:
1. Hinweis anzeigen.
2. Ordner vom Benutzer abfragen.
3. Ordner pruefen.
4. Suchmuster laden.
5. Dateien nach verdächtigen Namen durchsuchen.
6. Ergebnisse anzeigen.

Auch im Hauptablauf gibt es keine Schreibzugriffe, keine Netzwerkanfragen,
keine Downloads, keine Registry-Aenderungen und keine Hintergrundprozesse.
#>
function Start-OpenModScanner {
    Write-Info "OpenModScanner - quelloffener Minecraft-Mod-Dateinamen-Scanner"
    Write-Info "Dieses Skript liest nur Dateinamen und Pfade. Es veraendert keine Dateien."
    Write-Host ""

    $folderPath = Get-ScanFolderFromUser

    if (-not (Test-ScanFolder -FolderPath $folderPath)) {
        Write-WarningMessage "Der angegebene Ordner wurde nicht gefunden oder ist kein Ordner."
        return
    }

    $patterns = Get-SuspiciousNamePatterns
    # Das @(...)-Konstrukt sorgt dafuer, dass PowerShell immer eine Liste erzeugt.
    # Ohne diese Klammerung kann PowerShell bei null Treffern den Wert $null liefern.
    $matches = @(Find-SuspiciousModFiles -FolderPath $folderPath -Patterns $patterns)

    Show-ScanResults -Matches $matches
}

Start-OpenModScanner
