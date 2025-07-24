#cs
Erweiterte Parser Manager Funktionen für Log-Dateien
Verbesserte Version mit Unterstützung für unvollständige JSON-Datensätze
#ce

#include-once
#include "..\constants.au3"
#include "..\logging.au3"
#include "..\log_analysis_utils.au3"
#include "..\robust_json_parser.au3"  ; Neuer robuster Parser für unvollständige JSON-Einträge

; Entferne doppelte Min-Funktion durch Umbenennung
Func ParserManager_Min($a, $b)
    Return ($a < $b) ? $a : $b
EndFunc

; Konstante für unvollständige JSON-Logs
;~ Global Const $LOG_FORMAT_JSON_INCOMPLETE = 6

; Erkennt das Format einer Log-Datei
Func ParserManager_DetectLogFormat($sFilePath)
    _LogInfo("Erkenne Log-Format: " & $sFilePath)

    If Not FileExists($sFilePath) Then
        _LogError("Datei nicht gefunden: " & $sFilePath)
        Return $LOG_FORMAT_UNKNOWN
    EndIf

    ; Datei öffnen und Probeinhalt lesen
    Local $hFileHandle = FileOpen($sFilePath, $FO_READ)
    If $hFileHandle = -1 Then
        _LogError("Konnte Datei nicht öffnen: " & $sFilePath)
        Return $LOG_FORMAT_UNKNOWN
    EndIf

    ; Lese die ersten 20 Zeilen oder max. 20.000 Zeichen (erweitert für bessere Erkennung)
    Local $sContent = ""
    Local $iLines = 0
    Local $sLine = ""

    While Not FileEOF($hFileHandle) And $iLines < 20 And StringLen($sContent) < 20000
        $sLine = FileReadLine($hFileHandle)
        $sContent &= $sLine & @CRLF
        $iLines += 1
    WEnd

    FileClose($hFileHandle)

    ; Prüfe auf spezifisches JSON-Pattern
    If StringRegExp($sContent, $g_sLogPattern) Then
        _LogInfo("Erkannt: JSON Log-Pattern")
        Return $LOG_FORMAT_JSON
    EndIf

    ; Prüfe auf unvollständige JSON-Einträge mit dem einfachen Pattern
    If StringRegExp($sContent, $g_sIncompleteLogPattern) Then
        _LogInfo("Erkannt: Unvollständiges JSON-Format")
        Return $LOG_FORMAT_JSON_INCOMPLETE
    EndIf

    ; Prüfe auf allgemeines JSON-Format
    If StringInStr($sContent, "{") > 0 And StringInStr($sContent, "}") > 0 And _
       (StringInStr($sContent, "Timestamp") > 0 Or StringInStr($sContent, "timestamp") > 0) Then
        _LogInfo("Erkannt: Allgemeines JSON-Format")
        Return $LOG_FORMAT_JSON_GENERIC
    EndIf

    ; Prüfe auf JSON-ähnliche Einträge (möglicherweise unvollständig)
    If StringInStr($sContent, "{") > 0 And StringInStr($sContent, '"Timestamp"') > 0 Then
        _LogInfo("Erkannt: Möglicherweise unvollständiges JSON-Format")
        Return $LOG_FORMAT_JSON_INCOMPLETE
    EndIf

    ; Prüfe auf Universal-Log-Format
    If StringRegExp($sContent, "^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}") Then
        _LogInfo("Erkannt: Universal Log-Format")
        Return $LOG_FORMAT_UNIVERSAL_LOG
    EndIf

    ; Prüfe auf Enhanced-Log-Format
    If StringRegExp($sContent, "^\[\d{2}:\d{2}:\d{2}\]") Then
        _LogInfo("Erkannt: Enhanced Log-Format")
        Return $LOG_FORMAT_ENHANCED_LOG
    EndIf

    ; Allgemeines Text-Format
    If StringLen($sContent) > 0 Then
        _LogInfo("Erkannt: Allgemeines Text-Format")
        Return $LOG_FORMAT_TEXT
    EndIf

    _LogWarning("Kein bekanntes Format erkannt")
    Return $LOG_FORMAT_UNKNOWN
