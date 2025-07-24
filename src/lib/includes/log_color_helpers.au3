#include-once
#include <GUIConstantsEx.au3>
#include <ColorConstants.au3>

; Globale Variablen für die Farbkonfigurator-Hilfsfunktionen
Global $g_bUserModifiedColor = False       ; Flag, das anzeigt ob der Benutzer eine Farbe geändert hat
Global $g_sCurrentSchema = "Standard"      ; Aktuell ausgewähltes Schema
Global $g_iPreselectedLogLevel = -1        ; Ausgewähltes Log-Level für Farbpalette

; Konstanten für die Hinweistexte
Global Enum $HINT_COLOR_MODIFIED, $HINT_SCHEMA_APPLIED, $HINT_SCHEMA_READONLY, $HINT_SETTINGS_SAVED

; =============================================
; Statusmeldungen für den Benutzer
; =============================================

; Gibt einen Hinweistext basierend auf der Aktion zurück
Func _GetUserHint($iHintType)
    Switch $iHintType
        Case $HINT_COLOR_MODIFIED
            Return "Hinweis: Du hast eine Farbe angepasst." & @CRLF & "Das Schema wurde automatisch auf 'Benutzerdefiniert' umgestellt."

        Case $HINT_SCHEMA_APPLIED
            Return "Hinweis: Das Farbschema '" & $g_sCurrentSchema & "' wurde angewendet." & @CRLF & "Alle Farben wurden zurückgesetzt."

        Case $HINT_SCHEMA_READONLY
            Return "Hinweis: Das ausgewählte Farbschema ist schreibgeschützt." & @CRLF & "Änderungen sind nur über 'Benutzerdefiniert' möglich."

        Case $HINT_SETTINGS_SAVED
            Return "Hinweis: Deine Farbanpassungen wurden gespeichert und beim nächsten Start wieder geladen."

        Case Else
            Return ""
    EndSwitch
EndFunc

; =============================================
; Zustandsmanagement für den Farbkonfigurator
; =============================================

; Erkennt, ob eine Farbe geändert wurde und setzt das Schema auf "Benutzerdefiniert"
Func _HandleColorModification($idSchemaCombo, $idHinweisLabel)
    ; Wenn noch nicht auf Benutzerdefiniert umgestellt
    If Not $g_bUserModifiedColor Then
        $g_bUserModifiedColor = True
        GUICtrlSetData($idSchemaCombo, "Benutzerdefiniert")
        GUICtrlSetData($idHinweisLabel, _GetUserHint($HINT_COLOR_MODIFIED))
    EndIf
EndFunc

; Prüft, ob das aktuelle Farbschema einem der vordefinierten Schemata entspricht
Func _IsCurrentSchemaCustom($aLogLevelColors, $aColorSchemes)
    Local $bMatches = False
    Local $iSchemaCount = UBound($aColorSchemes)
    Local $iLevelCount = UBound($aLogLevelColors)

    ; Prüfe für jedes vordefinierte Schema
    For $iSchema = 0 To $iSchemaCount - 1
        $bMatches = True

        ; Prüfe alle Farben dieses Schemas
        For $i = 0 To $iLevelCount - 1
            ; Wenn eine Farbe nicht übereinstimmt, ist das Schema nicht identisch
            If $aLogLevelColors[$i][1] <> $aColorSchemes[$iSchema][$i+1] Then
                $bMatches = False
                ExitLoop
            EndIf
        Next

        ; Wenn alle Farben übereinstimmen, haben wir ein vordefiniertes Schema
        If $bMatches Then
            Return False
        EndIf
    Next

    ; Auch für spezielle Schemata (Blautöne, Grüntöne) prüfen
    ; Blautöne-Schema überprüfen
    If _MatchesBlueSchema($aLogLevelColors) Then
        Return False
    EndIf

    ; Grüntöne-Schema überprüfen
    If _MatchesGreenSchema($aLogLevelColors) Then
        Return False
    EndIf

    ; Wenn keine Übereinstimmung gefunden wurde, handelt es sich um ein benutzerdefiniertes Schema
    Return True
EndFunc

; Prüft, ob das aktuelle Schema dem "Blautöne"-Schema entspricht
Func _MatchesBlueSchema($aLogLevelColors)
    Return ($aLogLevelColors[0][1] = 0xDDDDFF And _
            $aLogLevelColors[1][1] = 0xCCCCFF And _
            $aLogLevelColors[2][1] = 0xEEEEFF And _
            $aLogLevelColors[3][1] = 0xBBBBFF And _
            $aLogLevelColors[4][1] = 0xAAAAFF And _
            $aLogLevelColors[5][1] = 0x9999FF)
EndFunc

; Prüft, ob das aktuelle Schema dem "Grüntöne"-Schema entspricht
Func _MatchesGreenSchema($aLogLevelColors)
    Return ($aLogLevelColors[0][1] = 0xFFCCCC And _
            $aLogLevelColors[1][1] = 0xFFFFCC And _
            $aLogLevelColors[2][1] = 0xDDFFDD And _
            $aLogLevelColors[3][1] = 0xCCFFCC And _
            $aLogLevelColors[4][1] = 0xBBFFBB And _
            $aLogLevelColors[5][1] = 0xAAFFAA)
