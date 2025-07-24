#include-once
#include <File.au3>
#include <Array.au3>
#include "../logging.au3"

; =====================================================================
; Universeller Log-Parser 2.0 - verbesserte Version
; Liest JEDE Log-Datei unabhängig vom Format mit höherer Zuverlässigkeit
; Unterstützt Multiline-Logs, JSON-Logs und gemischte Formate
; =====================================================================

; Hilfsfunktion um Dateiende zu prüfen
Func __UniversalEnhancedParser_FileIsEndOfFile($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Zeitstempel-Muster (erweitert mit mehr Varianten)
Global $g_aEnhancedTimestampPatterns[9]
$g_aEnhancedTimestampPatterns[0] = '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}'           ; YYYY-MM-DD HH:MM:SS oder YYYY-MM-DDTHH:MM:SS (ISO)
$g_aEnhancedTimestampPatterns[1] = '\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2}'          ; DD.MM.YYYY HH:MM:SS (deutsches Format)
$g_aEnhancedTimestampPatterns[2] = '\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}'            ; MM/DD/YYYY HH:MM:SS (US-Format) 
$g_aEnhancedTimestampPatterns[3] = '\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}'              ; MMM DD HH:MM:SS (Unix-Format)
$g_aEnhancedTimestampPatterns[4] = '\d{2}:\d{2}:\d{2}'                                ; HH:MM:SS (nur Zeit)
$g_aEnhancedTimestampPatterns[5] = '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}.\d{3}'     ; YYYY-MM-DD HH:MM:SS.mmm (mit Millisekunden)
$g_aEnhancedTimestampPatterns[6] = '\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}'          ; YYYY.MM.DD HH:MM:SS
$g_aEnhancedTimestampPatterns[7] = '\[\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}\]'       ; [YYYY-MM-DD HH:MM:SS] (in eckigen Klammern)
$g_aEnhancedTimestampPatterns[8] = '\(\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}\)'        ; (YYYY/MM/DD HH:MM:SS) (in Klammern)

; Log-Level Muster (erweitert)
Global $g_aEnhancedLogLevelPatterns[5]
$g_aEnhancedLogLevelPatterns[0] = '(INFO|WARN|WARNING|ERROR|DEBUG|TRACE|FATAL|CRITICAL)'        ; Standard Log-Levels
$g_aEnhancedLogLevelPatterns[1] = '(INFORMATION|FEHLER|WARNUNG|HINWEIS|VERBOSE)'                ; Alternative Bezeichnungen
$g_aEnhancedLogLevelPatterns[2] = '\[(INFO|WARN|WARNING|ERROR|DEBUG|TRACE|FATAL|CRITICAL)\]'    ; Log-Levels in eckigen Klammern
$g_aEnhancedLogLevelPatterns[3] = '(Info|Warn|Warning|Error|Debug|Trace|Fatal|Critical)'        ; Variante mit Groß-/Kleinschreibung
$g_aEnhancedLogLevelPatterns[4] = '(LOG INFO|LOG WARN|LOG WARNING|LOG ERROR|LOG DEBUG)'         ; LOG-Präfix

; Dynamische Cache für gefundene Log-Format-Muster
Global $g_sEnhancedFoundTimestampPattern = ""
Global $g_sEnhancedFoundLogLevelPattern = ""

; Prüft, ob eine Datei als Log erkannt werden kann (erweiterte Version)
Func _UniversalEnhancedParser_IsLogFile($sFilePath)
    _LogInfo("Überprüfe Datei auf Log-Format (Enhanced): " & $sFilePath)
    
    ; Jede .log Datei wird sofort akzeptiert
    If StringRight($sFilePath, 4) = ".log" Then
        _LogInfo("Datei wurde als Log-Datei akzeptiert (Erweiterung .log)")
        Return True
    EndIf
    
    ; DigiApp wird automatisch akzeptiert
    If StringInStr(StringLower($sFilePath), "digiapp") Then
        _LogInfo("Datei wurde als Log-Datei akzeptiert (DigiApp im Namen)")
        Return True
    EndIf
    
    ; Prüfe, ob "log" im Dateinamen enthalten ist
    If StringInStr(StringLower($sFilePath), "log") Then
        _LogInfo("Datei wurde als Log-Datei akzeptiert ('log' im Namen)")
        Return True
    EndIf
    
    ; Zusätzlich prüfen wir den Inhalt
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then 
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf
    
    ; Teste die ersten 20 Zeilen (höhere Anzahl für bessere Erkennung)
    Local $iLineCount = 0
    Local $sLine = ""
    Local $bContainsTimestamp = False
    Local $bContainsLogLevel = False
    Local $iTimestampHits = 0
    Local $iLogLevelHits = 0
    
    While Not __UniversalEnhancedParser_FileIsEndOfFile($hFile) And $iLineCount < 20
        $sLine = FileReadLine($hFile)
        If @error Then ExitLoop
        $iLineCount += 1
        
        If $sLine = "" Then ContinueLoop
        
        ; Nach Zeitstempel-Mustern suchen
        For $i = 0 To UBound($g_aEnhancedTimestampPatterns) - 1
            If StringRegExp($sLine, $g_aEnhancedTimestampPatterns[$i]) Then
                $bContainsTimestamp = True
                $g_sEnhancedFoundTimestampPattern = $g_aEnhancedTimestampPatterns[$i]
                $iTimestampHits += 1
                ExitLoop
            EndIf
        Next
        
        ; Nach Log-Level-Mustern suchen
        For $i = 0 To UBound($g_aEnhancedLogLevelPatterns) - 1
            If StringRegExp($sLine, $g_aEnhancedLogLevelPatterns[$i]) Then
                $bContainsLogLevel = True
                $g_sEnhancedFoundLogLevelPattern = $g_aEnhancedLogLevelPatterns[$i]
                $iLogLevelHits += 1
                ExitLoop
            EndIf
        Next
    WEnd
    
    FileClose($hFile)
    
    ; Erkennung hat Thresholds - mindestens 20% der geprüften Zeilen sollten Timestamps oder Log-Levels enthalten
    Local $fTimestampRate = $iTimestampHits / $iLineCount
    Local $fLogLevelRate = $iLogLevelHits / $iLineCount
    
    _LogInfo("Zeitstempel-Rate: " & Round($fTimestampRate * 100, 2) & "%, Log-Level-Rate: " & Round($fLogLevelRate * 100, 2) & "%")
    
    ; Wenn mehr als 20% der Zeilen einen Zeitstempel oder Log-Level haben, gilt es als Log-Datei
    If $fTimestampRate >= 0.2 Or $fLogLevelRate >= 0.2 Then
        _LogInfo("Datei wurde als Log-Datei erkannt (Analysebasiert)")
        Return True
    EndIf
    
    ; Prüfen, ob generell strukturierte Daten enthalten sind (z.B. für JSON-Logs)
    If StringInStr($sLine, "{") And StringInStr($sLine, "}") Then
        _LogInfo("Datei wurde als Log-Datei akzeptiert (JSON-Struktur erkannt)")
        Return True
    EndIf
    
    _LogWarning("Datei sieht nicht wie eine Log-Datei aus")
    Return False
EndFunc

; Extrahiert Zeitstempel aus einer Logzeile (verbesserte Version)
Func _ExtractEnhancedTimestamp($sLine)
    ; Wenn bereits ein Muster erkannt wurde, dieses zuerst versuchen
    If $g_sEnhancedFoundTimestampPattern <> "" Then
        Local $aResult = StringRegExp($sLine, $g_sEnhancedFoundTimestampPattern, 1)
        If Not @error Then
            Return $aResult[0]
        EndIf
    EndIf
    
    ; Alle Muster durchprobieren
    For $i = 0 To UBound($g_aEnhancedTimestampPatterns) - 1
        Local $aResult = StringRegExp($sLine, $g_aEnhancedTimestampPatterns[$i], 1)
        If Not @error Then
            ; Gefundenes Muster speichern für zukünftige Aufrufe
            $g_sEnhancedFoundTimestampPattern = $g_aEnhancedTimestampPatterns[$i]
            Return $aResult[0]
        EndIf
    Next
    
    Return ""  ; Kein Zeitstempel gefunden
EndFunc

; Extrahiert Log-Level aus einer Logzeile (verbesserte Version)
Func _ExtractEnhancedLogLevel($sLine)
    ; Wenn bereits ein Muster erkannt wurde, dieses zuerst versuchen
    If $g_sEnhancedFoundLogLevelPattern <> "" Then
        Local $aResult = StringRegExp($sLine, $g_sEnhancedFoundLogLevelPattern, 1)
        If Not @error Then
            Return $aResult[0]
        EndIf
    EndIf
    
    ; Alle Muster durchprobieren
    For $i = 0 To UBound($g_aEnhancedLogLevelPatterns) - 1
        Local $aResult = StringRegExp($sLine, $g_aEnhancedLogLevelPatterns[$i], 1)
        If Not @error Then
            ; Gefundenes Muster speichern für zukünftige Aufrufe
            $g_sEnhancedFoundLogLevelPattern = $g_aEnhancedLogLevelPatterns[$i]
            
            ; Formatierung bereinigen (Klammern entfernen)
            Local $sLevel = $aResult[0]
            $sLevel = StringReplace($sLevel, "[", "")
            $sLevel = StringReplace($sLevel, "]", "")
            $sLevel = StringReplace($sLevel, "LOG ", "")
            
            Return $sLevel
        EndIf
    Next
    
    Return ""  ; Kein Log-Level gefunden
EndFunc

; Versucht die Logklasse zu extrahieren (Name des Komponententeils)
Func _ExtractEnhancedLogClass($sLine, $sTimestamp, $sLogLevel)
    ; Wenn Timestamp und LogLevel gefunden wurden, versuchen wir den Text dazwischen als LogClass zu interpretieren
    If $sTimestamp <> "" And $sLogLevel <> "" Then
        ; Timestamp aus der Zeile entfernen
        Local $sRest = StringReplace($sLine, $sTimestamp, "")
        
        ; LogLevel aus dem Rest entfernen
        $sRest = StringReplace($sRest, $sLogLevel, "")
        
        ; Sonderzeichen entfernen
        $sRest = StringReplace($sRest, "[]", "")
        $sRest = StringReplace($sRest, "()", "")
        $sRest = StringReplace($sRest, "{}", "")
        $sRest = StringStripWS($sRest, 3)  ; Whitespace vorne und hinten entfernen
        
        ; Wenn der Rest nicht zu lang ist und keine Leerzeichen enthält, könnte es die LogClass sein
        If StringLen($sRest) < 30 And Not StringInStr($sRest, " ") Then
            Return $sRest
        EndIf
    EndIf
    
    ; Versuche, eine Klasse nach bekannten Mustern zu extrahieren
    Local $aPatterns[3]
    $aPatterns[0] = '\[\s*([a-zA-Z][a-zA-Z0-9._]+)\s*\]'                ; [LoggerName]
    $aPatterns[1] = '\"LogClass\":\s*\"([^\"]+)\"'                      ; "LogClass":"ClassName"
    $aPatterns[2] = '([a-zA-Z][a-zA-Z0-9._]+)(?=\s*[-:]\s)'            ; ClassName - oder ClassName:
    
    For $i = 0 To UBound($aPatterns) - 1
        Local $aResult = StringRegExp($sLine, $aPatterns[$i], 1)
        If Not @error Then
            Return $aResult[0]
        EndIf
    Next
    
    Return ""  ; Keine Log-Klasse gefunden
EndFunc

; Parsed eine Log-Datei in ein Array (universelle erweiterte Methode)
Func _UniversalEnhancedParser_ParseLogFile($sFilePath)
    _LogInfo("Parse Log-Datei (Universeller erweiterter Parser): " & $sFilePath)
    
    ; Datei einlesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Logeinträge parsen
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iCount = 0
    
    ; Analysiere erste 50 Zeilen, um zu erkennen, ob es ein zeilenweises oder ein Mehrfachzeilen-Log ist
    Local $bMultiLineLog = False
    Local $aFirstLines[50]
    Local $iFirstLineCount = 0
    Local $iTimestampCount = 0
    
    ; Erste Zeilen lesen
    While Not __UniversalEnhancedParser_FileIsEndOfFile($hFile) And $iFirstLineCount < 50
        $aFirstLines[$iFirstLineCount] = FileReadLine($hFile)
        If @error Then ExitLoop
        
        ; Prüfen, ob die Zeile einen Zeitstempel enthält
        If _ExtractEnhancedTimestamp($aFirstLines[$iFirstLineCount]) <> "" Then
            $iTimestampCount += 1
        EndIf
        
        $iFirstLineCount += 1
    WEnd
    
    ; Wenn weniger als 60% der Zeilen einen Zeitstempel haben, handelt es sich wahrscheinlich um ein Mehrfachzeilen-Log
    $bMultiLineLog = ($iTimestampCount < $iFirstLineCount * 0.6)
    
    ; Datei zurücksetzen
    FileClose($hFile)
    $hFile = FileOpen($sFilePath, $FO_READ)
    
    If $bMultiLineLog Then
        _LogInfo("Mehrfachzeilen-Log erkannt - Nachrichten können über mehrere Zeilen gehen")
        
        ; Lese alle Zeilen
        Local $sCurrentTimestamp = ""
        Local $sCurrentLogLevel = ""
        Local $sCurrentLogClass = ""
        Local $sCurrentMessage = ""
        Local $sCurrentRawLine = ""
        
        While Not __UniversalEnhancedParser_FileIsEndOfFile($hFile)
            Local $sLine = FileReadLine($hFile)
            If @error Then ExitLoop
            
            ; Prüfen, ob die Zeile einen neuen Eintrag beginnt
            Local $sTimestamp = _ExtractEnhancedTimestamp($sLine)
            
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
                $sCurrentLogLevel = _ExtractEnhancedLogLevel($sLine)
                $sCurrentLogClass = _ExtractEnhancedLogClass($sLine, $sTimestamp, $sCurrentLogLevel)
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
    Else
        _LogInfo("Zeilenweises Log erkannt - jede Zeile ist ein eigener Eintrag")
        
        ; Jede Zeile als separaten Eintrag behandeln
        While Not __UniversalEnhancedParser_FileIsEndOfFile($hFile)
            Local $sLine = FileReadLine($hFile)
            If @error Then ExitLoop
            If $sLine = "" Then ContinueLoop
            
            ; Zeitstempel und Log-Level extrahieren
            Local $sTimestamp = _ExtractEnhancedTimestamp($sLine)
            Local $sLogLevel = _ExtractEnhancedLogLevel($sLine)
            Local $sLogClass = _ExtractEnhancedLogClass($sLine, $sTimestamp, $sLogLevel)
            
            ; Zum Array hinzufügen
            ReDim $aLogEntries[$iCount + 1][5]
            $aLogEntries[$iCount][0] = $sTimestamp
            $aLogEntries[$iCount][1] = $sLogLevel
            $aLogEntries[$iCount][2] = $sLogClass
            $aLogEntries[$iCount][3] = $sLine
            $aLogEntries[$iCount][4] = $sLine
            $iCount += 1
        WEnd
    EndIf
    
    FileClose($hFile)
    _LogInfo("Logdatei geparst, " & $iCount & " Einträge gefunden")
    
    Return $aLogEntries
EndFunc