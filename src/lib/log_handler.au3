#cs
Log Handler Funktionen
#ce

#include-once
#include "constants.au3"

; DigiApp Parser Mock-Funktionen
Func DigiAppParser_SearchLogs($aLogEntries, $sSearchPattern, $bRegex = False, $sLogLevel = "", $sLogClass = "", $sDateFrom = "", $sDateTo = "")
    Local $aResults[0]
    
    ; Such-Logik implementieren
    For $i = 0 To UBound($aLogEntries) - 1
        ; Platzhalter-Implementierung
        If StringInStr($aLogEntries[$i], $sSearchPattern) Then
            _ArrayAdd($aResults, $aLogEntries[$i])
        EndIf
    Next
    
    Return $aResults
EndFunc

Func DigiAppParser_GetUniqueLogClasses($aLogEntries)
    Local $aUniqueClasses[0]
    
    ; Eindeutige Log-Klassen extrahieren
    For $i = 0 To UBound($aLogEntries) - 1
        ; Platzhalter-Implementierung
        Local $sLogClass = StringRegExp($aLogEntries[$i], "LogClass:\s*(\w+)", $STR_REGEXPARRAYMATCH)
        If Not _ArraySearch($aUniqueClasses, $sLogClass[0]) Then
            _ArrayAdd($aUniqueClasses, $sLogClass[0])
        EndIf
    Next
    
    Return $aUniqueClasses
EndFunc
