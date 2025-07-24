#include-once

; Konstanten für Logdatei-Formate
;~ Global Const $LOG_FORMAT_UNKNOWN = 0
;~ Global Const $LOG_FORMAT_TEXT = 1
;~ Global Const $LOG_FORMAT_JSON = 2
;~ Global Const $LOG_FORMAT_XML = 3
;~ Global Const $LOG_FORMAT_CSV = 4
;~ Global Const $LOG_FORMAT_CUSTOM = 99

; Konstanten für Dateierzugriffe (kopiert von log_analysis_utils.au3)
;~ Global Const $FLTAR_FILESFOLDERS = 0
;~ Global Const $FLTAR_FILES = 1
;~ Global Const $FLTAR_FOLDERS = 2
;~ Global Const $FLTAR_NOHIDDEN = 4
;~ Global Const $FLTAR_NOSYSTEM = 8
;~ Global Const $FLTAR_NOLINK = 16
;~ Global Const $FLTAR_NOARCHIVE = 32
;~ Global Const $FLTAR_NOREADONLY = 64
;~ Global Const $FLTAR_RECUR = 1
;~ Global Const $FLTAR_NORECUR = 0
;~ Global Const $FLTAR_SORT = 0
;~ Global Const $FLTAR_NOSORT = 2
;~ Global Const $FLTAR_RELPATH = 0
;~ Global Const $FLTAR_FULLPATH = 1
;~ Global Const $FLTAR_NOPATH = 2
Global Const $FLTAR_DIRNAMES = ""
;~ Global Const $FLTAR_DIRS = $FLTAR_FOLDERS

;~ ; GUI-bezogene Konstanten
;~ Global Const $GUI_MAIN_WIDTH = 1200
;~ Global Const $GUI_MAIN_HEIGHT = 700
Global Const $GUI_LOGVIEWER_WIDTH = 1000
Global Const $GUI_LOGVIEWER_HEIGHT = 700
Global Const $GUI_PROGRESS_HEIGHT = 20

; Dateierweiterungen
Global Const $FILE_EXT_LOG = "log"
Global Const $FILE_EXT_TXT = "txt"
Global Const $FILE_EXT_JSON = "json"
Global Const $FILE_EXT_XML = "xml"
Global Const $FILE_EXT_CSV = "csv"
Global Const $FILE_EXT_DB = "db"
Global Const $FILE_EXT_DB3 = "db3"
Global Const $FILE_EXT_ZIP = "zip"

; Dateimuster
Global $g_aDefaultLogPatterns = ["*.log", "*.txt", "DigiApp*.log", "DigiApp*.txt"]

; Standardpfade
Global $g_sDefaultExtractDir = @TempDir & "\diagnose-tool\extracted"

; Systemparameter
Global $g_iMaxLogEntriesToShow = 5000 ; Erhöht von 2000 auf 5000, um auch seltene/spätere Einträge zu erfassen
Global $g_iMaxFileSizeWarning = 50000000 ; 50MB