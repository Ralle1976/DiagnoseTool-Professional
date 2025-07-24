; Titel.......: SQL-Editor-Einfach
; Beschreibung: Vereinfachte Lösung für das Problem mit der automatischen SQL-Ausführung
; Autor.......: Ralle1976
; Erstellt....: 2025-04-12
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <GuiListView.au3>
#include <GUIRichEdit.au3>
#include <StringConstants.au3>
#include <GUIConstantsEx.au3>
#include <WinAPI.au3>
#include <Array.au3>
#include <EditConstants.au3> ; Für Tastenkonstanten

; VK-Konstanten für Tastaturabfragen
Global Const $VK_CONTROL = 0x11
Global Const $VK_SHIFT = 0x10
Global Const $VK_MENU = 0x12 ; ALT

; ListBox-Konstanten
;~ Global Const $LB_SETCURSEL = 0x0186 ; Setzt die aktuelle Auswahl in einer ListBox

; WindowMessages-Konstanten für Mausaktionen - jetzt definiert in Code-Abschnitt "WindowMessages-Konstanten"

;~ Global Const $WM_LBUTTONDBLCLK = 0x0203 ; Linke Maustaste Doppelklick
;~ Global Const $WM_CHAR = 0x0102 ; Zeicheneingabe

; Referenzen auf die vorhandenen Implementierungen
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung

; Globale Variablen für die letzte verwendete DB und Tabelle
Global $sSavedDB = ""
Global $sSavedTable = ""

; Rich Edit Control Notification Codes - auskommentiert wegen möglicher Doppeldefinition
;~ Global Const $EN_CHANGE = 0x0300  ; Content of an edit control is changed

; Eigene, eindeutige Konstante für die Event-Erkennung
Global Const $SQL_EDITOR_EN_CHANGE = 0x0300  ; Content of edit control is changed

; Höhe des SQL-Editor-Panels
Global Const $SQL_EDITOR_HEIGHT = 200

; F5-Event für SQL-Ausführung
Global Const $SQL_HOTKEY_F5 = 1  ; Eindeutige ID für F5-Hotkey

; Variablen für Syntax-Highlighting-Timer
Global $g_iLastSyntaxUpdate = 0
Global $g_iSyntaxUpdateInterval = 2000  ; Intervall in Millisekunden (deutlich höher, um Benutzerinteraktionen nicht zu stören)

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLDbCombo = 0            ; ID der Datenbank-Auswahlbox
Global $g_idSQLTableCombo = 0         ; ID der Tabellen-Auswahlbox
Global $g_idSQLExecuteBtn = 0         ; ID des Buttons zum Ausführen von Abfragen
Global $g_idSQLSaveBtn = 0            ; ID des Buttons zum Speichern einer SQL-Abfrage
Global $g_idSQLLoadBtn = 0            ; ID des Buttons zum Laden einer SQL-Abfrage
Global $g_idSQLBackBtn = 0            ; ID des Buttons zum Zurückkehren zur normalen Ansicht
Global $g_idBtnRefresh = 0            ; ID des Refresh-Buttons
Global $g_idBtnSQLEditor = 0          ; ID des SQL-Editor-Buttons
Global $g_bSQLEditorMode = False      ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_sLastSQLStatement = ""      ; Speichert das letzte SQL-Statement für erneuten Modiwechsel
Global $g_sLastSQLTable = ""          ; Speichert die letzte Tabelle, zu der das Statement gehört
; Kontrollvariablen für SQL-Ausführung
Global $g_bAutoExecuteEnabled = False  ; Diese Variable steuert, ob SQL-Statements jemals automatisch ausgeführt werden dürfen
Global $g_bUserInitiatedExecution = False  ; Wird nur bei tatsächlichem Klick auf Ausführen-Button gesetzt

Global $g_aListViewBackup[0][0]       ; Array zum Speichern des ListView-Zustands vor SQL-Editor-Aktivierung
Global $g_aListViewColBackup = 0      ; Array zum Speichern der Spaltenüberschriften
Global $g_iOrigListViewHeight = 0     ; Ursprüngliche Höhe der ListView
Global $g_iOrigListViewTop = 0        ; Ursprüngliche Y-Position der ListView
Global $g_aTableColumns[0]            ; Spalten der aktuell ausgewählten Tabelle
Global $g_idAutoCompleteList = 0      ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList = 0       ; Handle der Auto-Vervollständigungsliste
Global $g_sLastDir = @ScriptDir       ; Letztes Verzeichnis für Dateidialoge
Global $g_bUseAutoComplete = True     ; Auto-Vervollständigung aktivieren/deaktivieren
Global $g_iLastCursorPos = -1         ; Letzte Cursor-Position für Auto-Vervollständigung

; Globale Variable zum Speichern des letzten SQL-Statements
Global $g_sLastSQLStatement = ""
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
; STARK VEREINFACHTE SQL-EDITOR IMPLEMENTATION
; Ziel: Minimalismus, keine automatischen Ausführungen
; ===============================================================================================================================

; Funktion zum absoluten Blockieren aller SQL-Ausführungen
Func _BlockAllSQLExecutions()
    ; Diese Funktion setzt ein Flag, das verhindert, dass SQL-Ausführungen automatisch ausgelöst werden
    $g_bUserInitiatedExecution = False
    $g_bAutoExecuteEnabled = False
    ; Logging deaktiviert um Spam zu reduzieren
    ; _LogInfo("*** SICHERHEITSBLOCK: Alle automatischen SQL-Ausführungen blockiert ***")
EndFunc

; AdLib-Funktion für Syntax-Highlighting (wird in regelmäßigen Abständen aufgerufen)
Func _AdLibSyntaxHighlighting()
    ; Nur ausführen, wenn SQL-Editor aktiv ist und notwendige Controls existieren
    If Not $g_bSQLEditorMode Then Return
    If $g_hSQLRichEdit = 0 Then Return

    ; Nur alle X Millisekunden aktualisieren
    If $g_iLastSyntaxUpdate = 0 Or TimerDiff($g_iLastSyntaxUpdate) > $g_iSyntaxUpdateInterval Then
        _SQL_UpdateSyntaxHighlighting()
        $g_iLastSyntaxUpdate = TimerInit()

        ; Auto-Vervollständigung aktualisieren, wenn sichtbar und existiert
        If $g_idAutoCompleteList <> 0 And BitAND(GUICtrlGetState($g_idAutoCompleteList), $GUI_SHOW) Then
            _UpdateAutoCompleteList()
        EndIf
    EndIf
EndFunc

