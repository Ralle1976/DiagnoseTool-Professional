#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstants.au3>
#include <TreeViewConstants.au3>

#include <GuiListView.au3>
#include <GuiTreeView.au3>
#include <Date.au3>
#include <WinAPIGdi.au3>
;~ #include <CommCtrl.au3> ; Für ListView CustomDraw-Konstanten
#include "logging.au3"
#include "gui_functions.au3"
#include "log_handler.au3"
;~ #include "log_level_colors.au3"  ; Include-Datei für Log-Level-Farben und TRUNCATED-Einträge
;~ #include "log_color_configurator_enhanced.au3"  ; Include-Datei für erweiterten Farbkonfigurator
#include "log_color_configurator_gdiplus_fixed.au3"
#include "log_viewer_functions.au3"  ; Include-Datei mit allen Funktionen


; Globale Variablen für den Log-Viewer
Global $g_hLogViewerGUI
Global $g_idLogFileTree
Global $g_idLogLevelCombo
Global $g_idLogClassCombo
Global $g_idSearchEdit
Global $g_idSearchButton
Global $g_idRegexCheck
Global $g_idLogListView
Global $g_idLogStats
Global $g_idCloseButton
Global $g_idExportButton
Global $g_idToggleViewButton
Global $g_idColorConfigButton  ; Button für Log-Level-Farben-Konfiguration
Global $g_aCurrentLogFiles
Global $g_aCurrentLogEntries
Global $g_sCurrentLogFile = ""
Global $g_hTreeViewHandle ; Handle zum TreeView-Control (wichtig für WM_NOTIFY)
Global $g_idStatus ; Status-Label für Feedback

; Speicherung des ursprünglichen WM_NOTIFY-Handlers
Global $g_fnOriginalWM_NOTIFY = "_LogViewer_WM_NOTIFY_Handler"

; Konstanten für Tooltips
Global Const $LVN_GETINFOTIP = -58
Global $tagNMLVGETINFOTIP_LogViewer = "struct;hwnd hWndFrom;uint_ptr IDFrom;int Code;" & _
                                "dword dwFlags;int iItem;int iSubItem;" & _
                                "ptr pszText;int cchTextMax;endstruct"

