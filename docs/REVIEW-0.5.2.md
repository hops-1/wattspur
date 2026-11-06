# Review iOS 0.5.2 + Mac 1.8.7

Stand: 6.11.2026 · Entwurf, wächst mit jedem Bereich (B-251 bis B-258). Plan und Regeln: `BACKLOG.md`, Abschnitt „iOS 0.5.2 + Mac 1.8.7 – Review“.

**Schwere:** **Fehler** (falsches Ergebnis, Absturz, Datenverlust) · **Risiko** (geht heute, bricht leicht) · **Aufräumen** · **Idee**.
**Ziel:** **0.5.2** (klein und sicher, kommt in dieses Release) oder **später** (wird eine Story im Backlog).

## Übersicht

| Bereich | Story | Stand | Funde |
|---|---|---|---|
| Tests, Skripte, CI, Projekt | B-258 | ☑ geprüft 6.11.2026 | R-01 bis R-16 |
| Kit-Kern | B-251 | ☑ geprüft 6.11.2026 | R-17 bis R-26 |
| Kit-Store | B-252 | ☐ | – |
| Sync und CloudKit | B-253 | ☐ | – |
| Import | B-254 | ☐ | – |
| Aufnahme | B-255 | ☐ | – |
| Mac-App | B-256 | ☐ | – |
| iPhone-App | B-257 | ☐ | – |

---

## B-258 – Tests, Skripte, CI, Projekt

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `scripts/`, `.github/`, `project.yml`, `Config/`, `Package.swift` und `Tests/`, dazu die Prüfliste.