EndFunc

; Parst eine Log-Datei mit dem entsprechenden Parser
Func ParserManager_ParseLogFile($sFilePath)
    _LogInfo("Parse Log-Datei: " & $sFilePath)

    ; Format erkennen
    Local $iFormat = ParserManager_DetectLogFormat($sFilePath)

    ; Entsprechenden Parser verwenden
    Switch $iFormat
        Case $LOG_FORMAT_JSON, $LOG_FORMAT_JSON_INCOMPLETE
            _LogInfo("Verwende verbesserten JSON-Parser mit Unterstützung für unvollständige Einträge")
            Return _ParseJsonLogFile($sFilePath)  ; Neuer robuster Parser, der zeilenweise verarbeitet

        Case $LOG_FORMAT_JSON_GENERIC
            _LogInfo("Verwende allgemeinen JSON-Parser")
            ; Datei als String einlesen für JSON-Verarbeitung
            Local $sContent = FileRead($sFilePath)
            If @error Then
                _LogError("Fehler beim Lesen der JSON-Datei: " & @error)
                Return SetError(1, 0, 0)
            EndIf

            Return _ParseGeneralJsonLog($sContent)

        Case $LOG_FORMAT_UNIVERSAL_LOG, $LOG_FORMAT_ENHANCED_LOG, $LOG_FORMAT_TEXT
            _LogInfo("Verwende Text-Log-Parser")
            Return _ParseTextLogFile($sFilePath)

        Case Else
            _LogWarning("Kein Parser für Format " & $iFormat & " verfügbar - versuche JSON-Parser als Fallback")
            ; Als Fallback versuchen wir den verbesserten JSON-Parser
            Local $sContent = FileRead($sFilePath)
            If @error Then
                _LogError("Fehler beim Lesen der Datei für Fallback-Parser: " & @error)
                Return SetError(1, 0, 0)
            EndIf

            Return _ParseJsonPatternLog($sContent)
    EndSwitch
EndFunc

; Gibt den Namen eines erkannten Formats zurück
Func ParserManager_GetFormatName($iFormat)
    Switch $iFormat
        Case $LOG_FORMAT_JSON
            Return "JSON Log"
        Case $LOG_FORMAT_JSON_INCOMPLETE
            Return "Unvollständiges JSON-Format"
        Case $LOG_FORMAT_JSON_GENERIC
            Return "Allgemeines JSON-Format"
        Case $LOG_FORMAT_UNIVERSAL_LOG
            Return "Universal Log"
        Case $LOG_FORMAT_ENHANCED_LOG
            Return "Enhanced Log"
        Case $LOG_FORMAT_TEXT
            Return "Text-Log"
        Case Else
            Return "Unbekanntes Format"
    EndSwitch
EndFunc

; Funktion zum Testen auf unvollständige JSON-Einträge in einer Datei
Func ParserManager_TestIncompleteJson($sFilePath)
    _LogInfo("Teste auf unvollständige JSON-Einträge: " & $sFilePath)

    ; Datei vollständig einlesen
    Local $sContent = FileRead($sFilePath)
    If @error Then
        _LogError("Fehler beim Lesen der Datei: " & @error)
        Return SetError(1, 0, False)
    EndIf

    ; Suche direkt nach unvollständigen JSON-Strings mit dem gleichen Pattern wie in log_analysis_utils.au3
    Local $aIncompleteMatches = StringRegExp($sContent, $g_sIncompleteLogPattern, 3)

    If Not @error Then
        _LogInfo("Unvollständige JSON-Einträge gefunden: " & UBound($aIncompleteMatches))
        Return True
    EndIf

    _LogInfo("Keine unvollständigen JSON-Einträge gefunden")
    Return False
EndFunc