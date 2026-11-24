# Architektur

Stand: Mac 1.10.5 und iPhone/iPad 1.6.6 (Review Architektur und Sicherheit, B-352; gemeinsame Texte in `Shared/`, B-355; Rest aus dem Review, B-353 bis B-361). Kurz gefasst, wo was liegt, wie die Daten fließen, welche Regeln gelten und was für die Sicherheit gilt. Die Gründe stehen in den Lern-Notizen [25](learning/25-architektur-aufraeumen.md) (Schichten), [34](learning/34-review.md) (Review 0.5.2) und [35](learning/35-review-sicherheit.md) (Review 1.6.2) und [36](learning/36-gemeinsame-texte.md) (gemeinsame Texte). Die Funde der Reviews stehen in [REVIEW-0.5.2](REVIEW-0.5.2.md) und [REVIEW-1.6.2](REVIEW-1.6.2.md).

## Überblick

```
App (macOS)            iOS (iPhone und iPad)     iOSWidgets, iOSShare (Erweiterungen)
Views, Karten-Hülle,   Übersicht, Fahrten,       Live-Aktivität, Widget „Diese Woche“,
PDF, Ordner, Sync      Aufnahme, Kurzbefehle     „Teilen an Wattspur“
  │       │              │        │                 │
  │       ▼              │        └── iOSShared ────┤  ActivityKit, App Intents, App Group
  ├── Shared ────────────┤   Texte und Formate für beide Apps (ohne AppKit/UIKit)
  │   WattspurMap (MapKit, ohne AppKit/UIKit/SwiftUI): Kacheln, Route und Farben,
  │   Karte aller Fahrten, Marker und Cursor; nutzt nur WattspurCore
  │   WattspurSymbols (nur SwiftUI-Formen): die gezeichneten Symbole der Gerätearten,
  │   für Mac, iPhone und Widgets; nutzt nur WattspurCore
  ▼                      ▼                          ▼
WattspurKit (Store)                              WattspurCore allein
SwiftData-Modelle, RideLibrary und ihre Dienste, (kein SwiftData)
Sync, Import-Ablauf, iPhone-Datenbank
  │   re-exportiert
  ▼
WattspurCore (rein)
FIT und GPX, Werttypen, Analysen, Aufnahme-Rechnung, Austauschformat
```

Pfeile zeigen die erlaubte Richtung der Abhängigkeit; zurück darf es nie gehen. `WattspurMap` nutzen beide Apps; am iPhone die Detailkarte, die Kachel „Letzte Fahrt“ und die Aufnahme-Karte (B-226). `WattspurSymbols` nutzen beide Apps und die Widgets, damit jede Geräteart überall gleich aussieht (B-342). `Shared/` ist kein Modul, sondern ein Ordner, den `project.yml` in die Mac-App und die iPhone/iPad-App einbindet, nicht in die Erweiterungen (B-355).

**Größe (21.11.2026, Review 1.6.2):** Mac-App 15 000 Zeilen in 81 Dateien, iPhone/iPad-App 11 200 in 46, `iOSShared`, Widgets und Teilen 880 in 6, `WattspurCore` 9 700 in 73, `WattspurKit` 5 600 in 38, `WattspurMap` 1 100 in 7, `WattspurSymbols` 160 in 1, Tests 14 000 in 95 (810 Tests).

## Regeln

Die Regeln mit ✓ prüft `scripts/check-architecture.sh` (lokal in `scripts/ci-local.sh` und in GitHub Actions).

