#include <Date.au3>

; Logging-Konstanten
Global Const $LOG_LEVEL_DEBUG = 0
Global Const $LOG_LEVEL_INFO = 1
Global Const $LOG_LEVEL_WARNING = 2
Global Const $LOG_LEVEL_ERROR = 3
Global Const $LOG_LEVEL_CRITICAL = 4

; Globale Logging-Variablen
Global $g_sLogFile = @ScriptDir & "\logs\diagnostic_log_" & @YEAR & @MON & @MDAY & ".log"
Global $g_iCurrentLogLevel = $LOG_LEVEL_INFO ; Standardmäßig INFO und höher
Global $g_bEnableConsoleOutput = True
Global $g_bEnableFileOutput = True

; ===============================================================================================================================
; Func.....: _InitializeLogging
; Beschreibung: Initialisiert das Logging-System
; Parameter.: $iLogLevel - Minimaler Log-Level (optional)
;             $bConsoleOutput - Konsolenausgabe aktivieren (optional)
;             $bFileOutput - Datei-Logging aktivieren (optional)
; Rückgabe..: Erfolg - True, Fehler - False
; ===============================================================================================================================
Func _InitializeLogging($iLogLevel = $LOG_LEVEL_INFO, $bConsoleOutput = True, $bFileOutput = True)
    ; Logging-Verzeichnis erstellen, falls nicht vorhanden
    Local $sLogDir = @ScriptDir & "\logs"
    If Not FileExists($sLogDir) Then
        DirCreate($sLogDir)
        If @error Then
            ConsoleWrite("CRITICAL: Konnte Logging-Verzeichnis nicht erstellen!" & @CRLF)
            Return False
        EndIf
    EndIf

    ; Log-Level setzen
    $g_iCurrentLogLevel = $iLogLevel
    $g_bEnableConsoleOutput = $bConsoleOutput
    $g_bEnableFileOutput = $bFileOutput

    ; Initialer Log-Eintrag
    _Log("Logging initialisiert", $LOG_LEVEL_INFO)

    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _Log
; Beschreibung: Zentrale Logging-Funktion
; Parameter.: $sMessage - Zu loggende Nachricht
;             $iLogLevel - Log-Level der Nachricht
;             $sContext - Optionaler Kontext (Funktionsname, etc.)
; Rückgabe..: Keine
; ===============================================================================================================================
Func _Log($sMessage, $iLogLevel = $LOG_LEVEL_INFO, $sContext = "")
    ; Prüfen, ob Logging für diesen Level aktiviert ist
    If $iLogLevel < $g_iCurrentLogLevel Then Return

    ; Zeitstempel generieren
    Local $sTimestamp = _Now()

    ; Log-Level-Text
    Local $sLogLevelText = ""
    Switch $iLogLevel
        Case $LOG_LEVEL_DEBUG
            $sLogLevelText = "DEBUG   "
        Case $LOG_LEVEL_INFO
            $sLogLevelText = "INFO    "
        Case $LOG_LEVEL_WARNING
            $sLogLevelText = "WARNING "
        Case $LOG_LEVEL_ERROR
            $sLogLevelText = "ERROR   "
        Case $LOG_LEVEL_CRITICAL
            $sLogLevelText = "CRITICAL"
    EndSwitch

    ; Vollständige Nachricht zusammensetzen
    Local $sFullMessage = StringFormat("[%s] %s %s%s", $sTimestamp, $sLogLevelText, $sContext ? "(" & $sContext & ") " : "", $sMessage)

    ; Konsolenausgabe
    If $g_bEnableConsoleOutput Then
        ConsoleWrite($sFullMessage & @CRLF)
    EndIf

    ; Datei-Logging
    If $g_bEnableFileOutput Then
        ; Temporäre Datei-Logging-Lösung mit Fehlerbehandlung
        Local $hFileHandle = FileOpen($g_sLogFile, $FO_APPEND)
        If $hFileHandle <> -1 Then
            FileWriteLine($hFileHandle, $sFullMessage)
            FileClose($hFileHandle)
        Else
            ; Notfall-Konsolen-Ausgabe, falls Datei-Logging fehlschlägt
            ConsoleWrite("CRITICAL: Konnte nicht in Logdatei schreiben: " & $g_sLogFile & @CRLF)
        EndIf
    EndIf
EndFunc

; Weitere Logging-Funktionen wie in vorherigem Patch
Func _LogDebug($sMessage, $sContext = "")
    _Log($sMessage, $LOG_LEVEL_DEBUG, $sContext)
EndFunc

Func _LogInfo($sMessage, $sContext = "")
    _Log($sMessage, $LOG_LEVEL_INFO, $sContext)
EndFunc

Func _LogWarning($sMessage, $sContext = "")
    _Log($sMessage, $LOG_LEVEL_WARNING, $sContext)
EndFunc

Func _LogError($sMessage, $sContext = "")
    _Log($sMessage, $LOG_LEVEL_ERROR, $sContext)
EndFunc

Func _LogCritical($sMessage, $sContext = "")
    _Log($sMessage, $LOG_LEVEL_CRITICAL, $sContext)
EndFunc

; Performance-Messung
Func _LogPerformanceStart($sOperationName)
    Local $iStartTime = TimerInit()
    _LogDebug("Performance-Messung gestartet: " & $sOperationName, "Performance")
    Return $iStartTime
EndFunc

Func _LogPerformanceEnd($sOperationName, $iStartTime)
    Local $iElapsedTime = TimerDiff($iStartTime)
    _LogDebug("Performance-Messung beendet: " & $sOperationName & " - Dauer: " & $iElapsedTime & " ms", "Performance")
    Return $iElapsedTime
EndFunc

; Systeminformationen protokollieren
Func _LogSystemInfo()
    _LogInfo("Betriebssystem: " & @OSVersion, "SystemInfo")
    _LogInfo("Computermodell: " & @ComputerName, "SystemInfo")
    _LogInfo("Prozessorarchitektur: " & @OSArch, "SystemInfo")
    _LogInfo("Installationspfad: " & @ScriptDir, "SystemInfo")
EndFunc

; Initialisierung am Programmstart
Func _InitDiagnosticLogging()
    ; Logging-System initialisieren
    _InitializeLogging($LOG_LEVEL_DEBUG, True, True)
    
    ; Systeminformationen protokollieren
    _LogSystemInfo()
EndFunc
