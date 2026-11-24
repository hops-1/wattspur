# 38 – Robuster: Schema-Abdruck, Lesefehler, Karten-Tests

Stories: B-353, B-354, B-356, B-357, B-359, B-360, B-361 und B-379 (iOS 1.6.6 + Mac 1.10.5, 24.11.2026), der Rest aus dem [Review 1.6.2](../REVIEW-1.6.2.md) und ein Fehler aus dem Test von 1.6.5. Regeln: [ARCHITECTURE](../ARCHITECTURE.md), Regel 2 und 10.

## Was gemacht wurde
- **Schema-Abdruck (B-353):** `CloudKitSchema.txt` listet jedes Feld des iCloud-Schemas mit Typ und „optional“, „default“ oder „required“. Der Test meldet ein fehlendes oder geändertes Feld. Neue Felder sind erlaubt, wenn sie nicht „required“ sind.
- **Lesefehler melden (B-354):** `LibraryFetch` ersetzt 37 Stellen mit `try? context.fetch`. Ein Fehler geht einmal je Typ ins Protokoll und als Zähler in den Diagnosebericht. Der Import bricht dann ab, statt eine Fahrt doppelt anzulegen. Das Prüfskript verbietet neue `try?` vor einem Abruf.
- **Fehler-Attrappen (B-354, B-359):** `LibraryFetch.failReads` und `LibrarySave.failSaves` lassen im Test einen Abruf oder ein Speichern absichtlich scheitern.
- **Karten-Tests (B-360):** Ein Test-Server im Prozess (`URLProtocol`) beantwortet die Kachel-Anfragen. Die Abdeckung von `WattspurMap` stieg von 29,6 % auf 92,2 %.
- **Kalender ins Kit (B-356):** `HeatmapCalendar` baut die Wochen eines Jahres und findet die Monatsanfänge; `RideRecord.isNew` entscheidet über „Neu“.
- **Dateien teilen (B-357):** zwei große iPhone-Dateien je Abschnitt in eigene Dateien; nur verschoben.
- **Teilen-Erweiterung (B-361):** `SharedDrop` kopiert Dateien, statt sie zu laden, und liest für den Typ nur 2 KB.
- **CarPlay-Kachel (B-379):** Die Live-Aktivität hat jetzt einen Link (`widgetURL`). Erst damit öffnet CarPlay die App.

## Was die Stories gelernt haben
- **`try?` versteckt mehr als den Fehler.** Ein gescheiterter Abruf sah aus wie „nichts gefunden“. Darum legte der Import eine Fahrt neu an, obwohl sie da war. Ein leeres Ergebnis und ein Fehler sind zwei verschiedene Dinge.
- **Ein Test-Server findet echte Fehler.** Der falsche Server antwortete einmal mit 503. Danach zeigte die Karte ohne Netz die gespeicherte Fehlerseite als Kachel. Den Fehler gab es auch in der App, er ist jetzt behoben.
- **Ein Test ist nur so gut wie sein Leerlauf.** Der erste Schema-Abdruck war leer und der Test trotzdem grün. Ein Test muss zuerst einmal rot werden.
- **Werte, die sich bei jedem Lauf ändern, gehören nicht in den Abdruck.** Datum und UUID als Standardwert sind jedes Mal neu. Darum steht nur „default“ da.
- **Zwei PRs an derselben Datei brauchen eine Reihenfolge.** Das Teilen der Highlights-Datei und der Umbau der Kalender-Helfer trafen dieselbe Datei. Der zweite PR baut auf dem ersten auf.
- **Was Apple für Widgets schreibt, gilt oft auch für die Live-Aktivität.** CarPlay öffnet eine App nur über einen Link. Ohne Link passiert beim Tipp nichts.

## Warum so
- **Ein Text-Abdruck statt eines Vergleichs mit iCloud:** Der Test läuft ohne Konto und ohne Netz, und jede Änderung steht lesbar im Diff.
- **Ein Zähler je Typ statt jeder Meldung:** Ein kaputter Speicher kann tausende Abrufe scheitern lassen. Eine Zeile je Typ genügt für den Bericht.
- **Kopieren statt Laden:** Eine Erweiterung hat wenig Speicher. Fünf große Dateien auf einmal waren zu viel. Kopieren braucht fast keinen Speicher.

## Swift-Konzepte
- **`URLProtocol`:** Ein eigener Protokoll-Handler beantwortet Anfragen einer `URLSession`, ohne Netz. Er muss Cache-Regeln wie `returnCacheDataDontLoad` selbst beachten.
- **`Mutex` (Modul `Synchronization`):** schützt einen Wert, den mehrere Threads lesen und schreiben, hier die Zähler der Lesefehler.
- **`FileHandle.read(upToCount:)`:** liest nur den Anfang einer Datei.
- **`widgetURL(_:)`:** der Link einer Live-Aktivität oder eines Widgets. Eine Szene bekommt ihn in `scene(_:openURLContexts:)`.

## Selbst nachprüfen
1. `scripts/check-architecture.sh` – meldet „architecture: ok“.
2. `git grep -nE "try\?.*\.fetch(Count)?\(" -- Packages/WattspurKit/Sources` – kein Treffer.
3. `scripts/coverage.sh` – `WattspurMap` über 90 %.
