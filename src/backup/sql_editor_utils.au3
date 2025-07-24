; Titel.......: SQL-Editor-Hilfsfunktionen
; Beschreibung: Hilfsfunktionen für den optimierten SQL-Editor mit einer ComboBox
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
; Externe Variablen
Global $g_bSQLEditorMode ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_hSQLRichEdit ; Handle des RichEdit-Controls
Global $g_hGUI ; Handle des Hauptfensters
Global $g_bUserInitiatedExecution ; Benutzerinitiierte Ausführung
Global $g_idAutoCompleteList ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList ; Handle der Auto-Vervollständigungsliste
Global $g_aTableColumns ; Array mit Spaltennamen
Global $g_idListView ; ListView-ID
Global $g_idStatus ; Status-ID
Global $g_sCurrentDB ; Aktuelle Datenbank

; =============================================================================
; Globale Variablen für das eigenständige Autovervollständigungs-Fenster
; =============================================================================
Global $g_hAutoCompleteWindow = 0     ; Handle des Autovervollständigungs-Fensters
Global $g_idAutoCompleteListPopup = 0  ; ID der Listbox im Popup-Fenster
Global $g_bAutoCompleteWindowVisible = False ; Status des Fensters
Global $g_aCurrentMatches[0]         ; Aktuell angezeigte Vorschläge
Global $g_iCurrentWordStart = 0       ; Startposition des aktuellen Wortes

; Timer-Variablen für Syntax-Highlighting
Global $g_iLastSyntaxUpdate = 0
Global $g_iSyntaxUpdateInterval = 2000  ; Intervall für Syntax-Highlighting

; Neue gemeinsame ComboBox-Variable (referenziert die Haupt-ComboBox)
Global $g_idTableCombo = 0 ; ID der gemeinsamen Tabellen-ComboBox

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
                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0xFF0000)  ; Rot für Schlüsselwörter (BGR-Format: 0x0000FF in RGB = Rot)
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

    ; NEUES FEATURE: Tabellenname aus SELECT-Statement per RegEx extrahieren und ComboBox aktualisieren
    Local $sTableFromSQL = _ExtractTableFromSQL($sSQL)
    If $sTableFromSQL <> "" Then
        _LogInfo("Tabelle aus SQL extrahiert: " & $sTableFromSQL)

        ; Tabellenname in ComboBox auswählen, wenn vorhanden
        Local $sTables = GUICtrlRead($g_idTableCombo, 1)
        If StringInStr("|" & $sTables & "|", "|" & $sTableFromSQL & "|") Then
            _LogInfo("Selektiere Tabelle in ComboBox: " & $sTableFromSQL)
            GUICtrlSetData($g_idTableCombo, $sTableFromSQL, $sTableFromSQL)
            $g_sCurrentTable = $sTableFromSQL
        EndIf
    EndIf

    ; Prüfen, ob eine Datenbankverbindung bereits besteht
    Local $bNeedToConnect = True
    If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
        $bNeedToConnect = False
        _LogInfo("Datenbankverbindung besteht bereits")
    EndIf

    ; Datenbank nur öffnen, wenn keine Verbindung besteht
    Local $hDB = -1 ; Standardhandle verwenden
    Local $bWasOpened = False

    If $bNeedToConnect Then
        _LogInfo("_SQL_ExecuteQuery: Öffne Datenbankverbindung zu: " & $sDBPath)
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("Fehler beim Öffnen der Datenbank: " & @error & " - " & _SQLite_ErrMsg())
            _SetStatus("Fehler beim Öffnen der Datenbank")
            Return False
        EndIf
        $bWasOpened = True
    EndIf

    ; SQL-Typ bestimmen (SELECT oder andere Anweisung)
    If StringRegExp(StringUpper(StringStripWS($sSQL, 3)), "^\s*SELECT") Then
        ; SELECT-Abfrage ausführen
        Local $aResult, $iRows, $iColumns
        _LogInfo("Führe SELECT-Abfrage aus")

        Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

        ; Verbindung nur schließen, wenn wir sie selbst geöffnet haben
        If $bWasOpened Then _SQLite_Close($hDB)

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

        ; Verbindung nur schließen, wenn wir sie selbst geöffnet haben
        If $bWasOpened Then _SQLite_Close($hDB)

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
; Func.....: _ExtractTableFromSQL
; Beschreibung: Extrahiert den Tabellennamen aus einem SQL-Statement mittels RegEx
; Parameter.: $sSQL - SQL-Abfrage
; Rückgabe..: Tabellenname oder leerer String wenn nicht gefunden
; ===============================================================================================================================
Func _ExtractTableFromSQL($sSQL)
    _LogInfo("Extrahiere Tabellennamen aus SQL: " & StringLeft($sSQL, 50) & "...")

    ; Zeilenumbrüche normalisieren und Kommentare entfernen
    Local $sCleanedSQL = StringReplace($sSQL, @CRLF, " ")
    $sCleanedSQL = StringReplace($sCleanedSQL, @LF, " ")
    $sCleanedSQL = StringRegExpReplace($sCleanedSQL, "--.*", " ")

    ; RegEx für einfaches SELECT ... FROM tablename
    ; Auch mit Leerzeichen, Zeilenumbrüchen etc. zwischen den Teilen
    Local $sPattern = "(?i)\bSELECT\b[\s\S]*?\bFROM\b\s+([a-zA-Z0-9_]+)"

    Local $aMatches = StringRegExp($sCleanedSQL, $sPattern, $STR_REGEXPARRAYMATCH)
    If @error Then
        _LogInfo("Kein Tabellenname gefunden")
        Return ""
    EndIf

    ; Erster Treffer ist der Tabellenname
    _LogInfo("Tabellenname gefunden: " & $aMatches[0])
    Return $aMatches[0]
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
If $sDBPath = "" Or $sTable = "" Then
        _LogInfo("_GetTableColumns: Leerer Datenbankpfad oder Tabellenname")
    Return $aColumns
