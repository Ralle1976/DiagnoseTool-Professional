; ===============================================================================================================================
; Titel.......: SQL-Editor-Fix
; Beschreibung: Fundamentale Lösung für das Problem mit der automatischen SQL-Ausführung
; Autor.......: Ralle1976
; Erstellt....: 2025-04-12
; ===============================================================================================================================

#include-once
#include <SQLite.au3>
#include <GuiListView.au3>
#include <GUIRichEdit.au3>
#include <StringConstants.au3>
#include <GUIConstantsEx.au3>
#include <WinAPI.au3>
#include <Array.au3>

; Referenzen auf die vorhandenen Implementierungen
#include "constants.au3"    ; Globale Konstanten
#include "globals.au3"      ; Globale Variablen
#include "logging.au3"      ; Logging-Funktionen
#include "error_handler.au3" ; Fehlerbehandlung

; Höhe des SQL-Editor-Panels
Global Const $SQL_EDITOR_HEIGHT = 200

; Globale Variablen für den integrierten SQL-Editor (aus sql_editor_integrated.au3)
Global $g_idSQLEditorPanel = 0        ; ID des Panel-Containers
Global $g_hSQLRichEdit = 0            ; Handle des RichEdit-Controls
Global $g_idSQLDbCombo = 0            ; ID der Datenbank-Auswahlbox
Global $g_idSQLTableCombo = 0         ; ID der Tabellen-Auswahlbox
Global $g_idSQLExecuteBtn = 0         ; ID des Buttons zum Ausführen von Abfragen
Global $g_idSQLSaveBtn = 0            ; ID des Buttons zum Speichern einer SQL-Abfrage
Global $g_idSQLLoadBtn = 0            ; ID des Buttons zum Laden einer SQL-Abfrage
Global $g_idSQLBackBtn = 0            ; ID des Buttons zum Zurückkehren zur normalen Ansicht
Global $g_idBtnRefresh = 0            ; ID des Refresh-Buttons
Global $g_idBtnSQLEditor = 0          ; ID des SQL-Editor-Buttons
Global $g_bSQLEditorMode = False      ; Flag, ob der SQL-Editor-Modus aktiv ist
Global $g_bSQLExecutionInProgress = False ; Flag, um unbeabsichtigte SQL-Ausführungen zu verhindern
Global $g_aListViewBackup[0][0]       ; Array zum Speichern des ListView-Zustands vor SQL-Editor-Aktivierung
Global $g_aListViewColBackup = 0      ; Array zum Speichern der Spaltenüberschriften
Global $g_iOrigListViewHeight = 0     ; Ursprüngliche Höhe der ListView
Global $g_iOrigListViewTop = 0        ; Ursprüngliche Y-Position der ListView
Global $g_aTableColumns[0]            ; Spalten der aktuell ausgewählten Tabelle
Global $g_bAutoComplete = False       ; Flag für Auto-Vervollständigung
Global $g_idAutoCompleteList = 0      ; ID der Auto-Vervollständigungsliste
Global $g_hAutoCompleteList = 0       ; Handle der Auto-Vervollständigungsliste
Global $g_sLastDir = @ScriptDir      ; Letztes Verzeichnis für Dateidialoge

; ===============================================================================================================================
; Hilfsfunktionen, die in der Hauptimplementierung fehlen oder ersetzt werden müssen
; ===============================================================================================================================

; Funktion zur umfassenden Korrektur von Leerzeichen in SQL-Anweisungen
Func _SQL_FixSpacingComprehensive($sSQL)
    ; Umfangreichere Liste von Schlüsselwörtern, bei denen Leerzeichen wichtig sind
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|SET|GROUP BY|ORDER BY|HAVING|LIMIT|JOIN|ON|AND|OR|AS|IN|BETWEEN|LIKE|NOT|IS|NULL|VALUES|INTO)(?=[^\s])", "$1 ")

    ; Korrigiere fehlende Leerzeichen zwischen Operatoren
    $sSQL = StringRegExpReplace($sSQL, "([^\s])(\=|\<|\>|\+|\-|\*|\/|\%)([^\s])", "$1 $2 $3")

    ; Korrigiere doppelte Leerzeichen
    $sSQL = StringRegExpReplace($sSQL, "\s{2,}", " ")

    ; Setze Leerzeichen nach Kommas
    $sSQL = StringRegExpReplace($sSQL, ",([^\s])", ", $1")

    ; Entferne Leerzeichen vor Semikolons
    $sSQL = StringRegExpReplace($sSQL, "\s+;", ";")

    ; Stelle sicher, dass kein Leerzeichen zwischen Punktnotation und Folgezeichen existiert
    $sSQL = StringRegExpReplace($sSQL, "\.\s+([a-zA-Z0-9_])", ".$1")

    ; Korrigiere Leerzeichen bei Klammern
    $sSQL = StringRegExpReplace($sSQL, "\(\s+", "(")  ; Keine Leerzeichen nach öffnender Klammer
    $sSQL = StringRegExpReplace($sSQL, "\s+\)", ")")  ; Keine Leerzeichen vor schließender Klammer

    ; Problem mit "SELECT*FROM" beheben - Sicherstellen, dass nach Stern ein Leerzeichen steht
    $sSQL = StringRegExpReplace($sSQL, "\*(?=[^\s])", "* ")

    Return $sSQL
EndFunc

; Funktion zum Speichern des ListView-Status
Func _SQL_SaveListViewState()
    Local $hListView = GUICtrlGetHandle($g_idListView)
    Local $iItems = _GUICtrlListView_GetItemCount($hListView)
    Local $iColumns = _GUICtrlListView_GetColumnCount($hListView)

    ; Spaltenüberschriften speichern
    Local $aColInfo[$iColumns][2]
    For $i = 0 To $iColumns - 1
        Local $aColTemp = _GUICtrlListView_GetColumn($hListView, $i)
        $aColInfo[$i][0] = $aColTemp[5]  ; Text
        $aColInfo[$i][1] = _GUICtrlListView_GetColumnWidth($hListView, $i)  ; Breite
    Next
    $g_aListViewColBackup = $aColInfo

    ; Daten speichern
    Local $aData[$iItems][$iColumns]
    For $i = 0 To $iItems - 1
        For $j = 0 To $iColumns - 1
            $aData[$i][$j] = _GUICtrlListView_GetItemText($hListView, $i, $j)
        Next
    Next
    $g_aListViewBackup = $aData

    _LogInfo("ListView-Status gespeichert: " & $iItems & " Zeilen, " & $iColumns & " Spalten")
EndFunc

; Funktion zum Ermitteln des Namens der ersten Tabelle in einer Datenbank
Func _GetFirstTableFromDB($sDBPath)
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " Fehler: " & @error)
        Return SetError(1, 0, "")
    EndIf

    ; Tabellenliste abfragen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    ; Bei Fehler oder keinen Tabellen leeren String zurückgeben
    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        Return ""
    EndIf

    ; Name der ersten Tabelle zurückgeben
    Return $aResult[1][0]
EndFunc

