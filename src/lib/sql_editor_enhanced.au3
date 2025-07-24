; Titel.......: SQL-Editor-Optimiert und Überarbeitet
; Beschreibung: Implementierung des persistenten SQL-Editors mit einem einzigen ListView-Control
; Autor.......: Ralle1976
; Erstellt....: 2025-04-15
; Aktualisiert: 2025-04-26 - Verbesserte SQL-Text-Darstellung
; ===============================================================================================================================
; Func.....: _ForceSetSQLText
; Beschreibung: Verbesserte Funktion zum zuverlässigen Setzen des SQL-Texts im RichEdit-Control
; Parameter.: $sText - Der zu setzende SQL-Text
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ForceSetSQLText($sText)
    _LogInfo("_ForceSetSQLText: Setze SQL-Text: " & $sText)
    
    ; Prüfen, ob RichEdit-Control gültig ist
    If Not IsHWnd($g_hSQLRichEdit) Then
        _LogError("_ForceSetSQLText: RichEdit-Control nicht gültig")
        Return False
    EndIf
    
    ; Sicherstellen, dass der SQL-Editor im Vordergrund ist
    _WinAPI_SetFocus($g_hSQLRichEdit)
    Sleep(50) ; Kurze Pause für Fokus-Übergang
    
    ; Verbesserte Methode zur garantierten Textübergabe
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")
    _WinAPI_UpdateWindow($g_hSQLRichEdit)
    Sleep(50)
    
    ; DirectUI-Ansatz ohne Zwischenablage
    DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $g_hSQLRichEdit, "uint", $WM_SETTEXT, "wparam", 0, "wstr", $sText)
    _WinAPI_UpdateWindow($g_hSQLRichEdit)
    Sleep(50)
    
    ; Alternative Methode wenn die erste nicht funktioniert
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sText)
    _WinAPI_UpdateWindow($g_hSQLRichEdit) 
    Sleep(50)
    
    ; Letzte Methode: Windows Clipboard verwenden (funktioniert fast immer)
    Local $sPrevClip = ClipGet() ; Zwischenablage sichern
    ClipPut($sText) ; Text in die Zwischenablage
    ControlSend($g_hGUI, "", $g_hSQLRichEdit, "^a{DEL}^v") ; Alles löschen und einfügen
    Sleep(100) ; Längere Pause für die Einfüge-Operation
    ClipPut($sPrevClip) ; Zwischenablage wiederherstellen
    
    ; Mehrfache GUI-Aktualisierung erzwingen
    _WinAPI_UpdateWindow($g_hSQLRichEdit)
    _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
    
    ; Aktuellen Text prüfen
    Local $sActualText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    _LogInfo("_ForceSetSQLText: Tatsächlicher Text: '" & $sActualText & "'")
    
    ; Globale Variablen aktualisieren
    $g_sCurrentSQL = $sText
    $g_sLastSQLStatement = $sText
    
    ; Zu vorsichtig? Wenn der Text immer noch nicht stimmt, einen weiteren Versuch unternehmen
    If StringStripWS($sActualText, 8) <> StringStripWS($sText, 8) Then
        _LogError("_ForceSetSQLText: Text konnte nicht gesetzt werden, versuche es mit _SQL_SetInitialValue")
        Return _SQL_SetInitialValue()
    EndIf
    
    _LogInfo("_ForceSetSQLText: Text erfolgreich gesetzt")
    Return True
EndFunc

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
#include <WindowsConstants.au3>
#include <Misc.au3>

; Include Dateien für spezifische Komponenten
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung
#include "missing_functions.au3" ; Enthält Hilfsfunktionen
#include "sql_keywords.au3"      ; Zentrale Keyword-Definitionen
#include "sql_autocomplete_improved.au3" ; Verbesserte und optimierte Autovervollständigung
#include "sql_autocomplete_connector_improved.au3" ; Erweiterte Verbindung zur Datenbank-Metadaten
#include "filter_functions.au3" ; Filter-Funktionen für Zurücksetzen im SQL-Editor-Modus

