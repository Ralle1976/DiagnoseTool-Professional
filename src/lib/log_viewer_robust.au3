#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstants.au3>
#include <TreeViewConstants.au3>
#include <GuiTreeView.au3>
#include <Date.au3>
#include <Array.au3>
#include "constants_new.au3"
#include "logging.au3"
#include "gui_functions.au3"
#include "log_handler.au3"
#include "log_analysis_utils.au3"
#include "debug_utils.au3"
#include "utils.au3"
#include "log_parser.au3"
#include "log_level_colors.au3"

; Globale Variablen für den robusten Log-Viewer
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
Global $g_aCurrentLogFiles
Global $g_idStatus

Global $g_aCurrentLogEntries
Global $g_sCurrentLogFile = ""

; Hauptfunktion zum Anzeigen des robusten Log-Viewers
Func _ShowLogViewerRobust($aLogFiles)
    _LogInfo("Starte robusten Log-Viewer mit " & $aLogFiles[0] & " Dateien")
    _DebugInfo("Log-Viewer gestartet mit " & $aLogFiles[0] & " Dateien")
    
    ; Log-Viewer GUI erstellen
    $g_hLogViewerGUI = GUICreate("Robuster Log-Datei Viewer", $GUI_LOGVIEWER_WIDTH, $GUI_LOGVIEWER_HEIGHT, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_MAXIMIZEBOX, $WS_SIZEBOX))
    
    ; Speichern der Log-Dateien global
    $g_aCurrentLogFiles = $aLogFiles
    
    ; Panel für die Dateiauswahl erstellen
    GUICtrlCreateLabel("Verfügbare Log-Dateien:", 10, 10, 200, 20)
    $g_idLogFileTree = GUICtrlCreateTreeView(10, 35, 250, 580, BitOR($TVS_HASBUTTONS, $TVS_HASLINES, $TVS_LINESATROOT, $TVS_SHOWSELALWAYS))
    
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
    _GUICtrlListView_SetExtendedListViewStyle($g_idLogListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))
    
    ; Statusleiste
    $g_idStatus = GUICtrlCreateLabel("Bereit.", 270, 625, 250, 20)
    
    ; Aktionsbuttons
    $g_idExportButton = GUICtrlCreateButton("Exportieren", 400, 625, 100, 25)
    $g_idToggleViewButton = GUICtrlCreateButton("Details", 510, 625, 100, 25)
    $g_idCloseButton = GUICtrlCreateButton("Schließen", 890, 625, 100, 25)
    
    ; Logdateien im TreeView organisieren
    _PopulateLogFileTreeRobust($aLogFiles)
    
    GUISetState(@SW_SHOW, $g_hLogViewerGUI)
    
    ; Event-Schleife für den Log-Viewer
    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $g_idCloseButton
                GUIDelete($g_hLogViewerGUI)
                Return
                
            Case $g_idLogFileTree
                _HandleLogFileSelectionRobust()
                
            Case $g_idLogLevelCombo, $g_idLogClassCombo
                _FilterLogEntriesRobust()
                
            Case $g_idSearchButton
                _SearchInLogEntriesRobust()
                
            Case $g_idExportButton
                _ExportLogEntriesRobust()
                
            Case $g_idToggleViewButton
                _ToggleLogDetailViewRobust()
        EndSwitch
    WEnd
EndFunc