EndIf

    _LogInfo("_GetTableColumns: Hole Spalten für Tabelle '" & $sTable & "' aus DB '" & $sDBPath & "'")

; Prüfen, ob aktuell eine Datenbankverbindung besteht
Local $bNeedToConnect = True
If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
    ; Bereits verbunden
        $bNeedToConnect = False
    _LogInfo("_GetTableColumns: Datenbankverbindung besteht bereits")
    EndIf

; Datenbank öffnen falls notwendig
Local $hDB = -1 ; Standardhandle verwenden
Local $bWasOpened = False

    If $bNeedToConnect Then
    _LogInfo("_GetTableColumns: Öffne Datenbankverbindung")
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("_GetTableColumns: Konnte Datenbank nicht öffnen: " & $sDBPath)
            Return $aColumns
        EndIf
        $bWasOpened = True
    EndIf

    ; PRAGMA-Befehl ausführen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "PRAGMA table_info(" & $sTable & ");"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Verbindung nur schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogError("_GetTableColumns: Fehler beim Abrufen der Spalteninformationen: " & _SQLite_ErrMsg())
        Return $aColumns
    EndIf

    ; Spaltennamen extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    _LogInfo("_GetTableColumns: " & $iRows & " Spalten gefunden")
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

        ; Wenn das Autovervollständigungsfenster aktiv ist, Topmost-Status erneuern
        If $g_bAutoCompleteWindowVisible And $g_hAutoCompleteWindow <> 0 Then
            ; Fenster im Vordergrund halten
            WinSetOnTop($g_hAutoCompleteWindow, "", 1)  ; 1 = immer im Vordergrund

            ; Bei Bedarf Listeninhalt aktualisieren
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

    ; Für Debug - Tasten ausgeben
    ;_LogInfo("_WM_KEYDOWN: Key=" & $iKeyCode & ", hWnd=" & $hWnd)

    ; ===== Autovervollständigungs-Steuerung =====

    ; Nur wenn Autovervollständigung sichtbar
    If $g_bAutoCompleteWindowVisible Then
        ; ENTER oder TAB zum Übernehmen der Auswahl
        If $iKeyCode = 13 Or $iKeyCode = 9 Then  ; ENTER/TAB
            _LogInfo("ENTER/TAB: Übernehme Autovervollständigung")
            _ApplyAutoComplete()
            Return $GUI_RUNDEFMSG  ; Event verarbeitet
        EndIf

        ; ESC zum Schließen
        If $iKeyCode = 27 Then  ; ESC
            _LogInfo("ESC: Schließe Autovervollständigung")
            _CloseAutoCompleteWindow()
            Return $GUI_RUNDEFMSG  ; Event verarbeitet
        EndIf

        ; Pfeiltasten an Autovervollständigungsfenster weiterleiten
        If $iKeyCode = 38 Or $iKeyCode = 40 Then  ; Hoch(38)/Runter(40)
            If $g_hAutoCompleteWindow <> 0 Then
                _LogInfo("Pfeiltaste: Weiterleitung an Autovervollständigung")

                ; Aktuell ausgewählten Eintrag ermitteln
                Local $hListBox = GUICtrlGetHandle($g_idAutoCompleteListPopup)
                Local $iCurSel = _SendMessage($hListBox, $LB_GETCURSEL, 0, 0)

                ; Je nach Taste neue Auswahl berechnen
                If $iKeyCode = 38 Then  ; Hoch
                    $iCurSel = $iCurSel > 0 ? $iCurSel - 1 : 0
                Else  ; Runter
                    $iCurSel = $iCurSel < _SendMessage($hListBox, $LB_GETCOUNT, 0, 0) - 1 ? $iCurSel + 1 : $iCurSel
                EndIf

                ; Neue Auswahl setzen
                _SendMessage($hListBox, $LB_SETCURSEL, $iCurSel, 0)
                Return $GUI_RUNDEFMSG  ; Event verarbeitet
            EndIf
        EndIf
    EndIf

    ; ===== Autovervollständigung aktivieren =====

    ; STRG+LEERTASTE für Autovervollständigung
    If $iKeyCode = 32 And BitAND(_WinAPI_GetKeyState($VK_CONTROL), 0x8000) <> 0 Then
        _LogInfo("STRG+LEERTASTE: Aktiviere Autovervollständigung")
        _ShowCompletionList()
        Return $GUI_RUNDEFMSG  ; Event verarbeitet
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
        _LogInfo("Punkt erkannt: Aktiviere Autovervollständigung automatisch")
        Sleep(50)  ; Kurze Verzögerung zur Verarbeitung
        _ShowCompletionList()
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _ShowCompletionList
; Beschreibung: Zeigt das eigenständige Autovervollständigungsfenster an
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ShowCompletionList()
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return False

    ; Vorschläge ermitteln
    $g_aCurrentMatches = _GetCurrentWordAndMatches($g_iCurrentWordStart)
    If UBound($g_aCurrentMatches) = 0 Then
        ; Wenn keine Vorschläge vorhanden, verstecke Fenster falls sichtbar
        If $g_bAutoCompleteWindowVisible Then _HideAutoCompleteWindow()
        Return False
    EndIf

    ; Position für das Popup-Fenster ermitteln
    Local $aPositionInfo = _GetPositionForAutoComplete($g_iCurrentWordStart)
    Local $iXPos = $aPositionInfo[0]
    Local $iYPos = $aPositionInfo[1]

    ; Falls das Fenster bereits existiert, nur aktualisieren
    If $g_hAutoCompleteWindow <> 0 And WinExists($g_hAutoCompleteWindow) Then
        ; Fensterposition aktualisieren
        WinMove($g_hAutoCompleteWindow, "", $iXPos, $iYPos)

        ; Listeninhalt aktualisieren
        _UpdateAutoCompleteList()

        ; Fenster anzeigen falls unsichtbar
        If Not $g_bAutoCompleteWindowVisible Then
            WinSetState($g_hAutoCompleteWindow, "", @SW_SHOW)
            $g_bAutoCompleteWindowVisible = True
        EndIf
    Else
        ; Neues Fenster erstellen
        _CreateAutoCompleteWindow($iXPos, $iYPos)
    EndIf

    ; Immer Statusmeldung anzeigen
    _SetStatus("Autovervollst.: Pfeiltasten zum Navigieren, Enter/Tab zum Übernehmen, ESC zum Abbrechen")

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _CreateAutoCompleteWindow
; Beschreibung: Erstellt das eigenständige Autovervollständigungsfenster
; Parameter.: $iXPos, $iYPos - Position des Fensters
; Rückgabe..: Handle des Fensters
; ===============================================================================================================================
Func _CreateAutoCompleteWindow($iXPos, $iYPos)
    ; Altes Fenster schließen falls vorhanden
    If $g_hAutoCompleteWindow <> 0 And WinExists($g_hAutoCompleteWindow) Then
        GUIDelete($g_hAutoCompleteWindow)
    EndIf

    ; Berechne optimale Fensterbreite und -höhe basierend auf Inhalten
    Local $iWidth = 200 ; Mindestbreite
    Local $iMaxItemLen = 0

    ; Berechne die maximale Länge aller Einträge
    For $i = 0 To UBound($g_aCurrentMatches) - 1
        Local $iLen = StringLen($g_aCurrentMatches[$i])
        If $iLen > $iMaxItemLen Then $iMaxItemLen = $iLen
    Next

    ; Breitenberechnung (8 Pixel pro Zeichen + 20 Pixel Puffer)
    If $iMaxItemLen > 0 Then $iWidth = _Min(400, _Max(150, $iMaxItemLen * 8 + 20))

    ; Höhe basierend auf Anzahl der Einträge berechnen (19 Pixel pro Eintrag + 5 Pixel Puffer)
    Local $iHeight = _Min(300, _Max(50, UBound($g_aCurrentMatches) * 19 + 5))

    ; Fenster erstellen mit speziellen Styles
    ; - $WS_POPUP: Rahmenloses Popup-Fenster ohne Taskbar-Eintrag
    ; - $WS_EX_TOPMOST: Immer im Vordergrund
    ; - $WS_EX_TOOLWINDOW: Kein Taskbar-Eintrag
    $g_hAutoCompleteWindow = GUICreate("SQL Autovervollständigung", $iWidth, $iHeight, $iXPos, $iYPos, _
                                         BitOR($WS_POPUP, $WS_BORDER), _
                                         BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))

    ; Listbox erstellen, die das gesamte Fenster ausfüllt
    $g_idAutoCompleteListPopup = GUICtrlCreateList("", 0, 0, $iWidth, $iHeight, _
                                                      BitOR($LBS_NOTIFY, $WS_VSCROLL, $LBS_HASSTRINGS))

    ; Einträge hinzufügen
    _UpdateAutoCompleteList()

    ; Eigene Ereignisbehandlung registrieren
    GUISetOnEvent($GUI_EVENT_CLOSE, "_OnAutoCompleteClose", $g_hAutoCompleteWindow)

    ; Doppelklick auf Listbox registrieren
    Local $hListBox = GUICtrlGetHandle($g_idAutoCompleteListPopup)
    GUIRegisterMsg($WM_COMMAND, "_AC_WM_COMMAND")

    ; Fenster anzeigen
    GUISetState(@SW_SHOW, $g_hAutoCompleteWindow)
    $g_bAutoCompleteWindowVisible = True

    Return $g_hAutoCompleteWindow