; Funktion, die bei Drücken der F5-Taste ausgeführt wird
Func _ExecuteSQL_F5()
    ; Nur ausführen, wenn SQL-Editor-Modus aktiv ist
    If Not $g_bSQLEditorMode Then Return

    _LogInfo("F5-Taste gedrückt - SQL-Ausführung gestartet")

    ; Die gleiche Aktion wie beim Klick auf den Ausführen-Button durchführen
    Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)

    ; Benutzer-initiierte Ausführung markieren
    $g_bUserInitiatedExecution = True

    ; Nur ausführen, wenn SQL + DB vorhanden sind
    If $sSQL <> "" And $sDBPath <> "" Then
        _LogInfo("SQL-Ausführung wird durch F5-TASTE gestartet")
        _SetStatus("Führe SQL aus...")

        ; SQL aus der EditBox ausführen
        _SQL_ExecuteQuery($sSQL, $sDBPath)

        _LogInfo("SQL wurde durch F5-Taste ausgeführt")
        _SetStatus("SQL-Ausführung abgeschlossen")

        ; Noch einmal Syntax-Highlighting aktualisieren
        _SQL_UpdateSyntaxHighlighting()
    Else
        _SetStatus("Fehler: SQL oder Datenbank fehlt")
    EndIf

    ; Benutzer-initiierte Ausführung zurücksetzen
    $g_bUserInitiatedExecution = False
EndFunc

; Einfache Implementierung für Syntax-Highlighting
Func _SQL_UpdateSyntaxHighlighting()
    ; Nur fortfahren, wenn SQL-Editor aktiv ist und RichEdit-Control existiert
    If Not $g_bSQLEditorMode Or $g_hSQLRichEdit = 0 Then
        ; Statischen Cache zurücksetzen, damit beim Wiedereintreten in den Editor
        ; das Highlighting neu initialisiert wird
        Static $sPreviousText = ""
        $sPreviousText = ""
        Return
    EndIf

    ; Statischen Cache für den letzten Text verwenden
    Static $sPreviousText = ""

    ; Aktuelle Cursortposition und andere Informationen erfassen
    Local $aSel = 0, $sText = ""

    ; Vor dem Zugriff auf RichEdit prüfen, ob es existiert und zugreifbar ist
    If $g_hSQLRichEdit = 0 Or Not IsHWnd($g_hSQLRichEdit) Then
        _LogInfo("Fehler beim Syntax-Highlighting: RichEdit existiert nicht mehr")
        Return False
    EndIf

    ; Versuchen, den Text zu holen, aber mit Fehlerprüfung
    $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If @error Then
        _LogInfo("Fehler beim Syntax-Highlighting: Text konnte nicht gelesen werden")
        Return False
    EndIf

    If $sText = "" Then Return

    ; Cursor-Position merken
    $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    If @error Then
        _LogInfo("Fehler beim Syntax-Highlighting: Cursor-Position konnte nicht ermittelt werden")
        Return False
    EndIf

    ; Nur fortfahren, wenn der Text sich geändert hat
    If $sText = $sPreviousText Then Return
    $sPreviousText = $sText

    ; SQL-Schlüsselwörter definieren
    Local $aSQLKeywords = ["SELECT", "FROM", "WHERE", "GROUP", "ORDER", "BY", "HAVING", "LIMIT", "JOIN", "LEFT", "RIGHT", "INNER", "DELETE", "UPDATE", "INSERT", "VALUES", "INTO", "SET", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN", "IS", "NULL", "AS", "ON", "UNION", "ALL", "DISTINCT", "DESC", "ASC", "PRAGMA", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "UNIQUE", "CHECK", "DEFAULT", "AUTOINCREMENT", "CASCADE", "CASE", "WHEN", "THEN", "ELSE", "END", "COALESCE", "IFNULL", "NULLIF", "CAST", "COLLATE", "EXPLAIN", "VACUUM", "ATTACH", "DETACH", "DATABASE", "TRANSACTION", "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE", "TRIGGER", "INSTEAD", "BEFORE", "AFTER", "EACH", "ROW", "WITH", "WITHOUT", "ROWID", "EXISTS"]

    ; Sicherstellen, dass das RichEdit noch existiert, bevor wir versuchen, es zu bearbeiten
    If $g_hSQLRichEdit = 0 Or Not IsHWnd($g_hSQLRichEdit) Then
        _LogInfo("Fehler beim Syntax-Highlighting: RichEdit existiert nicht mehr vor der Formatierung")
        Return False
    EndIf

    ; Mit Standardfarbe beginnen - mit Fehlerprüfung
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, 0, -1)  ; Alles auswählen
    If @error Then
        _LogInfo("Fehler beim Syntax-Highlighting: Text konnte nicht markiert werden")
        Return False
    EndIf

    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0x000000)  ; Schwarz als Standardfarbe
    If @error Then
        _LogInfo("Fehler beim Syntax-Highlighting: Textfarbe konnte nicht gesetzt werden")
        Return False
    EndIf

    ; Störendes Bildschirmflackern reduzieren, indem wir das Highlighting optimieren
    ; Wir suchen nur nach Schlüsselwörtern, die wirklich im Text vorkommen
    For $i = 0 To UBound($aSQLKeywords) - 1
        ; Regelmäßige Existenzprüfung während der Schleife
        If $g_hSQLRichEdit = 0 Or Not IsHWnd($g_hSQLRichEdit) Then
            _LogInfo("Fehler beim Syntax-Highlighting: RichEdit während der Verarbeitung verschwunden")
            Return False
        EndIf

        Local $sUpperKeyword = StringUpper($aSQLKeywords[$i])
        If StringInStr($sText, $sUpperKeyword) Then
            ; Suche nach allen Vorkommen dieses Schlüsselworts
            Local $iPos = 1
            While 1
                $iPos = StringInStr($sText, $sUpperKeyword, 0, 1, $iPos)
                If $iPos = 0 Then ExitLoop

                ; Prüfen, ob es ein eigenständiges Wort ist (nicht Teil eines anderen Worts)
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
                    If @error Then
                        _LogInfo("Fehler beim Syntax-Highlighting: Wortmarkierung fehlgeschlagen")
                        ContinueLoop
                    EndIf

                    _GUICtrlRichEdit_SetCharColor($g_hSQLRichEdit, 0xFF0000)  ; Rot
                    If @error Then
                        _LogInfo("Fehler beim Syntax-Highlighting: Farbänderung fehlgeschlagen")
                        ContinueLoop
                    EndIf
                EndIf

                ; Zur nächsten Position weitergehen
                $iPos += 1
            WEnd
        EndIf
    Next

    ; Cursor-Position wiederherstellen mit Fehlerprüfung
    If $g_hSQLRichEdit <> 0 And IsHWnd($g_hSQLRichEdit) Then
        _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $aSel[0], $aSel[1])
    EndIf

    Return True
EndFunc

; Status-Meldung setzen
Func _SetStatus($sText)
    If $g_idStatus <> 0 Then
        ; Logging nur für wichtige Meldungen oder bei Debug aktivieren
        Static $aPreviousStatus[1] = [""] ; Speichert die letzte Statusmeldung

        ; Wenn es sich um eine wiederholte REFRESH-BUTTON Meldung handelt, nur alle 60s loggen
        If StringInStr($sText, "Bitte verwenden Sie den 'Ausführen'-Button") Then
            Static $iLastRefreshLogTime = 0
            If $iLastRefreshLogTime = 0 Or TimerDiff($iLastRefreshLogTime) > 60000 Then
                _LogInfo("Status: " & $sText)
                $iLastRefreshLogTime = TimerInit()
            EndIf
        ElseIf $aPreviousStatus[0] <> $sText Then ; Nur bei Änderung loggen
            _LogInfo("Status: " & $sText)
            $aPreviousStatus[0] = $sText
        EndIf

        GUICtrlSetData($g_idStatus, $sText)
    EndIf
