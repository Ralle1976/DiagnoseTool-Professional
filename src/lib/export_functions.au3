#include-once
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include "logging.au3"

Func _ExportToCSV($sFilePath, $sDelimiter)
    _LogInfo("CSV-Export wird gestartet nach: " & $sFilePath)
    
    ; Prüfe ListView
    If _GUICtrlListView_GetItemCount($g_idListView) = 0 Then
        _LogError("Keine Daten zum Exportieren vorhanden")
        MsgBox(16, "Fehler", "Es sind keine Daten zum Exportieren vorhanden.")
        Return False
    EndIf
    
    ; Öffne Datei
    Local $hFile = FileOpen($sFilePath, $FO_OVERWRITE + $FO_UTF8)
    If $hFile = -1 Then
        _LogError("Konnte Exportdatei nicht erstellen: " & $sFilePath)
        Return False
    EndIf

    ; Spaltennamen exportieren
    Local $iColumns = _GUICtrlListView_GetColumnCount($g_idListView)
    For $i = 0 To $iColumns - 1
        FileWrite($hFile, _GUICtrlListView_GetColumn($g_idListView, $i)[5])
        If $i < $iColumns - 1 Then FileWrite($hFile, $sDelimiter)
    Next
    FileWrite($hFile, @CRLF)

    ; Daten exportieren
    Local $iItems = _GUICtrlListView_GetItemCount($g_idListView)
    For $i = 0 To $iItems - 1
        For $j = 0 To $iColumns - 1
            Local $sText = _GUICtrlListView_GetItemText($g_idListView, $i, $j)
            ; CSV-Escape: Wenn der Text das Trennzeichen enthält, in Anführungszeichen setzen
            If StringInStr($sText, $sDelimiter) Then
                $sText = '"' & StringReplace($sText, '"', '""') & '"'
            EndIf
            FileWrite($hFile, $sText)
            If $j < $iColumns - 1 Then FileWrite($hFile, $sDelimiter)
        Next
        FileWrite($hFile, @CRLF)
    Next

    FileClose($hFile)
    If FileExists($sFilePath) Then
        _LogInfo("CSV-Export erfolgreich abgeschlossen: " & $sFilePath)
        Return True
    Else
        _LogError("CSV-Export fehlgeschlagen - Datei wurde nicht erstellt")
        Return False
    EndIf
EndFunc

Func _ExportToExcel($sFilePath)
    Local $oExcel = ObjCreate("Excel.Application")
    If @error Then
        _LogError("Excel konnte nicht gestartet werden")
        MsgBox(16, "Fehler", "Excel ist nicht installiert oder konnte nicht gestartet werden.")
        Return False
    EndIf

    $oExcel.Visible = False
    $oExcel.DisplayAlerts = False

    Local $oWorkbook = $oExcel.Workbooks.Add()
    Local $oSheet = $oWorkbook.Worksheets(1)

    ; Spaltennamen exportieren
    Local $iColumns = _GUICtrlListView_GetColumnCount($g_idListView)
    For $i = 0 To $iColumns - 1
        $oSheet.Cells(1, $i + 1).Value = _GUICtrlListView_GetColumn($g_idListView, $i)[5]
        $oSheet.Cells(1, $i + 1).Font.Bold = True
    Next

    ; Daten exportieren
    Local $iItems = _GUICtrlListView_GetItemCount($g_idListView)
    For $i = 0 To $iItems - 1
        For $j = 0 To $iColumns - 1
            $oSheet.Cells($i + 2, $j + 1).Value = _GUICtrlListView_GetItemText($g_idListView, $i, $j)
        Next
    Next

    ; Formatierung
    $oSheet.Range($oSheet.Cells(1, 1), $oSheet.Cells($iItems + 1, $iColumns)).Borders.LineStyle = 1
    $oSheet.Range($oSheet.Cells(1, 1), $oSheet.Cells(1, $iColumns)).Interior.ColorIndex = 15
    $oSheet.Columns.AutoFit()

    ; Speichern und aufräumen
    $oWorkbook.SaveAs($sFilePath)
    $oWorkbook.Close()
    $oExcel.Quit()

    _LogInfo("Excel-Export abgeschlossen: " & $sFilePath)
    Return True
EndFunc

Func _ExportToJSON($sFilePath)
    Local $hFile = FileOpen($sFilePath, $FO_OVERWRITE + $FO_UTF8)
    If $hFile = -1 Then
        _LogError("Konnte JSON-Datei nicht erstellen: " & $sFilePath)
        Return False
    EndIf

    ; Spaltennamen ermitteln
    Local $iColumns = _GUICtrlListView_GetColumnCount($g_idListView)
    Local $aColumns[$iColumns]
    For $i = 0 To $iColumns - 1
        $aColumns[$i] = _GUICtrlListView_GetColumn($g_idListView, $i)[5]
    Next

    FileWrite($hFile, "[" & @CRLF)

    ; Daten exportieren
    Local $iItems = _GUICtrlListView_GetItemCount($g_idListView)
    For $i = 0 To $iItems - 1
        FileWrite($hFile, "  {" & @CRLF)
        For $j = 0 To $iColumns - 1
            Local $sValue = _GUICtrlListView_GetItemText($g_idListView, $i, $j)
            ; JSON-Escape
            $sValue = StringReplace($sValue, '\', '\\')
            $sValue = StringReplace($sValue, '"', '\"')
            $sValue = StringReplace($sValue, @CRLF, '\n')
            FileWrite($hFile, '    "' & $aColumns[$j] & '": "' & $sValue & '"')
            If $j < $iColumns - 1 Then FileWrite($hFile, ",")
            FileWrite($hFile, @CRLF)
        Next
        FileWrite($hFile, "  }")
        If $i < $iItems - 1 Then FileWrite($hFile, ",")
        FileWrite($hFile, @CRLF)
    Next

    FileWrite($hFile, "]" & @CRLF)
    FileClose($hFile)

    _LogInfo("JSON-Export abgeschlossen: " & $sFilePath)
    Return True
EndFunc