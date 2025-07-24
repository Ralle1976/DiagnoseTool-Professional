; ===============================================================================================================================
; Titel.......: Modernes UI-Design für SQL-Editor
; Beschreibung: Verbessert das visuelle Design des SQL-Editors mit GDI+ und Custom Controls
; Autor.......: Ralle1976
; Erstellt....: 2025-07-24
; ===============================================================================================================================

#include-once
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <GuiRichEdit.au3>
#include <GuiButton.au3>
#include <GuiListBox.au3>

; Moderne Farbpalette (VS Code Dark Theme inspiriert)
Global Const $COLOR_BACKGROUND = 0x1E1E1E
Global Const $COLOR_EDITOR_BG = 0x252526
Global Const $COLOR_BUTTON_BG = 0x3C3C3C
Global Const $COLOR_BUTTON_HOVER = 0x505050
Global Const $COLOR_ACCENT = 0x007ACC
Global Const $COLOR_TEXT = 0xCCCCCC
Global Const $COLOR_KEYWORD = 0x569CD6
Global Const $COLOR_STRING = 0xCE9178
Global Const $COLOR_COMMENT = 0x6A9955
Global Const $COLOR_FUNCTION = 0xDCDCAA

; ===============================================================================================================================
; Func.....: _CreateModernSQLPanel
; Beschreibung: Erstellt ein modernes SQL-Editor-Panel mit verbessertem Design
; Parameter.: $hGUI - Parent GUI Handle
;             $x, $y, $width, $height - Position und Größe
; Rückgabe..: Array mit Control-IDs
; ===============================================================================================================================
Func _CreateModernSQLPanel($hGUI, $x, $y, $width, $height)
    Local $aControls[10]
    
    ; GDI+ initialisieren für moderne Grafiken
    _GDIPlus_Startup()
    
    ; Hintergrund-Panel mit abgerundeten Ecken
    $aControls[0] = GUICtrlCreateLabel("", $x, $y, $width, $height)
    GUICtrlSetBkColor($aControls[0], $COLOR_BACKGROUND)
    
    ; Titel-Bereich
    Local $hTitleLabel = GUICtrlCreateLabel("SQL Editor", $x + 10, $y + 5, $width - 20, 30)
    GUICtrlSetFont($hTitleLabel, 14, 600, 0, "Segoe UI")
    GUICtrlSetColor($hTitleLabel, $COLOR_TEXT)
    GUICtrlSetBkColor($hTitleLabel, $COLOR_BACKGROUND)
    
    ; Moderne Buttons mit Icons (simuliert)
    Local $btnY = $y + 40
    Local $btnWidth = 110
    Local $btnHeight = 32
    Local $btnSpacing = 5
    
    ; Ausführen-Button (mit Play-Icon-Simulation)
    $aControls[1] = _CreateModernButton($hGUI, "▶ Ausführen", $x + 10, $btnY, $btnWidth, $btnHeight, $COLOR_ACCENT)
    
    ; Speichern-Button
    $aControls[2] = _CreateModernButton($hGUI, "💾 Speichern", $x + 10 + $btnWidth + $btnSpacing, $btnY, $btnWidth, $btnHeight)
    
    ; Laden-Button
    $aControls[3] = _CreateModernButton($hGUI, "📁 Laden", $x + 10 + 2*($btnWidth + $btnSpacing), $btnY, $btnWidth, $btnHeight)
    
    ; Autovervollständigung-Button
    $aControls[4] = _CreateModernButton($hGUI, "🔍 IntelliSense", $x + 10 + 3*($btnWidth + $btnSpacing), $btnY, $btnWidth + 20, $btnHeight)
    
    ; Zurück-Button (rechts ausgerichtet)
    $aControls[5] = _CreateModernButton($hGUI, "← Zurück", $x + $width - $btnWidth - 10, $btnY, $btnWidth, $btnHeight, 0x505050)
    
    ; Editor-Bereich mit modernem Stil
    Local $editorY = $btnY + $btnHeight + 10
    Local $editorHeight = $height - ($editorY - $y) - 10
    
    ; RichEdit mit dunklem Theme
    $aControls[6] = _GUICtrlRichEdit_Create($hGUI, "", $x + 10, $editorY, $width - 20, $editorHeight, _
        BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN, $ES_NOHIDESEL))
    
    ; Editor-Stil anpassen
    _GUICtrlRichEdit_SetBkColor($aControls[6], $COLOR_EDITOR_BG)
    _GUICtrlRichEdit_SetFont($aControls[6], 11, "Consolas")
    _GUICtrlRichEdit_SetCharColor($aControls[6], $COLOR_TEXT)
    
    ; Zeilen-Nummern-Bereich (simuliert)
    Local $hLineNumbers = GUICtrlCreateLabel("1" & @CRLF & "2" & @CRLF & "3" & @CRLF & "4" & @CRLF & "5", _
        $x + 10, $editorY, 30, $editorHeight)
    GUICtrlSetFont($hLineNumbers, 10, 400, 0, "Consolas")
    GUICtrlSetColor($hLineNumbers, 0x858585)
    GUICtrlSetBkColor($hLineNumbers, $COLOR_BACKGROUND)
    
    Return $aControls