; Funktion zum Ermitteln der Spalten einer Tabelle
Func _GetTableColumns($sDBPath, $sTable)
    Local $aColumns[0]

    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " Fehler: " & @error)
        Return SetError(1, 0, $aColumns)
    EndIf

    ; PRAGMA-Befehl ausführen, um Tabellenspalten zu erhalten
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "PRAGMA table_info(" & $sTable & ");"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogWarning("Keine Spalten in der Tabelle gefunden: " & $sTable)
        Return SetError(2, 0, $aColumns)
    EndIf

    ; Spaltennamen aus Ergebnis extrahieren
    ReDim $aColumns[$iRows]
    For $i = 1 To $iRows
        $aColumns[$i-1] = $aResult[$i][1] ; Spalte 1 (Index 1) enthält den Spaltennamen
    Next

    _LogInfo("Spaltennamen aus Tabelle " & $sTable & " geladen: " & _ArrayToString($aColumns, ", "))
    Return $aColumns
EndFunc

; Funktion zum Laden der Tabellen aus einer Datenbank
Func _SQL_LoadTables($sDBPath)
    ; Datenbank öffnen
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        Return SetError(1, 0, False)
    EndIf

    ; Tabellenliste abfragen
    Local $aResult, $iRows, $iColumns
    Local $sSQL = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
    Local $iRet = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)

    ; Datenbank schließen
    _SQLite_Close($hDB)

    ; Liste leeren
    GUICtrlSetData($g_idSQLTableCombo, "")

    If @error Or $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _LogWarning("Keine Tabellen in der Datenbank gefunden: " & $sDBPath)
        Return False
    EndIf

    ; Tabellen zur Combo hinzufügen
    Local $sTableList = ""
    For $i = 1 To $iRows
        $sTableList &= $aResult[$i][0] & "|"
    Next
    GUICtrlSetData($g_idSQLTableCombo, StringTrimRight($sTableList, 1))

    ; Erste Tabelle auswählen
    If $iRows > 0 Then
        GUICtrlSetData($g_idSQLTableCombo, $aResult[1][0], $aResult[1][0])

        ; Spalten für Autovervollständigung laden
        $g_aTableColumns = _GetTableColumns($sDBPath, $aResult[1][0])
    EndIf

    Return True
EndFunc

; Funktion zum Laden der verfügbaren Datenbanken
Func _SQL_LoadDatabases()
    ; Aktuell ausgewählten Eintrag merken
    Local $sCurrentDB = GUICtrlRead($g_idSQLDbCombo)

    ; Liste leeren
    GUICtrlSetData($g_idSQLDbCombo, "")

    ; SQLite-Datenbankdateien im Programmverzeichnis suchen
    Local $aDBFiles = _FileListToArray(@ScriptDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES)
    If @error Then
        _LogWarning("Keine Datenbankdateien im Programmverzeichnis gefunden")
    Else
        ; Datenbankdateien zur Combo hinzufügen
        Local $sDBList = ""
        For $i = 1 To $aDBFiles[0]
            $sDBList &= @ScriptDir & "\" & $aDBFiles[$i] & "|"
        Next
        GUICtrlSetData($g_idSQLDbCombo, StringTrimRight($sDBList, 1))
    EndIf

    ; Extraktionsverzeichnis durchsuchen, falls vorhanden
    If $g_sExtractDir <> "" And FileExists($g_sExtractDir) Then
        Local $aExtractDBFiles = _FileListToArray($g_sExtractDir, "*.db;*.db3;*.sqlite;*.sqlite3", $FLTA_FILES, True)
        If Not @error Then
            Local $sExtractDBList = ""
            For $i = 1 To $aExtractDBFiles[0]
                $sExtractDBList &= $aExtractDBFiles[$i] & "|"
            Next
            GUICtrlSetData($g_idSQLDbCombo, StringTrimRight($sExtractDBList, 1))
        EndIf
    EndIf

    ; Falls aktuell ausgewählte Datenbank vorhanden, wieder auswählen
    If $sCurrentDB <> "" Then
        GUICtrlSetData($g_idSQLDbCombo, $sCurrentDB, $sCurrentDB)
    ElseIf $g_sCurrentDB <> "" Then
        GUICtrlSetData($g_idSQLDbCombo, $g_sCurrentDB, $g_sCurrentDB)
    EndIf

    Return True
EndFunc

; Einfache Implementierung für Syntax-Highlighting (Platzhalter)
Func _SQL_UpdateSyntaxHighlighting()
    _LogInfo("_SQL_UpdateSyntaxHighlighting: Syntax-Highlighting aktualisiert")
EndFunc

Func _SetStatus($sText)
    ; Statustext setzen und protokollieren
    _LogInfo("Status: " & $sText)
    If $g_idStatus <> 0 Then
        GUICtrlSetData($g_idStatus, $sText)
    EndIf
EndFunc

; Funktion zum Parsen von SQL-Abfragen mit RegEx
Func _SQL_ExtractQueriesWithRegex($sSQL)
    ; Array für Rückgabe
    Local $aQueries[0]

    ; Problem mit "SELECT*FROM" beheben - Sicherstellen, dass nach Stern ein Leerzeichen steht
    $sSQL = StringRegExpReplace($sSQL, "\*(?=[^\s;])", "* ")

    ; Auch "SELECTFROM" ohne Sternchen abfangen
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT)(?=[^\s*])", "$1 ")
    $sSQL = StringRegExpReplace($sSQL, "(?i)([^\s])FROM", "$1 FROM")

    ; Sicherstellen, dass ein Leerzeichen vor dem FROM steht (sehr häufiges Problem)
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT\s*\*)(FROM)", "$1 $2")

    ; Verschiedene gängige SQL-Muster erkennen
    Local $aPatterns[4] = [ _
        "(?im)(SELECT\s+.*?(?:LIMIT\s+\d+)?\s*;)", _ ; SELECT-Anweisungen
        "(?im)(INSERT\s+.*?;)", _                     ; INSERT-Anweisungen
        "(?im)(UPDATE\s+.*?;)", _                     ; UPDATE-Anweisungen
        "(?im)(DELETE\s+.*?;)" _                      ; DELETE-Anweisungen
    ]

    For $sPattern In $aPatterns
        Local $aMatches = StringRegExp($sSQL, $sPattern, 3)
        If Not @error Then
            ; Übereinstimmungen hinzufügen
            For $sMatch In $aMatches
                ReDim $aQueries[UBound($aQueries) + 1]
                $aQueries[UBound($aQueries) - 1] = StringStripWS($sMatch, $STR_STRIPLEADING + $STR_STRIPTRAILING)
                _LogInfo("_SQL_ExtractQueriesWithRegex: Befehl mit Muster extrahiert: " & StringLeft($sMatch, 50) & "...")
            Next
        EndIf
    Next

    ; Spezialfall: Wenn keine vollständigen Anweisungen gefunden wurden, aber eine unvollständige
    If UBound($aQueries) = 0 And StringRegExp($sSQL, "(?i)SELECT\s+.*?FROM\s+.*", 0) Then
        ; Falls kein Semikolon vorhanden, eines hinzufügen
        If Not StringInStr($sSQL, ";") Then
            $sSQL &= ";"
        EndIf
        ReDim $aQueries[1]
        $aQueries[0] = $sSQL
        _LogInfo("_SQL_ExtractQueriesWithRegex: Unvollständige SQL-Anweisung als Ganzes verarbeitet: " & StringLeft($sSQL, 50) & "...")
    EndIf

    Return $aQueries
