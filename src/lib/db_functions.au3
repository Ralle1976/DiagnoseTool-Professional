#include-once
#include <SQLite.au3>
#include <GUIListView.au3>
#include <GUIConstants.au3> ; Für GUI-Konstanten wie $GUI_ENABLE
#include "logging.au3"
#include "globals.au3" ; Für globale Variablen wie $idTableCombo, $idBtnRefresh, etc.
#include "filter_functions.au3" ; Für Filterfunktionen

; Globale Struktur zum Speichern der Tabellen- und Spalteninformationen
Global $g_oTablesAndColumns ; Dictionary-Objekt: Tabellenname => Array von Spaltennamen

; Hilfsfunktion: Tabellen- und Spaltenstruktur auslesen
Func _LoadTableAndColumnStructure($sDBPath)
    _LogInfo("Lade Tabellen- und Spaltenstruktur...")
    
    ; Prüfen, ob Datenbank existiert
    If Not FileExists($sDBPath) Then
        _LogError("Datenbank nicht gefunden: " & $sDBPath)
        Return False
    EndIf
    
    ; Dictionary für Tabellen und Spalten erstellen
    $g_oTablesAndColumns = ObjCreate("Scripting.Dictionary")
    
    ; Verfügbare Tabellen abrufen
    Local $aResult, $iRows, $iColumns
    Local $sQuery = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d(-1, $sQuery, $aResult, $iRows, $iColumns)
    
    If @error Or $iRet = $SQLITE_ERROR Then
        _LogError("Fehler beim Abrufen der Tabellen")
        Return False
    EndIf
    
    _LogInfo("Gefundene Tabellen: " & $iRows)
    
    ; Für jede Tabelle die Spalten auslesen
    For $i = 1 To $iRows
        Local $sTableName = $aResult[$i][0]
        _LogInfo("Lese Spalten für Tabelle: " & $sTableName)
        
        ; PRAGMA-Befehl ausführen, um Spalteninformationen zu erhalten
        Local $aColumns, $iColRows, $iColColumns
        Local $sColQuery = "PRAGMA table_info(" & $sTableName & ");"
        $iRet = _SQLite_GetTable2d(-1, $sColQuery, $aColumns, $iColRows, $iColColumns)
        
        If @error Or $iRet = $SQLITE_ERROR Then
            _LogWarning("Fehler beim Abrufen der Spalteninformationen für Tabelle: " & $sTableName)
            ContinueLoop
        EndIf
        
        ; Spalten in Array speichern
        Local $aColumnNames[$iColRows]
        For $j = 1 To $iColRows
            $aColumnNames[$j-1] = $aColumns[$j][1] ; Spalte 1 enthält den Namen
            _LogInfo("  - Spalte: " & $aColumnNames[$j-1])
        Next
        
        ; Tabelle und Spalten im Dictionary speichern
        $g_oTablesAndColumns.Add($sTableName, $aColumnNames)
    Next
    
    _LogInfo("Tabellen- und Spaltenstruktur erfolgreich geladen. Tabellen: " & $g_oTablesAndColumns.Count)
    Return True
EndFunc

Func _DB_Connect($sDBPath)
    If Not FileExists($sDBPath) Then
        _LogError("Datenbank nicht gefunden: " & $sDBPath)
        Return False
    EndIf
    
    _SQLite_Close()
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath)
        Return False
    EndIf
    
    _LogInfo("Datenbankverbindung hergestellt: " & $sDBPath)
    
    ; Speichern des Datenbankpfads als globale Variable für späteren Zugriff
    $g_sCurrentDB = $sDBPath
    
    ; Alle Metadaten (Tabellen und Spalten) für Autovervollständigung laden
    _SQL_LoadAllMetadata($sDBPath)
    _LogInfo("Alle Datenbank-Metadaten für Autovervollständigung geladen")
    
    ; Tabellen- und Spaltenstruktur auslesen
    If Not _LoadTableAndColumnStructure($sDBPath) Then
        _LogWarning("Konnte Tabellen- und Spaltenstruktur nicht vollständig laden")
        ; Trotzdem fortfahren mit den verfügbaren Informationen
    EndIf
    
    ; ComboBox leeren und neu füllen
    GUICtrlSetData($idTableCombo, "")
    
    ; Tabellennamen aus dem Dictionary holen
    Local $aTables = $g_oTablesAndColumns.Keys
    For $i = 0 To UBound($aTables) - 1
        _LogInfo("Füge Tabelle hinzu: " & $aTables[$i])
        GUICtrlSetData($idTableCombo, $aTables[$i])
    Next
    
    ; Erste Tabelle auswählen
    If $g_oTablesAndColumns.Count > 0 Then
        Local $aTables = $g_oTablesAndColumns.Keys
        $g_sCurrentTable = $aTables[0]
        GUICtrlSetData($idTableCombo, $g_sCurrentTable)
        _LogInfo("Aktuelle Tabelle gesetzt: " & $g_sCurrentTable)
        
        ; GUI-Elemente aktivieren
        GUICtrlSetState($idTableCombo, $GUI_ENABLE)
        GUICtrlSetState($idBtnRefresh, $GUI_ENABLE)
        GUICtrlSetState($idBtnFilter, $GUI_ENABLE)
        GUICtrlSetState($idBtnExport, $GUI_ENABLE)
        GUICtrlSetState($idBtnSQLEditor, $GUI_ENABLE) ; SQL-Editor-Button aktivieren
        
        ; Daten der ersten Tabelle laden
        Return _LoadDatabaseData()
    EndIf
    
    Return True
EndFunc

Func _LoadDatabaseData()
    ; Filter zurücksetzen, wenn er aktiv ist
    If $g_bFilterActive Then
        _ResetListViewFilter()
        _LogInfo("Filter wurde beim Aktualisieren zurückgesetzt")
    EndIf
    
    If $g_sCurrentTable = "" Then
        _LogError("Keine Tabelle ausgewählt")
        Return False
    EndIf
    
    $g_bIsLoading = True
    GUICtrlSetData($g_idStatus, "Lade Daten...")
    _LogInfo("Lade Daten aus Tabelle: " & $g_sCurrentTable)
    
    ; Spalteninformationen abrufen
    Local $aColumns, $iRows, $iColumns
    Local $sQuery = "PRAGMA table_info(" & $g_sCurrentTable & ");"    
    _LogInfo("SQL-Query: " & $sQuery)
    Local $iRet = _SQLite_GetTable2d(-1, $sQuery, $aColumns, $iRows, $iColumns)
    If @error Or $iRet = $SQLITE_ERROR Then
        _LogError("Fehler beim Abrufen der Spalteninformationen: " & _SQLite_ErrMsg())
        $g_bIsLoading = False
        Return False
    EndIf
    
    _LogInfo("Spalteninformationen erhalten: " & $iRows & " Spalten")
    
    ; Debug-Ausgabe der Spalteninformationen
    For $i = 1 To $iRows
        _LogInfo("Spalte " & $i & ": ID=" & $aColumns[$i][0] & ", Name=" & $aColumns[$i][1])
    Next
    
    ; ListView vorbereiten
    _GUICtrlListView_BeginUpdate(GUICtrlGetHandle($g_idListView))
    
    ; Bestehende Daten löschen
    _GUICtrlListView_DeleteAllItems(GUICtrlGetHandle($g_idListView))
    
    ; Alle Spalten löschen - Wir nutzen die Funktion aus missing_functions.au3
    Local $hListView = GUICtrlGetHandle($g_idListView)
    Local $iColumnCount = _GUICtrlListView_GetColumnCount($hListView)
    For $i = $iColumnCount - 1 To 0 Step -1
        _GUICtrlListView_DeleteColumn($hListView, $i)
    Next
    
    ; Spalten erstellen
    _LogInfo("Erstelle " & $iRows & " Spalten")
    For $i = 0 To $iRows - 1
        ; Index 1 enthält den Spaltennamen
        _GUICtrlListView_InsertColumn($g_idListView, $i, $aColumns[$i + 1][1], 100)
    Next
    
    ; Daten laden
    Local $aData, $iDataRows, $iDataColumns
    $sQuery = "SELECT * FROM " & $g_sCurrentTable & " LIMIT 1000;"
    $iRet = _SQLite_GetTable2d(-1, $sQuery, $aData, $iDataRows, $iDataColumns)
    
    If @error Or $iRet = $SQLITE_ERROR Then
        _LogError("Fehler beim Laden der Tabellendaten")
        _GUICtrlListView_EndUpdate(GUICtrlGetHandle($g_idListView))
        $g_bIsLoading = False
        Return False
    EndIf
    
    _LogInfo("Füge " & $iDataRows & " Datensätze ein")
    
    ; Daten einfügen
    For $i = 1 To $iDataRows
        _GUICtrlListView_AddItem($g_idListView, $aData[$i][0])
        For $j = 1 To $iDataColumns - 1
            _GUICtrlListView_AddSubItem($g_idListView, $i - 1, $aData[$i][$j], $j)
        Next
    Next
    
    _GUICtrlListView_EndUpdate(GUICtrlGetHandle($g_idListView))
    
    $g_bIsLoading = False
    GUICtrlSetData($g_idStatus, $iDataRows & " Datensätze geladen.")
    _LogInfo("Datenladen abgeschlossen: " & $iDataRows & " Datensätze")
    
    Return True
EndFunc