1. ✓ **`WattspurCore` kennt weder SwiftData noch SwiftUI, AppKit, UIKit, MapKit oder Charts.** Es rechnet auf Werttypen (`RideFigures`, `HighlightRide`, `MapRide`, `ParsedRide`, `RideSample`, `RideExchange`). Die Prüfung erkennt jede Form einer Import-Zeile in Swift 6 (`public import`, `@preconcurrency import`, `import struct …`) und prüft ihre Muster selbst.
2. **`WattspurKit` behält seinen Namen und alle `@Model`-Klassen** (`Ride`, `Bike`, `Rider`, `Goal`, `RouteGroup`, `SourceFile`, `ImportRecord`). Ein Umzug in ein anderes Modul könnte bestehende Bibliotheken unlesbar machen. **Das CloudKit-Schema ist in Production:** neue Felder und Typen ja, nie umbenennen, löschen oder den Typ ändern; jedes neue Feld braucht einen Standardwert oder ist optional. `CloudKitSchemaTests` vergleicht das Modell mit dem Abdruck `Tests/WattspurKitTests/CloudKitSchema.txt` (Typ, Feld, Datentyp, optional/Standardwert; B-353): Fehlt eine Zeile, wird der Test rot. Ein neues Feld bekommt dort eine neue Zeile.
3. **Die Brücken vom Modell zu den Werttypen stehen an wenigen bekannten Orten:** `Store/RideBridges.swift` (dazu `Bike+Statistics.swift` und `DuplicateFacts+Ride.swift`), das Austauschformat in `Store/RideExchange+Store.swift` (`Ride.exchangeRide`, `Bike.exchangeBike`), `Ride.summary` in `Store/Models.swift` und `Ride.isFromiPhone` in `Store/Ride+iPhone.swift` (S-01). Neue Umrechnungen von `Ride` in einen reinen Typ kommen nach `RideBridges.swift`.
4. ✓ **Die Apps schreiben nur über `RideLibrary`** (am iPhone über `PhoneDatabase`, die `RideLibrary` nutzt). `@Query` zum Lesen ist erlaubt, `modelContext.insert/delete/save` und ein eigener `ModelContext(…)` in der App nicht (S-11). Den Container legen nur `App/WattspurApp.swift` und `iOS/PhoneSync.swift` an. Einzige Ausnahme: `App/DemoMode.swift` füllt eine eigene Demo-Bibliothek für Screenshots.
5. **Eine Bibliothek je App.** `WattspurApp` erzeugt sie und gibt sie in die Environment (`@Environment(RideLibrary.self)`). Das Rückgängig-Machen gehört zum Fenster: `library.using(undoManager)`. Ein Rückgängig-Schritt merkt sich die **ID** einer Fahrt, nicht das Objekt: Hat der Sync die Fahrt inzwischen gelöscht, tut ⌘Z nichts (R-27).
6. ✓ **Die iPhone-App (`iOS/`, `iOSShared/`, `iOSWidgets/`, `iOSShare/`) nimmt nichts aus `App/` außer Ressourcen** (Beispielfahrt, Icon) und importiert kein `AppKit`. Die Widgets, die Teilen-Erweiterung und `iOSShared` importieren kein SwiftData. Was beide Apps brauchen, wandert ins Paket, nie per Kopie. Geprüft werden die Quellen der iPhone-Targets in `project.yml`, in beiden Schreibweisen. **Ausnahme `Shared/`** (B-355, S-17 bis S-19): Texte und Formate, die beide Apps gleich zeigen, aber nach Regel 8 nicht ins Kit dürfen (`AnalysisFormat`, `ComparisonFormat`, `HighlightsFormat`, `ImportReport+Text`, `SaveFailureAlert`, `PDFText`, dazu `ValueFormat` für Dauer, Strecke und Tempo). `Shared/` importiert nur SwiftUI, Charts, Foundation und das Kit, nie AppKit oder UIKit, und nutzt nicht das `RideFormat` einer App (die Dauer am Mac hat Sekunden, die am iPhone nicht). Die Texte stehen mit `String(localized:)` oder `LocalizedStringKey` darin; die Übersetzungen hält jede App in ihrem String-Katalog.
7. **Einstellungsschlüssel stehen an einem Ort:** am Mac in `App/AppSettings.swift` (`SettingsKey`), am iPhone in `iOS/PhoneSettingsKey.swift` (`PhoneSettingsKey`). Die Werte nie ändern; eine neue Einstellung bekommt eine neue Zeile. Ausnahmen (S-03): Schlüssel, die nur ein Dienst des Kits braucht, stehen bei ihm (`syncLastSuccess` in `SyncMonitor`); Schlüssel der App Group stehen in `iOSShared` (`WidgetShare.weekSnapshot`); Startargumente für Tests und Bildschirmfotos dürfen verstreut stehen, beginnen aber immer mit `Wattspur`.
8. ✓ **Das Kit enthält keine Texte für die Oberfläche.** Es liefert Fakten (z. B. `ImportReport`, `SyncProblem`), die Apps formulieren sie (`Shared/ImportReport+Text.swift`, am iPhone dazu `iOS/ImportFlowSummary+Text.swift`), jede App hält die Übersetzungen.
9. **Abgeleitete Werte einer Fahrt werden gespeichert und tragen eine Version** (beste Minute, Übersichtsroute, Kurvigkeit, stärkste Steigung; `TrackFigures.version`, dazu `parserVersion` je Leser). Ändert sich die Rechnung, wird die Version erhöht, und `LibraryMaintenance` rechnet ältere Fahrten im Hintergrund nach, in Paketen. Nachgerechnet wird nur **nach oben**: Eine ältere App lässt Werte einer neueren Version in Ruhe (R-28). Eine neue Spalte kommt in `docs/reference/data-exchange.md`, sonst schlägt der Test fehl.
10. ✓ **Gespeichert wird über `LibrarySave.save(_:)`.** Es meldet einen Fehler (`LibrarySave.failedNotification`), und beide Apps zeigen ihn (`Shared/SaveFailureAlert.swift`, `.reportsSaveFailures()`). Ein `try? context.save()` würde den Fehler verschlucken (R-31). Die Prüfung findet jedes `.save()` im Paket, wie auch immer der Kontext heißt (S-02). Ausnahme mit Grund: `Store/LibraryBackup+Rewrite.swift` schreibt eine Sicherung über Core Data mit `try target.save()`, ein Fehler bricht dort ab. **Gelesen wird über `LibraryFetch`** (in einem Dienst `fetch(_:)`, B-354): Ein Fehler kommt einmal je Typ ins Protokoll und als Zahl in den Diagnosebericht. Ein `try? context.fetch` würde aus dem Fehler „nichts gefunden“ machen; die Prüfung findet es. Wer mit „nichts“ nicht weitermachen darf, nimmt `fetchOrThrow(_:)`: Die Suche nach einem Doppel beim Import bricht dann den Import ab, statt die Datei ein zweites Mal anzulegen.
11. ✓ **Versionen stehen an einer Stelle:** Mac in `Config/Mac.xcconfig` (nur `MARKETING_VERSION`; die Build-Nummer rechnet `scripts/build-dmg.sh` aus der Zahl der Commits, sonst gilt `1` aus `project.yml`), iPhone, Widgets und Teilen-Erweiterung gemeinsam in `Config/iOS.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`). `scripts/build-dmg.sh` liest die Mac-Version von dort und baut nur aus einem sauberen Stand (R-04, R-12). Die Prüfung sieht nach, dass alle drei iPhone-Targets `Config/iOS.xcconfig` nutzen und `MARKETING_VERSION` nur in den beiden Dateien steht (S-08, S-09).
12. ✓ **`WattspurMap` kennt weder AppKit noch UIKit, SwiftUI oder SwiftData** (B-186), auch keine Typen wie `NSColor` oder `UIImage`: Die Prüfung verbietet jeden `NS…`- und `UI…`-Typ außer einer kurzen Liste (`NSObject`, `NSError`, `NSString`, `NSMutableData`, Core-Data-Typen; S-12). Es rechnet und zeichnet mit MapKit und Core Graphics. Farben des Systems (Akzent, Grau, Vergleichsfarben) löst die App für hell oder dunkel auf und gibt sie als `CGColor` hinein (`RouteColors`); die übrigen Kartenfarben stehen als Hex-Werte in `MapPalette`, und die Legenden der App bauen ihre Farben daraus. Bilder (Marker, Cursor) liefert das Modul als `CGImage`; die App verpackt sie in ihren Bildtyp. Was nur eine Plattform kann, bleibt in der App: die `…Representable`-Hülle, Maus und Klick (`TrackingMapView`, `NSClickGestureRecognizer`), Tooltips, der Rand beim Einpassen (`NSEdgeInsets`) und die Quellenangabe als Text.
13. ✓ **`WattspurSymbols` enthält nur SwiftUI-Formen** (B-342): kein AppKit, UIKit, SwiftData oder MapKit, keine Texte, also auch kein `Text(` oder `Label(` (S-13). Am iPhone macht `BikeKind.image(size:)` daraus ein Vorlagenbild, weil Menüs und Picker nur Bilder zeigen.

