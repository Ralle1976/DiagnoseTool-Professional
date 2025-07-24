; Titel.......: SQL-Autocomplete - Verbesserte Autovervollständigung
; Beschreibung: Implementierung einer DropDown-Liste mit Vorschlägen basierend auf dem aktuellen Cursor
; Autor.......: Ralle1976
; Erstellt....: 2025-04-24
; Aktualisiert: 2025-04-25 - Behebung von Anzeigeproblemen
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

; Globale Variablen für SQL-Autovervollständigung
Global $g_hList                 ; Handle der Autovervollständigungs-Liste
Global $g_sCurrentWord = ""     ; Aktuelles Wort unter dem Cursor
Global $g_iLastCursorPos = -1   ; Letzte Cursor-Position
Global $g_iWordStartPos = -1    ; Startposition des aktuellen Worts
Global $g_iWordEndPos = -1      ; Endposition des aktuellen Worts
Global $g_iListIndex = 0        ; Aktuell ausgewählter Eintrag in der Autovervollständigungsliste
Global $g_bAutoCompleteActive = False ; Status der Autovervollständigung

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
        Local $hOldList = GUICtrlGetHandle($g_hList)
        If IsHWnd($hOldList) Then
            GUICtrlSetState($g_hList, $GUI_HIDE)
            GUICtrlDelete($g_hList)
            $g_hList = 0
            Sleep(50) ; Kurze Pause für GUI-Update
        EndIf
    EndIf

    ; Erstelle das Vorschlagsliste-Fenster
    Local $iWidth = 250
    Local $iHeight = 120

    ; ListBox für Vorschläge erstellen (anfangs versteckt)
    $g_hList = GUICtrlCreateList("", 0, 0, $iWidth, $iHeight, BitOR($WS_BORDER, $WS_VSCROLL, $LBS_NOTIFY, $LBS_NOINTEGRALHEIGHT))

    ; Schriftart und Farbe anpassen
    Local $hFont = _WinAPI_CreateFont(10, 0, 0, 0, 400, False, False, False, $DEFAULT_CHARSET, $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $DEFAULT_QUALITY, $DEFAULT_PITCH, "Consolas")
    If $hFont Then _WinAPI_SetFont(GUICtrlGetHandle($g_hList), $hFont)

    ; Ausblenden für Start
    GUICtrlSetState($g_hList, $GUI_HIDE)

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

    ; Überwachungsfunktion registrieren - höhere Frequenz für bessere Reaktionsfähigkeit
    AdlibRegister("_CheckSQLInputForAutoComplete", 50)

    ; Status zurücksetzen
    $g_iLastCursorPos = -1
    $g_sCurrentWord = ""
    $g_iWordStartPos = -1
    $g_iWordEndPos = -1
    $g_bAutoCompleteActive = True

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
    If $g_hList <> 0 Then
        ; Zuerst ausblenden
        GUICtrlSetState($g_hList, $GUI_HIDE)

        ; Kurze Pause, damit GUI aktualisiert wird
        Sleep(50)

        ; Dann löschen
        Local $hListCtrl = GUICtrlGetHandle($g_hList)
        If IsHWnd($hListCtrl) Then
            GUICtrlDelete($g_hList)
        EndIf

        $g_hList = 0
    EndIf

    ; Status zurücksetzen
    $g_bAutoCompleteActive = False

    _LogInfo("SQL-Autovervollständigung deaktiviert")
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
    If BitAND(GUICtrlGetState($g_hList), $GUI_SHOW) = $GUI_SHOW Then
        ; ESC-Taste überprüfen
        If _IsPressed("1B") Then ; VK_ESCAPE
            _LogInfo("ESC-Taste direkt erkannt - Liste ausblenden")
            GUICtrlSetState($g_hList, $GUI_HIDE)
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

    ; Filtere Vorschläge basierend auf aktuellem Wort
    Local $sMatches = "", $sSearch = ""

    If $g_sCurrentWord <> "" Then
        ; Liste mit passenden Vorschlägen erstellen
        Local $aMatches[0] ; Array für eindeutige Vorschläge
        Local $sUpperCurrentWord = StringUpper($g_sCurrentWord)

        ; Schritt 1: Prüfe auf exakte Übereinstimmung mit einem einzelnen Keyword
        Local $bExactMatchFound = False
        Local $sExactMatch = ""

        ; Exakten Match in Keywords suchen
        For $i = 0 To UBound($g_aSQL_AllKeywords) - 1
            If StringUpper($g_aSQL_AllKeywords[$i]) = $sUpperCurrentWord Then
                ; Exakter Match gefunden - nur diesen verwenden
                $sExactMatch = $g_aSQL_AllKeywords[$i]
                $bExactMatchFound = True
                _LogInfo("Exakte Übereinstimmung mit Keyword: " & $sExactMatch)
                _ArrayAdd($aMatches, $sExactMatch)
                ExitLoop
            EndIf
        Next

        ; Wenn kein exakter Match gefunden wurde, partielle Matches prüfen
        If Not $bExactMatchFound Then
            ; SQL-Keywords prüfen
            For $i = 0 To UBound($g_aSQL_AllKeywords) - 1
                If StringLeft(StringUpper($g_aSQL_AllKeywords[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                    ; Nur hinzufügen, wenn noch nicht im Array
                    If _ArraySearch($aMatches, $g_aSQL_AllKeywords[$i]) = -1 Then
                        _ArrayAdd($aMatches, $g_aSQL_AllKeywords[$i])
                    EndIf
                EndIf
            Next
        EndIf

            ; SQL-Funktionen prüfen
            For $i = 0 To UBound($g_aSQL_Functions) - 1
                If StringLeft(StringUpper($g_aSQL_Functions[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                    ; Nur hinzufügen, wenn noch nicht im Array
                    If _ArraySearch($aMatches, $g_aSQL_Functions[$i]) = -1 Then
                        _ArrayAdd($aMatches, $g_aSQL_Functions[$i])
                    EndIf
                EndIf
            Next

            ; SQL-Datentypen prüfen
            For $i = 0 To UBound($g_aSQL_DataTypes) - 1
                If StringLeft(StringUpper($g_aSQL_DataTypes[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                    ; Nur hinzufügen, wenn noch nicht im Array
                    If _ArraySearch($aMatches, $g_aSQL_DataTypes[$i]) = -1 Then
                        _ArrayAdd($aMatches, $g_aSQL_DataTypes[$i])
                    EndIf
                EndIf
            Next

            ; Tabellennamen prüfen
            Local $sTables = GUICtrlRead($g_idTableCombo, 1)
            If $sTables <> "" Then
                Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
                For $i = 0 To UBound($aTableList) - 1
                    If $aTableList[$i] <> "" Then
                        If StringLeft(StringUpper($aTableList[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                            ; Nur hinzufügen, wenn noch nicht im Array
                            If _ArraySearch($aMatches, $aTableList[$i]) = -1 Then
                                _ArrayAdd($aMatches, $aTableList[$i])
                            EndIf
                        EndIf
                    EndIf
                Next
            EndIf

            ; Spaltennamen prüfen
            If UBound($g_aTableColumns) > 0 Then
                For $i = 0 To UBound($g_aTableColumns) - 1
                    If $g_aTableColumns[$i] <> "" Then
                        If StringLeft(StringUpper($g_aTableColumns[$i]), StringLen($sUpperCurrentWord)) = $sUpperCurrentWord Then
                            ; Nur hinzufügen, wenn noch nicht im Array
                            If _ArraySearch($aMatches, $g_aTableColumns[$i]) = -1 Then
                                _ArrayAdd($aMatches, $g_aTableColumns[$i])
                            EndIf
                        EndIf
                    EndIf
                Next
            EndIf

        ; Kontext-spezifische Analyse
        Local $sTextBeforeCursor = StringLeft($sText, $iCursorPos)

        ; Prüfen ob wir im FROM- oder JOIN-Kontext sind (=> Tabellennamen vorrangig)
        If StringRegExp(StringUpper($sTextBeforeCursor), "(FROM|JOIN)\s+[^\s,;]* *$") Then
            ; Zusätzlich alle Tabellennamen auflisten, auch wenn sie nicht mit dem aktuellen Wort beginnen
            Local $sTables = GUICtrlRead($g_idTableCombo, 1)
            If $sTables <> "" Then
                Local $aTableList = StringSplit($sTables, "|", $STR_NOCOUNT)
                For $i = 0 To UBound($aTableList) - 1
                    If $aTableList[$i] <> "" Then
                        ; Nur hinzufügen, wenn noch nicht in der Liste
                        If Not StringInStr("|" & $sMatches, "|" & $aTableList[$i] & "|") Then
                            $sMatches &= $aTableList[$i] & "|"
                        EndIf
                    EndIf
                Next
            EndIf
        EndIf

        ; Nach einem Tabellennamen und einem Punkt (table.) prüfen wir auf Spaltennamen
        If StringRegExp($sTextBeforeCursor, "([a-zA-Z0-9_]+)\.$") Then
            ; Tabellennamen aus dem Text extrahieren
            Local $aTableMatch = StringRegExp($sTextBeforeCursor, "([a-zA-Z0-9_]+)\.$", $STR_REGEXPARRAYMATCH)
            If IsArray($aTableMatch) And UBound($aTableMatch) > 0 Then
                Local $sTableName = $aTableMatch[0]

                ; Wenn es sich um die aktuelle Tabelle handelt, alle Spaltennamen anzeigen
                If $sTableName = $g_sCurrentTable And UBound($g_aTableColumns) > 0 Then
                    ; Alle Spaltennamen der aktuellen Tabelle anzeigen
                    $sMatches = ""  ; Liste zurücksetzen, nur Spaltennamen anzeigen
                    For $i = 0 To UBound($g_aTableColumns) - 1
                        If $g_aTableColumns[$i] <> "" Then
                            $sMatches &= $g_aTableColumns[$i] & "|"
                        EndIf
                    Next
                EndIf
            EndIf
        EndIf
    EndIf

    ; Zeige oder verstecke die Autovervollständigungsliste
    If $sMatches <> "" Then
        _LogInfo("Vorschläge gefunden: " & $sMatches)

        ; Position der Liste berechnen
        Local $aPosition = _GetAutoCompletePosition()
        _LogInfo("Position für Autovervollständigungsliste: X=" & $aPosition[0] & ", Y=" & $aPosition[1])

        ; Sicherstellen, dass die Liste existiert und korrekt angezeigt wird
        Local $hListWnd = GUICtrlGetHandle($g_hList)
        If Not IsHWnd($hListWnd) Then
            ; Falls das Handle ungültig ist, Liste neu erstellen
            _LogInfo("Liste nicht gefunden oder ungültig, erstelle neu")
            _InitSQLAutoComplete($g_hGUI, $g_hSQLRichEdit)
            $hListWnd = GUICtrlGetHandle($g_hList)
        EndIf

        ; Vorbereitungen für die Anzeige
        _GUICtrlListBox_ResetContent($hListWnd)
        _GUICtrlListBox_BeginUpdate($hListWnd)

        ; Listengröße anpassen - höher machen, wenn viele Einträge vorhanden sind
        Local $aEntries = StringSplit($sMatches, "|", $STR_NOCOUNT)
        Local $iEntryCount = UBound($aEntries)
        Local $iHeight = _Min(180, _Max(60, $iEntryCount * 20)) ; Mindestens 60px, maximal 180px
        Local $iWidth = 280 ; Standardbreite

        ; Bei langen Einträgen die Breite anpassen
        For $i = 0 To UBound($aEntries) - 1
            $iWidth = _Max($iWidth, StringLen($aEntries[$i]) * 10) ; Ungefähr 10 Pixel pro Zeichen
        Next
        $iWidth = _Min(400, $iWidth) ; Nicht breiter als 400px

        ; Listen-Eigenschaften setzen
        ControlMove($g_hGUI, "", $g_hList, $aPosition[0], $aPosition[1], $iWidth, $iHeight)

        ; Daten setzen und Update beenden
        GUICtrlSetData($g_hList, $sMatches)
        _GUICtrlListBox_EndUpdate($hListWnd)

        ; Zusätzliches Invalidieren und Neuzeichnen des Bereichs
        _WinAPI_InvalidateRect($g_hGUI, _WinAPI_CreateRect($aPosition[0], $aPosition[1], $aPosition[0] + $iWidth, $aPosition[1] + $iHeight))
        _WinAPI_UpdateWindow($g_hGUI)

        ; Liste anzeigen
        GUICtrlSetState($g_hList, $GUI_SHOW)
        GUICtrlSetState($g_hList, $GUI_FOCUS) ; Fokus auf die Liste setzen

        ; Ersten Eintrag auswählen
        $g_iListIndex = 0
        _GUICtrlListBox_SetCurSel($g_hList, $g_iListIndex)
    Else
        ; Bei keinen Vorschlägen die Liste ausblenden
        GUICtrlSetState($g_hList, $GUI_HIDE)
    EndIf
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

    ; Startposition des Wortes ermitteln
    $iStart = $iCursorPos
    While $iStart > 0 And StringRegExp(StringMid($sText, $iStart, 1), "[a-zA-Z0-9_.]")
        $iStart -= 1
    WEnd
    $iStart += 1

    ; Wort aus dem Text extrahieren
    Return StringMid($sText, $iStart, $iCursorPos - $iStart)
EndFunc

; ===============================================================================================================================
; Func.....: _AcceptSQLAutoCompleteSelection
; Beschreibung: Übernimmt den ausgewählten Eintrag aus der Autovervollständigungsliste
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _AcceptSQLAutoCompleteSelection()
    ; Prüfen, ob Liste sichtbar ist
    If BitAND(GUICtrlGetState($g_hList), $GUI_SHOW) <> $GUI_SHOW Then
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

    ; Liste ausblenden
    GUICtrlSetState($g_hList, $GUI_HIDE)

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
    Local $bListVisible = (BitAND(GUICtrlGetState($g_hList), $GUI_SHOW) = $GUI_SHOW)

    ; Wenn Liste sichtbar ist, Tasten für die Navigation verarbeiten
    If $bListVisible Then
        ; ESC-Taste zum Ausblenden der Liste
        If $iKey = 0x1B Then  ; VK_ESCAPE
            _LogInfo("ESC-Taste gedrückt - Liste ausblenden")
            GUICtrlSetState($g_hList, $GUI_HIDE)
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
        _CheckSQLInputForAutoComplete()
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
    ; Verwende _IsPressed aus <Misc.au3> statt _WinAPI_GetKeyState
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
    EndIf

    Return $aPos
EndFunc

; ===============================================================================================================================
; Func.....: _RemoveDuplicateEntries
; Beschreibung: Entfernt Duplikate aus der pipe-getrennten Liste
; Parameter.: $sList - Pipe-getrennte Liste
; Rückgabe..: Bereinigte Liste ohne Duplikate
; ===============================================================================================================================
Func _RemoveDuplicateEntries($sList)
    ; In Array umwandeln
    Local $aEntries = StringSplit($sList, "|", $STR_NOCOUNT)

    ; Duplikate entfernen
    Local $aUniqueEntries[0]
    For $i = 0 To UBound($aEntries) - 1
        If _ArraySearch($aUniqueEntries, $aEntries[$i]) = -1 Then
            _ArrayAdd($aUniqueEntries, $aEntries[$i])
        EndIf
    Next

    ; Wieder zu String zusammenfügen
    Local $sResult = ""
    For $i = 0 To UBound($aUniqueEntries) - 1
        $sResult &= $aUniqueEntries[$i] & "|"
    Next

    ; Letztes Pipe-Zeichen entfernen
    If $sResult <> "" Then $sResult = StringTrimRight($sResult, 1)

    Return $sResult
EndFunc

; ===============================================================================================================================
; Func.....: _UpdateSQLKeywords
; Beschreibung: Aktualisiert die Liste der SQL-Keywords (für Abwärtskompatibilität)
; Parameter.: $aNewKeywords - Array mit zusätzlichen Keywords
; Rückgabe..: Anzahl der Keywords in der zentralen Definition
; ===============================================================================================================================
Func _UpdateSQLKeywords($aNewKeywords)
    _LogInfo("_UpdateSQLKeywords: Diese Funktion ist veraltet. Bitte sql_keywords.au3 direkt aktualisieren.")
    ; Keine Aktion notwendig, da wir jetzt die zentrale Definition verwenden
    Return UBound($g_aSQL_AllKeywords)
EndFunc

; ===============================================================================================================================
; Func.....: _HandleSQLAutoCompleteEvent
; Beschreibung: Event-Handler für Doppelklick in der Autovervollständigungsliste
; Parameter.: $iEvent - Event-ID
; Rückgabe..: True wenn Event verarbeitet wurde, sonst False
; ===============================================================================================================================
Func _HandleSQLAutoCompleteEvent($iEvent)
    ; Nur bei Autovervollständigung und wenn Liste sichtbar
    If Not $g_bSQLEditorMode Or Not $g_bAutoCompleteActive Then Return False
    If GUICtrlGetState($g_hList) <> BitOR($GUI_SHOW, $GUI_ENABLE) Then Return False

    ; Prüfen, ob das Event von der Liste stammt
    If $iEvent = $g_hList Then
        _AcceptSQLAutoCompleteSelection()
        Return True
    EndIf

    Return False
EndFunc