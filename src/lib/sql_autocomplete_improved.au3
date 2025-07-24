; Titel.......: SQL-Autocomplete - Verbesserte und optimierte Autovervollständigung
; Beschreibung: Implementierung einer intelligenten Autovervollständigung mit verbesserter Benutzerfreundlichkeit
; Autor.......: Ralle1976
; Erstellt....: 2025-04-24
; Aktualisiert: 2025-04-28 - Verbesserung der Autovervollständigung, Case-Sensitivity und Kontextlogik
; ===============================================================================================================================

#include-once
#include <WindowsConstants.au3>
#include <GUIConstants.au3>
#include <GuiEdit.au3>
#include <GuiRichEdit.au3>
#include <GuiListBox.au3>
#include <StringConstants.au3>
#include <Array.au3>
#include <WinAPIGdi.au3>
#include <FontConstants.au3>
#include <WinAPISys.au3>
#include <SQLite.au3>
#include <Misc.au3>

; Wichtig: Globale Variable, die in main_robust.au3 definiert ist (ListView-ID)
Global $g_idListView = 0 ; ID der ListView


; Hinzugefügt: Notwendige WinAPI-Konstanten für Fensterzeichnung
;~ Global Const $GCL_STYLE = -26 ; Klassenstil
Global Const $CS_SAVEBITS = 0x0800 ; Speichert Bits unter dem Fenster
Global Const $CS_DROPSHADOW = 0x00020000 ; Zeichnet einen Schatten unter dem Fenster
;~ Global Const $GWL_EXSTYLE = -20 ; Erweiterter Fensterstil
;~ Global Const $WS_EX_LAYERED = 0x00080000 ; Layered Window
;~ Global Const $WS_EX_TRANSPARENT = 0x00000020 ; Transparent
;~ Global Const $LWA_COLORKEY = 0x00000001 ; Farbschlüssel transparent setzen
;~ Global Const $LWA_ALPHA = 0x00000002 ; Alpha-Wert verwenden

; Referenz zur SQL-Editor-Panel-ID
Global $g_idSQLEditorPanel = 0 ; Panel-ID aus sql_editor_enhanced.au3

; Logging-Funktionen aus dem Hauptprojekt einbinden
#include "logging.au3"
; Zentrale SQL-Keyword-Definitionen
#include "sql_keywords.au3"

; In globals.au3 definierte Variablen
Global $g_hGUI                  ; Handle des Hauptfensters
Global $g_bSQLEditorMode        ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_hSQLRichEdit          ; Handle des RichEdit-Controls
Global $g_aTableColumns         ; Array mit Spaltennamen für die aktuelle Tabelle
Global $g_sCurrentDB            ; Aktuelle Datenbank
Global $g_idStatus              ; ID für Statustext
Global $g_idTableCombo          ; ID der Tabellen-ComboBox
Global $g_sCurrentTable         ; Aktuell ausgewählte Tabelle

; Windows API Message-Konstanten für Listbox-Steuerung
Global Const $LB_SETBKCOLOR = 0x0207 ; Setzt die Hintergrundfarbe der ListBox

; Globale Variablen für SQL-Autovervollständigung
Global $g_hList = 0             ; Handle der Autovervollständigungs-Liste
Global $g_sCurrentWord = ""     ; Aktuelles Wort unter dem Cursor
Global $g_iLastCursorPos = -1   ; Letzte Cursor-Position
Global $g_iWordStartPos = -1    ; Startposition des aktuellen Worts
Global $g_iWordEndPos = -1      ; Endposition des aktuellen Worts
Global $g_iListIndex = 0        ; Aktuell ausgewählter Eintrag in der Autovervollständigungsliste
Global $g_bAutoCompleteActive = False ; Status der Autovervollständigung
Global $g_hListGUICtrlHandle    ; GUICtrl-Handle des ListBox-Controls

; Neue Variablen für verbesserte Autovervollständigung
Global $g_aLastDisplayedMatches[0] ; Zuletzt angezeigte Matches als Cache
Global $g_aOriginalCaseSQLKeywords[0] ; Speichert die ursprüngliche Gross-/Kleinschreibung
Global $g_aOriginalCaseTableNames[0]  ; Speichert die Originalschreibweise der Tabellennamen
Global $g_aOriginalCaseColumnNames[0] ; Speichert die Originalschreibweise der Spaltennamen

; ===============================================================================================================================
; Func.....: _InitSQLAutoComplete
; Beschreibung: Initialisiert die SQL-Autovervollständigung
; Parameter.: $hGUI - Handle des Hauptfensters
;             $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _InitSQLAutoComplete($hGUI, $hRichEdit)
_LogInfo("Initialisiere SQL-Autovervollständigung")

; Globale Variablen setzen
$g_hGUI = $hGUI
$g_hSQLRichEdit = $hRichEdit

If Not IsHWnd($g_hGUI) Or Not IsHWnd($g_hSQLRichEdit) Then
_LogError("Autovervollständigung: Ungültige Fenster-Handles")
Return False
EndIf

; Bestehende Instanz der Liste entfernen, falls vorhanden
If $g_hList <> 0 Then
_StopSQLAutoComplete()
EndIf

; Erstelle das Vorschlagsliste-Fenster
Local $iWidth = 250
Local $iHeight = 120

; Verbesserte ListBox für Vorschläge erstellen mit zusätzlichen Stilen zum besseren Rendering (anfangs versteckt)
$g_hListGUICtrlHandle = GUICtrlCreateList("", 0, 0, $iWidth, $iHeight, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY, $LBS_NOINTEGRALHEIGHT, $LBS_HASSTRINGS, $WS_CLIPCHILDREN, $WS_CLIPSIBLINGS))
$g_hList = GUICtrlGetHandle($g_hListGUICtrlHandle)

; Wichtig: Hintergrundfarbe explizit auf Weiß setzen, um gelbe Artefakte zu vermeiden
DllCall("user32.dll", "int", "SendMessageW", "hwnd", $g_hList, "int", $LB_SETBKCOLOR, "int", 0, "int", 0xFFFFFF)

; Schriftart und Farbe anpassen
Local $hFont = _WinAPI_CreateFont(10, 0, 0, 0, 400, False, False, False, $DEFAULT_CHARSET, $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $DEFAULT_QUALITY, $DEFAULT_PITCH, "Consolas")
If $hFont Then _WinAPI_SetFont($g_hList, $hFont)

; Z-Order setzen, damit die Liste ÜBER allem anderen liegt
_WinAPI_SetWindowPos($g_hList, $HWND_TOPMOST, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))

; Ausblenden für Start
GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)

; Keywords in der Originalschreibweise speichern
If UBound($g_aOriginalCaseSQLKeywords) = 0 Then
; Keywords mit Großbuchstaben und Originalschreibweise speichern
    For $i = 0 To UBound($g_aSQL_AllKeywords) - 1
            _ArrayAdd($g_aOriginalCaseSQLKeywords, $g_aSQL_AllKeywords[$i])
    Next
