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

; Definieren der Log-Patterns für JSON Logs
Global $g_sLogPattern = '\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'

; Pattern für unvollständige Einträge - verschiedene Varianten
Global $g_sIncompletePatterns[] = [ _
    '\{"Timestamp":"([^"]+)","LogLevel":"([^"]*)"(?!\})(?:,"LogClass"|$|[^}])', _  ; Unvollständig nach LogLevel
    '\{"Timestamp":"([^"]+)"(?!\})(?:,"LogLevel"|$|[^}])', _                       ; Unvollständig nach Timestamp
    '\{"Timestamp":"([^"]+)","LogLevel":"([^"]*)","LogClass":"([^"]*)"(?!\})(?:,"Message"|$|[^}])' _ ; Unvollständig nach LogClass
]

; Hilfsfunktion zum Einfügen und Vermeiden von Duplikaten
Func _AddLogEntryIfUnique(ByRef $aLogEntries, ByRef $iEntryCount, $sTimestamp, $sLogLevel, $sLogClass, $sMessage, $sRawText)
    ; Prüfen, ob dieser Timestamp bereits existiert
    Local $bIsDuplicate = False
    For $i = 0 To $iEntryCount - 1
        If $aLogEntries[$i][0] == $sTimestamp Then
            ; Wenn der Eintrag bereits existiert, aber der neue vollständiger ist, ersetzen
            If StringInStr($aLogEntries[$i][1], "TRUNCATED") And Not StringInStr($sLogLevel, "TRUNCATED") Then
                $aLogEntries[$i][1] = $sLogLevel
                $aLogEntries[$i][2] = $sLogClass
                $aLogEntries[$i][3] = $sMessage
                $aLogEntries[$i][4] = $sRawText
                _LogInfo("Unvollständiger Eintrag mit vollständigerem ersetzt: " & $sTimestamp)
            EndIf
            $bIsDuplicate = True
            ExitLoop
        EndIf
    Next

    If Not $bIsDuplicate Then
        ; Neuen Eintrag hinzufügen
        ReDim $aLogEntries[$iEntryCount + 1][5]
        $aLogEntries[$iEntryCount][0] = $sTimestamp    ; Timestamp
        $aLogEntries[$iEntryCount][1] = $sLogLevel     ; LogLevel
        $aLogEntries[$iEntryCount][2] = $sLogClass     ; LogClass
        $aLogEntries[$iEntryCount][3] = $sMessage      ; Message
        $aLogEntries[$iEntryCount][4] = $sRawText      ; Original-Text
        $iEntryCount += 1
        Return True
    EndIf
    
    Return False
EndFunc

; Findet den tatsächlichen unvollständigen JSON-Text in einer Logdatei
Func _FindRawIncompleteJson($sContent, $sTimestamp)
    ; Durch alle Zeilen durchgehen und nach der abgeschnittenen JSON-Struktur mit dem entsprechenden Timestamp suchen
    Local $aLines = StringSplit($sContent, @CRLF, $STR_ENTIRESPLIT)
    
    For $i = 1 To $aLines[0]
        If StringInStr($aLines[$i], $sTimestamp) And StringInStr($aLines[$i], '{"Timestamp"') Then
            ; Prüfen ob die Zeile ein unvollständiges JSON-Objekt enthält (kein passendes schließendes })
            If Not StringRegExp($aLines[$i], '^\s*\{.*\}\s*$') Then
                Return $aLines[$i]  ; Gib die gesamte Zeile zurück
            EndIf
        EndIf
    Next
    
    Return ""  ; Nichts gefunden
EndFunc

