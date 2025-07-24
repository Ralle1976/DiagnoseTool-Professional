#include-once
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <ListViewConstants.au3>
#include <GDIPlusConstants.au3>
#include <Misc.au3> ; Für _ChooseColor() Funktion

#include <GUIListView.au3>
#include <GuiImageList.au3>
#include <WinAPIGdi.au3>
#include <GDIPlus.au3>

; =============================================
; Log-Level Farbkonfigurator mit GDI+
; Autor: Ralle1976, 2025-03-31
; =============================================

; Log-Level-Farben als globale Variable (wird vom Hauptprogramm übernommen)
Global $g_aLogLevelColors[6][3] = [ _
    ["ERROR",     0xFF0000, "Fehler (ERROR, FATAL, CRITICAL)"], _
    ["WARNING",   0x00AAFF, "Warnungen (WARNING, WARN)"], _
    ["INFO",      0xFFFFFF, "Informationen (INFO, INFORMATION)"], _
    ["DEBUG",     0xF0F0F0, "Debug-Meldungen (DEBUG)"], _
    ["TRACE",     0xF8F8F8, "Trace-Meldungen (TRACE)"], _
    ["TRUNCATED", 0xFF00FF, "Abgeschnittene Einträge (TRUNCATED)"] _
]

; Globale GDI+ Variablen
Global $g_hGDIPlus, $g_hColorConfigGUI
Global $g_hGraphics, $g_hBitmap, $g_hBackbuffer
Global $g_hPen, $g_hBrush, $g_hFont, $g_hFontFamily
Global $g_iPanelWidth, $g_iPanelHeight
Global $g_idColorPanel

; Globale GUI-Elemente
Global $g_idStatusLabel, $g_idPreviewListView, $g_hPreviewListView

; Beispielhafte Log-Einträge für die Vorschau
Global $g_aExampleLogEntries[6][4] = [ _
    ["2025-03-22 10:15:32", "ERROR", "System", "Kritischer Fehler bei der Verbindung zur Datenbank"], _
    ["2025-03-22 10:16:45", "WARNING", "Network", "Netzwerkverbindung instabil - Wiederholungsversuch"], _
    ["2025-03-22 10:17:20", "INFO", "Application", "Anwendung erfolgreich initialisiert"], _
    ["2025-03-22 10:18:05", "DEBUG", "Database", "SQL-Abfrage ausgeführt: SELECT * FROM users"], _
    ["2025-03-22 10:18:30", "TRACE", "UI", "Button 'Speichern' wurde geklickt"], _
    ["2025-03-22 10:19:10", "ERROR (TRUNCATED)", "Logger", "Fehler beim Schreiben der Protokolldatei: Disk full..."] _
]

; Aktiv ausgewählter Log-Level
Global $g_iSelectedLogLevel = -1

; Pfad zur INI-Datei (wird vom Hauptprogramm gesetzt)
Global $g_sLogLevelColorsIniPath = ""

; Farbschemata - KORRIGIERT: Blautöne richtig als Blau definiert
Global $g_aColorSchemas[5][7] = [ _
    ["Standard", 0x0000FF, 0x00AAFF, 0xFFFFFF, 0xF0F0F0, 0xF8F8F8, 0xFF00FF], _
    ["Hoher Kontrast", 0x0000FF, 0xFFAA00, 0xFFFFFF, 0xC0C0C0, 0xE0E0E0, 0xFF00FF], _
    ["Pastell", 0xFFCCCC, 0xFFEECC, 0xCCFFCC, 0xCCCCFF, 0xEEEEFF, 0xFFCCFF], _
    ["Blautöne", 0xFF0000, 0xFFFF80, 0xF4C74F, 0xFEEC95, 0xFEF0CD, 0xFEF9C5], _ ; Korrigiert: Echte Blautöne in RGB
    ["Grüntöne", 0xCCFFCC, 0xCCFFEE, 0xDDFFDD, 0xCCFFCC, 0xBBFFBB, 0xAAFFAA] _ ; Auch Grüntöne optimiert
]

; Schema-Namen und aktuelles Schema
Global $g_asSchemaNames[6] = ["Standard", "Hoher Kontrast", "Pastell", "Blautöne", "Grüntöne", "Benutzerdefiniert"]
Global $g_sCurrentSchema = "Standard"
Global $g_bCustomSchema = False