; Füllt den TreeView mit Logdateien (robuste Version)
Func _PopulateLogFileTreeRobust($aLogFiles)
    _DebugInfo("Fülle TreeView mit " & $aLogFiles[0] & " Dateien")
    
    ; Root-Element erstellen
    Local $hRoot = GUICtrlCreateTreeViewItem("Log-Dateien", $g_idLogFileTree)
    
    ; Verzeichnisstruktur aufbauen
    Local $aDirectories[0][2]
    
    For $i = 1 To $aLogFiles[0]
        ; Verzeichnis extrahieren
        Local $sDirectory = StringRegExpReplace($aLogFiles[$i], "^(.*\\)([^\\]+)$", "$1")
        
        ; Prüfen, ob Verzeichnis bereits bekannt ist
        Local $bFound = False
        For $j = 0 To UBound($aDirectories) - 1
            If $aDirectories[$j][0] = $sDirectory Then
                $bFound = True
                
                ; Datei zum Verzeichnis hinzufügen
                Local $sFileName = StringRegExpReplace($aLogFiles[$i], "^.*\\([^\\]+)$", "$1")
                Local $hItem = GUICtrlCreateTreeViewItem($sFileName, $aDirectories[$j][1])
                ; Pfad in Daten speichern
                GUICtrlSetData($hItem, $aLogFiles[$i])
                
                ExitLoop
            EndIf
        Next
        
        ; Wenn Verzeichnis noch nicht bekannt, hinzufügen
        If Not $bFound Then
            Local $sDirectoryName = StringRegExpReplace($sDirectory, "^.*\\([^\\]+\\)$", "$1")
            If $sDirectoryName = $sDirectory Then $sDirectoryName = "Root"
            
            ; Verzeichnis erstellen
            Local $hDirItem = GUICtrlCreateTreeViewItem($sDirectoryName, $hRoot)
            
            ; Datei zum Verzeichnis hinzufügen
            Local $sFileName = StringRegExpReplace($aLogFiles[$i], "^.*\\([^\\]+)$", "$1")
            Local $hItem = GUICtrlCreateTreeViewItem($sFileName, $hDirItem)
            ; Pfad in Daten speichern
            GUICtrlSetData($hItem, $aLogFiles[$i])
            
            ; Verzeichnis zum Array hinzufügen
            ReDim $aDirectories[UBound($aDirectories) + 1][2]
            $aDirectories[UBound($aDirectories) - 1][0] = $sDirectory
            $aDirectories[UBound($aDirectories) - 1][1] = $hDirItem
        EndIf
    Next
    
    ; Verzeichnisknoten erweitern
    _GUICtrlTreeView_Expand($g_idLogFileTree, $hRoot, True)
    
    ; Erste Logdatei auswählen, falls vorhanden
    If $aLogFiles[0] > 0 Then
        Local $hFirstFile = _GUICtrlTreeView_GetFirstItem($g_idLogFileTree)
        _GUICtrlTreeView_SelectItem($g_idLogFileTree, $hFirstFile)
        _HandleLogFileSelectionRobust()
    EndIf
EndFunc

