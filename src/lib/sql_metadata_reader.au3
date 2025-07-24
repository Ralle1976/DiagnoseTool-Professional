; Titel.......: SQL-Metadata-Reader
; Beschreibung: Effiziente Funktionen zum Auslesen von Metadaten aus SQLite-Datenbanken
; Autor.......: Ralle1976
; Erstellt....: 2025-04-25
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <Array.au3>
#include <String.au3>

; Logging-Funktionen aus dem Hauptprojekt einbinden
#include "logging.au3"

; ===============================================================================================================================
; Func.....: _GetAllSQLiteTables
; Beschreibung: Liest alle Tabellen einer SQLite-Datenbank auf einmal aus
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Array mit Tabellennamen oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetAllSQLiteTables($sDBPath)
    Local $aTables[0]

    If $sDBPath = "" Then
        _LogError("_GetAllSQLiteTables: Leerer Datenbankpfad")
        Return $aTables
    EndIf

    _LogInfo("_GetAllSQLiteTables: Lese Tabellen aus DB '" & $sDBPath & "'")

    ; Prüfen, ob aktuell eine Datenbankverbindung besteht
    Local $bNeedToConnect = True
    If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
        $bNeedToConnect = False
        _LogInfo("_GetAllSQLiteTables: Datenbankverbindung besteht bereits")
    EndIf

    ; Datenbank öffnen falls notwendig
    Local $hDB = -1 ; Standardhandle verwenden
    Local $bWasOpened = False

    If $bNeedToConnect Then
        _LogInfo("_GetAllSQLiteTables: Öffne Datenbankverbindung")
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("_GetAllSQLiteTables: Konnte Datenbank nicht öffnen: " & $sDBPath)
            Return $aTables
        EndIf
        $bWasOpened = True
    EndIf

    ; Effizienter SQL-Befehl zum Auslesen aller Tabellen (keine System-Tabellen)
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
    Local $aResult, $iRows, $iColumns

    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Verbindung nur schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogError("_GetAllSQLiteTables: Fehler beim Abrufen der Tabellen: " & _SQLite_ErrMsg())
        Return $aTables
    EndIf

    ; Tabellennamen in ein Array extrahieren
    ReDim $aTables[$iRows]
    For $i = 1 To $iRows
        $aTables[$i-1] = $aResult[$i][0]
    Next

    _LogInfo("_GetAllSQLiteTables: " & $iRows & " Tabellen gefunden")
    Return $aTables
EndFunc

; ===============================================================================================================================
; Func.....: _GetAllTableColumns
; Beschreibung: Liest alle Spalten aller Tabellen einer SQLite-Datenbank auf einmal aus
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Zweidimensionales Array [Tabellenname][Spaltenname] oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetAllTableColumns($sDBPath)
    Local $aColumnsMap[0][0]
    Local $aTables = _GetAllSQLiteTables($sDBPath)

    If UBound($aTables) = 0 Then
        _LogError("_GetAllTableColumns: Keine Tabellen gefunden")
        Return $aColumnsMap
    EndIf

    _LogInfo("_GetAllTableColumns: Lese Spalten für " & UBound($aTables) & " Tabellen aus")

    ; Prüfen, ob aktuell eine Datenbankverbindung besteht
    Local $bNeedToConnect = True
    If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
        $bNeedToConnect = False
        _LogInfo("_GetAllTableColumns: Datenbankverbindung besteht bereits")
    EndIf

    ; Datenbank öffnen falls notwendig
    Local $hDB = -1 ; Standardhandle verwenden
    Local $bWasOpened = False

    If $bNeedToConnect Then
        _LogInfo("_GetAllTableColumns: Öffne Datenbankverbindung")
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("_GetAllTableColumns: Konnte Datenbank nicht öffnen: " & $sDBPath)
            Return $aColumnsMap
        EndIf
        $bWasOpened = True
    EndIf

    ; Ergebnis-Array initialisieren (Tabellenname => [Spalten])
    Local $aColumnsInfo[UBound($aTables) + 1][2] ; +1 für Header
    $aColumnsInfo[0][0] = "Tabelle"
    $aColumnsInfo[0][1] = "Spalten"

    ; Für jede Tabelle die Spalten auslesen
    For $i = 0 To UBound($aTables) - 1
        Local $sTableName = $aTables[$i]
        $aColumnsInfo[$i + 1][0] = $sTableName

        ; PRAGMA table_info für Spalteninformationen verwenden
        Local $sSQL = "PRAGMA table_info(" & $sTableName & ");"
        Local $aResult, $iRows, $iColumns

        Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

        If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
            _LogError("_GetAllTableColumns: Fehler beim Abrufen der Spalten für Tabelle " & $sTableName & ": " & _SQLite_ErrMsg())
            ; Leeres Array für diese Tabelle
            $aColumnsInfo[$i + 1][1] = ""
            ContinueLoop
        EndIf

        ; Spaltennamen sammeln und in String mit Trennzeichen speichern
        Local $sColumns = ""
        For $j = 1 To $iRows
            $sColumns &= $aResult[$j][1] & "|"  ; Spalte 1 (Index 1) enthält den Spaltennamen
        Next

        If $sColumns <> "" Then $sColumns = StringTrimRight($sColumns, 1)
        $aColumnsInfo[$i + 1][1] = $sColumns

        _LogInfo("_GetAllTableColumns: " & $iRows & " Spalten für Tabelle '" & $sTableName & "' gefunden")
    Next

    ; Verbindung nur schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    Return $aColumnsInfo
