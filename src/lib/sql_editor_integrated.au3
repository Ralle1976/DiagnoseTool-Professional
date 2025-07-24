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
#include <StringConstants.au3>
#include <GuiListBox.au3>

#include "logging.au3"
#include "error_handler.au3"
#include "db_functions.au3"
#include "gui_functions.au3"  ; Enthält _DeleteAllListViewColumns
#include "sql_syntax_highlighter.au3" ; Neuer AdlibRegister-basierter Syntax-Highlighter
#include "sql_query_parser.au3" ; Verbesserte SQL-Abfrageverarbeitung

; ===============================================================================================================================
; Titel.......: SQL-Editor (Integriert)
; Beschreibung: Ein in das Hauptfenster integrierter Editor für SQLite-Abfragen mit Syntax-Highlighting
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-06
; Aktualisiert: 2025-04-11
; ===============================================================================================================================

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLDbCombo = 0            ; ID der Datenbank-Auswahlbox
Global $g_idSQLTableCombo = 0         ; ID der Tabellen-Auswahlbox
Global $g_idSQLExecuteBtn = 0         ; ID des Buttons zum Ausführen von Abfragen (ersetzt separate Buttons)
Global $g_idSQLSaveBtn = 0            ; ID des Buttons zum Speichern einer SQL-Abfrage
Global $g_idSQLLoadBtn = 0            ; ID des Buttons zum Laden einer SQL-Abfrage
Global $g_idSQLBackBtn = 0            ; ID des Buttons zum Zurückkehren zur normalen Ansicht
Global $g_sCurrentDB = ""             ; Aktuelle Datenbank-Datei
Global $g_bTriggerTextUpdate = False  ; Steuerung für Text-Update nach Selektion

; Externe globale Variablen (definiert in der Hauptdatei)
Global $g_idBtnSQLEditor              ; Button zum Umschalten SQL-Editor (in main_robust.au3 definiert)
Global $g_idStatus                    ; Statusbar-Control
Global $g_idListView                  ; ListView-Control
Global $idTableCombo                  ; Tabellen-Combo im Hauptfenster
Global $g_idBtnRefresh               ; Aktualisieren-Button im Hauptfenster

; SQL-Editor-Zustand
Global $g_bSQLEditorMode = False      ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_aListViewBackup[0][0]       ; Array zum Speichern des ListView-Zustands vor SQL-Editor-Aktivierung
Global $g_aListViewColBackup = 0      ; Array zum Speichern der Spaltenüberschriften

; Originale ListView-Position und -Größe
Global $g_iOrigListViewHeight = 0     ; Ursprüngliche Höhe der ListView
Global $g_iOrigListViewTop = 0        ; Ursprüngliche Y-Position der ListView

; Höhe des SQL-Editor-Panels
Global Const $SQL_EDITOR_HEIGHT = 200

; Optimiertes Include-Management - Nur die wirklich benötigten Dateien einbinden
; und redundante Includes vermeiden
#include "sql_editor_main.au3"       ; Basisklasse für den verbesserten SQL-Editor
#include "sql_query_parser.au3"      ; SQL-Abfrageverarbeitung
#include "sql_syntax_highlighter.au3" ; Optimierter Syntax-Highlighter (ohne Timer)

; Token-Typen für SQL-Syntax-Highlighting
Global Const $TOKEN_NORMAL = 0
Global Const $TOKEN_KEYWORD = 1
Global Const $TOKEN_STRING = 2
Global Const $TOKEN_NUMBER = 3
Global Const $TOKEN_COMMENT = 4
Global Const $TOKEN_OPERATOR = 5
Global Const $TOKEN_FUNCTION = 6     ; Zusätzlich für SQL-Funktionen

; Auto-Vervollständigung
Global $g_aTableColumns[0]            ; Spalten der aktuell ausgewählten Tabelle
Global $g_bAutoComplete = False       ; Flag für Auto-Vervollständigung
Global $g_idAutoCompleteList = 0      ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList = 0       ; Handle der Auto-Vervollständigungsliste

; Flag zur Steuerung des ersten Ladens - verhindert automatische Abfragen
Global $g_bSQLEditorFirstLoad = True
Global $g_bManualExecuteOnly = True  ; Wenn True, werden Abfragen nur durch expliziten Button-Klick ausgeführt

; Letzte Cursorposition für Auto-Vervollständigung
Global $g_iLastCursorPos = 0

