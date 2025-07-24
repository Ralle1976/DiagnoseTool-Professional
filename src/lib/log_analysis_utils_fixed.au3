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

; Einfaches Pattern für unvollständige JSON-Logs - beginnt mit {"Timestamp" und hat kein schließendes }
Global $g_sIncompleteLogPattern = '\{"Timestamp":"([^"]+)"[^}]*?(?:\r\n|\n|$)'

; Parst JSON-Logs mit dem spezifischen Pattern - verbesserte Version mit mehr Debug-Ausgaben
Func _ParseJsonPatternLog($sContent)
    _LogInfo("Parse JSON-Logs mit vereinfachtem Pattern")

    ; Array zur Speicherung der Ergebnisse
    Local $aLogEntries[0][5]  ; [timestamp, level, class, message, rawText]
    Local $iEntryCount = 0
    Local $iIncompleteCount = 0

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

    ; 2. Jetzt nach unvollständigen Einträgen suchen
    Local $aIncompleteMatches = StringRegExp($sContent, $g_sIncompleteLogPattern, 3)
    
    If Not @error Then
        _LogInfo("Gefundene unvollständige Log-Einträge: " & UBound($aIncompleteMatches))
        $iIncompleteCount = UBound($aIncompleteMatches)
        
        ; Für jedes unvollständige Match
        For $i = 0 To UBound($aIncompleteMatches) - 1
            ; Das komplette unvollständige JSON nehmen
            Local $sIncompleteText = $aIncompleteMatches[$i]
            
            ; Debug-Information
            _LogInfo("UNVOLLSTÄNDIGER EINTRAG GEFUNDEN: " & $sIncompleteText)
            
            ; Timestamp extrahieren - wir wissen, dass er im Match vorhanden ist
            Local $aTimestampMatch = StringRegExp($sIncompleteText, '"Timestamp":"([^"]+)"', 1)
            If Not @error Then
                Local $sTimestamp = $aTimestampMatch[0]
                ; Log-Level als TRUNCATED markieren, damit es auffällt
                Local $sLogLevel = "TRUNCATED"
                Local $sLogClass = "Unbekannt"
                
                ; Debug-Information
                _LogInfo("TIMESTAMP EXTRAHIERT: " & $sTimestamp)
                
                ; Prüfen, ob es bereits einen vollständigen Eintrag mit diesem Timestamp gibt
                Local $bIsDuplicate = False
                For $j = 0 To $iEntryCount - 1
                    If $aLogEntries[$j][0] == $sTimestamp Then
                        $bIsDuplicate = True
                        _LogInfo("DUPLIKAT GEFUNDEN FÜR: " & $sTimestamp)
                        ExitLoop
                    EndIf
                Next
                
                ; WICHTIG: Selbst wenn es ein Duplikat ist, sollten wir es hinzufügen
                ; damit unvollständige Einträge immer sichtbar sind
                $bIsDuplicate = False
                
                ; Nur hinzufügen, wenn kein Duplikat oder wenn wir alle anzeigen möchten
                If Not $bIsDuplicate Then
                    ; Optional: Versuche LogLevel zu extrahieren
                    Local $aLevelMatch = StringRegExp($sIncompleteText, '"LogLevel":"([^"]+)"', 1)
                    If Not @error Then
                        $sLogLevel = $aLevelMatch[0] & " (TRUNCATED)"
                    EndIf
                    
                    ; Optional: Versuche LogClass zu extrahieren
                    Local $aClassMatch = StringRegExp($sIncompleteText, '"LogClass":"([^"]+)"', 1)
                    If Not @error Then
                        $sLogClass = $aClassMatch[0]
                    EndIf
                    
                    ; WICHTIG: Den unvollständigen JSON-String selbst als Nachricht verwenden
                    ; Hierbei "UNVOLLSTÄNDIGER EINTRAG:" voranstellen, damit es auffällt
                    Local $sMessage = "UNVOLLSTÄNDIGER EINTRAG: " & $sIncompleteText
                    
                    ; Eintrag zum Array hinzufügen
                    ReDim $aLogEntries[$iEntryCount + 1][5]
                    $aLogEntries[$iEntryCount][0] = $sTimestamp     ; Timestamp
                    $aLogEntries[$iEntryCount][1] = $sLogLevel      ; LogLevel (TRUNCATED)
                    $aLogEntries[$iEntryCount][2] = $sLogClass      ; LogClass
                    $aLogEntries[$iEntryCount][3] = $sMessage       ; Unvollständiges JSON als Nachricht
                    $aLogEntries[$iEntryCount][4] = $sIncompleteText ; Raw
                    
                    ; Wichtig: Zähler erhöhen!
                    $iEntryCount += 1
                    
                    ; Debug-Information
                    _LogInfo("UNVOLLSTÄNDIGER EINTRAG HINZUGEFÜGT - Anzahl jetzt: " & $iEntryCount)
                EndIf
            Else
                _LogInfo("FEHLER: Konnte keinen Timestamp extrahieren aus: " & $sIncompleteText)
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
    
    ; Hier explizit noch einmal die Anzahl der unvollständigen Einträge ausgeben
    If $iIncompleteCount > 0 Then
        _LogInfo("DAVON UNVOLLSTÄNDIGE EINTRÄGE: " & $iIncompleteCount)
    EndIf

    ; Sortieren nach Timestamp - WICHTIG: Wir machen nur eine einfache Sortierung,
    ; damit die unvollständigen Einträge richtig an ihrer zeitlichen Position erscheinen
    _ArraySort($aLogEntries, 0, 0, 0, 0) ; Sortieren nach erster Spalte (Timestamp)

    _LogInfo("JSON-Logdatei erfolgreich geparst: " & $iEntryCount & " Einträge gesamt")
    Return $aLogEntries
EndFunc

; Rest der Funktionen wie vorher...
#region Andere Parser
; (Code hier unverändert, wird hier nicht wiederholt)
#endregion