# Testanleitung iPhone 1.6.5

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz. Neu ist B-369: Die Aufnahme überlastet das iPhone nicht mehr.

Fahre nur, wenn es sicher ist. Schau die Punkte im Stand an.

## 0. Vorher

- Den neuen Build installieren. *Mehr › Über Wattspur* zeigt seine Nummer.
- Deine echte Bibliothek ist richtig so: Der Fehler wuchs mit der Zahl der Fahrten.

## A. Am Schreibtisch (10 Minuten)

1. **Aufnahme starten, Pause, Weiter:** Knöpfe und Anzeige stimmen sofort.
2. **Hintergrund:** 3 Minuten eine andere App, dann zurück. Zeit, Strecke und Linie sind sofort aktuell.
3. **Pause von außen:** in der Live-Aktivität pausieren, Wattspur öffnen: „Pausiert“ steht da.
4. **Stopp und Sichern:** Name und Gerät wählen, die Fahrt steht in der Liste.
5. **Abbruch:** während einer Aufnahme Wattspur im App-Umschalter beenden, öffnen, „Aufnahme fortsetzen“: Sie läuft weiter.
6. **Querformat:** das iPhone drehen, dann Stopp: Das Fenster zum Sichern steht neben der Leiste.
7. **Übersicht:** Highlights, Ziele und „Fahrt starten mit …“ stimmen. Ein Ziel ändern: Die Kachel folgt. Ein anderes Gerät wählen: Der Knopf folgt.
8. **Geräte und Fahrten:** „Archivieren“, die Zahl der Fahrten eines Geräts und das Aufteilen einer zusammengeführten Fahrt stimmen.

## B. Rad (mindestens 45 Minuten)

Wie am 22.11.2026: Flow navigiert vorn, Wattspur im Hintergrund, Podcast läuft, Höhenfarben an.

1. Das iPhone bleibt flott, der Podcast läuft durch.
2. Beim Öffnen von Wattspur ist die Spur sofort da und **nirgends grau**.
3. Danach 10 Minuten mit Wattspur **vorn**: Es bleibt flott.

## C. Auto (mindestens 45 Minuten)

1. Aus CarPlay starten, Navigation vorn, iPhone gesperrt: Tempo und Strecke laufen in CarPlay weiter.
2. Das Gerät ist das Auto: CarPlay zeigt die Querbeschleunigung.
3. Ende aus CarPlay: Die Fahrt ist vollständig gesichert, mit Höhe.
4. `TESTANLEITUNG-1.6.4.md`, F.1, F.2, F.4 und F.5 mit diesem Build.
5. Auto-Start: „Bereit“ wird beim Losfahren zur Fahrt, auch in der Anzeige am iPhone.

## D. Danach

1. *Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten:* kein neuer Bericht `Wattspur.cpu_resource…`, kein `Wattspur…`-Absturz.
2. *Dateien › Auf meinem iPhone › Wattspur › Diagnose:* die Dateien von B und C an Claude geben. Sie enthalten keine Orte.

Erwartet im Protokoll:

| Spalte | Erwartet |
|---|---|
| `cpu_percent` | unsichtbar (`visible` 0) unter 15, ohne Anstieg |
| `memory_mb` | ohne stetigen Anstieg, unter 350 |
| `max_delay_s` | unter 2, außer beim Start |
| `no_barometer` | nach der ersten Minute 0 oder fast 0 |

**Bestanden:** A bis D ✓. Erst dann entscheidet Nils über das Einreichen im App Store.
