; Titel.......: SQL-Editor-Optimiert und Überarbeitet
; Beschreibung: Implementierung des persistenten SQL-Editors mit einem einzigen ListView-Control
; Autor.......: Ralle1976
; Erstellt....: 2025-04-15
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

; Include Dateien für spezifische Komponenten
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung
#include "missing_functions.au3" ; Enthält Hilfsfunktionen

; Allgemeine Konstanten
Global Const $SQL_EDITOR_HEIGHT = 240     ; Höhe des SQL-Editor-Bereichs
Global Const $SQL_HOTKEY_F5 = 1           ; Eindeutige ID für F5-Hotkey
Global Const $SQL_EDITOR_EN_CHANGE = 0x0300  ; Content of edit control changed

; GUI-Positionen für Controls im SQL-Editor-Modus
Global $g_aSQLPanelPos[4]       ; X, Y, Breite, Höhe des SQL-Panels
Global $g_aSQLListViewPos[4]    ; X, Y, Breite, Höhe der ListView im SQL-Editor-Modus
Global $g_aNormalListViewPos[4] ; X, Y, Breite, Höhe der ListView im normalen Modus

; Globale Variablen für den integrierten SQL-Editor
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLExecuteBtn = 0         ; ID des Buttons zum Ausführen von Abfragen
Global $g_idSQLSaveBtn = 0            ; ID des Buttons zum Speichern einer SQL-Abfrage
Global $g_idSQLLoadBtn = 0            ; ID des Buttons zum Laden einer SQL-Abfrage
Global $g_idSQLBackBtn = 0            ; ID des Buttons zum Zurückkehren zur normalen Ansicht
Global $g_idShowCompletionBtn = 0     ; Button für Autovervollständigung
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

; Datenbank-Variablen
Global $g_sCurrentDB = ""             ; Aktuelle Datenbank
Global $g_aTableColumns[0]           ; Array mit Spaltennamen

; Auto-Vervollständigungs-Variablen
Global $g_idAutoCompleteList = 0      ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList = 0       ; Handle der Auto-Vervollständigungsliste
Global $g_bUseAutoComplete = True     ; Auto-Vervollständigung aktivieren/deaktivieren
Global $g_bAutoCompleteWindowVisible = False ; Status des Autovervollständigungsfensters
Global $g_hAutoCompleteWindow = 0     ; Handle des Autovervollständigungs-Fensters
Global $g_idAutoCompleteListPopup = 0  ; ID der Listbox im Popup-Fenster
Global $g_aCurrentMatches[0]          ; Array mit aktuellen Vorschlägen
Global $g_iCurrentWordStart = 0       ; Startposition des aktuellen Wortes

