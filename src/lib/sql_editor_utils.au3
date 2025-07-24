; ===============================================================================================================================
; Func.....: _GetAllDatabaseMetadata
; Beschreibung: Liest alle Tabellen- und Spaltennamen einer SQLite-Datenbank in einem Durchlauf
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Mehrdimensionales Array mit Tabellen und deren Spalten oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetAllDatabaseMetadata($sDBPath)
    If $sDBPath = "" Then
        _LogError("_GetAllDatabaseMetadata: Leerer Datenbankpfad")
        Local $aEmpty[0][0]
        Return $aEmpty
    EndIf
    
    _LogInfo("_GetAllDatabaseMetadata: Lese alle Metadaten aus DB '" & $sDBPath & "'")
    
    ; Prüfen, ob aktuell eine Datenbankverbindung besteht
    Local $bNeedToConnect = True
    If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
        $bNeedToConnect = False
        _LogInfo("_GetAllDatabaseMetadata: Datenbankverbindung besteht bereits")
    EndIf
    
    ; Datenbank öffnen falls notwendig
    Local $hDB = -1 ; Standardhandle verwenden
    Local $bWasOpened = False
    
    If $bNeedToConnect Then
        _LogInfo("_GetAllDatabaseMetadata: Öffne Datenbankverbindung")
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("_GetAllDatabaseMetadata: Konnte Datenbank nicht öffnen: " & $sDBPath)
            Local $aEmpty[0][0]
            Return $aEmpty
        EndIf
        $bWasOpened = True
    EndIf
    
    ; Ein einziges SQL-Statement, um alle Tabellen zu ermitteln
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    Local $aResult, $iRows, $iColumns
    
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
    
    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogError("_GetAllDatabaseMetadata: Fehler beim Abrufen der Tabellen: " & _SQLite_ErrMsg())
        If $bWasOpened Then _SQLite_Close($hDB)
        Local $aEmpty[0][0]
        Return $aEmpty
    EndIf
    
    ; Metadaten-Array initialisieren: [TabellenIndex][0]=Tabellenname, [TabellenIndex][1...n]=Spaltennamen
    Local $aMetadata[$iRows][1]
    
    ; Tabellennamen extrahieren
    For $i = 0 To $iRows - 1
        $aMetadata[$i][0] = $aResult[$i+1][0] ; +1 wegen Header-Zeile in $aResult
    Next
    
    ; Für jede Tabelle die Spalteninformationen abrufen und ins Array einfügen
    For $i = 0 To $iRows - 1
        Local $sTableName = $aMetadata[$i][0]
        _LogInfo("_GetAllDatabaseMetadata: Lese Spalten für Tabelle '" & $sTableName & "'")
        
        ; PRAGMA table_info verwenden, um Spalten zu ermitteln
        Local $sColSQL = "PRAGMA table_info(" & $sTableName & ")"
        Local $aColResult, $iColRows, $iColColumns
        
        Local $iColRet = _SQLite_GetTable2d($hDB, $sColSQL, $aColResult, $iColRows, $iColColumns)
        
        If @error Or $iColRet <> $SQLITE_OK Or $iColRows = 0 Then
            _LogError("_GetAllDatabaseMetadata: Fehler beim Abrufen der Spalten für '" & $sTableName & "': " & _SQLite_ErrMsg())
            ContinueLoop
        EndIf
        
        ; Spaltenarray dimensionieren
        ReDim $aMetadata[$iRows][$iColRows + 1] ; +1 für Tabellenname in [0]
        
        ; Spaltennamen extrahieren und ins Array einfügen
        For $j = 0 To $iColRows - 1
            $aMetadata[$i][$j + 1] = $aColResult[$j+1][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
        Next
    Next
    
    ; Verbindung nur schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)
    
    _LogInfo("_GetAllDatabaseMetadata: Metadaten für " & $iRows & " Tabellen erfolgreich gelesen")
    Return $aMetadata
