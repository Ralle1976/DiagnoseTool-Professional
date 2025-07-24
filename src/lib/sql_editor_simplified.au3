; Titel.......: SQL-Editor-Optimiert
; Beschreibung: Implementierung des SQL-Editors mit einer einzigen ComboBox
; Autor.......: Ralle1976
; Erstellt....: 2025-04-14 (überarbeitet)
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

; Include Dateien für spezifische Komponenten
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung
#include "missing_functions.au3" ; Enthält die Funktion _BringButtonsToFront
#include "sql_editor_utils.au3" ; Hilfsfunktionen für den SQL-Editor

; Allgemeine Konstanten
Global Const $SQL_EDITOR_HEIGHT = 240 ; Noch mehr Platz für die neue Button-Position
Global Const $SQL_HOTKEY_F5 = 1      ; Eindeutige ID für F5-Hotkey
Global Const $SQL_EDITOR_EN_CHANGE = 0x0300  ; Content of edit control changed

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLExecuteBtn = 0         ; ID des Buttons zum Ausführen von Abfragen
Global $g_idSQLSaveBtn = 0            ; ID des Buttons zum Speichern einer SQL-Abfrage
Global $g_idSQLLoadBtn = 0            ; ID des Buttons zum Laden einer SQL-Abfrage
Global $g_idSQLBackBtn = 0            ; ID des Buttons zum Zurückkehren zur normalen Ansicht
Global $g_bSQLEditorMode = False      ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_sLastSQLStatement = ""      ; Speichert das letzte SQL-Statement
Global $g_sLastSQLTable = ""          ; Speichert die letzte Tabelle
Global $g_sCurrentSQL = ""            ; Aktuelles SQL-Statement
Global $g_idBtnSQLEditor = 0          ; ID des SQL-Editor-Buttons
Global $g_idBtnRefresh = 0            ; ID des Refresh-Buttons im Hauptfenster
Global $g_bInitializing = False       ; Flag zum Verhindern von rekursiven Events
Global $g_bExitingEditor = False      ; Flag zum Verhindern von rekursiven Events beim Beenden

; Sicherheits-Flags
Global $g_bUserInitiatedExecution = False  ; Wird nur bei tatsächlichem Klick auf Ausführen-Button gesetzt

; Status-Speicherung
Global $g_aListViewBackup[0][0]       ; Array zum Speichern des ListView-Zustands vor SQL-Editor-Aktivierung
Global $g_aListViewColBackup = 0      ; Array zum Speichern der Spaltenüberschriften
Global $g_iOrigListViewHeight = 0     ; Ursprüngliche Höhe der ListView
Global $g_iOrigListViewTop = 0        ; Ursprüngliche Y-Position der ListView

; Autovervollständigung
Global $g_idAutoCompleteList = 0      ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList = 0       ; Handle der Auto-Vervollständigungsliste
Global $g_bUseAutoComplete = True     ; Auto-Vervollständigung aktivieren/deaktivieren
Global $g_idShowCompletionBtn = 0      ; Button für Autovervollständigung

