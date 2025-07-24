; ===============================================================================================================================
; Titel.......: SQL verbesserte Tabellenfunktionen
; Beschreibung: Überarbeitete Funktionen zur Behandlung von Tabellen- und SQL-Ausführungsevents
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-12
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <GUIRichEdit.au3>
#include <Array.au3>
#include <GuiListView.au3>

#include "logging.au3"
#include "error_handler.au3"

; ===============================================================================================================================
; Func.....: _SQL_ImprovedTableComboChange
; Beschreibung: Verbesserte Event-Handler-Funktion für Tabellenwechsel
; Parameter.: $sTable - Der Name der ausgewählten Tabelle
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ImprovedTableComboChange($sTable)
    If $sTable = "" Then Return
    
    _LogInfo("_SQL_ImprovedTableComboChange: Tabelle gewechselt zu: " & $sTable)
    
    ; SQL-Statement erstellen mit garantierten korrekten Leerzeichen
    Local $sSQL = "SELECT * FROM " & $sTable & " LIMIT 100;"
    
    ; SQL in RichEdit setzen und Syntax-Highlighting aktualisieren
    _LogInfo("Setze neues SQL-Statement in Editor")
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
    Sleep(100) ; Kurze Pause für bessere Verarbeitung
    
    ; Anfordern eines Syntax-Highlighting-Updates
    _SQL_SyntaxHighlighter_RequestUpdate($g_hSQLRichEdit)
    
    ; Spalten für Autovervollständigung laden
    _LogInfo("Lade Tabellenspalten für Autovervollständigung")
    $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sTable)
    _LogInfo("Neue Tabellenspalten geladen: " & UBound($g_aTableColumns))
    
    ; Aktualisieren nur, wenn dies eine manuelle Aktion war, z.B. durch Dropdown-Auswahl
    ; Dies prüft, ob das Flag für explizite Ausführung aktiv ist
    If Not $g_bManualExecuteOnly And Not $g_bSQLEditorFirstLoad Then
        ; Nur anwenden, wenn ausdrücklich erlaubt (nach manueller Auswahl)
        _LogInfo("Automatische Aktualisierung nach Tabellenwechsel wird durchgeführt")
        _SQL_ImprovedExecuteQueries($sSQL)
    Else
        _LogInfo("Tabellenwechsel: Automatische Ausführung unterdrückt wegen ManualOnly=" & _
                $g_bManualExecuteOnly & ", FirstLoad=" & $g_bSQLEditorFirstLoad)
    EndIf
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ImprovedInitializeEditor
; Beschreibung: Initialisiert den verbesserten SQL-Editor
; Parameter.: $hGUI - Handle des Hauptfensters
;             $hRichEdit - Handle des RichEdit-Controls
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_ImprovedInitializeEditor($hGUI, $hRichEdit)
    ; Globale Referenzen setzen
    $g_hGUI = $hGUI
    $g_hSQLRichEdit = $hRichEdit
    
    ; Syntax-Highlighter initialisieren
    _SQL_SyntaxHighlighter_Initialize($hRichEdit)
    
    ; Beispiel-SQL-Statement mit korrekter Formatierung
    Local $sInitialSQL = "SELECT * FROM yourtable LIMIT 100;"
    _GUICtrlRichEdit_SetText($hRichEdit, $sInitialSQL)
    _SQL_SyntaxHighlighter_RequestUpdate($hRichEdit)
    
    _LogInfo("Verbesserter SQL-Editor initialisiert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ImprovedUpdateEditorText
; Beschreibung: Aktualisiert den Text im SQL-Editor mit verbessertem Syntax-Highlighting
; Parameter.: $sText - Der einzufügende Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ImprovedUpdateEditorText($sText)
    ; Sicherstellen, dass SQL-Statement korrekte Leerzeichen hat
    $sText = _SQL_FixSpacingComprehensive($sText)
    
    ; Text setzen
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sText)
    
    ; Kurze Pause für bessere UI-Verarbeitung
    Sleep(50)
    
    ; Syntax-Highlighting aktualisieren
    _SQL_SyntaxHighlighter_RequestUpdate($g_hSQLRichEdit)
    
    ; Cursor ans Ende des Textes setzen
    Local $iLen = StringLen($sText)
    _GUICtrlRichEdit_SetSel($g_hSQLRichEdit, $iLen, $iLen)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ImprovedHandleKeywordHighlighting
; Beschreibung: Verbesserte Behandlung der SQL-Syntax-Hervorhebung
; Parameter.: $hRichEdit - Handle des RichEdit-Controls
;             $sText - Der zu bearbeitende Text
; Rückgabe..: Keine
; ===============================================================================================================================
Func _SQL_ImprovedHandleKeywordHighlighting($hRichEdit, $sText)
    ; Einige Basiskorrekturen vornehmen
    $sText = _SQL_FixSpacingComprehensive($sText)
    
    ; Syntax-Highlighter direkt aufrufen
    _SQL_SyntaxHighlighter_Update($hRichEdit)
EndFunc