14. ✓ **Keine Build-Dateien und keine Team-ID im Repo** (S-49, S-50). `git ls-files` enthält nichts unter `build/`, `.build/` oder `DerivedData/`, keine `*.xcent` und kein `Config/Local.xcconfig`. Eine Team-ID steht nur in der ignorierten `Config/Local.xcconfig`; die Vorlage `Local.xcconfig.example` hat einen Platzhalter. Die Prüfung nennt nur Dateinamen, nie den Wert.
15. ✓ **Kein Dateiname steht in `App/` und in `iOS/` zugleich** (B-355). Ein gleicher Name ist meist eine Kopie, die auseinanderläuft (S-18: Dauer „00:48:36“ am Mac, „0:48“ am iPad). Gemeinsames kommt nach `Shared/` oder ins Kit. Erlaubt sind nur Dateien, die es je Plattform geben muss und die verschieden sind: `WattspurApp.swift` (Einstieg), `Localizable.xcstrings` (ein Katalog je App), `RideFormat.swift` (Formate für Listen und Aufnahme; am iPhone die kurze Dauer), `RidePDF.swift` (gezeichnet mit AppKit bzw. UIKit), `HighlightsView.swift`, `LibraryErrorView.swift`, `TrashView.swift` (eigene Views je Plattform) und `SampleRide.swift` (der Mac lädt sie in SwiftData, das iPhone in sein Austauschformat). Eine neue Ausnahme kommt mit Grund in diese Liste und in `scripts/check-architecture.sh`.
16. **Eine Ansicht holt im `body` nichts aus dem Store** (B-369). Jeder Fetch liefert neue Modell-Objekte, und SwiftUI beobachtet jedes davon weiter. Was die iPhone-Ansichten zeigen, liest `PhoneLibrary.reload()` und hält es als Wert; was nur eine Seite braucht, lädt sie in `.task` oder in einer Aktion. Ebenso liest außerhalb der Aufnahme keine Ansicht einen Wert, der sich mit jedem GPS-Punkt ändert: die Wurzel der App nur `isRecording`, die Aufnahme-Ansicht `shown`. Ältere Stellen außerhalb der Aufnahme stehen bei B-369.

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

