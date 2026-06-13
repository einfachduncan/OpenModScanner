<#
OpenModScanner.ps1

Ein quelloffener Minecraft-Mod-Scanner fuer Windows PowerShell.

Wichtig:
- Das Skript liest nur Dateien aus dem Ordner, den der Benutzer angibt.
- Das Skript veraendert, verschiebt und loescht keine Dateien.
- Das Skript sendet nur dann Hashes an Modrinth/Megabase, wenn der Benutzer
  die Online-Verifikation ausdruecklich mit y aktiviert.
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
    Write-Host "██╗    ██╗ █████╗ ██╗  ██╗███████╗██████╗ " -ForegroundColor Cyan
    Write-Host "██║    ██║██╔══██╗╚██╗██╔╝██╔════╝██╔══██╗" -ForegroundColor Cyan
    Write-Host "██║ █╗ ██║███████║ ╚███╔╝ █████╗  ██║  ██║" -ForegroundColor Cyan
    Write-Host "██║███╗██║██╔══██║ ██╔██╗ ██╔══╝  ██║  ██║" -ForegroundColor Cyan
    Write-Host "╚███╔███╔╝██║  ██║██╔╝ ██╗███████╗██████╔╝" -ForegroundColor Cyan
    Write-Host " ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝ " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "███╗   ███╗ ██████╗ ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗  ██╗   ██╗████████╗███████╗██████╗ " -ForegroundColor Cyan
    Write-Host "████╗ ████║██╔═══██╗██╔══██╗    ██╔══██╗████╗  ██║██╔══██╗██║  ╚██╗ ██╔╝╚══██╔══╝██╔════╝██╔══██╗" -ForegroundColor Cyan
    Write-Host "██╔████╔██║██║   ██║██║  ██║    ███████║██╔██╗ ██║███████║██║   ╚████╔╝    ██║   █████╗  ██████╔╝" -ForegroundColor Cyan
    Write-Host "██║╚██╔╝██║██║   ██║██║  ██║    ██╔══██║██║╚██╗██║██╔══██║██║    ╚██╔╝     ██║   ██╔══╝  ██╔══██╗" -ForegroundColor Cyan
    Write-Host "██║ ╚═╝ ██║╚██████╔╝██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗██║      ██║   ███████╗██║  ██║" -ForegroundColor Cyan
    Write-Host "╚═╝     ╚═╝ ╚═════╝ ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                 WaxedMod Analyzer - Minecraft Mod Security Scanner" -ForegroundColor White
    Write-Host "                              Made by Waxed" -ForegroundColor DarkGray
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
Funktion: Get-OnlineVerificationChoice

Diese Funktion fragt den Benutzer, ob bekannte Mods online verifiziert werden
sollen. Standard ist Nein, damit ohne ausdrueckliche Zustimmung keine Daten ins
Internet gesendet werden. Wenn der Benutzer y eingibt, werden spaeter nur
SHA1-Dateihashes an Modrinth und Megabase gesendet.
#>
function Get-OnlineVerificationChoice {
    Write-Host ""
    Write-Host "Online verification with Modrinth/Megabase? [y/N]" -ForegroundColor White
    Write-Host "Default: N - offline mode, no hashes are sent" -ForegroundColor DarkGray
    $choice = Read-Host "VERIFY"

    return ($choice.Trim().ToLowerInvariant() -eq "y")
}

<#
Funktion: Query-Modrinth

Diese Funktion fragt die oeffentliche Modrinth-API mit einem SHA1-Hash.
Sie wird nur aufgerufen, wenn der Benutzer Online-Verifikation aktiviert hat.
Es wird kein Mod-Inhalt hochgeladen, sondern nur der Hash der Datei.
#>
function Query-Modrinth {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Hash
    )

    try {
        $versionInfo = Invoke-RestMethod -Uri ("https://api.modrinth.com/v2/version_file/{0}" -f $Hash) -Method Get -UseBasicParsing -ErrorAction Stop

        if (($versionInfo.PSObject.Properties.Name -contains "project_id") -and $null -ne $versionInfo.project_id) {
            $projectInfo = Invoke-RestMethod -Uri ("https://api.modrinth.com/v2/project/{0}" -f $versionInfo.project_id) -Method Get -UseBasicParsing -ErrorAction Stop

            return [PSCustomObject]@{
                Source = "Modrinth"
                Name = [string]$projectInfo.title
                Slug = [string]$projectInfo.slug
            }
        }
    }
    catch {
        return $null
    }

    return $null
}

<#
Funktion: Query-Megabase

Diese Funktion fragt die Megabase-API mit einem SHA1-Hash.
Sie wird nur aufgerufen, wenn Modrinth keinen Treffer liefert und der Benutzer
Online-Verifikation aktiviert hat. Auch hier wird nur der Hash gesendet.
#>
function Query-Megabase {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Hash
    )

    try {
        $result = Invoke-RestMethod -Uri ("https://megabase.vercel.app/api/query?hash={0}" -f $Hash) -Method Get -UseBasicParsing -ErrorAction Stop

        $hasData = ($result.PSObject.Properties.Name -contains "data") -and $null -ne $result.data
        $hasError = ($result.PSObject.Properties.Name -contains "error") -and [bool]$result.error

        if ($hasData -and -not $hasError) {
            return [PSCustomObject]@{
                Source = "Megabase"
                Name = [string]$result.data.name
                Slug = [string]$result.data.slug
            }
        }
    }
    catch {
        return $null
    }

    return $null
}

