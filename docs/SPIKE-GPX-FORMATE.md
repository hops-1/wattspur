# Spike V-11: GPX-Formate verschiedener Quellen

Stand: 25.10.2026 · Vorarbeit für den GPX-Import in v1.6 (B-139 bis B-146, Requirements 3.2 und 10.17)

## Ergebnis in einem Satz
**GPX ist ein loses Format: Der Parser muss nach lokalen Elementnamen lesen, Zeiten in allen ISO-Varianten annehmen und Lücken, doppelte Punkte und GPS-Sprünge als Normalfall behandeln.** Echt geprüft sind Bosch Flow (zwei Touren), komoot (eine Tour, dieselbe wie Bosch), BMW Motorrad Connected (zwei Dateien) und der eigene Export; alles andere ist nur aus Spezifikationen und Herstellerseiten belegt und unten als „nicht an einer echten Datei geprüft“ gekennzeichnet.

Die wichtigsten Befunde:
1. **Die geplante Streckenschwelle ±5 % ist zu knapp.** Bosch-FIT und GPX derselben Fahrt weichen um 4,9 % ab, weil die FIT-Strecke vom Radsensor kommt und die GPX-Strecke aus GPS-Punkten. Bei der zweiten Bosch-Tour sind es 4,4 bis 4,5 %. Vergleicht man GPS-Pfad mit GPS-Pfad, sind es 0,0 bis 0,1 %. Vorschlag: GPS-Pfad vergleichen, Toleranz ±10 %, Route (95-%-Abstand ≤ 60 m) als eigentliches Kriterium.
2. **komoot hat die Bosch-Fahrt mit denselben GPS-Punkten geführt, aber andere Höhen** (Anstieg 129 m statt 166 m bei 1 m Schwelle) und jeden dritten Punkt doppelt (gleicher Zeitstempel). Bei Summen aus GPX ist „geschätzt“ also keine Floskel: Anstieg und Abstieg weichen je nach Quelle um 14 bis 22 % ab.
3. **Keine einzige echte Datei enthält Leistung, Trittfrequenz oder Puls.** Auch die komoot-Datei nicht, obwohl die Bosch-FIT Leistung und Trittfrequenz hat. Das passt zum Plan (Leistung nur „wenn die Datei sie enthält“), heißt aber: Radcomputer- und Strava-Dateien mit Sensoren sind bisher nur aus Dokumentation bekannt (V-11 bleibt offen).
4. **Pausen stehen nicht als Stillstand in der Datei, sondern als Lücke.** Bosch lässt beim Anhalten einfach die Punkte weg (322 s, 79 s, 37 s …). Rechnet man alle Abstände unter 30 s als Fahrzeit, kommt man mit der Bosch-GPX auf **2 916 s, exakt die Fahrzeit der FIT**.
5. **Die BMW-Dateien zeigen die Schmutzfälle:** 33 Segmente über drei Tage, Lücken bis 17 Stunden, GPS-Sprünge von 90 bis 225 m in einer Sekunde (75 Mal in 81 230 Punkten), Höhensprünge um 60 m. Ohne Ausreißerfilter wären es 1 586 statt 1 455 km (+9 %).
6. **Foundation `XMLParser` reicht:** 81 230 Punkte (8,4 MB) in 0,12 s, BOM, CRLF und DOCTYPE mit internen Entities laufen, abgeschnittene Dateien melden einen Fehler nach den bis dahin gelesenen Punkten. Der Zeitstempel-Parser `Date(_:strategy:)` mit `time(includingFractionalSeconds: true)` nimmt alle gefundenen Varianten an (Sekunden, 1 bis 9 Nachkommastellen, `Z` und `±hh:mm`, sogar ohne Zone).

## Wie geprüft wurde
- Skripte außerhalb des Repos (`python3 -I`, `ElementTree` ohne Entity-Auflösung, kleines Swift-Programm für `XMLParser`), jede Datei in einem eigenen Ordner, nichts ausgeführt, nichts aus dem Netz geladen. Nur Webseiten gelesen (Garmin-Schemas, TopoGrafix, Strava- und Bosch-Hilfe, Ride-with-GPS-API, GPXSee-Quellcode).
- Echte Dateien kamen von Nils: `Tour1_Bosch-Flow.gpx` (Byte für Byte die Beispielfahrt „Reinheim Rundfahrt“), `Tour1_Komoot.gpx` (dieselbe Tour), `Tour2_Bosch-Flow.gpx`, `BMW_1.gpx` und `BMW_Gardasee_und_Dolomiten.gpx` (Motorrad eines Testers). Die FIT der Tour 1 liegt in `docs/reference/sample-data/`. Nils hat später die FIT zu Tour 2 und eine zweite Kopie der Tour-1-FIT geliefert und gebeten, die Zuordnung zu prüfen: **beide passen** (siehe unten).
- Evidenzstufen unten: **echt** = an einer Datei geprüft, **Doku** = aus Spezifikation oder Herstellerseite, **Drittquelle** = Beschreibung eines Fremdwerkzeugs oder Forums, **Erinnerung** = nicht belegt, nur zur Orientierung.

## Quelle × Merkmal

