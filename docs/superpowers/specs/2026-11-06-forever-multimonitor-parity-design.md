# Forever MultiMonitor Feature-Parität – Design

Datum: 2026-11-06
Status: Freigegeben durch Benutzer am 2026-11-06
Zielclient: WoW Forever / Camelot, Interface 16001, Build 1.60.1.70790 als derzeit dokumentierter Zielstand

## Versioned scope clarification

The selected versioned behavior target is package **2.1.2 Beta 17**, file **9029504**. The shipped package and `docs/FEATURE_PARITY.md` govern over broader ideas below. Do not add behavior found only in later Beta 20/26 material; a code-free custom-media importer is outside this target. Documented custom theme colors, exact topology, explicit single-ultrawide mode, gather command and external-process-dependent recovery remain in scope or explicit gaps.

## 1. Ziel und Erfolgskriterium

Das Projekt soll den ausgewählten Funktionsumfang tatsächlich nutzbar bereitstellen, unter eigener Forever-MultiMonitor-Marke und ohne fremden Quellcode oder fremde Produktnamen in der Add-on-Oberfläche. Betriebssystemfunktionen übernimmt ein eigenständiges Windows-Hilfsprogramm. Das Ergebnis darf keine Funktionen als vorhanden ausgeben, die lediglich beschrieben, simuliert oder nur teilweise implementiert sind.

Erfolg bedeutet: Für jede öffentlich dokumentierte Benutzerfunktion existiert entweder eine funktionierende Implementierung mit passendem Testnachweis oder eine ausdrücklich begründete technische Grenze. Vollständige Parität wird erst behauptet, wenn die Feature-Matrix und die Live-Testmatrix vollständig bestanden sind.

## 2. Ansätze und Entscheidung

1. **Addon-only:** Lua übernimmt alles. Verworfen als vollständige Lösung, weil WoW-Lua keine nativen HWND-Fenster verschieben, rahmenlos machen, Windows-Monitore enumerieren oder Display-Hotplug verwalten kann.
2. **Addon plus Windows-Hilfsprogramm:** Gewählter Ansatz. Das Addon besitzt In-Game-Layout, Panel-Lifecycle, HUD-/Edit-Mode-Integration, Profile, Themes, Wizard und Wiederherstellung. Ein separat gestartetes natives Programm besitzt ausschließlich Windows-Fenster-/Monitor-Operationen und liefert validierte Geometrie an das Addon. Kein dauerhaft laufender Windows-Hintergrundprozess ist erforderlich; automatisches Monitoring wird nur angeboten, wenn der Benutzer das Hilfsprogramm explizit startet.
3. **FancyZones/manual als vollständiger Ersatz:** Nicht ausreichend. Diese Methoden können Window Placement erleichtern, bieten aber keine Forever MultiMonitor-Topologieübergabe, Fensterwiederherstellung, Monitoridentität oder Hotplug-Transaktionen.

## 3. Bestehender Stand und relevante Befunde

Das bestehende Addon ist ein kleiner Lua-Kern mit Konfiguration, Geometrie, WorldFrame-Viewport, einer statischen Panelnamensliste, Slash Commands und debouncter Recovery. Es besitzt noch keine grafische Optionsoberfläche und keinen nativen Windows-Teil.

Konkrete Stabilitätsprobleme im aktuellen Code:

- `Core/Panels.lua` entdeckt primär eine feste Liste globaler Frames. Die vorhandenen Bag-Hooks erfassen nur ausgewählte Toggle-Funktionen und erkennen keine beliebigen später erzeugten Panels.
- `Panels:Remember` sichert Anchors und Scale nur beim ersten Routing, aber speichert keine vollständige Frame-Lifecycle-/Owner-Information und hat keine explizite Behandlung für fremde Addons oder dynamische Controller.
- `Panels:Restore` kann Anchors ohne valide gespeicherte Punkte auf `UIParent` setzen; das ist kein nachgewiesener Originalzustand.
- `Core/Viewport.lua` sichert WorldFrame-Punkte einmalig und stellt sie nur in der laufenden Sitzung wieder her. Es fehlen explizite Zustands-/Generation-/Fehlerverträge und belastbare Regressionstests.
- Combat-Deferred-Work verwendet einen einzelnen Callback-Slot. Mehrere Operationen können sich gegenseitig überschreiben; die letzte gewünschte Aktion ist nicht als transaktionaler Zustand modelliert.
- `Core/Init.lua` besitzt keine vollständige UI-Optionen- oder Setup-Wizard-Lifecycle.
- Die derzeitige Testvalidierung prüft Lua-Struktur, nicht das Verhalten der Frame-API oder den Forever-Client.

