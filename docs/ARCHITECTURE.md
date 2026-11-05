# Architektur

Stand: 1.8.1. Kurz gefasst, wo was liegt und welche Regeln gelten. Die Gründe stehen in der Lern-Notiz [25](learning/25-architektur-aufraeumen.md).

## Überblick

```
App (SwiftUI, macOS)     Views, PDF, Karten, Ordner-Wächter, Einstellungen
  │        iOS (SwiftUI, iPhone)   Übersicht, Fahrten vom Mac (iOS 0.x)
  │          │
  ▼          ▼
WattspurKit (Store)      SwiftData-Modelle, RideLibrary und ihre Dienste, Ordner-Import
  │   re-exportiert
  ▼
WattspurCore (rein)      FIT- und GPX-Leser, Werttypen, Analysen, Filter, Diagnosebericht
```

Pfeile zeigen die erlaubte Richtung der Abhängigkeit; zurück darf es nie gehen.

## Regeln

1. **`WattspurCore` kennt weder SwiftData noch SwiftUI, AppKit oder MapKit.** Es rechnet auf Werttypen (`RideFigures`, `HighlightRide`, `MapRide`, `ParsedRide`, `RideSample`). Der Compiler erzwingt das für Module, die es nicht einbinden; `scripts/check-architecture.sh` prüft, dass keine solche Import-Zeile hineinkommt (läuft in der CI und in `scripts/ci-local.sh`).
2. **`WattspurKit` behält seinen Namen und alle `@Model`-Klassen** (`Ride`, `Bike`, `Rider`, `Goal`, `RouteGroup`, `SourceFile`, `ImportRecord`). Ein Umzug der Klassen in ein anderes Modul könnte bestehende Bibliotheken unlesbar machen.
3. **Die Brücke vom Modell zu den Werttypen steht an einem Ort:** `Store/RideBridges.swift` (und `Bike+Statistics.swift`). Neue Umrechnungen von `Ride` in einen reinen Typ kommen dorthin, nicht in einen Core-Ordner.
4. **Views schreiben nur über `RideLibrary`.** `@Query` zum Lesen ist erlaubt, `modelContext.insert/delete/save` in einer View nicht. Ziele, Bikes, Papierkorb, Zusammenführen: immer eine Methode der Bibliothek.
5. **Eine Bibliothek für die ganze App.** `WattspurApp` erzeugt sie und gibt sie in die Environment (`@Environment(RideLibrary.self)`). Das Rückgängig-Machen gehört zum Fenster: `library.using(undoManager)`.
6. **Die iPhone-App (`iOS/`) nimmt nichts aus `App/` außer Ressourcen** (Beispielfahrt, Icon) und importiert kein `AppKit`. Was beide Apps brauchen, wandert ins Paket, nie per Kopie. `scripts/check-architecture.sh` prüft beides (die Quellen des Targets in `project.yml`).
7. **Einstellungsschlüssel stehen in `App/AppSettings.swift` (`SettingsKey`).** Die Werte nie ändern; eine neue Einstellung bekommt eine neue Zeile.
8. **Das Kit enthält keine Texte für die Oberfläche** (`String(localized:)` nur in der App).
9. **Abgeleitete Werte einer Fahrt werden gespeichert und tragen eine Version** (beste Minute, Übersichtsroute, Kurvigkeit und stärkste Steigung). Ändert sich die Rechnung, wird die Version erhöht (`TrackFigures.version`), und `LibraryMaintenance` rechnet ältere Fahrten im Hintergrund nach. Eine neue Spalte kommt in `docs/reference/data-exchange.md`, sonst schlägt der Test fehl.

## WattspurCore

| Ordner | Inhalt |
|---|---|
| `FIT/` | Container-Decoder, Basistypen, Profil, Anonymisierer |
| `Import/` | `RideImporter` (Protokoll), FIT- und GPX-Importer, `ImportResult` |
| `Ride/` | `ParsedRide`, Samples, Zusammenführen, Reihen für Diagramme, GPX-Schreiber, Kalorienmodell, Routen, Routenähnlichkeit (`RouteSimilarity`, `RouteSignature`, `RouteIndex`), gespeicherte Strecken (`RouteGrouping`: Mitgliedschaft und Vorschläge), beste Minute (`PeakPower`), Steigung an einer Stelle und stärkste Steigung und Gefälle (`RideTrack`) |
| `Analysis/` | Summen und Trends, Rekorde, Vergleich, Karte (Filter, Dichte), neue Wege, Verlauf einer Strecke (`RouteHistory`), Kurvigkeit einer Fahrt (`CurvatureAnalyzer`, mit den Wörtern `Curviness`) und die zusammen gespeicherten Werte `TrackFigures` |
| `Library/` | Reine Typen rund um die Bibliothek: Filter, Quellen, Bike-Statistik, Duplikat-Fakten, Tagesfilter aus den Highlights (`RideDayFilter`), Summen für Woche und Monat der iPhone-Übersicht (`RidePeriodTotals`) |
| `Map/` | Kachelserver (`TileSource`) und Kachel-Rechnung in Web Mercator (`TileMath`, `Tile`, `MercatorRect`); kurvige Straßen von roadcurvature.com: `CurvyRoad`, `CurvyRegion` (eigenes kompaktes Dateiformat), der KMZ/KML-Leser mit eigenem `ZipArchive` |
| `Support/` | Diagnosebericht, Versionen (`AppVersion`), Version und Commit der laufenden App (`AppInfo`, für beide Apps) |