; Erkennt unvollständige JSON-Einträge direkt im Text
Func _FindIncompleteJsonEntries($sContent)
    _LogInfo("Suche nach unvollständigen JSON-Einträgen")
    
    Local $aIncompleteEntries[0][2]  ; [vollständiger Text, Abschnitt]
    Local $iEntryCount = 0
    
    ; Suche nach JSON-Strukturen mit { aber ohne schließendes }
    Local $aLines = StringSplit($sContent, @CRLF, $STR_ENTIRESPLIT)
    
    For $i = 1 To $aLines[0]
        Local $sLine = $aLines[$i]
        
        ; Prüfe, ob die Zeile ein öffnendes { aber kein schließendes } enthält
        If StringInStr($sLine, "{") > 0 And Not StringRegExp($sLine, '^\s*\{.*\}\s*$') Then
            ; Möglicher unvollständiger Eintrag
            If StringInStr($sLine, '"Timestamp"') > 0 Then
                ReDim $aIncompleteEntries[$iEntryCount + 1][2]
                $aIncompleteEntries[$iEntryCount][0] = $sLine
                $aIncompleteEntries[$iEntryCount][1] = "Timestamp vorhanden"
                $iEntryCount += 1
            EndIf
        EndIf
        
        ; Suche nach abgeschnittenen JSON-Objekten
        If StringRegExp($sLine, '\{"Timestamp":.*[^"}]$') Then
            ReDim $aIncompleteEntries[$iEntryCount + 1][2]
            $aIncompleteEntries[$iEntryCount][0] = $sLine
            $aIncompleteEntries[$iEntryCount][1] = "Abgeschnitten"
            $iEntryCount += 1
        EndIf
    Next
    
    _LogInfo("Gefundene potentiell unvollständige Einträge: " & $iEntryCount)
    Return $aIncompleteEntries
EndFunc

; Extrahiert einen lesbaren Text aus einem unvollständigen JSON-String
Func _ExtractMessageFromIncompleteJson($sJson)
    ; Versuche eine Message zu extrahieren, falls vorhanden
    Local $aMessageMatch = StringRegExp($sJson, '"Message":"([^"]*)', $STR_REGEXPARRAYMATCH)
    If IsArray($aMessageMatch) And UBound($aMessageMatch) > 0 Then
        Return $aMessageMatch[0]  ; Extrahierte Message (kann unvollständig sein)
    EndIf
    
    ; Wenn keine Message vorhanden, gib den gesamten JSON-String ohne die Metadaten zurück
    Local $sCleanedJson = StringReplace($sJson, '{"Timestamp":', "")
    $sCleanedJson = StringRegExpReplace($sCleanedJson, '"[^"]*":"', "")
    $sCleanedJson = StringReplace($sCleanedJson, '"', "")
    $sCleanedJson = StringReplace($sCleanedJson, ",", " ")
    
    ; Wenn der Text zu lang ist, kürze ihn
    If StringLen($sCleanedJson) > 100 Then
        $sCleanedJson = StringLeft($sCleanedJson, 97) & "..."
    EndIf
    
    Return $sCleanedJson
EndFunc

