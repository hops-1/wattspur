# Testanleitung iPhone 1.6.2 und Mac 1.10.3

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Das ist ein Review-Release mit kleinen Fixes (B-351, Bericht `REVIEW-1.6.2.md`) und den Fixes aus dem Test von 1.6 im Auto (B-363, B-365, B-366). Es gibt keine neuen Funktionen und kein neues CloudKit-Feld.

Nur mit Demo-Daten oder eigenen Testdateien prüfen. Bitte nichts während der Fahrt am iPhone einstellen.

## 0. Vorher

- Am iPhone **1.6.2 (43)** aus TestFlight.
- Am Mac **1.10.3** aus dem notarisierten DMG, geöffnet aus `/Applications`.

## A. Im Auto (B-363, B-365, B-366)

1. Eine lange Fahrt aufnehmen, gern wieder mit CarPlay und Google Maps daneben. Wattspur wird nicht von iOS beendet. Falls doch: Uhrzeit notieren, der Bericht kommt über TestFlight.
2. Die App während der Aufnahme beenden und neu öffnen. Die Karte zoomt auf etwa 1,5 km um die Position, nicht auf die ganze Welt.
3. Die Fahrt speichern und **sofort** zu einer anderen App wechseln. In **Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten** entsteht kein Bericht `Wattspur…` mit `0xdead10cc`.

## B. Bosch-Teile (S-34, S-37)

1. Eine Aufnahme am iPhone, dazu die Bosch-FIT derselben Fahrt importieren, wenn die Fahrt auf zwei Aufnahmen verteilt ist. Die ganze Bosch-Fahrt liegt danach im **Papierkorb**, die Teile tragen Rad und Sensorwerte.
2. Dieselbe FIT noch einmal importieren. Es entsteht kein Doppel, und die Fahrt kommt nicht aus dem Papierkorb zurück.

## C. Dateien (S-38 bis S-41)

1. Am iPhone eine normale FIT und eine normale GPX über **Dateien › Wattspur › Import** einlesen. Beide kommen wie vorher an.
2. Optional: eine sehr große Testdatei (über 50 MB FIT) in „Import“ legen. Sie landet in **Fehler** und wird beim nächsten Start nicht wieder gelesen.

## D. PDF und Einheiten (S-15, S-16)

1. Am iPhone oder iPad das PDF einer Fahrt mit einer Lücke im Track teilen, z. B. mit einer Bahnfahrt ohne Aufnahme dazwischen. Über die Lücke führt keine Linie, wie am Mac.
2. Strecken stehen überall in km.

## E. Mac

1. **Über Wattspur** zeigt 1.10.3 und den Knopf **Unterstützen**, der Buy Me a Coffee öffnet.
2. **Hilfe › Diagnose erstellen …** sagt, dass das Import-Protokoll Dateinamen enthält.
3. Am iPhone: **Mehr › Über** zeigt den Link **Wattspur auf GitHub**.