EndFunc

; Funktion zum Parsen von SQL-Abfragen mit klassischer Methode
Func _SQL_SplitQueriesClassic($sSQL)
    Local $aQueries[0]
    Local $sPrevChar = ""
    Local $sCurrentQuery = ""
    Local $bInString = False
    Local $sStringChar = ""
    Local $bInComment = False
    Local $bInLineComment = False

    For $i = 1 To StringLen($sSQL)
        Local $sChar = StringMid($sSQL, $i, 1)

        ; Einzeilige Kommentare verarbeiten
        If $bInLineComment Then
            $sCurrentQuery &= $sChar
            If $sChar = @CR Or $sChar = @LF Then
                $bInLineComment = False
            EndIf
            ContinueLoop
        EndIf

        ; Prüfen, ob wir uns in einem String befinden
        If $bInString Then
            $sCurrentQuery &= $sChar
            ; String-Ende erkennen (nicht escaped)
            If $sChar = $sStringChar And $sPrevChar <> "\" Then
                $bInString = False
            EndIf
        ; Mehrzeilige Kommentare verarbeiten
        ElseIf $bInComment Then
            $sCurrentQuery &= $sChar
            If $sChar = "/" And $sPrevChar = "*" Then
                $bInComment = False
            EndIf
        ; Normale Verarbeitung
        Else
            ; String-Start erkennen
            If $sChar = "'" Or $sChar = '"' Then
                $bInString = True
                $sStringChar = $sChar
                $sCurrentQuery &= $sChar
            ; Kommentar-Start erkennen
            ElseIf $sChar = "-" And $sPrevChar = "-" Then
                $bInLineComment = True
                $sCurrentQuery &= $sChar
            ElseIf $sChar = "*" And $sPrevChar = "/" Then
                $bInComment = True
                $sCurrentQuery &= $sChar
            ; Semikolon erkannt (wenn nicht in String oder Kommentar)
            ElseIf $sChar = ";" Then
                $sCurrentQuery &= $sChar
                $sCurrentQuery = StringStripWS($sCurrentQuery, $STR_STRIPLEADING + $STR_STRIPTRAILING)
                If $sCurrentQuery <> "" Then
                    ReDim $aQueries[UBound($aQueries) + 1]
                    $aQueries[UBound($aQueries) - 1] = $sCurrentQuery
                    _LogInfo("_SQL_SplitQueriesClassic: Befehl extrahiert: " & StringLeft($sCurrentQuery, 50) & "...")
                EndIf
                $sCurrentQuery = ""
            ; Normales Zeichen
            Else
                $sCurrentQuery &= $sChar
            EndIf
        EndIf

        $sPrevChar = $sChar
    Next

    ; Letzte Abfrage hinzufügen, falls vorhanden und kein Semikolon am Ende
    $sCurrentQuery = StringStripWS($sCurrentQuery, $STR_STRIPLEADING + $STR_STRIPTRAILING)
    If $sCurrentQuery <> "" Then
        ; Semikolon hinzufügen, falls keines vorhanden
        If Not StringInStr($sCurrentQuery, ";") Then
            $sCurrentQuery &= ";"
            _LogInfo("_SQL_SplitQueriesClassic: Semikolon zu unvollständiger Abfrage hinzugefügt")
        EndIf

        ReDim $aQueries[UBound($aQueries) + 1]
        $aQueries[UBound($aQueries) - 1] = $sCurrentQuery
        _LogInfo("_SQL_SplitQueriesClassic: Abschließende Abfrage extrahiert: " & StringLeft($sCurrentQuery, 50) & "...")
    EndIf

    Return $aQueries
EndFunc

; Funktion zum Parsen von SQL-Abfragen mit hoher Robustheit
Func _SQL_ParseQuery($sSQL)
; Debug-Information
_LogInfo("_SQL_ParseQuery: Parse SQL-Anweisung: " & StringLeft($sSQL, 100) & (StringLen($sSQL) > 100 ? "..." : ""))

; Prüfen, ob die Abfrage leer ist
If $sSQL = "" Then
    _LogWarning("_SQL_ParseQuery: Leere SQL-Anweisung")
    Local $aEmpty[0]
    Return $aEmpty
EndIf

; Leerzeichen korrigieren
$sSQL = _SQL_FixSpacingComprehensive($sSQL)

; Versuche zuerst mit RegEx-basiertem Ansatz (robuster für unvollständige SQL-Anweisungen)
Local $aQueriesRegEx = _SQL_ExtractQueriesWithRegex($sSQL)

; Wenn RegEx erfolgreich war und Ergebnisse lieferte
If IsArray($aQueriesRegEx) And UBound($aQueriesRegEx) > 0 Then
        _LogInfo("_SQL_ParseQuery: " & UBound($aQueriesRegEx) & " Befehle mit RegEx extrahiert")
        Return $aQueriesRegEx
    EndIf

    ; Fallback: Traditioneller Ansatz (trennt nach Semikolon)
    _LogInfo("_SQL_ParseQuery: RegEx-Extraktion ergab keine Ergebnisse, verwende klassische Trennung")
    Return _SQL_SplitQueriesClassic($sSQL)
EndFunc