EndFunc

; Globales Metadaten-Cache-Array
Global $g_aMetadataCache[0][2] ; [0]=DBPath, [1]=Metadaten-Array

; ===============================================================================================================================
; Func.....: _GetMetadataFromCache
; Beschreibung: Holt Metadaten aus dem Cache oder lädt sie neu
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Metadaten-Array oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetMetadataFromCache($sDBPath)
    ; Im Cache suchen
    For $i = 0 To UBound($g_aMetadataCache) - 1
        If $g_aMetadataCache[$i][0] = $sDBPath Then
            _LogInfo("_GetMetadataFromCache: Metadaten für '" & $sDBPath & "' aus Cache geholt")
            Return $g_aMetadataCache[$i][1]
        EndIf
    Next
    
    ; Nicht im Cache, neu laden
    Local $aMetadata = _GetAllDatabaseMetadata($sDBPath)
    
    ; In Cache speichern
    Local $iSize = UBound($g_aMetadataCache)
    ReDim $g_aMetadataCache[$iSize + 1][2]
    $g_aMetadataCache[$iSize][0] = $sDBPath
    $g_aMetadataCache[$iSize][1] = $aMetadata
    
    _LogInfo("_GetMetadataFromCache: Metadaten für '" & $sDBPath & "' in Cache gespeichert")
    Return $aMetadata
EndFunc; Titel.......: SQL-Editor-Hilfsfunktionen
; Beschreibung: Hilfsfunktionen für den optimierten SQL-Editor mit einer ComboBox
; Autor.......: Ralle1976 (optimiert)
; Erstellt....: 2025-04-14
; Aktualisiert: 2025-04-24 - Verbesserte Autovervollständigung
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

; Eigene Include-Dateien
; Neue verbesserte Autovervollständigung wird in sql_editor_enhanced.au3 eingebunden

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
Global $g_aTableColumns ; Array mit Spaltennamen
Global $g_idListView ; ListView-ID
Global $g_idStatus ; Status-ID
Global $g_sCurrentDB ; Aktuelle Datenbank
Global $g_sCurrentTable ; Aktuell ausgewählte Tabelle

; Referenzen zu Variablen in sql_autocomplete.au3
Global $g_hList ; Handle der Autovervollständigungs-Liste
Global $g_bAutoCompleteActive ; Status der Autovervollständigung

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

        ; Nach Schema-Änderungen suchen und Metadaten aktualisieren
        If StringRegExp(StringUpper($sSQL), "\b(CREATE|ALTER|DROP)\b.*\b(TABLE|VIEW|INDEX)\b") Then
            _LogInfo("Schema-Änderung erkannt, aktualisiere Metadaten")
            _SQL_CheckForSchemaChanges($sDBPath)
        EndIf

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
; Beschreibung: Ermittelt die Spalten einer Tabelle (optimierte Version mit Metadaten-Cache)
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: Array mit Spaltennamen
; ===============================================================================================================================
Func _GetTableColumns($sDBPath, $sTable)
    _LogInfo("_GetTableColumns: Suche Spalten für Tabelle '" & $sTable & "' in Metadaten-Cache")
    
    ; Metadaten aus Cache holen
    Local $aMetadata = _GetMetadataFromCache($sDBPath)
    If UBound($aMetadata, 0) < 2 Then
        _LogError("_GetTableColumns: Keine Metadaten im Cache gefunden")
        Return _GetTableColumnsDirectly($sDBPath, $sTable) ; Fallback auf direkte Abfrage
    EndIf
    
    ; Tabelle in Metadaten suchen
    For $i = 0 To UBound($aMetadata) - 1
        If $aMetadata[$i][0] = $sTable Then
            ; Tabelle gefunden, Spalten in Array kopieren
            Local $iColumnCount = UBound($aMetadata, 2) - 1 ; -1 wegen Tabellenname in [0]
            Local $aColumns[$iColumnCount]
            
            For $j = 0 To $iColumnCount - 1
                $aColumns[$j] = $aMetadata[$i][$j + 1] ; +1 wegen Tabellenname in [0]
            Next
            
            _LogInfo("_GetTableColumns: " & $iColumnCount & " Spalten für '" & $sTable & "' aus Cache geholt")
            Return $aColumns
        EndIf
    Next
    
    _LogError("_GetTableColumns: Tabelle '" & $sTable & "' nicht in Metadaten gefunden")
    Return _GetTableColumnsDirectly($sDBPath, $sTable) ; Fallback auf direkte Abfrage