; =============================================
; Hauptfunktion: Farbkonfigurator anzeigen
; =============================================

Func _ShowLogLevelColorConfigurator($sIniPath = "")
    ; Sichern der aktuellen Farben für späteren Abbruch
    Local $aColorBackup[UBound($g_aLogLevelColors)][3]
    For $i = 0 To UBound($g_aLogLevelColors) - 1
        $aColorBackup[$i][0] = $g_aLogLevelColors[$i][0]
        $aColorBackup[$i][1] = $g_aLogLevelColors[$i][1]
        $aColorBackup[$i][2] = $g_aLogLevelColors[$i][2]
    Next

    ; INI-Pfad setzen wenn angegeben
    If $sIniPath <> "" Then
        $g_sLogLevelColorsIniPath = $sIniPath
    EndIf

    ; Aktuelles Schema erkennen
    _DetectCurrentSchema()

    ; GDI+ starten
    _GDIPlus_Startup()
    $g_hGDIPlus = 1

    ; GUI erstellen
    $g_hColorConfigGUI = GUICreate("Log-Level Farbkonfigurator", 800, 600)

    ; Überschrift
    GUICtrlCreateLabel("Log-Level Farbkonfiguration", 20, 20, 300, 30)
    GUICtrlSetFont(-1, 12, 800)

    ; Erklärungstext
    GUICtrlCreateLabel("Klicken Sie auf einen Log-Level, um ihn auszuwählen, dann auf 'Farbe ändern', um seine Farbe zu ändern.", 20, 50, 760, 20)

    ; Status-Label
    $g_idStatusLabel = GUICtrlCreateLabel("Bereit. Wählen Sie einen Log-Level aus...", 20, 80, 760, 30)
    GUICtrlSetColor($g_idStatusLabel, 0x008000) ; Grüne Textfarbe
    GUICtrlSetFont($g_idStatusLabel, 9, 400, 4) ; Kursiv

    ; =============================================
    ; Farbschema-Auswahl
    ; =============================================

    GUICtrlCreateGroup("Farbschema", 580, 110, 200, 100)

    ; Dropdown für Farbschema
    GUICtrlCreateLabel("Schema:", 590, 130, 60, 20)
    Local $idSchemaCombo = GUICtrlCreateCombo("", 590, 150, 180, 25)

    ; Schemas in Combo einfügen
    Local $sSchemaList = ""
    For $i = 0 To UBound($g_asSchemaNames) - 1
        $sSchemaList &= $g_asSchemaNames[$i] & "|"
    Next
    GUICtrlSetData($idSchemaCombo, StringTrimRight($sSchemaList, 1))

    ; Aktuelles Schema selektieren
    GUICtrlSetData($idSchemaCombo, $g_sCurrentSchema)

    ; Schema anwenden Button
    Local $idSchemaApplyButton = GUICtrlCreateButton("Schema anwenden", 590, 180, 120, 25)

    ; =============================================
    ; GDI+ Zeichenfläche für Farbkonfiguration
    ; =============================================

    GUICtrlCreateGroup("Log-Level und Farben", 20, 120, 550, 230)

    ; GDI+ Zeichenfläche (als Pic-Control)
    $g_iPanelWidth = 530
    $g_iPanelHeight = 190
    $g_idColorPanel = GUICtrlCreatePic("", 30, 145, $g_iPanelWidth, $g_iPanelHeight)

    ; Backbuffer für Doppelpufferung erstellen
    $g_hBackbuffer = _GDIPlus_BitmapCreateFromScan0($g_iPanelWidth, $g_iPanelHeight)
    $g_hGraphics = _GDIPlus_ImageGetGraphicsContext($g_hBackbuffer)

    ; Antialiasing für Text und Formen aktivieren
    _GDIPlus_GraphicsSetSmoothingMode($g_hGraphics, $GDIP_SMOOTHINGMODE_HIGHQUALITY)
    _GDIPlus_GraphicsSetTextRenderingHint($g_hGraphics, 3) ; 3 = ClearTypeGridFit

    ; Basis-Objekte für das Zeichnen erstellen
    $g_hPen = _GDIPlus_PenCreate(0xFF000000, 1)
    $g_hBrush = _GDIPlus_BrushCreateSolid(0xFFFFFFFF)

    ; Font-Family und Font erstellen
    $g_hFontFamily = _GDIPlus_FontFamilyCreate("Segoe UI")
    $g_hFont = _GDIPlus_FontCreate($g_hFontFamily, 10, 0)

    ; Erste Zeichnung durchführen
    _DrawColorPanel()

    ; =============================================
    ; Vorschau ListView
    ; =============================================

    GUICtrlCreateGroup("Vorschau", 20, 360, 760, 180)

    ; ListView für Vorschau
    $g_idPreviewListView = GUICtrlCreateListView("Zeitstempel|Level|Klasse|Nachricht", 30, 385, 740, 145)
    $g_hPreviewListView = GUICtrlGetHandle($g_idPreviewListView)

    ; ListView-Spalten anpassen
    _GUICtrlListView_SetColumnWidth($g_idPreviewListView, 0, 130)
    _GUICtrlListView_SetColumnWidth($g_idPreviewListView, 1, 80)
    _GUICtrlListView_SetColumnWidth($g_idPreviewListView, 2, 80)
    _GUICtrlListView_SetColumnWidth($g_idPreviewListView, 3, 430)

    ; ListView-Stil anpassen
    _GUICtrlListView_SetExtendedListViewStyle($g_idPreviewListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))

    ; Beispieldaten in Preview-ListView einfügen
    _UpdatePreviewListView()

    ; =============================================
    ; Buttons
    ; =============================================

    Local $idColorButton = GUICtrlCreateButton("Farbe ändern", 20, 550, 150, 30)
    Local $idSaveButton = GUICtrlCreateButton("Speichern", 390, 550, 120, 30)
    Local $idResetButton = GUICtrlCreateButton("Zurücksetzen", 520, 550, 120, 30)
    Local $idCancelButton = GUICtrlCreateButton("Abbrechen", 650, 550, 120, 30)

    ; Hilfe-Button
    Local $idHelpButton = GUICtrlCreateButton("?", 760, 20, 25, 25, $BS_DEFPUSHBUTTON)

    ; =============================================
    ; WM_NOTIFY-Handler für die ListView
    ; =============================================

    GUIRegisterMsg($WM_NOTIFY, "_ColorConfig_WM_NOTIFY_Handler")

    ; GUI anzeigen
    GUISetState(@SW_SHOW, $g_hColorConfigGUI)

    ; Event-Schleife
    Local $bSaveChanges = False

    While 1
        Local $nMsg = GUIGetMsg()

        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $idCancelButton

                ; Farben zurücksetzen auf Backup
                For $i = 0 To UBound($g_aLogLevelColors) - 1
                    $g_aLogLevelColors[$i][1] = $aColorBackup[$i][1]
                Next

                ; Aufräumen und beenden ohne Speichern
                _Cleanup_Log_Color_Configurator()

                Return False

            Case $idSaveButton
                ; Farben speichern
                _SaveLogLevelColors()

                ; Status-Meldung aktualisieren
                GUICtrlSetData($g_idStatusLabel, "Farben wurden gespeichert.")

                ; Aufräumen und beenden mit Speichern
                _Cleanup_Log_Color_Configurator()
                $bSaveChanges = True
                Return True

            Case $idResetButton
                ; Farben zurücksetzen
                _ApplyColorSchema("Standard")

                ; Status-Meldung aktualisieren
                GUICtrlSetData($g_idStatusLabel, "Farben wurden auf Standardwerte zurückgesetzt.")

            Case $idColorButton
                ; Farbe des ausgewählten Log-Levels ändern
                If $g_iSelectedLogLevel >= 0 And $g_iSelectedLogLevel < UBound($g_aLogLevelColors) Then
                    ; Farbauswahldialog anzeigen
                    Local $iNewColor = _ChooseColor(1, $g_aLogLevelColors[$g_iSelectedLogLevel][1], 0, $g_hColorConfigGUI)

                    ; Wenn Farbe ausgewählt wurde
                    If $iNewColor <> -1 Then
                        ; Farbe aktualisieren
                        $g_aLogLevelColors[$g_iSelectedLogLevel][1] = $iNewColor

                        ; Panel und Preview neu zeichnen
                        _DrawColorPanel()
                        _UpdatePreviewListView()

                        ; Auf benutzerdefiniertes Schema umstellen
                        $g_sCurrentSchema = "Benutzerdefiniert"
                        $g_bCustomSchema = True
                        GUICtrlSetData($idSchemaCombo, "Benutzerdefiniert")

                        ; Status-Meldung aktualisieren
                        GUICtrlSetData($g_idStatusLabel, "Farbe für " & $g_aLogLevelColors[$g_iSelectedLogLevel][0] & " wurde geändert.")
                        GUICtrlSetColor($g_idStatusLabel, 0x008000) ; Grüne Textfarbe
                    EndIf
                Else
                    ; Kein Log-Level ausgewählt
                    GUICtrlSetData($g_idStatusLabel, "Bitte wählen Sie erst einen Log-Level aus!")
                    GUICtrlSetColor($g_idStatusLabel, 0xFF0000) ; Rote Textfarbe für Warnung
                EndIf

            Case $g_idColorPanel
                ; Klick auf das Color-Panel verarbeiten
                Local $aPos = GUIGetCursorInfo($g_hColorConfigGUI)
                If IsArray($aPos) Then
                    ; Klickposition relativ zum Panel bestimmen
                    Local $iPanelX = $aPos[0] - 30 ; X-Position des Panels
                    Local $iPanelY = $aPos[1] - 145 ; Y-Position des Panels

                    ; Log-Level basierend auf Klickposition ermitteln
                    Local $iClickedLevel = Int($iPanelY / 30)

                    ; Wenn gültiger Log-Level
                    If $iClickedLevel >= 0 And $iClickedLevel < UBound($g_aLogLevelColors) Then
                        ; Log-Level auswählen
                        $g_iSelectedLogLevel = $iClickedLevel

                        ; Panel neu zeichnen
                        _DrawColorPanel()

                        ; Status-Meldung aktualisieren
                        GUICtrlSetData($g_idStatusLabel, "Log-Level '" & $g_aLogLevelColors[$g_iSelectedLogLevel][0] & "' ausgewählt.")
                        GUICtrlSetColor($g_idStatusLabel, 0x000000) ; Schwarze Textfarbe
                    EndIf
                EndIf

            Case $idHelpButton
                ; Hilfe anzeigen
                _ShowHelpDialog()

            Case $idSchemaApplyButton
                ; Ausgewähltes Schema anwenden
                Local $sSchema = GUICtrlRead($idSchemaCombo)

                ; Schema wechseln
                _ApplyColorSchema($sSchema)

                ; Schema-Informationen aktualisieren
                $g_sCurrentSchema = $sSchema
                If $sSchema = "Benutzerdefiniert" Then
                    $g_bCustomSchema = True
                Else
                    $g_bCustomSchema = False
                EndIf

                ; Status-Meldung aktualisieren
                GUICtrlSetData($g_idStatusLabel, "Farbschema '" & $sSchema & "' wurde angewendet.")
                GUICtrlSetColor($g_idStatusLabel, 0x008000) ; Grüne Textfarbe
        EndSwitch
    WEnd

    ; Aufräumen
    _Cleanup()

    ; Rückgabe - wurden Änderungen gespeichert?
    Return $bSaveChanges
