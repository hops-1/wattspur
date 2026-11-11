# Architektur

Stand: Mac 1.8.7 und iPhone 0.5.2 (Review, B-259). Kurz gefasst, wo was liegt, wie die Daten fließen und welche Regeln gelten. Die Gründe stehen in den Lern-Notizen [25](learning/25-architektur-aufraeumen.md) (Schichten) und [34](learning/34-review.md) (Review). Die Funde des Reviews stehen in [REVIEW-0.5.2](REVIEW-0.5.2.md).

## Überblick

```
App (macOS)            iOS (iPhone)              iOSWidgets (Erweiterung)
Views, Karten-Hülle,   Übersicht, Fahrten,       Live-Aktivität,
PDF, Ordner, Sync      Aufnahme, Kurzbefehle     Widget „Diese Woche“
  │       │              │        │                 │
  │       ▼              │        └── iOSShared ────┤  ActivityKit, App Intents, App Group
  │   WattspurMap (MapKit, ohne AppKit/UIKit/SwiftUI): Kacheln, Route und Farben,
  │   Karte aller Fahrten, Marker und Cursor; nutzt nur WattspurCore
  ▼                      ▼                          ▼
WattspurKit (Store)                              WattspurCore allein
SwiftData-Modelle, RideLibrary und ihre Dienste, (kein SwiftData)
Sync, Import-Ablauf, iPhone-Datenbank
  │   re-exportiert
  ▼
WattspurCore (rein)
FIT und GPX, Werttypen, Analysen, Aufnahme-Rechnung, Austauschformat
```

Pfeile zeigen die erlaubte Richtung der Abhängigkeit; zurück darf es nie gehen. `WattspurMap` nutzen beide Apps; am iPhone die Detailkarte, die Kachel „Letzte Fahrt“ und die Aufnahme-Karte (B-226).

**Größe (8.11.2026):** Mac-App 15 300 Zeilen in 80 Dateien, iPhone-App 4 600 in 30, Widgets und `iOSShared` 440, `WattspurCore` 8 400 in 61, `WattspurKit` 4 300 in 31, Tests 10 900 in 76 (653 Tests).

## Regeln

Die Regeln mit ✓ prüft `scripts/check-architecture.sh` (lokal in `scripts/ci-local.sh` und in GitHub Actions).

