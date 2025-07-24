; Titel.......: SQL-Editor-Hilfsfunktionen
; Beschreibung: Hilfsfunktionen für den vereinfachten SQL-Editor
; Autor.......: Ralle1976
; Erstellt....: 2025-04-14
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <GuiListView.au3>
#include <GUIRichEdit.au3>
#include <StringConstants.au3>
#include <GUIConstantsEx.au3>
#include <WinAPI.au3>
#include <Array.au3>
#include <EditConstants.au3>

; VK-Konstanten für Tastaturabfragen
Global Const $VK_CONTROL = 0x11
Global Const $VK_SHIFT = 0x10
Global Const $VK_MENU = 0x12 ; ALT

; Externe Variablen
Global $g_bSQLEditorMode ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_hSQLRichEdit ; Handle des RichEdit-Controls
Global $g_hGUI ; Handle des Hauptfensters
Global $g_bUserInitiatedExecution ; Benutzerinitiierte Ausführung
Global $g_idAutoCompleteList ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList ; Handle der Auto-Vervollständigungsliste
Global $g_idSQLTableCombo ; ID der Tabellen-ComboBox
Global $g_aTableColumns ; Array mit Spaltennamen
Global $g_idListView ; ListView-ID
Global $g_idStatus ; Status-ID
Global $g_sCurrentDB ; Aktuelle Datenbank

; Timer-Variablen für Syntax-Highlighting
Global $g_iLastSyntaxUpdate = 0
Global $g_iSyntaxUpdateInterval = 2000  ; Intervall für Syntax-Highlighting