EndFunc

; ===============================================================================================================================
; Func.....: _CreateModernButton
; Beschreibung: Erstellt einen modernen Button mit Hover-Effekt
; Parameter.: $hGUI - Parent GUI
;             $sText - Button-Text
;             $x, $y, $width, $height - Position und Größe
;             $color - Hintergrundfarbe (optional)
; Rückgabe..: Control-ID des Buttons
; ===============================================================================================================================
Func _CreateModernButton($hGUI, $sText, $x, $y, $width, $height, $color = $COLOR_BUTTON_BG)
    Local $idButton = GUICtrlCreateButton($sText, $x, $y, $width, $height)
    
    ; Moderne Schriftart
    GUICtrlSetFont($idButton, 10, 500, 0, "Segoe UI")
    GUICtrlSetColor($idButton, $COLOR_TEXT)
    GUICtrlSetBkColor($idButton, $color)
    
    ; Flacher Button-Stil
    GUICtrlSetStyle($idButton, $BS_FLAT)
    
    Return $idButton
EndFunc

; ===============================================================================================================================
; Func.....: _CreateModernAutoCompleteList
; Beschreibung: Erstellt eine moderne Autovervollständigungsliste
; Parameter.: $hGUI - Parent GUI
;             $x, $y - Position
; Rückgabe..: Handle der Liste
; ===============================================================================================================================
Func _CreateModernAutoCompleteList($hGUI, $x, $y)
    Local $width = 300
    Local $height = 200
    
    ; Schatten-Effekt (simuliert mit mehreren Labels)
    For $i = 3 To 1 Step -1
        Local $shadow = GUICtrlCreateLabel("", $x + $i, $y + $i, $width, $height)
        GUICtrlSetBkColor($shadow, 0x000000)
        GUICtrlSetState($shadow, $GUI_DISABLE)
        WinSetTrans(GUICtrlGetHandle($shadow), "", 50 * $i)
    Next
    
    ; Hauptliste
    Local $idList = GUICtrlCreateList("", $x, $y, $width, $height, _
        BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY, $LBS_NOINTEGRALHEIGHT))
    
    ; Moderner Stil
    GUICtrlSetFont($idList, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($idList, $COLOR_EDITOR_BG)
    GUICtrlSetColor($idList, $COLOR_TEXT)
    
    ; Beispiel-Einträge mit Icons
    Local $aItems = [ _
        "📘 SELECT", _
        "📘 FROM", _
        "📘 WHERE", _
        "📘 JOIN", _
        "🔧 COUNT()", _
        "🔧 SUM()", _
        "🔧 AVG()", _
        "📊 users", _
        "📊 products", _
        "📊 orders" _
    ]
    
    For $item In $aItems
        GUICtrlSetData($idList, $item)
    Next
    
    Return $idList
EndFunc

; ===============================================================================================================================
; Func.....: _ApplyModernSyntaxHighlighting
; Beschreibung: Wendet modernes Syntax-Highlighting auf den SQL-Text an
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
;             $sText - Der SQL-Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ApplyModernSyntaxHighlighting($hRichEdit, $sText)
    ; Keywords
    Local $aKeywords = ["SELECT", "FROM", "WHERE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", _
                       "ORDER", "BY", "GROUP", "HAVING", "INSERT", "UPDATE", "DELETE", "CREATE", _
                       "ALTER", "DROP", "TABLE", "INDEX", "VIEW", "AS", "ON", "AND", "OR", "NOT"]
    
    ; Funktionen
    Local $aFunctions = ["COUNT", "SUM", "AVG", "MIN", "MAX", "UPPER", "LOWER", "LENGTH", _
                        "SUBSTR", "TRIM", "COALESCE", "CAST", "DATE", "NOW"]
    
    ; Text zurücksetzen
    _GUICtrlRichEdit_SetSel($hRichEdit, 0, -1)
    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_TEXT)
    
    ; Keywords highlighten
    For $keyword In $aKeywords
        Local $iPos = 0
        While True
            $iPos = StringInStr($sText, $keyword, 0, 1, $iPos + 1)
            If $iPos = 0 Then ExitLoop
            
            _GUICtrlRichEdit_SetSel($hRichEdit, $iPos - 1, $iPos - 1 + StringLen($keyword))
            _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_KEYWORD)
        WEnd
    Next
    
    ; Funktionen highlighten
    For $func In $aFunctions
        Local $iPos = 0
        While True
            $iPos = StringInStr($sText, $func & "(", 0, 1, $iPos + 1)
            If $iPos = 0 Then ExitLoop
            
            _GUICtrlRichEdit_SetSel($hRichEdit, $iPos - 1, $iPos - 1 + StringLen($func))
            _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_FUNCTION)
        WEnd
    Next
    
    ; Strings highlighten (einfache Anführungszeichen)
    Local $aStrings = StringRegExp($sText, "'[^']*'", 3)
    If IsArray($aStrings) Then
        For $string In $aStrings
            Local $iPos = StringInStr($sText, $string)
            If $iPos > 0 Then
                _GUICtrlRichEdit_SetSel($hRichEdit, $iPos - 1, $iPos - 1 + StringLen($string))
                _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_STRING)
            EndIf
        Next
    EndIf
    
    ; Kommentare highlighten
    Local $aLines = StringSplit($sText, @CRLF, 1)
    Local $iCurrentPos = 0
    For $i = 1 To $aLines[0]
        If StringLeft(StringStripWS($aLines[$i], 1), 2) = "--" Then
            _GUICtrlRichEdit_SetSel($hRichEdit, $iCurrentPos, $iCurrentPos + StringLen($aLines[$i]))
            _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_COMMENT)
        EndIf
        $iCurrentPos += StringLen($aLines[$i]) + 2 ; +2 für @CRLF
    Next
    
    ; Cursor ans Ende setzen
    _GUICtrlRichEdit_SetSel($hRichEdit, -1, -1)
