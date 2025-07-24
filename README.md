# DiagnoseTool Professional

## Übersicht

DiagnoseTool Professional ist eine leistungsstarke Windows-Anwendung zur Analyse und Diagnose von verschlüsselten ZIP-Archiven, die SQLite-Datenbanken und Logdateien enthalten. Das Tool wurde speziell für Systemadministratoren, Entwickler und Support-Teams entwickelt, die komplexe Diagnoseaufgaben effizient durchführen müssen.

## Features

### 🔐 Archive-Verarbeitung
- **Verschlüsselte ZIP-Archive**: Automatische Entschlüsselung und Extraktion
- **Bulk-Processing**: Massenverarbeitung mehrerer Archive
- **7-Zip Integration**: Unterstützung für verschiedene Archivformate

### 📊 Datenbank-Analyse
- **SQLite Integration**: Direkte Analyse von SQLite-Datenbanken
- **SQL-Editor**: Integrierter Editor mit Syntax-Highlighting
- **Autocomplete**: Intelligente Vervollständigung für SQL-Befehle
- **Export-Funktionen**: Datenexport in verschiedene Formate

### 📋 Log-Analyse
- **Multi-Format Support**: JSON, Text und binäre Log-Formate
- **Echtzeit-Parsing**: Dynamische Log-Analyse
- **Filter-System**: Erweiterte Filteroptionen
- **Syntax-Highlighting**: Farbcodierte Darstellung verschiedener Log-Level

### 🎨 Benutzeroberfläche
- **Multi-Monitor Support**: Optimiert für Mehrmonitor-Setups
- **Anpassbare GUI**: Konfigurierbare Oberflächenelemente
- **Drag & Drop**: Intuitive Dateiverwaltung
- **Export-Optionen**: Flexible Ausgabeformate

## Systemanforderungen

- **Betriebssystem**: Windows 7/8/10/11 (32-bit/64-bit)
- **AutoIT Runtime**: Version 3.3.14.5 oder höher
- **Speicher**: Mindestens 512 MB RAM
- **Festplatte**: 100 MB freier Speicherplatz
- **Zusätzlich**: 7-Zip Installation empfohlen

## Installation

### Schnellinstallation
1. Download der neuesten Version aus dem [Releases](releases/) Ordner
2. Entpacken der ZIP-Datei in gewünschten Ordner
3. Ausführen der `DiagnoseTool.exe`

### Manuelle Installation
1. AutoIT 3 Runtime installieren (falls nicht vorhanden)
2. Projektdateien herunterladen
3. Dependencies überprüfen:
   - `sqlite3.dll` im lib/ Verzeichnis
   - `7za.exe` und `7za.dll` im Hauptverzeichnis

## Verwendung

### Grundfunktionen

#### Archive öffnen
```
1. Datei → Archive öffnen oder Drag & Drop
2. Passwort eingeben (falls verschlüsselt)
3. Automatische Extraktion und Analyse
```

#### SQL-Abfragen
```
1. Datenbank-Tab auswählen
2. SQL-Editor öffnen
3. Abfrage eingeben (Autocomplete verfügbar)
4. Ausführen und Ergebnisse exportieren
```

#### Log-Analyse
```
1. Log-Tab auswählen
2. Gewünschte Log-Datei auswählen
3. Filter anwenden
4. Analyse durchführen
```

### Erweiterte Funktionen

#### Bulk-Processing
- Mehrere Archive gleichzeitig verarbeiten
- Batch-Export für große Datenmengen
- Automatisierte Berichterstellung

#### SQL-Editor Features
- Syntax-Highlighting für SQL
- Autocomplete für Tabellen und Spalten
- Abfrage-Historie
- Export in CSV, JSON, XML

## Konfiguration

Die Anwendung kann über die `settings.ini` Datei konfiguriert werden:

```ini
[General]
DefaultPath=C:\DiagnoseTools\
AutoSave=1
Language=DE

[Database]
QueryTimeout=30
MaxResultRows=10000

[Logging]
LogLevel=INFO
LogRotation=1
```

## Troubleshooting

### Häufige Probleme

**Problem**: Archive kann nicht geöffnet werden
- **Lösung**: Überprüfen Sie das Passwort und die Dateiintegrität

**Problem**: SQL-Editor reagiert nicht
- **Lösung**: Überprüfen Sie die SQLite-Datei auf Korruption

**Problem**: Log-Parsing schlägt fehl
- **Lösung**: Überprüfen Sie das Log-Format und die Kodierung

### Debug-Modus
Aktivieren Sie den Debug-Modus für detaillierte Fehleranalyse:
```
DiagnoseTool.exe --debug
```

## Entwicklung

### Architektur
- **Hauptsprache**: AutoIT 3
- **Modularer Aufbau**: Getrennte Bibliotheken für verschiedene Funktionen
- **Plugin-System**: Erweiterbare Parser-Module

### Verzeichnisstruktur
```
DiagnoseTool-Professional/
├── src/                    # Hauptquellcode
│   ├── lib/               # Kernbibliotheken
│   ├── parsers/           # Log-Parser Module
│   └── dll/               # Native DLL-Komponenten
├── docs/                  # Dokumentation
└── releases/              # Binärdateien
```

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert. Siehe LICENSE-Datei für Details.

## Support

Für Support und Fehlermeldungen erstellen Sie bitte ein Issue im GitHub Repository.

## Changelog

Siehe [CHANGELOG.md](docs/CHANGELOG.md) für detaillierte Versionshistorie.

---

**Entwickelt von Ralle1976** | Version 2.1 | © 2024