EndFunc

; =============================================
; Hilfsfunktionen
; =============================================

; Farbauswahldialog anzeigen (Verwendet die Standard _ChooseColor Funktion aus Misc.au3)
; Da diese bereits über Misc.au3 importiert wird, keine eigene Implementierung notwendig

; Zeichnet das Color-Panel mit GDI+
Func _DrawColorPanel()
    ; Hintergrund löschen (weiß)
    _GDIPlus_GraphicsClear($g_hGraphics, 0xFFFFFFFF)

    ; Jeder Log-Level bekommt eine Zeile
    For $i = 0 To UBound($g_aLogLevelColors) - 1
        ; Zeilen-Bereich berechnen
        Local $iY = $i * 30

        ; Hintergrundfarbe für ausgewählten Log-Level
        If $i = $g_iSelectedLogLevel Then
            ; Blasses Blau als Selektionsfarbe
            _GDIPlus_BrushSetSolidColor($g_hBrush, 0xFFE0E8F0)
            _GDIPlus_GraphicsFillRect($g_hGraphics, 0, $iY, $g_iPanelWidth, 30, $g_hBrush)
        EndIf

        ; Rahmen um die Zeile zeichnen
        _GDIPlus_GraphicsDrawRect($g_hGraphics, 0, $iY, $g_iPanelWidth, 30, $g_hPen)

        ; Log-Level-Name zeichnen
        _GDIPlus_BrushSetSolidColor($g_hBrush, 0xFF000000)
        Local $hFormat = _GDIPlus_StringFormatCreate()
        _GDIPlus_StringFormatSetAlign($hFormat, 0)
        _GDIPlus_StringFormatSetLineAlign($hFormat, 1)
        _GDIPlus_GraphicsDrawStringEx($g_hGraphics, $g_aLogLevelColors[$i][0], $g_hFont, _GDIPlus_RectFCreate(10, $iY, 100, 30), $hFormat, $g_hBrush)
        _GDIPlus_StringFormatDispose($hFormat)

        ; Farbvorschau zeichnen (farbiges Rechteck)
        ; WICHTIG: RGB zu BGR konvertieren für richtige Farbdarstellung
        _GDIPlus_BrushSetSolidColor($g_hBrush, 0xFF000000 + _WinAPI_SwitchColor($g_aLogLevelColors[$i][1]))
        _GDIPlus_GraphicsFillRect($g_hGraphics, 120, $iY + 5, 100, 20, $g_hBrush)
        _GDIPlus_GraphicsDrawRect($g_hGraphics, 120, $iY + 5, 100, 20, $g_hPen)

        ; Farbwert als Text
        _GDIPlus_BrushSetSolidColor($g_hBrush, 0xFF000000)
        $hFormat = _GDIPlus_StringFormatCreate()
        _GDIPlus_StringFormatSetAlign($hFormat, 1)
        _GDIPlus_StringFormatSetLineAlign($hFormat, 1)
        _GDIPlus_GraphicsDrawStringEx($g_hGraphics, "0x" & Hex($g_aLogLevelColors[$i][1], 6), $g_hFont, _GDIPlus_RectFCreate(230, $iY, 80, 30), $hFormat, $g_hBrush)
        _GDIPlus_StringFormatDispose($hFormat)

        ; Beschreibung zeichnen
        $hFormat = _GDIPlus_StringFormatCreate()
        _GDIPlus_StringFormatSetAlign($hFormat, 0)
        _GDIPlus_StringFormatSetLineAlign($hFormat, 1)
        _GDIPlus_GraphicsDrawStringEx($g_hGraphics, $g_aLogLevelColors[$i][2], $g_hFont, _GDIPlus_RectFCreate(320, $iY, 210, 30), $hFormat, $g_hBrush)
        _GDIPlus_StringFormatDispose($hFormat)
    Next

    ; Backbuffer in GUI-Control übertragen
    Local $hBitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($g_hBackbuffer)
    _WinAPI_DeleteObject(GUICtrlSendMsg($g_idColorPanel, $STM_SETIMAGE, $IMAGE_BITMAP, $hBitmap))
    _WinAPI_DeleteObject($hBitmap)
