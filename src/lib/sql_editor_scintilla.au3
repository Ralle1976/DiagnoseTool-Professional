; ===============================================================================================================================
; Titel.......: SQL-Editor mit Scintilla Control
; Beschreibung: Moderne SQL-Editor-Implementierung mit Scintilla für besseres UI/UX
; Autor.......: Ralle1976
; Erstellt....: 2025-07-24
; ===============================================================================================================================

#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <SendMessage.au3>

; Scintilla Konstanten
Global Const $SCI_SETLEXER = 4001
Global Const $SCI_SETLEXERLANGUAGE = 4006
Global Const $SCI_STYLESETFONT = 2056
Global Const $SCI_STYLESETSIZE = 2055
Global Const $SCI_STYLESETFORE = 2052
Global Const $SCI_STYLESETBACK = 2053
Global Const $SCI_STYLECLEARALL = 2050
Global Const $SCI_SETMARGINWIDTHN = 2242
Global Const $SCI_SETCODEPAGE = 2037
Global Const $SCI_SETINDENTATIONGUIDES = 2132
Global Const $SCI_SETVIEWWS = 2021
Global Const $SCI_SETWRAPMODE = 2268
Global Const $SCI_AUTOCSHOW = 2100
Global Const $SCI_AUTOCCANCEL = 2101
Global Const $SCI_AUTOCACTIVE = 2102
Global Const $SCI_AUTOCPOSSTART = 2103
Global Const $SCI_AUTOCSETSEPARATOR = 2106
Global Const $SCI_AUTOCSETIGNORECASE = 2115
Global Const $SCI_AUTOCSETAUTOHIDE = 2118
Global Const $SCI_AUTOCSETDROPRESTOFWORD = 2270
Global Const $SCI_CALLTIPSHOW = 2200
Global Const $SCI_CALLTIPCANCEL = 2201

; SQL Lexer
Global Const $SCLEX_SQL = 7

; SQL Styles
Global Const $SCE_SQL_DEFAULT = 0
Global Const $SCE_SQL_COMMENT = 1
Global Const $SCE_SQL_COMMENTLINE = 2
Global Const $SCE_SQL_COMMENTDOC = 3
Global Const $SCE_SQL_NUMBER = 4
Global Const $SCE_SQL_WORD = 5
Global Const $SCE_SQL_STRING = 6
Global Const $SCE_SQL_CHARACTER = 7
Global Const $SCE_SQL_SQLPLUS = 8
Global Const $SCE_SQL_SQLPLUS_PROMPT = 9
Global Const $SCE_SQL_OPERATOR = 10
Global Const $SCE_SQL_IDENTIFIER = 11
Global Const $SCE_SQL_SQLPLUS_COMMENT = 13
Global Const $SCE_SQL_COMMENTLINEDOC = 15
Global Const $SCE_SQL_WORD2 = 16
Global Const $SCE_SQL_COMMENTDOCKEYWORD = 17
Global Const $SCE_SQL_COMMENTDOCKEYWORDERROR = 18
Global Const $SCE_SQL_USER1 = 19
Global Const $SCE_SQL_USER2 = 20
Global Const $SCE_SQL_USER3 = 21
Global Const $SCE_SQL_USER4 = 22
Global Const $SCE_SQL_QUOTEDIDENTIFIER = 23

; Globale Variablen
Global $g_hScintilla = 0
Global $g_hScintillaDLL = 0

; ===============================================================================================================================
; Func.....: _InitScintillaSQLEditor
; Beschreibung: Initialisiert den SQL-Editor mit Scintilla Control
; Parameter.: $hGUI - Handle des Parent-Fensters
;             $x, $y, $width, $height - Position und Größe
; Rückgabe..: Handle des Scintilla-Controls bei Erfolg, 0 bei Fehler
; ===============================================================================================================================
Func _InitScintillaSQLEditor($hGUI, $x, $y, $width, $height)
    ; Scintilla DLL laden
    $g_hScintillaDLL = DllOpen(@ScriptDir & "\SciLexer.dll")
    If $g_hScintillaDLL = -1 Then
        ; Fallback: Versuche System-Scintilla
        $g_hScintillaDLL = DllOpen("SciLexer.dll")
        If $g_hScintillaDLL = -1 Then
            MsgBox(16, "Fehler", "SciLexer.dll konnte nicht geladen werden!")
            Return 0
        EndIf
    EndIf
    
    ; Scintilla Control erstellen
    $g_hScintilla = _WinAPI_CreateWindowEx($WS_EX_CLIENTEDGE, "Scintilla", "", _
        BitOR($WS_CHILD, $WS_VISIBLE, $WS_TABSTOP, $WS_VSCROLL, $WS_HSCROLL), _
        $x, $y, $width, $height, $hGUI)
    
    If Not IsHWnd($g_hScintilla) Then
        DllClose($g_hScintillaDLL)
        Return 0
    EndIf
    
    ; Scintilla konfigurieren
    _ConfigureScintillaSQL()
    
    Return $g_hScintilla
