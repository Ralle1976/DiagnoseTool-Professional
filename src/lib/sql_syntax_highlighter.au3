; ===============================================================================================================================
; Titel.......: SQL-Syntax-Highlighter mit AdlibRegister
; Beschreibung: Alternativer Highlighter für SQL-Syntax
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-12
; ===============================================================================================================================

#include-once

#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <WinAPIGdi.au3>
#include <Array.au3>
#include <String.au3>
#include <GUIRichEdit.au3>

; Zentrale SQL-Keyword-Definitionen
#include "sql_keywords.au3"

; ===============================================================================================================================
; Func.....: _SQL_InitializeKeywordHighlighting
; Beschreibung: Initialisiert die Syntax-Hervorhebung für SQL-Keywords
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_InitializeKeywordHighlighting($hRichEdit)
    ; Stellt sicher, dass der Highlighter aktiv ist
    _SQL_SyntaxHighlighter_Initialize($hRichEdit)
    
    ; Aktualisierung des Highlightings erzwingen
    _SQL_SyntaxHighlighter_Update($hRichEdit)
EndFunc

; Externe globale Variablen
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls

; SQL-Keywords und Funktionen werden aus sql_keywords.au3 importiert
; Keine lokale Deklaration mehr notwendig, da wir die zentrale Definition verwenden

; Globale Variablen
Global $g_hSyntaxTimerFunc = 0    ; Timer-ID für AdlibRegister
Global $g_iSyntaxDelay = 300      ; Verzögerung in ms für Syntax-Hervorhebung
Global $g_iLastSyntaxUpdate = 0   ; Zeitstempel der letzten Aktualisierung
Global $g_bSyntaxUpdatePending = False ; Flag, ob ein Update ansteht

; Farben für Syntax-Elemente
Global Const $COLOR_NORMAL = 0x000000   ; Schwarz für normalen Text
Global Const $COLOR_KEYWORD = 0x0000FF  ; Blau für Keywords
Global Const $COLOR_FUNCTION = 0x008080 ; Türkis für Funktionen
Global Const $COLOR_STRING = 0x008000   ; Grün für Strings
Global Const $COLOR_NUMBER = 0x800000   ; Dunkelrot für Zahlen
Global Const $COLOR_OPERATOR = 0x800080 ; Lila für Operatoren
Global Const $COLOR_COMMENT = 0x808080  ; Grau für Kommentare