1. ✓ **`WattspurCore` kennt weder SwiftData noch SwiftUI, AppKit, UIKit, MapKit oder Charts.** Es rechnet auf Werttypen (`RideFigures`, `HighlightRide`, `MapRide`, `ParsedRide`, `RideSample`, `RideExchange`). Die Prüfung erkennt jede Form einer Import-Zeile in Swift 6 (`public import`, `@preconcurrency import`, `import struct …`) und prüft ihre Muster selbst.
2. **`WattspurKit` behält seinen Namen und alle `@Model`-Klassen** (`Ride`, `Bike`, `Rider`, `Goal`, `RouteGroup`, `SourceFile`, `ImportRecord`). Ein Umzug in ein anderes Modul könnte bestehende Bibliotheken unlesbar machen. **Das CloudKit-Schema ist in Production:** neue Felder und Typen ja, nie umbenennen, löschen oder den Typ ändern; jedes neue Feld braucht einen Standardwert oder ist optional.
3. **Die Brücke vom Modell zu den Werttypen steht an einem Ort:** `Store/RideBridges.swift` (dazu `Bike+Statistics.swift` und `DuplicateFacts+Ride.swift`). Neue Umrechnungen von `Ride` in einen reinen Typ kommen dorthin.
4. ✓ **Die Apps schreiben nur über `RideLibrary`** (am iPhone über `PhoneDatabase`, die `RideLibrary` nutzt). `@Query` zum Lesen ist erlaubt, `modelContext.insert/delete/save` in der App nicht. Einzige Ausnahme: `App/DemoMode.swift` füllt eine eigene Demo-Bibliothek für Screenshots.
5. **Eine Bibliothek je App.** `WattspurApp` erzeugt sie und gibt sie in die Environment (`@Environment(RideLibrary.self)`). Das Rückgängig-Machen gehört zum Fenster: `library.using(undoManager)`. Ein Rückgängig-Schritt merkt sich die **ID** einer Fahrt, nicht das Objekt: Hat der Sync die Fahrt inzwischen gelöscht, tut ⌘Z nichts (R-27).
6. ✓ **Die iPhone-App (`iOS/`, `iOSShared/`, `iOSWidgets/`) nimmt nichts aus `App/` außer Ressourcen** (Beispielfahrt, Icon) und importiert kein `AppKit`. Die Widgets und `iOSShared` importieren kein SwiftData. Was beide Apps brauchen, wandert ins Paket, nie per Kopie. Geprüft werden die Quellen beider iPhone-Targets in `project.yml`, in beiden Schreibweisen.
7. **Einstellungsschlüssel stehen an einem Ort:** am Mac in `App/AppSettings.swift` (`SettingsKey`), am iPhone in `iOS/PhoneSettingsKey.swift` (`PhoneSettingsKey`). Die Werte nie ändern; eine neue Einstellung bekommt eine neue Zeile.
8. ✓ **Das Kit enthält keine Texte für die Oberfläche.** Es liefert Fakten (z. B. `ImportReport`, `SyncProblem`), jede App formuliert sie selbst (`ImportReport+Text.swift`) und hält die Übersetzungen.
9. **Abgeleitete Werte einer Fahrt werden gespeichert und tragen eine Version** (beste Minute, Übersichtsroute, Kurvigkeit, stärkste Steigung; `TrackFigures.version`, dazu `parserVersion` je Leser). Ändert sich die Rechnung, wird die Version erhöht, und `LibraryMaintenance` rechnet ältere Fahrten im Hintergrund nach, in Paketen. Nachgerechnet wird nur **nach oben**: Eine ältere App lässt Werte einer neueren Version in Ruhe (R-28). Eine neue Spalte kommt in `docs/reference/data-exchange.md`, sonst schlägt der Test fehl.
10. ✓ **Gespeichert wird über `LibrarySave.save(_:)`.** Es meldet einen Fehler (`LibrarySave.failedNotification`), und beide Apps zeigen ihn (`SaveFailureAlert.swift`, `.reportsSaveFailures()`). Ein `try? context.save()` würde den Fehler verschlucken (R-31).
11. **Versionen stehen an einer Stelle:** Mac in `Config/Mac.xcconfig`, iPhone und Widget gemeinsam in `Config/iOS.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`). `scripts/build-dmg.sh` liest die Mac-Version von dort und baut nur aus einem sauberen Stand (R-04, R-12).
12. ✓ **`WattspurMap` kennt weder AppKit noch UIKit, SwiftUI oder SwiftData** (B-186), auch keine Typen wie `NSColor` oder `UIImage`. Es rechnet und zeichnet mit MapKit und Core Graphics. Farben des Systems (Akzent, Grau, Vergleichsfarben) löst die App für hell oder dunkel auf und gibt sie als `CGColor` hinein (`RouteColors`); die übrigen Kartenfarben stehen als Hex-Werte in `MapPalette`, und die Legenden der App bauen ihre Farben daraus. Bilder (Marker, Cursor) liefert das Modul als `CGImage`; die App verpackt sie in ihren Bildtyp. Was nur eine Plattform kann, bleibt in der App: die `…Representable`-Hülle, Maus und Klick (`TrackingMapView`, `NSClickGestureRecognizer`), Tooltips, der Rand beim Einpassen (`NSEdgeInsets`) und die Quellenangabe als Text.

## Datenfluss

### Import (Mac und iPhone)

