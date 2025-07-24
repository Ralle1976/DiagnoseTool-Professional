; ===============================================================================================================================
; Func.....: _SQL_ExecuteQuery
; Beschreibung: Führt eine SQL-Abfrage aus und zeigt Ergebnisse in der ListView an
; Parameter.: $sSQL - SQL-Abfrage
;             $sDBPath - Pfad zur Datenbank
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_ExecuteQuery($sSQL, $sDBPath)
    ; WICHTIG: Diese Funktion ist der zentrale Punkt für SQL-Ausführungen
    ; Sie sollte NUR direkt vom Execute-Button aufgerufen werden

    ; NOTFALLSTOP: Nur erlauben, wenn $g_bUserInitiatedExecution gesetzt ist
    If Not $g_bUserInitiatedExecution Then
        _LogInfo("KRITISCH: SQL-Ausführung blockiert - nicht manuell vom Benutzer initiiert!")
        _SetStatus("Bitte nur den 'Ausführen'-Button verwenden")
        Return False
    EndIf

    ; Klare Protokollierung der Ausführung
    _LogInfo("**********************************************************")
    _LogInfo("* MANUELL AUSGELÖSTE SQL-AUSFÜHRUNG - BEGINN             *")
    _LogInfo("**********************************************************")

    ; Basisdaten prüfen
    If $sDBPath = "" Then
        _LogInfo("SQL-Ausführung fehlgeschlagen: Keine Datenbank angegeben")
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        Return False
    EndIf

    If $sSQL = "" Then
        _LogInfo("SQL-Ausführung fehlgeschlagen: Keine SQL-Anweisung angegeben")
        _SetStatus("Fehler: Keine SQL-Anweisung eingegeben")
        Return False
    EndIf

    _LogInfo("SQL-Text: " & StringLeft($sSQL, 500) & "...")
    _LogInfo("Datenbank: " & $sDBPath)

    ; SQL verarbeiten
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogInfo("Fehler beim Öffnen der Datenbank: " & @error)
        _SetStatus("Fehler beim Öffnen der Datenbank")
        Return False
    EndIf

    ; Für SELECT-Abfragen
    If StringRegExp(StringUpper(StringStripWS($sSQL, 3)), "^\s*SELECT") Then
        Local $aResult, $iRows, $iColumns
        _LogInfo("SQL-Abfrage ist ein SELECT - führe aus...")

        Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
        _SQLite_Close($hDB)

        If @error Or $iRet <> $SQLITE_OK Then
            _LogInfo("SQL-Fehler: " & _SQLite_ErrMsg())
            _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
            Return False
        EndIf

        _LogInfo("SELECT-Abfrage erfolgreich ausgeführt: " & $iRows & " Zeilen, " & $iColumns & " Spalten")

        ; ListView leeren
        _LogInfo("Lösche bisherige Daten in der ListView")
        _GUICtrlListView_DeleteAllItems($g_idListView)
        _DeleteAllListViewColumns($g_idListView)

        ; Keine Ergebnisse? Dann nur Meldung
        If $iRows = 0 Then
            _LogInfo("Keine Ergebnisse für diese Abfrage")
            _SetStatus("Abfrage erfolgreich ausgeführt - keine Ergebnisse")
            Return True
        EndIf

        ; Spalten hinzufügen
        _LogInfo("Füge " & $iColumns & " Spalten zur ListView hinzu")
        For $i = 0 To $iColumns - 1
            _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$i], 100)
        Next

        ; Daten hinzufügen
        _LogInfo("Füge " & $iRows & " Datensätze ein")
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
        _LogInfo("Aktualisiere ListView-Anzeige")
        GUICtrlSetState($g_idListView, $GUI_SHOW)
        _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
        _SetStatus("Abfrage erfolgreich ausgeführt: " & $iRows & " Zeilen gefunden")
    Else
        ; Für Nicht-SELECT-Abfragen
        _LogInfo("SQL-Anweisung ist kein SELECT - führe aus...")
        Local $iRet = _SQLite_Exec($hDB, $sSQL)
        Local $iChanges = _SQLite_Changes($hDB)
        _SQLite_Close($hDB)

        If @error Or $iRet <> $SQLITE_OK Then
            _LogInfo("SQL-Fehler: " & _SQLite_ErrMsg())
            _SetStatus("SQL-Fehler: " & _SQLite_ErrMsg())
            Return False
        EndIf

        _LogInfo("Nicht-SELECT-Anweisung erfolgreich ausgeführt: " & $iChanges & " Zeilen betroffen")
        _SetStatus("Anweisung erfolgreich ausgeführt: " & $iChanges & " Zeilen betroffen")
    EndIf

    _LogInfo("**********************************************************")
    _LogInfo("* MANUELL AUSGELÖSTE SQL-AUSFÜHRUNG - ENDE               *")
    _LogInfo("**********************************************************")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _InitSQLEditorIntegrated