EndFunc

; =============================================
; Farbauswahl-Funktionen
; =============================================

; Verarbeitet Klicks auf die Farbpalette
Func _HandlePaletteClick($idPalette, $aLogLevelColors, $idPreviewControls, $idSchemaCombo, $idHinweisLabel)
    ; Wenn kein Level ausgewählt ist, nichts tun
    If $g_iPreselectedLogLevel < 0 Then
        Return False
    EndIf

    ; Farbe aus der Palette anwenden
    $aLogLevelColors[$g_iPreselectedLogLevel][1] = $idPalette

    ; Vorschau aktualisieren
    If IsArray($idPreviewControls) And $g_iPreselectedLogLevel < UBound($idPreviewControls) Then
        GUICtrlSetBkColor($idPreviewControls[$g_iPreselectedLogLevel], $idPalette)
    EndIf

    ; Auf benutzerdefiniert umschalten
    _HandleColorModification($idSchemaCombo, $idHinweisLabel)

    Return True
EndFunc

; Verarbeitet die Vorauswahl eines Log-Levels für die Farbpalette
Func _SelectLogLevelForPalette($iLevelIndex, $aLevelLabels, $idHinweisLabel, $aLogLevelColors)
    ; Zurücksetzen aller Markierungen
    For $i = 0 To UBound($aLevelLabels) - 1
        GUICtrlSetColor($aLevelLabels[$i], 0x000000)  ; Standardfarbe: Schwarz
    Next

    ; Auswahl setzen
    $g_iPreselectedLogLevel = $iLevelIndex

    ; Ausgewähltes Label markieren
    If $iLevelIndex >= 0 And $iLevelIndex < UBound($aLevelLabels) - 1 Then
        GUICtrlSetColor($aLevelLabels[$iLevelIndex], 0x0000FF)  ; Blau für die Auswahl
        GUICtrlSetData($idHinweisLabel, "Logtyp '" & $aLogLevelColors[$iLevelIndex][2] & "' ausgewählt. Wähle eine Farbe aus der Palette unten.")
    EndIf

EndFunc

; =============================================
; ListView-Verarbeitung für Echtzeit-Vorschau
; =============================================

; Erzwingt das Neuzeichnen der ListView für die Echtzeit-Vorschau
Func _ForceListViewRedraw($hListView, $aExampleEntries)
    ; Sicherstellen, dass das Handle gültig ist
    If Not IsHWnd($hListView) Then Return False

    ; ListView zurücksetzen
    _GUICtrlListView_DeleteAllItems($hListView)

    ; ListView mit Beispieldaten füllen
    For $i = 0 To UBound($aExampleEntries) - 1
        Local $iIndex = _GUICtrlListView_AddItem($hListView, $aExampleEntries[$i][0])
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aExampleEntries[$i][1], 1)
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aExampleEntries[$i][2], 2)
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aExampleEntries[$i][3], 3)
    Next

    ; Bereich invalidieren und sofort neu zeichnen
    _WinAPI_InvalidateRect($hListView)
    _WinAPI_UpdateWindow($hListView)

    Return True
EndFunc

; Extrahiert den Log-Level aus einer ausgewählten ListView-Zeile
Func _GetLogLevelFromListViewSelection($idListView)
    ; Gewählte Zeile ermitteln
    Local $iSelectedItem = _GUICtrlListView_GetSelectedIndices($idListView, True)

    ; Wenn keine Auswahl, -1 zurückgeben
    If Not IsArray($iSelectedItem) Or $iSelectedItem[0] <= 0 Then
        Return -1
    EndIf

    ; Log-Level der ausgewählten Zeile auslesen (Spalte 1)
    Local $sLevel = _GUICtrlListView_GetItemText($idListView, $iSelectedItem[1], 1)

    Return $sLevel
EndFunc

; Ermittelt den Log-Level-Index aus einem Log-Level-String
Func _GetLogLevelIndexFromString($sLevel, $aLogLevelColors)
    ; Wenn TRUNCATED im Namen, spezielle Behandlung
    If StringInStr($sLevel, "TRUNCATED") Then
        Return 5  ; Index für TRUNCATED
    EndIf

    ; Level-String in Großbuchstaben umwandeln für Vergleich
    $sLevel = StringUpper($sLevel)

    For $i = 0 To UBound($aLogLevelColors) - 1
        ; Wenn der Level-String dem Muster entspricht
        If StringInStr($sLevel, StringReplace($aLogLevelColors[$i][0], "TRUNCATED", "")) Then
            Return $i
        EndIf
    Next

    ; Wenn nicht gefunden, -1 zurückgeben
    Return -1
EndFunc

; =============================================
; Farb-Konvertierungsfunktionen
; =============================================

; Konvertiert zwischen RGB und BGR Farbformaten
Func _SwapRedBlue($iColor)
    Local $iRed = BitAND(BitShift($iColor, 16), 0xFF)
    Local $iGreen = BitAND(BitShift($iColor, 8), 0xFF)
    Local $iBlue = BitAND($iColor, 0xFF)

    ; Rot und Blau vertauschen, Grün bleibt gleich
    Return BitOR(BitShift($iBlue, -16), BitShift($iGreen, -8), $iRed)
EndFunc