<#
Funktion: Get-ModVerification

Diese Funktion berechnet zuerst lokal den SHA1-Hash der Mod-Datei.
Wenn Online-Verifikation aktiv ist, fragt sie damit Modrinth und danach
Megabase. Gibt eine Verifikation zurueck, wenn eine bekannte Mod gefunden wird.
#>
function Get-ModVerification {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ModFile,

        [Parameter(Mandatory = $true)]
        [bool]$UseOnlineVerification
    )

    try {
        $hash = (Get-FileHash -LiteralPath $ModFile.FullName -Algorithm SHA1 -ErrorAction Stop).Hash
    }
    catch {
        return $null
    }

    if (-not $UseOnlineVerification) {
        return $null
    }

    $verified = Query-Modrinth -Hash $hash

    if ($null -eq $verified) {
        $verified = Query-Megabase -Hash $hash
    }

    if ($null -eq $verified) {
        return $null
    }

    return [PSCustomObject]@{
        ModFile = $ModFile.Name
        ModPath = $ModFile.FullName
        Hash = $hash
        Source = $verified.Source
        Name = $verified.Name
        Slug = $verified.Slug
    }
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
        [PSCustomObject]@{ Pattern = "killaura"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Cheat- oder PvP-Client-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "clickaura"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Cheat- oder PvP-Client-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "multiaura"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Cheat- oder PvP-Client-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "forcefield"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Aura-/Auto-Angriff-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "crystalaura"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Cheat- oder PvP-Client-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autocrystal"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Crystal-PvP-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autoanchor"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Anchor-PvP-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "anchoraura"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Anchor-PvP-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "bedaura"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Bed-PvP-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autoclicker"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatisierte Klickfunktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "triggerbot"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Angriffsausloesung hinweisen." },
        [PSCustomObject]@{ Pattern = "aimassist"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Aim-Assist-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "aimbot"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Aim-Bot-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "silentaim"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf stille Zielhilfe hinweisen." },
        [PSCustomObject]@{ Pattern = "bowaimbot"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Aim-Bot-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autototem"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Totem-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "inventorytotem"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Totem-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "hover totem"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Totem-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autopot"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Potion-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autoarmor"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Armor-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "autoeat"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Ess-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "auto weapon"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Waffenwahl hinweisen." },
        [PSCustomObject]@{ Pattern = "autoweapon"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Waffenwahl hinweisen." },
        [PSCustomObject]@{ Pattern = "shieldbreaker"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Schild-Breaker-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "shielddisabler"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Schild-Disabler-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "xray"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf unfairen Sicht-/Suchvorteil hinweisen." },
        [PSCustomObject]@{ Pattern = "wallhack"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf unfairen Sichtvorteil hinweisen." },
        [PSCustomObject]@{ Pattern = "blockesp"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf ESP-/Anzeige-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "storageesp"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf ESP-/Anzeige-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "chestesp"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf ESP-/Anzeige-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "playeresp"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf ESP-/Anzeige-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "itemesp"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf ESP-/Anzeige-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "tracers"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Spieler-/Entity-Tracking hinweisen." },
        [PSCustomObject]@{ Pattern = "nuker"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Blockzerstoerung hinweisen." },
        [PSCustomObject]@{ Pattern = "scaffold"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Bau-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "airplace"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf unfaire Platzierungs-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "ghosthand"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf unfaire Interaktions-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "nofall"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf No-Fall-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "noslow"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf No-Slow-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "antiknockback"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Anti-Knockback-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "velocityspoof"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Velocity-/Knockback-Spoofing hinweisen." },
        [PSCustomObject]@{ Pattern = "timerhack"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Timer-/Speed-Manipulation hinweisen." },
        [PSCustomObject]@{ Pattern = "packetfly"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Bewegungs-Cheats hinweisen." },
        [PSCustomObject]@{ Pattern = "elytraspeed"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Elytra-Speed-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "cheststealer"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Inventar-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "invmanager"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf automatische Inventar-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "fakelag"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Netzwerk-/Lag-Manipulation hinweisen." },
        [PSCustomObject]@{ Pattern = "pingspoof"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Ping-Spoofing hinweisen." },
        [PSCustomObject]@{ Pattern = "packetcancel"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Packet-Manipulation hinweisen." },
        [PSCustomObject]@{ Pattern = "packetmine"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Packet-Mining-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "grimbypass"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Anti-Cheat-Bypass hinweisen." },
        [PSCustomObject]@{ Pattern = "vulcanbypass"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Anti-Cheat-Bypass hinweisen." },
        [PSCustomObject]@{ Pattern = "matrixbypass"; Level = "Mittel"; Section = "PATTERNS"; Reason = "Kann auf Anti-Cheat-Bypass hinweisen." },
        [PSCustomObject]@{ Pattern = "seedcracker"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Seed-Rekonstruktionswerkzeuge hinweisen." },
        [PSCustomObject]@{ Pattern = "orefinder"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Erzsuch-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "stashfinder"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Such-/Finder-Funktionen hinweisen." },
        [PSCustomObject]@{ Pattern = "meteorclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "meteor-client"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Meteor-Client-Code oder Addons hinweisen." },
        [PSCustomObject]@{ Pattern = "meteordevelopment"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Meteor-Client-Code oder Addons hinweisen." },
        [PSCustomObject]@{ Pattern = "meteordevelopment.meteorclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Meteor-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "meteordevelopment/meteorclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Meteor-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "wurstclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Wurst-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "wurst-client"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Wurst-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "net.wurstclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Wurst-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "net/wurstclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Wurst-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "wurstplus"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Wurst-Plus-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "wurst+"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Wurst-Plus-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "dev.krypton"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Krypton-/Crypton-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "kryptonclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Krypton-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "krypton-client"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Krypton-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "cryptonclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Crypton-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "crypton-client"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf Crypton-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "cevapi"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf CevAPI-/Crystal-PvP-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "cev-api"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf CevAPI-/Crystal-PvP-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "cev api"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf CevAPI-/Crystal-PvP-Client-Code hinweisen." },
        [PSCustomObject]@{ Pattern = "liquidbounce"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "rusherhack"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "vapeclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "futureclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "impactclient"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "aristois"; Level = "Mittel"; Section = "STRINGS"; Reason = "Kann auf einen bekannten Utility-/Cheat-Client hinweisen." },
        [PSCustomObject]@{ Pattern = "sessionstealer"; Level = "Hoch"; Section = "STRINGS"; Reason = "Kann auf Account-/Session-Diebstahl hinweisen." },
        [PSCustomObject]@{ Pattern = "tokengrabber"; Level = "Hoch"; Section = "STRINGS"; Reason = "Kann auf Token-Diebstahl hinweisen." },
        [PSCustomObject]@{ Pattern = "tokenlogger"; Level = "Hoch"; Section = "STRINGS"; Reason = "Kann auf Token-Logging hinweisen." },
        [PSCustomObject]@{ Pattern = "keylogger"; Level = "Hoch"; Section = "STRINGS"; Reason = "Kann auf Tastatur-Aufzeichnung hinweisen." },
        [PSCustomObject]@{ Pattern = "backdoor"; Level = "Hoch"; Section = "STRINGS"; Reason = "Kann auf eine Hintertuer hinweisen." },
        [PSCustomObject]@{ Pattern = "reverseshell"; Level = "Hoch"; Section = "STRINGS"; Reason = "Kann auf Remote-Zugriff hinweisen." }
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
        Section = "STRINGS"
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
Funktion: New-FindingFromPattern

Diese Funktion baut einen Treffer direkt aus einem Suchmuster-Objekt.
Dadurch bleibt die Zuordnung zu PATTERNS oder STRINGS erhalten.
#>
function New-FindingFromPattern {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModFile,

        [Parameter(Mandatory = $true)]
        [string]$ModPath,

        [Parameter(Mandatory = $true)]
        [string]$Where,

        [Parameter(Mandatory = $true)]
        [object]$Pattern
    )

    return [PSCustomObject]@{
        ModFile = $ModFile
        ModPath = $ModPath
        Where = $Where
        Pattern = $Pattern.Pattern
        Level = $Pattern.Level
        Section = $Pattern.Section
        Reason = $Pattern.Reason
    }
}

<#
Funktion: Get-ModFiles

Diese Funktion sucht im angegebenen Ordner nach Mod-Dateien.
Minecraft-Mods sind meistens .jar-Dateien. .jar-Dateien sind technisch ZIP-Archive.
Die Funktion listet nur die Hauptdateien direkt im angegebenen Mods-Ordner auf
und veraendert nichts.
Auch deaktivierte Mod-Dateien wie name.jar.disabled werden erkannt, weil sie
technisch weiterhin JAR-Dateien sein koennen.
#>
function Get-ModFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $scanErrors = @()
    $allFiles = @(Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue -ErrorVariable scanErrors)

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
Funktion: Test-GibberishClassName

Diese Funktion prueft eine Java-Klassendatei grob auf verschleierte Namen.
Das ist nur eine Heuristik: kurze, zufaellige oder vokallose Namen koennen
harmlos sein, sind aber bei Obfuscation haeufig.
#>
function Test-GibberishClassName {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ClassName
    )

    $simpleName = [System.IO.Path]::GetFileNameWithoutExtension($ClassName)

    if ($simpleName.Length -le 2) {
        return $true
    }

    if ($simpleName.Length -ge 5 -and $simpleName -notmatch "[aeiouAEIOU]") {
        return $true
    }

    if ($simpleName -match "[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{5,}") {
        return $true
    }

    return $false
}

<#
Funktion: Scan-ModObfuscation

Diese Funktion untersucht nur die Namen von .class-Dateien innerhalb einer Mod.
Sie liest keine Dateien ausfuehrend und entpackt nichts dauerhaft.
Wenn sehr viele Klassennamen zufaellig wirken, wird die Mod als moeglich
obfuscated angezeigt. Die Grenze ist absichtlich streng, damit normale
Performance- und Library-Mods nicht zu schnell als auffaellig erscheinen.
#>
function Scan-ModObfuscation {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ModFile
    )

    $archive = $null

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ModFile.FullName)
        $classEntries = @($archive.Entries | Where-Object { $_.FullName.ToLowerInvariant().EndsWith(".class") })

        if ($classEntries.Count -eq 0) {
            return $null
        }

        $gibberishEntries = @($classEntries | Where-Object { Test-GibberishClassName -ClassName $_.FullName })
        $percent = [math]::Round(($gibberishEntries.Count / [double]$classEntries.Count) * 100)

        if ($gibberishEntries.Count -ge 20 -and $percent -ge 35) {
            return [PSCustomObject]@{
                ModFile = $ModFile.Name
                ModPath = $ModFile.FullName
                Percent = $percent
                Count = $gibberishEntries.Count
                Total = $classEntries.Count
                Reason = "Gibberish class names"
            }
        }
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    return $null
}

<#
Funktion: Get-BypassInjectionPatterns

Diese Funktion liefert Suchbegriffe fuer klare Bypass-, Agent- und
Injection-Hinweise. Normale Minecraft-Mod-Technik wie Mixins, ASM oder
Launchwrapper steht hier bewusst nicht drin, weil besonders Fabric-Mods diese
Begriffe oft ganz harmlos verwenden.
#>
function Get-BypassInjectionPatterns {
    return @(
        "javaagent",
        "-javaagent",
        "premain",
        "agentmain",
        "dllinject",
        "dll injection",
        "native injector",
        "anticheatbypass",
        "anti-cheat bypass",
        "grimbypass",
        "vulcanbypass",
        "matrixbypass"
    )
}

<#
Funktion: Scan-ModBypassInjection

Diese Funktion sucht in einem Mod-Archiv nach Hinweisen auf Agenten,
Injection, Bytecode-Transformation oder Bypass-Begriffe.
Das ist eine statische Read-only-Pruefung.
#>
function Scan-ModBypassInjection {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ModFile
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $patterns = Get-BypassInjectionPatterns
    $archive = $null

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ModFile.FullName)

        foreach ($entry in $archive.Entries) {
            $entryName = $entry.FullName.ToLowerInvariant()

            foreach ($pattern in $patterns) {
                if ($entryName.Contains($pattern.ToLowerInvariant())) {
                    $findings.Add([PSCustomObject]@{
                        ModFile = $ModFile.Name
                        ModPath = $ModFile.FullName
                        Pattern = $pattern
                        Where = ("Archiv-Pfad: {0}" -f $entry.FullName)
                    })
                }
            }

            if (Test-EntryShouldBeRead -Entry $entry) {
                $entryText = Read-ArchiveEntryAsText -Entry $entry
                $lowerText = $entryText.ToLowerInvariant()

                foreach ($pattern in $patterns) {
                    if ($lowerText.Contains($pattern.ToLowerInvariant())) {
                        $findings.Add([PSCustomObject]@{
                            ModFile = $ModFile.Name
                            ModPath = $ModFile.FullName
                            Pattern = $pattern
                            Where = ("Inhalt: {0}" -f $entry.FullName)
                        })
                    }
                }
            }
        }
    }
    catch {
        return @()
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    return [object[]]$findings.ToArray()
}

<#
Funktion: Scan-JvmAgents

Diese Funktion liest laufende Java-Prozesse aus und sucht in der Kommandozeile
nach Agent- oder Injection-Hinweisen wie -javaagent.
Sie beendet keine Prozesse und startet nichts.
#>
function Scan-JvmAgents {
    $issues = New-Object System.Collections.Generic.List[object]

    try {
        $javaProcesses = @(Get-CimInstance Win32_Process -Filter "name = 'javaw.exe' or name = 'java.exe'" -ErrorAction SilentlyContinue)

        foreach ($process in $javaProcesses) {
            $commandLine = [string]$process.CommandLine
            $lowerCommandLine = $commandLine.ToLowerInvariant()

            foreach ($pattern in @(Get-BypassInjectionPatterns)) {
                if ($lowerCommandLine.Contains($pattern.ToLowerInvariant())) {
                    $issues.Add([PSCustomObject]@{
                        ProcessId = $process.ProcessId
                        ProcessName = $process.Name
                        Pattern = $pattern
                    })
                }
            }
        }
    }
    catch {
        return @()
    }

    return [object[]]$issues.ToArray()
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
        $findings.Add((New-FindingFromPattern -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where "Mod-Dateiname" -Pattern $pattern))
    }

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ModFile.FullName)

        foreach ($entry in $archive.Entries) {
            foreach ($pattern in @(Find-PatternsInText -Text $entry.FullName -Patterns $Patterns)) {
                $findings.Add((New-FindingFromPattern -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where ("Archiv-Pfad: {0}" -f $entry.FullName) -Pattern $pattern))
            }

            if (Test-EntryShouldBeRead -Entry $entry) {
                $entryText = Read-ArchiveEntryAsText -Entry $entry

                if (-not [string]::IsNullOrWhiteSpace($entryText)) {
                    foreach ($pattern in @(Find-PatternsInText -Text $entryText -Patterns $Patterns)) {
                        $findings.Add((New-FindingFromPattern -ModFile $ModFile.Name -ModPath $ModFile.FullName -Where ("Inhalt: {0}" -f $entry.FullName) -Pattern $pattern))
                    }
                }
            }
        }
    }
    catch {
        # Ein Lesefehler allein soll keine Mod als Cheat markieren. Bereits
        # vorher gefundene Dateinamen-Signaturen bleiben aber erhalten.
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    return $findings
}

<#
Funktion: Write-SpinnerStatus

Diese Funktion zeigt eine einzeilige Lade-Anzeige an.
Sie ueberschreibt immer dieselbe Konsolenzeile. Dadurch sieht der Benutzer,
dass der Scanner arbeitet, ohne dass fuer jede einzelne Mod viele neue Zeilen
ausgegeben werden.
#>
function Write-SpinnerStatus {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [int]$Total,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $frames = @("|", "/", "-", "\")
    $frame = $frames[$Index % $frames.Count]
    $shortName = $Name

    if ($shortName.Length -gt 46) {
        $shortName = $shortName.Substring(0, 43) + "..."
    }

    Write-Host ("`r   [{0}] {1}: {2}/{3} - {4}        " -f $frame, $Activity, $Index, $Total, $shortName) -NoNewline -ForegroundColor DarkGray
}

<#
Funktion: Clear-SpinnerStatus

Diese Funktion raeumt die Lade-Anzeige nach einem Pass auf.
Sie schreibt Leerzeichen ueber die aktuelle Zeile und springt danach in eine
neue Zeile, damit die naechste Ausgabe sauber beginnt.
#>
function Clear-SpinnerStatus {
    Write-Host ("`r" + (" " * 100) + "`r") -NoNewline
}

<#
Funktion: Show-ClosingCredits

Diese Funktion zeigt den Abschlussbereich nach dem Scan an.
Der Bereich ist rein optisch. Er speichert nichts, liest keine Dateien und
stellt keine Netzwerkverbindung her.
#>
function Show-ClosingCredits {
    $sparkles = [char]::ConvertFromUtf32(0x2728)
    $person = [char]::ConvertFromUtf32(0x1F464)
    $star = [char]::ConvertFromUtf32(0x1F31F)
    $phone = [char]::ConvertFromUtf32(0x1F4F1)
    $link = [char]::ConvertFromUtf32(0x1F517)

    Write-Host ""
    Write-Host ("  {0} Analysis complete! Thanks for using OpenModScanner" -f $sparkles) -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  {0} Created by: {1} einfachduncan" -f $person, $star) -ForegroundColor White
    Write-Host ("  {0} Project:    {1} GitHub   : https://github.com/einfachduncan/OpenModScanner" -f $phone, $link) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("-" * 71) -ForegroundColor DarkCyan
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
        [string]$FolderPath,

        [Parameter(Mandatory = $true)]
        [bool]$UseOnlineVerification
    )

    $allFindings = New-Object System.Collections.Generic.List[object]
    $obfuscatedMods = New-Object System.Collections.Generic.List[object]
    $bypassFindings = New-Object System.Collections.Generic.List[object]
    $verifiedMods = New-Object System.Collections.Generic.List[object]
    $patterns = Get-SuspiciousPatterns
    # Das @(...)-Konstrukt sorgt dafuer, dass auch genau eine gefundene Mod
    # als Liste behandelt wird. Dadurch funktioniert $mods.Count immer.
    $mods = @(Get-ModFiles -FolderPath $FolderPath)

    Write-Host ""
    Write-Host ("Found {0} JAR files to analyze" -f $mods.Count) -ForegroundColor Cyan
    Write-Host ""

    $iconSearch = [char]::ConvertFromUtf32(0x1F50D)
    $iconMicroscope = [char]::ConvertFromUtf32(0x1F52C)
    $iconShield = [char]::ConvertFromUtf32(0x1F6E1)
    $iconMagnifier = [char]::ConvertFromUtf32(0x1F50E)
    $iconZap = [char]::ConvertFromUtf32(0x26A1)

    if ($UseOnlineVerification) {
        Write-Host ("{0} Pass 1 - Hash verification (Modrinth + Megabase)..." -f $iconSearch) -ForegroundColor Cyan
    }
    else {
        Write-Host ("{0} Pass 1 - Hash verification (offline; Modrinth + Megabase disabled)..." -f $iconSearch) -ForegroundColor Cyan
    }

    $index = 0
    foreach ($mod in $mods) {
        $index++
        Write-SpinnerStatus -Activity "Hash verify" -Index $index -Total $mods.Count -Name $mod.Name
        $verification = Get-ModVerification -ModFile $mod -UseOnlineVerification $UseOnlineVerification

        if ($null -ne $verification) {
            $verifiedMods.Add($verification)
        }
    }
    Clear-SpinnerStatus

    Write-Host ("{0} Pass 2 - Deep-scanning all {1} mods..." -f $iconMicroscope, $mods.Count) -ForegroundColor Cyan
    $index = 0
    foreach ($mod in $mods) {
        $index++
        Write-SpinnerStatus -Activity "Deep scan" -Index $index -Total $mods.Count -Name $mod.Name
        foreach ($finding in @(Scan-ModArchive -ModFile $mod -Patterns $patterns)) {
            $allFindings.Add($finding)
        }
    }
    Clear-SpinnerStatus

    Write-Host ("{0} Pass 3 - Bypass/injection scan on all {1} mods..." -f $iconShield, $mods.Count) -ForegroundColor Cyan
    $index = 0
    foreach ($mod in $mods) {
        $index++
        Write-SpinnerStatus -Activity "Injection scan" -Index $index -Total $mods.Count -Name $mod.Name
        foreach ($finding in @(Scan-ModBypassInjection -ModFile $mod)) {
            $bypassFindings.Add($finding)
        }
    }
    Clear-SpinnerStatus

    Write-Host ("{0} Pass 4 - Obfuscation analysis on all {1} mods..." -f $iconMagnifier, $mods.Count) -ForegroundColor Cyan
    $index = 0
    foreach ($mod in $mods) {
        $index++
        Write-SpinnerStatus -Activity "Obfuscation" -Index $index -Total $mods.Count -Name $mod.Name
        $obfuscation = Scan-ModObfuscation -ModFile $mod

        if ($null -ne $obfuscation) {
            $obfuscatedMods.Add($obfuscation)
        }
    }
    Clear-SpinnerStatus

    Write-Host ("{0} Pass 5 - Scanning JVM for agents and injections..." -f $iconZap) -ForegroundColor Cyan
    Write-SpinnerStatus -Activity "JVM scan" -Index 1 -Total 1 -Name "java/javaw processes"
    $jvmIssues = @(Scan-JvmAgents)
    Clear-SpinnerStatus

    if ($jvmIssues.Count -eq 0) {
        Write-Host "   OK  JVM looks clean" -ForegroundColor Green
    }

    return [PSCustomObject]@{
        ModCount = $mods.Count
        Mods = [object[]]$mods
        VerifiedMods = [object[]]$verifiedMods.ToArray()
        Findings = [object[]]$allFindings.ToArray()
        ObfuscatedMods = [object[]]$obfuscatedMods.ToArray()
        BypassFindings = [object[]]$bypassFindings.ToArray()
        JvmIssues = [object[]]$jvmIssues
        NetworkUsed = $UseOnlineVerification
    }
}
<#
Funktion: Show-ScanResults

Diese Funktion zeigt zuerst eine Haupt-Mod-Tabelle.
Alle sichtbaren Haupt-Mod-Dateien aus dem Ordner werden mit Status angezeigt.
Nur Mods mit Cheat-, Injection-, Obfuscation- oder JVM-Hinweisen werden danach
als geflaggt ausgegeben.
#>
function Show-ScanResults {
    param (
        [Parameter(Mandatory = $true)]
        [int]$ModCount,

        [AllowEmptyCollection()]
        [object[]]$Mods = @(),

        [AllowEmptyCollection()]
        [object[]]$VerifiedMods = @(),

        [AllowEmptyCollection()]
        [object[]]$Findings = @(),

        [AllowEmptyCollection()]
        [object[]]$ObfuscatedMods = @(),

        [AllowEmptyCollection()]
        [object[]]$BypassFindings = @(),

        [AllowEmptyCollection()]
        [object[]]$JvmIssues = @(),

        [Parameter(Mandatory = $true)]
        [bool]$NetworkUsed
    )

    if ($null -eq $VerifiedMods) {
        $VerifiedMods = @()
    }

    if ($null -eq $Findings) {
        $Findings = @()
    }

    if ($null -eq $ObfuscatedMods) {
        $ObfuscatedMods = @()
    }

    if ($null -eq $BypassFindings) {
        $BypassFindings = @()
    }

    if ($null -eq $JvmIssues) {
        $JvmIssues = @()
    }

    $findingCount = $Findings.Count
    $verifiedPaths = @($VerifiedMods | Select-Object -ExpandProperty ModPath -Unique)
    $suspiciousPaths = @($Findings | Select-Object -ExpandProperty ModPath -Unique)
    $bypassPaths = @($BypassFindings | Select-Object -ExpandProperty ModPath -Unique)
    $obfuscatedPaths = @($ObfuscatedMods | Select-Object -ExpandProperty ModPath -Unique)
    $flaggedPaths = @($suspiciousPaths + $bypassPaths | Select-Object -Unique)
    $reviewPaths = @($obfuscatedPaths | Where-Object { $flaggedPaths -notcontains $_ } | Select-Object -Unique)
    $okMark = [char]::ConvertFromUtf32(0x2713)
    $warnMark = "!"
    $reviewMark = "?"
    $flaggedMods = @($Mods | Where-Object { $flaggedPaths -contains $_.FullName } | Sort-Object Name)
    $verifiedCleanMods = @($Mods | Where-Object { ($verifiedPaths -contains $_.FullName) -and ($flaggedPaths -notcontains $_.FullName) } | Sort-Object Name)
    $reviewMods = @($Mods | Where-Object { ($reviewPaths -contains $_.FullName) -and ($flaggedPaths -notcontains $_.FullName) -and ($verifiedPaths -notcontains $_.FullName) } | Sort-Object Name)
    $cleanMods = @($Mods | Where-Object { ($flaggedPaths -notcontains $_.FullName) -and ($verifiedPaths -notcontains $_.FullName) -and ($reviewPaths -notcontains $_.FullName) } | Sort-Object Name)

    Write-Host ""
    Write-Host ("  *  MAIN MODS  ({0})" -f $Mods.Count) -ForegroundColor Cyan
    Write-Line

    if ($Mods.Count -eq 0) {
        Write-Host "  None" -ForegroundColor DarkGray
    }
    else {
        Write-Host ("  {0,-4} {1,-10} {2}" -f "OK", "STATUS", "MOD FILE") -ForegroundColor DarkGray
        Write-Line

        Write-Host ("  FLAGGED  ({0})" -f $flaggedMods.Count) -ForegroundColor Red
        if ($flaggedMods.Count -eq 0) {
            Write-Host "    None" -ForegroundColor DarkGray
        }
        else {
            foreach ($mod in $flaggedMods) {
                Write-Host ("  {0,-4} {1,-10} {2}" -f $warnMark, "FLAGGED", $mod.Name) -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host ("  VERIFIED ({0})" -f $verifiedCleanMods.Count) -ForegroundColor Green
        if ($verifiedCleanMods.Count -eq 0) {
            Write-Host "    None" -ForegroundColor DarkGray
        }
        else {
            foreach ($mod in $verifiedCleanMods) {
                Write-Host ("  {0,-4} {1,-10} {2}" -f $okMark, "VERIFIED", $mod.Name) -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host ("  REVIEW   ({0})" -f $reviewMods.Count) -ForegroundColor Yellow
        if ($reviewMods.Count -eq 0) {
            Write-Host "    None" -ForegroundColor DarkGray
        }
        else {
            foreach ($mod in $reviewMods) {
                Write-Host ("  {0,-4} {1,-10} {2}" -f $reviewMark, "REVIEW", $mod.Name) -ForegroundColor Yellow
            }
        }

        Write-Host ""
        Write-Host ("  CLEAN    ({0})" -f $cleanMods.Count) -ForegroundColor Green
        if ($cleanMods.Count -eq 0) {
            Write-Host "    None" -ForegroundColor DarkGray
        }
        else {
            foreach ($mod in $cleanMods) {
                Write-Host ("  {0,-4} {1,-10} {2}" -f $okMark, "CLEAN", $mod.Name) -ForegroundColor Green
            }
        }
    }

    Write-Host ""

    Write-Host ("  *  VERIFIED MODS  ({0})" -f $VerifiedMods.Count) -ForegroundColor Green
    Write-Line

    if ($VerifiedMods.Count -eq 0) {
        if ($NetworkUsed) {
            Write-Host "  None" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  Disabled - online verification was not enabled" -ForegroundColor DarkGray
        }
    }
    else {
        foreach ($mod in @($VerifiedMods | Sort-Object ModFile)) {
            Write-Host ("  [ OK ] {0}" -f $mod.ModFile) -ForegroundColor Green
            Write-Host ("         {0}: {1}" -f $mod.Source, $mod.Name) -ForegroundColor DarkGray
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

            $patternFindings = @($group.Group | Where-Object { $_.Section -eq "PATTERNS" } | Sort-Object Pattern -Unique)
            $stringFindings = @($group.Group | Where-Object { $_.Section -eq "STRINGS" } | Sort-Object Pattern -Unique)

            if ($patternFindings.Count -gt 0) {
                Write-Host "  PATTERNS" -ForegroundColor Yellow
                foreach ($finding in $patternFindings) {
                    Write-Host ("    {0}" -f $finding.Pattern) -ForegroundColor White
                }
                Write-Host ""
            }

            if ($stringFindings.Count -gt 0) {
                Write-Host "  STRINGS" -ForegroundColor Yellow
                foreach ($finding in $stringFindings) {
                    Write-Host ("    {0}" -f $finding.Pattern) -ForegroundColor White
                }
                Write-Host ""
            }

            Write-Line
        }
    }

    Write-Host ""
    Write-Host ("  *  BYPASS / INJECTION  ({0})" -f $bypassPaths.Count) -ForegroundColor Yellow
    Write-Line

    if ($BypassFindings.Count -eq 0) {
        Write-Host "  None" -ForegroundColor DarkGray
    }
    else {
        foreach ($group in @($BypassFindings | Group-Object -Property ModPath)) {
            $firstFinding = $group.Group[0]
            Write-Host ""
            Write-Host ("  INJECTED?  {0}" -f $firstFinding.ModFile) -ForegroundColor Yellow
            Write-Host ("  Path:      {0}" -f $firstFinding.ModPath) -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  PATTERNS" -ForegroundColor Yellow

            foreach ($finding in @($group.Group | Sort-Object Pattern -Unique)) {
                Write-Host ("    {0}" -f $finding.Pattern) -ForegroundColor White
            }

            Write-Line
        }
    }

    Write-Host ""
    Write-Host ("  *  OBFUSCATED MODS  ({0})" -f $ObfuscatedMods.Count) -ForegroundColor Magenta
    Write-Line

    if ($ObfuscatedMods.Count -eq 0) {
        Write-Host "  None" -ForegroundColor DarkGray
    }
    else {
        foreach ($item in $ObfuscatedMods) {
            Write-Host ""
            Write-Host ("  OBFUSCATED   {0}" -f $item.ModFile) -ForegroundColor Magenta
            Write-Host ("  Path:         {0}" -f $item.ModPath) -ForegroundColor DarkGray
            Write-Host ""
            Write-Host ("  Flag: {0}" -f $item.Reason) -ForegroundColor Yellow
            Write-Host ("    {0}% look obfuscated ({1}/{2} class files)" -f $item.Percent, $item.Count, $item.Total) -ForegroundColor Gray
            Write-Line
        }
    }

    Write-Host ""
    Write-Host ("  *  JVM ISSUES  ({0})" -f $JvmIssues.Count) -ForegroundColor Yellow
    Write-Line

    if ($JvmIssues.Count -eq 0) {
        Write-Host "  None" -ForegroundColor DarkGray
    }
    else {
        foreach ($issue in $JvmIssues) {
            Write-Host ("  JVM FLAG   {0} PID {1}" -f $issue.ProcessName, $issue.ProcessId) -ForegroundColor Yellow
            Write-Host ("    Pattern: {0}" -f $issue.Pattern) -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Line
    Write-Host ("  Total files scanned: {0}" -f $ModCount) -ForegroundColor White
    Write-Host ("  Verified mods:       {0}" -f $VerifiedMods.Count) -ForegroundColor White
    Write-Host ("  Clean mods:          {0}" -f $cleanMods.Count) -ForegroundColor White
    Write-Host ("  Suspicious mods:     {0}" -f $suspiciousPaths.Count) -ForegroundColor White
    Write-Host ("  Bypass/Injected:     {0}" -f $bypassPaths.Count) -ForegroundColor White
    Write-Host ("  Obfuscated mods:     {0}" -f $ObfuscatedMods.Count) -ForegroundColor White
    Write-Host ("  JVM issues:          {0}" -f $JvmIssues.Count) -ForegroundColor White
    $networkNumber = if ($NetworkUsed) { 1 } else { 0 }
    Write-Host ("  Network used:        {0}" -f $networkNumber) -ForegroundColor White
    Write-Host ("  Files changed:       0") -ForegroundColor White
    Write-Line

    if ($findingCount -eq 0 -and $ObfuscatedMods.Count -eq 0 -and $BypassFindings.Count -eq 0 -and $JvmIssues.Count -eq 0) {
        Write-Host "Analysis complete. No suspicious hints found." -ForegroundColor Green
    }
    else {
        Write-Host "Analysis complete. Review flagged mods before launching Minecraft." -ForegroundColor Yellow
    }

    Show-ClosingCredits
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

Eine Netzwerkverbindung wird nur benutzt, wenn der Benutzer die Online-
Verifikation mit y aktiviert. Es gibt keine Datei-Aenderung, keine
Registry-Aenderung, keine Autostarts und keine Hintergrundprozesse.
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
    Write-Host ""
    Write-Host "{ Minecraft Uptime }" -ForegroundColor Cyan
    foreach ($line in @(Get-MinecraftUptimeText)) {
        Write-Host ("   {0}" -f $line) -ForegroundColor DarkGray
    }

    $useOnlineVerification = Get-OnlineVerificationChoice

    $scanResult = Start-ModScan -FolderPath $folderPath -UseOnlineVerification $useOnlineVerification

    Show-ScanResults -ModCount $scanResult.ModCount -Mods $scanResult.Mods -VerifiedMods $scanResult.VerifiedMods -Findings $scanResult.Findings -ObfuscatedMods $scanResult.ObfuscatedMods -BypassFindings $scanResult.BypassFindings -JvmIssues $scanResult.JvmIssues -NetworkUsed $scanResult.NetworkUsed
}

Start-OpenModScanner

