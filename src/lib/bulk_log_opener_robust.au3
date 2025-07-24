#include-once
#include <File.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include <StringConstants.au3>
#include "logging.au3"
#include "log_viewer.au3"
#include "constants_new.au3"
#include "globals.au3"
#include "utils.au3"
#include "json_test_utils.au3"  ; Testfunktionen für JSON-Parser
#include "parsers\parser_manager_enhanced.au3"  ; Verbesserten Parser-Manager einbinden

; Funktion zum Öffnen eines Verzeichnisses mit Logdateien (robuste Version)
Func _OpenLogFolderRobust()
    _LogInfo("Öffne Logdateien aus Ordner (robust)")

    ; Extraktionsverzeichnis als Startverzeichnis verwenden, falls verfügbar
    Local $sStartDir = $g_sExtractDir <> "" ? $g_sExtractDir : $g_sLastDir
    ; Ordnerauswahldialog anzeigen
    Local $sFolder = FileSelectFolder("Ordner mit Logdateien auswählen", $sStartDir)
    If @error Then Return

    ; Letzten Verzeichnispfad speichern
    $g_sLastDir = $sFolder

    ; Logdateien im Verzeichnis suchen (rekursiv)
    Local $aLogPatternsFilter = "" ; Leer = alle Dateien

    ; Filtermuster anhand von Standardmustern erstellen
    For $i = 0 To UBound($g_aDefaultLogPatterns) - 1
        If $aLogPatternsFilter <> "" Then $aLogPatternsFilter &= ";"
        $aLogPatternsFilter &= $g_aDefaultLogPatterns[$i]
    Next

    ; Alle Dateien auflisten, die den Filtermustern entsprechen
    Local $aLogFiles = _FileListToArrayRec($sFolder, $aLogPatternsFilter, $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)

    ; Fehlererkennung verbessern und benutzerfreundlicher gestalten
    If @error Or Not IsArray($aLogFiles) Then
        _LogWarning("Keine Logdateien im Verzeichnis gefunden: " & $sFolder)
        If @error = 1 Then
            MsgBox($MB_ICONINFORMATION, "Hinweis", "Das angegebene Verzeichnis existiert nicht:" & @CRLF & $sFolder)
        ElseIf @error = 4 Then
            MsgBox($MB_ICONINFORMATION, "Hinweis", "Keine Logdateien im Verzeichnis gefunden:" & @CRLF & $sFolder & @CRLF & @CRLF & "Hinweis: Es werden nur Dateien mit folgenden Erweiterungen berücksichtigt: " & $aLogPatternsFilter)
        Else
            MsgBox($MB_ICONINFORMATION, "Hinweis", "Fehler beim Durchsuchen des Verzeichnisses: " & @error & @CRLF & $sFolder)
        EndIf
        Return
    EndIf

    _LogInfo("Gefundene Logdateien: " & $aLogFiles[0])

    ; Gefundene Logdateien filtern (nur tatsächliche Logdateien behalten)
    Local $aFilteredLogFiles[1] = [0]  ; [0] = Anzahl der Elemente
    Local $iFilteredCount = 0

    For $i = 1 To $aLogFiles[0]
        ; Prüfen, ob die Datei ein Log sein könnte
        If _LooksLikeLogFile($aLogFiles[$i]) Then
            $iFilteredCount += 1
            ReDim $aFilteredLogFiles[$iFilteredCount + 1]
            $aFilteredLogFiles[$iFilteredCount] = $aLogFiles[$i]
        EndIf
    Next

    $aFilteredLogFiles[0] = $iFilteredCount

    If $iFilteredCount = 0 Then
        _LogWarning("Keine gültigen Logdateien im Verzeichnis gefunden: " & $sFolder)
        MsgBox($MB_ICONINFORMATION, "Hinweis", "Es wurden " & $aLogFiles[0] & " Dateien gefunden, aber keine davon scheint eine gültige Logdatei zu sein." & @CRLF & @CRLF & "Hinweis: Das Programm prüft den Inhalt der Dateien auf typische Log-Muster.")
        Return
    EndIf

    _LogInfo("Gefilterte Logdateien: " & $iFilteredCount)

    ; Log-Viewer mit den gefilterten Logdateien öffnen
    _ShowLogViewer($aFilteredLogFiles)