EndFunc

; Funktion zum Ermitteln der Spalten einer Tabelle
Func _GetTableColumns($sDBPath, $sTable)
    Local $aColumns[0]
    If $sDBPath = "" Or $sTable = "" Then Return $aColumns

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then Return $aColumns

    ; PRAGMA-Befehl ausführen, um Tabellenspalten zu erhalten
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "PRAGMA table_info(" & $sTable & ");"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
    _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then Return $aColumns

    ; Spaltennamen aus Ergebnis extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    Return $aColumns
EndFunc

; Funktion zum Löschen aller ListView-Spalten
;~ Func _DeleteAllListViewColumns($idListView)
;~     Local $hListView = GUICtrlGetHandle($idListView)
;~     Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)

;~     ; Spalten von rechts nach links löschen
;~     For $i = $iColumns - 1 To 0 Step -1
;~         _GUICtrlListView_DeleteColumn($hListView, $i)
;~     Next

;~     Return True
;~ EndFunc

; Funktion zum Laden der Tabellen aus einer Datenbank
Func _SQL_LoadTables($sDBPath)
    If $sDBPath = "" Then Return False

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then Return False

    ; Tabellenliste abfragen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
    _SQLite_Close($hDB)

    ; Liste leeren
    GUICtrlSetData($g_idSQLTableCombo, "")

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then Return False

    ; Tabellen zur Combo hinzufügen
    Local $sTableList = ""
    For $i = 1 To $iRows
        $sTableList &= $aResult[$i][0] & "|"
    Next
    GUICtrlSetData($g_idSQLTableCombo, StringTrimRight($sTableList, 1))

    ; Erste Tabelle auswählen
    If $iRows > 0 Then GUICtrlSetData($g_idSQLTableCombo, $aResult[1][0], $aResult[1][0])

    ; Spalten der gewählten Tabelle laden
    Local $sCurrentTable = GUICtrlRead($g_idSQLTableCombo)
    If $sCurrentTable <> "" Then
        $g_aTableColumns = _GetTableColumns($sDBPath, $sCurrentTable)
        _LogInfo("Spalten für Tabelle '" & $sCurrentTable & "' geladen: " & UBound($g_aTableColumns))
    EndIf

    Return True
EndFunc

; Funktion zum Laden der verfügbaren Datenbanken
Func _SQL_LoadDatabases()
    ; Aktuell ausgewählten Eintrag merken
    Local $sCurrentDB = GUICtrlRead($g_idSQLDbCombo)

    ; Liste leeren
    GUICtrlSetData($g_idSQLDbCombo, "")

    ; SQLite-Datenbankdateien im Programmverzeichnis suchen
    Local $aDBFiles = _FileListToArray(@ScriptDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES)
    If Not @error Then
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
    If $sCurrentDB <> "" Then GUICtrlSetData($g_idSQLDbCombo, $sCurrentDB, $sCurrentDB)

    Return True
EndFunc

; Funktion zum Speichern des ListView-Status
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
EndFunc

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
_LogInfo("Füge " & $iRows & " Datenzeilen zur ListView hinzu")
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
    $g_idSQLDbCombo = 0
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

; ===============================================================================================================================
; Func.....: _DeleteSQLEditorElements
; Beschreibung: Löscht alle SQL-Editor GUI-Elemente vom Bildschirm
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _DeleteSQLEditorElements()
    _LogInfo("Lösche SQL-Editor-Elemente")

    ; Prüfen, ob die Elemente existieren
    If $g_hSQLRichEdit <> 0 Then
        ; RichEdit-Control zerstören
        _GUICtrlRichEdit_Destroy($g_hSQLRichEdit)
        $g_hSQLRichEdit = 0
    EndIf

    ; Alle anderen Controls löschen
    If $g_idSQLEditorPanel <> 0 Then
        GUICtrlDelete($g_idSQLEditorPanel)
        $g_idSQLEditorPanel = 0
    EndIf

    If $g_idSQLDbCombo <> 0 Then
        GUICtrlDelete($g_idSQLDbCombo)
        $g_idSQLDbCombo = 0
    EndIf

    If $g_idSQLTableCombo <> 0 Then
        GUICtrlDelete($g_idSQLTableCombo)
        $g_idSQLTableCombo = 0
    EndIf

    If $g_idAutoCompleteList <> 0 Then
        GUICtrlDelete($g_idAutoCompleteList)
        $g_idAutoCompleteList = 0
        $g_hAutoCompleteList = 0
    EndIf

    If $g_idSQLExecuteBtn <> 0 Then
        GUICtrlDelete($g_idSQLExecuteBtn)
        $g_idSQLExecuteBtn = 0
    EndIf

    If $g_idSQLSaveBtn <> 0 Then
        GUICtrlDelete($g_idSQLSaveBtn)
        $g_idSQLSaveBtn = 0
    EndIf

    If $g_idSQLLoadBtn <> 0 Then
        GUICtrlDelete($g_idSQLLoadBtn)
        $g_idSQLLoadBtn = 0
    EndIf

    If $g_idSQLBackBtn <> 0 Then
        GUICtrlDelete($g_idSQLBackBtn)
        $g_idSQLBackBtn = 0
    EndIf

    _LogInfo("SQL-Editor-Elemente wurden gelöscht")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _HandleSQLEditorEvents