EndFunc

; Aktualisiert die Preview-ListView
Func _UpdatePreviewListView()
    ; ListView leeren
    _GUICtrlListView_DeleteAllItems($g_idPreviewListView)

    ; ListView in den Bearbeitungsmodus versetzen
    _GUICtrlListView_BeginUpdate($g_idPreviewListView)

    ; Beispieleinträge hinzufügen
    For $i = 0 To UBound($g_aExampleLogEntries) - 1
        ; Eintrag zum ListView hinzufügen
        Local $iIndex = _GUICtrlListView_AddItem($g_idPreviewListView, $g_aExampleLogEntries[$i][0])
        _GUICtrlListView_AddSubItem($g_idPreviewListView, $iIndex, $g_aExampleLogEntries[$i][1], 1)
        _GUICtrlListView_AddSubItem($g_idPreviewListView, $iIndex, $g_aExampleLogEntries[$i][2], 2)
        _GUICtrlListView_AddSubItem($g_idPreviewListView, $iIndex, $g_aExampleLogEntries[$i][3], 3)
    Next

    ; ListView-Aktualisierung abschließen
    _GUICtrlListView_EndUpdate($g_idPreviewListView)

    ; Bereich ungültig machen und Neuzeichnung erzwingen
    _WinAPI_InvalidateRect($g_hPreviewListView)
    _WinAPI_UpdateWindow($g_hPreviewListView)
