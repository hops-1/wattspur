# Architektur

Stand: 1.7.0. Kurz gefasst, wo was liegt und welche Regeln gelten. Die Gründe stehen in der Lern-Notiz [25](learning/25-architektur-aufraeumen.md).

## Überblick

```
App (SwiftUI)            Views, PDF, Karten, Ordner-Wächter, Einstellungen
  │
  ▼
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
6. **Einstellungsschlüssel stehen in `App/AppSettings.swift` (`SettingsKey`).** Die Werte nie ändern; eine neue Einstellung bekommt eine neue Zeile.
7. **Das Kit enthält keine Texte für die Oberfläche** (`String(localized:)` nur in der App).

## WattspurCore

| Ordner | Inhalt |
|---|---|
| `FIT/` | Container-Decoder, Basistypen, Profil, Anonymisierer |
| `Import/` | `RideImporter` (Protokoll), FIT- und GPX-Importer, `ImportResult` |
| `Ride/` | `ParsedRide`, Samples, Zusammenführen, Reihen für Diagramme, GPX-Schreiber, Kalorienmodell, Routen, Routenähnlichkeit (`RouteSimilarity`, `RouteSignature`, `RouteIndex`), gespeicherte Strecken (`RouteGrouping`: Mitgliedschaft und Vorschläge), beste Minute (`PeakPower`) |
| `Analysis/` | Summen und Trends, Rekorde, Vergleich, Karte (Filter, Dichte), neue Wege, Verlauf einer Strecke (`RouteHistory`) |
| `Library/` | Reine Typen rund um die Bibliothek: Filter, Quellen, Bike-Statistik, Duplikat-Fakten |
| `Support/` | Diagnosebericht |

## WattspurKit (Store)

| Teil | Inhalt |
|---|---|
| `Store/Models.swift`, `ImportRecord.swift` | SwiftData-Modelle |
| `Store/RideLibrary.swift` | Die eine Tür für die App; reicht an die Dienste weiter (Übergangsfassade) |
| `Store/Services/` | `ImportService`, `RideService`, `MergeService`, `BikeService`, `ImportLogService`, `GoalService`, `RouteGroupService`, dazu `LibraryService` (gemeinsame Umgebung und Rückgängig) |
| `Store/RideBridges.swift` | Modell → Werttypen |
| `Store/LibraryMaintenance.swift` | Aufräumen nach dem ersten Fenster |
| `Import/FolderImport.swift` | Überwachter Ordner |

**Dienste:** zustandslose Structs, die aus einer `LibraryEnvironment` (Kontext, Importer, UndoManager, Standard-Bikename) gebaut werden. Sie nutzen sich nur in eine Richtung: Import → Zusammenführen → Bikes. `RideService`, `ImportLogService`, `GoalService` und `RouteGroupService` stehen für sich.

## App

Views in `App/`; die großen Bereiche haben eigene Ordner (`Highlights/`, `Analysis/`, `Compare/`). `@Observable`-Hilfsobjekte (`FolderWatcher`, `ImportLog`, `NewPathsStore`, `RouteSimilarityStore`, `MergeSuggestionCenter`, `BikeAssignmentNotice`) liegen in der Environment. `DemoMode` und `SampleRide` sind für Screenshots und die Beispielfahrt.

## Tests

`Tests/WattspurCoreTests` (ohne SwiftData), `Tests/WattspurKitTests` (mit In-Memory-Bibliothek), `Tests/TestFixtures` (gemeinsame FIT- und GPX-Dateien). `swift test --no-parallel` im Paket; `--no-parallel`, weil SwiftData unter macOS 26 beim parallelen Anlegen vieler In-Memory-Container abstürzen kann.

## Offen

- Die Fassade `RideLibrary` kann schrumpfen, wenn die App die Dienste direkt kennt.
- Wartung und Ordner-Import laufen auf dem Hauptthread, nur zeitlich nach hinten gelegt; echtes Hintergrundlaufen bräuchte einen `ModelActor`.
- `HighlightsData` hält `Ride`-Objekte und bleibt deshalb in der App; eine Fassung auf `HighlightRide` allein könnte nach Core ziehen.
- Die App hat kein Test-Target; die Regeln für `AppSettings` und die Views werden von Hand geprüft.
