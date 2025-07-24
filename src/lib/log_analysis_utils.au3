#include-once
#include <File.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include "logging.au3"
#include "JSON.au3"
#include "file_utils.au3"
#include "json_helper.au3"
#include "constants_new.au3"
#include "missing_functions.au3" ; Für die _Min()-Funktion
#include "log_parser.au3" ; Enthält jetzt die Such- und Analysefunktionen

; Definieren des Log-Patterns für vollständige JSON Logs
Global $g_sLogPattern = '(?m)\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'

; Kombiniertes Pattern für vollständige und unvollständige JSON-Logs
; Der erste Teil erfasst vollständige JSON mit Gruppen, der zweite Teil unvollständige Einträge
Global $g_sCombinedLogPattern = '(?m)\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}|\{[^\}]*?$'

; Parst JSON-Logs mit dem kombinierten Pattern - optimierte Version ohne Sortierung
Func _ParseJsonPatternLog($sContent)
    _LogInfo("Parse JSON-Logs mit verbessertem kombinierten Pattern - ohne Sortierung")

    ; Array zur Speicherung der Ergebnisse
    Local $aLogEntries[0][6]  ; [timestamp, level, class, message, rawText, originalLineNumber]
    Local $iEntryCount = 0

    ; Mit dem kombinierten Pattern alle JSON-Logs finden (vollständig und unvollständig)
    ; Flag 4 gibt ein Array von Arrays zurück, wobei jedes innere Array den Match und die Gruppen enthält
    Local $aMatches = StringRegExp($sContent, $g_sCombinedLogPattern, 4)
    
    If Not @error Then
        _LogInfo("Gefundene Log-Einträge: " & UBound($aMatches))
        ConsoleWrite("GEFUNDEN: " & UBound($aMatches) & " Log-Einträge gesamt" & @CRLF)
        
        ; Ursprünglichen Text in Zeilen aufteilen für Zeilennummernzuordnung
        Local $aTextLines = StringSplit($sContent, @CRLF, $STR_ENTIRESPLIT)
        
        ; Jeden gefundenen Logeintrag verarbeiten
        For $i = 0 To UBound($aMatches) - 1
            Local $aEntry = $aMatches[$i]
            Local $bIsComplete = UBound($aEntry) > 1 ; Wenn das Array mehr als 1 Element hat, ist es ein vollständiger Eintrag mit Gruppen
            
            ; Ursprüngliche Zeilennummer ermitteln
            Local $iOriginalLine = 0
            For $j = 1 To $aTextLines[0]
                If StringInStr($aTextLines[$j], $aEntry[0]) Then
                    $iOriginalLine = $j
                    ExitLoop
                EndIf
            Next
            
            ; Debug-Ausgabe
            If $bIsComplete Then
                _LogInfo("VOLLSTÄNDIGER EINTRAG [" & $i & "]: " & $aEntry[0])
                ConsoleWrite("VOLLSTÄNDIGER EINTRAG [" & $i & "]: " & $aEntry[0] & @CRLF)
            Else
                _LogInfo("UNVOLLSTÄNDIGER EINTRAG [" & $i & "]: " & $aEntry[0])
                ConsoleWrite("UNVOLLSTÄNDIGER EINTRAG [" & $i & "]: " & $aEntry[0] & @CRLF)
            EndIf
            
            ; Je nach Typ des Eintrags unterschiedlich verarbeiten
            If $bIsComplete Then
                ; Vollständiger Eintrag - Gruppen sind bereits extrahiert
                Local $sTimestamp = $aEntry[1]
                Local $sLogLevel = $aEntry[2]
                Local $sLogClass = $aEntry[3]
                Local $sMessage = $aEntry[4]
                
                ; Eintrag zum Array hinzufügen
                ReDim $aLogEntries[$iEntryCount + 1][6]
                $aLogEntries[$iEntryCount][0] = $sTimestamp        ; Timestamp
                $aLogEntries[$iEntryCount][1] = $sLogLevel         ; LogLevel
                $aLogEntries[$iEntryCount][2] = $sLogClass         ; LogClass
                $aLogEntries[$iEntryCount][3] = $sMessage          ; Message
                $aLogEntries[$iEntryCount][4] = $aEntry[0]         ; Raw JSON
                $aLogEntries[$iEntryCount][5] = $iOriginalLine     ; Ursprüngliche Zeilennummer
                $iEntryCount += 1
            Else
                ; Unvollständiger Eintrag - extrahiere Daten so gut wie möglich
                Local $sIncompleteText = $aEntry[0]
                Local $sTimestamp = ""
                Local $sLogLevel = "TRUNCATED"
                Local $sLogClass = "Unbekannt"
                
                ; Versuche Timestamp zu extrahieren
                Local $aTimestampMatch = StringRegExp($sIncompleteText, '"Timestamp":"([^"]+)"', 1)
                If Not @error Then
                    $sTimestamp = $aTimestampMatch[0]
                    ConsoleWrite("JSON-TIMESTAMP EXTRAHIERT: " & $sTimestamp & @CRLF)
                    _LogInfo("JSON-Timestamp extrahiert: " & $sTimestamp)
                Else
                    ; Direkter ISO-Timestamp ohne JSON?
                    If StringRegExp($sIncompleteText, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') Then
                        $sTimestamp = $sIncompleteText ; Der komplette Text ist der Timestamp
                        ConsoleWrite("DIREKTER ISO-TIMESTAMP GEFUNDEN: " & $sTimestamp & @CRLF)
                        _LogInfo("Direkter ISO-Timestamp gefunden: " & $sTimestamp)
                    EndIf
                EndIf
                
                ; Versuche LogLevel zu extrahieren
                Local $aLevelMatch = StringRegExp($sIncompleteText, '"LogLevel":"([^"]+)"', 1)
                If Not @error Then
                    $sLogLevel = $aLevelMatch[0] & " (TRUNCATED)"
                EndIf
                
                ; Versuche LogClass zu extrahieren
                Local $aClassMatch = StringRegExp($sIncompleteText, '"LogClass":"([^"]+)"', 1)
                If Not @error Then
                    $sLogClass = $aClassMatch[0]
                EndIf
                
                ; WICHTIG: Den unvollständigen Text als Nachricht verwenden, mit Markierung
                Local $sMessage = "!!! UNVOLLSTÄNDIGER LOG-EINTRAG !!! " & $sIncompleteText
                
                ; Eintrag zum Array hinzufügen
                ReDim $aLogEntries[$iEntryCount + 1][6]
                $aLogEntries[$iEntryCount][0] = $sTimestamp     ; Timestamp
                $aLogEntries[$iEntryCount][1] = $sLogLevel      ; LogLevel (TRUNCATED)
                $aLogEntries[$iEntryCount][2] = $sLogClass      ; LogClass
                $aLogEntries[$iEntryCount][3] = $sMessage       ; Markierte Nachricht
                $aLogEntries[$iEntryCount][4] = $sIncompleteText ; Raw
                $aLogEntries[$iEntryCount][5] = $iOriginalLine ; Ursprüngliche Zeilennummer
                
                ; Zähler erhöhen
                $iEntryCount += 1
                
                ; Bestätigung ausgeben
                ConsoleWrite("UNVOLLSTÄNDIGER EINTRAG HINZUGEFÜGT: Pos=" & ($iEntryCount-1) & ", TS=" & $sTimestamp & @CRLF)
                _LogInfo("Unvollständiger Eintrag hinzugefügt: " & $sTimestamp)
            EndIf
        Next
    EndIf

    ; Wenn keine Einträge gefunden wurden, einen Hinweiseintrag hinzufügen
    If $iEntryCount = 0 Then
        ReDim $aLogEntries[1][6]
        $aLogEntries[0][0] = _NowCalc()
        $aLogEntries[0][1] = "INFO"
        $aLogEntries[0][2] = "LogParser"
        $aLogEntries[0][3] = "Keine gültigen Log-Einträge gefunden. Möglicherweise ist das Format nicht unterstützt."
        $aLogEntries[0][4] = "Keine Daten"
        $aLogEntries[0][5] = 1 ; Zeilennummer 1 als Standard
        $iEntryCount = 1
    EndIf

    ; Final-Debugging
    _LogInfo("FINALE ANZAHL EINTRÄGE: " & $iEntryCount)
    ConsoleWrite("FINALE ANZAHL EINTRÄGE: " & $iEntryCount & @CRLF)

    ; Zusätzliche Prüfung: Suche unvollständige Einträge im finalen Array
    Local $iTruncatedCount = 0
    For $i = 0 To $iEntryCount - 1
        If StringInStr($aLogEntries[$i][1], "TRUNCATED") Then
            $iTruncatedCount += 1
            ConsoleWrite("FINALER UNVOLLSTÄNDIGER EINTRAG #" & $iTruncatedCount & " an Position " & $i & ": " & $aLogEntries[$i][0] & @CRLF)
        EndIf
    Next
    ConsoleWrite("Insgesamt " & $iTruncatedCount & " unvollständige Einträge im finalen Array gefunden." & @CRLF)

    ; WICHTIG: KEINE SORTIERUNG mehr durchführen!
    ; Die Einträge bleiben in der Reihenfolge, wie sie im Log gefunden wurden

    _LogInfo("JSON-Logdatei erfolgreich geparst: " & $iEntryCount & " Einträge gesamt (" & $iTruncatedCount & " unvollständig)")
    Return $aLogEntries
EndFunc

; Rest der Funktionen für andere Formate beibehalten
#region Andere Parser

; Parst allgemeine JSON-Logs, die nicht dem spezifischen Pattern entsprechen
Func _ParseGeneralJsonLog($sContent)
    _LogInfo("Parse allgemeine JSON-Logs")

    ; Versuchen, ein JSON-Array zu erkennen
    Local $sArrayPattern = '\[\s*\{.*?\}\s*\]'
    If StringRegExp($sContent, $sArrayPattern) Then
        ; Hier könnte eine komplexere JSON-Verarbeitung stattfinden
        _LogWarning("JSON-Array erkannt, aber Verarbeitung nicht implementiert")
    EndIf

    ; Versuchen, einzelne JSON-Objekte zu finden
    Local $sObjectPattern = '\{[^\{\}]*"timestamp"[^\{\}]*\}'
    Local $aMatches = StringRegExp($sContent, $sObjectPattern, 4)
    If @error Then
        ; Versuche alternatives Pattern mit Großbuchstaben ("Timestamp")
        $sObjectPattern = '\{[^\{\}]*"Timestamp"[^\{\}]*\}'
        $aMatches = StringRegExp($sContent, $sObjectPattern, 4)

        If @error Then
            _LogWarning("Keine JSON-Objekte mit timestamp/Timestamp erkannt")
            Return _ParseTextLogFile_FromString($sContent)
        EndIf
    EndIf

    _LogInfo("Gefundene JSON-Objekte: " & UBound($aMatches))

    ; Logeinträge Array vorbereiten
    Local $aLogEntries[UBound($aMatches)][5]

    ; Einträge verarbeiten
    For $i = 0 To UBound($aMatches) - 1
        ; Hier müsste man eigentlich jedes JSON-Objekt einzeln parsen
        Local $sObj = $aMatches[$i][0]

        ; Nach bekannten Feldern suchen (berücksichtige Groß- und Kleinschreibung)
        Local $sTimestamp = ""
        Local $aTimestampMatch = StringRegExp($sObj, '"[tT]imestamp"\s*:\s*"([^"]+)"', $STR_REGEXPARRAYMATCH)
        If IsArray($aTimestampMatch) Then $sTimestamp = $aTimestampMatch[0]

        Local $sLevel = ""
        Local $aLevelMatch = StringRegExp($sObj, '"(?:[lL]og)?[lL]evel"\s*:\s*"([^"]+)"', $STR_REGEXPARRAYMATCH)
        If IsArray($aLevelMatch) Then $sLevel = $aLevelMatch[0]

        Local $sClass = ""
        Local $aClassMatch = StringRegExp($sObj, '"(?:[lL]og)?[cC]lass"\s*:\s*"([^"]+)"', $STR_REGEXPARRAYMATCH)
        If IsArray($aClassMatch) Then $sClass = $aClassMatch[0]

        Local $sMessage = ""
        Local $aMessageMatch = StringRegExp($sObj, '"[mM]essage"\s*:\s*"([^"]+)"', $STR_REGEXPARRAYMATCH)
        If IsArray($aMessageMatch) Then $sMessage = $aMessageMatch[0]

        ; Daten in das Array einfügen
        $aLogEntries[$i][0] = $sTimestamp
        $aLogEntries[$i][1] = $sLevel
        $aLogEntries[$i][2] = $sClass
        $aLogEntries[$i][3] = $sMessage
        $aLogEntries[$i][4] = $sObj
    Next

    _LogInfo("JSON-Objekte erfolgreich geparst")
    Return $aLogEntries
EndFunc

; Parst eine Text-Logdatei, die als String übergeben wird
Func _ParseTextLogFile_FromString($sContent)
    _LogInfo("Parse Text-Logdatei aus String")

    ; Zeilen aufteilen
    Local $aLines = StringSplit($sContent, @CRLF, $STR_ENTIRESPLIT)

    ; Array für die Ergebnisse vorbereiten
    Local $aLogEntries[UBound($aLines)][5]

    ; Einträge verarbeiten
    For $i = 1 To $aLines[0]
        $aLogEntries[$i-1][0] = _NowCalc() ; Zeitstempel
        $aLogEntries[$i-1][1] = "INFO" ; Level
        $aLogEntries[$i-1][2] = "LogFile" ; Class
        $aLogEntries[$i-1][3] = $aLines[$i] ; Message
        $aLogEntries[$i-1][4] = $aLines[$i] ; Raw
    Next

    _LogInfo("Text-Logdatei erfolgreich geparst: " & $aLines[0] & " Zeilen")
    Return $aLogEntries
EndFunc

; Parst eine Text-Logdatei (versucht gängige Formate zu erkennen)
Func _ParseTextLogFile($sFilePath)
    _LogInfo("Parse Text-Logdatei: " & $sFilePath)

    ; Datei zeilenweise einlesen
    Local $aLines = FileReadToArray($sFilePath)
    If @error Then
        _LogError("Fehler beim Lesen der Textdatei: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf

    ; Log-Pattern erkennen (vereinfachte Erkennung gängiger Muster)
    Local $sPattern = ""
    Local $iSampleSize = _Min(UBound($aLines), 20)

    ; Pattern-Erkennung anhand von Stichproben
    For $i = 0 To $iSampleSize - 1
        ; ISO-Datum mit Uhrzeit am Anfang (YYYY-MM-DD HH:MM:SS)
        If StringRegExp($aLines[$i], '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}') Then
            $sPattern = "ISO"
            ExitLoop
        ; Log4j/Logback-ähnliches Format (YYYY-MM-DD HH:MM:SS,mmm Level [Class] - Message)
        ElseIf StringRegExp($aLines[$i], '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2},\d{3}\s+\w+\s+\[.*?\]') Then
            $sPattern = "LOG4J"
            ExitLoop
        ; Windows-Ereignislog (DD.MM.YYYY HH:MM:SS - Level - Message)
        ElseIf StringRegExp($aLines[$i], '^\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2}\s+-\s+\w+\s+-') Then
            $sPattern = "WINEVENT"
            ExitLoop
        ; Apache-Access-Log (IP - - [DD/Mon/YYYY:HH:MM:SS +ZZZZ] "METHOD URL HTTP/x.x" CODE SIZE)
        ElseIf StringRegExp($aLines[$i], '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|[a-fA-F0-9:]+) - - \[\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [\+\-]\d{4}\]') Then
            $sPattern = "APACHE"
            ExitLoop
        EndIf
    Next

    ; Wenn kein bekanntes Pattern erkannt wurde, generisches Format annehmen
    If $sPattern = "" Then
        $sPattern = "GENERIC"
    EndIf

    ; Log-Einträge in ein Array konvertieren basierend auf dem erkannten Pattern
    Local $aLogEntries[0][5]  ; [timestamp, level, class, message, rawLine]
    Local $iCount = 0

    For $i = 0 To UBound($aLines) - 1
        Local $sLine = $aLines[$i]
        Local $sTimestamp = ""
        Local $sLevel = ""
        Local $sClass = ""
        Local $sMessage = ""

        Switch $sPattern
            Case "ISO"
                ; ISO-Datum mit Uhrzeit (YYYY-MM-DD HH:MM:SS Level [Class] Message)
                Local $aMatch = StringRegExp($sLine, '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+\[(.*?)\]\s+(.*)', $STR_REGEXPARRAYMATCH)
                If IsArray($aMatch) And UBound($aMatch) >= 4 Then
                    $sTimestamp = $aMatch[0]
                    $sLevel = $aMatch[1]
                    $sClass = $aMatch[2]
                    $sMessage = $aMatch[3]
                Else
                    ; Zweiter Versuch mit weniger striktem Pattern
                    $aMatch = StringRegExp($sLine, '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.*)', $STR_REGEXPARRAYMATCH)
                    If IsArray($aMatch) And UBound($aMatch) >= 3 Then
                        $sTimestamp = $aMatch[0]
                        $sLevel = $aMatch[1]
                        $sMessage = $aMatch[2]
                    ElseIf StringLen($sLine) > 0 Then
                        ; Fallback: Zeile als Nachricht behandeln, wenn sie nicht leer ist
                        $sMessage = $sLine
                    Else
                        ContinueLoop ; Leere Zeile überspringen
                    EndIf
                EndIf

            Case "LOG4J"
                ; Log4j/Logback-ähnliches Format
                Local $aMatch = StringRegExp($sLine, '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2},\d{3})\s+(\w+)\s+\[(.*?)\]\s+(.*)', $STR_REGEXPARRAYMATCH)
                If IsArray($aMatch) And UBound($aMatch) >= 4 Then
                    $sTimestamp = $aMatch[0]
                    $sLevel = $aMatch[1]
                    $sClass = $aMatch[2]
                    $sMessage = $aMatch[3]
                ElseIf StringLen($sLine) > 0 Then
                    ; Fallback: Zeile als Nachricht behandeln
                    $sMessage = $sLine
                Else
                    ContinueLoop ; Leere Zeile überspringen
                EndIf

            Case "WINEVENT"
                ; Windows-Ereignislog
                Local $aMatch = StringRegExp($sLine, '^(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2})\s+-\s+(\w+)\s+-\s+(.*)', $STR_REGEXPARRAYMATCH)
                If IsArray($aMatch) And UBound($aMatch) >= 3 Then
                    $sTimestamp = $aMatch[0]
                    $sLevel = $aMatch[1]
                    $sMessage = $aMatch[2]
                ElseIf StringLen($sLine) > 0 Then
                    ; Fallback: Zeile als Nachricht behandeln
                    $sMessage = $sLine
                Else
                    ContinueLoop ; Leere Zeile überspringen
                EndIf

            Case "APACHE"
                ; Apache-Access-Log
                Local $aMatch = StringRegExp($sLine, '^(.*?) - - \[(.*?)\] "(.*?)" (\d+) (\d+)', $STR_REGEXPARRAYMATCH)
                If IsArray($aMatch) And UBound($aMatch) >= 5 Then
                    $sTimestamp = $aMatch[1]
                    $sLevel = "INFO" ; Apache-Access-Logs haben üblicherweise kein Level
                    $sClass = "AccessLog"
                    $sMessage = $aMatch[2] & " - " & $aMatch[3] & " - " & $aMatch[4]
                ElseIf StringLen($sLine) > 0 Then
                    ; Fallback: Zeile als Nachricht behandeln
                    $sMessage = $sLine
                Else
                    ContinueLoop ; Leere Zeile überspringen
                EndIf

            Case "GENERIC"
                ; Generisches Format: Einfache Zeilentrennung
                If StringLen($sLine) > 0 Then
                    ; Versuche Zeitstempel und Level basierend auf gängigen Formen zu extrahieren
                    Local $aTimestampMatch = StringRegExp($sLine, '^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}|\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2}|\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})', $STR_REGEXPARRAYMATCH)
                    If IsArray($aTimestampMatch) Then
                        $sTimestamp = $aTimestampMatch[0]
                        $sLine = StringTrimLeft($sLine, StringLen($sTimestamp))
                    EndIf

                    Local $aLevelMatch = StringRegExp(StringStripWS($sLine, $STR_STRIPLEADING), '^(INFO|ERROR|WARNING|DEBUG|TRACE|CRITICAL|FATAL)', $STR_REGEXPARRAYMATCH)
                    If IsArray($aLevelMatch) Then
                        $sLevel = $aLevelMatch[0]
                        $sLine = StringTrimLeft($sLine, StringLen($sLevel))
                    EndIf

                    ; Rest als Nachricht behandeln
                    $sMessage = StringStripWS($sLine, $STR_STRIPLEADING)
                Else
                    ContinueLoop ; Leere Zeile überspringen
                EndIf
        EndSwitch

        ; Eintrag zum Array hinzufügen
        ReDim $aLogEntries[$iCount + 1][5]
        $aLogEntries[$iCount][0] = $sTimestamp
        $aLogEntries[$iCount][1] = $sLevel
        $aLogEntries[$iCount][2] = $sClass
        $aLogEntries[$iCount][3] = $sMessage
        $aLogEntries[$iCount][4] = $aLines[$i] ; Rohdaten für spätere Referenz
        $iCount += 1
    Next

    _LogInfo("Text-Logdatei erfolgreich geparst: " & $iCount & " Einträge")
    Return $aLogEntries
EndFunc

; Prüft, ob eine Datei wie eine Log-Datei aussieht
Func _LooksLikeLogFile($sFilePath)
    _LogInfo("Prüfe ob es eine Logdatei ist: " & $sFilePath)

    ; Dateiendung prüfen
    Local $sExtension = StringLower(StringRegExpReplace($sFilePath, "^.*\.([^.]+)$", "$1"))
    If $sExtension = "log" Or $sExtension = "txt" Then
        ; Log-Dateien mit typischen Endungen automatisch akzeptieren
        _LogInfo("Datei mit Endung ." & $sExtension & " wird automatisch als Log akzeptiert")
        Return True
    EndIf

    ; Datei öffnen und Inhalt lesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf

    ; Lies einen größeren Abschnitt der Datei - bis zu 100 Zeilen oder 20000 Zeichen
    Local $sContent = ""
    Local $iLines = 0
    Local $iMaxLineToRead = 100 ; Mehr Zeilen lesen für größere Genauigkeit

    While Not FileEOF($hFile) And $iLines < $iMaxLineToRead And StringLen($sContent) < 20000
        $sContent &= FileReadLine($hFile) & @CRLF
        $iLines += 1
    WEnd

    FileClose($hFile)

    ; Prüfe auf typische Log-Patterns mit größerer Flexibilität

    ; 1. Prüfe auf verschiedene Datumsformate
    If StringRegExp($sContent, '\d{4}-\d{2}-\d{2}') Then
        _LogInfo("Log-Pattern gefunden: ISO-Datum")
        Return True ; ISO-Datum (YYYY-MM-DD)
    EndIf
    If StringRegExp($sContent, '\d{2}\.\d{2}\.\d{4}') Then
        _LogInfo("Log-Pattern gefunden: Deutsches Datumsformat")
        Return True ; Deutsches Datumsformat (DD.MM.YYYY)
    EndIf
    If StringRegExp($sContent, '\d{2}/\d{2}/\d{4}') Then
        _LogInfo("Log-Pattern gefunden: Amerikanisches Datumsformat")
        Return True ; Amerikanisches Datumsformat (MM/DD/YYYY)
    EndIf

    ; 2. Prüfe auf verschiedene Zeitformate
    If StringRegExp($sContent, '\d{2}:\d{2}:\d{2}') Then
        _LogInfo("Log-Pattern gefunden: Zeitstempel")
        Return True ; Zeitstempel (HH:MM:SS)
    EndIf
    If StringRegExp($sContent, '\[\d{2}:\d{2}:\d{2}\]') Then
        _LogInfo("Log-Pattern gefunden: Zeit in Klammern")
        Return True ; Zeit in Klammern [HH:MM:SS]
    EndIf

    ; 3. Prüfe auf Log-Level (auch Groß-/Kleinschreibung berücksichtigen)
    If StringRegExp($sContent, '(?i)(INFO|ERROR|WARNING|DEBUG|TRACE|FATAL|CRITICAL)') Then
        _LogInfo("Log-Pattern gefunden: Log-Level")
        Return True ; Log-Level
    EndIf

    ; 4. Prüfe auf JSON-Strukturen und spezifisches JSON-Pattern
    If StringInStr($sContent, '{') > 0 And StringInStr($sContent, '}') > 0 Then
        _LogInfo("Log-Pattern gefunden: JSON-Format")
        Return True ; Allgemeines JSON-Format
    EndIf
    If StringRegExp($sContent, $g_sLogPattern) Then
        _LogInfo("Log-Pattern gefunden: Spezifisches JSON-Pattern")
        Return True ; Spezifisches JSON-Pattern
    EndIf
    If StringRegExp($sContent, '\{[^}]*$') Then
        _LogInfo("Log-Pattern gefunden: Unvollständiges JSON-Pattern")
        Return True ; Unvollständiges JSON-Pattern
    EndIf

    ; 5. Prüfe auf typische Log-Schleifen oder Muster
    If StringRegExp($sContent, '(Started|Completed|Executed|Process|Thread|Connection)') Then
        _LogInfo("Log-Pattern gefunden: Aktionsbeschreibungen")
        Return True ; Typische Aktionen in Logs
    EndIf

    ; 6. Prüfe auf Ausnahmen und Fehlermeldungen
    If StringRegExp($sContent, '(Exception|Error:|Failed|Failure|Warning:)') Then
        _LogInfo("Log-Pattern gefunden: Ausnahmen/Fehler")
        Return True ; Ausnahmen und Fehlermeldungen
    EndIf

    ; Datei ist vermutlich keine Logdatei
    _LogWarning("Keine typischen Log-Patterns in der Datei gefunden: " & $sFilePath)
    Return False
EndFunc

#endregion


; Rest der Funktionen für andere Formate beibehalten
#region Andere Parser


#endregion