; SQL-Schlüsselwörter für Syntax-Highlighting (erweitert)
Global $g_aSQLKeywords = StringSplit("SELECT,FROM,WHERE,INSERT,UPDATE,DELETE,JOIN,GROUP,ORDER,BY,HAVING,CREATE,ALTER,DROP,TABLE,VIEW,INDEX,TRIGGER,PRAGMA,AS,ON,AND,OR,NOT,NULL,IS,IN,BETWEEN,LIKE,GLOB,LIMIT,DISTINCT,ALL,UNION,CASE,WHEN,THEN,ELSE,END,EXISTS,INTO,VALUES,SET,FOREIGN,KEY,PRIMARY,REFERENCES,DEFAULT,UNIQUE,CHECK,CONSTRAINT,INTEGER,TEXT,BLOB,REAL,DATETIME,LEFT,RIGHT,INNER,OUTER,FULL,NATURAL,CROSS,USING,WITH,DESC,ASC,ASC,ORDER BY,GROUP BY,INNER JOIN,LEFT JOIN,RIGHT JOIN,OUTER JOIN,HAVING,SELECT DISTINCT,UNION ALL,CREATE TABLE,DROP TABLE,CREATE INDEX,DROP INDEX,PRIMARY KEY,FOREIGN KEY,NOT NULL,AUTOINCREMENT,ON DELETE,ON UPDATE,CASCADE,RESTRICT,SET NULL", ",", 1)