EndIf

    _LogInfo("SQL-Autovervollständigung initialisiert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _StartSQLAutoComplete
; Beschreibung: Aktiviert die Autovervollständigung und registriert die Timer-Funktion
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _StartSQLAutoComplete()
    _LogInfo("Aktiviere SQL-Autovervollständigung")

    ; Sicherstellen, dass die Liste existiert
    If $g_hList = 0 Or Not IsHWnd($g_hList) Then
        _InitSQLAutoComplete($g_hGUI, $g_hSQLRichEdit)
    EndIf

    ; Überwachungsfunktion registrieren - höhere Frequenz für bessere Reaktionsfähigkeit
    AdlibRegister("_CheckSQLInputForAutoComplete", 50)

    ; Status zurücksetzen
    $g_iLastCursorPos = -1
    $g_sCurrentWord = ""
    $g_iWordStartPos = -1
    $g_iWordEndPos = -1
    $g_bAutoCompleteActive = True

    ; Originalschreibweise der Tabellen- und Spaltennamen speichern
    _CacheOriginalCaseNames()

    _LogInfo("SQL-Autovervollständigung aktiviert")
EndFunc

; ===============================================================================================================================
; Func.....: _StopSQLAutoComplete
; Beschreibung: Deaktiviert die Autovervollständigung
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _StopSQLAutoComplete()
    _LogInfo("Deaktiviere SQL-Autovervollständigung")

    ; Überwachungsfunktion deregistrieren
    AdlibUnRegister("_CheckSQLInputForAutoComplete")

    ; Liste ausblenden und vollständig entfernen
    If $g_hList <> 0 And IsHWnd($g_hList) Then
        ; Zuerst ausblenden
        GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)

        ; Kurze Pause, damit GUI aktualisiert wird
        Sleep(100)

        ; Hintergrund komplett weiß löschen - wichtig für Artefaktentfernung
        If IsHWnd($g_hGUI) Then
            Local $hDC = _WinAPI_GetDC($g_hGUI)
            Local $hBrush = _WinAPI_CreateSolidBrush(0xFFFFFF) ; Weißer Hintergrund
            _WinAPI_FillRect($hDC, _WinAPI_GetClientRect($g_hGUI), $hBrush)
            _WinAPI_ReleaseDC($g_hGUI, $hDC)
            _WinAPI_DeleteObject($hBrush)
        EndIf

        ; Dann löschen
        GUICtrlDelete($g_hListGUICtrlHandle)
        $g_hList = 0
        $g_hListGUICtrlHandle = 0

        ; Cache leeren
        ReDim $g_aLastDisplayedMatches[0]

        ; Gesamtes Anwendungsfenster gründlich neu zeichnen, um Artefakte zu beseitigen
        _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
        Sleep(100) ; Längere Pause um sicherzustellen, dass die Zeichenoperation abgeschlossen ist

        ; RichEdit-Control neu zeichnen mit Fokus
        If IsHWnd($g_hSQLRichEdit) Then
            ; Mehrfaches Neuzeichnen mit verschiedenen Optionen
            _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
            _WinAPI_SetFocus($g_hSQLRichEdit)
            Sleep(50)

            ; Nochmals explizit neu zeichnen lassen
            _WinAPI_InvalidateRect($g_hSQLRichEdit, 0, True) ; Komplettes Invalidieren mit Hintergrund
            _WinAPI_UpdateWindow($g_hSQLRichEdit)

            ; Zusätzliches Update für den Parent
            _WinAPI_InvalidateRect($g_hGUI, 0, True)
            _WinAPI_UpdateWindow($g_hGUI)
        EndIf

        ; ListView invalidieren, falls die ID bekannt ist und die Variable existiert
        If IsDeclared("g_idListView") And GUICtrlGetHandle($g_idListView) <> 0 Then
            _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView), 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
        EndIf
    EndIf

    ; Status zurücksetzen
    $g_bAutoCompleteActive = False

    _LogInfo("SQL-Autovervollständigung deaktiviert")
EndFunc

; ===============================================================================================================================
; Func.....: _CacheOriginalCaseNames
; Beschreibung: Speichert die Originalschreibweise der Tabellen- und Spaltennamen
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _CacheOriginalCaseNames()
    _LogInfo("Cache der Originalschreibweise der Tabellen- und Spaltennamen wird erstellt")

    ; Tabellennamen in ihrer Originalschreibweise speichern
    ReDim $g_aOriginalCaseTableNames[0]
    Local $sTables = GUICtrlRead($g_idTableCombo, 1)
    If $sTables <> "" Then
        Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
        For $i = 0 To UBound($aTableList) - 1
            If $aTableList[$i] <> "" Then
                _ArrayAdd($g_aOriginalCaseTableNames, $aTableList[$i])
            EndIf
        Next
        _LogInfo("Originalschreibweise von " & UBound($g_aOriginalCaseTableNames) & " Tabellen gespeichert")
    EndIf

    ; Spaltennamen in ihrer Originalschreibweise speichern
    ReDim $g_aOriginalCaseColumnNames[0]
    If UBound($g_aTableColumns) > 0 Then
        For $i = 0 To UBound($g_aTableColumns) - 1
            If $g_aTableColumns[$i] <> "" Then
                _ArrayAdd($g_aOriginalCaseColumnNames, $g_aTableColumns[$i])
            EndIf
        Next
        _LogInfo("Originalschreibweise von " & UBound($g_aOriginalCaseColumnNames) & " Spalten gespeichert")
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _CheckSQLInputForAutoComplete
; Beschreibung: Überwacht die Texteingabe und aktualisiert die Autovervollständigungsliste
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _CheckSQLInputForAutoComplete()
    ; Nur fortfahren, wenn SQL-Editor aktiv ist und Autovervollständigung aktiviert
    If Not $g_bSQLEditorMode Or Not $g_bAutoCompleteActive Then Return
    If Not IsHWnd($g_hSQLRichEdit) Then Return

    ; Zuerst prüfen wir direkt auf Tastaturinteraktionen (Pfeil hoch/runter, Enter, Tab)
    ; wenn die Liste angezeigt wird
    If $g_hList <> 0 And IsHWnd($g_hList) And BitAND(GUICtrlGetState($g_hListGUICtrlHandle), $GUI_SHOW) = $GUI_SHOW Then
        ; ESC-Taste überprüfen
        If _IsPressed("1B") Then ; VK_ESCAPE
            _LogInfo("ESC-Taste direkt erkannt - Liste ausblenden")
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
            Sleep(100) ; Kurze Pause, um mehrfache Verarbeitung zu vermeiden
            Return
        EndIf

        ; Pfeiltasten überprüfen
        If _IsPressed("28") Then ; VK_DOWN (Pfeil runter)
            _LogInfo("Pfeil runter direkt erkannt - Nächster Eintrag")
            $g_iListIndex += 1
            If $g_iListIndex >= _GUICtrlListBox_GetCount($g_hList) Then $g_iListIndex = 0
            _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
            Sleep(150) ; Verzögerung, um zu schnelles Scrollen zu vermeiden
            Return
        ElseIf _IsPressed("26") Then ; VK_UP (Pfeil hoch)
            _LogInfo("Pfeil hoch direkt erkannt - Vorheriger Eintrag")
            $g_iListIndex -= 1
            If $g_iListIndex < 0 Then $g_iListIndex = _GUICtrlListBox_GetCount($g_hList) - 1
            _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
            Sleep(150) ; Verzögerung, um zu schnelles Scrollen zu vermeiden
            Return
        EndIf

        ; Enter oder Tab zum Übernehmen der Auswahl
        If _IsPressed("0D") Or _IsPressed("09") Then ; VK_RETURN oder VK_TAB
            _LogInfo("Enter/Tab direkt erkannt - Auswahl übernehmen")
            _AcceptSQLAutoCompleteSelection()
            Sleep(150) ; Pause nach Auswahl
            Return
        EndIf
    EndIf

    ; Aktuelle Cursor-Position abrufen
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    If @error Then Return

    Local $iCursorPos = $aSel[0]

    ; Nur bei Änderung der Cursor-Position fortfahren
    If $iCursorPos = $g_iLastCursorPos Then Return
    $g_iLastCursorPos = $iCursorPos

    ; Text abrufen und aktuelles Wort ermitteln
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Aktuelles Wort unter dem Cursor ermitteln
    $g_sCurrentWord = _GetCurrentWord($sText, $iCursorPos, $g_iWordStartPos)
    $g_iWordEndPos = $iCursorPos

    ; Vorschläge erzeugen
    Local $aMatches = _GetSQLMatches($sText, $iCursorPos)

    ; Zeige oder verstecke die Autovervollständigungsliste
    If UBound($aMatches) > 0 Then
        ; Prüfen ob das aktuelle Wort bereits ein vollständiges Keyword ist
        ; und wenn ja, keine Autovervollständigung zeigen
        If _IsCompleteWordAndNoMoreSuggestions($g_sCurrentWord, $aMatches) Then
            _LogInfo("Vollständiges Wort bereits geschrieben, keine Vorschläge anzeigen: " & $g_sCurrentWord)
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
            _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
        Else
            _ShowAutoCompleteList($aMatches)
        EndIf
    Else
        ; Bei keinen Vorschlägen die Liste ausblenden
        If $g_hList <> 0 And IsHWnd($g_hList) Then
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
            ; Neu zeichnen um Artefakte zu vermeiden
            _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
        EndIf
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _IsCompleteWordAndNoMoreSuggestions
; Beschreibung: Prüft, ob das aktuelle Wort bereits ein vollständiges Keyword ist und keine weiteren Vorschläge nötig sind
; Parameter.: $sWord - Das aktuelle Wort
;             $aMatches - Array mit den gefundenen Vorschlägen
; Rückgabe..: True wenn das Wort vollständig ist und keine weiteren Vorschläge nötig sind, sonst False
; ===============================================================================================================================
Func _IsCompleteWordAndNoMoreSuggestions($sWord, $aMatches)
    ; Wenn kein Wort vorhanden, immer False
    If $sWord = "" Then Return False

    ; Wenn nur ein Vorschlag und dieser entspricht exakt dem Wort, dann True
    If UBound($aMatches) = 1 Then
        If StringUpper($aMatches[0]) = StringUpper($sWord) Then
            _LogInfo("Vollständiges Wort gefunden: " & $sWord & " = " & $aMatches[0])
            Return True
        EndIf
    EndIf

    ; Wenn mehrere Vorschläge, prüfen, ob eines exakt dem Wort entspricht und der Rest Erweiterungen sind
    Local $bExactMatch = False
    Local $bHasOtherSuggestions = False

    For $i = 0 To UBound($aMatches) - 1
        If StringUpper($aMatches[$i]) = StringUpper($sWord) Then
            $bExactMatch = True
        ElseIf Not StringUpper($aMatches[$i]) = StringUpper($sWord) Then
            $bHasOtherSuggestions = True
        EndIf
    Next

    ; Wenn wir einen exakten Treffer haben und keine anderen Vorschläge, dann True
    If $bExactMatch And Not $bHasOtherSuggestions Then
        _LogInfo("Perfekter Treffer ohne weitere Vorschläge")
        Return True
    EndIf

    ; Bei Keywords prüfen, ob das Wort exakt einem Keyword entspricht
    For $i = 0 To UBound($g_aSQL_AllKeywords) - 1
        If StringUpper($g_aSQL_AllKeywords[$i]) = StringUpper($sWord) Then
            _LogInfo("Vollständiges Keyword bereits geschrieben: " & $sWord)
            Return True
        EndIf
    Next

    Return False