Die Verhaltensprüfung stützt sich auf das öffentliche README des ausgewählten Pakets, dessen versioniertes Forever-TOC sowie dokumentierte Forever-Panel- und API-Verträge. Paketquellcode wird weder kopiert noch abgeleitet; dessen Lizenz untersagt Weitergabe und abgeleitete Werke.

## 4. Funktionsumfang und Paritätsanforderungen

### 4.1 In-Game Addon

- `MainMonitor`-/`SecondMonitor1`-Aufteilung des 3D-Viewports, links/rechts, manuelle Seam-/Aspect-Kalibrierung und sichere Ein-Monitor-Rückfallebene.
- Panel-Routing für Karte, Taschen, Charakter, Zauberbuch, Questlog, Berufe, Auktionshaus, Freunde/Soziales/Communities, Sammlungen, Begegnungsjournal, Erfolge und unterstützte native Fenster.
- Dynamische Panel-Erkennung für beim Login noch nicht vorhandene oder durch Blizzard/andere Addons später erzeugte Frames.
- Panel-Lifecycle: Öffnen, Schließen, Escape, Fokus, Drag, gespeicherte Position, Wiederherstellung, Gather Off-Screen UI und Persistenz über Reload/Relog.
- Exklusive Positions-Controller für riskante Panel-Familien; generische Reparatur darf keinen dedizierten Controller, Ersatz-Taschen-Addon oder geschützte HUD-Frames überschreiben.
- Combat-Lockdown: keine verbotenen geschützten Änderungen; Operationen werden verlustfrei zusammengeführt und nach Combat-Ende in definierter Reihenfolge abgearbeitet.
- Blizzard Edit Mode/HUD-Layout-Integration, sofern die Forever-APIs es zulassen. Nicht verfügbare geschützte APIs werden als nicht unterstützt ausgewiesen, nicht umgangen.
- Setup-Wizard, Dashboard, Display-/MainMonitor-Steuerung, Skalierung, Aktivierung, Profile, Theme-/Hintergrundoptionen mit den Beta-17-dokumentierten benutzerdefinierten Farben, Recovery/Preview, Diagnose und klare Fehlerzustände.
- MainMonitor-/Gamepad-Kompatibilität, Chat-Bubbles, Menüs, Popup-Bounds, Minimap-/Workspace-Chrome und transient HUD-Frames entsprechend den nachgewiesenen Forever-APIs.
- Single-Ultrawide-Modi (21:9 sowie explizite 32:9/32:10-Aufteilung), OBS-/Streaming-Hinweise und Seam-/Bezel-Kalibrierung.
- Raw-Mouse-Input-Handling mit Speicherung und Wiederherstellung des vorherigen Benutzerwertes, sofern die Forever-API dies unterstützt.
- Persistenz mit Schema-Version, Validierung, Migration und nachvollziehbarer Herkunft der aktiven Geometrie.

### 4.2 Eigenständiges Windows-Hilfsprogramm

- Erkennung physischer Displays mit stabiler Geräteidentität, Bounds, Auflösung, DPI/Scaling und Anordnung.
- Auswahl von `MainMonitor` und `SecondMonitor1`, einschließlich asymmetrischer Auflösungen, Hoch-/Querformat, vertikal versetzter Displays, negativer Koordinaten, gemischter DPI-Skalierung und Single-Ultrawide-Split.
- Fenstererkennung des passenden WoW-Forever-Prozesses; sichere Fensterplatzierung, rahmenloser Modus und Wiederherstellung der ursprünglichen Fensterparameter.
- Exakte Geometrieübergabe an das Addon über ein versioniertes, validiertes Datenformat. Addon muss bei fehlender, veralteter oder fehlerhafter Übergabe sicher auf manuelle Geometrie zurückfallen.
- Display-Hotplug-Erkennung und definierte Fail-safe-Recovery: bei Verlust eines Displays WoW nicht in eine unerreichbare Fläche zwingen; ursprüngliche oder sichere verbleibende Fenstergeometrie wiederherstellen.
- Einmalige Anwendung muss möglich sein; das Programm muss nach erfolgreicher Platzierung beendet werden können. Dauerhafte Überwachung ist optional und explizit durch den Benutzer zu starten.
- Keine Telemetrie, kein Netzwerkzwang, keine automatischen Updates und keine ungefragten Autostart-/Dienstinstallationen.

