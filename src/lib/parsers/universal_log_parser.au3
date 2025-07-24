#include-once
#include <File.au3>
#include <Array.au3>
#include "../logging.au3"
#include "../missing_functions.au3" ; Für die FileEOF-Funktion

; Universeller Log-Parser - liest JEDE Log-Datei unabhängig vom Format
; Keine komplexen JSON-Interpretationen, einfach pragmatisch und funktional

; Zeitstempel-Muster
Global $g_aTimestampPatterns[5]
$g_aTimestampPatterns[0] = '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}'      ; YYYY-MM-DD HH:MM:SS oder YYYY-MM-DDTHH:MM:SS (ISO)
$g_aTimestampPatterns[1] = '\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2}'     ; DD.MM.YYYY HH:MM:SS (deutsches Format)
$g_aTimestampPatterns[2] = '\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}'       ; MM/DD/YYYY HH:MM:SS (US-Format) 
$g_aTimestampPatterns[3] = '\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}'         ; MMM DD HH:MM:SS (Unix-Format)
$g_aTimestampPatterns[4] = '\d{2}:\d{2}:\d{2}'                           ; HH:MM:SS (nur Zeit)

; Log-Level Muster
Global $g_aLogLevelPatterns[2]
$g_aLogLevelPatterns[0] = '(INFO|WARN|WARNING|ERROR|DEBUG|TRACE|FATAL|CRITICAL)'        ; Standard Log-Levels
$g_aLogLevelPatterns[1] = '(INFORMATION|FEHLER|WARNUNG|HINWEIS|VERBOSE)'                ; Alternative Bezeichnungen

; Prüft, ob eine Datei als Log erkannt werden kann (jegliches Format)
Func _UniversalLogParser_IsLogFile($sFilePath)
    ; Jede .log Datei wird akzeptiert
    If StringRight($sFilePath, 4) = ".log" Then
        _LogInfo("Datei wurde als Log-Datei akzeptiert (Erweiterung .log): " & $sFilePath)
        Return True
    EndIf
    
    ; Zusätzlich prüfen wir den Inhalt
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then 
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf
    
    ; Teste die ersten 10 Zeilen
    Local $iLineCount = 0
    Local $sLine = ""
    Local $bContainsTimestamp = False
    Local $bContainsLogLevel = False
    
    While Not FileEOF($hFile) And $iLineCount < 10
        $sLine = FileReadLine($hFile)
        $iLineCount += 1
        
        If $sLine = "" Then ContinueLoop
        
        ; Nach Zeitstempel-Mustern suchen
        If Not $bContainsTimestamp Then
            For $i = 0 To UBound($g_aTimestampPatterns) - 1
                If StringRegExp($sLine, $g_aTimestampPatterns[$i]) Then
                    $bContainsTimestamp = True
                    _LogDebug("Zeitstempel-Muster gefunden: " & $g_aTimestampPatterns[$i])
                    ExitLoop
                EndIf
            Next
        EndIf
        
        ; Nach Log-Level-Mustern suchen
        If Not $bContainsLogLevel Then
            For $i = 0 To UBound($g_aLogLevelPatterns) - 1
                If StringRegExp($sLine, $g_aLogLevelPatterns[$i]) Then
                    $bContainsLogLevel = True
                    _LogDebug("Log-Level-Muster gefunden: " & $g_aLogLevelPatterns[$i])
                    ExitLoop
                EndIf
            Next
        EndIf
        
        ; Wenn beides gefunden wurde, können wir aufhören
        If $bContainsTimestamp And $bContainsLogLevel Then
            _LogInfo("Datei wurde als Log-Datei erkannt (enthält Zeitstempel und Log-Level)")
            FileClose($hFile)
            Return True
        EndIf
    WEnd
    
    FileClose($hFile)
    
    ; Wenn wir zumindest einen Zeitstempel oder ein Log-Level gefunden haben, akzeptieren wir die Datei
    If $bContainsTimestamp Or $bContainsLogLevel Then
        _LogInfo("Datei wurde als Log-Datei erkannt (enthält Zeitstempel oder Log-Level)")
        Return True
    EndIf
    
    _LogWarning("Datei sieht nicht wie eine Log-Datei aus")
    Return False
EndFunc

; Extrahiert Zeitstempel aus einer Logzeile
Func _ExtractTimestamp($sLine)
    For $i = 0 To UBound($g_aTimestampPatterns) - 1
        Local $aResult = StringRegExp($sLine, $g_aTimestampPatterns[$i], 1)
        If Not @error Then
            Return $aResult[0]
        EndIf
    Next
    
    Return ""  ; Kein Zeitstempel gefunden
EndFunc

