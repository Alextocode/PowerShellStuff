<#
Dateiname:             Set-Firefoxconfig.ps1
Version:               2.0
Autor:                 Alexander Schüßler
Erstellt:              13.05.2015
Letzte Änderung:       26.05.2015
#>

##############
# Funktionen #
##############
function Set-Firefoxconfig
{
    <#
        .SYNOPSIS
        Eine Funktion, um Einträge in Firefoxkonfigurationsdateien zu ändern

        .DESCRIPTION
        Mit der Funktion können Einträge in Firefoxkonfigurationsdateien, z.B. all.js oder pref.js
        verändert werden. Dabei werden sowohl allgemeine, als auch userbezogene Regeln unterstützt

        .PARAMETER file
        Die Datei, die bearbeitet werden soll. Sie wird als Dateiinfoobjekt übergeben, zum Beispiel durch Ermittlung mit
        Get-Childitem

        .PARAMETER type
        Die Art der Regel, die geändert werden soll. Kann 'pref', 'user_pref' oder 'lock_pref' sein

        .PARAMETER key
        Der Schlüssel der Regel, die bearbeitet werden soll

        .PARAMETER value
        Der neue Wert für diesen Schlüssel

        .INPUTS
        Es sind keine Inputs möglich

        .OUTPUTS
        Gibt true zurück, wenn eine Änderung vorgenommen wurde.
        Gibt false zurück, wenn eine Änderung vorgenommen hätte werden müsste, dies jedoch fehlschlug.
        Gibt null zurück, wenn keine Änderung nötig war.

        .EXAMPLE
        Set-Firefoxconfig -file prefs.js -type user_pref -key browser.newtab.url -value "www.google.de" 
        setzt die aufgerufene Seite für einen neuen Tab für die aktuelle Sitzung auf www.google.de

    #>
    
    param(
    [System.IO.FileInfo]$file,
    [ValidateSet("pref", "user_pref", "lockpref")]
    [string]$type,
    [string]$key,
    $value,
    [System.Boolean]$debug = $false            
    )

    
    begin
    {
        [bool]$inas | Out-Null #inas steht übrigens für "is not a string"
        #Booleans oder Zahlen müssen als Nicht-Strings besonders berücksichtigt werden.... :)
        if($value -eq "true" -or $value -eq $true -or $value -eq "false" -or $value -eq $false -or $value -is [int])
        {                                 
            $exactpattern = "$type(`"$key`", $value);"
            $inas = $true
            if($debug){Write-verbose "Es wurde ein Wahrheitswert oder eine Zahl als Eingabe erkannt: " $value} 
         }
         else
         {
             $inas = $false
             $exactpattern = "$type(`"$key`", `"$value`");"
         }  
    }

    process
    {
        
        #Wenn wir keine Berechtigungen für die Datei haben, haben wir ein Problem und lassen es besser bleiben....
        trap [System.UnauthorizedAccessException]{
           Write-Error "Es ist kein Zugriff auf die Datei "$file.FullName" möglich. Bitte überprüfen Sie die Rechte für diese Datei."
           return $false
        }
        #Zunächst die Datei auslesen
        $content = Get-Content -path $file.FullName

        #Debugzwecke: Ausgabe des derzeitigen Inhaltes der Datei
        if($debug){$content | ? {Write-Verbose $_}}

        #Möglicherweise gibt es die Konfiguration schon exakt so, dann sind wir bereits fertig
        if($content  | ? {$_ -like $exactpattern})
        {
            Write-Host "Konfiguration bereits korrekt, keine weiteren Handlungen nötig für "$file.FullName"."
            return $null
        }
        #Möglicherweise gibt es zwar schon eine Konfiguration für diese Eigenschaft, aber sie hat noch den falschen Wert
        #Dann müssen wir sie entfernen
        elseif($content | ? {$_ -like "$type(`"$key`",*"})
        {
            Write-Host "Konfiguration nicht korrekt, Wert aktualisieren in "$file.FullName"."
            #Filtere die nicht mehr aktuelle Regel heraus
            $content = $content | ? {$_ -notlike "$type(`"$key`",*"}

        } 
        else
        {
            Write-Host "Konfiguration nicht vorhanden, daher eintragen in "$file.FullName"."   
        }
            
        $content += $exactpattern

        #Wir sortieren unsere gesetzten Eigenschaften wieder
        $content = $content | Sort-Object 
        #Dann leeren wir unsere Datei
        Clear-Content $file.FullName
        #und schreiben den veränderten Inhalt wieder hinein.
                
        Add-Content $file.FullName -Value $content
        Write-Host "Konfiguration erfolgreich geändert." 
        return $true
    }
}

##############
#MAIN SCRIPT #
##############


##
##Hier: Setze Proxy auf Systemstandard:
##

#Aktiviere Infonachrichten
$VerbosePreference = "continue"
$ErrorActionPreference = "continue"
$policy = Get-ExecutionPolicy
#Ermittle, ob Ausführung von Skripten erlaubt ist
if($policy -ne "bypass" -and $policy -ne "unrestricted") <#Variante für PowerShell 3.0 oder neuer - nicht praktikabel derzeit => if((Get-ExecutionPolicy) -notin ("bypass", "restricted") #>
{
    try
    {
        #Wenn nein, dann versuche, sie zu erlauben
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
    }
    catch
    {
        #Fehlen die Rechte, die Ausführung zu erlauben, werfe einen Fehler und beende das Skript
        Write-Error "Auf dem Gerät ist die Ausführung von Skripten nicht erlaubt. Es sind daher Administrationsrechte nötig, um diesem Skript die Ausführung zu ermöglichen."
        return
    }
}

<#
$ffsettings = "${env:ProgramFiles(x86)}\Mozilla firefox"
Derzeit nicht benötigt, das ist dann hilfreich, wenn man Einstellungen für alle oder für neue User setzen möchte
#>
    #Das ist das reguläre Verzeichnis für Firefoxnutzerprofile
    $ffusersettings = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if($ffusersettings -eq $null)
    {
        throw [System.IO.DirectoryNotFoundException] "Der Pfad konnte nicht gefunden werden."
    }

#Finde alle Userprofile im Profilordner, rekursiv da die Benutzer-ID zufällig generiert wird und nicht hartkodiert ist.
$profilefiles = Get-Childitem $ffusersettings -Recurse -Force | ? {$_.Name -like 'prefs.js'}

#Setze die Verwendung des Standardproxys für die aktuelle Sitzung
foreach($file in $profilefiles)
{
    try
    {
        Set-Firefoxconfig -file $file -type user_pref -key "network.proxy.type" -value 5 | Out-Null
    }
    catch
    {
        Write-Error "Der Wert konnte nicht geändert werden in "$file.FullName"."
    }
}
