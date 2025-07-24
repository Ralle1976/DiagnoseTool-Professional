; ===============================================================================================================================
; Titel.......: SQL-Query-Parser
; Beschreibung: Robuste Funktionen zum Parsen und Ausführen von SQL-Abfragen
; Autor.......: DiagnoseTool-Entwicklerteam
; Erstellt....: 2025-04-12
; ===============================================================================================================================

#include-once

#include <SQLite.au3>
#include <Array.au3>
#include <String.au3>

; ===============================================================================================================================
; Func.....: _SQL_FixSelectStarSyntax
; Beschreibung: Behebt speziell das häufige Problem mit "SELECT*FROM" ohne Leerzeichen
; Parameter.: $sSQL - Die zu korrigierende SQL-Anweisung
; Rückgabe..: Korrigierte SQL-Anweisung
; ===============================================================================================================================
Func _SQL_FixSelectStarSyntax($sSQL)
    ; Häufigste Probleme mit SELECT-Anweisungen korrigieren
    
    ; 1. "SELECT*FROM" - fehlende Leerzeichen um Stern
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT)\s*(\*)\s*(FROM)", "$1 $2 $3")
    
    ; 2. "SELECTFROM" - fehlendes Sternchen und Leerzeichen
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT)(?!\s*\*)(FROM)", "$1 * $2")
    
    ; 3. Allgemein fehlendes Leerzeichen zwischen Keywords
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT|WHERE|FROM|JOIN|ON|GROUP BY|ORDER BY|HAVING)(?=[^\s])", "$1 ")
    
    ; 4. Semikolon am Ende hinzufügen, falls nicht vorhanden
    If Not StringRegExp($sSQL, ";\s*$") Then
        $sSQL = $sSQL & ";"
    EndIf
    
    Return $sSQL
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ParseQuery
; Beschreibung: Parst einen SQL-String mit hoher Robustheit
; Parameter.: $sSQL - Die zu parsende SQL-Anweisung
; Rückgabe..: Array mit einzelnen SQL-Befehlen
; ===============================================================================================================================
Func _SQL_ParseQuery($sSQL)
    ; Debug-Information
    _LogInfo("_SQL_ParseQuery: Parse SQL-Anweisung: " & StringLeft($sSQL, 100) & (StringLen($sSQL) > 100 ? "..." : ""))
    
    ; Leerzeichen korrigieren
    $sSQL = _SQL_FixSpacingEnhanced($sSQL)
    
    ; Spezielle SELECT-Syntax-Probleme korrigieren
    $sSQL = _SQL_FixSelectStarSyntax($sSQL)
    
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
; Func.....: _SQL_ExtractQueriesWithRegex
; Beschreibung: Extrahiert SQL-Anweisungen mit RegEx für erhöhte Robustheit
; Parameter.: $sSQL - Die zu parsenden SQL-Anweisungen
; Rückgabe..: Array mit SQL-Anweisungen
; ===============================================================================================================================
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

; ===============================================================================================================================
; Func.....: _SQL_SplitQueriesClassic
; Beschreibung: Teilt SQL-Befehle in einzelne Anweisungen auf (Standard-Methode)
; Parameter.: $sSQL - Die zu trennenden SQL-Anweisungen
; Rückgabe..: Array mit einzelnen SQL-Anweisungen
; ===============================================================================================================================
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