**Messwerte:**
- `scripts/check-architecture.sh`: ok.
- `swift test --no-parallel --enable-code-coverage`: **630 Tests grün** (297 in 54 Suites, 333 in 44 Suites), 1:19 min.
- **Abdeckung des Kits: 93,1 % der Zeilen** (8 542 Zeilen, 591 nicht getroffen). Schwach: `SyncMonitor` 44 %, `LibrarySync+Usage` und `LibrarySync+Schema` 0 %, `ImportFlow` 74 %, `ImportReport` 76 %, `MotionRawLog` 80 %.
- Warnungen beim Bauen (Debug, ohne Signierung): Kit 0, iPhone-App mit Widget 0, Mac-App **1** (R-16). Dazu ein Hinweis des Werkzeugs für App Intents am Mac („no AppIntents.framework dependency“), der harmlos ist.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-01 | Fehler | `.github/workflows/release.yml` | `actions/checkout` holt nur den letzten Commit. `build-dmg.sh` rechnet die Build-Nummer als 217 + Anzahl Commits, das gibt **218 statt etwa 516**. Ein DMG aus dem Workflow hätte eine kleinere Build-Nummer als 1.8.6. | Entfällt mit R-03: der Workflow wird gestrichen | 0.5.2 |
| R-02 | Fehler | `.github/workflows/release.yml` | Die erzeugte `Local.xcconfig` setzt `WATTSPUR_MAC_ENTITLEMENTS` nicht. Ein DMG aus dem Workflow wäre notarisiert, hätte aber **keinen iCloud-Sync**. | Entfällt mit R-03: der Workflow wird gestrichen | 0.5.2 |
| R-03 | Risiko | `.github/workflows/release.yml` | Archiv und Export laufen mit `-allowProvisioningUpdates`. Das braucht ein angemeldetes Apple-Konto oder einen App-Store-Connect-API-Schlüssel; der Runner hat beides nicht. Der Workflow lief noch nie; alle Releases entstehen am Mac. | **Entscheidung Nils (6.11.2026): streichen.** `release.yml` löschen, Releases bleiben lokal mit `scripts/build-dmg.sh`; `RELEASE.md` (Schritt 3b, Secrets) anpassen; die Secrets in GitHub kann Nils danach löschen | 0.5.2 |
| R-04 | Risiko | `project.yml` | Version und Build-Nummer der iPhone-App stehen doppelt: einmal in der App, einmal im Widget. Nur ein Kommentar erinnert daran. Weichen sie ab, lehnt App Store Connect den Upload ab. | Ein YAML-Anker oder eine Variable in `Config/iOS.xcconfig` für beide Targets | 0.5.2 |
| R-05 | Risiko | `scripts/check-architecture.sh` | Die Prüfung sucht nur Zeilen, die mit `import` beginnen. `public import SwiftData` (Swift 6), `@preconcurrency import …` oder `import struct SwiftUI.Color` in `WattspurCore` rutschen durch. | Muster für Attribute, Zugriffsstufe und Einzel-Importe erweitern; Test-Fälle im Skript | 0.5.2 |
| R-06 | Risiko | `scripts/check-architecture.sh` | Die Prüfung der iPhone-Quellen sieht nur Einträge `- path: App…`. Die Kurzform `- App/Foo.swift` und das Widget-Target prüft sie nicht. Dass das Widget kein SwiftData einbindet (ARCHITECTURE), prüft niemand. | Beide Schreibweisen und das Widget-Target prüfen; `import SwiftData` in `iOSWidgets/` verbieten | 0.5.2 |
| R-07 | Risiko | `.github/workflows/ci.yml` | Kein `timeout-minutes`. Ein hängender Test läuft bis zu 6 Stunden und verbraucht die freien macOS-Minuten des ganzen Monats. | `timeout-minutes: 20` (Tests) und `30` (Build) | 0.5.2 |
| R-08 | Risiko | `Tests/…/SyncMergeWatcherTests.swift` | Zwei Tests warten fest 300 ms auf eine Pause von 50 ms. Auf einem ausgelasteten Rechner kann das zu knapp sein: Test wird zufällig rot. | Mit Frist abfragen (z. B. bis 2 s alle 20 ms) statt fest warten | 0.5.2 |
| R-09 | Risiko | `Tests/…/GPXRideImporterTests.swift` | Der Tempo-Test misst die Zeit mit `Date()` und verlangt unter 5 s. Mit Abdeckung oder auf einem langsamen Runner kann er ohne Code-Änderung rot werden. | `.timeLimit`-Trait mit großzügiger Grenze, oder die Grenze deutlich anheben | 0.5.2 |
| R-10 | Aufräumen | `Tests/…` (6 Suites) | `FolderImportTests`, `ImportFlowTests`, `PhoneStateWriterTests`, `GPXDuplicateTests`, `CurvyRoadLibraryTests` und `CurvyRoadsTests` legen Ordner im Temp-Verzeichnis an und löschen sie nie. | Aufräumen in `deinit` oder `defer`, wie in `LibraryBackupTests` | 0.5.2 |
| R-11 | Aufräumen | `scripts/ci-local.sh` | Bricht man das Skript mit Ctrl-C ab, bleibt der Status „local-ci“ im PR auf „pending“ stehen. | `trap` auch für `INT` und `TERM`, Status „error“ setzen | 0.5.2 |
| R-12 | Aufräumen | `scripts/build-dmg.sh` | Die Version liest das Skript aus dem **ersten** `MARKETING_VERSION` in `project.yml`. Das ist heute die Mac-Version, aber nur wegen der Reihenfolge der Datei. Ein Build aus einem nicht sauberen Stand ist nur eine Warnung. | Mit R-04: Mac-Version als eigene Variable lesen; bei nicht sauberem Stand abbrechen (außer mit `--allow-dirty`) | 0.5.2 |
| R-13 | Risiko | `Config/iOS.xcconfig` | Ohne `Local.xcconfig` startet das iPhone im Modus `folder` (Austausch über den Ordner wie in 0.2). Ausgeliefert wird `icloud`. Der Simulator-Build in `ci-local.sh` prüft also nicht den Weg, den die Tester nutzen. | Im Review der iPhone-App (B-257) klären, ob `folder` noch gebraucht wird; sonst `local` als Standard | B-257 |
| R-14 | Idee | Kit-Tests | Sync und Import haben die schwächste Abdeckung (siehe Messwerte), genau die riskanten Wege. | In B-253 und B-254 gezielt Tests ergänzen, wo die Reviews Fehler finden | B-253, B-254 |
| R-15 | Idee | Mac- und iPhone-App | Die Apps haben kein Test-Target; Views, `AppSettings` und Abläufe in der App prüft nur der Mensch. | Story für später: Test-Target mit ersten Tests für `AppSettings` und Logik, die in der App bleibt | später |
| R-16 | Aufräumen | `App/WattspurApp.swift:83` | `restored != nil` ist immer wahr: `try?` macht aus dem Ergebnis schon ein Optional, und `if let` packt es aus. Der Hinweis nach dem Wiederherstellen erscheint trotzdem richtig, es ist die einzige Warnung der Mac-App. | Die Bedingung `restored != nil` streichen | 0.5.2 |

