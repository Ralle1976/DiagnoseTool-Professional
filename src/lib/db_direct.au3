#include-once
#include <SQLite.au3>
#include <File.au3>
#include "logging.au3"
#include "db_functions.au3"

; Direkte Öffnung einer Datenbankdatei (ohne ZIP-Entpacken)
Func _OpenDatabaseFile($sFile)
    If Not FileExists($sFile) Then
        _LogError("Datenbank nicht gefunden: " & $sFile)
        Return False
    EndIf

    ; Dateierweiterung prüfen
    Local $sExt = StringLower(StringRight($sFile, 3))
    If $sExt <> "db3" And $sExt <> ".db" Then
        _LogError("Ungültiges Datenbankformat: " & $sExt)
        MsgBox(16, "Fehler", "Die gewählte Datei ist keine unterstützte SQLite-Datenbank. Unterstützte Formate: .db, .db3")
        Return False
    EndIf

    _LogInfo("Öffne Datenbank direkt: " & $sFile)

    ; Datenbank öffnen und verarbeiten
    Global $g_sCurrentDB = $sFile

    ; Status aktualisieren
    GUICtrlSetData($g_idStatus, "Datenbank geöffnet: " & $sFile)

    ; Datenbank mit vorhandener Funktion öffnen
    Return _DB_Connect($sFile)
EndFunc