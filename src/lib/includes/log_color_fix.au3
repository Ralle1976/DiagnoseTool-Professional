#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>

; =============================================
; Korrekturmaßnahmen für Farbdarstellungsprobleme und Palette-Events
; Autor: Ralle1976, 2025-03-29
; =============================================

; =============================================
; Konstanten für Farbkorrektur
; =============================================
Global Const $COLOR_FIX_USE_RGB = 0     ; RGB-Farben direkt verwenden
Global Const $COLOR_FIX_USE_BGR = 1     ; BGR-Konvertierung verwenden
Global Const $COLOR_FIX_AUTO = 2        ; Automatisch bestimmen

; Globale Variablen
Global $g_iColorFixMode = $COLOR_FIX_AUTO  ; Standardmäßig automatisch bestimmen
Global $g_bPaletteEventFix = True           ; Event-Fix für Palette aktivieren

; =============================================
; Verbesserte Farbkonvertierungsfunktionen
; =============================================

; Robuste RGB zu BGR Konvertierung
Func _ColorFix_RGB_to_BGR($iRGBColor)
    Local $iRed   = BitAND(BitShift($iRGBColor, 16), 0xFF)
    Local $iGreen = BitAND(BitShift($iRGBColor, 8), 0xFF)
    Local $iBlue  = BitAND($iRGBColor, 0xFF)
    
    ; Debug-Information
    ConsoleWrite("RGB->BGR: " & Hex($iRGBColor, 6) & " -> BGR: R=" & $iRed & ", G=" & $iGreen & ", B=" & $iBlue & @CRLF)
    
    ; BGR-Format zurückgeben
    Return BitOR(BitShift($iBlue, 16), BitShift($iGreen, 8), $iRed)
EndFunc

; BGR zu RGB Konvertierung
Func _ColorFix_BGR_to_RGB($iBGRColor)
    Local $iBlue  = BitAND(BitShift($iBGRColor, 16), 0xFF)
    Local $iGreen = BitAND(BitShift($iBGRColor, 8), 0xFF)
    Local $iRed   = BitAND($iBGRColor, 0xFF)
    
    ; Debug-Information
    ConsoleWrite("BGR->RGB: " & Hex($iBGRColor, 6) & " -> RGB: B=" & $iBlue & ", G=" & $iGreen & ", R=" & $iRed & @CRLF)
    
    ; RGB-Format zurückgeben
    Return BitOR(BitShift($iRed, 16), BitShift($iGreen, 8), $iBlue)
EndFunc

; Farbe basierend auf dem Fix-Modus konvertieren
Func _ColorFix_GetFixedColor($iColor, $iFixMode = -1)
    ; Wenn kein Fix-Modus angegeben, globalen verwenden
    If $iFixMode = -1 Then $iFixMode = $g_iColorFixMode
    
    ; Basierend auf Fix-Modus konvertieren
    Switch $iFixMode
        Case $COLOR_FIX_USE_RGB
            ; RGB-Format direkt verwenden
            Return $iColor
            
        Case $COLOR_FIX_USE_BGR
            ; BGR-Konvertierung anwenden
            Return _ColorFix_RGB_to_BGR($iColor)
            
        Case $COLOR_FIX_AUTO
            ; Automatisch bestimmen basierend auf Windows-Version
            If @OSVersion = "WIN_10" Or @OSVersion = "WIN_11" Then
                ; Neuere Windows-Versionen verwenden meist direkt RGB
                Return $iColor
            Else
                ; Ältere Windows-Versionen könnten BGR benötigen
                Return _ColorFix_RGB_to_BGR($iColor)
            EndIf
    EndSwitch
    
    ; Standardmäßig RGB zurückgeben
    Return $iColor
EndFunc

; =============================================
; Verbesserte ListView-Farbgebung
; =============================================

