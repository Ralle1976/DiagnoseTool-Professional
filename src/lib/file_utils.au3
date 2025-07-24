; Titel.......: Dateioperationen-Hilfsfunktionen
; Beschreibung: Sammlung von Hilfsfunktionen für Dateioperationen
; Autor.......: Ralle1976
; Erstellt....: 2025-04-14
; ===============================================================================================================================

#include-once
#include <FileConstants.au3>
#include <File.au3>
#include <StringConstants.au3>
#include "logging.au3"

; ===============================================================================================================================
; Func.....: FileEOF
; Beschreibung: Prüft, ob das Ende einer Datei erreicht wurde
; Parameter.: $hFile - Handle der geöffneten Datei
; Rückgabe..: True wenn Ende der Datei erreicht, sonst False
; ===============================================================================================================================
;~ Func FileEOF($hFile)
;~     ; Aktuelle Position speichern
;~     Local $iCurrentPos = FileGetPos($hFile)
;~
;~     ; Ein Zeichen lesen versuchen
;~     Local $sChar = FileRead($hFile, 1)
;~
;~     ; Zurück zur ursprünglichen Position
;~     FileSetPos($hFile, $iCurrentPos, $FILE_BEGIN)
;~
;~     ; Wenn kein Zeichen gelesen wurde, ist das Dateiende erreicht
;~     Return ($sChar = "")
;~ EndFunc

; ===============================================================================================================================
; Func.....: ReadFileContentsAsLines
; Beschreibung: Liest eine Textdatei zeilenweise in ein Array ein
; Parameter.: $sFilePath - Pfad zur Datei
; Rückgabe..: Array mit Zeilen oder 0 bei Fehler
; ===============================================================================================================================
Func ReadFileContentsAsLines($sFilePath)
    _LogInfo("Lese Datei zeilenweise: " & $sFilePath)

    ; Datei öffnen
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then
        _LogError("Fehler beim Öffnen der Datei: " & $sFilePath)
        Return SetError(1, 0, 0)
    EndIf

    ; Variablen initialisieren
    Local $aLines[1000]  ; Startgröße
    Local $iCount = 0

    ; Zeilen lesen
    While Not FileEOF($hFile)
        ; Wenn das Array voll ist, vergrößern
        If $iCount >= UBound($aLines) Then
            ReDim $aLines[$iCount + 1000]
        EndIf

        ; Zeile lesen und in Array speichern
        $aLines[$iCount] = FileReadLine($hFile)
        $iCount += 1
    WEnd

    ; Array auf tatsächliche Größe trimmen
    ReDim $aLines[$iCount]

    ; Datei schließen
    FileClose($hFile)

    _LogInfo("Datei erfolgreich gelesen: " & $iCount & " Zeilen")
    Return $aLines
EndFunc