; Parst JSON-Logs mit dem spezifischen Pattern - erweitert mit verbesserter Erkennung unvollständiger Einträge
Func _ParseJsonPatternLog($sContent)
    _LogInfo("Parse JSON-Logs mit spezifischem Pattern")

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
            
            ; Eintrag hinzufügen
            _AddLogEntryIfUnique($aLogEntries, $iEntryCount, $aTempArray[1], $aTempArray[2], $aTempArray[3], $aTempArray[4], $sOriginalJson)
        Next
    EndIf

    ; 2. Suche nach unvollständigen Einträgen mit verschiedenen Patterns
    For $i = 0 To UBound($g_sIncompletePatterns) - 1
        Local $aIncompleteMatches = StringRegExp($sContent, $g_sIncompletePatterns[$i], 4)
        
        If Not @error Then
            _LogInfo("Gefundene unvollständige Log-Einträge (Pattern " & $i & "): " & UBound($aIncompleteMatches))
            
            For $j = 0 To UBound($aIncompleteMatches) - 1
                Local $aTempArray = $aIncompleteMatches[$j]
                Local $sTimestamp = $aTempArray[1]
                Local $sLogLevel = "TRUNCATED"
                Local $sLogClass = "Unbekannt"
                Local $sMessage = ""
                
                ; Den originalen unvollständigen JSON-String suchen
                Local $sRawIncompleteJson = _FindRawIncompleteJson($sContent, $sTimestamp)
                If $sRawIncompleteJson = "" Then
                    $sRawIncompleteJson = '{"Timestamp":"' & $sTimestamp & '"...'
                EndIf
                
                ; Extrahiere die tatsächliche Nachricht aus dem unvollständigen JSON
                $sMessage = _ExtractMessageFromIncompleteJson($sRawIncompleteJson)
                
                ; Falls keine sinnvolle Nachricht extrahiert werden konnte
                If $sMessage = "" Then
                    $sMessage = "[UNVOLLSTÄNDIGER LOGEINTRAG: " & $sRawIncompleteJson & "]"
                Else
                    $sMessage &= " [UNVOLLSTÄNDIG]"
                EndIf
                
                ; Rekonstruiere so viel JSON wie möglich für die Anzeige
                Local $sIncompleteJson = '{"Timestamp":"' & $sTimestamp & '"'
                
                ; Extrahiere weitere Felder, wenn vorhanden
                If UBound($aTempArray) > 2 And $aTempArray[2] <> "" Then
                    $sIncompleteJson &= ',"LogLevel":"' & $aTempArray[2] & '"'
                    $sLogLevel = $aTempArray[2] & " (TRUNCATED)"
                    
                    If UBound($aTempArray) > 3 And $aTempArray[3] <> "" Then
                        $sIncompleteJson &= ',"LogClass":"' & $aTempArray[3] & '"'
                        $sLogClass = $aTempArray[3]
                    EndIf
                EndIf
                
                ; Markiere als unvollständig
                $sIncompleteJson &= ' ... (unvollständig)'
                
                ; Eintrag hinzufügen, wenn er noch nicht existiert
                _AddLogEntryIfUnique($aLogEntries, $iEntryCount, $sTimestamp, $sLogLevel, $sLogClass, $sMessage, $sRawIncompleteJson)
            Next
        EndIf
    Next
    
    ; 3. Zusätzlich nach direkten Anzeichen für unvollständige Einträge suchen
    Local $aExtraIncomplete = _FindIncompleteJsonEntries($sContent)
    If IsArray($aExtraIncomplete) And UBound($aExtraIncomplete) > 0 Then
        _LogInfo("Zusätzliche unvollständige Einträge gefunden: " & UBound($aExtraIncomplete))
        
        For $i = 0 To UBound($aExtraIncomplete) - 1
            Local $sIncompleteText = $aExtraIncomplete[$i][0]
            
            ; Versuche Timestamp zu extrahieren
            Local $aTimestampMatch = StringRegExp($sIncompleteText, '"Timestamp":"([^"]+)"', $STR_REGEXPARRAYMATCH)
            If IsArray($aTimestampMatch) And UBound($aTimestampMatch) > 0 Then
                Local $sTimestamp = $aTimestampMatch[0]
                Local $sLogLevel = "SCHWER_BESCHÄDIGT"
                Local $sLogClass = "Unbekannt"
                
                ; Extrahiere den eigentlichen Inhalt für die Nachricht
                Local $sMessage = _ExtractMessageFromIncompleteJson($sIncompleteText)
                If $sMessage = "" Then
                    $sMessage = "[BESCHÄDIGTER LOGEINTRAG: " & $sIncompleteText & "]"
                Else
                    $sMessage &= " [BESCHÄDIGT]"
                EndIf
                
                ; Versuche LogLevel zu extrahieren
                Local $aLevelMatch = StringRegExp($sIncompleteText, '"LogLevel":"([^"]+)"', $STR_REGEXPARRAYMATCH)
                If IsArray($aLevelMatch) And UBound($aLevelMatch) > 0 Then
                    $sLogLevel = $aLevelMatch[0] & " (BESCHÄDIGT)"
                    
                    ; Versuche LogClass zu extrahieren
                    Local $aClassMatch = StringRegExp($sIncompleteText, '"LogClass":"([^"]+)"', $STR_REGEXPARRAYMATCH)
                    If IsArray($aClassMatch) And UBound($aClassMatch) > 0 Then
                        $sLogClass = $aClassMatch[0]
                    EndIf
                EndIf
                
                ; Eintrag mit Originaldaten hinzufügen
                _AddLogEntryIfUnique($aLogEntries, $iEntryCount, $sTimestamp, $sLogLevel, $sLogClass, $sMessage, $sIncompleteText)
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

    ; Sortieren nach Timestamp
    _ArraySort($aLogEntries, 0, 0, 0, 0) ; Sortieren nach erster Spalte (Timestamp)

    _LogInfo("JSON-Logdatei erfolgreich geparst: " & $iEntryCount & " Einträge gesamt")
    Return $aLogEntries
EndFunc

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