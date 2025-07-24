#include-once
#include <GuiListView.au3>
#include <Array.au3>
#include <Clipboard.au3>
#include <ListViewConstants.au3>
#include <WinAPIConstants.au3>



; Kopieren einer einzelnen Zelle
Func _ListView_CopyCell($hListView, $iRow, $iCol)
    Local $sText = _GUICtrlListView_GetItemText($hListView, $iRow, $iCol)
    Return _ClipBoard_SetData($sText)
EndFunc

; Kopieren einer ganzen Zeile
Func _ListView_CopyRow($hListView, $iRow)
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)
    Local $aRow[$iColumns]

    For $i = 0 To $iColumns - 1
        $aRow[$i] = _GUICtrlListView_GetItemText($hListView, $iRow, $i)
    Next

    Return _ClipBoard_SetData(_ArrayToString($aRow, "|"))
EndFunc

; Kopieren einer Spalte
Func _ListView_CopyColumn($hListView, $iCol)
    Local $iRows = _GUICtrlListView_GetItemCount($hListView)
    Local $aColumn[$iRows]

    For $i = 0 To $iRows - 1
        $aColumn[$i] = _GUICtrlListView_GetItemText($hListView, $i, $iCol)
    Next

    Return _ClipBoard_SetData(_ArrayToString($aColumn, @CRLF))
EndFunc

; Kopieren eines markierten Bereichs
Func _ListView_CopySelection($hListView)
    Local $aSelected = _GUICtrlListView_GetSelectedIndices($hListView, True)
    If Not IsArray($aSelected) Then Return False

    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)
    Local $sResult = ""

    For $i = 1 To $aSelected[0]
        Local $iRow = $aSelected[$i]
        Local $aRowData[$iColumns]

        For $j = 0 To $iColumns - 1
            $aRowData[$j] = _GUICtrlListView_GetItemText($hListView, $iRow, $j)
        Next

        $sResult &= _ArrayToString($aRowData, "|") & @CRLF
    Next

    Return _ClipBoard_SetData($sResult)
EndFunc

; Kopieren mit Spaltenüberschriften
Func _ListView_CopyWithHeaders($hListView, $bSelection = False)
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)
    Local $aHeaders[$iColumns]

    ; Spaltenüberschriften holen
    For $i = 0 To $iColumns - 1
        Local $tColumn = DllStructCreate($tagLVCOLUMN)
        DllStructSetData($tColumn, "Mask", $LVCF_TEXT)
        DllStructSetData($tColumn, "TextMax", 260)
        Local $tText = DllStructCreate("wchar Text[260]")
        DllStructSetData($tColumn, "Text", DllStructGetPtr($tText))
        _GUICtrlListView_GetColumn($hListView, $i)
        $aHeaders[$i] = DllStructGetData($tText, "Text")
    Next

    Local $sResult = _ArrayToString($aHeaders, "|") & @CRLF

    If $bSelection Then
        Local $aSelected = _GUICtrlListView_GetSelectedIndices($hListView, True)
        If Not IsArray($aSelected) Then Return False

        For $i = 1 To $aSelected[0]
            Local $iRow = $aSelected[$i]
            Local $aRowData[$iColumns]

            For $j = 0 To $iColumns - 1
                $aRowData[$j] = _GUICtrlListView_GetItemText($hListView, $iRow, $j)
            Next

            $sResult &= _ArrayToString($aRowData, "|") & @CRLF
        Next
    Else
        Local $iRows = _GUICtrlListView_GetItemCount($hListView)

        For $i = 0 To $iRows - 1
            Local $aRowData[$iColumns]

            For $j = 0 To $iColumns - 1
                $aRowData[$j] = _GUICtrlListView_GetItemText($hListView, $i, $j)
            Next

            $sResult &= _ArrayToString($aRowData, "|") & @CRLF
        Next
    EndIf

    Return _ClipBoard_SetData($sResult)
EndFunc