EndFunc

; ===============================================================================================================================
; Func.....: _GetKeywordContext
; Beschreibung: Ermittelt den Kontext des SQL-Statements, um kontextbezogene Vorschläge zu machen
; Parameter.: $sText - Der vollständige SQL-Text
;             $iCursorPos - Aktuelle Cursor-Position
; Rückgabe..: String mit dem aktuellen Kontext ("FROM", "WHERE", "SELECT", etc.)
; ===============================================================================================================================
Func _GetKeywordContext($sText, $iCursorPos)
    Local $sContext = "DEFAULT"
    Local $sTextBeforeCursor = StringLeft($sText, $iCursorPos)

    ; Mehrzeiliges Statement? Dann nur aktuelle Zeile betrachten
    If StringInStr($sTextBeforeCursor, @CRLF) > 0 Then
        ; Position des letzten Zeilenumbruchs vor Cursor finden
        Local $iLastNewline = StringInStr($sTextBeforeCursor, @CRLF, 0, -1)
        If $iLastNewline > 0 Then
            ; Nur Text nach dem letzten Zeilenumbruch betrachten
            $sTextBeforeCursor = StringTrimLeft($sTextBeforeCursor, $iLastNewline + 1)
            _LogInfo("Mehrzeiliges Statement erkannt, betrachte nur die aktuelle Zeile für Kontext")
        EndIf
    EndIf

    ; FROM oder JOIN Kontext (Tabellennamen)
    If StringRegExp(StringUpper($sTextBeforeCursor), "(?:FROM|JOIN)\s+[^\s,;]*$") Then
        $sContext = "TABLE"
    ; SELECT Kontext (Spaltennamen, Funktionen)
    ElseIf StringRegExp(StringUpper($sTextBeforeCursor), "SELECT\s+[^\s,;]*$") Then
        $sContext = "COLUMN"
    ; WHERE Kontext (Spaltennamen, Operatoren)
    ElseIf StringRegExp(StringUpper($sTextBeforeCursor), "WHERE\s+[^\s,;]*$") Then
        $sContext = "WHERE"
    ; ORDER BY oder GROUP BY Kontext (Spaltennamen)
    ElseIf StringRegExp(StringUpper($sTextBeforeCursor), "(?:ORDER|GROUP)\s+BY\s+[^\s,;]*$") Then
        $sContext = "COLUMN"
    ; Nach einem Tabellennamen und einem Punkt (Spaltennamen)
    ElseIf StringRegExp($sTextBeforeCursor, "([a-zA-Z0-9_]+)\.$") Then
        $sContext = "TABLE_COLUMN"
    ; Am Anfang einer neuen Zeile (potentielles Keyword)
    ElseIf StringRegExp(StringStripWS($sTextBeforeCursor, 1), "^\s*[A-Za-z0-9_]*$") Then
        $sContext = "NEW_LINE_KEYWORD"
    EndIf

    _LogInfo("SQL-Kontext erkannt: " & $sContext)
    Return $sContext
EndFunc

; ===============================================================================================================================
; Func.....: _GetSQLMatches
; Beschreibung: Filtert die SQL-Keywords und gibt ein Array mit passenden Vorschlägen zurück
; Parameter.: $sText - Der komplette Text im Editor
;             $iCursorPos - Die aktuelle Cursor-Position
; Rückgabe..: Array mit passenden Vorschlägen
; ===============================================================================================================================
Func _GetSQLMatches($sText, $iCursorPos)
    Local $aMatches[0] ; Array für eindeutige Vorschläge

    ; Wenn kein aktuelles Wort, keine Vorschläge
    If $g_sCurrentWord = "" Then Return $aMatches

    Local $sUpperCurrentWord = StringUpper($g_sCurrentWord)

    ; Debug-Ausgabe hinzufügen
    _LogInfo("Suche nach Matches für: '" & $g_sCurrentWord & "'")

    ; Aktuellen Kontext ermitteln
    Local $sContext = _GetKeywordContext($sText, $iCursorPos)

    ; Bei mehrzeiligen Statements - prüfen, ob das aktuelle Wort am Anfang einer Zeile steht
    Local $bIsPotentialKeyword = False
    If StringInStr($sText, @CRLF) Then
        ; Position des letzten Zeilenumbruchs vor dem Cursor finden
        Local $iLastNewline = StringInStr($sText, @CRLF, 0, -1, $iCursorPos)
        If $iLastNewline = 0 Then $iLastNewline = 1

        ; Text zwischen letztem Zeilenumbruch und Cursor prüfen
        Local $sLineBeforeCursor = StringMid($sText, $iLastNewline, $iCursorPos - $iLastNewline + 1)

        ; Wenn das aktuelle Wort am Anfang der Zeile steht (oder nach Leerzeichen), ist es wahrscheinlich ein Keyword
        If StringRegExp(StringStripWS($sLineBeforeCursor, 1), "^[\s]*" & $g_sCurrentWord & "$") Then
            $bIsPotentialKeyword = True
            _LogInfo("Potentielles Keyword am Zeilenanfang erkannt: " & $g_sCurrentWord)
        EndIf
    EndIf

    ; Schritt 1: Prüfe ob das aktuelle Wort exakt einem Keyword entspricht
    Local $bExactMatchFound = False

    For $i = 0 To UBound($g_aOriginalCaseSQLKeywords) - 1
        If StringUpper($g_aOriginalCaseSQLKeywords[$i]) = $sUpperCurrentWord Then
            $bExactMatchFound = True
            _LogInfo("Exakte Übereinstimmung mit Keyword: " & $g_aOriginalCaseSQLKeywords[$i])
            ; Bei exakter Übereinstimmung hinzufügen, aber nur wenn es ein potentielles Keyword ist
            If $bIsPotentialKeyword Then
                _ArrayAdd($aMatches, $g_aOriginalCaseSQLKeywords[$i])
            EndIf
            ExitLoop
        EndIf
    Next

    ; Kontextbasierte Suche
    Switch $sContext
        Case "TABLE"
            ; Bei FROM oder JOIN nur Tabellennamen vorschlagen
            _LogInfo("Tabellennamen-Kontext (FROM/JOIN)")
            _AddMatchingTableNames($aMatches, $sUpperCurrentWord)

        Case "COLUMN"
            ; Bei SELECT oder ORDER BY Spaltennamen und Funktionen vorschlagen
            _LogInfo("Spaltennamen-Kontext (SELECT/ORDER BY)")
            _AddMatchingColumnNames($aMatches, $sUpperCurrentWord)
            _AddMatchingFunctions($aMatches, $sUpperCurrentWord)

        Case "WHERE"
            ; Bei WHERE Spaltennamen, Funktionen und Operatoren vorschlagen
            _LogInfo("WHERE-Kontext")
            _AddMatchingColumnNames($aMatches, $sUpperCurrentWord)
            _AddMatchingFunctions($aMatches, $sUpperCurrentWord)
            _AddMatchingOperators($aMatches, $sUpperCurrentWord)

        Case "TABLE_COLUMN"
            ; Nach einem Tabellennamen und Punkt nur Spaltennamen vorschlagen
            _LogInfo("Tabelle.Spalte-Kontext")
            Local $aTableMatch = StringRegExp($sText, "([a-zA-Z0-9_]+)\.$", $STR_REGEXPARRAYMATCH)
            If IsArray($aTableMatch) And UBound($aTableMatch) > 0 Then
                Local $sTableName = $aTableMatch[0]
                _LogInfo("Tabellenname: " & $sTableName)

                If StringUpper($sTableName) = StringUpper($g_sCurrentTable) Then
                    ; Alle Spaltennamen der aktuellen Tabelle anzeigen
                    _AddAllColumns($aMatches)
                EndIf
            EndIf

        Case "DEFAULT"
            ; Standard-Kontext
            _LogInfo("Standard-Kontext")
            ; Nur wenn kein exakter Match gefunden wurde, partielle Matches hinzufügen
            If Not $bExactMatchFound Then
                ; SQL-Keywords prüfen
                _AddMatchingKeywords($aMatches, $sUpperCurrentWord)

                ; SQL-Funktionen prüfen
                _AddMatchingFunctions($aMatches, $sUpperCurrentWord)

                ; SQL-Datentypen prüfen
                _AddMatchingDataTypes($aMatches, $sUpperCurrentWord)

                ; Tabellennamen prüfen
                _AddMatchingTableNames($aMatches, $sUpperCurrentWord)

                ; Spaltennamen prüfen
                _AddMatchingColumnNames($aMatches, $sUpperCurrentWord)
            EndIf
    EndSwitch

    ; Cache der angezeigten Matches aktualisieren
    $g_aLastDisplayedMatches = $aMatches

    _LogInfo("Finale Anzahl der Matches: " & UBound($aMatches))
    Return $aMatches
