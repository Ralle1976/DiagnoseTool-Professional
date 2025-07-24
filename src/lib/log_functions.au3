#include-once
#include <File.au3>
#include <Array.au3>
#include "log_handler.au3"
#include "log_viewer_robust.au3"  ; Verwende den robusteren Log-Viewer
#include "logging.au3"
#include "simple_log_parser.au3"
#include "parsers\parser_manager_enhanced.au3"

; Hilfsfunktion um Dateiende zu prüfen (mit eindeutigem Namen für diese Datei)
Func __LogFunctions_FileIsEndOfFile($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Umbenannt zu _OpenLogFileStandard, um Namenskonflikt zu vermeiden
Func _OpenLogFileStandard($sFilePath)
    _LogInfo("Öffne Log-Datei: " & $sFilePath)

    ; Prüfen, ob die Datei existiert
    If Not FileExists($sFilePath) Then
        _LogError("Datei nicht gefunden: " & $sFilePath)
        MsgBox(16, "Fehler", "Die angegebene Log-Datei wurde nicht gefunden:" & @CRLF & $sFilePath)
        Return False
    EndIf

    ; Versuche Log-Format zu erkennen
    Local $iFormat = ParserManager_DetectLogFormat($sFilePath)

    If $iFormat = $LOG_FORMAT_UNKNOWN Then
        _LogWarning("Datei wurde nicht als bekanntes Log-Format erkannt")

        ; Erste paar Zeilen der Datei lesen und anzeigen
        Local $hFile = FileOpen($sFilePath, $FO_READ)
        Local $sPreview = ""
        Local $iLineCount = 0

        While Not __LogFunctions_FileIsEndOfFile($hFile) And $iLineCount < 5
            $sPreview &= FileReadLine($hFile) & @CRLF
            $iLineCount += 1
        WEnd

        FileClose($hFile)

        ; Fragen, ob die Datei trotzdem geöffnet werden soll
        Local $iAnswer = MsgBox(52, "Unbekanntes Log-Format", _
                              "Die ausgewählte Datei wurde nicht als bekanntes Log-Format erkannt." & @CRLF & @CRLF & _
                              "Die ersten Zeilen der Datei sehen so aus:" & @CRLF & _
                              StringLeft($sPreview, 300) & "..." & @CRLF & @CRLF & _
                              "Möchten Sie versuchen, sie als normalen Text zu öffnen?" & @CRLF & _
                              "(Möglicherweise fehlen dann einige Funktionen der Log-Analyse)")

        If $iAnswer <> 6 Then ; Nicht Ja
            Return False
        Else
            ; Hier könnte eine alternative Darstellung implementiert werden
            ; Zum Beispiel mit einfacher Text-Ansicht statt strukturierter Analyse
            _LogInfo("Öffne Datei als normalen Text")
            ShellExecute("notepad.exe", $sFilePath)
            Return True
        EndIf
    EndIf

    ; Format wurde erkannt
    _LogInfo("Log-Format erkannt: " & ParserManager_GetFormatName($iFormat))

    ; Log-Datei in Array umwandeln für die Anzeige
    Local $aLogFiles[2] = [1, $sFilePath]

    ; Log-Viewer anzeigen
    _ShowLogViewerRobust($aLogFiles)
    Return True
EndFunc

; Alias für Rückwärtskompatibilität
Func _OpenLogFile($sFilePath)
    Return _OpenLogFileStandard($sFilePath)
EndFunc

; Analysiert eine Logdatei, um deren Format zu bestimmen
Func _AnalyzeLogFormat($sFilePath)
    _LogInfo("Analysiere Logdatei-Format: " & $sFilePath)

    ; Verwende den Parser-Manager
    Local $iFormat = ParserManager_DetectLogFormat($sFilePath)

    ; Format als Text zurückgeben
    Local $sFormatText = ParserManager_GetFormatName($iFormat)

    _LogInfo("Erkanntes Log-Format: " & $sFormatText)
    Return $sFormatText
EndFunc

; Funktion zur besseren Fehlerbehandlung beim Log-Parsing
Func _SafeParseLogFile($sFilePath)
    _LogInfo("Versuche Logdatei zu parsen: " & $sFilePath)

    ; Datei-Existenz prüfen
    If Not FileExists($sFilePath) Then
        _LogError("Logdatei existiert nicht: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf

    ; Datei-Größe prüfen
    Local $iFileSize = FileGetSize($sFilePath)
    If $iFileSize = 0 Then
        _LogWarning("Logdatei ist leer: " & $sFilePath)
        Return SetError(2, 0, 0)
    EndIf

    ; Dateiinhalt prüfen
    If $iFileSize > 50000000 Then ; 50MB
        _LogWarning("Logdatei ist sehr groß (" & Round($iFileSize / 1048576, 2) & " MB), dies kann zu Verzögerungen führen")
    EndIf

    ; Versuche das Format zu erkennen
    Local $iFormat = ParserManager_DetectLogFormat($sFilePath)

    If $iFormat = $LOG_FORMAT_UNKNOWN Then
        _LogWarning("Kein bekanntes Log-Format erkannt")
        Return SetError(3, 0, 0)
    EndIf

    ; Log-Datei parsen
    Local $aEntries = ParserManager_ParseLogFile($sFilePath)

    If @error Then
        _LogError("Fehler beim Parsen der Logdatei: " & @error)
        Return SetError(4, @error, 0)
    EndIf

    If UBound($aEntries) = 0 Then
        _LogWarning("Keine Log-Einträge gefunden oder Parsing fehlgeschlagen")
        Return SetError(5, 0, 0)
    EndIf

    _LogInfo("Logdatei erfolgreich geparst: " & UBound($aEntries) & " Einträge gefunden")
    Return $aEntries
EndFunc