EndFunc

; ===============================================================================================================================
; Func.....: _ConfigureScintillaSQL
; Beschreibung: Konfiguriert Scintilla für SQL-Syntax-Highlighting
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ConfigureScintillaSQL()
    ; SQL Lexer setzen
    _SendMessage($g_hScintilla, $SCI_SETLEXER, $SCLEX_SQL, 0)
    
    ; Codepage auf UTF-8 setzen
    _SendMessage($g_hScintilla, $SCI_SETCODEPAGE, 65001, 0)
    
    ; Font für alle Styles setzen
    _SendMessage($g_hScintilla, $SCI_STYLECLEARALL, 0, 0)
    
    ; Moderne Farbschema für SQL (Dark Theme)
    Local $aColors[][] = [ _
        [$SCE_SQL_DEFAULT, 0xF8F8F2, 0x282A36], _ ; Default: Weiß auf Dunkelgrau
        [$SCE_SQL_COMMENT, 0x6272A4, 0x282A36], _ ; Kommentare: Grau
        [$SCE_SQL_COMMENTLINE, 0x6272A4, 0x282A36], _ ; Zeilenkommentare
        [$SCE_SQL_NUMBER, 0xBD93F9, 0x282A36], _ ; Zahlen: Lila
        [$SCE_SQL_WORD, 0xFF79C6, 0x282A36], _ ; Keywords: Pink
        [$SCE_SQL_STRING, 0xF1FA8C, 0x282A36], _ ; Strings: Gelb
        [$SCE_SQL_OPERATOR, 0x50FA7B, 0x282A36], _ ; Operatoren: Grün
        [$SCE_SQL_IDENTIFIER, 0x8BE9FD, 0x282A36], _ ; Identifiers: Cyan
        [$SCE_SQL_WORD2, 0xFFB86C, 0x282A36], _ ; Funktionen: Orange
        [$SCE_SQL_USER1, 0xFF5555, 0x282A36], _ ; Tabellennamen: Rot
        [$SCE_SQL_USER2, 0x50FA7B, 0x282A36] _ ; Spaltennamen: Grün
    ]
    
    ; Farben anwenden
    For $i = 0 To UBound($aColors) - 1
        _SendMessage($g_hScintilla, $SCI_STYLESETFORE, $aColors[$i][0], $aColors[$i][1])
        _SendMessage($g_hScintilla, $SCI_STYLESETBACK, $aColors[$i][0], $aColors[$i][2])
    Next
    
    ; Font-Einstellungen
    Local $sFont = "Consolas"
    Local $iFontSize = 11
    
    For $i = 0 To 127
        _ScintillaSendString($g_hScintilla, $SCI_STYLESETFONT, $i, $sFont)
        _SendMessage($g_hScintilla, $SCI_STYLESETSIZE, $i, $iFontSize)
    Next
    
    ; Zeilen-Nummern anzeigen
    _SendMessage($g_hScintilla, $SCI_SETMARGINWIDTHN, 0, 50)
    
    ; Einrückungslinien anzeigen
    _SendMessage($g_hScintilla, $SCI_SETINDENTATIONGUIDES, 1, 0)
    
    ; Autovervollständigung konfigurieren
    _SendMessage($g_hScintilla, $SCI_AUTOCSETIGNORECASE, 1, 0)
    _SendMessage($g_hScintilla, $SCI_AUTOCSETAUTOHIDE, 0, 0)
    _SendMessage($g_hScintilla, $SCI_AUTOCSETDROPRESTOFWORD, 1, 0)
    _SendMessage($g_hScintilla, $SCI_AUTOCSETSEPARATOR, Asc(" "), 0)
EndFunc

; ===============================================================================================================================
; Func.....: _ScintillaSetText
; Beschreibung: Setzt den Text im Scintilla-Control
; Parameter.: $sText - Der zu setzende Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ScintillaSetText($sText)
    If Not IsHWnd($g_hScintilla) Then Return
    
    Local $tText = DllStructCreate("char[" & StringLen($sText) + 1 & "]")
    DllStructSetData($tText, 1, $sText)
    
    _SendMessage($g_hScintilla, $WM_SETTEXT, 0, DllStructGetPtr($tText))
EndFunc

