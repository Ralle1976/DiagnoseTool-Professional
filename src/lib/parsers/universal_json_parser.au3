#include-once
#include <File.au3>
#include <Array.au3>
#include "../JSON.au3"
#include "../logging.au3"

; Hilfsfunktion um Dateiende zu prüfen (Alternative zu FileEnd)
Func __FileIsEndOfFile($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Globale Variablen für erkannte Schlüssel
Global $g_sJsonTimestampKey = ""
Global $g_sJsonLogLevelKey = ""
Global $g_sJsonMessageKey = ""

; Universeller JSON-Parser - erkennt jedes gültige JSON-Format
Func _UniversalJson_IsJsonLogFile($sFilePath)
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf

    ; Teste die ersten paar Zeilen auf JSON-Struktur
    Local $bIsJsonLog = False
    Local $iLineCount = 0
    Local $sLine = ""

    While Not __FileIsEndOfFile($hFile) And $iLineCount < 20
        $sLine = FileReadLine($hFile)
        $iLineCount += 1

        If $sLine = "" Then ContinueLoop

        _LogDebug("Prüfe Zeile " & $iLineCount & ": " & StringLeft($sLine, 50) & "...")

        ; Versuche zu erkennen, ob es sich um JSON handelt
        If Not StringRegExp($sLine, "^\s*{.*}\s*$") Then
            _LogDebug("Keine JSON-Klammern gefunden")
            ContinueLoop
        EndIf

        ; Versuche, die Zeile als JSON zu parsen
        Local $jObject = Json_Decode($sLine)
        If @error Then
            _LogDebug("JSON-Parsing fehlgeschlagen: " & @error)
            ContinueLoop
        EndIf

        _LogDebug("JSON erfolgreich geparst")

        ; Wenn wir hier sind, handelt es sich um gültiges JSON
        $bIsJsonLog = True

        ; Versuche, wichtige Schlüssel zu identifizieren
        Local $aKeys = Json_ObjGetKeys($jObject)
        If Not IsArray($aKeys) Then
            _LogDebug("Keine Schlüssel im JSON-Objekt gefunden")
            ExitLoop
        EndIf

        _LogDebug("JSON-Schlüssel: " & _ArrayToString($aKeys, ", "))

        ; Versuche Zeitstempel zu finden
        For $i = 0 To UBound($aKeys) - 1
            Local $key = $aKeys[$i]
            Local $sValue = Json_Get($jObject, "." & $key)

            ; Suche nach zeitähnlichen Schlüsseln oder Werten
            If StringInStr($key, "time", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "date", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "ts", $STR_NOCASESENSEBASIC) Then
                $g_sJsonTimestampKey = $key
                _LogDebug("Timestamp-Schlüssel gefunden: " & $key)
            EndIf

            ; Suche nach level-ähnlichen Schlüsseln
            If StringInStr($key, "level", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "severity", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "type", $STR_NOCASESENSEBASIC) Then
                $g_sJsonLogLevelKey = $key
                _LogDebug("LogLevel-Schlüssel gefunden: " & $key)
            ; Oder versuche, Werte zu finden, die typische Log-Levels enthalten
            ElseIf IsString($sValue) And StringRegExp($sValue, "(?i)(INFO|ERROR|WARN|DEBUG)") Then
                $g_sJsonLogLevelKey = $key
                _LogDebug("LogLevel-Schlüssel durch Wert erkannt: " & $key)
            EndIf

            ; Suche nach message-ähnlichen Schlüsseln
            If StringInStr($key, "message", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "msg", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "text", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "content", $STR_NOCASESENSEBASIC) Or _
               StringInStr($key, "desc", $STR_NOCASESENSEBASIC) Then
                $g_sJsonMessageKey = $key
                _LogDebug("Message-Schlüssel gefunden: " & $key)
            EndIf
        Next

        ExitLoop
    WEnd

    FileClose($hFile)

    ; Wenn es JSON ist aber keine Schlüssel gefunden wurden, nehmen wir die ersten Schlüssel
    If $bIsJsonLog And $g_sJsonTimestampKey = "" And $g_sJsonLogLevelKey = "" And $g_sJsonMessageKey = "" Then
        _LogInfo("JSON-Format erkannt, aber keine typischen Log-Schlüssel gefunden. Verwende allgemeines Format.")

        ; Öffne Datei erneut und lese eine Zeile
        $hFile = FileOpen($sFilePath, $FO_READ)
        If $hFile <> -1 Then
            $sLine = FileReadLine($hFile)
            FileClose($hFile)

            ; Parse JSON
            Local $jObject = Json_Decode($sLine)
            If Not @error Then
                Local $aKeys = Json_ObjGetKeys($jObject)
                If IsArray($aKeys) And UBound($aKeys) > 0 Then
                    ; Verwende die ersten drei Schlüssel als Standard
                    If UBound($aKeys) >= 1 Then
                        $g_sJsonTimestampKey = $aKeys[0]
                        _LogDebug("Verwende ersten Schlüssel als Timestamp: " & $aKeys[0])
                    EndIf
                    If UBound($aKeys) >= 2 Then
                        $g_sJsonLogLevelKey = $aKeys[1]
                        _LogDebug("Verwende zweiten Schlüssel als LogLevel: " & $aKeys[1])
                    EndIf
                    If UBound($aKeys) >= 3 Then
                        $g_sJsonMessageKey = $aKeys[2]
                        _LogDebug("Verwende dritten Schlüssel als Message: " & $aKeys[2])
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf

    If $bIsJsonLog Then
        _LogInfo("JSON-Log erkannt mit Schlüsseln: " & $g_sJsonTimestampKey & ", " & $g_sJsonLogLevelKey & ", " & $g_sJsonMessageKey)
    Else
        _LogWarning("Datei wurde nicht als JSON-Log erkannt")
    EndIf

    Return $bIsJsonLog
EndFunc

; Parsed eine JSON-Logdatei mit dem universellen Parser
Func _UniversalJson_ParseLogFile($sFilePath)
    _LogInfo("Parse JSON-Logdatei (universell): " & $sFilePath)

    ; Prüfe, ob die Schlüssel bekannt sind
    If $g_sJsonTimestampKey = "" And $g_sJsonLogLevelKey = "" And $g_sJsonMessageKey = "" Then
        ; Wenn nicht, führe erneut IsJsonLogFile aus
        If Not _UniversalJson_IsJsonLogFile($sFilePath) Then
            _LogError("Datei ist kein JSON-Log oder Format nicht erkannt")
            Return SetError(1, 0, 0)
        EndIf
    EndIf

    ; Datei einlesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(2, 0, 0)
    EndIf

    ; Logeinträge parsen
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawJson]
    Local $iCount = 0

    While Not __FileIsEndOfFile($hFile)
        Local $sLine = FileReadLine($hFile)
        If $sLine = "" Then ContinueLoop

        ; Prüfe, ob die Zeile ein JSON ist
        If Not StringRegExp($sLine, "^\s*{.*}\s*$") Then ContinueLoop

        ; JSON parsen
        Local $jObject = Json_Decode($sLine)
        If @error Then ContinueLoop

        ; Werte extrahieren
        Local $sTimestamp = ""
        If $g_sJsonTimestampKey <> "" Then
            $sTimestamp = Json_Get($jObject, "." & $g_sJsonTimestampKey)
        EndIf

        Local $sLogLevel = ""
        If $g_sJsonLogLevelKey <> "" Then
            $sLogLevel = Json_Get($jObject, "." & $g_sJsonLogLevelKey)
        EndIf

        ; LogClass ist der Schlüsselname des dritten Felds
        Local $sLogClass = ""

        Local $sMessage = ""
        If $g_sJsonMessageKey <> "" Then
            $sMessage = Json_Get($jObject, "." & $g_sJsonMessageKey)
        EndIf

        ; Wenn keine Nachricht gefunden wurde, verwende die gesamte JSON-Zeile
        If $sMessage = "" Then
            $sMessage = $sLine
        EndIf

        ; Zum Array hinzufügen
        ReDim $aLogEntries[$iCount + 1][5]
        $aLogEntries[$iCount][0] = $sTimestamp
        $aLogEntries[$iCount][1] = $sLogLevel
        $aLogEntries[$iCount][2] = $sLogClass
        $aLogEntries[$iCount][3] = $sMessage
        $aLogEntries[$iCount][4] = $sLine  ; Original-JSON für erweiterte Ansicht

        $iCount += 1
    WEnd

    FileClose($hFile)
    _LogInfo("Logdatei geparst, " & $iCount & " Einträge gefunden")

    Return $aLogEntries
EndFunc