; Hauptfunktion zum Anzeigen des Log-Viewers
Func _ShowLogViewer($aLogFiles)
    ConsoleWrite("DEBUG: _ShowLogViewer gestartet, Array-Größe: " & UBound($aLogFiles) & @CRLF)
    If UBound($aLogFiles) > 1 Then
        ConsoleWrite("DEBUG: Datei: " & $aLogFiles[1] & @CRLF)
    EndIf
    
    ; Log-Farben initialisieren
    _InitLogLevelColors($g_sSettingsIniPath)

    ; Log-Viewer GUI erstellen
    $g_hLogViewerGUI = GUICreate("Log-Datei Viewer", 1000, 700, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_MAXIMIZEBOX, $WS_SIZEBOX))
    ConsoleWrite("DEBUG: GUI erstellt" & @CRLF)

    ; Speichern der Log-Dateien global
    $g_aCurrentLogFiles = $aLogFiles

    ; Panel für die Dateiauswahl erstellen
    GUICtrlCreateLabel("Verfügbare Log-Dateien:", 10, 10, 200, 20)
    $g_idLogFileTree = GUICtrlCreateTreeView(10, 35, 250, 580, BitOR($TVS_HASBUTTONS, $TVS_HASLINES, $TVS_LINESATROOT, $TVS_SHOWSELALWAYS))

    ; Speichern des TreeView-Handles für WM_NOTIFY
    $g_hTreeViewHandle = GUICtrlGetHandle($g_idLogFileTree)

    ; Filter-Panel erstellen
    GUICtrlCreateLabel("Log-Level:", 270, 10, 80, 20)
    $g_idLogLevelCombo = GUICtrlCreateCombo("Alle", 350, 10, 100, 20, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))

    GUICtrlCreateLabel("Log-Klasse:", 460, 10, 80, 20)
    $g_idLogClassCombo = GUICtrlCreateCombo("Alle", 540, 10, 160, 20, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))

    GUICtrlCreateLabel("Suche:", 270, 40, 80, 20)
    $g_idSearchEdit = GUICtrlCreateInput("", 350, 40, 280, 20)
    $g_idSearchButton = GUICtrlCreateButton("Suchen", 640, 40, 80, 20)
    $g_idRegexCheck = GUICtrlCreateCheckbox("RegEx", 730, 40, 60, 20)

    ; Statistikbereich
    $g_idLogStats = GUICtrlCreateEdit("", 270, 70, 720, 80, BitOR($ES_READONLY, $ES_MULTILINE))
    GUICtrlSetBkColor($g_idLogStats, $COLOR_SKYBLUE)
    GUICtrlSetFont($g_idLogStats, 9, 400, 0, "Consolas")

    ; ListView für Logeinträge
    $g_idLogListView = GUICtrlCreateListView("Zeitstempel|Level|Klasse|Nachricht", 270, 160, 720, 455)
    _GUICtrlListView_SetColumnWidth($g_idLogListView, 0, 150)
    _GUICtrlListView_SetColumnWidth($g_idLogListView, 1, 70)
    _GUICtrlListView_SetColumnWidth($g_idLogListView, 2, 120)
    _GUICtrlListView_SetColumnWidth($g_idLogListView, 3, 360)

    ; ListView-Stil anpassen
    _GUICtrlListView_SetExtendedListViewStyle($g_idLogListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER, $LVS_EX_INFOTIP))

    ; Aktionsbuttons
    $g_idColorConfigButton = GUICtrlCreateButton("Farben", 290, 625, 100, 25)  ; Button für Farbkonfiguration
    $g_idExportButton = GUICtrlCreateButton("Exportieren", 400, 625, 100, 25)
    $g_idToggleViewButton = GUICtrlCreateButton("Details", 510, 625, 100, 25)
    $g_idCloseButton = GUICtrlCreateButton("Schließen", 890, 625, 100, 25)

    ; Status-Label hinzufügen (fürs Debugging hilfreich)
    $g_idStatus = GUICtrlCreateLabel("Bereit.", 10, 625, 270, 25)  ; Breite angepasst, damit Status nicht mit Farben-Button überlappt

    ; Logdateien im TreeView organisieren
    ConsoleWrite("DEBUG: Rufe _PopulateLogFileTree auf..." & @CRLF)
    _PopulateLogFileTree($aLogFiles)
    ConsoleWrite("DEBUG: _PopulateLogFileTree beendet" & @CRLF)

    ; Ursprünglichen WM_NOTIFY-Handler speichern und eigenen Handler registrieren
    GUIRegisterMsg($WM_NOTIFY, "_LogViewer_WM_NOTIFY_Handler")
    ConsoleWrite("Log-Viewer: Original WM_NOTIFY handler gesichert: " & "_LogViewer_WM_NOTIFY_Handler" & @CRLF)

    GUISetState(@SW_SHOW, $g_hLogViewerGUI)

    ; Event-Schleife für den Log-Viewer
    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $g_idCloseButton
                ; Ursprünglichen WM_NOTIFY-Handler wiederherstellen
                ConsoleWrite("Log-Viewer: Stelle ursprünglichen WM_NOTIFY-Handler wieder her: " & "_LogViewer_WM_NOTIFY_Handler" & @CRLF)
                GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
                GUIDelete($g_hLogViewerGUI)
                Return

            Case $g_idLogFileTree
                _HandleLogFileSelection()

            Case $g_idLogLevelCombo, $g_idLogClassCombo
                _FilterLogEntries()

            Case $g_idSearchButton
                _SearchInLogEntries()

            Case $g_idExportButton
                _ExportLogEntries()

            Case $g_idToggleViewButton
                _ToggleLogDetailView()

            Case $g_idColorConfigButton
                ; Erweiterten Farbkonfigurator aufrufen
                If _ShowLogLevelColorConfigurator() Then
                    ; Wenn Änderungen gespeichert wurden, aktuelle Ansicht aktualisieren
                    _DisplayLogEntries($g_aCurrentLogEntries)
                    GUICtrlSetData($g_idStatus, "Farbeinstellungen wurden aktualisiert.")
                EndIf
        EndSwitch
    WEnd
EndFunc

