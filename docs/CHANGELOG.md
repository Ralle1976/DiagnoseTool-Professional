# Changelog - DiagnoseTool Professional

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/) und das Projekt folgt der [Semantic Versioning](https://semver.org/) Spezifikation.

## [2.1.0] - 2024-01-15

### Hinzugefügt
- **Autocomplete-System für SQL-Editor**: Intelligente Vervollständigung für Tabellen, Spalten und SQL-Keywords
- **Multi-Format Log-Parser**: Unterstützung für JSON, Textlogs und binäre Formate
- **Bulk-Archive-Processing**: Massenverarbeitung mehrerer Archive gleichzeitig
- **Export-Manager**: Erweiterte Export-Optionen für CSV, JSON, XML und Excel
- **Performance-Optimierungen**: Verbesserte Speicherverwaltung und Ladezeiten
- **Multi-Monitor-Support**: Optimierte Darstellung auf mehreren Bildschirmen
- **Debug-Utilities**: Erweiterte Debug-Tools und Logging-Funktionen

### Geändert
- **SQL-Editor UI**: Komplett überarbeitete Benutzeroberfläche mit Syntax-Highlighting
- **Archive-Handler**: Verbesserte 7-Zip Integration mit besserer Fehlerbehandlung
- **Log-Viewer**: Performance-Optimierungen für große Log-Dateien
- **Settings-Manager**: Erweiterte Konfigurationsmöglichkeiten
- **Filter-System**: Verbesserte Filter-Performance und neue Filteroptionen

### Behoben
- **Memory Leaks**: Mehrere Speicherlecks in der Log-Analyse behoben
- **SQL-Syntax-Highlighting**: Korrekte Darstellung von verschachtelten Queries
- **Archive-Extraction**: Robustere Behandlung korrupter Archive
- **Unicode-Support**: Verbesserte Unterstützung für internationale Zeichen
- **Crash-Fixes**: Verschiedene Absturzursachen bei großen Dateien behoben

### Entfernt
- **Legacy Log-Parser**: Alte Parser-Module durch universelle Lösung ersetzt
- **Deprecated Functions**: Veraltete Funktionen aus der API entfernt

## [2.0.3] - 2023-12-10

### Behoben
- **SQLite Lock-Issues**: Probleme mit gesperrten Datenbanken behoben
- **GUI-Responsiveness**: Bessere Reaktionsfähigkeit bei großen Datasets
- **Filter-Reset**: Problem beim Zurücksetzen der Filter-Einstellungen

### Geändert
- **Error-Handling**: Verbesserte Fehlermeldungen und Recovery-Mechanismen
- **Log-Colors**: Anpassbare Farbschemata für verschiedene Log-Level

## [2.0.2] - 2023-11-28

### Hinzugefügt
- **Query-Historie**: Automatische Speicherung und Wiederherstellung von SQL-Abfragen
- **Schema-Browser**: Detaillierte Anzeige von Tabellen-Strukturen
- **Keyboard-Shortcuts**: Erweiterte Tastaturkürzel für alle Hauptfunktionen

### Behoben
- **Archive-Password**: Korrekte Behandlung von Passwort-geschützten Archives
- **Export-Encoding**: UTF-8 Kodierung für alle Export-Formate
- **GUI-Scaling**: DPI-Awareness für High-Resolution Displays

## [2.0.1] - 2023-11-15

### Behoben
- **Critical Bug**: Absturz beim Öffnen sehr großer SQLite-Dateien
- **Memory Usage**: Optimierter Speicherverbrauch bei Log-Analyse
- **File Permissions**: Korrekte Behandlung von Dateiberechtigungen

### Geändert
- **Startup-Performance**: Schnellerer Programmstart durch lazy loading
- **UI-Updates**: Kleinere Verbesserungen der Benutzeroberfläche

## [2.0.0] - 2023-11-01

### Hinzugefügt
- **Neue Architektur**: Modularer Aufbau mit Plugin-System
- **Enhanced SQL-Editor**: Vollständige Neuentwicklung mit modernen Features
- **Real-time Log-Parsing**: Live-Analyse von Log-Streams
- **Advanced Filtering**: Regex-Support und kombinierte Filter
- **Export-Pipeline**: Konfigurierbare Export-Workflows
- **Settings-Management**: Umfassendes Konfigurationssystem

### Geändert
- **Complete UI-Redesign**: Moderne, responsive Benutzeroberfläche
- **Performance**: Bis zu 300% schnellere Verarbeitung großer Dateien
- **Memory Footprint**: 50% reduzierter Speicherverbrauch
- **Error Handling**: Robuste Fehlerbehandlung mit Recovery-Optionen

### Behoben
- **Unicode Issues**: Vollständige UTF-8/UTF-16 Unterstützung
- **Thread Safety**: Alle bekannten Threading-Probleme behoben
- **Resource Leaks**: Korrekte Freigabe aller Systemressourcen

## [1.5.2] - 2023-09-20

### Hinzugefügt
- **JSON-Log-Support**: Native Unterstützung für strukturierte JSON-Logs
- **Color-Customization**: Anpassbare Farbschemata für Log-Level
- **Archive-Validation**: Integrität-Prüfung vor der Verarbeitung

### Behoben
- **CSV-Export**: Korrekte Behandlung von Kommas in Datenfeldern
- **Log-Timestamps**: Verbesserte Parsing von verschiedenen Zeitformaten
- **GUI-Freezing**: Responsivität bei intensiven Operationen

## [1.5.1] - 2023-08-15

### Behoben
- **Critical Security Fix**: Validierung von Archive-Pfaden gegen Directory Traversal
- **Memory Leak**: Speicherleck bei wiederholten Archive-Operationen
- **SQL-Injection**: Härtung der SQL-Query-Verarbeitung

### Geändert
- **Security**: Erweiterte Sicherheitsmaßnahmen für Datei-Operationen
- **Logging**: Detailliertere Protokollierung von Sicherheitsereignissen

## [1.5.0] - 2023-07-30

### Hinzugefügt
- **Multi-Archive-Support**: Gleichzeitige Bearbeitung mehrerer Archive
- **Advanced-Search**: Volltext-Suche in SQLite-Datenbanken
- **Backup-System**: Automatische Backups der Konfiguration
- **Plugin-Interface**: Experimentelle Plugin-Unterstützung

### Geändert
- **SQLite-Engine**: Update auf SQLite 3.42.0
- **7-Zip-Integration**: Update auf 7-Zip 23.01
- **UI-Framework**: Migration zu neuerer AutoIT-Version

## [1.4.0] - 2023-06-10

### Hinzugefügt
- **Batch-Processing**: Automatische Verarbeitung von Archive-Ordnern
- **Report-Generation**: Automatische Report-Erstellung
- **Command-Line-Interface**: Unterstützung für Batch-Operationen
- **Configuration-Profiles**: Verschiedene Konfigurationsprofile

### Geändert
- **Performance**: Optimierungen für große Datei-Operationen
- **UI-Layout**: Verbesserte Tab-Organisation

## [1.3.0] - 2023-04-25

### Hinzugefügt
- **Log-Filtering**: Erweiterte Filter-Optionen für Log-Analyse
- **Data-Export**: Multiple Export-Formate (CSV, JSON, XML)
- **Search-Function**: Globale Suchfunktion über alle geöffneten Dateien
- **Drag-Drop-Support**: Intuitive Datei-Verwaltung

### Behoben
- **Archive-Corruption**: Bessere Behandlung korrupter Archive
- **Large-Files**: Optimierungen für Dateien > 1GB

## [1.2.0] - 2023-03-15

### Hinzugefügt
- **SQLite-Integration**: Native SQLite-Datenbankunterstützung
- **SQL-Query-Editor**: Einfacher SQL-Editor mit Syntax-Highlighting
- **Table-Browser**: Grafische Darstellung von Datenbankstrukturen

### Geändert
- **Archive-Engine**: Wechsel zu 7-Zip für bessere Kompatibilität
- **Memory-Management**: Optimierter Speicherverbrauch

## [1.1.0] - 2023-02-01

### Hinzugefügt
- **Log-Viewer**: Integrierter Log-Datei-Viewer
- **Archive-Preview**: Vorschau des Archive-Inhalts vor Extraktion
- **Settings-Dialog**: GUI für Programmeinstellungen

### Behoben
- **Password-Handling**: Korrekte Verarbeitung von Sonderzeichen in Passwörtern
- **File-Encoding**: UTF-8 Support für internationale Dateinamen

## [1.0.0] - 2023-01-15

### Hinzugefügt
- **Initial Release**: Grundfunktionen für Archive-Verarbeitung
- **ZIP-Support**: Entpacken passwort-geschützter ZIP-Archive
- **Basic-GUI**: Einfache Benutzeroberfläche
- **File-Browser**: Durchsuchen extrahierter Dateien
- **Configuration**: Grundlegende Konfigurationsmöglichkeiten

---

## Versionsschema

- **Major**: Große Architektur-Änderungen oder Breaking Changes
- **Minor**: Neue Features ohne Breaking Changes
- **Patch**: Bugfixes und kleine Verbesserungen

## Support

Für Fragen zu spezifischen Versionen oder Updates erstellen Sie bitte ein Issue im GitHub Repository.

**Entwickelt von Ralle1976**