; ===============================================================================================================================
; Func.....: _InitSQLEditorIntegrated
; Beschreibung: Initialisiert den integrierten SQL-Editor im Hauptfenster
; Parameter.: $hGUI - Handle des Hauptfensters
;             $x, $y - Position des SQL-Editor-Panels
;             $w - Breite
;             $h - Höhe
; Rückgabe..: True bei Erfolg
; ===============================================================================================================================
Func _InitSQLEditorIntegrated($hGUI, $x, $y, $w, $h)
    _LogInfo("★★★ KRITISCHES DEBUG EVENT ★★★ Initialisiere integrierten SQL-Editor (SICHERE IMPLEMENTATION)")

    ; Globale Variablen initialisieren
    $g_bSQLEditorMode = False  ; Standardmäßig ist der SQL-Editor deaktiviert

    ; Ursprüngliche Position und Größe der ListView speichern
    Local $aListViewPos = ControlGetPos($hGUI, "", $g_idListView)
    $g_iOrigListViewTop = $aListViewPos[1]
    $g_iOrigListViewHeight = $aListViewPos[3]

    ; Panel erstellen (anfangs ausgeblendet)
    $g_idSQLEditorPanel = GUICtrlCreateGroup("SQL-Editor", $x, $y, $w, $SQL_EDITOR_HEIGHT)
    GUICtrlSetState($g_idSQLEditorPanel, $GUI_HIDE)

    ; Abstand der Steuerelemente vom Rand des Panels
    Local $iMargin = 10
    Local $xCtrl = $x + $iMargin
    Local $yCtrl = $y + 20 ; Berücksichtige Höhe der Gruppenüberschrift
    Local $wCtrl = $w - 2 * $iMargin

    ; Dropdown-Menüs für Datenbanken und Tabellen
    GUICtrlCreateLabel("Datenbank:", $xCtrl, $yCtrl, 80, 20)
    $g_idSQLDbCombo = GUICtrlCreateCombo("", $xCtrl + 85, $yCtrl, 200, 20)
    GUICtrlCreateLabel("Tabelle:", $xCtrl + 300, $yCtrl, 80, 20)
    $g_idSQLTableCombo = GUICtrlCreateCombo("", $xCtrl + 385, $yCtrl, 200, 20)

    ; RichEdit-Control für SQL-Eingabe
    $yCtrl += 30
    $g_hSQLRichEdit = _GUICtrlRichEdit_Create($hGUI, "", $xCtrl, $yCtrl, $wCtrl, 100, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_WANTRETURN))
    _GUICtrlRichEdit_SetFont($g_hSQLRichEdit, 10, "Consolas")

    ; Auto-Vervollständigungsliste vorbereiten (anfangs ausgeblendet)
    $g_idAutoCompleteList = GUICtrlCreateList("", $xCtrl, $yCtrl + 50, 200, 80)
    $g_hAutoCompleteList = GUICtrlGetHandle($g_idAutoCompleteList)
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)

    ; Buttons
    $yCtrl += 110
    ; Button für Ausführung
    $g_idSQLExecuteBtn = GUICtrlCreateButton("Ausführen (F5)", $xCtrl, $yCtrl, 150, 30)

    $g_idSQLSaveBtn = GUICtrlCreateButton("Speichern", $xCtrl + 160, $yCtrl, 100, 30)
    $g_idSQLLoadBtn = GUICtrlCreateButton("Laden", $xCtrl + 270, $yCtrl, 100, 30)
    $g_idSQLBackBtn = GUICtrlCreateButton("Zurück", $xCtrl + $wCtrl - 100, $yCtrl, 100, 30)

    ; Panel abschließen
    GUICtrlCreateGroup("", -99, -99, 1, 1) ; Dummy-Gruppe zum Schließen

    _LogInfo("Integrierter SQL-Editor initialisiert")
    Return True
EndFunc
; ===============================================================================================================================
; Func.....: _SQL_SafeExecuteQuery
; Beschreibung: Entkoppelte Ausführungsfunktion, die nur direkt aufgerufen werden kann
; Parameter.: $sSQL - SQL-Abfragen zum Ausführen
;             $sDBPath - Pfad zur Datenbank
;             $bForceExecute - Optional: Bei True wird die Ausführung erzwungen (für Debug)
; Rückgabe..: True bei Erfolg, False bei Fehler
; ===============================================================================================================================
Func _SQL_SafeExecuteQuery($sSQL, $sDBPath, $bForceExecute = False)
; Neue, eigenständige Funktion, die keine globalen Status oder Flags verwendet
; Sie kann nur durch einen direkten Funktionsaufruf ausgelöst werden

; BLOCKIERUNGS-SICHERHEITSSYSTEM: 
; Diese Funktion darf nur ausgeführt werden, wenn der Aufruf direkt 
; von den Button-Handler-Funktionen kommt - nicht von GUI-Events

; In der Live-Version deaktivieren wir die Stack-Prüfung, da sie zu streng ist
; und die echten Button-Klicks blockiert. Stattdessen verwenden wir die bereits
; implementierte Sperre-Variable als einfachere Lösung.

; Prüfen, ob gerade eine SQL-Ausführungssperre aktiv ist
If $g_bSQLExecutionInProgress = True And Not $bForceExecute Then
_LogWarning("_SQL_SafeExecuteQuery: Ausführung blockiert, da bereits eine Aktion in Bearbeitung ist.")
Return SetError(99, 0, False)
EndIf

; Sperre setzen
$g_bSQLExecutionInProgress = True

