#include-once
#include <WinHttp.au3>
#include <WinHttpConstants.au3>
#include <File.au3>
#include <StringConstants.au3>
#include "logging.au3"
#include "missing_functions.au3"
#include "zip_functions.au3"
#include "log_viewer.au3"
#include "sqlite_handler.au3"

; Globale Variablen für ZIP-Verarbeitung
Global $g_sCurrentExtractPath = "" ; Aktuelles Extraktionsverzeichnis
Global $g_sLastOpenedZip = "" ; Zuletzt geöffnete ZIP-Datei

; Hauptfunktion für ZIP-Dateien
Func _ProcessZipFile($sFile)
    _LogInfo("Starte ZIP-Datei Verarbeitung: " & $sFile)
    
    ; Speichern Sie den zuletzt geöffneten ZIP-Pfad
    $g_sLastOpenedZip = $sFile
    
    ; Prüfen ob 7-Zip vorhanden ist und ggf. herunterladen
    If Not CheckAndDownload7Zip() Then
        MsgBox(16, "Fehler", "7-Zip konnte nicht installiert werden. Die Verarbeitung wird fortgesetzt mit eventuell vorhandenen Komponenten.")
    EndIf
    
    Local $sTimeStamp = StringReplace(_NowCalc(), ":", "-")
    $sTimeStamp = StringReplace($sTimeStamp, " ", "_")
    $sTimeStamp = StringReplace($sTimeStamp, "/", "-")
    
    Local $sExtractPath = @TempDir & "\diagnose-tool\extracted\DiagnoseTool_" & $sTimeStamp
    
    ; Speichern Sie das aktuelle Extraktionsverzeichnis
    $g_sCurrentExtractPath = $sExtractPath

    _LogInfo("Extrahiere ZIP-Datei nach: " & $sExtractPath)
    
    Local $sPassword = IniRead($g_sSettingsFile, "ZIP", "password", "")
    $sPassword = StringReplace($sPassword, "password=", "")
    _LogInfo("Passwort aus INI gelesen")

    Local $sCmd = '"' & $g_sevenZipPath & '" x -y'
    If $sPassword <> "" Then
        $sCmd &= ' -p"' & $sPassword & '"'
    EndIf
    $sCmd &= ' -o"' & $sExtractPath & '" "' & $sFile & '"'

    DirCreate($sExtractPath)

    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD)
    Local $sOutput = "", $sError = ""
    
    While ProcessExists($iPID)
        $sOutput &= StdoutRead($iPID)
        $sError &= StderrRead($iPID)
        Sleep(100)
    WEnd
    
    ProcessWaitClose($iPID)
    
    $sOutput &= StdoutRead($iPID)
    $sError &= StderrRead($iPID)

    If StringLen($sError) > 0 Then
        _LogError("Fehler beim Entpacken: " & $sError)
        Return False
    EndIf

    _LogInfo("ZIP-Datei erfolgreich entpackt")
    Return _ZH_ProcessExtractedFiles($sExtractPath)
EndFunc

; Funktion zum Verarbeiten von entpackten Dateien
Func _ZH_ProcessExtractedFiles($sExtractPath)
    _LogInfo("Verarbeite entpackte Dateien in: " & $sExtractPath)
    
    ; Nach allen unterstützten Dateitypen suchen
    Local $aLogFiles = _FindLogFiles($sExtractPath)
    Local $aDBFiles = _FindDatabaseFiles($sExtractPath)
    
    ; Zusammenfassung für den Benutzer anzeigen
    Local $sMessage = "Folgende Dateien wurden im Archiv gefunden:" & @CRLF & @CRLF
    
    If $aLogFiles[0] > 0 Then
        $sMessage &= "- " & $aLogFiles[0] & " Log-Datei(en)" & @CRLF
    EndIf
    
    If $aDBFiles[0] > 0 Then
        $sMessage &= "- " & $aDBFiles[0] & " Datenbank(en)" & @CRLF
    EndIf
    
    $sMessage &= @CRLF & "Was möchten Sie öffnen?"
    
    ; Optionen abhängig von gefundenen Dateien
    Local $iAnswer
    If $aLogFiles[0] > 0 And $aDBFiles[0] > 0 Then
        $iAnswer = MsgBox(3 + 32, "Dateien gefunden", $sMessage & @CRLF & @CRLF & "Ja = Logs anzeigen, Nein = Datenbank öffnen")
        If $iAnswer = 6 Then ; Ja (Logs)
            _ShowLogViewer($aLogFiles)
            ; Danach fragen, ob auch die Datenbank geöffnet werden soll
            If MsgBox(4 + 32, "Datenbank öffnen?", "Möchten Sie jetzt auch die Datenbank öffnen?") = 6 Then
                Return _OpenDatabaseFile($aDBFiles[1])
            EndIf
            Return True
        ElseIf $iAnswer = 7 Then ; Nein (DBs)
            Return _OpenDatabaseFile($aDBFiles[1])
        EndIf
    ElseIf $aLogFiles[0] > 0 Then
        $iAnswer = MsgBox(4 + 32, "Log-Dateien gefunden", $sMessage & @CRLF & @CRLF & "Möchten Sie die Logdateien anzeigen?")
        If $iAnswer = 6 Then ; Ja
            _ShowLogViewer($aLogFiles)
            Return True
        EndIf
    ElseIf $aDBFiles[0] > 0 Then
        Return _OpenDatabaseFile($aDBFiles[1])
    Else
        MsgBox(48, "Keine unterstützten Dateien", "Im Archiv wurden keine Log-Dateien oder Datenbanken gefunden.")
        Return False
    EndIf
    
    Return False
