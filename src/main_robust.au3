#RequireAdmin

; Globale Konfigurationseinstellungen
Global Const $g_sSettingsFile = @ScriptDir & "\settings.ini"
Global Const $g_sqliteDLL = @ScriptDir & "\Lib\sqlite3.dll"

#include-once
#include <ListViewConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <GUIConstantsEx.au3>
#include <GUIConstants.au3>

#include <Array.au3>
#include <File.au3>
#include <SQLite.au3>
#include <GuiListView.au3>
#include <WinAPI.au3>
#include <Debug.au3>
#include <StringConstants.au3>

; Eigene Include-Dateien
#include "lib/constants.au3"  ; Wichtig: Konstanten zuerst includen
#include "lib/globals.au3"    ; Global Variablen direkt danach
#include "lib/system_functions.au3"
#include "lib/utils.au3"      ; Allgemeine Hilfsfunktionen
#include "lib/zip_handler.au3"
#include "lib/zip_functions.au3"
#include "lib/sqlite_handler.au3"
#include "lib/settings_manager.au3"
#include "lib/logging.au3"
#include "lib/error_handler.au3"
#include "lib/db_functions.au3"
#include "lib/db_direct.au3"
#include "lib/missing_functions.au3"  ; Wichtig: Diese Datei enthält alle fehlenden Funktionen
#include "lib/gui_functions.au3"
#include "lib/export_functions.au3"
;~ #include "lib/decrypt_functions.au3"
#include "lib/listview_copy.au3"
#include "lib/JSON.au3"
#include "lib/log_handler.au3"
#include "lib/debug_utils.au3"  ; Debug-Funktionen
#include "lib/log_parser.au3"  ; Gemeinsame Log-Funktionen
#include "lib/log_analysis_utils.au3"
#include "lib/log_viewer.au3"  ; Verwende den normalen Log-Viewer
#include "lib/log_functions.au3"
#include "lib/bulk_log_opener_robust.au3"  ; Robuste Logordner-Verarbeitung
#include "lib/archive_log_opener.au3"
#include "lib/parsers/parser_manager_enhanced.au3"  ; Verbesserter Parser-Manager
#include "lib/filter_functions.au3"
#include "lib/sql_editor_utils.au3"  ; SQL-Editor Hilfsfunktionen
#include "lib/sql_editor_enhanced.au3"  ; Persistenter SQL-Editor

; Windows API Konstanten für die Fenstergrößenänderungen
Global Const $SIZE_RESTORED = 0     ; Fenster wurde wiederhergestellt
Global Const $SIZE_MINIMIZED = 1    ; Fenster wurde minimiert
Global Const $SIZE_MAXIMIZED = 2    ; Fenster wurde maximiert
Global Const $SIZE_MAXSHOW = 3      ; Fenster wird maximiert angezeigt
Global Const $SIZE_MAXHIDE = 4      ; Fenster wird maximiert versteckt