### Echt geprüft
| Merkmal | Bosch Flow (2 Touren) | komoot (Tour 1) | BMW Motorrad Connected (2 Dateien) | Wattspur-Export (`GPXWriter`) |
|---|---|---|---|---|
| Version, `creator` | 1.1, `https://www.bosch-ebike.com/` | 1.1, `https://www.komoot.de` | 1.1, `BMW Motorrad Connected` | 1.1, `Wattspur` |
| Namensräume | nur GPX 1.1, `xsi`, Schema-URL mit `https` | nur GPX 1.1, `xsi` | GPX 1.1 und `cnrd` (`http://www.bmw-motorrad.com/CNRD/1/0`), im Inhalt ungenutzt, keine Schema-URL | GPX 1.1, `gpxtpx` v2, `xsi` |
| XML-Kopf | `<?xml … encoding="UTF-8"?>` direkt vor `<gpx>`, ganze Datei in **einer Zeile** | Einfache Anführungszeichen in der Deklaration, eingerückt | `standalone="yes"`, Zeilenumbruch nach jedem Element | eingerückt |
| Aufbau | 1 `trk`, 1 `trkseg`; `trk` ohne Name und Typ | 1 `trk`, 1 `trkseg` | 1 `trk`; Gardasee **33 `trkseg`** (drei Tage), BMW_1: 1 | 1 `trk`, 1 `trkseg` je Teil einer zusammengefügten Fahrt |
| Metadaten | nur `metadata/name` (Tourname, mit „ß“), keine Zeit | `metadata/name` „Fahrradtour“, `author/link/text`; `trk/type` = `e_touring_bicycle` (komoot-Sportart) | `metadata/name` + `metadata/time`; Name bei BMW_1 ist ein **deutsches Datum** („16. Okt. 2026, 13:20“); kein `type` | `metadata/name` + `time`; `trk/type` = `cycling` |
| Zeitstempel | UTC `Z`, **6 bis 9 Nachkommastellen** (`…19.508648038Z`, Tour 2 teils 6) | UTC `Z`, immer `.000Z` | UTC `Z`, ganze Sekunden | UTC `Z`, ganze Sekunden |
| Abtastrate | ca. 1 Hz mit Jitter (0,6 bis 2 s, Median 0,99 s) | 1 Hz, **jeder dritte Punkt doppelt** (1 287 von 4 164 mit gleichem Zeitstempel, 1 297 mit gleicher Position) | exakt 1 Hz; steht das Motorrad, wiederholt sich die Position (6 %) | wie die Zeitreihe der Fahrt (1 Hz) |
| Position | 5 Nachkommastellen (≈ 1,1 m), **abschließende Nullen entfallen** (`49.8195`, `49.81`) | 6 Stellen | 6 Stellen; Attributreihenfolge `lat lon` **oder** `lon lat`, auch innerhalb einer Datei | 7 Stellen |
| Höhe | 2 Stellen, Rundungsrauschen (`176.23999`), barometrisch (Schritt je Punkt im Median 0,06 m) | 6 Stellen, glatt wie aus einem Höhenmodell (bis zu 101 Punkte gleich) | 5 Stellen, **GPS-Höhe** (Sprünge um 60 m) | 1 Stelle |
| Erweiterungen | keine | keine | keine | `<power>`, `gpxtpx:cad` (v2); nur bei gemessenen Werten |
| Pausen, Lücken | Punkte fehlen: 322 s, 79 s, 37 s, 18 s; Tour 2: 69 s, 15 s | gleiche Lücken (322, 78, 35, 16 s) | Segmentwechsel mit 53 s bis **62 267 s** Abstand und 0 bis 1 330 m Sprung | Segment je Teil |
| Besonderheiten | Start 4,5 s nach dem ersten GPS-Record der FIT, 6,5 s nach Sitzungsbeginn; 58 Punkte weniger als FIT-GPS-Records (2 858 von 2 916); Zeiten im Mittel 0,58 s nach den ganzen FIT-Sekunden | Start 1 s nach FIT-Start; Positionen **identisch** mit den FIT-GPS-Fixes | GPS-Sprünge (75 Schritte > 250 km/h), Höhensprünge, 28 Zeitstempel doppelt | nur Punkte mit Position |
| Größe | 205 bis 298 KB | 567 KB | 417 KB und 8,4 MB (81 230 Punkte) | – |

### Nicht an einer echten Datei geprüft
| Quelle | Was aus Doku und Drittquellen bekannt ist | Stufe |
|---|---|---|
| **Strava** | „Export GPX“ im Menü „…“ der Aktivität, „Export Original“ liefert meist die FIT; die GPX enthält Position, Zeit, Puls, Trittfrequenz, Temperatur, **Leistung nur bei Leistungsmesser**, keine geschätzte Leistung. Sammelexport als ZIP mit einer Datei je Aktivität (Format wie hochgeladen). Aktivitäten ohne GPS liefern leere Dateien. Einzelheiten wie `creator="StravaGPX"`, `<power>` direkt in `extensions`, `gpxtpx` v1 für `hr`/`cad`/`atemp` und ein numerisches `<type>` stammen aus Drittwerkzeugen und Erinnerung | Doku (Inhalt), Drittquelle/Erinnerung (Schreibweise) |
| **Garmin Connect / Edge** | Export nur im Web: „Export to GPX“ oder „Original“ (ZIP mit FIT). GPX trägt laut Drittwerkzeug Puls und Trittfrequenz (`gpxtpx`); Leistung: Quellen widersprechen sich. Edge selbst schreibt FIT. Garmin definiert `TrackPointExtension` v1 (`atemp`, `wtemp`, `depth`, `hr`, `cad`) und v2 (zusätzlich `speed`, `course`, `bearing`) | Doku (Schema), Drittquelle (Export) |
| **Wahoo ELEMNT** | Training in der App: Verlauf → Aktion → „.fit-Datei teilen“. Ein GPX-Export für Trainings wurde nicht gefunden (GPX nur für Routen). Wahoo-FIT hat mehr Daten als die GPX-Fassung bei Strava | Drittquelle |
| **Hammerhead Karoo** | Keine Dokumentation zum Export gefunden; ein Testbericht beschreibt nur, dass Fahrten als FIT an Partner (z. B. Suunto) übertragen werden | nicht belegt |
| **Ride with GPS** | Aufzeichnung bis 1 Hz mit Geschwindigkeit (km/h in der API), Trittfrequenz, Leistung, Puls, Temperatur; wie das in GPX geschrieben wird, steht nicht in der Doku | Doku (API), Rest nicht belegt |
| **Apple Fitness / Health** | „Alle Gesundheitsdaten exportieren“ erzeugt `export.zip` mit `workout-routes/route_<Datum>.gpx` (je eine Datei pro Route). Fremde Exportapps schreiben Puls, Leistung, Trittfrequenz und Geschwindigkeit als `gpxtpx`/`gpxpx`; die Höhe ist ab Apple Watch Series 3 barometrisch. Elementnamen im rohen Apple-Export (z. B. `speed`, `course`, `hAcc`) sind **nicht belegt** | Drittquelle |
| **komoot-Planung** | Geplante Touren liefern Route oder Track **ohne Zeit**. Der Export ist nur für eigene Touren möglich. Nicht an einer Datei geprüft | Drittquelle |
| **Bosch Flow (App)** | Seit dem Update 05/2023 GPX- und FIT-Export und Teilen; FIT hat die Zusatzdaten. Menüpfad nicht geprüft | Doku |
| **Specialized, Giant, Shimano E-TUBE, Bafang** | Keine Dateiexporte gefunden. Mission Control teilt zu Strava und komoot, E-TUBE Ride zu Strava; Giant und Bafang ergaben keine Treffer. Realistischer Weg: über Strava oder komoot als GPX | Doku (nur Teilen) |