```
Datei (FIT/GPX) ──► ImportFlow ──► RideLibrary.importFile ──► ImportService ──► FIT-/GPXRideImporter (Core)
  Ziehen, Öffnen,    Fragen: Bike,                              Duplikat?       ParsedRide
  Teilen, Dateien    Doppel, GPX anhängen                       anhängen?        │
                       │                                                         ▼
                       └── ImportReport (Fakten) ──► App formuliert          Ride + SourceFile
```

- `ImportFlow` (Kit) hält nur die Entscheidungen und eine **Warteschlange**: Ein zweiter Import wartet, bis der erste fertig ist (R-46). Jede App zeichnet ihre eigenen Fragen.
- Am iPhone kommen Dateien über „Öffnen mit“, die Dateiauswahl und den Ordner „Import“ (B-300, `PhoneImport`, `ImportInbox`). `ImportFlow.stepsThroughFiles` liest dort Datei für Datei, damit die Oberfläche nicht hängt, und `ImportFlow.Summary` zählt für die Zusammenfassung am Ende.
- Der **überwachte Ordner** am Mac (`FolderWatcher` → `FolderImport`) fragt niemanden. Er nimmt eine Datei erst, wenn sie ein paar Sekunden unverändert ist, und liest sie mit `NSFileCoordinator` (R-45).
- Eine Datei zu einer Fahrt im Papierkorb holt die Fahrt zurück und sagt es (R-44).

### Aufnahme (iPhone)

```
CLLocationUpdate ──► Recorder ──► RideRecording (Core) ──► GPXWriter ──► PhoneDatabase.saveRecording ──► Import wie oben
CMAltimeter     ──► AltitudeFusion (Höhe)       │
CMDeviceMotion  ──► MotionRecorder ──► MotionFusion (Schräglage, Rütteln)
                                                 └──► Protokolldatei je Ereignis (nach Absturz: weiter oder beenden)
```

- Jeder Punkt geht sofort in eine Protokolldatei. Nach einem Absturz bietet die App an, weiterzufahren oder zu beenden. Scheitert das Speichern, bleibt das Protokoll liegen und die App sagt es (R-51, R-52).
- Gilt eine Aufnahme als Doppel, wird die vorhandene Fahrt aktualisiert, nicht verworfen (R-53).
- Live-Aktivität und Knopf „Pause“ kommen über `iOSShared` (`RecordingAttributes`, `ToggleRecordingPauseIntent`); Siri und Kurzbefehle über `iOS/RideIntents.swift`.

### Sync über iCloud (Mac und iPhone)

```
Mac: SwiftData + CloudKit ◄──── private Datenbank in iCloud ────► iPhone: SwiftData + CloudKit
     (LibrarySync)                                                     (PhoneDatabase, Modus icloud)
        │                                                                  │
        └── SyncMergeWatcher ──► RideLibrary.mergeSyncDuplicates ◄──────────┘
            SyncMonitor ──► Status in Einstellungen / „Mehr“
```

- **Beide Geräte haben dieselbe Bibliothek**, gespiegelt von `NSPersistentCloudKitContainer`. CloudKit kennt keine eindeutigen Schlüssel, also entstehen Doppel (zwei „Mein eBike“, dieselbe Datei auf zwei Geräten importiert).
- `SyncMergeService` führt sie zusammen. Was bleibt, entscheidet nur, was **beide Geräte gleich sehen** (ältestes `createdAt`, dann `id`), nie Zählungen. Die zweite Kopie gibt vorher ihre Änderungen ab (Name, Bike, Papierkorb, angehängte Datei; R-35). Bikes werden nur bei gleicher Seriennummer oder als unberührtes Standard-Bike zusammengeführt (R-36).
- `SyncMergeWatcher` wartet, bis CloudKit eine Weile still ist und kein Import läuft; ein Import ohne Ende gilt nach 120 s als beendet (R-37).
- Einschalten am Mac legt **jedes Mal** vorher eine Sicherung an (R-39). Der Schalter wirkt beim nächsten Start; die Bibliothek bleibt dieselbe Datei.
- `SyncMonitor` liefert Fakten (`SyncProblem`, letzter Sync); die Apps formulieren sie.