; Beschreibung: Verarbeitet Events für den SQL-Editor-Modus
; Parameter.: $iMsg - Event-ID aus GUIGetMsg
; Rückgabe..: True wenn Event verarbeitet wurde, sonst False
; ===============================================================================================================================
Func _HandleSQLEditorEvents($iMsg)
    ; Wenn SQL-Editor nicht aktiv, keine Events behandeln
    If Not $g_bSQLEditorMode Then Return False

    ; Von kritischen Fehlern protokollieren, aber stark reduzieren
    Static $iEventLogCounter = 0

    ; Logging nur alle 1000 Events
    $iEventLogCounter += 1
    If Mod($iEventLogCounter, 1000) = 0 Then
        _LogInfo("SQLEditor-Event: $iMsg=" & $iMsg & ", $g_idBtnRefresh=" & $g_idBtnRefresh & " (Anzahl: " & $iEventLogCounter & ")")
    EndIf

    Switch $iMsg
        Case $g_idSQLDbCombo
            ; Keine besondere Sperrlogik mehr notwendig
            Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
            If $sDBPath <> "" Then
                _SQL_LoadTables($sDBPath)  ; Tabellen laden, keine SQL-Ausführung
            EndIf
            Return True

        Case $g_idSQLTableCombo
        ; Sofort alle möglichen Ausführungen blockieren
        _BlockAllSQLExecutions()
        _LogInfo("Tabellenwechsel erkannt - Ausführungssperre aktiviert")

        Local $sTable = GUICtrlRead($g_idSQLTableCombo)
        If $sTable <> "" Then
                _LogInfo("Tabelle ausgewählt: " & $sTable)

            ; Standard SQL-Statement für diese Tabelle erstellen
            Local $sSQL = "SELECT * FROM " & $sTable & " LIMIT 100;"
            Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)

            If $sDBPath <> "" Then
            ; WICHTIG: KEIN direktes Ausführen des SQL-Statements mehr!
                    ; SQL-Statement in die EditBox schreiben (ohne Kommentar)
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        $g_sCurrentTable = $sTable

                ; Syntax-Highlighting sofort aktualisieren
                _SQL_UpdateSyntaxHighlighting()
                _SetStatus("Tabelle '" & $sTable & "' ausgewählt. Klicken Sie auf 'Ausführen', um Daten anzuzeigen.")
        Else
            _SetStatus("Fehler: Keine Datenbank ausgewählt")
        EndIf
        EndIf
        Return True

        Case $g_idSQLExecuteBtn
        ; Zusätzliche Sicherheit gegen programmgesteuerte Aufrufe (abfangen durch Timer z.B.)
        Static $iLastButtonClick = 0
        Local $iCurrentTime = TimerInit()

        ; Wenn der Button innerhalb von 50ms erneut ausgelöst wird, ignorieren (vermutlich automatisch)
        If $iCurrentTime - $iLastButtonClick < 50 Then
            _LogInfo("VERDACHT AUF AUTOMATISCHE AUSLÖSUNG: Execute-Button zu schnell hintereinander - IGNORIERT!")
            Return True
        EndIf

        ; Zeit des letzten Klicks speichern
        $iLastButtonClick = $iCurrentTime

        _LogInfo("######## AUSFÜHREN-BUTTON GEDRÜCKT ########")

        ; Benutzer-initiierte Ausführung markieren
        $g_bUserInitiatedExecution = True
        _LogInfo("SQL-Ausführung wurde VOM BENUTZER initiiert - Flag gesetzt")

        ; SQL-Text aus der EditBox laden
        Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
        Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)

        ; Nur ausführen, wenn Button gedrückt wurde und SQL + DB vorhanden sind
        If $sSQL <> "" And $sDBPath <> "" Then
        _LogInfo("SQL-Ausführung wird durch BUTTON-KLICK gestartet")
        _SetStatus("Führe SQL aus...")

        ; SQL aus der EditBox ausführen
        _SQL_ExecuteQuery($sSQL, $sDBPath)

        _LogInfo("SQL wurde durch Button-Klick ausgeführt")
        _SetStatus("SQL-Ausführung abgeschlossen")

        ; Button kurzzeitig deaktivieren, um versehentliches Mehrfachklicken zu verhindern
        GUICtrlSetState($g_idSQLExecuteBtn, $GUI_DISABLE)
        Sleep(500) ; Kurze Verzögerung
        GUICtrlSetState($g_idSQLExecuteBtn, $GUI_ENABLE)

        ; Noch einmal Syntax-Highlighting aktualisieren
        _SQL_UpdateSyntaxHighlighting()
        Else
        _SetStatus("Fehler: SQL oder Datenbank fehlt")
        EndIf

        ; Benutzer-initiierte Ausführung zurücksetzen
        $g_bUserInitiatedExecution = False
        _LogInfo("Benutzer-Ausführungsflag zurückgesetzt")

        Return True

        Case $g_idBtnRefresh
            ; HINWEIS: Nur alle 60 Sekunden eine Meldung ausgeben
            Static $iLastRefreshMsg = 0
            If $iLastRefreshMsg = 0 Or TimerDiff($iLastRefreshMsg) > 60000 Then
                _SetStatus("Bitte verwenden Sie den 'Ausführen'-Button stattdessen")
                $iLastRefreshMsg = TimerInit()
            EndIf
            Return True

        Case $g_idSQLBackBtn, $g_idBtnSQLEditor
            _SQL_EditorExit()  ; SQL-Editor verlassen
            Return True

        Case $g_idSQLSaveBtn
            ; Temporäre Variable, nichts ändert sich an der Ausführungslogik
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                Local $sFile = FileSaveDialog("SQL-Abfrage speichern", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_PATHMUSTEXIST)
                If Not @error Then
                    If StringRight($sFile, 4) <> ".sql" Then $sFile &= ".sql"
                    FileWrite($sFile, $sSQL)
                EndIf
            EndIf
            Return True

        Case $g_idSQLLoadBtn
            ; Temporäre Variable, nichts ändert sich an der Ausführungslogik
            Local $sFile = FileOpenDialog("SQL-Abfrage laden", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_FILEMUSTEXIST)
            If Not @error Then
                Local $sSQL = FileRead($sFile)
                If Not @error Then _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
            EndIf
            Return True
    EndSwitch

    Return False
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_EditorEnter
; Beschreibung: Aktiviert den SQL-Editor-Modus
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, sonst False
; ===============================================================================================================================
Func _SQL_EditorEnter()
    ; Aktiviert den SQL-Editor-Modus
    If $g_bSQLEditorMode Then Return True  ; Bereits aktiv

    _LogInfo("========= Betrete SQL-Editor-Modus... ==========")

    ; Aktuell ausgewählte Tabelle und Datenbank speichern
    $sSavedDB = $g_sCurrentDB
    $sSavedTable = GUICtrlRead($idTableCombo)  ; Direkt aus der ComboBox der Hauptansicht lesen
    _LogInfo("Speichere aktuelle Tabelle für Kontext: DB = '" & $sSavedDB & "', Tabelle = '" & $sSavedTable & "'")

    ; ListView-Status speichern
    _SQL_SaveListViewState()

    ; Button-Text ändern
    GUICtrlSetData($g_idBtnSQLEditor, "Zurück")

    ; SQL-Editor-Elemente dynamisch erstellen
    _CreateSQLEditorElements()
    GUICtrlSetData($g_idSQLTableCombo, GUICtrlRead($idTableCombo, 1), $sSavedTable)
    ; ListView anpassen (Position und Größe)
    Local $aPos = ControlGetPos($g_hGUI, "", $g_idListView)
    ControlMove($g_hGUI, "", $g_idListView, $aPos[0], $g_iOrigListViewTop + $SQL_EDITOR_HEIGHT, $aPos[2], $g_iOrigListViewHeight - $SQL_EDITOR_HEIGHT)
    GUICtrlSetState($g_idListView, $GUI_SHOW)

    ; SQL-Editor-Modus aktivieren
    $g_bSQLEditorMode = True

    ; Absolute Sicherheitssperre aktivieren
    _BlockAllSQLExecutions()
    _LogInfo("SQL-Editor-Modus aktiviert - Ausführungskontrolle aktiviert")

    ; Timer für Syntax-Highlighting initialisieren
    $g_iLastSyntaxUpdate = 0

    ; Syntax-Highlighting-Funktion registrieren (alle 2 Sekunden auslösen)
    AdlibRegister("_AdLibSyntaxHighlighting", 2000)

    ; F5-Taste für SQL-Ausführung registrieren
    HotKeySet("{F5}", "_ExecuteSQL_F5")

    ; Sofort Syntax-Highlighting durchführen
    _SQL_UpdateSyntaxHighlighting()

    ; Die ListView-Anzeige aktualisieren, um Darstellungsprobleme zu vermeiden
    GUICtrlSetState($g_idListView, $GUI_SHOW)
    _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))

    _LogInfo("SQL-Editor-Modus aktiviert - aktuelle Tabelle: '" & $sSavedTable & "'")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_EditorExit
