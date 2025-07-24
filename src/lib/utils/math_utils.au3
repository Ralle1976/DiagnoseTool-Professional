#cs
Mathematische Utility-Funktionen für das Diagnose-Tool
@author AssistentClaude
@version 1.0
#ce

; Sichere Min-Funktion
Func SafeMin($a, $b)
    If $a < $b Then
        Return $a
    Else
        Return $b
    EndIf
EndFunc
