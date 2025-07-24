#include-once
#include <Crypt.au3>
#include <String.au3>
#include "logging.au3"

Func _Base64Decode($sData)
    ; Padding hinzufügen falls nötig
    Switch Mod(StringLen($sData), 4)
        Case 2
            $sData &= "=="
        Case 3
            $sData &= "="
    EndSwitch
    
    Local $oXml = ObjCreate("Msxml2.DOMDocument")
    If @error Then Return SetError(1, 0, "")
    
    Local $oElement = $oXml.createElement("b64")
    $oElement.dataType = "bin.base64"
    $oElement.text = $sData
    
    Return $oElement.nodeTypedValue
EndFunc

Func _DecryptPassword($sEncrypted)
    _LogInfo("Entschlüssele: " & $sEncrypted)
    
    ; Base64 dekodieren
    Local $bDecoded = _Base64Decode($sEncrypted)
    If @error Then
        _LogError("Base64-Decodierung fehlgeschlagen")
        Return ""
    EndIf
    
    ; Spezieller Schlüssel basierend auf der Analyse
    Local Static $aKey = [ _
        73, 79, 173, 205, 127, 80, 9, 250, 222, 120, _
        232, 214, 31, 187, 145, 209, 53, 106, 117, 94 _
    ]
    
    ; Entschlüsseln
    Local $sResult = ""
    Local $bLen = BinaryLen($bDecoded)
    
    For $i = 1 To $bLen
        Local $byte = Number(BinaryMid($bDecoded, $i, 1))
        Local $keyByte = $aKey[Mod($i - 1, 20)]
        Local $plainByte = BitXOR($byte, $keyByte)
        
        ; Nur gültige ASCII-Zeichen akzeptieren
        If $plainByte >= 32 And $plainByte <= 126 Then
            $sResult &= Chr($plainByte)
        EndIf
    Next
    
    ; Validierung des Ergebnisses
    If StringRegExp($sResult, "^[a-zA-Z0-9]+$") Then
        _LogInfo("Erfolgreich entschlüsselt: " & $sResult)
        Return $sResult
    EndIf
    
    _LogError("Entschlüsselung fehlgeschlagen")
    Return ""
EndFunc