EndFunc

; ===============================================================================================================================
; Func.....: _UpdateAutoCompleteList
; Beschreibung: Aktualisiert die Einträge in der Autovervollständigungsliste
; Parameter.: Keine
; Rückgabe..: True bei Erfolg
; ===============================================================================================================================
Func _UpdateAutoCompleteList()
    If Not $g_bAutoCompleteWindowVisible Or $g_idAutoCompleteListPopup = 0 Then Return False

    ; Liste leeren
    GUICtrlSetData($g_idAutoCompleteListPopup, "")

    ; Aktuelle Vorschläge hinzufügen
    For $i = 0 To UBound($g_aCurrentMatches) - 1
        GUICtrlSetData($g_idAutoCompleteListPopup, $g_aCurrentMatches[$i])
    Next

    ; Ersten Eintrag auswählen
    Local $hListBox = GUICtrlGetHandle($g_idAutoCompleteListPopup)
    _SendMessage($hListBox, $LB_SETCURSEL, 0, 0)

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _HideAutoCompleteWindow
; Beschreibung: Versteckt das Autovervollständigungsfenster
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _HideAutoCompleteWindow()
    If $g_hAutoCompleteWindow <> 0 And WinExists($g_hAutoCompleteWindow) Then
        ; Fenster verstecken
        WinSetState($g_hAutoCompleteWindow, "", @SW_HIDE)
        $g_bAutoCompleteWindowVisible = False
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _CloseAutoCompleteWindow
; Beschreibung: Schließt das Autovervollständigungsfenster vollständig
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _CloseAutoCompleteWindow()
    If $g_hAutoCompleteWindow <> 0 And WinExists($g_hAutoCompleteWindow) Then
        ; Fenster schließen
        GUIDelete($g_hAutoCompleteWindow)
        $g_hAutoCompleteWindow = 0
        $g_bAutoCompleteWindowVisible = False
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _OnAutoCompleteClose
; Beschreibung: Ereignisbehandlung für das Schließen des Autovervollständigungsfensters
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _OnAutoCompleteClose()
    $g_bAutoCompleteWindowVisible = False
    $g_hAutoCompleteWindow = 0
