#cs
JSON Test-Hilfsfunktionen
Diese Datei bietet Funktionen zum Testen der JSON-Parser und der Erkennung unvollständiger JSON-Einträge
#ce

#include-once
#include "logging.au3"
#include "JSON.au3"
#include "log_analysis_utils.au3"
#include "parsers\parser_manager_enhanced.au3"

; Erzeugt eine Testdatei mit vollständigen und unvollständigen JSON-Einträgen
Func _CreateJsonTestFile($sFilePath, $bIncludeIncomplete = True)
    _LogInfo("Erstelle JSON-Testdatei: " & $sFilePath)
    
    ; Einige Beispiel-JSON-Objekte
    Local $aJsonExamples[5][4]  ; [timestamp, level, class, message]
    $aJsonExamples[0][0] = "2024-09-25T22:30:31.321198+08:00"
    $aJsonExamples[0][1] = "Debug"
    $aJsonExamples[0][2] = "InfoViewModel"
    $aJsonExamples[0][3] = "SendeLogfiles: Schreibe ZIP"
    
    $aJsonExamples[1][0] = "2024-09-25T22:30:32.432987+08:00"
    $aJsonExamples[1][1] = "Info"
    $aJsonExamples[1][2] = "MainController"
    $aJsonExamples[1][3] = "Anwendung gestartet"
    
    $aJsonExamples[2][0] = "2024-09-25T22:31:15.176543+08:00"
    $aJsonExamples[2][1] = "Warning"
    $aJsonExamples[2][2] = "NetworkService"
    $aJsonExamples[2][3] = "Verbindung langsam: 2342ms Antwortzeit"
    
    $aJsonExamples[3][0] = "2024-09-25T22:32:01.887766+08:00"
    $aJsonExamples[3][1] = "Error"
    $aJsonExamples[3][2] = "DataAccess"
    $aJsonExamples[3][3] = "Datenbankfehler: Timeout bei Abfrage"
    
    $aJsonExamples[4][0] = "2024-09-25T22:33:45.112233+08:00"
    $aJsonExamples[4][1] = "Fatal"
    $aJsonExamples[4][2] = "ApplicationCore"
    $aJsonExamples[4][3] = "Unbehandelte Ausnahme im Hauptthread"
    
    ; Datei zum Schreiben öffnen
    Local $hFile = FileOpen($sFilePath, $FO_OVERWRITE)
    If $hFile = -1 Then
        _LogError("Fehler beim Erstellen der Testdatei: " & $sFilePath)
        Return SetError(1, 0, False)
    EndIf
    
    ; Vollständige JSON-Objekte schreiben
    For $i = 0 To UBound($aJsonExamples) - 1
        Local $sJson = '{"Timestamp":"' & $aJsonExamples[$i][0] & '",' & _
                      '"LogLevel":"' & $aJsonExamples[$i][1] & '",' & _
                      '"LogClass":"' & $aJsonExamples[$i][2] & '",' & _
                      '"Message":"' & $aJsonExamples[$i][3] & '"}'
        FileWriteLine($hFile, $sJson)
    Next
    
    ; Unvollständige JSON-Objekte hinzufügen
    If $bIncludeIncomplete Then
        ; Unvollständig nach Timestamp (fehlendes schließendes ")
        FileWriteLine($hFile, '{"Timestamp":"2024-09-25T22:35:10.445566+08:00')
        
        ; Unvollständig nach LogLevel
        FileWriteLine($hFile, '{"Timestamp":"2024-09-25T22:36:20.778899+08:00","LogLevel":"Debug"')
        
        ; Unvollständig nach LogClass
        FileWriteLine($hFile, '{"Timestamp":"2024-09-25T22:37:30.112233+08:00","LogLevel":"Info","LogClass":"ConfigHandler"')
        
        ; Unvollständig nach Message-Beginn
        FileWriteLine($hFile, '{"Timestamp":"2024-09-25T22:38:40.445566+08:00","LogLevel":"Warning","LogClass":"FileSystem","Message":"Datei nicht gefunden')
        
        ; Mit Nachricht, aber unvollständig
        FileWriteLine($hFile, '{"Timestamp":"2024-09-25T22:39:50.667788+08:00","LogLevel":"Error","LogClass":"DatabaseService","Message":"Verbindungsfehler zur Datenbank mit Fehlermeldung: Timeout bei der Verbindung zum SQL-Server')
        
        ; Weiteres Beispiel mit speziellem Zeichen am Ende
        FileWriteLine($hFile, '{"Timestamp":"2024-09-25T22:40:10.123456+08:00","LogLevel":"Debug","LogClass":"Log"')
    EndIf
    
    FileClose($hFile)
    _LogInfo("Testdatei erfolgreich erstellt: " & $sFilePath)
    Return True
EndFunc

; Testet den JSON-Parser mit einer gegebenen Datei
Func _TestJsonParser($sFilePath)
    _LogInfo("Teste JSON-Parser mit Datei: " & $sFilePath)
    
    ; Prüfen, ob die Datei existiert
    If Not FileExists($sFilePath) Then
        _LogError("Testdatei nicht gefunden: " & $sFilePath)
        Return SetError(1, 0, False)
    EndIf
    
    ; Format erkennen
    Local $iFormat = ParserManager_DetectLogFormat($sFilePath)
    _LogInfo("Erkanntes Format: " & ParserManager_GetFormatName($iFormat))
    
    ; Auf unvollständige Einträge prüfen
    Local $bHasIncomplete = ParserManager_TestIncompleteJson($sFilePath)
    _LogInfo("Unvollständige Einträge gefunden: " & ($bHasIncomplete ? "Ja" : "Nein"))
    
    ; Datei parsen
    Local $aLogEntries = ParserManager_ParseLogFile($sFilePath)
    If @error Then
        _LogError("Fehler beim Parsen der Datei: " & @error)
        Return SetError(2, 0, False)
    EndIf
    
    ; Anzahl der gefundenen Einträge
    Local $iEntryCount = UBound($aLogEntries)
    _LogInfo("Gefundene Log-Einträge: " & $iEntryCount)
    
    ; Ausgabe der Einträge zur Kontrolle
    For $i = 0 To $iEntryCount - 1
        _LogInfo("Eintrag " & ($i + 1) & ":")
        _LogInfo("  Timestamp: " & $aLogEntries[$i][0])
        _LogInfo("  LogLevel:  " & $aLogEntries[$i][1])
        _LogInfo("  LogClass:  " & $aLogEntries[$i][2])
        _LogInfo("  Message:   " & $aLogEntries[$i][3])
        _LogInfo("  Raw:       " & StringLeft($aLogEntries[$i][4], 100) & (StringLen($aLogEntries[$i][4]) > 100 ? "..." : ""))
        _LogInfo("")
    Next
    
    ; Vollständige und unvollständige Einträge zählen
    Local $iCompleteCount = 0
    Local $iIncompleteCount = 0
    
    For $i = 0 To $iEntryCount - 1
        If StringInStr($aLogEntries[$i][1], "TRUNCATED") Or StringInStr($aLogEntries[$i][1], "BESCHÄDIGT") Then
            $iIncompleteCount += 1
        Else
            $iCompleteCount += 1
        EndIf
    Next
    
    _LogInfo("Vollständige Einträge: " & $iCompleteCount)
    _LogInfo("Unvollständige Einträge: " & $iIncompleteCount)
    
    Return True
EndFunc

; Hauptfunktion zum Testen der JSON-Parser
Func _RunJsonParserTest()
    _LogInfo("Starte JSON-Parser-Test")
    
    ; Testdatei erstellen
    Local $sTestFile = @TempDir & "\json_test.log"
    If Not _CreateJsonTestFile($sTestFile) Then
        _LogError("Fehler beim Erstellen der Testdatei")
        Return False
    EndIf
    
    ; Parser testen
    If Not _TestJsonParser($sTestFile) Then
        _LogError("Fehler beim Testen des Parsers")
        Return False
    EndIf
    
    _LogInfo("JSON-Parser-Test erfolgreich abgeschlossen")
    Return True
EndFunc