; ===============================================================================================================================
; Func.....: _LogLimit
; Beschreibung: Begrenzt die Anzahl der Log-Einträge für wiederholte Meldungen
; Parameter.: $sText - Log-Text
;             $iLimitCount - Nur jede X-te Meldung loggen (Standard: 10)
; Rückgabe..: True wenn geloggt wurde, sonst False
; ===============================================================================================================================
Func _LogLimit($sText, $iLimitCount = 10)
    Static $aLogCount[1][2] = [[0, ""]] ; Speichert Count und letzte Nachricht

    ; Prüfen, ob die Nachricht bereits bekannt ist
    Local $iIndex = -1
    For $i = 0 To UBound($aLogCount) - 1
        If $aLogCount[$i][1] = $sText Then
            $iIndex = $i
            ExitLoop
        EndIf
    Next

    ; Wenn nicht gefunden, neue Nachricht hinzufügen
    If $iIndex = -1 Then
        Local $iCount = UBound($aLogCount)
        ReDim $aLogCount[$iCount + 1][2]
        $aLogCount[$iCount][0] = 0
        $aLogCount[$iCount][1] = $sText
        $iIndex = $iCount
    EndIf

    ; Zähler erhöhen
    $aLogCount[$iIndex][0] += 1

    ; Nur jede N-te Nachricht loggen
    If Mod($aLogCount[$iIndex][0], $iLimitCount) = 0 Then
        _LogInfo($sText & " (wiederholte Nachricht " & $aLogCount[$iIndex][0] & " mal)")
        Return True
    EndIf

    ; Erste Nachricht immer loggen
    If $aLogCount[$iIndex][0] = 1 Then
        _LogInfo($sText)
        Return True
    EndIf

    Return False
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateSyntaxHighlighting
; Beschreibung: Führt Syntax-Highlighting für SQL-Anweisungen im RichEdit-Control durch
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateSyntaxHighlighting()
    ; Nur fortfahren, wenn SQL-Editor aktiv ist und RichEdit existiert
    If Not $g_bSQLEditorMode Or $g_hSQLRichEdit = 0 Then
        Static $sPreviousText = ""
        $sPreviousText = ""
        Return False
    EndIf

    ; Statischen Cache für den letzten Text verwenden
    Static $sPreviousText = ""

    ; RichEdit existiert und ist zugreifbar?
    If $g_hSQLRichEdit = 0 Or Not IsHWnd($g_hSQLRichEdit) Then
        _LogInfo("Fehler beim Syntax-Highlighting: RichEdit nicht verfügbar")
        Return False
    EndIf

    ; Text holen
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If @error Or $sText = "" Then Return False

    ; Cursor-Position merken
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    If @error Then Return False

    ; Nur fortfahren wenn der Text sich geändert hat
    If $sText = $sPreviousText Then Return True
    $sPreviousText = $sText

    ; SQL-Schlüsselwörter definieren
    Local $aSQLKeywords = ["SELECT", "FROM", "WHERE", "GROUP", "ORDER", "BY", "HAVING", "LIMIT", "JOIN", "LEFT", "RIGHT", "INNER", "DELETE", "UPDATE", "INSERT", "VALUES", "INTO", "SET", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN", "IS", "NULL", "AS", "ON", "UNION", "ALL", "DISTINCT", "DESC", "ASC", "PRAGMA", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "UNIQUE", "CHECK", "DEFAULT", "AUTOINCREMENT", "CASCADE"]

    ; Mit Standardfarbe beginnen (schwarz)
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, 0, -1)
    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000)

    ; Nach Schlüsselwörtern suchen und formatieren
    For $i = 0 To UBound($aSQLKeywords) - 1
        ; RichEdit noch vorhanden?
        If Not IsHWnd($g_hSQLRichEdit) Then Return False

        Local $sUpperKeyword = StringUpper($aSQLKeywords[$i])
        If StringInStr($sText, $sUpperKeyword) Then
            ; Suche nach allen Vorkommen dieses Schlüsselworts
            Local $iPos = 1
            While 1
                $iPos = StringInStr($sText, $sUpperKeyword, 0, 1, $iPos)
                If $iPos = 0 Then ExitLoop

                ; Prüfen, ob es ein eigenständiges Wort ist
                Local $bIsWholeWord = True

                ; Zeichen vor dem Wort prüfen
                If $iPos > 1 Then
                    Local $cBefore = StringMid($sText, $iPos - 1, 1)
                    If StringRegExp($cBefore, "[a-zA-Z0-9_]") Then $bIsWholeWord = False
                EndIf

                ; Zeichen nach dem Wort prüfen
                Local $iEndPos = $iPos + StringLen($sUpperKeyword)
                If $iEndPos <= StringLen($sText) Then
                    Local $cAfter = StringMid($sText, $iEndPos, 1)
                    If StringRegExp($cAfter, "[a-zA-Z0-9_]") Then $bIsWholeWord = False
                EndIf

                ; Wenn es ein eigenständiges Wort ist, formatieren
                If $bIsWholeWord Then
                    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iPos - 1, $iPos + StringLen($sUpperKeyword) - 1)
                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x0000FF)  ; Blau für Schlüsselwörter
                EndIf

                ; Zur nächsten Position weitergehen
                $iPos += 1
            WEnd
        EndIf
    Next

    ; Cursor-Position wiederherstellen
    If IsHWnd($g_hSQLRichEdit) Then
        _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $aSel[0], $aSel[1])
    EndIf

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ExecuteQuery
; Beschreibung: Führt eine SQL-Abfrage aus und zeigt Ergebnisse in der ListView
; Parameter.: $sSQL - SQL-Abfrage
;             $sDBPath - Pfad zur Datenbank
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_ExecuteQuery($sSQL, $sDBPath)
    ; Sicherheitscheck: Nur Ausführen wenn vom Benutzer initiiert
    If Not $g_bUserInitiatedExecution Then
        _LogInfo("Ausführung blockiert: Nicht vom Benutzer initiiert")
        _SetStatus("Bitte den 'Ausführen'-Button verwenden")
        Return False
    EndIf

    _LogInfo("SQL-Ausführung gestartet")

    ; Eingabeparameter prüfen
    If $sDBPath = "" Then
        _LogInfo("Fehler: Keine Datenbank angegeben")
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        Return False
    EndIf

    If $sSQL = "" Then
        _LogInfo("Fehler: Keine SQL-Anweisung angegeben")
        _SetStatus("Fehler: Keine SQL-Anweisung eingegeben")
        Return False
    EndIf

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogInfo("Fehler beim Öffnen der Datenbank: " & @error)
        _SetStatus("Fehler beim Öffnen der Datenbank")
        Return False
    EndIf

    ; SQL-Typ bestimmen (SELECT oder andere Anweisung)
    If StringRegExp(StringUpper(StringStripWS($sSQL, 3)), "^\s*SELECT") Then
        ; SELECT-Abfrage ausführen
        Local $aResult, $iRows, $iColumns
        _LogInfo("Führe SELECT-Abfrage aus")

        Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
        _SQLite_Close($hDB)

        If @error Or $iRet <> $SQLITE_OK Then
            _LogInfo("SQL-Fehler: " & _SQLite_ErrMsg())
            _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
            Return False
        EndIf

        _LogInfo("SELECT-Abfrage erfolgreich: " & $iRows & " Zeilen, " & $iColumns & " Spalten")

        ; ListView leeren
        _GUICtrlListView_DeleteAllItems($g_idListView)
        _DeleteAllListViewColumns($g_idListView)

        ; Keine Ergebnisse?
        If $iRows = 0 Or $iColumns = 0 Then
            _LogInfo("Keine Ergebnisse für diese Abfrage")
            _SetStatus("Abfrage erfolgreich - keine Ergebnisse")
            Return True
        EndIf

        ; Spalten hinzufügen
        For $i = 0 To $iColumns - 1
            _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$i], 100)
        Next

        ; Daten hinzufügen
        For $i = 1 To $iRows
            Local $iIndex = _GUICtrlListView_AddItem($g_idListView, $aResult[$i][0])
            For $j = 1 To $iColumns - 1
                _GUICtrlListView_AddSubItem($g_idListView, $iIndex, $aResult[$i][$j], $j)
            Next
        Next

        ; Spaltenbreiten anpassen
        For $i = 0 To $iColumns - 1
            _GUICtrlListView_SetColumnWidth($g_idListView, $i, $LVSCW_AUTOSIZE_USEHEADER)
        Next

        ; ListView aktualisieren
        _LogInfo("ListView aktualisiert")
        GUICtrlSetState($g_idListView, $GUI_SHOW)
        _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
        _SetStatus("Abfrage erfolgreich: " & $iRows & " Zeilen gefunden")
    Else
        ; Nicht-SELECT-Abfrage (UPDATE, INSERT, etc.)
        _LogInfo("Führe Nicht-SELECT-Anweisung aus")

        Local $iRet = _SQLite_Exec($hDB, $sSQL)
        Local $iChanges = _SQLite_Changes($hDB)
        _SQLite_Close($hDB)

        If @error Or $iRet <> $SQLITE_OK Then
            _LogInfo("SQL-Fehler: " & _SQLite_ErrMsg())
            _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
            Return False
        EndIf

        _LogInfo("Nicht-SELECT-Anweisung erfolgreich: " & $iChanges & " Zeilen betroffen")
        _SetStatus("Anweisung erfolgreich: " & $iChanges & " Zeilen betroffen")
    EndIf

    _LogInfo("SQL-Ausführung beendet")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SetStatus