; Hauptprogramm mit EventLoop
Func _CreateMainGUI()
    ; Globale Variable für ListView-Styles
    $iExListViewStyle = BitOR( _
                            $LVS_EX_BORDERSELECT, _
                            $LVS_EX_ONECLICKACTIVATE, _
                            $LVS_EX_TRACKSELECT, _
                            $LVS_EX_DOUBLEBUFFER, _
                            $LVS_EX_TWOCLICKACTIVATE, _
                            $LVS_EX_SUBITEMIMAGES, _
                            $LVS_EX_GRIDLINES, _
                            $LVS_EX_INFOTIP, _
                            $LVS_EX_FULLROWSELECT, _
                            $LVS_EX_LABELTIP, _
                            $LVS_EX_FLATSB, _
                            $LVS_AUTOARRANGE _
                          )

    ; Breiteres Hauptfenster für bessere Anordnung der Buttons
    ; Hinzugefügt: $WS_CLIPCHILDREN Style, um Zeichenprobleme zu reduzieren
    $g_hGUI = GUICreate("Diagnose Tool (Robuste Logdatei-Unterstützung)", 1200, 700, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_CLIPCHILDREN))

    ; Menü erstellen
    Local $idFile = GUICtrlCreateMenu("&Datei")
    $idFileOpen = GUICtrlCreateMenuItem("ZIP öffnen...", $idFile)
    $idFileDBOpen = GUICtrlCreateMenuItem("Datenbank öffnen...", $idFile)
    $idFileLogOpen = GUICtrlCreateMenuItem("Logdatei öffnen...", $idFile)
    $idFileLogFolder = GUICtrlCreateMenuItem("Logdateien aus Ordner öffnen...", $idFile)
    GUICtrlCreateMenuItem("", $idFile) ; Separator
    $idFileViewArchive = GUICtrlCreateMenuItem("Logs im aktuellen Archiv...", $idFile)
    $idFileOpenExtrDir = GUICtrlCreateMenuItem("Extraktionsverzeichnis öffnen", $idFile)
    GUICtrlCreateMenuItem("", $idFile) ; Separator
    $idSettings = GUICtrlCreateMenuItem("Einstellungen...", $idFile)
    GUICtrlCreateMenuItem("", $idFile) ; Separator
    $idFileExit = GUICtrlCreateMenuItem("Beenden", $idFile)

    Local $idView = GUICtrlCreateMenu("&Ansicht")
    $idBtnRefresh = GUICtrlCreateMenuItem("Aktualisieren", $idView)
    $idBtnFilter = GUICtrlCreateMenuItem("Filter...", $idView)

    Local $idTools = GUICtrlCreateMenu("&Werkzeuge")
    $idToolSQLEditor = GUICtrlCreateMenuItem("SQL-Editor", $idTools)
    $idToolLogTester = GUICtrlCreateMenuItem("JSON-Parser Tester", $idTools)  ; Parser-Tester aktiviert

    ; Toolbar mit gleichmäßigen Abständen zwischen den Buttons
    Local $idToolbar = GUICtrlCreateGroup("", 2, 2, 1196, 45)
    $idBtnOpen = GUICtrlCreateButton("ZIP öffnen", 10, 15, 85, 25)
    $idBtnDBOpen = GUICtrlCreateButton("DB öffnen", 100, 15, 85, 25)
    $idBtnLogOpen = GUICtrlCreateButton("Log öffnen", 190, 15, 85, 25)
    $idBtnLogFolder = GUICtrlCreateButton("Log-Ordner", 280, 15, 85, 25)
    $idBtnViewArchive = GUICtrlCreateButton("Archiv-Logs", 370, 15, 85, 25)
    $idBtnOpenExtrDir = GUICtrlCreateButton("Extr.-Verz.", 460, 15, 85, 25)
    $idBtnExport = GUICtrlCreateButton("Exportieren", 550, 15, 85, 25)
    GUICtrlSetState($idBtnExport, $GUI_DISABLE)

    ; Tabellen-Auswahl
    GUICtrlCreateLabel("Tabelle:", 645, 20, 50, 20)
    $idTableCombo = GUICtrlCreateCombo("", 700, 15, 200, 25)
    GUICtrlSetState($idTableCombo, $GUI_DISABLE)

    $idBtnRefresh = GUICtrlCreateButton("Aktual.", 910, 15, 85, 25)
    GUICtrlSetState($idBtnRefresh, $GUI_DISABLE)

    $idBtnFilter = GUICtrlCreateButton("Filter", 1000, 15, 85, 25)
    GUICtrlSetState($idBtnFilter, $GUI_DISABLE)

    $idBtnSQLEditor = GUICtrlCreateButton("SQL-Editor", 1090, 15, 85, 25)
    GUICtrlSetState($idBtnSQLEditor, $GUI_DISABLE) ; Erst aktivieren, wenn eine Datenbank geladen ist

    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Extraktionsverzeichnis-Button initial deaktivieren
    GUICtrlSetState($idBtnViewArchive, $GUI_DISABLE)
    GUICtrlSetState($idBtnOpenExtrDir, $GUI_DISABLE)
    GUICtrlSetState($idFileViewArchive, $GUI_DISABLE)
    GUICtrlSetState($idFileOpenExtrDir, $GUI_DISABLE)

    ; ListView Notifications handeln
    ConsoleWrite(GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY") & @CRLF)

    ; ListView für Daten erstellen
    $g_idListView = GUICtrlCreateListView("", 2, 50, 1196, 600)
    ; Explizit sichtbar setzen (wichtig für SQL-Editor)
    GUICtrlSetState($g_idListView, $GUI_SHOW)
    Local $hListView = GUICtrlGetHandle($g_idListView)

    ; Erweiterte Styles setzen
    _GUICtrlListView_SetExtendedListViewStyle($hListView, $iExListViewStyle)

    ; Z-Order der ListView korrigieren, damit keine Überlagerung stattfindet
    _WinAPI_SetWindowPos($hListView, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))

    ; Kontextmenü für ListView
    $g_idContextMenu = GUICtrlCreateContextMenu($g_idListView)
    $g_idCopyCell = GUICtrlCreateMenuItem("Zelle kopieren", $g_idContextMenu)
    $g_idCopyRow = GUICtrlCreateMenuItem("Zeile kopieren", $g_idContextMenu)
    $g_idCopySelection = GUICtrlCreateMenuItem("Auswahl kopieren", $g_idContextMenu)
    $g_idCopyWithHeaders = GUICtrlCreateMenuItem("Mit Überschriften kopieren", $g_idContextMenu)
    GUICtrlCreateMenuItem("", $g_idContextMenu) ; Separator
    $g_idDecryptPassword = GUICtrlCreateMenuItem("Passwort entschlüsseln", $g_idContextMenu)
    _DeleteAllListViewColumns($g_idListView)

    ; Fortschrittsanzeige
    $g_idProgress = GUICtrlCreateProgress(2, 655, 1196, 20)
    GUICtrlSetState($g_idProgress, $GUI_HIDE)

    ; Statusbar
    $g_idStatus = GUICtrlCreateLabel("Bereit.", 2, 680, 1196, 20)

    GUISetState(@SW_SHOW, $g_hGUI)

    ; Integrierter SQL-Editor initialisieren
    ; Parameter: Hauptfenster-Handle, ListView-ID, x, y, Breite des Editor-Panels
    _InitPersistentSQLEditor($g_hGUI, $g_idListView, 2, 50, 1196)
    
    ; Registriere Events für Fensteraktivierung und Größenveränderung (wichtig für die GUI)
    GUIRegisterMsg($WM_ACTIVATEAPP, "WM_ACTIVATEAPP")
    GUIRegisterMsg($WM_SIZE, "WM_SIZE")
    GUIRegisterMsg($WM_WINDOWPOSCHANGED, "WM_WINDOWPOSCHANGED")

    Return True