## WattspurKit (Store)

| Teil | Inhalt |
|---|---|
| `Store/Models.swift`, `ImportRecord.swift` | SwiftData-Modelle |
| `Store/RideLibrary.swift` | Die eine Tür für die App; reicht an die Dienste weiter (Übergangsfassade) |
| `Store/Services/` | `ImportService`, `RideService`, `MergeService`, `BikeService`, `ImportLogService`, `GoalService`, `RouteGroupService`, dazu `LibraryService` (gemeinsame Umgebung und Rückgängig) |
| `Store/LibraryBackup.swift` | Sicherung und Wiederherstellung der Mediathek als Ordner (SQLite-Backup, Austausch beim Start) |
| `Store/RideBridges.swift` | Modell → Werttypen |
| `Store/LibraryMaintenance.swift` | Aufräumen nach dem ersten Fenster, auch das Nachrechnen gespeicherter Werte nach Version |
| `Store/CurvyRoadLibrary.swift` | Die importierten Regionen als Dateien in einem Ordner der App; nicht in der SwiftData-Datei und nicht im Backup |
| `Import/FolderImport.swift` | Überwachter Ordner |

**Dienste:** zustandslose Structs, die aus einer `LibraryEnvironment` (Kontext, Importer, UndoManager, Standard-Bikename) gebaut werden. Sie nutzen sich nur in eine Richtung: Import → Zusammenführen → Bikes. `RideService`, `ImportLogService`, `GoalService` und `RouteGroupService` stehen für sich.

## App

Views in `App/`; die großen Bereiche haben eigene Ordner (`Highlights/`, `Analysis/`, `Compare/`). `@Observable`-Hilfsobjekte (`FolderWatcher`, `ImportLog`, `NewPathsStore`, `RouteSimilarityStore` (Suche, gespeicherte Strecken, Vorschläge), `LibraryBackupCenter`, `MergeSuggestionCenter`, `BikeAssignmentNotice`) liegen in der Environment. `DemoMode` und `SampleRide` sind für Screenshots und die Beispielfahrt.

Karten: Alle drei Karten (Tour-Detail, Karte aller Fahrten, Vergleich) sind `MKMapView` mit eigenen Overlays. `MapTiles.swift` bringt die OSM-Kacheln (`TileLoader` mit Cache und User-Agent, `CachingTileOverlay`, `MutedTileRenderer`, `MKMapView.show(_:)`), `MapBackdrop.swift` das Kartenbild der PDFs (Apples Schnappschuss oder zusammengesetzte Kacheln), `MapCustomizePopover.swift` und `MapStyleThumbnail.swift` das Fenster „Karte anpassen“. `CurvyRoads.swift` bringt die Ebene „Kurvige Straßen“: `CurvyRoadsStore` (in der Environment) hält die geladenen Regionen, ein `CurvyRoadsOverlay` mit eigenem Renderer zeichnet nur Straßen, die die Kachel schneiden, dazu Legende und der Abschnitt „Ebenen“ im Fenster „Karte anpassen“. Die Einfärbung der Route nach Kurven steckt in `RideMapView`.

## iOS

Target `Wattspur iOS` in `project.yml` (iPhone, ab iOS 26, Bundle-ID `io.github.hops-1.wattspur.ios`, eigene Versionsnummern 0.x, eigenes Schema), Quellen in `iOS/`, Texte in `iOS/Localizable.xcstrings`. Stand 0.2: `TabView` mit *Übersicht · Fahrten · Mehr*. Das iPhone hat keine SwiftData-Bibliothek: Es liest den Stand, den der Mac in den Import-Ordner schreibt (`RideExchange` im Kern, `PhoneStateWriter` im Kit, Format in [data-exchange](reference/data-exchange.md)), über `ImportFolder` (Lesezeichen auf den gewählten iCloud-Ordner, `NSFileCoordinator`) und `PhoneLibrary` (lokale Kopie für offline). Es rechnet nichts nach und ändert nichts. Ohne Stand zeigt die Übersicht die Beispielfahrt, mit `FITRideImporter` direkt gelesen. Karten sind SwiftUI-`Map` mit `MapPolyline` (`RouteMap`), nicht die `MKMapView`-Karten der Mac-App; das Höhenprofil ist Swift Charts.


