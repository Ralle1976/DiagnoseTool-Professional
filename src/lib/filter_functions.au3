#include-once
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include "logging.au3"

Global $g_aOriginalData[0][0]  ; Speichert die originalen Daten
Global $g_bFilterActive = False

Func _StoreOriginalData()
    Local $hListView = GUICtrlGetHandle($g_idListView)
    Local $iItems = _GUICtrlListView_GetItemCount($hListView)
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)

    ReDim $g_aOriginalData[$iItems][$iColumns]

    For $i = 0 To $iItems - 1
        For $j = 0 To $iColumns - 1
            $g_aOriginalData[$i][$j] = _GUICtrlListView_GetItemText($hListView, $i, $j)
        Next
    Next
EndFunc

Func _ApplyListViewFilter($sColumn, $sCondition, $sValue, $bCaseSensitive)
    If Not $g_bFilterActive Then
        _StoreOriginalData()
        $g_bFilterActive = True
    EndIf

    Local $hListView = GUICtrlGetHandle($g_idListView)
    _GUICtrlListView_BeginUpdate($hListView)

    ; Spaltenindex finden
    Local $iColumnIndex = -1
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)
    For $i = 0 To $iColumns - 1
        If _GUICtrlListView_GetColumn($hListView, $i)[5] = $sColumn Then
            $iColumnIndex = $i
            ExitLoop
        EndIf
    Next

    If $iColumnIndex = -1 Then
        _LogError("Spalte nicht gefunden: " & $sColumn)
        Return -1
    EndIf

    ; Alle Einträge löschen
    _GUICtrlListView_DeleteAllItems($hListView)

    Local $iItems = UBound($g_aOriginalData)
    Local $iVisible = 0

    For $i = 0 To $iItems - 1
        Local $sItemText = $g_aOriginalData[$i][$iColumnIndex]
        Local $bMatch = False

        ; Groß-/Kleinschreibung berücksichtigen
        Local $sCompareText = $bCaseSensitive ? $sItemText : StringLower($sItemText)
        Local $sCompareValue = $bCaseSensitive ? $sValue : StringLower($sValue)

        Switch $sCondition
            Case "Enthält"
                $bMatch = StringInStr($sCompareText, $sCompareValue) > 0
            Case "Beginnt mit"
                $bMatch = StringLeft($sCompareText, StringLen($sCompareValue)) = $sCompareValue
            Case "Endet mit"
                $bMatch = StringRight($sCompareText, StringLen($sCompareValue)) = $sCompareValue
            Case "Ist gleich"
                $bMatch = $sCompareText = $sCompareValue
            Case "Ist größer als"
                $bMatch = Number($sCompareText) > Number($sCompareValue)
            Case "Ist kleiner als"
                $bMatch = Number($sCompareText) < Number($sCompareValue)
        EndSwitch

        ; Wenn der Eintrag dem Filter entspricht, fügen wir ihn hinzu
        If $bMatch Then
            Local $iIndex = _GUICtrlListView_AddItem($hListView, $g_aOriginalData[$i][0])
            For $j = 1 To _GUICtrlListView_GetColumnCount($hListView) - 1
                _GUICtrlListView_AddSubItem($hListView, $iIndex, $g_aOriginalData[$i][$j], $j)
            Next
            $iVisible += 1
        EndIf
    Next

    _GUICtrlListView_EndUpdate($hListView)
    _LogInfo("Filter angewendet: " & $iVisible & " von " & $iItems & " Einträgen sichtbar")

    Return $iVisible
EndFunc

Func _ResetListViewFilter()
    If Not $g_bFilterActive Then Return True

    Local $hListView = GUICtrlGetHandle($g_idListView)
    _GUICtrlListView_BeginUpdate($hListView)

    ; Alle aktuellen Einträge löschen
    _GUICtrlListView_DeleteAllItems($hListView)

    ; Originaldaten wiederherstellen
    For $i = 0 To UBound($g_aOriginalData) - 1
        Local $iIndex = _GUICtrlListView_AddItem($hListView, $g_aOriginalData[$i][0])
        For $j = 1 To _GUICtrlListView_GetColumnCount($hListView) - 1
            _GUICtrlListView_AddSubItem($hListView, $iIndex, $g_aOriginalData[$i][$j], $j)
        Next
    Next

    _GUICtrlListView_EndUpdate($hListView)

    ; Filter-Status zurücksetzen
    $g_bFilterActive = False
    ReDim $g_aOriginalData[0][0]  ; Speicher freigeben

    _LogInfo("Filter zurückgesetzt")
    GUICtrlSetData($g_idStatus, "Filter zurückgesetzt: Alle Einträge werden angezeigt.")
    Return True
EndFunc