; Layout-Informationen
Global $g_sSQLEditorPosition = ""     ; Position und Größe des Editors

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
    $g_bInitializing = False   ; Initialisierung nicht aktiv
    $g_bExitingEditor = False  ; Beenden nicht aktiv

    ; Ursprüngliche Position und Größe der ListView speichern
    Local $aListViewPos = ControlGetPos($hGUI, "", $g_idListView)
    $g_iOrigListViewTop = $aListViewPos[1]
    $g_iOrigListViewHeight = $aListViewPos[3]

    ; Speichern der GUI-Informationen für dynamische Erstellung
    $g_sSQLEditorPosition = $x & "," & $y & "," & $w & "," & $SQL_EDITOR_HEIGHT

    _LogInfo("SQL-Editor-Modul initialisiert")
    _LogInfo("SQL-Editor-Position gesetzt: X=" & $x & ", Y=" & $y & ", W=" & $w & ", H=" & $SQL_EDITOR_HEIGHT)

    ; Event-Handler für Tastendrücke und Befehle im GUI registrieren
    GUIRegisterMsg($WM_COMMAND, "_WM_COMMAND")
    GUIRegisterMsg($WM_KEYDOWN, "_WM_KEYDOWN")
    GUIRegisterMsg($WM_CHAR, "_WM_CHAR")
    GUIRegisterMsg($WM_NOTIFY, "_WM_NOTIFY")

    _LogInfo("SQL-Editor: Event-Handler registriert")

    ; Variablen für GUI-Elemente initialisieren
    $g_idSQLEditorPanel = 0
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

    ; Hinweis: In dieser Version verwenden wir die gemeinsame ComboBox aus dem Hauptfenster
    ; $g_idTableCombo = $idTableCombo

    ; Buttons direkt am Anfang des Editors platzieren (innerhalb der grauen Fläche)
    Local $yBtnPos = $y + 22 ; Direkt nach der Gruppentitel-Überschrift
    
    ; Sicherstellen, dass die Buttons im Vordergrund sind mit hohem Z-Index
    ; Zuerst eine unsichtbare Gruppe erstellen, um die Z-Order zu steuern
    Local $idBtnGroup = GUICtrlCreateGroup("", $xCtrl, $yBtnPos - 2, $wCtrl, 30)
    GUICtrlSetState($idBtnGroup, $GUI_SHOW)
    
    ; Alle Controls sichtbar machen, falls sie bereits existieren aber unsichtbar sind
    Local $aControls = [$g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idShowCompletionBtn, $g_idSQLBackBtn]
    For $idControl In $aControls
        If $idControl <> 0 Then
            GUICtrlSetState($idControl, $GUI_SHOW)
            _LogInfo("Button sichtbar gemacht: " & $idControl)
        EndIf
    Next
    
    ; Dann die Buttons mit expliziter Z-Order erstellen - mit Tooltips
    $g_idSQLExecuteBtn = GUICtrlCreateButton("Ausführen (F5)", $xCtrl, $yBtnPos, 150, 25, $BS_DEFPUSHBUTTON)
    GUICtrlSetTip($g_idSQLExecuteBtn, "Führt die SQL-Abfrage aus (F5)", "Ausführen", 0, 1)
    
    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", $xCtrl + 160, $yBtnPos, 100, 25)
    GUICtrlSetTip($g_idSQLSaveBtn, "Speichert die aktuelle SQL-Abfrage in einer Datei", "Speichern", 0, 1)
    
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", $xCtrl + 270, $yBtnPos, 100, 25)
    GUICtrlSetTip($g_idSQLLoadBtn, "Lädt eine SQL-Abfrage aus einer Datei", "Laden", 0, 1)
    
    $g_idShowCompletionBtn = GUICtrlCreateButton("Vervollst.", $xCtrl + 380, $yBtnPos, 100, 25)
    GUICtrlSetTip($g_idShowCompletionBtn, "Zeigt Autovervollständigung an (Strg+Leertaste)", "Autovervollständigung", 0, 1)
    
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $xCtrl + $wCtrl - 100, $yBtnPos, 100, 25)
    GUICtrlSetTip($g_idSQLBackBtn, "Zurück zur normalen Ansicht", "Zurück", 0, 1)
    
    ; Button-Gruppe abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    
    ; RichEdit-Control für SQL-Eingabe - vergrößert für mehr Code-Raum, direkt unter den Buttons
    $yCtrl = $yBtnPos + 30 ; Abstand zu den Buttons
    $g_hSQLRichEdit = _GUICtrlRichEdit_Create($g_hGUI, "", $xCtrl, $yCtrl, $wCtrl, 170, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")
    
    ; Tooltip für das RichEdit-Control
    GUICtrlSetTip(GUICtrlGetHandle($g_hSQLRichEdit), "F5 = Ausführen, Strg+Leertaste = Autovervollständigung, Pfeiltasten & Enter/Tab/Esc = Navigation", "SQL-Editor Tastaturkürzel", 0, 1)
    
    ; Explizit die Z-Order festlegen - RichEdit hinter die Buttons setzen
    _WinAPI_SetWindowPos(GUICtrlGetHandle($g_hSQLRichEdit), $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))

    ; Auto-Vervollständigungsliste
    $g_idAutoCompleteList = GUICtrlCreateList("", $xCtrl, $yCtrl + 50, 250, 150, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY))
    $g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
    _LogInfo("Autovervollständigungsliste erstellt: " & $g_idAutoCompleteList & ", Handle: " & $g_hAutoCompleteList)

    ; Panel abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1) ; Dummy-Gruppe zum Schließen

    ; Debug-Ausgaben über den aktuellen Status
    _LogInfo("Aktuelle Tabelle (global): '" & $g_sCurrentTable & "'")
    _LogInfo("Letztes SQL für Tabelle: '" & $g_sLastSQLTable & "'")

    ; SQL für aktuelle Tabelle erstellen
    Local $sCurrentTable = GUICtrlRead($g_idTableCombo)
    _LogInfo("Aktuelle Tabelle in ComboBox: " & $sCurrentTable)

    If $sCurrentTable <> "" Then
        ; SQL-Statement generieren oder das gespeicherte verwenden
        Local $sSQL = "SELECT * FROM " & $sCurrentTable & " LIMIT 100;"
        If $g_sLastSQLTable = $sCurrentTable And $g_sLastSQLStatement <> "" Then
            $sSQL = $g_sLastSQLStatement
            _LogInfo("Verwende gespeichertes SQL-Statement")
        Else
            _LogInfo("Generiere neues SQL-Statement")
        EndIf

        ; Statement in Editor setzen
        _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        $g_sCurrentSQL = $sSQL

        ; Tabellen- und SQL-Referenzen speichern
        $g_sLastSQLTable = $sCurrentTable
        $g_sLastSQLStatement = $sSQL

        ; Spalten für Auto-Vervollständigung laden
        $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sCurrentTable)
        _LogInfo("Spalten geladen: " & UBound($g_aTableColumns))

        ; SQL initial ausführen (nur bei Eintritt)
        _LogInfo("Führe initiales SQL für Tabelle " & $sCurrentTable & " aus")
        $g_bUserInitiatedExecution = True
        _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
        $g_bUserInitiatedExecution = False

    ; Statusmeldung mit Tastaturkombinationen anzeigen
    _SetStatus("SQL-Editor: [F5] = Ausführen, [Strg+Leertaste] = Autovervollst., [Tab/Enter] = Auswahl bestätigen")
    Else
        ; Keine Tabelle ausgewählt - leeres SQL
        Local $sSQL = "-- Bitte wählen Sie eine Tabelle aus der Dropdown-Liste"
        _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        $g_sCurrentSQL = $sSQL
    EndIf

    ; Fokus auf SQL-Editor setzen
    _WinAPI_SetFocus($g_hSQLRichEdit)

    ; Syntax-Highlighting initial durchführen
    _SQL_UpdateSyntaxHighlighting()

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

    ; RichEdit zuerst zerstören
    If $g_hSQLRichEdit <> 0 Then
        _GUICtrlRichEdit_Destroy($g_hSQLRichEdit)
        $g_hSQLRichEdit = 0
    EndIf

    ; Dann Controls löschen
    Local $aControls = [$g_idSQLEditorPanel, $g_idAutoCompleteList, _
                       $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn]

    For $idControl In $aControls
        If $idControl <> 0 Then
            GUICtrlDelete($idControl)
        EndIf
    Next

    ; Handles zurücksetzen
    $g_idSQLEditorPanel = 0
    $g_idAutoCompleteList = 0
    $g_hAutoCompleteList = 0
    $g_idSQLExecuteBtn = 0
    $g_idSQLSaveBtn = 0
    $g_idSQLLoadBtn = 0
    $g_idSQLBackBtn = 0
    $g_idShowCompletionBtn = 0

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
    ; Wenn wir gerade initialisieren oder beenden, keine Events verarbeiten
    If $g_bInitializing Or $g_bExitingEditor Then Return True

    Switch $iMsg
        Case $g_idTableCombo, $idTableCombo
            ; Tabellenwechsel - SQL-Statement aktualisieren
            _BlockAllSQLExecutions()

            Local $sTable = GUICtrlRead($g_idTableCombo)
            If $sTable <> "" Then
                _LogInfo("Tabelle ausgewählt: " & $sTable)

                ; Standard-SQL für diese Tabelle erstellen
                Local $sSQL = "SELECT * FROM " & $sTable & " LIMIT 100;"
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                $g_sCurrentSQL = $sSQL
                $g_sCurrentTable = $sTable

                ; Syntax aktualisieren und Benutzerhinweis
                _SQL_UpdateSyntaxHighlighting()
                _SetStatus("Tabelle '" & $sTable & "' ausgewählt. Klicken Sie auf 'Ausführen'.")
            EndIf
            Return True

        Case $g_idSQLExecuteBtn
            ; SQL ausführen
            _LogInfo("Ausführen-Button gedrückt")

            ; Benutzer-initiierte Ausführung markieren
            $g_bUserInitiatedExecution = True

            ; SQL-Text und Datenbank holen
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            $g_sCurrentSQL = $sSQL

            ; Ausführen wenn SQL vorhanden
            If $sSQL <> "" Then
                _LogInfo("Führe SQL aus")
                _SetStatus("Führe SQL aus...")

                ; SQL ausführen
                _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)

                ; Erfolgsmeldung
                _LogInfo("SQL ausgeführt")
                _SetStatus("SQL-Ausführung abgeschlossen")

                ; Statement für nächste Verwendung speichern
                $g_sLastSQLStatement = $sSQL

                ; Highlighting aktualisieren
                _SQL_UpdateSyntaxHighlighting()
            Else
                _SetStatus("Fehler: SQL-Anweisung fehlt")
            EndIf

            ; Flag zurücksetzen
            $g_bUserInitiatedExecution = False
            Return True

        Case $g_idShowCompletionBtn
            ; Button für Autovervollständigung
            _LogInfo("Autovervollständigungs-Button gedrückt")
            ; Sicherstellen, dass bestehende Autovervollständigungsfenster geschlossen werden
            If $g_bAutoCompleteWindowVisible Then _CloseAutoCompleteWindow()
            _ShowCompletionList()
            Return True

        Case $g_idSQLBackBtn
            ; SQL-Editor mit Zurück-Button verlassen
            _LogInfo("Zurück-Button im SQL-Editor gedrückt")
            _SQL_EditorExit()
            Return True

        Case $idBtnSQLEditor
            ; SQL-Editor mit Haupt-Button verlassen
            _LogInfo("Hauptbutton für SQL-Editor gedrückt")
            _SQL_EditorExit()
            Return True

        Case $g_idSQLSaveBtn
            ; SQL-Abfrage in Datei speichern
            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                Local $sFile = FileSaveDialog("SQL-Abfrage speichern", @ScriptDir, "SQL-Dateien (*.sql)", $FD_PATHMUSTEXIST)
                If Not @error Then
                    If StringRight($sFile, 4) <> ".sql" Then $sFile &= ".sql"
                    FileWrite($sFile, $sSQL)
                    _SetStatus("SQL-Abfrage gespeichert: " & $sFile)
                EndIf
            EndIf
            Return True

        Case $g_idSQLLoadBtn
            ; SQL-Abfrage aus Datei laden
            Local $sFile = FileOpenDialog("SQL-Abfrage laden", @ScriptDir, "SQL-Dateien (*.sql)", $FD_FILEMUSTEXIST)
            If Not @error Then
                Local $sSQL = FileRead($sFile)
                If Not @error Then
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                    $g_sCurrentSQL = $sSQL
                    _SQL_UpdateSyntaxHighlighting()
                    _SetStatus("SQL-Abfrage geladen: " & $sFile)

                    ; NEUES FEATURE: Versuche Tabellenname aus SQL zu extrahieren und ComboBox zu aktualisieren
                    Local $sTableFromSQL = _ExtractTableFromSQL($sSQL)
                    If $sTableFromSQL <> "" Then
                        Local $sTables = GUICtrlRead($g_idTableCombo, 1)
                        If StringInStr("|" & $sTables & "|", "|" & $sTableFromSQL & "|") Then
                            _LogInfo("Tabelle aus SQL erkannt, aktualisiere ComboBox: " & $sTableFromSQL)
                            GUICtrlSetData($g_idTableCombo, $sTableFromSQL, $sTableFromSQL)
                            $g_sCurrentTable = $sTableFromSQL
                        EndIf
                    EndIf
                EndIf
            EndIf
            Return True

        Case $idBtnRefresh
            ; Duplizierte Aktualisierung verhindern
            _SetStatus("Bitte verwenden Sie den 'Ausführen'-Button stattdessen")
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
    ; Bereits aktiv?
    If $g_bSQLEditorMode Then Return True
    ; Rekursion vermeiden
    If $g_bInitializing Then Return False

    $g_bInitializing = True
    _LogInfo("Aktiviere SQL-Editor-Modus")

    ; Globale Button-IDs aus dem Hauptfenster speichern
    $g_idBtnSQLEditor = $idBtnSQLEditor
    $g_idBtnRefresh = $idBtnRefresh
    _LogInfo("Button-IDs gespeichert: SQLEditor=" & $g_idBtnSQLEditor & ", Refresh=" & $g_idBtnRefresh)

    ; ComboBox-ID speichern - NEUES FEATURE: Wir verwenden die vorhandene ComboBox
    $g_idTableCombo = $idTableCombo
    _LogInfo("Verwende vorhandene ComboBox: " & $g_idTableCombo)

    ; ListView-Status speichern
    _SQL_SaveListViewState()

    ; Button-Text ändern für Rückkehr zum normalen Modus
    GUICtrlSetData($idBtnSQLEditor, "Zurück")

    ; SQL-Editor-Elemente erstellen
    _CreateSQLEditorElements()
    
    ; Sicherstellen, dass alle Buttons im Vordergrund sind - Funktion aus missing_functions.au3
    _BringButtonsToFront()

    ; ListView anpassen (Position/Größe)
    Local $aPos = ControlGetPos($g_hGUI, "", $g_idListView)
    ControlMove($g_hGUI, "", $g_idListView, $aPos[0], $g_iOrigListViewTop + $SQL_EDITOR_HEIGHT, $aPos[2], $g_iOrigListViewHeight - $SQL_EDITOR_HEIGHT)
    GUICtrlSetState($g_idListView, $GUI_SHOW)

    ; Editor aktivieren
    $g_bSQLEditorMode = True

    ; Sicherheitssperre aktivieren
    _BlockAllSQLExecutions()

    ; F5-Taste und Syntax-Highlighting aktivieren
    AdlibRegister("_AdLibSyntaxHighlighting", 2000)
    HotKeySet("{F5}", "_ExecuteSQL_F5")

    _LogInfo("SQL-Editor-Modus aktiviert")
    $g_bInitializing = False
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_EditorExit
; Beschreibung: Deaktiviert den SQL-Editor-Modus
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, sonst False
; ===============================================================================================================================
Func _SQL_EditorExit()
    ; Nicht aktiv?
    If Not $g_bSQLEditorMode Then Return True
    ; Rekursion vermeiden
    If $g_bExitingEditor Then Return False

    $g_bExitingEditor = True
    _LogInfo("Verlasse SQL-Editor-Modus")

    ; Aktuelle Tabelle und SQL speichern
    If $g_hSQLRichEdit <> 0 And IsHWnd($g_hSQLRichEdit) Then
        $g_sLastSQLStatement = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
        $g_sLastSQLTable = GUICtrlRead($g_idTableCombo)
        _LogInfo("Speichere aktuelle Tabelle: " & $g_sLastSQLTable)
    EndIf

    ; Altes Autovervollständigungsfenster schließen
    If $g_bAutoCompleteWindowVisible Then _CloseAutoCompleteWindow()
    
    ; Button-Text zurücksetzen - verwende lokale Variable von main_robust.au3
    GUICtrlSetData($idBtnSQLEditor, "SQL-Editor")

    ; Editor-Elemente entfernen
    _DeleteSQLEditorElements()

    ; ListView wiederherstellen
    ControlMove($g_hGUI, "", $g_idListView, 2, $g_iOrigListViewTop, ControlGetPos($g_hGUI, "", $g_idListView)[2], $g_iOrigListViewHeight)

    ; Modus deaktivieren
    $g_bSQLEditorMode = False

    ; AdLib und Hotkey deaktivieren
    AdlibUnRegister("_AdLibSyntaxHighlighting")
    HotKeySet("{F5}")

    ; Kurze Pause für saubere Deaktivierung
    Sleep(100)

    ; ListView zurücksetzen
    Local $hListView = GUICtrlGetHandle($g_idListView)
    _WinAPI_SetWindowPos($hListView, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    _WinAPI_RedrawWindow($hListView)

    ; Sicherstellen, dass die Datenbank noch offen ist, bevor wir Daten laden
    If Not _SQLite_Exec($g_sCurrentDB, "SELECT 1") = $SQLITE_OK Then
        ; Wenn die Datenbank geschlossen ist, öffnen wir sie erneut
        _LogInfo("Datenbank scheint geschlossen zu sein, öffne sie erneut")
        _SQLite_Open($g_sCurrentDB)
    EndIf

    ; Kurze Pause um sicherzustellen, dass die Datenbank bereit ist
    Sleep(200)

    ; Daten für die aktuelle Tabelle laden
    If $g_sCurrentTable <> "" Then
        _LogInfo("Lade Daten für Tabelle: " & $g_sCurrentTable)
        _LoadDatabaseData()
    Else
        _LogInfo("Keine aktuelle Tabelle definiert")
    EndIf

    ; GUI-Styles wiederherstellen
    _GUICtrlListView_SetExtendedListViewStyle($hListView, $iExListViewStyle)

    ; Fenster aktualisieren
    WinSetState($g_hGUI, "", @SW_HIDE)
    WinSetState($g_hGUI, "", @SW_SHOW)

    _LogInfo("SQL-Editor-Modus deaktiviert")
    $g_bExitingEditor = False
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _ToggleSQLEditorMode
; Beschreibung: Umschalten zwischen SQL-Editor-Modus und normalem Modus
; Parameter.: $bActivate - True zum Aktivieren, False zum Deaktivieren
; Rückgabe..: True bei Erfolg, sonst False
; ===============================================================================================================================
Func _ToggleSQLEditorMode($bActivate)
    If $g_bSQLEditorMode = $bActivate Then Return True

    If $bActivate Then
        Return _SQL_EditorEnter()
    Else
        Return _SQL_EditorExit()
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _WM_COMMAND
; Beschreibung: Event-Handler für WM_COMMAND Nachrichten (Textänderungen)
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func _WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    ; Rekursive Ereignisverarbeitung vermeiden
    Static $bProcessing = False

    If $bProcessing Then Return $GUI_RUNDEFMSG
    $bProcessing = True

    If $g_bSQLEditorMode And Not $g_bExitingEditor And Not $g_bInitializing Then
        ; Textänderung im RichEdit erkennen
        Local $hiword = BitShift($wParam, 16)
        Local $lowword = BitAND($wParam, 0xFFFF)

        If $hiword = $SQL_EDITOR_EN_CHANGE And $g_hSQLRichEdit <> 0 Then
            If GUICtrlGetHandle($lowword) = $g_hSQLRichEdit Then
                ; Automatische Ausführung blockieren
                _BlockAllSQLExecutions()

                ; Aktuellen SQL-Text erfassen für spätere Verwendung
                $g_sCurrentSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            EndIf
        EndIf
    EndIf

    $bProcessing = False
    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SaveListViewState
; Beschreibung: Speichert den aktuellen Zustand der ListView
; Parameter.: Keine
; Rückgabe..: True bei Erfolg
; ===============================================================================================================================
Func _SQL_SaveListViewState()
    Local $hListView = GUICtrlGetHandle($g_idListView)
    Local $iItems = _GUICtrlListView_GetItemCount($hListView)
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)

    ; Keine Daten vorhanden
    If $iItems = 0 Or $iColumns = 0 Then
        Local $aEmpty[0][0]
        $g_aListViewBackup = $aEmpty
        Local $aEmptyCol[0][2]
        $g_aListViewColBackup = $aEmptyCol
        Return True
    EndIf

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

    Return True
