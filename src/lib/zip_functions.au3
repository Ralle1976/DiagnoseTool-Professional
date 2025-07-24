#include-once
#include <File.au3>
#include "logging.au3"
#include "globals.au3" ; Für Zugriff auf $g_sevenZipPath und $g_sevenZipDll

; Diese Datei enthält Funktionen für die Verarbeitung von ZIP-Archiven

Func _IsValidZipFile($sFile)
    If Not FileExists($sFile) Then Return False
    
    Local $bValid = False
    Local $hFile = FileOpen($sFile, 16) ; Binär lesen
    If $hFile <> -1 Then
        Local $sHeader = FileRead($hFile, 2)
        If @error Then
            FileClose($hFile)
            Return False
        EndIf
        
        ; Prüfen, ob die ersten 2 Bytes dem ZIP-Header "PK" entsprechen
        If BinaryToString($sHeader) = "PK" Then
            $bValid = True
        EndIf
        
        FileClose($hFile)
    EndIf
    
    Return $bValid
EndFunc

Func _Extract7Zip($sSourceArchive, $sDestDir)
    _LogInfo("Extrahiere " & $sSourceArchive & " nach " & $sDestDir)
    
    ; Prüfen, ob 7-Zip-Tools verfügbar sind
    If FileExists($g_sevenZipPath) And FileExists($g_sevenZipDll) Then
        ; Verzeichnis erstellen, falls es nicht existiert
        If Not FileExists($sDestDir) Then
            DirCreate($sDestDir)
        EndIf
        
        ; Extrahieren
        Local $iExitCode = RunWait('"' & $g_sevenZipPath & '" x "' & $sSourceArchive & '" -o"' & $sDestDir & '" -y', @ScriptDir, @SW_HIDE)
        
        If $iExitCode <> 0 Then
            _LogError("Fehler beim Extrahieren: " & $iExitCode)
            Return False
        EndIf
        
        _LogInfo("Extraktion abgeschlossen")
        Return True
    Else
        _LogError("7-Zip nicht gefunden")
        Return False
    EndIf
EndFunc

Func _ScanForDatabases($sDirectory)
    Local $aDBFiles = _FileListToArray($sDirectory, "*.db;*.db3", $FLTAR_FILES, True)
    
    If @error Then
        _LogWarning("Keine Datenbankdateien gefunden in " & $sDirectory)
        Return 0
    EndIf
    
    _LogInfo("Gefundene Datenbankdateien: " & $aDBFiles[0])
    
    For $i = 1 To $aDBFiles[0]
        _LogInfo("DB-Datei gefunden: " & $aDBFiles[$i])
    Next
    
    Return $aDBFiles
EndFunc

Func _GetFirstDatabaseFromArray($aDBFiles)
    If Not IsArray($aDBFiles) Or $aDBFiles[0] = 0 Then
        Return ""
    EndIf
    
    Return $aDBFiles[1]
EndFunc

Func _CleanupExtracted($sDirectory)
    If $sDirectory <> "" And FileExists($sDirectory) Then
        _LogInfo("Räume Extraktionsverzeichnis auf: " & $sDirectory)
        
        ; Hier könnte man eine selektive Löschung implementieren
        DirRemove($sDirectory, 1) ; 1 = Rekursiv
    EndIf
EndFunc

; Download URL von 7-Zip Webseite ermitteln mit Pattern Matching
Func _Get7ZipDownloadUrl()
    Local Const $sBaseUrl = "https://7-zip.org/"
    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")

    _LogInfo("Lade Webseite: " & $sBaseUrl & "download.html")

    $oHTTP.Open("GET", $sBaseUrl & "download.html", False)
    $oHTTP.Send()

    If $oHTTP.Status <> 200 Then
        _LogError("HTTP Fehler: " & $oHTTP.Status)
        Return ""
    EndIf

    Local $sHtml = $oHTTP.ResponseText
    _LogInfo("HTML geladen, Länge: " & StringLen($sHtml))

    ; Pattern für Extra Package (standalone console version)
    Local $sPattern = '(?i)<TR>\s*<TD[^>]*>\s*<A\s+href="(a/7z\d+-extra\.7z)"'
    Local $aMatch = StringRegExp($sHtml, $sPattern, 1)

    If @error Then
        _LogError("Download-Link nicht gefunden", "Pattern: " & $sPattern)
        Return ""
    EndIf

    Local $sUrl = $sBaseUrl & $aMatch[0]
    _LogInfo("Download URL gefunden: " & $sUrl)
    Return $sUrl
