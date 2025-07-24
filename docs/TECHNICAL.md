# Technische Dokumentation - DiagnoseTool Professional

## Architektur-Übersicht

### Systemdesign
```
DiagnoseTool Professional
├── GUI Layer (AutoIT GUICreate)
├── Business Logic Layer
│   ├── Archive Handler
│   ├── Database Manager  
│   ├── Log Parser Engine
│   └── Export Controller
├── Data Access Layer
│   ├── SQLite Interface
│   ├── File System Handler
│   └── 7-Zip Integration
└── Utility Layer
    ├── Configuration Manager
    ├── Logging System
    └── Error Handler
```

### Modulstruktur

#### Kern-Module (lib/)
- `main.au3` - Hauptprogramm und GUI-Initialisierung
- `constants.au3` - Globale Konstanten und Konfigurationen
- `globals.au3` - Globale Variablen und Zustandsverwaltung
- `utils.au3` - Allgemeine Hilfsfunktionen

#### Spezialisierte Module
- `sql_editor_enhanced.au3` - Erweiterter SQL-Editor mit Autocomplete
- `zip_handler.au3` - Archive-Verarbeitung und 7-Zip Integration
- `sqlite_handler.au3` - SQLite-Datenbankoperationen
- `log_parser.au3` - Multi-Format Log-Parsing

## Datenfluss-Architektur

### Archive-Verarbeitung
```
Benutzer-Input (ZIP-Datei)
    ↓
Password-Validierung (settings.ini)
    ↓
7-Zip-Extraktion (7za.exe)
    ↓
Temporary Directory (%TEMP%/diagnose-tool/)
    ↓
Content-Analyse (SQLite/Log-Erkennung)
    ↓
Parser-Routing (automatisch)
    ↓
GUI-Darstellung (ListView/TreeView)
```

### SQL-Verarbeitung
```
SQL-Query-Input
    ↓
Syntax-Validierung
    ↓
SQLite-Engine (_SQLite_Exec)
    ↓
Result-Set-Processing
    ↓
GUI-Output (ListView)
    ↓
Export-Options (CSV/JSON/XML)
```

## Technische Spezifikationen

### Entwicklungsumgebung
- **Programmiersprache**: AutoIT 3.3.14.5+
- **GUI-Framework**: Native AutoIT GUI
- **Datenbank-Engine**: SQLite 3.42.0
- **Archive-Library**: 7-Zip 23.01
- **Build-System**: AutoIT Compiler (Aut2exe)

### System-Abhängigkeiten
```
Erforderliche DLLs:
- sqlite3.dll (SQLite-Engine)
- 7za.dll (7-Zip-Funktionen)

Externe Executables:
- 7za.exe (Archive-Extraktion)

AutoIT-Bibliotheken:
- <SQLite.au3>
- <Array.au3>
- <File.au3>
- <GUIConstantsEx.au3>
```

### Performance-Charakteristika
- **Speicherverbrauch**: 50-200 MB (abhängig von Datenmenge)
- **Startzeit**: < 3 Sekunden
- **Archive-Extraktion**: ~100 MB/s (SSD-abhängig)
- **SQL-Query-Performance**: Native SQLite-Geschwindigkeit
- **Log-Parsing**: ~500 MB/min (formatabhängig)

## API-Dokumentation

### Kern-Funktionen

#### Archive-Handler
```autoit
; Archiv öffnen und extrahieren
Func _OpenArchive($sArchivePath, $sPassword = "")
    ; Parameter:
    ;   $sArchivePath - Vollständiger Pfad zum Archiv
    ;   $sPassword - Entschlüsselungspasswort (optional)
    ; Rückgabe:
    ;   @error = 0: Erfolg, Pfad zum Extraktionsordner
    ;   @error = 1: Archiv nicht gefunden
    ;   @error = 2: Falsches Passwort
    ;   @error = 3: Extraktionsfehler
EndFunc
```