## Befunde im Detail

### Bosch Flow und komoot an derselben Tour
- **Zeit:** FIT-Start 12:12:13 (Sitzungsbeginn), erster GPS-Record 12:12:15. Bosch-GPX beginnt 12:12:19,5 (+6,5 s), komoot 12:12:14 (+1 s). Ende: FIT 13:08:15, Bosch-GPX 13:08:13,6 (−1,5 s), komoot 13:08:15. Die Bosch-GPX-Zeiten liegen im Mittel 0,58 s nach den ganzen FIT-Sekunden (Spanne 0,45 bis 0,84 s), weil sie Bruchteile tragen.
- **Strecke:** FIT-Session 19 543 m (Radsensor), GPS-Pfad der FIT 18 595 m, Bosch-GPX 18 614 m, komoot 18 595 m. Gegenüber der Session sind das −4,8 % (Bosch-GPX) und −4,9 % (FIT-GPS, komoot). Tour 2: Session 13 003 m, FIT-GPS-Pfad 12 416 m (−4,5 %), Bosch-GPX 12 430 m (−4,4 %).
- **Route:** Jeder komoot-Punkt entspricht einem GPS-Fix der FIT (6 Stellen, 4 164 von 4 164). Abstand der Bosch-GPX zur komoot-Spur: Median 0,3 m, größter Wert 2,8 m (Rundung auf 5 Stellen).
- **Höhe:** Die Bosch-GPX liefert mit 1 m Schwelle **166 m Anstieg und 169 m Abstieg, genau die Werte der FIT-Session**. komoot: 129 m und 146 m (−22 %/−14 %), mit 3 m Schwelle 114 und 133.
- **Fahrzeit:** FIT-Timer 2 916 s = Anzahl der GPS-Records. Elapsed 3 364 s, davon 448 s Pause als Lücke.

### Zuordnung der FIT zu den GPX-Touren (Prüfung 25.10.2026)
- **Tour 1:** `Reinheim Rundfahrt-…-2f4d8b0c3e57.fit 2` ist Byte für Byte die FIT der Beispielfahrt (gleiche Prüfsumme); sie gehört zur Bosch-GPX und zur komoot-Datei (siehe oben).
- **Tour 2:** `Fahrt Roßdorf bis Reinheim-….fit` passt zur `Tour2_Bosch-Flow.gpx`. Gleicher Name, gleicher Tag (22.10.2026), Start 16:22:25 (erster GPS-Record 16:22:27, GPX 16:22:31,8), Ende 16:56:55 (GPX 16:56:52). Route: jeder GPX-Punkt liegt höchstens 0,7 m von der FIT-Spur (Median 0,3 m); die FIT-Punkte, die in der GPX fehlen (Anfang und Ende), liegen höchstens 8 m daneben. Strecke Session 13 003 m, Fahrzeit 2 004 s, Anstieg 73 m, Abstieg 116 m; die GPX ergibt mit 1 m Schwelle 75 und 118 m (+2 %) und mit Lücken ≥ 30 s 1 991 s Fahrzeit (−0,7 %). Die Bosch-GPX-Zeiten liegen auch hier im Mittel 0,85 s nach den ganzen FIT-Sekunden.
- Beide Paare bestätigen die Grundmuster: GPX beginnt 6,5 bis 7 s nach dem Sitzungsbeginn und endet 1,5 bis 3 s vor dem letzten FIT-Record, mit 26 bis 58 Punkten weniger als GPS-Records; die Session-Strecke liegt 4,4 bis 4,9 % über dem GPS-Pfad.

### BMW Motorrad Connected
- Ein Motorrad, kein Rad: Ø 65 km/h bei BMW_1 (73 km in 67 min), Spitzen bis 169 km/h (teils GPS-Sprünge). Die Datei verrät den Typ nicht (kein `type`), aber der Tester hat sie importieren wollen.
- **GPS-Sprünge:** 75 Schritte mit > 250 km/h innerhalb von Segmenten (z. B. 225 m in 1 s, dann mehrere Punkte hintereinander ≈ 90 m in 1 s). Dazu mehrere Höhensprünge > 40 m zwischen zwei Sekunden (GPS-Höhe).
- **Segmente:** Lücken zwischen den 33 Segmenten von 22 s bis 62 267 s; nach der Nacht springt die Position um 1 330 m. Wattspur darf diese Lücken weder als Fahrzeit noch als Strecke zählen.
- **Ausreißerfilter wirkt:** Verwirft man Punkte, die mehr als 250 km/h von ihrem Vorgänger entfernt sind, sinkt die Gesamtstrecke von 1 586 auf 1 455 km (310 Punkte). Bei den drei Radfahrten verwirft ein Grenzwert von 100 km/h höchstens 1 Punkt.

### Eigener Export (`GPXWriter`)
Verlustfrei zurück sind Position, Höhe (1 Stelle), Zeit (Sekunden), Leistung und Trittfrequenz. Verloren geht beim Export: Nachkommastellen der Zeit, Puls, Temperatur, Geschwindigkeit, Bike (der Name kommt mit B-136 als Metadatum dazu). Der Importer muss das Format also nur *lesen* können, ein Rundreise-Test mit `GPXWriter` ist ohne Datei möglich.