; Allgemeine Konstanten
Global Const $SQL_EDITOR_HEIGHT = 240     ; Höhe des SQL-Editor-Bereichs
Global Const $SQL_HOTKEY_F5 = 1           ; Eindeutige ID für F5-Hotkey
Global Const $SQL_EDITOR_EN_CHANGE = 0x0300  ; Content of edit control changed
; $WM_SETTEXT ist bereits in WindowsConstants.au3 definiert (Wert: 0x000C)

; GUI-Positionen für Controls im SQL-Editor-Modus
Global $g_aSQLPanelPos[4]       ; X, Y, Breite, Höhe des SQL-Panels
Global $g_aSQLListViewPos[4]    ; X, Y, Breite, Höhe der ListView im SQL-Editor-Modus
Global $g_aNormalListViewPos[4] ; X, Y, Breite, Höhe der ListView im normalen Modus
Global $g_xCtrl, $g_yCtrl, $g_wCtrl  ; Globale Variablen für Control-Positionen

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
Global $g_sqlEditorTextBackup = ""    ; Backup für den SQL-Editor Text

; Sicherheits-Flags
Global $g_bUserInitiatedExecution = False  ; Wird nur bei tatsächlichem Klick auf Ausführen-Button gesetzt

; Datenbank-Variablen
Global $g_sCurrentDB = ""             ; Aktuelle Datenbank
Global $g_aTableColumns[0]            ; Array mit Spaltennamen

; ===============================================================================================================================
; Func.....: _SQL_SetInitialValue
; Beschreibung: Hilfsfunktion, die sicherstellt dass der SQL-Text im RichEdit-Control richtig angezeigt wird
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_SetInitialValue()
    ; Diese Hilfsfunktion stellt sicher, dass der SQL-Text im Editor richtig angezeigt wird
    ; durch direkte Manipulation des Controls
    
    Local $sText = "SELECT * FROM " & $g_sCurrentTable & " LIMIT 50;"
    _LogInfo("_SQL_SetInitialValue: Setze SQL-Text: " & $sText)
    
    If Not IsHWnd($g_hSQLRichEdit) Then 
        _LogError("_SQL_SetInitialValue: RichEdit-Control nicht gültig!")
        Return False
    EndIf
    
    ; Mehrere Methoden zum Setzen des Textes versuchen
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sText)
    
    ; Direkte Methode mit Control
    Local $hControl = GUICtrlGetHandle($g_hSQLRichEdit)
    GUICtrlSetData($hControl, $sText)
    
    ; Windows API Methode
    DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $g_hSQLRichEdit, "uint", $WM_SETTEXT, "wparam", 0, "wstr", $sText)
    
    ; Aktualisieren und neu zeichnen
    _WinAPI_UpdateWindow($g_hSQLRichEdit)
    _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW))
    
    ; Setze globale Variablen
    $g_sCurrentSQL = $sText
    $g_sLastSQLStatement = $sText
    
    ; Überprüfen, ob der Text gesetzt wurde
    Local $sActualText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
    _LogInfo("_SQL_SetInitialValue: Gesetzter Text: '" & $sActualText & "'")
    
    Return ($sActualText = $sText)
EndFunc

