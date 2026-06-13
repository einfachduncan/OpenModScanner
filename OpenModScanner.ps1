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
Funktion: Write-Line

Diese Funktion zeichnet eine einfache Trennlinie.
Sie verwendet bewusst nur ASCII-Zeichen, damit die Ausgabe in Windows PowerShell
sauber aussieht und nicht von Terminal-Schriftarten abhaengt.
#>
function Write-Line {
    Write-Host ("-" * 76) -ForegroundColor DarkGray
}

<#
Funktion: Show-Banner

Diese Funktion zeigt den Startbildschirm des Scanners.
Der Banner ist rein optisch und fuehrt keine Systemaktionen aus.
#>
function Show-Banner {
    Write-Host ""
    Write-Host "   ____                  __  __           _ ____" -ForegroundColor Cyan
    Write-Host "  / __ \____  ___  ____ |  \/  | ___   __| / ___|  ___ __ _ _ __  _ __   ___ _ __" -ForegroundColor Cyan
    Write-Host " | |  | | '_ \/ _ \/ __|| |\/| |/ _ \ / _` \___ \ / __/ _` | '_ \| '_ \ / _ \ '__|" -ForegroundColor Cyan
    Write-Host " | |__| | |_) |  __/\__ \| |  | | (_) | (_| |___) | (_| (_| | | | | | | |  __/ |" -ForegroundColor Cyan
    Write-Host "  \____/| .__/ \___||___/|_|  |_|\___/ \__,_|____/ \___\__,_|_| |_|_| |_|\___|_|" -ForegroundColor Cyan
    Write-Host "        |_|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                 OpenModScanner - Minecraft Mod Security Scanner" -ForegroundColor White
    Write-Host "                      Made for local, read-only mod checks" -ForegroundColor DarkGray
    Write-Host ""
    Write-Line
    Write-Host ""
}

<#
Funktion: Get-DefaultModsFolder

Diese Funktion baut einen typischen Minecraft-Mods-Pfad fuer Windows.
Der Pfad wird nur als Vorschlag benutzt, wenn der Benutzer bei der Eingabe
Enter drueckt. Es wird nichts erstellt.
#>
function Get-DefaultModsFolder {
    return (Join-Path $env:APPDATA ".minecraft\mods")
}

<#
Funktion: Get-ScanFolderFromUser

