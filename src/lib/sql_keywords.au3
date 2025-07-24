; Titel.......: SQL-Keywords - Gemeinsame Definitionen für SQL-Schlüsselwörter
; Beschreibung: Zentrale Definition aller SQL-Schlüsselwörter für Syntax-Highlighting und Autovervollständigung
; Autor.......: Optimized by Claude
; Erstellt....: 2025-04-25
; ===============================================================================================================================

#include-once
#include <Array.au3>

; ===============================================================================================================================
; Globale Arrays für SQL-Syntax-Elemente
; Diese werden sowohl vom Syntax-Highlighter als auch von der Autovervollständigung verwendet
; ===============================================================================================================================

; Vollständige Liste aller SQL-Keywords
Global $g_aSQL_AllKeywords[59] = [ _
    "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "JOIN", "INNER", "LEFT", "RIGHT", _
    "ORDER", "GROUP", "BY", "HAVING", "VALUES", "CREATE", "TABLE", "VIEW", "ALTER", "DROP", _
    "INDEX", "PRIMARY", "KEY", "FOREIGN", "CONSTRAINT", "UNIQUE", "CHECK", "DEFAULT", "NOT", "NULL", _
    "AS", "ON", "AND", "OR", "BETWEEN", "LIKE", "IN", "EXISTS", "ALL", "ANY", _
    "DISTINCT", "UNION", "INTERSECT", "EXCEPT", "LIMIT", "OFFSET", "ASC", "DESC", "COUNT", "SUM", _
    "AVG", "MIN", "MAX", "PRAGMA", "REFERENCES", "INTO", "SET", "AUTOINCREMENT" _
]

; SQL-Funktionen
Global $g_aSQL_Functions[31] = [ _
    "ABS", "AVG", "COUNT", "MAX", "MIN", "SUM", "TOTAL", "LENGTH", "UPPER", "LOWER", _
    "TRIM", "LTRIM", "RTRIM", "SUBSTR", "REPLACE", "INSTR", "ROUND", "RANDOM", "COALESCE", "IFNULL", _
    "DATE", "TIME", "DATETIME", "JULIANDAY", "STRFTIME", "GLOB", "TYPEOF", "UNICODE", "CHAR", "HEX" _
]

; SQL-Datentypen
Global $g_aSQL_DataTypes[12] = [ _
    "INTEGER", "REAL", "TEXT", "BLOB", "NULL", "NUMERIC", "INT", "VARCHAR", "CHAR", "FLOAT", "DOUBLE", "BOOLEAN" _
]

; Operatoren und Symbole
Global $g_aSQL_Operators[24] = [ _
    "+", "-", "*", "/", "%", "=", "<>", "!=", ">", "<", ">=", "<=", "||", "AND", "OR", "NOT", _
    "(", ")", ",", ".", ";", "IS", "LIKE", "GLOB" _
]

; ===============================================================================================================================
; Hilfsfunktionen für die Arbeit mit Keywords
; ===============================================================================================================================

; ===============================================================================================================================
; Func.....: _SQL_IsKeyword
; Beschreibung: Prüft, ob ein Token ein SQL-Schlüsselwort ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es ein Schlüsselwort ist, sonst False
; ===============================================================================================================================
Func _SQL_IsKeyword($sToken)
    $sToken = StringUpper($sToken)
    Return _ArraySearch($g_aSQL_AllKeywords, $sToken) >= 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsFunction
; Beschreibung: Prüft, ob ein Token eine SQL-Funktion ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es eine Funktion ist, sonst False
; ===============================================================================================================================
Func _SQL_IsFunction($sToken)
    $sToken = StringUpper($sToken)
    Return _ArraySearch($g_aSQL_Functions, $sToken) >= 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsDataType
; Beschreibung: Prüft, ob ein Token ein SQL-Datentyp ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es ein Datentyp ist, sonst False
; ===============================================================================================================================
Func _SQL_IsDataType($sToken)
    $sToken = StringUpper($sToken)
    Return _ArraySearch($g_aSQL_DataTypes, $sToken) >= 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_IsOperator
; Beschreibung: Prüft, ob ein Token ein SQL-Operator ist
; Parameter.: $sToken - Der zu prüfende Token
; Rückgabe..: True wenn es ein Operator ist, sonst False
; ===============================================================================================================================
Func _SQL_IsOperator($sToken)
    Return _ArraySearch($g_aSQL_Operators, $sToken) >= 0
EndFunc

; ===============================================================================================================================
; Func.....: _SQL_GetAllTokens
; Beschreibung: Gibt alle verfügbaren SQL-Tokens als ein großes Array zurück
; Rückgabe..: Ein Array mit allen SQL-Tokens (Keywords, Funktionen, Datentypen)
; ===============================================================================================================================
Func _SQL_GetAllTokens()
    Local $aAllTokens[0]
    
    ; Keywords hinzufügen
    For $i = 0 To UBound($g_aSQL_AllKeywords) - 1
        _ArrayAdd($aAllTokens, $g_aSQL_AllKeywords[$i])
    Next
    
    ; Funktionen hinzufügen
    For $i = 0 To UBound($g_aSQL_Functions) - 1
        _ArrayAdd($aAllTokens, $g_aSQL_Functions[$i])
    Next
    
    ; Datentypen hinzufügen
    For $i = 0 To UBound($g_aSQL_DataTypes) - 1
        _ArrayAdd($aAllTokens, $g_aSQL_DataTypes[$i])
    Next
    
    Return $aAllTokens
EndFunc
