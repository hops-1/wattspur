# Review iOS 0.5.2 + Mac 1.8.7

Stand: 6.11.2026 · Entwurf, wächst mit jedem Bereich (B-251 bis B-258). Plan und Regeln: `BACKLOG.md`, Abschnitt „iOS 0.5.2 + Mac 1.8.7 – Review“.

**Schwere:** **Fehler** (falsches Ergebnis, Absturz, Datenverlust) · **Risiko** (geht heute, bricht leicht) · **Aufräumen** · **Idee**.
**Ziel:** **0.5.2** (klein und sicher, kommt in dieses Release) oder **später** (wird eine Story im Backlog).

## Übersicht

| Bereich | Story | Stand | Funde |
|---|---|---|---|
| Tests, Skripte, CI, Projekt | B-258 | ☑ geprüft 6.11.2026 | R-01 bis R-16 |
| Kit-Kern | B-251 | ☑ geprüft 6.11.2026 | R-17 bis R-26 |
| Kit-Store | B-252 | ☑ geprüft 6.11.2026 | R-27 bis R-34 |
| Sync und CloudKit | B-253 | ☑ geprüft 6.11.2026 | R-35 bis R-43 |
| Import | B-254 | ☑ geprüft 6.11.2026 | R-44 bis R-50 |
| Aufnahme | B-255 | ☑ geprüft 6.11.2026 | R-51 bis R-56 |
| Mac-App | B-256 | ☑ geprüft 6.11.2026 | R-57 bis R-61 |
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

---

## B-252 – Kit-Store (`WattspurKit/Store`)

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `WattspurKit/Store` (Modelle, `RideLibrary` und Dienste, Wartung, Backup, Brücken, `PhoneDatabase`), dazu die Prüfliste. Sync (`SyncMonitor`, `SyncMergeService`, `LibrarySync`) folgt in B-253, der Import in B-254.

**Prüfliste:**
- Regel 2 (alle `@Model` im Kit) und die CloudKit-Regeln (alles optional oder mit Standardwert, keine eindeutigen Felder, Beziehungen optional) sind eingehalten; der Test `CloudKitSchemaTests` sichert das.
- Regel 4 (Views schreiben nur über `RideLibrary`): eingehalten, keine View ruft `insert`, `delete` oder `save`; nur `App/DemoMode.swift` (Demo-Bibliothek für Bilder) speichert direkt.
- Regel 9 (abgeleitete Werte mit Version): eingehalten, aber der Vergleich ist `!=` statt `<` (R-28).
- Fehler beim Speichern werden überall mit `try?` verschluckt (R-31).
- Nur der Mac führt die Wartung aus (Papierkorb leeren, neu lesen, nachrechnen); das iPhone leert seinen Papierkorb selbst.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-27 | Risiko | `Store/Services/LibraryService.swift:20` | Die Schritte für ⌘Z halten die Fahrt (bzw. das Bike, das Ziel) als Objekt fest. Seit dem Sync kann es inzwischen gelöscht sein, etwa endgültig auf dem iPhone. Dann greift ⌘Z am Mac auf ein gelöschtes Objekt zu – **Absturz** möglich. | Im Schritt nur die ID merken und die Fahrt neu holen; ist sie weg, nichts tun | 0.5.2 |
| R-28 | Risiko | `Store/Models.swift:232` | Gespeicherte Werte (Übersichtsroute, beste Minute, Kurvigkeit und Steigung) gelten als veraltet, sobald ihre Version **anders** ist, nicht nur **älter**. Hat das iPhone (über TestFlight oft früher) eine neuere Rechnung als der Mac, rechnet der Mac die Werte mit der alten Rechnung zurück und schickt sie per iCloud ans iPhone. | `<` statt `!=` in den drei `needs…` und in den Abfragen der Wartung; Test mit einer „neueren“ Version | 0.5.2 |
| R-29 | Risiko | `Store/LibraryBackup.swift:131` | **Wiederherstellen** tauscht die Datenbank samt dem Stand des iCloud-Syncs von damals. Bei eingeschaltetem Sync spielt iCloud danach die Änderungen seit der Sicherung wieder ein: Fahrten, die seitdem gelöscht wurden, verschwinden wieder; Änderungen am iPhone können die wiederhergestellten Werte überschreiben. Nichts warnt davor. | 0.5.2: Hinweis beim Wiederherstellen, solange Sync an ist (vorher Sync aus). Später: ein sauberer Weg für synchronisierte Bibliotheken | 0.5.2 + später |
| R-30 | Risiko | `Store/Services/ImportService.swift:143` | „Neu lesen nach Parser-Update“ läuft beim Start auf einmal und auf dem Hauptthread. Erhöht R-18 die Version des GPX-Lesers, liest der Mac beim nächsten Start alle GPX-Fahrten neu, und die App hängt. | In Paketen und abseits des Hauptthreads wie die Übersichtsrouten; **muss vor R-18 kommen** | 0.5.2 |
| R-31 | Risiko | `Store/Services/*` | Rund 40-mal `try? context.save()`: Schlägt das Speichern fehl (Platte voll, iCloud), sieht der Nutzer nichts, und die Änderung ist nach dem nächsten Start weg. Auch der Diagnosebericht weiß davon nichts. | Eine zentrale Funktion `save()` im `LibraryService`, die den Fehler protokolliert und an die App meldet | 0.5.2 |
| R-32 | Risiko | `Store/Models.swift:178` | Lässt sich die Zeitreihe einer Fahrt nicht lesen, gibt `samples` still eine leere Liste. Karte und Diagramme sind leer, ohne Hinweis auf einen Schaden. | Lesefehler protokollieren (Diagnose) und aus einer leeren Liste keine gespeicherten Werte neu berechnen | später |
| R-33 | Aufräumen | `Store/PhoneDatabase.swift:89` | Das Tour-Detail am iPhone liest die ganze Zeitreihe vier- bis fünfmal (Route, Diagramm, Cursor, Bewegung) und beim Wechsel der x-Achse noch einmal; bei langen Fahrten ruckelt das Öffnen. | Einmal lesen je geöffneter Fahrt und daraus alles ableiten | 0.5.2 |
| R-34 | Idee | `Store/RideLibrary.swift` | `RideLibrary` reicht nur noch an die Dienste weiter (etwa 70 einzeilige Methoden). Jede neue Funktion steht doppelt da. | In B-259 entscheiden: Apps nutzen die Dienste direkt, oder die Fassade bleibt bewusst | später |