EndFunc

; ===============================================================================================================================
; Func.....: _AC_WM_COMMAND
; Beschreibung: Verarbeitet WM_COMMAND-Nachrichten für die Autovervollständigung
; Parameter.: Standard WM_COMMAND-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func _AC_WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    ; Nur für Autovervollständigungsfenster oder wenn dieses nicht existiert
    If $g_hAutoCompleteWindow = 0 Or $hWnd <> $g_hAutoCompleteWindow Then Return $GUI_RUNDEFMSG

    ; Listbox-Nachricht extrahieren
    Local $iCtrlID = BitAND($wParam, 0xFFFF) ; Low-Word = Control ID
    Local $iNotifyCode = BitShift($wParam, 16) ; High-Word = Notification code

    ; Überprüfen, ob es von unserer Listbox stammt
    If $iCtrlID = $g_idAutoCompleteListPopup Then
        ; Doppelklick erkennen (LBN_DBLCLK = 2)
        If $iNotifyCode = 2 Then
            _ApplyAutoComplete()
            Return $GUI_RUNDEFMSG
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _GetCurrentWordAndMatches
; Beschreibung: Ermittelt das aktuelle Wort unter dem Cursor und passende Vorschläge
; Parameter.: ByRef $iWordStart - Rückgabe der Startposition des Wortes
; Rückgabe..: Array mit passenden Vorschlägen
; ===============================================================================================================================
Func _GetCurrentWordAndMatches(ByRef $iWordStart)
    Local $aEmptyArray[0]

    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return $aEmptyArray

    ; Cursor-Position ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]

    ; Text holen
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Aktuelles Wort ermitteln
    Local $sCurrentWord = ""
    $iWordStart = $iCursorPos

    For $i = $iCursorPos - 1 To 0 Step -1
        Local $sChar = StringMid($sText, $i + 1, 1)
        If StringRegExp($sChar, "[^a-zA-Z0-9_]") Then
            $iWordStart = $i + 1
            ExitLoop
        EndIf
        $sCurrentWord = $sChar & $sCurrentWord
    Next

    ; Wenn kein Wort gefunden oder zu kurz
    If StringLen($sCurrentWord) < 1 Then Return $aEmptyArray

    ; Vorschläge suchen
    Return _FindAutoCompleteMatches($sCurrentWord)