EndFunc

; ===============================================================================================================================
; Func.....: _GetTableColumns
; Beschreibung: Liest die Spalten einer bestimmten Tabelle aus (optimierte Version)
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: Array mit Spaltennamen oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetTableColumns($sDBPath, $sTable)
    Local $aColumns[0]

    If $sDBPath = "" Or $sTable = "" Then
        _LogInfo("_GetTableColumns: Leerer Datenbankpfad oder Tabellenname")
        Return $aColumns
    EndIf

    _LogInfo("_GetTableColumns: Hole Spalten für Tabelle '" & $sTable & "' aus DB '" & $sDBPath & "'")

    ; Prüfen, ob aktuell eine Datenbankverbindung besteht
    Local $bNeedToConnect = True
    If _SQLite_Exec(-1, "SELECT 1") = $SQLITE_OK Then
        $bNeedToConnect = False
        _LogInfo("_GetTableColumns: Datenbankverbindung besteht bereits")
    EndIf

    ; Datenbank öffnen falls notwendig
    Local $hDB = -1 ; Standardhandle verwenden
    Local $bWasOpened = False

    If $bNeedToConnect Then
        _LogInfo("_GetTableColumns: Öffne Datenbankverbindung")
        $hDB = _SQLite_Open($sDBPath)
        If @error Then
            _LogError("_GetTableColumns: Konnte Datenbank nicht öffnen: " & $sDBPath)
            Return $aColumns
        EndIf
        $bWasOpened = True
    EndIf

    ; Effiziente Version mit PRAGMA-Befehl für Spalteninfos
    Local $sSQL = "PRAGMA table_info(" & $sTable & ");"
    Local $aResult, $iRows, $iColumns

    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Verbindung nur schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogError("_GetTableColumns: Fehler beim Abrufen der Spalteninformationen: " & _SQLite_ErrMsg())
        Return $aColumns
    EndIf

    ; Spaltennamen extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    _LogInfo("_GetTableColumns: " & $iRows & " Spalten gefunden")
    Return $aColumns
EndFunc