### iPhone ohne iCloud

Das iPhone hat immer seine eigene Bibliothek (`PhoneDatabase`); `PhoneDatabase.Mode` (`local`, `icloud`) wählt der Build, `Mode.effective(syncOn:)` die Wahl des Nutzers. Ohne iCloud bleiben die Fahrten auf dem iPhone, „GPX teilen“ bringt eine an den Mac. Die Ansichten bekommen die Fahrten weiter im Austauschformat (`RideExchange`, gebaut von `PhoneDatabase.snapshot`). **Der Ordner-Weg aus iOS 0.2** (der Mac schrieb `Stand.json` in den Unterordner `iPhone` des Import-Ordners, das iPhone las ihn und legte Aufnahmen als GPX dorthin) **endete mit iPhone 0.6 und Mac 1.8.10 (B-263, Entscheidung Nils 6.11.2026).** Wer ihn noch nutzte (`Mode.wasFolderUser`), sieht einmal einen Hinweis mit dem Weg zu iCloud.

### Widget

Die App legt bei jeder Änderung einen `WeekSnapshot` (Core) in die App Group `group.io.github.hops-1.wattspur` (`iOSShared/WidgetShare.swift`). Das Widget liest nur diesen Schnappschuss und rechnet die Woche selbst aus, damit es am Montag ohne die App bei null beginnt.

## WattspurCore

| Ordner | Inhalt |
|---|---|
| `FIT/` | Container-Decoder, Basistypen, Profil, Anonymisierer |
| `Import/` | `RideImporter` (Protokoll), FIT- und GPX-Importer, `GPXSummary`, `ImportResult` |
| `Ride/` | `ParsedRide`, Samples, Zusammenführen und Vorschläge, Zeitachse über Teile und Tage (`PartTimeline`), Reihen für Diagramme, GPX-Schreiber, Kalorienmodell, Routen und Routenähnlichkeit, gespeicherte Strecken, beste Minute, Steigung (`RideTrack`), Bewegungswerte einer Fahrt (`RideMotion`), Radumfang (`WheelCheck`) |
| `Recording/` | Rechnung der Aufnahme ohne Sensoren: `RideRecording` (Punkte, Pausen, Strecke, Anstieg), `AltitudeFusion` (Barometer an GPS-Höhe, grobe GPS-Höhe ohne Barometer), `MotionFusion` (Schräglage, Beschleunigung, Rütteln), `MotionRawLog` (CSV für den Test V-16) |
| `Analysis/` | Summen und Trends, Rekorde, Vergleich, Karte (Filter, Dichte), neue Wege, Verlauf einer Strecke, Kurvigkeit, `TrackFigures` |
| `Library/` | Filter, Quellen, Bike-Statistik und -Profil, Fahrer für „Mehr“ am iPhone (`RiderDetails`), Duplikat-Fakten, Tagesfilter, Summen für Woche und Monat, `WeekSnapshot` für das Widget |
| `Exchange/` | `RideExchange`: das Austauschformat (JSON) und die Werte, die die iPhone-Views zeigen, aus beiden Quellen |
| `Map/` | Kachelserver und Kachel-Rechnung (Web Mercator); kurvige Straßen von roadcurvature.com mit eigenem Dateiformat und KMZ-Leser |
| `Support/` | Diagnosebericht, Versionen (`AppVersion`), Version und Commit der laufenden App (`AppInfo`), Links ins Handbuch für beide Apps (`HelpLinks`) |

## WattspurKit (Store)

