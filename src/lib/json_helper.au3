#include-once
#include <Array.au3>
#include "utils.au3" ; Verwende die Dict-Funktionen aus utils.au3

; Diese Datei definiert Hilfsfunktionen für JSON-Verarbeitung

; Zugriff auf JSON-Daten
Func JSON_GetValue($oJSON, $sKey, $vDefault = "")
    If IsObj($oJSON) And Dict_Exists($oJSON, $sKey) Then
        Return Dict_Get($oJSON, $sKey)
    EndIf
    Return $vDefault
EndFunc

; Vereinfachter JSON-Parser für einfache Strukturen
Func JSON_ParseSimple($sJSON)
    ; Stellen wir sicher, dass ein gültiges JSON-Objekt vorhanden ist
    $sJSON = StringStripWS($sJSON, 3)
    If Not (StringLeft($sJSON, 1) = "{" And StringRight($sJSON, 1) = "}") Then
        Return SetError(1, 0, 0)
    EndIf
    
    ; Äußere Klammern entfernen
    $sJSON = StringTrimLeft(StringTrimRight($sJSON, 1), 1)
    
    ; Einfaches Dictionary erstellen
    Local $oDict = Dict_Create()
    
    ; Key-Value-Paare extrahieren
    While StringLen($sJSON) > 0
        $sJSON = StringStripWS($sJSON, 3)
        
        ; Key extrahieren (in Anführungszeichen)
        Local $iStart = StringInStr($sJSON, '"')
        If $iStart <= 0 Then ExitLoop
        
        Local $iEnd = StringInStr($sJSON, '"', 0, 1, $iStart + 1)
        If $iEnd <= 0 Then ExitLoop
        
        Local $sKey = StringMid($sJSON, $iStart + 1, $iEnd - $iStart - 1)
        $sJSON = StringTrimLeft($sJSON, $iEnd)
        
        ; Doppelpunkt überspringen
        $iStart = StringInStr($sJSON, ':')
        If $iStart <= 0 Then ExitLoop
        $sJSON = StringTrimLeft($sJSON, $iStart)
        
        ; Value extrahieren (verschiedene Typen)
        $sJSON = StringStripWS($sJSON, 3)
        
        Local $vValue = ""
        
        ; String-Wert
        If StringLeft($sJSON, 1) = '"' Then
            $iStart = 1
            $iEnd = StringInStr($sJSON, '"', 0, 1, $iStart + 1)
            If $iEnd <= 0 Then ExitLoop
            
            $vValue = StringMid($sJSON, $iStart + 1, $iEnd - $iStart - 1)
            $sJSON = StringTrimLeft($sJSON, $iEnd)
        ; Zahl oder Boolean
        Else
            Local $iComma = StringInStr($sJSON, ',')
            If $iComma > 0 Then
                $vValue = StringLeft($sJSON, $iComma - 1)
                $sJSON = StringTrimLeft($sJSON, $iComma)
            Else
                $vValue = $sJSON
                $sJSON = ""
            EndIf
            
            $vValue = StringStripWS($vValue, 3)
            
            ; Typ konvertieren
            Switch $vValue
                Case "true"
                    $vValue = True
                Case "false"
                    $vValue = False
                Case "null"
                    $vValue = Null
                Case Else
                    ; Zahl?
                    If StringRegExp($vValue, "^[0-9]+(\.[0-9]+)?$") Then
                        $vValue = Number($vValue)
                    EndIf
            EndSwitch
        EndIf
        
        ; Wert zum Dictionary hinzufügen
        Dict_Add($oDict, $sKey, $vValue)
        
        ; Komma überspringen
        $sJSON = StringStripWS($sJSON, 3)
        If StringLeft($sJSON, 1) = "," Then
            $sJSON = StringTrimLeft($sJSON, 1)
        EndIf
    WEnd
    
    Return $oDict
EndFunc

; Json_Get für Kompatibilität mit robust_json_parser.au3
Func Json_Get($oJSON, $sPath, $vDefault = "")
    ; Entferne den Punkt am Anfang des Pfads, falls vorhanden
    If StringLeft($sPath, 1) = "." Then
        $sPath = StringTrimLeft($sPath, 1)
    EndIf
    
    ; Einfache Implementierung für direkten Schlüsselzugriff
    Return JSON_GetValue($oJSON, $sPath, $vDefault)
EndFunc