- `Recorder` hat zwei Stände (B-369): `recording` ist immer aktuell und wird nicht beobachtet (Protokoll, Live-Aktivität, CarPlay, Kurzbefehle, Sichern); `shown` sieht die Ansicht und folgt nur, solange das Fenster sichtbar ist, oder bei Start, Ende, Pause und Losfahren (`RecordingDisplay`).
- Das Barometer schreibt auf einer eigenen Queue in `BarometerHistory`; ein GPS-Punkt nimmt den Wert seiner Messzeit, auch wenn er spät verarbeitet wird.
- `RecordingDiagnostics` schreibt je Minute eine Zeile ohne Orte in „Diagnose“ (`RecordingHealth`).
- Jeder Punkt geht sofort in eine Protokolldatei. Nach einem Absturz bietet die App an, weiterzufahren oder zu beenden. Scheitert das Speichern, bleibt das Protokoll liegen und die App sagt es (R-51, R-52).
- Gilt eine Aufnahme als Doppel, wird die vorhandene Fahrt aktualisiert, nicht verworfen (R-53).
- Live-Aktivität und Knopf „Pause“ kommen über `iOSShared` (`RecordingAttributes`, `ToggleRecordingPauseIntent`); Siri und Kurzbefehle über `iOS/RideIntents.swift`. „Fahrt starten“ öffnet die App, weil GPS mit „Beim Verwenden“ nicht aus dem Hintergrund anläuft; „Fahrt beenden“ läuft im Hintergrund (B-370). Was sich in „Bereit“ ändert (Beginn, Gerät), geht als Update in die Live-Aktivität: Im Hintergrund darf die App keine neue starten.

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
| `Recording/` | Rechnung der Aufnahme ohne Sensoren: `RideRecording` (Punkte, Pausen, Strecke, Anstieg), `AltitudeFusion` (Barometer an GPS-Höhe, grobe oder geglättete GPS-Höhe ohne Barometer), `BarometerHistory` (Werte nach Messzeit), `RecordingDisplay` (was die Anzeige erreicht), `RecordingHealth` (Diagnose je Minute), `MotionFusion` (Schräglage, Beschleunigung, Rütteln), `MotionRawLog` (CSV für den Test V-16) |
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
| `Store/Services/` | `ImportService`, `RideService`, `MergeService`, `BikeService`, `ImportLogService`, `GoalService`, `RouteGroupService`, `SyncMergeService`, `RecordingPartsService` (Bosch-Teile zu einer iPhone-Aufnahme, B-274), dazu `LibraryService` (gemeinsame Umgebung und Rückgängig) |
| `Store/LibrarySave.swift` | Speichern an einer Stelle, mit Meldung bei Fehlern |
| `Store/LibraryFetch.swift` | Lesen an einer Stelle: ein Fehler ins Protokoll und in den Diagnosebericht (B-354) |
| `Store/TimeSeriesDamage.swift` | Zeitreihen, die sich nicht lesen lassen: ins Protokoll und in den Diagnosebericht; das Nachrechnen lässt deren gespeicherte Werte stehen (B-268) |
| `Store/LibrarySync*.swift` | Konfiguration mit oder ohne CloudKit; Schema anlegen und Speicher messen (nur Debug) |
| `Store/SyncMergeWatcher.swift`, `SyncMonitor.swift` | Wann Doppel zusammengeführt werden; Stand und Probleme des Sync |
| `Store/PhoneDatabase.swift` | Die Bibliothek des iPhones: liefert `RideExchange`-Werte, speichert Aufnahmen, bearbeitet und löscht |
| `Store/RideExchange+Store.swift` | Fahrten der Bibliothek im Austauschformat für die iPhone-Ansichten |
| `Store/LibraryBackup.swift` | Sicherung und Wiederherstellung als Ordner (SQLite-Backup, Austausch beim Start) |
| `Store/LibraryBackup+Automatic.swift`, `+Rewrite.swift` | Automatische Sicherung (B-302); Sicherung zurückholen bei eingeschaltetem Sync, über Core Data (B-265) |
| `Store/LibraryRecovery.swift` | Bibliothek, die sich nicht öffnen lässt, beiseitelegen (B-264) |
| `Store/BikeDraft.swift` | Entwurf eines Geräts für die Editoren am Mac und am iPhone (B-290) |
| `Store/Ride+iPhone.swift` | Ob eine Fahrt vom iPhone stammt |
| `Store/LibraryMaintenance.swift` | Aufräumen nach dem ersten Fenster, Nachrechnen nach Version, in Paketen |
| `Store/RideBridges.swift` | Modell → Werttypen |
| `Store/CurvyRoadLibrary.swift` | Importierte Regionen als Dateien, nicht in SwiftData und nicht im Backup |
| `Import/` | `FolderImport` (überwachter Ordner), `ImportFlow` (Fragen, Warteschlange, am iPhone Datei für Datei mit Fortschritt und Zusammenfassung), `ImportReport` (Fakten), `ImportInbox` (Ordner „Import“ am iPhone) |

