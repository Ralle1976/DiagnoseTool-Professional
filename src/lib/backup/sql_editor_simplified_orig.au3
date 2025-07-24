; Titel.......: SQL-Editor-Vereinfacht
; Beschreibung: Optimierte und vereinfachte Implementierung des SQL-Editors
; Autor.......: Ralle1976
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

; Include Dateien für spezifische Komponenten
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung
#include "sql_editor_utils.au3" ; Hilfsfunktionen für den SQL-Editor

; Allgemeine Konstanten
Global Const $SQL_EDITOR_HEIGHT = 200
Global Const $SQL_HOTKEY_F5 = 1      ; Eindeutige ID für F5-Hotkey
Global Const $SQL_EDITOR_EN_CHANGE = 0x0300  ; Content of edit control changed

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLTableCombo = 0         ; ID der Tabellen-Auswahlbox (keine DB-Combobox mehr)
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
Global $g_bInitializing = False       ; Flag zum Verhindern von rekursiven Events
Global $g_bExitingEditor = False      ; Flag zum Verhindern von rekursiven Events beim Beenden

; Sicherheits-Flags
Global $g_bUserInitiatedExecution = False  ; Wird nur bei tatsächlichem Klick auf Ausführen-Button gesetzt

; Status-Speicherung
Global $g_aListViewBackup[0][0]       ; Array zum Speichern des ListView-Zustands vor SQL-Editor-Aktivierung
Global $g_aListViewColBackup = 0      ; Array zum Speichern der Spaltenüberschriften
Global $g_iOrigListViewHeight = 0     ; Ursprüngliche Höhe der ListView
Global $g_iOrigListViewTop = 0        ; Ursprüngliche Y-Position der ListView
Global $g_aTableColumns[0]            ; Spalten der aktuell ausgewählten Tabelle

; Autovervollständigung
Global $g_idAutoCompleteList = 0      ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList = 0       ; Handle der Auto-Vervollständigungsliste
Global $g_bUseAutoComplete = True     ; Auto-Vervollständigung aktivieren/deaktivieren

; Layout-Informationen
Global $g_sSQLEditorPosition = ""     ; Position und Größe des Editors