EndFunc

; ===============================================================================================================================
; Func.....: _GetPositionForAutoComplete
; Beschreibung: Berechnet die optimale Position für das Autovervollständigungsfenster
; Parameter.: $iWordStart - Startposition des aktuellen Wortes
; Rückgabe..: Array [X, Y] mit den Koordinaten
; ===============================================================================================================================
Func _GetPositionForAutoComplete($iWordStart)
    _LogInfo("Berechne AutoComplete-Position für Cursor")
    
    ; RichEdit-Controls Position im Hauptfenster ermitteln
    Local $aRichEditPos = ControlGetPos($g_hGUI, "", $g_hSQLRichEdit)
    If Not IsArray($aRichEditPos) Then
        _LogInfo("Fehler: RichEdit-Position konnte nicht ermittelt werden")
        Local $aFallback[2] = [100, 100]
        Return $aFallback
    EndIf
    
    ; Client-zu-Screen-Koordinaten umrechnen
    Local $aWinPos = WinGetPos($g_hGUI)
    
    ; Die Position des Editfelds in Bildschirmkoordinaten
    Local $iEditX = $aWinPos[0] + $aRichEditPos[0]
    Local $iEditY = $aWinPos[1] + $aRichEditPos[1]
    
    ; Cursor-Position und Zeilen-/Spaltenindex ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]
    
    ; Text bis zur aktuellen Position holen
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    Local $sTextBeforeCursor = StringLeft($sText, $iCursorPos)
    
    ; Zeilenindex ermitteln (Anzahl der Zeilenumbrüche im Text vor dem Cursor)
    Local $iLineCount = StringRegExpReplace($sTextBeforeCursor, "[^\n]", "") 
    Local $iLineIndex = StringLen($iLineCount)
    
    ; Spaltenindex in der aktuellen Zeile ermitteln
    Local $iLastNewline = StringInStr($sTextBeforeCursor, @LF, 0, -1)
    Local $iColumnIndex = $iCursorPos - $iLastNewline
    If $iLastNewline = 0 Then $iColumnIndex = $iCursorPos
    
    ; Einfüge-Cursor-Position berechnen
    ; Wir nehmen etwa 10 Pixel pro Zeichen und 18 Pixel pro Zeile an
    Local $iCharWidth = 10 ; Durchschnittliche Zeichenbreite in Pixel
    Local $iLineHeight = 18 ; Durchschnittliche Zeilenhöhe in Pixel
    
    ; Bildschirmkoordinaten für die Position berechnen
    Local $iXPos = $iEditX + ($iColumnIndex * $iCharWidth)
    Local $iYPos = $iEditY + (($iLineIndex + 1) * $iLineHeight) ; +1 für Abstand zum Text
    
    ; Sicherstellen, dass das Fenster im sichtbaren Bereich bleibt
    If $iXPos + 200 > @DesktopWidth Then $iXPos = @DesktopWidth - 250
    If $iYPos + 150 > @DesktopHeight Then $iYPos = $iYPos - 170
    
    _LogInfo("Berechnete Position für Autovervollständigung: X=" & $iXPos & ", Y=" & $iYPos)
    
    ; Ergebnis zurückgeben
    Local $aResult[2] = [$iXPos, $iYPos]
    Return $aResult