**Bewertung:** Grundlage solide. Die Tests sind zahlreich und schnell, die Abdeckung des Kits ist hoch, die lokale CI prüft mehr als GitHub. Echte Fehler stecken nur im Release-Workflow, und der wird bisher nicht benutzt. Die übrigen Funde sind klein und lassen sich in zwei bis drei PRs beheben: Workflow streichen und Zeitlimit (R-01 bis R-03, R-07), Architektur-Prüfung (R-05, R-06), Versionen (R-04, R-12), Tests (R-08 bis R-11), dazu R-16 als Einzeiler.

---

## B-251 – Kit-Kern (`WattspurCore`)

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `Packages/WattspurKit/Sources/WattspurCore` (60 Dateien, 8 300 Zeilen), dazu die Prüfliste. Genau gelesen: FIT-Decoder, GPX-Import, Zusammenfügen, Aufnahme, Bewegung, Höhe, Steigung, beste Minute, Kalorien.

**Prüfliste:**
- Regel 1 (keine UI- und Datenbank-Frameworks): eingehalten.
- Regel 8 (keine Texte für die Oberfläche): im Kern eingehalten. **Aber** `WattspurKit/Import/ImportReport.swift` nutzt `String(localized:)` – gehört zum Review des Imports (B-254).
- Keine `fatalError`, kein `try!`, kein `@unchecked Sendable`, keine Logs. Die `!` stehen alle hinter einer Prüfung.
- Der FIT-Decoder ist robust: Länge, Kopf, Prüfsumme und jede Lese-Stelle werden geprüft; die Tests mit feindlichen Dateien decken das ab.
- Zeit und Kalender kommen überall als Parameter mit Standardwert, also testbar.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-17 | Fehler | `Ride/RideMerge.swift:111` | Beim Zusammenfügen über **mehrere Tage** landet der zweite Teil eines späteren Tages einen Tag zu weit hinten. Grund: Der Abstand wird vom ersten Teil der ganzen Fahrt gemessen, nicht vom vorigen Teil. Beispiel: Tag 1 10 Uhr, Tag 2 10 Uhr und 14 Uhr → der letzte Teil beginnt bei 28 h statt bei 5 h. Diagramme haben eine Lücke von 26 h, die Gesamtzeit stimmt nicht. | Abstand = Lage des vorigen Teils + (Start dieses Teils − Start des vorigen); Test mit drei Teilen an zwei Tagen zuerst | 0.5.2 |
| R-18 | Fehler | `Import/GPXRideImporter.swift:91` | Derselbe Fehler beim **GPX-Import**: eine Datei über zwei Tage mit zwei Abschnitten am zweiten Tag. | Mit R-17 und R-24 eine gemeinsame Rechnung; `parserVersion` erhöhen, damit betroffene Fahrten neu gelesen werden | 0.5.2 |
| R-19 | Risiko | `Recording/AltitudeFusion.swift:64` | Mit Barometer wartet die Höhe auf eine GPS-Höhe mit höchstens 15 m Ungenauigkeit. Kommt die nie (Stadt, Wald: oft 16–30 m), hat die **ganze Aufnahme keine Höhe** – schlechter als vor B-235. | Nach `anchorTimeout` die besten vorhandenen GPS-Höhen nehmen, auch wenn sie ungenauer sind | 0.5.2 |
| R-20 | Risiko | `Recording/AltitudeFusion.swift:55` | Ist das Barometer kurz veraltet (älter als 5 s), nimmt die Aufnahme die rohe GPS-Höhe, danach wieder die vom Barometer. Die Höhe springt um einige Meter hin und her, und jeder Sprung über 2 m zählt als Anstieg. | Während der Lücke die letzte Barometer-Höhe mit dem Versatz halten oder keine Höhe schreiben | 0.5.2 |
| R-21 | Risiko | `Ride/RideMotion.swift:70` | „0 auf 25“ (bzw. 100) prüft nicht, ob der Wert möglich ist. Ein GPS-Ausreißer an der Ampel (8 m in einer Sekunde) ergibt „0 auf 25 in 1,1 s“. | Ziel muss ein paar Sekunden gehalten werden, oder Obergrenze für die Beschleunigung; mit den Testfahrten aus V-16 einstellen | B-261 |
| R-22 | Risiko | `Import/GPXRideImporter.swift:243` | Ist der **erste** Punkt eines GPX-Abschnitts ein Ausreißer, gelten alle Punkte der nächsten 30 s als Sprung und fallen weg; der Anfang der Fahrt fehlt. | Wenn mehrere „Sprünge“ hintereinander zueinander passen, den einzelnen Punkt davor verwerfen; braucht eine echte Datei zum Prüfen | später |
| R-23 | Risiko | `Ride/RideMotion.swift:40` | Größte Schräglage und stärkste Beschleunigung sind der Höchstwert eines einzigen Messpunkts. Ein Schlagloch oder ein Stoß ans Handy wird so zur Kennzahl und zum Rekord. | Wert nehmen, der etwa 1 s gehalten wurde; mit V-16 einstellen | B-261 |
| R-24 | Aufräumen | `Ride/RideMerge.swift:103` | Die Lage der Teile auf einer Zeitachse ist zweimal gebaut (Zusammenfügen und GPX), mit verschiedenen Regeln für „derselbe Tag“ (Start des vorigen Teils bzw. sein Ende). Eine Fahrt über Mitternacht liegt deshalb verschieden, je nachdem, wie sie entstand. | Eine gemeinsame Funktion, zusammen mit R-17 und R-18 | 0.5.2 |
| R-25 | Aufräumen | `Ride/RideTrack.swift:156` | `fix(atTime:)` baut bei jedem Aufruf eine Liste aller Indizes. Das passiert bei jeder Mausbewegung über dem Diagramm. | Direkt in `fixes` suchen | 0.5.2 |
| R-26 | Aufräumen | `Recording/RideRecording.swift:162` | Der Anstieg in der Aufnahme wird bei jeder Anzeige über die ganze Fahrt neu gerechnet. Bei langen Fahrten kostet das mit der Zeit mehr Akku. | Anstieg je Abschnitt laufend mitführen | 0.5.2 |

**Bewertung:** Der Kern ist sauber getrennt und gut getestet. Echte Fehler gibt es nur bei Fahrten über mehrere Tage (R-17, R-18) – selten, aber dann falsch. Die Bewegungswerte (R-21, R-23) und die Höhe beim Aufnehmen (R-19, R-20) sind neu und noch nicht an echten Fahrten geprüft; die Grenzen kommen mit B-261. Für 0.5.2 sind es drei PRs: Zeitachse (R-17, R-18, R-24), Höhe (R-19, R-20), Kleinigkeiten (R-25, R-26).