## Zusatzfelder: wie stabil sind die Namen? (Frage 1)
Nicht stabil. Quellen und Fremdparser zeigen mehrere Schreibweisen für dieselbe Größe; der GPXSee-Parser liest zum Beispiel `power`, `PowerInWatts`, `hr`, `heartrate`, `cadence`, `temp`, `speed` und das `TrackPointExtension`-Element, ohne auf Namensräume zu achten.

| Größe | Schreibweisen (Stufe) | Regel für den Parser |
|---|---|---|
| Leistung | `<power>` direkt in `extensions` (Wattspur: echt; Strava: Drittquelle), `PowerInWatts` aus Garmins Power-Erweiterung (Erinnerung; GPXSee liest es) | lokaler Name `power` oder `powerinwatts`; ganze Watt, 0 bis 3 000 sonst verwerfen |
| Trittfrequenz | `cad` in `TrackPointExtension` v1/v2 (Wattspur: echt; Garmin: Doku), bloß `cadence` | `cad`, `cadence`; 0 bis 254 (Schema), sonst verwerfen |
| Puls | `hr` in `TrackPointExtension`, bloß `hr` oder `heartrate` | `hr`, `heartrate`; 1 bis 255, 0 heißt „nicht gemessen“ |
| Temperatur | `atemp` (Luft), `wtemp` (Wasser), bloß `temp` | `atemp`, `temp`; `wtemp` ignorieren; plausibel −50 bis 60 °C |
| Geschwindigkeit | v2: `speed` (m/s); GPX 1.0: `<speed>` direkt am Punkt; bloß in `extensions` | nur lesen, nicht verwenden (Geschwindigkeit kommt aus Abstand und Zeit) |
| Kurs | GPX 1.0 `course`; v2 `course`, `bearing` | ignorieren |

Der Präfix ist beliebig (`gpxtpx`, `ns3`, `tpx`, keiner), der Namensraum-URI für `TrackPointExtension` ist `…/TrackPointExtension/v1` oder `…/v2`. Deshalb: **nach lokalem Namen suchen, in Namensraum und Präfix nicht festlegen**, unbekannte Elemente überspringen, nur dann etwas speichern, wenn der Wert im plausiblen Bereich liegt. Einheiten: SI (m/s, °C, Watt, bpm); die API von Ride with GPS nutzt km/h, das gilt aber nicht für deren GPX (nicht geprüft).

## Folgen für den Parser (B-140)
1. **Streaming mit `XMLParser`**, `shouldProcessNamespaces = true`, `shouldResolveExternalEntities = false`. Keine DOM-Bäume: Die größte Datei (8,4 MB, 81 230 Punkte) braucht 0,12 s. Dateien mit DOCTYPE und internen Entities (`&tourname;`) dürfen nicht abstürzen; externe Entities nie auflösen. Als Grenze Dateigröße (z. B. 200 MB) und Punktzahl (z. B. 5 Mio.) festlegen.
2. **Reihenfolge der Attribute und Elemente ist beliebig** (`lon` vor `lat` kommt in einer BMW-Datei vor). `lat`, `lon` als Pflicht, `ele`, `time` optional.
3. **Zeit:** `Date(_:strategy:)` mit `.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: true)` (ohne Zone nimmt der Parser die Zeit an; sie gilt dann als UTC, die Auslegung ist noch zu prüfen und im Protokoll zu vermerken). Beachtet: `Date` speichert Sekunden als Zahl, Mikrosekunden genügen; die 9 Stellen von Bosch werden also gerundet. **Keine Zeitstempel → Fehler mit klarer Meldung** („Die Datei enthält keine Zeiten“), ebenso bei Dateien mit nur `rte`/`wpt`. Teilweise fehlende Zeiten: Punkte ohne Zeit verwerfen, bei > 5 % ablehnen.
4. **Mehrere Tracks und Segmente → eine Fahrt.** Jede `trkseg`-Grenze ist ein Teil; zusätzlich beginnt ein neuer Teil, wenn der Abstand zum Vorgänger ≥ 30 s ist. Über Teile hinweg wird weder Zeit noch Strecke gerechnet.
5. **Gleiche Zeitstempel:** Punkte mit demselben Zeitstempel zusammenfassen (der erste gewinnt; komoot schreibt 31 % doppelt). Rückwärtslaufende Zeiten: nach Zeit sortieren, wenn die Datei insgesamt nur wenige Rückwärtsschritte hat (BMW und Bosch: keine), sonst Fehler.
6. **Ausreißer verwerfen:** Punkt ist ein Sprung, wenn die Geschwindigkeit zum letzten behaltenen Punkt über einer Grenze liegt (Vorschlag 150 km/h bei Fahrrädern, siehe offene Frage zu Motorrädern). Koordinate 0/0 und Breite/Länge außerhalb des Bereichs immer verwerfen. Höhe 0 oder fehlend: als „keine Höhe“ behandeln, nicht als Meeresspiegel.
7. **Höhenquelle unbekannt.** Die Datei verrät nicht, ob die Höhe barometrisch, vom GPS oder aus einem Höhenmodell kommt; die Glättung (unten) muss mit allen drei zurechtkommen.
8. **Teilweise Erweiterungen:** In `strava-style-power-hr-cad.gpx` fehlt die Leistung ab Punkt 50. Fehlende Werte bleiben `nil`, werden nicht aufgefüllt.
9. **BOM, CRLF, Kommentare, CDATA, `standalone`, unbekannte Namensräume** müssen durchlaufen. Dateien in UTF-16 oder mit falsch erklärter Kodierung: Fehler statt Absturz.
10. **Abgeschnittene Datei:** `XMLParser` meldet Fehler 111 nach den bis dahin gelesenen Punkten (Testdatei: 32). Empfehlung: ablehnen und ins Protokoll („Datei ist unvollständig“), kein Teilimport; offene Frage an Nils.
11. **Name der Fahrt:** `trk/name`, sonst `metadata/name`, sonst Dateiname. Datumsnamen wie „16. Okt. 2026, 13:20“ (BMW) sind gültig, aber nicht schön; wenn der Name wie ein Datum aussieht, besser „GPX-Fahrt vom <Datum>“.
12. **Quelle merken:** `creator` und `trk/type` als Hinweis in `ImportRecord`, nicht für Logik (komoot schreibt Sportartcodes, Strava vermutlich Zahlen).

