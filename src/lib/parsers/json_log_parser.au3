#include-once
#include <File.au3>
#include <Array.au3>
#include "../JSON.au3"
#include "../logging.au3"
#include "../file_utils.au3"

; Konfigurierbare Schlüssel-Felder für JSON-Logs
Global $g_aJsonTimestampKeys = ["Timestamp", "timestamp", "time", "@timestamp", "date"] ; Mögliche Timestamp-Schlüssel
Global $g_aJsonLogLevelKeys = ["LogLevel", "level", "severity", "log_level"] ; Mögliche LogLevel-Schlüssel
Global $g_aJsonLogClassKeys = ["LogClass", "class", "module", "logger", "source"] ; Mögliche LogClass-Schlüssel
Global $g_aJsonMessageKeys = ["Message", "message", "msg", "content", "text"] ; Mögliche Message-Schlüssel

; Gefundene Schlüssel für die aktuelle Logdatei
Global $g_sJsonTimestampKey = ""
Global $g_sJsonLogLevelKey = ""
Global $g_sJsonLogClassKey = ""
Global $g_sJsonMessageKey = ""

; Prüft, ob eine Datei ein JSON-Logfile ist
Func _JsonParser_IsJsonLogFile($sFilePath)
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then 
        _LogWarning("Datei konnte nicht geöffnet werden: " & $sFilePath)
        Return False
    EndIf
    
    ; Teste die ersten paar Zeilen auf JSON-Struktur
    Local $bIsJsonLog = False
    Local $iLineCount = 0
    Local $sLine = ""
    
    ; Wir speichern die gefundenen Schlüssel für später
    Local $sFoundTimestampKey = ""
    Local $sFoundLogLevelKey = ""
    Local $sFoundLogClassKey = ""
    Local $sFoundMessageKey = ""
    
    While $iLineCount < 10 And Not _FileIsEndOfFile($hFile)
        $sLine = FileReadLine($hFile)
        $iLineCount += 1
        
        If $sLine = "" Then ContinueLoop
        
        ; Debug-Info ausgeben
        _LogDebug("Analysiere Zeile " & $iLineCount & ": " & StringLeft($sLine, 100) & "...")
        
        ; Prüfen, ob es sich um eine JSON-Zeile handelt
        If Not StringRegExp($sLine, "^\s*{.*}\s*$") Then ContinueLoop
        
        ; Versuche, die Zeile als JSON zu parsen
        Local $jObject = Json_Decode($sLine)
        If @error Then 
            _LogDebug("Zeile konnte nicht als JSON geparst werden: " & @error)
            ContinueLoop
        EndIf
        
        If Not Json_IsObject($jObject) Then
            _LogDebug("Geparste Zeile ist kein JSON-Objekt")
            ContinueLoop
        EndIf
        
        ; Alle Schlüssel aus dem JSON-Objekt extrahieren
        Local $aKeys = Json_ObjGetKeys($jObject)
        If Not IsArray($aKeys) Then
            _LogDebug("Keine Schlüssel im JSON-Objekt gefunden")
            ContinueLoop
        EndIf
        
        _LogDebug("JSON-Schlüssel gefunden: " & _ArrayToString($aKeys, ", "))
        
        ; Prüfen auf Timestamp-Schlüssel
        For $i = 0 To UBound($g_aJsonTimestampKeys) - 1
            If _ArraySearch($aKeys, $g_aJsonTimestampKeys[$i]) >= 0 Then
                $sFoundTimestampKey = $g_aJsonTimestampKeys[$i]
                _LogDebug("Timestamp-Schlüssel gefunden: " & $sFoundTimestampKey)
                ExitLoop
            EndIf
        Next
        
        ; Prüfen auf LogLevel-Schlüssel
        For $i = 0 To UBound($g_aJsonLogLevelKeys) - 1
            If _ArraySearch($aKeys, $g_aJsonLogLevelKeys[$i]) >= 0 Then
                $sFoundLogLevelKey = $g_aJsonLogLevelKeys[$i]
                _LogDebug("LogLevel-Schlüssel gefunden: " & $sFoundLogLevelKey)
                ExitLoop
            EndIf
        Next
        
        ; Prüfen auf LogClass-Schlüssel (optional)
        For $i = 0 To UBound($g_aJsonLogClassKeys) - 1
            If _ArraySearch($aKeys, $g_aJsonLogClassKeys[$i]) >= 0 Then
                $sFoundLogClassKey = $g_aJsonLogClassKeys[$i]
                _LogDebug("LogClass-Schlüssel gefunden: " & $sFoundLogClassKey)
                ExitLoop
            EndIf
        Next
        
        ; Prüfen auf Message-Schlüssel
        For $i = 0 To UBound($g_aJsonMessageKeys) - 1
            If _ArraySearch($aKeys, $g_aJsonMessageKeys[$i]) >= 0 Then
                $sFoundMessageKey = $g_aJsonMessageKeys[$i]
                _LogDebug("Message-Schlüssel gefunden: " & $sFoundMessageKey)
                ExitLoop
            EndIf
        Next
        
        ; Wenn wir mindestens einen Timestamp ODER einen LogLevel haben, ist es ein gültiges JSON-Log
        If $sFoundTimestampKey <> "" Or $sFoundLogLevelKey <> "" Then
            _LogInfo("JSON-Log erkannt mit Format: " & $sFoundTimestampKey & "/" & $sFoundLogLevelKey & "/" & $sFoundMessageKey)
            
            ; Schlüssel in globalen Variablen für später speichern
            $g_sJsonTimestampKey = $sFoundTimestampKey
            $g_sJsonLogLevelKey = $sFoundLogLevelKey
            $g_sJsonLogClassKey = $sFoundLogClassKey
            $g_sJsonMessageKey = $sFoundMessageKey
            
            $bIsJsonLog = True
            ExitLoop
        EndIf
    WEnd
    
    FileClose($hFile)
    
    If Not $bIsJsonLog Then
        _LogWarning("Datei wurde nicht als JSON-Log erkannt")
    EndIf
    
    Return $bIsJsonLog
