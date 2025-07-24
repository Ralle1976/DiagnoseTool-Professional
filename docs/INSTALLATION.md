# Installation Guide - DiagnoseTool Professional

## Systemvoraussetzungen

### Mindestanforderungen
- Windows 7/8/10/11 (32-bit oder 64-bit)
- 512 MB RAM
- 100 MB freier Festplattenspeicher
- Administratorrechte für die Installation

### Empfohlene Konfiguration
- Windows 10/11 (64-bit)
- 2 GB RAM oder mehr
- 500 MB freier Festplattenspeicher
- SSD-Laufwerk für optimale Performance

## Installation

### Option 1: Binärversion (Empfohlen)

1. **Download der aktuellen Version**
   - Laden Sie die neueste Version aus dem [Releases](../releases/) Ordner herunter
   - Datei: `DiagnoseTool-Professional-v2.1.zip`

2. **Entpacken**
   ```
   Entpacken Sie die ZIP-Datei in einen Ordner Ihrer Wahl, z.B.:
   C:\Program Files\DiagnoseTool-Professional\
   ```

3. **Konfiguration**
   - Kopieren Sie `settings.ini.example` nach `settings.ini`
   - Bearbeiten Sie die Konfigurationsdatei nach Ihren Bedürfnissen
   - **WICHTIG**: Setzen Sie Ihr Passwort in der [ZIP] Sektion

4. **Erste Ausführung**
   - Starten Sie `DiagnoseTool.exe` als Administrator
   - Das Tool prüft automatisch alle Abhängigkeiten

### Option 2: Aus Quellcode kompilieren

#### Voraussetzungen
- AutoIT 3 (Version 3.3.14.5 oder höher)
- Git für Windows
- Compiler-Umgebung (falls DLL-Komponenten benötigt werden)

#### Schritte

1. **Repository klonen**
   ```bash
   git clone https://github.com/Ralle1976/DiagnoseTool-Professional.git
   cd DiagnoseTool-Professional
   ```

2. **Abhängigkeiten installieren**
   ```
   Stellen Sie sicher, dass folgende Dateien vorhanden sind:
   - src/lib/sqlite3.dll
   - src/7za.exe
   - src/7za.dll
   ```

3. **Konfiguration vorbereiten**
   ```
   cp src/settings.ini.example src/settings.ini
   # Bearbeiten Sie settings.ini mit Ihren Einstellungen
   ```

4. **Kompilierung**
   ```
   AutoIT-Compiler:
   "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe" /in src/main.au3 /out bin/DiagnoseTool.exe
   ```

## Abhängigkeiten

### Erforderliche Dateien
- **sqlite3.dll**: SQLite-Datenbankunterstützung
- **7za.exe**: 7-Zip Archiv-Unterstützung
- **7za.dll**: 7-Zip DLL-Komponente

### AutoIT Runtime
Falls AutoIT nicht installiert ist, wird die Runtime automatisch erkannt und das Tool entsprechend konfiguriert.

## Konfiguration

### Basis-Konfiguration (settings.ini)

```ini
[ZIP]
password=IHR_ARCHIV_PASSWORT

[DATABASE]
max_rows=1000

[PATHS]
extract_dir=C:\Users\%USERNAME%\AppData\Local\Temp\diagnose-tool\extracted
```

### Erweiterte Einstellungen

#### Log-Level Farben
```ini
[LogLevelColors]
Info=0xFFEECC
ERROR=0x7D64F7
WARNING=0xFFCCCC
DEBUG=0xCCFFCC
```

#### GUI-Optionen
```ini
[GUI]
auto_clear_temp=0
auto_clear_logs=0
```

## Fehlerbehebung

### Problem: "DLL nicht gefunden"
**Lösung**: Stellen Sie sicher, dass sqlite3.dll im lib/ Verzeichnis vorhanden ist

### Problem: "Archiv kann nicht geöffnet werden"
**Lösung**: 
1. Überprüfen Sie, ob 7za.exe vorhanden ist
2. Stellen Sie sicher, dass Sie Administratorrechte haben
3. Prüfen Sie das Passwort in settings.ini

### Problem: "Access Denied"
**Lösung**: Starten Sie das Tool als Administrator

### Problem: Langsame Performance
**Lösung**: 
1. Erhöhen Sie max_rows in der Datenbank-Sektion
2. Aktivieren Sie auto_clear_temp
3. Verwenden Sie SSD-Laufwerk

## Deinstallation

1. Beenden Sie alle laufenden Instanzen von DiagnoseTool
2. Löschen Sie den Installationsordner
3. Entfernen Sie temporäre Dateien:
   ```
   %TEMP%\diagnose-tool\
   %APPDATA%\DiagnoseTool\
   ```

## Update

### Automatisches Update
Das Tool prüft beim Start auf verfügbare Updates (erfordert Internetverbindung).

### Manuelles Update
1. Laden Sie die neue Version herunter
2. Sichern Sie Ihre settings.ini
3. Ersetzen Sie die alte Installation
4. Stellen Sie Ihre Konfiguration wieder her

## Support

Bei Installationsproblemen:
1. Prüfen Sie die Systemvoraussetzungen
2. Führen Sie das Tool als Administrator aus
3. Überprüfen Sie die Log-Dateien
4. Erstellen Sie ein Issue im GitHub Repository

---

**Letzte Aktualisierung**: Januar 2024  
**Version**: 2.1