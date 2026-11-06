# Review iOS 0.5.2 + Mac 1.8.7

Stand: 6.11.2026 · Entwurf, wächst mit jedem Bereich (B-251 bis B-258). Plan und Regeln: `BACKLOG.md`, Abschnitt „iOS 0.5.2 + Mac 1.8.7 – Review“.

**Schwere:** **Fehler** (falsches Ergebnis, Absturz, Datenverlust) · **Risiko** (geht heute, bricht leicht) · **Aufräumen** · **Idee**.
**Ziel:** **0.5.2** (klein und sicher, kommt in dieses Release) oder **später** (wird eine Story im Backlog).

## Übersicht

| Bereich | Story | Stand | Funde |
|---|---|---|---|
| Tests, Skripte, CI, Projekt | B-258 | ☑ geprüft 6.11.2026 | R-01 bis R-16 |
| Kit-Kern | B-251 | ☐ | – |
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
| R-01 | Fehler | `.github/workflows/release.yml` | `actions/checkout` holt nur den letzten Commit. `build-dmg.sh` rechnet die Build-Nummer als 217 + Anzahl Commits, das gibt **218 statt etwa 516**. Ein DMG aus dem Workflow hätte eine kleinere Build-Nummer als 1.8.6. | `fetch-depth: 0` – oder den Workflow streichen (siehe R-03) | 0.5.2 |
| R-02 | Fehler | `.github/workflows/release.yml` | Die erzeugte `Local.xcconfig` setzt `WATTSPUR_MAC_ENTITLEMENTS` nicht. Ein DMG aus dem Workflow wäre notarisiert, hätte aber **keinen iCloud-Sync**. | Zeile `WATTSPUR_MAC_ENTITLEMENTS = App/Wattspur-iCloud.entitlements` – oder streichen (R-03) | 0.5.2 |
| R-03 | Risiko | `.github/workflows/release.yml` | Archiv und Export laufen mit `-allowProvisioningUpdates`. Das braucht ein angemeldetes Apple-Konto oder einen App-Store-Connect-API-Schlüssel; der Runner hat beides nicht. Der Workflow lief noch nie; alle Releases entstehen am Mac. | **Frage an Nils:** Workflow streichen (Releases bleiben lokal, `RELEASE.md` anpassen) oder mit API-Schlüssel reparieren (dann R-01 und R-02 dazu) | 0.5.2 |
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

**Bewertung:** Grundlage solide. Die Tests sind zahlreich und schnell, die Abdeckung des Kits ist hoch, die lokale CI prüft mehr als GitHub. Echte Fehler stecken nur im Release-Workflow, und der wird bisher nicht benutzt. Die übrigen Funde sind klein und lassen sich in zwei bis drei PRs beheben: Workflow (R-01 bis R-03, R-07), Architektur-Prüfung (R-05, R-06), Versionen (R-04, R-12), Tests (R-08 bis R-11), dazu R-16 als Einzeiler.
