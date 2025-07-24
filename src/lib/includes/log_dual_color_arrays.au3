#include-once
#include <WinAPIGdi.au3>
#include <ColorConstants.au3>

; =============================================
; Dual-Array Farbverwaltung für Log-Level-Farben
; Autor: Ralle1976, 2025-03-30
; =============================================

; RGB-Array (für GUI-Elemente wie Labels)
Global $g_aLogLevelColorsRGB[6][3] = [ _
    ["ERROR",     0xFF0000, "Fehler (ERROR, FATAL, CRITICAL)"], _
    ["WARNING",   0x00AAFF, "Warnungen (WARNING, WARN)"], _      ; RGB: Gelb/Orange
    ["INFO",      0xFFFFFF, "Informationen (INFO, INFORMATION)"], _
    ["DEBUG",     0xF0F0F0, "Debug-Meldungen (DEBUG)"], _
    ["TRACE",     0xF8F8F8, "Trace-Meldungen (TRACE)"], _
    ["TRUNCATED", 0xFF00FF, "Abgeschnittene Einträge (TRUNCATED)"] _
]

; BGR-Array (für ListView und Windows API)
Global $g_aLogLevelColorsBGR[6]

; =============================================
; Initialisierungsfunktionen
; =============================================

; Initialisiert die BGR-Farben aus dem RGB-Array
Func _InitDualColorArrays()
    ; Debug-Ausgabe
    ConsoleWrite("=== Initialisiere Dual-Color-Arrays ===" & @CRLF)
    
    ; BGR-Farben berechnen
    For $i = 0 To UBound($g_aLogLevelColorsRGB) - 1
        $g_aLogLevelColorsBGR[$i] = _WinAPI_SwitchColor($g_aLogLevelColorsRGB[$i][1])
        
        ; Debug-Ausgabe
        ConsoleWrite("Level: " & $g_aLogLevelColorsRGB[$i][0] & _
                   " | RGB: 0x" & Hex($g_aLogLevelColorsRGB[$i][1], 6) & _
                   " | BGR: 0x" & Hex($g_aLogLevelColorsBGR[$i], 6) & @CRLF)
    Next
    
    Return True
EndFunc

; Synchronisiert RGB- und BGR-Arrays nach Änderungen
Func _SyncColorArrays()
    For $i = 0 To UBound($g_aLogLevelColorsRGB) - 1
        $g_aLogLevelColorsBGR[$i] = _WinAPI_SwitchColor($g_aLogLevelColorsRGB[$i][1])
    Next
    
    Return True
EndFunc

; =============================================
; Getter und Setter Funktionen
; =============================================

; Setzt eine neue RGB-Farbe für ein Log-Level und aktualisiert BGR
Func _SetLogLevelColorRGB($iLevel, $iRGBColor)
    ; RGB-Farbe setzen
    $g_aLogLevelColorsRGB[$iLevel][1] = $iRGBColor
    
    ; BGR-Farbe aktualisieren
    $g_aLogLevelColorsBGR[$iLevel] = _WinAPI_SwitchColor($iRGBColor)
    
    ; Debug-Ausgabe
    ConsoleWrite("Farbe geändert: Level=" & $g_aLogLevelColorsRGB[$iLevel][0] & _
               " | Neue RGB: 0x" & Hex($iRGBColor, 6) & _
               " | Neue BGR: 0x" & Hex($g_aLogLevelColorsBGR[$iLevel], 6) & @CRLF)
    
    Return True
EndFunc

; Ermittelt die RGB-Farbe für ein bestimmtes Log-Level (für GUI-Elemente)
Func _GetLogLevelColorRGB($sLevel)
    ; Log-Level-Index ermitteln
    Local $iLevelIndex = _FindLogLevelIndex($sLevel)
    
    ; RGB-Farbe zurückgeben
    If $iLevelIndex >= 0 Then
        Return $g_aLogLevelColorsRGB[$iLevelIndex][1]
    Else
        ; Standard: INFO-Farbe
        Return $g_aLogLevelColorsRGB[2][1]
    EndIf
EndFunc

; Ermittelt die BGR-Farbe für ein bestimmtes Log-Level (für ListView)
Func _GetLogLevelColorBGR($sLevel)
    ; Log-Level-Index ermitteln
    Local $iLevelIndex = _FindLogLevelIndex($sLevel)
    
    ; BGR-Farbe zurückgeben
    If $iLevelIndex >= 0 Then
        Return $g_aLogLevelColorsBGR[$iLevelIndex]
    Else
        ; Standard: INFO-Farbe
        Return $g_aLogLevelColorsBGR[2]
    EndIf
EndFunc

; =============================================
; Hilfsfunktionen
; =============================================

