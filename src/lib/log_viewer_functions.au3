#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <ComboConstants.au3>
#include <TreeViewConstants.au3>
#include <FileConstants.au3>
#include <GuiListView.au3>
#include <GuiTreeView.au3>
#include <File.au3>
#include <Array.au3>
#include <Date.au3>

#include "logging.au3"
#include "log_handler.au3"
#include "missing_functions.au3"

; Konstanten für die Log-Viewer-Funktionalität
Global Const $LOG_FILTER_ALL = "Alle"
Global Const $LOG_DETAIL_VIEW_MAX_LENGTH = 10000

; Externe Referenz auf globale Variablen
; Diese Variablen werden in log_viewer.au3 definiert
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
Global $g_idColorConfigButton
Global $g_aCurrentLogFiles
Global $g_aCurrentLogEntries
Global $g_sCurrentLogFile
Global $g_hTreeViewHandle
Global $g_idStatus

; Funktion zum Befüllen des TreeViews mit Logdateien
; KORRIGIERTE VERSION: Zeigt den vollständigen Pfad an
Func _PopulateLogFileTree($aLogFiles)
    ConsoleWrite("DEBUG: _PopulateLogFileTree gestartet, Array-Größe: " & UBound($aLogFiles) & @CRLF)
    For $j = 0 To UBound($aLogFiles) - 1
        ConsoleWrite("DEBUG: aLogFiles[" & $j & "] = " & $aLogFiles[$j] & @CRLF)
    Next
    
    ; TreeView leeren
    _GUICtrlTreeView_DeleteAll($g_idLogFileTree)

    ; Verzeichnisstruktur für Gruppierung erstellen
    Local $oDirectories = ObjCreate("Scripting.Dictionary")

    ; Dateien nach Verzeichnissen gruppieren
    For $i = 1 To UBound($aLogFiles) - 1
        Local $sPath = $aLogFiles[$i]
        Local $sDir = StringLeft($sPath, StringInStr($sPath, "\", 0, -1))
        Local $sFileName = StringTrimLeft($sPath, StringInStr($sPath, "\", 0, -1))

        If Not $oDirectories.Exists($sDir) Then
            $oDirectories.Add($sDir, ObjCreate("Scripting.Dictionary"))
        EndIf

        Local $oFiles = $oDirectories.Item($sDir)
        $oFiles.Add($sFileName, $sPath)
    Next

    ; Verzeichnisse im TreeView anzeigen
    Local $vDirectories = $oDirectories.Keys()
    For $i = 0 To UBound($vDirectories) - 1
        Local $sDir = $vDirectories[$i]
        Local $hDirItem = _GUICtrlTreeView_Add($g_idLogFileTree, 0, StringReplace($sDir, @ScriptDir, "..."))

        ; Dateien im Verzeichnis hinzufügen
        Local $oFiles = $oDirectories.Item($sDir)
        Local $vFiles = $oFiles.Keys()
        For $j = 0 To UBound($vFiles) - 1
            Local $sFileName = $vFiles[$j]
            Local $sFilePath = $oFiles.Item($sFileName)

            ; Datei zum TreeView hinzufügen - VOLLSTÄNDIGER PFAD wird angezeigt!
            _GUICtrlTreeView_AddChild($g_idLogFileTree, $hDirItem, $sFilePath)
        Next
    Next

    ; Ersten Knoten automatisch expandieren
    If _GUICtrlTreeView_GetCount($g_idLogFileTree) > 0 Then
        Local $hFirstItem = _GUICtrlTreeView_GetFirstItem($g_idLogFileTree)
        _GUICtrlTreeView_Expand($g_idLogFileTree, $hFirstItem)
    EndIf
EndFunc

; Funktion zur Behandlung der Logdateiauswahl
Func _HandleLogFileSelection()
    ; Ausgewählten Knoten im TreeView ermitteln
    Local $hSelected = _GUICtrlTreeView_GetSelection($g_idLogFileTree)
    If $hSelected = 0 Then Return

    ; Prüfen, ob es ein Dateieintrag ist (kein Verzeichnis)
    If _GUICtrlTreeView_GetChildren($g_idLogFileTree, $hSelected) = 0 Then
        ; VERBESSERT: Direkt den Text als Pfad verwenden
        Local $sFilePath = _GUICtrlTreeView_GetText($g_idLogFileTree, $hSelected)

        ; Prüfen, ob eine gültige Datei ausgewählt wurde
        If $sFilePath <> "" And FileExists($sFilePath) Then
            ; Statusmeldung aktualisieren
            GUICtrlSetData($g_idStatus, "Lade Logdatei: " & StringRegExpReplace($sFilePath, "^.*\\", ""))

            ; Logdatei öffnen und anzeigen
            _ViewerOpenLogFile($sFilePath)
        EndIf
    EndIf
EndFunc

; Funktion zum Filtern der Logeinträge
Func _FilterLogEntries()
    ; Ausgewählte Filter-Kriterien abrufen
    Local $sLevelFilter = GUICtrlRead($g_idLogLevelCombo)
    Local $sClassFilter = GUICtrlRead($g_idLogClassCombo)

    ; "Alle" in leeren String für Filter umwandeln
    If $sLevelFilter = $LOG_FILTER_ALL Then $sLevelFilter = ""
    If $sClassFilter = $LOG_FILTER_ALL Then $sClassFilter = ""

    ; Leere Filterung abfangen - bei "Alle" einfach die Originaldaten anzeigen
    If ($sLevelFilter = "" And $sClassFilter = "") Then
        _DisplayLogEntries($g_aCurrentLogEntries)
        GUICtrlSetData($g_idStatus, "Alle Einträge werden angezeigt: " & UBound($g_aCurrentLogEntries) & " Einträge.")
        Return
    EndIf

    ; Wenn keine Logeinträge vorhanden, nichts tun
    If $g_aCurrentLogEntries = 0 Or Not IsArray($g_aCurrentLogEntries) Then Return

    ; Gefilterte Liste erstellen
    Local $aFilteredEntries[0][6] ; Auf 6 Spalten erweitert (mit Zeilennummer)
    Local $iCount = 0

    ; Einträge filtern - ALLE Einträge durchgehen
    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        ; WICHTIG: Prüfen, ob es sich um einen TRUNCATED-Eintrag handelt
        Local $bIsTruncated = StringInStr($g_aCurrentLogEntries[$i][1], "TRUNCATED") > 0

        ; Bei VERBATIM-Filterung nach DEBUG oder anderen speziellen Levels
        ; WICHTIG: Bei TRUNCATED muss nach dem Basis-Level geprüft werden
        If $sLevelFilter <> "" Then
            If $bIsTruncated Then
                ; Für TRUNCATED-Einträge: Prüfe nach dem Basis-Level im String
                ; Beispiel: "DEBUG (TRUNCATED)" enthält "DEBUG"
                If Not StringInStr($g_aCurrentLogEntries[$i][1], $sLevelFilter) Then
                    ContinueLoop
                EndIf
            Else
                ; Für normale Einträge: Exakter Vergleich
                If $g_aCurrentLogEntries[$i][1] <> $sLevelFilter Then
                    ContinueLoop
                EndIf
            EndIf
        EndIf

        ; Klassen-Filter prüfen
        If $sClassFilter <> "" And $g_aCurrentLogEntries[$i][2] <> $sClassFilter Then
            ContinueLoop
        EndIf

        ; Eintrag zu gefilterten Einträgen hinzufügen
        ReDim $aFilteredEntries[$iCount + 1][6]
        For $j = 0 To 5 ; Alle 6 Spalten kopieren inklusive Zeilennummer
            $aFilteredEntries[$iCount][$j] = $g_aCurrentLogEntries[$i][$j]
        Next
        $iCount += 1
    Next

    ; Keine Sortierung durchführen, um die ursprüngliche Reihenfolge beizubehalten
    ; Die Reihenfolge wird durch die Zeilennummern in Spalte 5 bestimmt, die bereits beim Parsen gesetzt wurden

    ; Gefilterte Einträge anzeigen
    _DisplayLogEntries($aFilteredEntries)

    ; Zählen der TRUNCATED-Einträge für die Statusmeldung
    Local $iTruncatedCount = 0
    For $i = 0 To UBound($aFilteredEntries) - 1
        If StringInStr($aFilteredEntries[$i][1], "TRUNCATED") Then
            $iTruncatedCount += 1
        EndIf
    Next

    ; Statusmeldung aktualisieren
    Local $sMessage = "Filter angewendet: " & UBound($aFilteredEntries) & " von " & UBound($g_aCurrentLogEntries) & " Einträgen."
    If $iTruncatedCount > 0 Then
        $sMessage &= " (inkl. " & $iTruncatedCount & " unvollständige Einträge)"
    EndIf
    GUICtrlSetData($g_idStatus, $sMessage)
EndFunc

; Funktion zum Suchen in Logeinträgen
Func _SearchInLogEntries()
    ; Suchkriterien abrufen
    Local $sSearchText = GUICtrlRead($g_idSearchEdit)
    Local $bRegexSearch = (GUICtrlRead($g_idRegexCheck) = $GUI_CHECKED)

    ; Leere Suche abfangen - bei leerem Suchtext einfach alle Einträge anzeigen
    If $sSearchText = "" Then
        _DisplayLogEntries($g_aCurrentLogEntries)
        GUICtrlSetData($g_idStatus, "Alle Einträge werden angezeigt: " & UBound($g_aCurrentLogEntries) & " Einträge.")
        Return
    EndIf

    ; Level- und Klassenfilter berücksichtigen
    Local $sLevelFilter = GUICtrlRead($g_idLogLevelCombo)
    Local $sClassFilter = GUICtrlRead($g_idLogClassCombo)

    ; "Alle" in leeren String für Filter umwandeln
    If $sLevelFilter = $LOG_FILTER_ALL Then $sLevelFilter = ""
    If $sClassFilter = $LOG_FILTER_ALL Then $sClassFilter = ""

    ; Wenn keine Logeinträge vorhanden, nichts tun
    If $g_aCurrentLogEntries = 0 Or Not IsArray($g_aCurrentLogEntries) Then Return

    ; Gefilterte Liste erstellen
    Local $aSearchResults[0][6] ; Auf 6 Spalten erweitert (mit Zeilennummer)
    Local $iCount = 0

    ; Alle Einträge durchsuchen (inklusive TRUNCATED)
    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        ; Prüfen, ob es sich um einen TRUNCATED-Eintrag handelt
        Local $bIsTruncated = StringInStr($g_aCurrentLogEntries[$i][1], "TRUNCATED") > 0

        ; Bei VERBATIM-Filterung nach DEBUG oder anderen speziellen Levels
        ; WICHTIG: Bei TRUNCATED muss nach dem Basis-Level geprüft werden
        If $sLevelFilter <> "" Then
            If $bIsTruncated Then
                ; Für TRUNCATED-Einträge: Prüfe nach dem Basis-Level im String
                ; Beispiel: "DEBUG (TRUNCATED)" enthält "DEBUG"
                If Not StringInStr($g_aCurrentLogEntries[$i][1], $sLevelFilter) Then
                    ContinueLoop
                EndIf
            Else
                ; Für normale Einträge: Exakter Vergleich
                If $g_aCurrentLogEntries[$i][1] <> $sLevelFilter Then
                    ContinueLoop
                EndIf
            EndIf
        EndIf

        ; Klassen-Filter prüfen
        If $sClassFilter <> "" And $g_aCurrentLogEntries[$i][2] <> $sClassFilter Then
            ContinueLoop
        EndIf

        ; Suche NUR in den Feldern, die tatsächlich in der ListView angezeigt werden
        Local $bMatch = False

        ; Suche in den Standardfeldern (Timestamp, Level, Class, Message)
        ; Diese entsprechen den 4 Spalten der ListView
        For $j = 0 To 3 ; Timestamp, Level, Class, Message durchsuchen
            If $bRegexSearch Then
                ; RegEx-Suche
                Local $aRegexMatch = StringRegExp($g_aCurrentLogEntries[$i][$j], $sSearchText, $STR_REGEXPARRAYMATCH)
                If Not @error Then
                    $bMatch = True
                    ExitLoop
                EndIf
            Else
                ; Normale Textsuche (Groß-/Kleinschreibung ignorieren)
                If StringInStr($g_aCurrentLogEntries[$i][$j], $sSearchText, $STR_CASESENSE) > 0 Then
                    $bMatch = True
                    ExitLoop
                EndIf
            EndIf
        Next

        ; Wichtig: NICHT im Original-JSON (Feld 4) suchen, da es nicht in der ListView angezeigt wird

        ; Wenn ein Match gefunden wurde, den Eintrag hinzufügen
        If $bMatch Then
            ReDim $aSearchResults[$iCount + 1][6]
            For $j = 0 To 5 ; Alle 6 Spalten inklusive Zeilennummer kopieren
                $aSearchResults[$iCount][$j] = $g_aCurrentLogEntries[$i][$j]
            Next
            $iCount += 1
        EndIf
    Next

    ; Keine Sortierung durchführen, um die ursprüngliche Reihenfolge beizubehalten
    ; Die Reihenfolge wird durch die Zeilennummern in Spalte 5 bestimmt, die bereits beim Parsen gesetzt wurden

    ; Ergebnisse anzeigen
    _DisplayLogEntries($aSearchResults)

    ; Zählen der TRUNCATED-Einträge für die Statusmeldung
    Local $iTruncatedCount = 0
    For $i = 0 To UBound($aSearchResults) - 1
        If StringInStr($aSearchResults[$i][1], "TRUNCATED") Then
            $iTruncatedCount += 1
        EndIf
    Next

    ; Statusmeldung aktualisieren
    Local $sRegexInfo = $bRegexSearch ? " (RegEx)" : ""
    Local $sMessage = "Suche nach '" & $sSearchText & "'" & $sRegexInfo & ": " & UBound($aSearchResults) & " Treffer"
    If $iTruncatedCount > 0 Then
        $sMessage &= " (inkl. " & $iTruncatedCount & " unvollständige Einträge)"
    EndIf
    GUICtrlSetData($g_idStatus, $sMessage)
EndFunc

; Funktion zum Exportieren von Logeinträgen
Func _ExportLogEntries()
    ; Prüfen, ob Logeinträge vorhanden sind
    If Not IsArray($g_aCurrentLogEntries) Or UBound($g_aCurrentLogEntries) = 0 Then
        MsgBox(48, "Export", "Keine Logeinträge zum Exportieren vorhanden.")
        Return
    EndIf

    ; Speicherdialog anzeigen
    Local $sFilePath = FileSaveDialog("Logeinträge exportieren", @DesktopDir, "CSV-Dateien (*.csv)|Alle Dateien (*.*)", 16, "log_export_" & @YEAR & @MON & @MDAY & ".csv")
    If @error Then Return

    ; Datei zum Schreiben öffnen
    Local $hFile = FileOpen($sFilePath, 2) ; 2 = Überschreiben
    If $hFile = -1 Then
        MsgBox(16, "Fehler", "Konnte die Datei nicht zum Schreiben öffnen: " & $sFilePath)
        Return
    EndIf

    ; CSV-Header schreiben
    FileWriteLine($hFile, "Zeitstempel;Level;Klasse;Nachricht")

    ; Daten schreiben
    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        ; CSV-Zeile erstellen
        Local $sLine = _
            $g_aCurrentLogEntries[$i][0] & ";" & _
            $g_aCurrentLogEntries[$i][1] & ";" & _
            $g_aCurrentLogEntries[$i][2] & ";" & _
            """" & StringReplace($g_aCurrentLogEntries[$i][3], """", """""") & """"  ; Anführungszeichen in Nachrichten escapen

        ; Zeile in Datei schreiben
        FileWriteLine($hFile, $sLine)
    Next

    ; Datei schließen
    FileClose($hFile)

    ; Erfolgsmeldung
    GUICtrlSetData($g_idStatus, "Export abgeschlossen: " & UBound($g_aCurrentLogEntries) & " Einträge nach " & $sFilePath)
    MsgBox(64, "Export", "Export erfolgreich abgeschlossen." & @CRLF & @CRLF & "Datei: " & $sFilePath)
EndFunc

; Funktion zum Umschalten der Detailansicht
Func _ToggleLogDetailView()
    ; Aktuell ausgewählten Eintrag ermitteln
    Local $iSelected = _GUICtrlListView_GetSelectedIndices($g_idLogListView, True)
    If Not IsArray($iSelected) Or $iSelected[0] = 0 Then
        MsgBox(48, "Detailansicht", "Bitte wählen Sie einen Logeintrag aus.")
        Return
    EndIf

    ; Daten des ausgewählten Eintrags auslesen
    Local $iRow = $iSelected[1] ; Erste ausgewählte Zeile
    Local $sTimestamp = _GUICtrlListView_GetItemText($g_idLogListView, $iRow, 0)
    Local $sLevel = _GUICtrlListView_GetItemText($g_idLogListView, $iRow, 1)
    Local $sClass = _GUICtrlListView_GetItemText($g_idLogListView, $iRow, 2)
    Local $sMessage = _GUICtrlListView_GetItemText($g_idLogListView, $iRow, 3)

    ; Detailfenster erstellen
    Local $hDetailGUI = GUICreate("Logeintrag Details", 600, 400, -1, -1, BitOR($GUI_SS_DEFAULT_GUI, $WS_MAXIMIZEBOX, $WS_SIZEBOX))

    ; Informationen zum Eintrag anzeigen
    GUICtrlCreateLabel("Zeitstempel:", 10, 10, 100, 20)
    GUICtrlCreateInput($sTimestamp, 110, 10, 480, 20, BitOR($ES_READONLY, $SS_SUNKEN))

    GUICtrlCreateLabel("Log-Level:", 10, 40, 100, 20)
    GUICtrlCreateInput($sLevel, 110, 40, 200, 20, BitOR($ES_READONLY, $SS_SUNKEN))

    GUICtrlCreateLabel("Log-Klasse:", 320, 40, 100, 20)
    GUICtrlCreateInput($sClass, 430, 40, 160, 20, BitOR($ES_READONLY, $SS_SUNKEN))

    GUICtrlCreateLabel("Nachricht:", 10, 70, 100, 20)

    ; Mehrzeiliges Eingabefeld für die Nachricht
    Local $idMessageEdit = GUICtrlCreateEdit($sMessage, 10, 95, 580, 265, BitOR($ES_READONLY, $ES_WANTRETURN, $WS_VSCROLL, $ES_MULTILINE))
    GUICtrlSetFont($idMessageEdit, 9, 400, 0, "Consolas")

    ; Schließen-Button
    Local $idCloseButton = GUICtrlCreateButton("Schließen", 250, 370, 100, 25)

    ; GUI anzeigen
    GUISetState(@SW_SHOW, $hDetailGUI)

    ; Event-Schleife
    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $idCloseButton
                GUIDelete($hDetailGUI)
                ExitLoop
        EndSwitch
    WEnd
EndFunc

; Funktion zur Anzeige der Logeinträge in der ListView
Func _DisplayLogEntries($aEntries)
    ; ListView leeren
    _GUICtrlListView_DeleteAllItems($g_idLogListView)

    ; ListView-Style erweitern, um Tooltips zu unterstützen (falls noch nicht gesetzt)
    Local $hListView = GUICtrlGetHandle($g_idLogListView)
    Local $iStyle = _GUICtrlListView_GetExtendedListViewStyle($hListView)
    If BitAND($iStyle, $LVS_EX_INFOTIP) = 0 Then
        _GUICtrlListView_SetExtendedListViewStyle($hListView, BitOR($iStyle, $LVS_EX_INFOTIP))
    EndIf

    ; Leer-Prüfung
    If Not IsArray($aEntries) Or UBound($aEntries) = 0 Then
        GUICtrlSetData($g_idStatus, "Keine Logeinträge zum Anzeigen vorhanden.")
        Return
    EndIf

    ; Zählen der unvollständigen Einträge für Statusmeldung
    Local $iTruncatedCount = 0

    ; ListView in den Bearbeitungsmodus versetzen
    _GUICtrlListView_BeginUpdate($g_idLogListView)

    ; Einträge zur ListView hinzufügen
    For $i = 0 To UBound($aEntries) - 1
        ; Prüfen, ob es sich um einen unvollständigen Eintrag handelt
        Local $bIsTruncated = StringInStr($aEntries[$i][1], "TRUNCATED") > 0
        If $bIsTruncated Then
            $iTruncatedCount += 1

            ; Nachricht besonders markieren
            If Not StringInStr($aEntries[$i][3], "*** UNVOLLSTÄNDIG ***") Then
                $aEntries[$i][3] = "*** UNVOLLSTÄNDIG *** " & $aEntries[$i][3]
            EndIf

            ; Für Debug-Zwecke konsole schreiben
            ConsoleWrite("ANZEIGE: Unvollständiger Eintrag wird angezeigt: " & $aEntries[$i][0] & @CRLF)
            _LogInfo("Log-Viewer zeigt unvollständigen Eintrag an: " & $aEntries[$i][0])
        EndIf

        ; Eintrag zum ListView hinzufügen
        Local $iIndex = _GUICtrlListView_AddItem($g_idLogListView, $aEntries[$i][0]) ; Timestamp
        _GUICtrlListView_AddSubItem($g_idLogListView, $iIndex, $aEntries[$i][1], 1) ; Level
        _GUICtrlListView_AddSubItem($g_idLogListView, $iIndex, $aEntries[$i][2], 2) ; Class

        ; Spezialbehandlung für unvollständige Einträge bei der Anzeige
        If StringInStr($aEntries[$i][1], "TRUNCATED") Then
            ConsoleWrite("ANZEIGE: Unvollständiger Eintrag in ListView: " & $aEntries[$i][0] & @CRLF)
            _LogInfo("Unvollständiger Eintrag wird in ListView angezeigt: " & $aEntries[$i][0])

            ; Sicherstellen, dass die Nachricht klar markiert ist
            If Not StringInStr($aEntries[$i][3], "UNVOLLSTÄNDIG") Then
                $aEntries[$i][3] = "*** UNVOLLSTÄNDIGER EINTRAG *** " & $aEntries[$i][3]
            EndIf
        EndIf

        _GUICtrlListView_AddSubItem($g_idLogListView, $iIndex, $aEntries[$i][3], 3) ; Message

        ; Tooltip mit Zeileninfo hinzufügen
        Local $sTooltip = "Zeile " & $aEntries[$i][5] & " in der ursprünglichen Log-Datei"
        _GUICtrlListView_SetItemText($g_idLogListView, $iIndex, $sTooltip, 4) ; Tooltip im 5. (invis.) Feld speichern

        ; TRUNCATED speziell hervorheben im Tooltip
        If $bIsTruncated Then
            ; Erweiterten Tooltip mit zusätzlichen Infos setzen
            $sTooltip = "!!! UNVOLLSTÄNDIGER EINTRAG !!! Zeile " & $aEntries[$i][5] & " in der ursprünglichen Log-Datei"
            _GUICtrlListView_SetItemText($g_idLogListView, $iIndex, $sTooltip, 4)

            ; Zusätzliche Debug-Info
            ConsoleWrite("DISPLAY: TRUNCATED-Eintrag an Position " & $i & " wird angezeigt mit Zeilennummer " & $aEntries[$i][5] & @CRLF)
        EndIf
    Next

    ; ListView-Aktualisierung abschließen
    _GUICtrlListView_EndUpdate($g_idLogListView)

    ; Statusmeldung aktualisieren
    Local $sMessage = UBound($aEntries) & " Logeinträge angezeigt."
    If $iTruncatedCount > 0 Then
        $sMessage &= " (inkl. " & $iTruncatedCount & " unvollständige Einträge)"
    EndIf
    GUICtrlSetData($g_idStatus, $sMessage)
EndFunc

; Funktion zum Öffnen der ausgewählten Logdatei
Func _OpenSelectedLogFile()
    ; Ausgewählten Knoten im TreeView ermitteln
    Local $hSelected = _GUICtrlTreeView_GetSelection($g_idLogFileTree)
    If $hSelected = 0 Then Return

    ; Prüfen, ob es ein Dateieintrag ist (kein Verzeichnis)
    If _GUICtrlTreeView_GetChildren($g_idLogFileTree, $hSelected) = 0 Then
        ; VERBESSERT: Direkt den Text als Pfad verwenden (ursprüngliche Methode)
        Local $sFilePath = _GUICtrlTreeView_GetText($g_idLogFileTree, $hSelected)

        ; Debug-Ausgabe
        ConsoleWrite("_OpenSelectedLogFile: Gewählter Pfad = " & $sFilePath & @CRLF)

        ; Prüfen, ob eine gültige Datei ausgewählt wurde
        If $sFilePath <> "" And FileExists($sFilePath) Then
            ; Statusmeldung aktualisieren
            GUICtrlSetData($g_idStatus, "Öffne Logdatei: " & StringRegExpReplace($sFilePath, "^.*\\", ""))

            ; Logdatei öffnen
            _ViewerOpenLogFile($sFilePath)
        Else
            ; Debug-Information bei Fehler
            ConsoleWrite("_OpenSelectedLogFile: Datei existiert nicht oder Pfad ist leer" & @CRLF)
            If $sFilePath = "" Then
                ConsoleWrite("Pfad ist leer" & @CRLF)
            ElseIf Not FileExists($sFilePath) Then
                ConsoleWrite("Datei existiert nicht: " & $sFilePath & @CRLF)
            EndIf
        EndIf
    EndIf
EndFunc

; Funktion zum Öffnen einer Logdatei
Func _ViewerOpenLogFile($sFilePath)
    ; Statusmeldung aktualisieren
    GUICtrlSetData($g_idStatus, "Lade Logdatei: " & StringRegExpReplace($sFilePath, "^.*\\", ""))

    ; Aktuellen Pfad speichern
    $g_sCurrentLogFile = $sFilePath

    ; Logdatei parsen (Implementierung in missing_functions.au3)
    ConsoleWrite("DEBUG: _ViewerOpenLogFile ruft _ParseLogFile auf..." & @CRLF)
    Local $aLogEntries = _ParseLogFile($sFilePath)
    Local $iError = @error
    ConsoleWrite("DEBUG: _ParseLogFile zurückgekehrt, Error: " & $iError & @CRLF)
    
    If $iError Then
        ConsoleWrite("DEBUG: Parser-Fehler " & $iError & " bei Datei: " & $sFilePath & @CRLF)
        GUICtrlSetData($g_idStatus, "Fehler beim Laden der Logdatei! (Error: " & $iError & ")")
        MsgBox(16, "Fehler", "Die Logdatei konnte nicht geladen werden: " & @CRLF & $sFilePath & @CRLF & @CRLF & "Fehlercode: " & $iError)
        Return
    EndIf
    
    ConsoleWrite("DEBUG: Erfolgreich geparst, Array-Größe: " & UBound($aLogEntries) & @CRLF)
    If UBound($aLogEntries) = 0 Then
        ConsoleWrite("DEBUG: PROBLEM - Array ist leer!" & @CRLF)
        GUICtrlSetData($g_idStatus, "Keine Logeinträge in der Datei gefunden!")
        MsgBox(48, "Information", "Die Logdatei enthält keine erkennbaren Logeinträge: " & @CRLF & $sFilePath)
        Return
    EndIf

    ; Logeinträge global speichern
    $g_aCurrentLogEntries = $aLogEntries

    ; Filter-Dropdowns mit verfügbaren Werten befüllen
    _UpdateFilterDropdowns()

    ; Statistik erstellen und anzeigen
    _UpdateLogStatistics()

    ; NOTFALL-FUNKTION: Diesen Debug-Code immer ausführen, um zu checken, ob unvollständige Einträge vorhanden sind
    ; und welche Werte sie genau enthalten!
    ConsoleWrite("DEBUG CHECK: Durchsuche alle " & UBound($g_aCurrentLogEntries) & " Log-Einträge nach unvollständigen..." & @CRLF)
    Local $iFound = 0

    For $i = 0 To UBound($g_aCurrentLogEntries) - 1
        If StringInStr($g_aCurrentLogEntries[$i][1], "TRUNCATED") Then
            $iFound += 1
            ConsoleWrite("!!! GEFUNDEN #" & $iFound & " an Index " & $i & ":" & @CRLF)
            ConsoleWrite("  - Timestamp: " & $g_aCurrentLogEntries[$i][0] & @CRLF)
            ConsoleWrite("  - Level: " & $g_aCurrentLogEntries[$i][1] & @CRLF)
            ConsoleWrite("  - Class: " & $g_aCurrentLogEntries[$i][2] & @CRLF)
            ConsoleWrite("  - Message: " & StringLeft($g_aCurrentLogEntries[$i][3], 100) & "..." & @CRLF)
        EndIf
    Next

    ConsoleWrite("Insgesamt " & $iFound & " unvollständige Einträge in der aktuellen Liste gefunden." & @CRLF)

    ; Logeinträge anzeigen
    _DisplayLogEntries($g_aCurrentLogEntries)
EndFunc

; Hilfsfunktion zum Aktualisieren der Filterdropdowns
Func _UpdateFilterDropdowns()
    ; Wenn keine Logeinträge vorhanden, nichts tun
    If Not IsArray($g_aCurrentLogEntries) Or UBound($g_aCurrentLogEntries) = 0 Then Return

    ; Eindeutige Log-Levels ermitteln
    Local $aLevels = _GetUniqueLogLevels($g_aCurrentLogEntries)

    ; Log-Level-Dropdown befüllen
    GUICtrlSetData($g_idLogLevelCombo, "")
    GUICtrlSetData($g_idLogLevelCombo, $LOG_FILTER_ALL & "|" & _ArrayToString($aLevels, "|"))
    GUICtrlSetData($g_idLogLevelCombo, $LOG_FILTER_ALL)

    ; Eindeutige Log-Klassen ermitteln
    Local $aClasses = _GetUniqueLogClasses($g_aCurrentLogEntries)

    ; Log-Klassen-Dropdown befüllen
    GUICtrlSetData($g_idLogClassCombo, "")
    GUICtrlSetData($g_idLogClassCombo, $LOG_FILTER_ALL & "|" & _ArrayToString($aClasses, "|"))
    GUICtrlSetData($g_idLogClassCombo, $LOG_FILTER_ALL)
EndFunc

; Hilfsfunktion zum Aktualisieren der Logstatistik
Func _UpdateLogStatistics()
    ; Wenn keine Logeinträge vorhanden, nichts tun
    If Not IsArray($g_aCurrentLogEntries) Or UBound($g_aCurrentLogEntries) = 0 Then Return

    ; Statistik erstellen
    Local $oStats = _GetLogStatistics($g_aCurrentLogEntries)

    ; Statistiktext erstellen
    Local $sStats = "Logdatei: " & StringRegExpReplace($g_sCurrentLogFile, "^.*\\", "") & @CRLF
    $sStats &= "Gesamtzahl der Einträge: " & $oStats.Item("TotalEntries") & @CRLF

    ; Hervorhebung für unvollständige Einträge, falls vorhanden
    If $oStats.Exists("TruncatedEntries") And $oStats.Item("TruncatedEntries") > 0 Then
        $sStats &= @CRLF & "!!! ACHTUNG: " & $oStats.Item("TruncatedEntries") & " unvollständige Einträge gefunden !!!" & @CRLF

        ; Auflistung der unvollständigen Einträge
        $sStats &= "Unvollständige Einträge:" & @CRLF
        Local $iCount = 0

        For $i = 0 To UBound($g_aCurrentLogEntries) - 1
            If StringInStr($g_aCurrentLogEntries[$i][1], "TRUNCATED") Then
                $iCount += 1
                $sStats &= "  " & $iCount & ". Timestamp: " & $g_aCurrentLogEntries[$i][0] & @CRLF

                ; Konsolen-Ausgabe zur Sicherheit
                ConsoleWrite("LOG-VIEWER STATISTIK: Unvollständiger Eintrag #" & $iCount & ": " & $g_aCurrentLogEntries[$i][0] & @CRLF)
            EndIf
        Next

        $sStats &= @CRLF
    EndIf

    ; Level-Statistik
    $sStats &= "Log-Level Verteilung:" & @CRLF
    Local $oLevelStats = $oStats.Item("LevelStats")
    Local $vLevels = $oLevelStats.Keys()
    For $i = 0 To UBound($vLevels) - 1
        $sStats &= "  " & $vLevels[$i] & ": " & $oLevelStats.Item($vLevels[$i]) & @CRLF
    Next

    ; Statistik anzeigen
    GUICtrlSetData($g_idLogStats, $sStats)
EndFunc

; Funktion zum Umwandeln von RGB (0xRRGGBB) zu BGR (Windows API Format)
Func _SwapRGB($iColor)
    Local $iRed = BitAND(BitShift($iColor, 16), 0xFF)
    Local $iGreen = BitAND(BitShift($iColor, 8), 0xFF)
    Local $iBlue = BitAND($iColor, 0xFF)
    Return BitOR(BitShift($iBlue, -16), BitShift($iGreen, -8), $iRed)
EndFunc