; Extrahiert Log-Level aus einer Logzeile
Func _ExtractLogLevel($sLine)
    Local $sCombinedPattern = "(" & StringTrimLeft(StringTrimRight($g_aLogLevelPatterns[0], 1), 1) & "|" & StringTrimLeft(StringTrimRight($g_aLogLevelPatterns[1], 1), 1) & ")"
    
    Local $aResult = StringRegExp($sLine, $sCombinedPattern, 1)
    If Not @error Then
        Return $aResult[0]
    EndIf
    
    Return ""  ; Kein Log-Level gefunden
EndFunc

; Parsed eine Log-Datei in ein Array (universelle Methode)
Func _UniversalLogParser_ParseLogFile($sFilePath)
    _LogInfo("Parse Log-Datei (universell): " & $sFilePath)
    
    ; Datei einlesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Logeinträge parsen
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iCount = 0
    
    ; Analysiere erste 5 Zeilen, um zu erkennen, ob es ein zeilenweises oder ein Mehrfachzeilen-Log ist
    Local $bMultiLineLog = False
    Local $aFirstLines[5]
    Local $iFirstLineCount = 0
    Local $iTimestampCount = 0
    
    While Not FileEOF($hFile) And $iFirstLineCount < 5
        $aFirstLines[$iFirstLineCount] = FileReadLine($hFile)
        
        ; Prüfen, ob die Zeile einen Zeitstempel enthält
        If _ExtractTimestamp($aFirstLines[$iFirstLineCount]) <> "" Then
            $iTimestampCount += 1
        EndIf
        
        $iFirstLineCount += 1
    WEnd
    
    ; Wenn weniger als 50% der Zeilen einen Zeitstempel haben, handelt es sich wahrscheinlich um ein Mehrfachzeilen-Log
    $bMultiLineLog = ($iTimestampCount < $iFirstLineCount / 2)
    
    ; Datei zurücksetzen
    FileClose($hFile)
    $hFile = FileOpen($sFilePath, $FO_READ)
    
    If $bMultiLineLog Then
        _LogInfo("Mehrfachzeilen-Log erkannt - Nachrichten können über mehrere Zeilen gehen")
        
        ; Lese alle Zeilen
        Local $sCurrentTimestamp = ""
        Local $sCurrentLogLevel = ""
        Local $sCurrentMessage = ""
        Local $sCurrentRawLine = ""
        
        While Not FileEOF($hFile)
            Local $sLine = FileReadLine($hFile)
            
            ; Prüfen, ob die Zeile einen neuen Eintrag beginnt
            Local $sTimestamp = _ExtractTimestamp($sLine)
            Local $sLogLevel = _ExtractLogLevel($sLine)
            
            If $sTimestamp <> "" Then
                ; Vorherigen Eintrag speichern, wenn vorhanden
                If $sCurrentMessage <> "" Then
                    ReDim $aLogEntries[$iCount + 1][5]
                    $aLogEntries[$iCount][0] = $sCurrentTimestamp
                    $aLogEntries[$iCount][1] = $sCurrentLogLevel
                    $aLogEntries[$iCount][2] = ""  ; Keine Log-Klasse
                    $aLogEntries[$iCount][3] = $sCurrentMessage
                    $aLogEntries[$iCount][4] = $sCurrentRawLine
                    $iCount += 1
                EndIf
                
                ; Neuen Eintrag beginnen
                $sCurrentTimestamp = $sTimestamp
                $sCurrentLogLevel = $sLogLevel
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
            $aLogEntries[$iCount][2] = ""  ; Keine Log-Klasse
            $aLogEntries[$iCount][3] = $sCurrentMessage
            $aLogEntries[$iCount][4] = $sCurrentRawLine
        EndIf
    Else
        _LogInfo("Zeilenweises Log erkannt - jede Zeile ist ein eigener Eintrag")
        
        ; Jede Zeile als separaten Eintrag behandeln
        While Not FileEOF($hFile)
            Local $sLine = FileReadLine($hFile)
            If $sLine = "" Then ContinueLoop
            
            ; Zeitstempel und Log-Level extrahieren
            Local $sTimestamp = _ExtractTimestamp($sLine)
            Local $sLogLevel = _ExtractLogLevel($sLine)
            
            ; Zum Array hinzufügen
            ReDim $aLogEntries[$iCount + 1][5]
            $aLogEntries[$iCount][0] = $sTimestamp
            $aLogEntries[$iCount][1] = $sLogLevel
            $aLogEntries[$iCount][2] = ""  ; Keine Log-Klasse
            $aLogEntries[$iCount][3] = $sLine
            $aLogEntries[$iCount][4] = $sLine
            $iCount += 1
        WEnd
    EndIf
    
    FileClose($hFile)
    _LogInfo("Logdatei geparst, " & $iCount & " Einträge gefunden")
    
    Return $aLogEntries
EndFunc