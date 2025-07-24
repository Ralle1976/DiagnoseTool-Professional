; Titel.......: SQL-Editor-Vereinheitlicht
; Beschreibung: Vereinfachte und optimierte Lösung für den SQL-Editor mit gemeinsamer Tabellennutzung
; Autor.......: Claude
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
#include <EditConstants.au3> ; Für Tastenkonstanten

; VK-Konstanten für Tastaturabfragen
Global Const $VK_CONTROL = 0x11
Global Const $VK_SHIFT = 0x10
Global Const $VK_MENU = 0x12 ; ALT

; Referenzen auf die vorhandenen Implementierungen
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung

; Globale Variablen für die letzte verwendete Tabelle
Global $sSavedTable = ""

; Rich Edit Control Notification Codes
Global Const $SQL_EDITOR_EN_CHANGE = 0x0300  ; Content of edit control is changed

; Höhe des SQL-Editor-Panels
Global Const $SQL_EDITOR_HEIGHT = 200

; F5-Event für SQL-Ausführung
Global Const $SQL_HOTKEY_F5 = 1  ; Eindeutige ID für F5-Hotkey

; Variablen für Syntax-Highlighting-Timer
Global $g_iLastSyntaxUpdate = 0
Global $g_iSyntaxUpdateInterval = 2000  ; Intervall in Millisekunden

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
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

; Logging-Funktion mit Begrenzung für wiederkehrende Meldungen
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
; OPTIMIERTE SQL-EDITOR IMPLEMENTATION
; Ziel: Vereinfachte Navigation zwischen Hauptansicht und SQL-Editor
; ===============================================================================================================================

; Funktion zum absoluten Blockieren aller SQL-Ausführungen
Func _BlockAllSQLExecutions()
    ; Diese Funktion setzt ein Flag, das verhindert, dass SQL-Ausführungen automatisch ausgelöst werden
    $g_bUserInitiatedExecution = False
    $g_bAutoExecuteEnabled = False
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

    ; Benutzer-initiierte Ausführung markieren
    $g_bUserInitiatedExecution = True

    ; Nur ausführen, wenn SQL vorhanden ist
    If $sSQL <> "" Then
        _LogInfo("SQL-Ausführung wird durch F5-TASTE gestartet")
        _SetStatus("Führe SQL aus...")

        ; SQL aus der EditBox ausführen
        _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)

        _LogInfo("SQL wurde durch F5-Taste ausgeführt")
        _SetStatus("SQL-Ausführung abgeschlossen")

        ; Noch einmal Syntax-Highlighting aktualisieren
        _SQL_UpdateSyntaxHighlighting()
    Else
        _SetStatus("Fehler: SQL-Anweisung fehlt")
    EndIf

    ; Benutzer-initiierte Ausführung zurücksetzen
    $g_bUserInitiatedExecution = False
EndFunc

; Einfache Implementierung für Syntax-Highlighting
Func _SQL_UpdateSyntaxHighlighting()
    ; Nur fortfahren, wenn SQL-Editor aktiv ist und RichEdit-Control existiert
    If Not $g_bSQLEditorMode Or $g_hSQLRichEdit = 0 Then
        ; Statischen Cache zurücksetzen
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

#include "sql_editor_part2.au3"