### 4.3 Explizite Nicht-Ziele

- Das externe Hilfsprogramm nachbauen, dessen Code übernehmen oder geschützte Implementierungsdetails reverse-engineeren.
- Fremdes Produkt-Branding, Store-/Update-/Installer-Verhalten oder Protokollkompatibilität übernehmen.
- Behaupten, WoW-Lua könne native Windows-Fensterfunktionen oder physische Monitorinformationen selbst bereitstellen.
- Geschützte Blizzard-Aktionen durch Taint-/Secure-Frame-Umgehungen erzwingen.
- Vollständige Verhaltensparität deklarieren, solange Live-Tests auf dem tatsächlichen Forever-Client fehlen.

## 5. Architektur

### Phase 1 – Addon-Kern stabilisieren

Lua-Module werden in klar getrennte Zuständigkeiten überführt: Panel-Registry/Discovery, Panel-Controller, Frame-State-Snapshot, Placement, Restore, Combat-Queue, Viewport-State, Recovery und Diagnose. Jeder Frame erhält einen einmaligen, validierten Snapshot. Snapshots werden nicht aus bereits verschobenen Positionen neu aufgenommen. Restore entfernt nur den vom Addon gesetzten Zustand und stellt alle gültigen ursprünglichen Anchors/Scale/Strata/Level-/Parent-Werte wieder her, soweit diese Eigenschaften tatsächlich verändert wurden.

Panel-Erkennung verwendet unterstützte sichere Hooks auf UI-Panel-/Frame-Erzeugungs- und Öffnungswege plus kontrollierte Scans zu definierten Lifecycle-Zeitpunkten. Hooks sind idempotent. Die Erkennung darf keine fremden Frames blind übernehmen. Controller-Ownership wird explizit registriert; dedizierte Controller schließen generische Peer-Reparatur aus.

Combat-Änderungen werden als gewünschter Zielzustand mit Generation/Revision geführt, nicht als einzelner überschreibbarer Callback. Nach `PLAYER_REGEN_ENABLED` wird genau der aktuelle Zielzustand angewendet. Fehler pro Frame dürfen die übrigen Frames nicht abbrechen.

### Phase 2 – Vollständige In-Game-Bedienoberfläche

Options-Dashboard mit Status, Enable/Disable, MainMonitor-Seite, Breiten-/Seam-/Skalierungssteuerung, Setup-Wizard, Recovery/Preview, Profile und Diagnose. UI-Werte werden aus derselben validierten Config gelesen/geschrieben wie Slash Commands. Keine getrennten Konfigurationspfade. Tastatur-/Slash-Fallback bleibt verfügbar.

### Phase 3 – Eigenständiges Windows-Hilfsprogramm

Eigenständiger x64-Windows-Prozess mit kleinem UI- oder CLI-Einstieg. Windows Display Configuration APIs und Win32 Window APIs werden nur in diesem Prozess verwendet. Die erste lokale Implementierung verwendet .NET 10 mit direktem Win32-P/Invoke; sie ist ein eigenständiges Windows-Programm, aber kein Rust-/NativeAOT-Build. Eine spätere Rust-Portierung bleibt eine Technologieoption, keine bereits gelieferte Eigenschaft. Das Datenprotokoll ist versioniert, atomar geschrieben und schema-validiert. WoW-Addon und Helfer bleiben getrennt testbar. Der ursprünglich geplante versionierte Named-Pipe-/Dateihandoff ist noch nicht implementiert. Der aktuelle Einmalbetrieb setzt das Fenster auf die gewählte Monitor-Bounding-Box; das Addon liest anschließend die resultierende logische UIParent-Fläche. Eine direkte Geometrieübergabe und Hotplug-Wiederherstellung bleiben offene Phase-3-Arbeiten.

## 6. Test- und Qualitätsstrategie

- TDD für jede Verhaltensänderung: Regressionstest zuerst, beobachtetes Scheitern, minimale Implementierung, erneuter Test.
- Lua-Parser-/Manifest-Prüfung und statische Sandbox-Prüfung.
- Mock-Frame-Harness für Anchor-Snapshots, Wiederherstellung, dynamische Discovery, Hook-Idempotenz, Combat-Queue und Fehlerisolation.
- Property-/Grenztests für Geometrie: links/rechts, 25–90 %, Seam-Grenzen, ungültige Canvaswerte, asymmetrische und versetzte Geometrie.
- Windows-Helfer-Tests für Monitoridentitäten, DPI, negative Koordinaten, Fensterzustand, Hotplug und Rollback.
- Live-Testmatrix im Forever-Client für Cold Launch, `/reload`, Relog, alle Panel-Lifecycle-Fälle, Combat, Escape, Drag, Bags mit Ersatz-Addons, UI-Scale-/Displayänderung und Monitorverlust/-rückkehr.
- Evidenzstufen bleiben getrennt: static, simulated, live candidate, live verified. Nur `live verified` erfüllt den Release-Gate.