**Bewertung:** Modell und Dienste sind sauber und gut getestet; die CloudKit-Regeln sind abgesichert. Die Risiken kommen fast alle daher, dass seit 1.8.4 **zwei Geräte** an derselben Bibliothek arbeiten: ⌘Z auf gelöschte Fahrten (R-27), verschiedene Versionen der Rechnung (R-28), Wiederherstellen mit Sync (R-29). Dazu fehlen Rückmeldungen bei Fehlern (R-31, R-32). Für 0.5.2 sind es vier kleine PRs; R-30 muss vor der Korrektur der Zeitachse (R-18) kommen.

---

## B-253 – Sync und CloudKit

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `SyncMergeService`, `SyncMergeWatcher`, `SyncMonitor`, `LibrarySync` (Kit), `App/ICloudSync.swift`, `iOS/PhoneSync.swift` und das Öffnen der Bibliothek in beiden Apps, dazu die Prüfliste.

**Prüfliste:**
- Das Schema ist in Production; das Review ändert es nicht. Neue Felder bleiben erlaubt, wenn sie optional sind oder einen Standardwert haben (Test `CloudKitSchemaTests`).
- Vor dem ersten Einschalten am Mac gibt es eine Sicherung; der Sync ist als Standard aus (Mac) bzw. für neue Nutzer an (iPhone).
- Doppelte Fahrer, Bikes, Ziele und Fahrten aus zwei Geräten führt `SyncMergeService` zusammen. Beide Geräte wählen dabei dasselbe Objekt (das älteste, bei Gleichstand die kleinere ID); das ist gut.
- Abdeckung (aus B-258): `SyncMonitor` 44 %, `LibrarySync+Usage` und `+Schema` 0 % (nur Entwickler-Werkzeuge, ok).

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-35 | Fehler | `Store/Services/SyncMergeService.swift:120` | Dieselbe Datei auf beiden Geräten importiert (z. B. die FIT aus Flow per AirDrop an Mac und iPhone): Beim Zusammenführen bleibt die **ältere** Kopie, die neuere wird gelöscht. Ihr Name, ihr Bike, ihr Papierkorb-Zustand und angehängte Bosch-Werte gehen verloren. Der Kommentar verspricht das Gegenteil („Ein Name vom anderen Gerät gewinnt“). | Vor dem Löschen übernehmen, was der Nutzer an der anderen Kopie geändert hat (Name ≠ Dateiname, Bike ≠ Standard, Papierkorb nur wenn beide); Tests für jeden Fall | 0.5.2 |
| R-36 | Risiko | `Store/Services/SyncMergeService.swift:65` | Zwei Bikes mit **gleichem Namen und gleicher Art** gelten als Doppel und werden zusammengelegt: alle Fahrten auf eines, das andere gelöscht. Legt jemand bewusst ein zweites „Cube“ an, ist es beim nächsten Sync weg. | Nur Standard-Bikes („Mein eBike“ ohne Änderung) und Bikes mit gleicher ID oder Seriennummer zusammenlegen | 0.5.2 |
| R-37 | Risiko | `Store/SyncMergeWatcher.swift:56` | Das Zusammenführen wartet, bis kein iCloud-Import mehr läuft. Kommt das Ende eines Imports nie an (App im Hintergrund angehalten), wartet es bis zum nächsten Start der App: zwei „Mein eBike“ bleiben stehen. | Laufende Importe nach etwa 2 Minuten vergessen | 0.5.2 |
| R-38 | Risiko | `Store/PhoneDatabase.swift:17` | Schaltet man am iPhone „Mit iCloud synchronisieren“ **aus**, liest die App nicht mehr ihre eigene Datenbank, sondern den alten Ordner von 0.2. Wer den Ordner nie hatte, sieht danach keine Fahrten mehr, und Aufnahmen werden keine Fahrten. | „Aus“ heißt: dieselbe Datenbank ohne iCloud (`local`); den Ordner nur für alte Ordner-Nutzer. Hängt mit R-13 zusammen | 0.5.2 |
| R-39 | Risiko | `App/ICloudSync.swift:62` | Die Sicherung vor dem Sync gibt es nur beim **ersten** Einschalten. Wer den Sync aus- und Monate später wieder einschaltet, synchronisiert ohne frische Sicherung. | Bei jedem Einschalten sichern | 0.5.2 |
| R-40 | Risiko | `App/ICloudSync.swift:98` | Ungeprüft: Kommen Fahrten, die **bei ausgeschaltetem Sync** importiert wurden, nach dem Wiedereinschalten in iCloud an? Bei ausgeschaltetem Sync öffnet die App die Datenbank ohne CloudKit; ob der Abgleich die Änderungen später noch sieht, testet nichts. | Test auf echten Geräten (Mac aus → 2 Fahrten → an → am iPhone da?). Fehlen sie: ein erzwungenes erneutes Hochladen | 0.5.2 (Test) |
| R-41 | Risiko | `iOS/PhoneSync.swift:79`, `App/WattspurApp.swift:101` | Lässt sich die Bibliothek nicht öffnen (kaputte Datei, misslungene Umstellung, schlechte Sicherung), stürzt die App **bei jedem Start** ab (`fatalError`). Es gibt keinen Weg heraus außer Dateien von Hand zu löschen. | Statt Absturz eine Fehleransicht: Sicherungen zeigen, Diagnose, mit leerer Bibliothek starten (die alte bleibt liegen) | später |
| R-42 | Aufräumen | `Store/SyncMonitor.swift:160` | Fehlt das Ende eines Sync-Vorgangs, zeigt die Einstellung „Synchronisiere …“ für den Rest der Sitzung und verdeckt den echten Stand. | Laufende Vorgänge nach einigen Minuten vergessen, wie R-37 | 0.5.2 |
| R-43 | Idee | `Store/Services/SyncMergeService.swift:41` | Alle Fahrer werden zu einem zusammengelegt. Mit mehreren Fahrern (B-073) wäre das falsch. | In B-073 vermerken: vorher Standard-Fahrer kennzeichnen und nur diese zusammenlegen | später (B-073) |

