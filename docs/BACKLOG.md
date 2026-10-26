# Backlog – Wattspur

Stand: 26.10.2026 (v0.18, Plan für 1.7 in zwei Releases 1.7.0 und 1.7.1; davor v0.17 vom 25.10.2026, Release 1.6.2 mit Update-Hinweis B-172; davor 1.6.1 mit Sicherheits-Fix, Architektur-Aufräumen B-162 bis B-169 und zwei Karten-Verbesserungen B-170, B-171; Plan für 1.7 bis 1.9) · Die IDs in Klammern verweisen auf `REQUIREMENTS.md`.
Größe: **S** ≈ wenige Stunden, **M** ≈ 1–2 Tage, **L** ≈ mehrere Tage.
Status: ☐ offen · ◐ in Arbeit · ☑ erledigt

**Releaseplan (Hobbyprojekt, kein Termin):** kleine, jeweils nutzbare Zwischenstände.

| Release | Inhalt | Für wen |
|---|---|---|
| **v0.1** | Fundament + Import per Drag & Drop + Liste + Tour-Detail | mich |
| **v0.2** | Auswertung (Kumuliert & Trends) | mich |
| **v0.3** | Import ohne Aufwand (iCloud-Ordner), Profil, Einstellungen, Deutsch komplett | mich |
| **v1.0** | Robustheit, Erststart, Diagnose, Handbuch, Changelog, DMG | Freunde |
| **v1.1** | Fahrten zusammenfügen, ⌘Z, mehrere Fahrten löschen | Freunde |
| **v1.2** | Tourenvergleich, Teaser für Highlights und Karte in der Seitenleiste | Freunde |
| **v1.3** | Highlights: Jahresrückblick, Rekorde, Ziele; GPX-Export einer Fahrt | Freunde |
| **v1.4** | Karte aller Fahrten mit Heatmap | Freunde |
| **v1.4.2** | Fehlerbehebungen aus dem Test von 1.4.1: PDF der Karte, neue Wege, Rücksprung aus Highlights, Klick neben die Spuren | Freunde |
| **v1.4.3** | Aus dem Test von 1.4.1: keine Orte auf der Karte aller Fahrten, Zusammenfügen beim Import vorschlagen, Fügestellen, x-Achse Strecke oder Zeit, Diagramm und Karte gekoppelt | Freunde |
| **v1.5** | Profil und mehrere Bikes: Bereich „Profil“, Bike-Filter je Bereich, Kalorien „mit Profil“ | Freunde |
| **v1.6** | GPX-Import: Fahrten anderer Bikes und Radcomputer, FIT und GPX derselben Tour zusammenführen | Freunde, Tester mit anderen Bikes |
| **v1.6.1** | Sicherheits-Fix für beschädigte FIT-Dateien und Aufräumen der Architektur (zwei Module, Dienste, geteilte Bibliothek); keine neuen Funktionen | Freunde |
| **v1.6.2** | Update-Hinweis: Banner, wenn auf GitHub eine neuere Version liegt (B-172); Auto-Update bleibt offen (B-173) | Freunde |
| **v1.7.0** | Ähnliche Strecken (suchen, filtern, vergleichen, Verlauf) und weitere Rekorde; dazu B-161 und B-174 | Freunde |
| **v1.7.1** | Strecken-Gruppen (erkennen, benennen, Neuzuordnung beim Import) | Freunde |
| **v1.8** | Ein Bereich „Fahrten“ mit Karte als Standard (B-125), Kalendertag als Filter (B-130) | Freunde |
| **v1.9** | Bosch-Daten über die offizielle Data-Act-API (optional, eigenes Bosch-Konto): Bike, Akku und Wartung, Zusatzfelder je Fahrt und Import von Fahrten ohne Datei (Altbestand). **Motordaten je Fahrt gibt die API nicht her (Spezifikation 25.10.2026), Entscheidung Nils: Option B;** steht unter dem Vorbehalt des Spikes V-12 | Freunde mit Smart-System-Bike in der EU |
| v1.x | Analysen, Komfort, Karten | alle |

**Definition of Done:** Kernlogik mit Unit-Tests (WattspurKit), CI grün (GitHub Actions; ohne verfügbare Runner der Check „local-ci“ aus `scripts/ci-local.sh`), Änderung als Branch mit Code-Review vor dem Merge nach `main`, Texte lokalisierbar (EN/DE), Grundniveau Barrierefreiheit (NFR-16), **Erklärung der Story** (was, warum, welche Swift-Konzepte) im PR bzw. in `docs/learning/`.

---

## v0.1 – Fundament, Import, Liste, Tour-Detail

| # | Story | Größe | Status |
|---|---|---|---|
| B-001 | Xcode-Projekt: SwiftUI-App für **macOS 26+** (Multiplatform-fähig) + lokales Swift Package `WattspurKit`, Git-Repo mit `.gitignore` für echte Fahrtdaten (NFR-12), Bundle-ID veröffentlichungsfähig (NFR-13) | S | ☑ |
| B-009 | GitHub-Repo (zunächst privat), CI mit GitHub Actions (Build + Tests von WattspurKit), Branch-Schutz für `main` und PR-Workflow mit Review (NFR-14). Branch-Schutz für private Repos erst mit GitHub Pro, bis dahin als Absprache | S | ◐ |
| B-002 | **Spike FIT-Parser:** Garmin FIT SDK (Swift) und eigenen Decoder an der Beispielfahrt vergleichen; Entscheidung nach Vollständigkeit, Robustheit gegen fremde/beschädigte Dateien, Lizenz für GitHub, Größe, Wartung; Ergebnis als kurze Notiz in `docs/` (NFR-11, NFR-19) | M | ☑ |
| B-003 | Datenmodell: `Rider`, `Bike`, `Ride` (Metadaten + Bosch-Summen + Quelle), `RideSamples` (1-Hz-Zeitreihe), `SourceFile` (Original), mit SwiftData persistiert und CloudKit-fähig (Req. Kap. 7) | M | ☑ |
| B-004 | GPS- und Sensor-Strom zu einer 1-Hz-Zeitreihe zusammenführen; Trittfrequenz für die Darstellung halten, Rohwerte für die Statistik markieren (Req. 3.3) | M | ☑ |
| B-005 | Referenztest mit der Beispielfahrt: Summen exakt wie in der `session` (2916 s, 19 543 m, 6,703 m/s, 166/169 m, 135 W, 60 1/min, Max 15,142 m/s / 460 W / 82 1/min) (NFR-04) | S | ☑ |
| B-006 | Ortszeit über die Zeitzone der Startkoordinate ermitteln (Bug `local_timestamp`) | S | ☑ |
| B-007 | Schnittstellen `RideImporter`, `CalorieEstimator` und `MapProvider` anlegen; Standard-Fahrer und -Bike automatisch erzeugen | S | ◐ |
| B-008 | Lokalisierung einrichten: String Catalog, Englisch als Entwicklungssprache, Deutsch als zweite Sprache; Formatierung über `Measurement` und `FormatStyle` (NFR-10) | S | ☑ |
| B-010 | Als Fahrer ziehe ich FIT-Dateien ins Fenster oder wähle sie im Dialog aus, um Fahrten zu importieren (IMP-01) | M | ☑ |
| B-011 | Duplikate erkennen; beim manuellen Import nachfragen (überspringen/aktualisieren, lokale Änderungen bleiben) (IMP-02) | S | ☑ |
| B-012 | Der Tourname kommt aus dem Dateinamen, die UUID wird abgetrennt (IMP-03) | S | ☑ |
| B-013 | Originaldateien werden in die App-Bibliothek kopiert (IMP-07) | S | ☑ |
| B-021 | App-Gerüst im Mac-Stil: Seitenleiste (Statistiken, Auswertung), Werkzeugleiste, Detailbereich (Req. Kap. 6) | S | ☑ |
| B-014 | Statistik-Liste mit Name, Fahrzeit, Strecke, Ø Geschw. und relativem Datum, dazu „N Fahrten insgesamt“ (LIST-01, LIST-03) | M | ☑ |
| B-015 | Fahrt umbenennen; löschen in den Papierkorb mit ⌘Z (LIST-07, TOUR-09) | S | ☑ |
| B-016 | Tour-Detail: MapKit-Karte mit Route und Start/Ziel, Kartentyp umschaltbar (TOUR-01, MAP-01) | M | ☑ |
| B-017 | Tour-Detail: Kennzahlen-Raster wie in der Flow-App (TOUR-02, TOUR-03) | S | ☑ |
| B-018 | Kalorien („aus Arbeit“) und CO₂ nach den Hypothesen berechnen; Faktoren zentral konfigurierbar (Req. 3.4) | S | ☑ |
| B-019 | Tour-Detail: Diagramme Höhe, Geschwindigkeit, Trittfrequenz, Leistung über km mit Max/Ø (TOUR-04) | M | ☑ |
| B-020 | Tour-Detail: Zusatzkennzahlen wie Pausenzeit, Arbeit (kJ) und Min/Max-Höhe (TOUR-05) | S | ☑ |
| B-022 | Suche, Sortierung und Zeitraumfilter in der Liste (LIST-05) | S | ☑ |

## v0.2 – Auswertung (Kumuliert & Trends)

| # | Story | Größe | Status |
|---|---|---|---|
| B-030 | Bereich „Auswertung“: Zeitraum-Auswahl oben, darunter Summen und gewichtete Durchschnitte (AGG-01, AGG-02, AGG-03) | M | ☑ |
| B-031 | Mehrfachauswahl in der Liste öffnet die Auswertung für diese Fahrten (LIST-06) | S | ☑ |
| B-032 | Balkendiagramm je Woche, Monat oder Jahr (AGG-04) | M | ☑ |
| B-033 | Trendverläufe: Ø Leistung, Trittfrequenz und Geschwindigkeit je Fahrt mit gleitendem Mittel (TREND-01) | M | ☑ |
| B-034 | Veränderung zum Vorzeitraum (± %) je Woche oder Monat (TREND-02) | S | ☑ |

## v0.3 – Import ohne Aufwand, Profil, Einstellungen

| # | Story | Größe | Status |
|---|---|---|---|
| B-040 | iCloud-Drive-Ordner `Wattspur Import` überwachen (security-scoped bookmark, Import auch beim App-Start); erfolgreich importierte Dateien nach `Importiert/`, fehlerhafte nach `Fehlerhaft/` verschieben (IMP-05, SET-02, NFR-05) | M | ☑ |
| B-041 | Import-Protokoll mit verständlichen Fehlermeldungen (IMP-06, NFR-11) | S | ☑ |
| B-049 | Lokales Benutzerprofil beim ersten Start anlegen (Name, optional Avatar), Profil = `Rider` (ACC-01) | S | ☑ |
| B-027 | Einrichtungsassistent beim ersten Start: Profilname, Import-Ordner, Hinweis zum Export (ONB-01) | M | ☑ |
| B-029 | Leere Ansichten mit Hinweis und Import-Aktion (ONB-03) | S | ☑ |
| B-042 | Einstellungsfenster: Kartentyp, Import-Ordner, Sprache (SET-01, SET-02, SET-07) | S | ☑ |
| B-044 | Deutsche Übersetzung vervollständigen und prüfen (NFR-10) | S | ☑ |
| B-023 | Papierkorb-Ansicht: wiederherstellen, nach 30 Tagen endgültig löschen, „Papierkorb leeren“ (LIST-08) | S | ☑ |
| B-024 | Parser-Version je Fahrt speichern und betroffene Fahrten nach einem Update automatisch neu auswerten (NFR-17) | M | ☑ |

## v1.0 – Freunde-Version

| # | Story | Größe | Status |
|---|---|---|---|
| B-045 | Testdateien von Freunden bzw. anderen Bosch-Systemen importieren und Fehler beheben (NFR-11). Erste fremde Datei (Tester mit Flow+-Abo, 101 km, 10 h mit 15 Pausen) geprüft: gleiches Format, Import fehlerfrei, Summen stimmen; keine Fehler zu beheben | M | ☑ |
| B-080 | Benutzerhandbuch auf GitHub in Englisch und Deutsch unter `docs/user-guide/`, inkl. Export-Anleitung aus der Flow-App mit Screenshots (DOC-01, DOC-02). Dazu Kennzahlen (DOC-03) und FAQ (DOC-05); Screenshots nur von Wattspur selbst, die Flow-App-Schritte als Text (NFR-12) | M | ☑ |
| B-081 | `CHANGELOG.md` anlegen und je Build pflegen (DOC-04) | S | ☑ |
| B-025 | Barrierefreiheit prüfen: VoiceOver-Durchgang durch alle Ansichten, Audio Graphs für die Diagramme, Tastaturbedienung (NFR-16) | M | ☑ |
| B-046 | App-Icon und DMG-Build für Freunde: ad-hoc signiert, Build-Skript, Anleitung zum ersten Öffnen trotz Gatekeeper (NFR-18) | M | ☑ |
| B-026 | Menübefehl „Diagnose erstellen“ mit Protokoll, Versionen und optional der fehlerhaften Datei (SUP-01) | S | ☑ |
| B-094 | Info-Fenster „Über Wattspur“: Version, Build, Git-Commit, © Nils Wiese, MIT-Lizenz, Marken- und Datenschutzhinweis, Hinweis zu Schätzwerten (NFR-09) | S | ☑ |
| B-028 | Optionale anonymisierte Beispielfahrt im Erststart (ONB-02; setzt V-05 voraus) | S | ☑ |

---

## v1.2 – Tourenvergleich (Tester-Wunsch 21.10.2026)

Entschieden mit Nils (21.10.2026, Mockup „Compare“ auf dem Design-Canvas): Der Vergleich steht rechts neben der Liste, die markierten Fahrten **sind** der Vergleich (⌘-Klick fügt hinzu, × hebt die Markierung auf). Stern für den besten Wert nur bei Ø Geschwindigkeit, Ø Leistung, Ø Leistung über die Fahrzeit (mehr ist besser) und Pausen (weniger ist besser); alles andere neutral. Schnitt = alle Fahrten außer Beispielfahrt und Papierkorb, je Fahrt; Ø-Werte nach Fahrzeit gewichtet wie in der Auswertung. Die Beispielfahrt lässt sich vergleichen, zählt aber nicht zum Schnitt; eine zusammengefügte Fahrt ist eine Fahrt. Kürzel: Highlights ⌘4, Karte ⌘5, Papierkorb bleibt ⌘3.