EndFunc

; Parsed eine JSON-Logdatei in ein Array
Func _JsonParser_ParseLogFile($sFilePath)
    _LogInfo("Parse JSON-Logdatei: " & $sFilePath)
    
    ; Datei einlesen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Konnte Logdatei nicht öffnen: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf
    
    ; Logeinträge parsen
    Local $aLogEntries[0][5]  ; [Index][Timestamp, LogLevel, LogClass, Message, RawJson]
    Local $iCount = 0
    
    While Not _FileIsEndOfFile($hFile)
        Local $sLine = FileReadLine($hFile)
        If $sLine = "" Then ContinueLoop
        
        ; JSON parsen
        Local $jObject = Json_Decode($sLine)
        If @error Then ContinueLoop
        
        ; Verwende die erkannten Schlüssel aus _IsJsonLogFile()
        Local $sTimestamp = ""
        If $g_sJsonTimestampKey <> "" Then
            $sTimestamp = Json_Get($jObject, "." & $g_sJsonTimestampKey)
        EndIf
        
        Local $sLogLevel = ""
        If $g_sJsonLogLevelKey <> "" Then
            $sLogLevel = Json_Get($jObject, "." & $g_sJsonLogLevelKey)
        EndIf
        
        ; LogClass ist optional
        Local $sLogClass = ""
        If $g_sJsonLogClassKey <> "" Then
            $sLogClass = Json_Get($jObject, "." & $g_sJsonLogClassKey)
        EndIf
        
        Local $sMessage = ""
        If $g_sJsonMessageKey <> "" Then
            $sMessage = Json_Get($jObject, "." & $g_sJsonMessageKey)
        EndIf
        
        ; Wenn keine Nachricht direkt gefunden wurde, dann ganze JSON-Struktur anzeigen
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