**Bewertung:** Der Sync ist vorsichtig gebaut (Sicherung, Status, klare Texte), und das Zusammenführen ist auf beiden Geräten gleich. Die Schwachstelle ist das **Zusammenführen von Doppeln**: Es löscht zu viel (R-35, R-36) oder wartet zu lange (R-37). Dazu kommen das Aus- und Einschalten (R-38 bis R-40) und der Absturz beim Öffnen (R-41). Für 0.5.2 sind es drei PRs: Doppel (R-35, R-36), Warten (R-37, R-42), Ein/Aus (R-38, R-39) – dazu der Test R-40 auf echten Geräten, den Nils mit mir macht.

---

## B-254 – Import

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `ImportService`, `ImportFlow`, `FolderImport`, `ImportReport` (Kit), `App/FolderWatcher.swift` und `iOS/PhoneImport.swift`, dazu die Prüfliste.

**Prüfliste:**
- Mac und iPhone nutzen denselben Ablauf (`ImportFlow`, B-188); gut.
- Feindliche Dateien: Größe und Punktzahl sind begrenzt, der FIT-Decoder prüft jede Lese-Stelle (siehe B-251).
- Dateien aus iCloud, die noch nicht geladen sind, überspringt der Ordner-Import und lädt sie an; nur ein Scan zur Zeit.
- **Regel 8 verletzt:** `ImportReport` im Kit baut Texte mit `String(localized:)` (R-48).
- Abdeckung (aus B-258): `ImportFlow` 74 %, `ImportReport` 76 %.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-44 | Risiko | `Store/Services/ImportService.swift:47` | Die Prüfung auf Doppel sieht auch Fahrten im **Papierkorb**. Wer eine Fahrt versehentlich löscht und die Datei neu importiert, bekommt „schon vorhanden“, sieht aber nichts. Im überwachten Ordner wandert die Datei still nach „Importiert“, die Fahrt bleibt im Papierkorb und ist nach 30 Tagen weg. | Liegt das Doppel im Papierkorb: anbieten, es wiederherzustellen (im Ordner: wiederherstellen und protokollieren) | 0.5.2 |
| R-45 | Risiko | `Import/FolderImport.swift:63` | Der Ordner-Import liest 1,5 s nach einer Änderung im Ordner. Wird eine Datei noch geschrieben (große Datei, langsames Netz), liest er sie halb und schiebt sie nach „Fehlerhaft“, obwohl sie heil ist. | Dateien überspringen, die sich in den letzten Sekunden geändert haben; mit `NSFileCoordinator` lesen | 0.5.2 |
| R-46 | Risiko | `Import/ImportFlow.swift:63` | Ein zweiter Import, solange eine Frage des ersten offen ist (Bike, Doppel), ersetzt die offene Frage. Der erste Import bleibt ohne Entscheidung, seine Kopie liegt weiter im Temp-Ordner. Am iPhone reicht es, zwei Dateien kurz nacheinander mit „Öffnen mit“ zu öffnen. | Den zweiten Import warten lassen, bis der erste entschieden ist | 0.5.2 |
| R-47 | Aufräumen | `Store/Services/ImportService.swift:21` | Lässt sich eine Datei nicht **lesen** (keine Rechte, nicht geladen, weg), meldet der Import „FIT zu kurz/beschädigt“. Protokoll und Diagnose zeigen dann einen Fehler im Leser, den es nicht gibt. | Eigenes Ergebnis „konnte nicht gelesen werden“ mit dem Fehler des Systems | 0.5.2 |
| R-48 | Aufräumen | `Import/ImportReport.swift:62` | Texte für die Oberfläche im Kit (gegen Regel 8). Die Übersetzungen landen im Katalog des Pakets statt in denen der Apps; Mac und iPhone können verschieden formulieren. | Der Bericht liefert Art und Werte, jede App formt den Text selbst | 0.5.2 |
| R-49 | Aufräumen | `iOS/PhoneImport.swift:30` | Am iPhone löscht der Import die Datei aus dem Eingang, bevor er sie gespeichert hat. Klappt das Speichern der Kopie nicht, ist die Datei weg, ohne Meldung. | Erst nach dem Import löschen; bei Fehler eine Meldung | 0.5.2 |
| R-50 | Aufräumen | `Store/Services/ImportService.swift:27` | Lesen und Auswerten einer Datei laufen auf dem Hauptthread. 20 Fahrten auf einmal oder eine GPX mit 50 000 Punkten lassen die App sekundenlang hängen. | Lesen der Datei abseits des Hauptthreads (die Leser sind reine Werttypen), nur das Einfügen auf dem Hauptthread. Der ganze Umzug in einen `ModelActor` bleibt später | später |

