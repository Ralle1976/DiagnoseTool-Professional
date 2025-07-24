#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include "logging.au3"
#include "filter_functions.au3"
#include "export_functions.au3"



Func _DBViewerShowExport()
    Local $hExportGUI = GUICreate("Export", 400, 200, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU))

    ; Format auswählen
    GUICtrlCreateLabel("Exportformat:", 10, 10, 80, 20)
    Local $idFormat = GUICtrlCreateCombo("", 90, 8, 120, 20)
    GUICtrlSetData($idFormat, "CSV|Excel|JSON", "CSV")

    ; CSV-Optionen
    GUICtrlCreateGroup("CSV-Optionen", 10, 40, 380, 60)
    GUICtrlCreateLabel("Trennzeichen:", 20, 65, 80, 20)
    Local $idDelimiter = GUICtrlCreateInput(";", 100, 63, 30, 20)

    ; Buttons
    Local $idExport = GUICtrlCreateButton("Exportieren", 220, 160, 80, 25)
    Local $idCancel = GUICtrlCreateButton("Abbrechen", 310, 160, 80, 25)

    GUISetState(@SW_SHOW, $hExportGUI)

    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $idCancel
                GUIDelete($hExportGUI)
                Return

            Case $idExport
                Local $sFormat = GUICtrlRead($idFormat)
                Local $sFilename = ""
                Local $sFilter = ""
                Local $bSuccess = False

                ; Standard-Dateiname mit Tabellenname erstellen
                Local $sDefaultFileName = $g_sCurrentTable & "_Export"

                _LogInfo("Export gestartet - Format: " & $sFormat)
                Switch $sFormat
                    Case "CSV"
                        $sFilter = "CSV-Dateien (*.csv)"
                        $sFilename = FileSaveDialog("CSV exportieren", @DesktopDir, $sFilter, $FD_PATHMUSTEXIST + $FD_PROMPTOVERWRITE, $sDefaultFileName & ".csv")
                        If Not @error Then
                            $bSuccess = _ExportToCSV($sFilename, GUICtrlRead($idDelimiter))
                        EndIf

                    Case "Excel"
                        $sFilter = "Excel-Dateien (*.xlsx)"
                        $sFilename = FileSaveDialog("Excel exportieren", @DesktopDir, $sFilter, $FD_PATHMUSTEXIST + $FD_PROMPTOVERWRITE, $sDefaultFileName & ".xlsx")
                        If Not @error Then
                            $bSuccess = _ExportToExcel($sFilename)
                        EndIf

                    Case "JSON"
                        $sFilter = "JSON-Dateien (*.json)"
                        $sFilename = FileSaveDialog("JSON exportieren", @DesktopDir, $sFilter, $FD_PATHMUSTEXIST + $FD_PROMPTOVERWRITE, $sDefaultFileName & ".json")
                        If Not @error Then
                            $bSuccess = _ExportToJSON($sFilename)
                        EndIf
                EndSwitch

                If $sFilename = "" Then
                    _LogInfo("Export abgebrochen - Keine Datei ausgewählt")
                    ContinueLoop
                EndIf

                _LogInfo("Export wird ausgeführt nach: " & $sFilename)

                If $bSuccess Then
                    MsgBox(64, "Export erfolgreich", "Die Daten wurden erfolgreich exportiert:" & @CRLF & $sFilename)
                    GUIDelete($hExportGUI)
                    Return
                ElseIf $sFilename <> "" Then
                    MsgBox(16, "Fehler", "Beim Export ist ein Fehler aufgetreten.")
                EndIf
        EndSwitch
    WEnd
EndFunc

Func _DBViewerShowFilter()
    ; Erstelle das Filter-GUI mit modalen Style, damit es im Vordergrund bleibt
    Local $hFilterGUI = GUICreate("Filter", 400, 300, -1, -1, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_DLGFRAME), $WS_EX_TOPMOST)

    ; Spaltenauswahl
    GUICtrlCreateGroup("Spalte", 10, 10, 380, 60)
    GUICtrlCreateLabel("Filtern nach:", 20, 35, 70, 20)
    Local $idColumn = GUICtrlCreateCombo("", 100, 32, 200, 20)

    ; Verfügbare Spalten laden
    Local $aColumns = _GUICtrlListView_GetColumnCount($g_idListView)
    Local $sColumns = ""
    For $i = 0 To $aColumns - 1
        Local $aColInfo = _GUICtrlListView_GetColumn($g_idListView, $i)
        $sColumns &= $aColInfo[5] & "|"
    Next
    GUICtrlSetData($idColumn, StringTrimRight($sColumns, 1))
    Local $aFirstCol = _GUICtrlListView_GetColumn($g_idListView, 0)
    GUICtrlSetData($idColumn, $aFirstCol[5])

    ; Filterbedingungen
    GUICtrlCreateGroup("Filterbedingung", 10, 80, 380, 120)
    Local $idCondition = GUICtrlCreateCombo("", 20, 105, 150, 20)
    GUICtrlSetData($idCondition, "Enthält|Beginnt mit|Endet mit|Ist gleich|Ist größer als|Ist kleiner als", "Enthält")

    GUICtrlCreateLabel("Wert:", 20, 135, 40, 20)
    Local $idValue = GUICtrlCreateInput("", 70, 132, 310, 20)

    Local $idCaseSensitive = GUICtrlCreateCheckbox("Groß-/Kleinschreibung beachten", 20, 165, 200, 20)

    ; Statuszeile für Filterergebnisse
    Local $idStatus = GUICtrlCreateLabel("", 10, 210, 380, 20)

    ; Buttons
    Local $idApply = GUICtrlCreateButton("Anwenden", 130, 260, 80, 25)
    Local $idReset = GUICtrlCreateButton("Zurücksetzen", 220, 260, 80, 25)
    Local $idClose = GUICtrlCreateButton("Schließen", 310, 260, 80, 25)

    GUISetState(@SW_SHOW, $hFilterGUI)

    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $idClose
                GUIDelete($hFilterGUI)
                Return

            Case $idReset
                _ResetListViewFilter()
                GUICtrlSetData($idStatus, "Filter zurückgesetzt: Alle Einträge werden angezeigt.")
                GUICtrlSetData($idValue, "") ; Filterfeld leeren

            Case $idApply
                Local $sColumn = GUICtrlRead($idColumn)
                Local $sCondition = GUICtrlRead($idCondition)
                Local $sValue = GUICtrlRead($idValue)
                Local $bCaseSensitive = BitAND(GUICtrlRead($idCaseSensitive), $GUI_CHECKED)

                If $sValue = "" Then
                    GUICtrlSetData($idStatus, "Fehler: Bitte einen Suchwert eingeben.")
                    ContinueLoop
                EndIf

                Local $iFiltered = _ApplyListViewFilter($sColumn, $sCondition, $sValue, $bCaseSensitive)
                If $iFiltered >= 0 Then
                    GUICtrlSetData($idStatus, $iFiltered & " Einträge gefunden. Filter aktiv.")
                Else
                    GUICtrlSetData($idStatus, "Fehler beim Anwenden des Filters.")
                EndIf
        EndSwitch
    WEnd
EndFunc