; ===============================================================================================================================
; Func.....: _SQL_SyntaxHighlighter_Initialize
; Beschreibung: Initialisiert den AdlibRegister-basierten Syntax-Highlighter
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_SyntaxHighlighter_Initialize($hRichEdit)
    ; Timer nur bei expliziter Anforderung verwenden, nicht automatisch
    ; Wenn ein Timer bereits registriert ist, diesen deaktivieren
    If $g_hSyntaxTimerFunc <> 0 Then
        AdlibUnRegister($g_hSyntaxTimerFunc)
        $g_hSyntaxTimerFunc = 0
    EndIf
    
    ; Initial kein Update anstehend
    $g_bSyntaxUpdatePending = False
    $g_iLastSyntaxUpdate = 0
    
    ; Globale Variable für späteren Zugriff setzen
    $g_hSQLRichEdit = $hRichEdit
    
    ; Keine Übernahme der Keyword-Arrays mehr notwendig, da wir die zentrale Definition verwenden
    _LogInfo("Syntax-Highlighter initialisiert mit zentralen Keyword-Definitionen")
    
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SyntaxHighlighter_Shutdown
; Beschreibung: Beendet den Syntax-Highlighter und gibt Ressourcen frei
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SyntaxHighlighter_Shutdown()
    ; Timer beenden
    If $g_hSyntaxTimerFunc <> 0 Then
        AdlibUnRegister($g_hSyntaxTimerFunc)
        $g_hSyntaxTimerFunc = 0
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SyntaxHighlighter_RequestUpdate
; Beschreibung: Fordert eine Aktualisierung der Syntax-Hervorhebung an
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SyntaxHighlighter_RequestUpdate($hRichEdit)
    ; Aktualisierung als ausstehend markieren
    $g_bSyntaxUpdatePending = True
    $g_iLastSyntaxUpdate = TimerInit()
    $g_hSQLRichEdit = $hRichEdit
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SyntaxHighlighter_TimerFunc
; Beschreibung: Timer-Funktion, die von AdlibRegister aufgerufen wird
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SyntaxHighlighter_TimerFunc()
    ; Prüfen, ob eine Aktualisierung ansteht und genug Zeit vergangen ist
    If $g_bSyntaxUpdatePending And TimerDiff($g_iLastSyntaxUpdate) >= $g_iSyntaxDelay Then
        ; Hervorhebung aktualisieren
        _SQL_SyntaxHighlighter_Update($g_hSQLRichEdit)
        
        ; Zurücksetzen
        $g_bSyntaxUpdatePending = False
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SyntaxHighlighter_Update
; Beschreibung: Führt die Syntax-Hervorhebung durch
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_SyntaxHighlighter_Update($hRichEdit)
    ; Text und aktuelle Position erhalten
    Local $sText = _GUICtrlRichEdit_GetText($hRichEdit)
    If $sText = "" Then Return False
    
    ; Aktuelle Selektion speichern
    Local $aSel = _GUICtrlRichEdit_GetSel($hRichEdit)
    Local $iSelStart = $aSel[0]
    Local $iSelEnd = $aSel[1]
    
    ; Event-Maske temporär deaktivieren für bessere Performance
    _GUICtrlRichEdit_SetEventMask($hRichEdit, 0)
    
    ; Text komplett ersetzen für Neuformatierung
    _GUICtrlRichEdit_SetText($hRichEdit, "")
    
    ; Keywords, Operatoren, etc. identifizieren und einfärben
    _SQL_SyntaxHighlighter_Process($hRichEdit, $sText)
    
    ; Cursor-Position wiederherstellen
    _GUICtrlRichEdit_SetSel($hRichEdit, $iSelStart, $iSelEnd)
    
    ; Event-Maske wiederherstellen
    _GUICtrlRichEdit_SetEventMask($hRichEdit, $ENM_CHANGE)
    
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_SyntaxHighlighter_Process
; Beschreibung: Verarbeitet den Text für die Syntax-Hervorhebung
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
;             $sText - Der zu verarbeitende Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_SyntaxHighlighter_Process($hRichEdit, $sText)
    ; Textlänge
    Local $iLen = StringLen($sText)
    If $iLen = 0 Then Return
    
    ; Token-Verarbeitung mit Zustandsmaschine
    Local $iPos = 1
    Local $sCurrentToken = ""
    Local $iTokenStart = 1
    Local $iState = 0 ; 0=Normal, 1=Keyword, 2=String, 3=Number, 4=Comment, 5=Operator
    
    ; Keine Initialisierungsprüfung mehr notwendig, da wir die zentrale Definition verwenden
    
    While $iPos <= $iLen
        Local $sChar = StringMid($sText, $iPos, 1)
        Local $sNextChar = ($iPos < $iLen) ? StringMid($sText, $iPos + 1, 1) : ""
        
        ; Zustandsbasierte Verarbeitung
        Switch $iState
            Case 0 ; Normaler Text
                ; Keywords erkennen (alphanumerisch beginnend)
                If StringIsAlpha($sChar) Then
                    $iTokenStart = $iPos
                    $sCurrentToken = $sChar
                    $iState = 1 ; Mögliches Keyword
                    
                ; Strings erkennen
                ElseIf $sChar = "'" Or $sChar = '"' Then
                    ; String-Anfangszeichen ausgeben
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_STRING)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sChar)
                    
                    $iTokenStart = $iPos + 1
                    $sCurrentToken = ""
                    $iState = 2 ; String-Modus
                    
                ; Zahlen erkennen
                ElseIf StringIsDigit($sChar) Then
                    $iTokenStart = $iPos
                    $sCurrentToken = $sChar
                    $iState = 3 ; Zahl
                    
                ; Kommentare erkennen
                ElseIf $sChar = "-" And $sNextChar = "-" Then
                    ; Kommentar-Marker ausgeben
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_COMMENT)
                    _GUICtrlRichEdit_AppendText($hRichEdit, "--")
                    
                    $iTokenStart = $iPos + 2
                    $sCurrentToken = ""
                    $iState = 4 ; Kommentar
                    $iPos += 1 ; Zweites '-' überspringen
                    
                ; Operatoren erkennen
                ElseIf StringInStr("+-*/=<>!%&|^~()[]{},;:", $sChar) Then
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_OPERATOR)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sChar)
                    
                ; Sternchen erkennen (besondere Beachtung für "SELECT * FROM")
                ElseIf $sChar = "*" Then
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_OPERATOR)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sChar)
                    
                ; Normaler Text
                Else
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_NORMAL)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sChar)
                EndIf
                
            Case 1 ; Mögliches Keyword
                If StringIsAlNum($sChar) Or $sChar = "_" Then
                    ; Token erweitern
                    $sCurrentToken &= $sChar
                Else
                    ; Token abschließen und prüfen
                    Local $bIsKeyword = False
                    Local $bIsFunction = False
                    
                    ; Als Keyword prüfen (mit zentraler Definition)
                    Local $sUpperToken = StringUpper($sCurrentToken)
                    $bIsKeyword = _ArraySearch($g_aSQL_AllKeywords, $sUpperToken) >= 0
                    
                    ; Als Funktion prüfen, wenn kein Keyword
                    If Not $bIsKeyword Then
                        $bIsFunction = _ArraySearch($g_aSQL_Functions, $sUpperToken) >= 0
                    EndIf
                    
                    ; Als Datentyp prüfen, wenn weder Keyword noch Funktion
                    If Not $bIsKeyword And Not $bIsFunction Then
                        Local $bIsDataType = _ArraySearch($g_aSQL_DataTypes, $sUpperToken) >= 0
                        If $bIsDataType Then $bIsKeyword = True ; Datentypen wie Keywords formatieren
                    EndIf
                    
                    ; Token ausgeben mit entsprechender Farbe
                    If $bIsKeyword Then
                        _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_KEYWORD)
                    ElseIf $bIsFunction Then
                        _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_FUNCTION)
                    Else
                        _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_NORMAL)
                    EndIf
                    
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
                    
                    ; Aktuelles Zeichen verarbeiten
                    $iPos -= 1 ; Ein Zeichen zurück, um es im nächsten Durchlauf zu verarbeiten
                    $iState = 0 ; Zurück zum normalen Modus
                EndIf
                
            Case 2 ; String
                If ($sChar = "'" Or $sChar = '"') And Not ($iPos > 1 And StringMid($sText, $iPos - 1, 1) = "\") Then
                    ; String-Abschlusszeichen gefunden
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_STRING)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken & $sChar)
                    
                    $iState = 0 ; Zurück zum normalen Modus
                Else
                    ; String erweitern
                    $sCurrentToken &= $sChar
                EndIf
                
            Case 3 ; Zahl
                If StringIsDigit($sChar) Or $sChar = "." Then
                    ; Token erweitern
                    $sCurrentToken &= $sChar
                Else
                    ; Token abschließen
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_NUMBER)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
                    
                    ; Aktuelles Zeichen verarbeiten
                    $iPos -= 1 ; Ein Zeichen zurück
                    $iState = 0 ; Zurück zum normalen Modus
                EndIf
                
            Case 4 ; Kommentar
                If $sChar = @CR Or $sChar = @LF Then
                    ; Kommentar ist zu Ende
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_COMMENT)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
                    
                    ; Zeilenumbruch verarbeiten
                    _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_NORMAL)
                    _GUICtrlRichEdit_AppendText($hRichEdit, $sChar)
                    
                    $iState = 0 ; Zurück zum normalen Modus
                Else
                    ; Kommentar erweitern
                    $sCurrentToken &= $sChar
                EndIf
        EndSwitch
        
        $iPos += 1
    WEnd
    
    ; Abschließende Token-Verarbeitung
    Switch $iState
        Case 1 ; Unvollständiges Keyword
            ; Als Keyword prüfen
            Local $bIsKeyword = False
            If IsArray($g_aSQLKeywords) And UBound($g_aSQLKeywords) > 1 Then
                For $i = 1 To $g_aSQLKeywords[0]
                    If StringUpper($sCurrentToken) = $g_aSQLKeywords[$i] Then
                        $bIsKeyword = True
                        ExitLoop
                    EndIf
                Next
            EndIf
            
            ; Als Funktion prüfen, wenn kein Keyword
            Local $bIsFunction = False
            If Not $bIsKeyword And IsArray($g_aSQLFunctions) And UBound($g_aSQLFunctions) > 1 Then
                For $i = 1 To $g_aSQLFunctions[0]
                    If StringUpper($sCurrentToken) = $g_aSQLFunctions[$i] Then
                        $bIsFunction = True
                        ExitLoop
                    EndIf
                Next
            EndIf
            
            ; Token ausgeben
            If $bIsKeyword Then
                _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_KEYWORD)
            ElseIf $bIsFunction Then
                _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_FUNCTION)
            Else
                _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_NORMAL)
            EndIf
            
            _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
            
        Case 2 ; Unvollständiger String
            _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_STRING)
            _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
            
        Case 3 ; Unvollständige Zahl
            _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_NUMBER)
            _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
            
        Case 4 ; Unvollständiger Kommentar
            _GUICtrlRichEdit_SetCharColor($hRichEdit, $COLOR_COMMENT)
            _GUICtrlRichEdit_AppendText($hRichEdit, $sCurrentToken)
    EndSwitch
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsKeyword
; Beschreibung: Prüft, ob ein Token ein SQL-Schlüsselwort ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es ein Schlüsselwort ist, sonst False
; ===============================================================================================================================
Func _SQL_IsKeyword($sToken)
    $sToken = StringUpper($sToken)
    Return _ArraySearch($g_aSQL_AllKeywords, $sToken) >= 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsFunction
; Beschreibung: Prüft, ob ein Token eine SQL-Funktion ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es eine Funktion ist, sonst False
; ===============================================================================================================================
Func _SQL_IsFunction($sToken)
    $sToken = StringUpper($sToken)
    Return _ArraySearch($g_aSQL_Functions, $sToken) >= 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsDataType
; Beschreibung: Prüft, ob ein Token ein SQL-Datentyp ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es ein Datentyp ist, sonst False
; ===============================================================================================================================
Func _SQL_IsDataType($sToken)
    $sToken = StringUpper($sToken)
    Return _ArraySearch($g_aSQL_DataTypes, $sToken) >= 0
EndFunc