; ===============================================================================================================================
; Func.....: _InitPersistentSQLEditor
; Beschreibung: Initialisiert den SQL-Editor einmalig während des Programmstarts
; Parameter.: $hGUI - Handle des Hauptfensters
;             $idListView - ID der ListView
;             $x, $y - Basis-Position (oben links)
;             $width - Breite des Arbeitsbereichs
; Rückgabe..: True bei Erfolg
; ===============================================================================================================================
Func _InitPersistentSQLEditor($hGUI, $idListView, $x, $y, $width)
    _LogInfo("Initialisiere persistenten SQL-Editor")
    
    Local $height = 700 ; Gesamthöhe des Bereichs
    
    ; Speichere ListView-ID global
    $g_idListView = $idListView
    
    ; Speichere Positionen für normalen Modus
    Local $aListViewPos = ControlGetPos($hGUI, "", $g_idListView)
    $g_aNormalListViewPos[0] = $aListViewPos[0] ; X
    $g_aNormalListViewPos[1] = $aListViewPos[1] ; Y
    $g_aNormalListViewPos[2] = $aListViewPos[2] ; Breite
    $g_aNormalListViewPos[3] = $aListViewPos[3] ; Höhe
    
    ; Berechne SQL-Panel-Position
    $g_aSQLPanelPos[0] = $x
    $g_aSQLPanelPos[1] = $y
    $g_aSQLPanelPos[2] = $width
    $g_aSQLPanelPos[3] = $SQL_EDITOR_HEIGHT
    
    ; Berechne ListView-Position im SQL-Editor-Modus
    $g_aSQLListViewPos[0] = $x
    $g_aSQLListViewPos[1] = $y + $SQL_EDITOR_HEIGHT
    $g_aSQLListViewPos[2] = $width
    $g_aSQLListViewPos[3] = $height - $SQL_EDITOR_HEIGHT - $y
    
    ; Panel für SQL-Editor erstellen
    $g_idSQLEditorPanel = GUICtrlCreateGroup("SQL-Editor", $g_aSQLPanelPos[0], $g_aSQLPanelPos[1], $g_aSQLPanelPos[2], $g_aSQLPanelPos[3])
    
    ; Abstand der Steuerelemente vom Rand des Panels
    Local $iMargin = 10
    Local $xCtrl = $g_aSQLPanelPos[0] + $iMargin
    Local $yCtrl = $g_aSQLPanelPos[1] + 20 ; Berücksichtige Höhe der Gruppenüberschrift
    Local $wCtrl = $g_aSQLPanelPos[2] - 2 * $iMargin
    
    ; Buttons erstellen - Positionierung relativ zum Panel
    Local $yBtnPos = $g_aSQLPanelPos[1] + 22 ; Direkt nach der Gruppentitel-Überschrift

    ; SQL-Editor-Buttons mit Tooltips erstellen
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
    
    ; RichEdit-Control für SQL-Eingabe
    $yCtrl = $yBtnPos + 30 ; Abstand zu den Buttons
    $g_hSQLRichEdit = _GUICtrlRichEdit_Create($hGUI, "", $xCtrl, $yCtrl, $wCtrl, 170, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")
    
    ; Tooltip für das RichEdit-Control
    GUICtrlSetTip(GUICtrlGetHandle($g_hSQLRichEdit), "F5 = Ausführen, Strg+Leertaste = Autovervollständigung, Pfeiltasten & Enter/Tab/Esc = Navigation", "SQL-Editor Tastaturkürzel", 0, 1)
    
    ; Auto-Vervollständigungsliste - initial unsichtbar
    $g_idAutoCompleteList = GUICtrlCreateList("", $xCtrl, $yCtrl + 50, 250, 150, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY))
    $g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
    
    ; Panel-Gruppe abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    
    ; Alle SQL-Editor-Elemente initial verstecken
    Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn, $g_idAutoCompleteList]
    For $idControl In $aControls
        GUICtrlSetState($idControl, $GUI_HIDE)
    Next
    
    ; RichEdit verstecken
    If IsHWnd($g_hSQLRichEdit) Then
        _WinAPI_ShowWindow($g_hSQLRichEdit, @SW_HIDE)
    EndIf
    
    ; Event-Handler für Tastendrücke und Befehle im GUI registrieren
    GUIRegisterMsg($WM_COMMAND, "_SQL_WM_COMMAND")
    
    ; Wichtig: Wir verweisen hier auf die bereits existierenden Funktionen in sql_editor_utils.au3
    GUIRegisterMsg($WM_KEYDOWN, "_WM_KEYDOWN")
    GUIRegisterMsg($WM_CHAR, "_WM_CHAR")
    
    _LogInfo("Persistenter SQL-Editor initialisiert und verborgen")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _TogglePersistentSQLEditor