EndFunc

Func WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    Static $bProcessing = False  ; Verhindert Rekursion

    ; Rekursion vermeiden
    If $bProcessing Then Return $GUI_RUNDEFMSG
    $bProcessing = True

    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    Local $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
    Local $iCode = DllStructGetData($tNMHDR, "Code")

    ; Auto-Vervollständigungsliste-Ereignisse (SQL-Editor)
    If $g_bSQLEditorMode And $g_hList <> 0 And $hWndFrom = $g_hList Then
        Switch $iCode
            Case $LBN_DBLCLK, $LBN_SELCHANGE  ; Doppelklick oder Auswahl geändert
                _AcceptSQLAutoCompleteSelection()
        EndSwitch
    EndIf

    ; ListView-Ereignisse verarbeiten
    Switch $hWndFrom
        Case GUICtrlGetHandle($g_idListView)
            Switch $iCode
                Case $NM_DBLCLK
                    ; Position des Doppelklicks ermitteln
                    Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $lParam)
                    Local $iRow = DllStructGetData($tInfo, "Index")
                    Local $iCol = DllStructGetData($tInfo, "SubItem")
                    Local $ListViewSubitemText = _GUICtrlListView_GetItem(GUICtrlGetHandle($g_idListView), $iRow, $iCol)

                    ; Inhalt der Zelle lesen
                    IF IsArray($ListViewSubitemText) Then
                        IF $ListViewSubitemText[3] <> "" Then
                            ConsoleWrite( $ListViewSubitemText[3] & @CRLF)
                            ClipPut($ListViewSubitemText[3])
                        EndIf
                    EndIf
            EndSwitch
    EndSwitch

    $bProcessing = False
    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: WM_ACTIVATEAPP