| Teil | Inhalt |
|---|---|
| `Store/Models.swift`, `ImportRecord.swift` | SwiftData-Modelle (CloudKit-tauglich: alles optional oder mit Standardwert, keine eindeutigen Schlüssel) |
| `Store/RideLibrary.swift` | Die eine Tür für beide Apps; reicht an die Dienste weiter (siehe „Entscheidungen“) |
| `Store/Services/` | `ImportService`, `RideService`, `MergeService`, `BikeService`, `ImportLogService`, `GoalService`, `RouteGroupService`, `SyncMergeService`, dazu `LibraryService` (gemeinsame Umgebung und Rückgängig) |
| `Store/LibrarySave.swift` | Speichern an einer Stelle, mit Meldung bei Fehlern |
| `Store/LibrarySync*.swift` | Konfiguration mit oder ohne CloudKit; Schema anlegen und Speicher messen (nur Debug) |
| `Store/SyncMergeWatcher.swift`, `SyncMonitor.swift` | Wann Doppel zusammengeführt werden; Stand und Probleme des Sync |
| `Store/PhoneDatabase.swift` | Die Bibliothek des iPhones: liefert `RideExchange`-Werte, speichert Aufnahmen, bearbeitet und löscht |
| `Store/RideExchange+Store.swift` | Fahrten der Bibliothek im Austauschformat für die iPhone-Ansichten |
| `Store/LibraryBackup.swift` | Sicherung und Wiederherstellung als Ordner (SQLite-Backup, Austausch beim Start) |
| `Store/LibraryMaintenance.swift` | Aufräumen nach dem ersten Fenster, Nachrechnen nach Version, in Paketen |
| `Store/RideBridges.swift` | Modell → Werttypen |
| `Store/CurvyRoadLibrary.swift` | Importierte Regionen als Dateien, nicht in SwiftData und nicht im Backup |
| `Import/` | `FolderImport` (überwachter Ordner), `ImportFlow` (Fragen, Warteschlange, am iPhone Datei für Datei mit Fortschritt und Zusammenfassung), `ImportReport` (Fakten), `ImportInbox` (Ordner „Import“ am iPhone) |

**Dienste:** zustandslose Structs, gebaut aus einer `LibraryEnvironment` (Kontext, Importer, UndoManager, Standard-Bikename). Sie nutzen sich nur in eine Richtung: Import → Zusammenführen → Bikes. Die übrigen stehen für sich.

## App (macOS)

Views in `App/`; große Bereiche in eigenen Ordnern (`Highlights/`, `Analysis/`, `Compare/`). `@Observable`-Hilfsobjekte in der Environment: `FolderWatcher`, `ImportLog`, `NewPathsStore`, `RouteSimilarityStore`, `LibraryBackupCenter`, `MergeSuggestionCenter`, `BikeAssignmentNotice`, `ICloudSync`, `CurvyRoadsStore`. `DemoMode` und `SampleRide` sind für Screenshots und die Beispielfahrt.

**Karten:** Tour-Detail, Karte aller Fahrten und Vergleich sind `MKMapView` mit den Overlays aus `WattspurMap` (B-186): `RideRouteOverlay` mit `RouteColouring`, `RidesMapOverlay` mit `RidesMapStyle`, `ComparisonRoutesOverlay`, `CurvyRoadsOverlay` und die Kacheln (`CachingTileOverlay`, `MutedTileRenderer`, `TileLoader` mit Cache und User-Agent). Jeder Delegate holt seinen Renderer bei `MapRenderers.renderer(for:)`. In der App bleiben die Hüllen (`RideMapView`, `RidesMapLayer`, `ComparisonMap`), die Legenden, die Quellenangabe (`MapTiles.swift`), `MapBackdrop.swift` für das Kartenbild der PDFs (die Kacheln setzt `TileMosaic` im Paket zusammen) und `CurvyRoads.swift` für Import und Einstellungen der Ebene „Kurvige Straßen“. Das Tour-Detail rechnet seine Werte abseits des Hauptthreads (`DetailValues`, R-58).

## iOS (iPhone)

