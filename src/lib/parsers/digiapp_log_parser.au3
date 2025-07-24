#include-once
#include <File.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include "../logging.au3"

; DigiApp-Log-Parser
; Optimiert für das Format: {"Timestamp":"2025-02-17T01:04:03.867024+01:00","LogLevel":"Debug","LogClass":"Logger","Message":"RegisterClient(Datenuebertragung)"}

; RegEx-Pattern für das DigiApp-Log-Format
Global $g_sDigiAppLogPattern = '\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'

; Prüft, ob eine Datei ein DigiApp-Log ist
Func _DigiAppParser_IsLogFile($sFilePath)
    _LogInfo("Prüfe, ob " & $sFilePath & " ein DigiApp-Log ist")
    
    ; Dateiexistenz prüfen
    If Not FileExists($sFilePath) Then
        _LogWarning("Datei existiert nicht: " & $sFilePath)
        Return False
    EndIf
    
    ; Erste paar KB der Datei lesen (für die Erkennung)
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf
    
    Local $sContent = FileRead($hFile, 8192)  ; 8 KB
    FileClose($hFile)
    
    ; Prüfen, ob wenigstens eine Zeile dem DigiApp-Format entspricht
    Local $aMatches = StringRegExp($sContent, $g_sDigiAppLogPattern, $STR_REGEXPARRAYMATCH)
    Local $bIsDigiAppLog = (Not @error And IsArray($aMatches))
    
    If $bIsDigiAppLog Then
        _LogInfo("DigiApp-Log-Format erkannt: " & $sFilePath)
    Else
        _LogInfo("Kein DigiApp-Log-Format erkannt: " & $sFilePath)
    EndIf
    
    Return $bIsDigiAppLog
EndFunc

; Parsiert eine DigiApp-Log-Datei zeilenweise (zuverlässige Methode)
Func _DigiAppParser_ParseLogFile($sFilePath)
    _LogInfo("Parse DigiApp-Log: " & $sFilePath)
    
    ; Prüfen, ob Datei existiert
    If Not FileExists($sFilePath) Then
        _LogError("Datei existiert nicht: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Datei zeilenweise einlesen
    Local $aLines = FileReadToArray($sFilePath)
    If @error Then
        _LogError("Fehler beim Einlesen: " & @error)
        Return SetError(2, 0, 0)
    EndIf
    
    _LogInfo("Gelesene Zeilen: " & UBound($aLines))
    
    ; Logeinträge Array vorbereiten
    Local $aLogEntries[UBound($aLines)][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iValidCount = 0
    
    ; Zeilen verarbeiten
    For $i = 0 To UBound($aLines) - 1
        Local $sLine = $aLines[$i]
        If $sLine = "" Then ContinueLoop
        
        ; RegEx auf Zeile anwenden
        Local $aMatches = StringRegExp($sLine, $g_sDigiAppLogPattern, $STR_REGEXPARRAYMATCH)
        
        If Not @error And IsArray($aMatches) And UBound($aMatches) >= 4 Then
            $aLogEntries[$iValidCount][0] = $aMatches[0]  ; Timestamp
            $aLogEntries[$iValidCount][1] = $aMatches[1]  ; LogLevel
            $aLogEntries[$iValidCount][2] = $aMatches[2]  ; LogClass
            $aLogEntries[$iValidCount][3] = $aMatches[3]  ; Message
            $aLogEntries[$iValidCount][4] = $sLine        ; Original-Zeile
            $iValidCount += 1
        EndIf
    Next
    
    ; Array auf tatsächliche Größe anpassen
    If $iValidCount < UBound($aLogEntries) Then
        ReDim $aLogEntries[$iValidCount][5]
    EndIf
    
    _LogInfo("DigiApp-Logdatei geparst, " & $iValidCount & " Einträge gefunden")
    Return $aLogEntries
EndFunc

; Erweiterte Suche in DigiApp-Logs mit speziellen Filtern
Func _DigiAppParser_SearchLogs($aLogEntries, $sSearchPattern, $bRegex = False, $sLogLevel = "", $sLogClass = "", $sDateFrom = "", $sDateTo = "")
    _LogInfo("Erweiterte Suche in DigiApp-Logs: " & $sSearchPattern)

    Local $aResults[0][5]
    Local $iCount = 0

    For $i = 0 To UBound($aLogEntries) - 1
        ; Prüfe LogLevel-Filter
        If $sLogLevel <> "" And $aLogEntries[$i][1] <> $sLogLevel Then
            ContinueLoop
        EndIf

        ; Prüfe LogClass-Filter
        If $sLogClass <> "" And $aLogEntries[$i][2] <> $sLogClass Then
            ContinueLoop
        EndIf

        ; Prüfe Datum/Zeit-Filter (für DigiApp-Format)
        If $sDateFrom <> "" Or $sDateTo <> "" Then
            Local $sTimestamp = $aLogEntries[$i][0]
            ; Konvertiere ISO-Zeitstempel in vergleichbares Format
            Local $sDatePart = StringLeft($sTimestamp, 10)  ; YYYY-MM-DD
            
            If $sDateFrom <> "" And StringCompare($sDatePart, $sDateFrom) < 0 Then
                ContinueLoop
            EndIf
            
            If $sDateTo <> "" And StringCompare($sDatePart, $sDateTo) > 0 Then
                ContinueLoop
            EndIf
        EndIf

        ; Prüfe Suchpattern
        Local $bMatch = False
        If $sSearchPattern <> "" Then
            If $bRegex Then
                $bMatch = StringRegExp($aLogEntries[$i][3], $sSearchPattern)
            Else
                $bMatch = StringInStr($aLogEntries[$i][3], $sSearchPattern)
            EndIf
            
            If Not $bMatch Then
                ContinueLoop
            EndIf
        Else
            ; Wenn kein Suchtext, aber andere Filter aktiv sind
            $bMatch = True
        EndIf

        ; Alle Filter bestanden, zum Ergebnis hinzufügen
        ReDim $aResults[$iCount + 1][5]
        For $j = 0 To 4
            $aResults[$iCount][$j] = $aLogEntries[$i][$j]
        Next
        $iCount += 1
    Next

    _LogInfo("DigiApp-Suche: " & $iCount & " Einträge gefunden")
    Return $aResults
EndFunc

; Extrahiert eindeutige Log-Klassen aus DigiApp-Logs
Func _DigiAppParser_GetUniqueLogClasses($aLogEntries)
    Local $aClasses[0]
    
    ; Hashtabelle für Eindeutigkeit
    Local $oClasses = ObjCreate("Scripting.Dictionary")
    
    For $i = 0 To UBound($aLogEntries) - 1
        Local $sClass = $aLogEntries[$i][2]
        If $sClass <> "" And Not $oClasses.Exists($sClass) Then
            $oClasses.Add($sClass, 1)
            _ArrayAdd($aClasses, $sClass)
        EndIf
    Next
    
    ; Optional: Sortieren
    _ArraySort($aClasses)
    
    Return $aClasses
EndFunc