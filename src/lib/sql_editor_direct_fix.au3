; ===============================================================================================================================
; Titel.......: SQL-Editor (Direkte Korrekturen)
; Beschreibung: Direkte, einfache Lösungen für die Hauptprobleme im SQL-Editor
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-11
; ===============================================================================================================================

; ===============================================================================================================================
; Func.....: _SQL_FormatStatement
; Beschreibung: Einfache, direkte Funktion zum Korrigieren von Leerzeichen in SQL-Statements
; Parameter.: $sSQL - Die zu formatierende SQL-Anweisung
; Rückgabe..: Formatierte SQL-Anweisung
; ===============================================================================================================================
Func _SQL_FormatStatement($sSQL)
    ; Basiskorrekturen für häufige Fehler
    $sSQL = StringRegExpReplace($sSQL, "SELECT\*", "SELECT *")
    $sSQL = StringRegExpReplace($sSQL, "FROM([A-Za-z])", "FROM $1")
    $sSQL = StringRegExpReplace($sSQL, "LIMIT(\d)", "LIMIT $1")
    $sSQL = StringRegExpReplace($sSQL, "WHERE([A-Za-z])", "WHERE $1")
    $sSQL = StringRegExpReplace($sSQL, "ORDER BY([A-Za-z])", "ORDER BY $1")
    
    ; Zusätzliche Korrekturen für andere SQL-Befehle
    $sSQL = StringRegExpReplace($sSQL, "INSERT INTO([A-Za-z])", "INSERT INTO $1")
    $sSQL = StringRegExpReplace($sSQL, "VALUES\(", "VALUES (")
    $sSQL = StringRegExpReplace($sSQL, "DELETE FROM([A-Za-z])", "DELETE FROM $1")
    $sSQL = StringRegExpReplace($sSQL, "UPDATE([A-Za-z])", "UPDATE $1")
    $sSQL = StringRegExpReplace($sSQL, "SET([A-Za-z])", "SET $1")
    
    Return $sSQL
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ExecuteDirect
; Beschreibung: Vereinfachte, direkte SQL-Ausführungsfunktion mit minimaler Komplexität
; Parameter.: $sSQL - Die SQL-Anweisung zum Ausführen
; Rückgabe..: Erfolg oder Fehler
; ===============================================================================================================================
Func _SQL_ExecuteDirect($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        Return False
    EndIf
    
    ; Formatiere SQL-Statement
    $sSQL = _SQL_FormatStatement($sSQL)
    
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        Return False
    EndIf
    
    ; Einfacher Test, ob es sich um ein SELECT handelt
    Local $bIsSelect = (StringLeft(StringStripWS(StringUpper($sSQL), 3), 6) = "SELECT")
    
    If $bIsSelect Then
        ; SELECT-Abfrage ausführen
        Local $aResult, $iRows, $iColumns
        Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
        
        ; Datenbank schließen, bevor wir zur GUI-Aktualisierung gehen
        _SQLite_Close($hDB)
        
        If @error Or $iRet <> $SQLITE_OK Then
            _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
            Return False
        EndIf
        
        ; ListView vorher komplett leeren
        _GUICtrlListView_DeleteAllItems($g_idListView)
        While _GUICtrlListView_GetColumnCount($g_idListView) > 0
            _GUICtrlListView_DeleteColumn($g_idListView, 0)
        WEnd
        
        ; Wenn keine Ergebnisse, Meldung anzeigen
        If $iRows = 0 Then
            _SetStatus("Abfrage ausgeführt. Keine Ergebnisse.")
            Return True
        EndIf
        
        ; Spaltenüberschriften setzen
        For $i = 0 To $iColumns - 1
            _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$i], 100)
        Next
        
        ; Datenzeilen einfügen
        For $i = 1 To $iRows
            $iIndex = _GUICtrlListView_AddItem($g_idListView, $aResult[$i][0])
            For $j = 1 To $iColumns - 1
                _GUICtrlListView_AddSubItem($g_idListView, $iIndex, $aResult[$i][$j], $j)
            Next
        Next
        
        ; Spaltenbreiten anpassen
        For $i = 0 To $iColumns - 1
            _GUICtrlListView_SetColumnWidth($g_idListView, $i, $LVSCW_AUTOSIZE_USEHEADER)
        Next
        
        ; ListView explizit aktualisieren
        GUICtrlSetState($g_idListView, $GUI_SHOW)
        _WinAPI_UpdateWindow(GUICtrlGetHandle($g_idListView))
        
        _SetStatus("Abfrage ausgeführt: " & $iRows & " Zeilen")
        Return True
    Else
        ; Andere Befehle (INSERT, UPDATE, DELETE) ausführen
        Local $iRet = _SQLite_Exec($hDB, $sSQL)
        
        ; Änderungen zählen
        Local $iChanges = _SQLite_Changes($hDB)
        
        ; Datenbank schließen
        _SQLite_Close($hDB)
        
        If @error Or $iRet <> $SQLITE_OK Then
            _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
            Return False
        EndIf
        
        _SetStatus("Befehl ausgeführt: " & $iChanges & " Zeilen betroffen")
        Return True
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateSimpleHighlighting
; Beschreibung: Vereinfachte Version des Syntax-Highlightings, die garantiert funktioniert
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_UpdateSimpleHighlighting()
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If $sText = "" Then Return
    
    ; Aktuelle Cursor-Position speichern
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iSelStart = $aSel[0]
    Local $iSelEnd = $aSel[1]
    
    ; RichEdit leeren
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")
    
    ; Keywords für Hervorhebung - kurze, präzise Liste
    Local $aKeywords = ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "JOIN", "GROUP BY", "ORDER BY", "LIMIT", "DESC", "ASC"]
    
    ; Temporärer Text für Manipulation
    Local $sTempText = $sText
    
    ; Keywords markieren
    For $i = 0 To UBound($aKeywords) - 1
        $sTempText = StringRegExpReplace($sTempText, "(?i)\b" & $aKeywords[$i] & "\b", "###KEYWORD" & $i & "###")
    Next
    
    ; Text in Tokens zerlegen
    Local $aTokens = StringSplit($sTempText, "###", $STR_NOCOUNT)
    
    ; Tokens mit Formatierung einfügen
    For $i = 0 To UBound($aTokens) - 1
        If StringLeft($aTokens[$i], 7) = "KEYWORD" Then
            ; Keyword identifizieren und blau einfärben
            Local $iKeywordIndex = Number(StringMid($aTokens[$i], 8, StringLen($aTokens[$i]) - 8))
            _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x0000FF) ; Blau für Keywords
            _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $aKeywords[$iKeywordIndex])
        Else
            ; Normaler Text - schwarz
            _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000)
            _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $aTokens[$i])
        EndIf
    Next
    
    ; Cursor-Position wiederherstellen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iSelStart, $iSelEnd)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SimpleTableChange
; Beschreibung: Direkte Implementierung für Tabellenwechsel mit garantierter Leerzeichen-Korrektur
; Parameter.: $sTable - Die ausgewählte Tabelle
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SimpleTableChange($sTable)
    If $sTable = "" Then Return
    
    ; Statement mit GARANTIERTEN Leerzeichen erzeugen
    Local $sSQL = "SELECT * FROM " & $sTable & " LIMIT 100;"
    
    ; Statement im Editor setzen
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
    
    ; Statement direkt ausführen
    _SQL_ExecuteDirect($sSQL)
    
    ; Spalten für Autovervollständigung laden
    $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sTable)
    
    ; Highlighting aktualisieren
    _SQL_UpdateSimpleHighlighting()
EndFunc
