#include-once
#include <File.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include "logging.au3"
#include "JSON.au3"
#include "file_utils.au3"
#include "missing_functions.au3"
#include "log_parser.au3"

; Definieren des Log-Patterns für vollständige JSON Logs
Global $g_sCompleteLogPattern = '\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'

; Einfaches Pattern für unvollständige JSON-Logs - beginnt mit {"Timestamp" und hat kein schließendes }
Global $g_sIncompleteLogPattern = '(\{"Timestamp":"[^}]*?)(?:\r\n|\n|$)'

; Parst JSON-Logs - einfache Version mit direkter RegEx-Erkennung
Func _ParseJsonPatternLog($sContent)
    _LogInfo("Parse JSON-Logs mit vereinfachtem Pattern")

    ; Array zur Speicherung der Ergebnisse
    Local $aLogEntries[0][5]  ; [timestamp, level, class, message, rawText]
    Local $iEntryCount = 0

    ; 1. Zuerst vollständige Einträge suchen mit dem Original-Pattern
    Local $aMatches = StringRegExp($sContent, $g_sCompleteLogPattern, 4)
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

    ; 2. Jetzt nach unvollständigen Einträgen suchen - alles was mit {"Timestamp" beginnt
    ; und kein schließendes } hat
    Local $aIncompleteMatches = StringRegExp($sContent, $g_sIncompleteLogPattern, 4)
    
    If Not @error Then
        _LogInfo("Gefundene unvollständige Log-Einträge: " & UBound($aIncompleteMatches))
        
        For $i = 0 To UBound($aIncompleteMatches) - 1
            Local $sIncompleteJson = $aIncompleteMatches[$i][0]
            
            ; Versuche Timestamp zu extrahieren
            Local $aTimestampMatch = StringRegExp($sIncompleteJson, '"Timestamp":"([^"]+)"', $STR_REGEXPARRAYMATCH)
            If IsArray($aTimestampMatch) And UBound($aTimestampMatch) > 0 Then
                Local $sTimestamp = $aTimestampMatch[0]
                Local $sLogLevel = "TRUNCATED"
                Local $sLogClass = "Unbekannt"
                
                ; Prüfen, ob es bereits einen vollständigen Eintrag mit diesem Timestamp gibt
                Local $bIsDuplicate = False
                For $j = 0 To $iEntryCount - 1
                    If $aLogEntries[$j][0] == $sTimestamp Then
                        $bIsDuplicate = True
                        ExitLoop
                    EndIf
                Next
                
                ; Nur hinzufügen, wenn kein Duplikat
                If Not $bIsDuplicate Then
                    ; Optional: Versuche LogLevel zu extrahieren
                    Local $aLevelMatch = StringRegExp($sIncompleteJson, '"LogLevel":"([^"]+)"', $STR_REGEXPARRAYMATCH)
                    If IsArray($aLevelMatch) And UBound($aLevelMatch) > 0 Then
                        $sLogLevel = $aLevelMatch[0] & " (TRUNCATED)"
                    EndIf
                    
                    ; Optional: Versuche LogClass zu extrahieren
                    Local $aClassMatch = StringRegExp($sIncompleteJson, '"LogClass":"([^"]+)"', $STR_REGEXPARRAYMATCH)
                    If IsArray($aClassMatch) And UBound($aClassMatch) > 0 Then
                        $sLogClass = $aClassMatch[0]
                    EndIf
                    
                    ; WICHTIG: Den unvollständigen JSON-String selbst als Nachricht verwenden
                    Local $sMessage = $sIncompleteJson
                    
                    ReDim $aLogEntries[$iEntryCount + 1][5]
                    $aLogEntries[$iEntryCount][0] = $sTimestamp     ; Timestamp
                    $aLogEntries[$iEntryCount][1] = $sLogLevel      ; LogLevel (TRUNCATED)
                    $aLogEntries[$iEntryCount][2] = $sLogClass      ; LogClass
                    $aLogEntries[$iEntryCount][3] = $sMessage       ; Unvollständiges JSON als Nachricht
                    $aLogEntries[$iEntryCount][4] = $sIncompleteJson ; Raw
                    $iEntryCount += 1
                EndIf
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