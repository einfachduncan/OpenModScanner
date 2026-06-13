<#
OpenModScanner.ps1

Ein quelloffener Minecraft-Mod-Scanner fuer Windows PowerShell.

Wichtig:
- Das Skript liest nur Dateien aus dem Ordner, den der Benutzer angibt.
- Das Skript veraendert, verschiebt und loescht keine Dateien.
- Das Skript sendet keine Daten ins Internet.
- Das Skript nutzt keine versteckten Downloads.
- Das Skript braucht keine Administratorrechte.
- Das Skript nutzt nur PowerShell- und .NET-Bordmittel.
#>

Set-StrictMode -Version Latest

<#
Funktion: Write-Info

Diese Funktion zeigt normale Hinweise an.
Sie ist nur fuer die Anzeige im PowerShell-Fenster da.
Sie speichert nichts und greift nicht auf Dateien zu.
#>
function Write-Info {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Cyan
}

<#
Funktion: Write-WarningMessage

Diese Funktion zeigt Warnungen an.
Sie wird benutzt, wenn ein Ordner fehlt oder eine Mod-Datei nicht gelesen werden kann.
Sie veraendert keine Dateien.
#>
function Write-WarningMessage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Yellow
}

<#
Funktion: Get-ScanFolderFromUser

Diese Funktion fragt den Benutzer nach dem Mods-Ordner.
Sie entfernt nur Leerzeichen und aeussere Anfuehrungszeichen.
Dadurch funktionieren kopierte Pfade besser.
#>
function Get-ScanFolderFromUser {
    $rawInput = Read-Host "Bitte den zu scannenden Mods-Ordner eingeben"
    return $rawInput.Trim().Trim('"')
}

<#
Funktion: Test-ScanFolder

Diese Funktion prueft, ob der eingegebene Pfad wirklich ein Ordner ist.
Test-Path liest nur Informationen aus dem Dateisystem.
Es wird kein Ordner erstellt und keine Datei geaendert.
#>
function Test-ScanFolder {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        return $false
    }

    return (Test-Path -LiteralPath $FolderPath -PathType Container)
}

<#
Funktion: Get-SuspiciousPatterns

Diese Funktion enthaelt die sichtbare Suchliste.
Jedes Muster hat:
- Pattern: Der Text, nach dem gesucht wird.
- Level: Eine grobe Einschaetzung.
- Reason: Eine einfache Erklaerung fuer den Benutzer.