; ===============================================================================================================================
; Func.....: _GetSQLiteDatabaseMetadata
; Beschreibung: Liest alle Metadaten einer SQLite-Datenbank (Tabellen, Spalten, Views, Trigger, Indizes) aus
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Array mit Metadaten-Struktur oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetSQLiteDatabaseMetadata($sDBPath)
    Local $aMetadata[5]
    $aMetadata[0] = _GetAllSQLiteTables($sDBPath) ; Tabellen

    ; Spalten für jede Tabelle
    Local $aAllColumns = _GetAllTableColumns($sDBPath)
    $aMetadata[1] = $aAllColumns

    ; Auf Erfolg prüfen
    If UBound($aMetadata[0]) > 0 Then
        _LogInfo("_GetSQLiteDatabaseMetadata: Metadaten erfolgreich aus DB '" & $sDBPath & "' gelesen")
        Return $aMetadata
    Else
        _LogError("_GetSQLiteDatabaseMetadata: Keine Metadaten gefunden in DB '" & $sDBPath & "'")
        Return $aMetadata
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _CacheDatabaseMetadata
; Beschreibung: Liest und speichert Metadaten einer SQLite-Datenbank im Cache
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _CacheDatabaseMetadata($sDBPath)
    Static $aMetadataCache[0][2] ; [Pfad][Metadaten]

    ; Bereits im Cache prüfen
    For $i = 0 To UBound($aMetadataCache) - 1
        If $aMetadataCache[$i][0] = $sDBPath Then
            _LogInfo("_CacheDatabaseMetadata: Metadaten für '" & $sDBPath & "' sind bereits im Cache")
            Return True
        EndIf
    Next

    ; Neue Metadaten laden
    Local $aMetadata = _GetSQLiteDatabaseMetadata($sDBPath)

    ; In Cache speichern
    Local $iSize = UBound($aMetadataCache)
    ReDim $aMetadataCache[$iSize + 1][2]
    $aMetadataCache[$iSize][0] = $sDBPath
    $aMetadataCache[$iSize][1] = $aMetadata

    _LogInfo("_CacheDatabaseMetadata: Metadaten für '" & $sDBPath & "' in Cache gespeichert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _GetTablesFromCache
; Beschreibung: Gibt alle Tabellen aus dem Cache zurück
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Array mit Tabellennamen oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetTablesFromCache($sDBPath)
    Static $aMetadataCache[0][2] ; [Pfad][Metadaten]

    ; Im Cache suchen
    For $i = 0 To UBound($aMetadataCache) - 1
        If $aMetadataCache[$i][0] = $sDBPath Then
            _LogInfo("_GetTablesFromCache: Tabellen für '" & $sDBPath & "' aus Cache geholt")
            Return $aMetadataCache[$i][1][0]
        EndIf
    Next

    ; Nicht im Cache, neu laden
    _CacheDatabaseMetadata($sDBPath)

    ; Erneut versuchen, aus Cache zu lesen
    Return _GetTablesFromCache($sDBPath)
EndFunc

; ===============================================================================================================================
; Func.....: _GetColumnsFromCache
; Beschreibung: Gibt alle Spalten einer Tabelle aus dem Cache zurück
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: Array mit Spaltennamen oder leeres Array bei Fehler
; ===============================================================================================================================
Func _GetColumnsFromCache($sDBPath, $sTable)
    Static $aMetadataCache[0][2] ; [Pfad][Metadaten]

    ; Im Cache suchen
    For $i = 0 To UBound($aMetadataCache) - 1
        If $aMetadataCache[$i][0] = $sDBPath Then
            ; Cache gefunden, jetzt Tabelle suchen
            Local $aAllColumns = $aMetadataCache[$i][1][1]

            For $j = 1 To UBound($aAllColumns) - 1 ; Start bei 1 um Header zu überspringen
                If $aAllColumns[$j][0] = $sTable Then
                    ; Spalten gefunden, als Array zurückgeben
                    Local $sColumns = $aAllColumns[$j][1]
                    Local $aColumns = StringSplit($sColumns, "|", $STR_NOCOUNT)
                    _LogInfo("_GetColumnsFromCache: Spalten für '" & $sTable & "' aus Cache geholt")
                    Return $aColumns
                EndIf
            Next

            ; Tabelle nicht im Cache gefunden
            _LogError("_GetColumnsFromCache: Tabelle '" & $sTable & "' nicht im Cache gefunden")
            Return _GetTableColumns($sDBPath, $sTable) ; Fallback auf direkte Abfrage
        EndIf
    Next

    ; Nicht im Cache, neu laden
    _CacheDatabaseMetadata($sDBPath)

    ; Erneut versuchen, aus Cache zu lesen
    Return _GetColumnsFromCache($sDBPath, $sTable)
EndFunc