; Beschreibung: Deaktiviert den SQL-Editor-Modus
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, sonst False
; ===============================================================================================================================
Func _SQL_EditorExit()
    ; Deaktiviert den SQL-Editor-Modus
    If Not $g_bSQLEditorMode Then Return True  ; Nicht aktiv

    _LogInfo("========= Verlasse SQL-Editor-Modus... ==========")

    ; Aktuelles SQL und Tabelle aus der Sitzung speichern
    Local $sTableToUse = ""
    If $g_hSQLRichEdit <> 0 And IsHWnd($g_hSQLRichEdit) Then
        $g_sLastSQLStatement = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

        ; Wichtig: Aktuelle Tabelle aus der ComboBox des SQL-Editors holen
        $sTableToUse = GUICtrlRead($g_idSQLTableCombo)
        $g_sLastSQLTable = $sTableToUse

        _LogInfo("Aktuelle Tabelle im SQL-Editor: '" & $sTableToUse & "'")
        _LogInfo("SQL-Statement für nächsten Aufruf gespeichert: " & StringLeft($g_sLastSQLStatement, 50) & "...")
    EndIf

    ; Button-Text zurücksetzen
    GUICtrlSetData($g_idBtnSQLEditor, "SQL-Editor")

    ; SQL-Editor-Elemente löschen
    _DeleteSQLEditorElements()

    ; ListView zurücksetzen
    ControlMove($g_hGUI, "", $g_idListView, 2, $g_iOrigListViewTop, ControlGetPos($g_hGUI, "", $g_idListView)[2], $g_iOrigListViewHeight)

    ; Status zurücksetzen
    $g_bSQLEditorMode = False

    ; Syntax-Highlighting-Timer deaktivieren
    AdlibUnRegister("_AdLibSyntaxHighlighting")

    ; F5-Hotkey deaktivieren
    HotKeySet("{F5}")

    ; Kurze Verzögerung, um sicherzustellen, dass alle AdLib-Aufrufe beendet sind
    Sleep(100)

    ; ListView neu zeichnen und nach unten in der Z-Order setzen, um Überlagerungsprobleme zu beheben
    Local $hListView = GUICtrlGetHandle($g_idListView)
    _WinAPI_SetWindowPos($hListView, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    _WinAPI_RedrawWindow($hListView)

    ; Hauptfenster aktualisieren, wenn eine Tabelle ausgewählt ist
    ; Wichtig: Hier müssen wir die im SQL-Editor ausgewählte Tabelle und Datenbank zurückgeben
    Local $sDBToUse = $g_sCurrentDB

    _LogInfo("Setze Tabelle/Datenbank nach Rückkehr: DB = '" & $sDBToUse & "', Tabelle = '" & $sTableToUse & "'")

    If $sDBToUse <> "" Then
        ; Datenbank in der aufrufenden GUI setzen, falls nicht bereits gesetzt
        If $g_sCurrentDB <> $sDBToUse Then
            _LogInfo("Datenbankwechsel erforderlich: " & $g_sCurrentDB & " -> " & $sDBToUse)
            _OpenDatabaseFile($sDBToUse)
        EndIf

        ; Tabelle explizit setzen, wenn sie existiert
        If $sTableToUse <> "" Then
            ; Prüfen, ob Tabelle in ComboBox vorhanden ist
            Local $sTables = GUICtrlRead($idTableCombo, 1)
            _LogInfo("Verfügbare Tabellen in Hauptansicht: '" & $sTables & "'")

            ; Sicherstellen, dass die Tabelle in der ComboBox ist
            If StringInStr($sTables, $sTableToUse) Then
                ; Aktuelle Tabelle in der Combo setzen (mit Fallback auf reguläre Methode)
                _LogInfo("Setze Tabelle in ComboBox: " & $sTableToUse)

                ; Direkte Methode
                If Not GUICtrlSetData($idTableCombo, $sTableToUse, $sTableToUse) Then
                    _LogInfo("WARNUNG: Konnte Tabelle nicht setzen mit GUICtrlSetData, versuche alternative Methode")
                    ; Alternative Methode, falls GUICtrlSetData fehlschlägt
                    ControlCommand($g_hGUI, "", $idTableCombo, "SelectString", $sTableToUse)
                EndIf

                ; Globale Variable aktualisieren
                $g_sCurrentTable = $sTableToUse

                ; Daten laden für die ausgewählte Tabelle ohne Event-Auslösung
                _LogInfo("Lade Daten für Tabelle: " & $sTableToUse)
                _LoadDatabaseData()
            Else
                _LogInfo("WARNUNG: Tabelle '" & $sTableToUse & "' nicht in Hauptfenster-ComboBox gefunden")
                ; Versuchen, die erste verfügbare Tabelle zu verwenden
                If $sTables <> "" Then
                    Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
                    If UBound($aTableList) > 0 Then
                        $sTableToUse = $aTableList[0]
                        _LogInfo("Verwende erste verfügbare Tabelle in Hauptansicht: " & $sTableToUse)
                        GUICtrlSetData($idTableCombo, $sTableToUse, $sTableToUse)
                        ControlCommand($g_hGUI, "", $idTableCombo, "SelectString", $sTableToUse)
                        $g_sCurrentTable = $sTableToUse
                        _LoadDatabaseData()
                    EndIf
                EndIf
            EndIf
        Else
            _LogInfo("Keine Tabelle zum Zurückgeben gefunden, verwende erste verfügbare")
            ; Versuchen, die erste verfügbare Tabelle zu verwenden
            Local $sTables = GUICtrlRead($idTableCombo, 1)
            If $sTables <> "" Then
                Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
                If UBound($aTableList) > 0 Then
                    $sTableToUse = $aTableList[0]
                    _LogInfo("Verwende erste verfügbare Tabelle in Hauptansicht: " & $sTableToUse)
                    GUICtrlSetData($idTableCombo, $sTableToUse, $sTableToUse)
                    ControlCommand($g_hGUI, "", $idTableCombo, "SelectString", $sTableToUse)
                    $g_sCurrentTable = $sTableToUse
                    _LoadDatabaseData()
                EndIf
            EndIf
        EndIf
    EndIf

    ; ListView-Style aktualisieren, um Darstellungsprobleme zu beheben
    _GUICtrlListView_SetExtendedListViewStyle($hListView, $iExListViewStyle)

    ; Fenster neu zeichnen, um Anzeigefehler zu beheben
    WinSetState($g_hGUI, "", @SW_HIDE)
    WinSetState($g_hGUI, "", @SW_SHOW)

    _LogInfo("SQL-Editor-Modus deaktiviert - Tabelle in Hauptansicht: " & $g_sCurrentTable)
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _ToggleSQLEditorMode
; Beschreibung: Umschalten zwischen SQL-Editor-Modus und normalem Modus
; Parameter.: $bActivate - True zum Aktivieren, False zum Deaktivieren
; Rückgabe..: True bei Erfolg, sonst False
; ===============================================================================================================================
Func _ToggleSQLEditorMode($bActivate)
    ; Umschalten des SQL-Editor-Modus
    If $g_bSQLEditorMode = $bActivate Then Return True  ; Nichts zu tun

    If $bActivate Then
        Return _SQL_EditorEnter()
    Else
        Return _SQL_EditorExit()
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _WM_COMMAND
; Beschreibung: Event-Handler für WM_COMMAND Nachrichten, erkennt Änderungen an Controls
; Parameter.: Standard-Windows-Nachrichtenparameter
; Rückgabe..: Success: $GUI_RUNDEFMSG, Error: None
; ===============================================================================================================================
Func _WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    ; Textveränderungen im RichEdit-Control erkenen
    Local $hiword = BitShift($wParam, 16)
    Local $lowword = BitAND($wParam, 0xFFFF)

    ; Wenn es sich um einen Textveränderungs-Event handelt und der SQL-Editor aktiv ist
    If $g_bSQLEditorMode And $hiword = $SQL_EDITOR_EN_CHANGE Then
        ; Da wir jetzt dynamisch erzeugen, müssen wir erst prüfen, ob das RichEdit existiert
        If $g_hSQLRichEdit <> 0 Then
            ; Falls das Handle existiert, prüfen wir, ob es das aktive Control ist
            If GUICtrlGetHandle($lowword) = $g_hSQLRichEdit Then
                ; Sofort alle möglichen Ausführungen blockieren
                _BlockAllSQLExecutions()

                ; Log-Nachricht mit weniger Häufigkeit (stark reduziert)
                Static $iTextChangeCounter = 0
                $iTextChangeCounter += 1
                If Mod($iTextChangeCounter, 100) = 0 Then
                    _LogLimit("Textveränderung im SQL-Editor erkannt - Ausführung blockiert (Anzahl: " & $iTextChangeCounter & ")", 1000)
                EndIf

                ; Kein automatisches Highlighting hier - wird durch AdlibRegister erledigt
            EndIf
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; Event-Handler für WM_KEYDOWN - erfasst Tastendrücke
Func _WM_KEYDOWN($hWnd, $iMsg, $wParam, $lParam)
    ; Nur behandeln, wenn SQL-Editor aktiv ist
    If Not $g_bSQLEditorMode Then Return $GUI_RUNDEFMSG

    ; Prüfen, ob die notwendigen Controls existieren (wegen dynamischer Erstellung)
    If $g_hSQLRichEdit = 0 Then Return $GUI_RUNDEFMSG

    ; Tasten-Code ermitteln
    Local $iKeyCode = $wParam

    ; Debug-Logging für Tastendrücke
    _LogInfo("WM_KEYDOWN: Taste = " & $iKeyCode & " für Fenster " & $hWnd)

    ; Prüfen, ob es der richtige RichEdit ist
    If $hWnd <> $g_hSQLRichEdit Then
        _LogInfo("WM_KEYDOWN: Falsches Fenster, erwartet: " & $g_hSQLRichEdit)
        Return $GUI_RUNDEFMSG
    EndIf

    ; STRG+LEERTASTE für Auto-Vervollständigung erzwingen (besondere Behandlung)
    If $iKeyCode = 32 And BitAND(_WinAPI_GetKeyState($VK_CONTROL), 0x8000) <> 0 Then
        _LogInfo("WM_KEYDOWN: STRG+LEERTASTE erkannt - Auto-Vervollständigung wird erzwungen")
        ; Warten, damit die Tastatur verarbeitet wird
        Sleep(100)
        ; Auto-Vervollständigungsliste aktualisieren und anzeigen
        _ShowCompletionList()
        ; Event komplett abfangen
        Return $GUI_RUNDEFMSG
    EndIf

    ; Wenn bereits die Autovervollständigungsliste angezeigt wird
    If $g_idAutoCompleteList <> 0 And BitAND(GUICtrlGetState($g_idAutoCompleteList), $GUI_SHOW) <> 0 Then
        ; TAB oder ENTER für Auto-Vervollständigung anwenden
        If $iKeyCode = 9 Or $iKeyCode = 13 Then ; TAB/ENTER
            _LogInfo("WM_KEYDOWN: TAB/ENTER erkannt - Auto-Vervollständigung wird angewendet")
            _ApplyAutoComplete()
            Return $GUI_RUNDEFMSG
        EndIf

        ; ESC um Auto-Vervollständigungsliste zu schließen
        If $iKeyCode = 27 Then ; ESC
            _LogInfo("WM_KEYDOWN: ESC erkannt - Auto-Vervollständigungsliste wird geschlossen")
            GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
            Return $GUI_RUNDEFMSG
        EndIf

        ; Pfeiltasten für Navigation in der Liste
        If $iKeyCode = 38 Or $iKeyCode = 40 Then ; Nach oben/unten
            _LogInfo("WM_KEYDOWN: Pfeiltaste erkannt - Navigation in Auto-Vervollständigungsliste")
            ; Fokus auf Auto-Vervollständigungsliste setzen
            If $g_hAutoCompleteList <> 0 And IsHWnd($g_hAutoCompleteList) Then
                _WinAPI_SetFocus($g_hAutoCompleteList)
                ; Simulate Pfeil nach unten oder oben
                _SendMessage($g_hAutoCompleteList, $WM_KEYDOWN, $iKeyCode, 0)
                Return $GUI_RUNDEFMSG
            EndIf
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; Zeigt die Auto-Vervollständigungsliste an einer bestimmten Position an
Func _ShowCompletionList()
If Not $g_bSQLEditorMode Then
        _LogInfo("Auto-Vervollständigung: SQL-Editor nicht aktiv")
    Return False
    EndIf

_LogInfo("Auto-Vervollständigung: Zeige Vorschläge an...")

; Prüfen, ob RichEdit existiert
If $g_hSQLRichEdit = 0 Or Not IsHWnd($g_hSQLRichEdit) Then
_LogInfo("Auto-Vervollständigung: RichEdit existiert nicht")
    Return False
    EndIf

; Vorhandene Liste aktualisieren
Local $aMatches = _UpdateAutoCompleteList()

; Prüfen, ob Übereinstimmungen gefunden wurden
If UBound($aMatches) = 0 Then
    _LogInfo("Auto-Vervollständigung: Keine Vorschläge gefunden")
    If $g_idAutoCompleteList <> 0 Then GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
    Return False
EndIf

; Position des Textcursors im RichEdit ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
Local $iCursorPos = $aSel[0]

_LogInfo("Auto-Vervollständigung: Cursor-Position = " & $iCursorPos)

; Den Text bis zur aktuellen Position holen, um die Zeile zu zählen
Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
Local $sTextUpToCursor = StringLeft($sText, $iCursorPos)

; Zeilenberechnung
Local $aLines = StringSplit($sTextUpToCursor, @CRLF, $STR_ENTIRESPLIT)
Local $iLineCount = UBound($aLines) - 1
    If $iLineCount <= 0 Then $iLineCount = 1

; Länge der aktuellen Zeile bestimmen
Local $iCurrentLineLength = StringLen($aLines[$iLineCount-1])
If $iCurrentLineLength <= 0 Then $iCurrentLineLength = 1

_LogInfo("Auto-Vervollständigung: Zeile " & $iLineCount & ", Zeichenlänge: " & $iCurrentLineLength)

; Position der ListView ermitteln
Local $aRichEditPos = ControlGetPos($g_hGUI, "", $g_hSQLRichEdit)
_LogInfo("Auto-Vervollständigung: RichEdit-Position: X=" & $aRichEditPos[0] & ", Y=" & $aRichEditPos[1])

; Positionsberechnung für die Auto-Vervollständigungsliste
Local $iXPos = $aRichEditPos[0] + 100
Local $iYPos = $aRichEditPos[1] + 50

    _LogInfo("Auto-Vervollständigung: Liste wird positioniert bei X=" & $iXPos & ", Y=" & $iYPos)

; Immer eine neue Liste erstellen, um Probleme zu vermeiden
If $g_idAutoCompleteList <> 0 Then
    GUICtrlDelete($g_idAutoCompleteList)
        $g_idAutoCompleteList = 0
    $g_hAutoCompleteList = 0
EndIf

; Neue Liste erstellen
$g_idAutoCompleteList = GUICtrlCreateList("", $iXPos, $iYPos, 250, 150, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY))
$g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)

