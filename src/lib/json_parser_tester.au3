#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <File.au3>
#include <Array.au3>
#include "logging.au3"
#include "constants.au3"
#include "json_test_utils.au3"

; GUI-Elemente
Global $g_hJsonTesterGUI = 0
Global $g_idJsonTesterInput = 0
Global $g_idJsonTesterOutput = 0
Global $g_idJsonTesterFileInput = 0
Global $g_idJsonTestButton = 0
Global $g_idJsonTestCreateButton = 0
Global $g_idJsonTestCloseButton = 0

; Zeigt den JSON-Parser-Tester Dialog an
Func _ShowJsonParserTester()
    _LogInfo("Öffne JSON-Parser-Tester")

    ; GUI erstellen
    $g_hJsonTesterGUI = GUICreate("JSON-Parser Tester", 800, 600)
    
    ; Eingabefeld für JSON-Text
    GUICtrlCreateLabel("JSON-Text oder Dateipfad:", 10, 10, 200, 20)
    $g_idJsonTesterInput = GUICtrlCreateEdit("", 10, 35, 780, 100, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    
    ; Datei-Eingabefeld und Browse-Button
    GUICtrlCreateLabel("Oder Datei auswählen:", 10, 145, 200, 20)
    $g_idJsonTesterFileInput = GUICtrlCreateInput("", 10, 165, 680, 20)
    $g_idJsonBrowseButton = GUICtrlCreateButton("...", 700, 165, 30, 20)
    
    ; Ausgabefeld
    GUICtrlCreateLabel("Parser-Ergebnis:", 10, 195, 200, 20)
    $g_idJsonTesterOutput = GUICtrlCreateEdit("", 10, 215, 780, 330, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL))
    
    ; Buttons
    $g_idJsonTestButton = GUICtrlCreateButton("Testen", 170, 560, 100, 30)
    $g_idJsonTestCreateButton = GUICtrlCreateButton("Testdatei erzeugen", 350, 560, 150, 30)
    $g_idJsonTestCloseButton = GUICtrlCreateButton("Schließen", 580, 560, 100, 30)
    
    ; Beispiel JSON anzeigen
    GUICtrlSetData($g_idJsonTesterInput, '{"Timestamp":"2024-09-25T22:30:31.321198+08:00","LogLevel":"Debug","LogClass":"InfoViewModel","Message":"SendeLogfiles: Schreibe ZIP"}' & @CRLF & _
                                         '{"Timestamp":"2024-09-25T22:30:32.432987+08:00","LogLevel":"Info"' & @CRLF)
    
    ; GUI anzeigen
    GUISetState(@SW_SHOW, $g_hJsonTesterGUI)
    
    ; Event-Loop
    Local $iMsg
    While 1
        $iMsg = GUIGetMsg()
        
        Switch $iMsg
            Case $GUI_EVENT_CLOSE, $g_idJsonTestCloseButton
                ExitLoop
                
            Case $g_idJsonBrowseButton
                Local $sFile = FileOpenDialog("Log-Datei öffnen", @WorkingDir, "Log-Dateien (*.log;*.txt)|Alle Dateien (*.*)", $FD_FILEMUSTEXIST)
                If Not @error Then
                    GUICtrlSetData($g_idJsonTesterFileInput, $sFile)
                EndIf
                
            Case $g_idJsonTestButton
                _HandleJsonTest()
                
            Case $g_idJsonTestCreateButton
                _HandleCreateTestFile()
        EndSwitch
    WEnd
    
    ; GUI schließen
    GUIDelete($g_hJsonTesterGUI)
    $g_hJsonTesterGUI = 0
EndFunc

; Verarbeitet den Test-Button-Klick
Func _HandleJsonTest()
    GUICtrlSetData($g_idJsonTesterOutput, "Verarbeite JSON...")
    
    ; Prüfen, ob eine Datei ausgewählt wurde
    Local $sFile = GUICtrlRead($g_idJsonTesterFileInput)
    If $sFile <> "" And FileExists($sFile) Then
        ; Datei testen
        GUICtrlSetData($g_idJsonTesterOutput, "Teste Datei: " & $sFile & @CRLF & @CRLF)
        _TestJsonFileAndShowResults($sFile)
    Else
        ; Text aus dem Eingabefeld testen
        Local $sJsonText = GUICtrlRead($g_idJsonTesterInput)
        If $sJsonText <> "" Then
            ; Temporäre Datei erstellen
            Local $sTempFile = _TempFile(@TempDir, "json_test_", ".log")
            FileWrite($sTempFile, $sJsonText)
            
            GUICtrlSetData($g_idJsonTesterOutput, "Teste eingegebenen JSON-Text" & @CRLF & @CRLF)
            _TestJsonFileAndShowResults($sTempFile)
            
            ; Temporäre Datei löschen
            FileDelete($sTempFile)
        Else
            GUICtrlSetData($g_idJsonTesterOutput, "Bitte geben Sie JSON-Text ein oder wählen Sie eine Datei aus.")
        EndIf
    EndIf