; Beschreibung: Event-Handler für Fensteraktivierung (wird aufgerufen, wenn das Hauptfenster aktiviert wird)
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func WM_ACTIVATEAPP($hWnd, $iMsg, $wParam, $lParam)
    ; $wParam = 1 bedeutet, dass das Fenster aktiviert wurde
    ; $wParam = 0 bedeutet, dass das Fenster deaktiviert wurde
    
    If $wParam = 1 Then ; Fenster wurde aktiviert
        _LogInfo("Hauptfenster aktiviert")
        
        ; Wenn SQL-Editor-Modus aktiv ist, Autovervollständigung neu initialisieren
        If $g_bSQLEditorMode Then
            _LogInfo("SQL-Editor-Modus aktiv, initialisiere Autovervollständigung neu")
            
            ; Sicherstellen, dass der SQL-Editor korrekt angezeigt wird
            If IsHWnd($g_hSQLRichEdit) Then
                ; RichEdit anzeigen und aktualisieren
                _WinAPI_ShowWindow($g_hSQLRichEdit, @SW_SHOW)
                _WinAPI_UpdateWindow($g_hSQLRichEdit)
                _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
                
                ; Neu-Initialisierung der Autovervollständigung
                If IsDeclared("_StopSQLAutoComplete") And IsDeclared("_InitSQLEditorAutocompleteFix") Then
                    ; Bestehende Autovervollständigung beenden
                    _StopSQLAutoComplete()
                    Sleep(100) ; Kurze Pause
                    
                    ; Autovervollständigung neu starten
                    _InitSQLEditorAutocompleteFix()
                    
                    ; Z-Order korrigieren
                    _SetSQLControlsZOrder()
                    
                    _LogInfo("Autovervollständigung erfolgreich neu initialisiert")
                EndIf
            EndIf
        EndIf
    EndIf
    
    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: WM_SIZE
; Beschreibung: Event-Handler für Größenveränderungen des Hauptfensters
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
    ; Nur für das Hauptfenster
    If $hWnd <> $g_hGUI Then Return $GUI_RUNDEFMSG
    
    ; Fenster wurde minimiert oder wiederhergestellt
    If $wParam = $SIZE_MINIMIZED Then
        _LogInfo("Hauptfenster minimiert")
    ElseIf $wParam = $SIZE_RESTORED Then
        _LogInfo("Hauptfenster wiederhergestellt")
        
        ; Wenn SQL-Editor-Modus aktiv, Controls neu anordnen und anzeigen
        If $g_bSQLEditorMode Then
            _LogInfo("SQL-Editor-Modus aktiv, aktualisiere GUI-Elemente")
            
            ; Kurze Pause zum Neuzeichnen der GUI-Elemente
            Sleep(100)
            
            ; Controls neu anzeigen
            If IsHWnd($g_hSQLRichEdit) Then
                _WinAPI_ShowWindow($g_hSQLRichEdit, @SW_SHOW)
                _WinAPI_UpdateWindow($g_hSQLRichEdit)
                _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
                
                ; Setze den Fokus zum RichEdit
                _WinAPI_SetFocus($g_hSQLRichEdit)
            EndIf
        EndIf
    EndIf
    
    Return $GUI_RUNDEFMSG
EndFunc

