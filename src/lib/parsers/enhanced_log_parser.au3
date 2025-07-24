#include-once
#include <File.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include "../logging.au3"

; =====================================================================
; Erweiterter Log-Parser
; Unterstützt diverse Log-Formate durch intelligente Mustererkennung
; =====================================================================

; Hilfsfunktion um Dateiende zu prüfen
Func __EnhancedLogParser_FileIsEndOfFile($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Erweiterte Zeitstempel-Muster
Global $g_aEnhancedTimestampPatterns[9]
$g_aEnhancedTimestampPatterns[0] = '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}'       ; YYYY-MM-DD HH:MM:SS oder YYYY-MM-DDTHH:MM:SS (ISO)
$g_aEnhancedTimestampPatterns[1] = '\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2}'      ; DD.MM.YYYY HH:MM:SS (deutsches Format)
$g_aEnhancedTimestampPatterns[2] = '\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}'        ; MM/DD/YYYY HH:MM:SS (US-Format) 
$g_aEnhancedTimestampPatterns[3] = '\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}'          ; MMM DD HH:MM:SS (Unix-Format)
$g_aEnhancedTimestampPatterns[4] = '\d{2}:\d{2}:\d{2}'                            ; HH:MM:SS (nur Zeit)
$g_aEnhancedTimestampPatterns[5] = '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}.\d+'   ; YYYY-MM-DD HH:MM:SS.sss (mit Millisekunden)
$g_aEnhancedTimestampPatterns[6] = '\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2},\d+'    ; DD.MM.YYYY HH:MM:SS,sss (europäisches Format mit Millisekunden)
$g_aEnhancedTimestampPatterns[7] = '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]'      ; [YYYY-MM-DD HH:MM:SS] (in eckigen Klammern)
$g_aEnhancedTimestampPatterns[8] = '\(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\)'      ; (YYYY-MM-DD HH:MM:SS) (in runden Klammern)

; Erweiterte Log-Level Muster
Global $g_aEnhancedLogLevelPatterns[4]
$g_aEnhancedLogLevelPatterns[0] = '(?i)(INFO|WARN|WARNING|ERROR|DEBUG|TRACE|FATAL|CRITICAL|NOTICE)'  ; Standard Log-Levels (case insensitive)
$g_aEnhancedLogLevelPatterns[1] = '(?i)(INFORMATION|FEHLER|WARNUNG|HINWEIS|VERBOSE)'                 ; Alternative Bezeichnungen (case insensitive)
$g_aEnhancedLogLevelPatterns[2] = '\[(?i)(INFO|WARN|WARNING|ERROR|DEBUG|TRACE|FATAL|CRITICAL)\]'     ; [INFO], [ERROR], etc.
$g_aEnhancedLogLevelPatterns[3] = '\((?i)(INFO|WARN|WARNING|ERROR|DEBUG|TRACE|FATAL|CRITICAL)\)'     ; (INFO), (ERROR), etc.

; Bekannte Trennzeichen zwischen Logteilen
Global $g_aEnhancedSeparators = [" | ", " - ", ": ", "||", "\t", ",", ";"]

; Prüft, ob eine Datei als Log erkannt werden kann
Func _EnhancedLogParser_IsLogFile($sFilePath)
    _LogInfo("Enhanced: Prüfe, ob Datei ein Log ist: " & $sFilePath)
    
    ; Jede .log Datei wird akzeptiert
    If StringRight($sFilePath, 4) = ".log" Then
        _LogInfo("Enhanced: Datei wurde als Log-Datei akzeptiert (Erweiterung .log): " & $sFilePath)
        Return True
    EndIf
    
    ; DigiApp-Logs erkennen (spezielle Behandlung)
    If StringInStr($sFilePath, "DigiApp") And StringRight($sFilePath, 4) = ".txt" Then
        _LogInfo("Enhanced: Datei wurde als DigiApp-Log erkannt: " & $sFilePath)
        Return True
    EndIf
    
    ; Zusätzlich den Inhalt prüfen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then 
        _LogWarning("Enhanced: Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf
    
    ; Teste die ersten 20 Zeilen
    Local $iLineCount = 0
    Local $sLine = ""
    Local $iTimestampCount = 0
    Local $iLogLevelCount = 0
    
    While Not __EnhancedLogParser_FileIsEndOfFile($hFile) And $iLineCount < 20
        $sLine = FileReadLine($hFile)
        $iLineCount += 1
        
        If $sLine = "" Then ContinueLoop
        
        ; Nach Zeitstempel-Mustern suchen
        For $i = 0 To UBound($g_aEnhancedTimestampPatterns) - 1
            If StringRegExp($sLine, $g_aEnhancedTimestampPatterns[$i]) Then
                $iTimestampCount += 1
                _LogDebug("Enhanced: Zeitstempel-Muster gefunden: " & $g_aEnhancedTimestampPatterns[$i])
                ExitLoop
            EndIf
        Next
        
        ; Nach Log-Level-Mustern suchen
        For $i = 0 To UBound($g_aEnhancedLogLevelPatterns) - 1
            If StringRegExp($sLine, $g_aEnhancedLogLevelPatterns[$i]) Then
                $iLogLevelCount += 1
                _LogDebug("Enhanced: Log-Level-Muster gefunden: " & $g_aEnhancedLogLevelPatterns[$i])
                ExitLoop
            EndIf
        Next
    WEnd
    
    FileClose($hFile)
    
    ; Entscheidung, ob es sich um eine Logdatei handelt
    ; Wenn mindestens 30% der Zeilen Zeitstempel oder Log-Level enthalten
    Local $bIsLogFile = ($iTimestampCount >= $iLineCount * 0.3) Or ($iLogLevelCount >= $iLineCount * 0.3)
    
    If $bIsLogFile Then
        _LogInfo("Enhanced: Datei wurde als Log-Datei erkannt (Enthält genügend Zeitstempel oder Log-Levels)")
    Else
        _LogWarning("Enhanced: Datei sieht nicht wie eine Log-Datei aus")
    EndIf
    
    Return $bIsLogFile
EndFunc

; Extrahiert Zeitstempel aus einer Logzeile
Func _EnhancedExtractTimestamp($sLine)
    For $i = 0 To UBound($g_aEnhancedTimestampPatterns) - 1
        Local $aResult = StringRegExp($sLine, $g_aEnhancedTimestampPatterns[$i], $STR_REGEXPARRAYMATCH)
        If Not @error Then
            ; Klammern entfernen, falls vorhanden
            Local $sTimestamp = $aResult[0]
            $sTimestamp = StringRegExpReplace($sTimestamp, "^\[|\]$", "")  ; Eckige Klammern entfernen
            $sTimestamp = StringRegExpReplace($sTimestamp, "^\(|\)$", "")  ; Runde Klammern entfernen
            Return $sTimestamp
        EndIf
    Next
    
    Return ""  ; Kein Zeitstempel gefunden
EndFunc

; Extrahiert Log-Level aus einer Logzeile
Func _EnhancedExtractLogLevel($sLine)
    For $i = 0 To UBound($g_aEnhancedLogLevelPatterns) - 1
        Local $aResult = StringRegExp($sLine, $g_aEnhancedLogLevelPatterns[$i], $STR_REGEXPARRAYMATCH)
        If Not @error Then
            ; Klammern entfernen, falls vorhanden
            Local $sLogLevel = $aResult[0]
            $sLogLevel = StringRegExpReplace($sLogLevel, "^\[|\]$", "")  ; Eckige Klammern entfernen
            $sLogLevel = StringRegExpReplace($sLogLevel, "^\(|\)$", "")  ; Runde Klammern entfernen
            Return $sLogLevel
        EndIf
    Next
    
    Return ""  ; Kein Log-Level gefunden
EndFunc

; Versucht, die Log-Klasse (Kategorie, Komponente) aus einer Logzeile zu extrahieren
Func _EnhancedExtractLogClass($sLine, $sTimestamp, $sLogLevel)
    ; Wenn Zeitstempel und Log-Level bekannt sind, versuchen wir sie aus der Zeile zu entfernen
    Local $sRemainingLine = $sLine
    
    If $sTimestamp <> "" Then
        $sRemainingLine = StringReplace($sRemainingLine, $sTimestamp, "")
    EndIf
    
    If $sLogLevel <> "" Then
        $sRemainingLine = StringReplace($sRemainingLine, $sLogLevel, "")
    EndIf
    
    ; Klammern und spezielle Zeichen entfernen
    $sRemainingLine = StringRegExpReplace($sRemainingLine, "^\s*\[|\]\s*", "")
    $sRemainingLine = StringRegExpReplace($sRemainingLine, "^\s*\(|\)\s*", "")
    $sRemainingLine = StringStripWS($sRemainingLine, $STR_STRIPLEADING + $STR_STRIPTRAILING)
    
    ; Nach Trennzeichen suchen
    For $i = 0 To UBound($g_aEnhancedSeparators) - 1
        Local $aParts = StringSplit($sRemainingLine, $g_aEnhancedSeparators[$i], $STR_NOCOUNT)
        If UBound($aParts) >= 2 Then
            ; Zweites Element könnte die Log-Klasse sein
            Local $sCandidate = StringStripWS($aParts[0], $STR_STRIPLEADING + $STR_STRIPTRAILING)
            If $sCandidate <> "" And StringLen($sCandidate) < 30 Then  ; Vernünftige Begrenzung
                Return $sCandidate
            EndIf
        EndIf
    Next
    
    ; Keine Log-Klasse gefunden
    Return ""
EndFunc

; Intelligente Analyse, ob es sich um ein Mehrfachzeilen-Log handelt
Func _EnhancedIsMultiLineLog($sFilePath)
    _LogInfo("Enhanced: Prüfe, ob " & $sFilePath & " ein Mehrfachzeilen-Log ist")
    
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then Return False
    
    Local $iTimestampLines = 0
    Local $iTotalLines = 0
    Local $aLines[10]
    
    ; Die ersten 10 nicht-leeren Zeilen lesen
    While Not __EnhancedLogParser_FileIsEndOfFile($hFile) And $iTotalLines < 10
        Local $sLine = FileReadLine($hFile)
        If $sLine = "" Then ContinueLoop
        
        $aLines[$iTotalLines] = $sLine
        
        ; Prüfen, ob die Zeile einen Zeitstempel enthält
        If _EnhancedExtractTimestamp($sLine) <> "" Then
            $iTimestampLines += 1
        EndIf
        
        $iTotalLines += 1
    WEnd
    
    FileClose($hFile)
    
    ; Wenn weniger als 70% der Zeilen einen Zeitstempel haben, ist es wahrscheinlich ein Mehrfachzeilen-Log
    Local $bIsMultiLine = ($iTimestampLines < $iTotalLines * 0.7)
    
    _LogInfo("Enhanced: Mehrfachzeilen-Log erkannt: " & $bIsMultiLine & " (Zeitstempel-Zeilen: " & $iTimestampLines & "/" & $iTotalLines & ")")
    Return $bIsMultiLine
EndFunc

; Parsed eine Log-Datei mit erweiterter Format-Erkennung
Func _EnhancedLogParser_ParseLogFile($sFilePath)
    _LogInfo("Enhanced: Parse Log-Datei: " & $sFilePath)
    
    ; Datei einlesen
    If Not FileExists($sFilePath) Then
        _LogError("Enhanced: Logdatei existiert nicht: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Prüfen, ob es sich um ein Mehrfachzeilen-Log handelt
    Local $bIsMultiLineLog = _EnhancedIsMultiLineLog($sFilePath)
    
    ; Je nach Typ entsprechend parsen
    If $bIsMultiLineLog Then
        Return _EnhancedParseMultiLineLog($sFilePath)
    Else
        Return _EnhancedParseSingleLineLog($sFilePath)
    EndIf
EndFunc

; Parser für Logdateien mit einer Zeile pro Eintrag
Func _EnhancedParseSingleLineLog($sFilePath)
    _LogInfo("Enhanced: Parse Einzeilige Logdatei: " & $sFilePath)
    
    ; Datei einlesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Enhanced: Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Array für Logeinträge vorbereiten
    Local $aLines = FileReadToArray($sFilePath)
    If @error Then
        _LogError("Enhanced: Fehler beim Einlesen der Logdatei: " & @error)
        FileClose($hFile)
        Return SetError(2, 0, 0)
    EndIf
    
    Local $iLineCount = UBound($aLines)
    Local $aLogEntries[$iLineCount][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iValidCount = 0
    
    ; Jede Zeile als separaten Eintrag behandeln
    For $i = 0 To $iLineCount - 1
        If $aLines[$i] = "" Then ContinueLoop
        
        ; Zeitstempel, Log-Level und Log-Klasse extrahieren
        Local $sTimestamp = _EnhancedExtractTimestamp($aLines[$i])
        Local $sLogLevel = _EnhancedExtractLogLevel($aLines[$i])
        Local $sLogClass = _EnhancedExtractLogClass($aLines[$i], $sTimestamp, $sLogLevel)
        
        ; Zum Array hinzufügen
        $aLogEntries[$iValidCount][0] = $sTimestamp
        $aLogEntries[$iValidCount][1] = $sLogLevel
        $aLogEntries[$iValidCount][2] = $sLogClass
        $aLogEntries[$iValidCount][3] = $aLines[$i]  ; Komplette Nachricht
        $aLogEntries[$iValidCount][4] = $aLines[$i]  ; Original-Zeile
        $iValidCount += 1
    Next
    
    ; Array auf tatsächliche Größe anpassen
    If $iValidCount < $iLineCount Then
        ReDim $aLogEntries[$iValidCount][5]
    EndIf
    
    _LogInfo("Enhanced: Einzeiligen-Parser abgeschlossen, " & $iValidCount & " Einträge gefunden")
    Return $aLogEntries
EndFunc

; Parser für Logdateien mit mehrzeiligen Einträgen
Func _EnhancedParseMultiLineLog($sFilePath)
    _LogInfo("Enhanced: Parse Mehrzeilige Logdatei: " & $sFilePath)
    
    ; Datei öffnen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Enhanced: Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Logeinträge Array
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iCount = 0
    
    ; Lese alle Zeilen
    Local $sCurrentTimestamp = ""
    Local $sCurrentLogLevel = ""
    Local $sCurrentLogClass = ""
    Local $sCurrentMessage = ""
    Local $sCurrentRawLine = ""
    
    While Not __EnhancedLogParser_FileIsEndOfFile($hFile)
        Local $sLine = FileReadLine($hFile)
        
        ; Prüfen, ob die Zeile einen neuen Eintrag beginnt
        Local $sTimestamp = _EnhancedExtractTimestamp($sLine)
        
        If $sTimestamp <> "" Then
            ; Vorherigen Eintrag speichern, wenn vorhanden
            If $sCurrentMessage <> "" Then
                ReDim $aLogEntries[$iCount + 1][5]
                $aLogEntries[$iCount][0] = $sCurrentTimestamp
                $aLogEntries[$iCount][1] = $sCurrentLogLevel
                $aLogEntries[$iCount][2] = $sCurrentLogClass
                $aLogEntries[$iCount][3] = $sCurrentMessage
                $aLogEntries[$iCount][4] = $sCurrentRawLine
                $iCount += 1
            EndIf
            
            ; Neuen Eintrag beginnen
            $sCurrentTimestamp = $sTimestamp
            $sCurrentLogLevel = _EnhancedExtractLogLevel($sLine)
            $sCurrentLogClass = _EnhancedExtractLogClass($sLine, $sTimestamp, $sCurrentLogLevel)
            $sCurrentMessage = $sLine
            $sCurrentRawLine = $sLine
        Else
            ; Zeile zum aktuellen Eintrag hinzufügen
            If $sCurrentMessage <> "" Then
                $sCurrentMessage &= @CRLF & $sLine
                $sCurrentRawLine &= @CRLF & $sLine
            Else
                ; Falls der erste Eintrag keinen Zeitstempel hat
                $sCurrentMessage = $sLine
                $sCurrentRawLine = $sLine
            EndIf
        EndIf
    WEnd
    
    ; Letzten Eintrag speichern
    If $sCurrentMessage <> "" Then
        ReDim $aLogEntries[$iCount + 1][5]
        $aLogEntries[$iCount][0] = $sCurrentTimestamp
        $aLogEntries[$iCount][1] = $sCurrentLogLevel
        $aLogEntries[$iCount][2] = $sCurrentLogClass
        $aLogEntries[$iCount][3] = $sCurrentMessage
        $aLogEntries[$iCount][4] = $sCurrentRawLine
    EndIf
    
    FileClose($hFile)
    _LogInfo("Enhanced: Mehrzeiligen-Parser abgeschlossen, " & UBound($aLogEntries) & " Einträge gefunden")
    
    Return $aLogEntries
EndFunc