EndFunc


; ===============================================================================================================================
; Func.....: _WM_NOTIFY
; Beschreibung: Event-Handler für WM_NOTIFY Nachrichten (Listenboxen etc.)
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func _WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    ; Nur im SQL-Editor-Modus
    If Not $g_bSQLEditorMode Then Return $GUI_RUNDEFMSG

    ; Rekursive Ereignisverarbeitung vermeiden
    Static $bProcessing = False
    If $bProcessing Then Return $GUI_RUNDEFMSG
    $bProcessing = True

    ; NMHDR-Struktur extrahieren
    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    Local $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
    Local $iCode = DllStructGetData($tNMHDR, "Code")

    ; Debug-Ausgabe für Events - zur Fehlersuche aktivieren
    _LogInfo("WM_NOTIFY: hWndFrom=" & $hWndFrom & ", hAutoComplete=" & $g_hAutoCompleteList & ", Code=" & $iCode)

    ; AutoCompleteList-Events - verbesserte Erkennung mit direktem Vergleich
    If $g_hAutoCompleteList <> 0 And $hWndFrom = $g_hAutoCompleteList Then
        _LogInfo("WM_NOTIFY: AutoCompleteList-Event erkannt: Code=" & $iCode)

        ; Sowohl Doppelklick als auch Selektionsänderung erkennen
        If $iCode = $LBN_DBLCLK Then
            _LogInfo("WM_NOTIFY: Doppelklick auf Autovervollständigung")
            _ApplyAutoComplete()
            $bProcessing = False
            Return $GUI_RUNDEFMSG
        ElseIf $iCode = $LBN_SELCHANGE Then
            _LogInfo("WM_NOTIFY: Selektion in Autovervollständigung geändert")
            ; Hier könnte man eine Preview-Funktion implementieren
        EndIf
    EndIf

    $bProcessing = False
    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: _BlockAllSQLExecutions
; Beschreibung: Verhindert automatische SQL-Ausführungen
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================

#CS
Func _BlockAllSQLExecutions()
    $g_bUserInitiatedExecution = False
    _LogInfo("SQL-Ausführungssperre aktiviert - Warte auf Benutzeraktion")
EndFunc
#CE
