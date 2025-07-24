# Benutzerhandbuch - DiagnoseTool Professional

## Übersicht

DiagnoseTool Professional ist eine umfassende Anwendung zur Analyse und Diagnose von verschlüsselten Archiven, SQLite-Datenbanken und Log-Dateien. Dieses Handbuch führt Sie durch alle wichtigen Funktionen.

## Programmstart

1. Starten Sie `DiagnoseTool.exe` als Administrator
2. Das Hauptfenster öffnet sich mit verschiedenen Tabs
3. Wählen Sie den gewünschten Arbeitsbereich

## Hauptfunktionen

### 1. Archive öffnen und verarbeiten

#### Einzelne Archive
```
1. Datei → Archive öffnen (Strg+O)
2. Wählen Sie die ZIP-Datei aus
3. Bei verschlüsselten Archiven wird automatisch das Passwort aus settings.ini verwendet
4. Das Archiv wird entpackt und analysiert
```

#### Drag & Drop
```
1. Ziehen Sie Archive direkt ins Hauptfenster
2. Mehrere Dateien können gleichzeitig verarbeitet werden
3. Automatische Erkennung des Archivformats
```

#### Bulk-Processing
```
1. Extras → Bulk-Processing
2. Wählen Sie einen Ordner mit mehreren Archiven
3. Konfigurieren Sie die Verarbeitungsoptionen
4. Starten Sie die Massenverarbeitung
```

### 2. Datenbank-Analyse

#### SQLite-Datenbanken öffnen
```
1. Wechseln Sie zum "Datenbank"-Tab
2. Automatische Erkennung von .db, .sqlite, .db3 Dateien
3. Tabellenstruktur wird im linken Bereich angezeigt
```

#### SQL-Editor verwenden
```
1. Klicken Sie auf "SQL-Editor öffnen"
2. Neues Fenster mit Syntax-Highlighting öffnet sich
3. Geben Sie SQL-Befehle ein
4. F5 zum Ausführen oder Strg+Enter
```

#### Autocomplete-Funktionen
```
- Tabellennamen: Beginnen Sie zu tippen, Vorschläge erscheinen
- Spaltennamen: Nach SELECT oder WHERE automatisch verfügbar
- SQL-Keywords: Alle Standard-SQL-Befehle werden erkannt
- Funktionen: Eingebaute SQLite-Funktionen verfügbar
```

#### Beispiel-Abfragen
```sql
-- Alle Daten einer Tabelle anzeigen
SELECT * FROM tablename LIMIT 100;

-- Fehler-Logs finden
SELECT * FROM logs WHERE level = 'ERROR' ORDER BY timestamp DESC;

-- Statistiken erstellen
SELECT level, COUNT(*) as count FROM logs GROUP BY level;

-- Zeitbereich-Analyse
SELECT * FROM logs WHERE timestamp BETWEEN '2024-01-01' AND '2024-01-31';
```

### 3. Log-Analyse

#### Log-Dateien öffnen
```
1. Wechseln Sie zum "Log-Analyse"-Tab
2. Unterstützte Formate: .log, .txt, .json
3. Automatische Format-Erkennung
```

#### Filter anwenden
```
- Level-Filter: ERROR, WARNING, INFO, DEBUG, TRACE
- Zeitbereich: Von-Bis Datum/Zeit
- Text-Suche: Reguläre Ausdrücke unterstützt
- Kombinierte Filter: Mehrere Kriterien gleichzeitig
```

#### Log-Parser Konfiguration
```
JSON-Logs:
- Automatische Struktur-Erkennung
- Verschachtelte Objekte werden flach dargestellt
- Timestamp-Extraktion

Text-Logs:
- Konfigurierbare Patterns
- Multi-Line-Support
- Custom-Delimiter
```

### 4. Export-Funktionen

#### Datenbank-Export
```
Formate:
- CSV: Komma-getrennte Werte
- JSON: Strukturierte JSON-Ausgabe
- XML: XML-Schema mit Metadaten
- Excel: .xlsx Format mit Formatierung
```

#### Log-Export
```
Optionen:
- Gefilterte Daten exportieren
- Original-Format beibehalten
- Zusammenfassung erstellen
- Statistik-Report generieren
```

#### Export-Konfiguration
```
1. Wählen Sie Ziel-Format
2. Bestimmen Sie Ausgabe-Pfad
3. Konfigurieren Sie Format-Optionen
4. Starten Sie den Export
```

