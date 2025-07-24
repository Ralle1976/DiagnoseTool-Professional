#cs
Archiv Utility Funktionen
#ce

#include-once
#include "..\constants.au3"

Func SetArchiveExtractDirectory($sNewPath)
    If FileExists($sNewPath) Then
        $g_sExtractDir = $sNewPath
        Return True
    Else
        ConsoleWrite("Fehler: Verzeichnis existiert nicht - " & $sNewPath & @CRLF)
        Return False
    EndIf
EndFunc