; Beschreibung: Wechselt zwischen SQL-Editor-Modus und normalem Modus
; Parameter.: $bActivate - True zum Aktivieren, False zum Deaktivieren
; Rückgabe..: True bei Erfolg, sonst False
; ===============================================================================================================================
Func _TogglePersistentSQLEditor($bActivate)
    ; Wenn Status bereits entspricht, nichts tun
    If $g_bSQLEditorMode = $bActivate Then Return True
    
    If $bActivate Then
        ; Wechsel in SQL-Editor-Modus
        _LogInfo("Wechsle in SQL-Editor-Modus")
        
        ; Button-Text für Rückkehr zum normalen Modus ändern
        GUICtrlSetData($g_idBtnSQLEditor, "Zurück")
        
        ; ListView-Position anpassen
        ControlMove($g_hGUI, "", $g_idListView, $g_aSQLListViewPos[0], $g_aSQLListViewPos[1], $g_aSQLListViewPos[2], $g_aSQLListViewPos[3])
        
        ; SQL-Panel und dessen Controls anzeigen
        Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn]
        For $idControl In $aControls
            GUICtrlSetState($idControl, $GUI_SHOW)
        Next
        
        ; RichEdit anzeigen
        If IsHWnd($g_hSQLRichEdit) Then
            _WinAPI_ShowWindow($g_hSQLRichEdit, @SW_SHOW)
        EndIf
        
        ; SQL für aktuelle Tabelle vorbereiten
        _PrepareCurrentSQL()
        
        ; Sicherstellen, dass alle Controls die richtige Z-Order haben
        _SetSQLControlsZOrder()
        
        ; Timer für Syntax-Highlighting aktivieren
        AdlibRegister("_AdLibSyntaxHighlighting", 2000)
        
        ; F5-Taste für SQL-Ausführung registrieren
        HotKeySet("{F5}", "_ExecuteSQL_F5")
        
        ; Status aktualisieren
        $g_bSQLEditorMode = True
    Else
        ; Wechsel in normalen Modus
        _LogInfo("Wechsle in normalen Modus")
        
        ; Button-Text zurücksetzen
        GUICtrlSetData($g_idBtnSQLEditor, "SQL-Editor")
        
        ; Aktuelle SQL und Tabelle speichern
        $g_sLastSQLStatement = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
        $g_sLastSQLTable = GUICtrlRead($g_idTableCombo)
        
        ; SQL-Panel und dessen Controls verstecken
        Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn, $g_idAutoCompleteList]
        For $idControl In $aControls
            GUICtrlSetState($idControl, $GUI_HIDE)
        Next
        
        ; RichEdit verstecken
        If IsHWnd($g_hSQLRichEdit) Then
            _WinAPI_ShowWindow($g_hSQLRichEdit, @SW_HIDE)
        EndIf
        
        ; ListView-Position auf normal zurücksetzen
        ControlMove($g_hGUI, "", $g_idListView, $g_aNormalListViewPos[0], $g_aNormalListViewPos[1], $g_aNormalListViewPos[2], $g_aNormalListViewPos[3])
        
        ; Timer und Hotkeys deaktivieren
        AdlibUnRegister("_AdLibSyntaxHighlighting")
        HotKeySet("{F5}")
        
        ; Status aktualisieren
        $g_bSQLEditorMode = False
    EndIf
    
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _PrepareCurrentSQL
; Beschreibung: Bereitet den SQL-Text für die aktuelle Tabelle vor
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _PrepareCurrentSQL()
    ; Aktuelle Tabelle ermitteln
    Local $sCurrentTable = GUICtrlRead($g_idTableCombo)
    _LogInfo("Aktuelle Tabelle in ComboBox: " & $sCurrentTable)
    
    If $sCurrentTable <> "" Then
        ; SQL-Statement generieren oder gespeichertes verwenden
        Local $sSQL = "SELECT * FROM " & $sCurrentTable & " LIMIT 100;"
        
        ; Wenn die letzte Tabelle dieselbe war, gespeichertes SQL verwenden
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
        If IsDeclared("g_aTableColumns") Then
            $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sCurrentTable)
            _LogInfo("Spalten geladen: " & UBound($g_aTableColumns))
        EndIf
        
        ; Syntax-Highlighting initial durchführen
        _SQL_UpdateSyntaxHighlighting()
        
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
    
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SetSQLControlsZOrder
; Beschreibung: Setzt die Z-Order aller SQL-Editor-Controls korrekt
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SetSQLControlsZOrder()
    ; Panel im Hintergrund
    _WinAPI_SetWindowPos(GUICtrlGetHandle($g_idSQLEditorPanel), $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    
    ; RichEdit über dem Panel, aber unter den Buttons
    If IsHWnd($g_hSQLRichEdit) Then
        _WinAPI_SetWindowPos($g_hSQLRichEdit, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    EndIf
    
    ; Buttons im Vordergrund
    Local $aButtons = [$g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idShowCompletionBtn, $g_idSQLBackBtn]
    For $idButton In $aButtons
        If $idButton <> 0 Then
            Local $hButton = GUICtrlGetHandle($idButton)
            If $hButton <> 0 And IsHWnd($hButton) Then
                _WinAPI_SetWindowPos($hButton, $HWND_TOP, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
            EndIf
        EndIf
    Next
    
    _LogInfo("Z-Order der SQL-Editor-Controls gesetzt")
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
            
        Case $g_idSQLBackBtn, $g_idBtnSQLEditor
            ; SQL-Editor verlassen
            _LogInfo("Zurück-/SQL-Editor-Button gedrückt")
            _TogglePersistentSQLEditor(False)
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
                    
                    ; Versuche Tabellenname aus SQL zu extrahieren und ComboBox zu aktualisieren
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
; Func.....: _SQL_WM_COMMAND
; Beschreibung: Event-Handler für WM_COMMAND Nachrichten (Textänderungen)
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func _SQL_WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    ; Rekursive Ereignisverarbeitung vermeiden
    Static $bProcessing = False
    
    If $bProcessing Then Return $GUI_RUNDEFMSG
    $bProcessing = True
    
    If $g_bSQLEditorMode Then
        ; Textänderung im RichEdit erkennen
        Local $hiword = BitShift($wParam, 16)
        Local $lowword = BitAND($wParam, 0xFFFF)
        
        If $hiword = $SQL_EDITOR_EN_CHANGE And $g_hSQLRichEdit <> 0 Then
            If GUICtrlGetHandle($lowword) = $g_hSQLRichEdit Then
                ; Aktuellen SQL-Text erfassen für spätere Verwendung
                $g_sCurrentSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
                
                ; Verbindung zum externen _BlockAllSQLExecutions aus sql_editor_utils.au3
                If IsDeclared("_BlockAllSQLExecutions") Then
                    _BlockAllSQLExecutions()
                EndIf
            EndIf
        EndIf
    EndIf
    
    $bProcessing = False
    Return $GUI_RUNDEFMSG
EndFunc

; In sql_editor_utils.au3 bereits definiert - hier nur Referenz, keine erneute Definition
; ===============================================================================================================================
; Func.....: _BlockAllSQLExecutions
; Beschreibung: Verhindert automatische SQL-Ausführungen
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
; Wurde bereits in sql_editor_utils.au3 definiert - daher hier auskommentiert
;~ Func _BlockAllSQLExecutions()
;~     $g_bUserInitiatedExecution = False
;~ EndFunc