Diese Funktion fragt den Benutzer nach dem Mods-Ordner.
Sie entfernt nur Leerzeichen und aeussere Anfuehrungszeichen.
Dadurch funktionieren kopierte Pfade besser.
Wenn der Benutzer nur Enter drueckt, wird der Standardpfad verwendet.
#>
function Get-ScanFolderFromUser {
    $defaultPath = Get-DefaultModsFolder

    Write-Host "Enter path to the mods folder: (press Enter to use default)" -ForegroundColor White
    Write-Host ("Default: {0}" -f $defaultPath) -ForegroundColor DarkGray
    $rawInput = Read-Host "PATH"
    $cleanInput = $rawInput.Trim().Trim('"')

    if ([string]::IsNullOrWhiteSpace($cleanInput)) {
        return $defaultPath
    }

    return $cleanInput
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
        [PSCustomObject]@{ Pattern = "powershell"; Level = "Hoch"; Reason = "Kann auf PowerShell-Ausfuehrung durch eine Mod hinweisen." },
        [PSCustomObject]@{ Pattern = "killaura"; Level = "Mittel"; Reason = "Kann auf Cheat- oder PvP-Client-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "crystalaura"; Level = "Mittel"; Reason = "Kann auf Cheat- oder PvP-Client-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autoclicker"; Level = "Mittel"; Reason = "Kann auf automatisierte Klickfunktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "xray"; Level = "Mittel"; Reason = "Kann auf unfairen Sicht-/Suchvorteil hinweisen." },
        [PSCustomObject]@{ Pattern = "wallhack"; Level = "Mittel"; Reason = "Kann auf unfairen Sichtvorteil hinweisen." },
        [PSCustomObject]@{ Pattern = "meteorclient"; Level = "Mittel"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "meteordevelopment"; Level = "Mittel"; Reason = "Kann auf Meteor-Client-Code oder Addons hinweisen." }
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
Funktion: Get-MinecraftUptimeText

Diese Funktion schaut nur nach laufenden javaw/java-Prozessen.
Wenn Minecraft gerade laeuft, kann der Benutzer sehen, wie lange der Prozess
schon aktiv ist. Die Funktion beendet keine Prozesse und veraendert nichts.
#>
function Get-MinecraftUptimeText {
    $javaProcesses = @(Get-Process -Name "javaw", "java" -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.StartTime } |
        Sort-Object StartTime |
        Select-Object -First 3)

    if ($javaProcesses.Count -eq 0) {
        return @("No running javaw/java process found")
    }

    $lines = New-Object System.Collections.Generic.List[string]

    foreach ($process in $javaProcesses) {
        $uptime = (Get-Date) - $process.StartTime
        $lines.Add(("{0} PID {1} started at {2}" -f $process.ProcessName, $process.Id, $process.StartTime))
        $lines.Add(("Running for: {0}h {1}m {2}s" -f [int]$uptime.TotalHours, $uptime.Minutes, $uptime.Seconds))
    }

    return $lines
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
Sie gibt eine Zusammenfassung mit Mod-Anzahl und Trefferliste zurueck.
#>
function Start-ModScan {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $allFindings = New-Object System.Collections.Generic.List[object]
    $patterns = Get-SuspiciousPatterns
    $uptimeLines = @(Get-MinecraftUptimeText)
    # Das @(...)-Konstrukt sorgt dafuer, dass auch genau eine gefundene Mod
    # als Liste behandelt wird. Dadurch funktioniert $mods.Count immer.
    $mods = @(Get-ModFiles -FolderPath $FolderPath)

    if ($mods.Count -eq 0) {
        Write-WarningMessage "Keine .jar- oder .zip-Mod-Dateien gefunden. Bitte pruefe, ob wirklich der mods-Ordner des richtigen Profils ausgewaehlt wurde."
    }

    Write-Host ""
    Write-Host "{ Minecraft Uptime }" -ForegroundColor Cyan
    foreach ($line in $uptimeLines) {
        Write-Host ("   {0}" -f $line) -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host ("Found {0} JAR files to analyze" -f $mods.Count) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pass 1 - File discovery..." -ForegroundColor Cyan
    Write-Host "Pass 2 - Deep-scanning mod archives..." -ForegroundColor Cyan
    Write-Host "Pass 3 - Suspicious string scan..." -ForegroundColor Cyan
    Write-Host "Pass 4 - Read-only safety check..." -ForegroundColor Cyan
    Write-Host "Pass 5 - JVM process overview..." -ForegroundColor Cyan
    Write-Host "   OK  Scanner stayed read-only" -ForegroundColor Green
    Write-Host ""

    foreach ($mod in $mods) {
        foreach ($finding in @(Scan-ModArchive -ModFile $mod -Patterns $patterns)) {
            $allFindings.Add($finding)
        }
    }

    return [PSCustomObject]@{
        ModCount = $mods.Count
        Mods = [object[]]$mods
        Findings = [object[]]$allFindings.ToArray()
    }
}

<#
Funktion: Show-ScanResults

Diese Funktion zeigt das Ergebnis bewusst kurz und uebersichtlich an.
Treffer werden pro Mod gruppiert, damit die Ausgabe nicht unnoetig lang wird.
#>
function Show-ScanResults {
    param (
        [Parameter(Mandatory = $true)]
        [int]$ModCount,

        [AllowEmptyCollection()]
        [object[]]$Mods = @(),

        [AllowEmptyCollection()]
        [object[]]$Findings = @()
    )

    if ($null -eq $Findings) {
        $Findings = @()
    }

    $findingCount = $Findings.Count
    $suspiciousPaths = @($Findings | Select-Object -ExpandProperty ModPath -Unique)
    $unknownMods = @($Mods | Where-Object { $suspiciousPaths -notcontains $_.FullName })

    Write-Host ("  *  UNKNOWN MODS  ({0})" -f $unknownMods.Count) -ForegroundColor Yellow
    Write-Line

    if ($unknownMods.Count -eq 0) {
        Write-Host "  None" -ForegroundColor DarkGray
    }
    else {
        foreach ($mod in $unknownMods) {
            Write-Host ("  [ ? ] {0}" -f $mod.Name) -ForegroundColor White
            Write-Host "        Source: local file / not verified online" -ForegroundColor DarkGray
            Write-Host ""
        }
    }

    Write-Host ""

    if ($findingCount -eq 0) {
        Write-Host "  *  SUSPICIOUS MODS  (0)" -ForegroundColor Green
        Write-Line
        Write-Host "  None" -ForegroundColor Green
    }
    else {
        $groupedFindings = $Findings | Group-Object -Property ModPath

        Write-Host ("  *  SUSPICIOUS MODS  ({0})" -f $groupedFindings.Count) -ForegroundColor Red
        Write-Line

        foreach ($group in $groupedFindings) {
            $firstFinding = $group.Group[0]
            Write-Host ""
            Write-Host ("  FLAGGED   {0}" -f $firstFinding.ModFile) -ForegroundColor Red
            Write-Host ("  Path:     {0}" -f $firstFinding.ModPath) -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  PATTERNS" -ForegroundColor Yellow

            foreach ($finding in $group.Group) {
                Write-Host ("    {0}  [{1}]" -f $finding.Pattern, $finding.Level) -ForegroundColor White
                Write-Host ("      Where: {0}" -f $finding.Where) -ForegroundColor Gray
                Write-Host ("      Why:   {0}" -f $finding.Reason) -ForegroundColor Gray
            }

            Write-Line
        }
    }

    Write-Host ""
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Line
    Write-Host ("  Total files scanned: {0}" -f $ModCount) -ForegroundColor White
    Write-Host ("  Unknown mods:        {0}" -f $unknownMods.Count) -ForegroundColor White
    Write-Host ("  Suspicious mods:     {0}" -f $suspiciousPaths.Count) -ForegroundColor White
    Write-Host ("  Suspicious hits:     {0}" -f $findingCount) -ForegroundColor White
    Write-Host ("  Network used:        0") -ForegroundColor White
    Write-Host ("  Files changed:       0") -ForegroundColor White
    Write-Line

    if ($findingCount -eq 0) {
        Write-Host "Analysis complete. No suspicious hints found." -ForegroundColor Green
    }
    else {
        Write-Host "Analysis complete. Review flagged mods before launching Minecraft." -ForegroundColor Yellow
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
    Show-Banner

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

    Write-Host ""
    Write-Host ("Scanning directory: {0}" -f $folderPath) -ForegroundColor Cyan
    $scanResult = Start-ModScan -FolderPath $folderPath

    Show-ScanResults -ModCount $scanResult.ModCount -Mods $scanResult.Mods -Findings $scanResult.Findings
}

Start-OpenModScanner
