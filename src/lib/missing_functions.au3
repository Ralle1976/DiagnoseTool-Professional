; Titel.......: Nachträglich hinzugefügte Funktionen
; Beschreibung: Sammlung von Funktionen, die nachträglich hinzugefügt wurden
; Autor.......: Ralle1976
; Erstellt....: 2025-04-14
; ===============================================================================================================================

#include-once
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <Array.au3>
#include <File.au3>
#include <GuiListView.au3>
#include <Date.au3>
#include "logging.au3"
#include "parsers/universal_log_parser.au3"

; Externe Referenz zu SQL-Editor-Controls
Global $g_idSQLExecuteBtn
Global $g_idSQLSaveBtn
Global $g_idSQLLoadBtn
Global $g_idShowCompletionBtn
Global $g_idSQLBackBtn
Global $g_bSQLEditorMode
Global $g_hSQLRichEdit
Global $g_hGUI

; Log-Pattern Konstanten für JSON-Parsing
Global $g_sLogPattern = '(?m)\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'
Global $g_sCombinedLogPattern = '(?m)\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}|\{[^\}]*?$'

; ===============================================================================================================================
; Func.....: _DeleteAllListViewColumns
; Beschreibung: Löscht alle Spalten einer ListView
; Parameter.: $idListView - ID der ListView
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _DeleteAllListViewColumns($idListView)
    Local $hListView = GUICtrlGetHandle($idListView)
    If $hListView = 0 Then Return False

    ; Alle Spalten löschen
    Local $iCount = _GUICtrlListView_GetColumnCount($hListView)
    For $i = $iCount - 1 To 0 Step -1
        _GUICtrlListView_DeleteColumn($hListView, $i)
    Next

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _Min
; Beschreibung: Findet den kleineren von zwei Werten
; Parameter.: $iVal1, $iVal2 - Zu vergleichende Werte
; Rückgabe..: Der kleinere der beiden Werte
; ===============================================================================================================================
Func _Min($iVal1, $iVal2)
    If $iVal1 < $iVal2 Then Return $iVal1
    Return $iVal2
EndFunc

; ===============================================================================================================================
; Func.....: _Max
; Beschreibung: Findet den größeren von zwei Werten
; Parameter.: $iVal1, $iVal2 - Zu vergleichende Werte
; Rückgabe..: Der größere der beiden Werte
; ===============================================================================================================================
Func _Max($iVal1, $iVal2)
    If $iVal1 > $iVal2 Then Return $iVal1
    Return $iVal2
EndFunc