**Bewertung:** Der gemeinsame Ablauf für Mac und iPhone ist ein guter Schritt; die Leser selbst sind robust. Die Funde liegen an den Rändern: Papierkorb (R-44), halbe Dateien (R-45), zwei Importe zugleich (R-46) und ehrliche Fehlermeldungen (R-47, R-49). R-48 bringt die Texte zurück in die Apps. Für 0.5.2 sind es drei PRs: Papierkorb und Meldungen (R-44, R-47, R-49), Ordner (R-45), Ablauf und Texte (R-46, R-48).

---

## B-255 – Aufnahme (iPhone)

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `iOS/Recorder.swift`, `MotionRecorder.swift`, `SaveRecordingSheet.swift`, `PhoneRecordings.swift`, `RecordingActivityController.swift`, `RideIntents.swift`, `iOSShared/` und `iOSWidgets/`, dazu die Prüfliste. Die Rechnungen dahinter (`RideRecording`, `MotionFusion`, `AltitudeFusion`) stehen in B-251.

**Prüfliste:**
- Die Aufnahme schreibt jede Position sofort in ein Protokoll (`Aufnahme.jsonl`); nach einem Absturz fragt die App „Weiter“, „Beenden und sichern“ oder „Verwerfen“. Gut gedacht.
- Die Bewegung läuft auf einer eigenen Queue; die Ursache des Absturzes von Build 6 ist sauber beschrieben und behoben.
- „Fahrt starten“ per Siri startet nicht über eine unfertige Fahrt hinweg; gut.
- Das Widget bindet nur `WattspurCore` ein, kein SwiftData (prüft niemand automatisch, siehe R-06).

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-51 | Fehler | `iOS/WattspurApp.swift:143` | Nach einem Absturz: **„Beenden und sichern“** verschluckt einen Fehler beim Speichern und löscht danach trotzdem das Protokoll der Aufnahme. Klappt das Speichern nicht, ist die ganze Fahrt weg, ohne Meldung. | Nur nach erfolgreichem Speichern beenden; sonst Fehler zeigen und das Protokoll behalten, wie im normalen Speichern-Dialog | 0.5.2 |
| R-52 | Risiko | `iOS/Recorder.swift:225` | Das Protokoll schreibt mit einer alten Funktion, die bei einem Schreibfehler die App **abstürzen** lässt statt einen Fehler zu melden. Wird der Speicher während einer langen Fahrt voll (die Rohdaten brauchen etwa 20 MB pro Stunde), stürzt die App mitten in der Fahrt ab. | `try write(contentsOf:)` und ein Hinweis „Speicher voll“ | 0.5.2 |
| R-53 | Risiko | `iOS/PhoneLibrary.swift:197` | Gilt eine neue Aufnahme als **Doppel** einer schon importierten GPX derselben Fahrt, meldet „Sichern“ Erfolg, aber die Aufnahme wird nicht gespeichert. Schräglage, Beschleunigung und Belag der Aufnahme sind weg. | Fragen (ersetzen oder als Doppel verwerfen) oder die Aufnahme an die Fahrt anhängen | 0.5.2 |
| R-54 | Risiko | `iOS/RecordingActivityController.swift:15` | Beim Start beendet die App alle alten Live-Aktivitäten, aber verzögert. Startet Siri die Fahrt bei geschlossener App, kann dieses Aufräumen die **eben gestartete** Live-Aktivität gleich wieder beenden: kein Sperrbildschirm, kein Knopf Pause. | Die alten Aktivitäten beim Start merken und nur diese beenden | 0.5.2 |
| R-55 | Aufräumen | `iOSShared/RecordingActivity.swift:51` | Auf einem iPhone mit Meilen zeigt die Live-Aktivität die Strecke in Meilen, das Tempo aber in km/h. | Tempo in mph, wenn die Strecke in Meilen ist | 0.5.2 |
| R-56 | Idee | `iOS/MotionRecorder.swift:57` | Die Bewegung wird bei **jeder** Aufnahme 50-mal pro Sekunde gelesen, auch beim E-Bike, wo die Schräglage nur ein Versuch ist. Was das an Akku kostet, ist noch offen (V-16). | Mit den Testfahrten messen (B-261); kostet es viel, beim Rad seltener messen oder abschaltbar machen | B-261 |