EndFunc

; Funktion zum Finden von Datenbankdateien
Func _FindDatabaseFiles($sPath)
    _LogInfo("Suche Datenbankdateien in: " & $sPath)
    Local $aDBFiles[0]
    
    ; Dateien mit .db und .db3 Erweiterung suchen
    Local $aFiles = _FileListToArrayRec($sPath, "*.db;*.db3", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
    If @error Then
        _LogInfo("Keine Datenbankdateien gefunden in: " & $sPath)
        Return $aDBFiles
    EndIf
    
    ; SQLite-Signaturen prüfen
    For $i = 1 To $aFiles[0]
        If _IsSQLiteDatabase($aFiles[$i]) Then
            _ArrayAdd($aDBFiles, $aFiles[$i])
            _LogInfo("Datenbank gefunden: " & $aFiles[$i])
        EndIf
    Next
    
    ; Metadaten zum Array hinzufügen
    ReDim $aDBFiles[UBound($aDBFiles) + 1]
    For $i = UBound($aDBFiles) - 1 To 1 Step -1
        $aDBFiles[$i] = $aDBFiles[$i - 1]
    Next
    $aDBFiles[0] = UBound($aDBFiles) - 1
    
    _LogInfo("Insgesamt " & $aDBFiles[0] & " Datenbankdateien gefunden")
    Return $aDBFiles
EndFunc

; Prüft, ob eine Datei eine SQLite-Datenbank ist
Func _IsSQLiteDatabase($sFilePath)
    ; Vereinfachte Prüfung: Dateiendung und Existenz
    If Not FileExists($sFilePath) Then Return False
    
    ; Einfache Heuristik: Dateigröße > 0 und Endung
    If FileGetSize($sFilePath) > 0 And StringRegExp($sFilePath, "\.(db|db3)$", $STR_REGEXPMATCH) Then
        Return True
    EndIf
    
    Return False
EndFunc

; Funktion zum erneuten Öffnen des Log-Viewers für das aktuelle Archiv
Func _OpenCurrentArchiveLogs()
    If $g_sCurrentExtractPath = "" Then
        MsgBox(48, "Hinweis", "Es ist derzeit kein Archiv geöffnet.")
        Return False
    EndIf
    
    Local $aLogFiles = _FindLogFiles($g_sCurrentExtractPath)
    If $aLogFiles[0] = 0 Then
        MsgBox(48, "Hinweis", "Im aktuellen Archiv wurden keine Log-Dateien gefunden.")
        Return False
    EndIf
    
    _ShowLogViewer($aLogFiles)
    Return True
EndFunc

; Funktion zum Öffnen des Extraktionsverzeichnisses im Explorer
Func _OpenExtractDirectory()
    If $g_sCurrentExtractPath = "" Then
        MsgBox(48, "Hinweis", "Es ist derzeit kein Archiv geöffnet.")
        Return False
    EndIf
    
    If Not FileExists($g_sCurrentExtractPath) Then
        MsgBox(16, "Fehler", "Das Extraktionsverzeichnis existiert nicht mehr.")
        Return False
    EndIf
    
    ShellExecute($g_sCurrentExtractPath)
    Return True
EndFunc