| # | Story | Größe | Status |
|---|---|---|---|
| B-098 | Vergleichslogik im Kit: Kennzahlen je Fahrt, „besser“-Richtung je Kennzahl, bester Wert je Zeile, abgeleitete Werte (kcal/km, m/km, kJ/km, Rollanteil), Abweichung vom Schnitt aller Fahrten; mit Tests (CMP-02 bis CMP-04) | M | ☑ |
| B-099 | Mockup der Vergleichsansicht auf dem Design-Canvas (Tabelle + übereinandergelegte Diagramme, hell/dunkel) und Abstimmung | S | ☑ |
| B-100 | Einstieg: Knopf „Vergleichen“ bei 2–4 markierten Fahrten, sonst deaktiviert mit Hinweis (CMP-01) | S | ☑ |
| B-101 | Vergleichstabelle mit Spalte je Fahrt, Hervorhebung des besten Werts (Symbol + Farbe), Umschalter „Abweichung vom Schnitt“ (CMP-02, CMP-04) | M | ☑ |
| B-102 | Übereinandergelegte Diagramme (Höhe, Geschw., Trittfrequenz, Leistung) mit Legende und farbfehlsichtig-tauglicher Palette (CMP-05) | M | ☑ |
| B-103 | Fahrt im Vergleich öffnen, entfernen, hinzufügen (CMP-06); Export als PDF (CMP-07, auf Wunsch von Nils vorgezogen; als Bild später mit P-20). Dazu auf Wunsch beim Testen: Karte aller verglichenen Routen, Ø-Werte bzw. Anstieg/Abstieg/steilste Stelle über den Diagrammen | S | ☑ |
| B-111 | Teaser in der Seitenleiste: Einträge „Highlights“ (⌘4, Pokal) und „Karte“ (⌘5) mit dem Hinweis „bald“; sie öffnen eine Platzhalter-Ansicht „Kommt in Version 1.3/1.4“ mit kurzer Beschreibung, ohne Daten (Mockup „Teaser“) | S | ☑ |

## v1.3 – Highlights und GPX-Export

Ein Seitenleisten-Eintrag „Highlights“ (⌘4) mit den Reitern Jahr, Rekorde und Ziele. Entwurf auf dem Design-Canvas: Artboards „Highlights“ und „RecordHints“ (Jahreskachel, Hinweis „Neuer Rekord“, Rekord-Abzeichen, GPX-Knopf und Kontextmenü), von Nils am 22.10.2026 abgenommen; Entscheidungen in REQUIREMENTS.md 10.10. Dazu kommt der GPX-Export einer Fahrt (B-112, Entscheidung von Nils 22.10.2026); sein Knopf steht im Tour-Detail neben „PDF exportieren“. Jeder Reiter bekommt oben links „PDF exportieren“ wie Vergleich und Tour-Detail (`PDFExport`, Wunsch von Nils 21.10.2026).

| # | Story | Größe | Status |
|---|---|---|---|
| B-050 | Jahresrückblick mit Kalender-Heatmap und Jahreskachel auf Home (ADV-J1, LIST-04); ersetzt den Teaser aus B-111 | L | ☑ |
| B-051 | Rekorde berechnen und eigene Rekord-Ansicht (ADV-R1) | M | ☑ |
| B-052 | Hinweis „Neuer Rekord“ beim Import (ADV-R2) | S | ☑ |
| B-053 | Ziele je Woche, Monat oder Jahr mit Fortschritt (ADV-Z1) | M | ☑ |
| B-112 | GPX-Export einer Fahrt für komoot, Navigationsgeräte usw.: „Als GPX exportieren …“ im Tour-Detail neben „PDF exportieren“ und im Kontextmenü der Liste; GPX 1.1 mit Zeit, Höhe, Position, Leistung/Trittfrequenz als Erweiterung; zusammengefügte Fahrten mit einem Segment je Teil; Writer im Kit mit Tests (gültiges XML, Rundreise mit dem späteren GPX-Import B-060) (IMP-09, Wunsch von Nils 21.10.2026; auf seine Entscheidung vom 22.10.2026 in v1.3) | S | ☑ |
| B-113 | Hinweis auf ⌘-Klick für die Mehrfachauswahl: dezenter Tipp unter der Fahrtenliste (mit ✕) und in der leeren Detailansicht; verschwindet nach der ersten Mehrfachauswahl oder mit ✕ (`@AppStorage`). Tester-Feedback zum Tourenvergleich, Mockup „⌘-click hint“, von Nils am 22.10.2026 abgenommen | S | ☑ |

## v1.4 – Karte aller Fahrten mit Heatmap (Wunsch 21.10.2026)

Vorbild: Heatmap der eigenen Fahrten bei komoot. Entschieden: beide Darstellungen umschaltbar, Filter Zeitraum + markierte Fahrten, Klick zeigt die Fahrten an dieser Stelle, **keine** Privatzone. Oben links „PDF exportieren“ wie in Vergleich und Tour-Detail. Plan mit Nils abgestimmt am 22.10.2026 (REQUIREMENTS.md 10.11); Artboards „Map“, „MapDark“, „MapHeat“, „MapHeatDark“, „MapFocus“, „MapEmpty“ und „MapPDF“ auf dem Design-Canvas abgenommen; Kacheln für den Kartenausschnitt (B-114) nachträglich ergänzt. Dazu auf Wunsch von Nils aus dem Backlog: Routen-Vorschau in der Liste (B-064) und „neue Wege“ aus P-12 (B-115), Artboards „NewPaths“ und „NewPathsDark“.

Entschieden mit Nils (22.10.2026, Mockup „Map“ auf dem Design-Canvas): Kopfzeile wie im Vergleich (PDF-Knopf, Titel, Summe „Fahrten · km · Zeitraum“), rechts Umschalter **Linien | Wärmekarte**. Darunter der Zeitraum wie in der Auswertung (Woche, Monat, Jahr, Zeitraum …, Alle; ‹ › zum Blättern) und der Schalter „Nur markierte Fahrten (n)“: Er zeigt die markierten Fahrten in Farbe und Strichart des Vergleichs, Zeitraum und Darstellung sind dann ausgegraut. Linien: je Fahrt eine dünne, halbtransparente Linie, oft gefahrene Wege breiter und kräftiger, Linienfarbe Magenta (hebt sich vom Kartengrün ab); Legende „1× · 5× · 20× · 60×+“ zeigt Breite und Deckkraft. Wärmekarte: weichgezeichnete Bänder mit der Skala aus TOUR-08 (blau → rot), Legende „selten → oft“. Klick auf eine Strecke hebt sie hervor; Popover „n Fahrten an dieser Stelle“ mit Abschnitt (Ort – Ort), je Fahrt Name, Datum, km, Klick öffnet die Fahrt, unten „Alle n in der Liste markieren“. Auf der Karte: Kartentyp oben rechts, Legende unten links, unten rechts „Alle Fahrten zeigen“, Zoom und Kompass. *(Layout aus dem Mockup, nachgetragen aus der v1.4-Sitzung. Bei Abweichungen zu Farbe, Legende und Stufen gelten Requirements Kap. 10.11 und B-107/B-108.)*

**Reihenfolge und PRs:** je Zeile ein PR direkt gegen `main`; der nächste beginnt erst nach dem Merge des vorigen (keine gestapelten PRs). Check: `scripts/ci-local.sh` („local-ci“), solange GitHub Actions keine Minuten hat.

| PR | Inhalt | Kit | App |
|---|---|---|---|
| 1 | B-104 | `RouteSimplifier`, Kodierung, `RouteIndex`, Nachberechnung des Bestands | – |
| 2 | B-064 | – | Routen-Vorschau in der Fahrtenliste aus der Übersichtsroute |
| 3 | B-106 + B-107 + B-114 | Filter (Zeitraum, markiert), Fahrten im Ausschnitt | Bereich „Karte“ mit `MKMapView` und eigenem Overlay-Renderer, Linien-Heatmap, Legende, leere Zustände, Fortschritt, PDF |
| 4 | B-108 | `RouteDensity` (Raster, Stufen) | Wärmekarte im Renderer, Legende, PDF |
| 5 | B-109 | `RouteHitTest` | Popover, Fahrt hervorheben mit Infofeld, „Alle markieren“ |
| 6 | B-123 + B-124 | – | Fahrtenliste links in Karte und Auswertung, nur Fahrten im Ausschnitt bzw. der Auswertung |
| 7 | B-115 | „Neue Wege“ aus einem festen 50-m-Raster | Kennzahl und Hervorhebung im Tour-Detail, Infofeld und Kachel auf der Karte |
| 8 | Release 1.4.0 | – | Version, Changelog, Handbuch EN/DE, Katalogabgleich, DMG |

