#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <GuiListView.au3>
#include <GuiEdit.au3>
#include <GUIRichEdit.au3>
#include <SQLite.au3>
#include <Array.au3>
#include <File.au3>
#include <WinAPIGdi.au3>
#include <WinAPI.au3>
#include <WinAPISys.au3>

#include "logging.au3"
#include "error_handler.au3"
#include "db_functions.au3"
#include "gui_functions.au3"  ; Enthält _DeleteAllListViewColumns
#include <WinAPIGdi.au3>  ; Für _WinAPI_RedrawWindow

; ===============================================================================================================================
; Titel.......: SQL-Editor (Integriert)
; Beschreibung: Ein in das Hauptfenster integrierter Editor für SQLite-Abfragen mit Syntax-Highlighting
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-06
; ===============================================================================================================================

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLDbCombo = 0            ; ID der Datenbank-Auswahlbox
Global $g_idSQLTableCombo = 0         ; ID der Tabellen-Auswahlbox
Global $g_idSQLExecuteQueryBtn = 0    ; ID des Buttons zum Ausführen einer Abfrage
Global $g_idSQLExecuteCommandBtn = 0  ; ID des Buttons zum Ausführen eines Befehls
Global $g_idSQLSaveBtn = 0            ; ID des Buttons zum Speichern einer SQL-Abfrage
Global $g_idSQLLoadBtn = 0            ; ID des Buttons zum Laden einer SQL-Abfrage
Global $g_idSQLBackBtn = 0            ; ID des Buttons zum Zurückkehren zur normalen Ansicht
Global $g_sCurrentDB = ""             ; Aktuelle Datenbank-Datei

; Externe globale Variablen (definiert in der Hauptdatei)
Global $g_idBtnSQLEditor              ; Button zum Umschalten SQL-Editor (in main_robust.au3 definiert)
Global $g_idStatus                    ; Statusbar-Control
Global $g_idListView                  ; ListView-Control
Global $idTableCombo                  ; Tabellen-Combo im Hauptfenster

; SQL-Editor-Zustand
Global $g_bSQLEditorMode = False      ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_aListViewBackup[0][0]       ; Array zum Speichern des ListView-Zustands vor SQL-Editor-Aktivierung
Global $g_aListViewColBackup = 0      ; Array zum Speichern der Spaltenüberschriften

; Originale ListView-Position und -Größe
Global $g_iOrigListViewHeight = 0     ; Ursprüngliche Höhe der ListView
Global $g_iOrigListViewTop = 0        ; Ursprüngliche Y-Position der ListView

; Höhe des SQL-Editor-Panels
Global Const $SQL_EDITOR_HEIGHT = 200

; Token-Typen für SQL-Syntax-Highlighting
Global Const $TOKEN_NORMAL = 0
Global Const $TOKEN_KEYWORD = 1
Global Const $TOKEN_STRING = 2
Global Const $TOKEN_NUMBER = 3
Global Const $TOKEN_COMMENT = 4
Global Const $TOKEN_OPERATOR = 5

; Aktuelle Tabellenspalten für Autovervollständigung
Global $g_aTableColumns[0] ; Spalten der aktuell ausgewählten Tabelle

; SQL-Schlüsselwörter für Syntax-Highlighting
Global $g_aSQLKeywords = StringSplit("SELECT,FROM,WHERE,INSERT,UPDATE,DELETE,JOIN,GROUP,ORDER,BY,HAVING,CREATE,ALTER,DROP,TABLE,VIEW,INDEX,TRIGGER,PRAGMA,AS,ON,AND,OR,NOT,NULL,IS,IN,BETWEEN,LIKE,GLOB,LIMIT,DISTINCT,ALL,UNION,CASE,WHEN,THEN,ELSE,END,EXISTS,INTO,VALUES,SET,FOREIGN,KEY,PRIMARY,REFERENCES,DEFAULT,UNIQUE,CHECK,CONSTRAINT,INTEGER,TEXT,BLOB,REAL,DATETIME,LEFT,RIGHT,INNER,OUTER,FULL,NATURAL,CROSS,USING,WITH,DESC,ASC,ASC,ORDER BY,GROUP BY,INNER JOIN,LEFT JOIN,RIGHT JOIN,OUTER JOIN,HAVING,SELECT DISTINCT,UNION ALL,CREATE TABLE,DROP TABLE,CREATE INDEX,DROP INDEX,PRIMARY KEY,FOREIGN KEY,NOT NULL,AUTOINCREMENT,ON DELETE,ON UPDATE,CASCADE,RESTRICT,SET NULL", ",", 1)

; ===============================================================================================================================
; Func.....: _SetStatus
; Beschreibung: Setzt den Status in der Statusleiste
; Parameter.: $sText - Der anzuzeigende Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SetStatus($sText)
    GUICtrlSetData($g_idStatus, $sText)
    _LogInfo("Statusmeldung: " & $sText)
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
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    ; Bei Fehler oder keinen Tabellen leeren String zurückgeben
    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        Return ""
    EndIf

    ; Name der ersten Tabelle zurückgeben
    Return $aResult[1][0]
