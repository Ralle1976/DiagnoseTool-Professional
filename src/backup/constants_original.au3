#include-once

; Konstanten für Dateierzugriffe - diese definieren, nicht auskommentieren
;~ Global Const $FLTAR_FILESFOLDERS = 0
;~ Global Const $FLTAR_FILES = 1
;~ Global Const $FLTAR_FOLDERS = 2
;~ Global Const $FLTAR_NOHIDDEN = 4
;~ Global Const $FLTAR_NOSYSTEM = 8
;~ Global Const $FLTAR_NOLINK = 16
Global Const $FLTAR_NOARCHIVE = 32
Global Const $FLTAR_NOREADONLY = 64
;~ Global Const $FLTAR_RECUR = 1
;~ Global Const $FLTAR_NORECUR = 0
;~ Global Const $FLTAR_SORT = 0
;~ Global Const $FLTAR_NOSORT = 2
;~ Global Const $FLTAR_RELPATH = 0
;~ Global Const $FLTAR_FULLPATH = 1
;~ Global Const $FLTAR_NOPATH = 2
;~ Global Const $FLTAR_DIRNAMES = ""
Global Const $FLTAR_DIRS = $FLTAR_FOLDERS  ; Diese fehlte und verursachte Fehler

; ListView-Konstanten, die in älteren Versionen von AutoIt fehlen könnten
Global Const $LVS_EX_AUTOARRANGE = 0x0100  ; AutoArrange-Style für ListView

; Konstanten für Log-Handling
Global Const $LOG_FORMAT_UNKNOWN = 0
Global Const $LOG_FORMAT_TEXT = 1
Global Const $LOG_FORMAT_JSON = 2
Global Const $LOG_FORMAT_JSON_GENERIC = 5  ; Neue Konstante für allgemeines JSON-Format
Global Const $LOG_FORMAT_XML = 3
Global Const $LOG_FORMAT_CSV = 4

; Konstanten für den erweiterten Parser
Global Const $LOG_FORMAT_UNIVERSAL_LOG = 10
Global Const $LOG_FORMAT_ENHANCED_LOG = 11