EndFunc

; ===============================================================================================================================
; Func.....: _CreateSQLEditorStatusBar
; Beschreibung: Erstellt eine moderne Statusleiste für den SQL-Editor
; Parameter.: $hGUI - Parent GUI
;             $x, $y, $width - Position und Breite
; Rückgabe..: Control-ID der Statusleiste
; ===============================================================================================================================
Func _CreateSQLEditorStatusBar($hGUI, $x, $y, $width)
    Local $height = 25
    
    ; Hintergrund
    Local $idBg = GUICtrlCreateLabel("", $x, $y, $width, $height)
    GUICtrlSetBkColor($idBg, $COLOR_BUTTON_BG)
    
    ; Status-Text
    Local $idStatus = GUICtrlCreateLabel("Bereit | Zeile: 1, Spalte: 1 | SQL-Modus", $x + 10, $y + 3, $width - 200, 20)
    GUICtrlSetFont($idStatus, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idStatus, $COLOR_TEXT)
    GUICtrlSetBkColor($idStatus, $COLOR_BUTTON_BG)
    
    ; Verbindungsstatus (rechts)
    Local $idConnection = GUICtrlCreateLabel("🟢 Verbunden", $x + $width - 100, $y + 3, 90, 20)
    GUICtrlSetFont($idConnection, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($idConnection, 0x4EC94E)
    GUICtrlSetBkColor($idConnection, $COLOR_BUTTON_BG)
    
    Return $idStatus
EndFunc

; ===============================================================================================================================
; Beispiel für die Verwendung
; ===============================================================================================================================
Func _DemoModernSQLEditor()
    Local $hGUI = GUICreate("Moderner SQL Editor", 800, 600)
    GUISetBkColor($COLOR_BACKGROUND)
    
    ; Modernes SQL-Panel erstellen
    Local $aControls = _CreateModernSQLPanel($hGUI, 10, 10, 780, 550)
    
    ; Statusleiste
    _CreateSQLEditorStatusBar($hGUI, 10, 565, 780)
    
    ; Beispiel-SQL mit Syntax-Highlighting
    Local $sSQL = "-- Beispiel SQL Query" & @CRLF & _
                  "SELECT " & @CRLF & _
                  "    u.id," & @CRLF & _
                  "    u.name," & @CRLF & _
                  "    COUNT(o.id) as order_count" & @CRLF & _
                  "FROM users u" & @CRLF & _
                  "LEFT JOIN orders o ON u.id = o.user_id" & @CRLF & _
                  "WHERE u.active = 1" & @CRLF & _
                  "GROUP BY u.id, u.name" & @CRLF & _
                  "HAVING COUNT(o.id) > 5" & @CRLF & _
                  "ORDER BY order_count DESC;"
    
    _GUICtrlRichEdit_SetText($aControls[6], $sSQL)
    _ApplyModernSyntaxHighlighting($aControls[6], $sSQL)
    
    GUISetState(@SW_SHOW)
    
    ; Event-Loop
    While 1
        Local $msg = GUIGetMsg()
        If $msg = $GUI_EVENT_CLOSE Then ExitLoop
    WEnd
    
    _GUICtrlRichEdit_Destroy($aControls[6])
    _GDIPlus_Shutdown()
    GUIDelete()
EndFunc