; Farbkorrektur für ListView-Items
Func _ColorFix_WM_NOTIFY_Handler($hWnd, $iMsg, $wParam, $lParam, $aLogLevelColors)
    ; NMLVCUSTOMDRAW-Struktur
    Local $tagNMLVCUSTOMDRAW = "struct;hwnd hWndFrom;uint_ptr IDFrom;int Code;dword dwDrawStage;handle hdc;" & _
                             "struct;long left;long top;long right;long bottom;endstruct;" & _
                             "dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;endstruct;" & _
                             "dword clrText;dword clrTextBk;int iSubItem;dword dwItemType;" & _
                             "dword clrFace;int iIconEffect;int iIconPhase;int iPartId;int iStateId;" & _
                             "struct;long left;long top;long right;long bottom;endstruct;uint uAlign"

    ; NMHDR-Struktur auslesen
    Local $tNMHDR = DllStructCreate("hwnd hWndFrom; uint_ptr IDFrom; int Code", $lParam)
    Local $hWndFrom = DllStructGetData($tNMHDR, "hWndFrom")
    Local $iCode = DllStructGetData($tNMHDR, "Code")

    ; Für CUSTOMDRAW-Events
    If $iCode = $NM_CUSTOMDRAW Then
        ; Vollständige CUSTOMDRAW-Struktur auslesen
        Local $tNMLVCUSTOMDRAW = DllStructCreate($tagNMLVCUSTOMDRAW, $lParam)
        Local $iDrawStage = DllStructGetData($tNMLVCUSTOMDRAW, "dwDrawStage")

        ; In PREPAINT-Phase Items individuell behandeln
        If $iDrawStage = $CDDS_PREPAINT Then
            ; ITEM-Modus anfordern
            Return $CDRF_NOTIFYITEMDRAW
        ElseIf $iDrawStage = $CDDS_ITEMPREPAINT Then
            ; Item-Informationen extrahieren
            Local $iRow = DllStructGetData($tNMLVCUSTOMDRAW, "dwItemSpec")
            
            ; Bei gültiger Zeile
            If $iRow >= 0 And $iRow < UBound($aLogLevelColors) Then
                ; Farbkorrektur anwenden
                Local $iFixedColor = _ColorFix_GetFixedColor($aLogLevelColors[$iRow][1])
                
                ; Hintergrundfarbe setzen
                DllStructSetData($tNMLVCUSTOMDRAW, "clrTextBk", $iFixedColor)
                
                ; Debug-Information
                ConsoleWrite("ListView Zeile " & $iRow & " - Original: 0x" & Hex($aLogLevelColors[$iRow][1], 6) & _
                           ", Korrigiert: 0x" & Hex($iFixedColor, 6) & @CRLF)
                
                Return $CDRF_NEWFONT
            EndIf
        EndIf
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; =============================================
; Verbessertes Palette-Event-Handling
; =============================================

; Überprüft alle Palette-Controls auf Klick-Events
Func _ColorFix_CheckPaletteEvents($nMsg, $aPaletteControls, $aPaletteColors, ByRef $bEventHandled)
    ; Wenn bereits ein Event behandelt wurde, nichts tun
    If $bEventHandled Then Return False
    
    ; Alle Palette-Controls überprüfen
    For $row = 0 To UBound($aPaletteControls) - 1
        For $col = 0 To UBound($aPaletteControls, 2) - 1
            ; Wenn das Control-Event übereinstimmt
            If $nMsg = $aPaletteControls[$row][$col] Then
                ; Debug-Ausgabe
                ConsoleWrite("Palette-Event erkannt: Row=" & $row & ", Col=" & $col & ", ID=" & $aPaletteControls[$row][$col] & @CRLF)
                
                ; Event als behandelt markieren
                $bEventHandled = True
                
                ; Farbwert zurückgeben
                Return $aPaletteColors[$row][$col]
            EndIf
        Next
    Next
    
    ; Kein Event gefunden
    Return False
EndFunc

; Initialisiert die Palette-Controls mit optimierten Event-Handlern
Func _ColorFix_InitializePaletteControls($aPaletteControls, $aPaletteColors, $iPaletteStartX, $iPaletteStartY, $iPaletteWidth, $iPaletteHeight)
    ; Debug-Ausgabe
    ConsoleWrite("=== Initialisiere optimierte Palette-Controls ===" & @CRLF)
    
    ; Palette-Controls erstellen
    For $row = 0 To UBound($aPaletteControls) - 1
        For $col = 0 To UBound($aPaletteControls, 2) - 1
            ; Control mit optimierten Parametern erstellen
            $aPaletteControls[$row][$col] = GUICtrlCreateLabel("", _
                $iPaletteStartX + ($col * $iPaletteWidth), _
                $iPaletteStartY + ($row * $iPaletteHeight), _
                $iPaletteWidth - 5, $iPaletteHeight - 5)
            
            ; Eigenschaften setzen
            GUICtrlSetBkColor($aPaletteControls[$row][$col], $aPaletteColors[$row][$col])
            GUICtrlSetStyle($aPaletteControls[$row][$col], BitOR($SS_NOTIFY, $SS_CENTER))
            GUICtrlSetCursor($aPaletteControls[$row][$col], 0) ; Hand-Cursor
            
            ; Klickbaren Bereich vergrößern
            ;GUICtrlSetPos($aPaletteControls[$row][$col], $iPaletteStartX + ($col * $iPaletteWidth) - 2, _
            ;    $iPaletteStartY + ($row * $iPaletteHeight) - 2, $iPaletteWidth - 1, $iPaletteHeight - 1)
            
            ; Debug-Ausgabe
            ConsoleWrite("Optimiertes Palette-Control erstellt: Row=" & $row & ", Col=" & $col & ", ID=" & $aPaletteControls[$row][$col] & @CRLF)
        Next
    Next
    
    Return True
EndFunc

; =============================================
; Fix-Modus Auswahl und Konfiguration
; =============================================

; Setzt den Fix-Modus
Func _ColorFix_SetFixMode($iMode)
    $g_iColorFixMode = $iMode
    
    ; Debug-Ausgabe
    Switch $iMode
        Case $COLOR_FIX_USE_RGB
            ConsoleWrite("Farbkorrektur-Modus: RGB (direkt)" & @CRLF)
        Case $COLOR_FIX_USE_BGR
            ConsoleWrite("Farbkorrektur-Modus: BGR (konvertiert)" & @CRLF)
        Case $COLOR_FIX_AUTO
            ConsoleWrite("Farbkorrektur-Modus: Automatisch" & @CRLF)
    EndSwitch
    
    Return True
EndFunc

; Aktiviert oder deaktiviert den Palette-Event-Fix
Func _ColorFix_EnablePaletteFix($bEnable)
    $g_bPaletteEventFix = $bEnable
    
    ; Debug-Ausgabe
    If $bEnable Then
        ConsoleWrite("Palette-Event-Fix: Aktiviert" & @CRLF)
    Else
        ConsoleWrite("Palette-Event-Fix: Deaktiviert" & @CRLF)
    EndIf
    
    Return True
EndFunc

; =============================================
; Diagnose-Funktionen
; =============================================

; Führt einen automatischen Farbtest durch, um den optimalen Fix-Modus zu bestimmen
Func _ColorFix_AutoDetect()
    ; Hier könnte ein komplexerer Algorithmus stehen, der das System testet
    ; und den optimalen Fix-Modus bestimmt
    
    ; Beispielhaft AutoIt-Version und Windows-Version prüfen
    Local $sAutoItVersion = @AutoItVersion
    Local $sWindowsVersion = @OSVersion
    
    ; Debug-Ausgabe
    ConsoleWrite("=== Automatische Fix-Erkennung ===" & @CRLF)
    ConsoleWrite("AutoIt-Version: " & $sAutoItVersion & @CRLF)
    ConsoleWrite("Windows-Version: " & $sWindowsVersion & @CRLF)
    
    ; Entscheidung basierend auf Windows-Version
    Switch $sWindowsVersion
        Case "WIN_10", "WIN_11"
            ; Neuere Windows-Versionen
            _ColorFix_SetFixMode($COLOR_FIX_USE_RGB)
            
        Case "WIN_8", "WIN_81", "WIN_7", "WIN_VISTA"
            ; Ältere Windows-Versionen
            _ColorFix_SetFixMode($COLOR_FIX_USE_BGR)
            
        Case Else
            ; Fallback für unbekannte Versionen
            _ColorFix_SetFixMode($COLOR_FIX_USE_RGB)
    EndSwitch
    
    Return True
EndFunc

; Zeigt einen Diagnose-Dialog mit Fix-Optionen
Func _ColorFix_ShowDiagnoseDialog()
    Local $hGUI = GUICreate("Farbkorrektur-Diagnose", 400, 300)
    
    ; Überschrift
    GUICtrlCreateLabel("Farbkorrektur-Einstellungen", 20, 20, 300, 25)
    GUICtrlSetFont(-1, 12, 800)
    
    ; Beschreibung
    GUICtrlCreateLabel("Wählen Sie den Farbkorrektur-Modus:", 20, 50, 300, 20)
    
    ; Optionen
    Local $idRGB = GUICtrlCreateRadio("RGB-Modus (direkt)", 40, 80, 200, 20)
    Local $idBGR = GUICtrlCreateRadio("BGR-Modus (konvertiert)", 40, 110, 200, 20)
    Local $idAuto = GUICtrlCreateRadio("Automatisch erkennen", 40, 140, 200, 20)
    
    ; Vorschaubereich
    GUICtrlCreateGroup("Vorschau", 20, 170, 360, 60)
    Local $idPreview1 = GUICtrlCreateLabel("RGB-Rot (0xFF0000)", 40, 190, 150, 30, $SS_SUNKEN)
    GUICtrlSetBkColor($idPreview1, 0xFF0000)
    Local $idPreview2 = GUICtrlCreateLabel("BGR-Rot (0x0000FF)", 210, 190, 150, 30, $SS_SUNKEN)
    GUICtrlSetBkColor($idPreview2, 0x0000FF)
    
    ; Buttons
    Local $idApplyButton = GUICtrlCreateButton("Anwenden", 100, 250, 100, 30)
    Local $idCloseButton = GUICtrlCreateButton("Schließen", 210, 250, 100, 30)
    
    ; Standardmäßig Auto auswählen
    GUICtrlSetState($idAuto, $GUI_CHECKED)
    
    ; GUI anzeigen
    GUISetState(@SW_SHOW, $hGUI)
    
    ; Event-Schleife
    While 1
        Local $nMsg = GUIGetMsg()
        
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $idCloseButton
                GUIDelete($hGUI)
                Return False
                
            Case $idApplyButton
                ; Gewählten Modus anwenden
                If GUICtrlRead($idRGB) = $GUI_CHECKED Then
                    _ColorFix_SetFixMode($COLOR_FIX_USE_RGB)
                ElseIf GUICtrlRead($idBGR) = $GUI_CHECKED Then
                    _ColorFix_SetFixMode($COLOR_FIX_USE_BGR)
                Else
                    _ColorFix_SetFixMode($COLOR_FIX_AUTO)
                    _ColorFix_AutoDetect()
                EndIf
                
                ; Dialog schließen
                GUIDelete($hGUI)
                Return True
        EndSwitch
    WEnd
EndFunc