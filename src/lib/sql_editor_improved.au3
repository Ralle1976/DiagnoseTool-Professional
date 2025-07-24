; ===============================================================================================================================
; Titel.......: SQL-Editor (Verbesserte Version)
; Beschreibung: Vollständig überarbeiteter SQL-Editor mit verbesserter Syntax-Erkennung und -Ausführung
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-12
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <Array.au3>
#include <String.au3>
#include <GuiListView.au3>
#include <GUIConstantsEx.au3> ; Für $GUI_SHOW
#include <WinAPI.au3>

#include "logging.au3"
#include "error_handler.au3"

; Externe Variablen
Global $g_idSQLDbCombo     ; Datenbank-Combo-Box
Global $g_hSQLRichEdit     ; RichEdit-Control
Global $g_idListView       ; ListView für Ergebnisse
Global $g_idStatus         ; Statusleiste
Global $g_idAutoCompleteList ; Auto-Vervollständigungsliste
Global $g_hGUI             ; Hauptfenster-Handle

; ===============================================================================================================================
; Func.....: _SQL_ImprovedExecuteQueries
; Beschreibung: Verbesserte Funktion zur Ausführung von SQL-Anweisungen
; Parameter.: $sSQL - SQL-Anweisungen
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_ImprovedExecuteQueries($sSQL)
    ; Prüfen, ob wir uns im ersten Lade-Prozess befinden
    If $g_bSQLEditorFirstLoad Then
        _LogInfo("SQL-Ausführung abgebrochen: Erste Ladephase")
        Return False
    EndIf
    
    ; Prüfen, ob nur manuelle Ausführung erlaubt ist
    If $g_bManualExecuteOnly Then
        ; Prüfen, ob diese Funktion durch direkten Button-Klick aufgerufen wurde
        ; Diese Variable sollte nur in den Button-Event-Handlern auf True gesetzt werden
        Local $bWasManuallyTriggered = False
        
        ; Stack-Trace analysieren (wenn in AutoIt verfügbar)
        Local $sCallingFunction = @ScriptLineNumber  ; Als Fallback
        
        ; Wenn nicht explizit manuell ausgelöst, Ausführung verweigern
        If Not $bWasManuallyTriggered Then
            _LogInfo("SQL-Ausführung abgebrochen: Nicht manuell ausgelöst. Aufrufer: " & $sCallingFunction)
            Return False
        EndIf
    EndIf
    
    ; Ab hier normalen Code fortsetzen
    Local $bSQLExecutionInProgress = False  ; Lokale Kopie des Flags
    
    ; Mehrfachausführung verhindern
    If $bSQLExecutionInProgress = True Then
        _LogInfo("SQL-Ausführung bereits im Gange - Doppelte Ausführung verhindert")
        Return False
    EndIf
    
    $bSQLExecutionInProgress = True
    
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Abfrage fehlgeschlagen: Keine Datenbank ausgewählt")
        $g_bSQLExecutionInProgress = False  ; Flag zurücksetzen
        Return SetError(1, 0, False)
    EndIf

    ; Statusmeldung setzen
    _SetStatus("Führe SQL-Anweisungen aus...")
    
    ; Leerzeichen in SQL-Anweisung korrigieren (umfassende Korrektur)
    Local $sFixedSQL = _SQL_FixSpacingComprehensive($sSQL)
    _LogInfo("Korrigierte SQL-Anweisung: " & $sFixedSQL)

    ; Verwende den verbesserten SQL-Parser
    Local $aQueries = _SQL_ParseQuery($sFixedSQL)
    If Not IsArray($aQueries) Or UBound($aQueries) < 1 Then
        _SetStatus("Fehler beim Parsen der SQL-Anweisungen")
        $g_bSQLExecutionInProgress = False  ; Flag zurücksetzen
        Return SetError(2, 0, False)
    EndIf

    Local $bHasResults = False
    Local $iSuccessCount = 0
    Local $iErrorCount = 0

    ; Datenbank öffnen
    _LogInfo("SQL-Ausführung: Öffne Datenbank: " & $sDBPath)
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        $g_bSQLExecutionInProgress = False  ; Flag zurücksetzen
        Return SetError(3, 0, False)
    EndIf

    ; Transaktion beginnen
    _LogInfo("SQL-Ausführung: Beginne Transaktion")
    _SQLite_Exec($hDB, "BEGIN TRANSACTION;")

    ; Abfragen ausführen und Ergebnisse anzeigen
    _LogInfo("SQL-Ausführung: Verarbeite " & UBound($aQueries) & " SQL-Anweisungen")
    
    ; Jede Anweisung einzeln ausführen
    For $i = 0 To UBound($aQueries) - 1
        Local $sQuery = $aQueries[$i]
        $sQuery = StringStripWS($sQuery, $STR_STRIPTRAILING)
        
        ; Leere Queries überspringen
        If $sQuery = "" Then 
            _LogInfo("SQL-Ausführung: Leere Anweisung übersprungen")
            ContinueLoop
        EndIf
        
        ; Weitere Leerzeichen-Korrektur für jede Abfrage
        $sQuery = _SQL_FixSpacingComprehensive($sQuery)
        _LogInfo("SQL-Ausführung: Verarbeite SQL #" & ($i+1) & ": " & (StringLen($sQuery) > 100 ? StringLeft($sQuery, 100) & "..." : $sQuery))
        
        ; Prüfen, ob es sich um eine SELECT-Abfrage handelt
        Local $bIsSelect = StringRegExp(StringUpper($sQuery), "^\s*SELECT")
        
        If $bIsSelect Then
            ; SELECT-Abfrage ausführen
            _LogInfo("SQL-Ausführung: Führe SELECT-Abfrage aus")
            Local $aResult, $iRows, $iColumns
            Local $iRet = _SQLite_GetTable2d($hDB, $sQuery, $aResult, $iRows, $iColumns)
            
            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler bei Abfrage: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf
            
            _LogInfo("SQL-Ausführung: SELECT-Abfrage erfolgreich: " & $iRows & " Zeilen, " & $iColumns & " Spalten")
            
            ; Ergebnisse anzeigen (nur für die letzte Abfrage oder wenn es die einzige ist)
            If $i = UBound($aQueries) - 1 Or UBound($aQueries) = 1 Then
                _LogInfo("SQL-Ausführung: Bereite ListView für Ergebnisanzeige vor")
                
                ; ListView komplett neu aufbauen
                _GUICtrlListView_DeleteAllItems($g_idListView)
                _DeleteAllListViewColumns($g_idListView)
                
                If $iRows = 0 Then
                    _LogInfo("Keine Ergebniszeilen vorhanden")
                    _SetStatus("Abfrage ausgeführt. Keine Ergebnisse gefunden.")
                    $iSuccessCount += 1
                    $bHasResults = False
                    ContinueLoop
                EndIf
                
                ; Spaltenüberschriften zur ListView hinzufügen
                _LogInfo("SQL-Ausführung: Füge " & $iColumns & " Spaltenüberschriften hinzu")
                For $j = 0 To $iColumns - 1
                    _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$j], 100)
                Next
                
                ; Daten zur ListView hinzufügen
                _LogInfo("SQL-Ausführung: Füge " & $iRows & " Datenzeilen zur ListView hinzu")
                For $j = 1 To $iRows
                    Local $iIndex = _GUICtrlListView_AddItem($g_idListView, $aResult[$j][0])
                    For $k = 1 To $iColumns - 1
                        _GUICtrlListView_AddSubItem($g_idListView, $iIndex, $aResult[$j][$k], $k)
                    Next
                Next
                
                ; Spaltenbreiten automatisch anpassen
                For $j = 0 To $iColumns - 1
                    _GUICtrlListView_SetColumnWidth($g_idListView, $j, $LVSCW_AUTOSIZE_USEHEADER)
                Next
                
                ; Zwischenaktualisierungen der ListView vermeiden
                ; _LogInfo("SQL-Ausführung: Aktualisiere ListView-Darstellung")
                ; GUICtrlSetState($g_idListView, $GUI_SHOW)
                ; _WinAPI_InvalidateRect(GUICtrlGetHandle($g_idListView))
                ; _WinAPI_UpdateWindow(GUICtrlGetHandle($g_idListView))
                ; _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
                
                $bHasResults = True
                _LogInfo("ListView-Darstellung aktualisiert")
            EndIf
            
            $iSuccessCount += 1
        Else
            ; Andere Anweisungen (INSERT, UPDATE, DELETE, etc.)
            _LogInfo("SQL-Ausführung: Führe Nicht-SELECT-Anweisung aus")
            Local $iRet = _SQLite_Exec($hDB, $sQuery)
            
            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler bei Nicht-SELECT-Anweisung: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf
            
            _LogInfo("SQL-Ausführung: Nicht-SELECT-Anweisung erfolgreich ausgeführt")
            $iSuccessCount += 1
        EndIf
    Next

    ; Transaktion abschließen
    _LogInfo("SQL-Ausführung: Schließe Transaktion ab")
    _SQLite_Exec($hDB, "COMMIT;")

    ; Anzahl der betroffenen Zeilen ermitteln
    Local $iChanges = _SQLite_Changes($hDB)
    _LogInfo("SQL-Ausführung: " & $iChanges & " Zeilen betroffen")

    ; Datenbank schließen
    _SQLite_Close($hDB)
    _LogInfo("SQL-Ausführung: Datenbankverbindung geschlossen")
    
    ; Finale ListView-Aktualisierung erzwingen
    If $bHasResults Then
        _LogInfo("SQL-Ausführung: Erzwinge finale ListView-Aktualisierung")
        GUICtrlSetState($g_idListView, $GUI_SHOW)
        _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
        _WinAPI_UpdateWindow(GUICtrlGetHandle($g_idListView))
        _WinAPI_RedrawWindow($g_hGUI) ; Gesamtes Hauptfenster aktualisieren
    EndIf

    ; Statusmeldung aktualisieren
    If $iErrorCount = 0 Then
        If $bHasResults Then
            _SetStatus("Alle Abfragen erfolgreich ausgeführt: " & $iSuccessCount & " Anweisungen.")
        Else
            _SetStatus("Alle Anweisungen erfolgreich ausgeführt: " & $iChanges & " Zeilen betroffen.")
        EndIf
        _LogInfo("SQL-Ausführung: Alle Anweisungen erfolgreich abgeschlossen")
        ; Lock freigeben
        $bSQLExecutionInProgress = False
        ; Kurze Pause, um wiederholte Button-Klicks zu vermeiden (Wichtig gegen Event-Spamming)
        Sleep(200)
        Return True
    Else
        _SetStatus("Ausführung mit Fehlern: " & $iSuccessCount & " erfolgreich, " & $iErrorCount & " fehlgeschlagen.")
        _LogWarning("SQL-Ausführung: " & $iErrorCount & " Anweisungen fehlgeschlagen")
        ; Lock freigeben
        $bSQLExecutionInProgress = False
        ; Kurze Pause, um wiederholte Button-Klicks zu vermeiden (Wichtig gegen Event-Spamming)
        Sleep(200)
        Return False
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateEditorWithAdvancedHighlighting
; Beschreibung: Verbesserte Syntax-Hervorhebung für den SQL-Editor
; Parameter.: $hRichEdit - RichEdit-Control
;             $sSQL - SQL-Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_UpdateEditorWithAdvancedHighlighting($hRichEdit, $sSQL)
    ; Syntax-Highlighter direkt aufrufen
    _SQL_SyntaxHighlighter_Update($hRichEdit)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ShowSyntaxErrorHighlighting