EndFunc

; ===============================================================================================================================
; Func.....: _GetTableColumns
; Beschreibung: Ermittelt die Spalten einer Tabelle für Autovervollständigung
; Parameter.: $sDBPath - Der Pfad zur Datenbank
;             $sTable - Der Tabellenname
; Rückgabe..: Erfolg - Array mit Spaltennamen
;             Fehler - Leeres Array und @error gesetzt
; ===============================================================================================================================
Func _GetTableColumns($sDBPath, $sTable)
    Local $aColumns[0]
    
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " Fehler: " & @error)
        Return SetError(1, 0, $aColumns)
    EndIf

    ; PRAGMA-Befehl ausführen, um Tabellenspalten zu erhalten
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "PRAGMA table_info(" & $sTable & ");"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogWarning("Keine Spalten in der Tabelle gefunden: " & $sTable)
        Return SetError(2, 0, $aColumns)
    EndIf

    ; Spaltennamen aus Ergebnis extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    Return $aColumns
EndFunc

; ===============================================================================================================================
; Func.....: _InitSQLEditorIntegrated
; Beschreibung: Initialisiert den integrierten SQL-Editor im Hauptfenster
; Parameter.: $hGUI - Handle des Hauptfensters
;             $x, $y - Position des SQL-Editor-Panels (normal: Oberkante der ListView)
;             $w - Breite (normal: Breite der ListView)
;             $h - Nicht verwendet, stattdessen wird die konstante Höhe $SQL_EDITOR_HEIGHT verwendet
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _InitSQLEditorIntegrated($hGUI, $x, $y, $w, $h)
    _LogInfo("Initialisiere integrierten SQL-Editor")

    ; Ursprüngliche Position und Größe der ListView speichern
    Local $aListViewPos = ControlGetPos($hGUI, "", $g_idListView)
    $g_iOrigListViewTop = $aListViewPos[1]
    $g_iOrigListViewHeight = $aListViewPos[3]

    ; Panel erstellen (anfangs ausgeblendet)
    $g_idSQLEditorPanel = GUICtrlCreateGroup("SQL-Editor", $x, $y, $w, $SQL_EDITOR_HEIGHT)
    GUICtrlSetState($g_idSQLEditorPanel, $GUI_HIDE)

    ; Abstand der Steuerelemente vom Rand des Panels
    Local $iMargin = 10
    Local $xCtrl = $x + $iMargin
    Local $yCtrl = $y + 20 ; Berücksichtige Höhe der Gruppenüberschrift
    Local $wCtrl = $w - 2 * $iMargin

    ; Dropdown-Menüs für Datenbanken und Tabellen
    GUICtrlCreateLabel("Datenbank:", $xCtrl, $yCtrl, 80, 20)
    $g_idSQLDbCombo = GUICtrlCreateCombo("", $xCtrl + 85, $yCtrl, 200, 20)
    GUICtrlCreateLabel("Tabelle:", $xCtrl + 300, $yCtrl, 80, 20)
    $g_idSQLTableCombo = GUICtrlCreateCombo("", $xCtrl + 385, $yCtrl, 200, 20)

    ; RichEdit-Control für SQL-Eingabe
    $yCtrl += 30
    $g_hSQLRichEdit = _GUICtrlRichEdit_Create($hGUI, "", $xCtrl, $yCtrl, $wCtrl, 100, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")
    
    ; Event für Tastatureingabe an RichEdit binden
    GUIRegisterMsg($WM_KEYUP, "_WM_KEYUP_RichEdit")

    ; Buttons
    $yCtrl += 110
    $g_idSQLExecuteQueryBtn = GUICtrlCreateButton("Abfrage ausführen", $xCtrl, $yCtrl, 150, 30)
    $g_idSQLExecuteCommandBtn = GUICtrlCreateButton("Befehl ausführen", $xCtrl + 160, $yCtrl, 150, 30)
    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", $xCtrl + 320, $yCtrl, 100, 30)
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", $xCtrl + 430, $yCtrl, 100, 30)
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $xCtrl + $wCtrl - 100, $yCtrl, 100, 30)

    ; Panel abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1) ; Dummy-Gruppe zum Schließen

    _LogInfo("Integrierter SQL-Editor initialisiert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _WM_KEYUP_RichEdit
; Beschreibung: Event-Handler für Tastatureingaben im RichEdit-Control
; Parameter.: Standard-WM_KEYUP-Parameter
; Rückgabe..: $GUI_RUNDEFMSG um das Event weiterzuleiten
; ===============================================================================================================================
Func _WM_KEYUP_RichEdit($hWnd, $iMsg, $wParam, $lParam)
    ; Prüfen, ob wir uns im SQL-Editor-Modus befinden
    If $g_bSQLEditorMode Then
        ; RichEdit-Control erkennen
        Local $hWndFrom = HWnd(GUICtrlGetHandle($g_hSQLRichEdit))
        If $hWnd = $hWndFrom Then
            ; Syntax-Highlighting aktualisieren
            _SQL_UpdateSyntaxHighlighting()
            
            ; Wenn Leertaste oder Punkt gedrückt wurde, Autovervollständigung prüfen
            If $wParam = 0x20 Or $wParam = 0xBE Or $wParam = 0x0D Then ; Space, Period, Enter
                ; Implementiere Autovervollständigung hier
                ; TODO: Autovervollständigungslogik
            EndIf
        EndIf
    EndIf
    
    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _ToggleSQLEditorMode
; Beschreibung: Schaltet zwischen normaler Ansicht und SQL-Editor-Modus um
; Parameter.: $bActivate - True, um den SQL-Editor zu aktivieren, False um ihn zu deaktivieren
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ToggleSQLEditorMode($bActivate)
    ; Wenn aktueller Status bereits dem gewünschten entspricht, nichts tun
    If $g_bSQLEditorMode = $bActivate Then Return

    If $bActivate Then
        _LogInfo("Aktiviere SQL-Editor-Modus")

        ; Speichere den aktuellen Status der ListView für spätere Wiederherstellung
        _SQL_SaveListViewState()

        ; Button-Text ändern
        GUICtrlSetData($g_idBtnSQLEditor, "Zurück")

        ; SQL-Editor-Panel anzeigen
        GUICtrlSetState($g_idSQLEditorPanel, $GUI_SHOW)

        ; ListView verkleinern und nach unten verschieben
        Local $aPos = ControlGetPos($g_hGUI, "", $g_idListView)
        ControlMove($g_hGUI, "", $g_idListView, $aPos[0], $g_iOrigListViewTop + $SQL_EDITOR_HEIGHT, $aPos[2], $g_iOrigListViewHeight - $SQL_EDITOR_HEIGHT)
        ; Sicherstellen dass ListView sichtbar bleibt
        GUICtrlSetState($g_idListView, $GUI_SHOW)

        ; Datenbanken und Tabellen laden
        _SQL_LoadDatabases()

        ; Wenn eine Datenbank ausgewählt ist, Tabellen laden und SQL-Statement aktualisieren
        If $g_sCurrentDB <> "" Then
            GUICtrlSetData($g_idSQLDbCombo, $g_sCurrentDB, $g_sCurrentDB)
            _SQL_LoadTables($g_sCurrentDB)

            ; Standardabfrage mit aktueller Tabelle erstellen
            Local $sCurrentTable = GUICtrlRead($idTableCombo) ; Tabelle aus der Hauptfenster-ComboBox
            If $sCurrentTable <> "" Then
                ; Tabelle in SQL-Editor-ComboBox auswählen
                GUICtrlSetData($g_idSQLTableCombo, $sCurrentTable, $sCurrentTable)

                ; SQL-Statement mit der Tabelle aktualisieren
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "SELECT * FROM " & $sCurrentTable & " LIMIT 100;")
                _SQL_UpdateSyntaxHighlighting()
                _LogInfo("SQL-Statement aktualisiert für Tabelle: " & $sCurrentTable)
                
                ; Spalten für Autovervollständigung laden
                $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sCurrentTable)
            Else
                ; Falls keine Tabelle ausgewählt, erste Tabelle aus DB verwenden
                Local $sFirstTable = _GetFirstTableFromDB($g_sCurrentDB)
                If $sFirstTable <> "" Then
                    GUICtrlSetData($g_idSQLTableCombo, $sFirstTable, $sFirstTable)
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "SELECT * FROM " & $sFirstTable & " LIMIT 100;")
                    _SQL_UpdateSyntaxHighlighting()
                    _LogInfo("SQL-Statement mit erster Tabelle erstellt: " & $sFirstTable)
                    
                    ; Spalten für Autovervollständigung laden
                    $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sFirstTable)
                EndIf
            EndIf
        EndIf

        ; Synchronisiere mit dem Tabellen-Dropdown im Hauptfenster
        Local $sCurrentTable = GUICtrlRead($idTableCombo)
        If $sCurrentTable <> "" Then
            GUICtrlSetData($g_idSQLTableCombo, $sCurrentTable, $sCurrentTable)
        EndIf

        $g_bSQLEditorMode = True
    Else
        _LogInfo("Deaktiviere SQL-Editor-Modus - Radikale Methode")

        ; Button-Text zurücksetzen
        GUICtrlSetData($g_idBtnSQLEditor, "SQL-Editor")

        ; SQL-Editor-Panel ausblenden
        GUICtrlSetState($g_idSQLEditorPanel, $GUI_HIDE)

        ; Fensterbreite und -höhe ermitteln für Auto-Resize
        Local $aWinPos = WinGetPos($g_hGUI)
        _LogInfo("Hauptfenster-Maße: " & $aWinPos[2] & "x" & $aWinPos[3])

        ; RADIKALE METHODE: Hauptfenster erneut erstellen
        _LogInfo("Neukreation des Hauptfensters gestartet")

        ; 1. Speichere aktuellen Datenbank- und Tabellenzustand
        Local $sSavedDB = $g_sCurrentDB
        Local $sSavedTable = $g_sCurrentTable
        _LogInfo("Gespeicherte DB: " & $sSavedDB & ", Tabelle: " & $sSavedTable)

        ; 2. Aktuelle Parameter des Fensters sichern
        Local $sTitle = WinGetTitle($g_hGUI)
        Local $aPos = WinGetPos($g_hGUI)

        ; 3. Erstes Fenster schließen
        GUIDelete($g_hGUI)

        ; 4. Neues Hauptfenster mit identischen Parametern erstellen
        $g_hGUI = GUICreate($sTitle, $aPos[2], $aPos[3], $aPos[0], $aPos[1])

        ; 5. Standardkomponenten wiederherstellen
        _CreateMainGUI()

        ; 6. Fenster anzeigen
        GUISetState(@SW_SHOW, $g_hGUI)

        ; 7. Datenbank wieder öffnen, wenn eine ausgewählt war
        If $sSavedDB <> "" Then
            _LogInfo("Stelle Datenbankverbindung wieder her: " & $sSavedDB)
            _OpenDatabaseFile($sSavedDB)

            ; 8. Wenn eine Tabelle ausgewählt war, wähle sie wieder und lade Daten
            If $sSavedTable <> "" Then
                _LogInfo("Wähle Tabelle wieder aus: " & $sSavedTable)
                $g_sCurrentTable = $sSavedTable
                GUICtrlSetData($idTableCombo, $sSavedTable, $sSavedTable)
                _LoadDatabaseData()
            EndIf
        EndIf

        ; 9. Archiv-Buttons wieder aktivieren, falls ein Extraktionsverzeichnis existiert
        If $g_sExtractDir <> "" And FileExists($g_sExtractDir) Then
            _LogInfo("Aktiviere Archiv-Buttons, Extraktionsverzeichnis existiert: " & $g_sExtractDir)
            GUICtrlSetState($idBtnViewArchive, $GUI_ENABLE)
            GUICtrlSetState($idBtnOpenExtrDir, $GUI_ENABLE)
            GUICtrlSetState($idFileViewArchive, $GUI_ENABLE)
            GUICtrlSetState($idFileOpenExtrDir, $GUI_ENABLE)
        EndIf

        _LogInfo("Hauptfenster erfolgreich neu erstellt")

        ; Zustand aktualisieren
        $g_bSQLEditorMode = False

        _LogInfo("SQL-Editor-Modus deaktiviert mit radikaler Methode")
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SaveListViewState
; Beschreibung: Speichert den aktuellen Zustand der ListView für spätere Wiederherstellung
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SaveListViewState()
    Local $hListView = GUICtrlGetHandle($g_idListView)
    Local $iItems = _GUICtrlListView_GetItemCount($hListView)
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)

    ; Spaltenüberschriften speichern
    Local $aColInfo[$iColumns][2]
    For $i = 0 To $iColumns - 1
        Local $aColTemp = _GUICtrlListView_GetColumn($hListView, $i)
        $aColInfo[$i][0] = $aColTemp[5]  ; Text
        $aColInfo[$i][1] = _GUICtrlListView_GetColumnWidth($hListView, $i)  ; Breite
    Next
    $g_aListViewColBackup = $aColInfo

    ; Daten speichern
    Local $aData[$iItems][$iColumns]
    For $i = 0 To $iItems - 1
        For $j = 0 To $iColumns - 1
            $aData[$i][$j] = _GUICtrlListView_GetItemText($hListView, $i, $j)
        Next
    Next
    $g_aListViewBackup = $aData

    _LogInfo("ListView-Status gespeichert: " & $iItems & " Zeilen, " & $iColumns & " Spalten")
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_RestoreListViewState
; Beschreibung: Stellt den gespeicherten Zustand der ListView wieder her
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_RestoreListViewState()
    If Not IsArray($g_aListViewBackup) Or UBound($g_aListViewBackup, 0) < 1 Then
        _LogWarning("Kein Backup zum Wiederherstellen vorhanden")
        Return
    EndIf

    Local $hListView = GUICtrlGetHandle($g_idListView)
    Local $iItems = UBound($g_aListViewBackup, 1)
    Local $iColumns = UBound($g_aListViewBackup, 2)

    ; ListView leeren
    _GUICtrlListView_DeleteAllItems($hListView)

    ; Alle Spalten löschen
    While _GUICtrlListView_GetColumnCount($hListView) > 0
        _GUICtrlListView_DeleteColumn($hListView, 0)
    WEnd

    ; Debug-Hinweis
    _LogInfo("_SQL_RestoreListViewState: Wiederherstellung von " & $iItems & " Zeilen und " & UBound($g_aListViewColBackup, 1) & " Spalten")

    ; Spalten wiederherstellen
    For $i = 0 To UBound($g_aListViewColBackup, 1) - 1
        _GUICtrlListView_AddColumn($hListView, $g_aListViewColBackup[$i][0], $g_aListViewColBackup[$i][1])
    Next

    ; Daten wiederherstellen
    For $i = 0 To $iItems - 1
        Local $iIndex = _GUICtrlListView_AddItem($hListView, $g_aListViewBackup[$i][0])
        For $j = 1 To $iColumns - 1
            _GUICtrlListView_AddSubItem($hListView, $iIndex, $g_aListViewBackup[$i][$j], $j)
        Next
    Next

    ; Sicherstellen, dass ListView sichtbar ist
    GUICtrlSetState($g_idListView, $GUI_SHOW)

    _LogInfo("ListView-Status wiederhergestellt: " & $iItems & " Zeilen, " & $iColumns & " Spalten")
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_LoadDatabases
; Beschreibung: Füllt die Datenbank-Combo mit verfügbaren Datenbanken
; Rückgabe..: Erfolg - True
;             Fehler - False
; ===============================================================================================================================
Func _SQL_LoadDatabases()
    ; Aktuell ausgewählten Eintrag merken
    Local $sCurrentDB = GUICtrlRead($g_idSQLDbCombo)

    ; Liste leeren
    GUICtrlSetData($g_idSQLDbCombo, "")

    ; SQLite-Datenbankdateien im Programmverzeichnis suchen
    Local $aDBFiles = _FileListToArray(@ScriptDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES)
    If @error Then
        _LogWarning("Keine Datenbankdateien im Programmverzeichnis gefunden")
    Else
        ; Datenbankdateien zur Combo hinzufügen
        Local $sDBList = ""
        For $i = 1 To $aDBFiles[0]
            $sDBList &= @ScriptDir & "\" & $aDBFiles[$i] & "|"
        Next
        GUICtrlSetData($g_idSQLDbCombo, StringTrimRight($sDBList, 1))
    EndIf

    ; Extraktionsverzeichnis durchsuchen, falls vorhanden
    If $g_sExtractDir <> "" And FileExists($g_sExtractDir) Then
        Local $aExtractDBFiles = _FileListToArray($g_sExtractDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES, True)
        If Not @error Then
            Local $sExtractDBList = ""
            For $i = 1 To $aExtractDBFiles[0]
                $sExtractDBList &= $aExtractDBFiles[$i] & "|"
            Next
            GUICtrlSetData($g_idSQLDbCombo, StringTrimRight($sExtractDBList, 1))
        EndIf
    EndIf

    ; Falls aktuell ausgewählte Datenbank vorhanden, wieder auswählen
    If $sCurrentDB <> "" Then
        GUICtrlSetData($g_idSQLDbCombo, $sCurrentDB, $sCurrentDB)
    ElseIf $g_sCurrentDB <> "" Then
        GUICtrlSetData($g_idSQLDbCombo, $g_sCurrentDB, $g_sCurrentDB)
    EndIf

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_LoadTables
; Beschreibung: Lädt die Tabellen der ausgewählten Datenbank in die Tabellen-Combo
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SQL_LoadTables($sDBPath)
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        Return SetError(1, 0, False)
    EndIf

    ; Tabellenliste abfragen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    ; Liste leeren
    GUICtrlSetData($g_idSQLTableCombo, "")

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogWarning("Keine Tabellen in der Datenbank gefunden: " & $sDBPath)
        Return False
    EndIf

    ; Tabellen zur Combo hinzufügen
    Local $sTableList = ""
    For $i = 1 To $iRows
        $sTableList &= $aResult[$i][0] & "|"
    Next
    GUICtrlSetData($g_idSQLTableCombo, StringTrimRight($sTableList, 1))

    ; Erste Tabelle auswählen
    If $iRows > 0 Then
        GUICtrlSetData($g_idSQLTableCombo, $aResult[1][0], $aResult[1][0])
        
        ; Spalten für Autovervollständigung laden
        $g_aTableColumns = _GetTableColumns($sDBPath, $aResult[1][0])
    EndIf

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ExecuteQuery
; Beschreibung: Führt eine SELECT-Abfrage aus und zeigt die Ergebnisse in der ListView an
; Parameter.: $sSQL - SQL-Abfrage
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SQL_ExecuteQuery($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Abfrage fehlgeschlagen: Keine Datenbank ausgewählt")
        Return SetError(1, 0, False)
    EndIf

    ; Statusmeldung setzen
    _SetStatus("Führe SQL-Abfrage aus...")

    ; ListView leeren
    _GUICtrlListView_DeleteAllItems($g_idListView)
    _DeleteAllListViewColumns($g_idListView)

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        Return SetError(2, 0, False)
    EndIf

    ; Abfrage ausführen
    Local $aResult, $iRows, $iColumns
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Then
        Local $sError = _SQLite_ErrMsg()
        _SetStatus("SQL-Fehler: " & $sError)
        _LogError("SQL-Fehler: " & $sError)
        Return SetError(3, 0, False)
    EndIf

    ; Wenn keine Ergebnisse, Meldung anzeigen
    If $iRows = 0 Then
        _SetStatus("Abfrage ausgeführt. Keine Ergebnisse.")
        _LogInfo("SQL-Abfrage ausgeführt. Keine Ergebnisse.")
        Return False
    EndIf

    ; Spaltenüberschriften zur ListView hinzufügen
    For $i = 0 To $iColumns - 1
        _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$i], 100)
    Next

    ; Daten zur ListView hinzufügen
    For $i = 1 To $iRows
        Local $iIndex = _GUICtrlListView_AddItem($g_idListView, $aResult[$i][0])
        For $j = 1 To $iColumns - 1
            _GUICtrlListView_AddSubItem($g_idListView, $iIndex, $aResult[$i][$j], $j)
        Next
    Next

    ; Spaltenbreiten automatisch anpassen
    For $i = 0 To $iColumns - 1
        _GUICtrlListView_SetColumnWidth($g_idListView, $i, $LVSCW_AUTOSIZE_USEHEADER)
    Next

    ; Statusmeldung aktualisieren
    _SetStatus("Abfrage erfolgreich ausgeführt. " & $iRows & " Zeilen, " & $iColumns & " Spalten.")
    _LogInfo("SQL-Abfrage erfolgreich ausgeführt. " & $iRows & " Zeilen, " & $iColumns & " Spalten.")

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ExecuteCommand
; Beschreibung: Führt einen SQL-Befehl (INSERT, UPDATE, DELETE, etc.) aus
; Parameter.: $sSQL - SQL-Befehl
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SQL_ExecuteCommand($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Befehl fehlgeschlagen: Keine Datenbank ausgewählt")
        Return SetError(1, 0, False)
    EndIf

    ; Statusmeldung setzen
    _SetStatus("Führe SQL-Befehl aus...")

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        Return SetError(2, 0, False)
    EndIf

    ; Befehl ausführen
    Local $iRet = _SQLite_Exec($hDB, $sSQL)

    ; Anzahl der betroffenen Zeilen ermitteln
    Local $iChanges = _SQLite_Changes($hDB)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Then
        Local $sError = _SQLite_ErrMsg()
        _SetStatus("SQL-Fehler: " & $sError)
        _LogError("SQL-Fehler: " & $sError)
        Return SetError(3, 0, False)
    EndIf

    ; Statusmeldung aktualisieren
    _SetStatus("Befehl erfolgreich ausgeführt. " & $iChanges & " Zeilen betroffen.")
    _LogInfo("SQL-Befehl erfolgreich ausgeführt. " & $iChanges & " Zeilen betroffen.")

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateSyntaxHighlighting
; Beschreibung: Aktualisiert das Syntax-Highlighting im RichEdit-Control
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_UpdateSyntaxHighlighting()
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If $sText = "" Then Return

    ; Aktuelle Cursor-Position speichern
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iSelStart = $aSel[0]
    Local $iSelEnd = $aSel[1]

    ; Text tokenisieren
    Local $aTokens = _SQL_TokenizeSQL($sText)

    ; RichEdit leeren
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")

    ; Tokens mit Formatierung einfügen
    For $i = 0 To UBound($aTokens) - 1
        Local $sToken = $aTokens[$i][0]
        Local $iType = $aTokens[$i][1]

        ; Farbe vor jedem Token zurücksetzen, um Vererbung zu vermeiden
        _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000) ; Standard: Schwarz
        
        Switch $iType
            Case $TOKEN_KEYWORD
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x0000FF) ; Blau für Keywords
            Case $TOKEN_STRING
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x008000) ; Grün für Strings
            Case $TOKEN_NUMBER
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x800000) ; Dunkelrot für Zahlen
            Case $TOKEN_COMMENT
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x808080) ; Grau für Kommentare
            Case $TOKEN_OPERATOR
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x800080) ; Lila für Operatoren
        EndSwitch

        _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sToken)
    Next

    ; Cursor-Position wiederherstellen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iSelStart, $iSelEnd)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_TokenizeSQL