Target `Wattspur iOS` (ab iOS 26, Bundle-ID `io.github.hops-1.wattspur.ios`, Versionen 0.x), Quellen in `iOS/`, Texte in `iOS/Localizable.xcstrings`. `TabView` mit *Übersicht · Fahrten · Karte · Mehr*; „Karte“ ist die Karte aller Fahrten (`RidesMapScreen`, B-227) mit der Logik des Macs aus dem Paket. Die Views zeigen `RideExchange`-Werte, egal ob sie aus der eigenen Datenbank oder dem Ordner kommen. Die Karte einer Fahrt ist `PhoneMapView`, ein `MKMapView` mit den Overlays aus `WattspurMap`, damit sie auch die OpenStreetMap-Stile zeigt (B-226); die Aufnahme-Karte ist `RecordingMapView`, ebenso ein `MKMapView`, der dem Standort folgt oder sich nach der Fahrtrichtung dreht (`MapHeading`). Das Höhenprofil ist Swift Charts. Die Route liegt als Datei mit einem Fingerabdruck im Namen; eine geänderte Fahrt bekommt eine neue Datei (R-62).

**Erweiterung `Wattspur Widgets`** (`iOSWidgets/`): Live-Aktivität der Aufnahme und Widget „Diese Woche“. Eigene Texte, keine iCloud-Entitlements, dieselbe Versionsnummer wie die App.

**Signierung:** Team und Entitlements nur in der ignorierten `Config/Local.xcconfig` (Vorlage `Local.xcconfig.example`), Anleitung in Lern-Notiz [30](learning/30-ios-app.md). Ohne die Datei baut das Projekt für den Simulator im Modus `local` (eigene Bibliothek ohne iCloud). Gebaut wird das iPhone nur lokal (`scripts/ci-local.sh`, Simulator ohne Signierung); GitHub Actions baut nur den Mac und das Paket.

## Tests

`Tests/WattspurCoreTests` (ohne SwiftData), `Tests/WattspurKitTests` (mit In-Memory-Bibliothek), `Tests/TestFixtures` (gemeinsame FIT- und GPX-Dateien). `swift test --no-parallel` im Paket; `--no-parallel`, weil SwiftData beim parallelen Anlegen vieler In-Memory-Container abstürzen kann. Tests, die Ordner anlegen, räumen sie wieder weg. Abdeckung des Kits beim Review: 93 % der Zeilen.

## Entscheidungen (B-259)

- **`RideLibrary` bleibt die eine Tür (B-271, R-34).** Beide Apps brauchen fast alles davon. Die Fassade macht Regel 4 prüfbar, hält Rückgängig und Speichern an einer Stelle und lässt die Dienste `internal`. Sie wird nicht verkleinert. Neue Funktionen kommen als Dienst mit einer dünnen Methode in `RideLibrary`.
- **Große Dateien** (`RideListView`, `ContentView`, `RideDetailView`) werden erst mit B-125 (ein Bereich „Fahrten“) geteilt; jetzt wäre es ein Umbau ohne Nutzen.
- **Keine Änderung am CloudKit-Schema in einem Review-Release.**
- **Öffnet die Bibliothek nicht (B-264, R-41),** halten Mac und iPhone nicht mehr mit `fatalError` an. Der Mac öffnet dann eine leere Bibliothek nur im Speicher, zeigt `LibraryErrorView` statt `ContentView` und startet nichts, was importiert oder synchronisiert; Einstellungen und Import-Fenster zeigen nur einen Hinweis. Das iPhone zeigt die Ansicht statt der Tabs. „Mit leerer Bibliothek starten“ verschiebt die alte mit `LibraryBackup.setAsideDamaged` in einen Ordner „Damaged Library …“; gelöscht wird nichts.

## Offen

| Punkt | Story |
|---|---|
| Sicherung zurückholen, während der Sync an ist | B-265 |
| Import, Neu-Lesen und Nachrechnen in einem `ModelActor` statt zeitlich verschoben auf dem Hauptthread | B-266 |
| Test-Target für Mac- und iPhone-App | B-267 |
| Test auf echten Geräten: Sync aus, importieren, Sync an | B-272 |
| `HighlightsData` hält `Ride`-Objekte und bleibt deshalb in der App; eine Fassung auf `HighlightRide` könnte nach Core | – |
