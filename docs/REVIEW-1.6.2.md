# Review iOS 1.6.2 + Mac 1.10.3 – Architektur und Sicherheit

Stand: 21.11.2026 · alle acht Bereiche geprüft auf `main` (d7c1015), 54 Funde. Vier Entscheidungen von Nils sind eingetragen (S-16, S-37, S-46, S-49); **die Liste für 1.6.2 gibt Nils mit diesem PR frei.** Plan und Regeln: `BACKLOG.md`, Abschnitt „iOS 1.6.2 + Mac 1.10.3 – Review: Architektur und Sicherheit“. Vorbild: [REVIEW-0.5.2](REVIEW-0.5.2.md).

**Methode:** `/code-review high` je Bereich, dazu die Prüflisten aus dem Backlog. `/security-review` arbeitet auf einem Diff; auf `main` ohne Änderung gibt es keinen. Darum wurden die Sicherheits-Bereiche von Hand nach der Prüfliste gelesen, und die Datei-Leser mit selbst gebauten feindlichen Dateien gemessen (nur Demo-Daten, Release-Build am Mac).

**Schwere:** **Fehler** (falsches Ergebnis, Absturz, Datenverlust) · **Risiko** (geht heute, bricht leicht) · **Aufräumen** · **Idee**.
**Ziel:** **1.6.2** (klein und sicher, kommt in dieses Release) · **später** (wird eine Story, Nummer in Klammern) · **bleibt** (Nils hat entschieden, nichts zu ändern).

## Übersicht

| Bereich | Story | Stand | Funde |
|---|---|---|---|
| Architektur-Regeln und Prüfskript | B-343 | ☑ geprüft 21.11.2026 | S-01 bis S-14 |
| Große Dateien und doppelte Logik | B-344 | ☑ geprüft 21.11.2026 | S-15 bis S-25 |
| Toter Code, Warnungen, Tests | B-345 | ☑ geprüft 21.11.2026 | S-26 bis S-33 |
| Kit-Grenzen seit 1.8.7 | B-346 | ☑ geprüft 21.11.2026 | S-34 bis S-37 |
| Sicherheit: Datei-Import | B-347 | ☑ geprüft 21.11.2026 | S-38 bis S-45 |
| Sicherheit: Wege von außen | B-348 | ☑ geprüft 21.11.2026 | S-46 |
| Sicherheit: Netz, iCloud, Rechte | B-349 | ☑ geprüft 21.11.2026 | S-47, S-48 |
| Sicherheit: Build und Logs | B-350 | ☑ geprüft 21.11.2026 | S-49 bis S-54 |

**Messwerte auf einen Blick:** 810 Tests grün · Kit, Mac und iPhone ohne Warnung · Abdeckung des Kits 89,1 % (Core 96,4 %, Kit 89,5 %, Map 29,6 %) · `scripts/check-architecture.sh` grün.

---

## B-343 – Architektur-Regeln und Prüfskript

Geprüft am 21.11.2026 auf `main` (d7c1015), nur gelesen.

**Prüfliste**