## Stillstand und Höhenglättung für die Summen (Frage 2, B-142, später einstellbar SET-04)
**Messbasis:** Bosch-GPX und komoot der Tour 1 gegen die FIT-Werte, dazu eine synthetische Datei mit GPS-Zittern im Stand (2 m Rauschen pro Achse und Sekunde, Soll 300 s Fahrzeit) und ein Rauschmodell für die Höhe (siehe `stillstand-gps-drift.gpx`; die Höhenrauschdateien erzeugen die Tests selbst).

### Pause und Stillstand
| Parameter | Startwert | Begründung |
|---|---|---|
| Pause (Lücke) | Abstand zum Vorgänger **≥ 30 s** → keine Zeit, keine Strecke | Bosch-GPX ergibt so exakt 2 916 s (FIT-Timer); Abstände bis 18 s kommen im Betrieb noch vor und zählen als Fahrt |
| Stillstand | Geschwindigkeit über ein Fenster von **±5 s** um das Intervall **< 0,8 m/s (2,9 km/h)** → steht | Einzelpunkt-Geschwindigkeit versagt beim GPS-Zittern (389 s statt 300 s); mit ±5 s und 0,8 m/s sind es 315 s (+5 %). Langsame Anstiege mit 1,1 m/s (4 km/h) bleiben Fahrt |
| Ergebnis an echten Dateien | Bosch-GPX 2 893 s (FIT 2 916, −0,8 %), komoot 2 905 s (−0,4 %), BMW_1 3 952 von 4 046 s | die Summe liegt innerhalb 1 % der FIT |

Die Fahrzeit der FIT ist ein Timer, kein Stillstandsmaß. Wattspur zeigt bei GPX-Fahrten deshalb nicht die FIT-Fahrzeit; weicht die Fahrzeit einer GPX später von der FIT ab, gilt die FIT (Requirements 3.3).

### Höhe: Anstieg und Abstieg
Zwei Schritte: **Median über 5 Punkte**, dann **Schwellenverfahren** (eine Höhenänderung zählt erst, wenn sie die Schwelle gegenüber dem letzten gezählten Punkt überschreitet).

| Schwelle | Bosch-GPX Tour 1 (Soll 166 / 169) | komoot Tour 1 (Soll 166 / 169) | Rauschmodell GPS-Höhe σ 1,5 m, flach 3 600 s |
|---|---|---|---|
| 1 m | **166 / 169** | 129 / 146 | 160 m falscher Anstieg (Median 5); bei einer echten 100-m-Steigung 189 m |
| 2 m | 152 / 157 | 118 / 136 | 85 m; Steigung 130 m |
| 3 m | 147 / 152 | 114 / 133 | 33 m; Steigung 109 m |
| 5 m | 133 / 140 | 102 / 122 | 0 m; Steigung 100 m |

**Vorschlag:** Median 5 und **3 m** als Startwert; in den Einstellungen drei Stufen (SET-04): „fein 1 m“ (barometrische Höhe, entspricht Bosch), „normal 3 m“ (Standard), „grob 5 m“ (verrauschte GPS-Höhe). Begründung: 1 m trifft Bosch exakt, überschätzt aber bei GPS-Höhe um das Dreifache; 3 m verfehlt Bosch um 10 %, bleibt aber auf allen drei Höhenarten brauchbar. Auf barometrischer Höhe (Simulation σ 0,15 m) kostet 3 statt 1 m nur etwa 2 %, bei den echten Bosch-Daten 11 % (147 statt 166); auf GPS-Höhe ändert die Schwelle das Ergebnis um ein Mehrfaches.
Eine automatische Wahl (Rauschmaß aus der Datei schätzen) lohnt sich erst, wenn echte Strava- und Radcomputer-Dateien vorliegen; ohne solche Dateien bleibt sie ungeprüft.

### Ausreißer und Strecke
- Spike-Filter: Punkt verwerfen, wenn die Geschwindigkeit zum letzten behaltenen Punkt **> 150 km/h** liegt und die Lücke < 30 s ist. Bei Fahrrädern verwarf 100 km/h höchstens 1 Punkt.
- Strecke = Summe der Abstände behaltener Punkte innerhalb eines Teils (Haversine). Für Tour 1 ergibt das 18,59 km (FIT-GPS-Pfad 18,59 km, FIT-Session 19,54 km).
- **Höchstgeschwindigkeit** nicht aus einzelnen Punkten, sondern aus einem gleitenden Fenster von 5 s; sonst zählt jeder GPS-Sprung.

## Dieselbe Tour als FIT und GPX: reichen die Schwellen? (Frage 3, B-143)
Gemessen an Tour 1 (FIT, Bosch-GPX, komoot) und an Simulationen der FIT-Spur mit Positionsrauschen und gröberer Abtastung (zufällig, Saat fest; keine echten Strava-Dateien):

| Kriterium | Beobachtung | Folge |
|---|---|---|
| **Start ±60 s** | echte Abweichungen 1 bis 6,5 s | reicht weit; echte Fremdgeräte können eine Zeitzone falsch schreiben, deshalb nur UTC vergleichen und `metadata/time` **nicht** nehmen, sondern den ersten Punkt |
| **Strecke ±5 %** | FIT-Session gegen GPX −4,8 bis −4,9 %; GPS-Pfad gegen GPS-Pfad 0,0 bis 0,1 %; grobe Abtastung (30 s) schneidet Kurven: −6,8 % | **zu knapp**. Vorschlag: den GPS-Pfad beider Fahrten vergleichen, nicht die Session-Strecke, und ±10 % zulassen |
| **Route** | Abstand beider Spuren zueinander (Polylinie gegen Polylinie): gleiche Quelle 0,1 m; Rauschen 3 m/5 s Median 1,6 m, 95 % 5 m; Rauschen 10 m/15 s 95 % 18 m; 15 m/30 s 95 % 50 m; andere Fahrt im selben Gebiet 95 % > 3 000 m; erste 90 % derselben Fahrt: 95 % 279 m | Kriterium: **95-%-Abstand in beiden Richtungen ≤ 60 m** und Median ≤ 25 m. Es schließt verschiedene Fahrten sicher aus und lässt gröbere Radcomputer zu |
| **Teilaufzeichnung** | Fahrt mit nur 90 % der Strecke: Strecke −9,4 %, Route 279 m | wird nicht als Duplikat erkannt; sinnvoll (ein Akku-Ausfall ist eine andere Datei), aber ein Hinweis „ähnlich“ wäre denkbar (offene Frage) |

