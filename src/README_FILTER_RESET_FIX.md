# Filter-Zurücksetzung Bugfix

## Problembeschreibung

Wenn ein Filter auf die Daten angewendet und dann das Filter-Fenster geschlossen wurde, blieb der Filter aktiv. Beim Drücken des "Aktual." (Aktualisieren) Buttons wurde der Filter nicht zurückgesetzt, wie es zu erwarten wäre.

## Implementierte Lösung

Die Lösung besteht aus zwei Hauptänderungen:

1. **Erweiterung der `_LoadDatabaseData()` Funktion**
   - Diese Funktion wird ausgeführt, wenn der "Aktual." Button gedrückt wird
   - Die Funktion prüft jetzt, ob ein Filter aktiv ist, und setzt ihn zurück, bevor neue Daten geladen werden
   - Zu diesem Zweck wurde ein zusätzlicher Aufruf von `_ResetListViewFilter()` implementiert

2. **Verbesserte Nutzer-Rückmeldung**
   - Die Funktion `_ResetListViewFilter()` wurde um eine Statusmeldung erweitert
   - Diese informiert den Benutzer, dass der Filter zurückgesetzt wurde

## Verwendete globale Variablen

- `$g_bFilterActive` - Speichert, ob aktuell ein Filter aktiv ist
- `$g_idStatus` - Referenz auf das Statuslabel in der GUI

## Dateien, die geändert wurden

1. **db_functions.au3**
   - Hinzufügen der Prüfung auf aktiven Filter vor dem Laden der Daten
   - Hinzufügen von "filter_functions.au3" als Include-Datei

2. **filter_functions.au3**
   - Erweiterung der `_ResetListViewFilter()` Funktion um eine Statusmeldung

## Wie die Änderung funktioniert

1. Der Benutzer wendet einen Filter an und schließt dann das Filter-Fenster
2. Die gefilterten Daten bleiben sichtbar, `$g_bFilterActive` ist auf `True` gesetzt
3. Der Benutzer klickt auf den "Aktual." Button
4. Die erweiterte `_LoadDatabaseData()` Funktion:
   - Erkennt, dass ein Filter aktiv ist
   - Setzt den Filter zurück durch Aufruf von `_ResetListViewFilter()`
   - Zeigt eine Statusmeldung an, dass der Filter zurückgesetzt wurde
   - Lädt dann alle Daten der aktuellen Tabelle neu

## Testmethodik

Um die Funktionalität zu testen:
1. Wählen Sie eine Tabelle mit ausreichend Daten aus
2. Wenden Sie einen Filter an (z.B. über den "Filter" Button)
3. Schließen Sie das Filter-Fenster
4. Klicken Sie auf "Aktual."
5. Überprüfen Sie, dass alle Daten wieder angezeigt werden und der Filter zurückgesetzt wurde