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
Global $g_sLogPattern = '\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'

; Verbessertes Pattern für unvollständige JSON-Logs
; Prüft, ob ein JSON-Objekt beginnt, aber die schließende Klammer fehlt
; Wir suchen nur nach Einträgen, die bis zum Zeilenende keine schließende Klammer haben
Global $g_sIncompleteLogPattern = '\{[^\}]*"Timestamp":"[^"]+"[^\}]*'

; Parst JSON-Logs mit dem spezifischen Pattern - vereinfachte Version mit verbessertem Debugging
Func _ParseJsonPatternLog($sContent)
    _LogInfo("Parse JSON-Logs mit vereinfachtem Pattern")

    ; Array zur Speicherung der Ergebnisse
    Local $aLogEntries[0][5]  ; [timestamp, level, class, message, rawText]
    Local $iEntryCount = 0

    ; 1. Zuerst vollständige Einträge suchen mit dem Original-Pattern
    Local $aMatches = StringRegExp($sContent, $g_sLogPattern, 4)
    If Not @error Then
        _LogInfo("Gefundene vollständige Log-Einträge: " & UBound($aMatches))

        ; Vollständige Einträge verarbeiten
        For $i = 0 To UBound($aMatches) - 1
            Local $aTempArray = $aMatches[$i]

            ; Originalen JSON-String rekonstruieren
            Local $sOriginalJson = '{"Timestamp":"' & $aTempArray[1] & '","LogLevel":"' & $aTempArray[2] & '","LogClass":"' & $aTempArray[3] & '","Message":"' & $aTempArray[4] & '"}'

            ReDim $aLogEntries[$iEntryCount + 1][5]
            $aLogEntries[$iEntryCount][0] = $aTempArray[1] ; Timestamp
            $aLogEntries[$iEntryCount][1] = $aTempArray[2] ; LogLevel
            $aLogEntries[$iEntryCount][2] = $aTempArray[3] ; LogClass
            $aLogEntries[$iEntryCount][3] = $aTempArray[4] ; Message
            $aLogEntries[$iEntryCount][4] = $sOriginalJson ; Raw JSON
            $iEntryCount += 1
        Next
    EndIf

    ; 2. Jetzt nach unvollständigen Einträgen suchen - auch ISO-Zeitstempel direkt
    Local $aIncompleteMatches = StringRegExp($sContent, $g_sIncompleteLogPattern, 3)

    If Not @error Then
        _LogInfo("Gefundene unvollständige Log-Einträge: " & UBound($aIncompleteMatches))
        ConsoleWrite("GEFUNDEN: " & UBound($aIncompleteMatches) & " unvollständige Einträge" & @CRLF)

        ; Für jedes unvollständige Match
        For $i = 0 To UBound($aIncompleteMatches) - 1
            ; Das komplette unvollständige JSON nehmen
            Local $sIncompleteText = $aIncompleteMatches[$i]

            ; Debug-Information - AUSFÜHRLICH!
            _LogInfo("UNVOLLSTÄNDIGER EINTRAG GEFUNDEN: " & $sIncompleteText)
            ConsoleWrite("UNVOLLSTÄNDIGER EINTRAG [" & $i & "]: " & $sIncompleteText & @CRLF)

            ; Spezielle Behandlung für ISO-Zeitstempel
            Local $sTimestamp = ""

            ; Fall 1: Prüfen, ob es sich um einen direkten ISO-Zeitstempel handelt (ohne JSON)
            If StringRegExp($sIncompleteText, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') Then
                $sTimestamp = $sIncompleteText ; Der komplette Text ist der Timestamp
                ConsoleWrite("DIREKTER ISO-TIMESTAMP GEFUNDEN: " & $sTimestamp & @CRLF)
                _LogInfo("Direkter ISO-Timestamp gefunden: " & $sTimestamp)
            ; Fall 2: Normales JSON-Format mit Timestamp-Attribut
            Else
                Local $aTimestampMatch = StringRegExp($sIncompleteText, '"Timestamp":"([^"]+)"', 1)
                If Not @error Then
                    $sTimestamp = $aTimestampMatch[0]
                    ConsoleWrite("JSON-TIMESTAMP EXTRAHIERT: " & $sTimestamp & @CRLF)
                    _LogInfo("JSON-Timestamp extrahiert: " & $sTimestamp)
                EndIf
            EndIf

            ; Wenn ein Timestamp gefunden wurde, können wir den Eintrag verarbeiten
            If $sTimestamp <> "" Then
                ; Standardwerte für unvollständige Einträge
                Local $sLogLevel = "TRUNCATED"
                Local $sLogClass = "Unbekannt"

                ; Optional: Versuche LogLevel zu extrahieren (nur bei JSON-Format sinnvoll)
                Local $aLevelMatch = StringRegExp($sIncompleteText, '"LogLevel":"([^"]+)"', 1)
                If Not @error Then
                    $sLogLevel = $aLevelMatch[0] & " (TRUNCATED)"
                EndIf

                ; Optional: Versuche LogClass zu extrahieren (nur bei JSON-Format sinnvoll)
                Local $aClassMatch = StringRegExp($sIncompleteText, '"LogClass":"([^"]+)"', 1)
                If Not @error Then
                    $sLogClass = $aClassMatch[0]
                EndIf

                ; WICHTIG: Den unvollständigen Text als Nachricht verwenden, mit Markierung
                Local $sMessage = "!!! UNVOLLSTÄNDIGER LOG-EINTRAG !!! " & $sIncompleteText

                ; Eintrag zum Array hinzufügen
                ReDim $aLogEntries[$iEntryCount + 1][5]
                $aLogEntries[$iEntryCount][0] = $sTimestamp     ; Timestamp
                $aLogEntries[$iEntryCount][1] = $sLogLevel      ; LogLevel (TRUNCATED)
                $aLogEntries[$iEntryCount][2] = $sLogClass      ; LogClass
                $aLogEntries[$iEntryCount][3] = $sMessage       ; Markierte Nachricht
                $aLogEntries[$iEntryCount][4] = $sIncompleteText ; Raw

                ; Zähler erhöhen
                $iEntryCount += 1

                ; Bestätigung ausgeben
                ConsoleWrite("UNVOLLSTÄNDIGER EINTRAG HINZUGEFÜGT: Pos=" & ($iEntryCount-1) & ", TS=" & $sTimestamp & @CRLF)
                _LogInfo("Unvollständiger Eintrag hinzugefügt: " & $sTimestamp)
            Else
                ; Kein Timestamp gefunden
                ConsoleWrite("KONNTE KEINEN TIMESTAMP EXTRAHIEREN AUS: " & $sIncompleteText & @CRLF)
                _LogInfo("Konnte keinen Timestamp extrahieren aus: " & $sIncompleteText)
            EndIf
        Next
    EndIf

    ; Wenn keine Einträge gefunden wurden, einen Hinweiseintrag hinzufügen
    If $iEntryCount = 0 Then
        ReDim $aLogEntries[1][5]
        $aLogEntries[0][0] = _NowCalc()
        $aLogEntries[0][1] = "INFO"
        $aLogEntries[0][2] = "LogParser"
        $aLogEntries[0][3] = "Keine gültigen Log-Einträge gefunden. Möglicherweise ist das Format nicht unterstützt."
        $aLogEntries[0][4] = "Keine Daten"
        $iEntryCount = 1
    EndIf

    ; Final-Debugging
    _LogInfo("FINALE ANZAHL EINTRÄGE VOR SORTIERUNG: " & $iEntryCount)
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

    ; Sortieren nach Timestamp
    _ArraySort($aLogEntries, 0, 0, 0, 0) ; Sortieren nach erster Spalte (Timestamp)

    _LogInfo("JSON-Logdatei erfolgreich geparst: " & $iEntryCount & " Einträge gesamt")
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

; Parst JSON-Logs mit dem spezifischen Pattern - vereinfachte Version mit verbessertem Debugging
Func _ParseJsonPatternLog($sContent)
    _LogInfo("Parse JSON-Logs mit vereinfachtem Pattern")

    ; Array zur Speicherung der Ergebnisse
    Local $aLogEntries[0][5]  ; [timestamp, level, class, message, rawText]
    Local $iEntryCount = 0

    ; 1. Zuerst vollständige Einträge suchen mit dem Original-Pattern
    Local $aMatches = StringRegExp($sContent, $g_sLogPattern, 4)
    If Not @error Then
        _LogInfo("Gefundene vollständige Log-Einträge: " & UBound($aMatches))

        ; Vollständige Einträge verarbeiten
        For $i = 0 To UBound($aMatches) - 1
            Local $aTempArray = $aMatches[$i]

            ; Originalen JSON-String rekonstruieren
            Local $sOriginalJson = '{"Timestamp":"' & $aTempArray[1] & '","LogLevel":"' & $aTempArray[2] & '","LogClass":"' & $aTempArray[3] & '","Message":"' & $aTempArray[4] & '"}'

            ReDim $aLogEntries[$iEntryCount + 1][5]
            $aLogEntries[$iEntryCount][0] = $aTempArray[1] ; Timestamp
            $aLogEntries[$iEntryCount][1] = $aTempArray[2] ; LogLevel
            $aLogEntries[$iEntryCount][2] = $aTempArray[3] ; LogClass
            $aLogEntries[$iEntryCount][3] = $aTempArray[4] ; Message
            $aLogEntries[$iEntryCount][4] = $sOriginalJson ; Raw JSON
            $iEntryCount += 1
        Next
    EndIf

    ; 2. Jetzt nach unvollständigen Einträgen suchen - auch ISO-Zeitstempel direkt
    Local $aIncompleteMatches = StringRegExp($sContent, $g_sIncompleteLogPattern, 3)

    If Not @error Then
        _LogInfo("Gefundene unvollständige Log-Einträge: " & UBound($aIncompleteMatches))
        ConsoleWrite("GEFUNDEN: " & UBound($aIncompleteMatches) & " unvollständige Einträge" & @CRLF)

        ; Für jedes unvollständige Match
        For $i = 0 To UBound($aIncompleteMatches) - 1
            ; Das komplette unvollständige JSON nehmen
            Local $sIncompleteText = $aIncompleteMatches[$i]

            ; Debug-Information - AUSFÜHRLICH!
            _LogInfo("UNVOLLSTÄNDIGER EINTRAG GEFUNDEN: " & $sIncompleteText)
            ConsoleWrite("UNVOLLSTÄNDIGER EINTRAG [" & $i & "]: " & $sIncompleteText & @CRLF)

            ; Spezielle Behandlung für ISO-Zeitstempel
            Local $sTimestamp = ""

            ; Fall 1: Prüfen, ob es sich um einen direkten ISO-Zeitstempel handelt (ohne JSON)
            If StringRegExp($sIncompleteText, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') Then
                $sTimestamp = $sIncompleteText ; Der komplette Text ist der Timestamp
                ConsoleWrite("DIREKTER ISO-TIMESTAMP GEFUNDEN: " & $sTimestamp & @CRLF)
                _LogInfo("Direkter ISO-Timestamp gefunden: " & $sTimestamp)
            ; Fall 2: Normales JSON-Format mit Timestamp-Attribut
            Else
                Local $aTimestampMatch = StringRegExp($sIncompleteText, '"Timestamp":"([^"]+)"', 1)
                If Not @error Then
                    $sTimestamp = $aTimestampMatch[0]
                    ConsoleWrite("JSON-TIMESTAMP EXTRAHIERT: " & $sTimestamp & @CRLF)
                    _LogInfo("JSON-Timestamp extrahiert: " & $sTimestamp)
                EndIf
            EndIf

            ; Wenn ein Timestamp gefunden wurde, können wir den Eintrag verarbeiten
            If $sTimestamp <> "" Then
                ; Standardwerte für unvollständige Einträge
                Local $sLogLevel = "TRUNCATED"
                Local $sLogClass = "Unbekannt"

                ; Optional: Versuche LogLevel zu extrahieren (nur bei JSON-Format sinnvoll)
                Local $aLevelMatch = StringRegExp($sIncompleteText, '"LogLevel":"([^"]+)"', 1)
                If Not @error Then
                    $sLogLevel = $aLevelMatch[0] & " (TRUNCATED)"
                EndIf

                ; Optional: Versuche LogClass zu extrahieren (nur bei JSON-Format sinnvoll)
                Local $aClassMatch = StringRegExp($sIncompleteText, '"LogClass":"([^"]+)"', 1)
                If Not @error Then
                    $sLogClass = $aClassMatch[0]
                EndIf

                ; WICHTIG: Den unvollständigen Text als Nachricht verwenden, mit Markierung
                Local $sMessage = "!!! UNVOLLSTÄNDIGER LOG-EINTRAG !!! " & $sIncompleteText

                ; Eintrag zum Array hinzufügen
                ReDim $aLogEntries[$iEntryCount + 1][5]
                $aLogEntries[$iEntryCount][0] = $sTimestamp     ; Timestamp
                $aLogEntries[$iEntryCount][1] = $sLogLevel      ; LogLevel (TRUNCATED)
                $aLogEntries[$iEntryCount][2] = $sLogClass      ; LogClass
                $aLogEntries[$iEntryCount][3] = $sMessage       ; Markierte Nachricht
                $aLogEntries[$iEntryCount][4] = $sIncompleteText ; Raw

                ; Zähler erhöhen
                $iEntryCount += 1

                ; Bestätigung ausgeben
                ConsoleWrite("UNVOLLSTÄNDIGER EINTRAG HINZUGEFÜGT: Pos=" & ($iEntryCount-1) & ", TS=" & $sTimestamp & @CRLF)
                _LogInfo("Unvollständiger Eintrag hinzugefügt: " & $sTimestamp)
            Else
                ; Kein Timestamp gefunden
                ConsoleWrite("KONNTE KEINEN TIMESTAMP EXTRAHIEREN AUS: " & $sIncompleteText & @CRLF)
                _LogInfo("Konnte keinen Timestamp extrahieren aus: " & $sIncompleteText)
            EndIf
        Next
    EndIf

    ; Wenn keine Einträge gefunden wurden, einen Hinweiseintrag hinzufügen
    If $iEntryCount = 0 Then
        ReDim $aLogEntries[1][5]
        $aLogEntries[0][0] = _NowCalc()
        $aLogEntries[0][1] = "INFO"
        $aLogEntries[0][2] = "LogParser"
        $aLogEntries[0][3] = "Keine gültigen Log-Einträge gefunden. Möglicherweise ist das Format nicht unterstützt."
        $aLogEntries[0][4] = "Keine Daten"
        $iEntryCount = 1
    EndIf

    ; Final-Debugging
    _LogInfo("FINALE ANZAHL EINTRÄGE VOR SORTIERUNG: " & $iEntryCount)
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

    ; Sortieren nach Timestamp
    _ArraySort($aLogEntries, 0, 0, 0, 0) ; Sortieren nach erster Spalte (Timestamp)

    _LogInfo("JSON-Logdatei erfolgreich geparst: " & $iEntryCount & " Einträge gesamt")
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