EndFunc

; ===============================================================================================================================
; Func.....: _AddMatchingKeywords
; Beschreibung: Fügt passende SQL-Keywords zu den Vorschlägen hinzu
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
;             $sUpperCurrentWord - Das aktuelle Wort in Großbuchstaben
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddMatchingKeywords(ByRef $aMatches, $sUpperCurrentWord)
    For $i = 0 To UBound($g_aOriginalCaseSQLKeywords) - 1
        ; Case-insensitive Suche, aber mit Beibehaltung der Originalschreibweise
        If StringLeft(StringUpper($g_aOriginalCaseSQLKeywords[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
            ; Nur hinzufügen, wenn noch nicht im Array
            If _ArraySearch($aMatches, $g_aOriginalCaseSQLKeywords[$i]) = -1 Then
                _ArrayAdd($aMatches, $g_aOriginalCaseSQLKeywords[$i])
                _LogInfo("Keyword-Match hinzugefügt: " & $g_aOriginalCaseSQLKeywords[$i])
            EndIf
        EndIf
    Next
EndFunc

; ===============================================================================================================================
; Func.....: _AddMatchingFunctions
; Beschreibung: Fügt passende SQL-Funktionen zu den Vorschlägen hinzu
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
;             $sUpperCurrentWord - Das aktuelle Wort in Großbuchstaben
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddMatchingFunctions(ByRef $aMatches, $sUpperCurrentWord)
    For $i = 0 To UBound($g_aSQL_Functions) - 1
        ; Case-insensitive Suche
        If StringLeft(StringUpper($g_aSQL_Functions[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
            ; Nur hinzufügen, wenn noch nicht im Array
            If _ArraySearch($aMatches, $g_aSQL_Functions[$i]) = -1 Then
                _ArrayAdd($aMatches, $g_aSQL_Functions[$i])
                _LogInfo("Funktions-Match hinzugefügt: " & $g_aSQL_Functions[$i])
            EndIf
        EndIf
    Next
EndFunc

; ===============================================================================================================================
; Func.....: _AddMatchingDataTypes
; Beschreibung: Fügt passende SQL-Datentypen zu den Vorschlägen hinzu
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
;             $sUpperCurrentWord - Das aktuelle Wort in Großbuchstaben
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddMatchingDataTypes(ByRef $aMatches, $sUpperCurrentWord)
    For $i = 0 To UBound($g_aSQL_DataTypes) - 1
        ; Case-insensitive Suche
        If StringLeft(StringUpper($g_aSQL_DataTypes[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
            ; Nur hinzufügen, wenn noch nicht im Array
            If _ArraySearch($aMatches, $g_aSQL_DataTypes[$i]) = -1 Then
                _ArrayAdd($aMatches, $g_aSQL_DataTypes[$i])
                _LogInfo("Datentyp-Match hinzugefügt: " & $g_aSQL_DataTypes[$i])
            EndIf
        EndIf
    Next
EndFunc

; ===============================================================================================================================
; Func.....: _AddMatchingOperators
; Beschreibung: Fügt passende SQL-Operatoren zu den Vorschlägen hinzu
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
;             $sUpperCurrentWord - Das aktuelle Wort in Großbuchstaben
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddMatchingOperators(ByRef $aMatches, $sUpperCurrentWord)
    For $i = 0 To UBound($g_aSQL_Operators) - 1
        ; Case-insensitive Suche
        If StringLeft(StringUpper($g_aSQL_Operators[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
            ; Nur hinzufügen, wenn noch nicht im Array
            If _ArraySearch($aMatches, $g_aSQL_Operators[$i]) = -1 Then
                _ArrayAdd($aMatches, $g_aSQL_Operators[$i])
                _LogInfo("Operator-Match hinzugefügt: " & $g_aSQL_Operators[$i])
            EndIf
        EndIf
    Next
EndFunc

; ===============================================================================================================================
; Func.....: _AddMatchingTableNames
; Beschreibung: Fügt passende Tabellennamen zu den Vorschlägen hinzu
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
;             $sUpperCurrentWord - Das aktuelle Wort in Großbuchstaben
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddMatchingTableNames(ByRef $aMatches, $sUpperCurrentWord)
    _LogInfo("Prüfe Tabellennamen für Matches...")

    ; Originalschreibweise der Tabellennamen verwenden
    If UBound($g_aOriginalCaseTableNames) > 0 Then
        For $i = 0 To UBound($g_aOriginalCaseTableNames) - 1
            If $g_aOriginalCaseTableNames[$i] <> "" Then
                ; Case-insensitive Suche mit Originalschreibweise
                If StringLen($sUpperCurrentWord) = 0 Or StringLeft(StringUpper($g_aOriginalCaseTableNames[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                    ; Nur hinzufügen, wenn noch nicht im Array
                    If _ArraySearch($aMatches, $g_aOriginalCaseTableNames[$i]) = -1 Then
                        _ArrayAdd($aMatches, $g_aOriginalCaseTableNames[$i])
                        _LogInfo("Tabellennamen-Match hinzugefügt: " & $g_aOriginalCaseTableNames[$i])
                    EndIf
                EndIf
            EndIf
        Next
    ; Fallback: Aus ComboBox lesen
    Else
        Local $sTables = GUICtrlRead($g_idTableCombo, 1)
        If $sTables <> "" Then
            Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
            For $i = 0 To UBound($aTableList) - 1
                If $aTableList[$i] <> "" Then
                    ; Case-insensitive Suche
                    If StringLen($sUpperCurrentWord) = 0 Or StringLeft(StringUpper($aTableList[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                        ; Nur hinzufügen, wenn noch nicht im Array
                        If _ArraySearch($aMatches, $aTableList[$i]) = -1 Then
                            _ArrayAdd($aMatches, $aTableList[$i])
                            _LogInfo("Tabellennamen-Match hinzugefügt: " & $aTableList[$i])
                        EndIf
                    EndIf
                EndIf
            Next
        Else
            _LogInfo("Keine Tabellen verfügbar")
        EndIf
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _AddMatchingColumnNames
; Beschreibung: Fügt passende Spaltennamen zu den Vorschlägen hinzu
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
;             $sUpperCurrentWord - Das aktuelle Wort in Großbuchstaben
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddMatchingColumnNames(ByRef $aMatches, $sUpperCurrentWord)
    _LogInfo("Prüfe Spaltennamen für Matches...")

    ; Originalschreibweise der Spaltennamen verwenden
    If UBound($g_aOriginalCaseColumnNames) > 0 Then
        For $i = 0 To UBound($g_aOriginalCaseColumnNames) - 1
            If $g_aOriginalCaseColumnNames[$i] <> "" Then
                ; Case-insensitive Suche mit Originalschreibweise
                If StringLen($sUpperCurrentWord) = 0 Or StringLeft(StringUpper($g_aOriginalCaseColumnNames[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                    ; Nur hinzufügen, wenn noch nicht im Array
                    If _ArraySearch($aMatches, $g_aOriginalCaseColumnNames[$i]) = -1 Then
                        _ArrayAdd($aMatches, $g_aOriginalCaseColumnNames[$i])
                        _LogInfo("Spaltennamen-Match hinzugefügt: " & $g_aOriginalCaseColumnNames[$i])
                    EndIf
                EndIf
            EndIf
        Next
    ; Fallback: Aus g_aTableColumns lesen
    Else
        If UBound($g_aTableColumns) > 0 Then
            For $i = 0 To UBound($g_aTableColumns) - 1
                If $g_aTableColumns[$i] <> "" Then
                    ; Case-insensitive Suche
                    If StringLen($sUpperCurrentWord) = 0 Or StringLeft(StringUpper($g_aTableColumns[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                        ; Nur hinzufügen, wenn noch nicht im Array
                        If _ArraySearch($aMatches, $g_aTableColumns[$i]) = -1 Then
                            _ArrayAdd($aMatches, $g_aTableColumns[$i])
                            _LogInfo("Spaltennamen-Match hinzugefügt: " & $g_aTableColumns[$i])
                        EndIf
                    EndIf
                EndIf
            Next
        Else
            _LogInfo("Keine Spalten verfügbar")
        EndIf
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _AddAllColumns
; Beschreibung: Fügt alle verfügbaren Spaltennamen zu den Vorschlägen hinzu (für Tabelle.Spalte-Kontexte)
; Parameter.: ByRef $aMatches - Array mit Vorschlägen
; Rückgabe..: Keine
; ===============================================================================================================================
Func _AddAllColumns(ByRef $aMatches)
    _LogInfo("Füge alle Spalten der aktuellen Tabelle hinzu")

    ; Zuerst Array leeren, da wir nur Spaltennamen anzeigen wollen
    ReDim $aMatches[0]

    ; Originalschreibweise der Spaltennamen verwenden
    If UBound($g_aOriginalCaseColumnNames) > 0 Then
        For $i = 0 To UBound($g_aOriginalCaseColumnNames) - 1
            If $g_aOriginalCaseColumnNames[$i] <> "" Then
                _ArrayAdd($aMatches, $g_aOriginalCaseColumnNames[$i])
                _LogInfo("Spaltenname für Tabelle hinzugefügt: " & $g_aOriginalCaseColumnNames[$i])
            EndIf
        Next
    ; Fallback: Aus g_aTableColumns lesen
    Else
        If UBound($g_aTableColumns) > 0 Then
            For $i = 0 To UBound($g_aTableColumns) - 1
                If $g_aTableColumns[$i] <> "" Then
                    _ArrayAdd($aMatches, $g_aTableColumns[$i])
                    _LogInfo("Spaltenname für Tabelle hinzugefügt: " & $g_aTableColumns[$i])
                EndIf
            Next
        Else
            _LogInfo("Keine Spalten verfügbar")
        EndIf
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _ShowAutoCompleteList
; Beschreibung: Zeigt die Autovervollständigungsliste mit den gegebenen Vorschlägen an
; Parameter.: $aMatches - Array mit Vorschlägen
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ShowAutoCompleteList($aMatches)
    Local $iEntryCount = UBound($aMatches)

    If $iEntryCount = 0 Then
        If $g_hList <> 0 And IsHWnd($g_hList) Then
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
            ; Gründlich neu zeichnen um Artefakte zu vermeiden
            _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
            _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
        EndIf
        Return
    EndIf

    ; Bei nur einem Eintrag und mehrzeiligem Statement - direkt einfügen
    If $iEntryCount = 1 And StringInStr(_GUICtrlRichEdit_GetText($g_hSQLRichEdit), @CRLF) > 0 Then
        _LogInfo("Nur ein Vorschlag bei mehrzeiligem Statement - füge direkt ein: " & $aMatches[0])

        ; Wortposition sichern
        Local $iOldWordStart = $g_iWordStartPos
        Local $iOldWordEnd = $g_iWordEndPos

        ; Text ersetzen
        _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $g_iWordStartPos - 1, $g_iWordEndPos)
        _GUICtrlRichEdit_ReplaceText($g_hSQLRichEdit, $aMatches[0])

        ; Fokus setzen
        _WinAPI_SetFocus($g_hSQLRichEdit)

        ; Sicherstellen, dass keine Liste angezeigt wird
        If $g_hList <> 0 And IsHWnd($g_hList) Then
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
        EndIf

        ; GUI neu zeichnen
        _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_ALLCHILDREN, $RDW_UPDATENOW))
        _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))

        ; Status zurücksetzen
        $g_sCurrentWord = ""
        Return
    EndIf

    _LogInfo("Zeige Autovervollständigung mit " & $iEntryCount & " Vorschlägen")

    ; Sicherstellen, dass die Liste existiert
    If $g_hList = 0 Or Not IsHWnd($g_hList) Then
        _InitSQLAutoComplete($g_hGUI, $g_hSQLRichEdit)
    EndIf

    ; Position der Liste berechnen
    Local $aPosition = _GetAutoCompletePosition()

    ; Vorbereitungen für die Anzeige
    _GUICtrlListBox_ResetContent($g_hList)
    _GUICtrlListBox_BeginUpdate($g_hList)

    ; Listengröße anpassen - höher machen, wenn viele Einträge vorhanden sind
    ; Min und Max Funktionen direkt implementiert
    Local $iHeight = ($iEntryCount * 20 < 60) ? 60 : (($iEntryCount * 20 > 240) ? 240 : $iEntryCount * 20) ; Mindestens 60px, maximal 240px
    Local $iWidth = 280 ; Standardbreite

    ; Bei langen Einträgen die Breite anpassen
    For $i = 0 To $iEntryCount - 1
        $iWidth = ($iWidth < StringLen($aMatches[$i]) * 10) ? StringLen($aMatches[$i]) * 10 : $iWidth ; Ungefähr 10 Pixel pro Zeichen
    Next
    $iWidth = ($iWidth > 400) ? 400 : $iWidth ; Nicht breiter als 400px

    ; Bereich unter der Liste vorbereiten - wichtig für sauberes Rendering
    Local $tRect = _WinAPI_CreateRect($aPosition[0], $aPosition[1], $aPosition[0] + $iWidth, $aPosition[1] + $iHeight)
    Local $hDC = _WinAPI_GetDC($g_hGUI)
    Local $hBrush = _WinAPI_CreateSolidBrush(0xFFFFFF) ; Weißer Hintergrund
    _WinAPI_FillRect($hDC, $tRect, $hBrush)
    _WinAPI_ReleaseDC($g_hGUI, $hDC)
    _WinAPI_DeleteObject($hBrush)
    _WinAPI_UpdateWindow($g_hGUI)

    ; Listen-Eigenschaften setzen
    ControlMove($g_hGUI, "", $g_hListGUICtrlHandle, $aPosition[0], $aPosition[1], $iWidth, $iHeight)

    ; Z-Order setzen, damit die Liste ÜBER allem anderen liegt
    _WinAPI_SetWindowPos($g_hList, $HWND_TOPMOST, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))

    ; Daten setzen
    For $i = 0 To $iEntryCount - 1
        _GUICtrlListBox_AddString($g_hList, $aMatches[$i])
    Next

    ; Update beenden
    _GUICtrlListBox_EndUpdate($g_hList)

    ; Hintergrundfarbe der Liste explizit auf weiß setzen
    DllCall("user32.dll", "int", "SendMessageW", "hwnd", $g_hList, "int", $LB_SETBKCOLOR, "int", 0, "int", 0xFFFFFF)

    ; Erweiterte Z-Order-Einstellungen, falls noch Artefakte sichtbar sind
    _WinAPI_SetWindowPos($g_hList, $HWND_TOPMOST, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
    _WinAPI_SetWindowPos(GUICtrlGetHandle($g_idSQLEditorPanel), $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))

    ; Erweiterte Stileinstellungen und Zeicheneigenschaften
    ; Verwende WinAPI-Funktionen direkt statt der Wrapper, da diese nicht definiert sind
    DllCall("user32.dll", "dword", "SetClassLongW", "hwnd", $g_hList, "int", $GCL_STYLE, "dword", BitOR(DllCall("user32.dll", "dword", "GetClassLongW", "hwnd", $g_hList, "int", $GCL_STYLE)[0], $CS_SAVEBITS, $CS_DROPSHADOW))

    ; Layer-Window-Effekt für besseres Rendering aktivieren
    If IsHWnd($g_hList) Then
        ; Layer-Window-Stil aktivieren für bessere visuelle Darstellung
        Local $iExStyle = _WinAPI_GetWindowLong($g_hList, $GWL_EXSTYLE)
        _WinAPI_SetWindowLong($g_hList, $GWL_EXSTYLE, BitOR($iExStyle, $WS_EX_LAYERED, $WS_EX_TRANSPARENT))
        _WinAPI_SetLayeredWindowAttributes($g_hList, 0xFFFFFF, 255, $LWA_COLORKEY)
    EndIf

    ; Erweiterte Neuzeichnungsoptionen - wichtig für die Vermeidung von Artefakten
    _WinAPI_RedrawWindow($g_hList, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ERASE, $RDW_FRAME, $RDW_ALLCHILDREN))
    _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))

    ; Zusätzlich alle anderen Controls aktualisieren
    _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ERASE, $RDW_FRAME))

    ; Liste anzeigen
    GUICtrlSetState($g_hListGUICtrlHandle, $GUI_SHOW)

    ; Ersten Eintrag auswählen
    $g_iListIndex = 0
    _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
EndFunc

; ===============================================================================================================================
; Func.....: _GetCurrentWord
; Beschreibung: Ermittelt das Wort unter der aktuellen Cursor-Position
; Parameter.: $sText - Der Gesamttext
;             $iCursorPos - Die aktuelle Cursor-Position
;             ByRef $iStart - Rückgabewert für die Startposition des Wortes
; Rückgabe..: Das aktuelle Wort
; ===============================================================================================================================
Func _GetCurrentWord($sText, $iCursorPos, ByRef $iStart)
    If $iCursorPos < 1 Then
        $iStart = 0
        Return ""
    EndIf

    ; Bei mehrzeiligen Statements - nur aktuelle Zeile betrachten
    Local $bIsMultiline = (StringInStr($sText, @CRLF) > 0)
    Local $iLineStart = 0

    If $bIsMultiline Then
        ; Position des letzten Zeilenumbruchs vor dem Cursor finden
        Local $iLastNewline = StringInStr($sText, @CRLF, 0, -1, $iCursorPos)
        If $iLastNewline > 0 Then
            $iLineStart = $iLastNewline + 1 ; Position nach dem Zeilenumbruch
            _LogInfo("Mehrzeiliges Statement: Aktuelle Zeile beginnt bei Position " & $iLineStart)
        EndIf
    EndIf

    ; Startposition des Wortes ermitteln - nicht vor dem Beginn der aktuellen Zeile
    $iStart = $iCursorPos
    While $iStart > $iLineStart And StringRegExp(StringMid($sText, $iStart, 1), "[a-zA-Z0-9_.]")
        $iStart -= 1
    WEnd

    ; Wenn wir nicht am Zeilenbeginn sind oder ein gültiges Zeichen gefunden haben, eine Position nach vorne
    If $iStart > $iLineStart Or Not StringRegExp(StringMid($sText, $iStart, 1), "[a-zA-Z0-9_.]") Then
        $iStart += 1
    EndIf

    ; Wort aus dem Text extrahieren
    Local $sWord = StringMid($sText, $iStart, $iCursorPos - $iStart + 1)
    _LogInfo("Aktuelles Wort erkannt: '" & $sWord & "' (Start: " & $iStart & ", Ende: " & $iCursorPos & ")")

    Return $sWord
EndFunc

; ===============================================================================================================================
; Func.....: _AcceptSQLAutoCompleteSelection
; Beschreibung: Übernimmt den ausgewählten Eintrag aus der Autovervollständigungsliste
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _AcceptSQLAutoCompleteSelection()
    ; Prüfen, ob Liste sichtbar ist
    If $g_hList = 0 Or Not IsHWnd($g_hList) Or BitAND(GUICtrlGetState($g_hListGUICtrlHandle), $GUI_SHOW) <> $GUI_SHOW Then
        _LogInfo("Liste nicht sichtbar, keine Auswahl möglich")
        Return False
    EndIf

    ; Aktuell ausgewählten Index prüfen
    Local $iSelIndex = _GUICtrlListBox_GetCurSel($g_hList)
    If $iSelIndex < 0 Then
        _LogInfo("Keine Auswahl in der Liste getroffen")
        Return False
    EndIf

    ; Ausgewählten Eintrag aus der Liste holen
    Local $sItem = _GUICtrlListBox_GetText($g_hList, $iSelIndex)
    If $sItem = "" Then
        _LogInfo("Ausgewählter Eintrag ist leer")
        Return False
    EndIf

    _LogInfo("Ausgewählter Eintrag: '" & $sItem & "', wird jetzt eingefügt")
    _LogInfo("Wortposition: Start=" & $g_iWordStartPos & ", Ende=" & $g_iWordEndPos)

    ; Sicherstellen, dass die Wortposition korrekt ist
    If $g_iWordStartPos < 1 Or $g_iWordEndPos < $g_iWordStartPos Then
        _LogInfo("Ungültige Wortpositionen, verwende aktuelle Cursor-Position")
        ; Aktuelle Cursorposition holen
        Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
        If @error Then
            _LogInfo("Fehler beim Ermitteln der aktuellen Cursor-Position")
            Return False
        EndIf

        ; Wortposition neu berechnen
        Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
        $g_sCurrentWord = _GetCurrentWord($sText, $aSel[0], $g_iWordStartPos)
        $g_iWordEndPos = $aSel[0]
    EndIf

    ; Text ersetzen
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $g_iWordStartPos - 1, $g_iWordEndPos)
    _GUICtrlRichEdit_ReplaceText($g_hSQLRichEdit, $sItem)

    ; Liste ausblenden (zuerst verbergen, dann entfernen)
    GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
    Sleep(10) ; Kurze Pause für UI-Update

    ; Gesamtes Anwendungsfenster neu zeichnen um Artefakte zu beseitigen
    _WinAPI_RedrawWindow($g_hGUI, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_ALLCHILDREN, $RDW_UPDATENOW))

    ; Wichtig: RichEdit-Control explizit neu zeichnen
    If IsHWnd($g_hSQLRichEdit) Then
        _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))

        ; Mehrere Neuzeichnungen mit Fokus-Wechseln, um Artefakte zu eliminieren
        _WinAPI_SetFocus($g_hGUI) ; Kurz zum Hauptfenster wechseln
        Sleep(5)
        _WinAPI_SetFocus($g_hSQLRichEdit) ; Dann zurück zum Editor

        ; Nochmals neu zeichnen
        _WinAPI_RedrawWindow($g_hSQLRichEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_FRAME, $RDW_UPDATENOW))
    EndIf

    ; Den gelöschten Bereich aktualisieren - wichtig bei mehreren Panels
    Local $aRect = ControlGetPos($g_hGUI, "", $g_idSQLEditorPanel)
    _WinAPI_InvalidateRect($g_hGUI, _WinAPI_CreateRect($aRect[0], $aRect[1], $aRect[0] + $aRect[2], $aRect[1] + $aRect[3]), True)
    _WinAPI_UpdateWindow($g_hGUI)

    ; Status zurücksetzen
    $g_sCurrentWord = ""

    ; Fokus auf RichEdit setzen
    _WinAPI_SetFocus($g_hSQLRichEdit)

    ; Statusmeldung anzeigen
    If $g_idStatus <> 0 Then
        GUICtrlSetData($g_idStatus, "Autovervollständigung: '" & $sItem & "' eingefügt")
    EndIf

    _LogInfo("Autovervollständigung erfolgreich: '" & $sItem & "' eingefügt")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _HandleSQLAutocompleteKeys
; Beschreibung: Verarbeitet Tasteneingaben für die Autovervollständigung
; Parameter.: $hWnd - Handle des Fensters
;             $iMsg - Nachrichtentyp
;             $wParam - Zusätzliche Informationen
;             $lParam - Zusätzliche Informationen
; Rückgabe..: True wenn verarbeitet, False wenn nicht
; ===============================================================================================================================
Func _HandleSQLAutocompleteKeys($hWnd, $iMsg, $wParam, $lParam)
    ; Nur wenn SQL-Editor aktiv ist und Autovervollständigung aktiviert
    If Not $g_bSQLEditorMode Or Not $g_bAutoCompleteActive Then Return False

    ; Taste extrahieren
    Local $iKey = $wParam

    ; Prüfen, ob Liste sichtbar ist
    Local $bListVisible = ($g_hList <> 0 And IsHWnd($g_hList) And BitAND(GUICtrlGetState($g_hListGUICtrlHandle), $GUI_SHOW) = $GUI_SHOW)

    ; Wenn Liste sichtbar ist, Tasten für die Navigation verarbeiten
    If $bListVisible Then
        ; ESC-Taste zum Ausblenden der Liste
        If $iKey = 0x1B Then  ; VK_ESCAPE
            _LogInfo("ESC-Taste gedrückt - Liste ausblenden")
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
            Return True
        EndIf

        ; Pfeil runter
        If $iKey = 0x28 Then  ; VK_DOWN
            _LogInfo("Pfeil runter gedrückt - Nächster Eintrag")
            $g_iListIndex += 1
            If $g_iListIndex >= _GUICtrlListBox_GetCount($g_hList) Then $g_iListIndex = 0
            _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
            Return True
        EndIf

        ; Pfeil hoch
        If $iKey = 0x26 Then  ; VK_UP
            _LogInfo("Pfeil hoch gedrückt - Vorheriger Eintrag")
            $g_iListIndex -= 1
            If $g_iListIndex < 0 Then $g_iListIndex = _GUICtrlListBox_GetCount($g_hList) - 1
            _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
            Return True
        EndIf

        ; Enter oder Tab zum Übernehmen der Auswahl
        If $iKey = 0x0D Or $iKey = 0x09 Then  ; VK_RETURN oder VK_TAB
            _LogInfo("Enter/Tab gedrückt - Auswahl übernehmen")
            _AcceptSQLAutoCompleteSelection()
            Return True
        EndIf
    EndIf

    ; Strg+Leertaste zum Anzeigen der Autovervollständigung
    If $iKey = 0x20 And _IsCtrlPressed() Then  ; VK_SPACE
        _LogInfo("Strg+Leertaste gedrückt - Autovervollständigung anzeigen")
        _ShowSQLCompletionListFix()
        Return True
    EndIf

    Return False
EndFunc

; ===============================================================================================================================
; Func.....: _IsCtrlPressed
; Beschreibung: Prüft, ob die Strg-Taste gedrückt ist
; Parameter.: Keine
; Rückgabe..: True wenn Strg gedrückt ist, sonst False
; ===============================================================================================================================
Func _IsCtrlPressed()
    ; Verwende _IsPressed aus <Misc.au3>
    Return _IsPressed("11") ; VK_CONTROL
EndFunc

; ===============================================================================================================================
; Func.....: _GetAutoCompletePosition
; Beschreibung: Berechnet die Position für die Autovervollständigungsliste basierend auf der Cursor-Position
; Parameter.: Keine
; Rückgabe..: Array mit X- und Y-Koordinaten [X, Y]
; ===============================================================================================================================
Func _GetAutoCompletePosition()
    Local $aPos[2] = [0, 0]

    ; Position des RichEdit-Controls im Fenster ermitteln
    Local $aRichEditPos = ControlGetPos($g_hGUI, "", $g_hSQLRichEdit)
    If Not IsArray($aRichEditPos) Then Return $aPos

    ; Cursor-Position im Text ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    If @error Then Return $aPos

    Local $iCursorPos = $aSel[0]
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Anzahl der Zeilen vor dem Cursor zählen (für Y-Position)
    Local $iLineCount = StringRegExpReplace(StringLeft($sText, $iCursorPos), "[^\n]", "")
    Local $iLineIndex = StringLen($iLineCount)

    ; Position in der aktuellen Zeile ermitteln (für X-Position)
    Local $iLastNewline = StringInStr($sText, @LF, 0, -1, $iCursorPos)
    Local $iColIndex = $iCursorPos - $iLastNewline
    If $iLastNewline = 0 Then $iColIndex = $iCursorPos

    ; Ungefähre Pixel-Position berechnen (10 Pixel pro Zeichen, 18 Pixel pro Zeile)
    $aPos[0] = $aRichEditPos[0] + ($iColIndex * 10)
    $aPos[1] = $aRichEditPos[1] + (($iLineIndex + 1) * 18)

    ; Sicherstellen, dass die Liste im Fenster bleibt
    If $aPos[0] + 250 > $aRichEditPos[0] + $aRichEditPos[2] Then
        $aPos[0] = $aRichEditPos[0] + $aRichEditPos[2] - 260
    EndIf

    If $aPos[1] + 120 > $aRichEditPos[1] + $aRichEditPos[3] Then
        $aPos[1] = $aPos[1] - 140
        ; Sicherstellen, dass die Liste nicht zu weit nach oben rutscht
        If $aPos[1] < $aRichEditPos[1] Then
            $aPos[1] = $aRichEditPos[1] + 5 ; 5 Pixel vom oberen Rand
        EndIf
    EndIf

    Return $aPos
EndFunc

; ===============================================================================================================================
; Func.....: _HandleSQLAutoCompleteEvent
; Beschreibung: Event-Handler für Doppelklick in der Autovervollständigungsliste
; Parameter.: $iCtrlID - Control-ID des Events
; Rückgabe..: True wenn Event verarbeitet wurde, sonst False
; ===============================================================================================================================
Func _HandleSQLAutoCompleteEvent($iCtrlID)
    ; Nur bei Autovervollständigung und wenn Liste sichtbar
    If Not $g_bSQLEditorMode Or Not $g_bAutoCompleteActive Then Return False
    If $g_hList = 0 Or Not IsHWnd($g_hList) Then Return False

    ; Prüfen, ob das Event von der Liste stammt
    If $iCtrlID = $g_hListGUICtrlHandle Then
        _AcceptSQLAutoCompleteSelection()
        Return True
    EndIf

    Return False
EndFunc

; ===============================================================================================================================
; Func.....: _InitSQLEditorAutocompleteFix
; Beschreibung: Initialisiert die Autovervollständigung für den SQL-Editor
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _InitSQLEditorAutocompleteFix()
    _LogInfo("Initialisiere verbesserte SQL-Editor-Autovervollständigung")

    ; Autovervollständigung initialisieren
    If Not _InitSQLAutoComplete($g_hGUI, $g_hSQLRichEdit) Then
        _LogError("Fehler beim Initialisieren der Autovervollständigung")
        Return False
    EndIf

    ; Tabellen- und Spaltenliste protokollieren
    _DebugMetadataInfo()

    ; Originalschreibweise der Tabellen- und Spaltennamen speichern
    _CacheOriginalCaseNames()

    ; Autovervollständigung aktivieren
    _StartSQLAutoComplete()

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _ShowSQLCompletionListFix
; Beschreibung: Zeigt die Autovervollständigungsliste manuell an
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _ShowSQLCompletionListFix()
    _LogInfo("Manuelle Anzeige der Autovervollständigungsliste")

    ; Sicherstellen, dass SQL-Editor aktiv ist
    If Not $g_bSQLEditorMode Then
        _LogInfo("SQL-Editor nicht aktiv")
        Return False
    EndIf

    ; Autovervollständigung bei Bedarf initialisieren
    If Not $g_bAutoCompleteActive Then
        _InitSQLEditorAutocompleteFix()
    EndIf

    ; Aktuelle Cursor-Position ermitteln
    Local $aSel = _GUICtrlRichEdit_GetSel($g_hSQLRichEdit)
    If @error Then
        _LogError("Fehler beim Ermitteln der Cursor-Position")
        Return False
    EndIf

    ; Aktuellen Text abrufen
    Local $sText = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

    ; Aktuelles Wort ermitteln
    $g_sCurrentWord = _GetCurrentWord($sText, $aSel[0], $g_iWordStartPos)
    $g_iWordEndPos = $aSel[0]

    If $g_sCurrentWord = "" Then
        _LogInfo("Kein Wort unter dem Cursor - Zeige alle passenden Keywords")

        ; Deklariere Array für Autovervollständigung
        Local $aCompleteMatches[0]
        _AddMatchingKeywords($aCompleteMatches, "")
        _AddMatchingTableNames($aCompleteMatches, "")
        _AddMatchingColumnNames($aCompleteMatches, "")
        
        ; Auf Layer-Window-Technik verzichten, da es Probleme verursachen kann
        ; Stattdessen direktes Rendering mit höherer Z-Order verwenden
        Local $iEntryCount = UBound($aCompleteMatches)
        If $iEntryCount > 0 Then
            ; Sicherstellen, dass die Liste neu erstellt wird
            If $g_hList <> 0 And IsHWnd($g_hList) Then
                GUICtrlDelete($g_hListGUICtrlHandle)
                $g_hList = 0
            EndIf
            
            ; Liste neu erstellen mit verstecktem Status
            Local $iWidth = 300
            Local $iHeight = 200
            $g_hListGUICtrlHandle = GUICtrlCreateList("", 100, 100, $iWidth, $iHeight, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY, $LBS_NOINTEGRALHEIGHT, $LBS_HASSTRINGS))
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_HIDE)
            $g_hList = GUICtrlGetHandle($g_hListGUICtrlHandle)
            
            ; Z-Order auf höchste Stufe setzen
            _WinAPI_SetWindowPos($g_hList, $HWND_TOPMOST, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE))
            
            ; Position der Liste berechnen
            Local $aPosition = _GetAutoCompletePosition()
            ControlMove($g_hGUI, "", $g_hListGUICtrlHandle, $aPosition[0], $aPosition[1], $iWidth, $iHeight)
            
            ; Daten einfügen
            _GUICtrlListBox_BeginUpdate($g_hList)
            For $i = 0 To $iEntryCount - 1
                _GUICtrlListBox_AddString($g_hList, $aCompleteMatches[$i])
            Next
            _GUICtrlListBox_EndUpdate($g_hList)
            
            ; Liste anzeigen und ersten Eintrag wählen
            GUICtrlSetState($g_hListGUICtrlHandle, $GUI_SHOW)
            $g_iListIndex = 0
            _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
            
            ; Log-Meldung
            _LogInfo("Autovervollständigungsliste mit " & $iEntryCount & " Einträgen angezeigt")
            Return True
        EndIf
    Else
        ; Normales Verhalten: Passende Vorschläge anzeigen
        Local $aMatches = _GetSQLMatches($sText, $aSel[0])
        If UBound($aMatches) > 0 Then
            _ShowAutoCompleteList($aMatches)
            Return True
        EndIf
    EndIf

    _LogInfo("Keine passenden Vorschläge gefunden")
    Return False
EndFunc

; ===============================================================================================================================
; Func.....: _DebugMetadataInfo
; Beschreibung: Protokolliert Informationen über die verfügbaren Tabellen und Spalten für die Autovervollständigung
; Parameter.: Keine
; Rückgabe..: Keine
; ===============================================================================================================================
Func _DebugMetadataInfo()
    _LogInfo("=== Debug: Metadaten-Information ===")

    ; Aktuelle Datenbank
    _LogInfo("Aktuelle Datenbank: " & ($g_sCurrentDB <> "" ? $g_sCurrentDB : "<keine>"))

    ; Aktuelle Tabelle
    _LogInfo("Aktuelle Tabelle: " & ($g_sCurrentTable <> "" ? $g_sCurrentTable : "<keine>"))

    ; Alle verfügbaren Tabellen protokollieren
    Local $sTables = GUICtrlRead($g_idTableCombo, 1)
    If $sTables <> "" Then
        Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
        _LogInfo("Verfügbare Tabellen (" & UBound($aTableList) & "): " & _ArrayToString($aTableList, ", "))
    Else
        _LogInfo("Keine Tabellen in der ComboBox gefunden")
    EndIf

    ; Spalten der aktuellen Tabelle protokollieren
    If UBound($g_aTableColumns) > 0 Then
        _LogInfo("Spalten für aktuelle Tabelle (" & UBound($g_aTableColumns) & "): " & _ArrayToString($g_aTableColumns, ", "))
    Else
        _LogInfo("Keine Spalten für die aktuelle Tabelle gefunden")

        ; Versuch, die Spalten manuell zu laden
        If $g_sCurrentDB <> "" And $g_sCurrentTable <> "" Then
            _LogInfo("Versuche, Spalten manuell zu laden...")
            ; Alternative Methode verwenden, die bereits definiert ist
            _SQL_UpdateSpecificTable($g_sCurrentDB, $g_sCurrentTable)
            ; g_aTableColumns sollte nun aktualisiert sein
            If UBound($g_aTableColumns) > 0 Then
                _LogInfo("Spalten manuell geladen (" & UBound($g_aTableColumns) & "): " & _ArrayToString($g_aTableColumns, ", "))
            Else
                _LogInfo("Manuelles Laden der Spalten fehlgeschlagen")
                _LoadTableColumnsAlternative($g_sCurrentDB, $g_sCurrentTable)
            EndIf
        EndIf
    EndIf

    ; SQL-Keywords aus sql_keywords.au3 prüfen
    _LogInfo("SQL Keywords verfügbar: " & (IsDeclared("g_aSQL_AllKeywords") ? "Ja (" & UBound($g_aSQL_AllKeywords) & ")" : "Nein"))
    _LogInfo("SQL Funktionen verfügbar: " & (IsDeclared("g_aSQL_Functions") ? "Ja (" & UBound($g_aSQL_Functions) & ")" : "Nein"))
    _LogInfo("SQL Datentypen verfügbar: " & (IsDeclared("g_aSQL_DataTypes") ? "Ja (" & UBound($g_aSQL_DataTypes) & ")" : "Nein"))

    _LogInfo("=== Ende Debug: Metadaten-Information ===")
EndFunc

; ===============================================================================================================================
; Func.....: _LoadTableColumnsAlternative
; Beschreibung: Alternative Methode zum Laden von Tabellenspalten mit direkter SQL-Abfrage
; Parameter.: $sDatabase - Pfad zur Datenbank
;             $sTable - Name der Tabelle
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _LoadTableColumnsAlternative($sDatabase, $sTable)
    _LogInfo("Alternative Methode zum Laden der Spalten für Tabelle: " & $sTable)

    ; Sicherstellen, dass Datenbank vorhanden ist
    If Not FileExists($sDatabase) Then
        _LogError("Datenbank existiert nicht: " & $sDatabase)
        Return False
    EndIf

    ; Sicherstellen, dass Tabelle vorhanden ist
    If $sTable = "" Then
        _LogError("Kein Tabellenname angegeben")
        Return False
    EndIf

    _LogInfo("Direkte PRAGMA-Abfrage für Tabellenspalten")

    ; Direkte SQLite-Abfrage für Spaltennamen mit PRAGMA
    Local $hDB
    _SQLite_Startup()
    If @error Then
        _LogError("Fehler beim Starten der SQLite-Engine")
        Return False
    EndIf

    Local $iResult = _SQLite_Open($sDatabase, $SQLITE_OPEN_READONLY, $hDB)
    If $iResult <> $SQLITE_OK Then
        _LogError("Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
        _SQLite_Shutdown()
        Return False
    EndIf

    ; Array für Spaltennamen
    Local $aColumns[0]

    ; Erste Methode: PRAGMA table_info
    Local $hQuery, $aRow
    $iResult = _SQLite_Query($hDB, "PRAGMA table_info('" & $sTable & "');", $hQuery)
    If $iResult = $SQLITE_OK Then
        _LogInfo("PRAGMA-Abfrage erfolgreich ausgeführt")

        While _SQLite_FetchData($hQuery, $aRow, False, False) = $SQLITE_OK
            ; Spaltenname ist in Index 1
            If IsArray($aRow) And UBound($aRow) > 1 Then
                _ArrayAdd($aColumns, $aRow[1])
                _LogInfo("Spalte gefunden: " & $aRow[1])
            EndIf
        WEnd
        _SQLite_QueryFinalize($hQuery)
    Else
        _LogError("Fehler bei PRAGMA-Abfrage: " & _SQLite_ErrMsg())
    EndIf

    ; Wenn keine Spalten gefunden wurden, alternative Methode versuchen
    If UBound($aColumns) = 0 Then
        _LogInfo("Keine Spalten mit PRAGMA gefunden, versuche SELECT * LIMIT 0")

        $iResult = _SQLite_Query($hDB, "SELECT * FROM '" & $sTable & "' LIMIT 0;", $hQuery)
        If $iResult = $SQLITE_OK Then
            Local $iRows = 0, $iCols = 0
            Local $iResult = _SQLite_GetTable2d($hDB, "SELECT * FROM '" & $sTable & "' LIMIT 0;", $aRow, $iRows, $iCols)
            If $iResult = $SQLITE_OK And $iRows > 0 And IsArray($aRow) Then
                _LogInfo("Spalten mit SELECT gefunden: " & $iCols)
                ; Erste Zeile enthält Spaltennamen
                Local $aNewColumns[0]
                For $i = 0 To $iCols - 1
                    _ArrayAdd($aNewColumns, $aRow[0][$i])
                    _LogInfo("Spalte gefunden: " & $aRow[0][$i])
                Next
                $aColumns = $aNewColumns
            Else
                _LogError("Fehler bei SELECT-Abfrage: " & _SQLite_ErrMsg())
            EndIf

            ; Abfrage finalisieren
            _SQLite_QueryFinalize($hQuery)
        Else
            _LogError("Fehler beim Abrufen der Spaltennamen mit SELECT")
        EndIf
    EndIf

    ; Datenbank schließen
    _SQLite_Close($hDB)
    _SQLite_Shutdown()

    ; Globales Array aktualisieren
    If UBound($aColumns) > 0 Then
        $g_aTableColumns = $aColumns
        ; Originalschreibweise der Spalten speichern
        ReDim $g_aOriginalCaseColumnNames[UBound($aColumns)]
        For $i = 0 To UBound($aColumns) - 1
            $g_aOriginalCaseColumnNames[$i] = $aColumns[$i]
        Next
        _LogInfo("Spalten erfolgreich geladen: " & UBound($aColumns))
        Return True
    Else
        _LogError("Keine Spalten für Tabelle '" & $sTable & "' gefunden")
        Return False
    EndIf
EndFunc