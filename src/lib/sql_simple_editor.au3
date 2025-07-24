; ===============================================================================================================================
; Titel.......: SQL-Editor (Vereinfacht)
; Beschreibung: Direkter, vereinfachter Ansatz für den SQL-Editor
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-11
; ===============================================================================================================================

#include <Array.au3>
#include <StringConstants.au3>
#include <ColorConstants.au3>
#include <GUIRichEdit.au3>
#include <WinAPIGdi.au3>

; Globale Variablen für den AdLib-Timer
Global $g_hSyntaxTimer = 0
Global $g_bSyntaxHighlightingActive = False

; ===============================================================================================================================
; Func.....: _SQL_SimpleSplit
; Beschreibung: Teilt SQL-Anweisungen an Semikolons auf (vereinfachte Methode)
; Parameter.: $sSQL - SQL-Anweisungen
; Rückgabe..: Array mit einzelnen SQL-Anweisungen
; ===============================================================================================================================
Func _SQL_SimpleSplit($sSQL)
    ; Verwende StringRegExp mit dem Pattern "(\w[^;]+;)" - jedes Wort gefolgt von allem bis zum Semikolon
    Local $aQueries = StringRegExp($sSQL, "(\w[^;]+;)", 4)
    
    ; Wenn keine Treffer, versuche es ohne Semikolon-Ende (für den Fall, dass der Benutzer es vergessen hat)
    If Not IsArray($aQueries) Or UBound($aQueries) = 0 Then
        ; Prüfe, ob Text vorhanden ist
        If StringStripWS($sSQL, $STR_STRIPALL) <> "" Then
            Local $aResult[1] = [$sSQL]
            Return $aResult
        Else
            Local $aEmpty[0]
            Return $aEmpty
        EndIf
    EndIf
    
    Return $aQueries
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsSelectQuery
; Beschreibung: Prüft, ob eine SQL-Anweisung eine SELECT-Abfrage ist
; Parameter.: $sSQL - SQL-Anweisung
; Rückgabe..: True für SELECT-Abfragen, False für andere
; ===============================================================================================================================
Func _SQL_IsSelectQuery($sSQL)
    Return StringRegExp(StringUpper($sSQL), "^\s*(SELECT|SHOW|USE)", 0) = 1
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_FixSpacing
; Beschreibung: Einfache Korrektur von Leerzeichen in SQL
; Parameter.: $sSQL - SQL-Anweisung
; Rückgabe..: Korrigierte SQL-Anweisung
; ===============================================================================================================================
Func _SQL_FixSpacing($sSQL)
    ; Füge Leerzeichen nach Keywords ein
    Local $aKeywords = ["SELECT", "FROM", "WHERE", "ORDER BY", "GROUP BY", "HAVING", "LIMIT", "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN"]
    
    For $sKeyword In $aKeywords
        ; Groß-/Kleinschreibung ignorieren und Leerzeichen hinzufügen
        $sSQL = StringRegExpReplace($sSQL, "(?i)" & $sKeyword & "(?=[^\s])", $sKeyword & " ")
    Next
    
    ; Sicherstellen, dass ein Leerzeichen nach Kommas steht
    $sSQL = StringRegExpReplace($sSQL, ",(?=[^\s])", ", ")
    
    Return $sSQL
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SimpleExecute
; Beschreibung: Vereinfachte SQL-Ausführung
; Parameter.: $sSQL - SQL-Anweisung(en)
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_SimpleExecute($sSQL)
    ; Datenbank prüfen
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        Return False
    EndIf
    
    ; SQL korrigieren
    $sSQL = _SQL_FixSpacing($sSQL)
    
    ; Anweisungen aufteilen
    Local $aQueries = _SQL_SimpleSplit($sSQL)
    If Not IsArray($aQueries) Or UBound($aQueries) = 0 Then
        _SetStatus("Keine gültigen SQL-Anweisungen gefunden")
        Return False
    EndIf
    
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        Return False
    EndIf
    
    ; Für Erfolgs-/Fehlerstatistik
    Local $iSuccess = 0
    Local $iError = 0
    Local $bHasResults = False
    
    ; Anweisungen ausführen
    For $i = 0 To UBound($aQueries) - 1
        Local $sQuery
        
        ; Wenn das Element ein Array ist (bei StringRegExp mit Capture-Gruppen)
        If IsArray($aQueries[$i]) Then
            $sQuery = $aQueries[$i][0]
        Else
            $sQuery = $aQueries[$i]
        EndIf
        
        ; Leerzeichen korrigieren (nochmals für jede Anweisung)
        $sQuery = _SQL_FixSpacing($sQuery)
        
        ; Abfragetyp erkennen
        Local $bIsSelect = _SQL_IsSelectQuery($sQuery)
        
        If $bIsSelect Then
            ; SELECT-Abfrage ausführen
            Local $aResult, $iRows, $iColumns
            Local $iRet = _SQLite_GetTable2d($hDB, $sQuery, $aResult, $iRows, $iColumns)
            
            If @error Or $iRet <> $SQLITE_OK Then
                _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
                $iError += 1
                ContinueLoop
            EndIf
            
            ; Ergebnisse anzeigen (nur für die letzte SELECT-Abfrage)
            If $i = UBound($aQueries) - 1 Or UBound($aQueries) = 1 Then
                ; ListView leeren
                _GUICtrlListView_DeleteAllItems($g_idListView)
                _DeleteAllListViewColumns($g_idListView)
                
                ; Spaltenüberschriften und Daten hinzufügen
                If $iRows > 0 Then
                    ; Spaltenüberschriften
                    For $j = 0 To $iColumns - 1
                        _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$j], 100)
                    Next
                    
                    ; Daten
                    For $j = 1 To $iRows
                        Local $iIndex = _GUICtrlListView_AddItem($g_idListView, $aResult[$j][0])
                        For $k = 1 To $iColumns - 1
                            _GUICtrlListView_AddSubItem($g_idListView, $iIndex, $aResult[$j][$k], $k)
                        Next
                    Next
                    
                    ; Spaltenbreiten anpassen
                    For $j = 0 To $iColumns - 1
                        _GUICtrlListView_SetColumnWidth($g_idListView, $j, $LVSCW_AUTOSIZE_USEHEADER)
                    Next
                    
                    $bHasResults = True
                EndIf
            EndIf
            
            $iSuccess += 1
        Else
            ; Andere Anweisungen ausführen
            Local $iRet = _SQLite_Exec($hDB, $sQuery)
            
            If @error Or $iRet <> $SQLITE_OK Then
                _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
                $iError += 1
                ContinueLoop
            EndIf
            
            $iSuccess += 1
        EndIf
    Next
    
    ; Datenbank schließen
    _SQLite_Close($hDB)
    
    ; Statusmeldung aktualisieren
    If $iError = 0 Then
        If $bHasResults Then
            _SetStatus("Abfragen erfolgreich: " & $iSuccess & " Anweisung(en) ausgeführt.")
        Else
            _SetStatus("Befehle erfolgreich: " & $iSuccess & " Anweisung(en) ausgeführt.")
        EndIf
        Return True
    Else
        _SetStatus("Ausführung mit Fehlern: " & $iSuccess & " erfolgreich, " & $iError & " fehlgeschlagen.")
        Return False
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_EnableSyntaxTimer
; Beschreibung: Aktiviert den Timer für die Syntax-Hervorhebung
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_EnableSyntaxTimer()
    If $g_bSyntaxHighlightingActive Then Return
    
    ; Timer alle 500ms für Syntax-Highlighting
    $g_hSyntaxTimer = AdlibRegister("_SQL_TimerSyntaxHighlight", 500)
    $g_bSyntaxHighlightingActive = True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_DisableSyntaxTimer