**Bewertung:** Die Aufnahme ist gegen Abstürze gut geschützt – bis auf den einen Weg nach dem Absturz (R-51), der genau dann Daten verliert. R-51 bis R-53 sind die wichtigsten Funde des ganzen Reviews für Nutzer, weil eine gefahrene Strecke nicht wiederkommt. Für 0.5.2 sind es zwei PRs: Speichern und Protokoll (R-51 bis R-53), Live-Aktivität (R-54, R-55).

---

## B-256 – Mac-App (`App/`)

Geprüft am 6.11.2026 auf `main` (d812c47): `/code-review high` über `App/` (79 Dateien, 15 300 Zeilen), mit Blick auf Start, Einstellungen, Update-Hinweis, Kartenkacheln, PDF, Fahrtenliste, Tour-Detail und Reste; dazu die Prüfliste. Sync am Mac (`ICloudSync`) steht in B-253, der Ordner-Wächter in B-254.

**Prüfliste:**
- Regel 4 und 7: eingehalten. Views schreiben nur über die Bibliothek (Ausnahme `DemoMode` für Bilder); Einstellungen stehen in `SettingsKey`, nur die Startargumente der Demo nutzen eigene Schlüssel (nur in Debug).
- Netz: nur Kartenkacheln (eigener User-Agent, Cache, höchstens 4 Verbindungen je Server, nichts vorab) und der Update-Hinweis (einmal am Tag, abschaltbar). Passt zu `RECHERCHE-KARTEN.md`.
- Nebenläufigkeit: zwei `@unchecked Sendable` (Kachel-Overlay, kurvige Straßen) mit nur lesend genutzten Feldern; `assumeIsolated` nur in Handlern auf der Main-Queue. In Ordnung.
- Eine Warnung beim Bauen (R-16). Kein Test-Target (R-15).
- Der Absturz beim Öffnen einer kaputten Bibliothek gilt auch am Mac (`WattspurApp.swift:101`), siehe R-41.