EndFunc

; Funktion zum Testen des verbesserten JSON-Parsers mit unvollständigen Einträgen
Func _TestIncompleteJsonParser()
    _LogInfo("Teste verbesserten JSON-Parser mit unvollständigen Einträgen")

    ; Testdatei erstellen
    Local $sTestFile = @TempDir & "\test_incomplete_logs.json"
    If _CreateJsonTestFile($sTestFile, True) Then
        _LogInfo("Testdatei erstellt: " & $sTestFile)

        ; Parser testen
        If _TestJsonParser($sTestFile) Then
            ; Erfolgsmeldung an Benutzer
            MsgBox(64, "Test erfolgreich", "Der Test des verbesserten JSON-Parsers war erfolgreich." & @CRLF & @CRLF & _
                   "Die Testdatei mit unvollständigen Einträgen wurde korrekt geparst." & @CRLF & @CRLF & _
                   "Testdatei: " & $sTestFile & @CRLF & @CRLF & _
                   "Hinweis: Sie können diese Datei nun mit dem Log-Viewer öffnen," & @CRLF & _
                   "um zu sehen, wie unvollständige Einträge angezeigt werden.")

            ; Testdatei gleich öffnen
            _OpenLogFileRobust($sTestFile)
            Return True
        Else
            _LogError("Fehler beim Testen des JSON-Parsers")
            MsgBox(16, "Testfehler", "Der Test des verbesserten JSON-Parsers ist fehlgeschlagen.")
            Return False
        EndIf
    Else
        _LogError("Fehler beim Erstellen der Testdatei")
        MsgBox(16, "Testfehler", "Die Testdatei konnte nicht erstellt werden.")
        Return False
    EndIf
EndFunc

; Robuste Version zum Öffnen einer einzelnen Logdatei
Func _OpenLogFileRobust($sFilePath)
    _LogInfo("Öffne einzelne Logdatei (robust): " & $sFilePath)
    ConsoleWrite("DEBUG: _OpenLogFileRobust aufgerufen mit: " & $sFilePath & @CRLF)

    ; Prüfen, ob die Datei existiert
    If Not FileExists($sFilePath) Then
        _LogError("Logdatei nicht gefunden: " & $sFilePath)
        ConsoleWrite("DEBUG: Datei existiert nicht: " & $sFilePath & @CRLF)
        MsgBox($MB_ICONERROR, "Fehler", "Die angegebene Logdatei wurde nicht gefunden:" & @CRLF & $sFilePath)
        Return False
    EndIf
    
    ConsoleWrite("DEBUG: Datei existiert, Größe: " & FileGetSize($sFilePath) & " Bytes" & @CRLF)

    ; Dateigröße prüfen
    Local $iFileSize = FileGetSize($sFilePath)
    If $iFileSize > $g_iMaxFileSizeWarning Then ; Größer als 50 MB
        _LogWarning("Große Logdatei: " & Round($iFileSize / 1048576, 2) & " MB")

        Local $iAnswer = MsgBox($MB_YESNO + $MB_ICONWARNING, "Große Datei", _
            "Die ausgewählte Datei ist sehr groß (" & Round($iFileSize / 1048576, 2) & " MB) und könnte zu Verzögerungen führen." & @CRLF & @CRLF & _
            "Möchten Sie trotzdem fortfahren?" & @CRLF & @CRLF & _
            "Hinweis: Bei sehr großen Dateien werden nur die ersten " & $g_iMaxLogEntriesToShow & " Einträge angezeigt.")

        If $iAnswer <> $IDYES Then
            _LogInfo("Benutzer hat Öffnen der großen Datei abgebrochen")
            Return False
        EndIf
    EndIf

    ; Prüfen, ob die Datei wie eine Log-Datei aussieht
    If Not _LooksLikeLogFile($sFilePath) Then
        _LogWarning("Datei scheint keine Logdatei zu sein: " & $sFilePath)

        Local $iAnswer = MsgBox($MB_YESNO + $MB_ICONWARNING, "Unbekanntes Format", _
            "Die ausgewählte Datei scheint keine Logdatei im bekannten Format zu sein." & @CRLF & @CRLF & _
            "Möchten Sie trotzdem versuchen, sie zu öffnen?" & @CRLF & @CRLF & _
            "Hinweis: Das Programm prüft den Inhalt der Datei auf typische Log-Muster.")

        If $iAnswer <> $IDYES Then
            _LogInfo("Benutzer hat Öffnen der unbekannten Datei abgebrochen")
            Return False
        EndIf
    EndIf

    ; Logdatei in Array für den Viewer umwandeln
    Local $aLogFiles[2] = [1, $sFilePath]
    ConsoleWrite("DEBUG: LogFiles Array erstellt: [" & $aLogFiles[0] & ", " & $aLogFiles[1] & "]" & @CRLF)

    ; Log-Viewer mit der einzelnen Logdatei öffnen
    ConsoleWrite("DEBUG: Rufe _ShowLogViewer auf..." & @CRLF)
    _ShowLogViewer($aLogFiles)
    ConsoleWrite("DEBUG: _ShowLogViewer zurückgekehrt" & @CRLF)
    Return True
