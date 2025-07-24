#include-once
#include <File.au3>
#include <Date.au3>
#include <StringConstants.au3>
#include <Array.au3>
#include <WinAPI.au3>

; Globale Variablen für das Logging-System
Global $g_LogFile = @ScriptDir & "\diagnose.log"
Global $g_ErrorLogFile = @ScriptDir & "\error.log"
Global Enum $LOG_NONE = 0, $LOG_ERROR = 1, $LOG_INFO = 2, $LOG_DEBUG = 3
Global $g_LogLevel = $LOG_INFO
Global $g_MaxLogSize = 10 * 1024 * 1024  ; 10 MB
Global $g_MaxLogFiles = 5
Global $g_ConsoleOutput = True
Global $g_LogBuffer[0]     ; Buffer für asynchrones Logging
Global $g_LogBufferSize = 1000  ; Maximale Anzahl gepufferter Einträge

; Logging-System initialisieren
Func _LogInit($iLogLevel = $LOG_INFO, $bConsoleOutput = True)
    $g_LogLevel = $iLogLevel
    $g_ConsoleOutput = $bConsoleOutput

    ; Log-Rotation prüfen
    _LogRotate($g_LogFile)
    _LogRotate($g_ErrorLogFile)

    ; Startmeldung schreiben
    _LogInfo("=== Logging System gestartet ===")
    _LogInfo("Script: " & @ScriptName)
    _LogInfo("Version: " & FileGetVersion(@ScriptFullPath))
    _LogInfo("AutoIt Version: " & @AutoItVersion)
    _LogInfo("OS: " & @OSVersion & " " & @OSArch)
    _LogInfo("LogLevel: " & $g_LogLevel)
    Return True
EndFunc

; Log-Rotation durchführen
Func _LogRotate($sLogFile)
    If Not FileExists($sLogFile) Then Return

    ; Dateigröße prüfen
    Local $iSize = FileGetSize($sLogFile)
    If $iSize < $g_MaxLogSize Then Return

    ; Bestehende Backups umbenennen
    For $i = $g_MaxLogFiles - 1 To 1 Step -1
        Local $sOldFile = $sLogFile & "." & ($i)
        Local $sNewFile = $sLogFile & "." & ($i + 1)
        If FileExists($sOldFile) Then FileMove($sOldFile, $sNewFile, 1)
    Next

    ; Aktuelle Logdatei umbenennen
    FileMove($sLogFile, $sLogFile & ".1", 1)
EndFunc

; Internes Logging
Func _WriteLog($sType, $sMessage, $sDetails = "", $bError = False)
    ; Prüfen ob Logging aktiviert ist
    Switch $sType
        Case "ERROR"
            If $g_LogLevel < $LOG_ERROR Then Return
        Case "INFO"
            If $g_LogLevel < $LOG_INFO Then Return
        Case "DEBUG"
            If $g_LogLevel < $LOG_DEBUG Then Return
    EndSwitch

    ; Bestimmte häufig wiederholte Meldungen im SQL-Editor-Kontext filtern
    If StringInStr($sMessage, "ListView-Darstellung aktualisiert") Or _
       StringInStr($sMessage, "SQL-Ausführung: Aktualisiere ListView") Or _
       StringInStr($sMessage, "Aktualisiere ListView-Darstellung") Or _
       StringInStr($sMessage, "Führe finale ListView-Aktualisierung") Then
        ; Diese Log-Einträge unterdrücken, um Spam zu reduzieren
        Return
    EndIf

    ; Zeitstempel generieren
    Local $sDate = _NowDate()
    Local $sTime = _NowTime()
    Local $sTimestamp = $sDate & " " & $sTime

    ; Nachricht formatieren
    Local $sLogMessage = StringFormat("%-6s [%s] %s", $sType, $sTimestamp, $sMessage)
    If $sDetails <> "" Then
        $sDetails = StringReplace($sDetails, @CRLF, " | ")
        $sLogMessage &= ": " & $sDetails
    EndIf

    ; In Datei schreiben
    Local $sTargetFile = $bError ? $g_ErrorLogFile : $g_LogFile
    _FileWriteLog($sTargetFile, $sLogMessage)

    ; Konsolen-Ausgabe
    If $g_ConsoleOutput Then
        Switch $sType
            Case "ERROR"
                ConsoleWrite("! " & $sLogMessage & @CRLF)
            Case "DEBUG"
                ConsoleWrite("# " & $sLogMessage & @CRLF)
            Case Else
                ConsoleWrite("> " & $sLogMessage & @CRLF)
        EndSwitch
    EndIf
EndFunc

; Stack Trace ermitteln
Func _GetCallStack($iLevel)
    Local $aStack[2] = [@ScriptLineNumber, @ScriptName]
    Return $aStack
EndFunc

; Info-Level Logging
Func _LogInfo($sMessage, $sDetails = "")
    _WriteLog("INFO", $sMessage, $sDetails)
EndFunc

; Error-Level Logging
Func _LogError($sMessage, $sDetails = "")
    _WriteLog("ERROR", $sMessage, $sDetails, True)
EndFunc

; Debug-Level Logging
Func _LogDebug($sMessage, $sDetails = "")
    _WriteLog("DEBUG", $sMessage, $sDetails)
EndFunc

; Warning-Level Logging
Func _LogWarning($sMessage, $sDetails = "")
    _WriteLog("WARN", $sMessage, $sDetails)
EndFunc

; Stack Trace für Fehlerbehandlung
Func _LogStackTrace($sMessage = "Stack Trace:")
    Local $aCallStack = _GetCallStack(1)
    Local $sTrace = ""
    For $i = 0 To UBound($aCallStack) - 1
        $sTrace &= @CRLF & $i & ": " & $aCallStack[$i]
    Next
    _LogError($sMessage, $sTrace)
EndFunc

; Log-Puffer leeren
Func _LogFlushBuffer()
    If UBound($g_LogBuffer) = 0 Then Return

    For $aEntry In $g_LogBuffer
        _WriteLog($aEntry[0], $aEntry[1], $aEntry[2], $aEntry[3])
    Next

    ReDim $g_LogBuffer[0]
EndFunc

; Logging-System beenden
Func _LogShutdown()
    _LogFlushBuffer()
    _LogInfo("=== Logging System beendet ===")
EndFunc