; SQL-Funktionen für Syntax-Highlighting
Global $g_aSQLFunctions = StringSplit("ABS,AVG,COUNT,MAX,MIN,RANDOM,ROUND,SUM,UPPER,LOWER,LENGTH,SUBSTR,REPLACE,TRIM,LTRIM,RTRIM,INSTR,DATE,TIME,DATETIME,JULIANDAY,STRFTIME,IFNULL,COALESCE,CAST", ",", 1)

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

    _LogInfo("Spaltennamen aus Tabelle " & $sTable & " geladen: " & _ArrayToString($aColumns, ", "))
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

    ; Globale Variablen zurücksetzen
    $g_bSQLEditorFirstLoad = True    ; Signalisieren, dass der Editor gerade initialisiert wird
    $g_bManualExecuteOnly = True     ; Nur manuelle Ausführungen erlauben

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

    ; Events für RichEdit-Control registrieren
    GUIRegisterMsg($WM_KEYUP, "_WM_KEYUP_RichEdit")
    GUIRegisterMsg($WM_KEYDOWN, "_WM_KEYDOWN_RichEdit")
    GUIRegisterMsg($WM_COMMAND, "_WM_COMMAND_Handler")

    ; Auto-Vervollständigungsliste vorbereiten (anfangs ausgeblendet)
    $g_idAutoCompleteList = GUICtrlCreateList("", $xCtrl, $yCtrl + 50, 200, 80)
    $g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)

    ; Buttons
    $yCtrl += 110
    ; Neuer Button für Ausführung (ersetzt die separaten Buttons für Query und Command)
    $g_idSQLExecuteBtn = GUICtrlCreateButton("Ausführen (F5)", $xCtrl, $yCtrl, 150, 30)

    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", $xCtrl + 160, $yCtrl, 100, 30)
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", $xCtrl + 270, $yCtrl, 100, 30)
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $xCtrl + $wCtrl - 100, $yCtrl, 100, 30)

    ; Panel abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1) ; Dummy-Gruppe zum Schließen

    ; Syntax-Highlighter initialisieren
    _SQL_SyntaxHighlighter_Initialize($g_hSQLRichEdit)

    ; Externe Referenzen für verbesserten SQL-Editor setzen
    $g_hGUI = $hGUI; Hauptfenster-Handle für Neuzeichnungszwecke

    _LogInfo("Integrierter SQL-Editor initialisiert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _WM_COMMAND_Handler
; Beschreibung: Behandelt WM_COMMAND-Nachrichten für die Auto-Vervollständigungsliste
; Parameter.: Standard-WM_COMMAND-Parameter
; Rückgabe..: $GUI_RUNDEFMSG um das Event weiterzuleiten
; ===============================================================================================================================
Func _WM_COMMAND_Handler($hWnd, $iMsg, $wParam, $lParam)
    Local $nNotifyCode = BitShift($wParam, 16) ; Obere 16 Bits
    Local $nID = BitAND($wParam, 0xFFFF) ; Untere 16 Bits
    Local $hCtrl = $lParam

    ; Auto-Vervollständigungsliste
    If $hCtrl = $g_hAutoCompleteList And $nNotifyCode = $LBN_DBLCLK Then
        _SQL_HandleAutoCompleteSelection()
        Return $GUI_RUNDEFMSG
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _WM_KEYDOWN_RichEdit
; Beschreibung: Event-Handler für Tastatureingaben im RichEdit-Control
; Parameter.: Standard-WM_KEYDOWN-Parameter
; Rückgabe..: $GUI_RUNDEFMSG um das Event weiterzuleiten
; ===============================================================================================================================
Func _WM_KEYDOWN_RichEdit($hWnd, $iMsg, $wParam, $lParam)
    ; Prüfen, ob wir uns im SQL-Editor-Modus befinden
    If $g_bSQLEditorMode Then
        ; RichEdit-Control erkennen
        Local $hWndFrom = HWnd(GUICtrlGetHandle($g_hSQLRichEdit))

        If $hWnd = $hWndFrom Then
            ; F5-Taste drücken zum Ausführen der Abfrage
            If $wParam = 0x74 Then ; F5
                Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
                If $sSQL <> "" Then
                    ; Verbesserte SQL-Ausführungsfunktion verwenden
                    _SQL_ImprovedExecuteQueries($sSQL)
                Else
                    _SetStatus("Keine SQL-Abfrage eingegeben")
                EndIf
                Return $GUI_RUNDEFMSG
            EndIf

            ; Auto-Vervollständigungsliste aktiv?
            If $g_bAutoComplete And GUICtrlGetState($g_idAutoCompleteList) = $GUI_SHOW Then
                ; Pfeiltasten für Navigation in der Liste
                If $wParam = 0x26 Then ; Pfeil nach oben
                    ; Vorherigen Eintrag auswählen
                    Local $iCurSel = _GUICtrlListBox_GetCurSel($g_idAutoCompleteList)
                    If $iCurSel > 0 Then
                        _GUICtrlListBox_SetCurSel($g_idAutoCompleteList, $iCurSel - 1)
                    EndIf
                    Return $GUI_RUNDEFMSG
                ElseIf $wParam = 0x28 Then ; Pfeil nach unten
                    ; Nächsten Eintrag auswählen
                    Local $iCurSel = _GUICtrlListBox_GetCurSel($g_idAutoCompleteList)
                    Local $iCount = _GUICtrlListBox_GetCount($g_idAutoCompleteList)
                    If $iCurSel < $iCount - 1 Then
                        _GUICtrlListBox_SetCurSel($g_idAutoCompleteList, $iCurSel + 1)
                    EndIf
                    Return $GUI_RUNDEFMSG
                ElseIf $wParam = 0x0D Then ; Enter
                    ; Ausgewählten Eintrag einfügen
                    _SQL_HandleAutoCompleteSelection()
                    Return $GUI_RUNDEFMSG
                ElseIf $wParam = 0x1B Then ; Escape
                    ; Auto-Vervollständigung abbrechen
                    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
                    $g_bAutoComplete = False
                    Return $GUI_RUNDEFMSG
                EndIf
            EndIf
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
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
            ; Syntax-Highlighting aktualisieren (verzögert, um die Benutzererfahrung zu verbessern)
            If $g_bTriggerTextUpdate Or _
               ($wParam >= 0x30 And $wParam <= 0x5A) Or _ ; Buchstaben und Zahlen
               $wParam = 0x20 Or _ ; Leertaste
               $wParam = 0x0D Or _ ; Enter
               $wParam = 0x08 Or _ ; Backspace
               $wParam = 0x2E Then ; Delete
                $g_bTriggerTextUpdate = False

                ; Keine automatischen Anforderungen an den Syntax-Highlighter mehr
                ; Stattdessen Syntax-Highlighting direkt und einmalig ausführen
        _SQL_SyntaxHighlighter_Update($g_hSQLRichEdit)
            EndIf

            ; Wenn Punkt gedrückt wurde, Auto-Vervollständigung für Tabellenspalten aktivieren
            If $wParam = 0xBE Then ; Punkt
                _SQL_ShowColumnAutoComplete()
            EndIf

            ; Aktualisiere Cursorposition für die Auto-Vervollständigung
            $g_iLastCursorPos = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)[0]
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ShowColumnAutoComplete
; Beschreibung: Zeigt die Auto-Vervollständigungsliste für Tabellenspalten an
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ShowColumnAutoComplete()
    ; Prüfen, ob wir Spalteninformationen haben
    If UBound($g_aTableColumns) = 0 Then
        _LogInfo("Keine Spalteninformationen für Auto-Vervollständigung verfügbar")
        Return
    EndIf

    ; Aktuellen Text und Cursorposition ermitteln
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCurPos = $aSel[0]

    _LogInfo("Auto-Vervollständigung angefordert an Position " & $iCurPos & " im Text")

    ; Position des Punkts ermitteln
    Local $iDotPos = StringInStr(StringLeft($sText, $iCurPos), ".", 0, -1)
    If $iDotPos = 0 Then
        _LogInfo("Kein Punkt in der Nähe des Cursors gefunden")
        Return
    EndIf

    ; Tabellenalias oder Tabellennamen vor dem Punkt ermitteln
    Local $sTablePart = ""
    Local $i = $iDotPos - 1
    While $i > 0
        Local $sChar = StringMid($sText, $i, 1)
        If Not StringRegExp($sChar, "[a-zA-Z0-9_]") Then
            ExitLoop
        EndIf
        $sTablePart = $sChar & $sTablePart
        $i -= 1
    WEnd

    _LogInfo("Tabellenname oder Alias vor dem Punkt: " & $sTablePart)

    ; Tabellenname oder Alias ermitteln
    Local $sTableName = GUICtrlRead($g_idSQLTableCombo)

    ; Auto-Vervollständigungsliste anzeigen - mit expliziter Größenanpassung an den Inhalt
    _GUICtrlListBox_ResetContent($g_idAutoCompleteList)

    For $i = 0 To UBound($g_aTableColumns) - 1
        _GUICtrlListBox_AddString($g_idAutoCompleteList, $g_aTableColumns[$i])
    Next

    _LogInfo("Autovervollständigungsliste mit " & UBound($g_aTableColumns) & " Einträgen gefüllt")

    ; Position der Liste anpassen - Absolute Position im Hauptfenster verwenden
    Local $aRichEditPos = ControlGetPos($g_hGUI, "", $g_hSQLRichEdit)
    Local $aGUIPos = WinGetPos($g_hGUI)

    ; Position im Hauptfenster berechnen - unterhalb des RichEdit-Controls
    Local $iListX = $aRichEditPos[0] + 20
    Local $iListY = $aRichEditPos[1] + $aRichEditPos[3] / 2

    ; Verhindere, dass die Liste über den Bildschirmrand hinausragt
    If $iListX + 250 > $aGUIPos[2] Then
        $iListX = $aGUIPos[2] - 250
    EndIf

    ; Passt die Größe der Liste basierend auf der Anzahl der Einträge an
    Local $iListHeight = (UBound($g_aTableColumns) * 20 < 150) ? UBound($g_aTableColumns) * 20 : 150
    Local $iListWidth = 250 ; Breitere Liste für bessere Lesbarkeit

    ; Liste explizit neu positionieren und dimensionieren
    WinMove($g_hAutoCompleteList, "", $iListX, $iListY, $iListWidth, $iListHeight)
    _LogInfo("Autovervollständigungsliste positioniert bei X:" & $iListX & ", Y:" & $iListY)

    ; Liste anzeigen und ersten Eintrag auswählen
    GUICtrlSetState($g_idAutoCompleteList, $GUI_SHOW)
    _GUICtrlListBox_SetCurSel($g_idAutoCompleteList, 0)

    ; Sicherstellen, dass die Liste im Vordergrund ist
    WinSetOnTop($g_hAutoCompleteList, "", 1)
    _LogInfo("Autovervollständigungsliste sichtbar gemacht")

    $g_bAutoComplete = True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_HandleAutoCompleteSelection
