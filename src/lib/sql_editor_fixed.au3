; Neue optimierte SQL-Funktionen

; ===============================================================================================================================
; Func.....: _SQL_FixQuerySpacing
; Beschreibung: Korrigiert Leerzeichen in SQL-Abfragen
; Parameter.: $sSQL - SQL-Abfrage
; Rückgabe..: Korrigierte SQL-Abfrage
; ===============================================================================================================================
Func _SQL_FixQuerySpacing($sSQL)
    ; Korrigiere fehlende Leerzeichen nach SQL-Schlüsselwörtern
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT|FROM|WHERE|GROUP BY|ORDER BY|LIMIT|JOIN|ON|AND|OR|HAVING|UNION|CASE|WHEN)(?=[^\s])", "$1 ")
    
    ; Korrigiere fehlendes Leerzeichen um Operatoren
    $sSQL = StringRegExpReplace($sSQL, "([^\s])(\=|\<|\>|\+|\-|\*|\/|\%)([^\s])", "$1 $2 $3")
    
    Return $sSQL
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ExecuteQueries_Fixed
; Beschreibung: Verbesserte Version von _SQL_ExecuteQueries mit automatischer Korrektur von Leerzeichen
; Parameter.: $sSQL - Ein oder mehrere SQL-Anweisungen, getrennt durch Semikolon
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_ExecuteQueries_Fixed($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Abfrage fehlgeschlagen: Keine Datenbank ausgewählt")
        Return SetError(1, 0, False)
    EndIf

    ; Statusmeldung setzen
    _SetStatus("Führe SQL-Anweisungen aus...")

    ; Sicherstellen, dass korrekte Leerzeichen in SQL-Anweisung sind
    $sSQL = _SQL_FixQuerySpacing($sSQL)
    _LogInfo("Korrigierte SQL-Anweisung: " & $sSQL)

    ; Anweisungen trennen (Semikolons innerhalb von Strings berücksichtigen)
    Local $aQueries = _SQL_SplitQueries($sSQL)
    If @error Then
        _SetStatus("Fehler beim Parsen der SQL-Anweisungen: " & @error)
        Return SetError(2, 0, False)
    EndIf

    Local $bHasResults = False
    Local $iSuccessCount = 0
    Local $iErrorCount = 0

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        Return SetError(3, 0, False)
    EndIf

    ; Transaktion beginnen
    _SQLite_Exec($hDB, "BEGIN TRANSACTION;")

    ; Jede Anweisung einzeln ausführen
    For $i = 0 To UBound($aQueries) - 1
        Local $sQuery = $aQueries[$i]
        $sQuery = StringStripWS($sQuery, $STR_STRIPTRAILING)
        
        ; Leere Queries überspringen
        If $sQuery = "" Then ContinueLoop
        
        ; Nochmal Leerzeichen korrigieren für jede einzelne Query
        $sQuery = _SQL_FixQuerySpacing($sQuery)
        _LogInfo("Verarbeite Query #" & ($i+1) & ": " & $sQuery)
        
        ; Prüfen, ob es sich um eine SELECT-Abfrage handelt
        Local $bIsSelect = StringRegExp(StringUpper($sQuery), "^\s*SELECT")
        
        If $bIsSelect Then
            ; SELECT-Abfrage ausführen und Ergebnisse anzeigen
            Local $aResult, $iRows, $iColumns
            _LogInfo("Führe SELECT-Abfrage aus: " & $sQuery)
            Local $iRet = _SQLite_GetTable2d($hDB, $sQuery, $aResult, $iRows, $iColumns)
            
            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf
            
            ; Anzeigen der Ergebnisse für die letzte Abfrage oder wenn es die einzige ist
            If $i = UBound($aQueries) - 1 Or UBound($aQueries) = 1 Then
                _LogInfo("Zeige Ergebnisse der SQL-Abfrage: " & $iRows & " Zeilen, " & $iColumns & " Spalten")
                
                ; ListView leeren
                _GUICtrlListView_DeleteAllItems($g_idListView)
                _DeleteAllListViewColumns($g_idListView)
                
                ; Wenn keine Ergebnisse, Meldung anzeigen
                If $iRows = 0 Then
                    _SetStatus("Abfrage ausgeführt. Keine Ergebnisse gefunden.")
                    $iSuccessCount += 1
                    $bHasResults = False
                    ContinueLoop
                EndIf
                
                ; Spaltenüberschriften zur ListView hinzufügen
                For $j = 0 To $iColumns - 1
                    _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$j], 100)
                Next
                
                ; Daten zur ListView hinzufügen
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
                
                ; Sicherstellen, dass die ListView aktualisiert wird
                GUICtrlSetState($g_idListView, $GUI_SHOW)
                _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
                _LogInfo("ListView aktualisiert mit " & $iRows & " Zeilen und " & $iColumns & " Spalten")
                
                $bHasResults = True
            EndIf
            
            $iSuccessCount += 1
        Else
            ; Andere Anweisungen ausführen (INSERT, UPDATE, DELETE, etc.)
            _LogInfo("Führe Non-SELECT-Anweisung aus: " & $sQuery)
            Local $iRet = _SQLite_Exec($hDB, $sQuery)
            
            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler bei Non-SELECT: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf
            
            $iSuccessCount += 1
        EndIf
    Next

    ; Transaktion abschließen
    _SQLite_Exec($hDB, "COMMIT;")

    ; Anzahl der betroffenen Zeilen ermitteln
    Local $iChanges = _SQLite_Changes($hDB)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    ; Nach dem Schließen der Datenbank: ListView nochmals explizit aktualisieren
    If $bHasResults Then
        ; Sicherstellen, dass ListView sichtbar und aktualisiert ist
        GUICtrlSetState($g_idListView, $GUI_SHOW)
        _LogInfo("Erzwinge abschließendes Neuzeichnen der ListView")
        _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
    EndIf

    ; Statusmeldung aktualisieren
    If $iErrorCount = 0 Then
        If $bHasResults Then
            _SetStatus("Alle Abfragen erfolgreich ausgeführt. " & $iSuccessCount & " Anweisungen.")
        Else
            _SetStatus("Alle Anweisungen erfolgreich ausgeführt. " & $iChanges & " Zeilen betroffen.")
        EndIf
        _LogInfo("SQL-Anweisungen erfolgreich ausgeführt. " & $iSuccessCount & " Anweisungen, " & $iChanges & " Zeilen betroffen.")
        Return True
    Else
        _SetStatus("Ausführung mit Fehlern abgeschlossen. " & $iSuccessCount & " erfolgreich, " & $iErrorCount & " fehlgeschlagen.")
        _LogWarning("SQL-Anweisungen teilweise fehlgeschlagen. " & $iSuccessCount & " erfolgreich, " & $iErrorCount & " fehlgeschlagen.")
        Return False
    EndIf
EndFunc