Die Liste ist absichtlich Klartext, damit jeder pruefen kann, wonach gesucht wird.
Ein Treffer ist kein Beweis fuer Schadsoftware. Er ist nur ein Hinweis.
#>
function Get-SuspiciousPatterns {
    return @(
        [PSCustomObject]@{ Pattern = "token"; Level = "Mittel"; Reason = "Kann auf Token-Diebstahl oder Authentifizierungsdaten hinweisen." },
        [PSCustomObject]@{ Pattern = "grabber"; Level = "Hoch"; Reason = "Wird haeufig fuer Diebstahl-Werkzeuge verwendet." },
        [PSCustomObject]@{ Pattern = "stealer"; Level = "Hoch"; Reason = "Wird haeufig fuer Datendiebstahl verwendet." },
        [PSCustomObject]@{ Pattern = "keylogger"; Level = "Hoch"; Reason = "Kann auf Tastatur-Aufzeichnung hinweisen." },
        [PSCustomObject]@{ Pattern = "webhook"; Level = "Mittel"; Reason = "Kann auf externe Meldungen an Chat- oder Webdienste hinweisen." },
        [PSCustomObject]@{ Pattern = "discord.com/api/webhooks"; Level = "Hoch"; Reason = "Discord-Webhooks werden oft fuer Datenabfluss missbraucht." },
        [PSCustomObject]@{ Pattern = "payload"; Level = "Mittel"; Reason = "Kann auf nachgeladenen oder versteckten Schadcode hinweisen." },
        [PSCustomObject]@{ Pattern = "backdoor"; Level = "Hoch"; Reason = "Kann auf eine Hintertuer hinweisen." },
        [PSCustomObject]@{ Pattern = "rat"; Level = "Mittel"; Reason = "Kann fuer Remote-Access-Tool stehen." },
        [PSCustomObject]@{ Pattern = "miner"; Level = "Mittel"; Reason = "Kann auf Krypto-Mining hinweisen." },
        [PSCustomObject]@{ Pattern = "crypto"; Level = "Niedrig"; Reason = "Kann harmlos sein, sollte aber im Mod-Kontext geprueft werden." },
        [PSCustomObject]@{ Pattern = "exfil"; Level = "Hoch"; Reason = "Abkuerzung fuer Datenabfluss." },
        [PSCustomObject]@{ Pattern = "credential"; Level = "Mittel"; Reason = "Kann auf Zugangsdaten hinweisen." },
        [PSCustomObject]@{ Pattern = "password"; Level = "Mittel"; Reason = "Kann auf Passwort-Bezug hinweisen." },
        [PSCustomObject]@{ Pattern = "session"; Level = "Niedrig"; Reason = "Kann in Mods harmlos sein, ist aber fuer Kontodaten relevant." },
        [PSCustomObject]@{ Pattern = "cookie"; Level = "Mittel"; Reason = "Kann auf Browser- oder Sitzungsdaten hinweisen." },
        [PSCustomObject]@{ Pattern = "java.net.url"; Level = "Mittel"; Reason = "Kann auf Netzwerkzugriffe im Mod-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "urlclassloader"; Level = "Hoch"; Reason = "Kann auf dynamisches Nachladen von Code hinweisen." },
        [PSCustomObject]@{ Pattern = "runtime.getruntime"; Level = "Hoch"; Reason = "Kann auf das Starten externer Programme hinweisen." },
        [PSCustomObject]@{ Pattern = "processbuilder"; Level = "Hoch"; Reason = "Kann auf das Starten externer Programme hinweisen." },
        [PSCustomObject]@{ Pattern = "cmd.exe"; Level = "Hoch"; Reason = "Kann auf Windows-Kommandoausfuehrung hinweisen." },
        [PSCustomObject]@{ Pattern = "powershell"; Level = "Hoch"; Reason = "Kann auf PowerShell-Ausfuehrung durch eine Mod hinweisen." }
    )
}

<#
Funktion: New-Finding

Diese Funktion baut ein einheitliches Treffer-Objekt.
Dadurch sehen alle Ergebnisse gleich aus, egal ob sie aus dem Dateinamen,
aus einem Archiv-Pfad oder aus einer kleinen Datei innerhalb einer Mod stammen.
#>
function New-Finding {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModFile,

        [Parameter(Mandatory = $true)]
        [string]$ModPath,

        [Parameter(Mandatory = $true)]
        [string]$Where,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    return [PSCustomObject]@{
        ModFile = $ModFile
        ModPath = $ModPath
        Where = $Where
        Pattern = $Pattern
        Level = $Level
        Reason = $Reason
    }
}

<#
Funktion: Find-PatternsInText

Diese Funktion prueft einen Text gegen alle Suchmuster.
Sie nutzt einfache Klartext-Suche und keine Verschleierung.
Die Suche ist nicht gross-/kleinschreibungsabhaengig.
#>
function Find-PatternsInText {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [object[]]$Patterns
    )

    $found = New-Object System.Collections.Generic.List[object]
    $lowerText = $Text.ToLowerInvariant()

    foreach ($pattern in $Patterns) {
        $needle = $pattern.Pattern.ToLowerInvariant()

        if ($lowerText.Contains($needle)) {
            $found.Add($pattern)
        }
    }

    return $found
}

<#
Funktion: Get-ModFiles

Diese Funktion sucht im angegebenen Ordner nach Mod-Dateien.
Minecraft-Mods sind meistens .jar-Dateien. .jar-Dateien sind technisch ZIP-Archive.
Die Funktion listet nur Dateien auf und veraendert nichts.
Auch deaktivierte Mod-Dateien wie name.jar.disabled werden erkannt, weil sie
technisch weiterhin JAR-Dateien sein koennen.
#>
function Get-ModFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $scanErrors = @()
    $allFiles = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue -ErrorVariable scanErrors)

    foreach ($scanError in $scanErrors) {
        Write-WarningMessage ("Konnte einen Pfad nicht lesen: {0}" -f $scanError.Exception.Message)
    }

    return @($allFiles | Where-Object {
        $lowerName = $_.Name.ToLowerInvariant()

        $lowerName.EndsWith(".jar") -or
        $lowerName.EndsWith(".zip") -or
        $lowerName.Contains(".jar.")
    })
}

