#include-once
#include <SQLite.au3>
#include "logging.au3"

Func _InitSystem()
    ; SQLite-DLL initialisieren
    _SQLite_Startup($g_sqliteDLL)
    If @error Then
        MsgBox($MB_ICONERROR, "Fehler", "SQLite konnte nicht initialisiert werden.")
        _LogError("SQLite Initialisierung fehlgeschlagen: " & $g_sqliteDLL)
        Return False
    EndIf
    _LogInfo("SQLite erfolgreich initialisiert")

    ; Logging-System initialisieren
    If Not _LogInit() Then
        MsgBox($MB_ICONERROR, "Fehler", "Logging-System konnte nicht initialisiert werden.")
        Return False
    EndIf
    _LogInfo("Logging-System initialisiert")

    ; Temporäre Verzeichnisse prüfen/erstellen
    Local $sTempDir = IniRead($g_sSettingsFile, "PATHS", "temp_dir", @TempDir & "\diagnose-tool")
    Local $sExtractDir = IniRead($g_sSettingsFile, "PATHS", "extract_dir", $sTempDir & "\extracted")

    If Not FileExists($sTempDir) Then
        DirCreate($sTempDir)
        _LogInfo("Temporäres Verzeichnis erstellt: " & $sTempDir)
    EndIf

    If Not FileExists($sExtractDir) Then
        DirCreate($sExtractDir)
        _LogInfo("Extraktionsverzeichnis erstellt: " & $sExtractDir)
    EndIf

    Return True
EndFunc

Func _Cleanup()
    ; Temporäre Dateien bereinigen
    Local $sTempDir = IniRead($g_sSettingsFile, "PATHS", "temp_dir", @TempDir & "\diagnose-tool")
    
    ; Temporäre Dateien bereinigen, wenn in Einstellungen aktiviert
    If FileExists($sTempDir) And IniRead($g_sSettingsFile, "GUI", "auto_clear_temp", "1") = "1" Then
        DirRemove($sTempDir, 1)
        _LogInfo("Temporäre Dateien bereinigt: " & $sTempDir)
    EndIf
    
    ; Logdateien bereinigen, wenn in Einstellungen aktiviert
    Local $sLogsDir = @ScriptDir & "\logs"
    If FileExists($sLogsDir) And IniRead($g_sSettingsFile, "GUI", "auto_clear_logs", "0") = "1" Then
        DirRemove($sLogsDir, 1)
        _LogInfo("Logdateien bereinigt: " & $sLogsDir)
    EndIf

    ; Datenbankverbindung beenden
    _SQLite_Close()
    _SQLite_Shutdown()
    _LogInfo("SQLite heruntergefahren")

    ; Logging beenden
    _LogInfo("=== Programm beendet ===")
EndFunc