; Gespeicherte Tabelle von der Hauptansicht
Global $sSavedTable = ""

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

    _LogInfo("SQL-Editor: Event-Handler registriert")

    ; Variablen für GUI-Elemente initialisieren
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

    ; Nur Tabellen-Dropdown anzeigen (vereinfachte Struktur - keine DB-ComboBox mehr)
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
    $g_idSQLExecuteBtn = GUICtrlCreateButton("Ausführen (F5)", $xCtrl, $yCtrl, 150, 30)
    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", $xCtrl + 160, $yCtrl, 100, 30)
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", $xCtrl + 270, $yCtrl, 100, 30)
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $xCtrl + $wCtrl - 100, $yCtrl, 100, 30)

    ; Panel abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1) ; Dummy-Gruppe zum Schließen

    ; Debug-Ausgaben über den aktuellen Status
    _LogInfo("Aktuelle Tabelle (global): '" & $g_sCurrentTable & "'")
    _LogInfo("Gespeicherte Tabelle (von _SQL_EditorEnter): '" & $sSavedTable & "'")
    _LogInfo("Letztes SQL für Tabelle: '" & $g_sLastSQLTable & "'")

    ; Tabellen aus der Hauptansicht übernehmen
    Local $sTables = GUICtrlRead($idTableCombo, 1) ; Alle Tabellen aus der Hauptansicht lesen
    _LogInfo("Tabellen aus Hauptansicht: '" & $sTables & "'")
    GUICtrlSetData($g_idSQLTableCombo, $sTables) ; Alle Tabellen in SQL-Editor übertragen

    ; Aktuelle Tabelle auswählen (mit Fallbacks)
    Local $sTableToUse = $sSavedTable  ; Zuerst gespeicherte Tabelle verwenden
    If $sTableToUse = "" Then $sTableToUse = $g_sCurrentTable  ; Fallback auf globale Variable
    If $sTableToUse = "" And $g_sLastSQLTable <> "" Then $sTableToUse = $g_sLastSQLTable ; Zusätzlicher Fallback

    _LogInfo("Zu verwendende Tabelle: '" & $sTableToUse & "'")

    If $sTableToUse <> "" Then
        ; Tabelle in ComboBox wählen und SQL-Statement vorbereiten
        If StringInStr("|" & $sTables & "|", "|" & $sTableToUse & "|") Then
            ; Tabelle in Combo auswählen
            _LogInfo("Tabelle '" & $sTableToUse & "' gefunden, wähle sie aus")
            GUICtrlSetData($g_idSQLTableCombo, $sTableToUse, $sTableToUse)

            ; SQL-Statement generieren oder das gespeicherte verwenden
            Local $sSQL = "SELECT * FROM " & $sTableToUse & " LIMIT 100;"
            If $g_sLastSQLTable = $sTableToUse And $g_sLastSQLStatement <> "" Then
                $sSQL = $g_sLastSQLStatement
                _LogInfo("Verwende gespeichertes SQL-Statement")
            Else
                _LogInfo("Generiere neues SQL-Statement")
            EndIf

            ; Statement in Editor setzen
            _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
            $g_sCurrentSQL = $sSQL

            ; Tabellen- und SQL-Referenzen speichern
            $g_sLastSQLTable = $sTableToUse
            $g_sLastSQLStatement = $sSQL

            ; Spalten für Auto-Vervollständigung laden
            $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sTableToUse)
            _LogInfo("Spalten geladen: " & UBound($g_aTableColumns))

            ; SQL initial ausführen (nur bei Eintritt)
            _LogInfo("Führe initiales SQL für Tabelle " & $sTableToUse & " aus")
            $g_bUserInitiatedExecution = True
            _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
            $g_bUserInitiatedExecution = False
        Else
            ; Tabelle nicht gefunden - erste verfügbare Tabelle verwenden
            _LogInfo("Tabelle '" & $sTableToUse & "' nicht gefunden, verwende Ersatztabelle")
            _UseFirstAvailableTable($sTables)
        EndIf
    Else
        ; Keine Tabelle vorgegeben - erste verfügbare verwenden
        _LogInfo("Keine Tabelle vorgegeben, verwende erste verfügbare")
        _UseFirstAvailableTable($sTables)
    EndIf

    ; Fokus auf SQL-Editor setzen
    _WinAPI_SetFocus($g_hSQLRichEdit)

    ; Syntax-Highlighting initial durchführen
    _SQL_UpdateSyntaxHighlighting()

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _UseFirstAvailableTable
; Beschreibung: Wählt die erste verfügbare Tabelle aus und erstellt ein SQL-Statement dafür
; Parameter.: $sTables - String mit allen verfügbaren Tabellen (durch | getrennt)
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _UseFirstAvailableTable($sTables)
    If $sTables = "" Then
        ; Keine Tabellen vorhanden
        Local $sSQL = "-- Keine Tabellen verfügbar \n\nSELECT 1, 'Beispiel' AS Test;"
        _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        $g_sCurrentSQL = $sSQL
        Return False
    EndIf

    ; Erste Tabelle aus der Liste extrahieren
    Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
    If UBound($aTableList) > 0 Then
        Local $sTableToUse = $aTableList[0]
        _LogInfo("Verwende erste Tabelle: " & $sTableToUse)

        ; Tabelle auswählen
        GUICtrlSetData($g_idSQLTableCombo, $sTableToUse, $sTableToUse)

        ; SQL erstellen
        Local $sSQL = "SELECT * FROM " & $sTableToUse & " LIMIT 100;"
        _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        $g_sCurrentSQL = $sSQL

        ; Referenzen speichern
        $g_sLastSQLTable = $sTableToUse
        $g_sLastSQLStatement = $sSQL

        ; SQL ausführen
        $g_bUserInitiatedExecution = True
        _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
        $g_bUserInitiatedExecution = False

        Return True
    EndIf

    Return False
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
    Local $aControls = [$g_idSQLEditorPanel, $g_idSQLTableCombo, $g_idAutoCompleteList, _
                       $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn]

    For $idControl In $aControls
        If $idControl <> 0 Then
            GUICtrlDelete($idControl)
        EndIf
    Next

    ; Handles zurücksetzen
    $g_idSQLEditorPanel = 0
    $g_idSQLTableCombo = 0
    $g_idAutoCompleteList = 0
    $g_hAutoCompleteList = 0
    $g_idSQLExecuteBtn = 0
    $g_idSQLSaveBtn = 0
    $g_idSQLLoadBtn = 0
    $g_idSQLBackBtn = 0

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
        Case $g_idSQLTableCombo
            ; Tabellenwechsel - SQL-Statement aktualisieren
            _BlockAllSQLExecutions()

            Local $sTable = GUICtrlRead($g_idSQLTableCombo)
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

    ; Aktuelle Tabelle speichern
    $sSavedTable = GUICtrlRead($idTableCombo)
    _LogInfo("Speichere aktuelle Tabelle: '" & $sSavedTable & "'")

    ; ListView-Status speichern
    _SQL_SaveListViewState()

    ; Button-Text ändern - verwende lokale Variable von main_robust.au3
    GUICtrlSetData($idBtnSQLEditor, "Zurück")

    ; SQL-Editor-Elemente erstellen
    _CreateSQLEditorElements()

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
        $g_sLastSQLTable = GUICtrlRead($g_idSQLTableCombo)
        _LogInfo("Speichere aktuelle Tabelle: " & $g_sLastSQLTable)
    EndIf

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

    ; Tabelle in Hauptansicht aktualisieren
    Local $sTableToUse = $g_sLastSQLTable
    _LogInfo("Tabelle nach Rückkehr: " & $sTableToUse)

    If $sTableToUse <> "" Then
        ; Prüfen ob Tabelle in Hauptansicht vorhanden
        Local $sTables = GUICtrlRead($idTableCombo, 1)

        If StringInStr($sTables, $sTableToUse) Then
            ; Tabelle setzen und Daten laden
            GUICtrlSetData($idTableCombo, $sTableToUse, $sTableToUse)
            $g_sCurrentTable = $sTableToUse
            _LoadDatabaseData()
        Else
            ; Erste verfügbare Tabelle verwenden
            _LogInfo("Tabelle nicht in Hauptansicht verfügbar")
            If $sTables <> "" Then
                Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
                If UBound($aTableList) > 0 Then
                    GUICtrlSetData($idTableCombo, $aTableList[0], $aTableList[0])
                    $g_sCurrentTable = $aTableList[0]
                    _LoadDatabaseData()
                EndIf
            EndIf
        EndIf
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
; Func.....: _BlockAllSQLExecutions
; Beschreibung: Verhindert automatische SQL-Ausführungen
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _BlockAllSQLExecutions()
    $g_bUserInitiatedExecution = False
EndFunc