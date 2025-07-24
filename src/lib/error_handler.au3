#include-once
#include <Array.au3>
#include <Crypt.au3>
#include <MsgBoxConstants.au3>
#include "logging.au3"

; Globale Variablen für Error Handler
Global $g_aErrorStack[0]      ; Stack für Error-Tracking
Global $g_bErrorHandlerActive = True
Global $g_OnErrorFunc = ""    ; Benutzerdefinierte Error-Handler-Funktion

; Error Handler aktivieren
Func _ErrorHandlerInit($sOnErrorFunc = "")
    $g_bErrorHandlerActive = True
    $g_OnErrorFunc = $sOnErrorFunc

    ; AutoIt Error Handler setzen
    OnAutoItExitRegister("_ErrorHandler")

    _LogInfo("Error Handler initialisiert")
    Return True
EndFunc

; Haupt-Error-Handler
Func _ErrorHandler()
    If Not $g_bErrorHandlerActive Then Return

    Local $iError = @error
    Local $iExtended = @extended
    Local $sScript = @ScriptName
    Local $iLine = @ScriptLineNumber
    Local $sFunction = _GetCurrentFunction()

    ; Error Details sammeln
    Local $sErrorInfo = StringFormat("Error in %s at line %d (Function: %s)", $sScript, $iLine, $sFunction)
    Local $sErrorDetails = StringFormat("Error Code: %d, Extended: %d", $iError, $iExtended)

    ; Fehler loggen
    _LogError($sErrorInfo, $sErrorDetails)

    ; Error auf Stack legen
    Local $aError = [$iError, $iExtended, $sScript, $iLine, $sFunction]
    _ArrayAdd($g_aErrorStack, $aError)

    ; Benutzerdefinierte Error-Handler-Funktion aufrufen wenn vorhanden
    If $g_OnErrorFunc <> "" Then
        Call($g_OnErrorFunc, $aError)
    EndIf
EndFunc

; Aktuelle Funktion ermitteln
Func _GetCurrentFunction()
    Local $aBacktrace = StringSplit(@ScriptLineNumber, ":")
    If IsArray($aBacktrace) And $aBacktrace[0] >= 2 Then
        Return $aBacktrace[2]
    EndIf
    Return "Unknown"
EndFunc

; Fehlertext für Error-Code ermitteln
Func _GetErrorText($iError)
    Local $sText = ""
    Switch $iError
        Case 1
            $sText = "Fehler beim Dateizugriff"
        Case 2
            $sText = "Ungültige Funktion"
        Case 3
            $sText = "Suchfehler"
        Case 4
            $sText = "Speicherzugriffsfehler"
        Case 5
            $sText = "Ungültiger Parameter"
        Case 6
            $sText = "Kein Fenster gefunden"
        Case 7
            $sText = "Timeout"
        Case 8
            $sText = "Array außerhalb der Grenzen"
        Case 9
            $sText = "DLL-Funktionsaufruf fehlgeschlagen"
        Case Else
            $sText = "Unbekannter Fehler"
    EndSwitch
    Return $sText & " (" & $iError & ")"
EndFunc

; Letzten Fehler vom Stack holen
Func _GetLastError()
    Local $iSize = UBound($g_aErrorStack)
    If $iSize > 0 Then
        Local $aError = $g_aErrorStack[$iSize - 1]
        _ArrayDelete($g_aErrorStack, $iSize - 1)
        Return $aError
    EndIf
    Return SetError(1, 0, 0)
EndFunc

; Error Stack leeren
Func _ClearErrorStack()
    ReDim $g_aErrorStack[0]
EndFunc

; Error Handler deaktivieren
Func _ErrorHandlerShutdown()
    $g_bErrorHandlerActive = False
    _ClearErrorStack()
    $g_OnErrorFunc = ""

    ; AutoIt Error Handler zurücksetzen
    OnAutoItExitUnRegister("")

    _LogInfo("Error Handler deaktiviert")
EndFunc

; Fehler anzeigen (für UI)
Func _ShowError($sTitle, $sMessage)
    _LogError($sTitle & ": " & $sMessage)
    Return MsgBox($MB_ICONERROR + $MB_OK, $sTitle, $sMessage)
EndFunc