; Beschreibung: Setzt die Statusmeldung im Hauptfenster
; Parameter.: $sText - Statustext
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SetStatus($sText)
    If $g_idStatus <> 0 Then
        ; Logging optimieren
        Static $sPreviousStatus = ""

        ; Nur bei Änderung loggen
        If $sPreviousStatus <> $sText Then
            _LogInfo("Status: " & $sText)
            $sPreviousStatus = $sText
        EndIf

        GUICtrlSetData($g_idStatus, $sText)
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _GetTableColumns
; Beschreibung: Ermittelt die Spalten einer Tabelle
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: Array mit Spaltennamen
; ===============================================================================================================================
Func _GetTableColumns($sDBPath, $sTable)
    Local $aColumns[0]
    If $sDBPath = "" Or $sTable = "" Then Return $aColumns

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then Return $aColumns

    ; PRAGMA-Befehl ausführen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "PRAGMA table_info(" & $sTable & ");"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
    _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then Return $aColumns

    ; Spaltennamen extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    Return $aColumns
EndFunc

; ===============================================================================================================================
; Func.....: _AdLibSyntaxHighlighting
; Beschreibung: Timer-Funktion für Syntax-Highlighting
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AdLibSyntaxHighlighting()
    ; Nur ausführen, wenn SQL-Editor aktiv ist
    If Not $g_bSQLEditorMode Then Return
    If $g_hSQLRichEdit = 0 Then Return

    ; Nur alle X Millisekunden aktualisieren
    If $g_iLastSyntaxUpdate = 0 Or TimerDiff($g_iLastSyntaxUpdate) > $g_iSyntaxUpdateInterval Then
        _SQL_UpdateSyntaxHighlighting()
        $g_iLastSyntaxUpdate = TimerInit()

        ; Auto-Vervollständigung aktualisieren
        If $g_idAutoCompleteList <> 0 And BitAND(GUICtrlGetState($g_idAutoCompleteList), $GUI_SHOW) Then
            _UpdateAutoCompleteList()
        EndIf
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _ExecuteSQL_F5
; Beschreibung: Führt SQL aus wenn F5-Taste gedrückt wird
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ExecuteSQL_F5()
    ; Nur im SQL-Editor-Modus
    If Not $g_bSQLEditorMode Then Return

    _LogInfo("F5-Taste gedrückt - Führe SQL aus")

    ; SQL-Text und Datenbank holen
    Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Benutzer-initiierte Ausführung markieren
    $g_bUserInitiatedExecution = True

    ; Nur ausführen, wenn SQL vorhanden
    If $sSQL <> "" Then
        _LogInfo("SQL-Ausführung durch F5-Taste")
        _SetStatus("Führe SQL aus...")

        ; SQL ausführen
        _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)

        _LogInfo("SQL-Ausführung abgeschlossen")
        _SetStatus("SQL-Ausführung abgeschlossen")

        ; Syntax-Highlighting aktualisieren
        _SQL_UpdateSyntaxHighlighting()
    Else
        _SetStatus("Fehler: SQL-Anweisung fehlt")
    EndIf

    ; Flag zurücksetzen
    $g_bUserInitiatedExecution = False