EndFunc

; Download und Installation von 7za
Func CheckAndDownload7Zip()
    _LogInfo("Prüfe 7-Zip Installation")

    ; Prüfen ob 7za.exe und dll bereits existieren
    If FileExists($g_sevenZipPath) And FileExists($g_sevenZipDll) Then
        _LogInfo("7za.exe und dll bereits vorhanden")
        Return True
    EndIf

    ; Download URL ermitteln
    Local $sURL = _Get7ZipDownloadUrl()
    If $sURL = "" Then
        _LogError("Konnte Download-URL nicht ermitteln")
        Return False
    EndIf

    _LogInfo("Starte Download von: " & $sURL)

    ; Download durchführen
    Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
    $oHTTP.Open("GET", $sURL, False)
    $oHTTP.Send()

    If $oHTTP.Status <> 200 Then
        _LogError("Download fehlgeschlagen")
        Return False
    EndIf

    ; Temporäre Datei erstellen
    Local $sTempArchive = @TempDir & "\7z-extra.7z"
    Local $hFile = FileOpen($sTempArchive, $FO_BINARY + $FO_OVERWRITE)
    If $hFile = -1 Then
        _LogError("Konnte temporäre Datei nicht erstellen")
        Return False
    EndIf
    FileWrite($hFile, $oHTTP.ResponseBody)
    FileClose($hFile)

    ; Temporäres Entpackverzeichnis
    Local $sTempExtract = @TempDir & "\7z-extra"
    If Not DirCreate($sTempExtract) Then
        _LogError("Konnte temporäres Verzeichnis nicht erstellen")
        FileDelete($sTempArchive)
        Return False
    EndIf

    ; Mit Windows Bordmitteln entpacken
    Local $oShell = ObjCreate("Shell.Application")
    Local $oSource = $oShell.NameSpace($sTempArchive)
    Local $oDest = $oShell.NameSpace($sTempExtract)

    If Not IsObj($oSource) Or Not IsObj($oDest) Then
        _LogError("Shell-Objekte konnten nicht erstellt werden")
        FileDelete($sTempArchive)
        DirRemove($sTempExtract, 1)
        Return False
    EndIf

    ; Alles entpacken
    $oDest.CopyHere($oSource.Items(), 16)
    Sleep(2000) ; Warten auf Entpackvorgang

    ; Benötigte Dateien suchen und kopieren
    Local $bFoundExe = False
    Local $bFoundDll = False

    Local $aFiles = _FileListToArray($sTempExtract)
    If Not @error Then
        For $i = 1 To $aFiles[0]
            Select
                Case StringRegExp($aFiles[$i], "(?i)^7za\.exe$")
                    FileCopy($sTempExtract & "\" & $aFiles[$i], $g_sevenZipPath, 1)
                    $bFoundExe = True
                Case StringRegExp($aFiles[$i], "(?i)^7za\.dll$")
                    FileCopy($sTempExtract & "\" & $aFiles[$i], $g_sevenZipDll, 1)
                    $bFoundDll = True
            EndSelect
        Next
    EndIf

    ; Aufräumen
    FileDelete($sTempArchive)
    DirRemove($sTempExtract, 1)

    ; Prüfen ob alles geklappt hat
    If Not $bFoundExe Or Not $bFoundDll Then
        _LogError("Konnte benötigte Dateien nicht finden")
        Return False
    EndIf

    If Not FileExists($g_sevenZipPath) Or Not FileExists($g_sevenZipDll) Then
        _LogError("Installation fehlgeschlagen")
        Return False
    EndIf

    _LogInfo("7za Installation erfolgreich")
    Return True
EndFunc