EndFunc

; ===============================================================================================================================
; Func.....: _GetTableColumnsDirectly
; Beschreibung: Ermittelt die Spalten einer Tabelle direkt aus der Datenbank (Fallback)
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: Array mit Spaltennamen
; ===============================================================================================================================
Func _GetTableColumnsDirectly($sDBPath, $sTable)
    Local $aColumns[0]
    If $sDBPath = "" Or $sTable = "" Then
        _LogInfo("_GetTableColumnsDirectly: Leerer Datenbankpfad oder Tabellenname")
        Return $aColumns
    EndIf

    _LogInfo("_GetTableColumnsDirectly: Hole Spalten direkt für Tabelle '" & $sTable & "' aus DB '" & $sDBPath & "'")

    ; Prüfen, ob aktuell eine Datenbankverbindung besteht
    Local $bNeedToConnect = True
    If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
        ; Bereits verbunden
        $bNeedToConnect = False
        _LogInfo("_GetTableColumnsDirectly: Datenbankverbindung besteht bereits")
    EndIf

    ; Datenbank öffnen falls notwendig
    Local $hDB = -1 ; Standardhandle verwenden
    Local $bWasOpened = False

    If $bNeedToConnect Then
        _LogInfo("_GetTableColumnsDirectly: Öffne Datenbankverbindung")
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("_GetTableColumnsDirectly: Konnte Datenbank nicht öffnen: " & $sDBPath)
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
        _LogError("_GetTableColumnsDirectly: Fehler beim Abrufen der Spalteninformationen: " & _SQLite_ErrMsg())
        Return $aColumns
    EndIf

    ; Spaltennamen extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    _LogInfo("_GetTableColumnsDirectly: " & $iRows & " Spalten direkt gelesen")
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

    ; An die verbesserte Autovervollständigung weiterleiten
    If _HandleSQLAutocompleteKeys($hWnd, $iMsg, $wParam, $lParam) Then
        Return $GUI_RUNDEFMSG  ; Event wurde verarbeitet
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
        ; Verzögerung zur Verarbeitung
        Sleep(50)
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _InitSQLEditorAutocomplete
; Beschreibung: Initialisiert die verbesserte SQL-Autovervollständigung
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _InitSQLEditorAutocomplete()
    ; Initialisiere die Autovervollständigung mit dem RichEdit-Control und GUI-Handle
    _LogInfo("Initialisiere SQL-Editor-Autovervollständigung")
    _InitSQLAutoComplete($g_hGUI, $g_hSQLRichEdit)
    
    ; Aktiviere die Auto-Completion-Überwachung
    _StartSQLAutoComplete()
    
    _LogInfo("SQL-Autovervollständigung aktiviert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _ShowSQLCompletionList
; Beschreibung: Öffentliche Funktion zum Anzeigen der Autovervollständigungsliste
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ShowSQLCompletionList()
    _LogInfo("Manuelle Aktivierung der SQL-Autovervollständigung")
    
    ; Aktuellen Text und Cursor-Position prüfen
    If Not $g_bSQLEditorMode Or Not IsHWnd($g_hSQLRichEdit) Then Return

    ; Forciere eine sofortige Aktualisierung der Autovervollständigungsliste
    _CheckSQLInputForAutoComplete()
    
    _LogInfo("Autovervollständigungsliste angezeigt")
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