#### SQLite-Interface
```autoit
; Datenbank öffnen
Func _OpenDatabase($sDatabasePath)
    ; Parameter:
    ;   $sDatabasePath - Pfad zur SQLite-Datei
    ; Rückgabe:
    ;   @error = 0: Erfolg, Datenbankhandle
    ;   @error = 1: Datei nicht gefunden
    ;   @error = 2: Keine gültige SQLite-Datei
EndFunc

; SQL-Abfrage ausführen
Func _ExecuteSQL($hDatabase, $sQuery, $iMaxRows = 1000)
    ; Parameter:
    ;   $hDatabase - Datenbankhandle
    ;   $sQuery - SQL-Abfrage
    ;   $iMaxRows - Maximale Anzahl Ergebniszeilen
    ; Rückgabe:
    ;   @error = 0: Erfolg, 2D-Array mit Ergebnissen
    ;   @error = 1: SQL-Syntax-Fehler
    ;   @error = 2: Laufzeit-Fehler
EndFunc
```

#### Log-Parser
```autoit
; Log-Datei analysieren
Func _ParseLogFile($sLogPath, $sFormat = "auto")
    ; Parameter:
    ;   $sLogPath - Pfad zur Log-Datei
    ;   $sFormat - Format-Hint: "json", "text", "auto"
    ; Rückgabe:
    ;   @error = 0: Erfolg, Array mit Log-Einträgen
    ;   @error = 1: Datei nicht lesbar
    ;   @error = 2: Unbekanntes Format
EndFunc
```

### GUI-Komponenten

#### SQL-Editor
```autoit
; SQL-Editor erstellen
Func _CreateSQLEditor($hParent, $iX, $iY, $iWidth, $iHeight)
    ; Parameter:
    ;   $hParent - Parent-Window-Handle
    ;   $iX, $iY - Position
    ;   $iWidth, $iHeight - Größe
    ; Features:
    ;   - Syntax-Highlighting
    ;   - Autocomplete
    ;   - Query-Historie
    ;   - F5-Ausführung
EndFunc
```

#### Log-Viewer
```autoit
; Log-Viewer mit Filterung
Func _CreateLogViewer($hParent, $aLogData)
    ; Parameter:
    ;   $hParent - Parent-Window
    ;   $aLogData - Array mit Log-Einträgen
    ; Features:
    ;   - Level-basierte Farbcodierung
    ;   - Real-time-Filterung
    ;   - Export-Funktionen
EndFunc
```

## Konfigurationssystem

### settings.ini Struktur
```ini
[ZIP]
password=<VERSCHLUESSELTES_PASSWORT>

[DATABASE]
max_rows=1000                    ; Max. Ergebniszeilen
query_timeout=30                 ; SQL-Timeout in Sekunden
auto_analyze=1                   ; Automatische Schema-Analyse

[LOGGING]
level=INFO                       ; DEBUG, INFO, WARNING, ERROR
file_rotation=1                  ; Log-Rotation aktivieren
max_file_size=10485760          ; 10MB

[GUI]
theme=default                    ; GUI-Theme
auto_clear_temp=0               ; Temp-Dateien automatisch löschen
multi_monitor=1                 ; Multi-Monitor-Support

[PATHS]
extract_dir=%TEMP%\diagnose-tool\extracted
export_dir=%USERPROFILE%\Documents\DiagnoseTool
log_dir=%APPDATA%\DiagnoseTool\logs

[PERFORMANCE]
memory_limit=536870912          ; 512MB Speicherlimit
thread_count=4                  ; Anzahl Worker-Threads
cache_size=33554432            ; 32MB Cache
```

### Erweiterte Konfiguration
```ini
[SQL_EDITOR]
autocomplete=1                  ; Autocomplete aktivieren
syntax_highlighting=1           ; Syntax-Highlighting
query_history_size=100         ; Anzahl gespeicherte Queries
font_size=10                   ; Editor-Schriftgröße

[LOG_PARSER]
json_max_depth=10              ; Max. JSON-Verschachtelung
text_encoding=utf-8            ; Standard-Textcodierung
timestamp_formats=ISO8601,RFC3339,CUSTOM

[EXPORT]
default_format=CSV             ; Standard-Export-Format
csv_delimiter=;                ; CSV-Trennzeichen
json_pretty_print=1           ; JSON-Formatierung
xml_root_element=data         ; XML-Root-Element
```

