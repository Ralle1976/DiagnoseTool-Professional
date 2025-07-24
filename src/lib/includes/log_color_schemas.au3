#include-once
#include <ColorConstants.au3>

; =============================================
; Konstanten und Definitionen für Farbschemata
; =============================================

; Schema-Option für benutzerdefinierte Farben
Global Const $SCHEMA_CUSTOM = "Benutzerdefiniert"

; Vordefinierte Farbschemata als Array mit Name und Farbwerten
; [0] = Schema-Name
; [1] = ERROR-Farbe
; [2] = WARNING-Farbe
; [3] = INFO-Farbe
; [4] = DEBUG-Farbe
; [5] = TRACE-Farbe
; [6] = TRUNCATED-Farbe

; Grundlegende Farbschemata
Global $g_aColorSchemas[6][7] = [ _
    ["Standard", 0xFF0000, 0xFFAA00, 0xFFFFFF, 0xF0F0F0, 0xF8F8F8, 0xFF00FF], _
    ["Hoher Kontrast", 0xFF0000, 0xFFAA00, 0xFFFFFF, 0xC0C0C0, 0xE0E0E0, 0xFF00FF], _
    ["Pastell", 0xFFCCCC, 0xFFEECC, 0xCCFFCC, 0xCCCCFF, 0xEEEEFF, 0xFFCCFF], _
    ["Monochrom", 0xCCCCCC, 0xDDDDDD, 0xFFFFFF, 0xEEEEEE, 0xF5F5F5, 0xE0E0E0], _
    ["Blautöne", 0xDDDDFF, 0xCCCCFF, 0xEEEEFF, 0xBBBBFF, 0xAAAAFF, 0x9999FF], _
    ["Grüntöne", 0xFFCCCC, 0xFFFFCC, 0xDDFFDD, 0xCCFFCC, 0xBBFFBB, 0xAAFFAA] _
]

; Erweiterte Farbpalette mit vordefinierten Farben
Global $g_aPaletteColors[5][8] = [ _
    [0xFFCCCC, 0xFFDDDD, 0xFFEEEE, 0xFFCCDD, 0xFFAABB, 0xFFAACC, 0xFF9999, 0xFF8888], _ ; Rottöne
    [0xFFEECC, 0xFFDDCC, 0xFFCC99, 0xFFBB88, 0xFFAA77, 0xFFCC88, 0xFFDD99, 0xFFEEAA], _ ; Orangetöne
    [0xFFFFFF, 0xF8F8F8, 0xF0F0F0, 0xE8E8E8, 0xE0E0E0, 0xD8D8D8, 0xD0D0D0, 0xC8C8C8], _ ; Weißtöne
    [0xEEEEFF, 0xDDDDFF, 0xCCCCFF, 0xBBBBFF, 0xAAAAFF, 0x9999FF, 0x8888FF, 0x7777FF], _ ; Blautöne
    [0xCCFFCC, 0xBBFFBB, 0xAAFFAA, 0x99FF99, 0x88FF88, 0x77FF77, 0x66FF66, 0x55FF55]  _ ; Grüntöne
]

; =============================================
; Funktionen für Schemas
; =============================================

; Füllt eine ComboBox mit den verfügbaren Farbschemata
Func _PopulateSchemaCombo($idCombo)
    ; Alle definierten Schemas als Liste holen
    Local $sSchemaList = ""
    
    ; Alle Schema-Namen sammeln
    For $i = 0 To UBound($g_aColorSchemas) - 1
        $sSchemaList &= $g_aColorSchemas[$i][0] & "|"
    Next
    
    ; Benutzerdefiniert hinzufügen
    $sSchemaList &= $SCHEMA_CUSTOM
    
    ; ComboBox mit Schemas füllen
    GUICtrlSetData($idCombo, $sSchemaList)
    
    ; Standardmäßig "Standard" auswählen
    GUICtrlSetData($idCombo, "Standard")
    
    Return True
EndFunc

; Wendet ein Schema auf die Log-Level-Farben an
Func _ApplyColorSchemaByName($sSchemaName, ByRef $aLogLevelColors)
    ; Schema-Index suchen
    Local $iSchemaIndex = -1
    
    ; Im Schema-Array suchen
    For $i = 0 To UBound($g_aColorSchemas) - 1
        If $g_aColorSchemas[$i][0] = $sSchemaName Then
            $iSchemaIndex = $i
            ExitLoop
        EndIf
    Next
    
    ; Schema gefunden und anwenden
    If $iSchemaIndex >= 0 Then
        For $i = 0 To UBound($aLogLevelColors) - 1
            $aLogLevelColors[$i][1] = $g_aColorSchemas[$iSchemaIndex][$i+1]
        Next
        Return True
    EndIf
    
    ; Schema nicht gefunden
    Return False
EndFunc

; Prüft, ob das aktuelle Schema einem vordefinierten Schema entspricht
Func _IdentifyCurrentSchema($aLogLevelColors)
    ; Für alle definierten Schemas prüfen
    For $iSchema = 0 To UBound($g_aColorSchemas) - 1
        Local $bMatches = True
        
        ; Alle Log-Level-Farben mit dem Schema vergleichen
        For $i = 0 To UBound($aLogLevelColors) - 1
            If $aLogLevelColors[$i][1] <> $g_aColorSchemas[$iSchema][$i+1] Then
                $bMatches = False
                ExitLoop
            EndIf
        Next
        
        ; Wenn alle Farben übereinstimmen, Schema gefunden
        If $bMatches Then
            Return $g_aColorSchemas[$iSchema][0]
        EndIf
    Next
    
    ; Kein übereinstimmendes Schema gefunden
    Return $SCHEMA_CUSTOM
EndFunc