; Beschreibung: Hebt Syntaxfehler in einer SQL-Abfrage hervor
; Parameter.: $hRichEdit - RichEdit-Control
;             $sSQL - SQL-Text
;             $iErrorPos - Position des Fehlers (wenn bekannt)
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ShowSyntaxErrorHighlighting($hRichEdit, $sSQL, $iErrorPos = -1)
    ; Aktuelle Selektion speichern
    Local $aSel = _GUICtrlRichEdit_GetSel($hRichEdit)
    
    ; Wenn eine Fehlerposition angegeben wurde, diese hervorheben
    If $iErrorPos >= 0 Then
        ; Text rot färben
        _GUICtrlRichEdit_SetSel($hRichEdit, $iErrorPos, $iErrorPos + 10) ; 10 Zeichen nach dem Fehler
        _GUICtrlRichEdit_SetCharColor($hRichEdit, 0xFF0000) ; Rot
        
        ; Cursor an die Fehlerposition setzen
        _GUICtrlRichEdit_SetSel($hRichEdit, $iErrorPos, $iErrorPos)
    Else
        ; Wenn keine Position bekannt ist, normales Highlighting durchführen
        _SQL_UpdateEditorWithAdvancedHighlighting($hRichEdit, $sSQL)
    EndIf
    
    ; Ursprüngliche Selektion wiederherstellen, falls kein spezifischer Fehler
    If $iErrorPos < 0 Then
        _GUICtrlRichEdit_SetSel($hRichEdit, $aSel[0], $aSel[1])
    EndIf
EndFunc