EndFunc

; Funktion zum Öffnen von Logs im aktuellen Archiv (robuste Version)
Func _OpenCurrentArchiveLogsRobust()
    _LogInfo("Öffne Logs im aktuellen Archiv (robust): " & $g_sExtractDir)

    ; Prüfen, ob Extraktionsverzeichnis existiert
    If Not FileExists($g_sExtractDir) Then
        _LogError("Extraktionsverzeichnis nicht gefunden: " & $g_sExtractDir)
        MsgBox($MB_ICONERROR, "Fehler", "Das Extraktionsverzeichnis wurde nicht gefunden:" & @CRLF & $g_sExtractDir)
        Return False
    EndIf

    ; Logdateien im Extraktionsverzeichnis suchen (rekursiv)
    Local $aLogPatternsFilter = "" ; Leer = alle Dateien

    ; Filtermuster anhand von Standardmustern erstellen
    For $i = 0 To UBound($g_aDefaultLogPatterns) - 1
        If $aLogPatternsFilter <> "" Then $aLogPatternsFilter &= ";"
        $aLogPatternsFilter &= $g_aDefaultLogPatterns[$i]
    Next

    ; Alle Dateien auflisten, die den Filtermustern entsprechen
    Local $aLogFiles = _FileListToArrayRec($g_sExtractDir, $aLogPatternsFilter, $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)

    ; Fehlererkennung verbessern
    If @error Or Not IsArray($aLogFiles) Then
        _LogWarning("Keine Logdateien im Archiv gefunden: " & $g_sExtractDir)
        MsgBox($MB_ICONINFORMATION, "Hinweis", "Keine Logdateien im aktuellen Archiv gefunden." & @CRLF & @CRLF & "Hinweis: Es werden nur Dateien mit folgenden Erweiterungen berücksichtigt: " & $aLogPatternsFilter)
        Return False
    EndIf

    _LogInfo("Gefundene Logdateien im Archiv: " & $aLogFiles[0])

    ; Gefundene Logdateien filtern (nur tatsächliche Logdateien behalten)
    Local $aFilteredLogFiles[1] = [0]  ; [0] = Anzahl der Elemente
    Local $iFilteredCount = 0

    For $i = 1 To $aLogFiles[0]
        ; Prüfen, ob die Datei ein Log sein könnte
        If _LooksLikeLogFile($aLogFiles[$i]) Then
            $iFilteredCount += 1
            ReDim $aFilteredLogFiles[$iFilteredCount + 1]
            $aFilteredLogFiles[$iFilteredCount] = $aLogFiles[$i]
        EndIf
    Next

    $aFilteredLogFiles[0] = $iFilteredCount

    If $iFilteredCount = 0 Then
        _LogWarning("Keine gültigen Logdateien im Archiv gefunden: " & $g_sExtractDir)
        MsgBox($MB_ICONINFORMATION, "Hinweis", "Es wurden " & $aLogFiles[0] & " Dateien gefunden, aber keine davon scheint eine gültige Logdatei zu sein.")
        Return False
    EndIf

    _LogInfo("Gefilterte Logdateien im Archiv: " & $iFilteredCount)

    ; Log-Viewer mit den gefilterten Logdateien öffnen
    _ShowLogViewer($aFilteredLogFiles)
    Return True
EndFunc