EndFunc

; ===============================================================================================================================
; Func.....: _WM_KEYDOWN
; Beschreibung: Event-Handler für Tasten
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func _WM_KEYDOWN($hWnd, $iMsg, $wParam, $lParam)
    ; Nur im SQL-Editor-Modus
    If Not $g_bSQLEditorMode Then Return $GUI_RUNDEFMSG
    If $g_hSQLRichEdit = 0 Then Return $GUI_RUNDEFMSG

    ; Taste ermitteln
    Local $iKeyCode = $wParam

    ; STRG+LEERTASTE für Autovervollständigung
    If $iKeyCode = 32 And BitAND(_WinAPI_GetKeyState($VK_CONTROL), 0x8000) <> 0 Then
        If $hWnd = $g_hSQLRichEdit Then
            Sleep(50)  ; Kurze Verzögerung zur Verarbeitung
            _ShowCompletionList()
            Return $GUI_RUNDEFMSG
        EndIf
    EndIf

    ; Navigation in der Autovervollständigungsliste
    If $g_idAutoCompleteList <> 0 And BitAND(GUICtrlGetState($g_idAutoCompleteList), $GUI_SHOW) Then
        ; TAB oder ENTER für Anwendung
        If $iKeyCode = 9 Or $iKeyCode = 13 Then  ; TAB/ENTER
            _ApplyAutoComplete()
            Return $GUI_RUNDEFMSG
        EndIf

        ; ESC zum Schließen
        If $iKeyCode = 27 Then  ; ESC
            GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
            Return $GUI_RUNDEFMSG
        EndIf

        ; Pfeiltasten für Navigation
        If $iKeyCode = 38 Or $iKeyCode = 40 Then  ; Nach oben/unten
            If $g_hAutoCompleteList <> 0 Then
                _WinAPI_SetFocus($g_hAutoCompleteList)
                Return $GUI_RUNDEFMSG
            EndIf
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _WM_CHAR
; Beschreibung: Event-Handler für Zeicheneingabe
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func _WM_CHAR($hWnd, $iMsg, $wParam, $lParam)
    ; Nur im SQL-Editor-Modus
    If Not $g_bSQLEditorMode Or $hWnd <> $g_hSQLRichEdit Then Return $GUI_RUNDEFMSG

    ; Zeichen auswerten
    Local $iChar = $wParam

    ; Punkt-Zeichen (wichtig für Tabelle.Spalte) -> Autovervollständigung
    If $iChar = 46 Then  ; '.'
        Sleep(50)  ; Kurze Verzögerung zur Verarbeitung
        _ShowCompletionList()
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _ShowCompletionList
; Beschreibung: Zeigt Autovervollständigungs-Liste an
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ShowCompletionList()
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return False

    ; Vorschläge ermitteln
    Local $aMatches = _UpdateAutoCompleteList()
    If UBound($aMatches) = 0 Then
        If $g_idAutoCompleteList <> 0 Then GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
        Return False
    EndIf

    ; RichEdit-Position bestimmen
    Local $aRichEditPos = ControlGetPos($g_hGUI, "", $g_hSQLRichEdit)

    ; Position der Liste berechnen
    Local $iXPos = $aRichEditPos[0] + 100
    Local $iYPos = $aRichEditPos[1] + 50

    ; Liste neu erstellen
    If $g_idAutoCompleteList <> 0 Then GUICtrlDelete($g_idAutoCompleteList)

    $g_idAutoCompleteList = GUICtrlCreateList("", $iXPos, $iYPos, 250, 150, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY))
    $g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)

    ; Vorschläge einfügen
    For $i = 0 To UBound($aMatches) - 1
        GUICtrlSetData($g_idAutoCompleteList, $aMatches[$i])
    Next

    ; Ersten Eintrag auswählen und Liste anzeigen
    If $g_hAutoCompleteList <> 0 Then
        _SendMessage($g_hAutoCompleteList, $LB_SETCURSEL, 0, 0)
        GUICtrlSetState($g_idAutoCompleteList, $GUI_SHOW)

        ; Liste im Vordergrund platzieren
        _WinAPI_SetWindowPos($g_hAutoCompleteList, $HWND_TOPMOST, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    EndIf

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _UpdateAutoCompleteList
; Beschreibung: Aktualisiert die Liste der Vervollständigungsvorschläge
; Parameter.: Keine
; Rückgabe..: Array mit Vorschlägen
; ===============================================================================================================================
Func _UpdateAutoCompleteList()
    Local $aEmptyArray[0]
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return $aEmptyArray

    ; Cursor-Position ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]

    ; Text holen
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Aktuelles Wort ermitteln
    Local $sCurrentWord = ""
    For $i = $iCursorPos - 1 To 0 Step -1
        Local $sChar = StringMid($sText, $i + 1, 1)
        If StringRegExp($sChar, "[^a-zA-Z0-9_]") Then ExitLoop
        $sCurrentWord = $sChar & $sCurrentWord
    Next

    ; Zu kurzes Wort?
    If StringLen($sCurrentWord) < 1 Then Return $aEmptyArray

    ; Vorschläge suchen
    Return _FindAutoCompleteMatches($sCurrentWord)