EndFunc

; Wendet ein definiertes Farbschema an
Func _ApplyColorSchema($sSchema)
    ; Ermitteln des Schema-Index
    Local $iSchemaIndex = -1

    For $i = 0 To UBound($g_asSchemaNames) - 1
        If $g_asSchemaNames[$i] = $sSchema Then
            $iSchemaIndex = $i
            ExitLoop
        EndIf
    Next

    ; Wenn "Benutzerdefiniert" ausgewählt, nichts tun
    If $sSchema = "Benutzerdefiniert" And Not $g_bCustomSchema Then
        Return False
    EndIf

    ; Wenn ein gültiges Schema gefunden wurde
    If $iSchemaIndex >= 0 And $iSchemaIndex < UBound($g_aColorSchemas) Then
        ; Schema-Farben übernehmen
        For $i = 0 To UBound($g_aLogLevelColors) - 1
            $g_aLogLevelColors[$i][1] = $g_aColorSchemas[$iSchemaIndex][$i]
        Next

        ; Panel und Preview neu zeichnen
        _DrawColorPanel()
        _UpdatePreviewListView()

        Return True
    EndIf

    Return False
EndFunc

; Ermittelt, ob das aktuelle Farbset einem vordefinierten Schema entspricht
Func _DetectCurrentSchema()
    ; Für jedes vordefinierte Schema prüfen
    For $iSchema = 0 To UBound($g_aColorSchemas) - 1
        Local $bMatch = True

        ; Alle Farben prüfen
        For $i = 0 To UBound($g_aLogLevelColors) - 1
            If $g_aLogLevelColors[$i][1] <> $g_aColorSchemas[$iSchema][$i] Then
                $bMatch = False
                ExitLoop
            EndIf
        Next

        ; Wenn alle Farben übereinstimmen, Schema gefunden
        If $bMatch Then
            $g_sCurrentSchema = $g_asSchemaNames[$iSchema]
            $g_bCustomSchema = False
            Return True
        EndIf
    Next

    ; Kein passendes Schema gefunden -> Benutzerdefiniert
    $g_sCurrentSchema = "Benutzerdefiniert"
    $g_bCustomSchema = True
    Return False