| # | Story | Größe | Status |
|---|---|---|---|
| B-104 | Routen aller Fahrten für die Übersicht aufbereiten: Douglas-Peucker mit **5 m** Toleranz, ein Segment je Teil einer zusammengefügten Fahrt (keine Linie über die Lücke), kompakt kodiert (E6-Ganzzahlen mit Deltas). Gespeichert in zwei Feldern an `Ride` (`overviewRouteData: Data?`, `overviewRouteVersion: Int = 0`, CloudKit-fähig); berechnet bei Import, Neu-Auswertung, Zusammenfügen und Trennen, für den Bestand einmal im Hintergrund in Paketen (höhere Version = neu berechnen). Flüssig bei 1 000 Fahrten; Tests: Abweichung ≤ 5 m an der Beispielfahrt, Sonderfälle, Kodierung, Nachberechnung ohne Verlust lokaler Änderungen, Lasttest mit 1 000 synthetischen Fahrten | M | ☑ |
| B-105 | Mockup „Karte“ auf dem Design-Canvas (Linien- und Flächen-Heatmap, Filter, Popover, hervorgehobene Fahrt, leere Zustände, PDF, hell/dunkel) und Abstimmung | S | ☑ |
| B-106 | Seitenleisten-Eintrag „Karte“ (⌘5, ersetzt den Teaser aus B-111): alle Fahrten außer Beispielfahrt, Papierkorb und Teilen; Zeitraum wie in der Auswertung (Woche/Monat/Jahr/Zeitraum …/Alle mit ‹ ›), eigene gemerkte Auswahl, Standard „Alle“; Schalter „Nur markierte Fahrten“ (Zeitraum dann ausgegraut; 1–4 Fahrten in Farbe und Strichart wie im Vergleich, ab 5 Heatmap nur über die markierten); Kartentyp wie im Tour-Detail; Untertitel mit Anzahl, km und „N ohne GPS“; leere Zustände (keine Fahrten, Zeitraum leer) und Fortschritt „Routen werden vorbereitet“; „PDF exportieren“ mit dem sichtbaren Ausschnitt, A4 hochkant; Ausschnitt und Zoom bleiben beim Wechsel zu einem anderen Bereich erhalten; „In der Karte zeigen“ in der Auswertung zeigt genau deren Fahrten auf der Karte, mit Chip zum Zurückkehren (beides Wünsche von Nils nach dem ersten Test) (AGG-05) | M | ☑ |
| B-114 | Kacheln unter der Karte für die Fahrten im Kartenausschnitt: Fahrten, Strecke, Fahrzeit, Anstieg, Ø Geschwindigkeit (nach Fahrzeit gewichtet); es zählen ganze Fahrten, deren Route den Ausschnitt berührt, mit ihren Bosch-Summen; aktualisiert, sobald Schieben oder Zoomen endet, Beschriftung „Im Kartenausschnitt: N von M Fahrten“; „In der Auswertung zeigen“ öffnet die Auswertung für genau diese Fahrten (wie LIST-06); auch im PDF (Wunsch von Nils 22.10.2026) | S | ☑ |
| B-064 | Routen-Vorschau in der Fahrtenliste: Quadrat 44 pt links in jeder Zeile, Route als Linie in der Akzentfarbe (weiß in der markierten Zeile) auf ruhigem Grund, grüner Startpunkt, ohne Kartenkacheln; zusammengefügte Fahrt mit einem Strich je Teil; ohne GPS ein Symbol; VoiceOver „Rundfahrt“ bzw. „Strecke von A nach B“. Aus der Übersichtsroute (B-104), flüssig bei 1 000 Fahrten (LIST-02; aus v1.x vorgezogen 22.10.2026) | S | ☑ |
| B-107 | Linien-Heatmap wie komoot: halbtransparente Linien in Magenta (#C2187A hell, #FF4FAE dunkel), oft gefahrene Wege breiter und kräftiger, Legende „Wie oft gefahren“ mit Linienproben (MAP-04a) | M | ☑ |
| B-108 | Flächige Wärmekarte: Dichte-Raster mit Zellen von etwa 16 pt, die sich dem Zoom anpassen; jede Fahrt zählt je Zelle einmal; feste Stufen 1 / 2–4 / 5–9 / 10–19 / 20+ in Blau → Türkis → Gelb → Orange → Rot, gleich in jedem Zeitraum; Legende mit Zahlen (MAP-04b) | M | ☑ |
| B-109 | Klick auf eine Strecke (bis 10 pt daneben): Popover mit den Fahrten dort (Name, Datum, km, neueste zuerst), „Alle N in der Liste markieren“; Klick auf eine Fahrt hebt sie auf der Karte hervor (übrige treten zurück) und zeigt ein Infofeld mit Kennzahlen und „Im Tour-Detail öffnen“ (MAP-05) | S | ☑ |
| B-123 | Karte: links eine Fahrtenliste wie unter „Fahrten“ (Kopf mit „N von M Fahrten im Kartenausschnitt“, Import, Suche, Monatsüberschriften, Zeilen mit Routen-Vorschau), nur die Fahrten im sichtbaren Ausschnitt, folgt dem Schieben und Zoomen; Markierung gemeinsam mit „Fahrten“, eine markierte Fahrt wird auf der Karte hervorgehoben; Doppelklick bzw. „Im Tour-Detail öffnen“ öffnet sie, „Zurück zur Karte“ (⌘[) führt zurück (Wunsch von Nils 22.10.2026, Artboard „RidesColumn“) | M | ☑ |
| B-124 | Auswertung: dieselbe Fahrtenliste links, nur die ausgewerteten Fahrten (Zeitraum oder Auswahl), Markierung gemeinsam mit „Fahrten“ (Wunsch von Nils 22.10.2026, Artboard „RidesColumnAnalysis“) | S | ☑ |
| B-115 | „Neue Wege“ (Teil von P-12): Anteil und km der Strecke einer Fahrt in 50-m-Zellen, durch die vorher noch keine Fahrt lief („vorher“ = früher gestartete Fahrten außer Beispielfahrt und Papierkorb; Teile zusammengefügter Fahrten mit ihrem eigenen Zeitpunkt). Im Tour-Detail als Kennzahl „Neue Wege 23 % · 4,5 km“ und auf der Karte der Fahrt die neuen Stücke breiter in eigener Farbe mit Legende „neu / schon gefahren“; im Infofeld der Karte (B-109) und als Kachel „Neue Wege“ im Kartenausschnitt (B-114). Im Kit mit Tests (IDEA-12) | M | ☑ |

## v1.4.2 – Fehlerbehebungen aus dem Test von 1.4.1 (24.10.2026)

Feedback von Nils nach dem Test von 1.4.1, mit ihm am 24.10.2026 geklärt (REQUIREMENTS.md 10.14). Je Zeile ein PR gegen `main`, zuletzt Release 1.4.2 (Version, Changelog, Handbuch EN/DE falls betroffen, DMG).

| # | Story | Größe | Status |
|---|---|---|---|
| B-126 | **Bug:** Im PDF der Karte sind die Routen an der Waagerechten gespiegelt (Nord ↔ Süd), die Kartenkacheln stimmen; dadurch passt das Overlay nicht zur Karte (Beispiel 24.10.2026: Schwerpunkt Reinheim/Ober-Ramstadt landet bei Bensheim). Betrifft Linien und Wärmekarte. Ursache: `MKMapSnapshotter.Snapshot.point(for:)` zählt y unter macOS 26 von unten, die PDFs zeichnen von oben; behoben mit `topDownPoint(for:height:)`, das die Zählrichtung selbst erkennt, auch im Fahrt- und Vergleichs-PDF (PR #43) | S | ☑ |
| B-127 | **Bug:** Neue Wege fehlen manchmal auf der Karte im Tour-Detail: die ganze Route ist blau, obwohl die Fahrt neue Stücke hat; nach etwas Hin- und Herwechseln zwischen Fahrten stimmt es. Klick-Reihenfolge noch unbekannt, zuerst reproduzieren (Wechsel zwischen Fahrten, Neuberechnung nach Import, Fahrt direkt nach App-Start öffnen). Der Fix aus 1.4.1 (neue Wege über der Route) deckt diesen Fall nicht ab. Nachstellen gelang nur vereinzelt (1 von rund 250 simulierten Wechseln), die Daten waren dabei vollständig; Ursache: SwiftUI-`Map` legt ihre Linien in der Reihenfolge übereinander, in der sie MapKit erreichen, und bietet keine feste Ebene. Behoben, indem die Karte im Tour-Detail ein `MKMapView` mit einem Overlay ist, das Route und neue Stücke selbst in fester Reihenfolge zeichnet | M | ☑ |
| B-128 | Rücksprung aus den Highlights: Wer aus dem Kalender oder einem Rekord zu Fahrten springt, bekommt über dem Tour-Detail bzw. der Mehrfachauswahl „‹ Zurück zu Highlights“ (⌘[) wie bei Karte und Auswertung; zurück auf denselben Reiter und dasselbe Jahr | S | ☑ |
| B-129 | Klick auf die Karte aller Fahrten neben jede Spur (außerhalb der 10 pt aus B-109): hebt die Markierung in der Liste auf, schließt Popover und Infofeld und nimmt die Hervorhebung zurück. Bisher blieb die zuletzt markierte Fahrt auch in der Wärmekarte dunkelblau. Ausnahme: Bei „Nur markierte Fahrten“ bleibt die Markierung, weil sie dann die gezeigten Fahrten bestimmt | S | ☑ |

## v1.4.3 – Wünsche aus dem Test von 1.4.1 (Plan 24.10.2026)

Mit Nils am 24.10.2026 festgelegt (REQUIREMENTS.md 10.15): die kleinen Wünsche aus dem Test von 1.4.1 vorab als 1.4.3, die größeren Umbauten B-125 und B-130 als 1.5. Fast alles betrifft das Tour-Detail.

**Reihenfolge und PRs:** je Zeile ein PR direkt gegen `main`; der nächste beginnt erst nach dem Merge des vorigen. Check: `scripts/ci-local.sh` („local-ci“).

| PR | Inhalt | Kit | App |
|---|---|---|---|
| 1 | B-132 | – | Filter für Orte an der Kartenkonfiguration der Karte aller Fahrten und der PDF-Karten |
| 2 | B-096 | Kandidaten zum Zusammenfügen erkennen (mit Tests) | Hinweis nach dem Import, Eintrag im Import-Protokoll, vorhandener Zusammenfügen-Dialog |
| 3 | B-131 | Grenzen der Teile in Kilometern bzw. Sekunden der Zeitreihe (mit Tests) | Striche in den Diagrammen, Querstriche im Renderer der Fahrtkarte, PDF der Fahrt |
| 4 | B-065 | Zeitachse der Diagrammpunkte (Fahrzeit ab Start) | Umschalter, Achsenbeschriftung, gemerkte Auswahl |
| 5 | B-062 | – | gemeinsame Position der Diagramme, Punkt und Mausverfolgung auf der Fahrtkarte, Festhalten, Esc |
| 6 | Release 1.4.3 | – | Version, Changelog, Handbuch EN/DE, DMG, Tag |

| # | Story | Größe | Status |
|---|---|---|---|
| B-132 | **Bug:** Auf der Karte aller Fahrten erscheinen Orte und Gebiete (z. B. „Naturpark Harz“), weil die Kartenkonfiguration den Filter für Orte überschreibt (wie bei B-127 im Tour-Detail). Filter an der Konfiguration setzen, für alle Kartentypen; dabei die Karten in den PDFs (Fahrt, Vergleich, Karte) prüfen und gleich behandeln (gefunden beim Test von B-127, 24.10.2026) | S | ☑ |
| B-096 | Zusammenfügen beim Import vorschlagen: Kandidaten am selben Tag erkennen (Lücke unter dem einstellbaren Wert, Ende nahe am Start der nächsten, auch mit schon vorhandenen Fahrten) und nach dem Import als Hinweis zeigen: „2 Fahrten vom 15. Okt. gehören wohl zusammen“ mit „Zusammenfügen“ und „Nicht jetzt“; auch im Import-Protokoll; nie automatisch (LIST-10, REQUIREMENTS.md 10.7; aus v1.x vorgezogen nach dem Test von 1.4.1) | S | ☑ |
| B-131 | Fügestellen zusammengefügter Fahrten zeigen: in den Diagrammen des Tour-Details ein feiner senkrechter Strich in der Farbe des Diagramms, auf der Karte des Tour-Details ein kleiner schwarzer Querstrich quer (90°) zum Pfad, der ihn ein paar Punkte überragt; beides auch im PDF der Fahrt. Nicht im Tourenvergleich. Bei räumlicher Lücke zwischen den Teilen bekommen beide Enden einen Querstrich (entschieden 24.10.2026). (Feedback 1.4.1, Skizze von Nils) | S | ☑ |
| B-065 | x-Achse der Diagramme im Tour-Detail zwischen Strecke und Zeit umschalten: Umschalter „Strecke“/„Zeit“ über den Diagrammen, gilt für alle vier, Auswahl gemerkt; Zeit als Fahrzeit ab Start (h:mm), Pausen und Lücken zusammengefügter Fahrten ohne Linie; nicht im Vergleich (dort weiter Strecke, CMP-05). Vor B-062, damit die Kopplung gleich auf beiden Achsen entsteht (TOUR-07; aus v1.x vorgezogen 24.10.2026) | S | ☑ |
| B-062 | Diagramm und Karte im Tour-Detail koppeln: Mauszeiger über einem Diagramm zeigt einen senkrechten Strich an derselben Stelle in **allen** Diagrammen, die Werte dort und einen Punkt auf der Karte; umgekehrt zeigt der Mauszeiger auf der Route den Punkt und die Striche in den Diagrammen. Klick hält die Position fest, erneuter Klick oder Esc löst sie. Funktioniert auf beiden x-Achsen (B-065); nicht im PDF. VoiceOver: Position per Audio Graph ansagen (TOUR-06; aus v1.x vorgezogen nach dem Test von 1.4.1) | M | ☑ |

## v1.5 – Profil und mehrere Bikes (Plan 25.10.2026)

Erste Tester haben mehr als ein eBike mit Smart System und wollen sie getrennt auswerten; deshalb vor allen anderen Plänen. Entschieden mit Nils am 25.10.2026 (REQUIREMENTS.md 10.16):
- **Umfang:** ein lokales Profil mit Körperdaten und Kalorienmodus „mit Profil“, mehrere Bikes je Profil. Mehrere Fahrer und Profilwechsel (B-073, B-086) bleiben „später“.
- **Körperdaten:** Gewicht (kg), Größe (cm), Geburtsjahr (das Alter ergibt sich je Fahrt), Geschlecht männlich / weiblich / keine Angabe (dann Mittelwert der Formel).
- **Kalorien „mit Profil“:** Arbeit ÷ Wirkungsgrad wie heute **plus Grundumsatz** über die Dauer der Fahrt (Mifflin-St Jeor). Fehlt eine Angabe, gilt „aus Arbeit“ mit Hinweis.
- **Zuordnung:** neue Fahrten gehen an das **aktive Bike**, dazu nachträgliches Zuweisen. Keine Unterordner, keine Rückfrage beim Import (Bosch-Exporte haben keine Bike-Kennung).
- **Bike-Daten:** Name, Farbe und Symbol, Foto, Hersteller, Modell, Antrieb, Akku (Wh), Kaufdatum, km-Startwert, Gewicht (nur Info, wird nicht verrechnet). Das Foto erscheint nur im Editor und in der Profil-Kachel, überall sonst das farbige Symbol.
- **Ort und Aktives Bike:** Eintrag „Profil“ in der Seitenleiste; das aktive Bike wird dort mit einem Stern festgelegt und zusätzlich über ein Menü in der Werkzeugleiste umgeschaltet.
- **Filter:** je Bereich (Fahrten, Auswertung, Karte, Highlights), jeweils gemerkt. In den Highlights folgen Jahresrückblick und Rekorde dem Filter, **Ziele zählen über alle Bikes**.
- **Bike entfernen:** archivieren; die Fahrten bleiben zugeordnet, das Bike verschwindet aus dem Import-Menü und bleibt in den Filtern.
- **Anzeige:** Symbol in der Listenzeile (ab 2 Bikes), Menü im Tour-Detail, Zeile im Vergleich, Name im PDF der Fahrt und im GPX.
- **Umstieg:** das Standard-Bike heißt „Mein eBike“; nach dem Update ein einmaliger Hinweis „Lege deine Bikes an“. Der Einrichtungsassistent bekommt den Schritt „Erstes Bike“.

Entschieden mit Nils (25.10.2026, Mockup auf dem Design-Canvas, Artboards „Profile“, „BikeEditor“, „ImportFor“, „BikeFilter“, „BikeAssign“, „BikeDisplay“, „UpdateHint“ und „OnboardingBike“, je hell und dunkel): **Art statt freiem Symbol.** Der Editor bietet wie komoot vier Arten – Fahrrad, Mountainbike, Rennrad, Gravelbike – in unserem Grau und dazu den Schalter **E-Bike** (Standard an). Das Symbol in Liste, Menüs und Kachel folgt der Art und trägt die Farbe des Bikes. **Profil:** oben Avatar, Name, Körperdaten und der Kalorienstatus (der Modus selbst bleibt in den Einstellungen, SET-06); darunter Bike-Kacheln in drei Spalten mit Foto (ohne Foto das Symbol), Stern am aktiven Bike, Kennzahlen Strecke (inkl. Startwert), Fahrten, letzte Fahrt; „Archivierte Bikes“ klappt darunter auf, mit „Wiederherstellen“. **Import für:** Menü „Import für: ● Bike ▾“ in der Werkzeugleiste über Liste und Detail, nur ab 2 Bikes; Einträge je Bike mit Häkchen und „Bikes verwalten …“. **Filter:** Chip „Bike: Alle ▾“ als Einzelauswahl (Alle Bikes, aktive Bikes, Abschnitt „Archiviert“) über der Fahrtenliste, neben dem Zeitraum in Auswertung und Karte, neben den Reitern der Highlights; Jahr und Rekorde folgen dem Filter, die Ziele zeigen ein Schloss („immer alle Bikes“). **Zuweisen:** Kontextmenü „Bike zuweisen ▸“ mit Untermenü, bei Mehrfachauswahl auch im Detail; danach die Zeile „2 Fahrten wurden … zugewiesen“ mit „Rückgängig ⌘Z“. **Anzeige:** Bike-Chip im Kopf des Tour-Details (Menü zum Umhängen), Spalte „Bike“ im Vergleich, Zeile „Bike: Name · Antrieb“ im PDF-Kopf, Name im `<desc>` der GPX-Strecke. **Update:** Banner „Neu in 1.5: Lege deine Bikes an“ (Zum Profil / Später) statt Dialog. **Assistent:** neuer Schritt 2 „Erstes Bike“ (Name, Farbe, Körperdaten überspringbar), aus 4 werden 5 Schritte. Bei Abweichungen gelten Kap. 10.16 und die Zeilen B-074 bis B-138.

**Reihenfolge und PRs:** je Zeile ein PR direkt gegen `main`; der nächste beginnt erst nach dem Merge des vorigen. Check: `scripts/ci-local.sh` („local-ci“). B-133 → B-074 → B-134 → B-135 → B-136 → B-137 → B-067 → B-138 → Release 1.5.0 (Version, Changelog, Handbuch EN/DE mit neuem Kapitel „Profil und Bikes“, Katalogabgleich, DMG, Tag).

| # | Story | Größe | Status |
|---|---|---|---|
| B-133 | Mockup auf dem Design-Canvas: Bereich „Profil“ (Kopf mit Körperdaten, Bike-Kacheln mit Foto), Bike-Editor, Menü „Import für“, Bike-Filter je Bereich, Listenzeile mit Symbol, Hinweis nach dem Update, Schritt im Assistenten; hell/dunkel; Abstimmung (Artboards „Profile“, „BikeEditor“, „ImportFor“, „BikeFilter“, „BikeAssign“, „BikeDisplay“, „UpdateHint“, „OnboardingBike“) | S | ☑ |
| B-074 | Datenmodell im Kit: `Bike` erweitern (Farbe, Art Fahrrad / Mountainbike / Rennrad / Gravelbike, `isEbike`, Foto als `externalStorage`, Hersteller, Modell, Antrieb, Akku Wh, Gewicht, Kaufdatum, km-Startwert, `isArchived`, Reihenfolge) und mit `Rider` verknüpfen; `Rider` um Gewicht, Größe, Geburtsjahr und Geschlecht; aktives Bike; Migration (Standard-Bike → „Mein eBike“, alle Fahrten bleiben); CloudKit-fähig; Kennzahlen je Bike (km inkl. Startwert, Fahrten, erste/letzte Fahrt); **dazu für den GPX-Import (v1.6, B-141) in derselben Migration:** Quellenart `sourceFormat` „fit“/„gpx“, Kennzeichen „Summen geschätzt“ (`summaryEstimatedFromGPS`), optionale Felder `heartRate` und `temperature` in `RideSample`, optionale Zusatzquelle an der Fahrt (`attachedSourceName`, `attachedSourceFormat`) (nur Modell, kein Parser); mit Tests, auch für Altdaten (PROF-03) | M | ☑ |
| B-134 | Bereich „Profil“ in der Seitenleiste: Avatar, Name, Körperdaten; Bike-Kacheln mit Foto und Kennzahlen; Bike anlegen, bearbeiten, archivieren, wiederherstellen; Stern für das aktive Bike (ACC-01, PROF-01, PROF-03) | M | ☑ |
| B-135 | Zuordnen: Menü „Import für: Bike ▾“ in der Werkzeugleiste (manueller Import und iCloud-Ordner); „Bike zuweisen“ im Kontextmenü und bei Mehrfachauswahl mit ⌘Z; Menü im Kopf des Tour-Details; zusammengefügte Fahrten nehmen das Bike des ersten Teils | M | ☑ |
| B-136 | Anzeige: Bike-Symbol der Art in der Farbe des Bikes in der Listenzeile (ab 2 Bikes), Zeile im Vergleich, Name im PDF der Fahrt und als Metadatum im GPX; VoiceOver-Label | S | ☑ |
| B-137 | Bike-Filter je Bereich, jeweils gemerkt: Fahrten, Auswertung, Karte (**übernimmt B-110**), Highlights (Jahr und Rekorde; Ziele gesamt); archivierte Bikes erscheinen im Filter | M | ☑ |
| B-067 | Kalorienmodus „mit Profil“ (Standard bleibt „aus Arbeit“): Arbeit ÷ Wirkungsgrad + Grundumsatz × Dauer; Alter aus Geburtsjahr und Fahrtdatum; „keine Angabe“ = Mittelwert; fehlende Werte → Rückfall mit Hinweis; Info-Text zum Schätzwert anpassen; im Kit mit Tests, abgeglichen mit V-01 (PROF-01, SET-06) Stand 25.10.2026: Gerüst umgesetzt (Kit, Einstellung, Anzeige, Tests), **in 1.5.0 nicht freigeschaltet** (Schalter `CalorieMode.withProfileAvailable` in `App/CalorieSettings.swift`, Entscheidung von Nils: erst nach dem Abgleich). Abgleich mit V-01 erledigt: „aus Arbeit“ bildet Flow nach (0,97 × kJ + 64 kcal je Stunde Fahrzeit, ohne Körperdaten; Flow hat keine), „mit Profil“ rechnet mit Wirkungsgrad 25 % (Faktor 0,956) plus Grundumsatz über die Fahrzeit. Zum Freischalten fehlen noch: Info-Text, Handbuch- und Changelog-Text für den Modus, Schalter auf `true` | M | ◐ |
| B-138 | Umstieg und Erststart: einmaliger Hinweis nach dem Update (`@AppStorage`) mit Sprung ins Profil; Schritt „Erstes Bike“ im Assistenten (Name, Farbe; Körperdaten überspringbar) | S | ☑ |

### Rückmeldungen aus dem Test von 1.5.0 (25.10.2026, noch ohne Version)

Getestet von Nils aus Xcode am Stand von `main` (nach PR #68): Update von 1.4.3 mit dem Hinweis, Profil und Bikes mit allen Prüfpunkten, zweites Bike mit Auswahl in den Ansichten, Zuordnen, Kalorien (Abweichung zu Flow bei geprüften Fahrten etwa ±3 kcal). Nicht getestet: der Erststart-Assistent mit dem Schritt „Erstes Bike“ (später). Die beiden Punkte unten sind nur gemerkt, ohne Priorität und ohne Entscheidung zur Version.

| # | Story | Größe | Status |
|---|---|---|---|
| B-174 | Bike-Symbol in der Fahrtenliste in der kleinen Größe schlecht zu erkennen: Größe, Kontrast oder Form prüfen (Bugfix / Optimierung zu B-136; auch in Vergleich und Filter ansehen, VoiceOver bleibt) **Umgesetzt (26.10.2026, 1.7.0):** kleine Chips (unter 28 pt: Liste, Menüs, Filter, Vergleich) zeichnen das Symbol größer (80 statt 62 % des Kreises), mit kräftigerem Strich (mind. 1,4 pt) und stärkerer Tönung (22 statt 14 %); in der Listenzeile 22 statt 20 pt | S | ☑ |
| B-175 | Die zuletzt gewählte Bike-Auswahl soll in allen Ansichten gelten (Fahrten, Auswertung, Karte, Highlights) statt je Bereich einzeln. Ändert die Entscheidung „Filter je Bereich“ aus REQUIREMENTS.md 10.16 und B-137; vorher mit Nils klären (ein gemeinsamer Filter, Umschalter „für alle Ansichten“ oder je Bereich lassen; Verhalten der Ziele) | M | ☐ |

## v1.6 – GPX-Import (Plan 25.10.2026)

Wunsch von Nils: Die Zielgruppe wächst, wenn auch Fahrten anderer Bikes und Radcomputer, die eher GPX als FIT ausgeben, in Wattspur landen. Entschieden mit Nils am 25.10.2026 (REQUIREMENTS.md 10.17); ersetzt B-060. Als eigene Version nach 1.5, weil GPX auf Bikes (Bike-Frage beim Import, Filter nach Quelle) und dem erweiterten Datenmodell aufbaut.
- **Quellen:** GPX 1.0/1.1 mit Position, Höhe, Zeit und Erweiterungen (Garmin TrackPointExtension: Trittfrequenz, Puls, Temperatur; `<power>` wie im eigenen Export, damit Export → Import verlustfrei ist). Mehrere Tracks und Segmente einer Datei ergeben **eine Fahrt** mit Lücken, an verschiedenen Tagen getrennt. Keine Routen und Wegpunkte.
- **Zielgruppe:** andere eBikes, Fokus und Optik bleiben Bosch/Flow; Funktionen mit Leistung gibt es nur, wenn die Datei sie enthält.
- **Summen** aus dem Track berechnet (Strecke, Fahrzeit mit Stillstandserkennung, Ø/Max-Geschwindigkeit, Anstieg aus geglätteten Höhen), als „geschätzt“ gekennzeichnet; Bosch-FIT bleibt Wahrheitsquelle.
- **Abtastrate:** Originalpunkte behalten, Geschwindigkeit aus Abstand und Zeit; Leistung und Trittfrequenz bleiben leer. **Puls und Temperatur** werden nur gespeichert (Anzeige später, IDEA-27).
- **Duplikate** (Start ±60 s, Strecke ±10 %, bestätigt über die vereinfachte Route): FIT da, GPX kommt → GPX als Zusatz anhängen (nur Puls und Temperatur, sonst Quelle merken), ohne Rückfrage. GPX da, FIT kommt → nachfragen, im überwachten Ordner automatisch aktualisieren; Name, Notizen, Bike und Markierungen bleiben. Zwei GPX derselben Tour: wie IMP-02.
- **Überwachter Ordner:** GPX wird wie FIT importiert. **Bike:** beim manuellen Import Sheet „Für welches Bike?“, im Ordner das aktive Bike.
- **Anzeige:** Quellen-Symbol in der Listenzeile, „–“ für fehlende Werte, Info „geschätzt“, Filter nach Quelle in Liste, Auswertung und Karte.
- **Ohne Leistungsdaten:** Rekorde, Highlights und Ziele zählen, wo Daten da sind; Kalorien „–“, CO₂ aus der Strecke; Auswertung und Karte nehmen alle Fahrten, Ø-Leistung und Trends nur Fahrten mit Leistung („n von m Fahrten“); im Vergleich bleiben Zeilen leer.

**Datenmodell:** Quellenart, Kennzeichen „geschätzt“, optionale Felder für Puls und Temperatur und die Zusatzquelle legt B-074 in v1.5 schon mit an (nur Modell und Migration, kein Parser), damit nur eine Migration nötig ist.

**Reihenfolge und PRs:** je Zeile ein PR direkt gegen `main`; der nächste erst nach dem Merge. Check: `scripts/ci-local.sh` („local-ci“). B-139 → B-140 → B-141 → B-142 → B-143 → B-144 → B-145 → B-146 → Release 1.6.0 (Version, Changelog, Handbuch EN/DE mit Kapitel „GPX importieren“ und FAQ, DMG, Tag).

| # | Story | Größe | Status |
|---|---|---|---|
| B-139 | Mockup auf dem Design-Canvas: GPX-Dialoge (Bike-Frage, Duplikate FIT/GPX), Quellen-Symbol, „–“-Werte und „geschätzt“, Filter nach Quelle, Protokoll; hell/dunkel; Abstimmung. Stand 25.10.2026: Artboards `GpxImport`, `GpxLog`, `GpxDisplay` (je hell und dunkel) auf dem Canvas, Abstimmung mit Nils offen; erst danach Code | S | ◐ |
| B-140 | `GPXRideImporter` im Kit: GPX 1.0/1.1, Erweiterungen (Leistung, Trittfrequenz, Puls, Temperatur), mehrere Tracks/Segmente, Zeit in UTC, robust gegen fremde Dateien; Rundreise-Test mit `GPXWriter`; mit Tests (IMP-04). **Ergebnis aus V-11 ([SPIKE-GPX-FORMATE.md](SPIKE-GPX-FORMATE.md)):** `XMLParser` im Streaming (81 230 Punkte in 0,12 s), Elemente nach lokalem Namen mit Alias-Liste (`power`/`powerinwatts`, `cad`/`cadence`, `hr`/`heartrate`, `atemp`/`temp`), Attributreihenfolge und Präfixe beliebig, Zeit mit `time(includingFractionalSeconds:)` (0 bis 9 Stellen, `Z` und Offset); Lücken ≥ 30 s oder `trkseg`-Wechsel teilen die Fahrt; Punkte mit gleichem Zeitstempel zusammenfassen (komoot: 31 %), GPS-Sprünge und 0/0 verwerfen; ohne Zeit oder nur `rte`/`wpt` → klare Fehlermeldung; Grenzen für Größe und Punktzahl; Tests an den Dateien in `Fixtures/GPX/`. **Stand 25.10.2026:** umgesetzt in `GPXRideImporter` (Kit), 32 Tests. `parseTrack` liefert Teile (Segmente und Pausen ≥ 30 s), Name, `creator`, Typ und Zähler der verworfenen Punkte; `parse` macht daraus ein `ParsedRide` mit vorläufigen Summen (Fahrzeit = Summe der Teile, Strecke aus dem Track; Stillstand, Anstieg und Höchstgeschwindigkeit folgen in B-142). Mehrere Teile liegen wie bei zusammengefügten Fahrten auf einer Zeitachse: Pause am selben Tag bleibt, anderer Tag schließt direkt an. Sprungfilter nur, wenn der Schritt über 150 km/h **und** über dem Dreifachen des Schritts davor liegt (eine Motorradfahrt mit 160 km/h bleibt erhalten). Ablehnungen mit eigenem Grund (`GPXImportError`): keine GPX, abgeschnitten, nur Route/Wegpunkte, keine Zeiten, zu viele Punkte ohne Zeit (> 5 %), Zeit läuft zu oft rückwärts (> 10 %), zu groß (200 MB), zu viele Punkte (5 Mio.) | M | ☑ |
| B-141 | Datenmodell und Quelle für GPX: die Felder (`sourceFormat` „gpx“, Kennzeichen „geschätzt“, optionale Felder für Puls und Temperatur in der Zeitreihe, Zusatzquelle) kommen schon mit B-074 (v1.5, Entscheidung von Nils 25.10.2026, nur eine Migration); hier bleiben Originalpunkte statt 1 Hz in der Zeitreihe, die Parser-Version und die Nutzung der Felder. **Stand 25.10.2026:** `ParsedRide` trägt `summaryEstimated` und `suggestedName` (GPX: Name der Spur), `Ride.apply` setzt `summaryEstimatedFromGPS` (ein Update aus der Bosch-FIT löscht die Kennzeichnung), die Zeitreihe speichert die Originalpunkte mit Puls und Temperatur, Parser-Version je Format in der Diagnose. Die Bibliothek bekommt den GPX-Importer erst mit B-144 in der App (Standard bleibt FIT, Tests mit beiden) | S | ☑ |
| B-142 | Summen aus dem Track: Strecke, Fahrzeit mit Stillstandserkennung, geglättete Höhen, Anstieg/Abstieg, Ø/Max-Geschwindigkeit; Kennzeichnung „geschätzt“; Tests an echten GPX (Wattspur-Export, komoot, Strava, Radcomputer). **Startwerte aus V-11 (bestätigt von Nils am 25.10.2026):** Pause ab 30 s Lücke zwischen Punkten, Stillstand unter 0,8 m/s (über ±5 s), Höhe Median über 5 Punkte + Schwelle 3 m für Anstieg/Abstieg (später einstellbar 1/3/5 m, SET-04); Vorschlag ohne Entscheidung: Sprungfilter 150 km/h, Max-Geschwindigkeit aus 5-s-Fenster; Soll an Tour 1: Fahrzeit ±1 % der FIT, Anstieg bei 1 m Schwelle 166/169. **Stand 25.10.2026:** umgesetzt in `GPXTrack.totals(_:)` und `GPXSummaryParameters` (Kit, 11 Tests). Tour 1: Fahrzeit 2 893 s (FIT 2 916), Strecke 18 488 m, Anstieg 147/149 bei 3 m und 166/168 bei 1 m, komoot 114/131 bei 3 m; Stillstandsdatei 315 s (Soll 300). Der Stillstand wird über die Luftlinie im Fenster ±5 s erkannt, Schritte im Stand zählen auch keine Strecke (GPS-Zittern); Höchstgeschwindigkeit aus Strecken von ≥ 5 s (Tour 1: 57,9 km/h, FIT 54,5). Die Schwelle ist als Parameter vorbereitet (SET-04 später) | M | ☑ |
| B-143 | Duplikaterkennung und Zusammenführen: Erkennung Start ±60 s, Strecke ±10 %, bestätigt über die vereinfachte Route (B-104); FIT + GPX anhängen, GPX + FIT aktualisieren (Bosch-Werte neu, lokale Änderungen bleiben), GPX + GPX; mit Tests (IMP-02, IMP-04). **Ergebnis aus V-11:** die Strecke der FIT-Session (Radsensor) liegt 4,9 % über dem GPS-Pfad derselben Fahrt, ±5 % ist zu knapp; **bestätigt von Nils am 25.10.2026: ±10 %**, bestätigt über die vereinfachte Route (B-104; Vorschlag aus V-11: 95-%-Abstand beider Spuren ≤ 60 m); Bosch-FIT bleibt Wahrheitsquelle; Gruppenfahrten (gleicher Start, andere Person) beachten; Testpaare `pair-tour1-*` und `pair-tour2-*` in `Fixtures/GPX/` (Session-Strecke 4,4 bis 4,9 % über dem GPS-Pfad). **Stand 25.10.2026:** umgesetzt (Kit): `RideLibrary.findSimilarRide` (Start ±60 s, GPS-Pfad ±10 % von `GPSPath`, Route `RouteMatch` auf der vereinfachten Route: Median ≤ 25 m und 95 % ≤ 60 m, in beiden Richtungen). GPX auf Bosch-Fahrt: `.attached` (Puls und Temperatur in die Zeitreihe, Quelle gemerkt, Bosch-Werte bleiben); FIT auf GPX-Fahrt: `.fitForGPX`, `update` übernimmt die Bosch-Werte, Name/Notizen/Bike bleiben, die GPX bleibt als Zusatzquelle und ihr Puls erhalten; GPX auf GPX: `.duplicate` wie IMP-02. Im Ordner (`FolderImport`) ohne Nachfrage. **Gruppenfahrt:** Treffer nur im selben Bike (Vorschlag aus V-11, Frage 4 des Spikes); die Bike-Wahl kommt als `bike:` in `importFile`. App-Oberfläche folgt mit B-144 | M | ☑ |
| B-144 | Import-Oberfläche: `.gpx` per Drag & Drop und Dialog, Bike-Frage, Duplikat-Dialoge, Protokolleinträge, Ordnerüberwachung nimmt GPX auf (IMP-05, IMP-06). **Stand 25.10.2026:** umgesetzt. Die Bibliothek liest ab jetzt GPX (Standard-Importer); `ImportFlow` (App) steuert den manuellen Import in der Fahrtenliste und im Import-Fenster: Sheet „Für welches Bike?“ ab 2 Bikes (vorbelegt mit dem aktiven Bike, Datei-Liste mit Strecke und Datum), Vergleichsdialog „Diese Fahrt ist schon vorhanden“ (Überspringen / Als neue Fahrt / Aktualisieren) für FIT über GPX-Fahrt, GPX über GPX und zweite GPX an einer Bosch-Fahrt, Hinweis „GPX an … angehängt“ ohne Dialog; zwei FIT-Duplikate behalten die alte Sammelfrage. Protokoll: Zustand „Angehängt“, GPX-Symbol am Dateinamen, Filter FIT/GPX, „automatisch aktualisiert“ im Ordner. Abweichung vom Mockup: Im Ordner wartet GPX + GPX nicht im Protokoll auf eine Entscheidung, sondern wird wie zwei FIT-Duplikate (IMP-02) übersprungen und protokolliert | M | ☑ |
| B-145 | Anzeige: Quellen-Symbol, „–“ bei fehlenden Werten, Info „geschätzt“, Filter nach Quelle in Liste, Auswertung und Karte; VoiceOver. **Stand 25.10.2026:** umgesetzt nach dem Mockup „GPX-Fahrten anzeigen“. Kit: `SourceFilter` (Alle / Bosch-FIT inklusive angehängter GPX / GPX), `Ride.sourceBadge`, `MapFilter.source`, `Ride.hasPowerData`. App: Symbol „GPX“ bzw. „+GPX“ in der Listenzeile (Bosch-FIT ohne Symbol, VoiceOver „Quelle: GPX-Datei“); Quellenfilter in Liste (Filtermenü), Auswertung, Karte und Highlights, je Bereich gemerkt wie der Bike-Filter und nur, wenn es eine GPX-Fahrt gibt (Ziele zählen alle Quellen); die Jahreskarte der Liste folgt Bike- und Quellenfilter und öffnet die Jahresauswertung mit denselben Filtern; Tour-Detail mit Zeile „Quelle: GPX · Datei“, „≈ Summen geschätzt“ mit Erklärung (Pause 30 s, Stillstand 0,8 m/s, Höhen 3 m) und „≈“ an Fahrzeit, Strecke, Ø Geschwindigkeit und Anstieg; fehlende Werte „–“ mit „Nicht in der Datei“, Kalorien „–“ ohne Leistung („Braucht Leistung“), CO₂ „Aus der Strecke“, Arbeit „–“; Diagramme Höhe, Trittfrequenz und Leistung zeigen „Diese Datei enthält keine … Daten“. Abweichung vom Mockup: Das Quellenmenü steht im Filtermenü der Liste statt als eigener Knopf. Die Aggregate (Rekorde, Auswertung, Vergleich, „n von m Fahrten“) folgen mit B-146. Debug-Start `-WattspurDemoImport` legt Dateien in der Demo-Bibliothek an | M | ☑ |
| B-146 | Berechnungen ohne Leistung: Rekorde, Highlights, Ziele, Auswertung und Vergleich mit fehlenden Werten; CO₂ aus der Strecke, Kalorien „–“; „n von m Fahrten“; mit Tests. **Stand 25.10.2026:** umgesetzt. Kit: `ValueCoverage` („n von m“) und `RideAggregate.powerCoverage/cadenceCoverage/ascentCoverage`; Arbeit und Kalorien summieren nur Fahrten mit Leistung (`RideFigures.hasPowerData`), ohne eine solche Fahrt gibt es keinen Wert (`…IfKnown`, in der App „–“); Strecke, Zeit und CO₂ (aus der Strecke) zählen alle Fahrten. Vergleich: Arbeit, Kalorien und Werte je Kilometer sind ohne Leistung leer und ziehen den Durchschnitt nicht auf 0 (`RideComparison.coverage`). Rekorde (Ø Leistung, meiste Höhenmeter) übergehen Fahrten ohne den Wert schon bisher, mit Test belegt. Ziele: Anstieg-Ziel zeigt „n von m Fahrten“, wenn Fahrten keine Höhen haben (`GoalProgress.ascentCoverage`). App: Hinweis „n von m Fahrten“ unter Anstieg, Arbeit, Kalorien, Ø Leistung und Ø Trittfrequenz in der Auswertung, unter dem Anstieg der Jahresauswertung, am Anstieg-Ziel und unter dem Durchschnitt im Vergleich; nur, wenn der Wert nicht für alle Fahrten da ist; ohne Wert „–“; Vorschau beim Zusammenfügen „–“ für die Arbeit. 11 Tests (`NoPowerTests`). Das Mockup für den Hinweis fehlt weiter; umgesetzt ist „9 von 12 Fahrten“ klein unter der Zahl (Vorschlag, mit Nils abzustimmen) | M | ☑ |
| – | **Release 1.6.0** (25.10.2026): Version 1.6.0 in `project.yml`, Changelog, Handbuch EN/DE mit neuem Kapitel „GPX-Dateien importieren“ (08), Ergänzungen in Import, Ansichten, Kennzahlen, FAQ und Bikes, veraltete Texte (Einrichtungsassistent, Einstellungen › Import, Info, leere Karte) korrigiert; Tag `v1.6.0` und DMG nach dem Merge. Bilder für das neue Kapitel fehlen (Handbuch kommt ohne neue Screenshots) | S | ☑ |

## v1.6.1 – Sicherheits-Fix und Architektur aufräumen (Plan 25.10.2026)

Auslöser: Der Sicherheitscheck von 1.6.0 fand fünf Abstürze durch präparierte FIT-Dateien (PR #5, schon auf `main`). Der Architekturbericht danach zeigte Zyklen im Kit, eine zu große `RideLibrary`, Schreibzugriffe in Views, große View-Dateien, verstreute Einstellungsschlüssel und einen schweren Start. Entschieden mit Nils: Version 1.6.1 (Patch, keine neuen Funktionen), zwei Module, ein PR je Schritt.

**Reihenfolge und PRs:** je Zeile ein PR, aufeinander aufgebaut; Check: `scripts/ci-local.sh`.

| # | Story | Größe | Status |
|---|---|---|---|
| – | **Sicherheits-Fix** FIT-Import (Zeitstempel, Seriennummer, Leistungssumme, Zeitachse, NaN) mit `FITHostileInputTests` (PR #5) | M | ☑ |
| B-162 | Eine geteilte `RideLibrary` über die Environment, Undo je Fenster mit `using(_:)` (PR #6) | M | ☑ |
| B-163 | Schreibzugriffe aus den Views: Ziele, Speichern, Zeitzonen über die Bibliothek (PR #7) | S | ☑ |
| B-164 | Modulschnitt `WattspurCore` / `WattspurKit`, Brücken in `RideBridges.swift`, Tests und Fixtures geteilt (PR #8) | L | ☑ |
| B-165 | `RideLibrary` in sechs Dienste, Fassade bleibt, `defaultBikeName` als Parameter (PR #9) | L | ☑ |
| B-166 | Große Views in Ordner: Highlights, Analysis, Compare (PR #10) | M | ☑ |
| B-167 | Einstellungsschlüssel in `SettingsKey` (PR #11) | S | ☑ |
| B-168 | Wartung nach dem ersten Fenster, Ordner-Import liest im Hintergrund (PR #12) | M | ☑ |
| B-169 | `docs/ARCHITECTURE.md`, Regel-Prüfung `scripts/check-architecture.sh` in der CI, Lern-Notiz 25, Changelog, Version 1.6.1 | S | ☑ |
| – | **Release 1.6.1:** DMG bauen, Tag `v1.6.1`, GitHub-Release (veröffentlicht 25.10.2026) | S | ☑ |
| B-170 | Fahrtdetails: Karte mit Titelzeile bleibt oben stehen, nur der Teil darunter scrollt; Kartenhöhe 200–340 pt je nach Fensterhöhe (Wunsch 25.10.2026) | S | ☑ |
| B-171 | Streckenkarte: neue (rote) und bekannte (blaue) Spur gleich dick, Legende angepasst (Wunsch 25.10.2026) | S | ☑ |
| B-172 | Update-Hinweis: fragt höchstens einmal am Tag bei GitHub nach der neuesten Version und zeigt ein Banner mit Link zur Release-Seite; „Später“ blendet diese Version aus; Menü „Nach Updates suchen …“; Schalter in Einstellungen › Allgemein (Standard an); Info-Fenster, FAQ und NFR-01 angepasst (Wunsch 25.10.2026) | S | ☑ |
| B-173 | Auto-Update (Sparkle): lädt die neue Version und ersetzt die App. **Auf einen späteren, unbestimmten Release verschoben:** braucht EdDSA-Schlüssel, einen gehosteten Appcast, XPC-Dienste mit zusätzlichen Sandbox-Rechten, und die App ist ad hoc signiert (die Signatur wechselt mit jedem Build, Bookmarks und Berechtigungen hängen daran); sinnvoll erst mit Developer-Account und Notarisierung (NFR-18) | L | ☐ |

## v1.7 – Ähnliche Strecken und weitere Rekorde (Wunsch 22.10.2026, Plan 26.10.2026)

**Plan mit Nils am 26.10.2026 (REQUIREMENTS.md 10.19):** In zwei Releases geschnitten: **1.7.0** enthält B-116 bis B-120 und B-122, **1.7.1** die Gruppen (B-121, mit `RouteGroup` und eigener Migration). Dazu kommen B-161 und B-174 als eigene kleine PRs vor dem Release 1.7.0. Je Zeile ein PR direkt gegen `main`; der nächste erst nach dem Merge. Check: `scripts/check-architecture.sh`, `swift test --no-parallel`, `scripts/ci-local.sh`.

| PR | Inhalt |
|---|---|
| 0 | Doku-Stand (dieser Plan, Umnummerierung, README) |
| 1 | B-161 Papierkorb-Knopf |
| 2 | B-174 Bike-Symbol in der Liste |
| 3 | B-116 Ähnlichkeit und `RouteIndex` im Kit |
| 4 | B-122 Rekorde und Rekord-Felder (Migration 1) |
| 5 | B-118 und B-119 Liste mit Chip, Regler, Gegenrichtung, Vergleich (Mockup B-117 abgenommen) |
| 6 | B-120 Verlauf |
| 7 | Release 1.7.0 |
| 8 | B-121 Gruppen mit `RouteGroup` (Migration 2) |
| 9 | Release 1.7.1 |

Hinweis zu B-116: Einen `RouteIndex` gab es bisher nicht; er stand nur im Plan von 1.4 und entsteht jetzt.

Pendelstrecken und Lieblingsrunden wiederfinden und vergleichen. Details: REQUIREMENTS.md Kap. 4.5b (ROUTE) und ADV-R3. Ersetzt die Einträge P-10 (Lieblingsrunden) und den Teil „Gleiche Strecke“ aus B-079. Von v1.5 auf v1.7 verschoben (24./25.10.2026, nach Profil und Bikes und dem GPX-Import). B-125 (jetzt v1.8) kommt erst danach: Der Chip „Ähnlich wie …“ gehört in die heutige Fahrtenliste, nach dem Muster der Rücksprünge aus B-128, und B-125 übernimmt ihn später. Ähnlichkeit gilt über alle Bikes, der Bike-Filter (B-137) schränkt zusätzlich ein.

| # | Story | Größe | Status |
|---|---|---|---|
| B-116 | Ähnlichkeit im Kit: Anteil innerhalb 50 m in beide Richtungen auf Basis der vereinfachten Routen (B-104), Richtungsprüfung, Schwellwert; schnelle Vorauswahl über Start/Ziel und Ausdehnung; mit Tests (u. a. Pendelstrecke hin/zurück, Umweg, Teilstrecke) (ROUTE-01, ROUTE-08) **Stand 26.10.2026:** umgesetzt im Kit. `RouteSignature` (Route alle 10 m umgelegt, in 50-m-Zellen einsortiert), `RouteSimilarity` (Anteil innerhalb 50 m in beide Richtungen, der kleinere zählt; Richtung `same` / `reverse` / `none` über Start und Ziel mit 200 m Toleranz, bei Schleifen über den Umlaufsinn) und `RouteIndex` (50-m-Raster der Erde für die Vorauswahl, `insert`/`remove`/`similar(to:)`); Brücke `RouteIndex(rides)` in `RideBridges.swift`. Gemessen: 1 000 künstliche Fahrten, eine Anfrage etwa 60 ms im Debug-Build; Bosch-FIT, Bosch-GPX und komoot derselben Tour: 100 %, gleiche Richtung | M | ☑ |
| B-117 | Mockup auf dem Design-Canvas: Filter-Chip „Ähnlich wie …“, Ähnlichkeit je Zeile, Regler, Schalter Gegenrichtung, Verlauf, Gruppen; Abstimmung **Stand 26.10.2026:** als Textentwurf (Plan 1.7, Entwurf B-117) von Nils abgenommen; kein Canvas-Artboard | S | ☑ |
| B-118 | „Ähnliche Fahrten zeigen“ per Rechtsklick und im Tour-Detail, Filter-Chip, Sortierung nach Ähnlichkeit, Regler 80–99 %, Standard in den Einstellungen (ROUTE-02, ROUTE-03) **Stand 26.10.2026:** umgesetzt (PR 5). Menü „Show Similar Rides“ und Knopf „Similar Rides“ im Detail; `SimilarRidesBar` (Chip mit Slider, Schalter, Sortierung), `RouteSimilarityStore` (Index im Hintergrund, beim ersten Suchen gebaut, danach nur bei geänderten Routen), Einstellung `similarRoutesThreshold`. Abweichungen vom Entwurf: Die Liste bleibt neben dem Detail sichtbar, deshalb kein „‹ Zurück zu ähnlichen Fahrten“; der Knopf im Detail zeigt keine Trefferzahl | M | ☑ |
| B-119 | Schalter „Auch Gegenrichtung“ mit Richtungs-Symbol; Treffer in den Tourenvergleich übernehmen (ROUTE-04, ROUTE-05) **Stand 26.10.2026:** umgesetzt (PR 5). ⇄ in der Zeile; der Vergleich läuft über die bestehende Mehrfachauswahl (2–4 Fahrten) | S | ☑ |
| B-120 | Verlauf über alle Treffer: Fahrzeit, Ø Geschw., Ø Leistung, Ø Trittfrequenz über die Zeit, Bestzeit und letzte Fahrt markiert (ROUTE-06) **Stand 26.10.2026:** umgesetzt (PR 6). `RouteHistory` im Kit (Reihen je Kennzahl, beste und letzte Fahrt, Mittel, Veränderung der letzten Fahrt zum Mittel, „n von m“), allgemeines `TrendChart` aus `TrendCard` herausgelöst (Stern für die beste, Ring für die letzte Fahrt, Klick auf einen Punkt öffnet die Fahrt), `RouteHistoryView` rechts, solange der Filter aktiv und keine Fahrt markiert ist; im Detail „‹ Zurück zum Verlauf“ (⌘[). Der Verlauf nimmt alle Treffer bei Schwelle und Richtung des Chips, unabhängig von Bike-, Quellen- und Zeitraumfilter der Liste | M | ☑ |
| B-121 | Strecken automatisch gruppieren, benennen, auflösen; Zuordnung neuer Fahrten beim Import; Hintergrund-Berechnung mit Zwischenspeicher (ROUTE-07, ROUTE-08) | L | ☐ |
| B-122 | Weitere Rekorde: höchste Leistung, Trittfrequenz, Geschwindigkeit (Bosch-Maximum) und beste 1-Minuten-Leistung aus der Zeitreihe; „Neuer Rekord“ auch dafür; mit Tests (ADV-R3) **Stand 26.10.2026:** umgesetzt. `RecordKind` hat vier neue Arten (`highestSpeed`, `highestPower`, `highestCadence`, `bestPower1Min`), `RideFigures` die Spitzenwerte; `PeakPower.bestAverage` (Schiebefenster über 60 s ohne Unterbrechung, jede Messung gilt bis zur nächsten) rechnet die beste Minute beim Import, `Ride.bestPower1Min` und `peakPowerVersion` speichern sie (**Migration 1**, additiv; mit einer Bibliotheksdatei aus 1.6.2 geprüft), `preparePeakPower` trägt sie für den Bestand im Hintergrund nach (Wartung nach dem ersten Fenster). Zusammengefügte Fahrten nehmen die beste Minute ihrer Teile. App: vier Karten mehr bei den Rekorden, „Rekord“-Abzeichen und „Beste 1-Minuten-Leistung“ in den Details der Fahrt, „Neuer Rekord“ beim Import gilt auch für die neuen Arten | M | ☑ |

## v1.8 – Ein Bereich „Fahrten“ mit Karte (Plan 24.10.2026, von v1.5 auf v1.8 verschoben am 25.10.2026)

Zuerst Artboard für B-125 auf dem Design-Canvas und Abstimmung mit Nils, dann B-125 (eventuell in zwei PRs), dann B-130, zuletzt Release 1.8.0. B-125 führt dabei die Filter von „Fahrten“ und „Karte“ zusammen, auch den Bike-Filter (B-137) und den Chip „Ähnlich wie …“ (B-118). B-176 (Analyse nach Strecke filtern) wird dabei mitgedacht.

| # | Story | Größe | Status |
|---|---|---|---|
| B-125 | Ein Bereich „Fahrten“ mit Karte als Standard (Wunsch von Nils nach dem Test von v1.4, REQUIREMENTS.md 10.13): links die Liste, rechts die Karte aller Fahrten der Liste (Heatmap, Kacheln, PDF) statt der leeren Ansicht. Eine markierte Fahrt öffnet rechts ihr Tour-Detail mit „‹ Karte“ (Esc) zurück, 2–4 markierte den Vergleich wie heute. Suche und Zeitraum der Liste bestimmen die Fahrten der Karte; ein Schalter „Nur Kartenausschnitt“ beschränkt die Liste zusätzlich auf den sichtbaren Ausschnitt. „Karte“ und ⌘5 entfallen in der Seitenleiste. Zuerst Artboard und Abstimmung; | L | ☐ |
| B-130 | Kalendertag mit Fahrten in den Highlights anklicken: „Fahrten“ zeigt nur die Fahrten dieses Tages, mit Filter-Chip „15. Okt. ✕“ in der Liste und „‹ Zurück zu Highlights“ (⌘[, siehe B-128); bei genau einer Fahrt rechts gleich ihr Tour-Detail, bei mehreren rechts die Karte dieser Fahrten (mit B-125) bzw. bis dahin die Mehrfachauswahl. ✕ am Chip zeigt wieder alle Fahrten. Eine Serie in „Rekorde“ filtert entsprechend auf ihren Zeitraum, Chip „3.–9. Okt. ✕“ (Feedback 1.4.1, Entscheidung Nils 24.10.2026) | S | ☐ |
| B-176 | Analyse nach Strecke filtern: „Ähnlich wie …“ als Filter direkt in der Analyse (Wunsch von Nils am 26.10.2026, nach dem Test des Verlaufs). In 1.7 geht es über den Knopf „Analyze These Rides“ im Verlauf und über die markierten Treffer. Mit B-125 prüfen, ob Filter und Chip in „Fahrten“ und „Analyse“ gemeinsam gebaut werden; die Suche läuft über `RouteSimilarityStore` (B-118) | M | ☐ |

## v1.9 – Bosch-Daten (Plan 25.10.2026)

Wunsch von Nils: Motordaten einer Strecke über das offizielle Bosch-Portal laden, wie es die App „EBikeData“ macht. Recherche: [RECHERCHE-BOSCH-DEVELOPER-PORTAL.md](RECHERCHE-BOSCH-DEVELOPER-PORTAL.md). **Ergebnis der Recherche (amtliche Spezifikationen, 25.10.2026):** Die offizielle API liefert **keine Motordaten je Fahrt**: keine Unterstützungsmodi, keinen Energieanteil, keine Motorleistung, keinen Akkustand. **Nils hat daraufhin Option B gewählt (25.10.2026): 1.9 heißt „Bosch-Daten“** (REQUIREMENTS.md 10.18):
- **Weg:** nur die **offizielle Data-Act-API** (Data-Act-Portal von Bosch, Registrierung als Datenempfänger, OAuth Authorization Code, Freigabe je Bike im Bosch eBike Manager). Die inoffizielle App-API bleibt gestrichen (Kap. 9).
- **Daten:** Bike, Akku und Wartung (Ladezyklen am Bike und extern, abgegebene Energie, Betriebsstunden gesamt und mit Motor, fällige Wartung, Komponenten, Modi mit Reichweite); je Fahrt Titel von Bosch, Kilometerstand zu Beginn, Kalorien und CO₂ von Bosch, Puls; eine Spur mit Höhe, Geschwindigkeit, Trittfrequenz und Fahrerleistung **ohne Zeitstempel je Punkt**. Nur Fahrten, die mit der Flow-App aufgezeichnet wurden. **Nicht in der offiziellen API:** Modi je Fahrt, Energieanteil, Motorleistung, Akkustand, Brems-/ABS-Ereignisse. Deshalb entfallen **B-154, B-155 und B-157** (und MOT-07, MOT-08, MOT-10).
- **Fahrten ohne Datei (neu, Option B):** Fahrten, die nur bei Bosch liegen, werden zum **Anlegen angeboten** (Altbestand und laufend, nach Bestätigung). Summen von Bosch, Zeitreihe aus der Spur mit **geschätzter Zeit**, gekennzeichnet „geschätzt“ (wie GPX, B-141); eine später importierte FIT-Datei **ersetzt** die Bosch-Fahrt (Titel, Notizen, Bike bleiben); gelöschte Fahrten werden nicht erneut angeboten (`boschActivityId`). Das ist der Weg für den Altbestand (V-03).
- **Zusammenspiel:** Die FIT-Fahrt bleibt Wahrheitsquelle (Kap. 3.3), Rangfolge **FIT vor GPX vor Bosch**. Die Bosch-Fahrt wird über Start (mit `timeZone`), Strecke und Route (wie IMP-04) zugeordnet und liefert Zusatzfelder.
- **Anmeldung:** **Jeder Nutzer legt seinen eigenen Client** im Data-Act-Portal an (öffentlicher Client, keine Geheimnisse im Repo, kein Backend) und trägt die Client-ID ein; Redirect mit eigenem Schema. Anmeldung im Systembrowser, Tokens im Schlüsselbund, „Abmelden“ löscht sie und auf Wunsch die abgerufenen Daten.
- **Zeitpunkt:** nach jedem Import (auch im überwachten Ordner, nur bei geöffneter App) still im Hintergrund, dazu ein Knopf; Fahrten, die Bosch noch nicht hat, werden beim nächsten Mal wieder versucht. **Altbestand:** einmaliges Angebot nach der ersten Anmeldung mit Fortschritt, abbrechbar.
- **Verlauf und Service (Kann, entschieden 25.10.2026):** Wartungen, Software-Updates, Akkumessung und Modus-Statistik je Bike aus dem Digital Service Book, nur wenn V-12 echte Einträge zeigt (B-160).
- **Orte:** Einstellungen (Reiter „Bosch-Konto“), Tour-Detail (Abschnitt „Von Bosch“), Profil (Akku, Antrieb, Wartung je Bike, ggf. Verlauf und Service), Liste (Kennzeichnung der Bosch-Fahrten), Import-Protokoll.
- **Fehler:** Beim automatischen Abruf leise (Statuszeile und Protokoll), Dialoge mit Anleitung nur bei Knopfdruck. Ohne Konto und ohne Netz bleibt Wattspur voll nutzbar.
- **Daten und Export:** Die Antwort der API wird als Original archiviert (wie IMP-07); Anzeige auch im PDF der Fahrt; Fahrten aus Bosch-Daten werden wie GPX-Fahrten exportiert (geschätzte Zeiten gekennzeichnet); die Zusatzfelder nicht im GPX-Export, nicht in der Beispielfahrt. NFR-01 wird um den optionalen Abruf erweitert.
- **Vorbehalt:** Die **Bedingungen für Datenempfänger** sind nicht gelesen (V-12). Ohne Zusage entfällt 1.9, nichts anderes ist betroffen. Als Annahmen von Claude, **im Mockup B-147 zu bestätigen:** Anlegen nach Bestätigung (Einstellung „automatisch“ aus), Rangfolge FIT vor GPX vor Bosch, Ersetzen durch FIT.

**Voraussetzungen:** 1.5 (Bikes: Zuordnung API-Bike ↔ Wattspur-Bike), 1.6 (Quelle und Kennzeichen „geschätzt“ aus dem GPX-Import, B-141; Duplikaterkennung nach Start, Strecke und Route, B-143) und 1.8 (Reihenfolge; Oberfläche des Tour-Details bleibt gleich).

**Reihenfolge und PRs:** je Zeile ein PR direkt gegen `main`; der nächste erst nach dem Merge. Check: `scripts/ci-local.sh` („local-ci“). **V-12 → B-147 → B-148 → B-149 → B-150 → B-151 → B-152 → B-158 → B-153 → B-159 → B-156 → (B-160, nur wenn V-12 Einträge im Service Book zeigt) → Release 1.9.0.** B-154, B-155 und B-157 entfallen. V-12 läuft schon jetzt und braucht keinen Code; die Stories beginnen nach 1.8.

| # | Story | Größe | Status |
|---|---|---|---|
| B-147 | Mockup auf dem Design-Canvas: Reiter „Bosch-Konto“ (nicht angemeldet, Anmeldung läuft, angemeldet, nicht bei Bosch eBike Systems angemeldet, Fehlerzustände), Angebot „N Fahrten abgleichen, M neu importieren“ mit Fortschritt, Hinweis „N neue Fahrten bei Bosch“ mit Knopf und Einstellung „automatisch anlegen“, Abschnitt „Von Bosch“ im Tour-Detail (mit und ohne Daten), Fahrten aus Bosch-Daten in der Liste und im Detail („Zeit je Punkt geschätzt“), Ersetzen durch eine FIT-Datei (Bestätigung), Akku, Antrieb und Wartung in der Profil-Kachel, Zeile im PDF der Fahrt; hell/dunkel; Abstimmung (bestätigt die Annahmen aus 10.18) | S | ☐ |
| B-148 | Kit: Bosch-Client. Protokolle für HTTP und Anmeldung (einsetzbar im Test), OAuth-2.0-Ablauf (Authorization Code mit Anmelde-URL, Token-Tausch, Erneuerung; PKCE für den öffentlichen Client, in V-12 zu prüfen), Abruf der Bikes (`/bikes`, `/bikes/{id}` mit `ETag` und `If-None-Match`), der Fahrtenliste (`limit` bis 100, fertige `links` nutzen) und des Fahrtdetails, Fehlerabbildung nach dem Problem-Format (`requestId`; 401 `jwt-expired` einmal erneuern, 403 `insufficient-privileges` und `access-denied`, 404, 429 (Kopfzeilen `X-RateLimit-Limit`, `-Remaining`, `-Reset`; im Beispiel des Service Books 100 Anfragen je 60 s), 5xx ohne Problem-Schema, reiner Text bei 401 und 403, Konto außerhalb der EU, Client nicht freigegeben, Zustimmung widerrufen, `ebike-rider-id` fehlt), Offline-Token (läuft nach 180 Tagen ohne Erneuerung ab), Drosselung und Wiederholung mit Wartezeit; **Parser tolerant** (Zahl und Namen der Modi, optionale Komponenten, unbekannte Felder), Einheiten nach der Spezifikation, Reichweite der Modi nach V-12 (Spezifikation Meter, echte Antwort offenbar Kilometer); Tests nur mit **echten, anonymisierten Antworten aus V-12** (die Beispiele und der Mock-Server der Spezifikation weichen von der Wirklichkeit ab) (MOT-01, MOT-11) | M | ☐ |
| B-149 | App: Reiter „Bosch-Konto“ in den Einstellungen (Client-ID eintragen, „Mit Bosch anmelden“ im Systembrowser, Status, „Abmelden“ mit Frage, ob abgerufene Daten bleiben), Tokens im Schlüsselbund, Netzwerk-Berechtigung der Sandbox, Redirect als benutzerdefiniertes Schema (z. B. `wattspur://callback`; beim Client von EBikeData zulässig, mit eigenem Client in V-12 prüfen); Datenschutzhinweis im Reiter und im Info-Fenster; Prüfung mit einem ad-hoc signierten Build bei einem Freund (MOT-01, MOT-02, MOT-12, NFR-20) | M | ☐ |
| B-150 | Datenmodell und Auswertung der Antwort: Felder an `Ride` für Titel von Bosch, Kilometerstand zu Beginn, Kalorien und CO₂ von Bosch, Puls, `boschActivityId` und Abrufzeitpunkt, Quelle „bosch“ (neuer Wert), Original der Antwort als externe Daten, Bike-Daten (Akkus als Liste, Antrieb, Wartung, Komponenten) an `Bike`; Parser-Version, Neu-Auswertung aus dem Original ohne neuen Abruf (NFR-17), unbekannte Felder und Modus-Kennungen bleiben im Original erhalten (Bosch ergänzt Felder, wie der „API Debug“ von EBikeData zeigt), Abbildung Modus-Kennung → Anzeigename mit Rückfall; CloudKit-fähig, eine Migration; Tests, auch für Fahrten ohne Daten (MOT-06) | M | ☐ |
| B-151 | Zuordnung der Bosch-Fahrt zur Fahrt in Wattspur: Start (mit `timeZone`), Strecke und Route wie B-143, wenn möglich auch der Kilometerstand zu Beginn; Mehrdeutigkeit (Gruppenfahrten), Fahrten ohne Treffer als Kandidaten zum Anlegen (B-158), zusammengefügte Fahrten (Teile einzeln zuordnen und summieren), Zuordnung API-Bike ↔ Wattspur-Bike je Bike einmalig; Tests an den Paaren aus V-12 (MOT-05) | M | ☐ |
| B-152 | Abruf-Dienst: nach jedem Import (manuell, Drag & Drop, überwachter Ordner, Start), Knopf „Bosch-Daten abrufen“ im Tour-Detail und in den Einstellungen, Wiederholung für noch nicht veröffentlichte Fahrten, Hinweis auf neue Fahrten bei Bosch, Einträge im Import-Protokoll, leise Fehler mit Statuszeile, Dialog mit Anleitung nur bei Knopfdruck; ohne Konto und ohne Netz ohne Wirkung (MOT-03, MOT-11) | M | ☐ |
| B-153 | Altbestand: nach der ersten Anmeldung Angebot „N Fahrten abgleichen, M neu importieren“ mit Fortschritt, gedrosselt (Seiten über `links.next`), abbrechbar und fortsetzbar; vorhandene Fahrten angereichert, neue nach Bestätigung über B-158 angelegt; Fahrten, die Bosch nicht mehr hat, bleiben unberührt (MOT-04) | S | ☐ |
| B-154 | ~~Tour-Detail: Abschnitt „Unterstützung“ mit Balken je Modus (Meter und Anteil), Energieanteil Fahrer gegen Motor und Hinweis „von Bosch abgerufen“; fehlt der Abruf, ein Knopf statt leerer Fläche; VoiceOver mit Zahlen; Zeile im PDF der Fahrt (MOT-07, NFR-16)~~ **Entfällt (25.10.2026):** die offizielle API liefert die Daten nicht (Recherche); ersetzt durch B-159 | M | entfällt |
| B-155 | ~~Auswertung, Vergleich und Highlights: Modus-Anteile und Energieanteil über den Zeitraum (nach Strecke gewichtet, „n von m Fahrten“ wie B-146), Zeilen im Tourenvergleich mit leeren Werten, Kachel im Jahresrückblick (MOT-08)~~ **Entfällt (25.10.2026):** die offizielle API liefert die Daten nicht (Recherche) | M | entfällt |
| B-156 | Profil: Akku und Antrieb je Bike (Ladezyklen am Bike und extern, abgegebene Energie, Antrieb, Kilometerstand, Betriebsstunden gesamt und mit Motor, Radumfang, Modi mit Reichweite, fällige Wartung, Komponenten; Kapazität aus dem Modellnamen oder manuell, **keine Seriennummern**) in der Bike-Kachel und im Editor, Abruf per Knopf und nach der Anmeldung; Zuordnung wie B-151 (MOT-09) | M | ☐ |
| B-157 | ~~**Bedingt:** Verläufe von Motorleistung und Akku in den Diagrammen des Tour-Details (Abtastrate der API, nicht 1 Hz) und im Vergleich; nur wenn V-12 eine Zeitreihe findet, sonst entfällt die Story (MOT-10)~~ **Entfällt (25.10.2026):** die offizielle API liefert die Daten nicht (Recherche) | M | entfällt |
| B-158 | Fahrten ohne Datei importieren: Aus Zusammenfassung und Detail-Spur eine Fahrt mit Quelle „bosch“ anlegen (Start, Ende, Zeitzone, Fahrzeit, Strecke, Summen von Bosch, Spur mit Höhe, Geschwindigkeit, Trittfrequenz und Fahrerleistung, Puls wenn vorhanden); die Zeit je Punkt wird aus Strecke und Geschwindigkeit geschätzt (Summe gleich der Fahrzeit) und als „geschätzt“ gekennzeichnet (wie GPX, B-141); Anlegen nach Bestätigung (Angebot im Altbestand, Hinweis beim Abruf, Einstellung „automatisch“); Duplikatprüfung gegen vorhandene FIT- und GPX-Fahrten (B-143, B-151); eine später importierte Datei ersetzt die Bosch-Fahrt, Titel, Notizen und Bike bleiben; gelöschte Fahrten werden über `boschActivityId` nicht erneut angeboten; Original der Antwort archiviert; Tests mit echten, anonymisierten Antworten aus V-12 (MOT-13) | M | ☐ |
| B-159 | Tour-Detail: Abschnitt „Von Bosch“ (Titel, Kilometerstand zu Beginn, Kalorien und CO₂ von Bosch neben den eigenen Werten, Puls Mittel und Maximum, Hinweis „von Bosch abgerufen“); ohne Abruf ein Knopf statt leerer Fläche; bei Fahrten aus Bosch-Daten Hinweis „Zeit je Punkt geschätzt“ und die Strecke als x-Achse; VoiceOver mit Zahlen; Zeile im PDF der Fahrt; nicht im GPX-Export (MOT-14, NFR-16) | S | ☐ |
| B-160 | **Kann, entschieden mit Nils am 25.10.2026; nur wenn V-12 echte Einträge für sein Bike zeigt, sonst entfällt die Story:** Verlauf und Service im Profil aus dem Digital Service Book (`/service-records?bikeId=`, Ratenbegrenzung beachten): Wartungen und Inspektionen, Software-Updates, Akkumessung, nächste Wartung, Modus-Statistik als Momentaufnahme; Parser für die Eintragstypen (`INSPECTION`, `SOFTWARE_UPDATE`, `BBP_MEASUREMENT`, `CUSTOMER_REPORT`, übrige ignorieren), Kennungswechsel (`BIKE_ID_CHANGE`) in der Zuordnung; Tests mit echten, anonymisierten Antworten; kein Händlername in Diagnose und Export (MOT-15) | M | ☐ |

Release 1.9.0 (Version, Changelog, Handbuch EN/DE mit Kapitel „Bosch-Daten abrufen“ samt Registrierung Schritt für Schritt und FAQ, Datenschutzhinweis im Info-Fenster, NFR-01-Text, Katalogabgleich, DMG, Tag) ist die letzte Zeile der Reihenfolge.

## v1.x – Analysen

| # | Story | Größe | Status |
|---|---|---|---|
| B-054 | Leistungskurve je Fahrt und über alle Fahrten (ADV-L1) | M | ☐ |
| B-055 | Zonen-Verteilung für Leistung und Trittfrequenz sowie Rollanteil (ADV-L2, ADV-L3, SET-05) | M | ☐ |
| B-056 | Anstiege erkennen, mit Liste in der Tour-Ansicht (ADV-A1) | L | ☐ |
| B-057 | Steigung im Höhenprofil einfärben und Verteilung anzeigen (ADV-A2) | S | ☐ |

## v1.x – Hilfe & Profil

| # | Story | Größe | Status |
|---|---|---|---|
| B-082 | Erklärung der Kennzahlen und Formeln im Handbuch (DOC-03); erledigt mit B-080 | S | ☑ |
| B-083 | FAQ und Fehlerbehebung (DOC-05); erledigt mit B-080 | S | ☑ |
| B-084 | Hilfe-Menü mit Link zum Handbuch und Hinweise an leeren Ansichten (DOC-06) | S | ☐ |
| B-085 | Profil-Daten exportieren und löschen (ACC-05) | M | ☐ |

## v1.x – Komfort & Karten

| # | Story | Größe | Status |
|---|---|---|---|
| B-060 | GPX importieren und mit der FIT-Datei derselben Fahrt zusammenführen (IMP-04) → ersetzt durch B-139 bis B-146 in v1.6 | M | → |
| B-161 | **Bug:** Im Papierkorb sitzt **Papierkorb leeren …** in der Titelleiste ungünstig und überlappt den grauen Bereich der Seitenleiste (Screenshot von Nils, 25.10.2026, 1.6.0). Der Knopf gehört dahin, wo er die Seitenleiste nicht berührt, etwa in die Kopfzeile des Papierkorbs neben „Fahrten werden nach 30 Tagen endgültig gelöscht“. Beim Prüfen auch die Zeilen im Papierkorb ansehen: In der schmalen Listenspalte brechen Name und Datum mehrzeilig um (Beispiel „Garda-see und Dolomi-ten“), weil **Wiederherstellen** daneben Platz nimmt; Name und Zahlen gehören untereinander in eine Zeile je Fahrt, der Knopf rechts oder im Kontextmenü. Für das nächste Release. **Umgesetzt (26.10.2026, 1.7.0):** „Papierkorb leeren …“ steht in der Kopfzeile des Papierkorbs; „Wiederherstellen“ ist ein schmaler Symbol-Knopf (auch im Kontextmenü), Name und Zahlen brechen nicht mehr um | S | ☑ |
| B-061 | OSM-Stile Standard, CyclOSM und OpenTopoMap als `MapProvider` (MAP-02, NFR-08; setzt V-04 voraus) | M | ☐ |
| B-063 | Route auf der Karte einfärben nach Höhe, Geschwindigkeit, Trittfrequenz, Leistung oder Steigung: Menü auf der Karte, Skala Blau → Rot je Fahrt mit Legende, Lücken grau, Wert beim Zeigen, Auswahl merken (TOUR-08) | M | ☐ |
| B-090 | Diagramme als scrollbares bzw. wischbares Karussell in kompakten Fenstern und auf iOS (TOUR-11); Voraussetzung für B-070 | M | ☐ |
| B-091 | Zoom in Diagramme mit Kennzahlen und Kartenmarkierung für den gewählten Abschnitt (TOUR-12) | M | ☐ |
| B-092 | Tour-Ansicht anpassen: Abschnitte einklappen, per Drag & Drop umsortieren, ein-/ausblenden, Layout speichern und zurücksetzen (TOUR-13) | M | ☐ |
| B-095 | Fahrten zusammenfassen: Mehrfachauswahl → „Fahrten zusammenfassen“ ergibt eine Fahrt mit addierten Summen, gewichteten Mitteln und durchgehender Zeitreihe; Originale ausgeblendet, „Zusammenfassung aufheben“ und ⌘Z (LIST-09) | M | ☑ |
| B-097 | Teile einer zusammengefügten Fahrt einzeln ansehen: einen Abschnitt im Tour-Detail bzw. in der Auswertung wählen und Karte, Kennzahlen und Diagramme nur für ihn zeigen (Folge von B-095) | M | ☐ |
| B-066 | 2–4 Fahrten direkt vergleichen (TREND-03) → aufgeteilt in B-098 bis B-103 (Abschnitt „Tourenvergleich“) | M | → |
| B-067 | Fahrerprofil und Kalorienmodus „mit Profil“ (PROF-01, SET-06) → v1.5 (Abschnitt „Profil und mehrere Bikes“) | M | → |
| B-068 | Faktoren für Kalorien und CO₂ in den Einstellungen (SET-03) | S | ☐ |

## Später – iOS & Ausbau

| # | Story | Größe | Status |
|---|---|---|---|
| B-070 | iOS-Target: Tab-Navigation, gleiche Views mit angepasstem Layout | L | ☐ |
| B-071 | Import auf iOS: Teilen-Menü aus der Flow-App bzw. „Öffnen mit“ | M | ☐ |
| B-072 | Sync Mac ↔ iOS über iCloud/CloudKit (Entscheidung offen) | L | ☐ |
| B-073 | Mehrere Fahrer: Verwaltung, Zuordnung beim Import, Filter (PROF-02) | M | ☐ |
| B-110 | → B-137 (v1.5): Karte aller Fahrten nach Bike filtern; nach Fahrer erst mit B-073, sobald es mehrere gibt; aus v1.4 verschoben (22.10.2026), weil es nur einen Fahrer und ein Bike gibt (AGG-05, setzt B-073/B-074 voraus) | S | → |
| B-074 | Mehrere Bikes: Verwaltung, manuelle Zuordnung der Fahrten, Filter (PROF-03; Seriennummer taugt nicht, siehe SPIKE-FIT-PARSER.md) → v1.5 (Datenmodell B-074, dazu B-133 bis B-138) | M | → |
| B-075 | Apple Health anbinden (PROF-04); Apple-Watch-Puls siehe P-27 | L | ☐ |
| B-076 | Weitere Importer: Strava, generische FIT (PROF-04) | L | ☐ |
| B-077 | Export als CSV bzw. Originaldatei (IMP-08) | S | ☐ |
| B-078 | Kachel-Cache (MAP-03). Die Karte aller Routen (AGG-05) ist jetzt B-104 ff. | M | ☐ |
| B-079 | ~~Gleiche Strecke wiedererkennen (TREND-04)~~ → v1.7 (B-116 ff.), Streudiagramme (TREND-05), Notizen und Tags (TOUR-10) | L | ☐ |
| B-086 | Mehrere lokale Profile mit Profilwechsel (ACC-02, zusammen mit B-073) | M | ☐ |
| B-087 | App-Sperre per Touch ID oder Passwort (ACC-03) | S | ☐ |
| B-088 | Serverkonto (z. B. „Mit Apple anmelden“) inkl. Backend-Konzept, Datenschutzerklärung und Kontolöschung (ACC-04; Zweck vorher klären, Req. 8 #4) | L | ☐ |
| B-089 | Projekt-Website über GitHub Pages aus den Handbuch-Quellen (DOC-07) | M | ☐ |

---

## Ideen-Pool (unpriorisiert, Entscheidung später)

Je Idee eine Story; Größe grob geschätzt. Details: REQUIREMENTS.md Kap. 4.12.

| # | Idee | Größe | Status |
|---|---|---|---|
| P-01 | Fahrtzeit über 25 km/h (IDEA-01) | S | ☐ |
| P-02 | Wartungszähler je Bike (IDEA-02) | M | ☐ |
| P-03 | Pendel-Statistik (IDEA-03) | M | ☐ |
| P-04 | Kostenersparnis ggü. Auto/ÖPNV (IDEA-04) | S | ☐ |
| P-05 | Tour bearbeiten (IDEA-05) | M | ☐ |
| P-06 | Widgets (macOS/iOS) (IDEA-06) | M | ☐ |
| P-07 | Kurzbefehle / App Intents (IDEA-07) | M | ☐ |
| P-08 | Geschätzter Motoranteil (IDEA-08); **von v1.9 nicht berührt:** die offizielle Bosch-API liefert weder Energieanteil noch Motorleistung (Spezifikation 25.10.2026), die Schätzung aus Fahrphysik bliebe die einzige Quelle | L | ☐ |
| P-09 | Trittfrequenz-Hinweise (IDEA-09) | S | ☐ |
| P-10 | Lieblingsrunden (IDEA-10) → jetzt B-121 (v1.7) | L | ☐ |
| P-11 | Eigene Segmente (IDEA-11) | L | ☐ |
| P-12 | Mein Fahrgebiet (IDEA-12): Heatmap kommt mit B-107/B-108, „neue Wege“ mit B-115 in v1.4; besuchte Orte offen | M | ◐ |
| P-13 | Wetter nachträglich (IDEA-13) | M | ☐ |
| P-14 | Abzeichen und Meilensteine (IDEA-14) | M | ☐ |
| P-15 | Weltreise-Fortschritt (IDEA-15) | S | ☐ |
| P-16 | Wochen- bzw. Monatsrückblick (IDEA-16) | S | ☐ |
| P-17 | Fotos zur Tour (IDEA-17) | M | ☐ |
| P-18 | Tour als Bild teilen (IDEA-18) | M | ☐ |
| P-19 | PDF-Jahresbericht (IDEA-19) | S | ☐ |
| P-20 | PDF-Tourbericht (IDEA-20): in v1.2 vorgezogen, Knopf „PDF exportieren“ oben links im Tour-Detail (Karte, Kennzahlen, Details, Diagramme); Anstiege und Notizen folgen mit B-056/B-079 | M | ◐ |
| P-21 | Spotlight-Suche (IDEA-21) | S | ☐ |
| P-22 | Backup und Wiederherstellung (IDEA-22) | S | ☐ |
| P-23 | Menüleisten-Symbol (IDEA-23) | S | ☐ |
| P-24 | Gruppen mit Freunden (IDEA-24) | L | ☐ |
| P-25 | Gemeinsame Touren (IDEA-25) | L | ☐ |
| P-26 | komoot-Anbindung (IDEA-26) | M | ☐ |
| P-27 | Apple Health / Apple Watch (IDEA-27) | L | ☐ |
| P-28 | KI-Tour-Zusammenfassung (IDEA-28) | M | ☐ |
| P-29 | KI-Analyse: Fragen an die Daten („Gibt es Trends in meinen Leistungsdaten?“), Antwort als Text mit Diagramm, eigener Seitenleisten-Eintrag (IDEA-29) | L | ☐ |
| P-30 | KI-Tournamen (IDEA-30) | S | ☐ |
| P-31 | Fahrt nachfahren auf Apple Karten in 2D, 3D und Satellit, mit Schieberegler, Pause und Anzeige von Zeit, Geschwindigkeit, Strecke und Höhe (IDEA-31); Wunsch von Nils 25.10.2026, bewusst **nach v1.9**; erst vor dem Bau in Stories zerlegen (Mockup zuerst) | L | ☐ |
| P-32 | Akkustand und Fahrerleistung während der Fahrt mitschreiben über das Live Data Interface von Bosch (IDEA-32); Machbarkeit offen (Smartphone laut Bosch nicht im Umfang), nur nach einem Spike und nach B-070, bewusst **nach v1.9** | L | ☐ |

---

## Validierung, Recherche & Organisation

| # | Aufgabe | Status |
|---|---|---|
| V-01 | Weitere 3–5 Fahrten exportieren (mit Flow-App-Screenshots), um die Kalorien- und CO₂-Formel zu prüfen. Zweite Fahrt (Tester, Feucht): 1 117 kJ, Flow-Wert angefragt (Wattspur ergibt jetzt ≈ 1 444 kcal). **Kalorien erledigt am 25.10.2026** (Analyse mit sechs Flow-Werten, Fahrzeiten 7 min bis 4:50 h): Die FIT-Dateien enthalten keinen Kalorienwert; kcal ÷ kJ liegt bei 1,126–1,207 (höher bei geringer Leistung). Flow rechnet kcal ≈ 0,97 × kJ + 64 kcal je Stunde Fahrzeit (±3 kcal, nicht Gesamtzeit), ohne Körperdaten (Flow-Profil hat keine); in B-067 umgesetzt. Offen: CO₂-Formel prüfen; Kalorien: ob der Zeitanteil an Zeit oder Strecke hängt (2 langsame Fahrten mit Flow-Wert, Ø unter 15 km/h) und der Flow-Wert der zweiten Fahrt als Gegenprobe | ◐ |
| V-02 | Prüfen, ob Bosch-Exporte Unterschiede je Antrieb oder Display haben (auch Dateien von Freunden). Flow+-Abo ändert den FIT-Export nicht (gleicher Kopf, gleiche Nachrichten und Felder, keine Entwicklerfelder; GPX nur Position, Höhe, Zeit); andere Antriebe/Displays noch offen | ◐ |
| V-03 | **Recherche Altbestand** → erledigt, siehe [RECHERCHE-ALTBESTAND.md](RECHERCHE-ALTBESTAND.md). Entscheidung im zweiten Review: inoffizielle Bosch-API **gestrichen** (ehemals B-047/B-048); Altbestand per Einzelexport, optional DSGVO-Auskunft (V-07). **Nachtrag 25.10.2026:** Die Streichung gilt nur für die **inoffizielle** API; der offizielle Data-Act-Weg (Option C) kommt als Version 1.9 in den Plan, siehe [RECHERCHE-BOSCH-DEVELOPER-PORTAL.md](RECHERCHE-BOSCH-DEVELOPER-PORTAL.md), V-12 und REQUIREMENTS.md 10.18 | ☑ |
| V-04 | Nutzungsbedingungen der OSM-Kachelserver (OSM, CyclOSM, OpenTopoMap) bzw. eines kommerziellen Anbieters für die Verteilung an Freunde und im App Store klären | ☐ |
| V-05 | Beispielfahrt anonymisieren, bevor das Repo veröffentlicht wird (NFR-12). Werkzeug `anonymize-fit` und `App/SampleRide.fit` fertig; Test-Fixture `reinheim-rundfahrt.fit` und die echten GPX/FIT-Fixtures neu verschoben (eigener Versatz, nicht im Repo), ganze Touren um 500 m an Start und Ende gekürzt; echte Seriennummer und Bosch-Fahrt-ID in den Tests durch erfundene ersetzt. Vor dem Veröffentlichen die Historie nicht mitnehmen (neues Repo oder `git filter-repo`), sonst bleiben die alten Dateien abrufbar | ☑ |
| V-06 | Entscheidungen: Lizenz, Zeitpunkt des Developer-Accounts (für v1.0 nicht nötig), Markenprüfung „Wattspur“ (Req. Kap. 8) | ☐ |
| V-07 | DSGVO-Auskunft (Art. 15/20) bei Bosch eBike Systems stellen und das gelieferte Format dokumentieren; enthält es Akku- oder Modusdaten, wird Kap. 9 der Requirements neu bewertet (seit 25.10.2026 gilt für Akku- und Modusdaten schon der Weg über die Data-Act-API, V-12) | ☐ |
| V-08 | komoot: Gibt es eine nutzbare Schnittstelle (Partner-API) oder nur GPX-Austausch? Voraussetzung für P-26 | ☐ |
| V-09 | Altbestand: die wichtigsten bisherigen Fahrten einzeln aus der Flow-App exportieren (dienen auch als Testdaten für v0.2) | ☐ |
| V-10 | Prüfen, ob ad-hoc signierte Sandbox-Apps auf fremden Macs mit macOS 26 wie erwartet laufen (Gatekeeper, security-scoped bookmarks für den iCloud-Ordner) – früh mit einem Testbuild bei einem Freund. Bei einem Tester geprüft: Installation, Start und Import ohne Probleme | ☑ |
| V-11 | Echte GPX-Dateien für B-140 bis B-143 sammeln: je eine von komoot, Strava und einem Radcomputer (auch ohne Leistung), dazu dieselbe Fahrt als Bosch-FIT und GPX für die Duplikaterkennung; Fremddateien anonymisieren, bevor sie ins Repo kommen (NFR-12). **Zwischenstand 25.10.2026** (Notiz [SPIKE-GPX-FORMATE.md](SPIKE-GPX-FORMATE.md)): echt geprüft Bosch Flow (2 Touren), komoot (dieselbe Tour 1), BMW Motorrad Connected (2 Dateien); anonymisierte Fixtures und selbst erzeugte Dateien liegen unter `Packages/WattspurKit/Tests/WattspurKitTests/Fixtures/GPX/`. Zwei Paare Bosch-FIT + Bosch-GPX sind geprüft (Tour 1 mit komoot, Tour 2). Offen: Strava-GPX samt Original, Radcomputer mit Leistung (Garmin/Wahoo/Karoo), von komoot selbst aufgezeichnete Tour | ◐ |
| V-12 | **Spike Bosch Data-Act-API** (Voraussetzung für v1.9, ohne Code; Doku und Ergebnisse bisher in [RECHERCHE-BOSCH-DEVELOPER-PORTAL.md](RECHERCHE-BOSCH-DEVELOPER-PORTAL.md)). Die Spezifikationen und Textseiten des Portals sind gelesen (Nils, 25.10.2026): Modi je Fahrt, Energieanteil und Motorleistung gibt es in der offiziellen API nicht; der Redirect mit eigenem Schema ist beim Client von EBikeData belegt. **Offen, von Nils zu erledigen** (Wattspur und Claude melden nichts an): (1) **Bedingungen für Datenempfänger** und Anhang 1 lesen und festhalten: Weitergabe der App an Freunde und über GitHub, App Store, Speicherung, Marken; (2) eigenen Client anlegen (öffentlich, ohne Secret, Redirect `wattspur://callback`), Dauer der Freigabe messen, Bike im Bosch eBike Manager freigeben; (3) Antwort des **Digital Service Book** (`/service-records?bikeId=`) für Nils' Bike sichern (leer oder mit Einträgen? Bestimmt B-160); Antworten für 2 bis 3 Fahrten sichern (Beispielfahrt „Reinheim Rundfahrt“, die älteste Fahrt, wenn möglich eine ohne Smartphone-Höhe) und prüfen: **Punktzahl und Auflösung der Spur im Detail-Abruf**, Puls und Höhe, größtes `limit`, wie weit zurück Fahrten abrufbar sind, Ratenbegrenzung (nirgends genannt), Einheit der Reichweite der Modi, Modus-Kennungen und ihre Namen; (4) Zuordnung an echten Paaren: Start (mit `timeZone`), Strecke, Route und `startOdometer` gegen die FIT-Fahrt; (5) Schlüsselbund und Anmeldung mit einem ad-hoc signierten Build bei einem Freund (wie V-10). Antworten vor dem Einchecken anonymisieren (NFR-12: Seriennummern, Kennungen, genaue Zeitpunkte). Ergebnis als `docs/SPIKE-BOSCH-DATA-ACT-API.md`, dann B-147 bis B-153, B-156, B-158 und B-159 nachschärfen (B-160 nur nach dem Ergebnis des Service Books); fällt es negativ aus, entfällt v1.9 | ☐ |