**Eigene Datenbank (B-216, B-217, hinter einem Schalter):** `WATTSPUR_IOS_DATABASE` in `Config/iOS.xcconfig` (über `Local.xcconfig` änderbar) landet als `WattspurDatabase` in der Info.plist und wählt `PhoneDatabase.Mode`. `folder` (Standard) ist der Weg von 0.2 oben. `local` öffnet eine SwiftData-Bibliothek mit dem Modell aus dem Kit, ohne CloudKit, zum Ausprobieren im Simulator. `icloud` öffnet dieselbe Bibliothek mit `cloudKitDatabase: .private(…)` und braucht `iOS/Wattspur-iOS-iCloud.entitlements` (über `WATTSPUR_IOS_ENTITLEMENTS`) und den Developer-Account. `PhoneDatabase` (Kit) liefert die Fahrten als `RideExchange`-Werte, daher bleiben Übersicht, Liste und Tour-Detail gleich. Eine Aufnahme geht als GPX durch denselben Import wie am Mac und wird direkt eine Fahrt. Löschen geht mit Papierkorb (30 Tage, wie am Mac). Ab `local` braucht das iPhone den Ordner nicht mehr.

Signierung: `Config/iOS.xcconfig` (automatisch); das Team steht nur in der ignorierten `Config/Local.xcconfig` (Vorlage `Local.xcconfig.example`), Anleitung in der Lern-Notiz [30](learning/30-ios-app.md). Ohne die Datei baut das Projekt für den Simulator. Der Commit für die Versionszeile kommt wie am Mac über das Pre-Build-Script und `Config/Info.plist`.

**Erweiterung (B-223):** Das Target `Wattspur Widgets` (`iOSWidgets/`, WidgetKit, Bundle-ID `io.github.hops-1.wattspur.ios.widgets`) wird in die App eingebettet und zeigt die Live-Aktivität einer Aufnahme und das Widget „Diese Woche“ (B-224). Was App und Erweiterung beide brauchen und nur auf dem iPhone gilt (ActivityKit, App Intents), liegt in `iOSShared/` und gehört zu beiden Targets: `RecordingAttributes` und `ToggleRecordingPauseIntent`. Der Knopf Pause ist ein `LiveActivityIntent`, der im Prozess der App läuft; die App setzt dafür `RecordingControl.togglePause`. Die Erweiterung hat eigene Texte (`iOSWidgets/Localizable.xcstrings`), keine iCloud-Entitlements und dieselbe Versionsnummer wie die App. **Widget (B-224):** App und Erweiterung teilen die App Group `group.io.github.hops-1.wattspur` (in `iOS/Wattspur-iOS.entitlements`, `iOS/Wattspur-iOS-iCloud.entitlements` und `iOSWidgets/WattspurWidgets.entitlements`). Die App legt dort mit `WidgetShare` einen `WeekSnapshot` ab (Kit, `WattspurCore`): die Fahrten der laufenden Woche ohne Motorrad, wie in der Übersicht, und die letzte Fahrt. Das Widget rechnet die Woche selbst aus, damit es am Montag ohne die App bei null beginnt. Die Erweiterung bindet dafür nur `WattspurCore` ein, kein SwiftData. **Kurzbefehle und Siri (B-225):** Die App Intents liegen in der App (`iOS/RideIntents.swift`, Sätze in `iOS/AppShortcuts.xcstrings`). Sie erreichen den `Recorder` und einen kleinen `IntentRouter` über `AppDependencyManager`; „Fahrt beenden“ setzt `Recorder.endRequested`, die Aufnahme öffnet dann „Fahrt speichern“. Die Antworten übersetzt die App selbst (`IntentDialog.app`), sonst zeigte die App Kurzbefehle sie auf Englisch.

Gebaut wird das iOS-Target nur lokal: `scripts/ci-local.sh` baut es für `generic/platform=iOS Simulator` ohne Signierung. In GitHub Actions gibt es keinen iOS-Build (die macOS-Minuten reichen nicht); dort generiert `xcodegen` das Target nur mit.

## Tests

`Tests/WattspurCoreTests` (ohne SwiftData), `Tests/WattspurKitTests` (mit In-Memory-Bibliothek), `Tests/TestFixtures` (gemeinsame FIT- und GPX-Dateien). `swift test --no-parallel` im Paket; `--no-parallel`, weil SwiftData unter macOS 26 beim parallelen Anlegen vieler In-Memory-Container abstürzen kann.

## Offen

- Die Fassade `RideLibrary` kann schrumpfen, wenn die App die Dienste direkt kennt.
- Wartung und Ordner-Import laufen auf dem Hauptthread, nur zeitlich nach hinten gelegt; echtes Hintergrundlaufen bräuchte einen `ModelActor`.
- `HighlightsData` hält `Ride`-Objekte und bleibt deshalb in der App; eine Fassung auf `HighlightRide` allein könnte nach Core ziehen.
- Die App hat kein Test-Target; die Regeln für `AppSettings` und die Views werden von Hand geprüft.