- [x] Regeln 1–13 in `docs/ARCHITECTURE.md` gegen den Code gelesen (Regel 13 `WattspurSymbols` ist neu seit B-342).
- [x] `scripts/check-architecture.sh` laufen lassen: **„architecture: ok“**, Exit 0. Läuft in `scripts/ci-local.sh` und in `.github/workflows/ci.yml`.
- [x] Neue Targets und Module: `iOSShare/` (Target „Wattspur Share“) ist im Skript bei Regel 4, 6 und „kein SwiftData“ dabei; `WattspurSymbols` hat eine eigene Prüfung; `WattspurMapTests` braucht keine.
- [x] Regel 3 (Brücken): alle `extension Ride/Bike/Rider/…` im Kit gesucht.
- [x] Regel 4: `ModelContext(`, `ModelContainer(`, `mainContext` in den Apps gesucht. Nur `App/WattspurApp.swift` und `iOS/PhoneSync.swift` legen den Container an (erlaubt), geschrieben wird nur in `DemoMode.swift`.
- [x] Regel 7: alle `forKey: "…"`, `@AppStorage(…)` und `… Key = "…"` außerhalb der beiden Schlüssel-Dateien gesucht.
- [x] Regel 8: `LocalizedError`, `errorDescription`, Texte in Anführungszeichen im Kit gesucht. Nur durchgereichte Systemtexte (`localizedDescription`) und der englische Diagnosebericht. In Ordnung.
- [x] Regel 10: alle `.save()` im Paket gesucht.
- [x] Regel 11: `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `CFBundle…Version` in `project.yml`, `Config/`, Plists und Skripten gesucht.
- [x] Regel 2: vorhandene Tests zum Schema gelesen (`CloudKitSchemaTests`, `DataExchangeDocTests`).

**Messwerte (21.11.2026, Zeilen in Swift-Dateien)**

| Teil | Zeilen | Dateien | Im Dokument (8.11.2026) |
|---|---|---|---|
| Mac-App `App/` | 15 003 | 81 | 15 300 in 80 |
| iPhone/iPad `iOS/` | 11 233 | 46 | 4 600 in 30 |
| `iOSShared`, `iOSWidgets`, `iOSShare` | 877 | 6 | 440 |
| `WattspurCore` | 9 665 | 73 | 8 400 in 61 |
| `WattspurKit` | 5 599 | 38 | 4 300 in 31 |
| `WattspurMap` | 1 065 | 7 | – |
| `WattspurSymbols` | 158 | 1 | – |
| Tests | 13 976 | 95 | 10 900 in 76 |
| `@Test` im Paket | 810 | | 653 |

Prüfskript: grün. Regeln mit ✓: 1, 4, 6, 8, 10, 12, 13. Ohne Prüfung: 2, 3, 5, 7, 9 (hat einen Test), 11.

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-01 | Aufräumen | `docs/ARCHITECTURE.md` Regel 3 | Es gibt mehr Brücken vom Modell zu Werttypen als die drei genannten Dateien: `Ride.exchangeRide`/`Bike.exchangeBike` in `Store/RideExchange+Store.swift:16/50`, `Ride.summary` → `RideSummary` in `Store/Models.swift:206`, `Ride.isFromiPhone` in `Store/Ride+iPhone.swift`. | Die Dateien in Regel 3 nennen (oder `summary` nach `RideBridges.swift` schieben). Nur Text. | 1.6.2 |
| S-02 | Aufräumen | `scripts/check-architecture.sh:118` | Die Prüfung für Regel 10 findet nur `context.save(` / `Context.save(`. `try target.save()` in `Store/LibraryBackup+Rewrite.swift:174` geht durch: Das ist Core Data mit `try` und in Ordnung, aber nirgends als Ausnahme genannt. `try? ctx.save()` oder `store.save()` würde die Prüfung auch nicht finden. | Muster breiter fassen (jede `.save()` auf einem Kontext im Paket) und `LibraryBackup+Rewrite.swift` als Ausnahme mit Grund in Skript und Regel 10 eintragen. | 1.6.2 |
| S-03 | Aufräumen | `docs/ARCHITECTURE.md` Regel 7 | Schlüssel stehen auch an anderen Orten: im Kit `syncLastSuccess` (`Store/SyncMonitor.swift:95`), in der App Group `weekSnapshot` (`iOSShared/WidgetShare.swift:10`), dazu rund 30 Test-Schalter `Wattspur…` verteilt in `App/DemoMode.swift`, `App/WattspurApp.swift`, `App/LibraryBackupView.swift`, `App/UpdateChecker.swift`, `iOS/WattspurApp.swift`, `iOS/Recorder.swift`, `iOS/PhoneSync.swift`. | In Regel 7 nennen: Kit-Schlüssel stehen beim Dienst, App-Group-Schlüssel in `iOSShared`, Test-Schalter (Startargumente) dürfen verstreut sein, beginnen aber immer mit `Wattspur`. | 1.6.2 |
| S-04 | Aufräumen | `docs/ARCHITECTURE.md` Kopf und „Größe“ | „Stand: Mac 1.8.7 und iPhone 0.5.2 (Review, B-259)“ und die Zahlen vom 8.11.2026 sind alt (siehe Messwerte). Im Überblick fehlt `iOSShare`, und dort steht nur „iOS (iPhone)“, nicht das iPad. | Stand auf Mac 1.10.3 / iOS 1.6.2 (B-343) setzen, Zahlen neu, `iOSShare` und iPad ins Bild. | 1.6.2 |
| S-05 | Aufräumen | `docs/ARCHITECTURE.md` „WattspurKit (Store)“ | Es fehlen `Store/BikeDraft.swift` (Bike-Editor Mac und iPhone, B-290), `Store/LibraryRecovery.swift` (B-264), `Store/LibraryBackup+Automatic.swift` (B-302), `Store/LibraryBackup+Rewrite.swift` (B-265), `Store/Ride+iPhone.swift`. In der Liste `Store/Services/` fehlt `RecordingPartsService` (B-274). Die Richtung „Import → Zusammenführen → Bikes“ stimmt nicht mehr ganz: `RecordingPartsService` nutzt `ImportService`, `MergeService` und `RideService`, und `ImportService` nutzt `RecordingPartsService` (ein Kreis). | Zeilen ergänzen; die Nutzung der Dienste ehrlich beschreiben (Kreis Import ↔ Aufnahme-Teile nennen). | 1.6.2 |
| S-06 | Aufräumen | `docs/ARCHITECTURE.md` „iOS (iPhone)“ | „Versionen 0.x“ (jetzt 1.6); nur „`TabView` mit Übersicht · Fahrten · Karte · Mehr“, das iPad hat eine Seitenleiste (`iOS/PadLayout.swift`, `NavigationSplitView`); „egal ob sie aus der eigenen Datenbank oder dem Ordner kommen“, den Ordner-Weg gibt es seit B-263 nicht mehr. | Abschnitt auf iPhone und iPad umschreiben. | 1.6.2 |
| S-07 | Aufräumen | `docs/ARCHITECTURE.md` „Offen“ | B-265 (Sicherung zurückholen mit Sync an) ist umgesetzt (Commit e874552, Release 1.8.12), steht aber noch als offen. Unter „Tests“ fehlt `WattspurMapTests`. | Zeile streichen, Tests-Abschnitt ergänzen. | 1.6.2 |
| S-08 | Aufräumen | `docs/ARCHITECTURE.md` Regel 11 | Regel 11 nennt für den Mac `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` in `Config/Mac.xcconfig`. Dort steht nur `MARKETING_VERSION`; die Build-Nummer kommt aus `scripts/build-dmg.sh` (Zahl der Commits), sonst gilt `CURRENT_PROJECT_VERSION: "1"` aus `project.yml`. „iPhone und Widget gemeinsam“: die Teilen-Erweiterung nutzt `Config/iOS.xcconfig` auch. | Text richtigstellen. | 1.6.2 |
| S-09 | Idee | `scripts/check-architecture.sh` | Regel 11 wird nicht geprüft. Ein falsches `configFiles` bei „Wattspur Widgets“ oder „Wattspur Share“ fiele erst beim Upload auf (R-04). | Prüfen: alle drei iPhone-Targets haben in `project.yml` `Config/iOS.xcconfig`, und `MARKETING_VERSION` steht nur in den beiden xcconfig-Dateien. | 1.6.2 |
| S-10 | Aufräumen | `scripts/check-architecture.sh:1-7` | Der Kopf-Kommentar ist alt: Er nennt für Core nur SwiftData, SwiftUI, AppKit, MapKit (geprüft werden auch UIKit und Charts) und nennt weder `WattspurSymbols` noch die Teilen-Erweiterung. | Kommentar anpassen. | 1.6.2 |
| S-11 | Idee | `scripts/check-architecture.sh:107` | Regel 4 sucht nach Namen mit „context“. `let c = ModelContext(container); c.insert(…)` in einer App ginge durch. | `ModelContext(` in `App/` und `iOS*/` verbieten (Ausnahme `DemoMode.swift`). | 1.6.2 |
| S-12 | Idee | `scripts/check-architecture.sh:43` | Die Typ-Liste für Regel 12 fehlt u. a. `Screen`, `TraitCollection`, `GestureRecognizer`, `Window` (`NSScreen`, `UITraitCollection`, …). Heute nutzt `WattspurMap` keinen davon. | Liste ergänzen oder umdrehen: jedes `\b(NS|UI)[A-Z]` außer `NSObject`, `NSManagedObject…`, `NSMutableData`, `NSError`, `NSString` verbieten. | 1.6.2 |
| S-13 | Idee | `scripts/check-architecture.sh:50` | „Keine Texte“ für `WattspurSymbols` (Regel 13) prüft nur `String(localized`/`LocalizedStringKey`. `Text("…")` macht in SwiftUI still einen `LocalizedStringKey` und würde nicht auffallen. Heute ist kein `Text(` im Modul. | Für `WattspurSymbols` auch `Text\(` und `Label\(` verbieten. | 1.6.2 |
| S-14 | Idee | `Tests/WattspurKitTests/CloudKitSchemaTests.swift` | Regel 2 (CloudKit-Schema: nie umbenennen, löschen, Typ ändern) prüft nur die Namen der Typen und, über `DataExchangeDocTests`, dass jede Spalte dokumentiert ist. Ein geänderter Typ oder ein Feld ohne Standardwert fiele nicht auf. | Story: „Schema-Abdruck im Test“ – eine Datei mit Typ, Feld, Datentyp und optional/Standardwert; der Test vergleicht und erlaubt nur neue Zeilen. **Fertig, wenn** ein umbenanntes, gelöschtes oder umgetyptes Feld den Test rot macht und ein neues optionales Feld grün bleibt. | später (B-353) |

**Bewertung:** Die Schichten halten. Das Prüfskript ist grün und deckt die neuen Targets (`iOSShare`, `WattspurSymbols`) schon ab. Das Dokument ist aber zwei Releases hinterher: Stand, Zahlen, Kit-Tabelle, iPhone-Abschnitt und „Offen“ sind alt (S-04 bis S-08). Das sind reine Textänderungen für 1.6.2. Die Lücken im Skript (S-02, S-09, S-11 bis S-13) sind je ein paar Zeilen und sicher. Nur der Schema-Abdruck (S-14) ist eine eigene Story.

---

## B-344 – Große Dateien und doppelte Logik

Geprüft am 21.11.2026 auf `main` (d7c1015): `/code-review high` über `App/`, `iOS/` und `iOSShared/`, dazu ein Abgleich aller gleichnamigen Dateien und Funktionen in Mac und iPhone/iPad.

**Prüfliste:**
- Dateien über 600 Zeilen: 8 (siehe Messwerte). `RideListView`, `ContentView` und `RideDetailView` am Mac bleiben nach der Entscheidung aus B-259 bis B-125 („ein Bereich Fahrten“); dafür kein neuer Fund.
- `iOS/HighlightsView.swift` und `iOS/MorePages.swift` sind schon nach `// MARK` in eigenständige `private struct` geteilt. Ein Teilen in Dateien ist reines Verschieben; geprüft: keiner der Typnamen kommt in `iOS/` ein zweites Mal vor.
- `iOS/PadAnalysis.swift` und `iOS/PadCompare.swift` sind groß, weil sie die Texte des Macs kopieren (S-17, S-18). Ohne die Kopie wären es etwa 490 und 520 Zeilen.
- `GPXRideImporter.swift`: Leser (XML) und Aufbereitung stehen in einer Datei; der Leser lässt sich sauber lösen (S-24).
- Regel 6 („was beide brauchen, wandert ins Paket, nie per Kopie“) und Regel 8 („keine Texte im Kit“) widersprechen sich bei Texten. Darum sind heute etwa **350 Zeilen Texte und Formate** zwischen Mac und iPad kopiert. Die reine Rechnung (Analyse, Rekorde, Vergleich) liegt schon im Kit (B-294); kopiert ist nur die Schicht darüber.
- Kopien, die schon auseinanderlaufen: Dauer im Vergleich (S-18), Dateinamen und Schlusszeile der PDFs (S-22), Linie über Lücken im PDF (S-15).

**Messwerte:**
- Swift-Dateien: Mac `App/` 81 Dateien, 15 003 Zeilen · iPhone `iOS/` 46 Dateien, 11 233 Zeilen · `iOSShared/` 3 / 154 · `iOSWidgets/` 2 / 492 · `iOSShare/` 1 / 231 · Kit-Quellen 120 / 16 532.
- Über 600 Zeilen: `iOS/HighlightsView.swift` 1 062, `iOS/MorePages.swift` 971, `App/RideListView.swift` 941, `App/RideDetailView.swift` 745, `App/ContentView.swift` 702, `GPXRideImporter.swift` 669, `iOS/PadAnalysis.swift` 626, `iOS/PadCompare.swift` 622.
- Wörtlich oder fast wörtlich kopiert (Mac ↔ iPad): Analyse-Texte ~110 Zeilen, Vergleichs-Texte ~100, Highlights-Texte ~95, Jahres-Heatmap (Raster und Monatsnamen) ~20, `SaveFailureAlert` 23 (identisch), `ImportReport+Text` 41 (identisch), `prepareBrokenLibraryTest` 9 (identisch), Farbwerte an 6 Stellen.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-15 | Fehler | `iOS/RidePDF.swift:60`, `iOS/ReportPDF.swift:63` | Das PDF einer Fahrt und das PDF des Vergleichs am iPhone/iPad ziehen die Linie **über eine Lücke im Track** (z. B. Bahnfahrt ohne Aufnahme). B-309 verlangt „PDF der Fahrt“ ohne Linie über die Lücke; der Mac teilt mit `TrackGap.split` (`App/PDFExport.swift:95`), die iPhone-PDFs entstanden später und tun es nicht. | In beiden `mapImage` die Punkte mit `TrackGap.split` in Stücke teilen und jedes Stück einzeln zeichnen, wie am Mac | 1.6.2 |
| S-16 | Risiko | `iOS/RideFormat.swift:11` | Nur `RideFormat.distance` zeigt in Ländern ohne metrisches System **Meilen**. Alles andere am iPhone/iPad ist fest metrisch: Tempo (`km/h`), Rekorde (`HighlightTexts.value`: „km“), Ziele („Kilometres“), Vergleich (`CompareTexts.unit`: „km“, „km/h“). In den USA oder Großbritannien stehen dann „12,4 mi“ in der Liste und „20,0 km“ beim Rekord derselben Fahrt. Der Mac zeigt immer km. | **Entscheidung Nils:** entweder wie am Mac immer km (eine Zeile, `.kilometers`) oder Meilen überall als eigene Story | 1.6.2 (**Entscheidung Nils 21.11.2026:** immer km, wie am Mac) |
| S-17 | Aufräumen | `iOS/PadAnalysis.swift:489–620` ↔ `App/Analysis/AnalysisFormat.swift`, `App/Analysis/AnalysisModel.swift:40–70` | Die Texte der Analyse sind wörtlich kopiert: `hoursMinutes`, `whole`, `number`, `percent`, `bucketShort`, `bucketTitle`, `heading`/`title`, `subheading`, `previousName`, `comparisonCaption`, dazu `AnalysisPeriodKind.label`, `AnalysisGrouping.label`/`perLabel`. Ebenso identisch: `SaveFailureAlert.swift` und die ersten 41 Zeilen von `ImportReport+Text.swift` in beiden Apps. Grund ist der Widerspruch zwischen Regel 6 und Regel 8. | Story „Gemeinsame Texte für Mac und iPad“: ein Ordner `Shared/` (kein Kit-Modul) in beiden Targets in `project.yml`, die Übersetzungen bleiben in beiden String-Katalogen; Regel 6 um diese Ausnahme ergänzen. **Fertig, wenn:** jede der genannten Funktionen nur einmal im Repo steht, beide Apps bauen und die Texte am Mac und iPad gleich aussehen | später (B-355) |
| S-18 | Aufräumen | `iOS/PadCompare.swift:515–612` ↔ `App/Compare/ComparisonFormat.swift` | `CompareTexts` ist eine Kopie von `ComparisonFormat` (`title` ×2, `value`, `deviation`, `number`, `unit`, `shortDuration`). Die Kopie läuft schon auseinander: `value` zeigt Dauern am Mac als „00:48:36“ (Mac-`RideFormat.duration`), am iPad als „0:48“ (iPhone-`RideFormat.duration` ist `.hourMinute`); der Kommentar am iPad verspricht „0:48:36“. | Mit S-17 in dieselbe Story; bis dahin am iPad die Dauer mit Sekunden zeigen oder den Kommentar richtigstellen | später (B-355) |
| S-19 | Aufräumen | `iOS/HighlightsView.swift:967–1062` ↔ `App/Highlights/HighlightsFormat.swift` | `HighlightTexts` ist eine Kopie von `HighlightsFormat`: alle 12 Funktionen (`title` ×3, `value`, `text`, `display`, `unit`, `number`, `currentPeriod`, `shortDate`, `longDate`). | Mit S-17 in dieselbe Story | später (B-355) |
| S-20 | Idee | `iOS/HighlightsView.swift:430–483, 578` ↔ `App/Highlights/YearReview.swift:204–259`, `App/Highlights/Records.swift:50` | Logik ohne Texte, doppelt in beiden Apps: das Wochenraster der Jahres-Heatmap (`weeks`: Lücke vor dem 1. Januar nach `firstWeekday`, Tage in Wochen), `monthLabel` und `isNew` (Rekord aus einer Fahrt der letzten Tage). Das ist reine Kalender-Rechnung und gehört nach Regel 6 ins Kit. | Story: `YearHeatmap.weeks(year:calendar:)` und `monthStarts` in `WattspurCore/Analysis` neben `RidingDay`, `isNew` als Methode an `RideRecord` mit `now`-Parameter; Tests für Jahre, die an einem Sonntag/Montag beginnen, und Schaltjahre. **Fertig, wenn:** Mac und iPad die Kit-Funktionen nutzen und die Tests grün sind | später (B-356) |
| S-21 | Aufräumen | `App/Compare/ComparisonStyle.swift:13`, `iOS/PadCompare.swift:124`, `App/RideChartsView.swift:298`, `iOS/PadAnalysis.swift:623`, `iOS/RideFormat.swift:88`, `iOS/RidePDF.swift:80` | Dieselben Farbwerte stehen doppelt als Hex-Zahlen: die vier Farben des Vergleichs, die Farben für Tempo, Trittfrequenz und Leistung und das Magenta der Spur (am iPhone zweimal). Ändert jemand eine Seite, sehen Mac und iPad verschieden aus. Regel 12 sieht für Kartenfarben schon `MapPalette` mit `Pair(light:dark:)` vor. | Die Paare als `MapPalette.comparison`, `MapPalette.metricSpeed/Cadence/Power` und `MapPalette.track` ins Kit; beide Apps lesen sie von dort. Gleiche Werte, also keine sichtbare Änderung | 1.6.2 |
| S-22 | Aufräumen | `iOS/ReportPDF.swift:43` ↔ `App/PDFExport.swift:175` | Zwei Regeln für Dateinamen der PDFs: der Mac ersetzt nur `/` und `:`, das iPhone auch `\ ? % * \| " < >`. Eine Fahrt „Tour 50%?“ heißt so am Mac anders als am iPhone. Auch die Schlusszeile ist verschieden (der Mac sagt, dass Kalorien und CO₂ geschätzt sind, das iPhone nicht). | `fileName` als reine Funktion ins Kit (`WattspurCore/Support`, mit Test) und von beiden Apps nutzen; die Schlusszeile in die Story aus S-17 | 1.6.2 |
| S-23 | Aufräumen | `iOS/HighlightsView.swift` (1 062), `iOS/MorePages.swift` (971) | Die zwei größten Dateien der Apps. Beide sind schon nach `// MARK` in eigenständige Views geteilt (Jahr, Rekorde, Ziele, PDF, Texte bzw. Profil, Gerät, Karten, Bibliothek, Hilfe, Über, Test-Werkzeuge). | Story „Große iPhone-Dateien teilen“: je Abschnitt eine Datei, nur verschieben, `private` → `fileprivate`/intern wo nötig; kein Verhalten ändern. **Fertig, wenn:** keine iPhone-Datei über 600 Zeilen, beide Builds ohne Warnung, Diff ohne inhaltliche Änderung | später (B-357) |
| S-24 | Idee | `Packages/…/WattspurCore/Import/GPXRideImporter.swift:475–669` | Der XML-Leser (`RawPoint`, `GPXReader`, `whole`) ist ein eigener Teil, rund 195 Zeilen. Die Datei ist zu 98 % von Tests abgedeckt, das Verschieben ist also gut abgesichert. | Mit S-23: Leser nach `GPXReader.swift` im selben Ordner, `private` → `internal` | später (B-357) |
| S-25 | Aufräumen | `App/LibraryBackupView.swift:28`, `iOS/PhoneSync.swift:120` | `prepareBrokenLibraryTest()` ist in beiden Apps wörtlich gleich (Ordner anlegen, 8 KB Müll schreiben, Konfiguration ohne Sync). Logik ohne Text, also nach Regel 6 ein Fall fürs Kit. | Als `LibraryBackup.prepareBrokenLibraryTest(at:)` ins Kit, beide Apps rufen es mit ihrem Pfad auf | 1.6.2 |

**Bewertung:** Die Rechnung ist sauber im Kit, die Apps doppeln aber die Schicht darüber: Texte, Formate, Farben und ein paar Kalender-Helfer. Das ist die Folge einer Lücke in den Regeln (6 gegen 8), kein Wildwuchs. Spürbar ist es schon an drei Stellen, wo die Kopien auseinanderlaufen, am deutlichsten beim PDF (S-15, ein echter Fehler). Für 1.6.2 passen S-15, S-21, S-22 und S-25 (klein, ohne sichtbare Änderung) und die Entscheidung zu S-16. Das große Aufräumen (S-17 bis S-20, S-23, S-24) lohnt als zwei Stories für später: „Gemeinsame Texte“ und „Große iPhone-Dateien teilen“.

---

## B-345 – Toter Code, Warnungen und Tests

Geprüft am 21.11.2026 auf `main` (d7c1015): Suche nach ungenutzten öffentlichen Typen und Funktionen im Kit und in den Apps, nach Einstellungsschlüsseln ohne Leser, nach Resten des alten Ordner-Wegs und der Spikes; drei Builds aus einem frischen Stand; Abdeckung des Kits über alle drei Test-Bundles.

**Prüfliste:**
- Einstellungsschlüssel: jeder Schlüssel in `SettingsKey` (Mac) und `PhoneSettingsKey` (iPhone) wird gelesen. Keine Schlüssel als feste Zeichenkette an `@AppStorage` oder `UserDefaults` vorbei (Regel 7 eingehalten); Ausnahmen sind nur die Startargumente `Wattspur…` für Tests und Screenshots.
- Alter Ordner-Weg (iPhone 0.2 bis 0.5): Code für den Austausch ist weg. Übrig sind nur der Hinweis „Ordner beendet“ und das Lesen des alten Lesezeichens (S-28).
- Spikes: V-16 (rohe Bewegung) lebt nur noch hinter dem Schalter „Test-Werkzeuge“ (nur Debug und TestFlight, `BuildChannel`) – in Ordnung. Die Werkzeuge `-WattspurInitCloudKitSchema` und `-WattspurMeasureCloudKit` am Mac stehen in `#if DEBUG`; `LibrarySync+Schema` und `LibrarySync+Usage` (0 % Abdeckung) werden für das Ausrollen des CloudKit-Schemas gebraucht und bleiben.
- Ungenutzter Code: `CalorieEstimator` (S-26) und `CurvyRoadsStore.dismissFailure()` (S-27). Sonst keine öffentlichen Typen oder Funktionen ohne Nutzer gefunden.

**Messwerte:**
- `swift build --build-tests` (Kit, Debug): **0 Warnungen**.
- Mac-App (Debug, ad hoc ohne Team): **0 Warnungen**; dazu der bekannte harmlose Hinweis „Metadata extraction skipped, no AppIntents.framework dependency found“. R-16 aus 0.5.2 ist also erledigt.
- iPhone-App mit Widget und Teilen-Erweiterung (Debug, Simulator, ohne Signierung): **0 Warnungen**.
- `swift test --no-parallel --enable-code-coverage`: **810 Tests grün** (404 in 53 Suites, 395 in 66 Suites, 11 in 1 Suite für `WattspurMap`).
- **Abdeckung des Kits: 89,1 % der Zeilen** (11 577 Zeilen, 1 258 nicht getroffen), gemessen über alle drei Test-Bundles. Je Modul: `WattspurCore` 96,4 %, `WattspurKit` 89,5 %, `WattspurMap` **29,6 %**; `WattspurSymbols` hat kein Test-Target. Ohne `WattspurMap` wären es 93,6 % (0.5.2: 93,1 %).
- Am schwächsten (Zeilen ohne Test): `MapTiles` 12 % (164), `MapGeometry` 10 % (126), `SyncMonitor` 45 % (118, wie in 0.5.2), `RouteOverlay` 48 % (115), `RidesMapStyle` 30 % (110), `CurvyRoadsOverlay` 0 % (57), `ImportFlow` 81 % (49), `LibraryBackup` 90 % (32), `LibrarySave` 50 % (6).
- Achtung beim Messen: Die Datei von `swift test --show-codecov-path` enthält nur `WattspurCore` und zeigt darum 96,4 % (S-33).

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-26 | Aufräumen | `Packages/…/WattspurCore/Ride/RideMetrics.swift:4–20` | `CalorieEstimator` und `WorkBasedCalorieEstimator` nutzt niemand, weder die Apps noch die Tests. Die Apps rechnen mit `CalorieModel`. | Beide Typen löschen | 1.6.2 |
| S-27 | Aufräumen | `App/CurvyRoads.swift:101` | `dismissFailure()` ruft niemand auf. Eine Fehlermeldung beim Import der „Kurvigen Straßen“ bleibt darum in den Einstellungen stehen, bis ein späterer Import gelingt. | Beim neuen Öffnen des Datei-Dialogs (`chooseFiles`) aufrufen, sonst löschen | 1.6.2 |
| S-28 | Idee | `iOS/PhoneSync.swift:36–46`, `iOS/PhoneSettingsKey.swift:28, 35` | Rest des alten Ordner-Wegs: der einmalige Hinweis „Austausch über den Ordner beendet“ für Nutzer von iPhone 0.2 bis 0.5. Er wirkt nur noch bei Nutzern, die von 0.5 direkt aktualisieren. | Story: Hinweis und das Lesen von `importFolderBookmark` mit einer großen Version (z. B. 2.0) entfernen; die Schlüssel bleiben stehen (Regel 7). **Fertig, wenn:** kein Code den alten Ordner mehr kennt | später (B-358) |
| S-29 | Risiko | `Packages/…/WattspurKit/Import/ImportFlow.swift:289–297, 319–330` | Zwei Wege, die nach einer Wahl des Nutzers Daten schreiben, hat kein Test: `importAsNew` (Duplikat trotzdem als neue Fahrt) und `updatePlainDuplicates` (Duplikate mit der Datei ergänzen). Auch der Fehlerfall dort (`failedUpdates`, Zeile 281) ist ohne Test. | Tests in `ImportFlowTests` mit den vorhandenen Fixtures: neue Fahrt entsteht, Rad stimmt, Zähler stimmen; Ergänzen ändert die vorhandene Fahrt; kaputte Datei landet in `failedFileNames` | 1.6.2 |
| S-30 | Risiko | `Packages/…/WattspurKit/Store/LibraryBackup.swift:285–300`, `LibraryRecovery.swift:28–32` | Das Zurücklegen nach einem halb gescheiterten Wiederherstellen (alte Dateien zurück, neue weg) ist nie getestet, ebenso das Aufräumen nach einer halben Sicherung (Zeile 83, 103). Das ist genau der Weg, der vor Datenverlust schützt. | Tests mit einem schreibgeschützten Zielordner oder einer Datei, die im Weg liegt, so dass `moveItem` scheitert; prüfen, dass die alte Bibliothek danach unverändert da ist. Geht das ohne Umbau nicht, als Story für später | 1.6.2 |
| S-31 | Risiko | `Packages/…/WattspurKit/Store/LibrarySave.swift:21–24` | Der Fehlerweg von `LibrarySave.save` (Log und `failedNotification`, R-31) ist nie getestet. Bricht er, verschluckt die App wieder Speicherfehler, ohne dass ein Test rot wird. | Story: den Kontext hinter ein kleines Protokoll legen oder eine Fehler-Attrappe einspeisen, Test erwartet die Notification mit Text. **Fertig, wenn:** der Fehlerweg einen Test hat | später (B-359) |
| S-32 | Idee | `Packages/…/WattspurMap/` (29,6 %) | Das Karten-Modul ist kaum getestet: `MapTiles` (Kachel-URL, Cache, User-Agent) 12 %, `MapGeometry` 10 %, `RidesMapStyle` 30 %, `RouteOverlay` 48 %, `CurvyRoadsOverlay` 0 %. Dazu `SyncMonitor` 45 % wie schon in 0.5.2 (R-14). | Story: Tests für die Kachel-URL je Stil, den Cache (Treffer, Ablauf, Größe) und den User-Agent sowie für `MapGeometry` (Einpassen, Lücken); Ziel über 70 % für `WattspurMap`. **Fertig, wenn:** die Abdeckung von `WattspurMap` über 70 % liegt | später (B-360) |
| S-33 | Aufräumen | `docs/ARCHITECTURE.md` (Tests), Messung | Mit drei Test-Bundles enthält die Datei von `swift test --show-codecov-path` nur `WattspurCore` (96,4 %). Die richtige Zahl über alle Bundles ist 89,1 %. ARCHITECTURE nennt noch 93 % aus 0.5.2. Wer nach der Anleitung misst, sieht eine zu gute Zahl. | Kleines Skript `scripts/coverage.sh`: `llvm-profdata merge` über alle `.profraw`, dann `llvm-cov export` mit allen drei `.xctest`-Binärdateien, Ausgabe je Modul; Zahl in ARCHITECTURE auf 89 % (je Modul) setzen, passt zu B-352 | 1.6.2 |

**Bewertung:** Sehr wenig Ballast. Alle drei Builds sind ohne Warnung, alle 810 Tests grün, Einstellungsschlüssel und Spikes sind ordentlich abgegrenzt. Toter Code sind nur zwei kleine Reste (S-26, S-27). Die Abdeckung ist im Kern sehr gut (96 %), im Store gut (90 %), im Karten-Modul schwach (30 %); die Gesamtzahl ist mit dem neuen Modul auf 89 % gefallen und wurde bisher zu gut gemessen (S-33). Wichtiger als die Zahl sind drei ungetestete Wege, die Daten schreiben oder schützen: Import nach Wahl des Nutzers (S-29), Zurücklegen beim Wiederherstellen (S-30) und Speicherfehler (S-31). S-29 und S-30 sind reine Tests und passen in 1.6.2.

---

## B-346 – Kit-Grenzen seit 1.8.7

Geprüft am 21.11.2026 auf `main` (d7c1015) mit `/code-review high` über `Packages/WattspurKit/Sources`, nur gelesen.

**Prüfliste**

- [x] `WattspurMap` (Regel 12): Importe nur `CoreGraphics`, `Foundation`, `ImageIO`, `MapKit`, `UniformTypeIdentifiers`, `WattspurCore`. Keine `NS…`/`UI…`-Typen, keine Texte für die Oberfläche. Bilder als `CGImage`, Farben als `CGColor`/Hex. In Ordnung.
- [x] `TileLoader`: eigener User-Agent, Cache, höchstens 4 Verbindungen, keine Vorab-Downloads, `TileMosaic` höchstens 200 Kacheln. In Ordnung.
- [x] Neue Dienste seit 1.8.7: `BikeDraft`, `RecordingPartsService`, `LibraryBackup+Rewrite`, `LibraryBackup+Automatic`, `LibraryRecovery` gelesen.
- [x] Brücken (Regel 3), siehe S-01.
- [x] Keine Texte im Kit (Regel 8): sauber.
- [x] `try?`: 114 Stellen in `WattspurKit`, 9 in Core, 1 in Map, 0 in Symbols. Die meisten sind Aufräumen von Dateien (in Ordnung). Geprüft: Abrufe aus der Datenbank und Zusammenführen.
- [x] Arbeit auf dem Hauptthread: Dienste sind `@MainActor`; neue teure Stellen gesucht.

**Messwerte:** `WattspurKit` 5 599 Zeilen in 38 Dateien (+1 300 seit 8.11.), davon `RecordingPartsService` 226, `LibraryBackup+Rewrite` 192. `try?` mit `context.fetch` im Kit: 38.

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-34 | Fehler | `Store/Services/RecordingPartsService.swift:47-53` | `joinParts(of:)` schreibt erst Sensorwerte, `attachedSourceName`/`attachedSourceFormat` und Bike der Aufnahme in jedes Bosch-Teil und ruft dann `try? MergeService.merge`. Das wirft `.overlapping`, wenn sich zwei Teile überschneiden (z. B. dieselbe Tour zweimal exportiert). Dann bleibt die Aufnahme, nichts ist zusammengeführt, aber die Teile tragen eine angehängte GPX, die es nicht gibt. Ein späterer Import der GPX gilt als „schon angehängt“ (`ImportService.swift:81`). | Vor der Schleife `MergeService(env).mergeProblem(pieces)` fragen und bei einem Problem `nil` geben. Test: zwei überlappende FIT in einer Aufnahme ändern nichts. | 1.6.2 |
| S-35 | Risiko | `Store/Services/RecordingPartsService.swift:182-224` | Bei jedem FIT- und GPX-Import holen `recording(containing:)`, `boschRides(inside:)` und `recordings(inside:)` alle Fahrten in einem Fenster von 12 h und mehr und lesen über `span(of:)` die ganze Zeitreihe jeder Fahrt, auf dem Hauptthread. Zeile 201 ruft `window(of:)` zweimal, also zweimal lesen. Beim Doppel-Import laufen `joinParts` und `splitAcrossRecordings` zusätzlich. Ein Ordner mit vielen Dateien hängt spürbar. | Klein (1.6.2): `window` je Kandidat einmal rechnen; erst mit gespeicherten Werten (`startDate`, `elapsedTime`, Quelle) filtern und nur die übrigen Zeitreihen lesen. Groß: gehört zu B-266 (`ModelActor`). | 1.6.2 |
| S-36 | Risiko | `Store/Services/ImportService.swift:362/368`, `Store/PhoneDatabase.swift:107-456` | `try?` beim Abruf macht aus einem Fehler „nichts gefunden“, ohne Protokoll. In `findDuplicate` wird eine Datei dann ein zweites Mal importiert; am iPhone zeigen Liste, Ziele und Karte „leer“. Weder Protokoll noch Diagnosebericht sagen etwas. | Story „Abruffehler im Kit melden“: ein `LibraryService.fetch(_:)`, das den Fehler einmal ins Protokoll und in den Diagnosebericht schreibt; `findDuplicate` bricht bei Fehler den Import ab statt neu anzulegen. **Fertig, wenn** ein absichtlich fehlschlagender Abruf im Test keinen zweiten Import anlegt und im Diagnosebericht steht. | später (B-354) |
| S-37 | Risiko | `Store/Services/RecordingPartsService.swift:106` | Kommt die Datei einer Bosch-Fahrt erneut (Doppel, `ImportService.swift:60`) und gibt es inzwischen zwei Aufnahmen darin, löscht `splitAcrossRecordings` die vorhandene Fahrt endgültig (`context.delete`), ohne Papierkorb und ohne Rückgängig. Name, Notiz oder Bike, die Nils an der Fahrt geändert hat, sind weg. | Mit Nils klären, ob das beim Doppel gewollt ist. Sonst die Fahrt in den Papierkorb legen statt löschen, und den Namen übernehmen, wenn er von Hand geändert wurde. | 1.6.2 (**Entscheidung Nils 21.11.2026:** Papierkorb statt löschen, Namen übernehmen) |

(S-01 zu Regel 3 steht oben bei B-343.)

**Bewertung:** Die Grenzen des Kits halten. `WattspurMap` ist frei von AppKit, UIKit und SwiftUI, im Kit stehen keine Oberflächentexte, `WattspurSymbols` ist sauber. `BikeDraft`, `LibraryRecovery`, `LibraryBackup+Automatic` und `LibraryBackup+Rewrite` sind ohne Fund. Das Rewrite schreibt über Core Data direkt (S-02), aber mit `try` und in Paketen. Der eine echte Fehler steckt im neuen `RecordingPartsService` (S-34): klein und sicher zu beheben. Dieselbe Datei ist auch die teuerste neue Stelle auf dem Hauptthread (S-35). Die `try?`-Abrufe (S-36) sind alt und eine eigene Story.

---

## B-347 – Datei-Import

Geprüft am 21.11.2026 auf `main` (d7c1015): `FIT/FITDecoder.swift`, `Import/RideImporter.swift`, `Import/GPXRideImporter.swift`, `Import/SharedItem.swift` (Core), `Import/ImportInbox.swift`, `Import/FolderImport.swift`, `Import/ImportFlow.swift`, `Store/Services/ImportService.swift` (Kit), `iOSShare/ShareViewController.swift`, `iOSShared/SharedImports.swift`, `iOS/PhoneImport.swift`, `App/FolderWatcher.swift`, dazu die Tests `FITHostileInputTests` und `GPXRideImporterTests`.

**Prüfliste:**
- **XXE:** `shouldResolveExternalEntities = false`. Eine GPX mit `<!ENTITY x SYSTEM "file:///etc/hosts">` liest die Datei nicht ein. Gut.
- **Entity-Bombe („billion laughs“):** 10 Ebenen × 10 werden von libxml2 abgelehnt (`malformedXML`, 7 MB Speicher, sofort). Gut. Es gibt aber keinen Test dafür (S-44).
- **Tiefe Verschachtelung:** libxml2 begrenzt die Tiefe selbst; der Stapel im Leser wächst nur mit der Tiefe. Kein Fund.
- **Integer-Überlauf FIT:** Längen sind `UInt8`/`UInt32` und werden als `Int` (64 Bit) gerechnet, jede Lese-Stelle wird geprüft, die Zeitstempel rechnen mit `&+`. Die bestehenden Tests für feindliche FIT-Dateien decken Zeit, Leistung, NaN und Seriennummer ab. Gut.
- **Größe und Punktzahl:** GPX hat Grenzen (200 MB, 5 Mio. Punkte), sie sind aber viel zu hoch fürs iPhone (S-40). **FIT hat gar keine Grenze** (S-38).
- **Lange Texte:** Name, Typ und Gerät aus der GPX haben keine Längengrenze (S-41).
- **Dateinamen und Pfade:** `SharedItem.fileName` nimmt nur den letzten Teil des Namens, ersetzt `/` und `:` und entfernt führende Punkte. `..` wird zu einem Namen aus dem Datum. `ImportInbox.freeName` und `FolderImport.move` bleiben im Zielordner. Kein Pfad-Ausbruch gefunden.
- **App Group („Shared Imports“):** Jede Freigabe kommt in einen eigenen Ordner, zuerst versteckt geschrieben, dann umbenannt. Die App holt die Dateien beim Öffnen nach „Import“ und löscht leere Ordner. Ein halb geschriebener Ordner bleibt aber für immer liegen (S-42).
- **Temp-Dateien:** „Öffnen mit“ und der Dateiauswahl-Dialog kopieren nach `tmp/Opened/<UUID>`, die Kopie wird nach dem Import gelöscht (der leere Ordner bleibt). Beim Ablegen auf dem iPad bleiben die Kopien in `tmp/Dropped` liegen (S-43). `Documents/Inbox` wird nach dem Kopieren geleert (R-49 ist erledigt).
- **Absturz beim Import:** Die Datei in „Import“ wird erst nach dem Lesen verschoben. Ein Absturz beim Lesen wiederholt sich darum bei jedem Start (S-39).
- **Ordner-Import am Mac:** Ein Bookmark mit Security Scope, Lesen über `NSFileCoordinator`, versteckte Dateien und Platzhalter werden übersprungen, Symlinks sind keine normalen Dateien. Die Datei bleibt auch hier liegen, bis sie gelesen ist. Am Mac lagert das System aber aus, statt die App zu beenden.
- **Hauptthread:** Das Auswerten läuft weiter auf dem Hauptthread (R-50, schon „später“). Kein neuer Fund.

**Messung (Mac, Release, synthetische Dateien):**

| Datei | Größe | Inhalt | Speicher-Spitze |
|---|---|---|---|
| FIT | 5 MB | 1 Mio. Records à 5 Byte | 1,1 GB |
| FIT | 28 MB | 5 Mio. Records | 3,0 GB |
| GPX | 71 MB | 1 Mio. Punkte, Name 2 Mio. Zeichen | 1,5 GB (Name wird übernommen) |
| GPX | 174 MB | 2,5 Mio. Punkte | 3,2 GB |

Eine echte Bosch-Fahrt von 10 Stunden hat etwa 2 MB und 36 000 Punkte.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-38 | Risiko | `WattspurCore/FIT/FITDecoder.swift:25` | Der FIT-Leser hat **keine Grenze** für Größe oder Anzahl der Nachrichten. Jeder Record von 5 Byte wird eine Nachricht mit einem Wörterbuch. Gemessen: 5 MB → 1,1 GB, 28 MB → 3 GB. Szenario: Eine 28-MB-FIT wird am iPhone mit Wattspur geöffnet, iOS beendet die App wegen Speicher. | Grenze für die Dateigröße (z. B. 50 MB) und die Anzahl der Nachrichten (z. B. 2 Mio.) wie bei GPX, mit eigenem Fehler und Test | 1.6.2 |
| S-39 | Risiko | `iOS/PhoneImport.swift:72` | Bringt eine Datei in „Import“ die App zum Absturz (S-38, S-40), stürzt sie **bei jedem Start wieder ab**. Die Datei wird erst nach dem Lesen nach „Importiert“/„Fehler“ verschoben, und `importWaitingFiles` läuft bei jedem Wechsel nach „aktiv“. Szenario: Die Datei wird an Wattspur geteilt, `collectShared` legt sie nach „Import“, es kommt zum Absturz; jeder neue Start stürzt wieder ab, bis man die Datei in der Dateien-App löscht. | Vor dem Lesen die Datei als „in Arbeit“ merken (Ordner oder Schlüssel); liegt sie beim nächsten Start noch dort, kommt sie nach „Fehler“, statt neu gelesen zu werden | 1.6.2 |
| S-40 | Risiko | `WattspurCore/Import/GPXRideImporter.swift:131` | Die GPX-Grenzen (200 MB, 5 Mio. Punkte) liegen weit über dem, was ein iPhone schafft. Gemessen: 174 MB mit 2,5 Mio. Punkten → 3,2 GB, also Absturz am iPhone und dann S-39. | `defaultMaxPoints` auf etwa 1 Mio. (11 Tage bei 1 Hz), `defaultMaxFileSize` auf etwa 100 MB; der Test mit den Grenzen bleibt | 1.6.2 |
| S-41 | Aufräumen | `WattspurCore/Import/GPXRideImporter.swift:632` | `trk/name`, `metadata/name`, `type` und die Wattspur-Erweiterungen werden **ohne Längengrenze** übernommen. Der Name wird `Ride.name` (`ImportService.swift:99`). Gemessen: Ein Name mit 2 Mio. Zeichen kommt durch und landet in Liste, Widget und iCloud-Datensatz. | Texte beim Sammeln auf etwa 200 Zeichen kürzen, mit Test | 1.6.2 |
| S-42 | Aufräumen | `iOSShare/ShareViewController.swift:114` | Wird die Teilen-Erweiterung beim Schreiben beendet (z. B. Speichergrenze von etwa 120 MB bei mehreren großen Dateien), bleibt `.writing-<UUID>/` **für immer** in der App Group, mit den GPS-Daten darin. `collectShared` überspringt versteckte Ordner, nichts sonst räumt dort auf. | In `ImportInbox.collectShared` Ordner `.writing-*`, die älter als eine Stunde sind, löschen; mit Test | 1.6.2 |
| S-43 | Aufräumen | `iOS/PhoneImport.swift:174` | Dateien, die auf dem iPad auf die Fahrtenliste gezogen werden, kopiert `DroppedRideFile` nach `tmp/Dropped/<UUID>`. `importFiles` kopiert sie noch einmal nach `tmp/Opened`, gelöscht wird aber nur die zweite Kopie. Die erste Kopie mit den Orten bleibt liegen, bis iOS irgendwann `tmp` leert. Dazu bleiben die leeren Ordner `Opened/<UUID>`. | Nach dem Kopieren auch Dateien unter `tmp/Dropped` löschen; in `finishIfDone` den UUID-Ordner statt nur der Datei löschen | 1.6.2 |
| S-44 | Aufräumen | `Tests/WattspurCoreTests/GPXRideImporterTests.swift` | Kein Test schützt gegen XXE oder eine Entity-Bombe, und kein Test prüft eine Größengrenze bei FIT. Heute ist alles sicher (siehe Prüfliste), aber eine spätere Änderung an den Einstellungen des `XMLParser` fiele nicht auf. | Drei Tests: Eine externe Entity erscheint nicht im Namen; eine Entity-Bombe wird schnell abgelehnt; eine FIT über der Grenze aus S-38 wird abgelehnt | 1.6.2 |
| S-45 | Idee | `iOSShare/ShareViewController.swift:142` | Die Erweiterung lädt jede geteilte Datei ganz in den Speicher (`Data(contentsOf:)`), alle zugleich, bevor sie schreibt. Mehrere große Dateien sprengen die Grenze der Erweiterung; dann geht nichts durch (und es kommt zu S-42). | Die Datei mit `FileManager.copyItem` kopieren; für die Erkennung des Typs nur die ersten 2 KB lesen. **Story:** „Teilen-Erweiterung kopiert statt zu laden. Fertig, wenn: 5 GPX-Dateien zu je 50 MB auf einmal geteilt ankommen und ein Test das Kopieren prüft“ | später (B-361) |

**Bewertung:** Die Leser sind gegen kaputte Dateien robust: XXE und Entity-Bomben gehen nicht durch, Pfade bleiben in ihren Ordnern, die Zahlen im FIT sind sicher. Die Schwäche ist der **Speicher**. FIT hat keine Grenze, die GPX-Grenze passt zum Mac, nicht zum iPhone. Zusammen mit S-39 wird aus einer einzigen feindlichen Datei ein Absturz bei jedem Start. Für 1.6.2 ein PR „Grenzen und Absturz-Schleife“ (S-38, S-39, S-40, S-41, S-44) und ein PR „Aufräumen der Temp-Dateien und der App Group“ (S-42, S-43).

---

## B-348 – Wege von außen

Geprüft am 21.11.2026 auf `main` (d7c1015): `Config/iOS-Info.plist` (URL-Schema, Dokumenttypen), `iOS/WattspurApp.swift` (`onOpenURL`, Intents), `iOS/RideIntents.swift`, `iOSShared/RecordingActivity.swift`, `iOSShared/WidgetShare.swift`, `iOSWidgets/WeekWidget.swift`, `iOSWidgets/WattspurWidgets.swift`, Auto-Start (`AutoStartSettings`, `StartRideIntent`/`EndRideIntent`, B-311/B-339 sind auf `main`). Die Mac-App hat kein URL-Schema und keine Intents.

**Prüfliste:**
- **`wattspur://`:** Nur `wattspur://import` tut etwas. Es holt Dateien, die schon in der App Group oder in „Import“ liegen, nicht während einer Aufnahme. Diese Dateien würde die App beim nächsten Öffnen ohnehin holen. Jeder andere Link geht an `phoneImport.open`, das nur `.fit`/`.gpx` annimmt; ein Nicht-Datei-Link kann nicht kopiert werden und erscheint als „nicht lesbar“. Ein fremder Link kann also nichts löschen, nichts laden und keine Aufnahme starten, er wechselt höchstens auf den Tab „Fahrten“. Kein Fund.
- **„Öffnen mit“:** Dokumenttypen FIT und GPX mit Rang „Alternate“. Die Datei wird kopiert und läuft durch denselben Import (dazu siehe B-347).
- **App Intents:** „Fahrt starten“, „Fahrt beenden“ und „Letzte Fahrt öffnen“ haben `openAppWhenRun = true`; bei gesperrtem Gerät muss man also erst entsperren. Starten prüft, ob schon eine Aufnahme läuft oder eine unfertige wartet. Ein Gerät aus einer alten Liste wird zu „kein Gerät“. Gut.
- **„Diese Woche“** antwortet ohne Entsperren (S-46).
- **Live-Aktivität:** Pause/Weiter und „Auto-Start abbrechen“ gehen auf dem Sperrbildschirm ohne Entsperren. Das ist gewollt (Handschuhe, Halterung). Pause lässt sich fortsetzen, beim Abbrechen von „Bereit“ wurde noch nichts aufgenommen. Kein Verlust möglich, kein Fund.
- **Widgets:** Nur der Startbildschirm (`systemSmall`, `systemMedium`), keine Familie für den Sperrbildschirm. In der App Group liegen nur Wochensummen (`WidgetShare`), keine Orte.
- **Auto-Start:** Er läuft nur über eigene Automationen der Nutzerin oder des Nutzers in Kurzbefehle; eine fremde App kann keinen Intent ohne Zutun auslösen. Endet die Verbindung, speichert die App selbst, wenn die Fahrt mindestens 500 m lang war; sonst fragt sie. Kein Fund.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-46 | Idee | `iOS/RideIntents.swift:101` | `WeekDistanceIntent` hat weder `openAppWhenRun` noch eine `authenticationPolicy` (Standard: immer erlaubt). Szenario: Jemand hält ein gesperrtes iPhone und sagt „Meine Woche in Wattspur“; Siri nennt Kilometer und Zahl der Fahrten. Die Daten sind klein, und das Widget zeigt sie auf dem Startbildschirm ohnehin. | Nils entscheidet: so lassen (bequem am Rad) oder `static let authenticationPolicy = .requiresAuthentication` | bleibt (**Entscheidung Nils 21.11.2026:** so lassen) |

**Bewertung:** Die Wege von außen sind schmal. Das URL-Schema kann nur einen Import anstoßen, den die App sowieso machen würde. Alles, was eine Aufnahme startet oder beendet, öffnet die App und braucht ein entsperrtes Gerät. Was ohne Entsperren geht (Pause, „Bereit“ abbrechen, Wochensumme), ist harmlos und zum Teil gewollt. Offen ist nur die Entscheidung zu S-46.

---

## B-349 – Sicherheit: Netz, iCloud und Rechte

Geprüft am 21.11.2026 auf `main` (d7c1015): Code von Hand gelesen nach der Prüfliste (Sicherheitsblick wie `/security-review`, ohne Diff), dazu `grep` über `App/`, `iOS/`, `iOSShared/`, `iOSShare/`, `iOSWidgets/`, `Packages/WattspurKit/Sources`.

**Prüfliste:**
- ☑ **Kartenkacheln** (`WattspurMap/MapTiles.swift`, `WattspurCore/Map/TileSource.swift`): alle drei Server nur über `https://`. Keine ATS-Ausnahme in einer Info.plist. Eigener User-Agent `Wattspur/<Version> (+github.com/hops-1/wattspur)`, ohne Gerät, Name oder Konto. Cache: eigener `URLCache` in `Caches/Tiles` (32 MB Speicher, **300 MB Platte**), Policy nach den HTTP-Headern; das System darf `Caches` leeren. Höchstens 4 Verbindungen je Server. Kein Vorabladen; das PDF lädt höchstens 200 Kacheln für den sichtbaren Ausschnitt (`MapGeometry.swift:135`). Das passt zu den Bedingungen in `RECHERCHE-KARTEN.md` (User-Agent, Quellenangabe, Cache, kein Bulk-Download).
- ☑ **Update-Hinweis** (`App/UpdateChecker.swift`, `WattspurCore/Support/AppVersion.swift`): ein `GET` an `api.github.com/…/releases/latest`, ephemere Session, 10 s Frist, User-Agent nur mit Version, keine Daten über Nutzer oder Mediathek. Antwort nur bei Status 200 und unter 1 MB; Entwürfe und Vorabversionen zählen nicht. Der Link wird nur geöffnet, wenn er mit `https://github.com/hops-1/wattspur/` beginnt. Abschaltbar in den Einstellungen; im Demo-Modus kein Netz.
- ☑ **CloudKit:** nur `.private(containerIdentifier)` (`LibrarySync.swift:26`) und `privateCloudDatabase` (`LibrarySync+Usage.swift:21`, nur Debug-Messung). Keine öffentliche oder geteilte Datenbank, kein `CKShare`. Ohne Einschalten ausdrücklich `.none`.
- ☑ **Entitlements:** Mac: Sandbox, vom Nutzer gewählte Dateien (lesen/schreiben), App-Lesezeichen (`FolderWatcher.swift:68`), Netz als Client; mit iCloud dazu Container, CloudKit, Push. iPhone: App Group, mit iCloud dazu Container, CloudKit, Push. Widget und Teilen: nur die App Group. Alles wird im Code genutzt, nichts fehlt, nichts ist zu viel.
- ☑ **Rechte in Info.plist / `project.yml`:** Standort nur „beim Verwenden“ (`CLServiceSession(authorization: .whenInUse)`), Hintergrund `location` und `remote-notification`, Bewegung & Fitness (Barometer, Sensoren). Fotos nur über `PhotosPicker` (braucht keinen Text). Mitteilungen brauchen keinen Text. Kein Bluetooth, kein HealthKit, keine Kamera.
- ☑ **`PrivacyInfo.xcprivacy`:** iPhone: UserDefaults (CA92.1, 1C8F.1 für die App Group), Systemstartzeit (35F9.1, `MotionRecorder.swift:43` für die Zeitstempel der Sensoren), Datei-Zeitstempel (3B52.1). Widget und Teilen: UserDefaults nur über die App Group (1C8F.1), passt. Speicherplatz und Tastaturen nutzt der Code nicht. Datei-Zeitstempel liest heute nur `FolderImport` am Mac; das Kit ist aber ins iPhone gelinkt, darum die Angabe **bewusst lassen** (zu viel angeben schadet nicht, zu wenig gibt eine Warnung von Apple). Der Mac hat kein Manifest; das ist ohne App Store nicht nötig.
- ☐ **Datenschutztext gegen das Netz:** siehe S-47 und S-48.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-47 | Risiko | `docs/PRIVACY.md` (DE Z. 26–30, EN Z. 62–66) | Der Text nennt als Verbindungen nur Karten, Updates und Bosch. Es fehlt die **Ortssuche bei Apple** (`MKReverseGeocodingRequest`): Der Mac schickt den **Startpunkt jeder Fahrt ohne Zeitzone** an Apple (`App/TimeZoneResolver.swift:13`, bei jeder Änderung der Anzahl Fahrten, `ContentView.swift:106`). Das iPhone schickt **Start und Ende** einer selbst beendeten Fahrt für den Namen „Darmstadt – Frankfurt“ (`iOS/AutoEnd.swift:13`, `Recorder.swift:173`). Der Satz „keine Weitergabe“ stimmt so nicht ganz. | Einen Punkt ergänzen (DE und EN): „Orte und Zeitzonen: Für die Zeitzone einer importierten Fahrt (Mac) und den Ortsnamen einer automatisch beendeten Aufnahme (iPhone) fragt Wattspur den Kartendienst von Apple mit einem Punkt der Fahrt. Es gilt die Datenschutzrichtlinie von Apple.“ Stand-Datum anpassen; App-Store-Angaben kurz gegenprüfen. | 1.6.2 |
| S-48 | Aufräumen | `docs/PRIVACY.md:30`, `:66` | „Bosch (Mac, ab Version 1.9, nur nach deiner Anmeldung): Abruf deiner Fahrten vom Bosch-Portal“: Diesen Abruf gibt es im Code nicht (keine Anfrage an Bosch, kein Login). Der Text beschreibt etwas, das die App nicht tut. | Zeile streichen; wieder aufnehmen, wenn der Bosch-Abruf kommt. | 1.6.2 |

**Bewertung:** Netz, iCloud und Rechte sind sauber. Nur HTTPS, keine ATS-Ausnahmen, ein ehrlicher User-Agent, ein begrenzter Cache, nur die private CloudKit-Datenbank. Entitlements und Rechte passen genau zum Code. Lücken gibt es nur im Datenschutztext: Die Ortssuche bei Apple fehlt dort (S-47), und eine Bosch-Funktion steht drin, die es nicht gibt (S-48). Beides ist eine kleine Textänderung.

---

## B-350 – Sicherheit: Build und Logs

Geprüft am 21.11.2026 auf `main` (d7c1015): `scripts/*.sh` und `.github/workflows/ci.yml` von Hand gelesen; Suche nach Geheimnissen im Baum und in der ganzen Git-Geschichte (`git grep`, `git log --all -S/-G`); gefundene Werte nicht ausgegeben, nur Datei und Commit notiert. Alle `Logger`, `os_log`, `print` und der Diagnosebericht gelesen.

**Prüfliste:**
- ☑ **`scripts/build-dmg.sh`:** `set -euo pipefail`, kein `set -x`. Das Passwort für notarytool liegt im Schlüsselbund (`--keychain-profile`), nicht in einer Datei und nicht in der Ausgabe. Hardened Runtime und Zeitstempel werden vor der Notarisierung geprüft; App und DMG werden gestapelt und mit `spctl` geprüft. Arbeitsdateien (`ExportOptions.plist` mit Team-ID, `notary.json`, Archiv) bleiben in `.build/dmg`; das ist ignoriert und wird beim nächsten Lauf gelöscht. Die Prüfsumme nennt nur den Dateinamen.
- ☑ **Andere Skripte:** `ci-local.sh` nutzt `gh` mit der Anmeldung von `gh`, gibt kein Token aus. `appstore-screenshots.sh` und `check-appstore-texts.sh` ohne Geheimnisse.
- ☑ **Geheimnisse im heutigen Baum:** `Config/Local.xcconfig` ist in `.gitignore` und nicht im Repo. `Local.xcconfig.example` enthält nur einen Platzhalter (geprüft: nicht die echte Team-ID). Keine privaten Schlüssel, keine `.p8`/`.p12`/Profile, keine Tokens, keine Apple-ID.
- ☐ **Git-Geschichte:** siehe S-49.
- ☑ **Logs:** Nur drei `Logger` (`ProfileView.swift`, `LibrarySave.swift`, `TimeSeriesDamage.swift`). Öffentlich (`privacy: .public`) sind nur Schritte, Fehlertexte von SwiftData und die UUID einer Fahrt; keine Orte, Namen oder Pfade. Die `print`-Aufrufe in `App/WattspurApp.swift` stehen nur in `#if DEBUG`; `anonymize-fit` ist ein Werkzeug für Entwickler. Am iPhone, im Widget und im Teilen gibt es keine Logs.
- ☐ **Diagnosebericht** (`WattspurCore/Support/DiagnosticReport.swift`, `App/DiagnosticsView.swift`): Versionen, Zahlen und Import-Protokoll; keine Positionen, der Home-Ordner wird zu `~`. Fehlgeschlagene Dateien nur auf Wunsch, mit Hinweis auf GPS-Positionen. Siehe S-52 und S-53.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| S-49 | Risiko | Git-Geschichte: `57162ca` und `5cd1a8f` (18.11.2026), entfernt in `15e33c2` | Der Ordner `build/sim/` mit etwa 5 300 Build-Dateien war zwei Commits lang auf `main` und ist damit im **öffentlichen** Repo. Mehrere Dateien (u. a. `*.xcent`, `Entitlements-Simulated.plist`, `XCBuildData/…/manifest.json`) enthalten die **echte Team-ID**, 10 Dateien Pfade mit dem Benutzernamen unter `/Users/…`. Keine Apple-ID, keine Schlüssel. Seit `15e33c2` ist `build/` ignoriert. | **Entscheidung Nils.** (a) So lassen: Die Team-ID steht ohnehin in jeder signierten App, der Benutzername ist kein Geheimnis. (b) Geschichte umschreiben (`git filter-repo --path build --invert-paths`, Force-Push auf `main`, alle Branches und Worktrees neu aufsetzen, offene PRs neu). Story-Vorschlag: „Build-Dateien aus der Git-Geschichte entfernen. **Fertig, wenn** `git log --all -- build` leer ist und GitHub die alten Commits nicht mehr zeigt.“ | bleibt (**Entscheidung Nils 21.11.2026:** so lassen; Schutz mit S-50) |
| S-50 | Risiko | `scripts/check-architecture.sh` (läuft in CI und `ci-local.sh`) | Nichts verhindert, dass Build-Dateien oder eine Team-ID wieder eingecheckt werden. `.gitignore` half bei S-49 erst danach. | Prüfung ergänzen: `git ls-files` darf nichts unter `build/`, `.build/`, `DerivedData/`, keine `*.xcent` und kein `Config/Local.xcconfig` enthalten; `DEVELOPMENT_TEAM = <10 Zeichen>` nur als Platzhalter in `Local.xcconfig.example`. | 1.6.2 |
| S-51 | Idee | `scripts/build-dmg.sh:58`, `:74`, `:160` | Das Skript schreibt die Team-ID in die Ausgabe („Developer ID for team …“, Fehlermeldung zum Zertifikat, `codesign`-Zeilen `Authority` und `TeamIdentifier`). Kein Geheimnis, aber Sessions, die das Skript laufen lassen, tragen sie so in ihre Protokolle; die Regel ist, sie nie auszugeben. | Team-ID in den eigenen Meldungen durch „das Team aus Local.xcconfig“ ersetzen; bei `codesign` die Team-ID mit `sed` auf `…` kürzen. | 1.6.2 |
| S-52 | Risiko | `App/DiagnosticsView.swift:39`, `DiagnosticReport.swift` (Schluss-Satz) | Der Bericht listet die **Dateinamen** der letzten 200 Importe. GPX-Dateien aus komoot, Strava und Co. heißen meist wie die Tour, oft mit Ortsnamen. Der Text verspricht aber „no positions, ride names or other ride data“. | Text ehrlich machen: „… und das Import-Protokoll mit den Dateinamen“; der Schluss-Satz im Bericht ebenso. Wahlweise ein Schalter „Dateinamen weglassen“ (nur Endung). | 1.6.2 |
| S-53 | Aufräumen | `DiagnosticReport.swift` (Zeile `"macOS: …"`), genutzt in `iOS/LibraryErrorView.swift:20` | Auf iPhone und iPad steht im Bericht „macOS: Version 26.x“. | Bezeichnung „OS:“ oder je Plattform „iOS“/„macOS“; Test anpassen. | 1.6.2 |
| S-54 | Idee | `.github/workflows/ci.yml` | Kein `permissions:`-Block. Der `GITHUB_TOKEN` bekommt den Standard des Repos, je nach Einstellung mit Schreibrecht, obwohl die CI nur liest. | Oben `permissions: contents: read` ergänzen. | 1.6.2 |

**Bewertung:** Der Release-Weg ist sauber. Das Notar-Passwort liegt im Schlüsselbund, es gibt kein `set -x`, keine Geheimnisse im heutigen Baum, und die Logs geben nichts Persönliches preis. Der wichtigste Fund liegt in der Vergangenheit: Am 18.11.2026 kamen Build-Dateien mit Team-ID und Benutzernamen in die öffentliche Geschichte (S-49). Ob das umgeschrieben wird, entscheidet Nils; eine Prüfung gegen eine Wiederholung ist klein (S-50). Der Diagnosebericht verspricht etwas mehr, als er hält: Dateinamen können Tour- und Ortsnamen enthalten (S-52).

---

## Zusammenfassung

| Bereich | Funde | Fehler | Risiko | Aufräumen | Idee | Für 1.6.2 | Später | Bleibt |
|---|---|---|---|---|---|---|---|---|
| B-343 Regeln und Prüfskript | 14 | 0 | 0 | 9 | 5 | 13 | 1 | 0 |
| B-344 Große Dateien, doppelte Logik | 11 | 1 | 1 | 7 | 2 | 5 | 6 | 0 |
| B-345 Toter Code, Warnungen, Tests | 8 | 0 | 3 | 3 | 2 | 5 | 3 | 0 |
| B-346 Kit-Grenzen | 4 | 1 | 3 | 0 | 0 | 3 | 1 | 0 |
| B-347 Datei-Import | 8 | 0 | 3 | 4 | 1 | 7 | 1 | 0 |
| B-348 Wege von außen | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| B-349 Netz, iCloud, Rechte | 2 | 0 | 1 | 1 | 0 | 2 | 0 | 0 |
| B-350 Build und Logs | 6 | 0 | 3 | 1 | 2 | 5 | 0 | 1 |
| **Summe** | **54** | **2** | **14** | **25** | **13** | **40** | **12** | **2** |

**Die wichtigsten Funde:**
- **Fehler:** S-34 (Bosch-Teile tragen eine angehängte GPX, die es nicht gibt, wenn sich zwei Teile überschneiden) und S-15 (PDF am iPhone/iPad zieht die Linie über eine Lücke im Track).
- **Sicherheit:** S-38, S-40 und S-39 – eine einzige zu große FIT- oder GPX-Datei kann die iPhone-App bei **jedem** Start abstürzen lassen. Die Leser selbst sind robust (keine XXE, keine Entity-Bombe, kein Pfad-Ausbruch).
- **Datenschutz:** S-47 (Datenschutztext nennt die Ortssuche bei Apple nicht) und S-52 (Diagnosebericht nennt Dateinamen, die Ortsnamen enthalten können).
- **Daten:** S-37 (doppelte Bosch-Datei löscht eine Fahrt endgültig).

**Bewertung:** Die Schichten halten, das Prüfskript ist grün, alle Builds sind ohne Warnung. Netz, iCloud, Rechte und der Release-Weg sind sauber. Die Schwächen liegen beim **Speicher** am iPhone (keine Grenze für FIT), im neuen **`RecordingPartsService`** und bei den **kopierten Texten** zwischen Mac und iPad, die schon auseinanderlaufen. `ARCHITECTURE.md` ist zwei Releases hinterher; das holt B-352 nach.

### Vorschlag für die PRs in 1.6.2 (B-351)

Reihenfolge: zuerst, was Daten und Start schützt, dann der Rest. Je PR eine Gruppe, bei Fehlern zuerst ein Test.

| # | PR | Funde |
|---|---|---|
| 1 | Bosch-Teile sicher zusammenführen | S-34, S-35, S-37 |
| 2 | Grenzen für Dateien und keine Absturz-Schleife | S-38, S-39, S-40, S-41, S-44 |
| 3 | Temp-Dateien und App Group aufräumen | S-42, S-43 |
| 4 | PDF ohne Linie über Lücken, immer km | S-15, S-16 |
| 5 | Kit statt Kopie: Farben, PDF-Dateiname, Test-Werkzeug | S-21, S-22, S-25 |
| 6 | Tote Reste | S-26, S-27 |
| 7 | Tests für Import nach Wahl und Zurücklegen beim Wiederherstellen | S-29, S-30 |
| 8 | Datenschutztext und Diagnosebericht | S-47, S-48, S-52, S-53 |
| 9 | Prüfskript schärfen, keine Build-Dateien im Repo | S-02, S-09, S-10, S-11, S-12, S-13, S-50 |
| 10 | Build-Skript ohne Team-ID in der Ausgabe, CI nur lesend | S-51, S-54 |
| 11 | `ARCHITECTURE.md` und Messung der Abdeckung (B-352) | S-01, S-03, S-04, S-05, S-06, S-07, S-08, S-33 |

### Stories für später

| Story | Funde |
|---|---|
| B-353 Schema-Abdruck im Test | S-14 |
| B-354 Abruffehler im Kit melden | S-36 |
| B-355 Gemeinsame Texte für Mac und iPad | S-17, S-18, S-19 (und die PDF-Schlusszeile aus S-22) |
| B-356 Kalender-Helfer der Highlights ins Kit | S-20 |
| B-357 Große iPhone-Dateien teilen | S-23, S-24 |
| B-358 Hinweis auf den alten Ordner-Weg entfernen | S-28 |
| B-359 Test für Speicherfehler | S-31 |
| B-360 Tests für das Karten-Modul | S-32 |
| B-361 Teilen-Erweiterung kopiert statt zu laden | S-45 |
