#include-once
#include <File.au3>
#include <Date.au3>
#include "logging.au3"

; Konstanten für Debug-Level
Global Const $DEBUG_NONE = 0
Global Const $DEBUG_ERROR = 1
Global Const $DEBUG_WARNING = 2
Global Const $DEBUG_INFO = 3
Global Const $DEBUG_VERBOSE = 4
Global Const $DEBUG_TRACE = 5

; Globale Debug-Einstellungen
Global $g_iDebugLevel = $DEBUG_INFO
Global $g_bDebugToFile = True
Global $g_bDebugToConsole = True
Global $g_sDebugLogFile = @ScriptDir & "\debug.log"

; Initialisiert Debug-System mit benutzerdefinierten Einstellungen
Func _DebugInit($iLevel = $DEBUG_INFO, $bToFile = True, $bToConsole = True, $sLogFile = "")
    $g_iDebugLevel = $iLevel
    $g_bDebugToFile = $bToFile
    $g_bDebugToConsole = $bToConsole
    
    If $sLogFile <> "" Then
        $g_sDebugLogFile = $sLogFile
    EndIf
    
    ; Log-Datei mit Header initialisieren, wenn gewünscht
    If $g_bDebugToFile Then
        Local $hFile = FileOpen($g_sDebugLogFile, $FO_APPEND)
        If $hFile <> -1 Then
            FileWriteLine($hFile, "==================================================")
            FileWriteLine($hFile, "Debug-Log gestartet am " & _NowCalc())
            FileWriteLine($hFile, "Debug-Level: " & _DebugLevelToString($g_iDebugLevel))
            FileWriteLine($hFile, "==================================================")
            FileClose($hFile)
        EndIf
    EndIf
    
    _DebugInfo("Debug-System initialisiert")
EndFunc

; Schreibt eine Debug-Nachricht mit dem angegebenen Level
Func _DebugMessage($sMessage, $iLevel = $DEBUG_INFO)
    If $iLevel > $g_iDebugLevel Then Return
    
    ; Level als Text
    Local $sLevelText = _DebugLevelToString($iLevel)
    
    ; Zeitstempel
    Local $sTimestamp = _NowCalc()
    
    ; Vollständige Nachricht mit Zeitstempel und Level
    Local $sFullMessage = $sTimestamp & " [" & $sLevelText & "] " & $sMessage
    
    ; In Konsole ausgeben, wenn gewünscht
    If $g_bDebugToConsole Then
        ConsoleWrite($sFullMessage & @CRLF)
    EndIf
    
    ; In Datei schreiben, wenn gewünscht
    If $g_bDebugToFile Then
        Local $hFile = FileOpen($g_sDebugLogFile, $FO_APPEND)
        If $hFile <> -1 Then
            FileWriteLine($hFile, $sFullMessage)
            FileClose($hFile)
        EndIf
    EndIf
EndFunc

; Konvertiert einen Debug-Level in einen String
Func _DebugLevelToString($iLevel)
    Switch $iLevel
        Case $DEBUG_NONE
            Return "NONE"
        Case $DEBUG_ERROR
            Return "ERROR"
        Case $DEBUG_WARNING
            Return "WARNING"
        Case $DEBUG_INFO
            Return "INFO"
        Case $DEBUG_VERBOSE
            Return "VERBOSE"
        Case $DEBUG_TRACE
            Return "TRACE"
        Case Else
            Return "UNKNOWN"
    EndSwitch
EndFunc

; Helper-Funktionen für verschiedene Debug-Levels
Func _DebugError($sMessage)
    _DebugMessage($sMessage, $DEBUG_ERROR)
EndFunc

Func _DebugWarning($sMessage)
    _DebugMessage($sMessage, $DEBUG_WARNING)
EndFunc

Func _DebugInfo($sMessage)
    _DebugMessage($sMessage, $DEBUG_INFO)
EndFunc

Func _DebugVerbose($sMessage)
    _DebugMessage($sMessage, $DEBUG_VERBOSE)
EndFunc

Func _DebugTrace($sMessage)
    _DebugMessage($sMessage, $DEBUG_TRACE)
EndFunc

; Gibt den Inhalt einer Variable für Debug-Zwecke aus
Func _DebugVar($sVarName, $vVarValue, $iLevel = $DEBUG_INFO)
    Local $sType = VarGetType($vVarValue)
    Local $sValue
    
    Switch $sType
        Case "Array"
            If IsArray($vVarValue) Then
                $sValue = "{Array mit " & UBound($vVarValue) & " Elementen}"
                _DebugMessage($sVarName & " = " & $sValue, $iLevel)
                
                ; Bei 2D-Arrays
                If UBound($vVarValue, 0) = 2 Then
                    For $i = 0 To UBound($vVarValue) - 1
                        Local $sRowContent = ""
                        For $j = 0 To UBound($vVarValue, 2) - 1
                            If $j > 0 Then $sRowContent &= ", "
                            $sRowContent &= $vVarValue[$i][$j]
                        Next
                        _DebugMessage($sVarName & "[" & $i & "] = [" & $sRowContent & "]", $iLevel)
                    Next
                Else
                    ; Bei 1D-Arrays
                    For $i = 0 To UBound($vVarValue) - 1
                        _DebugMessage($sVarName & "[" & $i & "] = " & $vVarValue[$i], $iLevel)
                    Next
                EndIf
            Else
                $sValue = "{Ungültiges Array}"
                _DebugMessage($sVarName & " = " & $sValue, $iLevel)
            EndIf
            
        Case "Object"
            $sValue = "{Objekt}"
            _DebugMessage($sVarName & " = " & $sValue, $iLevel)
            
        Case "Binary"
            $sValue = "{Binärdaten, Länge: " & BinaryLen($vVarValue) & "}"
            _DebugMessage($sVarName & " = " & $sValue, $iLevel)
            
        Case "String"
            If StringLen($vVarValue) > 100 Then
                $sValue = '"' & StringLeft($vVarValue, 100) & '..." (Länge: ' & StringLen($vVarValue) & ')'
            Else
                $sValue = '"' & $vVarValue & '"'
            EndIf
            _DebugMessage($sVarName & " = " & $sValue, $iLevel)
            
        Case Else
            $sValue = $vVarValue
            _DebugMessage($sVarName & " = " & $sValue & " (Typ: " & $sType & ")", $iLevel)
    EndSwitch
EndFunc