**Dienste:** zustandslose Structs, gebaut aus einer `LibraryEnvironment` (Kontext, Importer, UndoManager, Standard-Bikename). Sie nutzen sich meist in eine Richtung: Import → Zusammenführen → Bikes. Eine Ausnahme ist bekannt (S-05): `ImportService` und `RecordingPartsService` rufen sich gegenseitig, weil eine Bosch-Datei beim Import zu einer Aufnahme passen kann und die Aufnahme-Teile dafür den Import, das Zusammenführen und `RideService` brauchen. Die übrigen stehen für sich.

## App (macOS)

Views in `App/`; große Bereiche in eigenen Ordnern (`Highlights/`, `Analysis/`, `Compare/`). `@Observable`-Hilfsobjekte in der Environment: `FolderWatcher`, `ImportLog`, `NewPathsStore`, `RouteSimilarityStore`, `LibraryBackupCenter`, `MergeSuggestionCenter`, `BikeAssignmentNotice`, `ICloudSync`, `CurvyRoadsStore`. `DemoMode` und `SampleRide` sind für Screenshots und die Beispielfahrt.

**Karten:** Tour-Detail, Karte aller Fahrten und Vergleich sind `MKMapView` mit den Overlays aus `WattspurMap` (B-186): `RideRouteOverlay` mit `RouteColouring`, `RidesMapOverlay` mit `RidesMapStyle`, `ComparisonRoutesOverlay`, `CurvyRoadsOverlay` und die Kacheln (`CachingTileOverlay`, `MutedTileRenderer`, `TileLoader` mit Cache und User-Agent). Jeder Delegate holt seinen Renderer bei `MapRenderers.renderer(for:)`. In der App bleiben die Hüllen (`RideMapView`, `RidesMapLayer`, `ComparisonMap`), die Legenden, die Quellenangabe (`MapTiles.swift`), `MapBackdrop.swift` für das Kartenbild der PDFs (die Kacheln setzt `TileMosaic` im Paket zusammen) und `CurvyRoads.swift` für Import und Einstellungen der Ebene „Kurvige Straßen“. Das Tour-Detail rechnet seine Werte abseits des Hauptthreads (`DetailValues`, R-58).

