# Variante 2: DropDown-Liste mit Vorschlägen unterhalb des RichEdit + Tastenauswahl + korrektes Ersetzen
#include <WindowsConstants.au3>
#include <GUIConstants.au3>

#include <WinAPIConv.au3>
#include <Misc.au3>
#include <WinAPISysWin.au3>
#include <SendMessage.au3>
#include <GuiEdit.au3>
#include <GuiRichEdit.au3>
#include <GuiListBox.au3>

Global $hGUI = GUICreate("SQL-AutoComplete", 600, 600)
Global $hEdit = _GUICtrlRichEdit_Create($hGUI, "", 10, 10, 580, 240, _
    BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))

; ListBox für Vorschläge
Global $hList = GUICtrlCreateList("", 10, 260, 200, 120, BitOR($WS_BORDER, $WS_VSCROLL))
GUICtrlSetState($hList, $GUI_HIDE)

GUISetState(@SW_SHOW)

; SQL-Keywords als Liste
Global $aKeywords[] = ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "JOIN", "INNER", "LEFT", "RIGHT", "ORDER", "GROUP", "BY", "HAVING", "VALUES"]

Global $sCurrentWord = ""
Global $iLastCursorPos = -1
Global $iWordStartPos = -1
Global $iWordEndPos = -1
Global $iListIndex = 0

AdlibRegister("CheckInput", 150)

While True
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit
        Case $hList
            AcceptSelection()
    EndSwitch

    If _IsPressed("1B") Then ; ESC blendet Vorschläge aus
        GUICtrlSetState($hList, $GUI_HIDE)
    EndIf

    If BitAND(GUICtrlGetState($hList), $GUI_SHOW) = $GUI_SHOW Then
        If _IsPressed("28") Then ; Pfeil runter
            $iListIndex += 1
            If $iListIndex >= _GUICtrlListBox_GetCount($hList) Then $iListIndex = 0
            _GUICtrlListBox_SetCurSel($hList, $iListIndex)
            Sleep(100)
        ElseIf _IsPressed("26") Then ; Pfeil hoch
            $iListIndex -= 1
            If $iListIndex < 0 Then $iListIndex = _GUICtrlListBox_GetCount($hList) - 1
            _GUICtrlListBox_SetCurSel($hList, $iListIndex)
            Sleep(100)
        ElseIf _IsPressed("0D") Or _IsPressed("09") Then ; Enter oder Tab
            AcceptSelection()
            Sleep(150)
        EndIf
    EndIf
WEnd

Func CheckInput()
    Local $aSel = _GUICtrlRichEdit_GetSel($hEdit)
    If @error Then Return
    Local $iCursorPos = $aSel[0]
    If $iCursorPos = $iLastCursorPos Then Return
    $iLastCursorPos = $iCursorPos

    Local $sText = _GUICtrlRichEdit_GetText($hEdit)
;~ 	ConsoleWrite($sText & @CRLF)
    $sCurrentWord = GetCurrentWord($sText, $iCursorPos, $iWordStartPos)
	$iWordEndPos = $iCursorPos
;~ 	ConsoleWrite($sCurrentWord & @CRLF)

    ; Liste filtern
    Local $sMatches = "", $sSearch = ""
    If $sCurrentWord <> "" Then
        For $i = 0 To UBound($aKeywords) - 1
			$sSearch = StringLeft($aKeywords[$i], StringLen($sCurrentWord))
			ConsoleWrite($sSearch & @CRLF)
			If $sSearch = $sCurrentWord Then
                $sMatches &= $aKeywords[$i] & "|"
            EndIf
        Next
    EndIf

    If $sMatches <> "" Then
        GUICtrlSetData($hList, StringTrimRight($sMatches, 1))
        GUICtrlSetState($hList, $GUI_SHOW)
        $iListIndex = 0
        _GUICtrlListBox_SetCurSel($hList, $iListIndex)
    Else
        GUICtrlSetState($hList, $GUI_HIDE)
    EndIf
EndFunc

Func GetCurrentWord($sText, $iCursorPos, ByRef $iStart)
    If $iCursorPos < 1 Then
        $iStart = 0
        Return ""
    EndIf
    $iStart = $iCursorPos
    While $iStart > 0 And StringRegExp(StringMid($sText, $iStart, 1), "[a-zA-Z]")
        $iStart -= 1
    WEnd
    $iStart += 1
    Return StringMid($sText, $iStart, $iCursorPos - $iStart)
EndFunc

Func AcceptSelection()
    Local $sItem = _GUICtrlListBox_GetText($hList, _GUICtrlListBox_GetCurSel($hList))
    If $sItem = "" Then Return
    _GUICtrlRichEdit_SetSel($hEdit, $iWordStartPos -1, $iWordEndPos)
	_GUICtrlRichEdit_ReplaceText($hEdit, $sItem)
    GUICtrlSetState($hList, $GUI_HIDE)
    $sCurrentWord = ""
EndFunc