EndFunc

; WM_NOTIFY-Handler für die Preview-ListView
Func _ColorConfig_WM_NOTIFY_Handler($hWnd, $iMsg, $wParam, $lParam)
    ; NMHDR-Struktur auslesen
    Local $tNMHDR = DllStructCreate("hwnd hWndFrom; uint_ptr IDFrom; int Code", $lParam)
    Local $hWndFrom = DllStructGetData($tNMHDR, "hWndFrom")
    Local $iCode = DllStructGetData($tNMHDR, "Code")

    ; Nur für die Preview-ListView
    If $hWndFrom = $g_hPreviewListView Then
        ; Für CUSTOMDRAW-Events
        If $iCode = $NM_CUSTOMDRAW Then
            ; NMLVCUSTOMDRAW-Struktur
            Local $tagNMLVCUSTOMDRAW = "struct;hwnd hWndFrom;uint_ptr IDFrom;int Code;dword dwDrawStage;handle hdc;" & _
                                     "struct;long left;long top;long right;long bottom;endstruct;" & _
                                     "dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;endstruct;" & _
                                     "dword clrText;dword clrTextBk;int iSubItem;dword dwItemType;" & _
                                     "dword clrFace;int iIconEffect;int iIconPhase;int iPartId;int iStateId;" & _
                                     "struct;long left;long top;long right;long bottom;endstruct;uint uAlign"

            Local $tNMLVCUSTOMDRAW = DllStructCreate($tagNMLVCUSTOMDRAW, $lParam)
            Local $iDrawStage = DllStructGetData($tNMLVCUSTOMDRAW, "dwDrawStage")

            ; In PREPAINT-Phase Items individuell behandeln
            If $iDrawStage = $CDDS_PREPAINT Then
                ; ITEM-Modus anfordern
                Return $CDRF_NOTIFYITEMDRAW

            ElseIf $iDrawStage = $CDDS_ITEMPREPAINT Then
                ; Item-Informationen extrahieren
                Local $iRow = DllStructGetData($tNMLVCUSTOMDRAW, "dwItemSpec")

                ; Gültigen Bereich prüfen
                If $iRow >= 0 And $iRow < UBound($g_aExampleLogEntries) Then
                    ; Log-Level ermitteln
                    Local $sLevel = $g_aExampleLogEntries[$iRow][1]

                    ; Passenden Farbwert ermitteln
                    Local $iColorIndex = _GetColorIndexForLevel($sLevel)

                    ; Farbe setzen - WICHTIG: RGB direkt verwenden (nicht konvertieren)
                    DllStructSetData($tNMLVCUSTOMDRAW, "clrTextBk", $g_aLogLevelColors[$iColorIndex][1])

                    Return $CDRF_NEWFONT
                EndIf
            EndIf
        EndIf
    EndIf

    ; Standard-Behandlung für andere Ereignisse
    Return $GUI_RUNDEFMSG