; Kombinierter WM_NOTIFY Handler für den Log-Viewer
Func _LogViewer_WM_NOTIFY_Handler($hWnd, $iMsg, $wParam, $lParam)
    ; Wenn es sich um unsere Log-Viewer-GUI handelt
    If $hWnd = $g_hLogViewerGUI Then
        If Not IsHWnd($g_hTreeViewHandle) Then $g_hTreeViewHandle = GUICtrlGetHandle($g_idLogFileTree)

        Local $tNMHDR = DllStructCreate("hwnd hWndFrom; uint_ptr IDFrom; int Code", $lParam)
        Local $hWndFrom = DllStructGetData($tNMHDR, "hWndFrom")
        Local $iCode = DllStructGetData($tNMHDR, "Code")

        ; Für TreeView-Control
        If $hWndFrom = $g_hTreeViewHandle Then
            Switch $iCode
                Case $NM_DBLCLK
                    ConsoleWrite("Log-Viewer: TreeView-Doppelklick erkannt!" & @CRLF)
                    _OpenSelectedLogFile()
                    Return $GUI_RUNDEFMSG
            EndSwitch
        EndIf

        ; Für ListView-Control
        Local $hListViewHandle = GUICtrlGetHandle($g_idLogListView)
        If $hWndFrom = $hListViewHandle Then
            Switch $iCode
                ; Tooltip-Event für ListView-Items
                Case $LVN_GETINFOTIP
                    ; ListInfoTip-Struktur bearbeiten
                    Local $tNMLVGETINFOTIP = DllStructCreate($tagNMLVGETINFOTIP_LogViewer, $lParam)

                    ; Zeilen- und Spaltenindex ermitteln
                    Local $iItem = DllStructGetData($tNMLVGETINFOTIP, "iItem")

                    ; Tooltip-Text abrufen (aus Spalte 4, die den Tooltip mit der Zeilennummer enthält)
                    Local $sTooltipText = _GUICtrlListView_GetItemText($g_idLogListView, $iItem, 4)

                    ; Tooltip-Text setzen
                    If $sTooltipText <> "" Then
                        DllStructSetData(DllStructCreate("wchar[" & DllStructGetData($tNMLVGETINFOTIP, "cchTextMax") & "]", _
                                       DllStructGetData($tNMLVGETINFOTIP, "pszText")), 1, $sTooltipText)
                        Return $GUI_RUNDEFMSG
                    EndIf

                ; Farbkodierung nach Log-Level
                Case $NM_CUSTOMDRAW
                    ; NMLVCUSTOMDRAW-Struktur - direkt definiert, um Abhängigkeiten zu vermeiden
                    Local $tagNMLVCUSTOMDRAW = "struct;hwnd hWndFrom;uint_ptr IDFrom;int Code;dword dwDrawStage;handle hdc;" & _
                                             "struct;long left;long top;long right;long bottom;endstruct;" & _
                                             "dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;endstruct;" & _
                                             "dword clrText;dword clrTextBk;int iSubItem;dword dwItemType;" & _
                                             "dword clrFace;int iIconEffect;int iIconPhase;int iPartId;int iStateId;" & _
                                             "struct;long left;long top;long right;long bottom;endstruct;uint uAlign"

                    Local $tNMLVCUSTOMDRAW = DllStructCreate($tagNMLVCUSTOMDRAW, $lParam)
                    Local $iDrawStage = DllStructGetData($tNMLVCUSTOMDRAW, "dwDrawStage")

                    ; In PREPAINT-Phase Items individuell behandeln
                    If $iDrawStage = $CDDS_PREPAINT Then
                        ; ITEM-Modus anfordern
                        Return $CDRF_NOTIFYITEMDRAW
                    ElseIf $iDrawStage = $CDDS_ITEMPREPAINT Then
                        ; Item-Informationen extrahieren
                        Local $iRow = DllStructGetData($tNMLVCUSTOMDRAW, "dwItemSpec")

                        ; Wenn gültige Zeile
                        If $iRow >= 0 And $iRow < _GUICtrlListView_GetItemCount($g_idLogListView) Then
                            ; Log-Level der Zeile ermitteln
                            Local $sLevel = _GUICtrlListView_GetItemText($g_idLogListView, $iRow, 1)

                            ; Anhand des Log-Levels die richtige Farbe auswählen
                            Local $iColor = 0xFFFFFF ; Standardfarbe weiß
;~                             Local $iLevelIndex = _GetColorIndexForLevel($sLevel, $g_aLogLevelColors)
                            Local $iLevelIndex = _GetColorIndexForLevel($sLevel)
                            ; Wenn Level gefunden, dessen Farbe verwenden
                            If $iLevelIndex >= 0 Then
                                ; RGB-Format aus dem Array holen
                                $iColor = $g_aLogLevelColors[$iLevelIndex][1]

                                ; Für die ListView in BGR konvertieren
                                $iColor = $iColor
                            EndIf

                            ; Hintergrundfarbe setzen
                            DllStructSetData($tNMLVCUSTOMDRAW, "clrTextBk",$iColor)

                            Return $CDRF_NEWFONT
                        EndIf
                    EndIf
            EndSwitch
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc