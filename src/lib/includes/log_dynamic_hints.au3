#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

; =============================================
; Dynamisches Hinweissystem für den Farbkonfigurator
; =============================================

; Globale Variablen für das Hinweissystem
Global $g_hHintGUI = 0           ; GUI-Handle für den Hinweis
Global $g_idHintLabel = 0        ; Label-ID für den Hinweistext
Global $g_iHintTimeout = 5000    ; Timeout für automatisches Ausblenden (5 Sekunden)
Global $g_iHintTimerID = 0       ; Timer-ID für automatisches Ausblenden

; Erstellt einen dynamischen Hinweis, der über dem Kontrollelement angezeigt wird
Func _ShowDynamicHint($hParentGUI, $sText, $iX, $iY, $iWidth = 400, $iHeight = 60, $bAutoHide = True)
    ; Bestehenden Hinweis entfernen, falls vorhanden
    If $g_hHintGUI <> 0 Then
        _HideDynamicHint()
    EndIf
    
    ; Neue Hinweis-GUI erstellen
    $g_hHintGUI = GUICreate("", $iWidth, $iHeight, $iX, $iY, BitOR($WS_POPUP, $WS_BORDER), BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW), $hParentGUI)
    
    ; Hintergrund einstellen
    GUISetBkColor(0xFFFFC0, $g_hHintGUI)  ; Helles Gelb für Hinweise
    
    ; Hinweistext-Label erstellen
    $g_idHintLabel = GUICtrlCreateLabel($sText, 10, 10, $iWidth - 20, $iHeight - 20)
    GUICtrlSetBkColor($g_idHintLabel, -2)  ; Transparent
    GUICtrlSetFont($g_idHintLabel, 9, 400, 0)
    
    ; GUI anzeigen
    GUISetState(@SW_SHOW, $g_hHintGUI)
    
    ; Timer für automatisches Ausblenden setzen, falls gewünscht
    If $bAutoHide Then
        $g_iHintTimerID = TimerInit()
    EndIf
    
    Return $g_hHintGUI
EndFunc

; Aktualisiert den Text des dynamischen Hinweises
Func _UpdateDynamicHint($sText, $bResetTimer = True)
    ; Prüfen, ob Hinweis existiert
    If $g_hHintGUI = 0 Or $g_idHintLabel = 0 Then
        Return False
    EndIf
    
    ; Text aktualisieren
    GUICtrlSetData($g_idHintLabel, $sText)
    
    ; Timer zurücksetzen, falls gewünscht
    If $bResetTimer And $g_iHintTimerID <> 0 Then
        $g_iHintTimerID = TimerInit()
    EndIf
    
    Return True
EndFunc

; Blendet den dynamischen Hinweis aus
Func _HideDynamicHint()
    ; Prüfen, ob Hinweis existiert
    If $g_hHintGUI = 0 Then
        Return False
    EndIf
    
    ; GUI ausblenden und löschen
    GUIDelete($g_hHintGUI)
    
    ; Variablen zurücksetzen
    $g_hHintGUI = 0
    $g_idHintLabel = 0
    $g_iHintTimerID = 0
    
    Return True
EndFunc

; Prüft, ob der Hinweis ausgeblendet werden sollte (basierend auf Timer)
Func _CheckHintTimeout()
    ; Prüfen, ob ein aktiver Hinweis mit Timer existiert
    If $g_hHintGUI <> 0 And $g_iHintTimerID <> 0 Then
        ; Zeit seit Timer-Start prüfen
        If TimerDiff($g_iHintTimerID) > $g_iHintTimeout Then
            ; Timeout erreicht, Hinweis ausblenden
            _HideDynamicHint()
            Return True
        EndIf
    EndIf
    
    Return False
EndFunc

; Position des Hinweises aktualisieren (z.B. bei Fenster-Verschiebung)
Func _UpdateHintPosition($iX, $iY)
    ; Prüfen, ob Hinweis existiert
    If $g_hHintGUI = 0 Then
        Return False
    EndIf
    
    ; Position aktualisieren
    WinMove($g_hHintGUI, "", $iX, $iY)
    
    Return True
EndFunc