<#
Funktion: Test-EntryShouldBeRead

Diese Funktion entscheidet, ob eine Datei innerhalb einer Mod gelesen werden soll.
Gelesen werden nur kleine Dateien und typische Text-/Metadaten-Dateien.
Auch kleine .class-Dateien werden als Text gelesen, weil viele auffaellige Strings
im Java-Bytecode trotzdem als Klartext vorkommen koennen.

Es wird nichts entpackt. Es wird nur aus dem Archiv-Stream gelesen.
#>
function Test-EntryShouldBeRead {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Entry
    )

    $maxBytes = 1048576

    if ($Entry.Length -le 0 -or $Entry.Length -gt $maxBytes) {
        return $false
    }

    $name = $Entry.FullName.ToLowerInvariant()

    return (
        $name.EndsWith(".json") -or
        $name.EndsWith(".toml") -or
        $name.EndsWith(".properties") -or
        $name.EndsWith(".mf") -or
        $name.EndsWith(".txt") -or
        $name.EndsWith(".yml") -or
        $name.EndsWith(".yaml") -or
        $name.EndsWith(".xml") -or
        $name.EndsWith(".cfg") -or
        $name.EndsWith(".class") -or
        $name.EndsWith("fabric.mod.json") -or
        $name.EndsWith("mods.toml") -or
        $name.EndsWith("mcmod.info")
    )
}

<#
Funktion: Read-ArchiveEntryAsText

Diese Funktion liest eine kleine Datei aus einer Mod als Text.
Sie speichert die Datei nicht auf der Festplatte und entpackt sie nicht dauerhaft.
Sie liest nur den Inhalt in den Arbeitsspeicher, prueft ihn und verwirft ihn danach.
#>
function Read-ArchiveEntryAsText {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Entry
    )

    $stream = $null
    $memory = $null

    try {
        $stream = $Entry.Open()
        $memory = New-Object System.IO.MemoryStream
        $stream.CopyTo($memory)
        $bytes = $memory.ToArray()

        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        return ""
    }
    finally {
        if ($null -ne $memory) {
            $memory.Dispose()
        }

        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

<#
Funktion: Scan-ModArchive

Diese Funktion oeffnet eine .jar- oder .zip-Datei read-only.
Sie prueft:
1. Den Dateinamen der Mod.
2. Die Namen der Dateien im Mod-Archiv.
3. Kleine Text-, Metadaten- und .class-Dateien im Mod-Archiv.

Die Mod wird nicht entpackt, nicht veraendert und nicht geloescht.
#>
function Scan-ModArchive {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ModFile,

        [Parameter(Mandatory = $true)]
        [object[]]$Patterns
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $archive = $null

    foreach ($pattern in @(Find-PatternsInText -Text $ModFile.Name -Patterns $Patterns)) {
        $findings.Add((New-Finding -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where "Mod-Dateiname" -Pattern $pattern.Pattern -Level $pattern.Level -Reason $pattern.Reason))
    }

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ModFile.FullName)

        foreach ($entry in $archive.Entries) {
            foreach ($pattern in @(Find-PatternsInText -Text $entry.FullName -Patterns $Patterns)) {
                $findings.Add((New-Finding -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where ("Archiv-Pfad: {0}" -f $entry.FullName) -Pattern $pattern.Pattern -Level $pattern.Level -Reason $pattern.Reason))
            }

            if (Test-EntryShouldBeRead -Entry $entry) {
                $entryText = Read-ArchiveEntryAsText -Entry $entry

                if (-not [string]::IsNullOrWhiteSpace($entryText)) {
                    foreach ($pattern in @(Find-PatternsInText -Text $entryText -Patterns $Patterns)) {
                        $findings.Add((New-Finding -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where ("Inhalt: {0}" -f $entry.FullName) -Pattern $pattern.Pattern -Level $pattern.Level -Reason $pattern.Reason))
                    }
                }
            }
        }
    }
    catch {
        $findings.Add((New-Finding -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where "Archiv kann nicht gelesen werden" -Pattern "Lesefehler" -Level "Info" -Reason "Die Datei ist keine lesbare JAR/ZIP-Datei oder ist beschaedigt."))
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    return $findings
}