; Beschreibung: Zerlegt einen SQL-Text in Tokens für das Syntax-Highlighting
; Parameter.: $sSQL - Der zu zerlegende SQL-Text
; Rückgabe..: Ein 2D-Array mit Tokens und deren Typen
; ===============================================================================================================================
Func _SQL_TokenizeSQL($sSQL)
    Local $aTokens[0][2] ; Spalte 0: Token, Spalte 1: Token-Typ

    ; Pre-Tokenisierung für Keywords
    ; Zerlege den gesamten Text in Worte, identifiziere Keywords durch exakten Vergleich
    Local $sUpperSQL = StringUpper($sSQL)
    
    ; Arrays für die Positionen aller Keywords im Text
    Local $aKeywordPos[0][3] ; [Start, Ende, Keyword]
    
    ; Suche nach jedem Keyword im Text
    For $i = 1 To $g_aSQLKeywords[0]
        Local $sKeyword = $g_aSQLKeywords[$i]
        Local $iPos = 1
        
        While 1
            $iPos = StringInStr($sUpperSQL, $sKeyword, 0, 1, $iPos)
            If $iPos = 0 Then ExitLoop
            
            ; Prüfen, ob das Keyword an dieser Position ein eigenständiges Wort ist
            Local $bIsValidStart = ($iPos = 1) Or Not StringIsAlNum(StringMid($sUpperSQL, $iPos-1, 1))
            Local $bIsValidEnd = ($iPos + StringLen($sKeyword) > StringLen($sUpperSQL)) Or Not StringIsAlNum(StringMid($sUpperSQL, $iPos + StringLen($sKeyword), 1))
            
            If $bIsValidStart And $bIsValidEnd Then
                ReDim $aKeywordPos[UBound($aKeywordPos) + 1][3]
                $aKeywordPos[UBound($aKeywordPos) - 1][0] = $iPos
                $aKeywordPos[UBound($aKeywordPos) - 1][1] = $iPos + StringLen($sKeyword) - 1
                $aKeywordPos[UBound($aKeywordPos) - 1][2] = $sKeyword
            EndIf
            
            $iPos += 1
        WEnd
    Next
    
    ; Sortiere Keywords nach Position (wichtig für die Tokenisierung)
    _ArraySort($aKeywordPos, 0, 0, 0, 0)

    Local $iLen = StringLen($sSQL)
    Local $i = 0
    
    While $i < $iLen
        Local $iCurrentPos = $i + 1
        Local $sChar = StringMid($sSQL, $iCurrentPos, 1)
        Local $bIsKeyword = False
        
        ; Prüfen, ob die aktuelle Position einem Keyword entspricht
        For $j = 0 To UBound($aKeywordPos) - 1
            If $iCurrentPos = $aKeywordPos[$j][0] Then
                ; Wir haben ein Keyword an dieser Position gefunden
                Local $sKeyword = StringMid($sSQL, $iCurrentPos, $aKeywordPos[$j][1] - $aKeywordPos[$j][0] + 1)
                _SQL_AddToken($aTokens, $sKeyword, $TOKEN_KEYWORD)
                $i = $aKeywordPos[$j][1]
                $bIsKeyword = True
                ExitLoop
            EndIf
        Next
        
        ; Falls wir ein Keyword verarbeitet haben, mit dem nächsten Zeichen fortfahren
        If $bIsKeyword Then
            $i += 1
            ContinueLoop
        EndIf

        ; Leerzeichen und Zeilenumbrüche
        If StringIsSpace($sChar) Then
            _SQL_AddToken($aTokens, $sChar, $TOKEN_NORMAL)
            $i += 1
            ContinueLoop
        EndIf

        ; Kommentare erkennen
        If $sChar = "-" And $i + 1 < $iLen And StringMid($sSQL, $i + 2, 1) = "-" Then
            ; Einzeiligen Kommentar bis zum Zeilenende sammeln
            Local $sComment = "--"
            $i += 2

            While $i < $iLen
                $sChar = StringMid($sSQL, $i + 1, 1)
                If $sChar = @CR Or $sChar = @LF Then ExitLoop
                $sComment &= $sChar
                $i += 1
            WEnd

            _SQL_AddToken($aTokens, $sComment, $TOKEN_COMMENT)
            ContinueLoop
        EndIf

        ; Strings erkennen
        If $sChar = "'" Or $sChar = '"' Then
            Local $sQuote = $sChar
            Local $sString = $sQuote
            $i += 1

            ; String-Inhalt sammeln
            While $i < $iLen
                $sChar = StringMid($sSQL, $i + 1, 1)
                $sString &= $sChar
                $i += 1

                ; Bei Escape-Sequenzen den nächsten Charakter mit erfassen
                If $sChar = "\" And $i < $iLen Then
                    $sString &= StringMid($sSQL, $i + 1, 1)
                    $i += 1
                ElseIf $sChar = $sQuote Then
                    ; Ende des Strings
                    ExitLoop
                EndIf
            WEnd

            _SQL_AddToken($aTokens, $sString, $TOKEN_STRING)
            ContinueLoop
        EndIf

        ; Zahlen erkennen
        If StringIsDigit($sChar) Then
            Local $sNumber = $sChar
            $i += 1

            ; Restliche Ziffern und ggf. Dezimalpunkt sammeln
            While $i < $iLen
                $sChar = StringMid($sSQL, $i + 1, 1)
                If Not StringIsDigit($sChar) And $sChar <> "." Then ExitLoop
                $sNumber &= $sChar
                $i += 1
            WEnd

            _SQL_AddToken($aTokens, $sNumber, $TOKEN_NUMBER)
            ContinueLoop
        EndIf

        ; Operatoren erkennen
        If StringInStr("+-*/=<>!%&|^~()[]{},;:", $sChar) Then
            _SQL_AddToken($aTokens, $sChar, $TOKEN_OPERATOR)
            $i += 1
            ContinueLoop
        EndIf

        ; Identifikatoren (beginnend mit Buchstaben oder Unterstrich)
        If StringIsAlpha($sChar) Or $sChar = "_" Then
            Local $sWord = $sChar
            $i += 1

            While $i < $iLen
                $sChar = StringMid($sSQL, $i + 1, 1)
                If Not StringIsAlNum($sChar) And $sChar <> "_" Then ExitLoop
                $sWord &= $sChar
                $i += 1
            WEnd

            ; Als normalen Text behandeln, da wir Keywords bereits behandelt haben
            _SQL_AddToken($aTokens, $sWord, $TOKEN_NORMAL)
            ContinueLoop
        EndIf

        ; Wenn wir hier ankommen, handelt es sich um ein unbekanntes Zeichen
        _SQL_AddToken($aTokens, $sChar, $TOKEN_NORMAL)
        $i += 1
    WEnd

    Return $aTokens
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_AddToken
; Beschreibung: Fügt einen Token zum Token-Array hinzu
; Parameter.: $aTokens - Token-Array (wird als Referenz übergeben)
;             $sToken - Token-Text
;             $iType - Token-Typ
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_AddToken(ByRef $aTokens, $sToken, $iType)
    ; Zum Array hinzufügen
    ReDim $aTokens[UBound($aTokens) + 1][2]
    $aTokens[UBound($aTokens) - 1][0] = $sToken
    $aTokens[UBound($aTokens) - 1][1] = $iType
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SaveToFile
; Beschreibung: Speichert eine SQL-Abfrage in eine Datei
; Parameter.: $sSQL - SQL-Abfrage
; Rückgabe..: Erfolg - True
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SQL_SaveToFile($sSQL)
    Local $sFile = FileSaveDialog("SQL-Abfrage speichern", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_PATHMUSTEXIST)
    If @error Then Return SetError(1, 0, False)

    ; Dateiendung hinzufügen, falls nicht vorhanden
    If StringRight($sFile, 4) <> ".sql" Then $sFile &= ".sql"

    ; Pfad merken
    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))

    ; Abfrage speichern
    If FileWrite($sFile, $sSQL) Then
        _SetStatus("SQL-Abfrage gespeichert: " & $sFile)
        _LogInfo("SQL-Abfrage gespeichert: " & $sFile)
        Return True
    Else
        _SetStatus("Fehler beim Speichern der SQL-Abfrage")
        _LogError("Fehler beim Speichern der SQL-Abfrage: " & $sFile)
        Return SetError(2, 0, False)
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_LoadFromFile
; Beschreibung: Lädt eine SQL-Abfrage aus einer Datei
; Rückgabe..: Erfolg - Geladene SQL-Abfrage
;             Fehler - Leerer String und @error gesetzt
; ===============================================================================================================================
Func _SQL_LoadFromFile()
    Local $sFile = FileOpenDialog("SQL-Abfrage laden", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_FILEMUSTEXIST)
    If @error Then Return SetError(1, 0, "")

    ; Pfad merken
    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))

    ; Datei laden
    Local $sSQL = FileRead($sFile)
    If @error Then
        _SetStatus("Fehler beim Laden der SQL-Abfrage")
        _LogError("Fehler beim Laden der SQL-Abfrage: " & $sFile)
        Return SetError(2, 0, "")
    EndIf

    _SetStatus("SQL-Abfrage geladen: " & $sFile)
    _LogInfo("SQL-Abfrage geladen: " & $sFile)
    Return $sSQL
