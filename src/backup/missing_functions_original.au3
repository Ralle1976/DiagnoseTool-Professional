#include-once
#include <SQLite.au3>
#include <GUIListView.au3>
#include <File.au3>
#include <GUIConstants.au3> ; Hinzugefügt für GUI-Konstanten
#include "logging.au3"
#include "db_functions.au3"
#include "JSON.au3"

; Funktion zum Löschen aller Spalten einer ListView
Func _DeleteAllListViewColumns($hListView)
    ; Zähle vorhandene Spalten
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)
    
    ; Lösche alle Spalten (von rechts nach links)
    For $i = $iColumns - 1 To 0 Step -1
        _GUICtrlListView_DeleteColumn($hListView, $i)
    Next
    
    Return True
EndFunc

; Hilfsfunktion um Dateiende zu prüfen
Func FileEOF($hFile)
    Local $iPos = FileGetPos($hFile)
    Local $iSize = FileGetSize($hFile)
    Return ($iPos >= $iSize)
EndFunc

; Findet Logdateien in einem Verzeichnis
Func _FindLogFiles($sPath)
    Local $aLogFiles[1]
    $aLogFiles[0] = 0

    ; Nach gängigen Log-Dateiendungen suchen
    Local $aFilePatterns = ["*.log", "*.txt", "*.json"]

    For $sPattern In $aFilePatterns
        Local $aFiles = _FileListToArrayRec($sPath, $sPattern, $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
        If @error Then ContinueLoop

        For $i = 1 To $aFiles[0]
            ; Bei .txt und .json zusätzlich prüfen, ob es eine Log-Datei sein könnte
            Local $sExt = StringLower(StringRight($aFiles[$i], 4))
            Local $bAdd = False

            If $sExt = ".log" Then
                $bAdd = True
            ElseIf $sExt = ".txt" Then
                ; Bei .txt-Dateien anhand des Namens prüfen
                If StringInStr(StringLower($aFiles[$i]), "log") Then
                    $bAdd = True
                EndIf
            ElseIf StringRight($sExt, 5) = ".json" Then
                ; Bei .json-Dateien anhand des Inhalts prüfen
                If _IsJsonLogFile($aFiles[$i]) Then
                    $bAdd = True
                EndIf
            EndIf

            If $bAdd Then
                _ArrayAdd($aLogFiles, $aFiles[$i])
                $aLogFiles[0] += 1
            EndIf
        Next
    Next

    Return $aLogFiles
EndFunc

; Prüft, ob eine Datei eine JSON-Logdatei ist
Func _IsJsonLogFile($sFilePath)
    ; Prüft anhand der Endung
    If StringLower(StringRight($sFilePath, 5)) = ".json" Then Return True

    ; Überprüfe die ersten paar Zeilen der Datei
    Local $hFile = FileOpen($sFilePath, $FO_READ)
    If $hFile = -1 Then Return False

    Local $sContent = ""
    For $i = 1 To 5 ; Lese max. 5 Zeilen
        If FileEOF($hFile) Then ExitLoop
        $sContent &= FileReadLine($hFile) & @CRLF
    Next
    FileClose($hFile)

    ; Vereinfachte Prüfung, ob der Inhalt wie JSON aussieht
    If StringRegExp($sContent, '^\s*[\[\{]') And StringRegExp($sContent, '"[^"]+"\s*:') Then
        Return True
    EndIf

    Return False
EndFunc

; Hilfsfunktion: Minimum von zwei Werten
Func _Min($a, $b)
    Return ($a < $b) ? $a : $b
EndFunc

; Hilfsfunktion: Maximum von zwei Werten
Func _Max($a, $b)
    Return ($a > $b) ? $a : $b
EndFunc

; Funktion zum Parsen einer Logdatei
Func _ParseLogFile($sFilePath)
    ; Einfache Implementierung - einfach die Datei zeilenweise einlesen
    ; Genauer RegEx-Pattern für das DigiApp-Log-Format
    Local $g_sLogPattern = '\{"Timestamp":"([^"]+)","LogLevel":"([^"]+)","LogClass":"([^"]+)","Message":"([^"]*)"\}'


     ; Datei einlesen
    Local $aString= FileRead($sFilePath)
    If @error Then
        _LogInfo("Fehler beim Einlesen: " & @error)
        Return SetError(1, 0, 0)
    EndIf


    Local $aMatches = StringRegExp($aString, $g_sLogPattern, 4)

    _LogInfo("Gelesene Zeilen: " & UBound($aMatches))

    ; Logeinträge Array vorbereiten
    Local $aLogEntries[UBound($aMatches)][5]
;~     Local $iValidCount = 0

    ; Zeilen verarbeiten
    For $i = 0 To UBound($aMatches) - 1
        Local $sTempArray = $aMatches[$i]
        $aLogEntries[$i][0] = $sTempArray[1] ; Timestamp
        $aLogEntries[$i][1] = $sTempArray[2] ; LogLevel
        $aLogEntries[$i][2] = $sTempArray[3] ; LogClass
        $aLogEntries[$i][3] = $sTempArray[4] ; Message
        $aLogEntries[$i][4] = $sTempArray[0] ; Raw
    Next

    Return $aLogEntries
EndFunc

; Extrahiert eindeutige Log-Levels aus einem Array von Log-Einträgen
Func _GetUniqueLogLevels($aLogEntries)
    Local $aLevels[0]

    For $i = 0 To UBound($aLogEntries) - 1
        Local $sLevel = $aLogEntries[$i][1]

        ; Nur hinzufügen, wenn nicht bereits vorhanden und nicht leer
        If $sLevel <> "" And _ArraySearch($aLevels, $sLevel) = -1 Then
            _ArrayAdd($aLevels, $sLevel)
        EndIf
    Next

    ; Sortieren für bessere Nutzbarkeit
    _ArraySort($aLevels)

    Return $aLevels
EndFunc

; Extrahiert eindeutige Log-Klassen aus einem Array von Log-Einträgen
Func _GetUniqueLogClasses($aLogEntries)
    Local $aClasses[0]

    For $i = 0 To UBound($aLogEntries) - 1
        Local $sClass = $aLogEntries[$i][2]

        ; Nur hinzufügen, wenn nicht bereits vorhanden und nicht leer
        If $sClass <> "" And _ArraySearch($aClasses, $sClass) = -1 Then
            _ArrayAdd($aClasses, $sClass)
        EndIf
    Next

    ; Sortieren für bessere Nutzbarkeit
    _ArraySort($aClasses)

    Return $aClasses
EndFunc

; Erstellt Statistiken über Log-Einträge
Func _GetLogStatistics($aLogEntries)
    ; Dictionary-ähnliche Struktur für die Statistiken
    Local $oStats = ObjCreate("Scripting.Dictionary")

    ; Gesamtzahl der Einträge
    $oStats.Add("TotalEntries", UBound($aLogEntries))

    ; Dictionary für Level-Statistik
    Local $oLevelStats = ObjCreate("Scripting.Dictionary")

    ; Dictionary für Klassen-Statistik
    Local $oClassStats = ObjCreate("Scripting.Dictionary")

    ; Durchlaufe alle Einträge
    For $i = 0 To UBound($aLogEntries) - 1
        ; Level-Statistik aktualisieren
        Local $sLevel = $aLogEntries[$i][1]
        If $sLevel <> "" Then
            If $oLevelStats.Exists($sLevel) Then
                $oLevelStats.Item($sLevel) = $oLevelStats.Item($sLevel) + 1
            Else
                $oLevelStats.Add($sLevel, 1)
            EndIf
        EndIf

        ; Klassen-Statistik aktualisieren
        Local $sClass = $aLogEntries[$i][2]
        If $sClass <> "" Then
            If $oClassStats.Exists($sClass) Then
                $oClassStats.Item($sClass) = $oClassStats.Item($sClass) + 1
            Else
                $oClassStats.Add($sClass, 1)
            EndIf
        EndIf
    Next

    ; Statistiken zum Hauptobjekt hinzufügen
    $oStats.Add("LevelStats", $oLevelStats)
    $oStats.Add("ClassStats", $oClassStats)

    Return $oStats
EndFunc

; Sucht in Log-Einträgen nach einem Text oder Regex
Func _SearchLogEntries($aLogEntries, $sSearch, $bRegex = False, $sLevel = "", $sClass = "")
    Local $aResults[0][5]
    Local $iCount = 0

    ; Durchlaufe alle Einträge
    For $i = 0 To UBound($aLogEntries) - 1
        ; Level-Filter anwenden
        If $sLevel <> "" And $aLogEntries[$i][1] <> $sLevel Then
            ContinueLoop
        EndIf

        ; Klassen-Filter anwenden
        If $sClass <> "" And $aLogEntries[$i][2] <> $sClass Then
            ContinueLoop
        EndIf

        ; Suchtext prüfen
        Local $bMatch = False
        If $bRegex Then
            ; Regex-Suche in Nachricht
            $bMatch = StringRegExp($aLogEntries[$i][3], $sSearch)
        Else
            ; Einfache Textsuche in Nachricht
            $bMatch = StringInStr($aLogEntries[$i][3], $sSearch) > 0
        EndIf

        ; Bei Treffer zum Ergebnis hinzufügen
        If $bMatch Then
            ReDim $aResults[$iCount + 1][5]
            For $j = 0 To 4 ; Kopiere alle 5 Spalten
                $aResults[$iCount][$j] = $aLogEntries[$i][$j]
            Next
            $iCount += 1
        EndIf
    Next

    Return $aResults
EndFunc

Func _ProcessExtractedFiles($sTempDir)
    If Not FileExists($sTempDir) Then
        _LogError("Verzeichnis nicht gefunden: " & $sTempDir)
        Return False
    EndIf

    Local $aFiles = _FileListToArray($sTempDir, "*.db3", $FLTA_FILES, True)
    If @error Then
        _LogInfo("DB-Suche: Keine DB3 gefunden")
        $aFiles = _FileListToArray($sTempDir, "*.db", $FLTA_FILES, True)
        If @error Then
            _LogInfo("DB-Suche: Auch keine DB gefunden")
            Return False
        EndIf
    EndIf

    _LogInfo("Gefundene Datenbanken: " & $aFiles[0])
    For $i = 1 To $aFiles[0]
        _LogInfo("DB " & $i & ": " & $aFiles[$i])
    Next

    Local $sDBPath = $aFiles[1]
    _LogInfo("Verwende Datenbank: " & $sDBPath)

    Global $g_sCurrentDB = $sDBPath
    Return _DB_Connect($sDBPath)
EndFunc