EndFunc

; ===============================================================================================================================
; Func.....: _GetCurrentWordSuggestions
; Beschreibung: Hilfsfunktion für die Autovervollständigung (erzeugt Vorschläge)
; Parameter.: Keine
; Rückgabe..: Array mit Vorschlägen
; ===============================================================================================================================
Func _GetCurrentWordSuggestions()
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
; Beschreibung: Sucht passende Vorschläge für das aktuelle Wort
; Parameter.: $sCurrentWord - Aktuelles Wort unter dem Cursor
; Rückgabe..: Array mit passenden Vorschlägen
; ===============================================================================================================================
Func _FindAutoCompleteMatches($sCurrentWord)
    ; Leeres Array erstellen
    Local $aMatches[0]

    ; Prüfen ob überhaupt ein Wort vorhanden ist
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

    ; Debug-Ausgabe zum Kontext
    _LogInfo("Autovervollständigungs-Kontext - Tabellenkontext: " & $bIsTableContext & ", Spaltenkontext: " & $bIsColumnContext)

    ; Tabellennamen hinzufügen wenn relevant
    If $bIsTableContext Or (Not $bIsColumnContext) Then
        Local $sTables = GUICtrlRead($g_idTableCombo, 1)
        Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
        For $i = 0 To UBound($aTableList) - 1
            If $aTableList[$i] <> "" Then _ArrayAdd($aSQLKeywords, $aTableList[$i])
        Next
    EndIf

    ; Spaltennamen hinzufügen wenn relevant
    If $bIsColumnContext Or (Not $bIsTableContext) Then
        Local $sCurrentTable = GUICtrlRead($g_idTableCombo)
        If $sCurrentTable <> "" Then
            If UBound($g_aTableColumns) = 0 Then
                $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sCurrentTable)
            EndIf

            For $i = 0 To UBound($g_aTableColumns) - 1
                If $g_aTableColumns[$i] <> "" Then _ArrayAdd($aSQLKeywords, $g_aTableColumns[$i])
            Next
        EndIf
    EndIf

    ; Nach Übereinstimmungen suchen und in das Ergebnis-Array einfügen
    For $i = 0 To UBound($aSQLKeywords) - 1
        If StringLeft(StringUpper($aSQLKeywords[$i]), StringLen($sCurrentWord)) = $sCurrentWord Then
            _ArrayAdd($aMatches, $aSQLKeywords[$i])  ; Original-Schreibweise beibehalten
        EndIf
    Next

    ; Debug-Ausgabe
    _LogInfo("Autovervollständigung: " & UBound($aMatches) & " Vorschläge gefunden für '" & $sCurrentWord & "'")

    Return $aMatches