## Erweiterte Funktionen

### 1. Batch-Verarbeitung

#### Automatisierte Workflows
```
1. Erstellen Sie eine Batch-Konfiguration
2. Definieren Sie Verarbeitungsschritte:
   - Archiv entpacken
   - Datenbank analysieren
   - Reports generieren
   - Cleanup durchführen
```

#### Scheduling
```
- Geplante Ausführung über Windows Task Scheduler
- Command-Line Interface für Automatisierung
- Batch-Dateien für wiederkehrende Aufgaben
```

### 2. Erweiterte SQL-Features

#### Schema-Browser
```
- Tabellen-Übersicht mit Spalten-Details
- Index-Informationen
- Foreign-Key-Beziehungen
- Trigger und Views
```

#### Query-Historie
```
- Automatische Speicherung aller Abfragen
- Favoriten-System für häufige Queries
- Export/Import von Query-Sets
```

#### Performance-Analyse
```
- EXPLAIN QUERY PLAN für Optimierung
- Index-Empfehlungen
- Query-Laufzeit-Messung
```

### 3. Multi-Monitor-Support

#### Fenster-Management
```
- Drag & Drop zwischen Monitoren
- Monitor-spezifische Einstellungen
- Fenster-Layouts speichern/laden
```

#### Display-Optimierung
```
- DPI-Awareness für High-DPI-Displays
- Skalierung-Anpassungen
- Font-Größen-Optimierung
```

## Tipps und Tricks

### Performance-Optimierung
```
1. Erhöhen Sie max_rows für große Datasets
2. Verwenden Sie LIMIT in SQL-Abfragen
3. Aktivieren Sie auto_clear_temp
4. Schließen Sie nicht benötigte Tabs
```

### Keyboard-Shortcuts
```
Allgemein:
- Strg+O: Archive öffnen
- Strg+S: Exportieren
- Strg+F: Suchen
- F5: Aktualisieren

SQL-Editor:
- F5: Query ausführen
- Strg+Enter: Query ausführen
- Strg+Shift+F: Formatieren
- Strg+/: Kommentar ein/aus
```

### Reguläre Ausdrücke in Filtern
```
Beispiele:
- Fehler finden: (error|failed|exception)
- IP-Adressen: \d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}
- Zeitstempel: \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}
- URLs: https?://[^\s]+
```

## Problemlösung

### Häufige Probleme

#### Archive können nicht geöffnet werden
```
Prüfen Sie:
1. Passwort in settings.ini
2. Archiv-Integrität (CRC-Fehler?)
3. Administratorrechte
4. Verfügbarer Speicherplatz
```

#### SQL-Abfragen schlagen fehl
```
Mögliche Ursachen:
1. Datenbank ist gesperrt
2. Syntax-Fehler in der Abfrage
3. Tabelle existiert nicht
4. Unzureichende Berechtigung
```

#### Log-Parsing funktioniert nicht
```
Überprüfen Sie:
1. Datei-Kodierung (UTF-8 empfohlen)
2. Log-Format-Einstellungen
3. Dateigröße (sehr große Dateien segmentieren)
4. Speicher-Verfügbarkeit
```

### Debug-Modus aktivieren
```
1. Starten Sie mit --debug Parameter
2. Oder setzen Sie debug=1 in settings.ini
3. Detaillierte Logs in debug.log
```

## Sicherheitshinweise

### Sensible Daten
```
- Verwenden Sie sichere Passwörter
- Löschen Sie temporäre Dateien regelmäßig
- Verschlüsseln Sie Backup-Archive
- Beschränken Sie Netzwerkzugriff bei Bedarf
```

### Daten-Export
```
- Überprüfen Sie Export-Pfade
- Verwenden Sie sichere Übertragungswege
- Bereinigen Sie exportierte Daten
- Dokumentieren Sie Datenflüsse
```

## Wartung

### Regelmäßige Aufgaben
```
1. Temporäre Dateien löschen
2. Log-Dateien rotieren
3. Settings.ini sichern
4. Updates installieren
```

### Performance-Monitoring
```
- Überwachen Sie Speicherverbrauch
- Prüfen Sie Festplatten-Space
- Analysieren Sie Query-Performance
- Optimieren Sie Filter-Einstellungen
```

---

**Letzte Aktualisierung**: Januar 2024  
**Version**: 2.1