## iOS (iPhone und iPad)

Target `Wattspur iOS` (ab iOS 26, Bundle-ID `io.github.hops-1.wattspur.ios`, Versionen 1.x), eine App für iPhone und iPad (B-291), Quellen in `iOS/` und `Shared/` (Texte und Formate wie am Mac, B-355), Texte in `iOS/Localizable.xcstrings`. Am iPhone eine `TabView` mit *Übersicht · Fahrten · Karte · Mehr*; am iPad eine Seitenleiste wie am Mac (`iOS/PadLayout.swift`, `NavigationSplitView`) mit Analyse, Highlights und Vergleich (`PadAnalysis`, `PadCompare`). „Karte“ ist die Karte aller Fahrten (`RidesMapScreen`, B-227) mit der Logik des Macs aus dem Paket. Die Views zeigen `RideExchange`-Werte aus der eigenen Datenbank (S-06). Die Karte einer Fahrt ist `PhoneMapView`, ein `MKMapView` mit den Overlays aus `WattspurMap`, damit sie auch die OpenStreetMap-Stile zeigt (B-226); die Aufnahme-Karte ist `RecordingMapView`, ebenso ein `MKMapView`, der dem Standort folgt oder sich nach der Fahrtrichtung dreht (`MapHeading`). Das Höhenprofil ist Swift Charts. Die Route liegt als Datei mit einem Fingerabdruck im Namen; eine geänderte Fahrt bekommt eine neue Datei (R-62).

**Erweiterung `Wattspur Widgets`** (`iOSWidgets/`): Live-Aktivität der Aufnahme und Widget „Diese Woche“. Eigene Texte, keine iCloud-Entitlements, dieselbe Versionsnummer wie die App.

