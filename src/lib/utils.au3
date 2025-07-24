#include-once
#include <Array.au3>
#include <File.au3>

; Hilfsfunktionen für Dictionaries (Key-Value-Speicher)
Func Dict_Create()
    Local $oDict = ObjCreate("Scripting.Dictionary")
    Return $oDict
EndFunc

; Globale Dict-Funktionen, die vom gesamten Programm verwendet werden
Func Dict_Add($oDict, $sKey, $vValue)
    $oDict.Add($sKey, $vValue)
EndFunc

Func Dict_Set($oDict, $sKey, $vValue)
    $oDict.Item($sKey) = $vValue
EndFunc

Func Dict_Get($oDict, $sKey)
    Return $oDict.Item($sKey)
EndFunc

Func Dict_Exists($oDict, $sKey)
    Return $oDict.Exists($sKey)
EndFunc

Func Dict_Keys($oDict)
    Return $oDict.Keys()
EndFunc

; Verschiedene Hilfsfunktionen
Func _SetGlobalVariable($sVarName, $vValue)
    Execute("Global $" & $sVarName & " = " & (IsString($vValue) ? '"' & $vValue & '"' : $vValue))
EndFunc

Func _GetGlobalVariable($sVarName)
    Return Execute("$" & $sVarName)
EndFunc

; Archiv-Extraktionsverzeichnis setzen
Func _SetArchiveExtractDirectory($sPath)
    Global $g_sExtractDir = $sPath
EndFunc
