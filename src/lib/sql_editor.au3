#include-once
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <GuiListView.au3>
#include <GuiEdit.au3>
#include <SQLite.au3>
#include <Array.au3>
#include <File.au3>

#include "logging.au3"
#include "error_handler.au3"
#include "db_functions.au3"

; ===============================================================================================================================
; Titel.......: SQL-Editor
; Beschreibung: Ein Editor für SQLite-Abfragen mit Syntax-Highlighting
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2023-04-06
; ===============================================================================================================================

; Globale Variablen für den SQL-Editor
Global $g_hSQLEditorGUI = 0
Global $g_idSQLEdit = 0
Global $g_idResultListView = 0
Global $g_idStatusLabel = 0
Global $g_idColumnInfo = 0
Global $g_iLastUpdate = 0
Global $g_sCurrentDB = ""

; SQL-Schlüsselwörter für Syntax-Highlighting
Global $g_aSQLKeywords = [ _
    "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "JOIN", "GROUP", "ORDER", "BY", "HAVING", _
    "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "TRIGGER", "PRAGMA", "AS", "ON", "AND", "OR", _
    "NOT", "NULL", "IS", "IN", "BETWEEN", "LIKE", "GLOB", "LIMIT", "DISTINCT", "ALL", "UNION", "CASE", _
    "WHEN", "THEN", "ELSE", "END", "EXISTS", "INTO", "VALUES", "SET", "FOREIGN", "KEY", "PRIMARY", _
    "REFERENCES", "DEFAULT", "UNIQUE", "CHECK", "CONSTRAINT", "INTEGER", "TEXT", "BLOB", "REAL", "DATETIME" _
]