Gefahr falscher Treffer: **Gruppenfahrt.** Zwei Personen auf derselben Tour starten zur selben Minute, gleiche Route, gleiche Strecke, und ihre Dateien würden als Duplikat gelten. Im Alltag trifft das Wattspur-Nutzer mit Freunden-Dateien. Schutz: Duplikat nur innerhalb desselben Bikes oder derselben Quelle vorschlagen, bei Treffern in einem anderen Bike den Dialog mit Bike-Namen zeigen. Zum Duplikatdialog gehört außerdem die Quelle (Gerät, `creator`).

Die Auswahl der Fahrten für den Vergleich ist billig: erst Start ±60 s (Index über `startDate`), dann Strecke ±10 %, erst dann die Route (50 m neu abgetastete Punkte, Gitter mit 200 m Zellen); die Laufzeit wurde nicht gemessen (die Python-Skizze brauchte für eine Fahrt einige Sekunden, in Swift mit Gitter wesentlich weniger). Das Paar „Bosch-FIT gegen Strava-GPX“ ist weiterhin nicht an echten Daten belegt; belegt sind nur Bosch-FIT gegen Bosch-GPX (zwei Touren) und gegen komoot (eine Tour).

## Testdateien
Alle vorhandenen Dateien liegen als `*.gpx` bzw. `*.fit` unter `Packages/WattspurKit/Tests/WattspurKitTests/Fixtures/GPX/` (Ausnahme in `.gitignore`, Aufbau in der dortigen `README.md`). Echte Fahrten sind verschoben (Position um einen festen Versatz, Zeiten um ganze Wochen, wie bei `anonymize-fit`) und die Namen ersetzt. Der Versatz steht bewusst nicht im Repo. Die Verschiebung ändert die Strecke leicht (anderer Breitengrad): Erwartungswerte der Tests aus der Datei selbst berechnen, nicht aus den Zahlen dieser Notiz. **Stand V-05 (25.10.2026):** alle echten Dateien mit einem neuen, gemeinsamen Versatz verschoben (Nachkommastellen und Zeitformate unverändert), die ganzen Touren (`pair-*`) zusätzlich um 500 m an Start und Ende gekürzt. In FIT bleiben die Samples ohne Position; in GPX bleiben die gekürzten Punkte mit ihrer Zeit, liegen aber auf dem ersten bzw. letzten gezeigten Punkt (Stillstand). Start und Ende passen damit weiter zur FIT-Fahrt; Fahrzeit und GPS-Strecke der GPX sind um etwa 200 s und 1,2 km kleiner. Die Auszüge (`bosch-flow-excerpt-gaps`, `bmw-*`) stammen aus der Mitte von Fahrten und sind nur verschoben. BMW- und komoot-Dateien enthalten nur die selbst aufgezeichneten Fahrten der Tester und von Nils, keine fremden Karten- oder Routendaten.

### Vorhanden (im Repo)
| Datei | Quelle | Prüft |
|---|---|---|
| `pair-tour1-bosch-flow.gpx` | Bosch Flow, ganze Tour 1 | Sekunden-Jitter, 9 Nachkommastellen, getrimmte Nullen, Lücken als Pause, Duplikatpaar |
| `pair-tour1-bosch-flow.fit` | dieselbe Fahrt, mit `anonymize-fit` (gleicher Versatz, 500 m gekürzt) | FIT + GPX derselben Tour (B-143) |
| `pair-tour1-komoot.gpx` | komoot, dieselbe Tour | doppelte Zeitstempel, `type`, `author`, Höhe aus dem Höhenmodell |
| `pair-tour2-bosch-flow.gpx` und `.fit` | Bosch Flow, ganze Tour 2 (34 min, 13,0 km vor dem Kürzen) | zweites Paar FIT + GPX, 15 s und 69 s Lücke, 6/9-stellige Zeit, Stellenzahl 2 bis 5 |
| `bosch-flow-excerpt-gaps.gpx` | Bosch Flow Tour 2, 300 Punkte | kleiner Auszug mit den beiden Lücken für schnelle Tests |
| `bmw-motorrad-excerpt-glitch.gpx` | BMW_1, 90 Punkte | GPS-Sprung > 150 km/h, 6 Punkte hintereinander |
| `bmw-motorrad-multi-segment.gpx` | BMW Gardasee, 4 Segmente | Segmentwechsel mit 24 301 s und 62 267 s, Sprung 1 330 m, `lon` vor `lat` |
| `wattspur-export.gpx` | wie `GPXWriter` (selbst erzeugt) | `<power>` und `gpxtpx:cad` v2, zwei Segmente, lückenhafte Erweiterungen |
| `garmin-tpx-v1-hr-cad-temp.gpx` | selbst erzeugt **nach Schema**, nicht nach echter Datei | `gpxtpx` v1 mit `hr`, `cad`, `atemp`, eingerückt |
| `strava-style-power-hr-cad.gpx` | selbst erzeugt **nach Drittquellen**, nicht nach echter Datei | `<power>` direkt, Leistung fällt ab Punkt 50 aus, numerischer `type`, Entity `&amp;` im Namen |
| `gpx10-speed-course.gpx` | selbst erzeugt, GPX 1.0 | Namensraum `/1/0`, `speed`, `course`, `fix`, `sat`, `hdop`, Zeit auf Dateiebene |
| `route-and-waypoints-only.gpx` | selbst erzeugt | nur `rte`/`wpt`: wird mit Meldung abgelehnt |
| `track-without-time.gpx` | selbst erzeugt | Track ohne Zeit: wird mit Meldung abgelehnt |
| `time-formats-and-offsets.gpx` | selbst erzeugt | `+02:00`, `-04:00`, 1/3/9 Nachkommastellen, ohne Zone |
| `faults-order-duplicates-zero.gpx` | selbst erzeugt | rückwärts laufende Zeiten, gleicher Zeitstempel, doppelter Punkt, 0/0, Höhe 0 oder fehlend, Sprung um 40 km, leeres Segment, leerer Track |
| `bom-crlf-doctype-vendor-extensions.gpx` | selbst erzeugt | BOM, CRLF, DOCTYPE mit interner Entity, Kommentar, CDATA, fremde Erweiterungen, `speed`/`course`/`hAcc` als bloße Elemente |
| `truncated.gpx` | selbst erzeugt, ab Mitte abgeschnitten | unvollständiges XML (Fehler nach 32 Punkten) |
| `stillstand-gps-drift.gpx` | selbst erzeugt, Saat fest | Stillstand mit GPS-Zittern; Soll 300 s Fahrzeit, 1,67 km Strecke bei Parametern oben |

