; Titel.......: SQL-Autocomplete-Connector - Verbindung zwischen SQL-Editor und Datenbank-Metadaten
; Beschreibung: Stellt die Verbindung zwischen der Autovervollständigung und den Datenbank-Metadaten her
; Autor.......: Claude
; Erstellt....: 2025-04-28
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <Array.au3>
#include "logging.au3"

; ===============================================================================================================================
; Func.....: _SQL_UpdateAutoCompleteMetadata
; Beschreibung: Aktualisiert die Metadaten für die SQL-Autovervollständigung
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Aktuell ausgewählte Tabelle
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateAutoCompleteMetadata($sDBPath, $sTable)
    _LogInfo("_SQL_UpdateAutoCompleteMetadata: Aktualisiere Metadaten für Tabelle '" & $sTable & "'")

    ; Prüfe Parameter
    If $sDBPath = "" Then
        _LogError("_SQL_UpdateAutoCompleteMetadata: Kein Datenbankpfad angegeben")
        Return False
    EndIf

    If $sTable = "" Then
        _LogInfo("_SQL_UpdateAutoCompleteMetadata: Keine Tabelle angegeben, lade nur allgemeine Metadaten")
    EndIf

    ; Metadaten für Autovervollständigung aktualisieren
    ; 1. Tabellennamen aktualisieren (für FROM/JOIN-Kontexte)
    _SQL_UpdateTableNames($sDBPath)

    ; 2. Spaltennamen für die aktuelle Tabelle aktualisieren
    If $sTable <> "" Then
        _SQL_UpdateColumnNames($sDBPath, $sTable)
    EndIf

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateTableNames
; Beschreibung: Aktualisiert die Tabellennamen für die Autovervollständigung
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateTableNames($sDBPath)
    _LogInfo("_SQL_UpdateTableNames: Lade Tabellennamen aus Datenbank: " & $sDBPath)

    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("_SQL_UpdateTableNames: Datenbankdatei nicht gefunden: " & $sDBPath)
        Return False
    EndIf

    ; Datenbankverbindung herstellen
    Local $hDB, $bWasOpened = False
    If _SQLite_Exec(-1, "SELECT 1") <> $SQLITE_OK Then
        ; Keine aktive Verbindung, neue erstellen
        $hDB = _SQLite_Open($sDBPath, $SQLITE_OPEN_READONLY)
        If @error Then
            _LogError("_SQL_UpdateTableNames: Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
            Return False
        EndIf
        $bWasOpened = True
    Else
        $hDB = -1 ; Bestehende Verbindung verwenden
    EndIf

    ; Tabellennamen abfragen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Then
        _LogError("_SQL_UpdateTableNames: Fehler bei der Abfrage: " & _SQLite_ErrMsg())
        Return False
    EndIf

    ; Tabellennamen in Array extrahieren
    Local $aTableNames[$iRows]
    For $i = 0 To $iRows - 1
        $aTableNames[$i] = $aResult[$i+1][0] ; +1 wegen Header-Zeile
    Next

    ; Globale Variable aktualisieren
    If IsDeclared("g_aOriginalCaseTableNames") Then
        ; Für sql_autocomplete_improved.au3 (verbesserte Version)
        ReDim $g_aOriginalCaseTableNames[$iRows]
        For $i = 0 To $iRows - 1
            $g_aOriginalCaseTableNames[$i] = $aTableNames[$i]
        Next
        _LogInfo("g_aOriginalCaseTableNames aktualisiert mit " & $iRows & " Tabellen")
    EndIf

    _LogInfo("_SQL_UpdateTableNames: " & $iRows & " Tabellennamen geladen")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_UpdateColumnNames
; Beschreibung: Aktualisiert die Spaltennamen einer Tabelle für die Autovervollständigung
; Parameter.: $sDBPath - Pfad zur Datenbank
;             $sTable - Tabellenname
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_UpdateColumnNames($sDBPath, $sTable)
    _LogInfo("_SQL_UpdateColumnNames: Lade Spaltennamen für Tabelle '" & $sTable & "'")

    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("_SQL_UpdateColumnNames: Datenbankdatei nicht gefunden: " & $sDBPath)
        Return False
    EndIf

    ; Datenbankverbindung herstellen
    Local $hDB, $bWasOpened = False
    If _SQLite_Exec(-1, "SELECT 1") <> $SQLITE_OK Then
        ; Keine aktive Verbindung, neue erstellen
        $hDB = _SQLite_Open($sDBPath, $SQLITE_OPEN_READONLY)
        If @error Then
            _LogError("_SQL_UpdateColumnNames: Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
            Return False
        EndIf
        $bWasOpened = True
    Else
        $hDB = -1 ; Bestehende Verbindung verwenden
    EndIf

    ; Spaltennamen abfragen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "PRAGMA table_info(" & $sTable & ")"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Then
        _LogError("_SQL_UpdateColumnNames: Fehler bei der Abfrage: " & _SQLite_ErrMsg())
        Return False
    EndIf

    ; Tabellenspalten in Array extrahieren
    Local $aColumnNames[$iRows]
    For $i = 0 To $iRows - 1
        $aColumnNames[$i] = $aResult[$i+1][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    ; Arrays neu dimensionieren
    If IsDeclared("g_aTableColumns") Then
        ReDim $g_aTableColumns[$iRows]
        For $i = 0 To $iRows - 1
            $g_aTableColumns[$i] = $aColumnNames[$i]
        Next
        _LogInfo("g_aTableColumns aktualisiert mit " & $iRows & " Spalten")
    EndIf

    If IsDeclared("g_aOriginalCaseColumnNames") Then
        ; Für sql_autocomplete_improved.au3 (verbesserte Version)
        ReDim $g_aOriginalCaseColumnNames[$iRows]
        For $i = 0 To $iRows - 1
            $g_aOriginalCaseColumnNames[$i] = $aColumnNames[$i]
        Next
        _LogInfo("g_aOriginalCaseColumnNames aktualisiert mit " & $iRows & " Spalten")
    EndIf

    _LogInfo("_SQL_UpdateColumnNames: " & $iRows & " Spaltennamen geladen")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_GetAllColumnNames
; Beschreibung: Extrahiert alle Spaltennamen aus allen Tabellen
; Parameter.: $sDBPath - Pfad zur Datenbank
; Rückgabe..: Array mit allen Spaltennamen
; ===============================================================================================================================
Func _SQL_GetAllColumnNames($sDBPath)
    _LogInfo("_SQL_GetAllColumnNames: Lade alle Spaltennamen aus Datenbank: " & $sDBPath)

    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("_SQL_GetAllColumnNames: Datenbankdatei nicht gefunden: " & $sDBPath)
        Local $aEmpty[0]
        Return $aEmpty
    EndIf

    ; Datenbankverbindung herstellen
    Local $hDB, $bWasOpened = False
    If _SQLite_Exec(-1, "SELECT 1") <> $SQLITE_OK Then
        ; Keine aktive Verbindung, neue erstellen
        $hDB = _SQLite_Open($sDBPath, $SQLITE_OPEN_READONLY)
        If @error Then
            _LogError("_SQL_GetAllColumnNames: Fehler beim Öffnen der Datenbank: " & _SQLite_ErrMsg())
            Local $aEmpty[0]
            Return $aEmpty
        EndIf
        $bWasOpened = True
    Else
        $hDB = -1 ; Bestehende Verbindung verwenden
    EndIf

    ; Zuerst Tabellennamen abfragen
    Local $aTableResult, $iTableRows, $iTableColumns
    Local $sTableSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    Local $iTableRet = _SQLite_GetTable2d($hDB, $sTableSQL, $aTableResult, $iTableRows, $iTableColumns)

    If @error Or $iTableRet <> $SQLITE_OK Then
        _LogError("_SQL_GetAllColumnNames: Fehler bei der Tabellenabfrage: " & _SQLite_ErrMsg())
        If $bWasOpened Then _SQLite_Close($hDB)
        Local $aEmpty[0]
        Return $aEmpty
    EndIf

    ; Array für alle Spaltennamen
    Local $aAllColumns[0]

    ; Für jede Tabelle die Spaltennamen abrufen
    For $i = 0 To $iTableRows - 1
        Local $sTableName = $aTableResult[$i+1][0] ; +1 wegen Header-Zeile
        
        ; Spaltennamen für diese Tabelle abfragen
        Local $aColResult, $iColRows, $iColColumns
        Local $sColSQL = "PRAGMA table_info(" & $sTableName & ")"
        Local $iColRet = _SQLite_GetTable2d($hDB, $sColSQL, $aColResult, $iColRows, $iColColumns)
        
        If @error Or $iColRet <> $SQLITE_OK Then
            _LogError("_SQL_GetAllColumnNames: Fehler bei der Spaltenabfrage für Tabelle '" & $sTableName & "': " & _SQLite_ErrMsg())
            ContinueLoop
        EndIf
        
        ; Spaltennamen hinzufügen
        For $j = 0 To $iColRows - 1
            Local $sColumnName = $aColResult[$j+1][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
            
            ; Nur hinzufügen, wenn noch nicht im Array
            If _ArraySearch($aAllColumns, $sColumnName) = -1 Then
                _ArrayAdd($aAllColumns, $sColumnName)
            EndIf
        Next
    Next

    ; Datenbank schließen, wenn wir sie geöffnet haben
    If $bWasOpened Then _SQLite_Close($hDB)

    _LogInfo("_SQL_GetAllColumnNames: " & UBound($aAllColumns) & " eindeutige Spaltennamen geladen")
    Return $aAllColumns
EndFunc