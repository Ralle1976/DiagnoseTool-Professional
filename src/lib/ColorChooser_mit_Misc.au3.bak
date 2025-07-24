#include-once
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <Misc.au3> ; Wird benötigt für _ChooseColor() und andere Funktionen
; Umbenennung der Funktion und Verweis auf originale Misc.au3 Implementierung
; Diese Version bietet eine erweiterte Oberfläche, nutzt aber im Hintergrund _ChooseColor aus Misc.au3

; Die benötigten Konstanten und Strukturen (CC_RGBINIT, CC_FULLOPEN, CC_ANYCOLOR, tagCHOOSECOLOR)
; werden automatisch aus Misc.au3 importiert

; #FUNCTION# ====================================================================================================================
; Name ..........: _ChooseColorDialog
; Description ...: Zeigt einen Windows-Farbauswahldialog an
; Syntax ........: _ChooseColorDialog($iDefaultColor = 0xFFFFFF, $hWndOwner = 0, $iFlags = 0)
; Parameters ....: $iDefaultColor - Standardfarbe (RGB-Wert).
;                  $hWndOwner     - Handle des übergeordneten Fensters.
;                  $iFlags        - Zusätzliche Flags für den Dialog.
; Return values .: Erfolg - Die ausgewählte Farbe (RGB)
;                  Fehler - -1 und setzt @error auf 1
; Author ........: Diagnose-Tool Entwickler
; Modified ......: 2025-03-22
; ===============================================================================================================================
Func _ChooseColorDialog($iDefaultColor = 0xFFFFFF, $hWndOwner = 0, $iFlags = 0)
    ; Diese Funktion ist ein Wrapper für die Standard _ChooseColor() Funktion aus Misc.au3
    ; Standardflags, wenn keine angegeben sind
    If $iFlags = 0 Then
        $iFlags = BitOR($CC_ANYCOLOR, $CC_FULLOPEN, $CC_RGBINIT)
    EndIf

    ; Verwende die Standard-Funktion aus Misc.au3 und übergib Parameter
    Local $iResult = _ChooseColor(1, $iDefaultColor, 0, $hWndOwner)
    If @error Then Return SetError(1, 0, -1)

    ; Ausgewählte Farbe zurückgeben
    Return $iResult
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GetColorName
; Description ...: Gibt einen Farbnamen für einen RGB-Wert zurück
; Syntax ........: _GetColorName($iColor)
; Parameters ....: $iColor        - RGB Farbwert.
; Return values .: Farbname als String
; Author ........: Diagnose-Tool Entwickler
; Modified ......: 2025-03-22
; ===============================================================================================================================
Func _GetColorName($iColor)
    Local $iRed = BitAND(BitShift($iColor, 16), 0xFF)
    Local $iGreen = BitAND(BitShift($iColor, 8), 0xFF)
    Local $iBlue = BitAND($iColor, 0xFF)

    ; Grundlegende Farberkennung
    If $iRed > 200 And $iGreen < 100 And $iBlue < 100 Then
        Return "Rot"
    ElseIf $iRed > 200 And $iGreen > 150 And $iBlue < 100 Then
        Return "Orange"
    ElseIf $iRed > 200 And $iGreen > 200 And $iBlue < 100 Then
        Return "Gelb"
    ElseIf $iRed < 100 And $iGreen > 200 And $iBlue < 100 Then
        Return "Grün"
    ElseIf $iRed < 100 And $iGreen > 150 And $iBlue > 200 Then
        Return "Cyan"
    ElseIf $iRed < 100 And $iGreen < 100 And $iBlue > 200 Then
        Return "Blau"
    ElseIf $iRed > 150 And $iGreen < 100 And $iBlue > 200 Then
        Return "Magenta"
    ElseIf $iRed > 200 And $iGreen > 200 And $iBlue > 200 Then
        Return "Weiß"
    ElseIf $iRed < 100 And $iGreen < 100 And $iBlue < 100 Then
        Return "Schwarz"
    ElseIf Abs($iRed - $iGreen) < 30 And Abs($iRed - $iBlue) < 30 And Abs($iGreen - $iBlue) < 30 Then
        Return "Grau"
    EndIf

    ; Fallback, wenn keine eindeutige Farbe erkannt wurde
    Return "RGB(" & $iRed & "," & $iGreen & "," & $iBlue & ")"
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GetContrastColor
; Description ...: Berechnet eine Kontrastfarbe (schwarz oder weiß) für optimale Lesbarkeit
; Syntax ........: _GetContrastColor($iBackgroundColor)
; Parameters ....: $iBackgroundColor - RGB-Hintergrundfarbe.
; Return values .: Kontrastfarbe ($COLOR_BLACK oder $COLOR_WHITE)
; Author ........: Diagnose-Tool Entwickler
; Modified ......: 2025-03-22
; ===============================================================================================================================
Func _GetContrastColor($iBackgroundColor)
    Local $iRed = BitAND(BitShift($iBackgroundColor, 16), 0xFF)
    Local $iGreen = BitAND(BitShift($iBackgroundColor, 8), 0xFF)
    Local $iBlue = BitAND($iBackgroundColor, 0xFF)

    ; Berechnung der Luminanz nach W3C-Formel
    Local $iLuminance = (0.299 * $iRed + 0.587 * $iGreen + 0.114 * $iBlue) / 255

    ; Wenn die Luminanz hoch ist (heller Hintergrund), verwende schwarzen Text, sonst weißen
    If $iLuminance > 0.5 Then
        Return $COLOR_BLACK
    Else
        Return $COLOR_WHITE
    EndIf
EndFunc