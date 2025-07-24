#cs
Erweiterte Parser Manager Funktionen für Log-Dateien
#ce

#include-once
#include "..\constants.au3"
#include "..\logging.au3"
#include "..\log_analysis_utils.au3"

; Entferne doppelte Min-Funktion durch Umbenennung
Func ParserManager_Min($a, $b)
    Return ($a < $b) ? $a : $b
EndFunc

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

    ; Lese die ersten 10 Zeilen oder max. 10.000 Zeichen
    Local $sContent = ""
    Local $iLines = 0
    Local $sLine = ""
    
    While Not FileEOF($hFileHandle) And $iLines < 10 And StringLen($sContent) < 10000
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
    
    ; Prüfe auf allgemeines JSON-Format
    If StringInStr($sContent, "{") > 0 And StringInStr($sContent, "}") > 0 And _
       (StringInStr($sContent, "Timestamp") > 0 Or StringInStr($sContent, "timestamp") > 0) Then
        _LogInfo("Erkannt: Allgemeines JSON-Format")
        Return $LOG_FORMAT_JSON_GENERIC
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
        Case $LOG_FORMAT_JSON, $LOG_FORMAT_JSON_GENERIC
            _LogInfo("Verwende JSON-Parser")
            ; Datei als String einlesen für JSON-Verarbeitung
            Local $sContent = FileRead($sFilePath)
            If @error Then
                _LogError("Fehler beim Lesen der JSON-Datei: " & @error)
                Return SetError(1, 0, 0)
            EndIf
            
            ; Prüfen, ob es dem spezifischen Pattern entspricht
            If StringRegExp($sContent, $g_sLogPattern) Then
                Return _ParseJsonPatternLog($sContent)
            Else
                Return _ParseGeneralJsonLog($sContent)
            EndIf
            
        Case $LOG_FORMAT_UNIVERSAL_LOG, $LOG_FORMAT_ENHANCED_LOG, $LOG_FORMAT_TEXT
            _LogInfo("Verwende Text-Log-Parser")
            Return _ParseTextLogFile($sFilePath)
            
        Case Else
            _LogWarning("Kein Parser für Format " & $iFormat & " verfügbar")
            Return SetError(2, 0, 0)
    EndSwitch
EndFunc

; Gibt den Namen eines erkannten Formats zurück
Func ParserManager_GetFormatName($iFormat)
    Switch $iFormat
        Case $LOG_FORMAT_JSON
            Return "JSON Log"
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