### Im Test selbst erzeugen (keine Datei im Repo)
- **Große Datei:** 1 Mio. Punkte in Speicher/temporärer Datei (≈ 100 MB); Zeit und Speicher des Parsers messen.
- **Höhenrauschen:** AR(1)-Reihe (ρ = 0,95; σ = 0,15 m und 1,5 m und 3 m), dazu ein 60-m-Anstieg und -Abstieg; Soll: Anstieg 60 ± 10 m bei „normal“ (3 m) und höchstens 40 m Scheinanstieg auf dem Flachen bei σ = 1,5 m.
- **Gefährliche XML-Fälle:** Entity-Explosion („Billion Laughs“) und externe Entity als eingebettete Zeichenfolge, damit keine solche Datei im Repo liegt; falsch erklärte Kodierung (ISO-8859-1), UTF-16.
- **Rundreise:** `GPXWriter` → Importer, auch mit zusammengefügter Fahrt.

### Von Nils zu besorgen (V-11 bleibt dafür offen)
| Datei (Wunschname) | Wofür |
|---|---|
| `docs/reference/sample-data/gpx/strava-tour1.gpx` und `…fit` | Strava-GPX **und** Original derselben Fahrt, wenn Tour 1 oder 2 bei Strava ankommt; das ist das wichtigste fehlende Paar (Duplikat, Namen der Erweiterungen) |
| `…/radcomputer-<gerät>-mit-leistung.gpx` (+ FIT) | Garmin Edge/Wahoo/Karoo mit Leistungsmesser, ggf. von einem Tester: `<power>` oder `PowerInWatts`, Präfixe, Abtastrate bei „Smart Recording“ |
| `…/radcomputer-<gerät>-ohne-sensoren.gpx` | nur Position und Zeit, Zeitstempel mit Offset |
| `…/komoot-aufgezeichnet-telefon.gpx` | von komoot selbst aufgezeichnet (nicht aus Bosch übernommen), prüft, ob komoot dort Puls/Trittfrequenz schreibt und wie die Höhe aussieht |
| `…/apple-health-route.gpx` | Roh-Export `workout-routes/route_*.gpx` einer Radfahrt |
| `…/ridewithgps-trip.gpx` | Export einer aufgezeichneten Fahrt (nicht einer Route) |

Lokal ohne Anonymisierung (bleibt wegen NFR-12 außerhalb des Repos, `.gitignore` greift schon): die fünf gelieferten Originale in `docs/reference/sample-data/gpx/` ablegen (`tour1-bosch-flow.gpx` ist dieselbe Datei wie die vorhandene Beispielfahrt, `tour1-komoot.gpx`, `tour2-bosch-flow.gpx`, `bmw-1.gpx`, `bmw-gardasee-und-dolomiten.gpx`).

## Exportwege für Nils (Schritt für Schritt)
Die Menünamen sind nicht in jedem Fall an der aktuellen App geprüft; stimmt etwas nicht, bitte kurz melden.

1. **Strava** (Web, Doku bestätigt): Aktivität öffnen → oben rechts „…“ → **„Export GPX“**; zum Vergleich daneben **„Export Original“** (meist FIT, bei Radcomputer-Fahrten mit Sensoren). Für viele Fahrten: Einstellungen → „Mein Konto“ → „Daten herunterladen“ → „Archiv anfordern“, die E-Mail mit dem Link kommt nach einigen Stunden; die ZIP enthält die Originaldateien. Zuerst eine Fahrt mit Leistungsmesser, dann eine ohne.
2. **komoot** (Web): Tour öffnen → Menü „…“ → **„Als GPX exportieren“** (Menütext nicht geprüft). Für „aufgezeichnet vom Telefon“ eine Tour wählen, die mit der komoot-App aufgezeichnet wurde, nicht eine, die über Bosch kam. Geplante Touren ohne Zeit zusätzlich exportieren (für den Fehlerfall).
3. **Garmin Connect** (nur Web, nicht in der App): Aktivität öffnen → Zahnrad oben rechts → **„Export to GPX“** und **„Export Original“** (ZIP mit FIT).
4. **Wahoo ELEMNT**: ELEMNT-App → „Verlauf“ → Training → „Aktion“ → **„.fit-Datei teilen“**. GPX gibt es für Trainings nicht direkt; entweder über Strava exportieren (Punkt 1) oder die FIT ins Repo legen, dann kann Wattspur später auch FIT von Fremdgeräten lesen (B-076).
5. **Hammerhead Karoo**: Hammerhead-Dashboard im Browser → Fahrten → die Fahrt → Download/Export (Format und Menü nicht geprüft). Alternativ über Strava.
6. **Ride with GPS** (Web): aufgezeichnete Fahrt („Trip“) öffnen → Exportfunktion → GPX-Track (nicht „Route“); Menütexte nicht geprüft.
7. **Apple Health** (iPhone): Health-App → Profilbild → **„Alle Gesundheitsdaten exportieren“**; die entstehende `export.zip` auf den Mac holen und `workout-routes/route_<Datum>.gpx` entnehmen. Dauert bei großen Beständen Minuten und die ZIP kann groß sein.
8. **Bosch Flow**: in der Flow-App die Fahrt öffnen → Teilen/Exportieren → GPX oder FIT (laut Bosch seit 05/2023; Menüpfad nicht geprüft). Du hast dafür schon das Muster aus `docs/reference/sample-data/`.
9. **Specialized / Giant / Shimano**: keine Dateiexporte gefunden. Fahrt zu Strava oder komoot teilen und dort exportieren (Punkte 1 und 2).