; ===============================================================================================================================
; Func.....: _ForceSetRichEditText
; Beschreibung: Erzwingt das Setzen eines Textes im RichEdit-Control mit mehreren Methoden
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
;             $sText - Zu setzender Text
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ForceSetRichEditText($hRichEdit, $sText)
    If Not IsHWnd($hRichEdit) Then
        _LogError("_ForceSetRichEditText: Ungültiges Handle")
        Return False
    EndIf
    
    _LogInfo("_ForceSetRichEditText: Setze Text mit mehreren Methoden")
    
    ; Backup des Textes erstellen
    $g_sqlEditorTextBackup = $sText
    
    ; Methode 1: Normale RichEdit-Funktion
    _GUICtrlRichEdit_SetText($hRichEdit, "")
    _GUICtrlRichEdit_SetText($hRichEdit, $sText)
    
    ; Methode 2: ControlSetText direkt
    ControlSetText($g_hGUI, "", $hRichEdit, $sText)
    
    ; Methode 3: SendMessage für WM_SETTEXT
    DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $hRichEdit, "uint", $WM_SETTEXT, "wparam", 0, "wstr", $sText)
    
    ; Methode 4: ControlSend um Text einzufügen
    ControlSend($g_hGUI, "", $hRichEdit, "^a{DEL}" & $sText)
    
    ; Prüfen, ob der Text gesetzt wurde
    Local $sActualText = _GUICtrlRichEdit_GetText($hRichEdit)
    If $sActualText <> $sText Then
        _LogError("_ForceSetRichEditText: Text wurde nicht korrekt gesetzt: '" & $sActualText & "' statt '" & $sText & "'")
        Return False
    EndIf
    
    _LogInfo("_ForceSetRichEditText: Text erfolgreich gesetzt")
    Return True