## Sicherheitskonzept

### Authentifizierung
- Passwort-geschützte Archive werden mit konfigurierten Credentials geöffnet
- Passwörter werden verschlüsselt in settings.ini gespeichert
- Keine Klartext-Speicherung sensibler Daten

### Datenschutz
- Temporäre Dateien werden nach Beendigung gelöscht
- Keine Übertragung von Daten an externe Services  
- Lokale Verarbeitung aller Inhalte

### Eingabe-Validierung
```autoit
; SQL-Injection-Schutz
Func _ValidateSQL($sQuery)
    ; Überprüfung auf gefährliche SQL-Statements
    Local $aDangerous = ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "CREATE"]
    ; Nur SELECT-Statements erlauben (konfiguierbar)
EndFunc

; Pfad-Validierung gegen Directory Traversal
Func _ValidatePath($sPath)
    ; Überprüfung auf "..", absolute Pfade außerhalb Arbeitsverzeichnis
EndFunc
```

## Debugging und Logging

### Debug-Modi
```autoit
; Debug-Level konfigurieren
Global Const $DEBUG_NONE = 0
Global Const $DEBUG_ERROR = 1    ; Nur Fehler
Global Const $DEBUG_WARNING = 2  ; Warnungen + Fehler
Global Const $DEBUG_INFO = 3     ; Info + Warning + Error
Global Const $DEBUG_VERBOSE = 4  ; Alles protokollieren
```

### Logging-System
```autoit
; Log-Funktionen
Func _WriteLog($sMessage, $iLevel = $DEBUG_INFO)
Func _WriteErrorLog($sError, $sFunction = "")
Func _WriteDebugLog($sDebug, $sContext = "")
```

### Performance-Monitoring
```autoit
; Performance-Messung
Func _StartTimer($sOperation)
Func _EndTimer($sOperation)
Func _GetMemoryUsage()
Func _GetCPUUsage()
```

## Erweiterungs-Architektur

### Plugin-System (Experimentell)
```autoit
; Plugin-Interface
Func _RegisterPlugin($sPluginName, $sPluginPath)
Func _CallPlugin($sPluginName, $sFunction, $aParams)
```

### Custom-Parser
```autoit
; Eigene Log-Parser registrieren
Func _RegisterLogParser($sFormat, $funcParser)
    ; Parameter:
    ;   $sFormat - Format-Bezeichner
    ;   $funcParser - Parser-Funktion
EndFunc
```

## Build-Prozess

### Kompilierung
```batch
REM AutoIT-Kompilierung
"C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe" ^
    /in src\main.au3 ^
    /out bin\DiagnoseTool.exe ^
    /icon resources\icon.ico ^
    /comp 4 ^
    /pack

REM Dependencies kopieren
copy src\lib\sqlite3.dll bin\
copy src\7za.exe bin\
copy src\7za.dll bin\
```

### Packaging
```batch
REM Release-Package erstellen
7z a -tzip releases\DiagnoseTool-Professional-v2.1.zip ^
    bin\*.exe ^
    bin\*.dll ^
    docs\*.md ^
    src\settings.ini.example ^
    LICENSE
```

## Testing-Framework

### Unit-Tests
```autoit
; Test-Framework für Kern-Funktionen
Func _TestArchiveHandler()
Func _TestSQLiteOperations()
Func _TestLogParsing()
Func _TestConfiguration()
```

### Integration-Tests
```autoit
; End-to-End-Tests
Func _TestCompleteWorkflow()
Func _TestBulkProcessing()
Func _TestErrorRecovery()
```

---

**Letzte Aktualisierung**: Januar 2024  
**Entwickelt von Ralle1976**