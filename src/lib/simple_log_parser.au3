#include-once
#include <File.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include "logging.au3"

; Einfacher JSON-Log-Parser, der speziell auf das Format von DigiApp-Log-Dateien abgestimmt ist
; Beispiel: {"Timestamp":"2025-02-17T01:04:05+01:00","LogLevel":"Info","LogClass":"VM","Message":"Text"}


; Hilfsfunktion um Dateiende zu prüfen (Alternative zu FileEnd)
Func FileAtEnd($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc


; Prüft, ob es sich um eine DigiApp-Logdatei handelt (einfache, schnelle Erkennung)
Func _IsDigiAppLogFile($sFilePath)
    _LogInfo("Prüfe, ob " & $sFilePath & " eine DigiApp-Logdatei ist...")

    ; Existiert die Datei?
    If Not FileExists($sFilePath) Then
        _LogError("Datei existiert nicht: " & $sFilePath)
        Return False
    EndIf

    ; Versuche die Datei zu öffnen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf

    ; Muster für DigiApp-Log-Format
    ; Wir suchen nach einem JSON-Objekt mit genau diesen Schlüsseln:
    ; Timestamp, LogLevel, LogClass und Message
    Local $sPattern = '{"Timestamp":"[^"]+","LogLevel":"[^"]+","LogClass":"[^"]+","Message":'

    ; Prüfe die ersten 3 Zeilen
    Local $bIsDigiAppLog = False
    Local $iLineCount = 0
    Local $iMatchCount = 0
    Local $sLine

    While Not FileAtEnd($hFile) And $iLineCount < 10
        $sLine = FileReadLine($hFile)
        $iLineCount += 1

        If StringRegExp($sLine, $sPattern) Then
            $iMatchCount += 1
            _LogDebug("Zeile " & $iLineCount & " entspricht dem DigiApp-Log-Format")
        EndIf
    WEnd

    FileClose($hFile)

    ; Wenn mindestens 2 Zeilen dem Format entsprechen, ist es höchstwahrscheinlich eine DigiApp-Log-Datei
    $bIsDigiAppLog = ($iMatchCount >= 2)

    If $bIsDigiAppLog Then
        _LogInfo("DigiApp-Log-Format erkannt!")
    Else
        _LogWarning("Kein DigiApp-Log-Format erkannt. Nur " & $iMatchCount & " von " & $iLineCount & " Zeilen entsprechen dem Format.")
    EndIf

    Return $bIsDigiAppLog
EndFunc

; Parst eine DigiApp-Logdatei und gibt ein Array mit den Einträgen zurück
; [Timestamp, LogLevel, LogClass, Message, Original-Zeile]
Func _ParseDigiAppLogFile($sFilePath)
    If Not _IsDigiAppLogFile($sFilePath) Then
        _LogWarning("Datei ist keine DigiApp-Logdatei: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf

    _LogInfo("Parse DigiApp-Logdatei: " & $sFilePath)

    ; Datei erneut öffnen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(2, 0, 0)
    EndIf

    ; Einträge parsen
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawLine]
    Local $iCount = 0

    While Not FileAtEnd($hFile)
        Local $sLine = FileReadLine($hFile)

        ; Leerzeilen überspringen
        If $sLine = "" Then ContinueLoop

        ; JSON mit RegEx parsen - schneller und zuverlässiger als JSON-Bibliothek
        Local $aMatches = StringRegExp($sLine, '{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"(.*?)"}', $STR_REGEXPARRAYMATCH)
        If @error Then
            ; Alternative Regex, falls die Message Anführungszeichen enthält
            $aMatches = StringRegExp($sLine, '{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":(.*)}', $STR_REGEXPARRAYMATCH)
            If @error Then ContinueLoop
        EndIf

        ; Werte extrahieren
        Local $sTimestamp = $aMatches[0]
        Local $sLogLevel = $aMatches[1]
        Local $sLogClass = $aMatches[2]
        Local $sMessage = $aMatches[3]

        ; Wenn die Message in Anführungszeichen ist, entferne diese
        If StringLeft($sMessage, 1) = '"' And StringRight($sMessage, 1) = '"' Then
            $sMessage = StringTrimLeft(StringTrimRight($sMessage, 1), 1)
            ; Escaped Anführungszeichen entfernen
            $sMessage = StringReplace($sMessage, '\"', '"')
        EndIf

        ; Zum Array hinzufügen
        ReDim $aLogEntries[$iCount + 1][5]
        $aLogEntries[$iCount][0] = $sTimestamp
        $aLogEntries[$iCount][1] = $sLogLevel
        $aLogEntries[$iCount][2] = $sLogClass
        $aLogEntries[$iCount][3] = $sMessage
        $aLogEntries[$iCount][4] = $sLine  ; Original-Zeile für erweiterte Ansicht

        $iCount += 1
    WEnd

    FileClose($hFile)

    _LogInfo("DigiApp-Logdatei erfolgreich geparst, " & $iCount & " Einträge gefunden")
    Return $aLogEntries
EndFunc