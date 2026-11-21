# 35 – Review Architektur und Sicherheit

Stories: B-343 bis B-352 (iOS 1.6.2 + Mac 1.10.3, 21.11.2026). Bericht: [REVIEW-1.6.2](../REVIEW-1.6.2.md), Stand der Architektur: [ARCHITECTURE](../ARCHITECTURE.md).

## Was gemacht wurde
- **Acht Bereiche in vier parallelen Sitzungen geprüft:** Regeln und Prüfskript, große Dateien und doppelte Logik, toter Code und Tests, Grenzen des Kits; dazu Sicherheit bei Datei-Import, Wegen von außen, Netz und Rechten, Build und Logs. Je Bereich `/code-review high` und eine feste Prüfliste.
- **54 Funde:** 2 Fehler, 14 Risiken, 25 zum Aufräumen, 13 Ideen. 40 kamen in 1.6.2, 12 wurden Stories für später (B-353 bis B-361), 2 bleiben nach Entscheidung von Nils.
- **Die Fixes in 10 PRs** (B-351), verteilt auf Sitzungen, die nie dieselben Dateien anfassen. Dazu dieser Stand von `ARCHITECTURE.md` mit einem neuen Abschnitt „Sicherheit“ und Regel 14.

## Was das Review gelernt hat
- **Sicher heißt am iPhone auch: genug Speicher.** Die Leser waren gegen kaputte Dateien robust (kein XXE, keine Entity-Bombe, kein Pfad-Ausbruch). Aber eine FIT von 28 MB brauchte 3 GB Speicher, und eine Datei, die beim Lesen abstürzt, wurde bei jedem Start neu gelesen. Grenzen und ein Ordner „wird gelesen“ machen daraus einen einzelnen Fehler statt einer Schleife (S-38 bis S-40).
- **Kopien laufen auseinander.** Mac und iPad haben rund 350 Zeilen Texte und Formate doppelt. An drei Stellen sahen sie schon verschieden aus, am deutlichsten beim PDF mit einer Linie über eine Lücke im Track (S-15). Die Ursache ist eine Lücke in den Regeln: Logik gehört ins Kit (Regel 6), Texte gehören nicht ins Kit (Regel 8). B-355 löst das mit einem gemeinsamen Ordner für beide Apps.
- **Ein Datenschutztext muss zum Code passen.** Der Text nannte eine Bosch-Funktion, die es nicht gibt, und nicht die Ortssuche bei Apple, die es gibt (S-47, S-48). Er wird jetzt bei jedem Review gegen die Verbindungen ins Netz gelesen.
- **Was einmal im öffentlichen Repo war, bleibt dort.** Build-Dateien mit Team-ID standen zwei Commits lang auf `main`. Die Geschichte umzuschreiben wäre teurer als der Schaden; eine Prüfung verhindert die Wiederholung (S-49, S-50).
- **Eine Messung kann zu gut sein.** `swift test --show-codecov-path` zeigt nur das erste Test-Bundle. Über alle drei liegt die Abdeckung bei 89 %, nicht bei 96 % (S-33).

## Warum so
- **Parallel lesen, nacheinander schreiben:** Die Reviews lasen nur und liefen gleichzeitig. Die Fixes liefen auch gleichzeitig, aber jede Sitzung bekam Gruppen mit eigenen Dateien, und PRs, die sich Dateien teilen, bauen aufeinander auf.
- **Entscheidungen vor dem Bericht:** Vier Funde brauchten Nils (Meilen, Siri ohne Entsperren, Git-Geschichte, Löschen eines Bosch-Doppels). Er hat sie entschieden, bevor die Liste freigegeben wurde.
- **Messen statt vermuten:** Für die Grenzen wurden feindliche Dateien gebaut und der Speicher gemessen, nur mit Demo-Daten.

## Swift-Konzepte
- **`XMLParser.shouldResolveExternalEntities = false`:** Der Leser löst keine externen Entities auf, also kann eine GPX keine Datei vom Gerät einlesen (XXE).
- **`openAppWhenRun` und `authenticationPolicy` in App Intents:** Ein Intent, der die App öffnet, braucht ein entsperrtes Gerät. Ein Intent ohne beides antwortet auch bei gesperrtem Gerät.
- **`Logger` mit `privacy: .public`:** Nur was ausdrücklich öffentlich ist, steht lesbar im Protokoll; alles andere zeigt das System als `<private>`.
- **`llvm-cov` mit mehreren `-object`:** So zählt die Abdeckung über alle Test-Bundles (`scripts/coverage.sh`).

## Selbst nachprüfen
1. `scripts/check-architecture.sh` – meldet „architecture: ok“.
2. `scripts/coverage.sh` – Abdeckung je Modul und gesamt.
3. `scripts/ci-local.sh` – Kit-Tests, Mac und iPhone ohne Warnung.