; Beschreibung: Fügt den ausgewählten Eintrag aus der Auto-Vervollständigungsliste ein
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_HandleAutoCompleteSelection()
    ; Ausgewählten Eintrag ermitteln
    Local $iSel = _GUICtrlListBox_GetCurSel($g_idAutoCompleteList)
    If $iSel = -1 Then
        GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
        $g_bAutoComplete = False
        Return
    EndIf

    Local $sSelected = _GUICtrlListBox_GetText($g_idAutoCompleteList, $iSel)

    ; Aktuellen Text und Cursorposition ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCurPos = $aSel[0]

    ; Einfügen des ausgewählten Eintrags
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iCurPos, $iCurPos)
    _GUICtrlRichEdit_InsertText($g_hSQLRichEdit, $sSelected)

    ; Liste ausblenden
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
    $g_bAutoComplete = False

    ; Verbesserte Syntax-Highlighting-Initialisierung
    _SQL_InitializeKeywordHighlighting($g_hSQLRichEdit)

    _LogInfo("Auto-Vervollständigung: " & $sSelected & " eingefügt")
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

        ; Sichere Flags für ersten Ladevorgang setzen
        $g_bSQLEditorFirstLoad = True    ; Ersten Ladevorgang signalisieren, verhindert Auto-Ausführung
        $g_bManualExecuteOnly = True     ; Nur explizite Button-Klicks erlauben

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
                ; WICHTIG: Keine automatische Ausführung der Abfrage hier
            EndIf

        ; Synchronisiere mit dem Tabellen-Dropdown im Hauptfenster
        Local $sCurrentTable = GUICtrlRead($idTableCombo)
        If $sCurrentTable <> "" Then
            GUICtrlSetData($g_idSQLTableCombo, $sCurrentTable, $sCurrentTable)
        EndIf

        $g_bSQLEditorMode = True
    Else
        _LogInfo("Deaktiviere SQL-Editor-Modus - Verbesserte Methode")

        ; Button-Text zurücksetzen
        GUICtrlSetData($g_idBtnSQLEditor, "SQL-Editor")

        ; SQL-Editor-Panel ausblenden
        GUICtrlSetState($g_idSQLEditorPanel, $GUI_HIDE)

        ; Auto-Vervollständigung ausblenden (falls aktiv)
        GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
        $g_bAutoComplete = False

        ; Verbesserte Methode zum Zurückkehren zum normalen Modus
        Local $sSavedDB = $g_sCurrentDB
        Local $sSavedTable = $g_sCurrentTable

        ; ListView zur ursprünglichen Position zurücksetzen
        ControlMove($g_hGUI, "", $g_idListView, 2, $g_iOrigListViewTop, _
                    ControlGetPos($g_hGUI, "", $g_idListView)[2], $g_iOrigListViewHeight)

        ; Fix für das Problem beim Wechseln zurück: Speichere aktuelle Tabelle
        Local $sTableBefore = GUICtrlRead($idTableCombo)

        ; Wenn dieselbe Tabelle erneut geladen werden soll, laden wir die Daten neu
        If $sSavedTable <> "" And $sSavedTable = $sTableBefore Then
            ; Datenverbindung neu öffnen
            _LogInfo("Stelle Datenbankverbindung wieder her: " & $sSavedDB)
            _OpenDatabaseFile($sSavedDB)

            ; Tabelle direkt auswählen ohne vorherige Auswahl der ersten Tabelle
            $g_sCurrentTable = $sSavedTable
            GUICtrlSetData($idTableCombo, $sSavedTable, $sSavedTable)
            _LoadDatabaseData()
        EndIf

        ; Zustand aktualisieren
        $g_bSQLEditorMode = False

        _LogInfo("SQL-Editor-Modus deaktiviert mit verbesserter Methode")
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
; Func.....: _SQL_ExecuteQueries
; Beschreibung: Führt mehrere SQL-Anweisungen (getrennt durch Semikolon) aus - Verbesserte Version
; Parameter.: $sSQL - Ein oder mehrere SQL-Anweisungen, getrennt durch Semikolon
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_ExecuteQueries($sSQL)
    ; Überprüfe, ob eine Datenbank ausgewählt wurde
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath = "" Then
        _SetStatus("Fehler: Keine Datenbank ausgewählt")
        _LogError("SQL-Abfrage fehlgeschlagen: Keine Datenbank ausgewählt")
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

        ; Prüfen, ob es sich um eine SELECT-Abfrage handelt
        Local $bIsSelect = StringRegExp(StringUpper($sQuery), "^\s*SELECT")
        _LogInfo("SQL-Ausführung: Verarbeite SQL #" & ($i+1) & ": " & (StringLen($sQuery) > 100 ? StringLeft($sQuery, 100) & "..." : $sQuery))

        If $bIsSelect Then
            ; SELECT-Abfrage ausführen mit Wiederholungsversuchen
            Local $aResult, $iRows, $iColumns
            _LogInfo("SQL-Ausführung: Führe SELECT-Abfrage aus")
            Local $iRet = _SQLite_GetTable2d($hDB, $sQuery, $aResult, $iRows, $iColumns)

            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler bei SELECT: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf

            _LogInfo("SQL-Ausführung: SELECT-Abfrage erfolgreich: " & $iRows & " Zeilen, " & $iColumns & " Spalten")

            ; Anzeigen der Ergebnisse nur für die letzte Abfrage oder wenn es die einzige ist
            If $i = UBound($aQueries) - 1 Or UBound($aQueries) = 1 Then
                _LogInfo("SQL-Ausführung: Bereite ListView für Ergebnisanzeige vor")

                ; ListView leeren
                _GUICtrlListView_DeleteAllItems($g_idListView)
                _DeleteAllListViewColumns($g_idListView)

                ; Wenn keine Ergebnisse, Meldung anzeigen
                If $iRows = 0 Then
                    _SetStatus("Abfrage ausgeführt. Keine Ergebnisse.")
                    $iSuccessCount += 1
                    ContinueLoop
                EndIf

                ; Spaltenüberschriften zur ListView hinzufügen
                _LogInfo("SQL-Ausführung: Füge " & $iColumns & " Spalten zur ListView hinzu")
                For $j = 0 To $iColumns - 1
                    _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$j], 100)
                Next

                ; Daten zur ListView hinzufügen
                _LogInfo("SQL-Ausführung: Füge " & $iRows & " Zeilen zur ListView hinzu")
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
                _LogInfo("SQL-Ausführung: Aktualisiere ListView-Darstellung")
                GUICtrlSetState($g_idListView, $GUI_SHOW)
                _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
                _WinAPI_UpdateWindow(GUICtrlGetHandle($g_idListView))

                $bHasResults = True
            EndIf

            $iSuccessCount += 1
            Else
            ; Andere Anweisungen ausführen (INSERT, UPDATE, DELETE, etc.)
            _LogInfo("SQL-Ausführung: Führe Nicht-SELECT-Anweisung aus")
            Local $iRet = _SQLite_Exec($hDB, $sQuery)

            If @error Or $iRet <> $SQLITE_OK Then
            Local $sError = _SQLite_ErrMsg()
            _SetStatus("SQL-Fehler: " & $sError)
            _LogError("SQL-Fehler bei Nicht-SELECT: " & $sError)
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
        Return True
    Else
        _SetStatus("Ausführung mit Fehlern: " & $iSuccessCount & " erfolgreich, " & $iErrorCount & " fehlgeschlagen.")
        _LogWarning("SQL-Ausführung: " & $iErrorCount & " Anweisungen fehlgeschlagen")
        Return False
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SplitQueries
; Beschreibung: Teilt einen SQL-String in einzelne Anweisungen auf und berücksichtigt dabei Strings
; Parameter.: $sSQL - SQL-String mit mehreren Anweisungen
; Rückgabe..: Array mit einzelnen SQL-Anweisungen
; ===============================================================================================================================
Func _SQL_SplitQueries($sSQL)
    Local $aQueries[1] = [""]
    Local $iIndex = 0
    Local $iLen = StringLen($sSQL)
    Local $bInString = False
    Local $sStringChar = ""

    For $i = 1 To $iLen
        Local $sChar = StringMid($sSQL, $i, 1)

        ; String-Grenzen erkennen
        If ($sChar = "'" Or $sChar = '"') And (Not $bInString Or $sChar = $sStringChar) Then
            ; Prüfen auf Escape-Sequenzen
            Local $bEscaped = False
            If $i > 1 And StringMid($sSQL, $i-1, 1) = "\" Then
                Local $iEscapeCount = 0
                Local $j = $i - 1
                While $j > 0 And StringMid($sSQL, $j, 1) = "\"
                    $iEscapeCount += 1
                    $j -= 1
                WEnd
                $bEscaped = (Mod($iEscapeCount, 2) = 1) ; Ungerade Anzahl = Escaped
            EndIf

            If Not $bEscaped Then
                If $bInString And $sChar = $sStringChar Then
                    $bInString = False
                ElseIf Not $bInString Then
                    $bInString = True
                    $sStringChar = $sChar
                EndIf
            EndIf
        EndIf

        ; Semikolon als Trennzeichen nur erkennen, wenn nicht in einem String
        If $sChar = ";" And Not $bInString Then
            $iIndex += 1
            ReDim $aQueries[$iIndex + 1]
            $aQueries[$iIndex] = ""
        Else
            $aQueries[$iIndex] &= $sChar
        EndIf
    Next

    ; Whitespace am Anfang und Ende jeder Anweisung entfernen
    For $i = 0 To $iIndex
        $aQueries[$i] = StringStripWS($aQueries[$i], $STR_STRIPLEADING + $STR_STRIPTRAILING)
    Next

    Return $aQueries
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateSyntaxHighlighting
; Beschreibung: Aktualisiert das Syntax-Highlighting im RichEdit-Control
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_UpdateSyntaxHighlighting()
    ; Debug-Information
    _LogInfo("_SQL_UpdateSyntaxHighlighting() aufgerufen")

    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If $sText = "" Then Return

    ; Aktuelle Cursor-Position speichern
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iSelStart = $aSel[0]
    Local $iSelEnd = $aSel[1]

    ; Debug-Information
    _LogInfo("Aktualisiere Syntax-Highlighting für: " & StringLeft($sText, 50) & "...")

    ; Text tokenisieren
    Local $aTokens = _SQL_TokenizeSQL($sText)

    ; Debug-Information
    _LogInfo("Tokenisierung abgeschlossen: " & UBound($aTokens) & " Tokens gefunden")

    ; Text vollständig löschen und neu setzen
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")

    ; Tokens mit Formatierung einfügen
    For $i = 0 To UBound($aTokens) - 1
        Local $sToken = $aTokens[$i][0]
        Local $iType = $aTokens[$i][1]

        ; Farbe vor jedem Token explizit setzen
        _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000) ; Standard: Schwarz

        Switch $iType
            Case $TOKEN_KEYWORD
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0xFF0000) ; Blau für Keywords
            Case $TOKEN_STRING
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x008000) ; Grün für Strings
            Case $TOKEN_NUMBER
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000080) ; Dunkelrot für Zahlen
            Case $TOKEN_COMMENT
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x808080) ; Grau für Kommentare
            Case $TOKEN_OPERATOR
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x800080) ; Lila für Operatoren
            Case $TOKEN_FUNCTION
                _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x808000) ; Türkis für Funktionen
        EndSwitch

        _GUICtrlRichEdit_AppendText($g_hSQLRichEdit, $sToken)
    Next

    ; Cursor-Position wiederherstellen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iSelStart, $iSelEnd)

    ; Debug-Information
    _LogInfo("Syntax-Highlighting abgeschlossen")
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_TokenizeSQL
; Beschreibung: Zerlegt einen SQL-Text in Tokens für das Syntax-Highlighting
; Parameter.: $sSQL - Der zu zerlegende SQL-Text
; Rückgabe..: Ein 2D-Array mit Tokens und deren Typen
; ===============================================================================================================================
Func _SQL_TokenizeSQL($sSQL)
    Local $aTokens[0][2] ; Spalte 0: Token, Spalte 1: Token-Typ

    ; Pre-Tokenisierung für Keywords und Funktionen
    Local $sUpperSQL = StringUpper($sSQL)

    ; Arrays für die Positionen aller Keywords im Text
    Local $aKeywordPos[0][3] ; [Start, Ende, Keyword]

    ; Suche nach allen SQL-Keywords
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

    ; Suche nach allen SQL-Funktionen
    Local $aFunctionPos[0][3] ; [Start, Ende, Funktion]

    For $i = 1 To $g_aSQLFunctions[0]
        Local $sFunction = $g_aSQLFunctions[$i]
        Local $iPos = 1

        While 1
            $iPos = StringInStr($sUpperSQL, $sFunction, 0, 1, $iPos)
            If $iPos = 0 Then ExitLoop

            ; Prüfen, ob das Funktionsname an dieser Position ein eigenständiges Wort ist
            ; und ob danach eine Klammer folgt
            Local $bIsValidStart = ($iPos = 1) Or Not StringIsAlNum(StringMid($sUpperSQL, $iPos-1, 1))
            Local $bIsValidEnd = False

            ; Suche nach einer öffnenden Klammer nach der Funktion
            Local $iPosAfterFunc = $iPos + StringLen($sFunction)
            For $j = $iPosAfterFunc To _Min($iPosAfterFunc + 10, StringLen($sUpperSQL))
                Local $sCharAfter = StringMid($sUpperSQL, $j, 1)
                If $sCharAfter = "(" Then
                    $bIsValidEnd = True
                    ExitLoop
                ElseIf Not StringIsSpace($sCharAfter) Then
                    ExitLoop
                EndIf
            Next

            If $bIsValidStart And $bIsValidEnd Then
                ReDim $aFunctionPos[UBound($aFunctionPos) + 1][3]
                $aFunctionPos[UBound($aFunctionPos) - 1][0] = $iPos
                $aFunctionPos[UBound($aFunctionPos) - 1][1] = $iPos + StringLen($sFunction) - 1
                $aFunctionPos[UBound($aFunctionPos) - 1][2] = $sFunction
            EndIf

            $iPos += 1
        WEnd
    Next

    ; Sortiere Keywords und Funktionen nach Position
    _ArraySort($aKeywordPos, 0, 0, 0, 0)
    _ArraySort($aFunctionPos, 0, 0, 0, 0)

    Local $iLen = StringLen($sSQL)
    Local $i = 0

    While $i < $iLen
        Local $iCurrentPos = $i + 1
        Local $sChar = StringMid($sSQL, $iCurrentPos, 1)
        Local $bIsKeyword = False
        Local $bIsFunction = False

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

        ; Falls kein Keyword, prüfen ob es eine Funktion ist
        If Not $bIsKeyword Then
            For $j = 0 To UBound($aFunctionPos) - 1
                If $iCurrentPos = $aFunctionPos[$j][0] Then
                    ; Wir haben eine Funktion an dieser Position gefunden
                    Local $sFunction = StringMid($sSQL, $iCurrentPos, $aFunctionPos[$j][1] - $aFunctionPos[$j][0] + 1)
                    _SQL_AddToken($aTokens, $sFunction, $TOKEN_FUNCTION)
                    $i = $aFunctionPos[$j][1]
                    $bIsFunction = True
                    ExitLoop
                EndIf
            Next
        EndIf

        ; Falls wir ein Keyword oder eine Funktion verarbeitet haben, mit dem nächsten Zeichen fortfahren
        If $bIsKeyword Or $bIsFunction Then
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

        ; /* ... */ Kommentare
        If $sChar = "/" And $i + 1 < $iLen And StringMid($sSQL, $i + 2, 1) = "*" Then
            Local $sComment = "/*"
            $i += 2

            While $i + 1 < $iLen
                $sChar = StringMid($sSQL, $i + 1, 1)
                $sComment &= $sChar
                $i += 1

                If $sChar = "*" And $i + 1 < $iLen And StringMid($sSQL, $i + 2, 1) = "/" Then
                    $sComment &= "/"
                    $i += 1
                    ExitLoop
                EndIf
            WEnd

            _SQL_AddToken($aTokens, $sComment, $TOKEN_COMMENT)
            $i += 1
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

    ; Auto-Vervollständigungsliste
    If $g_bAutoComplete And GUICtrlGetState($g_idAutoCompleteList) = $GUI_SHOW Then
        If $iMsg = $g_idAutoCompleteList Then
            _SQL_HandleAutoCompleteSelection()
            Return True
        EndIf
    EndIf

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
            If $sTable <> "" And $g_sCurrentTable <> $sTable Then
                ; Verbesserte Funktion für Tabellenwechsel verwenden
                ; Nur ausführen, wenn wirklich eine andere Tabelle ausgewählt wurde
                _LogInfo("SQL-Editor: Tabellenwechsel von '" & $g_sCurrentTable & "' zu '" & $sTable & "'")
                $g_sCurrentTable = $sTable
                _SQL_ImprovedTableComboChange($sTable)
            EndIf
            Return True

        Case $g_idSQLExecuteBtn
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                _LogInfo("Ausführen-Button MANUELL gedrückt, SQL: " & StringLeft($sSQL, 100))
                ; Manuelle Ausführung explizit signalisieren
                $g_bManualExecuteOnly = False  ; Erlaubt Ausführung
                $g_bSQLEditorFirstLoad = False ; Erster Ladevorgang abgeschlossen
                ; Verbesserte SQL-Ausführungsfunktion verwenden
                _SQL_ImprovedExecuteQueries($sSQL)
                ; Zurücksetzen auf sicheren Modus nach der Ausführung
                $g_bManualExecuteOnly = True
            Else
                _SetStatus("Keine SQL-Abfrage eingegeben")
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

        ; Aktualisieren Button im Editor Modus
        Case $g_idBtnRefresh
            If $g_bSQLEditorMode And $g_sCurrentTable <> "" Then
                _LogInfo("Aktualisieren Button MANUELL gedrückt im SQL-Editor-Modus: " & $g_sCurrentTable)
                ; Nur ausführen, wenn der Button wirklich gedrückt wurde, nicht als Seiteneffekt der GUI-Initialisierung
                Local $sCurrentSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
                If $sCurrentSQL = "" Then
                    $sCurrentSQL = "SELECT * FROM " & $g_sCurrentTable & " LIMIT 100;"
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sCurrentSQL)
                    _SQL_UpdateSyntaxHighlighting()
                EndIf

                ; Manuelle Ausführung explizit signalisieren
                $g_bManualExecuteOnly = False  ; Erlaubt Ausführung
                $g_bSQLEditorFirstLoad = False ; Erster Ladevorgang abgeschlossen
                _SQL_ImprovedExecuteQueries($sCurrentSQL)
                ; Zurücksetzen auf sicheren Modus nach der Ausführung
                $g_bManualExecuteOnly = True
                Return True
            EndIf

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

        Case $g_idAutoCompleteList
            If $g_bAutoComplete Then
                _SQL_HandleAutoCompleteSelection()
                Return True
            EndIf
    EndSwitch

    Return False
EndFunc