; ===============================================================================================================================
; Func.....: _ShowSQLEditor
; Beschreibung: Zeigt den SQL-Editor an
; Parameter.: $sDefaultDB - [optional] Die Standarddatenbank, die verwendet werden soll
;             $sDefaultSQL - [optional] Standard-SQL-Abfrage, die im Editor angezeigt wird
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _ShowSQLEditor($sDefaultDB = "", $sDefaultSQL = "")
    ; Wenn der Editor bereits geöffnet ist, aktiviere ihn einfach
    If IsHWnd($g_hSQLEditorGUI) Then
        WinActivate($g_hSQLEditorGUI)
        Return True
    EndIf

    ; GUI erstellen
    $g_hSQLEditorGUI = GUICreate("SQL-Editor", 800, 600, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_MAXIMIZEBOX, $WS_SIZEBOX))

    ; Datenbank-Auswahl
    GUICtrlCreateLabel("Datenbank:", 10, 10, 80, 20)
    Local $idDBCombo = GUICtrlCreateCombo("", 90, 10, 500, 20)
    Local $idRefreshDBButton = GUICtrlCreateButton("Aktualisieren", 600, 10, 90, 20)
    Local $idOpenDBButton = GUICtrlCreateButton("Öffnen...", 700, 10, 90, 20)

    ; SQL-Editor erstellen
    GUICtrlCreateLabel("SQL-Abfrage:", 10, 40, 100, 20)
    $g_idSQLEdit = GUICtrlCreateEdit("", 10, 60, 780, 180, BitOR($ES_WANTRETURN, $WS_VSCROLL, $ES_MULTILINE, $ES_AUTOVSCROLL))
    GUICtrlSetFont($g_idSQLEdit, 10, 400, 0, "Consolas") ; Monospace-Font für bessere Lesbarkeit

    ; Buttons für die Ausführung
    Local $idExecuteQuery = GUICtrlCreateButton("Abfrage ausführen (SELECT)", 10, 250, 200, 30)
    Local $idExecuteNoQuery = GUICtrlCreateButton("Befehl ausführen (INSERT/UPDATE/etc.)", 220, 250, 250, 30)
    Local $idClearResults = GUICtrlCreateButton("Ergebnisse löschen", 480, 250, 150, 30)
    Local $idSaveSQL = GUICtrlCreateButton("SQL speichern...", 640, 250, 150, 30)

    ; Spalteninformationen
    $g_idColumnInfo = GUICtrlCreateEdit("", 10, 290, 780, 50, BitOR($ES_READONLY, $ES_MULTILINE))
    GUICtrlSetBkColor($g_idColumnInfo, $COLOR_SKYBLUE)
    GUICtrlSetFont($g_idColumnInfo, 9, 400, 0, "Consolas")

    ; Ergebnisbereich
    GUICtrlCreateLabel("Ergebnisse:", 10, 350, 100, 20)
    $g_idResultListView = GUICtrlCreateListView("", 10, 370, 780, 200)
    _GUICtrlListView_SetExtendedListViewStyle($g_idResultListView, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT, $LVS_EX_DOUBLEBUFFER))

    ; Status-Label
    $g_idStatusLabel = GUICtrlCreateLabel("Bereit", 10, 580, 780, 20)

    ; Setze die aktuelle Datenbank
    $g_sCurrentDB = $sDefaultDB

    ; Fülle die DB-Combo mit vorhandenen Datenbanken
    _FillDatabaseCombo($idDBCombo)

    ; Wenn eine DB angegeben wurde, wähle sie aus
    If $sDefaultDB <> "" Then
        GUICtrlSetData($idDBCombo, $sDefaultDB, $sDefaultDB)
    EndIf

    ; Wenn SQL angegeben wurde, füge es ein
    If $sDefaultSQL <> "" Then
        GUICtrlSetData($g_idSQLEdit, $sDefaultSQL)
    ElseIf $sDefaultDB <> "" Then
        ; Beispielabfrage einfügen
        Local $sFirstTable = _GetFirstTableFromDB($sDefaultDB)
        If $sFirstTable <> "" Then
            GUICtrlSetData($g_idSQLEdit, "SELECT * FROM " & $sFirstTable & " LIMIT 10;")
        Else
            GUICtrlSetData($g_idSQLEdit, "-- Geben Sie hier Ihre SQL-Abfrage ein")
        EndIf
    Else
        GUICtrlSetData($g_idSQLEdit, "-- Geben Sie hier Ihre SQL-Abfrage ein")
    EndIf

    ; Syntax-Highlighting initial anwenden
    _UpdateSQLSyntaxHighlighting()

    ; GUI anzeigen
    GUISetState(@SW_SHOW, $g_hSQLEditorGUI)

    ; Event-Schleife
    Local $nMsg = 0
    While 1
        $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE
                GUIDelete($g_hSQLEditorGUI)
                $g_hSQLEditorGUI = 0
                Return False

            Case $idDBCombo
                $g_sCurrentDB = GUICtrlRead($idDBCombo)
                _LogInfo("Datenbank gewechselt zu: " & $g_sCurrentDB)

            Case $idRefreshDBButton
                _FillDatabaseCombo($idDBCombo)

            Case $idOpenDBButton
                Local $sFile = FileOpenDialog("Datenbank öffnen", $g_sLastDir, "SQLite Datenbanken (*.db;*.db3;*.sqlite;*.sqlite3)", $FD_FILEMUSTEXIST)
                If Not @error Then
                    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))
                    $g_sCurrentDB = $sFile
                    _FillDatabaseCombo($idDBCombo)
                    GUICtrlSetData($idDBCombo, $sFile, $sFile)
                EndIf

            Case $idExecuteQuery
                _ExecuteSQLQuery(GUICtrlRead($g_idSQLEdit))

            Case $idExecuteNoQuery
                _ExecuteSQLNoQuery(GUICtrlRead($g_idSQLEdit))

            Case $idClearResults
                _GUICtrlListView_DeleteAllItems($g_idResultListView)
                _DeleteAllListViewColumns($g_idResultListView)
                GUICtrlSetData($g_idColumnInfo, "")
                GUICtrlSetData($g_idStatusLabel, "Ergebnisse gelöscht")

            Case $idSaveSQL
                _SaveSQLQuery(GUICtrlRead($g_idSQLEdit))
        EndSwitch

        ; Aktualisiere Syntax-Highlighting alle 500ms
        If TimerDiff($g_iLastUpdate) > 500 Then
            _UpdateSQLSyntaxHighlighting()
            $g_iLastUpdate = TimerInit()
        EndIf
    WEnd