; ===============================================================================================================================
; Func.....: _BringButtonsToFront
; Beschreibung: Bringt alle Schaltflächen des SQL-Editors in den Vordergrund
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _BringButtonsToFront()
    ; Finde alle Buttons im SQL-Editor-Panel und bringe sie in den Vordergrund
    Local $hGUI = WinGetHandle(AutoItWinGetTitle())
    If $hGUI Then
        ; Buttons nach deren Handle-Namen finden
        Local $aButtonHandles = [GUICtrlGetHandle($g_idSQLExecuteBtn), _
                                GUICtrlGetHandle($g_idSQLSaveBtn), _
                                GUICtrlGetHandle($g_idSQLLoadBtn), _
                                GUICtrlGetHandle($g_idShowCompletionBtn), _
                                GUICtrlGetHandle($g_idSQLBackBtn)]
        
        ; Z-Order für jeden Button setzen (HWND_TOP = im Vordergrund)
        For $i = 0 To UBound($aButtonHandles) - 1
            If $aButtonHandles[$i] <> 0 And IsHWnd($aButtonHandles[$i]) Then
                _WinAPI_SetWindowPos($aButtonHandles[$i], $HWND_TOP, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
            EndIf
        Next
    EndIf
    
    _LogInfo("_BringButtonsToFront: Alle SQL-Editor-Buttons in den Vordergrund gebracht")
EndFunc

; ===============================================================================================================================
; Func.....: _ParseLogFile
; Beschreibung: Parst eine Logdatei und gibt ein Array mit Logeinträgen zurück
; Parameter.: $sFilePath - Pfad zur Logdatei
; Rückgabe..: Array mit Logeinträgen [timestamp, level, class, message, rawText]
; ===============================================================================================================================
Func _ParseLogFile($sFilePath)
    _LogInfo("Parse Logdatei: " & $sFilePath)
    ConsoleWrite("DEBUG: _ParseLogFile aufgerufen mit: " & $sFilePath & @CRLF)
    
    ; Prüfen, ob die Datei existiert
    If Not FileExists($sFilePath) Then
        _LogError("Logdatei existiert nicht: " & $sFilePath)
        ConsoleWrite("DEBUG: Datei existiert nicht!" & @CRLF)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Dateiinhalt einlesen
    Local $sContent = FileRead($sFilePath)
    If @error Then
        _LogError("Fehler beim Lesen der Logdatei: " & $sFilePath)
        ConsoleWrite("DEBUG: Fehler beim Dateien lesen!" & @CRLF)
        Return SetError(2, 0, 0)
    EndIf
    
    ConsoleWrite("DEBUG: Dateiinhalt gelesen, Länge: " & StringLen($sContent) & " Zeichen" & @CRLF)
    ConsoleWrite("DEBUG: Erste 200 Zeichen: " & StringLeft($sContent, 200) & @CRLF)
    
    ; Logformat erkennen
    If StringRegExp($sContent, '\{"Timestamp":"[^"]+\"') Then
        ; JSON-Format erkannt
        _LogInfo("JSON-Logformat erkannt")
        ConsoleWrite("DEBUG: JSON-Format erkannt" & @CRLF)
        Local $aResult = _ParseJsonPatternLog($sContent)
        If @error Then
            ConsoleWrite("DEBUG: JSON-Parser Fehler: " & @error & @CRLF)
            Return SetError(3, 0, 0)
        EndIf
        ConsoleWrite("DEBUG: JSON-Parser erfolgreich, Einträge: " & UBound($aResult) & @CRLF)
        Return $aResult
    Else
        ; Versuchen, ein Textlogformat zu erkennen
        _LogInfo("Versuche Textlogformat zu erkennen")
        ConsoleWrite("DEBUG: Text-Format wird versucht" & @CRLF)
        Local $aResult = _ParseTextLogFile($sFilePath)
        If @error Or Not IsArray($aResult) Or UBound($aResult) = 0 Then
            ConsoleWrite("DEBUG: Standard Text-Parser fehlgeschlagen (Error: " & @error & "), versuche Fallback-Parser" & @CRLF)
            _LogWarning("Standard Text-Parser fehlgeschlagen, versuche Fallback-Parser")
            
            ; Fallback-Parser versuchen
            $aResult = _ParseTextLogFile_Fallback($sFilePath)
            If @error Then
                ConsoleWrite("DEBUG: Auch Fallback-Parser Fehler: " & @error & @CRLF)
                Return SetError(5, 0, 0)
            EndIf
        EndIf
        ConsoleWrite("DEBUG: Text-Parser erfolgreich, Einträge: " & UBound($aResult) & @CRLF)
        Return $aResult
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _GetUniqueLogLevels
; Beschreibung: Extrahiert eindeutige Log-Levels aus einem Log-Einträge-Array
; Parameter.: $aLogEntries - Array mit Logeinträgen
; Rückgabe..: Array mit eindeutigen Log-Levels
; ===============================================================================================================================
Func _GetUniqueLogLevels($aLogEntries)
    ; Dictionary zur Vermeidung von Duplikaten erstellen
    Local $oDict = ObjCreate("Scripting.Dictionary")
    
    ; Einträge zählen für Debug-Info
    Local $iRegularCount = 0
    Local $iTruncatedCount = 0
    
    ; Log-Levels sammeln
    For $i = 0 To UBound($aLogEntries) - 1
        Local $sLevel = $aLogEntries[$i][1]
        
        ; Zählung für Debug-Info
        If StringInStr($sLevel, "TRUNCATED") Then
            $iTruncatedCount += 1
        Else
            $iRegularCount += 1
        EndIf
        
        ; Nur hinzufügen, wenn es noch nicht existiert
        If $sLevel <> "" And Not $oDict.Exists($sLevel) Then
            $oDict.Add($sLevel, 1)
            _LogInfo("Log-Level hinzugefügt: " & $sLevel)
        EndIf
    Next
    
    ; Debug-Info über Eintragstypen
    _LogInfo("Gesamt: " & UBound($aLogEntries) & " Einträge (" & $iRegularCount & " regulär, " & $iTruncatedCount & " TRUNCATED)")
    
    ; In Array umwandeln
    Local $aLevels = $oDict.Keys()
    
    ; Array sortieren
    If UBound($aLevels) > 1 Then
        _ArraySort($aLevels)
    EndIf
    
    ; Sortieren, aber TRUNCATED-Einträge ans Ende stellen
    If UBound($aLevels) > 1 Then
        ; Zuerst normal sortieren
        _ArraySort($aLevels)
        
        ; Dann TRUNCATED-Einträge ans Ende verschieben
        Local $aSortedLevels[0]
        Local $aTruncatedLevels[0]
        
        ; Aufteilen in normale und TRUNCATED-Einträge
        For $i = 0 To UBound($aLevels) - 1
            If StringInStr($aLevels[$i], "TRUNCATED") Then
                _ArrayAdd($aTruncatedLevels, $aLevels[$i])
            Else
                _ArrayAdd($aSortedLevels, $aLevels[$i])
            EndIf
        Next
        
        ; Zuerst normale, dann TRUNCATED-Einträge im Ergebnis
        Local $aFinalLevels[UBound($aSortedLevels) + UBound($aTruncatedLevels)]
        For $i = 0 To UBound($aSortedLevels) - 1
            $aFinalLevels[$i] = $aSortedLevels[$i]
        Next
        For $i = 0 To UBound($aTruncatedLevels) - 1
            $aFinalLevels[UBound($aSortedLevels) + $i] = $aTruncatedLevels[$i]
        Next
        
        Return $aFinalLevels
    EndIf
    
    Return $aLevels
EndFunc

; ===============================================================================================================================
; Func.....: _GetUniqueLogClasses
; Beschreibung: Extrahiert eindeutige Log-Klassen aus einem Log-Einträge-Array
; Parameter.: $aLogEntries - Array mit Logeinträgen
; Rückgabe..: Array mit eindeutigen Log-Klassen
; ===============================================================================================================================
Func _GetUniqueLogClasses($aLogEntries)
    ; Dictionary zur Vermeidung von Duplikaten erstellen
    Local $oDict = ObjCreate("Scripting.Dictionary")
    
    ; Log-Klassen sammeln
    For $i = 0 To UBound($aLogEntries) - 1
        Local $sClass = $aLogEntries[$i][2]
        Local $bIsTruncated = StringInStr($aLogEntries[$i][1], "TRUNCATED") > 0
        
        ; Für TRUNCATED-Einträge markieren wir die Klasse für bessere Unterscheidung
        If $bIsTruncated And Not StringInStr($sClass, "(TRUNCATED)") Then
            $sClass = $sClass & " (TRUNCATED)"
        EndIf
        
        If $sClass <> "" And Not $oDict.Exists($sClass) Then
            $oDict.Add($sClass, 1)
            _LogInfo("Log-Klasse hinzugefügt: " & $sClass)
        EndIf
    Next
    
    ; In Array umwandeln
    Local $aClasses = $oDict.Keys()
    
    ; Sortieren, aber TRUNCATED-bezogene Klassen ans Ende stellen
    If UBound($aClasses) > 1 Then
        ; Zuerst normal sortieren
        _ArraySort($aClasses)
        
        ; Dann TRUNCATED-Klassen ans Ende verschieben
        Local $aSortedClasses[0]
        Local $aTruncatedClasses[0]
        
        ; Aufteilen in normale und TRUNCATED-Klassen
        For $i = 0 To UBound($aClasses) - 1
            If StringInStr($aClasses[$i], "TRUNCATED") Then
                _ArrayAdd($aTruncatedClasses, $aClasses[$i])
            Else
                _ArrayAdd($aSortedClasses, $aClasses[$i])
            EndIf
        Next
        
        ; Zuerst normale, dann TRUNCATED-Klassen im Ergebnis
        Local $aFinalClasses[UBound($aSortedClasses) + UBound($aTruncatedClasses)]
        For $i = 0 To UBound($aSortedClasses) - 1
            $aFinalClasses[$i] = $aSortedClasses[$i]
        Next
        For $i = 0 To UBound($aTruncatedClasses) - 1
            $aFinalClasses[UBound($aSortedClasses) + $i] = $aTruncatedClasses[$i]
        Next
        
        Return $aFinalClasses
    EndIf
    
    Return $aClasses
EndFunc

; ===============================================================================================================================
; Func.....: _GetLogStatistics
; Beschreibung: Erstellt Statistiken über Logeinträge
; Parameter.: $aLogEntries - Array mit Logeinträgen
; Rückgabe..: Dictionary-Objekt mit Statistiken
; ===============================================================================================================================
Func _GetLogStatistics($aLogEntries)
    ; Dictionary für die Ergebnisse erstellen
    Local $oStats = ObjCreate("Scripting.Dictionary")
    Local $oLevelStats = ObjCreate("Scripting.Dictionary")
    
    ; Gesamtzahl der Einträge
    $oStats.Add("TotalEntries", UBound($aLogEntries))
    
    ; Zählen von unvollständigen Einträgen
    Local $iTruncatedCount = 0
    
    ; Statistik nach Log-Level
    For $i = 0 To UBound($aLogEntries) - 1
        Local $sLevel = $aLogEntries[$i][1]
        
        ; Zählen von unvollständigen Einträgen
        If StringInStr($sLevel, "TRUNCATED") Then
            $iTruncatedCount += 1
        EndIf
        
        ; Level-Zählung
        If $oLevelStats.Exists($sLevel) Then
            $oLevelStats.Item($sLevel) = $oLevelStats.Item($sLevel) + 1
        Else
            $oLevelStats.Add($sLevel, 1)
        EndIf
    Next
    
    ; Unvollständige Einträge hinzufügen, falls vorhanden
    If $iTruncatedCount > 0 Then
        $oStats.Add("TruncatedEntries", $iTruncatedCount)
    EndIf
    
    ; Level-Statistik hinzufügen
    $oStats.Add("LevelStats", $oLevelStats)
    
    Return $oStats
EndFunc

; ===============================================================================================================================
; Func.....: _FindLogFiles
; Beschreibung: Findet alle Logdateien in einem Verzeichnis
; Parameter.: $sPath - Pfad zum Verzeichnis
; Rückgabe..: Array mit Pfaden zu Logdateien
; ===============================================================================================================================
Func _FindLogFiles($sPath)
    _LogInfo("Suche Logdateien in: " & $sPath)
    
    ; Array für die gefundenen Dateien
    Local $aLogFiles[1] = [$sPath] ; Erste Position enthält den Basispfad
    
    ; Dateien im Verzeichnis durchsuchen
    Local $aFiles = _FileListToArray($sPath, "*.*", $FLTA_FILES, True)
    If @error Then
        _LogWarning("Keine Dateien im Verzeichnis gefunden oder Fehler beim Zugriff: " & $sPath)
        Return $aLogFiles
    EndIf
    
    ; Dateien überprüfen und Logdateien hinzufügen
    For $i = 1 To $aFiles[0]
        Local $sFilePath = $aFiles[$i]
        Local $sExt = StringLower(StringRegExpReplace($sFilePath, "^.*\.([^.]+)$", "$1"))
        
        ; Typische Log-Dateiendungen oder Inhalt überprüfen
        If $sExt = "log" Or $sExt = "txt" Or $sExt = "json" Then
            _ArrayAdd($aLogFiles, $sFilePath)
        EndIf
    Next
    
    ; Anzahl der gefundenen Dateien in Position 0 speichern
    $aLogFiles[0] = UBound($aLogFiles) - 1
    
    _LogInfo("Gefundene Logdateien: " & $aLogFiles[0])
    Return $aLogFiles
EndFunc

; ===============================================================================================================================
; Func.....: _SearchLogEntries
; Beschreibung: Durchsucht Logeinträge nach bestimmten Kriterien
; Parameter.: $aLogEntries - Array mit Logeinträgen
;             $sSearchText - Suchtext
;             $bRegex - True wenn RegEx-Suche, sonst False
;             $sLevel - Optionaler Level-Filter
;             $sClass - Optionaler Klassen-Filter
; Rückgabe..: Array mit gefundenen Einträgen
; ===============================================================================================================================
Func _SearchLogEntries($aLogEntries, $sSearchText, $bRegex = False, $sLevel = "", $sClass = "")
    _LogInfo("Durchsuche Logeinträge: " & $sSearchText & ", RegEx: " & $bRegex & ", Level: " & $sLevel & ", Class: " & $sClass)
    
    ; Array für die Ergebnisse
    Local $aResults[0][6] ; Auf 6 Spalten erweitert (inkl. Zeilennummer)
    Local $iResultCount = 0
    
    ; Unvollständige Einträge immer sammeln
    Local $aTruncated[0][6] ; Auch auf 6 Spalten erweitert
    Local $iTruncatedCount = 0
    
    ; Einträge durchsuchen
    For $i = 0 To UBound($aLogEntries) - 1
        ; Unvollständige Einträge immer in separate Liste aufnehmen
        If StringInStr($aLogEntries[$i][1], "TRUNCATED") Then
            ReDim $aTruncated[$iTruncatedCount + 1][6]
            For $j = 0 To 5 ; Alle 6 Spalten inklusive Zeilennummer kopieren
                $aTruncated[$iTruncatedCount][$j] = $aLogEntries[$i][$j]
            Next
            $iTruncatedCount += 1
            ContinueLoop
        EndIf
        
        ; Level-Filter anwenden
        If $sLevel <> "" And $aLogEntries[$i][1] <> $sLevel Then
            ContinueLoop
        EndIf
        
        ; Klassen-Filter anwenden
        If $sClass <> "" And $aLogEntries[$i][2] <> $sClass Then
            ContinueLoop
        EndIf
        
        ; Textsuche
        Local $bFound = False
        
        ; Alle Spalten durchsuchen
        For $j = 0 To 3 ; Timestamp, Level, Class, Message
            If $bRegex Then
                ; RegEx-Suche
                Local $aRegexMatch = StringRegExp($aLogEntries[$i][$j], $sSearchText, $STR_REGEXPARRAYMATCH)
                If Not @error Then
                    $bFound = True
                    ExitLoop
                EndIf
            Else
                ; Normale Textsuche (Groß-/Kleinschreibung ignorieren)
                If StringInStr($aLogEntries[$i][$j], $sSearchText, $STR_CASESENSE) > 0 Then
                    $bFound = True
                    ExitLoop
                EndIf
            EndIf
        Next
        
        ; Wenn gefunden, zum Ergebnis hinzufügen
        If $bFound Then
            ReDim $aResults[$iResultCount + 1][6]
            For $j = 0 To 5 ; Alle 6 Spalten inklusive Zeilennummer kopieren
                $aResults[$iResultCount][$j] = $aLogEntries[$i][$j]
            Next
            $iResultCount += 1
        EndIf
    Next
    
    ; Unvollständige Einträge hinzufügen
    Local $aFinalResults[$iResultCount + $iTruncatedCount][6] ; Auf 6 Spalten erweitert
    
    ; Zuerst die unvollständigen Einträge
    For $i = 0 To $iTruncatedCount - 1
        For $j = 0 To 5 ; Alle 6 Spalten inklusive Zeilennummer kopieren
            $aFinalResults[$i][$j] = $aTruncated[$i][$j]
        Next
    Next
    
    ; Dann die gefundenen Einträge
    For $i = 0 To $iResultCount - 1
        For $j = 0 To 5 ; Alle 6 Spalten inklusive Zeilennummer kopieren
            $aFinalResults[$i + $iTruncatedCount][$j] = $aResults[$i][$j]
        Next
    Next
    
    ; Ergebnis nach Zeilennummer sortieren, um ursprüngliche Reihenfolge zu erhalten
    If UBound($aFinalResults) > 1 Then
        _ArraySort($aFinalResults, 0, 0, 0, 5) ; nach Zeilennummer sortieren (5. Spalte)
    EndIf
    
    _LogInfo("Suchergebnisse: " & UBound($aFinalResults) & " Einträge gefunden")
    Return $aFinalResults
EndFunc

; ===============================================================================================================================
; Func.....: FileEOF
; Beschreibung: Prüft, ob das Ende einer Datei erreicht wurde
; Parameter.: $hFile - Handle der geöffneten Datei
; Rückgabe..: True wenn Ende der Datei erreicht, sonst False
; ===============================================================================================================================
Func FileEOF($hFile)
    ; Aktuelle Position speichern
    Local $iCurrentPos = FileGetPos($hFile)
    
    ; Ein Zeichen lesen versuchen
    Local $sChar = FileRead($hFile, 1)
    
    ; Zurück zur ursprünglichen Position
    FileSetPos($hFile, $iCurrentPos, $FILE_BEGIN)
    
    ; Wenn kein Zeichen gelesen wurde, ist das Dateiende erreicht
    Return ($sChar = "")
EndFunc

; ===============================================================================================================================
; Func.....: _ParseTextLogFile_Fallback
; Beschreibung: Fallback-Parser für Text-Logdateien wenn andere Parser versagen
; Parameter.: $sFilePath - Pfad zur Logdatei
; Rückgabe..: Array mit Logeinträgen [timestamp, level, class, message, rawText, lineNumber]
; ===============================================================================================================================
Func _ParseTextLogFile_Fallback($sFilePath)
    ConsoleWrite("DEBUG: Fallback Text-Parser wird verwendet für: " & $sFilePath & @CRLF)
    _LogInfo("Fallback Text-Parser für: " & $sFilePath)
    
    ; Datei zeilenweise lesen
    Local $aLines = FileReadToArray($sFilePath)
    If @error Then
        ConsoleWrite("DEBUG: FileReadToArray Fehler: " & @error & @CRLF)
        Return SetError(1, 0, 0)
    EndIf
    
    ConsoleWrite("DEBUG: Fallback-Parser - " & UBound($aLines) & " Zeilen gelesen" & @CRLF)
    
    ; Array für Logeinträge erstellen (6 Spalten für Kompatibilität)
    Local $aLogEntries[UBound($aLines)][6]
    
    ; Jede Zeile als separaten Log-Eintrag behandeln
    For $i = 0 To UBound($aLines) - 1
        Local $sLine = $aLines[$i]
        
        ; Einfache Pattern-Erkennung
        Local $sTimestamp = ""
        Local $sLevel = "INFO"
        Local $sClass = "Unknown"
        Local $sMessage = $sLine
        
        ; Versuche Zeitstempel zu extrahieren (verschiedene Formate)
        Local $aTimeMatch = StringRegExp($sLine, '(\d{4}-\d{2}-\d{2}[\sT]\d{2}:\d{2}:\d{2})', 1)
        If Not @error Then
            $sTimestamp = $aTimeMatch[0]
        Else
            ; Alternativ: DD.MM.YYYY HH:MM:SS
            $aTimeMatch = StringRegExp($sLine, '(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2})', 1)
            If Not @error Then
                $sTimestamp = $aTimeMatch[0]
            Else
                ; Fallback: Aktueller Zeitstempel
                $sTimestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
            EndIf
        EndIf
        
        ; Log-Level erkennen
        If StringRegExp($sLine, '(?i)(ERROR|ERR)') Then
            $sLevel = "ERROR"
        ElseIf StringRegExp($sLine, '(?i)(WARN|WARNING)') Then
            $sLevel = "WARNING"
        ElseIf StringRegExp($sLine, '(?i)(DEBUG|DBG)') Then
            $sLevel = "DEBUG"
        ElseIf StringRegExp($sLine, '(?i)(TRACE|TRC)') Then
            $sLevel = "TRACE"
        ElseIf StringRegExp($sLine, '(?i)(FATAL|CRIT|CRITICAL)') Then
            $sLevel = "FATAL"
        EndIf
        
        ; Array befüllen
        $aLogEntries[$i][0] = $sTimestamp
        $aLogEntries[$i][1] = $sLevel
        $aLogEntries[$i][2] = $sClass
        $aLogEntries[$i][3] = $sMessage
        $aLogEntries[$i][4] = $sLine  ; Raw text
        $aLogEntries[$i][5] = $i + 1  ; Line number
    Next
    
    ConsoleWrite("DEBUG: Fallback-Parser erfolgreich - " & UBound($aLogEntries) & " Einträge erstellt" & @CRLF)
    _LogInfo("Fallback Text-Parser erfolgreich: " & UBound($aLogEntries) & " Einträge")
    
    Return $aLogEntries
EndFunc