EndFunc

; Verarbeitet den Testdatei-erstellen-Button-Klick
Func _HandleCreateTestFile()
    ; Zieldatei auswählen
    Local $sFile = FileSaveDialog("Testdatei speichern", @WorkingDir, "Log-Dateien (*.log)", $FD_PATHMUSTEXIST)
    If @error Then Return
    
    ; Dateiendung hinzufügen, falls nicht vorhanden
    If StringRight($sFile, 4) <> ".log" Then $sFile &= ".log"
    
    ; Testdatei erstellen
    If _CreateJsonTestFile($sFile) Then
        GUICtrlSetData($g_idJsonTesterOutput, "Testdatei erfolgreich erstellt: " & $sFile & @CRLF & @CRLF)
        GUICtrlSetData($g_idJsonTesterFileInput, $sFile)
    Else
        GUICtrlSetData($g_idJsonTesterOutput, "Fehler beim Erstellen der Testdatei!")
    EndIf
EndFunc

; Testet eine JSON-Datei und zeigt die Ergebnisse an
Func _TestJsonFileAndShowResults($sFilePath)
    ; Format erkennen
    Local $iFormat = ParserManager_DetectLogFormat($sFilePath)
    Local $sOutput = "Erkanntes Format: " & ParserManager_GetFormatName($iFormat) & @CRLF
    
    ; Auf unvollständige Einträge prüfen
    Local $bHasIncomplete = ParserManager_TestIncompleteJson($sFilePath)
    $sOutput &= "Unvollständige Einträge gefunden: " & ($bHasIncomplete ? "JA" : "Nein") & @CRLF & @CRLF
    
    ; Datei parsen
    Local $sContent = FileRead($sFilePath)
    $sOutput &= "Dateiinhalt (" & StringLen($sContent) & " Zeichen):" & @CRLF
    $sOutput &= "----------------------------------------" & @CRLF
    $sOutput &= $sContent & @CRLF
    $sOutput &= "----------------------------------------" & @CRLF & @CRLF
    
    ; Parsing durchführen
    $sOutput &= "Parse-Ergebnisse:" & @CRLF
    
    ; Format-spezifischen Parser verwenden
    Local $aLogEntries
    
    Switch $iFormat
        Case $LOG_FORMAT_JSON, $LOG_FORMAT_JSON_INCOMPLETE
            $sOutput &= "Verwende JSON-Parser mit Unterstützung für unvollständige Einträge" & @CRLF
            $aLogEntries = _ParseJsonPatternLog($sContent)
            
        Case $LOG_FORMAT_JSON_GENERIC
            $sOutput &= "Verwende allgemeinen JSON-Parser" & @CRLF
            $aLogEntries = _ParseGeneralJsonLog($sContent)
            
        Case Else
            $sOutput &= "Verwende allgemeinen JSON-Parser als Fallback" & @CRLF
            $aLogEntries = _ParseJsonPatternLog($sContent)
    EndSwitch
    
    ; Ergebnisse ausgeben
    If IsArray($aLogEntries) Then
        Local $iEntryCount = UBound($aLogEntries)
        $sOutput &= @CRLF & "Gefundene Log-Einträge: " & $iEntryCount & @CRLF & @CRLF
        
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
        
        $sOutput &= "Vollständige Einträge: " & $iCompleteCount & @CRLF
        $sOutput &= "Unvollständige Einträge: " & $iIncompleteCount & @CRLF & @CRLF
        
        ; Details zu den gefundenen Einträgen
        $sOutput &= "Eintrags-Details:" & @CRLF
        $sOutput &= "----------------------------------------" & @CRLF
        
        For $i = 0 To $iEntryCount - 1
            $sOutput &= "Eintrag " & ($i + 1) & ":" & @CRLF
            $sOutput &= "  Timestamp: " & $aLogEntries[$i][0] & @CRLF
            $sOutput &= "  LogLevel: " & $aLogEntries[$i][1] & @CRLF
            $sOutput &= "  LogClass: " & $aLogEntries[$i][2] & @CRLF
            $sOutput &= "  Message: " & $aLogEntries[$i][3] & @CRLF
            $sOutput &= "  Raw: " & $aLogEntries[$i][4] & @CRLF
            $sOutput &= "----------------------------------------" & @CRLF
        Next
    Else
        $sOutput &= @CRLF & "Fehler beim Parsen der Datei!" & @CRLF
    EndIf
    
    ; Ergebnis anzeigen
    GUICtrlSetData($g_idJsonTesterOutput, $sOutput)
EndFunc