; Ermittelt den Index eines Log-Levels anhand des Namens
Func _FindLogLevelIndex($sLevel)
    ; Spezialfall: TRUNCATED
    If StringInStr(StringUpper($sLevel), "TRUNCATED") Then
        Return 5
    EndIf
    
    ; Level-String in Großbuchstaben umwandeln für Vergleich
    $sLevel = StringUpper($sLevel)
    
    ; Prüfen, welchem Level-Typ der String entspricht
    Switch True
        Case StringInStr($sLevel, "ERROR") Or StringInStr($sLevel, "FATAL") Or StringInStr($sLevel, "CRITICAL")
            Return 0  ; ERROR
        Case StringInStr($sLevel, "WARN")
            Return 1  ; WARNING
        Case StringInStr($sLevel, "INFO")
            Return 2  ; INFO
        Case StringInStr($sLevel, "DEBUG")
            Return 3  ; DEBUG
        Case StringInStr($sLevel, "TRACE")
            Return 4  ; TRACE
    EndSwitch
    
    ; Wenn nicht gefunden, -1 zurückgeben
    Return -1
EndFunc

; =============================================
; INI-Datei Funktionen
; =============================================

; Speichert die Farben in einer INI-Datei
Func _SaveDualColors($sIniPath)
    ; Sicherstellen, dass der Abschnitt existiert
    IniWrite($sIniPath, "LogLevelColors", "Info", "Log-Level-Farben Konfiguration (Dual-Array)")
    
    ; RGB-Farben speichern
    For $i = 0 To UBound($g_aLogLevelColorsRGB) - 1
        IniWrite($sIniPath, "LogLevelColors", $g_aLogLevelColorsRGB[$i][0] & "_RGB", "0x" & Hex($g_aLogLevelColorsRGB[$i][1], 6))
    Next
    
    ; BGR-Farben separat speichern für Debugging
    For $i = 0 To UBound($g_aLogLevelColorsRGB) - 1
        IniWrite($sIniPath, "LogLevelColorsBGR", $g_aLogLevelColorsRGB[$i][0], "0x" & Hex($g_aLogLevelColorsBGR[$i], 6))
    Next
    
    Return True
EndFunc

; Lädt die Farben aus einer INI-Datei
Func _LoadDualColors($sIniPath)
    ; Prüfen, ob INI-Datei existiert
    If Not FileExists($sIniPath) Then
        Return False
    EndIf
    
    ; RGB-Farben laden
    For $i = 0 To UBound($g_aLogLevelColorsRGB) - 1
        ; Farbwert als Hex-String lesen
        Local $sColorValue = IniRead($sIniPath, "LogLevelColors", $g_aLogLevelColorsRGB[$i][0] & "_RGB", "")
        
        ; Wenn Wert vorhanden, in Array speichern
        If $sColorValue <> "" Then
            $g_aLogLevelColorsRGB[$i][1] = Number($sColorValue)
        EndIf
    Next
    
    ; BGR-Farben synchronisieren
    _SyncColorArrays()
    
    Return True
EndFunc

; =============================================
; WM_NOTIFY Handler für ListView mit BGR-Farben
; =============================================

; Angepasster WM_NOTIFY-Handler für ListView mit BGR-Farben
Func _ColorDual_WM_NOTIFY_Handler($hWnd, $iMsg, $wParam, $lParam)
    ; NMHDR-Struktur auslesen
    Local $tNMHDR = DllStructCreate("hwnd hWndFrom; uint_ptr IDFrom; int Code", $lParam)
    Local $hWndFrom = DllStructGetData($tNMHDR, "hWndFrom")
    Local $iCode = DllStructGetData($tNMHDR, "Code")
    
    ; Für CUSTOMDRAW-Events
    If $iCode = $NM_CUSTOMDRAW Then
        ; NMLVCUSTOMDRAW-Struktur
        Local $tagNMLVCUSTOMDRAW = "struct;hwnd hWndFrom;uint_ptr IDFrom;int Code;dword dwDrawStage;handle hdc;" & _
                                 "struct;long left;long top;long right;long bottom;endstruct;" & _
                                 "dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;endstruct;" & _
                                 "dword clrText;dword clrTextBk;int iSubItem;dword dwItemType;" & _
                                 "dword clrFace;int iIconEffect;int iIconPhase;int iPartId;int iStateId;" & _
                                 "struct;long left;long top;long right;long bottom;endstruct;uint uAlign"
        
        Local $tNMLVCUSTOMDRAW = DllStructCreate($tagNMLVCUSTOMDRAW, $lParam)
        Local $iDrawStage = DllStructGetData($tNMLVCUSTOMDRAW, "dwDrawStage")
        
        ; In PREPAINT-Phase Items individuell behandeln
        If $iDrawStage = $CDDS_PREPAINT Then
            ; ITEM-Modus anfordern
            Return $CDRF_NOTIFYITEMDRAW
        ElseIf $iDrawStage = $CDDS_ITEMPREPAINT Then
            ; Item-Informationen extrahieren
            Local $iRow = DllStructGetData($tNMLVCUSTOMDRAW, "dwItemSpec")
            
            ; Wenn gültige Zeile und im Bereich unserer Log-Level
            If $iRow >= 0 And $iRow < UBound($g_aLogLevelColorsRGB) Then
                ; BGR-Farbe direkt aus dem Array verwenden
                DllStructSetData($tNMLVCUSTOMDRAW, "clrTextBk", $g_aLogLevelColorsBGR[$iRow])
                
                Return $CDRF_NEWFONT
            EndIf
        EndIf
    EndIf
    
    Return $GUI_RUNDEFMSG
EndFunc