; ===============================================================================================================================
; Func.....: WM_WINDOWPOSCHANGED
; Beschreibung: Event-Handler für Änderungen der Fensterposition (wird bei Wiederherstellen aufgerufen)
; Parameter.: $hWnd, $iMsg, $wParam, $lParam - Standard-Windows-Parameter
; Rückgabe..: $GUI_RUNDEFMSG
; ===============================================================================================================================
Func WM_WINDOWPOSCHANGED($hWnd, $iMsg, $wParam, $lParam)
    ; Nur für das Hauptfenster
    If $hWnd <> $g_hGUI Then Return $GUI_RUNDEFMSG
    
    ; Statische Variable, um unnötige Updates zu vermeiden
    Static $iLastUpdateTime = 0
    
    ; Nur alle 500ms aktualisieren, um Performance-Probleme zu vermeiden
    If TimerDiff($iLastUpdateTime) < 500 Then Return $GUI_RUNDEFMSG
    $iLastUpdateTime = TimerInit()
    
    ; Wenn SQL-Editor-Modus aktiv, Controls neu anordnen und anzeigen
    If $g_bSQLEditorMode Then
        _LogInfo("Fensterposition geändert, aktualisiere SQL-Editor-Elemente")
        
        ; SQL-Panel und dessen Controls aktualisieren
        Local $aControls = [$g_idSQLEditorPanel, $g_idSQLExecuteBtn, $g_idSQLSaveBtn, $g_idSQLLoadBtn, $g_idSQLBackBtn, $g_idShowCompletionBtn]
        For $idControl In $aControls
            If $idControl <> 0 Then
                GUICtrlSetState($idControl, $GUI_SHOW)
            EndIf
        Next
        
        ; RichEdit aktualisieren
        If IsHWnd($g_hSQLRichEdit) Then
            _WinAPI_ShowWindow($g_hSQLRichEdit, @SW_SHOW)
            _WinAPI_UpdateWindow($g_hSQLRichEdit)
            _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
            
            ; Z-Order korrigieren
            _SetSQLControlsZOrder()
        EndIf
    EndIf
    
    Return $GUI_RUNDEFMSG
EndFunc

