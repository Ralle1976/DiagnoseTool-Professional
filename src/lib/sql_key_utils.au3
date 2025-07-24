; Titel.......: SQL-Key-Utils - Tastaturabfragefunktionen
; Beschreibung: Eigene Implementierung von Tastaturabfragefunktionen, um Konflikte zu vermeiden
; Autor.......: 2025-04-24
; ===============================================================================================================================

#include-once
#include <WinAPI.au3>

; ===============================================================================================================================
; Func.....: _SQL_IsKeyPressed
; Beschreibung: Prüft, ob eine bestimmte Taste gedrückt ist (eigene Implementierung statt _IsPressed)
; Parameter.: $iKey - Virtueller Tastencode (z.B. 0x11 für CTRL)
; Rückgabe..: True wenn die Taste gedrückt ist, sonst False
; ===============================================================================================================================
Func _SQL_IsKeyPressed($iKey)
    ; Benutzerdefinierte Implementierung von _IsPressed, die Misc.au3 nicht benötigt
    Return BitAND(_WinAPI_GetAsyncKeyState($iKey), 0x8000) <> 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsCtrlPressed
; Beschreibung: Prüft, ob die Strg-Taste gedrückt ist
; Parameter.: Keine
; Rückgabe..: True wenn Strg gedrückt ist, sonst False
; ===============================================================================================================================
Func _SQL_IsCtrlPressed()
    Return _SQL_IsKeyPressed(0x11) ; VK_CONTROL
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsShiftPressed
; Beschreibung: Prüft, ob die Shift-Taste gedrückt ist
; Parameter.: Keine
; Rückgabe..: True wenn Shift gedrückt ist, sonst False
; ===============================================================================================================================
Func _SQL_IsShiftPressed()
    Return _SQL_IsKeyPressed(0x10) ; VK_SHIFT
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsAltPressed
; Beschreibung: Prüft, ob die Alt-Taste gedrückt ist
; Parameter.: Keine
; Rückgabe..: True wenn Alt gedrückt ist, sonst False
; ===============================================================================================================================
Func _SQL_IsAltPressed()
    Return _SQL_IsKeyPressed(0x12) ; VK_MENU
EndFunc
