; Redundante Includes entfernen, um Konflikte zu vermeiden
#include-once

; Notwendige Includes
#include "sql_editor_enhanced.au3"  ; Verbesserte Funktionen
#include "sql_improved_functions.au3" ; Verbesserte Tabellenfunktionen
#include "sql_editor_improved.au3"  ; Verbesserte SQL-Ausführung

; ===============================================================================================================================
; Func.....: _SQL_InitializeEditor
; Beschreibung: Hauptfunktion zur Initialisierung des verbesserten SQL-Editors
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_InitializeEditor($hRichEdit)
    ; Syntax-Highlighter initialisieren
    _SQL_SyntaxHighlighter_Initialize($hRichEdit)
    
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ShutdownEditor
; Beschreibung: Beendet den SQL-Editor und gibt Ressourcen frei
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ShutdownEditor()
    ; Syntax-Highlighter beenden
    _SQL_SyntaxHighlighter_Shutdown()
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_FixAndExecute
; Beschreibung: Korrigiert und führt einen SQL-Befehl aus
; Parameter.: $sSQL - SQL-Anweisung
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_FixAndExecute($sSQL)
    ; Leerzeichen korrigieren, speziell für "SELECT*FROM"-Problem
    $sSQL = _SQL_FixSelectStarSyntax($sSQL)
    
    ; Verbesserte Ausführung verwenden
    Return _SQL_ImprovedExecuteQueries($sSQL)
EndFunc
