#include-once
#include <String.au3>
#include "utils.au3" ; Include der Dict-Funktionen

; Diese Datei enthält Hilfsfunktionen für JSON

; JSON-Encoder für einfache Werte
Func JSON_Encode($vValue)
    Switch VarGetType($vValue)
        Case "String"
            Return '"' & StringReplace(StringReplace(StringReplace($vValue, '\', '\\'), '"', '\"'), @CRLF, '\n') & '"'
        Case "Int32", "Int64", "Double"
            Return $vValue
        Case "Bool"
            Return ($vValue) ? "true" : "false"
        Case "Keyword"
            If $vValue = Null Then Return "null"
        Case "Array"
            Local $sArray = "["
            For $i = 0 To UBound($vValue) - 1
                If $i > 0 Then $sArray &= ","
                $sArray &= JSON_Encode($vValue[$i])
            Next
            Return $sArray & "]"
        Case "Object"
            ; Spezialbehandlung für Dictionary
            If String($vValue) = "[object IDispatch]" Then
                Local $sJSON = "{"
                Local $aKeys = $vValue.Keys()
                For $i = 0 To UBound($aKeys) - 1
                    If $i > 0 Then $sJSON &= ","
                    $sJSON &= JSON_Encode($aKeys[$i]) & ":" & JSON_Encode($vValue.Item($aKeys[$i]))
                Next
                Return $sJSON & "}"
            EndIf
    EndSwitch
    
    ; Fallback
    Return '"' & String($vValue) & '"'
EndFunc

; JSON-Decoder für einfache JSON-Strings
Func JSON_Decode($sJSON)
    ; Strings
    If StringLeft($sJSON, 1) = '"' And StringRight($sJSON, 1) = '"' Then
        Return StringReplace(StringReplace(StringReplace(StringMid($sJSON, 2, StringLen($sJSON) - 2), '\n', @CRLF), '\"', '"'), '\\', '\')
    EndIf
    
    ; Zahlen
    If StringRegExp($sJSON, "^-?\d+(\.\d+)?$") Then
        Return Number($sJSON)
    EndIf
    
    ; Boolean
    If $sJSON = "true" Then Return True
    If $sJSON = "false" Then Return False
    
    ; Null
    If $sJSON = "null" Then Return Null
    
    ; Arrays
    If StringLeft($sJSON, 1) = "[" And StringRight($sJSON, 1) = "]" Then
        ; Hier wäre eine komplexere Verarbeitung nötig
        ; Für einfache Fälle nur eine Kommatrennung
        Local $sContent = StringMid($sJSON, 2, StringLen($sJSON) - 2)
        Local $aItems = StringSplit($sContent, ",", $STR_NOCOUNT)
        Local $aResult[UBound($aItems)]
        
        For $i = 0 To UBound($aItems) - 1
            $aResult[$i] = JSON_Decode(StringStripWS($aItems[$i], 3))
        Next
        
        Return $aResult
    EndIf
    
    ; Objekte
    If StringLeft($sJSON, 1) = "{" And StringRight($sJSON, 1) = "}" Then
        ; Einfache Version ohne verschachtelte Objekte
        Local $sContent = StringMid($sJSON, 2, StringLen($sJSON) - 2)
        Local $aItems = StringSplit($sContent, ",", $STR_NOCOUNT)
        Local $oResult = Dict_Create()
        
        For $i = 0 To UBound($aItems) - 1
            Local $aPair = StringSplit($aItems[$i], ":", $STR_NOCOUNT)
            If UBound($aPair) >= 2 Then
                Local $sKey = JSON_Decode(StringStripWS($aPair[0], 3))
                Local $vValue = JSON_Decode(StringStripWS($aPair[1], 3))
                Dict_Add($oResult, $sKey, $vValue)
            EndIf
        Next
        
        Return $oResult
    EndIf
    
    ; Fallback
    Return $sJSON
EndFunc

; Formatierte Ausgabe eines JSON-Objekts
Func JSON_PrettyPrint($vValue, $iIndent = 0, $sIndentChar = "  ")
    Local $sIndentation = ""
    For $i = 1 To $iIndent
        $sIndentation &= $sIndentChar
    Next
    
    Switch VarGetType($vValue)
        Case "Object"
            ; Dictionary
            If String($vValue) = "[object IDispatch]" Then
                Local $aKeys = $vValue.Keys()
                If UBound($aKeys) = 0 Then Return "{}"
                
                Local $sJSON = "{" & @CRLF
                For $i = 0 To UBound($aKeys) - 1
                    $sJSON &= $sIndentation & $sIndentChar & """" & $aKeys[$i] & """: " & JSON_PrettyPrint($vValue.Item($aKeys[$i]), $iIndent + 1, $sIndentChar)
                    If $i < UBound($aKeys) - 1 Then $sJSON &= ","
                    $sJSON &= @CRLF
                Next
                $sJSON &= $sIndentation & "}"
                Return $sJSON
            EndIf
        Case "Array"
            If UBound($vValue) = 0 Then Return "[]"
            
            Local $sJSON = "[" & @CRLF
            For $i = 0 To UBound($vValue) - 1
                $sJSON &= $sIndentation & $sIndentChar & JSON_PrettyPrint($vValue[$i], $iIndent + 1, $sIndentChar)
                If $i < UBound($vValue) - 1 Then $sJSON &= ","
                $sJSON &= @CRLF
            Next
            $sJSON &= $sIndentation & "]"
            Return $sJSON
        Case "String"
            Return """" & $vValue & """"
        Case "Bool"
            Return ($vValue) ? "true" : "false"
        Case "Keyword"
            If $vValue = Null Then Return "null"
    EndSwitch
    
    ; Zahlen und andere Typen
    Return $vValue
EndFunc
