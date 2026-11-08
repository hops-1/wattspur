# 34 – Review vor dem nächsten großen Schritt

Stories: B-250 bis B-261 (iOS 0.5.2 + Mac 1.8.7, 6. bis 8.11.2026). Bericht: [REVIEW-0.5.2](../REVIEW-0.5.2.md), Stand der Architektur: [ARCHITECTURE](../ARCHITECTURE.md).

## Was gemacht wurde
- **Acht Bereiche geprüft:** Tests und CI, Kit-Kern, Kit-Store, Sync, Import, Aufnahme, Mac-App, iPhone-App. Je Bereich ein `/code-review high` und dieselbe Prüfliste von Hand (Schichten, Nebenläufigkeit, verschluckte Fehler, CloudKit, Tempo bei 1 000 Fahrten, toter Code).
- **66 Funde**, je mit Schwere (Fehler, Risiko, Aufräumen, Idee) und Ziel (0.5.2 oder später). 6 Fehler, 34 Risiken, 20 zum Aufräumen, 6 Ideen.
- **51 Funde in 18 PRs behoben** (B-260, PR #126 bis #143), je PR eine Gruppe, bei Fehlern zuerst ein Test, der den Fehler zeigt. Die Funde für später sind Stories B-263 bis B-272.
- **Ergebnis:** 653 Tests statt 630, null Warnungen beim Bauen, zwei neue automatische Regeln in `scripts/check-architecture.sh` (Schreiben nur über `RideLibrary`, Speichern nur über `LibrarySave`).

## Was das Review gelernt hat
- **Die meisten Risiken kamen vom zweiten Gerät.** Seit dem Sync (1.8.4) arbeiten Mac und iPhone an derselben Bibliothek. Vieles, was mit einem Gerät sicher war, war es mit zweien nicht mehr: ⌘Z auf eine Fahrt, die das andere Gerät gelöscht hat (R-27), eine ältere App, die Werte einer neueren zurückrechnet (R-28), Doppel, die beim Zusammenführen Änderungen verlieren (R-35).
- **Daten, die nicht wiederkommen, zuerst.** Eine gefahrene Strecke lässt sich nicht noch einmal aufnehmen. Deshalb kam die Aufnahme als erster PR (R-51 bis R-53), vor allem anderen.
- **`try?` beim Speichern ist ein stiller Datenverlust.** 41 Stellen haben einen Fehler beim Speichern verschluckt. Jetzt geht alles durch `LibrarySave`, und die Apps zeigen den Fehler (R-31).
- **Was nur ein Kommentar sichert, bricht.** Die Version stand doppelt (App und Widget), die Architektur-Prüfung übersah neue Schreibweisen von `import`. Beides prüft jetzt ein Skript (R-04, R-05, R-06).
- **Nicht alles teilen, was groß ist.** Drei Dateien der Mac-App haben über 600 Zeilen. Sie zu teilen bringt erst etwas mit dem Bereich „Fahrten“ (B-125). Ein Umbau ohne neuen Nutzen macht nur Risiko.

## Warum so
- **Erst die Liste, dann die Fixes:** Der Bericht kam als eigener PR. Nils hat alle Funde auf einmal gesehen und die Liste freigegeben, bevor Code geändert wurde. So war klar, was in 0.5.2 kommt und was nicht.
- **Kleine PRs mit Test zuerst:** Ein Test, der vor dem Fix rot ist, zeigt, dass der Fehler echt ist und nicht wiederkommt.
- **Keine neuen Funktionen und kein neues Schema:** Ein Review-Release soll sich für Nutzer gleich anfühlen, nur ohne die Fehler. Das CloudKit-Schema ist in Production und darf nur wachsen.
- **`RideLibrary` bleibt die eine Tür** (B-271): Sie macht die Regel „Views schreiben nur über die Bibliothek“ prüfbar und hält Rückgängig und Speichern an einer Stelle.

## Swift-Konzepte
- **Code-Abdeckung:** `swift test --enable-code-coverage` und `xcrun llvm-cov report` zeigen, welche Zeilen kein Test trifft. Das Kit lag bei 93 %; schwach waren genau Sync und Import, die riskanten Wege.
- **Arbeit vom Hauptthread holen:** `Task.detached` rechnet das Tour-Detail und das Neu-Lesen abseits der Oberfläche; die Ergebnisse kommen als `Sendable`-Werte zurück.
- **Swift-6-Imports:** `public import`, `@preconcurrency import` und `import struct SwiftUI.Color` sind alles Import-Zeilen. Ein Muster, das nur `^import` sucht, übersieht sie.
- **Testordner aufräumen:** Eine Suite als `final class` mit `deinit` löscht ihren Temp-Ordner nach jedem Test.

## Selbst nachprüfen
1. `scripts/check-architecture.sh` – meldet „architecture: ok“.
2. `cd Packages/WattspurKit && swift test --no-parallel` – 653 Tests grün.
3. `scripts/ci-local.sh` – baut Mac, iPhone und Widget ohne Warnung.