## 7. Harte technische Grenzen und offene Verifikation

- Die WoW-Lua-Sandbox kann native Windows-Monitor- und Fensteroperationen nicht selbst ausführen. Dafür ist Phase 3 erforderlich.
- Ob alle geschützten HUD-/Edit-Mode-Operationen in Forever 1.60.1.70790 unterstützt werden, muss anhand der realen Client-APIs und Live-Tests nachgewiesen werden.
- Welche globalen Frame-Erzeugungs-/Öffnungsfunktionen Forever tatsächlich bereitstellt, wird vor Verwendung pro Hook verifiziert. Keine Annahme über API-Verfügbarkeit.
- Der gemeinsame WoW-Addon-Wissenspfad `D:\Tools\Code\N4UXADDONS\wow-addon-knowledge` war auf dem verbundenen Rechner nicht verfügbar. Diese Wissensbasis wurde daher nicht konsultiert; API-Entscheidungen bleiben bis zur anderweitigen Quellenprüfung offen.
- Kein Test wird als Live-Test bezeichnet, wenn er nicht im Forever-Client ausgeführt wurde.

## 8. Arbeitsreihenfolge und Abnahmekriterien

1. **Stabilität:** Panel- und Viewport-State, dynamische Discovery, Restore, Combat-Queue und Regressionstests. Abnahme: simulierte Tests vollständig grün; Live-Matrix separat offen, bis im Client ausgeführt.
2. **GUI:** Dashboard und Wizard auf stabiler Config-/Controller-API. Abnahme: alle Kernoptionen ohne Slash Commands bedienbar; gleiche Ergebnisse wie Slash Commands; UI-/Reload-/Combat-Tests grün.
3. **Windows-Helfer:** Display-/Fenstersteuerung und Recovery. Abnahme: Testfälle für unterschiedliche Displaytopologien und Hotplug; einmalige Anwendung und vollständige Wiederherstellung; kein dauerhaft laufender Prozess erforderlich.

## 9. Release-Wahrheit

README, CHANGELOG und Feature-Matrix müssen zwischen implementiert, statisch geprüft, simuliert getestet und live verifiziert unterscheiden. Ein veröffentlichter Commit, ein erfolgreicher Lua-Parse oder ein bestandener Mock-Test ist kein Nachweis vollständiger Verhaltensparität. Die Projektversion bleibt Beta/Development, bis die Live-Release-Gates bestanden sind.



## 10. Umsetzungsstand und bewusste Abweichungen (2026-11-06)

- Der Lua-Kern enth?lt keyed Combat-Queue, registrierte dynamische Panel-Erkennung, Position-Persistenz, Raw-Mouse-CVar-Restore, OnShow-/OnHide-Reconciliation, named profiles, dreistufigen Setup-Wizard, 15-Sekunden-Preview mit Keep/Rollback und `/forevermultimonitor diagnostics`. Panel-spezifische Lifecycle-/Focus-/Escape-Adapter und Live-Client-Tests fehlen weiterhin.
- Die Options-UI bietet die Kernsteuerung, den gef?hrten Wizard, Preview/Recovery, Diagnose sowie per Profil gespeicherte Midnight-/Indigo-/Classic-Dashboard-Themes und 50?100 % Hintergrundopazit?t. Die Themes gelten nur f?r Dashboard und Wizard; Beta-17-dokumentierte benutzerdefinierte Farben sind noch offen. Ein sp?terer User-Media-Importer geh?rt nicht zum gepinnten Beta-17-Vertrag.
- Der Windows-Helfer ist ein .NET-10-x64-Prozess mit Win32-P/Invoke, kein Rust-Build und kein NativeAOT. Er enumeriert Displays und bietet `place`, `restore` sowie optional gestartetes `watch` mit Hotplug-Rollback auf die urspr?ngliche sichtbare Position oder den Prim?rmonitor. GUI-Displayauswahl, automatisches Reconnect/Reapply und direkter Addon-Handoff fehlen.
- Diese Abweichungen sind in README, CHANGELOG und Feature-Matrix als offen ausgewiesen. Kein Vollparit?ts-Claim.