; ===============================================================================================================================
; Func.....: _ScintillaGetText
; Beschreibung: Holt den Text aus dem Scintilla-Control
; Parameter.: Keine
; Rückgabe..: Der aktuelle Text
; ===============================================================================================================================
Func _ScintillaGetText()
    If Not IsHWnd($g_hScintilla) Then Return ""
    
    Local $iLen = _SendMessage($g_hScintilla, $WM_GETTEXTLENGTH, 0, 0) + 1
    Local $tText = DllStructCreate("char[" & $iLen & "]")
    
    _SendMessage($g_hScintilla, $WM_GETTEXT, $iLen, DllStructGetPtr($tText))
    
    Return DllStructGetData($tText, 1)
EndFunc

; ===============================================================================================================================
; Func.....: _ScintillaShowAutoComplete
; Beschreibung: Zeigt die Autovervollständigungsliste
; Parameter.: $iLen - Länge des bereits eingegebenen Textes
;             $sWords - Liste der Wörter (Space-getrennt)
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ScintillaShowAutoComplete($iLen, $sWords)
    If Not IsHWnd($g_hScintilla) Then Return
    
    Local $tWords = DllStructCreate("char[" & StringLen($sWords) + 1 & "]")
    DllStructSetData($tWords, 1, $sWords)
    
    _SendMessage($g_hScintilla, $SCI_AUTOCSHOW, $iLen, DllStructGetPtr($tWords))
EndFunc

; ===============================================================================================================================
; Func.....: _ScintillaShowCallTip
; Beschreibung: Zeigt einen CallTip (Tooltip) an
; Parameter.: $iPos - Position im Text
;             $sTip - Der anzuzeigende Tipp
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ScintillaShowCallTip($iPos, $sTip)
    If Not IsHWnd($g_hScintilla) Then Return
    
    Local $tTip = DllStructCreate("char[" & StringLen($sTip) + 1 & "]")
    DllStructSetData($tTip, 1, $sTip)
    
    _SendMessage($g_hScintilla, $SCI_CALLTIPSHOW, $iPos, DllStructGetPtr($tTip))
EndFunc

; ===============================================================================================================================
; Func.....: _ScintillaSendString
; Beschreibung: Sendet einen String-Parameter an Scintilla
; Parameter.: $hWnd - Handle des Scintilla-Controls
;             $iMsg - Message-ID
;             $wParam - wParam
;             $sString - String-Parameter
; Rückgabe..: Rückgabewert der SendMessage
; ===============================================================================================================================
Func _ScintillaSendString($hWnd, $iMsg, $wParam, $sString)
    Local $tString = DllStructCreate("char[" & StringLen($sString) + 1 & "]")
    DllStructSetData($tString, 1, $sString)
    Return _SendMessage($hWnd, $iMsg, $wParam, DllStructGetPtr($tString))
EndFunc

; ===============================================================================================================================
; Func.....: _DestroyScintillaEditor
; Beschreibung: Zerstört das Scintilla-Control und gibt Ressourcen frei
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _DestroyScintillaEditor()
    If IsHWnd($g_hScintilla) Then
        _WinAPI_DestroyWindow($g_hScintilla)
        $g_hScintilla = 0
    EndIf
    
    If $g_hScintillaDLL <> -1 Then
        DllClose($g_hScintillaDLL)
        $g_hScintillaDLL = -1
    EndIf
EndFunc

; ===============================================================================================================================
; Beispiel-Implementierung für den SQL-Editor
; ===============================================================================================================================
Func _CreateModernSQLEditor($hGUI, $x, $y, $width, $height)
    ; Erstelle ein modernes Panel mit abgerundeten Ecken
    Local $hPanel = GUICtrlCreateLabel("", $x - 2, $y - 2, $width + 4, $height + 4)
    GUICtrlSetBkColor($hPanel, 0x44475A) ; Dunkler Rahmen
    
    ; Scintilla Editor initialisieren
    Local $hEditor = _InitScintillaSQLEditor($hGUI, $x, $y, $width, $height)
    
    If $hEditor = 0 Then
        ; Fallback auf RichEdit
        Return _GUICtrlRichEdit_Create($hGUI, "", $x, $y, $width, $height, _
            BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    EndIf
    
    ; Beispiel-SQL setzen
    _ScintillaSetText("-- Moderner SQL-Editor mit Scintilla" & @CRLF & _
                      "SELECT " & @CRLF & _
                      "    id," & @CRLF & _
                      "    name," & @CRLF & _
                      "    email" & @CRLF & _
                      "FROM users" & @CRLF & _
                      "WHERE active = 1" & @CRLF & _
                      "ORDER BY name ASC;")
    
    Return $hEditor
EndFunc