## Empfehlungen für die Stories
- **B-140 (Parser):** Regeln aus „Folgen für den Parser“; Fixtures aus der Tabelle; zusätzlich ein Test, der aus jeder Datei im Fixture-Ordner das erwartete Ergebnis prüft (Zahl Teile, Zahl Punkte, Fehlerart).
- **B-142 (Summen):** Parameter aus „Stillstand und Höhenglättung“ als Konstanten mit Namen, Tests gegen die gemessenen Werte der Tour-1-Dateien (Fahrzeit ±1 %, Anstieg bei 1 m exakt 166/169, Strecke 18,5 km) und gegen die synthetischen Dateien; Einstellung später (SET-04).
- **B-143 (Duplikate):** GPS-Pfad-Vergleich, ±10 % statt ±5 %, Route nach 95-%-Abstand; Gruppenfahrt beachten; Test mit dem Paar `pair-tour1-*`.

## Offene Fragen an Nils
1. **Strecke ±5 % oder ±10 %?** Die Messung (4,9 %) spricht für ±10 % und den Vergleich der GPS-Pfade. Soll Requirements 10.17 so geändert werden?
   **Entschieden (Nils, 25.10.2026): ±10 %**, bestätigt über die vereinfachte Route (B-104); Requirements 10.17 ist angepasst.
2. **Motorrad und andere Aktivitäten:** BMW-Dateien lassen sich ohne Weiteres importieren (Ø 65 km/h, 1 586 km in drei Tagen). Soll Wattspur Fahrten mit Ø > 45 km/h oder Spitzen > 150 km/h ablehnen, mit Warnung importieren oder als Fahrrad annehmen? Vorschlag: mit Warnung importieren (Hinweis „sieht nicht nach einer Radfahrt aus“) und vom Spike-Filter der Rad-Grenze (150 km/h) ausnehmen.
3. **Abgeschnittene Dateien:** ablehnen (Vorschlag) oder die bis dahin gelesenen Punkte importieren und kennzeichnen?
4. **Gruppenfahrt:** Duplikate nur innerhalb desselben Bikes vorschlagen (Vorschlag)? Oder immer und den Dialog das Bike nennen lassen?
5. **Höhenschwelle:** 3 m als Standard (Vorschlag) oder lieber 1 m wie Bosch, weil die meisten Nutzer Bosch-Daten haben? Bei GPS-Höhe (Strava ohne Barometer, BMW) wäre 1 m dreifach zu hoch.
   **Entschieden (Nils, 25.10.2026): Median über 5 Punkte und Schwelle 3 m.**
6. **Fahrzeit bei GPX:** Stillstand rausrechnen (Vorschlag, 0,8 m/s) oder nur Lücken ≥ 30 s als Pause nehmen und Stillstand als Fahrzeit lassen? Die zweite Variante trifft die FIT-Fahrzeit exakt (2 916 s), die erste ist näher an dem, was Strava und Garmin als „Bewegungszeit“ zeigen.
   **Entschieden (Nils, 25.10.2026): Pause ab 30 s Lücke zwischen Punkten, Stillstand bei Geschwindigkeit unter 0,8 m/s.**
7. **Dateien:** Magst du die Strava-/Radcomputer-/Apple-Dateien aus der Tabelle (oben) aus deinen eigenen Konten exportieren ? Und die fünf Originale lokal unter `docs/reference/sample-data/gpx/` ablegen?
8. **Fixtures vor Veröffentlichung:** Erledigt (V-05): Die Paare sind gekürzt, ohne die Zeiten zu verlieren (siehe „Testdateien“); die Startdifferenz zur FIT-Fahrt bleibt wie im echten Fall.

## Quellen
- GPX 1.1: [topografix.com/GPX/1/1](https://www.topografix.com/GPX/1/1/) (`trkpt`, `time` als `xsd:dateTime`, `extensions`, `metadata`); GPX 1.0 nur als Hinweis auf die Jahreszahlen (kein Wortlaut gelesen).
- Garmin: [TrackPointExtension v1](https://www8.garmin.com/xmlschemas/TrackPointExtensionv1.xsd) und [v2](https://www8.garmin.com/xmlschemas/TrackPointExtensionv2.xsd).
- Strava: [Export-Hilfe](https://support.strava.com/hc/en-us/articles/216918437-Exporting-your-Data-and-Bulk-Export) (GPX-Inhalt, „Export Original“, Sammelexport).
- Ride with GPS: [API, Track Points](https://ridewithgps.com/api/v1/doc/reference/track_points) (Felder, ≤ 1 Hz).
- Bosch: [Update der Flow-App 05/2023](https://www.bosch-ebike.com/au/news/update-for-the-ebike-flow-app-05/2023) (GPX- und FIT-Export).
- GPXSee: [`gpxparser.cpp`](https://github.com/tumic0/GPXSee/blob/master/src/data/gpxparser.cpp) (welche Elementnamen ein Parser in der Praxis liest).
- Drittquellen für Apple (WorkoutGPX/ObjectGraph), Garmin-Export (`garminexport`, Garmin-Forum), Wahoo (Ride-Import-Anleitung) und die genannten eBike-Apps wurden nur zur Orientierung gelesen und sind nicht verbindlich.
- Eigene Messungen: Dateien in `Tour1_*`, `Tour2_*`, `BMW_*` (Download-Ordner von Nils), Skripte lagen im Arbeitsordner der Sitzung und nicht im Repo; die Zahlen lassen sich mit den Fixtures grob wiederholen (Strecken um etwa 0,5 % kürzer, siehe oben).