EndFunc

; ===============================================================================================================================
; Func.....: _ExecuteSQLQuery
; Beschreibung: Führt eine SQL-Abfrage aus und zeigt die Ergebnisse an
; Parameter.: $sSQL - Die auszuführende SQL-Abfrage
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _ExecuteSQLQuery($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    If $g_sCurrentDB = "" Then
        GUICtrlSetData($g_idStatusLabel, "Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Abfrage fehlgeschlagen: Keine Datenbank ausgewählt")
        Return SetError(1, 0, False)
    EndIf

    ; Setze den Statustext
    GUICtrlSetData($g_idStatusLabel, "Führe Abfrage aus...")

    ; Lösche vorherige Ergebnisse
    _GUICtrlListView_DeleteAllItems($g_idResultListView)
    _DeleteAllListViewColumns($g_idResultListView)
    GUICtrlSetData($g_idColumnInfo, "")

    ; Starte ein Timer für die Leistungsmessung
    Local $hTimer = TimerInit()

    ; Öffne die Datenbank
    Local $hDB = _SQLite_Open($g_sCurrentDB)
    If @error Then
        GUICtrlSetData($g_idStatusLabel, "Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $g_sCurrentDB & " Fehler: " & @error)
        Return SetError(2, 0, False)
    EndIf

    ; Führe die Abfrage aus
    Local $aResult, $aRows, $iColumns
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $aRows, $iColumns)
    If @error Or $iRet <> $SQLITE_OK Then
        Local $sError = _SQLite_ErrMsg($hDB)
        GUICtrlSetData($g_idStatusLabel, "SQL-Fehler: " & $sError)
        _LogError("SQL-Fehler: " & $sError)
        _SQLite_Close($hDB)
        Return SetError(3, 0, False)
    EndIf

    ; Schließe die Datenbank
    _SQLite_Close($hDB)

    ; Wenn keine Ergebnisse, zeige eine Meldung an
    If $aRows = 0 Then
        GUICtrlSetData($g_idStatusLabel, "Abfrage ausgeführt. Keine Ergebnisse.")
        _LogInfo("SQL-Abfrage ausgeführt. Keine Ergebnisse.")
        Return False
    EndIf

    ; Spalten zum ListView hinzufügen
    For $i = 0 To $iColumns - 1
        _GUICtrlListView_AddColumn($g_idResultListView, $aResult[0][$i], 100)
    Next

    ; Spalteninformationen anzeigen
    Local $sColumnInfo = "Spalten: " & $iColumns & " | "
    For $i = 0 To $iColumns - 1
        $sColumnInfo &= $aResult[0][$i]
        If $i < $iColumns - 1 Then $sColumnInfo &= ", "
    Next
    GUICtrlSetData($g_idColumnInfo, $sColumnInfo)

    ; Daten zum ListView hinzufügen
    For $i = 1 To $aRows
        Local $iIndex = _GUICtrlListView_AddItem($g_idResultListView, $aResult[$i][0])
        For $j = 1 To $iColumns - 1
            _GUICtrlListView_AddSubItem($g_idResultListView, $iIndex, $aResult[$i][$j], $j)
        Next
    Next

    ; Spaltenbreiten automatisch anpassen
    For $i = 0 To $iColumns - 1
        _GUICtrlListView_SetColumnWidth($g_idResultListView, $i, $LVSCW_AUTOSIZE)
    Next

    ; Timer stoppen und Abfragezeit berechnen
    Local $fQueryTime = TimerDiff($hTimer) / 1000

    ; Statusmeldung aktualisieren
    GUICtrlSetData($g_idStatusLabel, "Abfrage erfolgreich ausgeführt. " & $aRows & " Zeilen in " & $fQueryTime & " Sekunden.")
    _LogInfo("SQL-Abfrage erfolgreich ausgeführt. " & $aRows & " Zeilen in " & $fQueryTime & " Sekunden.")

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _ExecuteSQLNoQuery
; Beschreibung: Führt einen SQL-Befehl aus, der keine Ergebnisse zurückgibt (INSERT, UPDATE, DELETE, etc.)
; Parameter.: $sSQL - Der auszuführende SQL-Befehl
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _ExecuteSQLNoQuery($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    If $g_sCurrentDB = "" Then
        GUICtrlSetData($g_idStatusLabel, "Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Befehl fehlgeschlagen: Keine Datenbank ausgewählt")
        Return SetError(1, 0, False)
    EndIf

    ; Setze den Statustext
    GUICtrlSetData($g_idStatusLabel, "Führe Befehl aus...")

    ; Starte ein Timer für die Leistungsmessung
    Local $hTimer = TimerInit()

    ; Öffne die Datenbank
    Local $hDB = _SQLite_Open($g_sCurrentDB)
    If @error Then
        GUICtrlSetData($g_idStatusLabel, "Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $g_sCurrentDB & " Fehler: " & @error)
        Return SetError(2, 0, False)
    EndIf

    ; Führe den Befehl aus
    Local $iRet = _SQLite_Exec($hDB, $sSQL)
    If @error Or $iRet <> $SQLITE_OK Then
        Local $sError = _SQLite_ErrMsg($hDB)
        GUICtrlSetData($g_idStatusLabel, "SQL-Fehler: " & $sError)
        _LogError("SQL-Fehler: " & $sError)
        _SQLite_Close($hDB)
        Return SetError(3, 0, False)
    EndIf

    ; Anzahl der betroffenen Zeilen ermitteln
    Local $iChanges = _SQLite_Changes($hDB)

    ; Schließe die Datenbank
    _SQLite_Close($hDB)

    ; Timer stoppen und Abfragezeit berechnen
    Local $fQueryTime = TimerDiff($hTimer) / 1000

    ; Statusmeldung aktualisieren
    GUICtrlSetData($g_idStatusLabel, "Befehl erfolgreich ausgeführt. " & $iChanges & " Zeilen betroffen. Zeit: " & $fQueryTime & " Sekunden.")
    _LogInfo("SQL-Befehl erfolgreich ausgeführt. " & $iChanges & " Zeilen betroffen. Zeit: " & $fQueryTime & " Sekunden.")

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _UpdateSQLSyntaxHighlighting
; Beschreibung: Implementiert das Syntax-Highlighting für SQL im Editor
; Rückgabe..: Keine
; ===============================================================================================================================
Func _UpdateSQLSyntaxHighlighting()
    ; Diese Funktion würde normalerweise mit RichEdit oder ActiveX-Controls implementiert
    ; Da dies jedoch über den Umfang dieser einfachen Implementierung hinausgeht,
    ; wird hier eine Platzhalter-Funktion verwendet

    ; Einfach ein paar Informationen protokollieren
    _LogDebug("SQL-Syntax-Highlighting aktualisiert")

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _FillDatabaseCombo
; Beschreibung: Füllt die Datenbank-Combo mit vorhandenen Datenbanken
; Parameter.: $idCombo - Die ID der Combo
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _FillDatabaseCombo($idCombo)
    ; Aktuell ausgewählten Eintrag merken
    Local $sCurrentDB = GUICtrlRead($idCombo)

    ; Liste leeren
    GUICtrlSetData($idCombo, "")

    ; SQLite-Datenbankdateien im Programmverzeichnis suchen
    Local $aDBFiles = _FileListToArray(@ScriptDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES)
    If @error Then
        _LogWarning("Keine Datenbankdateien im Programmverzeichnis gefunden")
    Else
        ; Datenbankdateien zur Combo hinzufügen
        For $i = 1 To $aDBFiles[0]
            GUICtrlSetData($idCombo, @ScriptDir & "\" & $aDBFiles[$i])
        Next
    EndIf

    ; Extraktionsverzeichnis durchsuchen, falls vorhanden
    If $g_sExtractDir <> "" And FileExists($g_sExtractDir) Then
        Local $aExtractDBFiles = _FileListToArray($g_sExtractDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES, True)
        If Not @error Then
            For $i = 1 To $aExtractDBFiles[0]
                GUICtrlSetData($idCombo, $aExtractDBFiles[$i])
            Next
        EndIf
    EndIf

    ; Falls aktuell ausgewählte Datenbank vorhanden, wieder auswählen
    If $sCurrentDB <> "" Then
        GUICtrlSetData($idCombo, $sCurrentDB, $sCurrentDB)
    ElseIf $g_sCurrentDB <> "" Then
        GUICtrlSetData($idCombo, $g_sCurrentDB, $g_sCurrentDB)
    EndIf

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _GetFirstTableFromDB
; Beschreibung: Ermittelt den Namen der ersten Tabelle in einer Datenbank
; Parameter.: $sDBPath - Der Pfad zur Datenbank
; Rückgabe..: Erfolg - Name der ersten Tabelle
;             Fehler - Leerer String und @error gesetzt
; ===============================================================================================================================
Func _GetFirstTableFromDB($sDBPath)
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " Fehler: " & @error)
        Return SetError(1, 0, "")
    EndIf

    ; Tabellenliste abfragen
    Local $aResult, $aRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $aRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    ; Bei Fehler oder keinen Tabellen leeren String zurückgeben
    If @error Or $iRet <> $SQLITE_OK Or $aRows = 0 Then
        Return ""
    EndIf

    ; Name der ersten Tabelle zurückgeben
    Return $aResult[1][0]
EndFunc

; ===============================================================================================================================
; Func.....: _SaveSQLQuery
; Beschreibung: Speichert eine SQL-Abfrage in einer Datei
; Parameter.: $sSQL - Die zu speichernde SQL-Abfrage
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SaveSQLQuery($sSQL)
    ; Speicherdialog anzeigen
    Local $sFile = FileSaveDialog("SQL-Abfrage speichern", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_PATHMUSTEXIST)
    If @error Then Return False

    ; Pfad merken
    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))

    ; Dateiendung prüfen
    If StringRight($sFile, 4) <> ".sql" Then $sFile &= ".sql"

    ; SQL-Abfrage in Datei speichern
    If FileWrite($sFile, $sSQL) Then
        GUICtrlSetData($g_idStatusLabel, "SQL-Abfrage gespeichert in: " & $sFile)
        _LogInfo("SQL-Abfrage gespeichert in: " & $sFile)
        Return True
    Else
        GUICtrlSetData($g_idStatusLabel, "Fehler beim Speichern der SQL-Abfrage")
        _LogError("Fehler beim Speichern der SQL-Abfrage in: " & $sFile)
        Return SetError(1, 0, False)
    EndIf
EndFunc

; Hilfsfunktion: Löscht alle Spalten eines ListView-Controls
;~ Func _DeleteAllListViewColumns($hListView)
;~     ; Zähle vorhandene Spalten
;~     Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)
;~
;~     ; Lösche alle Spalten (von rechts nach links)
;~     For $i = $iColumns - 1 To 0 Step -1
;~         _GUICtrlListView_DeleteColumn($hListView, $i)
;~     Next
;~
;~     Return True
;~ EndFunc