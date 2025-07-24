#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <ColorChooser.au3>

; Globale Variablen für die Log-Level-Farben
Global $g_aLogLevelColors[6][3] = [ _
    ["ERROR",           0xFF0000, "Fehler (ERROR, FATAL, CRITICAL)"], _
    ["WARNING",         0xFFAA00, "Warnungen (WARNING, WARN)"], _
    ["INFO",            0xFFFFFF, "Informationen (INFO, INFORMATION)"], _
    ["DEBUG",           0xF0F0F0, "Debug-Meldungen (DEBUG)"], _
    ["TRACE",           0xF8F8F8, "Trace-Meldungen (TRACE)"], _
    ["TRUNCATED",       0xFF00FF, "Abgeschnittene Einträge (TRUNCATED)"] _
]

; Farbschemata für schnelle Auswahl
;~ Global $g_aColorSchemes[4][8] = [ _
;~     ["Standard", 0xFF0000, 0xFFAA00, 0xFFFFFF, 0xF0F0F0, 0xF8F8F8, 0xFF00FF, 0xFF0080], _
;~     ["Hoher Kontrast", 0xFF0000, 0xFFAA00, 0xFFFFFF, 0xC0C0C0, 0xE0E0E0, 0xFF00FF, 0xFF0080], _
;~     ["Pastell", 0xFFCCCC, 0xFFEECC, 0xCCFFCC, 0xCCCCFF, 0xEEEEFF, 0xFFCCFF, 0xFFBBFF], _
;~     ["Monochrom", 0xCCCCCC, 0xDDDDDD, 0xFFFFFF, 0xEEEEEE, 0xF5F5F5, 0xE0E0E0, 0xD0D0D0] _
;~ ]

; Pfad zur INI-Datei (wird vom Hauptprogramm gesetzt)
Global $g_sLogLevelColorsIniPath = ""

;~ ; Funktion zum Umwandeln von RGB zu BGR für Windows API
;~ Func _RGB_to_BGR($iRGBColor)
;~     ; Exakte RGB/BGR-Umwandlung sicherstellen
;~     Local $iRed   = BitAND(BitShift($iRGBColor, 16), 0xFF)
;~     Local $iGreen = BitAND(BitShift($iRGBColor, 8), 0xFF)
;~     Local $iBlue  = BitAND($iRGBColor, 0xFF)

;~     ; BGR-Format zurückgeben (Blau in den höchsten 8 Bits, Rot in den niedrigsten)
;~     Return BitOR(BitShift($iBlue, 16), BitShift($iGreen, 8), $iRed)
;~ EndFunc

;~ ; Funktion zur Umwandlung von BGR (Windows COLORREF) in RGB
;~ Func _BGRToRGB($nColor)
;~     ; Extrahiere die einzelnen Farbkomponenten aus dem BGR-Wert
;~     Local $iRed   = BitAND($nColor, 0xFF)                     ; Rot (niedrigstes Byte)
;~     Local $iGreen = BitAND(BitShift($nColor, 8), 0xFF)         ; Grün (mittleres Byte)
;~     Local $iBlue  = BitAND(BitShift($nColor, 16), 0xFF)        ; Blau (höchstes Byte)

;~     ; Erstelle den RGB-Wert (Rot in den höchsten 8 Bits, Grün in den mittleren, Blau in den niedrigsten)
;~     Return BitOR(BitShift($iRed, 16), BitShift($iGreen, 8), $iBlue)
;~ EndFunc



; Ermittelt die Farbe für ein bestimmtes Log-Level in RGB-Format
Func _GetLogLevelColor($sLevel)
    ; Log-Level in Großbuchstaben umwandeln für den Vergleich
    Local $sUpperLevel = StringUpper($sLevel)

    ; Debug-Ausgabe hinzufügen
    ConsoleWrite("GetLogLevelColor aufgerufen für Level: " & $sLevel & @CRLF)

    ; Unvollständige Einträge prüfen (höchste Priorität)
    If StringInStr($sUpperLevel, "TRUNCATED") Then
        ConsoleWrite("  > Gebe TRUNCATED Farbe zurück: 0x" & Hex($g_aLogLevelColors[5][1]) & @CRLF)
        Return $g_aLogLevelColors[5][1]  ; TRUNCATED-Farbe in RGB
    ElseIf StringInStr($sUpperLevel, "BESCHÄDIGT") Then
        ConsoleWrite("  > Gebe BESCHÄDIGT Farbe zurück: 0x" & Hex($g_aLogLevelColors[6][1]) & @CRLF)
        Return $g_aLogLevelColors[6][1]  ; SCHWER_BESCHÄDIGT-Farbe in RGB
    EndIf

    ; Dann die anderen Kategorien prüfen
    Switch True
        Case StringInStr($sUpperLevel, "ERROR") Or StringInStr($sUpperLevel, "FATAL") Or StringInStr($sUpperLevel, "CRITICAL")
            Return $g_aLogLevelColors[0][1]  ; ERROR-Farbe in RGB
        Case StringInStr($sUpperLevel, "WARN")
            Return $g_aLogLevelColors[1][1]  ; WARNING-Farbe in RGB
        Case StringInStr($sUpperLevel, "INFO")
            Return $g_aLogLevelColors[2][1]  ; INFO-Farbe in RGB
        Case StringInStr($sUpperLevel, "DEBUG")
            Return $g_aLogLevelColors[3][1]  ; DEBUG-Farbe in RGB
        Case StringInStr($sUpperLevel, "TRACE")
            Return $g_aLogLevelColors[4][1]  ; TRACE-Farbe in RGB
    EndSwitch

    ; Standardfarbe zurückgeben (INFO, falls nichts passt)
    Return $g_aLogLevelColors[2][1]  ; in RGB
EndFunc

; Speziell für die Windows API BGR-Format benötigt
Func _GetLogLevelColorBGR($sLevel)
    Return _GetLogLevelColor($sLevel) ;_RGB_to_BGR()
EndFunc

; Funktion zum Initialisieren der Log-Level-Farben
Func _InitLogLevelColors($sSettingsFile = "")
    ; Setze den Pfad zur INI-Datei
    If $sSettingsFile <> "" Then
        _SetLogLevelColorsIniPath($sSettingsFile)
    EndIf

    ; Lade die gespeicherten Farbeinstellungen
    Return _LoadLogLevelColors()
EndFunc