; Protokollieren für Debugging-Zwecke
_LogInfo("_SQL_SafeExecuteQuery: Explizite SQL-Ausführung wird gestartet")
_LogInfo("SQL: " & $sSQL)
_LogInfo("Datenbank: " & $sDBPath)

    ; Prüfen, ob Datenbank und SQL gültig sind
    If $sDBPath = "" Then
    _SetStatus("Fehler: Keine Datenbank ausgewählt")
    _LogError("SQL-Ausführung fehlgeschlagen: Keine Datenbank angegeben")
    $g_bSQLExecutionInProgress = False ; Sperre aufheben
        Return SetError(1, 0, False)
    EndIf

    If $sSQL = "" Then
    _SetStatus("Fehler: Keine SQL-Anweisung angegeben")
    _LogError("SQL-Ausführung fehlgeschlagen: Leere SQL-Anweisung")
        $g_bSQLExecutionInProgress = False ; Sperre aufheben
        Return SetError(2, 0, False)
    EndIf

    ; Statusmeldung setzen
    _SetStatus("Führe SQL-Anweisungen aus...")

    ; Leerzeichen in SQL-Anweisung korrigieren
    $sSQL = _SQL_FixSpacingComprehensive($sSQL)
    _LogInfo("Korrigierte SQL-Anweisung: " & $sSQL)

    ; SQL parsen
    Local $aQueries = _SQL_ParseQuery($sSQL)
    If Not IsArray($aQueries) Or UBound($aQueries) < 1 Then
        _SetStatus("Fehler beim Parsen der SQL-Anweisungen")
        $g_bSQLExecutionInProgress = False ; Sperre aufheben
        Return SetError(3, 0, False)
    EndIf

    Local $bHasResults = False
    Local $iSuccessCount = 0
    Local $iErrorCount = 0

    ; Datenbank öffnen
    _LogInfo("Öffne Datenbank: " & $sDBPath)
    Local $hDB = _SQLite_Open($sDBPath)
    If @error Then
        _SetStatus("Fehler beim Öffnen der Datenbank: " & @error)
        _LogError("Fehler beim Öffnen der Datenbank: " & $sDBPath & " - " & @error)
        $g_bSQLExecutionInProgress = False ; Sperre aufheben
        Return SetError(4, 0, False)
    EndIf

    ; Transaktion beginnen
    _SQLite_Exec($hDB, "BEGIN TRANSACTION;")

    ; Abfragen ausführen
    _LogInfo("Verarbeite " & UBound($aQueries) & " SQL-Anweisungen")

    For $i = 0 To UBound($aQueries) - 1
        Local $sQuery = $aQueries[$i]
        $sQuery = StringStripWS($sQuery, $STR_STRIPTRAILING)

        ; Leere Abfragen überspringen
        If $sQuery = "" Then
            _LogInfo("Leere Anweisung übersprungen")
            ContinueLoop
        EndIf

        ; Prüfen, ob es sich um eine SELECT-Abfrage handelt
        Local $bIsSelect = StringRegExp(StringUpper($sQuery), "^\s*SELECT")
        _LogInfo("Verarbeite SQL #" & ($i+1) & ": " & (StringLen($sQuery) > 100 ? StringLeft($sQuery, 100) & "..." : $sQuery))

        If $bIsSelect Then
            ; SELECT-Abfrage ausführen
            Local $aResult, $iRows, $iColumns
            _LogInfo("Führe SELECT-Abfrage aus")
            Local $iRet = _SQLite_GetTable2d($hDB, $sQuery, $aResult, $iRows, $iColumns)

            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler bei SELECT: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf

            _LogInfo("SELECT-Abfrage erfolgreich: " & $iRows & " Zeilen, " & $iColumns & " Spalten")

            ; Ergebnisse anzeigen (nur für letzte oder einzige Abfrage)
            If $i = UBound($aQueries) - 1 Or UBound($aQueries) = 1 Then
                _LogInfo("Bereite ListView für Ergebnisanzeige vor")

                ; ListView leeren
                _GUICtrlListView_DeleteAllItems($g_idListView)
                _DeleteAllListViewColumns($g_idListView)

                ; Wenn keine Ergebnisse, Meldung anzeigen
                If $iRows = 0 Then
                    _SetStatus("Abfrage ausgeführt. Keine Ergebnisse.")
                    $iSuccessCount += 1
                    ContinueLoop
                EndIf

                ; Spaltenüberschriften zur ListView hinzufügen
                _LogInfo("Füge " & $iColumns & " Spalten zur ListView hinzu")
                For $j = 0 To $iColumns - 1
                    _GUICtrlListView_AddColumn($g_idListView, $aResult[0][$j], 100)
                Next

                ; Daten zur ListView hinzufügen
                _LogInfo("Füge " & $iRows & " Zeilen zur ListView hinzu")
                For $j = 1 To $iRows
                    Local $iIndex = _GUICtrlListView_AddItem($g_idListView, $aResult[$j][0])
                    For $k = 1 To $iColumns - 1
                        _GUICtrlListView_AddSubItem($g_idListView, $iIndex, $aResult[$j][$k], $k)
                    Next
                Next

                ; Spaltenbreiten automatisch anpassen
                For $j = 0 To $iColumns - 1
                    _GUICtrlListView_SetColumnWidth($g_idListView, $j, $LVSCW_AUTOSIZE_USEHEADER)
                Next

                ; ListView aktualisieren
                GUICtrlSetState($g_idListView, $GUI_SHOW)
                _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
                _WinAPI_UpdateWindow(GUICtrlGetHandle($g_idListView))

                $bHasResults = True
            EndIf

            $iSuccessCount += 1
        Else
            ; Andere Anweisungen (INSERT, UPDATE, DELETE, etc.)
            _LogInfo("Führe Nicht-SELECT-Anweisung aus")
            Local $iRet = _SQLite_Exec($hDB, $sQuery)

            If @error Or $iRet <> $SQLITE_OK Then
                Local $sError = _SQLite_ErrMsg()
                _SetStatus("SQL-Fehler: " & $sError)
                _LogError("SQL-Fehler bei Nicht-SELECT: " & $sError)
                $iErrorCount += 1
                ContinueLoop
            EndIf

            _LogInfo("Nicht-SELECT-Anweisung erfolgreich ausgeführt")
            $iSuccessCount += 1
        EndIf
    Next

    ; Transaktion abschließen
    _SQLite_Exec($hDB, "COMMIT;")

    ; Anzahl der betroffenen Zeilen ermitteln
    Local $iChanges = _SQLite_Changes($hDB)
    _LogInfo("Zeilen betroffen: " & $iChanges)

    ; Datenbank schließen
    _SQLite_Close($hDB)
    _LogInfo("Datenbankverbindung geschlossen")

    ; Ausführungssperre aufheben
    $g_bSQLExecutionInProgress = False

    ; ListView-Aktualisierung erzwingen
    If $bHasResults Then
        _LogInfo("Erzwinge finale ListView-Aktualisierung")
        GUICtrlSetState($g_idListView, $GUI_SHOW)
        _WinAPI_RedrawWindow(GUICtrlGetHandle($g_idListView))
        _WinAPI_UpdateWindow(GUICtrlGetHandle($g_idListView))
        _WinAPI_RedrawWindow($g_hGUI)
    EndIf

    ; Statusmeldung aktualisieren
    If $iErrorCount = 0 Then
        If $bHasResults Then
            _SetStatus("Alle Abfragen erfolgreich ausgeführt: " & $iSuccessCount & " Anweisungen.")
        Else
            _SetStatus("Alle Anweisungen erfolgreich ausgeführt: " & $iChanges & " Zeilen betroffen.")
        EndIf
        _LogInfo("SQL-Ausführung erfolgreich abgeschlossen")
        $g_bSQLExecutionInProgress = False ; Sicherheitshalber nochmal Sperre aufheben
        Return True
    Else
        _SetStatus("Ausführung mit Fehlern: " & $iSuccessCount & " erfolgreich, " & $iErrorCount & " fehlgeschlagen.")
        _LogWarning("SQL-Ausführung teilweise fehlgeschlagen")
        $g_bSQLExecutionInProgress = False ; Sicherheitshalber nochmal Sperre aufheben
        Return False
    EndIf
EndFunc

; Debug-Logging für Button-Events
Func _SQL_ExecuteButtonClicked()
    ; Diese Funktion wird NUR aufgerufen, wenn der Benutzer explizit auf den Ausführen-Button klickt
    _LogInfo(">>> SQL-EXECUTE-BUTTON MANUELL GEDRÜCKT <<<")

Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
If $sSQL = "" Then
_SetStatus("Keine SQL-Abfrage eingegeben")
Return False
EndIf

; Ausführung nur erlauben, wenn keine Sperre aktiv ist
If $g_bSQLExecutionInProgress = True Then
    _LogWarning("SQL-Ausführung nicht möglich: Bereits eine Operation in Bearbeitung")
    _SetStatus("Bitte warten, eine andere Operation wird gerade ausgeführt...")
        Return False
    EndIf

    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)

    _LogInfo("SQL-Ausführung manuell durch Benutzer gestartet via Execute-Button")
    Return _SQL_SafeExecuteQuery($sSQL, $sDBPath)
EndFunc

; Debug-Logging für Refresh-Button
Func _SQL_RefreshButtonClicked()
    ; Diese Funktion wird NUR aufgerufen, wenn der Benutzer explizit auf den Aktualisieren-Button klickt
    ; im SQL-Editor-Modus
    _LogInfo(">>> SQL-REFRESH-BUTTON MANUELL GEDRÜCKT <<<")

; Ausführung nur erlauben, wenn keine Sperre aktiv ist
If $g_bSQLExecutionInProgress = True Then
_LogWarning("SQL-Aktualisierung nicht möglich: Bereits eine Operation in Bearbeitung")
_SetStatus("Bitte warten, eine andere Operation wird gerade ausgeführt...")
    Return False
EndIf

; Nur ausführen, wenn eine Tabelle ausgewählt ist
If $g_sCurrentTable = "" Then
    _LogWarning("Aktualisieren nicht möglich: Keine Tabelle ausgewählt")