EndFunc

; ===============================================================================================================================
; Func.....: _FindAutoCompleteMatches
; Beschreibung: Sucht passende Vorschläge für Autovervollständigung
; Parameter.: $sCurrentWord - Aktuelles Wort
; Rückgabe..: Array mit passenden Vorschlägen
; ===============================================================================================================================
Func _FindAutoCompleteMatches($sCurrentWord)
    Local $aMatches[0]
    If $sCurrentWord = "" Then Return $aMatches

    ; SQL-Text und Cursor-Position ermitteln
    Local $sCurrentText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]
    Local $sTextBeforeCursor = StringLeft($sCurrentText, $iCursorPos)

    ; Kontextanalyse
    Local $bIsTableContext = False
    Local $bIsColumnContext = False

    ; Tabellenkontext? (nach FROM oder JOIN)
    If StringRegExp(StringUpper($sTextBeforeCursor), "(FROM|JOIN)\s+[^\s,;]* *$") Then
        $bIsTableContext = True
    ; Spaltenkontext? (nach SELECT, WHERE, etc.)
    ElseIf StringRegExp(StringUpper($sTextBeforeCursor), "(SELECT|WHERE|AND|OR|BY|,|\()\s*[^\s,;()]*$") Then
        $bIsColumnContext = True
    EndIf

    ; Vergleich in Großbuchstaben
    $sCurrentWord = StringUpper($sCurrentWord)

    ; SQL-Schlüsselwörter (Grundvokabular)
    Local $aSQLKeywords = ["SELECT", "FROM", "WHERE", "GROUP", "ORDER", "BY", "HAVING", "LIMIT", "JOIN", "LEFT", "RIGHT", "INNER", "DELETE", "UPDATE", "INSERT", "VALUES", "INTO", "SET", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN", "IS", "NULL", "AS", "ON"]

    ; Tabellennamen hinzufügen wenn relevant
    If $bIsTableContext Or (Not $bIsColumnContext) Then
        Local $sTables = GUICtrlRead($g_idSQLTableCombo, 1)
        Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
        For $i = 0 To UBound($aTableList) - 1
            If $aTableList[$i] <> "" Then _ArrayAdd($aSQLKeywords, $aTableList[$i])
        Next
    EndIf

    ; Spaltennamen hinzufügen wenn relevant
    If $bIsColumnContext Or (Not $bIsTableContext) Then
        Local $sCurrentTable = GUICtrlRead($g_idSQLTableCombo)
        If $sCurrentTable <> "" Then
            If UBound($g_aTableColumns) = 0 Then
                $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sCurrentTable)
            EndIf

            For $i = 0 To UBound($g_aTableColumns) - 1
                If $g_aTableColumns[$i] <> "" Then _ArrayAdd($aSQLKeywords, $g_aTableColumns[$i])
            Next
        EndIf
    EndIf

    ; Nach Übereinstimmungen suchen
    For $i = 0 To UBound($aSQLKeywords) - 1
        If StringLeft(StringUpper($aSQLKeywords[$i]), StringLen($sCurrentWord)) = $sCurrentWord Then
            _ArrayAdd($aMatches, $aSQLKeywords[$i])
        EndIf
    Next

    Return $aMatches
