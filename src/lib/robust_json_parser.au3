#include-once
#include <File.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include "logging.au3"
#include "JSON.au3"
#include "file_utils.au3"
#include "json_helper.au3"
#include "constants_new.au3"

; Parst JSON-Logs zeilenweise - komplett überarbeiteter Ansatz
Func _ParseJsonLogFile($sFilePath)
    _LogInfo("Parse JSON-Logs mit zeilenweisem Parser: " & $sFilePath)
    
    ; Sicherstellen, dass die Datei existiert
    If Not FileExists($sFilePath) Then
        _LogError("Datei nicht gefunden: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Datei laden
    Local $sContent = FileRead($sFilePath)
    If @error Then
        _LogError("Fehler beim Lesen der Datei: " & @error)
        Return SetError(2, 0, 0)
    EndIf
    
    ; Array zur Speicherung der Ergebnisse
    Local $aLogEntries[0][5]  ; [timestamp, level, class, message, rawText]
    Local $iEntryCount = 0
    
    ; Zerlege den Inhalt in Zeilen für die Verarbeitung
    Local $aLines = StringSplit($sContent, @CRLF, $STR_ENTIRESPLIT)
    
    ; Temporärer Buffer für unvollständige Einträge
    Local $sCurrentEntry = ""
    Local $bEntryStarted = False
    
    ; Debug-Information
    ConsoleWrite("PARSER: Starte Verarbeitung von " & $aLines[0] & " Zeilen..." & @CRLF)
    _LogInfo("Verarbeite " & $aLines[0] & " Zeilen...")
    
    ; Verarbeite jede Zeile
    For $i = 1 To $aLines[0]
        Local $sLine = $aLines[$i]
        
        ; Leere Zeilen überspringen
        If StringStripWS($sLine, $STR_STRIPALL) = "" Then ContinueLoop
        
        ; Prüfe, ob die Zeile ein neues JSON-Objekt startet
        If StringLeft(StringStripWS($sLine, $STR_STRIPLEADING), 1) = "{" Then
            ; Falls wir bereits einen unvollständigen Eintrag im Buffer haben, diesen als unvollständig hinzufügen
            If $bEntryStarted And $sCurrentEntry <> "" Then
                ; UNVOLLSTÄNDIGER EINTRAG GEFUNDEN
                _AddIncompleteLogEntry($aLogEntries, $iEntryCount, $sCurrentEntry)
                $iEntryCount += 1
                
                ; Debug-Information
                ConsoleWrite("UNVOLLSTÄNDIG: " & StringLeft($sCurrentEntry, 50) & "..." & @CRLF)
                _LogInfo("Unvollständiger Eintrag gefunden: " & StringLeft($sCurrentEntry, 30) & "...")
            EndIf
            
            ; Starte einen neuen Eintrag
            $sCurrentEntry = $sLine
            $bEntryStarted = True
            
            ; Prüfe, ob die Zeile ein vollständiges JSON-Objekt enthält
            If StringRight(StringStripWS($sLine, $STR_STRIPTRAILING), 1) = "}" Then
                ; VOLLSTÄNDIGES JSON erkannt
                _AddCompleteLogEntry($aLogEntries, $iEntryCount, $sLine)
                $iEntryCount += 1
                
                ; Buffer zurücksetzen
                $sCurrentEntry = ""
                $bEntryStarted = False
            EndIf
        ElseIf $bEntryStarted Then
            ; Zeile zum aktuellen Eintrag hinzufügen
            $sCurrentEntry &= $sLine
            
            ; Prüfe, ob der Eintrag jetzt vollständig ist
            If StringRight(StringStripWS($sLine, $STR_STRIPTRAILING), 1) = "}" Then
                ; VOLLSTÄNDIGES JSON erkannt (mehrere Zeilen)
                _AddCompleteLogEntry($aLogEntries, $iEntryCount, $sCurrentEntry)
                $iEntryCount += 1
                
                ; Buffer zurücksetzen
                $sCurrentEntry = ""
                $bEntryStarted = False
            EndIf
        EndIf
    Next
    
    ; Letzten unvollständigen Eintrag hinzufügen, falls vorhanden
    If $bEntryStarted And $sCurrentEntry <> "" Then
        ; UNVOLLSTÄNDIGER EINTRAG GEFUNDEN (am Ende der Datei)
        _AddIncompleteLogEntry($aLogEntries, $iEntryCount, $sCurrentEntry)
        $iEntryCount += 1
        
        ; Debug-Information
        ConsoleWrite("LETZTER UNVOLLSTÄNDIG: " & StringLeft($sCurrentEntry, 50) & "..." & @CRLF)
        _LogInfo("Letzter unvollständiger Eintrag: " & StringLeft($sCurrentEntry, 30) & "...")
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

    ; Debug-Ausgabe
    _LogInfo("FINALE ANZAHL EINTRÄGE: " & $iEntryCount)
    ConsoleWrite("PARSER: FINALE ANZAHL EINTRÄGE: " & $iEntryCount & @CRLF)
    
    ; Zusätzliche Prüfung: Suche unvollständige Einträge im finalen Array
    Local $iTruncatedCount = 0
    For $i = 0 To $iEntryCount - 1
        If StringInStr($aLogEntries[$i][1], "TRUNCATED") Then
            $iTruncatedCount += 1
            ConsoleWrite("UNVOLLSTÄNDIG #" & $iTruncatedCount & " an Position " & $i & ": " & $aLogEntries[$i][0] & @CRLF)
        EndIf
    Next
    ConsoleWrite("PARSER: Insgesamt " & $iTruncatedCount & " unvollständige Einträge gefunden." & @CRLF)
    
    _LogInfo("JSON-Logdatei erfolgreich geparst: " & $iEntryCount & " Einträge gesamt (davon " & $iTruncatedCount & " unvollständig)")
    Return $aLogEntries
EndFunc

; Hilfsfunktion: Fügt einen vollständigen Log-Eintrag zum Array hinzu
Func _AddCompleteLogEntry(ByRef $aLogEntries, $iIndex, $sJsonText)
    ; Versuchen, das JSON zu parsen
    Local $oJson = Json_Decode($sJsonText)
    
    ; Bei Fehlern, als Rohtext behandeln
    If @error Or Not IsObj($oJson) Then
        ; Eintrag erweitern
        ReDim $aLogEntries[$iIndex + 1][5]
        
        ; Als einfachen Texteintrag hinzufügen
        $aLogEntries[$iIndex][0] = _NowCalc() ; Timestamp
        $aLogEntries[$iIndex][1] = "INFO" ; Level
        $aLogEntries[$iIndex][2] = "RawJSON" ; Class
        $aLogEntries[$iIndex][3] = $sJsonText ; Message
        $aLogEntries[$iIndex][4] = $sJsonText ; Raw
        
        Return
    EndIf
    
    ; Timestamp extrahieren
    Local $sTimestamp = ""
    If Json_Get($oJson, ".Timestamp") <> "" Then 
        $sTimestamp = Json_Get($oJson, ".Timestamp")
    EndIf
    
    ; LogLevel extrahieren
    Local $sLogLevel = ""
    If Json_Get($oJson, ".LogLevel") <> "" Then 
        $sLogLevel = Json_Get($oJson, ".LogLevel")
    EndIf
    
    ; LogClass extrahieren
    Local $sLogClass = ""
    If Json_Get($oJson, ".LogClass") <> "" Then 
        $sLogClass = Json_Get($oJson, ".LogClass")
    EndIf
    
    ; Message extrahieren
    Local $sMessage = ""
    If Json_Get($oJson, ".Message") <> "" Then 
        $sMessage = Json_Get($oJson, ".Message")
    EndIf
    
    ; Eintrag erweitern
    ReDim $aLogEntries[$iIndex + 1][5]
    
    ; Daten einfügen
    $aLogEntries[$iIndex][0] = $sTimestamp
    $aLogEntries[$iIndex][1] = $sLogLevel
    $aLogEntries[$iIndex][2] = $sLogClass
    $aLogEntries[$iIndex][3] = $sMessage
    $aLogEntries[$iIndex][4] = $sJsonText
EndFunc

; Hilfsfunktion: Fügt einen unvollständigen Log-Eintrag zum Array hinzu
Func _AddIncompleteLogEntry(ByRef $aLogEntries, $iIndex, $sIncompleteText)
    ; Timestamp extrahieren (aus JSON-Format oder ISO-Format)
    Local $sTimestamp = ""
    Local $aTimestampMatch = StringRegExp($sIncompleteText, '"Timestamp":"([^"]+)"', 1)
    If Not @error Then
        $sTimestamp = $aTimestampMatch[0]
        ConsoleWrite("  > Timestamp aus JSON: " & $sTimestamp & @CRLF)
    ElseIf StringRegExp($sIncompleteText, '^\{"Timestamp"') Then
        ; Abgeschnittener Timestamp
        $sTimestamp = _NowCalc() ; Fallback auf aktuelle Zeit
        ConsoleWrite("  > Abgeschnittener Timestamp, verwende aktuelles Datum: " & $sTimestamp & @CRLF)
    Else
        ; Versuchen, einen ISO-Timestamp direkt zu finden
        $aTimestampMatch = StringRegExp($sIncompleteText, '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+[+-]\d{2}:\d{2}', 1)
        If Not @error Then
            $sTimestamp = $aTimestampMatch[0]
            ConsoleWrite("  > ISO-Timestamp gefunden: " & $sTimestamp & @CRLF)
        Else
            ; Fallback auf aktuelle Zeit
            $sTimestamp = _NowCalc()
            ConsoleWrite("  > Kein Timestamp gefunden, verwende aktuelles Datum: " & $sTimestamp & @CRLF)
        EndIf
    EndIf
    
    ; LogLevel extrahieren oder Standard verwenden
    Local $sLogLevel = "TRUNCATED"
    Local $aLevelMatch = StringRegExp($sIncompleteText, '"LogLevel":"([^"]+)"', 1)
    If Not @error Then
        $sLogLevel = $aLevelMatch[0] & " (TRUNCATED)"
    EndIf
    
    ; LogClass extrahieren oder Standard verwenden
    Local $sLogClass = "Unvollständiger Eintrag"
    Local $aClassMatch = StringRegExp($sIncompleteText, '"LogClass":"([^"]+)"', 1)
    If Not @error Then
        $sLogClass = $aClassMatch[0]
    EndIf
    
    ; Eintrag erweitern
    ReDim $aLogEntries[$iIndex + 1][5]
    
    ; Daten einfügen - unvollständigen Text als Message verwenden
    $aLogEntries[$iIndex][0] = $sTimestamp
    $aLogEntries[$iIndex][1] = $sLogLevel
    $aLogEntries[$iIndex][2] = $sLogClass
    $aLogEntries[$iIndex][3] = "!!! UNVOLLSTÄNDIGER LOG-EINTRAG !!! " & $sIncompleteText
    $aLogEntries[$iIndex][4] = $sIncompleteText
EndFunc