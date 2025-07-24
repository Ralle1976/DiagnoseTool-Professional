#include-once
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <Misc.au3> ; Für _ChooseColor() Funktion

; ===============================================================================================================================
; Func.....: _CustomChooseColor
; Beschreibung: Eine angepasste Version von _ChooseColor, die Konflikte mit der Misc.au3-Implementierung vermeidet
; Parameter.: $vReturnType - Der Rückgabetyp (0 = Array, 1 = RGB-Dezimalwert, 2 = RGB-Hex-String)
;             $iColorRef - Startfarbe (0-16,777,215 oder 0xRRGGBB)
;             $iRefType - Typ der übergebenen Farbe (0 = RGB-Dezimalwert, 1 = RGB-Werte in Array)
;             $hWndOwner - Handle des Elternfensters
; Rückgabe..: Je nach $vReturnType - Array, RGB-Dezimalwert oder RGB-Hex-String
; ===============================================================================================================================
Func _CustomChooseColor($vReturnType = 0, $iColorRef = 0, $iRefType = 0, $hWndOwner = 0)
    Local $tCC = DllStructCreate("dword Size;ptr hwndOwner;ptr hInstance;dword rgbResult;ptr lpCustColors;" & _
                               "dword Flags;lparam lCustData;ptr lpfnHook;ptr lpTemplateName")
    
    Local $tCustColor = DllStructCreate("dword[16]")
    For $i = 0 To 15
        DllStructSetData($tCustColor, 1, $i, $i + 1)
    Next
    
    DllStructSetData($tCC, "Size", DllStructGetSize($tCC))
    DllStructSetData($tCC, "hwndOwner", $hWndOwner)
    DllStructSetData($tCC, "hInstance", 0)
    
    ; Startfarbe setzen
    If $iRefType = 1 Then ; RGB-Werte in Array
        If UBound($iColorRef) < 3 Then Return SetError(1, 0, 0)
        $iColorRef = BitOR(BitShift($iColorRef[0], -16), BitShift($iColorRef[1], -8), $iColorRef[2])
    EndIf
    DllStructSetData($tCC, "rgbResult", $iColorRef)
    
    ; Custom Colors 
    DllStructSetData($tCC, "lpCustColors", DllStructGetPtr($tCustColor))
    
    ; Flags
    DllStructSetData($tCC, "Flags", BitOR($CC_ANYCOLOR, $CC_FULLOPEN, $CC_RGBINIT))
    DllStructSetData($tCC, "lCustData", 0)
    DllStructSetData($tCC, "lpfnHook", 0)
    DllStructSetData($tCC, "lpTemplateName", 0)
    
    Local $aResult = DllCall("comdlg32.dll", "int", "ChooseColor", "struct*", $tCC)
    If @error Then Return SetError(2, @error, 0)
    If $aResult[0] = 0 Then Return SetError(3, 0, 0)
    
    Local $vColor = DllStructGetData($tCC, "rgbResult")
    
    ; Ergebnis gemäß Rückgabetyp vorbereiten
    Switch $vReturnType
        Case 0 ; Array mit R,G,B-Werten
            Local $aRGB[3]
            $aRGB[0] = BitAND(BitShift($vColor, 16), 0xFF) ; Rot
            $aRGB[1] = BitAND(BitShift($vColor, 8), 0xFF)  ; Grün
            $aRGB[2] = BitAND($vColor, 0xFF)               ; Blau
            Return $aRGB
        Case 1 ; RGB-Dezimalwert
            Return $vColor
        Case 2 ; RGB-Hex-String
            Return "0x" & Hex($vColor, 6)
    EndSwitch
EndFunc

; Konstanten für ChooseColor
Global Const $CC_RGBINIT = 0x00000001
Global Const $CC_FULLOPEN = 0x00000002
Global Const $CC_ANYCOLOR = 0x00000100