EndFunc

; Ermittelt den Farb-Index für einen bestimmten Log-Level
Func _GetColorIndexForLevel($sLevel)
    ; Level-String in Großbuchstaben umwandeln für Vergleich
    $sLevel = StringUpper($sLevel)

    ; Spezialfall für TRUNCATED
    If StringInStr($sLevel, "TRUNCATED") Then
        Return 5
    EndIf

    ; Prüfen, welchem Level-Typ der String entspricht
    Switch True
        Case StringInStr($sLevel, "ERROR") Or StringInStr($sLevel, "FATAL") Or StringInStr($sLevel, "CRITICAL")
            Return 0
        Case StringInStr($sLevel, "WARN")
            Return 1
        Case StringInStr($sLevel, "INFO")
            Return 2
        Case StringInStr($sLevel, "DEBUG")
            Return 3
        Case StringInStr($sLevel, "TRACE")
            Return 4
    EndSwitch

    ; Standard: INFO
    Return 2
EndFunc

; Zeigt den Hilfe-Dialog an
Func _ShowHelpDialog()
    Local $sHelpText = "Log-Level Farbkonfigurator Hilfe" & @CRLF & @CRLF & _
                      "Mit diesem Tool können Sie die Farben für verschiedene Log-Level anpassen." & @CRLF & @CRLF & _
                      "Anleitung:" & @CRLF & _
                      "1. Klicken Sie auf einen Log-Level in der Liste, um ihn auszuwählen" & @CRLF & _
                      "2. Klicken Sie auf 'Farbe ändern', um die Farbe anzupassen" & @CRLF & _
                      "3. Im Farbauswahldialog können Sie eine neue Farbe wählen" & @CRLF & _
                      "4. Die Vorschau zeigt Ihnen, wie die Logs mit den neuen Farben aussehen" & @CRLF & @CRLF & _
                      "Farbschemata:" & @CRLF & _
                      "- Wählen Sie ein vordefiniertes Farbschema aus der Liste" & @CRLF & _
                      "- Klicken Sie auf 'Schema anwenden', um alle Farben zu ändern" & @CRLF & _
                      "- Bei individuellen Änderungen wechselt das Schema auf 'Benutzerdefiniert'" & @CRLF & @CRLF & _
                      "Hinweis zur Farbdarstellung:" & @CRLF & _
                      "Die Farben werden in der Vorschau und in der tatsächlichen Log-Anzeige" & @CRLF & _
                      "identisch dargestellt. Dies ist durch spezielle Farbkonvertierung sichergestellt."

    MsgBox($MB_ICONINFORMATION, "Hilfe", $sHelpText, 0, $g_hColorConfigGUI)
EndFunc