EndFunc

; ===============================================================================================================================
; Func.....: _ApplyAutoComplete
; Beschreibung: Wendet den ausgewählten Autovervollständigungs-Vorschlag an
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ApplyAutoComplete()
    ; Voraussetzungen prüfen
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return False
    If Not $g_bAutoCompleteWindowVisible Or $g_hAutoCompleteWindow = 0 Then Return False

    ; Ausgewählten Eintrag aus der Popup-Listbox holen
    Local $sSelected = GUICtrlRead($g_idAutoCompleteListPopup)
    If $sSelected = "" Then Return False

    ; Debug-Ausgabe
    _LogInfo("Popup-Autovervollständigung: '" & $sSelected & "' wird übernommen")

    ; Text und Cursor-Position holen
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Sicherstellen, dass die Wortposition bekannt ist
    If $g_iCurrentWordStart = 0 Or $g_iCurrentWordStart > $iCursorPos Then
        ; Wortposition neu ermitteln
        Local $sCurrentWord = ""
        $g_iCurrentWordStart = $iCursorPos

        For $i = $iCursorPos - 1 To 0 Step -1
            Local $sChar = StringMid($sText, $i + 1, 1)
            If StringRegExp($sChar, "[^a-zA-Z0-9_]") Then
                $g_iCurrentWordStart = $i + 1
                ExitLoop
            EndIf
            $sCurrentWord = $sChar & $sCurrentWord
        Next
    EndIf

    ; Aktuelles Wort aus dem Text extrahieren
    Local $sCurrentWord = StringMid($sText, $g_iCurrentWordStart, $iCursorPos - $g_iCurrentWordStart)
    _LogInfo("Ersetze Wort '" & $sCurrentWord & "' an Position " & $g_iCurrentWordStart & " bis " & $iCursorPos)

    ; Selektion setzen und Text ersetzen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $g_iCurrentWordStart, $iCursorPos)
    _GUICtrlRichEdit_ReplaceText($g_hSQLRichEdit, $sSelected)

    ; Cursor hinter das ersetzte Wort setzen
    Local $iNewPos = $g_iCurrentWordStart + StringLen($sSelected)
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iNewPos, $iNewPos)

    ; Autovervollständigungsfenster schließen
    _CloseAutoCompleteWindow()

    ; Fokus zurück auf RichEdit
    _WinAPI_SetFocus($g_hSQLRichEdit)

    ; Rückmeldung im Status
    _SetStatus("Text '" & $sCurrentWord & "' durch '" & $sSelected & "' ersetzt")

    ; Syntax-Highlighting aktualisieren
    _SQL_UpdateSyntaxHighlighting()

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _BlockAllSQLExecutions
; Beschreibung: Verhindert automatische SQL-Ausführungen
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _BlockAllSQLExecutions()
    $g_bUserInitiatedExecution = False
EndFunc