EndFunc

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
    
    ; Speichere GUI-Handle global
    $g_hGUI = $hGUI
    
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
    $g_xCtrl = $g_aSQLPanelPos[0] + $iMargin
    $g_yCtrl = $g_aSQLPanelPos[1] + 20 ; Berücksichtige Höhe der Gruppenüberschrift
    $g_wCtrl = $g_aSQLPanelPos[2] - 2 * $iMargin
    
    ; Buttons erstellen - Feste Positionierung mit absoluten Werten
    Local $yBtnPos = $g_aSQLPanelPos[1] + 22 ; Direkt nach der Gruppentitel-Überschrift
    
    ; Feste Positionierung für die Buttons
    $g_idSQLExecuteBtn = GUICtrlCreateButton("Ausführen (F5)", 10, $yBtnPos, 120, 25, $BS_DEFPUSHBUTTON)
    GUICtrlSetTip($g_idSQLExecuteBtn, "Führt die SQL-Abfrage aus (F5)", "Ausführen", 0, 1)
    
    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", 140, $yBtnPos, 90, 25)
    GUICtrlSetTip($g_idSQLSaveBtn, "Speichert die aktuelle SQL-Abfrage in einer Datei", "Speichern", 0, 1)
    
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", 240, $yBtnPos, 80, 25)
    GUICtrlSetTip($g_idSQLLoadBtn, "Lädt eine SQL-Abfrage aus einer Datei", "Laden", 0, 1)
    
    $g_idShowCompletionBtn = GUICtrlCreateButton("Vervollst.", 330, $yBtnPos, 90, 25)
    GUICtrlSetTip($g_idShowCompletionBtn, "Zeigt Autovervollständigung an (Strg+Leertaste)", "Autovervollständigung", 0, 1)
    
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $g_xCtrl + $g_wCtrl - 90, $yBtnPos, 80, 25)
    GUICtrlSetTip($g_idSQLBackBtn, "Zurück zur normalen Ansicht", "Zurück", 0, 1)
    
    ; RichEdit-Control für SQL-Eingabe - wichtig: Größe definieren!
    Local $yCtrl = $yBtnPos + 35 ; Mehr Abstand zu den Buttons
    Local $hRichEdit = _GUICtrlRichEdit_Create($hGUI, "", $g_xCtrl, $yCtrl, $g_wCtrl, 150, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    
    ; Speichere das Handle global
    $g_hSQLRichEdit = $hRichEdit
    
    ; Speichere den lokalen yCtrl-Wert in die globale Variable
    $g_yCtrl = $yCtrl
    
    ; Schriftart setzen
    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")
    
    ; Initialen Text setzen
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "-- Bitte wählen Sie eine Tabelle aus der Dropdown-Liste")
    
    ; Tooltip für das RichEdit-Control
    GUICtrlSetTip(GUICtrlGetHandle($g_hSQLRichEdit), "F5 = Ausführen, Strg+Leertaste = Autovervollständigung, Pfeiltasten & Enter/Tab/Esc = Navigation", "SQL-Editor Tastaturkürzel", 0, 1)
    
    ; Panel-Gruppe abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    
    ; Alle SQL-Editor-Elemente initial verstecken
    Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn]
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
        
        ; Hintergrund explizit löschen - wichtig zur Vermeidung von Artefakten
        Local $hDC = _WinAPI_GetDC($g_hGUI)
        Local $hBrush = _WinAPI_CreateSolidBrush(0xFFFFFF) ; Weißer Hintergrund
        Local $tRect = DllStructCreate("int Left;int Top;int Right;int Bottom")
        DllStructSetData($tRect, "Left", $g_aSQLPanelPos[0])
        DllStructSetData($tRect, "Top", $g_aSQLPanelPos[1])
        DllStructSetData($tRect, "Right", $g_aSQLPanelPos[0] + $g_aSQLPanelPos[2])
        DllStructSetData($tRect, "Bottom", $g_aSQLPanelPos[1] + $g_aSQLPanelPos[3])
        _WinAPI_FillRect($hDC, DllStructGetPtr($tRect), $hBrush)
        _WinAPI_ReleaseDC($g_hGUI, $hDC)
        _WinAPI_DeleteObject($hBrush)
        _WinAPI_UpdateWindow($g_hGUI)
        
        ; ListView-Position anpassen
        ControlMove($g_hGUI, "", $g_idListView, $g_aSQLListViewPos[0], $g_aSQLListViewPos[1], $g_aSQLListViewPos[2], $g_aSQLListViewPos[3])
        
        ; SQL-Panel und dessen Controls anzeigen
        Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn]
        For $idControl In $aControls
            GUICtrlSetState($idControl, $GUI_SHOW)
        Next
        
        ; RichEdit anzeigen - Komplettes Neuerstellen des Controls
        If IsHWnd($g_hSQLRichEdit) Then
            ; Altes Control löschen
            _GUICtrlRichEdit_Destroy($g_hSQLRichEdit)
            $g_hSQLRichEdit = 0
        EndIf
        
        ; Neues RichEdit-Control erstellen
        Local $hRichEdit = _GUICtrlRichEdit_Create($g_hGUI, "", $g_xCtrl, $g_yCtrl, $g_wCtrl, 150, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
        $g_hSQLRichEdit = $hRichEdit
        
        ; Schriftart setzen
        _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")
        
        ; Hintergrundfarbe explizit setzen - verhindert gelbe Artefakte
        _GUICtrlRichEdit_SetBkColor($g_hSQLRichEdit, 0xFFFFFF) ; Weißer Hintergrund
        
        ; Tooltip für das RichEdit-Control
        GUICtrlSetTip(GUICtrlGetHandle($g_hSQLRichEdit), "F5 = Ausführen, Strg+Leertaste = Autovervollständigung, Pfeiltasten & Enter/Tab/Esc = Navigation", "SQL-Editor Tastaturkürzel", 0, 1)
        
        ; Mehrfache Neuzeichnungen durchführen, um Artefakte komplett zu beseitigen
        _WinAPI_UpdateWindow($g_hSQLRichEdit)
        _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ERASE, $RDW_FRAME))
        _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
        
        ; SQL für aktuelle Tabelle vorbereiten
        _PrepareCurrentSQL()
        
        ; Sicherstellen, dass alle Controls die richtige Z-Order haben
        _SetSQLControlsZOrder()
        
        ; Timer für Syntax-Highlighting aktivieren
        AdlibRegister("_AdLibSyntaxHighlighting", 2000)
        
        ; F5-Taste für SQL-Ausführung registrieren
        HotKeySet("{F5}", "_ExecuteSQL_F5")
        
        ; Verbesserte Autovervollständigung initialisieren
        ; Zuerst die Metadaten aktualisieren, dann die Autovervollständigung initialisieren
        If $g_sCurrentDB <> "" And $g_sCurrentTable <> "" Then
            _SQL_UpdateAutoCompleteMetadata($g_sCurrentDB, $g_sCurrentTable)
        EndIf
        _InitSQLEditorAutocompleteFix()
        
        ; Status aktualisieren
        $g_bSQLEditorMode = True
    Else
        ; Wechsel in normalen Modus
        _LogInfo("Wechsle in normalen Modus")
        
        ; Button-Text zurücksetzen
        GUICtrlSetData($g_idBtnSQLEditor, "SQL-Editor")
        
        ; Aktuelle SQL und Tabelle speichern
        If IsHWnd($g_hSQLRichEdit) Then
            $g_sLastSQLStatement = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
        EndIf
        $g_sLastSQLTable = GUICtrlRead($g_idTableCombo)
        
        ; Autovervollständigung deaktivieren
        _StopSQLAutoComplete()
        
        ; SQL-Panel und dessen Controls verstecken
        Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn]
        For $idControl In $aControls
            GUICtrlSetState($idControl, $GUI_HIDE)
        Next
        
        ; RichEdit löschen - verhindert Artefakte nachhaltig
        If IsHWnd($g_hSQLRichEdit) Then
            _GUICtrlRichEdit_Destroy($g_hSQLRichEdit)
            $g_hSQLRichEdit = 0
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
        Local $sSQL = "SELECT * FROM " & $sCurrentTable & " LIMIT 50;"
        
        ; Wenn die letzte Tabelle dieselbe war, gespeichertes SQL verwenden
        If $g_sLastSQLTable = $sCurrentTable And $g_sLastSQLStatement <> "" Then
            $sSQL = $g_sLastSQLStatement
            _LogInfo("Verwende gespeichertes SQL-Statement")
        Else
            _LogInfo("Generiere neues SQL-Statement")
        EndIf
        
        ; Statement in Editor setzen - Beim neu erstellten RichEdit einfach
        If IsHWnd($g_hSQLRichEdit) Then 
            _LogInfo("Setze SQL-Text im neu erstellten RichEdit-Control")
            _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
            _GUICtrlRichEdit_SetBkColor($g_hSQLRichEdit, 0xFFFFFF) ; Weißer Hintergrund
            _WinAPI_UpdateWindow($g_hSQLRichEdit)
        Else
            _LogError("RichEdit-Control nicht gültig!")
        EndIf
        
        $g_sCurrentSQL = $sSQL
        
        ; Tabellen- und SQL-Referenzen speichern
        $g_sLastSQLTable = $sCurrentTable
        $g_sLastSQLStatement = $sSQL
        
        ; Spalten für Auto-Vervollständigung laden
        If IsDeclared("g_aTableColumns") Then
            _LogInfo("Lade Spalten für Autovervollständigung")
            ; Verwende den SQL-Autocomplete-Connector
            _SQL_UpdateAutoCompleteMetadata($g_sCurrentDB, $sCurrentTable)
            _LogInfo("Metadaten für Autovervollständigung aktualisiert")
        EndIf
        
        ; Syntax-Highlighting initial durchführen
        _SQL_UpdateSyntaxHighlighting()
        
        ; Mit wenig Verzögerung das SQL-Statement ausführen, um die Tabellendaten anzuzeigen
        $g_bUserInitiatedExecution = True
        _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
        $g_bUserInitiatedExecution = False
        
        ; Statusmeldung mit Tastaturkombinationen anzeigen
        _SetStatus("SQL-Editor: [F5] = Ausführen, [Strg+Leertaste] = Autovervollst., [Tab/Enter] = Auswahl bestätigen")
    Else
        ; Keine Tabelle ausgewählt - leeres SQL
        Local $sSQL = "-- Bitte wählen Sie eine Tabelle aus der Dropdown-Liste"
        If IsHWnd($g_hSQLRichEdit) Then
            _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
            _GUICtrlRichEdit_SetBkColor($g_hSQLRichEdit, 0xFFFFFF) ; Weißer Hintergrund
        EndIf
        $g_sCurrentSQL = $sSQL
    EndIf
    
    ; Fokus auf SQL-Editor setzen und nochmals neu zeichnen
    If IsHWnd($g_hSQLRichEdit) Then
        _WinAPI_SetFocus($g_hSQLRichEdit)
        _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ERASE, $RDW_FRAME))
    EndIf
    
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
                Local $sSQL = "SELECT * FROM " & $sTable & " LIMIT 50;"
                
                ; Tabelle und Text im Editor setzen
                $g_sCurrentTable = $sTable
                
                ; SQL-Statement garantiert ausführen (wichtiger Fix)
                $g_bUserInitiatedExecution = True
                If Not IsHWnd($g_hSQLRichEdit) Then
                    ; RichEdit neu erstellen, falls nötig
                    Local $hRichEdit = _GUICtrlRichEdit_Create($g_hGUI, $sSQL, $g_xCtrl, $g_yCtrl, $g_wCtrl, 150, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
                    $g_hSQLRichEdit = $hRichEdit
                    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")
                Else
                    ; Text direkt mit verschiedenen Methoden setzen
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "")
                    Sleep(50)
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                    _GUICtrlRichEdit_SetBkColor($g_hSQLRichEdit, 0xFFFFFF)
                    _WinAPI_InvalidateRect($g_hSQLRichEdit, 0, True)
                    _WinAPI_UpdateWindow($g_hSQLRichEdit)
                EndIf
                
                ; Globale Variablen aktualisieren
                $g_sCurrentSQL = $sSQL
                $g_sLastSQLStatement = $sSQL
                $g_sLastSQLTable = $g_sCurrentTable
                
                ; SQL-Statement garantiert ausführen
                _SQL_ExecuteQuery($sSQL, $g_sCurrentDB)
                $g_bUserInitiatedExecution = False
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
            ; Aktiviere Autovervollständigung manuell
            _ShowSQLCompletionListFix()
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
                            
                            ; Spalten für Autovervollständigung laden
                            _SQL_UpdateAutoCompleteMetadata($g_sCurrentDB, $sTableFromSQL)
                        EndIf
                    EndIf
                EndIf
            EndIf
            Return True
            
        Case $idBtnRefresh
            ; Aktualisierung im SQL-Editor-Modus verbessert
            _LogInfo("Refresh-Button im SQL-Editor gedrückt - Setze Filter zurück und aktualisiere Daten")
            
            ; Filter zurücksetzen, falls aktiv
            If IsDeclared("g_bFilterActive") And $g_bFilterActive Then
                _LogInfo("SQL-Editor: Filter wird zurückgesetzt")
                _ResetListViewFilter()
                _SetStatus("Filter zurückgesetzt: Alle Einträge werden angezeigt.")
            EndIf
            
            ; Aktuelles SQL ausführen, wenn vom Benutzer initiiert
            If _GUICtrlRichEdit_GetText($g_hSQLRichEdit) <> "" Then
                $g_bUserInitiatedExecution = True
                _SQL_ExecuteQuery(_GUICtrlRichEdit_GetText($g_hSQLRichEdit), $g_sCurrentDB)
                $g_bUserInitiatedExecution = False
            EndIf
            
            ; Stellt sicher, dass die Autovervollständigungsliste versteckt wird
            If $g_hList <> 0 And IsHWnd($g_hList) Then
                _StopSQLAutoComplete()
                Sleep(100)
                _InitSQLEditorAutocompleteFix()
            EndIf
            
            ; GUI-Elemente neu zeichnen
            _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
            
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
        
        ; Auf Doppelklick oder Auswahl-Ereignis in Autovervollständigungsliste prüfen
        If $g_hList <> 0 And $hWnd = $g_hGUI Then
            ; Verarbeite Autovervollständigungs-Events
            _HandleSQLAutoCompleteEvent($lowword)
        EndIf
    EndIf
    
    $bProcessing = False
    Return $GUI_RUNDEFMSG
EndFunc