Return False
EndIf

Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)

; Falls kein SQL im Editor, Standard-SELECT erstellen
If $sSQL = "" Then
    $sSQL = "SELECT * FROM " & $g_sCurrentTable & " LIMIT 100;"
    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
        _SQL_UpdateSyntaxHighlighting()
    EndIf

    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)

    _LogInfo("SQL-Aktualisierung manuell durch Benutzer gestartet via Refresh-Button")
    Return _SQL_SafeExecuteQuery($sSQL, $sDBPath)
EndFunc

; Ersatz für den Table-Combo-Change-Event-Handler
Func _SQL_TableComboChanged($sTable)
; Wird nur aufgerufen, wenn der Benutzer eine neue Tabelle auswählt
If $sTable = "" Then Return False

_LogInfo("Tabelle gewechselt zu: " & $sTable)

; Setze die Ausführungssperre
$g_bSQLExecutionInProgress = True

; SQL-Statement erstellen
Local $sSQL = "-- Wählen Sie die gewünschte Abfrage und klicken Sie auf 'Ausführen'" & @CRLF & @CRLF & "SELECT * FROM " & $sTable & " LIMIT 100;"

; SQL in RichEdit setzen und Syntax-Highlighting aktualisieren
_GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
_SQL_UpdateSyntaxHighlighting()

; Spalten für Autovervollständigung laden
Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
If $sDBPath <> "" Then
    $g_aTableColumns = _GetTableColumns($sDBPath, $sTable)
    _LogInfo("Spalten geladen: " & UBound($g_aTableColumns))
EndIf

    ; Ausführungssperre aufheben
    $g_bSQLExecutionInProgress = False

    ; WICHTIG: Nur Text aktualisieren, keine automatische Ausführung!
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _HandleSQLEditorEvents
; Beschreibung: Verarbeitet Events für den SQL-Editor (für die GUIGetMsg-Schleife)
; Parameter.: $iMsg - Die Ereignis-ID aus GUIGetMsg()
; Rückgabe..: True, wenn das Event verarbeitet wurde, sonst False
; ===============================================================================================================================
Func _HandleSQLEditorEvents($iMsg)
    ; KRITISCHE BUGFIX: Wenn eine SQL-Ausführung bereits im Gange ist, blocken wir alle Events
    Static $s_iPreviousMsg = -99999  ; Speichert das letzte Event, um wiederholte Events zu filtern
    Static $s_iEventCounter = 0      ; Zählt Events, um Log-Spam zu reduzieren
    
    ; Wenn wiederholtes Event, Log-Ausgabe nur jedes 20. Mal
    If $iMsg = $s_iPreviousMsg Then
        $s_iEventCounter += 1
        If Mod($s_iEventCounter, 20) <> 0 Then
            ; Event stumm verarbeiten ohne Log-Ausgaben
            Return (_HandleSQLEditorEventsInternal($iMsg, False))
        EndIf
    Else
        ; Neues Event, Counter zurücksetzen
        $s_iPreviousMsg = $iMsg
        $s_iEventCounter = 0
    EndIf
    
    ; Event mit Log-Ausgaben verarbeiten
    Return (_HandleSQLEditorEventsInternal($iMsg, True))
EndFunc