; Hauptprogramm
Func Main()
    _DebugSetup("Diagnose Tool Debug", True)
    ; Debug-Funktionen initialisieren
    _DebugInit($DEBUG_INFO, True, True, @ScriptDir & "\debug.log")
    _DebugInfo("Programm gestartet")

    If Not _InitSystem() Then Exit

    _LogInfo("Programm gestartet - Version " & FileGetVersion(@ScriptFullPath))
    _CreateMainGUI()

    While 1
        Local $iMsg = GUIGetMsg()

        ; Prüfen, ob der SQL-Editor-Modus aktiv ist, und wenn ja, rufe den speziellen Handler auf
        If $g_bSQLEditorMode Then
            ; Wenn dieser Handler True zurückgibt, wurde das Event verarbeitet - Weitermachen mit nächstem Event
            If _HandleSQLEditorEvents($iMsg) Then
                ContinueLoop
            EndIf
        EndIf

        ; Normale Programmevents verarbeiten
        Switch $iMsg
            Case $GUI_EVENT_CLOSE, $idFileExit
                ; Bei aktivem SQL-Editor-Modus zurück zum normalen Modus wechseln
                If $g_bSQLEditorMode Then
                    _TogglePersistentSQLEditor(False)
                EndIf
                ExitLoop

            Case $idFileOpen, $idBtnOpen
                ; Extraktionsverzeichnis als Startverzeichnis verwenden, falls verfügbar
                Local $sStartDir = $g_sExtractDir <> "" ? $g_sExtractDir : $g_sLastDir
                Local $sFile = FileOpenDialog("ZIP-Datei öffnen", $sStartDir, "ZIP-Dateien (*.zip)", $FD_FILEMUSTEXIST)
                If Not @error Then
                    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))

                    ; ZIP-Datei verarbeiten
                    If _ProcessZipFile($sFile) Then
                        ; Aktiviere Archiv-bezogene Menüpunkte und Buttons
                        GUICtrlSetState($idBtnViewArchive, $GUI_ENABLE)
                        GUICtrlSetState($idBtnOpenExtrDir, $GUI_ENABLE)
                        GUICtrlSetState($idFileViewArchive, $GUI_ENABLE)
                        GUICtrlSetState($idFileOpenExtrDir, $GUI_ENABLE)
                    EndIf
                EndIf

            Case $idFileDBOpen, $idBtnDBOpen
                ; Extraktionsverzeichnis als Startverzeichnis verwenden, falls verfügbar
                Local $sStartDir = $g_sExtractDir <> "" ? $g_sExtractDir : $g_sLastDir
                Local $sFile = FileOpenDialog("Datenbank öffnen", $sStartDir, "SQLite Datenbanken (*.db;*.db3)", $FD_FILEMUSTEXIST)
                If Not @error Then
                    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))
                    _OpenDatabaseFile($sFile)
                EndIf

            Case $idFileLogOpen, $idBtnLogOpen
                ; Extraktionsverzeichnis als Startverzeichnis verwenden, falls verfügbar
                Local $sStartDir = $g_sExtractDir <> "" ? $g_sExtractDir : $g_sLastDir
                Local $sFile = FileOpenDialog("Logdatei öffnen", $sStartDir, "Logdateien (*.log;*.txt)|Alle Dateien (*.*)", $FD_FILEMUSTEXIST)
                If Not @error Then
                    $g_sLastDir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1))
                    ; Robuste Log-Öffnung verwenden
                    _OpenLogFileRobust($sFile)
                EndIf

            Case $idFileLogFolder, $idBtnLogFolder
                ; Robuste Version zum Öffnen von Logdateien aus einem Ordner
                _OpenLogFolderRobust()

            Case $idFileViewArchive, $idBtnViewArchive
                ; Extraktionsverzeichnis setzen und Logs öffnen
                If $g_sExtractDir <> "" Then
                    _SetArchiveExtractDirectory($g_sExtractDir)
                    ; Robuste Version verwenden
                    _OpenCurrentArchiveLogsRobust()
                Else
                    MsgBox($MB_ICONINFORMATION, "Hinweis", "Es wurde noch kein ZIP-Archiv extrahiert.")
                EndIf

            Case $idFileOpenExtrDir, $idBtnOpenExtrDir
                _OpenExtractDirectory()

            Case $idToolSQLEditor, $idBtnSQLEditor
                ; Umschalten zwischen normalem Modus und SQL-Editor-Modus
                _LogInfo("SQL-Editor Button MANUELL gedrückt")
                _TogglePersistentSQLEditor(Not $g_bSQLEditorMode)

            Case $idToolLogTester
                ; Verbesserten JSON-Parser mit unvollständigen Einträgen testen
                _TestIncompleteJsonParser()

            Case $idTableCombo
                If Not $g_bIsLoading Then
                    $g_sCurrentTable = GUICtrlRead($idTableCombo)
                    _LogInfo("Tabelle in ComboBox ausgewählt: " & $g_sCurrentTable)

                    ; ListView mit der ausgewählten Tabelle befüllen
                    _LoadDatabaseData()

                    ; Nach dem Laden Buttons aktivieren
                    GUICtrlSetState($idBtnFilter, $GUI_ENABLE)
                    GUICtrlSetState($idBtnExport, $GUI_ENABLE)

                    ; Wenn SQL-Editor aktiv ist, automatisch Statement generieren
                    If $g_bSQLEditorMode And $g_sCurrentTable <> "" Then
                        _LogInfo("Generiere SQL-Statement für ausgewählte Tabelle: " & $g_sCurrentTable)
                        Local $sSQL = "SELECT * FROM " & $g_sCurrentTable & " LIMIT 50;"

                        ; Statement in Editor setzen - zuverlässige Methode verwenden
                        If IsHWnd($g_hSQLRichEdit) Then
                            ; Die verbesserte Funktion zum Setzen des Textes verwenden
                            _ForceSetSQLText($sSQL)
                            
                            ; Globale Variablen aktualisieren
                            $g_sCurrentSQL = $sSQL
                            $g_sLastSQLStatement = $sSQL
                            $g_sLastSQLTable = $g_sCurrentTable

                            ; Syntax-Highlighting aktualisieren
                            _SQL_UpdateSyntaxHighlighting()
                        EndIf
                    EndIf
                EndIf

            Case $idBtnRefresh
                If Not $g_bIsLoading Then
                    ; Wenn im SQL-Editor-Modus, nichts tun - der SQL-Editor hat seinen eigenen Event-Handler
                    If Not $g_bSQLEditorMode Then
                        ; Existierenden Filter zurücksetzen (direkt und explizit)
                        If IsDeclared("g_bFilterActive") And $g_bFilterActive Then
                            _ResetListViewFilter()
                            GUICtrlSetData($g_idStatus, "Filter zurückgesetzt: Alle Einträge werden angezeigt.")
                        EndIf
                        
                        ; Daten neu laden
                        _LoadDatabaseData()
                    EndIf
                EndIf

            Case $idBtnFilter
                If Not $g_bIsLoading Then
                    _DBViewerShowFilter()
                EndIf

            Case $idBtnExport
                If Not $g_bIsLoading Then
                    _DBViewerShowExport()
                EndIf

            Case $idSettings
                _Settings_ShowDialog()

            Case $g_idCopyCell
                Local $aPos = MouseGetPos()
                Local $aInfo = _GUICtrlListView_HitTest($g_idListView, $aPos[0], $aPos[1])

                If IsArray($aInfo) Then
                    Local $iRow = $aInfo[0]
                    Local $iCol = $aInfo[1]
                    If $aInfo[0] <> -1 Then
                        Local $sText = _GUICtrlListView_GetItem($g_idListView, $iRow, $iCol)
                        If IsArray($sText) Then
                            _LogInfo("Kopiere Zellinhalt: " & $sText[3])
                            ClipPut($sText[3])
                        EndIf
                    EndIf
                EndIf

            Case $g_idCopyRow
                Local $aPos = MouseGetPos()
                Local $aInfo = _GUICtrlListView_HitTest($g_idListView, $aPos[0], $aPos[1])

                If IsArray($aInfo) Then
                    Local $iRow = $aInfo[0]
                    If $aInfo[0] <> -1 Then
                        Local $sRow = ""
                        For $i = 0 To _GUICtrlListView_GetColumnCount($g_idListView) - 1
                            If $sRow <> "" Then $sRow &= ";"
                            Local $sText = _GUICtrlListView_GetItem($g_idListView, $iRow, $i)
                            If IsArray($sText) Then
                                $sRow &= $sText[3]
                            EndIf
                        Next
                        _LogInfo("Kopiere Zeile: " & $sRow)
                        ClipPut($sRow)
                    EndIf
                EndIf

            Case $g_idCopySelection
                Local $aSelected = _GUICtrlListView_GetSelectedIndices($g_idListView, True)
                If IsArray($aSelected) And $aSelected[0] > 0 Then
                    Local $sSelection = ""
                    For $i = 1 To $aSelected[0]
                        If $sSelection <> "" Then $sSelection &= @CRLF
                        Local $iRow = $aSelected[$i]
                        For $j = 0 To _GUICtrlListView_GetColumnCount($g_idListView) - 1
                            If $j > 0 Then $sSelection &= ";"
                            Local $sText = _GUICtrlListView_GetItem($g_idListView, $iRow, $j)
                            If IsArray($sText) Then
                                $sSelection &= $sText[3]
                            EndIf
                        Next
                    Next
                    _LogInfo("Kopiere Auswahl: " & $sSelection)
                    ClipPut($sSelection)
                EndIf

            Case $g_idCopyWithHeaders
                Local $aSelected = _GUICtrlListView_GetSelectedIndices($g_idListView, True)
                If IsArray($aSelected) And $aSelected[0] > 0 Then
                    Local $sText = ""
                    ; Kopfzeile
                    For $i = 0 To _GUICtrlListView_GetColumnCount($g_idListView) - 1
                        If $i > 0 Then $sText &= ";"
                        Local $aCol = _GUICtrlListView_GetColumn($g_idListView, $i)
                        $sText &= $aCol[5]  ; Spaltenname
                    Next
                    $sText &= @CRLF

                    ; Daten
                    For $i = 1 To $aSelected[0]
                        Local $iRow = $aSelected[$i]
                        For $j = 0 To _GUICtrlListView_GetColumnCount($g_idListView) - 1
                            If $j > 0 Then $sText &= ";"
                            Local $sTexta = _GUICtrlListView_GetItem($g_idListView, $iRow, $j)
                            If IsArray($sTexta) Then
                                $sText &= $sTexta[3]
                            EndIf
                        Next
                        $sText &= @CRLF
                    Next
                    _LogInfo("Kopiere mit Überschriften: " & $sText)
                    ClipPut($sText)
                EndIf
        EndSwitch
    WEnd

    _Cleanup()
EndFunc

Main()