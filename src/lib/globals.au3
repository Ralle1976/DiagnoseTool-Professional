#include-once
#include <ListViewConstants.au3> ; Für ListView-Konstanten

; SQL-Ausführungs-Lock Variable
Global $g_bSQLExecutionInProgress = False

; Globale Variablen für Pfade
Global $g_sLastDir = @ScriptDir
Global $g_sExtractDir = @TempDir & "\diagnose-tool\extracted\"
Global $g_sevenZipPath = @ScriptDir & "\7za.exe"
Global $g_sevenZipDll = @ScriptDir & "\7za.dll"

; Globale Variablen für den Zustand
Global $g_bIsLoading = False
Global $g_sCurrentTable = ""

; ListView-Style für die Hauptansicht
Global $iExListViewStyle
;~                                 BitOR(	$LVS_EX_BORDERSELECT, _
;~                                     $LVS_EX_ONECLICKACTIVATE, _
;~                                     $LVS_EX_TRACKSELECT, _
;~                                     $LVS_EX_DOUBLEBUFFER, _
;~                                     $LVS_EX_TWOCLICKACTIVATE, _
;~                                     $LVS_EX_SUBITEMIMAGES, _
;~                                     $LVS_EX_GRIDLINES, _
;~                                     $LVS_EX_INFOTIP, _
;~                                     $LVS_EX_FULLROWSELECT, _
;~                                     $LVS_EX_LABELTIP, _
;~                                     $LVS_EX_FLATSB, _
;~                                     $LVS_AUTOARRANGE	)
                                    ;                                    $LVS_EX_CHECKBOXES, _

; Globale GUI-Variablen
Global $g_hGUI
Global $g_idListView
Global $g_idProgress
Global $g_idStatus
Global $g_idContextMenu
Global $g_idCopyCell
Global $g_idCopyRow
Global $g_idCopySelection
Global $g_idCopyWithHeaders
Global $g_idDecryptPassword

; Menü-IDs
Global $idFileExit, $idFileOpen, $idBtnOpen, $idFileDBOpen, $idBtnDBOpen
Global $idFileLogOpen, $idBtnLogOpen, $idFileLogFolder, $idBtnLogFolder
Global $idFileViewArchive, $idFileOpenExtrDir, $idBtnViewArchive, $idBtnOpenExtrDir
Global $idSettings, $idBtnRefresh, $idBtnFilter, $idBtnExport
Global $idTableCombo, $idToolLogTester, $idBtnLogParser

Global $idToolSQLEditor, $idBtnSQLEditor

; Globale Einstellungen
Global $g_sSettingsIniPath = @ScriptDir & "\settings.ini"