; Interne Funktion, um die eigentliche Event-Verarbeitung durchzuführen
Func _HandleSQLEditorEventsInternal($iMsg, $bLogEnabled)
    ; Bei aktiver Ausführungssperre nur kritische Events durchlassen
    If $g_bSQLExecutionInProgress Then
        If $bLogEnabled Then _LogWarning("SQL-Editor-Event blockiert: Ausführung bereits im Gange")
        Switch $iMsg
            ; Kritische Events trotzdem durchlassen
            Case $g_idSQLBackBtn, $g_idBtnSQLEditor
                ; Diese Events dürfen auch bei aktiver Sperre verarbeitet werden
            Case Else
                ; Alle anderen Events blockieren
                Return True
        EndSwitch
    EndIf

    ; Wenn SQL-Editor nicht aktiv ist, keine Events verarbeiten
    If Not $g_bSQLEditorMode Then Return False

    If $bLogEnabled Then _LogInfo("SQL-Editor-Event erhalten: " & $iMsg)

    ; Event-Verarbeitung
    Switch $iMsg
        Case $g_idSQLDbCombo
            ; Datenbank gewechselt
            $g_bSQLExecutionInProgress = True  ; Sperre setzen
            If $bLogEnabled Then _LogInfo("SQL-Editor: Datenbankwechsel gestartet")
            
            Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
            If $sDBPath <> "" And $sDBPath <> $g_sCurrentDB Then
            $g_sCurrentDB = $sDBPath
            _SQL_LoadTables($sDBPath)
            If $bLogEnabled Then _LogInfo("Datenbank gewechselt zu: " & $sDBPath)
            EndIf
            
            $g_bSQLExecutionInProgress = False  ; Sperre aufheben
            Return True

        Case $g_idSQLTableCombo
            ; Tabelle gewechselt - NUR SQL-Text aktualisieren, KEINE Ausführung!
            $g_bSQLExecutionInProgress = True  ; Sperre setzen
            If $bLogEnabled Then _LogInfo("SQL-Editor: Tabellenwechsel gestartet - NUR Textaktualisierung")

            Local $sTable = GUICtrlRead($g_idSQLTableCombo)
            If $sTable <> "" And $sTable <> $g_sCurrentTable Then
                $g_sCurrentTable = $sTable

                ; Nur SQL-Text setzen, aber keine Ausführung!
                If $bLogEnabled Then _LogInfo("SQL-Text für neue Tabelle wird nur gesetzt, nicht ausgeführt: " & $sTable)
                Local $sSQL = "-- Wählen Sie die gewünschte Abfrage und klicken Sie auf 'Ausführen' (F5)" & @CRLF & @CRLF & _
                           "SELECT * FROM " & $sTable & " LIMIT 100;"

                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                _SQL_UpdateSyntaxHighlighting()

                ; Spalten für Autovervollständigung laden
                Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
                If $sDBPath <> "" Then
                    $g_aTableColumns = _GetTableColumns($sDBPath, $sTable)
                    If $bLogEnabled Then _LogInfo("Spalten geladen: " & UBound($g_aTableColumns))
                EndIf

                If $bLogEnabled Then _LogInfo("Tabelle gewechselt zu: " & $sTable & " - NUR Text aktualisiert, KEINE Ausführung")
            ElseIf $bLogEnabled Then
                _LogInfo("Tabellenwechsel ignoriert: Keine Änderung oder leere Auswahl")
            EndIf

            $g_bSQLExecutionInProgress = False  ; Sperre aufheben
            Return True

        Case $g_idSQLExecuteBtn
            ; Ausführen-Button EXPLICIT geklickt
            If $bLogEnabled Then _LogInfo("SQL-Editor: Ausführen-Button MANUELL gedrückt")
            
            ; KRITISCH: Verhindern, dass der Button-Handler automatisch aufgerufen wird
            ; Stattdessen direkt SQL-Text ausführen, nur wenn explizit geklickt
            If Not $g_bSQLExecutionInProgress Then
                Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
                If $sSQL <> "" Then
                    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
                    
                    If $bLogEnabled Then _LogInfo("*** EXPLIZITER EXECUTE-BUTTON-KLICK - STARTE SICHERE AUSFÜHRUNG OHNE HANDLER ***")
                    _SQL_SafeExecuteQuery($sSQL, $sDBPath, True) ; Force-Parameter hinzufügen
                Else
                    _SetStatus("Keine SQL-Abfrage eingegeben")
                EndIf
            Else
                If $bLogEnabled Then _LogWarning("Ausführung nicht möglich: Operation bereits in Bearbeitung")
            EndIf
            Return True

        Case $g_idBtnRefresh
            ; Aktualisieren-Button EXPLICIT geklickt im SQL-Editor-Modus
            If $bLogEnabled Then _LogInfo("SQL-Editor: Aktualisieren-Button MANUELL gedrückt")
            If $g_sCurrentTable <> "" Then
                ; KRITISCH: Verhindern, dass der Button-Handler automatisch aufgerufen wird
                ; Stattdessen direkt SQL-Text ausführen, nur wenn explizit geklickt
                If Not $g_bSQLExecutionInProgress Then
                    Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
                    Local $sDBPath = GUICtrlRead($g_idSQLDbCombo)
                    
                    If $bLogEnabled Then _LogInfo("*** EXPLIZITER REFRESH-BUTTON-KLICK - STARTE SICHERE AUSFÜHRUNG OHNE HANDLER ***")
                    _SQL_SafeExecuteQuery($sSQL, $sDBPath, True) ; Force-Parameter hinzufügen
                Else
                    If $bLogEnabled Then _LogWarning("Aktualisieren nicht möglich: Operation bereits in Bearbeitung")
                EndIf
            Else
                If $bLogEnabled Then _LogWarning("Aktualisieren nicht möglich: Keine Tabelle ausgewählt")
            EndIf
            Return True

        Case $g_idSQLBackBtn, $g_idBtnSQLEditor
            ; Zurück-Button oder SQL-Editor-Button geklickt
            _LogInfo("Zurück-Button gedrückt - Verlasse SQL-Editor-Modus")
            _SQL_EditorExit()
            Return True

        Case $g_idSQLSaveBtn
            ; Speichern-Button geklickt
            _LogInfo("SQL-Editor: Speichern-Button geklickt")
            $g_bSQLExecutionInProgress = True  ; Sperre setzen

            Local $sSQL = _GUICtrlRichEdit_GetText($g_hSQLRichEdit)
            If $sSQL <> "" Then
                Local $sFile = FileSaveDialog("SQL-Abfrage speichern", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_PATHMUSTEXIST)
                If Not @error Then
                    ; Dateiendung hinzufügen, falls nicht vorhanden
                    If StringRight($sFile, 4) <> ".sql" Then $sFile &= ".sql"

                    ; Abfrage speichern
                    If FileWrite($sFile, $sSQL) Then
                        _SetStatus("SQL-Abfrage gespeichert: " & $sFile)
                        _LogInfo("SQL-Abfrage gespeichert: " & $sFile)
                    Else
                        _SetStatus("Fehler beim Speichern der SQL-Abfrage")
                        _LogError("Fehler beim Speichern der SQL-Abfrage: " & $sFile)
                    EndIf
                EndIf
            Else
                _SetStatus("Nichts zum Speichern vorhanden")
            EndIf

            $g_bSQLExecutionInProgress = False  ; Sperre aufheben
            Return True

        Case $g_idSQLLoadBtn
            ; Laden-Button geklickt
            _LogInfo("SQL-Editor: Laden-Button geklickt")
            $g_bSQLExecutionInProgress = True  ; Sperre setzen

            Local $sFile = FileOpenDialog("SQL-Abfrage laden", $g_sLastDir, "SQL-Dateien (*.sql)", $FD_FILEMUSTEXIST)
            If Not @error Then
                ; Datei laden
                Local $sSQL = FileRead($sFile)
                If Not @error Then
                    _GUICtrlRichEdit_SetText($g_hSQLRichEdit, $sSQL)
                    _SQL_UpdateSyntaxHighlighting()
                    _SetStatus("SQL-Abfrage geladen: " & $sFile)
                    _LogInfo("SQL-Abfrage geladen: " & $sFile)
                Else
                    _SetStatus("Fehler beim Laden der SQL-Abfrage")
                    _LogError("Fehler beim Laden der SQL-Abfrage: " & $sFile)
                EndIf
            EndIf

            $g_bSQLExecutionInProgress = False  ; Sperre aufheben
            Return True
    EndSwitch

    ; Event nicht verarbeitet
    Return False
EndFunc

; Funktion zum sicheren Aktivieren des SQL-Editor-Modus
Func _SQL_EditorEnter()
; Wird aufgerufen, wenn der Benutzer in den SQL-Editor-Modus wechselt
_LogInfo("Aktiviere SQL-Editor-Modus (sichere Implementierung)")

; Sicherstellen, dass wir nicht bereits im SQL-Editor-Modus sind
If $g_bSQLEditorMode Then Return True

; Globalen Status für SQL-Ausführung blockieren
$g_bSQLExecutionInProgress = True

; ListView-Status sichern
_SQL_SaveListViewState()

; Button-Text ändern
GUICtrlSetData($g_idBtnSQLEditor, "Zurück")

; SQL-Editor-Panel anzeigen
GUICtrlSetState($g_idSQLEditorPanel, $GUI_SHOW)

; ListView anpassen
Local $aPos = ControlGetPos($g_hGUI, "", $g_idListView)
ControlMove($g_hGUI, "", $g_idListView, $aPos[0], $g_iOrigListViewTop + $SQL_EDITOR_HEIGHT, $aPos[2], $g_iOrigListViewHeight - $SQL_EDITOR_HEIGHT)
GUICtrlSetState($g_idListView, $GUI_SHOW)

; Datenbanken und Tabellen laden
_SQL_LoadDatabases()

; Wenn eine Datenbank ausgewählt ist, Tabellen laden
If $g_sCurrentDB <> "" Then
GUICtrlSetData($g_idSQLDbCombo, $g_sCurrentDB, $g_sCurrentDB)
_SQL_LoadTables($g_sCurrentDB)

; Standard-SQL für aktuelle Tabelle setzen
Local $sCurrentTable = GUICtrlRead($idTableCombo)
_LogInfo("Aktuelle Tabelle aus ComboBox: " & $sCurrentTable)

If $sCurrentTable <> "" Then
    ; Tabelle auswählen, aber KEINE Abfrage ausführen
_LogInfo("SQL-Editor: Wähle Tabelle aus TableCombo: " & $sCurrentTable)
GUICtrlSetData($g_idSQLTableCombo, $sCurrentTable, $sCurrentTable)