; Beschreibung: Deaktiviert den Timer für die Syntax-Hervorhebung
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_DisableSyntaxTimer()
    If Not $g_bSyntaxHighlightingActive Then Return
    
    AdlibUnRegister("_SQL_TimerSyntaxHighlight")
    $g_bSyntaxHighlightingActive = False
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_TimerSyntaxHighlight
; Beschreibung: Timer-Funktion für Syntax-Hervorhebung
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_TimerSyntaxHighlight()
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return
    
    _SQL_ApplySyntaxHighlighting()
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ApplySyntaxHighlighting
; Beschreibung: Wendet Syntax-Hervorhebung auf den aktuellen Text an
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ApplySyntaxHighlighting()
    ; Aktuellen Text und Cursor-Position holen
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If $sText = "" Then Return
    
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iSelStart = $aSel[0]
    Local $iSelEnd = $aSel[1]
    
    ; Aktuelle Selektion deaktivieren, um Cursor zu merken
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iSelStart, $iSelStart)
    
    ; Text zwischenspeichern
    Local $sOrigText = $sText
    
    ; Keywords für Hervorhebung
    Local $aKeywords = ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "JOIN", "GROUP", "ORDER", "BY", "HAVING", _
                        "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "TRIGGER", "PRAGMA", "ON", "AND", "OR", "NOT", _
                        "NULL", "IS", "IN", "BETWEEN", "LIKE", "GLOB", "LIMIT", "DISTINCT", "ALL", "UNION", "CASE", "WHEN", _
                        "THEN", "ELSE", "END", "EXISTS", "INTO", "VALUES", "SET", "FOREIGN", "PRIMARY", "KEY", "REFERENCES", _
                        "DEFAULT", "UNIQUE", "CHECK", "CONSTRAINT", "DESC", "ASC"]
    
    ; RichEdit leeren
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")
    
    ; Text Zeichen für Zeichen durchgehen und Keywords farbig markieren
    Local $iPos = 1
    Local $iLen = StringLen($sOrigText)
    Local $sWord = ""
    Local $bInWord = False
    
    While $iPos <= $iLen
        Local $sChar = StringMid($sOrigText, $iPos, 1)
        
        ; Wenn alphanumerisches Zeichen oder Unterstrich, Teil eines Wortes
        If StringRegExp($sChar, "[a-zA-Z0-9_]") = 1 Then
            $sWord &= $sChar
            $bInWord = True
        Else
            ; Wenn Ende eines Wortes erreicht
            If $bInWord Then
                ; Prüfen, ob es ein Keyword ist
                Local $bIsKeyword = False
                For $sKeyword In $aKeywords
                    If StringUpper($sWord) = $sKeyword Then
                        ; Als Keyword hinzufügen (blau)
                        _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x0000FF)
                        _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sWord)
                        $bIsKeyword = True
                        ExitLoop
                    EndIf
                Next
                
                ; Wenn kein Keyword, normale Farbe
                If Not $bIsKeyword Then
                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000)
                    _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sWord)
                EndIf
                
                $sWord = ""
                $bInWord = False
            EndIf
            
            ; Zeichenfarbe für Sonderzeichen
            Switch $sChar
                Case "'", '"'  ; String-Begrenzung
                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x008000)  ; Grün
                Case ";", ",", "(", ")", "=", "+", "-", "*", "/", "<", ">"  ; Operatoren und Trennzeichen
                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x800080)  ; Lila
                Case Else      ; Andere Zeichen (Leerzeichen, etc.)
                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000)  ; Schwarz
            EndSwitch
            
            ; Zeichen hinzufügen
            _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sChar)
        EndIf
        
        $iPos += 1
    WEnd
    
    ; Letztes Wort prüfen (falls Text mit einem Wort endet)
    If $bInWord Then
        ; Prüfen, ob es ein Keyword ist
        Local $bIsKeyword = False
        For $sKeyword In $aKeywords
            If StringUpper($sWord) = $sKeyword Then
                ; Als Keyword hinzufügen
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x0000FF)
                _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sWord)
                $bIsKeyword = True
                ExitLoop
            EndIf
        Next
        
        ; Wenn kein Keyword, normale Farbe
        If Not $bIsKeyword Then
            _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000)
            _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sWord)
        EndIf
    EndIf
    
    ; Cursor-Position wiederherstellen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iSelStart, $iSelEnd)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SimpleTableChange
; Beschreibung: Einfache Handler-Funktion für Tabellenwechsel
; Parameter.: $sTable - Name der Tabelle
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SimpleTableChange($sTable)
    If $sTable = "" Then Return
    
    ; SQL-Text mit korrekten Leerzeichen erstellen
    Local $sSQL = "SELECT * FROM " & $sTable & " LIMIT 100;"
    
    ; Text setzen
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
    
    ; Syntax-Highlighting explizit aufrufen
    _SQL_ApplySyntaxHighlighting()
    
    ; SQL sofort ausführen
    _SQL_SimpleExecute($sSQL)
    
    ; Tabellenspalten für Autovervollständigung laden
    $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sTable)
EndFunc