**Erweiterung `Wattspur Share`** (`iOSShare/`, B-301): „Teilen an Wattspur“. Sie prüft geteilte Dateien, Daten und Links mit `SharedItem` (Core), legt FIT und GPX in den Ordner „Shared Imports“ der App Group (`iOSShared/SharedImports.swift`) und öffnet die App mit `wattspur://import`. Die App schiebt die Dateien in den Ordner „Import“ (`ImportInbox.collectShared`), der Rest ist der normale Import. Eigene Texte, nur die App Group, dieselbe Versionsnummer wie die App.

**Signierung:** Team und Entitlements nur in der ignorierten `Config/Local.xcconfig` (Vorlage `Local.xcconfig.example`), Anleitung in Lern-Notiz [30](learning/30-ios-app.md). Ohne die Datei baut das Projekt für den Simulator im Modus `local` (eigene Bibliothek ohne iCloud). Gebaut wird das iPhone nur lokal (`scripts/ci-local.sh`, Simulator ohne Signierung); GitHub Actions baut nur den Mac und das Paket.

## Tests

`Tests/WattspurCoreTests` (ohne SwiftData), `Tests/WattspurKitTests` (mit In-Memory-Bibliothek), `Tests/TestFixtures` (gemeinsame FIT- und GPX-Dateien). `swift test --no-parallel` im Paket; `--no-parallel`, weil SwiftData beim parallelen Anlegen vieler In-Memory-Container abstürzen kann. Tests, die Ordner anlegen, räumen sie wieder weg. Dazu `Tests/WattspurMapTests` für das Karten-Modul (S-07). **Abdeckung** misst `scripts/coverage.sh` über alle drei Test-Bundles (S-33; `swift test --show-codecov-path` zeigt nur das erste und damit zu viel). Beim Review 1.6.2: 89,1 % der Zeilen, `WattspurCore` 96,4 %, `WattspurKit` 89,5 %, `WattspurMap` 29,6 %. Nach B-360 (1.6.6): `WattspurMap` 92,2 %, gesamt 94,4 %; die Kachel-Tests laufen gegen einen Test-Server im Prozess (`FakeTileServer`), nie gegen die echten Server.

## Entscheidungen (B-259)

- **`RideLibrary` bleibt die eine Tür (B-271, R-34).** Beide Apps brauchen fast alles davon. Die Fassade macht Regel 4 prüfbar, hält Rückgängig und Speichern an einer Stelle und lässt die Dienste `internal`. Sie wird nicht verkleinert. Neue Funktionen kommen als Dienst mit einer dünnen Methode in `RideLibrary`.
- **Große Dateien** (`RideListView`, `ContentView`, `RideDetailView`) werden erst mit B-125 (ein Bereich „Fahrten“) geteilt; jetzt wäre es ein Umbau ohne Nutzen.
- **Keine Änderung am CloudKit-Schema in einem Review-Release.**
- **Öffnet die Bibliothek nicht (B-264, R-41),** halten Mac und iPhone nicht mehr mit `fatalError` an. Der Mac öffnet dann eine leere Bibliothek nur im Speicher, zeigt `LibraryErrorView` statt `ContentView` und startet nichts, was importiert oder synchronisiert; Einstellungen und Import-Fenster zeigen nur einen Hinweis. Das iPhone zeigt die Ansicht statt der Tabs. „Mit leerer Bibliothek starten“ verschiebt die alte mit `LibraryBackup.setAsideDamaged` in einen Ordner „Damaged Library …“; gelöscht wird nichts.

- **Analyse, Highlights und Vergleich (B-294):** Die Zahlen liegen in Core: `AnalysisSummary` (Zeitraum oder Auswahl, Summen, Vergleich mit dem Zeitraum davor, Balken), `BarMetric` (Werte und Einheiten), `HighlightsSummary` (Rekorde und Jahre auf `HighlightRide`), `HeatmapCalendar` (Wochenraster der Jahres-Heatmap und Monatsanfänge, B-356), `RideRecord.isNew` (Rekord aus einer Fahrt der letzten 7 Tage) und `ComparisonMarks` (Linien und Symbole je Fahrt). Mac und iPad legen nur die Texte darüber (Regel 8): `AnalysisModel` mit den Überschriften, `HighlightsData` mit den Fahrten nach ID, `ComparisonStyle` mit den Farben.

