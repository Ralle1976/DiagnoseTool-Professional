#include-once
#include <File.au3>
#include <Array.au3>
#include "../logging.au3"

; Hilfsfunktion um Dateiende zu prüfen (Alternative zu FileEnd)
Func ___FileIsEndOfFile($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Bekannte Muster für Textlog-Dateien
Global $g_aTextLogPatterns[3][3] = [ _
    ["Standard", "^\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(?:,\d{3})?)\]\s+(\w+)\s*:\s*(.*)$", 3], _
    ["Windows", "^(\w+)\s+\[(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2})\]\s+(.*)$", 3], _
    ["Simple", "^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}):\s+(.*)$", 2] _
]

; Ausgewähltes Pattern für die aktuelle Log-Datei
Global $g_iSelectedPattern = -1

; Prüft, ob eine Datei als Text-Logfile erkannt werden kann
Func _TextParser_IsTextLogFile($sFilePath)
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf

    ; Teste die ersten paar Zeilen auf bekannte Log-Muster
    Local $bIsTextLog = False
    Local $iLineCount = 0
    Local $sLine = ""

    While Not ___FileIsEndOfFile($hFile) And $iLineCount < 5
        $sLine = FileReadLine($hFile)
        $iLineCount += 1

        If $sLine = "" Then ContinueLoop

        ; Prüfe alle bekannten Muster
        For $i = 0 To UBound($g_aTextLogPatterns) - 1
            If StringRegExp($sLine, $g_aTextLogPatterns[$i][1]) Then
                _LogInfo("Textlog-Format erkannt: " & $g_aTextLogPatterns[$i][0])
                $g_iSelectedPattern = $i
                $bIsTextLog = True
                ExitLoop 2
            EndIf
        Next
    WEnd

    FileClose($hFile)

    If Not $bIsTextLog Then
        _LogWarning("Datei wurde nicht als Text-Log erkannt")
    EndIf

    Return $bIsTextLog
EndFunc

; Parsed eine Text-Logdatei in ein Array
Func _TextParser_ParseLogFile($sFilePath)
    _LogInfo("Parse Text-Logdatei: " & $sFilePath)

    ; Wenn kein Pattern erkannt wurde, abbrechen
    If $g_iSelectedPattern = -1 Then
        _LogError("Kein Text-Log-Pattern erkannt")
        Return SetError(1, 0, 0)
    EndIf

    ; Datei einlesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(2, 0, 0)
    EndIf

    ; Logeinträge parsen
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iCount = 0
    Local $sPattern = $g_aTextLogPatterns[$g_iSelectedPattern][1]
    Local $iGroups = $g_aTextLogPatterns[$g_iSelectedPattern][2]

    While Not ___FileIsEndOfFile($hFile)
        Local $sLine = FileReadLine($hFile)
        If $sLine = "" Then ContinueLoop

        ; Zeile mit RegEx parsen
        Local $aMatches = StringRegExp($sLine, $sPattern, 3)
        If Not @error And UBound($aMatches) = $iGroups Then
            ; Werte zuordnen
            Local $sTimestamp = $aMatches[0]
            Local $sLogLevel = ""
            Local $sMessage = ""

            ; Je nach Pattern die Felder anders interpretieren
            Switch $g_iSelectedPattern
                Case 0 ; Standard
                    $sLogLevel = $aMatches[1]
                    $sMessage = $aMatches[2]
                Case 1 ; Windows
                    $sLogLevel = $aMatches[0]
                    $sTimestamp = $aMatches[1]
                    $sMessage = $aMatches[2]
                Case 2 ; Simple
                    $sMessage = $aMatches[1]
            EndSwitch

            ; Zum Array hinzufügen
            ReDim $aLogEntries[$iCount + 1][5]
            $aLogEntries[$iCount][0] = $sTimestamp
            $aLogEntries[$iCount][1] = $sLogLevel
            $aLogEntries[$iCount][2] = "" ; Keine LogClass bei Text-Logs
            $aLogEntries[$iCount][3] = $sMessage
            $aLogEntries[$iCount][4] = $sLine  ; Original-Zeile für erweiterte Ansicht

            $iCount += 1
        EndIf
    WEnd

    FileClose($hFile)
    _LogInfo("Logdatei geparst, " & $iCount & " Einträge gefunden")

    Return $aLogEntries
EndFunc