EndFunc

; ===============================================================================================================================
; Func.....: _HandleSQLEditorEvents
; Beschreibung: Verarbeitet Events für den SQL-Editor (für die GUIGetMsg-Schleife)
; Parameter.: $iMsg - Die Ereignis-ID aus GUIGetMsg()
; Rückgabe..: True, wenn das Event verarbeitet wurde, sonst False
; ===============================================================================================================================
Func _HandleSQLEditorEvents($iMsg)
    ; Wenn SQL-Editor nicht aktiv ist, keine Events verarbeiten
    If Not $g_bSQLEditorMode Then Return False

    Switch $iMsg
        Case $g_idSQLDbCombo
            Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
            If $sDBPath <> "" Then
                $g_sCurrentDB = $sDBPath
                _SQL_LoadTables($sDBPath)
            EndIf
            Return True

        Case $g_idSQLTableCombo
            Local $sTable = GUICtrlRead($g_idSQLTableCombo)
            If $sTable <> "" Then
                ; Aktualisiere SQL-Statement mit der neuen Tabelle
                _LogInfo("ComboBox-Änderung: Aktualisiere SQL-Statement mit Tabelle: " & $sTable)
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "SELECT * FROM " & $sTable & " LIMIT 100;")
                _SQL_UpdateSyntaxHighlighting()
                
                ; Spalten für Autovervollständigung laden
                $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sTable)
            EndIf
            Return True

        Case $g_idSQLExecuteQueryBtn
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                _SQL_ExecuteQuery($sSQL)
            Else
                _SetStatus("Keine SQL-Abfrage eingegeben")
            EndIf
            Return True

        Case $g_idSQLExecuteCommandBtn
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                _SQL_ExecuteCommand($sSQL)
            Else
                _SetStatus("Kein SQL-Befehl eingegeben")
            EndIf
            Return True

        Case $g_idSQLSaveBtn
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                _SQL_SaveToFile($sSQL)
            Else
                _SetStatus("Nichts zum Speichern vorhanden")
            EndIf
            Return True

        Case $g_idSQLLoadBtn
            Local $sSQL = _SQL_LoadFromFile()
            If $sSQL <> "" Then
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                _SQL_UpdateSyntaxHighlighting()
            EndIf
            Return True

        Case $g_idSQLBackBtn
            _ToggleSQLEditorMode(False)
            Return True
    EndSwitch

    Return False
EndFunc