; Speichert die Log-Level-Farben in der INI-Datei
Func _SaveLogLevelColors()
    If $g_sLogLevelColorsIniPath = "" Then
        $g_sLogLevelColorsIniPath = @ScriptDir & "\settings.ini"
    EndIf

    ; Sicherstellen, dass der Abschnitt existiert
    IniWrite($g_sLogLevelColorsIniPath, "LogLevelColors", "Info", "Log-Level-Farben Konfiguration")

    ; Schema-Information speichern
    IniWrite($g_sLogLevelColorsIniPath, "LogLevelColors", "Schema", $g_sCurrentSchema)

    ; Farben in INI-Datei speichern
    For $i = 0 To UBound($g_aLogLevelColors) - 1
        ; Farbwert als Hex-String speichern
        IniWrite($g_sLogLevelColorsIniPath, "LogLevelColors", $g_aLogLevelColors[$i][0], "0x" & Hex($g_aLogLevelColors[$i][1], 6))
    Next

    Return True
EndFunc

; Lädt die Log-Level-Farben aus der INI-Datei
Func _LoadLogLevelColors()
    If $g_sLogLevelColorsIniPath = "" Then
        $g_sLogLevelColorsIniPath = @ScriptDir & "\settings.ini"
    EndIf

    ; INI-Datei prüfen
    If Not FileExists($g_sLogLevelColorsIniPath) Then
        Return False
    EndIf

    ; Schema-Information laden
    Local $sSchema = IniRead($g_sLogLevelColorsIniPath, "LogLevelColors", "Schema", "Standard")

    ; Wenn ein vordefiniertes Schema, dann dieses anwenden
    For $i = 0 To UBound($g_asSchemaNames) - 2 ; -2 weil 'Benutzerdefiniert' nicht aus INI geladen wird
        If $sSchema = $g_asSchemaNames[$i] Then
            _ApplyColorSchema($sSchema)
            $g_sCurrentSchema = $sSchema
            $g_bCustomSchema = False
            Return True
        EndIf
    Next

    ; Wenn 'Benutzerdefiniert' oder unbekanntes Schema, dann einzelne Farben laden
    $g_sCurrentSchema = "Benutzerdefiniert"
    $g_bCustomSchema = True

    ; Farben aus INI-Datei lesen
    For $i = 0 To UBound($g_aLogLevelColors) - 1
        ; Farbwert als Hex-String lesen
        Local $sColorValue = IniRead($g_sLogLevelColorsIniPath, "LogLevelColors", $g_aLogLevelColors[$i][0], "")

        ; Wenn Wert vorhanden, in Zahl umwandeln und in Array speichern
        If $sColorValue <> "" Then
            ; Hex-String in Zahl umwandeln (0xRRGGBB Format)
            $g_aLogLevelColors[$i][1] = Number($sColorValue)
        EndIf
    Next

    Return True
EndFunc

; Setzt den Pfad zur INI-Datei für die Log-Level-Farben
Func _SetLogLevelColorsIniPath($sPath)
    $g_sLogLevelColorsIniPath = $sPath
EndFunc

; Aufräumen - GDI+ Ressourcen freigeben
Func _Cleanup_Log_Color_Configurator()
    ; GDI+ Ressourcen freigeben
    If $g_hPen Then _GDIPlus_PenDispose($g_hPen)
    If $g_hBrush Then _GDIPlus_BrushDispose($g_hBrush)
    If $g_hFont Then _GDIPlus_FontDispose($g_hFont)
    If $g_hFontFamily Then _GDIPlus_FontFamilyDispose($g_hFontFamily)
    If $g_hGraphics Then _GDIPlus_GraphicsDispose($g_hGraphics)
    If $g_hBackbuffer Then _GDIPlus_BitmapDispose($g_hBackbuffer)

    ; GDI+ herunterfahren
    If $g_hGDIPlus Then _GDIPlus_Shutdown()


    ; WM_NOTIFY-Handler wiederherstellen
    GUIRegisterMsg($WM_NOTIFY, "_LogViewer_WM_NOTIFY_Handler")
    GUIDelete($g_hColorConfigGUI)

    ; GUI löschen
    GUIDelete($g_hColorConfigGUI)
EndFunc