; Behandelt die Auswahl einer Logdatei im TreeView (robuste Version)
Func _HandleLogFileSelectionRobust()
    _DebugInfo("Logdatei-Auswahl im TreeView geändert")
    
    Local $hSelected = GUICtrlSendMsg($g_idLogFileTree, $TVM_GETNEXTITEM, $TVGN_CARET, 0)
    If $hSelected = 0 Then 
        _DebugWarning("Keine Auswahl im TreeView")
        Return
    EndIf
    
    ; Pfad aus Daten lesen
    Local $sFilePath = GUICtrlRead(_GUICtrlTreeView_GetSelection($g_idLogFileTree))
    _DebugVar("Ausgewählter Pfad", $sFilePath)
    
    ; Nur fortfahren, wenn ein Pfad vorhanden ist und es sich um eine Datei handelt
    If $sFilePath = "" Or StringInStr($sFilePath, "\") = 0 Then 
        _DebugWarning("Ungültiger Pfad oder keine Datei ausgewählt")
        Return
    EndIf
    
    ; Logdatei parsen mit Fortschrittsanzeige
    $g_sCurrentLogFile = $sFilePath
    _DebugInfo("Verarbeite Logdatei: " & $sFilePath)
    GUICtrlSetData($g_idStatus, "Lade Logdatei: " & StringRegExpReplace($sFilePath, "^.*\\([^\\]+)$", "$1") & "...")
    
    ; Überprüfen, ob die Datei existiert
    If Not FileExists($sFilePath) Then
        _DebugError("Datei nicht gefunden: " & $sFilePath)
        GUICtrlSetData($g_idStatus, "Fehler: Datei nicht gefunden")
        Return
    EndIf
    
    ; Dateigröße prüfen
    Local $iFileSize = FileGetSize($sFilePath)
    _DebugInfo("Dateigröße: " & $iFileSize & " Bytes")
    
    ; Verwendung der Funktion _ParseLogFile aus log_analysis_utils.au3
    $g_aCurrentLogEntries = _ParseLogFile($sFilePath)
    If @error Then
        _DebugError("Fehler beim Parsen der Logdatei: " & @error)
        GUICtrlSetData($g_idStatus, "Fehler beim Laden der Logdatei: " & @error)
        GUICtrlSetData($g_idLogStats, "Fehler beim Laden der Logdatei." & @CRLF & "Bitte prüfen Sie das Format und die Dateigröße.")
        _GUICtrlListView_DeleteAllItems($g_idLogListView)
        Return
    EndIf
    
    ; Gefiltertes Array für Anzeigeoptimierung vorbereiten
    Local $aFilteredEntries[0][5]
    
    ; Füge unvollständige Einträge IMMER hinzu, egal wie viele es sind
    Local $iFilteredCount = 0
    Local $iTruncatedCount = 0
    
    ; Erst alle unvollständigen Einträge suchen und markieren
    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        If StringInStr($g_aCurrentLogEntries[$i][1], "TRUNCATED") Then
            $iTruncatedCount += 1
            ; Hinzufügen zum gefilterten Array
            ReDim $aFilteredEntries[$iFilteredCount + 1][5]
            For $j = 0 To 4
                $aFilteredEntries[$iFilteredCount][$j] = $g_aCurrentLogEntries[$i][$j]
            Next
            
            ; Besonders hervorheben in der Nachricht
            If Not StringInStr($aFilteredEntries[$iFilteredCount][3], "UNVOLLSTÄNDIG") Then
                $aFilteredEntries[$iFilteredCount][3] = "!!! UNVOLLSTÄNDIGER LOG !!! " & $aFilteredEntries[$iFilteredCount][3]
            EndIf
            
            $iFilteredCount += 1
            
            ; Debug-Ausgabe
            ConsoleWrite("Unvollständiger Eintrag markiert: " & $g_aCurrentLogEntries[$i][0] & @CRLF)
        EndIf
    Next
    
    ConsoleWrite("Insgesamt " & $iTruncatedCount & " unvollständige Einträge gefunden und markiert." & @CRLF)
    
    ; Unvollständige Einträge in chronologischer Reihenfolge belassen
    ; Anzahl der gelesenen Einträge prüfen
    If Not IsArray($g_aCurrentLogEntries) Or UBound($g_aCurrentLogEntries) = 0 Then
        _DebugWarning("Keine Logeinträge gefunden")
        GUICtrlSetData($g_idStatus, "Keine Logeinträge gefunden")
        GUICtrlSetData($g_idLogStats, "Keine Logeinträge gefunden." & @CRLF & "Die Datei enthält möglicherweise kein bekanntes Log-Format.")
        _GUICtrlListView_DeleteAllItems($g_idLogListView)
        Return
    EndIf
    
    _DebugInfo("Anzahl gelesener Logeinträge: " & UBound($g_aCurrentLogEntries))
    
    ; Log-Levels und Klassen aktualisieren
    GUICtrlSetData($g_idStatus, "Aktualisiere Filter und Statistiken...")
    _UpdateLogFiltersFromEntriesRobust()
    
    ; Statistiken anzeigen
    _UpdateLogStatisticsRobust()
    
    ; Logeinträge anzeigen
    _DisplayLogEntriesRobust($g_aCurrentLogEntries)
    
    GUICtrlSetData($g_idStatus, "Bereit. Logdatei wurde geladen.")
EndFunc

; Aktualisiert die Filter-Dropdowns basierend auf den aktuellen Logeinträgen (robuste Version)
Func _UpdateLogFiltersFromEntriesRobust()
    ; Log-Levels ermitteln und im Combo-Box anzeigen
    GUICtrlSetData($g_idLogLevelCombo, "")
    GUICtrlSetData($g_idLogLevelCombo, "Alle")
    
    Local $aLogLevels = _GetUniqueLogLevels($g_aCurrentLogEntries)
    For $i = 0 To UBound($aLogLevels) - 1
        GUICtrlSetData($g_idLogLevelCombo, $aLogLevels[$i])
    Next
    GUICtrlSetData($g_idLogLevelCombo, "Alle")
    
    ; Log-Klassen ermitteln und im Combo-Box anzeigen
    GUICtrlSetData($g_idLogClassCombo, "")
    GUICtrlSetData($g_idLogClassCombo, "Alle")
    
    Local $aLogClasses = _GetUniqueLogClasses($g_aCurrentLogEntries)
    For $i = 0 To UBound($aLogClasses) - 1
        GUICtrlSetData($g_idLogClassCombo, $aLogClasses[$i])
    Next
    GUICtrlSetData($g_idLogClassCombo, "Alle")
EndFunc

; Aktualisiert die Logstatistiken (robuste Version)
Func _UpdateLogStatisticsRobust()
    Local $aStats = _GetLogStatistics($g_aCurrentLogEntries)
    
    ; Statistik-Text erstellen
    Local $sStatsText = "Datei: " & StringRegExpReplace($g_sCurrentLogFile, "^.*\\([^\\]+)$", "$1") & @CRLF
    $sStatsText &= "Pfad: " & $g_sCurrentLogFile & @CRLF
    $sStatsText &= "Gesamteinträge: " & $aStats.Item("TotalEntries") & @CRLF
    
    ; Zähle und hebe unvollständige Einträge hervor
    Local $iTruncated = 0
    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        If StringInStr($g_aCurrentLogEntries[$i][1], "TRUNCATED") Then
            $iTruncated += 1
        EndIf
    Next
    
    ; Wenn unvollständige Einträge vorhanden sind, deutlich anzeigen
    If $iTruncated > 0 Then
        $sStatsText &= "!!! UNVOLLSTÄNDIGE EINTRÄGE: " & $iTruncated & " !!!" & @CRLF
    EndIf
    
    ; Zeitraum anzeigen, wenn verfügbar
    If UBound($g_aCurrentLogEntries) > 0 Then
        $sStatsText &= "Zeitraum: " & $g_aCurrentLogEntries[0][0] & " bis " & $g_aCurrentLogEntries[UBound($g_aCurrentLogEntries) - 1][0] & @CRLF
    EndIf
    
    ; Log-Level-Statistiken
    $sStatsText &= "Log-Levels: "
    Local $oLevelStats = $aStats.Item("LevelStats")
    Local $aLevelKeys = Dict_Keys($oLevelStats)
    
    For $i = 0 To UBound($aLevelKeys) - 1
        $sStatsText &= $aLevelKeys[$i] & " (" & Dict_Get($oLevelStats, $aLevelKeys[$i]) & "), "
    Next
    If UBound($aLevelKeys) > 0 Then
        $sStatsText = StringTrimRight($sStatsText, 2)
    EndIf
    $sStatsText &= @CRLF
    
    ; Top Log-Klassen
    $sStatsText &= "Top Log-Klassen: "
    Local $oClassStats = $aStats.Item("ClassStats")
    Local $aClassKeys = Dict_Keys($oClassStats)
    
    ; Sortieren nach Häufigkeit (absteigend) mit temporärem Array
    Local $aClassCounts[UBound($aClassKeys)][2]
    For $i = 0 To UBound($aClassKeys) - 1
        $aClassCounts[$i][0] = Dict_Get($oClassStats, $aClassKeys[$i])
        $aClassCounts[$i][1] = $aClassKeys[$i]
    Next
    
    _ArraySort($aClassCounts, 1, 0, 0, 0) ; Sortiere nach Spalte 0 (Anzahl) absteigend
    
    ; Top 5 Klassen anzeigen
    Local $iTopCount = _Min(5, UBound($aClassCounts))
    For $i = 0 To $iTopCount - 1
        $sStatsText &= $aClassCounts[$i][1] & " (" & $aClassCounts[$i][0] & "), "
    Next
    If $iTopCount > 0 Then
        $sStatsText = StringTrimRight($sStatsText, 2)
    EndIf
    
    ; Statistik-Text setzen
    GUICtrlSetData($g_idLogStats, $sStatsText)
EndFunc

; Zeigt Logeinträge im ListView an (robuste Version)
Func _DisplayLogEntriesRobust($aEntries)
    ; ListView leeren
    _GUICtrlListView_DeleteAllItems($g_idLogListView)
    
    ; Logeinträge hinzufügen (maximal definierte Anzahl, um Performance-Probleme zu vermeiden)
    Local $iEntryCount = UBound($aEntries)
    Local $iMaxEntries = _Min($iEntryCount, $g_iMaxLogEntriesToShow)
    Local $bHasTruncated = False
    
    ; Prüfen, ob unvollständige Einträge vorhanden sind
    For $i = 0 To $iEntryCount - 1
        If StringInStr($aEntries[$i][1], "TRUNCATED") Then
            $bHasTruncated = True
            ; Position des unvollständigen Eintrags in der Konsole protokollieren
            _LogInfo("Unvollständiger Eintrag gefunden an Position " & $i & " von " & $iEntryCount)
            _DebugInfo("Unvollständiger Eintrag gefunden an Position " & $i)
        EndIf
    Next
    
    ; Wenn der Eintrag nach dem maximalen Anzeigelimit liegt, das Limit erweitern
    If $bHasTruncated And $iEntryCount > $g_iMaxLogEntriesToShow Then
        _LogInfo("Erhöhe Anzeigelimit, um unvollständige Einträge zu zeigen.")
        $iMaxEntries = $iEntryCount  ; Alle Einträge anzeigen
    EndIf
    
    _DebugInfo("Zeige " & $iMaxEntries & " von " & $iEntryCount & " Logeinträgen an")
    GUICtrlSetData($g_idStatus, "Lade " & $iMaxEntries & " Logeinträge...")
    
    For $i = 0 To $iMaxEntries - 1
        ; Zeitstempel formatieren
        Local $sTimestamp = $aEntries[$i][0]
        
        ; Log-Level Farbe festlegen
        Local $sLevel = $aEntries[$i][1]
        Local $iColor
        
        ; Hervorhebung für unvollständige/abgeschnittene Einträge
        If StringInStr($sLevel, "TRUNCATED") Then
            ; Farbe aus dem benutzerdefinierten System verwenden
            $iColor = _GetLogLevelColor("TRUNCATED")  ; Aus dem Farb-System
            
            ; Extra Debug-Info ausgeben
            ConsoleWrite("[ANZEIGE] Unvollständiger Eintrag gefunden in DisplayLogEntries - Level: " & $sLevel & @CRLF)
            
            ; Nachricht formatieren, damit unvollständige Einträge deutlich erkennbar sind
            If Not StringInStr($aEntries[$i][3], "UNVOLLSTÄNDIG") Then
                $aEntries[$i][3] = "!!! UNVOLLSTÄNDIGER LOG-EINTRAG !!! " & $aEntries[$i][3]
            EndIf
        Else
            Switch StringLower($sLevel)
                Case "error", "critical", "fatal"
                    $iColor = 0xFF0000  ; Rot
                Case "warn", "warning"
                    $iColor = 0xFFA500  ; Orange
                Case "info", "information"
                    $iColor = 0x000000  ; Schwarz
                Case "debug"
                    $iColor = 0x808080  ; Grau
                Case "trace"
                    $iColor = 0xA0A0A0  ; Hellgrau
                Case Else
                    $iColor = 0x000000  ; Schwarz
            EndSwitch
        EndIf
        
        ; Eintrag zum ListView hinzufügen
        Local $iIndex = _GUICtrlListView_AddItem($g_idLogListView, $sTimestamp, $iColor)
        _GUICtrlListView_AddSubItem($g_idLogListView, $iIndex, $sLevel, 1, $iColor)
        _GUICtrlListView_AddSubItem($g_idLogListView, $iIndex, $aEntries[$i][2], 2, $iColor)
        _GUICtrlListView_AddSubItem($g_idLogListView, $iIndex, $aEntries[$i][3], 3, $iColor)
    Next
    
    ; Prüfen, ob Einträge hinzugefügt wurden
    Local $iActualCount = _GUICtrlListView_GetItemCount($g_idLogListView)
    _DebugInfo("Tatsächlich hinzugefügte Einträge: " & $iActualCount)
    
    ; Statusinfo aktualisieren, wenn es mehr Einträge gibt als angezeigt werden
    If $iEntryCount > $iMaxEntries Then
        GUICtrlSetData($g_idLogStats, GUICtrlRead($g_idLogStats) & @CRLF & "* Zeige die ersten " & $iMaxEntries & " von " & $iEntryCount & " Einträgen")
    EndIf
    
    ; Wenn unvollständige Einträge gefunden wurden, den Status aktualisieren
    If $bHasTruncated Then
        GUICtrlSetData($g_idStatus, "Anzeige komplett. " & $iMaxEntries & " Einträge, inkl. UNVOLLSTÄNDIGER Einträge (lila markiert).")
    Else
        GUICtrlSetData($g_idStatus, "Bereit. " & $iMaxEntries & " von " & $iEntryCount & " Einträgen angezeigt.")
    EndIf
EndFunc

; Filtert Logeinträge basierend auf ausgewähltem Level und Klasse (robuste Version)
Func _FilterLogEntriesRobust()
    Local $sLevel = GUICtrlRead($g_idLogLevelCombo)
    Local $sClass = GUICtrlRead($g_idLogClassCombo)
    
    ; Wenn "Alle" ausgewählt ist, den Filter zurücksetzen
    If $sLevel = "Alle" Then $sLevel = ""
    If $sClass = "Alle" Then $sClass = ""
    
    ; Wenn keine Filter aktiv sind, alle Einträge anzeigen
    If $sLevel = "" And $sClass = "" Then
        _DisplayLogEntriesRobust($g_aCurrentLogEntries)
        Return
    EndIf
    
    GUICtrlSetData($g_idStatus, "Filtere Logeinträge...")
    
    ; Einträge filtern
    Local $aFiltered[0][5]
    Local $iCount = 0
    
    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        ; Prüfe Level-Filter
        If $sLevel <> "" And $g_aCurrentLogEntries[$i][1] <> $sLevel Then
            ContinueLoop
        EndIf
        
        ; Prüfe Class-Filter
        If $sClass <> "" And $g_aCurrentLogEntries[$i][2] <> $sClass Then
            ContinueLoop
        EndIf
        
        ; Füge zum gefilterten Array hinzu
        ReDim $aFiltered[$iCount + 1][5]
        $aFiltered[$iCount][0] = $g_aCurrentLogEntries[$i][0]
        $aFiltered[$iCount][1] = $g_aCurrentLogEntries[$i][1]
        $aFiltered[$iCount][2] = $g_aCurrentLogEntries[$i][2]
        $aFiltered[$iCount][3] = $g_aCurrentLogEntries[$i][3]
        $aFiltered[$iCount][4] = $g_aCurrentLogEntries[$i][4]
        $iCount += 1
    Next
    
    ; Gefilterte Einträge anzeigen
    _DisplayLogEntriesRobust($aFiltered)
    
    GUICtrlSetData($g_idStatus, "Filter angewendet. " & $iCount & " Einträge gefunden.")
EndFunc

; Sucht in Logeinträgen nach einem Suchbegriff (robuste Version)
Func _SearchInLogEntriesRobust()
    Local $sSearchText = GUICtrlRead($g_idSearchEdit)
    Local $bRegex = (GUICtrlRead($g_idRegexCheck) = $GUI_CHECKED)
    Local $sLevel = GUICtrlRead($g_idLogLevelCombo)
    Local $sClass = GUICtrlRead($g_idLogClassCombo)
    
    ; Wenn "Alle" ausgewählt ist, den Filter zurücksetzen
    If $sLevel = "Alle" Then $sLevel = ""
    If $sClass = "Alle" Then $sClass = ""
    
    ; Wenn keine Suche eingegeben wurde, nur Filter anwenden
    If $sSearchText = "" Then
        _FilterLogEntriesRobust()
        Return
    EndIf
    
    GUICtrlSetData($g_idStatus, "Führe Suche durch...")
    
    ; Bei ungültigen Regex-Suchen abfangen
    If $bRegex Then
        ; Teste den Regex zuerst
        Local $bValidRegex = True
        StringRegExp("test", $sSearchText)
        If @error = 2 Then ; Regex-Fehler
            $bValidRegex = False
            MsgBox(48, "Ungültiger Regex", "Der eingegebene reguläre Ausdruck ist ungültig." & @CRLF & "Die Suche wird als normaler Text durchgeführt.")
            $bRegex = False
        EndIf
    EndIf
    
    ; Einträge filtern und suchen
    ; Verwendung der Funktion aus log_analysis_utils.au3
    Local $aResults = _SearchLogEntries($g_aCurrentLogEntries, $sSearchText, $bRegex, $sLevel, $sClass)
    
    ; Ergebnisse anzeigen
    _DisplayLogEntriesRobust($aResults)
    
    GUICtrlSetData($g_idStatus, "Suche abgeschlossen. " & UBound($aResults) & " Einträge gefunden.")
EndFunc

; Zeigt Details zu einem Log-Eintrag an (robuste Version)
Func _ToggleLogDetailViewRobust()
    ; Prüfen, ob ein Eintrag ausgewählt ist
    Local $iIndex = _GUICtrlListView_GetSelectedIndices($g_idLogListView)
    If $iIndex = "" Then
        MsgBox(48, "Hinweis", "Bitte wählen Sie einen Logeintrag aus, um Details anzuzeigen.")
        Return
    EndIf
    
    ; Index aus Rückgabe extrahieren
    Local $aParts = StringSplit($iIndex, "|")
    If IsArray($aParts) And $aParts[0] > 0 Then
        $iIndex = Number($aParts[1])
    Else
        MsgBox(16, "Fehler", "Ungültiger Listenindex: " & $iIndex)
        Return
    EndIf
    
    ; Sicherstellen, dass der Index im gültigen Bereich liegt
    If $iIndex < 0 Or $iIndex >= UBound($g_aCurrentLogEntries) Then
        MsgBox(16, "Fehler", "Der ausgewählte Index ist außerhalb des gültigen Bereichs: " & $iIndex)
        Return
    EndIf
    
    ; Original-JSON-Daten anzeigen
    Local $sDetails = "Detaillierte Ansicht des Logeintrags:" & @CRLF & @CRLF
    $sDetails &= "Zeitstempel: " & $g_aCurrentLogEntries[$iIndex][0] & @CRLF
    $sDetails &= "Log-Level: " & $g_aCurrentLogEntries[$iIndex][1] & @CRLF
    $sDetails &= "Log-Klasse: " & $g_aCurrentLogEntries[$iIndex][2] & @CRLF
    $sDetails &= "Nachricht: " & $g_aCurrentLogEntries[$iIndex][3] & @CRLF & @CRLF
    $sDetails &= "Original-Daten:" & @CRLF & $g_aCurrentLogEntries[$iIndex][4]
    
    MsgBox(64, "Logeintrag Details", $sDetails)
EndFunc

#cs
; [ENTFERNT] Diese Funktion wurde entfernt, um die chronologische Reihenfolge der Log-Einträge zu bewahren
; Hilfsfunktion: Stelle sicher, dass unvollständige Einträge am Anfang des Arrays erscheinen
Func _ReorderTruncatedEntries(ByRef $aEntries)
    ; Prüfe, ob Array vorhanden und nicht leer ist
    If Not IsArray($aEntries) Or UBound($aEntries) < 2 Then Return
    
    Local $iCount = UBound($aEntries)
    Local $aTruncated[0][5]
    Local $aNormal[0][5]
    Local $iTruncatedCount = 0
    Local $iNormalCount = 0
    
    ; Einträge nach Typ trennen
    For $i = 0 To $iCount - 1
        If StringInStr($aEntries[$i][1], "TRUNCATED") Then
            ; In Truncated-Array übernehmen
            ReDim $aTruncated[$iTruncatedCount + 1][5]
            For $j = 0 To 4
                $aTruncated[$iTruncatedCount][$j] = $aEntries[$i][$j]
            Next
            $iTruncatedCount += 1
        Else
            ; In normales Array übernehmen
            ReDim $aNormal[$iNormalCount + 1][5]
            For $j = 0 To 4
                $aNormal[$iNormalCount][$j] = $aEntries[$i][$j]
            Next
            $iNormalCount += 1
        EndIf
    Next
    
    ; Falls keine unvollständigen Einträge gefunden wurden, nichts tun
    If $iTruncatedCount = 0 Then Return
    
    ; Neu zusammenführen: Erst unvollständige, dann normale Einträge
    ReDim $aEntries[$iCount][5]
    
    ; Unvollständige Einträge an den Anfang
    For $i = 0 To $iTruncatedCount - 1
        For $j = 0 To 4
            $aEntries[$i][$j] = $aTruncated[$i][$j]
        Next
    Next
    
    ; Normale Einträge danach
    For $i = 0 To $iNormalCount - 1
        For $j = 0 To 4
            $aEntries[$i + $iTruncatedCount][$j] = $aNormal[$i][$j]
        Next
    Next
    
    _LogInfo("Einträge neu angeordnet: " & $iTruncatedCount & " unvollständige Einträge an den Anfang gesetzt")
EndFunc
#ce

; Exportiert Logeinträge in eine Datei (robuste Version)
Func _ExportLogEntriesRobust()
    ; Dateiauswahltest anzeigen
    Local $sFilePath = FileSaveDialog("Logeinträge exportieren", @WorkingDir, "CSV-Dateien (*.csv)|Textdateien (*.txt)", 2, "export.csv")
    If @error Then Return
    
    ; Dateierweiterung prüfen und ggf. hinzufügen
    If StringRight($sFilePath, 4) <> ".csv" And StringRight($sFilePath, 4) <> ".txt" Then
        $sFilePath &= ".csv"
    EndIf
    
    ; Datei zum Schreiben öffnen
    Local $hFile = FileOpen($sFilePath, $FO_OVERWRITE + $FO_ANSI)
    If $hFile = -1 Then
        MsgBox(16, "Fehler", "Die Datei konnte nicht zum Schreiben geöffnet werden.")
        Return
    EndIf
    
    GUICtrlSetData($g_idStatus, "Exportiere Logeinträge...")
    
    ; Kopfzeile schreiben
    FileWriteLine($hFile, "Zeitstempel;Log-Level;Log-Klasse;Nachricht")
    
    ; Daten schreiben (aktuell angezeigte Einträge oder alle, falls weniger als maximale Anzahl)
    Local $iEntryCount = UBound($g_aCurrentLogEntries)
    Local $iMaxEntries = _Min($iEntryCount, $g_iMaxLogEntriesToShow)
    
    ; Exportfortschritt
    Local $iProgress = 0
    Local $iProgressStep = 1 ; Aktualisiere jede Zeile
    
    For $i = 0 To $iMaxEntries - 1
        ; CSV-Zelle vorbereiten: Semikolons durch Kommas ersetzen und in Anführungszeichen setzen
        Local $sTimestamp = StringReplace($g_aCurrentLogEntries[$i][0], ";", ",")
        Local $sLevel = StringReplace($g_aCurrentLogEntries[$i][1], ";", ",")
        Local $sClass = StringReplace($g_aCurrentLogEntries[$i][2], ";", ",")
        Local $sMessage = StringReplace($g_aCurrentLogEntries[$i][3], ";", ",")
        
        ; Anführungszeichen für Felder mit Sonderzeichen
        If StringRegExp($sTimestamp, "[;,\r\n]") Then $sTimestamp = '"' & $sTimestamp & '"'
        If StringRegExp($sLevel, "[;,\r\n]") Then $sLevel = '"' & $sLevel & '"'
        If StringRegExp($sClass, "[;,\r\n]") Then $sClass = '"' & $sClass & '"'
        If StringRegExp($sMessage, "[;,\r\n]") Then $sMessage = '"' & $sMessage & '"'
        
        ; Zeile schreiben
        Local $sLine = $sTimestamp & ";" & $sLevel & ";" & $sClass & ";" & $sMessage
        FileWriteLine($hFile, $sLine)
        
        ; Fortschritt aktualisieren
        $iProgress += 1
        If Mod($iProgress, $iProgressStep) = 0 Then
            GUICtrlSetData($g_idStatus, "Exportiere... " & Int($iProgress * 100 / $iMaxEntries) & "%")
        EndIf
    Next
    
    ; Datei schließen
    FileClose($hFile)
    
    ; Erfolgsbestätigung
    GUICtrlSetData($g_idStatus, "Export abgeschlossen: " & $iMaxEntries & " Einträge exportiert.")
    MsgBox(64, "Export abgeschlossen", "Die Logeinträge wurden erfolgreich exportiert nach:" & @CRLF & $sFilePath)
EndFunc