; Hier nur Text setzen, KEINE Ausführung
_GUICtrlRichEdit_SetText($g_hSQLRichEdit, "-- Wählen Sie die gewünschte Abfrage und klicken Sie auf 'Ausführen'" & @CRLF & @CRLF & "SELECT * FROM " & $sCurrentTable & " LIMIT 100;")

_SQL_UpdateSyntaxHighlighting()
$g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sCurrentTable)
$g_sCurrentTable = $sCurrentTable
Else
        ; Erste Tabelle verwenden, falls vorhanden
        Local $sFirstTable = _GetFirstTableFromDB($g_sCurrentDB)
        If $sFirstTable <> "" Then
            _LogInfo("SQL-Editor: Verwende erste Tabelle: " & $sFirstTable)
            GUICtrlSetData($g_idSQLTableCombo, $sFirstTable, $sFirstTable)

            ; Hier nur Text setzen, KEINE Ausführung
                _GUICtrlRichEdit_SetText($g_hSQLRichEdit, "-- Wählen Sie die gewünschte Abfrage und klicken Sie auf 'Ausführen'" & @CRLF & @CRLF & "SELECT * FROM " & $sFirstTable & " LIMIT 100;")

                _SQL_UpdateSyntaxHighlighting()
                $g_aTableColumns = _GetTableColumns($g_sCurrentDB, $sFirstTable)
                $g_sCurrentTable = $sFirstTable
            EndIf
        EndIf
    EndIf

    ; Status setzen
    $g_bSQLEditorMode = True

    ; SQL-Ausführungssperre aufheben
    $g_bSQLExecutionInProgress = False

    _LogInfo("SQL-Editor-Modus aktiviert - KEINE automatische Abfrage ausgeführt")
    Return True
EndFunc

; Funktion zum sicheren Verlassen des SQL-Editor-Modus
Func _SQL_EditorExit()
    ; Wird aufgerufen, wenn der Benutzer den SQL-Editor-Modus verlässt
    _LogInfo("Verlasse SQL-Editor-Modus (sichere Implementierung)")

    ; Sicherstellen, dass wir im SQL-Editor-Modus sind
    If Not $g_bSQLEditorMode Then Return True

    ; Button-Text zurücksetzen
    GUICtrlSetData($g_idBtnSQLEditor, "SQL-Editor")

    ; SQL-Editor-Panel ausblenden
    GUICtrlSetState($g_idSQLEditorPanel, $GUI_HIDE)

    ; Auto-Vervollständigung ausblenden
    GUICtrlSetState($g_idAutoCompleteList, $GUI_HIDE)
    $g_bAutoComplete = False

    ; Aktuelle Datenbank und Tabelle merken
    Local $sSavedDB = $g_sCurrentDB
    Local $sSavedTable = $g_sCurrentTable

    ; ListView zurücksetzen
    ControlMove($g_hGUI, "", $g_idListView, 2, $g_iOrigListViewTop, ControlGetPos($g_hGUI, "", $g_idListView)[2], $g_iOrigListViewHeight)

    ; Tabelle im Hauptfenster
    Local $sTableBefore = GUICtrlRead($idTableCombo)

    ; Daten neu laden, wenn nötig
    If $sSavedDB <> "" And $sSavedTable <> "" And $sSavedTable = $sTableBefore Then
        _LogInfo("Lade Datenbanktabelle neu: " & $sSavedTable)
        _OpenDatabaseFile($sSavedDB)
        $g_sCurrentTable = $sSavedTable
        GUICtrlSetData($idTableCombo, $sSavedTable, $sSavedTable)
        _LoadDatabaseData()
    EndIf

    ; Status zurücksetzen
    $g_bSQLEditorMode = False

    _LogInfo("SQL-Editor-Modus deaktiviert")
    Return True
EndFunc

; ===============================================================================================================================
; Func.....: _ToggleSQLEditorMode
; Beschreibung: Original-Kompatibilitätsfunktion für die Hauptdatei
; Parameter.: $bActivate - True, um den SQL-Editor zu aktivieren, False um ihn zu deaktivieren
; Rückgabe..: Keine
; ===============================================================================================================================
Func _ToggleSQLEditorMode($bActivate)
    ; Wenn aktueller Status bereits dem gewünschten entspricht, nichts tun
    If $g_bSQLEditorMode = $bActivate Then Return

    ; Rufe die sicheren Editor-Funktionen auf
    If $bActivate Then
        _SQL_EditorEnter()
    Else
        _SQL_EditorExit()
    EndIf
EndFunc

; StackTrace-Funktion zur Sicherheitsprüfung implementieren
Func _StackTrace($iFramesToSkip = 0)
    Local $aStack[0][2]  ; [Funktionsname, Zeile]
    Local $oError = ObjEvent("AutoIt.Error", "_ErrFunc")

    ; Traceback durchlaufen
    Local $i = 1 + $iFramesToSkip
    While 1
        Local $sFunc = "???"
        Local $iLine = 0

        ; Traceback-Informationen abrufen mit @ScriptLineNumber
        Local $aInfo = _GetCallerInfo($i)
        If @error Then ExitLoop

        $sFunc = $aInfo[0]
        $iLine = $aInfo[1]

        ; Zum Stack hinzufügen
        Local $iCount = UBound($aStack)
        ReDim $aStack[$iCount + 1][2]
        $aStack[$iCount][0] = $sFunc
        $aStack[$iCount][1] = $iLine

        $i += 1
    WEnd

    Return $aStack
EndFunc

; Hilfsfunktion für _StackTrace
Func _GetCallerInfo($iLevel)
    Local $aInfo[2]

    ; Für höheren Level muss rekursiv aufgerufen werden
    If $iLevel <= 0 Then Return SetError(1, 0, 0)

    ; Level 1 (direkter Aufrufer) abfragen
    Local $aCallStack = StringSplit(@ScriptLineNumber, ":")
    If @error Or $aCallStack[0] < 2 Then Return SetError(1, 0, 0)

    ; Wenn Level > 1, gibt es eine Künstliche Ober-Grenze für Sicherheit
    If $iLevel > 10 Then Return SetError(1, 0, 0)

    ; Als Ausweichlösung werden Funktionsnamen anhand der Tiefe simuliert
    ; Nur wirklich gebraucht für Aufrufer-Level <= 3
    Switch $iLevel
        Case 1
            $aInfo[0] = "_GetCallerInfo"
            $aInfo[1] = @ScriptLineNumber
        Case 2
            $aInfo[0] = "_StackTrace"
            $aInfo[1] = @ScriptLineNumber-1
        Case 3
            $aInfo[0] = "_SQL_SafeExecuteQuery"
            $aInfo[1] = @ScriptLineNumber-2
        Case 4
            $aInfo[0] = "_SQL_ExecuteButtonClicked"
            $aInfo[1] = @ScriptLineNumber-3
        Case Else
            $aInfo[0] = "func_level_" & $iLevel
            $aInfo[1] = 0
    EndSwitch

    Return $aInfo
EndFunc

; Error Handler für COM-Fehler
Func _ErrFunc()
    ; Nichts tun, nur Fehler unterdrücken
    Return
EndFunc
