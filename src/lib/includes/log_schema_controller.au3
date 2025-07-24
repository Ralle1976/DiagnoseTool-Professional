#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>

#include "..\log_level_colors.au3"
#include "log_color_schemas.au3"
#include "log_color_helpers.au3"

; =============================================
; Farbschema-Controller für den Farbkonfigurator
; =============================================

; Globale Variablen für den Schema-Controller
Global $g_sActiveSchema = "Standard"      ; Aktuell aktives Schema
Global $g_bCustomizedSchema = False       ; Flag für benutzerdefinierte Anpassungen

; Initialisiert den Schema-Controller
Func _InitSchemaController()
    ; Aktives Schema identifizieren
    $g_sActiveSchema = _IdentifyCurrentSchema($g_aLogLevelColors)

    ; Custom-Flag setzen, wenn benutzerdefiniertes Schema
    $g_bCustomizedSchema = ($g_sActiveSchema = $SCHEMA_CUSTOM)

    Return True
EndFunc

; Wechselt zu einem anderen Schema und aktualisiert die Vorschau
Func _SwitchSchema($sSchemaName, $idSchemaCombo, $idHinweisLabel, $aPreviewControls)
    ; Sicherstellen, dass Schema-Name gültig ist
    If $sSchemaName = $SCHEMA_CUSTOM And Not $g_bCustomizedSchema Then
        ; Keine Aktion, wenn "Benutzerdefiniert" nicht aktiv ist
        GUICtrlSetData($idHinweisLabel, "Bitte wähle erst ein vordefiniertes Schema aus oder passe Farben an.")
        Return False
    EndIf

    ; Schema anwenden, wenn es sich nicht um "Benutzerdefiniert" handelt
    If $sSchemaName <> $SCHEMA_CUSTOM Then
        ; Schema anwenden
        _ApplyColorSchemaByName($sSchemaName, $g_aLogLevelColors)

        ; Vorschau aktualisieren
        For $i = 0 To UBound($g_aLogLevelColors) - 1
            GUICtrlSetBkColor($aPreviewControls[$i], _WinAPI_SwitchColor($g_aLogLevelColors[$i][1]))
        Next

        ; Globale Variablen aktualisieren
        $g_sActiveSchema = $sSchemaName
        $g_bCustomizedSchema = False

        ; Feedback für Benutzer
        Local $sText = "Hinweis: Das Farbschema '" & $sSchemaName & "' wurde angewendet." & @CRLF & _
                       "Alle Farben wurden zurückgesetzt."
        GUICtrlSetData($idHinweisLabel, $sText)

        Return True
    EndIf

    ; Bei "Benutzerdefiniert" nichts tun
    GUICtrlSetData($idHinweisLabel, "Benutzerdefiniertes Schema ist aktiv.")
    Return True
EndFunc

; Behandelt Änderungen an einzelnen Farben
Func _HandleColorChange($iLevelIndex, $iNewColor, $idSchemaCombo, $idHinweisLabel, $aPreviewControls)
    ; Farbe im Array aktualisieren
    $g_aLogLevelColors[$iLevelIndex][1] = $iNewColor

    ; Vorschau aktualisieren
    GUICtrlSetBkColor($aPreviewControls[$iLevelIndex], _WinAPI_SwitchColor($iNewColor))

    ; Auf benutzerdefiniert umstellen, wenn noch nicht geschehen
    If Not $g_bCustomizedSchema Then
        $g_bCustomizedSchema = True
        $g_sActiveSchema = $SCHEMA_CUSTOM
        GUICtrlSetData($idSchemaCombo, $SCHEMA_CUSTOM)

        ; Hinweis anzeigen
        GUICtrlSetData($idHinweisLabel, "Hinweis: Du hast eine Farbe angepasst." & @CRLF & _
                                     "Das Schema wurde automatisch auf 'Benutzerdefiniert' umgestellt.")
    EndIf

    Return True
EndFunc

; Speichert das aktuelle Schema
Func _SaveCurrentSchema()
    ; Aktuelle Farben speichern
    _SaveLogLevelColors()

    Return True
EndFunc

; Stellt die Standardfarben wieder her
Func _ResetToDefaultSchema($idSchemaCombo, $idHinweisLabel, $aPreviewControls)
    ; Standard-Schema anwenden
    _ApplyColorSchemaByName("Standard", $g_aLogLevelColors)

    ; Vorschau aktualisieren
    For $i = 0 To UBound($g_aLogLevelColors) - 1
        GUICtrlSetBkColor($aPreviewControls[$i], _WinAPI_SwitchColor($g_aLogLevelColors[$i][1]))
    Next

    ; Globale Variablen aktualisieren
    $g_sActiveSchema = "Standard"
    $g_bCustomizedSchema = False

    ; UI aktualisieren
    GUICtrlSetData($idSchemaCombo, "Standard")
    GUICtrlSetData($idHinweisLabel, "Alle Farben wurden auf das Standard-Schema zurückgesetzt.")

    Return True
EndFunc