; Beschreibung: Initialisiert den integrierten SQL-Editor im Hauptfenster
; Parameter.: $hGUI - Handle des Hauptfensters
;             $x, $y - Position des SQL-Editor-Panels
;             $w - Breite
;             $h - Höhe
; Rückgabe..: True bei Erfolg
; ===============================================================================================================================
Func _InitSQLEditorIntegrated($hGUI, $x, $y, $w, $h)
    ; Globale Variablen initialisieren
    $g_bSQLEditorMode = False  ; Standardmäßig ist der SQL-Editor deaktiviert

    ; Ursprüngliche Position und Größe der ListView speichern
    Local $aListViewPos = ControlGetPos($hGUI, "", $g_idListView)
    $g_iOrigListViewTop = $aListViewPos[1]
    $g_iOrigListViewHeight = $aListViewPos[3]

    ; Speichern der GUI-Informationen für dynamische Erstellung
    Global $g_sSQLEditorPosition = $x & "," & $y & "," & $w & "," & $SQL_EDITOR_HEIGHT

    _LogInfo("SQL-Editor-Modul initialisiert")
    _LogInfo("SQL-Editor-Position gesetzt: X=" & $x & ", Y=" & $y & ", W=" & $w & ", H=" & $SQL_EDITOR_HEIGHT)

    ; Event-Handler für Tastendrücke und Befehle im GUI registrieren
    GUIRegisterMsg($WM_COMMAND, "_WM_COMMAND")
    GUIRegisterMsg($WM_KEYDOWN, "_WM_KEYDOWN")
    GUIRegisterMsg($WM_LBUTTONDBLCLK, "_WM_LBUTTONDBLCLK")
    GUIRegisterMsg($WM_CHAR, "_WM_CHAR")  ; Für die Erfassung von Tasteneingaben

    _LogInfo("SQL-Editor: Event-Handler registriert für WM_COMMAND, WM_KEYDOWN, WM_LBUTTONDBLCLK, WM_CHAR")

    ; Die GUI-Elemente werden erst erstellt, wenn der SQL-Editor aktiviert wird
    $g_idSQLEditorPanel = 0
    $g_idSQLTableCombo = 0
    $g_hSQLRichEdit = 0
    $g_idAutoCompleteList = 0
    $g_hAutoCompleteList = 0
    $g_idSQLExecuteBtn = 0
    $g_idSQLSaveBtn = 0
    $g_idSQLLoadBtn = 0
    $g_idSQLBackBtn = 0
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _CreateSQLEditorElements
; Beschreibung: Erstellt die GUI-Elemente für den SQL-Editor dynamisch
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _CreateSQLEditorElements()
    _LogInfo("Erstelle SQL-Editor-Elemente dynamisch")

    ; Position und Größe aus gespeicherter Information abrufen
    Local $aPosition = StringSplit($g_sSQLEditorPosition, ",", $STR_NOCOUNT)
    Local $x = Number($aPosition[0])
    Local $y = Number($aPosition[1])
    Local $w = Number($aPosition[2])
    Local $h = Number($aPosition[3])

    ; Panel erstellen
    $g_idSQLEditorPanel = GUICtrlCreateGroup("SQL-Editor", $x, $y, $w, $h)

    ; Abstand der Steuerelemente vom Rand des Panels
    Local $iMargin = 10
    Local $xCtrl = $x + $iMargin
    Local $yCtrl = $y + 20 ; Berücksichtige Höhe der Gruppenüberschrift
    Local $wCtrl = $w - 2 * $iMargin

    ; Nur Tabellen-Dropdown anzeigen (keine DB-ComboBox mehr)
    Local $idLabelTable = GUICtrlCreateLabel("Tabelle:", $xCtrl, $yCtrl, 80, 20)
    $g_idSQLTableCombo = GUICtrlCreateCombo("", $xCtrl + 85, $yCtrl, 300, 20)

    ; RichEdit-Control für SQL-Eingabe
    $yCtrl += 30
    $g_hSQLRichEdit = _GUICtrlRichEdit_Create($g_hGUI, "", $xCtrl, $yCtrl, $wCtrl, 100, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")

    ; Auto-Vervollständigungsliste erstellen (anfangs ausgeblendet)
    $g_idAutoCompleteList = GUICtrlCreateList("", $xCtrl, $yCtrl + 50, 200, 120, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY))
    $g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)

    ; Buttons
    $yCtrl += 110
    ; Button für Ausführung
    $g_idSQLExecuteBtn = GUICtrlCreateButton("Ausführen (F5)", $xCtrl, $yCtrl, 150, 30)
    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", $xCtrl + 160, $yCtrl, 100, 30)
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", $xCtrl + 270, $yCtrl, 100, 30)
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $xCtrl + $wCtrl - 100, $yCtrl, 100, 30)

    ; Panel abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1) ; Dummy-Gruppe zum Schließen

    ; Debug-Ausgaben über den aktuellen Status
    _LogInfo("Aktuelle Datenbank: '" & $g_sCurrentDB & "'")
    _LogInfo("Aktuelle Tabelle (global): '" & $g_sCurrentTable & "'")
    _LogInfo("Gespeicherte Tabelle (von _SQL_EditorEnter): '" & $sSavedTable & "'")
    _LogInfo("Letztes SQL für Tabelle: '" & $g_sLastSQLTable & "'")

    ; Verfügbare Tabellen aus der Hauptansicht in den SQL-Editor übernehmen
    Local $sTables = GUICtrlRead($idTableCombo, 1) ; Alle Tabellen aus der Hauptansicht lesen
    _LogInfo("Tabellen aus Hauptansicht: '" & $sTables & "'")
    GUICtrlSetData($g_idSQLTableCombo, $sTables) ; Alle Tabellen in SQL-Editor übertragen

    ; Aktuelle Tabelle aus der Hauptansicht wählen (mit Fallbacks)
    Local $sTableToUse = $sSavedTable  ; Zuerst gespeicherte Tabelle verwenden
    If $sTableToUse = "" Then $sTableToUse = $g_sCurrentTable  ; Fallback auf globale Variable
    If $sTableToUse = "" And $g_sLastSQLTable <> "" Then $sTableToUse = $g_sLastSQLTable ; Zusätzlicher Fallback

    _LogInfo("Zu verwendende Tabelle: '" & $sTableToUse & "'")

    If $sTableToUse <> "" Then
        ; Überprüfen, ob Tabelle in ComboBox vorhanden
        If StringInStr("|" & $sTables & "|", "|" & $sTableToUse & "|") Then
            ; Tabelle in Combo auswählen
            _LogInfo("Tabelle '" & $sTableToUse & "' ist in der Liste vorhanden, wähle sie aus")
            GUICtrlSetData($g_idSQLTableCombo, $sTableToUse, $sTableToUse) ; Auswahl setzen

            ; Als Fallback auch ControlCommand verwenden
            If Not ControlCommand($g_hGUI, "", $g_idSQLTableCombo, "SelectString", $sTableToUse) Then
                _LogInfo("WARNUNG: ControlCommand SelectString gescheitert")
            EndIf

            ; SQL-Statement generieren oder das gespeicherte verwenden
            Local $sSQL = "SELECT * FROM " & $sTableToUse & " LIMIT 100;"

            ; Prüfen, ob wir das gleiche Statement wie beim letzten Mal verwenden können
            If $g_sLastSQLTable = $sTableToUse And $g_sLastSQLStatement <> "" Then
                ; Die gleiche Tabelle wie zuvor - gespeichertes Statement verwenden
                $sSQL = $g_sLastSQLStatement
                _LogInfo("Verwende gespeichertes SQL-Statement für Tabelle '" & $sTableToUse & "'")
            Else
                ; Neue oder geänderte Tabelle - Standardabfrage erstellen
                _LogInfo("Generiere neues SQL-Statement für Tabelle '" & $sTableToUse & "'")
            EndIf

            ; Statement in Editor setzen und speichern
            _LogInfo("Setze SQL-Statement in Editor: " & $sSQL)
            _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)

            ; Letzte Tabelle speichern für nächste Verwendung
            $g_sLastSQLTable = $sTableToUse
            $g_sLastSQLStatement = $sSQL

            ; Spalten der Tabelle für Auto-Vervollständigung laden
            $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sTableToUse)
            _LogInfo("Spalten für Auto-Vervollständigung geladen: " & UBound($g_aTableColumns))

            ; SQL-Abfrage direkt ausführen, um die ListView zu befüllen
            _LogInfo("Befülle ListView mit Daten aus der Tabelle " & $sTableToUse)

            ; Vorbereitungen für SQL-Ausführung
            $g_bUserInitiatedExecution = True  ; Notwendig für _SQL_ExecuteQuery

            ; Ausführen und in ListView anzeigen
            _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)

            ; Status zurücksetzen
            $g_bUserInitiatedExecution = False
        Else
            ; Tabelle nicht gefunden - Default-Statement erstellen
            _LogInfo("WARNUNG: Tabelle '" & $sTableToUse & "' nicht in ComboBox gefunden - verwende erste verfügbare Tabelle")

            ; Versuchen, die erste verfügbare Tabelle zu verwenden
            If $sTables <> "" Then
                Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
                If UBound($aTableList) > 0 Then
                    $sTableToUse = $aTableList[0]
                    _LogInfo("Verwende erste verfügbare Tabelle: " & $sTableToUse)

                    ; Tabelle in Combo auswählen
                    GUICtrlSetData($g_idSQLTableCombo, $sTableToUse, $sTableToUse) ; Auswahl setzen
                    ControlCommand($g_hGUI, "", $g_idSQLTableCombo, "SelectString", $sTableToUse)

                    ; SQL-Statement generieren
                    Local $sSQL = "SELECT * FROM " & $sTableToUse & " LIMIT 100;"
                    _LogInfo("Generiere Standard-SQL-Statement für Tabelle '" & $sTableToUse & "'")
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)

                    ; Letzte Tabelle speichern für nächste Verwendung
                    $g_sLastSQLTable = $sTableToUse
                    $g_sLastSQLStatement = $sSQL

                    ; SQL-Abfrage direkt ausführen, um die ListView zu befüllen
                    $g_bUserInitiatedExecution = True
                    _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
                    $g_bUserInitiatedExecution = False
                Else
                    ; Keine Tabellen vorhanden - Standard-Statement
                    Local $sSQL = "-- Keine Tabellen verfügbar in dieser Datenbank \n\nSELECT 1, 'Beispiel' AS Test;"
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                EndIf
            Else
                ; Keine Tabellen vorhanden - Standard-Statement
                Local $sSQL = "-- Keine Tabellen verfügbar in dieser Datenbank \n\nSELECT 1, 'Beispiel' AS Test;"
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
            EndIf
        EndIf
    Else
        ; Versuchen, die erste verfügbare Tabelle zu verwenden
        Local $sTables = GUICtrlRead($g_idSQLTableCombo, 1)
        If $sTables <> "" Then
            Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
            If UBound($aTableList) > 0 Then
                $sTableToUse = $aTableList[0]
                _LogInfo("Keine vorherige Tabelle - verwende erste verfügbare: " & $sTableToUse)

                ; Tabelle in Combo auswählen
                GUICtrlSetData($g_idSQLTableCombo, $sTableToUse, $sTableToUse) ; Auswahl setzen
                ControlCommand($g_hGUI, "", $g_idSQLTableCombo, "SelectString", $sTableToUse)

                ; SQL-Statement generieren
                Local $sSQL = "SELECT * FROM " & $sTableToUse & " LIMIT 100;"
                _LogInfo("Generiere Standard-SQL-Statement für Tabelle '" & $sTableToUse & "'")
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)

                ; Letzte Tabelle speichern für nächste Verwendung
                $g_sLastSQLTable = $sTableToUse
                $g_sLastSQLStatement = $sSQL

                ; SQL-Abfrage direkt ausführen, um die ListView zu befüllen
                $g_bUserInitiatedExecution = True
                _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
                $g_bUserInitiatedExecution = False
            Else
                ; Standard-Statement
                Local $sSQL = "-- Bitte wählen Sie eine Tabelle aus \n\nSELECT 1, 'Beispiel' AS Test;"
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
            EndIf
        Else
            ; Standard-Statement
            Local $sSQL = "-- Bitte wählen Sie eine Tabelle aus \n\nSELECT 1, 'Beispiel' AS Test;"
            _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        EndIf
    EndIf

    ; Fokus auf RichEdit-Control setzen
    _WinAPI_SetFocus($g_hSQLRichEdit)

    Return True
EndFunc