<#
Funktion: Start-ModScan

Diese Funktion startet den eigentlichen Scan.
Sie laedt die Suchmuster, findet Mod-Dateien und scannt jede Mod einzeln.
Sie gibt eine komplette Trefferliste zurueck.
#>
function Start-ModScan {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $allFindings = New-Object System.Collections.Generic.List[object]
    $patterns = Get-SuspiciousPatterns
    # Das @(...)-Konstrukt sorgt dafuer, dass auch genau eine gefundene Mod
    # als Liste behandelt wird. Dadurch funktioniert $mods.Count immer.
    $mods = @(Get-ModFiles -FolderPath $FolderPath)

    Write-Info ("Gefundene Mod-Dateien: {0}" -f $mods.Count)

    if ($mods.Count -eq 0) {
        Write-WarningMessage "Keine .jar- oder .zip-Mod-Dateien gefunden. Bitte pruefe, ob wirklich der mods-Ordner des richtigen Profils ausgewaehlt wurde."
    }

    foreach ($mod in $mods) {
        Write-Host ("Pruefe: {0}" -f $mod.Name) -ForegroundColor DarkGray

        foreach ($finding in @(Scan-ModArchive -ModFile $mod -Patterns $patterns)) {
            $allFindings.Add($finding)
        }
    }

    return $allFindings
}

<#
Funktion: Show-ScanResults

Diese Funktion zeigt das Ergebnis sauber an.
Wenn es keine Treffer gibt, wird eine klare Entwarnung angezeigt.
Wenn es Treffer gibt, werden Mod-Datei, Pfad, Fundstelle, Muster, Risiko und Grund angezeigt.
#>
function Show-ScanResults {
    param (
        [AllowEmptyCollection()]
        [object[]]$Findings = @()
    )

    if ($null -eq $Findings) {
        $Findings = @()
    }

    Write-Host ""

    if ($Findings.Count -eq 0) {
        Write-Host "Keine verdaechtigen Hinweise gefunden." -ForegroundColor Green
        return
    }

    Write-Host ("Verdaechtige Hinweise gefunden: {0}" -f $Findings.Count) -ForegroundColor Red
    Write-Host ""

    foreach ($finding in $Findings) {
        Write-Host ("Risiko:   {0}" -f $finding.Level) -ForegroundColor Yellow
        Write-Host ("Mod:      {0}" -f $finding.ModFile) -ForegroundColor White
        Write-Host ("Pfad:     {0}" -f $finding.ModPath) -ForegroundColor White
        Write-Host ("Stelle:   {0}" -f $finding.Where) -ForegroundColor White
        Write-Host ("Muster:   {0}" -f $finding.Pattern) -ForegroundColor White
        Write-Host ("Grund:    {0}" -f $finding.Reason) -ForegroundColor White
        Write-Host ""
    }
}

<#
Funktion: Start-OpenModScanner

Diese Funktion ist der Hauptablauf:
1. Starttext anzeigen.
2. Mods-Ordner abfragen.
3. Ordner pruefen.
4. Mod-Dateien finden.
5. JAR/ZIP-Dateien read-only pruefen.
6. Ergebnisse anzeigen.

Es gibt keine Netzwerkverbindung, keine Datei-Aenderung, keine Registry-Aenderung,
keine Autostarts und keine Hintergrundprozesse.
#>
function Start-OpenModScanner {
    Write-Info "OpenModScanner - quelloffener Minecraft-Mod-Scanner"
    Write-Info "Read-only: liest Mods, entpackt nichts dauerhaft und veraendert keine Dateien."
    Write-Host ""

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    }
    catch {
        Write-WarningMessage "Die benoetigte .NET-ZIP-Unterstuetzung konnte nicht geladen werden."
        return
    }

    $folderPath = Get-ScanFolderFromUser

    if (-not (Test-ScanFolder -FolderPath $folderPath)) {
        Write-WarningMessage "Der angegebene Ordner wurde nicht gefunden oder ist kein Ordner."
        return
    }

    $findings = @(Start-ModScan -FolderPath $folderPath)
    Show-ScanResults -Findings $findings
}

Start-OpenModScanner