### Funde

| ID | Schwere | Datei | Fund | Vorschlag | Ziel |
|---|---|---|---|---|---|
| R-57 | Risiko | `App/RideDetailView.swift:115` | Das Tour-Detail rechnet Karte, Kurven, Schräglage und Diagramme nur neu, wenn eine **andere** Fahrt gewählt wird. Ändert sich die offene Fahrt (Bosch-FIT „Aktualisieren“, GPX mit Puls angehängt, Änderung vom iPhone per iCloud), zeigt es die alten Werte, bis man weg- und zurückklickt. | Die Aufgabe an einen Wert hängen, der sich mit der Zeitreihe ändert (z. B. Parser-Version und angehängte Quelle) | 0.5.2 |
| R-58 | Aufräumen | `App/RideDetailView.swift:117` | Dieselbe Rechnung läuft auf dem Hauptthread. Bei langen Fahrten (Motorrad, 4 h) hängt das Öffnen kurz, und das Blättern mit den Pfeiltasten ruckelt. | Abseits des Hauptthreads rechnen, nur das Ergebnis setzen | 0.5.2 |
| R-59 | Aufräumen | `App/PhoneState.swift:33` | Ist der alte „Stand fürs iPhone“ an, schreibt der Mac nach **jedem** Speichern den ganzen Stand samt Routen in iCloud Drive, auf dem Hauptthread. Bei einem Import von 30 Dateien geschieht das immer wieder. | Mit R-13 und R-38 entscheiden, ob der Ordner-Weg bleibt; wenn ja, abseits des Hauptthreads und gebündelt | B-257 |
| R-60 | Aufräumen | `App/SpikeLibrary.swift` | Reste des abgeschlossenen Spikes V-15 (eigene Spike-Bibliothek, nur in Debug) verzweigen noch in Start und Sync-Einstellung. | Entfernen, samt dem Test dafür | 0.5.2 |
| R-61 | Aufräumen | `App/RideListView.swift:84` | Die Fahrtenliste filtert und sortiert alle Fahrten bei jedem Neuzeichnen, also bei jedem Klick oder Hover. Mit 1 000 Fahrten wird die Liste träge. | Ergebnis merken und nur neu rechnen, wenn sich Suche, Filter oder Fahrten ändern | später |

**Bewertung:** Die Mac-App ist ordentlich aufgebaut, hält die Regeln ein und geht mit dem Netz zurückhaltend um. Es gibt keinen echten Fehler. Die Funde betreffen veraltete Anzeige (R-57), Tempo bei großen Fahrten und Bibliotheken (R-58, R-61) und Reste (R-59, R-60). Die großen Dateien (`RideListView` 909, `ContentView` 677, `RideDetailView` 636 Zeilen) zu teilen, lohnt sich erst mit B-125 (ein Bereich „Fahrten“). Für 0.5.2 sind es zwei PRs: Tour-Detail (R-57, R-58) und Reste (R-60).
