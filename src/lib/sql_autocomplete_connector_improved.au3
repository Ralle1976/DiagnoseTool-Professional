; Titel.......: SQL-Autocomplete-Connector Improved - Erweiterte Verbindung für Autovervollständigung
; Beschreibung: Stellt die Verbindung zwischen der Autovervollständigung und den Datenbank-Metadaten her
;               Lädt alle Tabellen- und Spaltennamen initial und aktualisiert sie bei Schemaänderungen
; Autor.......: Claude
; Erstellt....: 2025-04-28
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <Array.au3>
#include "logging.au3"

; Globale Variablen für die Metadaten-Verwaltung
Global $g_oTablesColumnsCache ; Dictionary: Tabellenname => Array mit Spaltennamen
Global $g_aAllTableNames[0]    ; Array mit allen Tabellennamen (für schnellen Zugriff)
Global $g_aAllColumnNames[0]   ; Array mit allen eindeutigen Spaltennamen aller Tabellen

; ===============================================================================================================================
; Func.....: _SQL_InitMetadataManager
; Beschreibung: Initialisiert den Metadaten-Manager für die Datenbank
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_InitMetadataManager()
    _LogInfo("_SQL_InitMetadataManager: Initialisiere Metadaten-Manager")
    
    ; Dictionary für Tabellen und Spalten erstellen
    $g_oTablesColumnsCache = ObjCreate("Scripting.Dictionary")
    
    ; Spezielle Prüfung für das Dictionary
    If Not IsObj($g_oTablesColumnsCache) Then
        _LogError("_SQL_InitMetadataManager: Konnte Dictionary-Objekt nicht erstellen")
        Return False
    EndIf
    
    ; Arrays für alle Tabellen und Spalten initialisieren
    ReDim $g_aAllTableNames[0]
    ReDim $g_aAllColumnNames[0]
    
    _LogInfo("_SQL_InitMetadataManager: Metadaten-Manager initialisiert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_LoadAllMetadata
; Beschreibung: Lädt alle Metadaten (Tabellen und Spalten) aus der Datenbank
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_LoadAllMetadata($sDBPath)
    _LogInfo("_SQL_LoadAllMetadata: Lade alle Metadaten aus Datenbank: " & $sDBPath)
    
    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("_SQL_LoadAllMetadata: Datenbankdatei nicht gefunden: " & $sDBPath)
        Return False
    EndIf
    
    ; Dictionary initialisieren, wenn noch nicht geschehen
    If Not IsObj($g_oTablesColumnsCache) Then
        _SQL_InitMetadataManager()
    EndIf
    
    ; Cache leeren
    $g_oTablesColumnsCache.RemoveAll()
    ReDim $g_aAllTableNames[0]
    ReDim $g_aAllColumnNames[0]
    
    ; Datenbankverbindung herstellen
    Local $hDB, $bWasOpened = False
    If _SQLite_Exec(-1, "SELECT 1") <> $SQLITE_OK Then
        ; Keine aktive Verbindung, neue erstellen
        $hDB = _SQLite_Open($sDBPath, $SQLITE_OPEN_READONLY)
        If @error Then
            _LogError("_SQL_LoadAllMetadata: Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
            Return False
        EndIf
        $bWasOpened = True
    Else
        $hDB = -1 ; Bestehende Verbindung verwenden
    EndIf
    
    ; Alle Tabellen abfragen
    Local $aTableResult, $iTableRows, $iTableColumns
    Local $sTableSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    Local $iTableRet = _SQLite_GetTable2d($hDB, $sTableSQL, $aTableResult, $iTableRows, $iTableColumns)
    
    If @error Or $iTableRet <> $SQLITE_OK Then
        _LogError("_SQL_LoadAllMetadata: Fehler bei der Tabellenabfrage: " & _SQLite_ErrMsg())
        If $bWasOpened Then _SQLite_Close($hDB)
        Return False
    EndIf
    
    ; Keine Tabellen gefunden
    If $iTableRows = 0 Then
        _LogInfo("_SQL_LoadAllMetadata: Keine Tabellen in der Datenbank gefunden")
        If $bWasOpened Then _SQLite_Close($hDB)
        Return True
    EndIf
    
    ; Tabellennamen-Array dimensionieren
    ReDim $g_aAllTableNames[$iTableRows]
    
    ; Für jede Tabelle die Spaltennamen abrufen
    For $i = 0 To $iTableRows - 1
        Local $sTableName = $aTableResult[$i+1][0] ; +1 wegen Header-Zeile
        
        ; Tabellennamen speichern (mit Originalschreibweise)
        $g_aAllTableNames[$i] = $sTableName
        
        ; Spalteninformationen für diese Tabelle abrufen
        Local $aColResult, $iColRows, $iColColumns
        Local $sColSQL = "PRAGMA table_info(" & $sTableName & ")"
        Local $iColRet = _SQLite_GetTable2d($hDB, $sColSQL, $aColResult, $iColRows, $iColColumns)
        
        If @error Or $iColRet <> $SQLITE_OK Then
            _LogError("_SQL_LoadAllMetadata: Fehler bei der Spaltenabfrage für Tabelle '" & $sTableName & "': " & _SQLite_ErrMsg())
            ContinueLoop
        EndIf
        
        ; Spalten in Array speichern
        Local $aColumnNames[$iColRows]
        For $j = 0 To $iColRows - 1
            $aColumnNames[$j] = $aColResult[$j+1][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
            
            ; Spalte zum globalen Array aller eindeutigen Spaltennamen hinzufügen (falls noch nicht vorhanden)
            If _ArraySearch($g_aAllColumnNames, $aColumnNames[$j]) = -1 Then
                _ArrayAdd($g_aAllColumnNames, $aColumnNames[$j])
            EndIf
        Next
        
        ; Tabelle und Spalten im Dictionary speichern
        $g_oTablesColumnsCache.Add($sTableName, $aColumnNames)
    Next
    
    ; Datenbank schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)
    
    ; Globale Arrays für die Autovervollständigung aktualisieren
    _SQL_UpdateAutoCompleteArrays()
    
    _LogInfo("_SQL_LoadAllMetadata: " & $iTableRows & " Tabellen und alle Spalten erfolgreich geladen")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateAutoCompleteArrays
; Beschreibung: Aktualisiert die globalen Arrays für die Autovervollständigung
; Parameter.: Keine
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateAutoCompleteArrays()
    _LogInfo("_SQL_UpdateAutoCompleteArrays: Aktualisiere globale Arrays für Autovervollständigung")
    
    ; Prüfen, ob überhaupt Daten geladen sind
    If Not IsObj($g_oTablesColumnsCache) Or $g_oTablesColumnsCache.Count = 0 Then
        _LogInfo("_SQL_UpdateAutoCompleteArrays: Keine Metadaten geladen")
        Return False
    EndIf
    
    ; Arrays für die Originalschreibweise
    If IsDeclared("g_aOriginalCaseTableNames") Then
        ; Tabellennamen
        Local $iTableCount = UBound($g_aAllTableNames)
        ReDim $g_aOriginalCaseTableNames[$iTableCount]
        For $i = 0 To $iTableCount - 1
            $g_aOriginalCaseTableNames[$i] = $g_aAllTableNames[$i]
        Next
        _LogInfo("g_aOriginalCaseTableNames aktualisiert mit " & $iTableCount & " Tabellen")
    EndIf
    
    If IsDeclared("g_aOriginalCaseColumnNames") Then
        ; Spaltennamen (alle eindeutigen)
        Local $iColumnCount = UBound($g_aAllColumnNames)
        ReDim $g_aOriginalCaseColumnNames[$iColumnCount]
        For $i = 0 To $iColumnCount - 1
            $g_aOriginalCaseColumnNames[$i] = $g_aAllColumnNames[$i]
        Next
        _LogInfo("g_aOriginalCaseColumnNames aktualisiert mit " & $iColumnCount & " eindeutigen Spalten")
    EndIf
    
    ; Auch das Standard-Array aktualisieren (für Kompatibilität)
    If IsDeclared("g_aTableColumns") Then
        Local $iColumnCount = UBound($g_aAllColumnNames)
        ReDim $g_aTableColumns[$iColumnCount]
        For $i = 0 To $iColumnCount - 1
            $g_aTableColumns[$i] = $g_aAllColumnNames[$i]
        Next
        _LogInfo("g_aTableColumns aktualisiert mit " & $iColumnCount & " eindeutigen Spalten")
    EndIf
    
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateSpecificTable
; Beschreibung: Aktualisiert Spaltennamen für eine bestimmte Tabelle
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateSpecificTable($sDBPath, $sTable)
    _LogInfo("_SQL_UpdateSpecificTable: Aktualisiere Spaltennamen für Tabelle '" & $sTable & "'")
    
    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("_SQL_UpdateSpecificTable: Datenbankdatei nicht gefunden: " & $sDBPath)
        Return False
    EndIf
    
    ; Dictionary initialisieren, wenn noch nicht geschehen
    If Not IsObj($g_oTablesColumnsCache) Then
        _SQL_InitMetadataManager()
    EndIf
    
    ; Datenbankverbindung herstellen
    Local $hDB, $bWasOpened = False
    If _SQLite_Exec(-1, "SELECT 1") <> $SQLITE_OK Then
        ; Keine aktive Verbindung, neue erstellen
        $hDB = _SQLite_Open($sDBPath, $SQLITE_OPEN_READONLY)
        If @error Then
            _LogError("_SQL_UpdateSpecificTable: Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
            Return False
        EndIf
        $bWasOpened = True
    Else
        $hDB = -1 ; Bestehende Verbindung verwenden
    EndIf
    
    ; Prüfen, ob die Tabelle überhaupt existiert
    Local $aTableResult, $iTableRows, $iTableColumns
    Local $sTableSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='" & $sTable & "'"
    Local $iTableRet = _SQLite_GetTable2d($hDB, $sTableSQL, $aTableResult, $iTableRows, $iTableColumns)
    
    If @error Or $iTableRet <> $SQLITE_OK Or $iTableRows = 0 Then
        _LogError("_SQL_UpdateSpecificTable: Tabelle '" & $sTable & "' existiert nicht")
        If $bWasOpened Then _SQLite_Close($hDB)
        Return False
    EndIf
    
    ; Spalteninformationen für diese Tabelle abrufen
    Local $aColResult, $iColRows, $iColColumns
    Local $sColSQL = "PRAGMA table_info(" & $sTable & ")"
    Local $iColRet = _SQLite_GetTable2d($hDB, $sColSQL, $aColResult, $iColRows, $iColColumns)
    
    If @error Or $iColRet <> $SQLITE_OK Then
        _LogError("_SQL_UpdateSpecificTable: Fehler bei der Spaltenabfrage: " & _SQLite_ErrMsg())
        If $bWasOpened Then _SQLite_Close($hDB)
        Return False
    EndIf
    
    ; Spalten in Array speichern
    Local $aColumnNames[$iColRows]
    For $j = 0 To $iColRows - 1
        $aColumnNames[$j] = $aColResult[$j+1][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
        
        ; Spalte zum globalen Array aller eindeutigen Spaltennamen hinzufügen (falls noch nicht vorhanden)
        If _ArraySearch($g_aAllColumnNames, $aColumnNames[$j]) = -1 Then
            _ArrayAdd($g_aAllColumnNames, $aColumnNames[$j])
        EndIf
    Next
    
    ; Tabelle im Dictionary aktualisieren
    If $g_oTablesColumnsCache.Exists($sTable) Then
        $g_oTablesColumnsCache.Item($sTable) = $aColumnNames
    Else
        $g_oTablesColumnsCache.Add($sTable, $aColumnNames)
        
        ; Auch die Tabellenliste aktualisieren
        If _ArraySearch($g_aAllTableNames, $sTable) = -1 Then
            _ArrayAdd($g_aAllTableNames, $sTable)
        EndIf
    EndIf
    
    ; Datenbank schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)
    
    ; Globale Arrays für die Autovervollständigung aktualisieren
    _SQL_UpdateAutoCompleteArrays()
    
    _LogInfo("_SQL_UpdateSpecificTable: " & $iColRows & " Spalten für Tabelle '" & $sTable & "' geladen")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_CheckForSchemaChanges
; Beschreibung: Prüft auf Änderungen am Datenbankschema und aktualisiert die Metadaten bei Bedarf
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: True wenn Änderungen gefunden wurden, False wenn nicht
; ===============================================================================================================================
Func _SQL_CheckForSchemaChanges($sDBPath)
    _LogInfo("_SQL_CheckForSchemaChanges: Prüfe auf Schema-Änderungen in Datenbank: " & $sDBPath)
    
    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("_SQL_CheckForSchemaChanges: Datenbankdatei nicht gefunden: " & $sDBPath)
        Return False
    EndIf
    
    ; Dictionary initialisieren, wenn noch nicht geschehen
    If Not IsObj($g_oTablesColumnsCache) Then
        _SQL_InitMetadataManager()
    EndIf
    
    ; Datenbankverbindung herstellen
    Local $hDB, $bWasOpened = False
    If _SQLite_Exec(-1, "SELECT 1") <> $SQLITE_OK Then
        ; Keine aktive Verbindung, neue erstellen
        $hDB = _SQLite_Open($sDBPath, $SQLITE_OPEN_READONLY)
        If @error Then
            _LogError("_SQL_CheckForSchemaChanges: Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
            Return False
        EndIf
        $bWasOpened = True
    Else
        $hDB = -1 ; Bestehende Verbindung verwenden
    EndIf
    
    ; Aktuelle Tabellen abfragen
    Local $aTableResult, $iTableRows, $iTableColumns
    Local $sTableSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    Local $iTableRet = _SQLite_GetTable2d($hDB, $sTableSQL, $aTableResult, $iTableRows, $iTableColumns)
    
    If @error Or $iTableRet <> $SQLITE_OK Then
        _LogError("_SQL_CheckForSchemaChanges: Fehler bei der Tabellenabfrage: " & _SQLite_ErrMsg())
        If $bWasOpened Then _SQLite_Close($hDB)
        Return False
    EndIf
    
    ; Flag, ob Änderungen gefunden wurden
    Local $bChangesFound = False
    
    ; Prüfen, ob neue Tabellen hinzugekommen sind
    For $i = 0 To $iTableRows - 1
        Local $sTableName = $aTableResult[$i+1][0] ; +1 wegen Header-Zeile
        
        ; Prüfen, ob diese Tabelle bereits im Cache ist
        If Not $g_oTablesColumnsCache.Exists($sTableName) Then
            _LogInfo("_SQL_CheckForSchemaChanges: Neue Tabelle gefunden: " & $sTableName)
            ; Spalteninformationen für diese Tabelle laden
            _SQL_UpdateSpecificTable($sDBPath, $sTableName)
            $bChangesFound = True
        Else
            ; Prüfen, ob sich die Spalten geändert haben
            Local $aCurrentCols = $g_oTablesColumnsCache.Item($sTableName)
            
            ; Spalteninformationen für diese Tabelle abrufen
            Local $aColResult, $iColRows, $iColColumns
            Local $sColSQL = "PRAGMA table_info(" & $sTableName & ")"
            Local $iColRet = _SQLite_GetTable2d($hDB, $sColSQL, $aColResult, $iColRows, $iColColumns)
            
            If @error Or $iColRet <> $SQLITE_OK Then
                _LogError("_SQL_CheckForSchemaChanges: Fehler bei der Spaltenabfrage für Tabelle '" & $sTableName & "': " & _SQLite_ErrMsg())
                ContinueLoop
            EndIf
            
            ; Anzahl der Spalten vergleichen
            If UBound($aCurrentCols) <> $iColRows Then
                _LogInfo("_SQL_CheckForSchemaChanges: Änderung der Spaltenanzahl in Tabelle '" & $sTableName & "'")
                ; Spalteninformationen aktualisieren
                _SQL_UpdateSpecificTable($sDBPath, $sTableName)
                $bChangesFound = True
                ContinueLoop
            EndIf
            
            ; Einzelne Spalten vergleichen
            For $j = 0 To $iColRows - 1
                Local $sColName = $aColResult[$j+1][1]
                If _ArraySearch($aCurrentCols, $sColName) = -1 Then
                    _LogInfo("_SQL_CheckForSchemaChanges: Neue Spalte '" & $sColName & "' in Tabelle '" & $sTableName & "' gefunden")
                    ; Spalteninformationen aktualisieren
                    _SQL_UpdateSpecificTable($sDBPath, $sTableName)
                    $bChangesFound = True
                    ExitLoop ; Eine Änderung reicht, um die Tabelle komplett zu aktualisieren
                EndIf
            Next
        EndIf
    Next
    
    ; Datenbank schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)
    
    ; Wenn Änderungen gefunden wurden, globale Arrays aktualisieren
    If $bChangesFound Then
        _SQL_UpdateAutoCompleteArrays()
    EndIf
    
    _LogInfo("_SQL_CheckForSchemaChanges: Prüfung abgeschlossen, Änderungen gefunden: " & ($bChangesFound ? "Ja" : "Nein"))
    Return $bChangesFound
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_GetTableColumns
; Beschreibung: Gibt die Spalten einer bestimmten Tabelle zurück
; Parameter.: $sTable - Tabellenname
; Rückgabe..: Array mit Spaltennamen oder leeres Array bei Fehler
; ===============================================================================================================================
Func _SQL_GetTableColumns($sTable)
    If Not IsObj($g_oTablesColumnsCache) Or Not $g_oTablesColumnsCache.Exists($sTable) Then
        _LogInfo("_SQL_GetTableColumns: Tabelle '" & $sTable & "' nicht im Cache")
        Return _SQL_GetEmptyArray()
    EndIf
    
    Return $g_oTablesColumnsCache.Item($sTable)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_GetAllTables
; Beschreibung: Gibt alle Tabellennamen zurück
; Parameter.: Keine
; Rückgabe..: Array mit Tabellennamen
; ===============================================================================================================================
Func _SQL_GetAllTables()
    Return $g_aAllTableNames
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_GetAllColumns
; Beschreibung: Gibt alle eindeutigen Spaltennamen zurück
; Parameter.: Keine
; Rückgabe..: Array mit Spaltennamen
; ===============================================================================================================================
Func _SQL_GetAllColumns()
    Return $g_aAllColumnNames
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_GetEmptyArray
; Beschreibung: Gibt ein leeres Array zurück
; Parameter.: Keine
; Rückgabe..: Leeres Array
; ===============================================================================================================================
Func _SQL_GetEmptyArray()
    Local $aEmpty[0]
    Return $aEmpty
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateAutoCompleteMetadata
; Beschreibung: Aktualisiert die Metadaten für die SQL-Autovervollständigung
;               (Kompatibilitätsfunktion für vorhandenen Code)
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Optional: Spezifische Tabelle, deren Spaltennamen aktualisiert werden sollen
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateAutoCompleteMetadata($sDBPath, $sTable = "")
    _LogInfo("_SQL_UpdateAutoCompleteMetadata: Aktualisiere Metadaten für Autovervollständigung")
    
    ; Prüfen, ob bereits Metadaten geladen sind
    If Not IsObj($g_oTablesColumnsCache) Or $g_oTablesColumnsCache.Count = 0 Then
        ; Noch keine Daten geladen, alles laden
        _LogInfo("_SQL_UpdateAutoCompleteMetadata: Noch keine Metadaten geladen, lade alle Metadaten")
        Return _SQL_LoadAllMetadata($sDBPath)
    EndIf
    
    ; Wenn eine spezifische Tabelle angegeben wurde, nur diese aktualisieren
    If $sTable <> "" Then
        _LogInfo("_SQL_UpdateAutoCompleteMetadata: Aktualisiere Spaltennamen für Tabelle '" & $sTable & "'")
        Return _SQL_UpdateSpecificTable($sDBPath, $sTable)
    EndIf
    
    ; Ansonsten auf Schema-Änderungen prüfen
    _LogInfo("_SQL_UpdateAutoCompleteMetadata: Prüfe auf Schema-Änderungen")
    Return _SQL_CheckForSchemaChanges($sDBPath)
EndFunc