; ===============================================================================================================================
; Func.....: _SQL_ExecuteWithRetry
; Beschreibung: Führt SQL-Befehle mit Fehlerbehandlung und Wiederholungsversuchen aus
; Parameter.: $hDB - Datenbankhandle
;             $sSQL - SQL-Befehl
;             $iMaxRetries - Maximale Anzahl von Wiederholungsversuchen (Standard: 3)
; Rückgabe..: Erfolg - Rückgabewert der SQL-Funktion
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SQL_ExecuteWithRetry($hDB, $sSQL, $iMaxRetries = 3)
    ; Korrigiere Leerzeichen im SQL-Befehl
    $sSQL = _SQL_FixSpacingEnhanced($sSQL)
    
    Local $iResult = 0
    Local $iRetryCount = 0
    Local $sError = ""
    
    While $iRetryCount <= $iMaxRetries
        ; Prüfen, ob es ein SELECT ist
        Local $bIsSelect = StringRegExp(StringUpper($sSQL), "^\s*SELECT")
        
        If $bIsSelect Then
            ; SELECT-Anweisung
            Local $aResult, $iRows, $iColumns
            $iResult = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
            
            ; Bei Erfolg Ergebnis zurückgeben
            If $iResult = $SQLITE_OK Then
                Return SetExtended($iRows, $aResult)
            EndIf
        Else
            ; Andere Anweisungen (INSERT, UPDATE, etc.)
            $iResult = _SQLite_Exec($hDB, $sSQL)
            
            ; Bei Erfolg True zurückgeben
            If $iResult = $SQLITE_OK Then
                Return True
            EndIf
        EndIf
        
        ; Fehler protokollieren und bei bestimmten Fehlern wiederholen
        $sError = _SQLite_ErrMsg()
        _LogWarning("_SQL_ExecuteWithRetry: Fehler beim Ausführen von SQL (Versuch " & ($iRetryCount + 1) & "): " & $sError)
        
        ; Bei bestimmten Fehlern wiederholen
        If StringInStr($sError, "database is locked") Or StringInStr($sError, "busy") Then
            $iRetryCount += 1
            Sleep(100 * $iRetryCount) ; Progressiv längere Wartezeit
            _LogInfo("_SQL_ExecuteWithRetry: Wiederhole Abfrage in " & (100 * $iRetryCount) & " ms")
        Else
            ; Bei anderen Fehlern sofort abbrechen
            _LogError("_SQL_ExecuteWithRetry: Fehler beim Ausführen von SQL: " & $sError)
            Return SetError(1, 0, False)
        EndIf
    WEnd
    
    ; Maximale Anzahl Wiederholungsversuche überschritten
    _LogError("_SQL_ExecuteWithRetry: Maximale Anzahl Wiederholungsversuche (" & $iMaxRetries & ") überschritten")
    Return SetError(2, 0, False)
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_FixSpacingComprehensive
; Beschreibung: Umfassende Korrektur von Leerzeichen in SQL-Anweisungen
; Parameter.: $sSQL - Die zu korrigierende SQL-Anweisung
; Rückgabe..: Korrigierte SQL-Anweisung
; ===============================================================================================================================
Func _SQL_FixSpacingComprehensive($sSQL)
    ; Sicherstellen, dass die Anweisung mit einer Kennung beginnt
    $sSQL = StringStripWS($sSQL, $STR_STRIPLEADING)
    
    ; Spezialbehandlung für "SELECT*FROM"
    If StringRegExp($sSQL, "(?i)SELECT\s*\*\s*FROM", 0) Then
        ; Korrekte Leerzeichen einfügen
        $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT)\s*\*\s*(FROM)", "$1 * $2")
    EndIf
    
    ; Allgemeine Korrekturen für SQL-Keywords
    $sSQL = StringRegExpReplace($sSQL, "(?i)(SELECT|UPDATE|DELETE|INSERT|FROM|WHERE|JOIN|ON|GROUP BY|ORDER BY|HAVING|LIMIT|OFFSET|VALUES|SET)(?=[^\s,;()])", "$1 ")
    
    ; SQL-Operatoren mit Leerzeichen versehen
    $sSQL = StringRegExpReplace($sSQL, "([^\s])(\=|\<|\>|\+|\-|\*|\/|\%|\!\=|\<\=|\>\=|\<\>|\|\|)(?=[^\s])", "$1 $2 ")
    
    ; Leerzeichen nach Kommas (aber nicht in Strings)
    Local $bInString = False
    Local $sStringChar = ""
    Local $sResult = ""
    
    For $i = 1 To StringLen($sSQL)
        Local $sChar = StringMid($sSQL, $i, 1)
        
        ; String-Grenzen erkennen
        If ($sChar = "'" Or $sChar = '"') Then
            If $bInString And $sChar = $sStringChar Then
                $bInString = False
            ElseIf Not $bInString Then
                $bInString = True
                $sStringChar = $sChar
            EndIf
        EndIf
        
        ; Leerzeichen nach Komma einfügen (außerhalb von Strings)
        If $sChar = "," And Not $bInString Then
            $sResult &= ", "
        Else
            $sResult &= $sChar
        EndIf
    Next
    
    ; Mehrfache Leerzeichen entfernen
    $sResult = StringRegExpReplace($sResult, "\s{2,}", " ")
    
    ; Zusätzliche Korrekturen
    $sResult = StringRegExpReplace($sResult, "\s+;", ";") ; Kein Leerzeichen vor Semikolon
    $sResult = StringRegExpReplace($sResult, ";\s+", ";") ; Kein Leerzeichen nach Semikolon (außer am Ende)
    
    Return $sResult
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_ExecuteBatch
; Beschreibung: Führt mehrere SQL-Befehle als Batch aus
; Parameter.: $hDB - Datenbankhandle
;             $aSQLBatch - Array mit SQL-Befehlen
;             $bTransaction - True, um eine Transaktion zu verwenden (Standard: True)
; Rückgabe..: Erfolg - Array [Anzahl erfolgreicher Befehle, Anzahl fehlgeschlagener Befehle]
;             Fehler - False und @error gesetzt
; ===============================================================================================================================
Func _SQL_ExecuteBatch($hDB, $aSQLBatch, $bTransaction = True)
    ; Prüfen, ob das Array gültig ist
    If Not IsArray($aSQLBatch) Or UBound($aSQLBatch) < 1 Then
        _LogError("_SQL_ExecuteBatch: Ungültiges SQL-Batch-Array")
        Return SetError(1, 0, False)
    EndIf
    
    Local $iSuccessCount = 0
    Local $iErrorCount = 0
    
    ; Transaktion starten falls gewünscht
    If $bTransaction Then
        _SQLite_Exec($hDB, "BEGIN TRANSACTION;")
    EndIf
    
    ; Jeden Befehl ausführen
    For $i = 0 To UBound($aSQLBatch) - 1
        Local $sSQL = $aSQLBatch[$i]
        
        ; Leere Anweisungen überspringen
        If StringStripWS($sSQL, $STR_STRIPLEADING + $STR_STRIPTRAILING) = "" Then
            ContinueLoop
        EndIf
        
        ; Leerzeichen korrigieren und Anweisung ausführen
        $sSQL = _SQL_FixSpacingComprehensive($sSQL)
        
        ; Prüfen, ob es ein SELECT ist
        Local $bIsSelect = StringRegExp(StringUpper($sSQL), "^\s*SELECT")
        
        Local $iResult
        If $bIsSelect Then
            Local $aResult, $iRows, $iColumns
            $iResult = _SQLite_GetTable2d($hDB, $sSQL, $aResult, $iRows, $iColumns)
        Else
            $iResult = _SQLite_Exec($hDB, $sSQL)
        EndIf
        
        ; Ergebnis auswerten
        If $iResult = $SQLITE_OK Then
            $iSuccessCount += 1
        Else
            $iErrorCount += 1
            Local $sError = _SQLite_ErrMsg()
            _LogError("_SQL_ExecuteBatch: Fehler bei Befehl " & ($i + 1) & ": " & $sError & @CRLF & "SQL: " & $sSQL)
            
            ; Bei Transaktion und Fehler: Rollback und Abbruch
            If $bTransaction Then
                _SQLite_Exec($hDB, "ROLLBACK;")
                _LogWarning("_SQL_ExecuteBatch: Transaktion zurückgerollt wegen Fehler")
                Local $aResult = [$iSuccessCount, $iErrorCount]
                Return SetError(2, 0, $aResult)
            EndIf
        EndIf
    Next
    
    ; Transaktion abschließen falls verwendet
    If $bTransaction And $iErrorCount = 0 Then
        _SQLite_Exec($hDB, "COMMIT;")
        _LogInfo("_SQL_ExecuteBatch: Transaktion erfolgreich abgeschlossen")
    ElseIf $bTransaction Then
        _SQLite_Exec($hDB, "ROLLBACK;")
        _LogWarning("_SQL_ExecuteBatch: Transaktion zurückgerollt wegen Fehlern")
    EndIf
    
    ; Ergebnis zurückgeben
    Local $aResult = [$iSuccessCount, $iErrorCount]
    Return $aResult
EndFunc
