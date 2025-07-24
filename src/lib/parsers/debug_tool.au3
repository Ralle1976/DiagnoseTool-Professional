#include-once
#include <File.au3>
#include <MsgBoxConstants.au3>
#include <Array.au3>
#include "../JSON.au3"
#include "../logging.au3"

; Hilfsfunktion um Dateiende zu prüfen (Alternative zu FileEnd)
Func _FileIsEndOfFile($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Funktion zur eingehenden Analyse einer Log-Datei
Func _DebugAnalyzeLogFile($sFilePath)
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        MsgBox($MB_ICONERROR, "Fehler", "Konnte die Datei nicht öffnen: " & $sFilePath)
        Return
    EndIf
    
    ; Erstelle Debug-Ausgabedatei
    Local $sDebugOut = @DesktopDir & "\log_debug_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".txt"
    Local $hDebug = FileOpen($sDebugOut, $FO_OVERWRITE)
    
    FileWriteLine($hDebug, "=== LOG-DATEI DEBUG ANALYSE ===")
    FileWriteLine($hDebug, "Datei: " & $sFilePath)
    FileWriteLine($hDebug, "Datum: " & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC)
    FileWriteLine($hDebug, "===========================")
    
    ; Lese und analysiere die ersten 20 Zeilen
    Local $iLineCount = 0
    While Not _FileIsEndOfFile($hFile) And $iLineCount < 20
        Local $sLine = FileReadLine($hFile)
        $iLineCount += 1
        
        FileWriteLine($hDebug, "")
        FileWriteLine($hDebug, "=== ZEILE " & $iLineCount & " ===")
        FileWriteLine($hDebug, "Inhalt: " & $sLine)
        
        ; Prüfen, ob es sich um eine JSON-Zeile handeln könnte
        If StringRegExp($sLine, "^\s*{.*}\s*$") Then
            FileWriteLine($hDebug, "Format: Mögliches JSON-Format (beginnt mit { und endet mit })")
            
            ; Versuche JSON zu parsen
            Local $jObject = Json_Decode($sLine)
            If @error Then
                FileWriteLine($hDebug, "JSON-Parse: FEHLER " & @error)
                FileWriteLine($hDebug, "Grund: Konnte nicht als JSON geparst werden")
            Else
                FileWriteLine($hDebug, "JSON-Parse: ERFOLG")
                
                ; Alle Schlüssel im JSON-Objekt auflisten
                Local $aKeys = Json_ObjGetKeys($jObject)
                If IsArray($aKeys) Then
                    FileWriteLine($hDebug, "Gefundene Schlüssel: " & _ArrayToString($aKeys, ", "))
                    
                    ; Nach bekannten Schlüsseln suchen
                    Local $bHasTimestamp = False
                    Local $bHasLogLevel = False
                    Local $bHasMessage = False
                    
                    ; Durchlaufe alle bekannten Timestamp-Schlüsselnamen
                    Local $aTimestampKeys = ["Timestamp", "timestamp", "time", "@timestamp", "date", "ts", "DateTime"]
                    For $i = 0 To UBound($aTimestampKeys) - 1
                        If _ArraySearch($aKeys, $aTimestampKeys[$i]) >= 0 Then
                            $bHasTimestamp = True
                            FileWriteLine($hDebug, "Timestamp-Schlüssel gefunden: " & $aTimestampKeys[$i])
                            FileWriteLine($hDebug, "Wert: " & Json_Get($jObject, "." & $aTimestampKeys[$i]))
                            ExitLoop
                        EndIf
                    Next
                    
                    ; Durchlaufe alle bekannten LogLevel-Schlüsselnamen
                    Local $aLogLevelKeys = ["LogLevel", "level", "severity", "log_level", "loglevel", "Level", "type", "Type"]
                    For $i = 0 To UBound($aLogLevelKeys) - 1
                        If _ArraySearch($aKeys, $aLogLevelKeys[$i]) >= 0 Then
                            $bHasLogLevel = True
                            FileWriteLine($hDebug, "LogLevel-Schlüssel gefunden: " & $aLogLevelKeys[$i])
                            FileWriteLine($hDebug, "Wert: " & Json_Get($jObject, "." & $aLogLevelKeys[$i]))
                            ExitLoop
                        EndIf
                    Next
                    
                    ; Durchlaufe alle bekannten Message-Schlüsselnamen
                    Local $aMessageKeys = ["Message", "message", "msg", "content", "text", "description", "desc"]
                    For $i = 0 To UBound($aMessageKeys) - 1
                        If _ArraySearch($aKeys, $aMessageKeys[$i]) >= 0 Then
                            $bHasMessage = True
                            FileWriteLine($hDebug, "Message-Schlüssel gefunden: " & $aMessageKeys[$i])
                            FileWriteLine($hDebug, "Wert: " & Json_Get($jObject, "." & $aMessageKeys[$i]))
                            ExitLoop
                        EndIf
                    Next
                    
                    ; Fazit
                    If $bHasTimestamp And $bHasLogLevel Then
                        FileWriteLine($hDebug, "ANALYSE: Diese Zeile erfüllt die Kriterien für ein JSON-Log-Format")
                    ElseIf $bHasTimestamp Or $bHasLogLevel Or $bHasMessage Then
                        FileWriteLine($hDebug, "ANALYSE: Diese Zeile erfüllt teilweise die Kriterien für ein JSON-Log-Format")
                    Else
                        FileWriteLine($hDebug, "ANALYSE: Diese Zeile hat JSON-Format, enthält aber keine typischen Log-Schlüssel")
                    EndIf
                Else
                    FileWriteLine($hDebug, "Konnte keine Schlüssel im JSON-Objekt finden")
                EndIf
            EndIf
        Else
            FileWriteLine($hDebug, "Format: Kein JSON-Format erkannt (keine geschweifte Klammern)")
            
            ; Prüfe auf bekannte Textlog-Formate
            If StringRegExp($sLine, "^\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(?:,\d{3})?)\]\s+(\w+)\s*:") Then
                FileWriteLine($hDebug, "ANALYSE: Mögliches Standard-Textlog-Format")
            ElseIf StringRegExp($sLine, "^(\w+)\s+\[(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2})\]") Then
                FileWriteLine($hDebug, "ANALYSE: Mögliches Windows-Event-Log-Format")
            ElseIf StringRegExp($sLine, "^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}):\s+") Then
                FileWriteLine($hDebug, "ANALYSE: Mögliches einfaches Textlog-Format")
            Else
                FileWriteLine($hDebug, "ANALYSE: Kein bekanntes Log-Format erkannt")
            EndIf
        EndIf
    WEnd
    
    FileClose($hFile)
    
    ; Dateiinformationen
    Local $iFileSize = FileGetSize($sFilePath)
    FileWriteLine($hDebug, "")
    FileWriteLine($hDebug, "=== DATEI-INFORMATIONEN ===")
    FileWriteLine($hDebug, "Dateigröße: " & $iFileSize & " Bytes (" & Round($iFileSize / 1024, 2) & " KB)")
    FileWriteLine($hDebug, "Anzahl analysierter Zeilen: " & $iLineCount)
    
    FileClose($hDebug)
    
    ; Öffne die Debug-Datei
    ShellExecute($sDebugOut)
    
    Return $sDebugOut
EndFunc