; Mit Einträgen füllen
    _LogInfo("Auto-Vervollständigung: Füge " & UBound($aMatches) & " Vorschläge hinzu")
    For $i = 0 To UBound($aMatches) - 1
        _LogInfo("Auto-Vervollständigung: Vorschlag " & ($i+1) & ": " & $aMatches[$i])
        GUICtrlSetData($g_idAutoCompleteList, $aMatches[$i])
    Next

    ; Ersten Eintrag auswählen und Liste anzeigen
    If $g_hAutoCompleteList <> 0 Then
        _SendMessage($g_hAutoCompleteList, $LB_SETCURSEL, 0, 0)
        GUICtrlSetState($g_idAutoCompleteList, $GUI_SHOW)
        _LogInfo("Auto-Vervollständigung: Liste angezeigt")
    Else
        _LogInfo("Auto-Vervollständigung: FEHLER - ListBox-Handle ist 0")
    EndIf

    ; Liste in den Vordergrund bringen
    _WinAPI_SetWindowPos($g_hAutoCompleteList, $HWND_TOPMOST, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    _LogInfo("Auto-Vervollständigung: Liste wurde positioniert und angezeigt")

    Return True
EndFunc

; Aktualisiert die Auto-Vervollständigungsliste basierend auf dem aktuellen Text
Func _UpdateAutoCompleteList()
If Not $g_bSQLEditorMode Then Return False

; Prüfen, ob die notwendigen Controls existieren (wegen dynamischer Erstellung)
If $g_hSQLRichEdit = 0 Then
    _LogInfo("Auto-Vervollständigung nicht möglich - RichEdit nicht gefunden")
    Local $aEmptyArray[0]
    Return $aEmptyArray
EndIf

; Debug-Log hinzufügen, um Ausführung zu überprüfen
_LogInfo("Auto-Vervollständigungsliste wird aktualisiert")

; Aktuelle Cursor-Position ermitteln
Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
Local $iCursorPos = $aSel[0]

; Text aus RichEdit holen
Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

; Aktuelles Wort ermitteln (rückwärts vom Cursor bis zum letzten Leerzeichen/Sonderzeichen)
Local $sCurrentWord = ""
For $i = $iCursorPos - 1 To 0 Step -1
    Local $sChar = StringMid($sText, $i + 1, 1)
    If StringRegExp($sChar, "[^a-zA-Z0-9_]") Then ExitLoop
    $sCurrentWord = $sChar & $sCurrentWord
Next

_LogInfo("Aktuelles Wort für Auto-Vervollständigung: '" & $sCurrentWord & "'")

; Wenn Wort zu kurz, keine Auto-Vervollständigung anzeigen
If StringLen($sCurrentWord) < 1 Then
    If $g_idAutoCompleteList <> 0 Then GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
Local $aEmptyArray[0]
Return $aEmptyArray
EndIf

; Mögliche Vervollständigungen suchen
Local $aMatches = _FindAutoCompleteMatches($sCurrentWord)

; Wenn keine Übereinstimmungen, Liste ausblenden
If UBound($aMatches) = 0 Then
    _LogInfo("Keine Auto-Vervollständigungsvorschläge gefunden")
If $g_idAutoCompleteList <> 0 Then GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
Return $aMatches
EndIf

_LogInfo("Gefundene Auto-Vervollständigungsvorschläge: " & UBound($aMatches))
Return $aMatches
EndFunc

; Findet passende Auto-Vervollständigungen basierend auf dem aktuellen Wort
Func _FindAutoCompleteMatches($sCurrentWord)
    Local $aMatches[0]

    If $sCurrentWord = "" Then Return $aMatches

    ; Die aktuelle Texteingabe analysieren, um den Kontext zu verstehen
    Local $sCurrentText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    If @error Then Return $aMatches

    ; Den Text bis zur Cursor-Position auswerten für den Kontext
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]
    Local $sTextBeforeCursor = StringLeft($sCurrentText, $iCursorPos)

    ; Kontextanalyse (FROM-Tabelle oder Spaltenreferenz)
    Local $bIsTableContext = False
    Local $bIsColumnContext = False

    ; Ist es ein Tabellenkontext? (Nach FROM oder JOIN)
    If StringRegExp(StringUpper($sTextBeforeCursor), "(FROM|JOIN)\s+[^\s,;]* *$") Then
        $bIsTableContext = True
        _LogInfo("Kontext erkannt: Tabellenname")
    ; Ist es ein Spaltenkontext? (Nach SELECT, WHERE, ORDER BY, etc.)
    ElseIf StringRegExp(StringUpper($sTextBeforeCursor), "(SELECT|WHERE|AND|OR|BY|,|\()\s*[^\s,;()]*$") Then
        $bIsColumnContext = True
        _LogInfo("Kontext erkannt: Spaltenname")
    EndIf

    ; In Großbuchstaben umwandeln für den Vergleich
    $sCurrentWord = StringUpper($sCurrentWord)

    ; SQL-Schlüsselwörter (immer verfügbar, es sei denn, wir sind in einem spezifischen Kontext)
    Local  $aSQLKeywords = ["SELECT", "FROM", "WHERE", "GROUP", "ORDER", "BY", "HAVING", "LIMIT", "JOIN", "LEFT", "RIGHT", "INNER", "DELETE", "UPDATE", "INSERT", "VALUES", "INTO", "SET", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN", "IS", "NULL", "AS", "ON", "UNION", "ALL", "DISTINCT", "DESC", "ASC", "PRAGMA", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "UNIQUE", "CHECK", "DEFAULT", "AUTOINCREMENT", "CASCADE", "CASE", "WHEN", "THEN", "ELSE", "END", "COALESCE", "IFNULL", "NULLIF", "CAST", "COLLATE", "EXPLAIN", "VACUUM", "ATTACH", "DETACH", "DATABASE", "TRANSACTION", "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE", "TRIGGER", "INSTEAD", "BEFORE", "AFTER", "EACH", "ROW", "WITH", "WITHOUT", "ROWID", "EXISTS"]
;~     If Not $bIsTableContext And Not $bIsColumnContext Then
;~         $aSQLKeywords = ["SELECT", "FROM", "WHERE", "GROUP", "ORDER", "BY", "HAVING", "LIMIT", "JOIN", "LEFT", "RIGHT", "INNER", "DELETE", "UPDATE", "INSERT", "VALUES", "INTO", "SET", "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN", "IS", "NULL", "AS", "ON", "UNION", "ALL", "DISTINCT", "DESC", "ASC", "PRAGMA", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "UNIQUE", "CHECK", "DEFAULT", "AUTOINCREMENT", "CASCADE", "CASE", "WHEN", "THEN", "ELSE", "END", "COALESCE", "IFNULL", "NULLIF", "CAST", "COLLATE", "EXPLAIN", "VACUUM", "ATTACH", "DETACH", "DATABASE", "TRANSACTION", "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE", "TRIGGER", "INSTEAD", "BEFORE", "AFTER", "EACH", "ROW", "WITH", "WITHOUT", "ROWID", "EXISTS"]
;~     EndIf

    ; Tabellen- und Spaltennamen hinzufügen
    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
    If $sDBPath <> "" Then
        ; Tabellennamen nur hinzufügen, wenn Tabellenkontext oder allgemeiner Kontext
        If $bIsTableContext Or (Not $bIsColumnContext) Then
            Local $sTables = GUICtrlRead($g_idSQLTableCombo)
            Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
            For $i = 0 To UBound($aTableList) - 1
                If $aTableList[$i] <> "" Then
                    _ArrayAdd($aSQLKeywords, $aTableList[$i])
                EndIf
            Next
        EndIf

        ; Spaltennamen der aktuellen Tabelle hinzufügen, wenn Spaltenkontext oder allgemeiner Kontext
        If $bIsColumnContext Or (Not $bIsTableContext) Then
            Local $sCurrentTable = GUICtrlRead($g_idSQLTableCombo)
            If $sCurrentTable <> "" Then
                If UBound($g_aTableColumns) = 0 Then
                    ; Wenn noch keine Spalten geladen wurden, jetzt laden
                    $g_aTableColumns = _GetTableColumns($sDBPath, $sCurrentTable)
                EndIf

                For $i = 0 To UBound($g_aTableColumns) - 1
                    If $g_aTableColumns[$i] <> "" Then
                        _ArrayAdd($aSQLKeywords, $g_aTableColumns[$i])
                    EndIf
                Next
            EndIf
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



; Handler für WM_CHAR - verarbeitet die Zeicheneingabe und aktiviert Auto-Vervollständigung bei Auslösebedingungen
Func _WM_CHAR($hWnd, $iMsg, $wParam, $lParam)
    ; Nur behandeln, wenn SQL-Editor aktiv ist
    If Not $g_bSQLEditorMode Then Return $GUI_RUNDEFMSG

    ; Prüfen, ob die notwendigen Controls existieren
    If $g_hSQLRichEdit = 0 Then Return $GUI_RUNDEFMSG

    ; Prüfen, ob es das richtige Fenster ist
    If $hWnd <> $g_hSQLRichEdit Then Return $GUI_RUNDEFMSG

    ; Zeichen ermitteln
    Local $iChar = $wParam

    ; Logging reduzieren - nur für bestimmte Zeichen (Leerzeichen, Punkt, Komma etc.)
    If $iChar = 32 Or $iChar = 46 Or $iChar = 44 Or $iChar = 9 Or $iChar = 10 Or $iChar = 13 Then
        _LogInfo("WM_CHAR: Wichtiges Zeichen erkannt: " & $iChar)
    EndIf

    ; Auto-Vervollständigung prüfen bei Auslösezeichen
    ; Nach bestimmten Zeichen (z.B. ".", " " oder ",") Auto-Vervollständigung anzeigen
    If $iChar = 46 Then  ; Punkt '.' - Wichtig für SQL-Spaltenreferenzen (Tabelle.Spalte)
        _LogInfo("WM_CHAR: Punkt-Zeichen erkannt - Auto-Vervollständigung wird initiiert")
        Sleep(50)  ; Kurze Verzögerung, damit der Text verarbeitet werden kann
        _ShowCompletionList()
    EndIf

    ; Verarbeitung fortsetzen
    Return $GUI_RUNDEFMSG
EndFunc
Func _ApplyAutoComplete()
    If Not $g_bSQLEditorMode Then Return False

    ; Prüfen, ob die notwendigen Controls existieren (wegen dynamischer Erstellung)
    If $g_hSQLRichEdit = 0 Or $g_idAutoCompleteList = 0 Then
        _LogInfo("Auto-Vervollständigung nicht möglich - Controls wurden noch nicht erstellt")
        Return False
    EndIf

    If Not BitAND(GUICtrlGetState($g_idAutoCompleteList), $GUI_SHOW) Then Return False

    ; Ausgewählten Eintrag holen
    Local $sSelected = GUICtrlRead($g_idAutoCompleteList)
    If $sSelected = "" Then
        _LogInfo("Kein Eintrag in Auto-Vervollständigungsliste ausgewählt")
        Return False
    EndIf

    _LogInfo("Ausgewählter Eintrag für Auto-Vervollständigung: " & $sSelected)

    ; Aktuelle Cursor-Position und Text holen
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    Local $iCursorPos = $aSel[0]
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Aktuelles Wort ermitteln (rückwärts vom Cursor)
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

    _LogInfo("Zu ersetzendes Wort: " & $sCurrentWord & ", von Pos " & $iStartPos & " bis " & $iCursorPos)

    ; Text ersetzen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iStartPos, $iCursorPos)
    _GUICtrlRichEdit_ReplaceText($g_hSQLRichEdit, $sSelected)

    ; Auto-Vervollständigungsliste ausblenden
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)

    ; Neue Cursor-Position setzen am Ende des eingefügten Wortes
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iStartPos + StringLen($sSelected), $iStartPos + StringLen($sSelected))

    ; Nach Einfügung den Fokus zurück auf den RichEdit setzen
    _WinAPI_SetFocus($g_hSQLRichEdit)

    ; Syntax-Highlighting aktualisieren
    _SQL_UpdateSyntaxHighlighting()

    Return True
EndFunc

; Doppelklick-Handler für die Autovervollständigung
Func _WM_LBUTTONDBLCLK($hWnd, $iMsg, $wParam, $lParam)
; Nur behandeln, wenn SQL-Editor aktiv ist
If Not $g_bSQLEditorMode Then Return $GUI_RUNDEFMSG

; Prüfen, ob die notwendigen Controls existieren (wegen dynamischer Erstellung)
If $g_hSQLRichEdit = 0 Then Return $GUI_RUNDEFMSG

; Debug-Logging für die Doppelklick-Behandlung
_LogInfo("WM_LBUTTONDBLCLK: Doppelklick erkannt in Fenster " & $hWnd & ", RichEdit: " & $g_hSQLRichEdit)

; Ermitteln, ob der Doppelklick im RichEdit stattfand
If $hWnd = $g_hSQLRichEdit Then
    _LogInfo("WM_LBUTTONDBLCLK: Doppelklick im SQL-Editor erkannt - aktiviere Auto-Vervollständigung")

    ; Warten, damit die Maus verarbeitet wird
        Sleep(100)

        ; Auto-Vervollständigungsliste anzeigen
        _ShowCompletionList()

        ; Event durchreichen
        Return $GUI_RUNDEFMSG
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc