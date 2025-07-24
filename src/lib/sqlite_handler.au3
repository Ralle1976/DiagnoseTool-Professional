#include-once
#include <SQLite.au3>
#include "logging.au3"
#include "error_handler.au3"
;~ Global $g_sqliteDLL = @ScriptDir & "\Lib\sqlite3.dll"
; SQLite-Initialisierung
Func _SQLiteHandler_Init()
    ; SQLite-Bibliothek initialisieren
    _SQLite_Startup($g_sqliteDLL)
    If @error Then
        _LogError("SQLite-Initialisierung fehlgeschlagen")
        Return False
    EndIf

    _LogInfo("SQLite erfolgreich initialisiert")
    Return True
EndFunc

; Datenbank öffnen
Func _SQLiteHandler_OpenDatabase($sDbPath)
    ; Überprüfen, ob Datenbankdatei existiert
    If Not FileExists($sDbPath) Then
        _LogError("Datenbank nicht gefunden: " & $sDbPath)
        Return SetError(1, 0, False)
    EndIf

    ; Datenbank-Handle öffnen
    Local $hDatabase = _SQLite_Open($sDbPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDbPath)
        Return SetError(2, 0, False)
    EndIf

    _LogInfo("Datenbank geöffnet: " & $sDbPath)
    Return $hDatabase
EndFunc

; Query ausführen
Func _SQLiteHandler_Query($hDatabase, $sQuery)
    If $hDatabase = 0 Then
        _LogError("Ungültiges Datenbank-Handle")
        Return SetError(1, 0, False)
    EndIf

    ; Query vorbereiten
    Local $hQuery
    _SQLite_Query($hDatabase, $sQuery, $hQuery)
    If @error Then
        _LogError("SQL-Query-Fehler: " & $sQuery)
        Return SetError(2, 0, False)
    EndIf

    _LogInfo("Query ausgeführt: " & $sQuery)
    Return $hQuery
EndFunc

; Daten abrufen
Func _SQLiteHandler_FetchData($hQuery, ByRef $aRow)
    Local $iResult = _SQLite_FetchData($hQuery, $aRow)

    Switch $iResult
        Case $SQLITE_ROW
            Return True
        Case $SQLITE_DONE
            Return False
        Case Else
            _LogError("Fehler beim Abrufen von Daten")
            Return SetError(1, 0, False)
    EndSwitch
EndFunc

; Query finalisieren
Func _SQLiteHandler_FinalizeQuery($hQuery)
    If $hQuery Then
        _SQLite_QueryFinalize($hQuery)
        _LogInfo("Query finalisiert")
    EndIf
EndFunc

; Datenbank schließen
Func _SQLiteHandler_CloseDatabase($hDatabase)
    If $hDatabase Then
        _SQLite_Close($hDatabase)
        _LogInfo("Datenbank geschlossen")
    EndIf
EndFunc

; SQLite-Bibliothek herunterfahren
Func _SQLiteHandler_Shutdown()
    _SQLite_Shutdown()
    _LogInfo("SQLite-Bibliothek heruntergefahren")
EndFunc

; Tabellen auflisten
Func _SQLiteHandler_ListTables($hDatabase)
    If $hDatabase = 0 Then
        _LogError("Ungültiges Datenbank-Handle")
        Return SetError(1, 0, False)
    EndIf

    Local $aResult, $iRows, $iColumns
    _SQLite_GetTable2D($hDatabase, "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name", $aResult, $iRows, $iColumns)

    If @error Then
        _LogError("Fehler beim Auflisten der Tabellen")
        Return SetError(2, 0, False)
    EndIf

    ; Konvertiere Ergebnis in einfaches Array
    Local $aTables[$iRows]
    For $i = 1 To $iRows
        $aTables[$i-1] = $aResult[$i][0]
    Next

    Return $aTables
EndFunc

; Tabellenschema abrufen
Func _SQLiteHandler_GetTableSchema($hDatabase, $sTableName)
    If $hDatabase = 0 Then
        _LogError("Ungültiges Datenbank-Handle")
        Return SetError(1, 0, False)
    EndIf

    Local $aResult, $iRows, $iColumns
    _SQLite_GetTable2D($hDatabase, "PRAGMA table_info(" & $sTableName & ")", $aResult, $iRows, $iColumns)

    If @error Then
        _LogError("Fehler beim Abrufen des Tabellenschemas: " & $sTableName)
        Return SetError(2, 0, False)
    EndIf

    Return $aResult
EndFunc