## Sicherheit (Review 1.6.2)

Geprüft im Review 1.6.2 (B-347 bis B-350, `REVIEW-1.6.2.md`). Was gilt:

- **Dateien von außen** (FIT, GPX, Teilen, „Öffnen mit“, Dateien-App, Ordner am Mac) laufen alle durch dieselben Leser in `WattspurCore`. Der GPX-Leser löst keine externen Entities auf (kein XXE), Entity-Bomben lehnt libxml2 ab; Tests sichern das (S-44). Grenzen: FIT höchstens 50 MB und 2 Mio. Nachrichten (S-38), GPX höchstens 100 MB und 1 Mio. Punkte (S-40), Texte aus der Datei höchstens 200 Zeichen (S-41). Dateinamen behalten nur den letzten Teil; kein Pfad führt aus dem Zielordner.
- **Keine Absturz-Schleife:** Am iPhone wandert eine Datei aus „Import“ vor dem Lesen in einen versteckten Ordner. Liegt sie beim nächsten Start noch dort, geht sie nach „Fehler“, statt neu gelesen zu werden (S-39).
- **App Group und Temp-Dateien:** Die Teilen-Erweiterung schreibt zuerst in einen versteckten Ordner; Reste, die älter als eine Stunde sind, löscht die App (S-42). Kopien in `tmp` werden nach dem Import gelöscht (S-43). Ins Widget gehen nur Wochensummen, keine Orte.
- **Wege von außen:** `wattspur://import` holt nur Dateien, die schon in der App Group oder in „Import“ liegen; andere Links tun nichts. Start und Ende einer Fahrt per Siri oder Kurzbefehl öffnen die App (`openAppWhenRun`), brauchen also ein entsperrtes Gerät. Ohne Entsperren gehen nur Pause und „Bereit“ abbrechen in der Live-Aktivität und die Wochensumme per Siri (bewusst, S-46).
- **Netz:** nur HTTPS, keine ATS-Ausnahme. Kartenkacheln mit eigenem User-Agent ohne persönliche Daten, eigener Cache in `Caches/Tiles` (300 MB), höchstens 4 Verbindungen je Server, kein Vorabladen. Der Update-Hinweis fragt nur die Releases auf GitHub und öffnet nur Links auf das eigene Repo. Die Ortssuche bei Apple bekommt nur einzelne Punkte (Zeitzone am Mac, Ortsname am iPhone); `docs/PRIVACY.md` nennt das (S-47).
- **iCloud:** nur die private CloudKit-Datenbank, kein `CKShare`, keine öffentliche Datenbank.
- **Rechte:** Entitlements und die Texte für Standort und Bewegung passen genau zum Code; die `PrivacyInfo.xcprivacy` der drei iPhone-Targets nennen UserDefaults, Systemstartzeit und Datei-Zeitstempel.
- **Logs und Diagnose:** `Logger` geben öffentlich nur Schritte, Fehlertexte und IDs aus, keine Orte, Namen oder Pfade. Der Diagnosebericht hat keine Positionen; er nennt die Dateinamen des Import-Protokolls und sagt das (S-52).
- **Build:** Das Passwort für die Notarisierung liegt im Schlüsselbund (`notarytool --keychain-profile`), kein `set -x`. Die Ausgabe von `scripts/build-dmg.sh` nennt die Team-ID nicht (S-51), die CI hat nur Leserechte (S-54). Regel 14 hält Build-Dateien und die Team-ID aus dem Repo.

## Offen

| Punkt | Story |
|---|---|
| Import, Neu-Lesen und Nachrechnen in einem `ModelActor` statt zeitlich verschoben auf dem Hauptthread | B-266 |
| Test-Target für Mac- und iPhone-App | B-267 |
| Test auf echten Geräten: Sync aus, importieren, Sync an | B-272 |
