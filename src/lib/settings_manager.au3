#include-once
#include <GUIConstantsEx.au3>
#include "logging.au3"

Global $__DEF_PASS_CHAR = -1
;~ Global Const $EM_SETPASSWORDCHAR = 0xCC
;~ Global Const $EM_GETPASSWORDCHAR = 0xD2

Func _Settings_ShowDialog()
    Local $hSettingsGUI = GUICreate("Einstellungen", 400, 400)

    ; ZIP-Einstellungen
    GUICtrlCreateGroup("ZIP-Einstellungen", 10, 10, 380, 80)
    GUICtrlCreateLabel("Passwort:", 20, 35, 60, 20)
    Local $idPassword = GUICtrlCreateInput(IniRead($g_sSettingsFile, "ZIP", "password", ""), 90, 32, 290, 20, $ES_PASSWORD)
    GUICtrlCreateLabel("Passwort anzeigen", 20, 60, 100, 20)
    Local $idShowPW = GUICtrlCreateCheckbox("", 120, 60, 20, 20)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Datenbank-Einstellungen
    GUICtrlCreateGroup("Datenbank-Einstellungen", 10, 100, 380, 80)
    GUICtrlCreateLabel("Max. Zeilen:", 20, 125, 70, 20)
    Local $idMaxRows = GUICtrlCreateInput(IniRead($g_sSettingsFile, "DATABASE", "max_rows", "1000"), 90, 122, 100, 20, $ES_NUMBER)
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    
    ; Temporäre Dateien-Einstellungen
    GUICtrlCreateGroup("Temporäre Dateien", 10, 190, 380, 120)
    GUICtrlCreateLabel("Datenbank nach Programmende löschen:", 20, 215, 250, 20)
    Local $idDeleteTemp = GUICtrlCreateCheckbox("", 280, 215, 20, 20)
    If IniRead($g_sSettingsFile, "GUI", "auto_clear_temp", "1") = "1" Then
        GUICtrlSetState($idDeleteTemp, $GUI_CHECKED)
    EndIf
    
    GUICtrlCreateLabel("Log-Dateien nach Programmende löschen:", 20, 245, 250, 20)
    Local $idDeleteLogs = GUICtrlCreateCheckbox("", 280, 245, 20, 20)
    If IniRead($g_sSettingsFile, "GUI", "auto_clear_logs", "0") = "1" Then
        GUICtrlSetState($idDeleteLogs, $GUI_CHECKED)
    Else
        GUICtrlSetState($idDeleteLogs, $GUI_UNCHECKED)
    EndIf
    
    GUICtrlCreateLabel("Extraktionsverzeichnis:", 20, 275, 120, 20)
    Local $idExtractDir = GUICtrlCreateInput(IniRead($g_sSettingsFile, "PATHS", "extract_dir", @TempDir & "\diagnose-tool\extracted"), 150, 272, 220, 20)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Buttons
    Local $idOK = GUICtrlCreateButton("OK", 230, 350, 75, 25)
    Local $idCancel = GUICtrlCreateButton("Abbrechen", 315, 350, 75, 25)

    GUISetState(@SW_SHOW, $hSettingsGUI)

    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE, $idCancel
                GUIDelete($hSettingsGUI)
                Return False
            Case $idShowPW
                If BitAND(GUICtrlRead($idShowPW), $GUI_CHECKED) = $GUI_CHECKED Then
                    _GUICtrlPasswordDisplay($idPassword, $idShowPW); Passwort in Klartext anzeigen
                Else
                    _GUICtrlPasswordDisplay($idPassword, 0) ; Passwort maskieren
                EndIf
            Case $idOK
                ; Einstellungen speichern
                IniWrite($g_sSettingsFile, "ZIP", "password", GUICtrlRead($idPassword))
                IniWrite($g_sSettingsFile, "DATABASE", "max_rows", GUICtrlRead($idMaxRows))
                
                ; Temporäre Dateien-Einstellungen speichern
                Local $iDeleteTemp = (GUICtrlRead($idDeleteTemp) = $GUI_CHECKED) ? 1 : 0
                IniWrite($g_sSettingsFile, "GUI", "auto_clear_temp", $iDeleteTemp)
                
                ; Logdateien-Einstellungen speichern
                Local $iDeleteLogs = (GUICtrlRead($idDeleteLogs) = $GUI_CHECKED) ? 1 : 0
                IniWrite($g_sSettingsFile, "GUI", "auto_clear_logs", $iDeleteLogs)
                
                ; Extraktionsverzeichnis speichern
                IniWrite($g_sSettingsFile, "PATHS", "extract_dir", GUICtrlRead($idExtractDir))
                
                _LogInfo("Einstellungen gespeichert")
                GUIDelete($hSettingsGUI)
                Return True
        EndSwitch
    WEnd
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _GUICtrlPasswordDisplay
; Description ...: Sets the visibility of the characters in any password styled input control.
; Syntax.........: _GUICtrlPasswordDisplay($iPasswordID [, $iShowFlag = -1])
; Parameters ....: $iPasswordID - The control identifier (controlID) of the input control as returned by
;                  +_GUICtrlCreatePassword or GUICtrlCreateInput.
;                  $iShowFlag - [optional] A flag to determine whether or not to show the actual contents of the input control
;                  |1 = reveal letters eg. "password", this is the default.
;                  |0 = mask letters eg. "********".
; Return values .: Success      - True
;                  Failure      - False
; Author ........: smartee
; Modified.......: ProgAndy
; Remarks .......:
; Related .......: _GUICtrlCreatePassword, _GUICtrlPasswordCheckbox
; Link ..........;
; Example .......; Yes
; ===============================================================================================================================
Func _GUICtrlPasswordDisplay($iPasswordID, $iShowFlag = -1)
    If $__DEF_PASS_CHAR = -1 Then $__DEF_PASS_CHAR = GUICtrlSendMsg($iPasswordID, $EM_GETPASSWORDCHAR, 0, 0)
    If $iShowFlag = -1 Then $iShowFlag = 1
    If $iShowFlag Then
        GUICtrlSendMsg($iPasswordID, $EM_SETPASSWORDCHAR, 0, 0)
    Else
        GUICtrlSendMsg($iPasswordID, $EM_SETPASSWORDCHAR, $__DEF_PASS_CHAR, 0)
    EndIf
    Local $aRes = DllCall("user32.dll", "int", "RedrawWindow", "hwnd", GUICtrlGetHandle($iPasswordID), "ptr", 0, "ptr", 0, "dword", 5)
    If @error Or $aRes[0] = 0 Then Return SetError(1, 0, False)
    Return True
EndFunc   ;==>_GUICtrlPasswordDisplay