EndFunc

; ===============================================================================================================================
; Func.....: _ApplyAutoComplete
; Beschreibung: Wendet den ausgewählten Autovervollständigungs-Vorschlag an
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ApplyAutoComplete()
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Or Not IsHWnd($g_hAutoCompleteList) Then Return False
    If Not BitAND(GUICtrlGetState($g_idAutoCompleteList), $GUI_SHOW) Then Return False

    ; Ausgewählten Eintrag holen
    Local $sSelected = GUICtrlRead($g_idAutoCompleteList)
    If $sSelected = "" Then Return False

    ; Cursor-Position und Text holen
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Aktuelles Wort ermitteln
    Local $sCurrentWord = ""
    Local $iStartPos = $iCursorPos
    For $i = $iCursorPos - 1 To 0 Step -1
        Local $sChar = StringMid($sText, $i + 1, 1)
        If StringRegExp($sChar, "[^a-zA-Z0-9_]") Then
            $iStartPos = $i + 1
            ExitLoop
        EndIf
        $sCurrentWord = $sChar & $sCurrentWord
    Next

    ; Text ersetzen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iStartPos, $iCursorPos)
    _GUICtrlRichEdit_ReplaceText($g_hSQLRichEdit, $sSelected)

    ; Liste ausblenden
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)

    ; Neue Cursor-Position setzen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iStartPos + StringLen($sSelected), $iStartPos + StringLen($sSelected))

    ; Fokus zurück auf RichEdit
    _WinAPI_SetFocus($g_hSQLRichEdit)

    ; Highlighting aktualisieren
    _SQL_UpdateSyntaxHighlighting()

    Return True
EndFunc