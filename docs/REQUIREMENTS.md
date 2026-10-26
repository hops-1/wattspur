# Requirements – Wattspur

Stand: 25.10.2026 · Status: Entwurf v0.14 (Plan für 1.5 bis 1.9; siehe Kap. 10.15 bis 10.18)

## 1. Ziel & Kontext

Wattspur ist eine Mac-App (später auch iOS), die die aus der **Bosch eBike Flow App** exportierten Fahrten (FIT, optional GPX) importiert, speichert und auswertet.

**Warum selbst bauen?** Es gibt Alternativen wie intervals.icu oder Golden Cheetah. Wattspur hat trotzdem drei eigene Gründe:
1. **Lernen und Spaß am Bauen:** Swift, SwiftUI und der Weg bis zur Veröffentlichung.
2. **eBike-spezifisch, vertraute Optik:** angelehnt an die Statistik-Ansichten der Flow-App, ohne Trainings-Fachbegriffe (FTP, TSS, CTL …).
3. **Flow+-Auswertungen ohne Abo**, aber **nur das, was die Exporte tatsächlich hergeben** (siehe Kap. 9).

**Zielgruppe:** zuerst ich, dann Freunde (DMG-Download). Eine Veröffentlichung auf GitHub oder im App Store ist ausdrücklich möglich und soll nicht verbaut werden.

Referenzmaterial im Repo:
- `docs/reference/bosch-flow-screenshots/`: Screenshots der Flow-App (Vorlage für das UI)
- `docs/reference/sample-data/`: Beispielfahrt „Reinheim Rundfahrt“ als FIT und GPX (nur lokal, **vor einer Veröffentlichung anonymisieren**, NFR-12)

## 2. Rahmenbedingungen (entschieden)

| Thema | Entscheidung |
|---|---|
| Plattform | **macOS 26 und neuer**; iOS/iPadOS später, Code von Anfang an multiplattformfähig |
| Technik | SwiftUI, Multiplatform-Target, gemeinsamer Kern als Swift Package `WattspurKit` |
| Designrichtung | **Mac-nativ mit Flow-Inhalten:** Aufbau wie eine Mac-App (Seitenleiste, Werkzeugleiste, Tabellen, aktuelles macOS-Design), Kennzahlen-Raster und Diagramme inhaltlich wie in der Flow-App |
| Vorgehen | Hobbyprojekt ohne Termin; kleine, jeweils nutzbare Releases v0.1 → v0.2 → v0.3 → v1.0 (siehe BACKLOG.md) |
| Zusammenarbeit | Claude implementiert und erklärt jede Story (Konzepte, Entscheidungen, Swift-Besonderheiten); ich reviewe, frage nach und gebe frei |
| Bibliothek | im App-Container (Standard für Mac-Apps, durch Time Machine gesichert); Umzug bzw. Sicherung über Backup-Funktion (IDEA-22) |
| Diagramme | Swift Charts |
| Karte | v1.0: **Apple MapKit**; OSM-Stile (Standard, CyclOSM, OpenTopoMap) erst in v1.x |
| Datenweg | iPhone: Flow-App → „In Dateien sichern“ → iCloud-Drive-Ordner (z. B. `Wattspur Import`); Mac: überwacht diesen Ordner. Zusätzlich Drag & Drop bzw. Dateidialog. Ab 1.9 optional: Bosch-Daten über die Data-Act-API (3.5) |
| Dateiformate | FIT (Pflicht), GPX (Import ab v1.6, Export seit v1.3) |
| Sprache | **Englisch als Standard, Deutsch wählbar** (folgt der Systemsprache), weitere Sprachen nachrüstbar über String Catalogs |
| Einheiten | metrisch (km, m, km/h, W, 1/min, kcal); imperiale Einheiten optional später |
| Verteilung | lokaler Build → **DMG** für Freunde (per Mail, GitHub Releases oder Website, wie bei bisherigen Projekten) → evtl. App Store. Zunächst **ohne Apple-Developer-Account** (ad-hoc signiert, nicht notarisiert) |

## 3. Datengrundlage

### 3.1 FIT (Hauptquelle), Erkenntnisse aus der Beispieldatei
- Nachrichten: `file_id`, `record` (ca. 2 pro Sekunde), `lap` (1), `session` (1), `activity` (1). Kein `device_info`, kein `event`, keine Developer-Felder.
- **Zwei getrennte `record`-Ströme**, die nur über den Zeitstempel zusammenhängen:
  - GPS: `timestamp`, `position_lat`, `position_long` (≈1 Hz)
  - Sensor: `timestamp`, `distance`, `speed`, `power`, `altitude`, `cadence` (cadence nur in ca. ⅓ der Zeilen)
- `session` liefert die offiziellen Summenwerte: `total_timer_time` (Fahrzeit), `total_elapsed_time` (inkl. Pausen), `total_distance`, `avg/max_speed`, `avg/max_power`, `avg/max_cadence`, `total_ascent/descent`, `sport` = 21 (E-Biking).
- `power` ist die **Tretleistung des Fahrers**. Motorleistung, Akkustand, Unterstützungsmodus und Reichweite sind **nicht** enthalten; auch die Bosch-Data-Act-API (ab 1.9, siehe 3.5) liefert sie je Fahrt nicht.
- Bekannte Fehler im Export:
  - `local_timestamp` ist UTC statt Ortszeit → Ortszeit über die Zeitzone der Startkoordinate bestimmen
  - `session.timestamp` = Startzeit statt Endzeit
  - Pausen stehen nicht als `event` in der Datei, sondern sind nur Lücken in den Zeitstempeln
- Mittelwerte für Leistung und Trittfrequenz rechnet Bosch **ohne Nullwerte** (Rollphasen); belegt durch die Nachrechnung: 135 W, 60 1/min.

### 3.2 GPX (eigene Quelle ab v1.6)
- Die Bosch-GPX aus der Flow-App enthält nur `trkpt` mit `lat`/`lon` (5 Nachkommastellen), `ele`, `time` und keine Extensions. Fremde GPX (komoot, Strava, Radcomputer) können zusätzlich Garmin-TrackPointExtension (`cad`, `hr`, `atemp`) und `<power>` enthalten.
- Wattspur liest GPX 1.0/1.1 mit diesen Erweiterungen; mehrere `trk`/`trkseg` einer Datei ergeben eine Fahrt mit Lücken (an verschiedenen Tagen getrennt). Routen (`rte`) und Wegpunkte werden nicht importiert.
- Summen einer GPX-Fahrt werden aus dem Track berechnet (Strecke, Fahrzeit mit Stillstandserkennung, Ø/Max-Geschwindigkeit, Anstieg aus geglätteten Höhen) und als „geschätzt“ gekennzeichnet. Die Originalpunkte bleiben erhalten; Leistung und Trittfrequenz bleiben leer, wenn die Datei sie nicht enthält. Puls und Temperatur werden gespeichert, aber noch nicht angezeigt (IDEA-27).

### 3.3 Datenregeln (entschieden)
| Regel | Festlegung |
|---|---|
| **Wahrheitsquelle für Summen** | Die `session`-Werte aus der FIT-Datei werden 1:1 übernommen (Fahrzeit, Strecke, Ø/Max-Werte, Anstieg/Abstieg), damit die Zahlen mit der Flow-App übereinstimmen |
| Selbst berechnet | nur, was in der Datei fehlt: Kalorien, CO₂, Pausenzeit, Arbeit (kJ), Min-/Max-Höhe, später Leistungskurve, Anstiege, Zonen |
| Trittfrequenz-Lücken | Diagramm: letzten Messwert bis zum nächsten halten. Statistiken und Zonen: nur echte Messpunkte |
| Zusammenführen der Ströme | eine 1-Hz-Zeitreihe; GPS und Sensor über den Zeitstempel zusammenführen |
| Kumulierte Durchschnitte | nach Fahrzeit gewichtet aus den Bosch-Ø-Werten je Fahrt |

### 3.4 Berechnungsformeln (Hypothesen, mit weiteren Fahrten prüfen: V-01)
| Wert | Hypothese |
|---|---|
| Kalorien | Mechanische Arbeit = Σ Leistung·Δt (320 kJ in der Beispielfahrt). Modus „aus Arbeit“ (Standard) bildet die Flow-App nach (V-01, sechs Fahrten mit Flow-Wert, Abweichung ≤ 4 kcal): kcal = kJ × 0,97 + 64 kcal je Stunde Fahrzeit; Flow kennt keine Körperdaten, der Zeitanteil ist ein fester Wert, Fahrzeit ohne Pausen. Der frühere Faktor 1,125 (Wirkungsgrad ≈ 21 %) lag bei langen, leistungsarmen Fahrten bis 7 % zu niedrig. Modus „mit Profil“ (v1.5, PROF-01): Arbeit × 0,956 (Wirkungsgrad 25 %) plus Grundumsatz über die Fahrzeit nach Mifflin-St Jeor aus Gewicht, Größe, Alter und Geschlecht (keine Angabe = Mittelwert beider Formeln); eigene Schätzung, weicht von Flow ab; fehlt eine Angabe, gilt „aus Arbeit“ |
| CO₂-Einsparung | 3,1 kg / 19,54 km ≈ 0,159 kg/km (Faktor gegenüber Autofahrt) |
| Pausenzeit | `total_elapsed_time − total_timer_time` |

### 3.5 Bosch-Daten aus der Data-Act-API (optional, ab 1.9)
Quelle: [RECHERCHE-BOSCH-DEVELOPER-PORTAL.md](RECHERCHE-BOSCH-DEVELOPER-PORTAL.md). Stand der Spezifikationen: 25.10.2026 (eBike Profile API und Activity Records API, jeweils v1.4.0, dazu Textseiten des Portals). Offen bis zum Spike V-12: die Bedingungen für Datenempfänger.
- **Was die offizielle Schnittstelle liefert:** je Bike Antrieb, Akkus (Ladezyklen am Bike und extern, abgegebene Energie), Kilometerstand, Betriebsstunden (gesamt und mit Motor), Radumfang, Modi mit Reichweite, fällige Wartung und Komponenten; je Fahrt Titel, Zeiten mit Zeitzone, Strecke, Kilometerstand zu Beginn, Geschwindigkeit, Trittfrequenz, Fahrerleistung, Anstieg und Abstieg, Kalorien, CO₂, Puls (Mittel, Maximum) und eine **Spur** mit Position, Strecke, Höhe, Geschwindigkeit, Trittfrequenz, Fahrerleistung und Puls, **ohne Zeitstempel je Punkt**. Es gibt nur Fahrten, die mit der Flow-App aufgezeichnet wurden; die Höhe nur mit Smartphone.
- **Was sie nicht liefert:** Unterstützungsmodi je Fahrt, Energieanteil von Fahrer und Motor, Motorleistung, Akkustand oder -verbrauch, Brems- und ABS-Ereignisse, Wetter. Die „Motordaten einer Strecke“, die der Anlass der Planung waren, gibt es in der offiziellen API nicht (Entscheidung Nils 25.10.2026: Option B, 1.9 heißt „Bosch-Daten“).
- **Regeln:** Die **FIT-Datei bleibt Wahrheitsquelle** für Summen und Zeitreihe (3.3); Rangfolge **FIT vor GPX vor Bosch**. Die Bosch-Fahrt wird einer vorhandenen Fahrt zugeordnet (Start, Strecke, Route wie IMP-04) und liefert Zusatzfelder. Liegt keine Fahrt vor, kann sie **neu angelegt** werden (MOT-13): Summen von Bosch, Zeitreihe aus der Spur mit geschätzter Zeit, gekennzeichnet „geschätzt“. Fehlt die Zuordnung oder der Abruf, bleiben Felder leer und werden mit „–“ gezeigt. Die Antwort wird als Original archiviert (wie IMP-07), damit sie ohne neuen Abruf neu ausgewertet werden kann. Werte von Bosch sind als „von Bosch abgerufen“ gekennzeichnet.
- **Service-Daten (Kann, MOT-15):** Das Digital Service Book liefert je Bike Inspektionen, Software-Updates, Akkumessungen (Kapazität, Gesundheit) und Händlerberichte mit **Strecke und Energie je Modus als Momentaufnahme**; nur nach Händlerbesuch oder Update.
- Geltungsbereich: Konten in der EU, Bikes mit Smart System, Freigabe je Bike im Bosch eBike Manager (Flow-Portal), eigener Client je Nutzer (10.18).

## 4. Funktionale Anforderungen

Priorität: **M** = Must bis **v1.0** (Freunde-Version; Aufteilung auf v0.1–v1.0 im Backlog) · **S** = Should, **v1.x** · **C** = Could, später.

**Umfang bis v1.0:** Import (inkl. iCloud-Ordner) · Statistik-Liste · Tour-Detail · Auswertung (Kumuliert & Trends).

### 4.1 Import (IMP)
| ID | Anforderung | Prio |
|---|---|---|
| IMP-01 | FIT-Dateien per Drag & Drop (Fenster/Dock-Icon) und per Dateidialog importieren, mehrere auf einmal | M |
| IMP-02 | Duplikate erkennen (Bosch-UUID im Dateinamen, sonst Startzeit + Distanz). Beim manuellen Import nachfragen: überspringen oder aktualisieren; im überwachten Ordner standardmäßig überspringen und im Protokoll vermerken. „Aktualisieren“ übernimmt die Bosch-Werte neu, behält aber lokale Änderungen (Name, Notizen) | M |
| IMP-03 | Tourname aus dem Dateinamen übernehmen, UUID abgetrennt (z. B. „Reinheim Rundfahrt“) | M |
| IMP-05 | Einen Ordner überwachen (Standard: iCloud-Drive-Ordner `Wattspur Import`) und neue Dateien automatisch importieren, auch beim App-Start. Danach Datei nach `Importiert/` verschieben, fehlerhafte nach `Fehlerhaft/`, damit gelöschte Fahrten nicht erneut importiert werden. Dateien eines nicht unterstützten Typs bleiben liegen und werden einmal im Protokoll vermerkt; GPX wird ab v1.6 wie FIT importiert (IMP-04). Überwachung nur bei geöffneter App | M |
| IMP-06 | Import-Protokoll: was importiert, übersprungen oder fehlerhaft war, mit verständlichem Grund | M |
| IMP-07 | Originaldateien unverändert in der App-Bibliothek archivieren, damit später neu ausgewertet werden kann | M |
| IMP-04 | GPX importieren (Drag & Drop, Dialog, überwachter Ordner), auch von anderen Bikes und Radcomputern, Details in 3.2. Beim manuellen Import fragt ein Sheet nach dem Bike, im Ordner gilt das aktive Bike. Dieselbe Tour als FIT und GPX: Start ±60 s, Strecke ±10 %, bestätigt über die vereinfachte Route. FIT schon da → GPX wird angehängt (Puls, Temperatur, Quelle), ohne Rückfrage; GPX schon da → beim Import der FIT nachfragen, im Ordner automatisch aktualisieren (Name, Notizen, Bike bleiben). Quellen-Symbol, „–“ bei fehlenden Werten, Hinweis „geschätzt“ und Filter nach Quelle | M |
| IMP-08 | Export einer Tour als Originaldatei (FIT/GPX) sowie CSV der Zeitreihe | C |
| IMP-09 | GPX-Export einer Fahrt aus der Ansicht „Fahrten“ (Tour-Detail und Kontextmenü), damit sie in komoot, Navigationsgeräten u. a. genutzt werden kann: Track mit Zeit, Höhe und Position (GPX 1.1), optional Leistung und Trittfrequenz als Erweiterung. Zusammengefügte Fahrten als ein Track mit einem Segment je Teil; bei der Beispielfahrt die verschobene Route. Wunsch von Nils, 21.10.2026 | S |

### 4.2 Statistiken – Home (LIST)
Vorlage: Screenshot `01-statistiken-liste`.
| ID | Anforderung | Prio |
|---|---|---|
| LIST-01 | Liste aller Fahrten, neueste zuerst: Name, Fahrzeit, Strecke, Ø Geschw., Datum/Uhrzeit (relativ: „Gestern, 14:12“) | M |
| LIST-03 | Kopfzeile „N Fahrten insgesamt“ | M |
| LIST-05 | Suche nach Name; Sortierung (Datum, Strecke, Dauer, Höhenmeter, Ø Leistung); Filter nach Zeitraum | M |
| LIST-06 | Mehrfachauswahl von Fahrten → Auswertung für diese Fahrten | M |
| LIST-07 | Fahrt umbenennen; löschen verschiebt in den Papierkorb und ist per ⌘Z rückgängig zu machen | M |
| LIST-08 | Papierkorb: gelöschte Fahrten 30 Tage wiederherstellbar, danach endgültig samt Originaldatei entfernt; „Papierkorb leeren“ mit Bestätigung | M |
| LIST-02 | Vorschaubild der Route je Fahrt | S |
| LIST-04 | Jahreskachel „Dein Jahr“: km im laufenden Jahr, Klick öffnet den Jahresrückblick (ADV-J1) | S |
| LIST-09 | Fahrten zusammenfassen: zwei oder mehr aufeinanderfolgende Fahrten per Mehrfachauswahl und Befehl „Fahrten zusammenfassen“ zu **einer** neuen Fahrt vereinen. Summen (Strecke, Fahrzeit, Anstieg/Abstieg, Arbeit) addiert, Ø-Werte nach Fahrzeit gewichtet, Max-Werte als Maximum; Karte und Diagramme durchgehend, die Lücke als Unterbrechung. Lücke am selben Tag zählt als Pause (Gesamtdauer, Pausenzeit); bei Teilen an verschiedenen Tagen zählen nur die Fahrzeiten. Die Originalfahrten verschwinden aus Liste und Auswertung, bleiben samt Originaldateien gespeichert; „Zusammenfassung aufheben“ stellt sie wieder her, ⌘Z macht das Zusammenfassen rückgängig. Name zunächst der der ersten Fahrt, umbenennbar | S |
| LIST-10 | Vorschlag zum Zusammenfassen: Die App erkennt Kandidaten (gleicher Tag, Lücke unter einem einstellbaren Wert, z. B. 60 min, Ende der einen nahe am Start der nächsten) und zeigt einen Hinweis; zusammengefasst wird erst nach Bestätigung | S |

### 4.3 Tour-Detail (TOUR)
Vorlage: Screenshots `02-…` bis `04-…`.
| ID | Anforderung | Prio |
|---|---|---|
| TOUR-01 | Karte (MapKit) mit Route, Start- und Zielmarkierung; Kartentyp Standard, Satellit oder Hybrid | M |
| TOUR-02 | Titel, Datum und Startzeit (Ortszeit) | M |
| TOUR-03 | Kennzahlen-Raster: Fahrzeit, Strecke, Ø Geschw., Anstieg, Ø Leistung, Ø Trittfreq., Kalorien, CO₂-Einsparung. Geschätzte Werte (Kalorien, CO₂) dezent mit Info-Symbol und Erklärung kennzeichnen | M |
| TOUR-04 | Diagramme über die Strecke (x-Achse km): Höhe (mit Anstieg/Abstieg), Geschwindigkeit, Trittfrequenz, Leistung (je mit Max und Ø). Auf dem Mac untereinander statt als Karussell | M |
| TOUR-05 | Zusätzliche Kennzahlen: Gesamtdauer inkl. Pausen, Pausenzeit, Abstieg, Max-Geschw., Max-Leistung, Max-Trittfreq., Arbeit (kJ), Min-/Max-Höhe | M |
| TOUR-09 | Menü: Umbenennen, Originaldatei im Finder zeigen bzw. exportieren, Fahrt entfernen | M |
| TOUR-06 | Diagramm und Karte gekoppelt: Hover im Diagramm zeigt die Position auf der Karte und einen Strich in allen Diagrammen, Hover auf der Route ebenso; Klick hält die Position fest | S |
| TOUR-07 | Umschalter für die x-Achse: Strecke oder Zeit (Fahrzeit ab Start); gilt für alle Diagramme des Tour-Details und wird gemerkt; die Kopplung aus TOUR-06 funktioniert auf beiden Achsen | S |
| TOUR-08 | Route auf der Karte nach Messwert einfärben. Auswahl über ein Menü auf der Karte neben dem Kartentyp: Einfarbig (Standard), Höhe, Geschwindigkeit, Trittfrequenz, Leistung, Steigung. Mehrstufige Farbskala Blau → Türkis → Gelb → Orange → Rot, bezogen auf Min/Max der jeweiligen Fahrt (Steigung: bergab blau, bergauf rot); Legende mit Min- und Max-Wert auf der Karte, damit die Farbe nie die einzige Information ist (NFR-16). Stellen ohne Messwert (z. B. Trittfrequenz 0 beim Rollen, Pausen) grau. Mit der Maus über der Spur zeigt ein Etikett den Wert an dieser Stelle. Die zuletzt gewählte Einfärbung gilt auch für die nächste geöffnete Fahrt | S |
| TOUR-10 | Notizen und Tags (z. B. „Pendeln“, „Freizeit“) je Tour | C |
| TOUR-11 | Diagramme in kompakten Fenstern bzw. auf dem iPhone als wischbares Karussell (eine Kennzahl je Seite, Seitenpunkte wie in der Flow-App); in großen Mac-Fenstern untereinander. Umschaltung automatisch nach verfügbarer Breite/Höhe | S |
| TOUR-12 | In Diagramme hineinzoomen: Bereich aufziehen (Mac) bzw. Pinch (iOS), zurück per Doppelklick; die Kennzahlen zeigen dann Max/Ø für den gewählten Abschnitt, die Karte hebt ihn hervor | S |
| TOUR-13 | Anpassbare Tour-Ansicht: jeder Abschnitt (Karte, Kennzahlen, Details, einzelne Diagramme) einklappbar; Reihenfolge per Drag & Drop änderbar, Abschnitte ein- und ausblendbar; Layout wird gespeichert und lässt sich zurücksetzen | S |

### 4.4 Auswertung – Kumulierte Daten (AGG)
Kumuliert und Trends bilden **einen** Bereich „Auswertung“ mit gemeinsamer Zeitraum-Auswahl oben; darunter Summen, Balkendiagramm und Trendverläufe.
| ID | Anforderung | Prio |
|---|---|---|
| AGG-01 | Summen über alle oder ausgewählte Fahrten bzw. einen Zeitraum: Anzahl, Strecke, Fahrzeit, Höhenmeter, Arbeit, Kalorien, CO₂ | M |
| AGG-02 | Nach Fahrzeit gewichtete Durchschnitte: Geschw., Leistung, Trittfrequenz; dazu Mittelwerte je Fahrt (Ø Strecke, Ø Dauer) | M |
| AGG-03 | Zeitraum-Auswahl: Woche, Monat, Jahr, frei, alles | M |
| AGG-04 | Balkendiagramm Strecke, Zeit oder Höhenmeter je Woche, Monat oder Jahr | M |
| AGG-05 | Eigener Bereich „Karte“ in der Seitenleiste: alle Fahrten auf einer Karte, gefiltert nach Zeitraum (wie in der Auswertung), nach den in der Liste markierten Fahrten und später nach Bike bzw. Fahrer | S |
| AGG-06 | Unter der Karte aller Fahrten Summen der Fahrten im sichtbaren Kartenausschnitt: Fahrten, Strecke, Fahrzeit, Anstieg, Ø Geschwindigkeit; ganze Fahrten mit ihren Bosch-Summen; Sprung in die Auswertung für diese Fahrten | S |

### 4.5 Auswertung – Trends & Vergleich (TREND)
| ID | Anforderung | Prio |
|---|---|---|
| TREND-01 | Verlauf je Fahrt über die Zeit: Ø Leistung, Ø Trittfreq., Ø Geschw., Strecke, Höhenmeter (Punkte + gleitender Durchschnitt) | M |
| TREND-02 | Aggregation je Woche oder Monat, inkl. Veränderung zum Vorzeitraum (± %) | M |
| TREND-03 | 2–4 Fahrten direkt vergleichen → ausgearbeitet in Kap. 4.5a (CMP) | S |
| TREND-04 | Gleiche Strecke wiedererkennen und Fahrten darauf vergleichen → ausgearbeitet in Kap. 4.5b (ROUTE) | S |
| TREND-05 | Streudiagramme, z. B. Leistung über Geschwindigkeit | C |

### 4.5a Tourenvergleich (CMP)
Quelle: Feature-Wunsch eines Testers (21.10.2026): „Tourenvergleich, z. B. Kalorien, Durchschnittsgeschwindigkeit, Höhenmeter …“. Verfeinert mit Nils am 21.10.2026. Nächstes v1.x-Feature.
| ID | Anforderung | Prio |
|---|---|---|
| CMP-01 | Einstieg: 2–4 Fahrten in der Liste markieren (⌘-Klick), dann Knopf „Vergleichen“ (neben „Auswertung“ für die Auswahl). Bei 1 oder mehr als 4 Fahrten ist der Knopf deaktiviert, mit Hinweis | S |
| CMP-02 | Vergleichstabelle: eine Spalte je Fahrt (Name, Datum), eine Zeile je Kennzahl: alle Werte aus dem Tour-Detail (Fahrzeit, Gesamtdauer, Pausen, Strecke, Ø/Max Geschw., Anstieg, Abstieg, Ø/Max Leistung, Ø/Max Trittfrequenz, Arbeit, Kalorien, CO₂, Min/Max-Höhe). Der beste Wert je Zeile ist hervorgehoben (nicht nur über Farbe, NFR-16); „besser“ je Kennzahl festgelegt (z. B. mehr Ø Geschw. = besser, weniger Pausen = besser; neutral bei Strecke, Fahrzeit) | S |
| CMP-03 | Abgeleitete Werte für unterschiedlich lange Touren: Kalorien pro km, Anstieg pro km (m/km), Arbeit pro km, Rollanteil (Anteil der Zeit ohne Tretleistung), Ø Leistung pro Fahrzeit | S |
| CMP-04 | Abweichung vom eigenen Schnitt: zu jedem Wert die Differenz zum Durchschnitt aller Fahrten (± und %), wahlweise ein- und ausblendbar | S |
| CMP-05 | Diagramme übereinandergelegt: Höhe, Geschwindigkeit, Trittfrequenz und Leistung, je Fahrt eine Linie in eigener Farbe mit Legende, x-Achse Strecke (später umschaltbar auf Zeit, TOUR-07); Farben auch für Farbfehlsichtige unterscheidbar | S |
| CMP-06 | Aus dem Vergleich eine Fahrt öffnen, entfernen oder eine weitere hinzufügen (bis 4) | C |
| CMP-07 | Vergleich als PDF exportieren (A4: Karte und Diagramme, dann Tabelle; Knopf oben links öffnet es in Vorschau, wahlweise sichern); als Bild später mit IDEA-20 | S |
| CMP-08 | Karte über den Diagrammen mit allen verglichenen Routen in den Farben und Stricharten der Spalten; über jedem Diagramm die Ø-Werte je Fahrt, bei der Höhe Anstieg, Abstieg und steilste Stelle | S |

### 4.5b Ähnliche Strecken (ROUTE)
Quelle: Wunsch von Nils (22.10.2026): „In der Fahrtenliste gleiche bzw. ähnliche Strecken suchen und filtern, um sie zu vergleichen, z. B. meine Pendelstrecke zwischen Zuhause und Arbeit.“ Verfeinert am 22.10.2026. Geplant für v1.7.
| ID | Anforderung | Prio |
|---|---|---|
| ROUTE-01 | Ähnlichkeit zweier Fahrten: Anteil der Route, der höchstens 50 m von der anderen Route entfernt liegt, **in beide Richtungen** geprüft (der kleinere Wert zählt), damit eine kurze Fahrt nicht als „ähnlich“ zu einer langen gilt, die sie nur enthält. Grundlage sind die vereinfachten Routen aus B-104. Die Richtung zählt: Gleiche Strecke heißt gleiche Fahrtrichtung (Start- und Zielbereich passen zueinander) | S |
| ROUTE-02 | Schwellwert: Standard ≥ 90 % (am 26.10.2026 von 95 % gesenkt: an echten Pendelstrecken findet 90 % mehr und der Regler steht in der Mitte), per Regler zwischen 80 % und 99 % einstellbar (in der Ansicht und in den Einstellungen als Standard) | S |
| ROUTE-03 | „Ähnliche Fahrten zeigen“: Rechtsklick auf eine Fahrt (und im Tour-Detail) filtert die Liste auf ähnliche Fahrten, sortiert nach Ähnlichkeit (in % je Zeile). Ein Chip „Ähnlich wie: ‹Name› (n) ✕“ zeigt den Filter wie beim Zeitraum; ✕ hebt ihn auf | S |
| ROUTE-04 | Schalter „Auch Gegenrichtung“: nimmt Fahrten auf derselben Strecke in umgekehrter Richtung dazu (z. B. Rückweg von der Arbeit), in der Liste mit Richtungs-Symbol gekennzeichnet | S |
| ROUTE-05 | Aus den Treffern 2–4 Fahrten markieren und im bestehenden Tourenvergleich (CMP) öffnen | S |
| ROUTE-06 | Verlauf über alle Treffer: je Fahrt Fahrzeit, Ø Geschwindigkeit, Ø Leistung und Ø Trittfrequenz über die Zeit (Punkte + gleitendes Mittel, wie TREND-01), Bestzeit und letzte Fahrt markiert, Veränderung zum Durchschnitt der Strecke | S |
| ROUTE-07 | Strecken automatisch gruppieren: Wattspur erkennt wiederkehrende Strecken (mindestens 3 ähnliche Fahrten) und bietet sie als Gruppe an; Gruppen lassen sich benennen („Pendeln“, „Runde Reinheim“), umbenennen, auflösen; neue Fahrten werden beim Import zugeordnet. Ersetzt IDEA-10 (Lieblingsrunden) und ist Grundlage für die Pendel-Statistik IDEA-03 | S |
| ROUTE-08 | Berechnung im Hintergrund, ohne die Oberfläche zu blockieren; Ergebnisse werden zwischengespeichert und bei neuen oder geänderten Fahrten aktualisiert. Ziel: „Ähnliche Fahrten zeigen“ in unter 1 s bei 1 000 Fahrten | S |

### 4.6 Erweiterte Analysen (ADV), Flow+-ähnlich, alle v1.x
| ID | Anforderung | Prio |
|---|---|---|
| ADV-J1 | Jahresrückblick: km, Fahrten, Zeit, Höhenmeter, CO₂, Rekorde des Jahres, Monatsdiagramm, Kalender-Heatmap der Fahrtage | S |
| ADV-R1 | Rekorde: längste Fahrt, längste Dauer, meiste Höhenmeter, höchste Ø-Geschw., höchste Ø-Leistung, längste Serie an Fahrtagen | S |
| ADV-R2 | Hinweis „Neuer Rekord“ beim Import; Rekorde in der Tour-Ansicht markieren | S |
| ADV-R3 | Weitere Rekorde (Wunsch 22.10.2026): höchste Leistung (Bosch-Maximum, Sekundenwert wie in der Flow-App), höchste Trittfrequenz (Bosch-Maximum), höchste Geschwindigkeit, beste 1-Minuten-Leistung (höchste über 60 s gehaltene Durchschnittsleistung, aus der Zeitreihe; Vorgriff auf ADV-L1). Wie bei den bestehenden Rekorden zählen Beispielfahrt und Papierkorb nicht; ohne Mindeststrecke, da es Spitzenwerte sind; „Neuer Rekord“ (ADV-R2) gilt auch für sie | S |
| ADV-Z1 | Ziele je Woche, Monat oder Jahr (km, Fahrten, Höhenmeter) mit Fortschrittsanzeige | S |
| ADV-L1 | Leistungskurve je Fahrt und über alle Fahrten: beste Durchschnittsleistung über 5 s, 30 s, 1, 5, 20 und 60 min | S |
| ADV-L2 | Verteilung der Leistung und Trittfrequenz in Zonen (Zeit je Zone); Zonen konfigurierbar | S |
| ADV-L3 | Rollanteil: Anteil der Fahrzeit ohne Tretleistung | S |
| ADV-A1 | Anstiege automatisch erkennen: Länge, Höhenmeter, Ø- und Max-Steigung, Dauer, Ø Leistung | S |
| ADV-A2 | Steigungsverlauf im Höhenprofil einfärben; Verteilung der Steigungen | S |

### 4.7 Karten (MAP)
| ID | Anforderung | Prio |
|---|---|---|
| MAP-01 | Apple MapKit mit Standard, Satellit und Hybrid | M |
| MAP-02 | OSM-Stile Standard, CyclOSM und OpenTopoMap über eine austauschbare Kartenquelle; Nutzungsbedingungen und ggf. kommerziellen Anbieter vorher klären (V-04) | S |
| MAP-03 | Kacheln für bereits angesehene Touren offline zwischenspeichern | C |
| MAP-04 | Heatmap über der Karte aller Fahrten, umschaltbar: (a) Linien wie bei komoot – jede Strecke halbtransparent, oft gefahrene Wege werden zu kräftigen Bändern; (b) flächige Wärmekarte (Dichte, blau → rot) für Gebiete, in denen viel gefahren wird. Mit Legende; Farbe nie allein (NFR-16) | S |
| MAP-05 | Klick auf eine Strecke in der Karte aller Fahrten zeigt ein Popover mit den Fahrten, die dort verlaufen; ein Klick hebt die Fahrt auf der Karte hervor und zeigt ein Infofeld, von dem aus sie sich im Tour-Detail öffnen lässt | S |

### 4.8 Einstellungen (SET)
| ID | Anforderung | Prio |
|---|---|---|
| SET-01 | Standard-Kartentyp | M |
| SET-02 | Überwachter Import-Ordner: an/aus und Ordner wählen | M |
| SET-07 | Sprache folgt dem System (Englisch/Deutsch); Hinweis auf die macOS-Spracheinstellung je App | M |
| SET-03 | Faktoren für Kalorien und CO₂ einstellbar, mit Standardwerten aus 3.4 | S |
| SET-06 | Kalorienmodus: „aus Arbeit“ (Standard) oder „mit Profil“ (Arbeit plus Grundumsatz, siehe 3.4); fehlen Körperdaten, Rückfall auf „aus Arbeit“ mit Hinweis | M |
| SET-05 | Leistungs- und Trittfrequenz-Zonen | S |
| SET-04 | Glättung der Höhendaten | C |

### 4.9 Fahrer, Bikes & Quellen (PROF)
| ID | Anforderung | Prio |
|---|---|---|
| PROF-01 | Fahrerprofil im Bereich „Profil“ (Name, Avatar, Gewicht, Größe, Geburtsjahr, Geschlecht) für die Kalorienberechnung mit Profil; alle Körperdaten optional | M |
| PROF-02 | Mehrere Fahrer mit getrennten Statistiken; Fahrer beim Import zuordnen | C |
| PROF-03 | Mehrere Bikes je Profil (v1.5): Name, Farbe, Art (Fahrrad, Mountainbike, Rennrad, Gravelbike), E-Bike, Foto, Hersteller, Modell, Antrieb, Akku, Gewicht (Info), Kaufdatum, km-Startwert; ein aktives Bike für neue Importe, nachträgliches Zuweisen einzeln und per Mehrfachauswahl; Filter nach Bike je Bereich; Archivieren statt Löschen. Eine automatische Zuordnung über die Seriennummer ist mit Bosch-Exporten nicht möglich: `file_id.serial_number` ändert sich bei jedem Export, eine andere Bike-Kennung gibt es nicht (siehe SPIKE-FIT-PARSER.md) | C |
| PROF-04 | Weitere Importquellen: Apple Health (zuerst), Strava, generische FIT-Dateien | C |

### 4.10 Benutzerkonto (ACC)
Ein Konto ist zunächst **rein lokal**: ein Profil ohne Passwort und ohne Server. Es ist dieselbe Entität wie der `Rider` aus Kap. 7, kein zusätzliches Konzept. Ein Serverkonto kommt erst, wenn es einen konkreten Zweck gibt (Sync, Teilen, Backup).
| ID | Anforderung | Prio |
|---|---|---|
| ACC-01 | Lokales Benutzerprofil: wird beim ersten Start angelegt (Name, optional Avatar); alle Fahrten gehören zu diesem Profil. Kein Passwort, da der macOS-Benutzer die Daten bereits schützt | M |
| ACC-02 | Mehrere lokale Profile auf einem Rechner mit Profilwechsel (gemeinsam mit PROF-02) | C |
| ACC-03 | Optionale App-Sperre per Touch ID oder Passwort beim Öffnen | C |
| ACC-04 | Serverkonto (z. B. „Mit Apple anmelden“) für Sync, Backup oder Teilen; lokales Profil ohne Datenverlust übernehmen. Setzt ein Backend, eine Datenschutzerklärung und ggf. eine Löschfunktion nach DSGVO voraus | C |
| ACC-05 | Profil-Daten exportieren und löschen (alle Fahrten und Einstellungen) | S |

### 4.11 Nutzer-Dokumentation (DOC)
| ID | Anforderung | Prio |
|---|---|---|
| DOC-01 | Benutzerhandbuch auf GitHub (Markdown unter `docs/user-guide/`), Englisch und Deutsch: Installation, erster Start, Import, Ansichten | M |
| DOC-02 | Anleitung „Fahrten aus der Bosch Flow App exportieren“ mit Screenshots (iPhone → Dateien → iCloud-Ordner) | M |
| DOC-03 | Erklärung der Kennzahlen: woher jeder Wert stammt (Bosch-Summe oder eigene Berechnung) und mit welcher Formel (Kalorien, CO₂, Pausen) | S |
| DOC-04 | Versionshinweise (`CHANGELOG.md`) je Release bzw. DMG | M |
| DOC-05 | FAQ und Fehlerbehebung (z. B. „Import schlägt fehl“, „Werte weichen von der Flow-App ab“) | S |
| DOC-06 | Hilfe in der App: Menü „Hilfe“ öffnet das Handbuch online; Hinweise an leeren Ansichten („Noch keine Fahrten – so importierst du“) | S |
| DOC-07 | Projekt-Website, z. B. über GitHub Pages, aus denselben Markdown-Quellen erzeugt | C |

### 4.13 Erststart & Support (ONB/SUP)
| ID | Anforderung | Prio |
|---|---|---|
| ONB-01 | Einrichtungsassistent beim ersten Start: Profilname (ACC-01), erstes Bike mit Name und Farbe (ab v1.5), Import-Ordner wählen (IMP-05), kurzer Hinweis zum Export aus der Flow-App | M |
| ONB-02 | Optional eine anonymisierte Beispielfahrt laden, um die App auszuprobieren; mit einem Klick entfernbar; zählt nicht in Statistiken, solange sie als Beispiel markiert ist | M |
| ONB-03 | Leere Ansichten mit Hinweis und Aktion („Fahrt importieren“) | M |
| SUP-01 | Menübefehl „Diagnose erstellen“: Import-Protokoll, App- und Parser-Version, macOS-Version als Datei; optional die fehlerhafte FIT-Datei beilegen. Nichts wird automatisch gesendet | M |
| SUP-02 | Hilfe-Menü: „Feedback senden“ öffnet eine vorbereitete Mail mit angehängter Diagnose | S |

### 4.14 Bosch-Daten (MOT)
Quelle: Wunsch von Nils (25.10.2026), Vorbild die App „EBikeData“. Geplant für v1.9 („Bosch-Daten“, Option B), unter dem Vorbehalt des Spikes V-12. Alles ist **optional**: ohne Bosch-Konto, ohne Smart-System-Bike oder ohne Netz verhält sich Wattspur wie bisher. Entscheidungen in Kap. 10.18, Hintergrund in 3.5.
| ID | Anforderung | Prio |
|---|---|---|
| MOT-01 | Reiter „Bosch-Konto“ in den Einstellungen: Client-ID eintragen, „Mit Bosch anmelden“ (OAuth 2.0 im Systembrowser, SingleKey ID; Wattspur sieht nie das Passwort), Status (angemeldet, Freigabe fehlt, nicht bei Bosch eBike Systems angemeldet, Fehler), „Abmelden“ | S |
| MOT-02 | Eigener Client je Nutzer: Wattspur enthält keine Client-ID und kein Geheimnis; das Handbuch erklärt die Registrierung als Datenempfänger im Data-Act-Portal (öffentlicher Client, Redirect mit eigenem Schema, nach V-12), die Wartezeit auf die Freigabe durch Bosch und die Freigabe je Bike im Bosch eBike Manager | S |
| MOT-03 | Abruf nach jedem Import (manuell, Drag & Drop, überwachter Ordner, nur bei geöffneter App) im Hintergrund, dazu Knopf „Bosch-Daten abrufen“ im Tour-Detail und in den Einstellungen; Fahrten, die Bosch noch nicht hat, werden beim nächsten Mal wieder versucht; neue Fahrten bei Bosch werden angezeigt (MOT-13) | S |
| MOT-04 | Altbestand: nach der ersten Anmeldung einmaliges Angebot „N Fahrten bei Bosch abgleichen, M davon neu importieren“ mit Fortschritt, gedrosselt (Seiten zu höchstens 100 über die mitgelieferten Links), abbrechbar und fortsetzbar; vorhandene Fahrten werden angereichert, neue nach Bestätigung angelegt (MOT-13); was Bosch nicht mehr hat, bleibt unberührt | S |
| MOT-05 | Zuordnung der Bosch-Fahrt zur Fahrt in Wattspur über Start (die Zeitzone liefert die API als `timeZone` mit), Strecke und Route (wie IMP-04), wenn möglich zusätzlich über den Kilometerstand zu Beginn (`startOdometer`, Prüfung im Spike); Fahrten, die nur bei Bosch liegen, werden **zum Anlegen angeboten** (MOT-13); zusammengefügte Fahrten nehmen die Daten ihrer Teile; die Bike-Kennung der API wird je Bike einmal manuell einem Wattspur-Bike zugeordnet | S |
| MOT-06 | Speicherung: Original der Antwort unverändert als externe Daten, Felder an `Ride` bzw. `Bike`, Kennung der Bosch-Fahrt (`boschActivityId`) an `Ride`, Quelle „bosch“, CloudKit-fähig, Neu-Auswertung nach einem Update ohne neuen Abruf (NFR-17) | S |
| MOT-07 | **Entfällt (25.10.2026):** Abschnitt „Unterstützung“ mit Modi und Energieanteil im Tour-Detail; die offizielle API liefert beides nicht | – |
| MOT-08 | **Entfällt (25.10.2026):** Modus-Anteile und Energieanteil in Auswertung, Vergleich und Jahresrückblick; gleiche Begründung | – |
| MOT-09 | Akku und Antrieb je Bike im Bereich „Profil“: Ladezyklen (am Bike und extern), abgegebene Energie, Antrieb, Kilometerstand, Betriebsstunden (gesamt und mit Motor), Radumfang, Modi mit Reichweite, fällige Wartung (`serviceDue`: Datum und Kilometerstand), Komponenten (Antrieb, Akkus, Bedieneinheit, soweit vorhanden Display, ABS, ConnectModule); die Akkukapazität steht nicht in der Antwort und kommt aus dem Modellnamen oder manuell; Seriennummern werden nicht übernommen | S |
| MOT-10 | **Entfällt (25.10.2026):** Verläufe von Motorleistung und Akku; die API hat keine Zeitreihe dafür und keinen Zeitstempel je Punkt | – |
| MOT-11 | Fehlerverhalten (Fehler kommen als Problem-Objekt mit `requestId`, die das Import-Protokoll mitschreibt; bei 401 und 403 kann auch reiner Text kommen): Beim automatischen Abruf leise (Statuszeile in den Einstellungen und Eintrag im Import-Protokoll, kein Dialog); bei Knopfdruck ein Dialog mit Anleitung (Freigabe fehlt, Client nicht freigegeben, Bike nicht freigegeben, Zustimmung bei Bosch widerrufen, nicht bei Bosch eBike Systems angemeldet, zu viele Anfragen, Konto außerhalb der EU, kein Netz). Ohne Konto und ohne Netz bleibt alles andere unverändert | S |
| MOT-12 | Datenschutz: Tokens nur im Schlüsselbund; „Abmelden“ löscht sie und fragt, ob die abgerufenen Daten (auch angelegte Fahrten) bleiben oder entfernt werden; Hinweis im Info-Fenster und im Handbuch, was abgerufen wird und dass es nur zwischen Mac und Bosch läuft; keine Telemetrie | S |
| MOT-13 | **Fahrten ohne Datei importieren** (Entscheidung Nils 25.10.2026, Option B): Fahrten, die nur bei Bosch liegen, als Fahrt mit Quelle „bosch“ anlegen. Summen aus der Zusammenfassung (von Bosch), Zeitreihe aus der Spur mit **geschätzter Zeit je Punkt** (aus Strecke und Geschwindigkeit, Summe gleich der Fahrzeit), gekennzeichnet „geschätzt“; Höhe, Geschwindigkeit, Trittfrequenz, Fahrerleistung und Puls, soweit vorhanden. Vor dem Anlegen Duplikatprüfung (MOT-05). **Anlegen nach Bestätigung** (Altbestand: Angebot, laufend: Hinweis „N neue Fahrten bei Bosch“ mit Knopf), Einstellung „Neue Fahrten automatisch anlegen“ (Standard aus); gelöschte Fahrten werden über `boschActivityId` nicht erneut angeboten. Rangfolge FIT vor GPX vor Bosch: Kommt später eine passende Datei, **ersetzt** sie die Bosch-Fahrt, Titel, Notizen und Bike bleiben. Export wie bei GPX-Fahrten (geschätzte Zeiten gekennzeichnet) | S |
| MOT-14 | Tour-Detail: Abschnitt „Von Bosch“ mit Titel, Kilometerstand zu Beginn, Kalorien und CO₂ von Bosch neben den eigenen Werten, Puls (Mittel, Maximum), gekennzeichnet „von Bosch abgerufen“; ohne Abruf ein Knopf statt leerer Fläche; bei Fahrten aus Bosch-Daten Hinweis „Zeit je Punkt geschätzt“ und bevorzugt die Strecke als x-Achse; Zeile im PDF der Fahrt; nicht im GPX-Export | S |
| MOT-15 | **Kann, entschieden mit Nils am 25.10.2026; nur wenn V-12 echte Einträge für sein Bike zeigt:** Bereich „Verlauf und Service“ im Profil aus dem Digital Service Book: Wartungen und Inspektionen (Datum, Händler, Kilometerstand), Software-Updates (Komponenten, Versionen), Akkumessung (gemessene und Nennkapazität, Gesundheit in Prozent), nächste Wartung nach Tagen und Metern, Modus-Statistik (Strecke und Energie je Modus) als Momentaufnahme je Händlerbesuch; kein Händlername in Diagnose und Export; ohne Einträge ein Hinweis statt leerer Fläche | C |

### 4.12 Ideen-Pool (noch nicht priorisiert)
Gesammelte Feature-Ideen, über deren Umsetzung und Release später entschieden wird. „?“ = noch nicht priorisiert.
| ID | Idee | Datenbasis | Prio |
|---|---|---|---|
| IDEA-01 | Fahrtzeit über 25 km/h: Dauer, Strecke und Anteil oberhalb der Unterstützungsgrenze, also aus eigener Kraft; je Tour und als Trend | Geschwindigkeit | ? |
| IDEA-02 | Wartungszähler je Bike: km seit Kettenwechsel, Bremsbelägen, Reifen, Inspektion; Schwellen und Erinnerungen; Wartungshistorie | Strecke je Bike | ? |
| IDEA-03 | Pendel-Statistik: wiederkehrende Start/Ziel-Paare automatisch als „Pendeln“ erkennen; km, Anzahl, Anteil (baut auf ROUTE-07 auf) | GPS, Uhrzeit | ? |
| IDEA-04 | Kostenersparnis gegenüber Auto bzw. ÖPNV (€/km einstellbar), ergänzend zum CO₂-Wert | Strecke | ? |
| IDEA-05 | Tour bearbeiten: Ende bzw. Anfang abschneiden, Tour teilen, zwei Fahrten zusammenführen; Summen danach neu berechnen (Ausnahme zur Bosch-Wahrheitsquelle, Kap. 3.3) | Zeitreihe | ? |
| IDEA-06 | Widgets (macOS/iOS): km der Woche, Fortschritt zum Ziel, letzte Fahrt | – | ? |
| IDEA-07 | Kurzbefehle / App Intents: Fahrt aus der Flow-App mit einem Tipp in den Import-Ordner legen; Abfragen wie „km diesen Monat“ per Siri | – | ? |
| IDEA-08 | Geschätzter Motoranteil: Gesamtleistung aus Fahrphysik (Geschwindigkeit, Steigung, Gewicht, Roll- und Luftwiderstand) minus Tretleistung; klar als Schätzung gekennzeichnet; **von v1.9 nicht berührt**, weil die offizielle Bosch-API keinen Energieanteil und keine Motorleistung liefert (Spezifikation 25.10.2026) | Zeitreihe + Gewicht | ? |
| IDEA-09 | Trittfrequenz-Hinweise: Anteil im effizienten Bereich (z. B. 70–90 1/min), Tipps bei dauerhaft niedriger Trittfrequenz | Trittfrequenz | ? |
| IDEA-10 | Lieblingsrunden: gleiche Strecken gruppieren, Bestzeit und Verlauf je Runde (baut auf TREND-04 auf) → aufgegangen in ROUTE-07 | GPS | ? |
| IDEA-11 | Eigene Segmente: Abschnitt markieren und auf allen Fahrten darüber Zeit und Leistung automatisch vergleichen | GPS, Zeitreihe | ? |
| IDEA-12 | Mein Fahrgebiet: Heatmap aller Fahrten, Anteil neuer Wege je Tour, besuchte Orte/Gemeinden | GPS | ? |
| IDEA-13 | Wetter nachträglich (z. B. Open-Meteo, ohne API-Key): Temperatur, Wind, Regen je Tour; Wind im Vergleich zur Geschwindigkeit | Online-Abfrage | ? |
| IDEA-14 | Abzeichen und Meilensteine: erste 100 km, 1 000 km im Jahr, Everesting (8 848 hm insgesamt), Serien | Summen | ? |
| IDEA-15 | Weltreise-Fortschritt: Gesamtstrecke als Anteil am Erdumfang bzw. als virtuelle Strecke (z. B. Darmstadt → Rom) | Summen | ? |
| IDEA-16 | Wochen- bzw. Monatsrückblick als Mitteilung oder Kachel inkl. Veränderung zum Vorzeitraum | Summen | ? |
| IDEA-17 | Fotos zur Tour: Fotos aus Apple Fotos über Zeit und Ort zuordnen und auf der Karte zeigen | PhotoKit | ? |
| IDEA-18 | Tour als Bild teilen: Karte und Kennzahlen als Grafik; dafür Privatzonen um Wohnort bzw. Ziele wieder aufgreifen (Kap. 9) | – | ? |
| IDEA-19 | PDF-Jahresbericht aus dem Jahresrückblick | Summen | ? |
| IDEA-20 | PDF-Tourbericht: Karte, Kennzahlen, alle Diagramme, ggf. Anstiege und Notizen einer Tour als druckbares PDF. Grundform in v1.2 (Knopf oben links im Tour-Detail) | Tour | ? |
| IDEA-21 | Spotlight-Suche: Fahrten über die Mac-Suche finden | – | ? |
| IDEA-22 | Backup und Wiederherstellung der gesamten Bibliothek als Archiv (Umzug auf einen neuen Mac, unabhängig von iCloud) | – | ? |
| IDEA-23 | Menüleisten-Symbol mit Mini-Statistik und Import-Status | – | ? |
| IDEA-24 | Gruppen mit Freunden: Vergleich der Monats-km, gemeinsame Ziele (setzt ACC-04 Serverkonto voraus) | Server | ? |
| IDEA-25 | Gemeinsame Touren erkennen und nebeneinanderstellen (setzt ACC-04 voraus) | Server | ? |
| IDEA-26 | komoot-Anbindung: Touren zu komoot übertragen bzw. geplante Routen importieren. Achtung: komoot hat keine offene API, nur Partnerzugang; Alternativen sind GPX-Austausch oder die Teilen-Funktion. Vorher klären (V-08) | GPX/API | ? |
| IDEA-27 | Apple Health / Apple Watch: Herzfrequenz aus dem parallel aufgezeichneten Watch-Workout (Zeitabgleich) in die Tour übernehmen, Puls-Diagramm und Pulszonen; Fahrten als Radfahr-Workout mit Kalorien nach Health schreiben (erweitert PROF-04) | HealthKit | ? |
| IDEA-28 | KI-Tour-Zusammenfassung (Apple Foundation Models, auf dem Gerät): Kurztext je Tour zu Charakter, Vergleich mit dem eigenen Schnitt und Auffälligkeiten | Tour + Historie | ? |
| IDEA-29 | KI-Analyse: Fragen in natürlicher Sprache („Wie viele km im Oktober?“, „Gibt es Trends in meinen Leistungsdaten?“), beantwortet über Abfragen und Berechnungen der eigenen Bibliothek (Tool Calling, z. B. Aggregation und Trends aus WattspurKit); die Antwort enthält einen kurzen Text und ein passendes Diagramm. Eigener Seitenleisten-Eintrag „KI-Analyse“ | Bibliothek | ? |
| IDEA-30 | KI-Tournamen: sinnvolle Namen aus Orten und Streckencharakter vorschlagen | GPS + Ortsnamen | ? |
| IDEA-31 | Fahrt nachfahren (Wunsch von Nils 25.10.2026, Vorbild die Wiedergabe in EBikeData): Knopf „Abspielen“ an der Karte des Tour-Details; die Fahrt läuft auf Apple Karten ab, wählbar **2D, 3D und Satellit**, mit Marker, Kamera, die der Strecke folgt, Pause/Fortsetzen, Schieberegler mit abgelaufener und Gesamtzeit und Anzeige von Zeit, Geschwindigkeit, Strecke und Höhe an der Position; Tempo wählbar. Wattspur hat die 1-Hz-Zeitreihe der FIT-Datei und kann feiner abspielen als eine API-Spur. Karte nur online (wie die Kartenkacheln, NFR-01); ohne Netz Hinweis. Weit hinten, **nach 1.9** | Zeitreihe, GPS | ? |
| IDEA-32 | Akkustand und Fahrerleistung während der Fahrt mitschreiben (Bosch Live Data Interface, Bluetooth): ein Gerät auf der Fahrt (iOS-App nach B-070 oder eigenes Zubehör) schreibt mit Zeitstempel mit und gibt es an Wattspur; der **einzige belegte Weg zu einem Akkustand als Zeitreihe**, aber ohne Motorleistung. Bosch nimmt Smartphones **nicht** in den Umfang (Zubehör-Rolle, GAP-Peripheral), Machbarkeit offen; Schnittstelle als „experimental“ gekennzeichnet. Weit hinten, **nach 1.9**, nur nach einem Spike | Live-Daten per Bluetooth | ? |

## 5. Nicht-funktionale Anforderungen (NFR)
| ID | Anforderung |
|---|---|
| NFR-01 | Offline-fähig; keine Pflicht zu einem Online-Konto (lokales Profil genügt), keine Telemetrie. Netz nur für Kartenkacheln, das Online-Handbuch und die Frage nach einer neuen Version bei GitHub (höchstens einmal am Tag, abschaltbar, es werden keine Daten gesendet; B-172), ab 1.9 zusätzlich für den **optionalen** Abruf von Bosch-Daten (MOT, NFR-20) |
| NFR-02 | Import einer Fahrt (ca. 6 000 Records) unter 1 s; Liste mit über 1 000 Fahrten flüssig |
| NFR-03 | Persistenz mit SwiftData im App-Container (CloudKit-fähig modelliert, siehe Kap. 7); Zeitreihen kompakt gespeichert; Originaldateien bleiben erhalten |
| NFR-04 | Die Summenwerte stimmen **exakt** mit der `session` der FIT-Datei überein (Referenztest Beispielfahrt); selbst berechnete Werte sind dokumentiert und reproduzierbar |
| NFR-05 | App-Sandbox; Ordnerzugriff (auch iCloud Drive) über security-scoped bookmarks |
| NFR-06 | Kernlogik (Parser, Berechnungen) plattformneutral in `WattspurKit`, mit Unit-Tests |
| NFR-07 | Hell- und Dunkelmodus; auf dem Mac Seitenleiste, Tastatur und Menüleiste wie bei nativen Apps |
| NFR-08 | Fremde Kartenkacheln nur nach den Nutzungsbedingungen des Anbieters (Attribution, User-Agent, Caching) |
| NFR-09 | Keine Bosch-Marken, -Logos oder -Assets in der App; das UI ist nur inhaltlich angelehnt. „Bosch“ nur beschreibend („importiert Exporte der Bosch eBike Flow App“) |
| NFR-10 | Lokalisierung: alle UI-Texte über String Catalogs; Englisch als Entwicklungssprache, Deutsch vollständig übersetzt; Zahlen-, Datums- und Einheitenformat nach Gebietsschema |
| NFR-11 | Robuster Import: unbekannte, beschädigte oder fremde FIT-Dateien führen nie zum Absturz, sondern zu einem verständlichen Eintrag im Import-Protokoll. Testdateien von mindestens zwei Bosch-Systemen bzw. Freunden |
| NFR-12 | Datenschutz und Rechte im Repo: keine echten Fahrtdaten in einem öffentlichen Repository (`.gitignore`); die Beispielfahrt vor einer Veröffentlichung anonymisieren (Koordinaten verschieben, Start und Ende abschneiden); **Screenshots der Bosch-App nicht veröffentlichen** (fremdes Urheberrecht), sie bleiben nur lokal als Referenz |
| NFR-13 | Veröffentlichungsfähig bleiben: Bundle-ID, Signierung und Datenschutzangaben so anlegen, dass Notarisierung bzw. App Store später ohne Umbau möglich sind |
| NFR-14 | Qualitätssicherung (Definition of Done): Unit-Tests für die Kernlogik in `WattspurKit` inkl. Referenztest; CI mit GitHub Actions bei jedem Push; jede Änderung als Branch mit Code-Review vor dem Merge nach `main`. UI-Tests vorerst nicht |
| NFR-15 | Mindestversion macOS 26; neueste SwiftUI-, SwiftData-, Charts- und MapKit-APIs ohne Fallbacks für ältere Systeme |
| NFR-16 | Barrierefreiheit (Grundniveau): VoiceOver-Beschriftungen für Kennzahlen und Diagramme (Audio Graphs), vollständige Tastaturbedienung, ausreichende Kontraste, Farbe nie als einzige Information |
| NFR-17 | Automatische Neu-Auswertung: jede Fahrt speichert die Parser-Version; nach einem Update werden betroffene Fahrten im Hintergrund aus der Originaldatei neu eingelesen; lokale Änderungen (Name, Notizen, Papierkorb-Status) bleiben erhalten |
| NFR-18 | Verteilung ohne Developer-Account: ad-hoc signierte App im DMG; v1.0 nutzt keine Funktionen, die bezahlte Berechtigungen voraussetzen (CloudKit, App-Gruppen für Widgets o. Ä.). Das Handbuch erklärt das einmalige Öffnen trotz Gatekeeper-Warnung (Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“). Ein Hinweis auf neue Versionen (Banner, B-172) ersetzt das Auto-Update. Mit Developer-Account: Notarisierung, ggf. Auto-Update (Sparkle, B-173) |
| NFR-19 | FIT-Parser: Entscheidung zwischen Garmin FIT SDK und eigenem Decoder im Spike B-002 nach Kriterien Vollständigkeit, Robustheit, Lizenz (Veröffentlichung auf GitHub), Größe und Wartungsaufwand |
| NFR-20 | Bosch-Abruf (MOT): Verbindung nur nach ausdrücklicher Anmeldung des Nutzers und nur zu den Bosch-Servern; Tokens ausschließlich im Schlüsselbund (nie in SwiftData, Protokollen, Diagnose-Dateien oder im Repo); keine Client-ID und kein Geheimnis im Repo; Anfragen gedrosselt und mit Wiederholung bei 429/5xx; Diagnose enthält keine Tokens und keine abgerufenen Fahrtdaten; Zugriff nur lesend; Bedingungen von Bosch für Datenempfänger sind einzuhalten (V-12) |

## 6. Informationsarchitektur (macOS)

```
Seitenleiste                                         Release
├── Statistiken   Liste aller Fahrten → Tour-Detail             v0.1
│                 Vergleich von 2–4 markierten Fahrten           v1.2
├── Auswertung    Zeitraum oben; Summen, Balken, Trends         v0.2
├── Highlights    Jahresrückblick, Rekorde, Ziele (⌘4)          v1.3 (Teaser ab v1.2)
├── Karte         alle Fahrten, Heatmap (Linien/Fläche) (⌘5)    v1.4 (Teaser ab v1.2)
├── Profil        Körperdaten, Bikes, aktives Bike               v1.5
├── KI-Analyse    Fragen an die Daten, Antwort mit Diagramm      Idee (IDEA-29)
Papierkorb (⌘3) unten in der Seitenleiste
Werkzeugleiste: Import (+), „Import für: Bike“ (ab v1.5), Import-Protokoll
Einstellungen (⌘,): Karte, Import-Ordner, Faktoren, Bosch-Konto (ab v1.9)
```
Auf iOS als Tab-Leiste mit Navigation-Stack.

## 7. Architektur-Leitlinien
- **Fahrer und Bike von Anfang an im Modell:** Entitäten `Rider` und `Bike` existieren ab M0. Jede Fahrt gehört genau einem Fahrer und optional einem Bike. In v1.0 gibt es genau einen Fahrer und ein Bike, die automatisch angelegt werden; jede importierte Fahrt kommt zu diesem Bike. `file_id.serial_number` taugt nicht als Bike-Kennung, weil Bosch sie bei jedem Export neu vergibt; sie bleibt nur als Metadatum an der Fahrt. Mit mehreren Bikes (PROF-03, B-074, v1.5) erfolgt die Zuordnung manuell: neue Fahrten gehen an das aktive Bike, danach lässt sich jede Fahrt umhängen. Ein Bike gehört einem `Rider`; ein Bike wird archiviert (`isArchived`), nicht gelöscht, damit die Fahrten zugeordnet bleiben.
- **Profil = Konto:** Das lokale Benutzerprofil (ACC-01) ist der `Rider`. Jede Entität trägt eine stabile UUID, damit ein späteres Serverkonto (ACC-04) die lokalen Daten ohne Umschlüsselung übernehmen kann.
- **Importquellen als Plug-in-Schnittstelle:** Protokoll `RideImporter` (FIT; später GPX, Apple Health, Strava, generische FIT). Jede Fahrt merkt sich ihre Quelle.
- **Bosch-Daten als eigene Schnittstelle:** Der Abruf bei Bosch (MOT, v1.9) hängt hinter Protokollen für HTTP und Anmeldung im Kit, damit er mit aufgezeichneten Antworten getestet wird; Tokens liegen im Schlüsselbund der App, nicht im Kit. Die Felder der Antwort sind Zusatzfelder an `Ride` und `Bike`, die FIT-Daten werden nie überschrieben (eine später importierte FIT-Datei ersetzt höchstens eine aus Bosch-Daten angelegte Fahrt, MOT-13).
- **Kartenquelle austauschbar:** Protokoll bzw. Abstraktion `MapProvider`. v1.0 enthält nur MapKit; OSM-Stile werden später als weitere Implementierungen ergänzt.
- **Sync-fähiges Datenmodell:** SwiftData so modellieren, dass ein späterer CloudKit-Sync ohne Migration möglich ist: keine `@Attribute(.unique)`, alle Felder optional oder mit Standardwert, Beziehungen optional, große Zeitreihen und Originaldateien als externe Daten.
- **Kalorien-Strategie austauschbar:** Protokoll `CalorieEstimator` mit „Arbeit“ (Standard, v1.0) und „Profil“ (v1.x).
- **Lokalisierung ab der ersten Zeile:** keine fest eingebauten UI-Texte; Formatierung über `FormatStyle` und `Measurement`.

## 8. Offene Fragen
1. ~~Lizenz~~ → entschieden 20.10.2026: Code **MIT**, Dokumentation **CC BY 4.0**, © Nils Wiese (`LICENSE`, `docs/LICENSE.md`).
2. Ab wann ein Apple-Developer-Account (99 €/Jahr)? Für v1.0 nicht nötig (DMG, NFR-18). Nötig erst für Notarisierung, iCloud-Sync, Widgets, iOS-Geräte und App Store.
3. Ist der Name „Wattspur“ im App Store und als Marke frei? Vor einer Veröffentlichung prüfen.
4. Wofür genau soll ein Serverkonto später dienen (Sync, Backup, Teilen mit Freunden, Vergleich in Gruppen)? Davon hängen Backend, Kosten und Datenschutz ab (ACC-04).
5. Bosch Data-Act-API (MOT, v1.9), im Spike V-12 zu klären: Inhalt der **Bedingungen für Datenempfänger** (Weitergabe an Freunde, GitHub, App Store, Speicherung, Marken); Punktzahl und Auflösung der **Spur**; **Ratenbegrenzung** (nirgends dokumentiert); Dauer der **Client-Freigabe**; **Schlüsselbund** mit ad-hoc signiertem Build; wie weit zurück Fahrten abrufbar sind; Verhalten bei Fahrten ohne Smartphone. **Geklärt am 25.10.2026:** Redirect mit eigenem Schema ist möglich; Felder und Einheiten stehen in den Spezifikationen; Motordaten je Fahrt gibt es nicht.

## 9. Nicht im Umfang (bewusst gestrichen)
- Akkustand, Unterstützungsmodus, Motorleistung, Reichweite und Akkuverbrauch: nicht in den Exporten und **auch nicht je Fahrt in der offiziellen Data-Act-API** (Spezifikationen, 25.10.2026). **Seit 25.10.2026** kommen optional Bike-, Akku- und Wartungsdaten sowie Zusatzfelder und Fahrten ohne Datei aus der Data-Act-API (siehe 3.5, MOT, 10.18). Weiter nicht im Umfang: Motorleistung und Akkustand als Zeitreihe
- Altbestand-Import über die **inoffizielle** Bosch-Fahrten-API (App-Client): rechtlich unklar und von einer undokumentierten Schnittstelle abhängig (zweites Review). Altbestand per Einzelexport. Die offizielle Data-Act-API ist davon unberührt (10.18), legt aber keine Fahrten an, die nicht als Datei vorliegen
- Ein gemeinsamer Bosch-Client für alle Nutzer, ein eigenes Backend oder Server für den Bosch-Abruf, Bosch-Marken und -Logos (NFR-09)
- Diebstahlschutz, eBike Lock, Navigation und Routenplanung (Flow+-Funktionen ohne Bezug zu den Exportdaten)
- Privatzonen um Wohnort und Ziele: vorerst nicht nötig, da die App lokal bleibt; nur die Beispieldaten werden anonymisiert. *Wird mit IDEA-18 (Tour als Bild teilen) wieder aufgegriffen.*
- ~~Wetter je Tour~~ → wieder aufgenommen als IDEA-13 (Ideen-Pool)

## 10. Entscheidungsprotokoll

### 10.1 Offene Fragen v0.1 (19.10.2026)
| # | Frage | Entscheidung |
|---|---|---|
| 1 | Kalorienberechnung | Umschaltbar: Standard aus der Arbeit, optional mit Fahrerprofil (v1.x) |
| 2 | Mehrere Bikes/Fahrer | v1.0 nur ein Fahrer; im Datenmodell von Anfang an vorgesehen |
| 3 | Sync Mac ↔ iOS | Später entscheiden; Modell bleibt CloudKit-fähig |
| 4 | OSM-Kartenstile | Standard, CyclOSM, OpenTopoMap, nach dem Review auf v1.x verschoben |
| 5 | Altbestand von 128 Fahrten | Recherche erledigt; inoffizielle API im zweiten Review gestrichen. Einzelexport, optional DSGVO-Auskunft |
| 6 | Weitere Datenquellen | v1.0 nur Bosch-Exporte; später Apple Health, Strava, generische FIT |

### 10.2 Requirements-Review (19.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Zweck | Lernen, eBike-Optik, Flow+ ohne Abo | Kap. 1 |
| Datenweg | iCloud-Drive-Ordner, vom Mac überwacht | IMP-05 wird Must |
| Nutzung | nach jeder Fahrt **und** regelmäßige Auswertung | Import mit null Aufwand, Kumuliert und Trends in v1.0 |
| Zielgruppe | ich + Freunde; GitHub bzw. App Store möglich | NFR-09, NFR-11, NFR-13 |
| Wahrheitsquelle | Bosch-`session`-Werte | Kap. 3.3, NFR-04 |
| Flow+ ohne Daten | streichen | Kap. 9 |
| Trittfrequenz-Lücken | letzten Wert halten (Diagramm) | Kap. 3.3 |
| Datenschutz | Beispieldaten anonymisieren, keine Privatzonen | NFR-12 |
| Umfang v1.0 | Import, Liste, Tour, Kumuliert, Trends | Prioritäten in Kap. 4 |
| Karten | MapKit zuerst, OSM v1.x | MAP-01/02 |
| Plattform | Mac zuerst bleibt | – |
| Sprache | Englisch Standard, Deutsch wählbar, erweiterbar | NFR-10, SET-07 |

### 10.3 Ergänzungen (19.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Benutzerkonto | zunächst lokal, später ggf. Server | Kap. 4.10 (ACC); lokales Profil = `Rider`; NFR-01 angepasst |
| Nutzer-Dokumentation | auf GitHub, später ggf. Website | Kap. 4.11 (DOC) |
| Ideen-Pool | Alle Vorschläge übernehmen, dazu PDF-Tourbericht, komoot und Apple Health / Apple Watch; Priorisierung später | Kap. 4.12 (IDEA-01 bis IDEA-27) |

### 10.4 Zweites Review (19.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Kapazität | Hobby, kein Termin | Releases v0.1–v1.0 (Kap. 2, Backlog) |
| Design | Mac-nativ mit Flow-Inhalten | Kap. 2, Kap. 6 |
| Mindest-OS | macOS 26+ | NFR-15 |
| Import-Ordner | importierte Dateien nach `Importiert/`, fehlerhafte nach `Fehlerhaft/` | IMP-05 |
| Zwischenstände | ja, v0.1 → v0.2 → v0.3 → v1.0 | Backlog |
| Altbestand über inoffizielle API | gestrichen | IMP-09 entfernt, Kap. 9 |
| Kumuliert + Trends | zu „Auswertung“ zusammengelegt | Kap. 4.4/4.5, Kap. 6 |
| Qualität | Unit-Tests Kern, CI (GitHub Actions), Code-Review vor Merge | NFR-14 |

### 10.5 Drittes Review (19.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Zusammenarbeit | Claude baut und erklärt, ich verstehe und reviewe | Kap. 2, DoD im Backlog |
| Barrierefreiheit | Grundniveau | NFR-16 |
| Löschen | Papierkorb (30 Tage) + ⌘Z | LIST-07, LIST-08 |
| Erneuter Import | manuell nachfragen, Ordner überspringen | IMP-02 |
| Bibliothek | App-Container | Kap. 2, NFR-03 |
| Parser-Verbesserungen | automatische Neu-Auswertung | NFR-17 |
| Schätzwerte | dezent mit Info-Symbol | TOUR-03 |
| KI auf dem Gerät | drei Ideen in den Pool | IDEA-28 bis IDEA-30 |

### 10.6 Viertes Review (19.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| FIT-Parser | Spike entscheidet (SDK vs. eigener Decoder) | NFR-19, B-002 |
| Verteilung | DMG per Mail/GitHub/Website, vorerst ohne Developer-Account | Kap. 2, NFR-13, NFR-18 |
| Feedback | Diagnose-Export, nichts automatisch | SUP-01, SUP-02 |
| Erststart | Einrichtungsassistent + optionale Beispielfahrt | ONB-01 bis ONB-03 |
| Bosch-Screenshots | nur lokal, nicht veröffentlichen | NFR-12 |

### 10.7 Fahrten zusammenfassen (20.10.2026)
| Frage | Entscheidung | Auswirkung |
|---|---|---|
| Ergebnis | eine neue Fahrt; Originale ausgeblendet, wiederherstellbar | LIST-09 |
| Lücke zwischen den Teilen | am selben Tag als Pause, über Tage hinweg nur Fahrzeiten | LIST-09 |
| Erkennung | Vorschlag als Hinweis, keine automatische Zusammenfassung | LIST-10 |
| Umfang | 2 oder mehr aufeinanderfolgende Fahrten; Vorschläge nur am selben Tag | LIST-09, LIST-10 |
| Offen | konkretes Beispiel aus den Testdaten benennen (Screenshot traf das falsche Paar); Grenzwerte für den Vorschlag (Lücke, Abstand Ende–Start) mit echten Fahrten festlegen | B-095, B-096 |

### 10.8 v0.3 Import ohne Aufwand (20.10.2026)
| Frage | Entscheidung | Auswirkung |
|---|---|---|
| Andere Dateien im überwachten Ordner (z. B. GPX) | bleiben liegen, einmal im Protokoll vermerkt, nicht nach `Fehlerhaft/`; **seit der Entscheidung vom 25.10.2026 (10.17) gilt das nicht mehr für GPX**, das ab v1.6 importiert wird | IMP-05, B-040 |
| Wann wird überwacht | beim Start und solange die App läuft; kein Hintergrunddienst | IMP-05, B-040 |
| Sprache | folgt macOS; kein eigener Schalter, nur Hinweis und Knopf zu den Systemeinstellungen | SET-07, B-042 |
| Einrichtungsassistent | einmal beim ersten Start, in den Einstellungen erneut aufrufbar; Beispielfahrt erst in v1.0 | ONB-01, ONB-02, B-027 |

### 10.9 Route einfärben (20.10.2026)
| Frage | Entscheidung | Auswirkung |
|---|---|---|
| Auswahl | Menü auf der Karte neben Standard/Satellit/Hybrid | TOUR-08 |
| Kennzahlen | Höhe, Geschwindigkeit, Trittfrequenz, Leistung, Steigung; Standard einfarbig | TOUR-08 |
| Farbskala | mehrstufig Blau → Rot mit Legende (min/max) | TOUR-08, NFR-16 |
| Bezug der Skala | Min/Max der jeweiligen Fahrt | TOUR-08 |
| Extras | Auswahl merken, Wert beim Zeigen auf die Spur, Stellen ohne Messwert grau | TOUR-08, B-063 |

### 10.7 Tourenvergleich (21.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Tester-Wunsch Tourenvergleich | 2–4 Fahrten nebeneinander, alle Kennzahlen + abgeleitete Werte + Abweichung vom Schnitt, Diagramme übereinander, Einstieg per Mehrfachauswahl → „Vergleichen“; nächstes v1.x-Feature | Kap. 4.5a (CMP-01 bis CMP-07), B-098 bis B-103 |
| Ort des Vergleichs | rechts neben der Liste; die markierten Fahrten sind der Vergleich (⌘-Klick fügt hinzu, × entfernt) | CMP-01, CMP-06, B-100, B-103 |
| Bester Wert | Stern nur bei Ø Geschwindigkeit, Ø Leistung, Ø Leistung über die Fahrzeit (mehr ist besser) und Pausen (weniger ist besser); alles andere neutral | CMP-02, B-101 |
| Schnitt für die Abweichung | alle Fahrten außer Beispielfahrt, Papierkorb und Teilen zusammengefügter Fahrten, je Fahrt; Ø-Werte nach Fahrzeit, Werte pro km nach Strecke gewichtet | CMP-04, B-098 |
| Rollanteil | aus den Bosch-Werten: 1 − (Arbeit ÷ Ø Leistung) ÷ Fahrzeit, weil Bosch die Ø Leistung nur über Sekunden mit Treten bildet | CMP-03, B-098 |
| Seitenleiste | Teaser „Highlights“ (⌘4) und „Karte“ (⌘5) ab v1.2; Papierkorb bleibt ⌘3 | Kap. 6, B-111 |
| Vergleich beim Testen (21.10.2026) | Reihenfolge Karte → Diagramme → Tabelle; Karte mit allen Routen; über den Diagrammen Ø-Werte je Fahrt, bei der Höhe Anstieg, Abstieg und steilste Stelle (über 100 m); PDF-Export (A4) oben links schon in v1.2 | CMP-05, CMP-07, CMP-08, B-102, B-103 |
| PDF-Export überall (21.10.2026) | Knopf „PDF exportieren“ oben links: ein Klick öffnet Vorschau, Menü bietet Sichern. In v1.2 für Vergleich und Tour-Detail (IDEA-20 vorgezogen); Highlights (v1.3) und Karte (v1.4) bekommen ihn mit ihrem Bau | CMP-07, IDEA-20, B-050 ff., B-106 ff. |

### 10.10 Highlights und GPX-Export (22.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Umfang v1.3 | Highlights (Jahr, Rekorde, Ziele) plus GPX-Export einer Fahrt | B-050 bis B-053, B-112 |
| Grundlage | Bosch-Summen jeder Fahrt; Beispielfahrt und Papierkorb zählen nie, eine zusammengefügte Fahrt ist eine Fahrt (ihre Teile zählen nicht extra) | ADV-J1, ADV-R1, ADV-Z1 |
| Serie | aufeinanderfolgende Kalendertage mit mindestens einer Fahrt, Tag nach Ortszeit des Fahrtstarts; ein Tag ohne Fahrt beendet die Serie | ADV-R1, B-051 |
| Ø-Rekorde | Ø Geschwindigkeit und Ø Leistung zählen erst ab 5 km Strecke, damit kurze Fahrten keinen Rekord setzen | ADV-R1, B-051 |
| Ziele | Kilometer, Fahrten oder Höhenmeter je Woche (Mo–So), Monat oder Jahr; jede Kombination höchstens einmal (bis zu 9 Ziele) | ADV-Z1, B-053 |
| Speicherort Ziele | eigenes SwiftData-Modell `Goal`, CloudKit-fähig (Standardwerte, keine unique-Felder) | ADV-Z1, B-053 |
| Hinweis „Neuer Rekord“ | bei jedem Import (manuell, Drag & Drop, überwachter Ordner, auch beim Start); mehrere Rekorde eines Imports in einem Hinweis, dazu ein Eintrag im Import-Protokoll | ADV-R2, B-052 |
| Rekord-Abzeichen | nur im Tour-Detail und nur, solange die Fahrt den Bestwert über alle Fahrten hält | ADV-R2, B-052 |
| PDF-Export | „PDF exportieren“ oben links in jedem Reiter der Highlights | IDEA-19, B-050 ff. |
| GPX-Format | GPX 1.1, Zeitstempel in UTC; Trittfrequenz als `gpxtpx:cad` (Garmin TrackPointExtension v2), Leistung als `<power>` wie in Garmin- und Strava-Exporten | IMP-09, B-112 |
| GPX bei zusammengefügten Fahrten | ein Track mit einem Segment je Teil | IMP-09, B-112 |
| GPX-Einstieg | Knopf „Als GPX exportieren …“ im Tour-Detail neben „PDF exportieren“ und Eintrag im Kontextmenü der Liste, jeweils mit Sichern-Dialog | IMP-09, B-112 |

### 10.11 Karte aller Fahrten (22.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Vereinfachte Routen | Douglas-Peucker mit 5 m Toleranz, ein Segment je Teil einer zusammengefügten Fahrt | B-104 |
| Speicherort | zwei optionale Felder an `Ride` (Daten + Version), CloudKit-fähig; berechnet bei Import, Neu-Auswertung, Zusammenfügen und Trennen, der Bestand einmal im Hintergrund mit Fortschritt | B-104, NFR-03, NFR-17 |
| Welche Fahrten | wie im Vergleich: Beispielfahrt nur, wenn markiert; zusammengefügte Fahrt = eine Fahrt, Teile nie extra; Papierkorb und Fahrten ohne GPS fehlen, der Untertitel nennt die Fahrten ohne GPS | AGG-05, B-106 |
| Zeitraum | wie in der Auswertung (Woche, Monat, Jahr, frei, alles, mit Blättern), aber eigene gemerkte Auswahl; Standard „Alle“ | AGG-05, B-106 |
| Nur markierte Fahrten | Zeitraum dann ausgegraut; 1–4 Fahrten in Farbe und Strichart wie im Vergleich, ab 5 Linien- bzw. Wärmekarte nur über die markierten | AGG-05, B-106 |
| Linienfarbe | Magenta (#C2187A hell, #FF4FAE dunkel), hebt sich von Straßen, Wald und Wasser ab | MAP-04a, B-107, NFR-16 |
| Wärmekarte | Zellen von etwa 16 pt am Bildschirm, passend zum Zoom; jede Fahrt zählt je Zelle einmal; feste Stufen 1 / 2–4 / 5–9 / 10–19 / 20+ in Blau → Rot, gleich in jedem Zeitraum, Legende mit Zahlen | MAP-04b, B-108, NFR-16 |
| Klick auf die Karte | Treffer bis 10 pt neben einer Strecke; Popover mit den Fahrten dort, neueste zuerst, „Alle in der Liste markieren“ | MAP-05, B-109 |
| Fahrt im Popover | hebt die Fahrt auf der Karte hervor (übrige treten zurück) und zeigt ein Infofeld mit „Im Tour-Detail öffnen“ | MAP-05, B-109 |
| PDF-Export | sichtbarer Ausschnitt in der aktuellen Darstellung, mit Titel, Zeitraum, Anzahl, km und Legende; A4 hochkant, hell | IDEA-20, B-106 ff. |
| Kacheln im Ausschnitt (Wunsch von Nils) | unter der Karte Fahrten, Strecke, Fahrzeit, Anstieg und Ø Geschwindigkeit der Fahrten, deren Route den sichtbaren Ausschnitt berührt, mit ihren ganzen Bosch-Summen (nicht nur dem sichtbaren Stück); live nach dem Schieben/Zoomen, Klick öffnet die Auswertung für diese Fahrten, auch im PDF; gebaut mit B-106 | AGG-06, B-114 |
| Routen-Vorschau in der Liste | aus v1.x vorgezogen: 44 pt links in jeder Zeile, nur die Linie aus der Übersichtsroute ohne Kartenkacheln, grüner Startpunkt, ein Strich je Teil, Symbol ohne GPS | LIST-02, B-064 |
| Neue Wege | Teil von IDEA-12 in v1.4: Anteil der Strecke in 50-m-Zellen, durch die vorher keine Fahrt lief (früher gestartete Fahrten außer Beispielfahrt und Papierkorb); im Tour-Detail mit Hervorhebung auf der Karte, im Infofeld und als Kachel der Karte aller Fahrten | IDEA-12, B-115 |
| Fahrtenliste in Karte und Auswertung (Wunsch von Nils nach dem ersten Test) | links eine Liste wie unter „Fahrten“, beschränkt auf die Fahrten im Kartenausschnitt bzw. in der Auswertung; Markierung gemeinsam mit „Fahrten“. Schon mit B-106: Die Karte merkt sich Ausschnitt und Zoom beim Wechsel zwischen den Bereichen, und „In der Karte zeigen“ in der Auswertung zeigt genau deren Fahrten (Chip wie bei der Auswahl in der Auswertung) | AGG-05, AGG-06, B-123, B-124 |
| Reihenfolge | B-104 → B-064 → Karte (B-106, B-107, B-114) → B-108 → B-109 → B-123/B-124 → B-115 → Release | B-104 ff. |
| Filter Bike/Fahrer | aus v1.4 verschoben, solange es nur einen Fahrer und ein Bike gibt | AGG-05, B-110 |
| Technik | `MKMapView` mit einem eigenen Overlay-Renderer für Linien und Wärmekarte statt vieler `MapPolyline`, damit 1 000 Fahrten flüssig bleiben; Rechnen (Vereinfachung, Raster, Treffer) im Kit | NFR-02, NFR-06, B-104 ff. |

### 10.12 Ähnliche Strecken und weitere Rekorde (22.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Ähnlichkeit | Anteil der Route innerhalb 50 m der anderen, in beide Richtungen; Standard ≥ 90 %, Regler 80–99 % | ROUTE-01, ROUTE-02 |
| Richtung | getrennt; Schalter „Auch Gegenrichtung“ | ROUTE-04 |
| Nutzung | „Ähnliche Fahrten zeigen“ mit Filter-Chip, Vergleich bis 4, Verlauf über alle Treffer, automatische Gruppen | ROUTE-03, ROUTE-05 bis ROUTE-07 |
| Weitere Rekorde | Max-Leistung, Max-Trittfrequenz, Max-Geschwindigkeit (Bosch-Maximum) und beste 1-Minuten-Leistung | ADV-R3 |
| Release | v1.7 (geändert am 25.10.2026, zuvor v1.5; siehe 10.16 und 10.17) | Backlog |

### 10.13 Fahrten und Karte in einem Bereich (22.10.2026, jetzt v1.8)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Aufbau | ein Bereich „Fahrten“: links die Liste, rechts standardmäßig die Karte aller Fahrten der Liste; eine markierte Fahrt zeigt ihr Tour-Detail mit „‹ Karte“ (Esc) zurück, 2–4 markierte den Vergleich; „Karte“ und ⌘5 entfallen | Kap. 6, AGG-05, B-125 |
| Was die Karte zeigt | die Liste führt: Suche und Zeitraum der Liste bestimmen die Fahrten der Karte; ein Schalter „Nur Kartenausschnitt“ beschränkt die Liste zusätzlich auf den Ausschnitt | AGG-05, AGG-06, B-125 |
| Zeitpunkt | ursprünglich v1.5, seit dem 25.10.2026 in v1.8 nach „Profil und Bikes“ (v1.5), „GPX-Import“ (v1.6) und „Ähnliche Strecken“ (v1.7), mit eigenem Artboard (10.16); v1.4 erscheint mit eigenem Bereich „Karte“ | B-125 |

### 10.14 Feedback aus dem Test von 1.4.1 (24.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Kalendertag mit mehreren Fahrten | die Liste unter „Fahrten“ wird auf den Tag gefiltert (Chip mit ✕), bei einer Fahrt öffnet sich gleich ihr Tour-Detail | B-130 (v1.8, mit B-125) |
| Rücksprung | „‹ Zurück zu Highlights“ (⌘[) wie bei Karte und Auswertung | B-128 (v1.4.2) |
| Klick neben jede Spur | hebt Markierung, Popover, Infofeld und Hervorhebung auf | MAP-05, B-129 (v1.4.2) |
| Diagramm ↔ Karte | Hover zeigt Position, Klick hält sie fest; in beide Richtungen | TOUR-06, B-062 (v1.5) |
| Fügestellen | Diagramme und Karte im Tour-Detail sowie PDF der Fahrt; nicht im Vergleich | B-131 (v1.5) |
| Zusammenfügen beim Import | Hinweis mit Knopf „Zusammenfügen“ nach dem Import, nie automatisch | LIST-10, B-096 (v1.5) |
| Fehler | PDF der Karte mit gespiegelten Routen und fehlende neue Wege im Tour-Detail kommen als 1.4.2 | B-126, B-127 |
| Versionen | 1.4.2 nur Fehlerbehebungen und die beiden kleinen Bedienfehler; alle neuen Funktionen in v1.5 | Backlog |

### 10.15 Releaseplan nach dem Test von 1.4.2 (24.10.2026)
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Test von 1.4.2 | B-126 bis B-129 im Test bestätigt | – |
| v1.4.3 | die kleinen Wünsche aus dem Test von 1.4.1 vorab: B-132 (keine Orte auf der Karte aller Fahrten), B-096, B-131, B-065, B-062; ersetzt die Zuordnung „v1.5“ in 10.14 | Backlog |
| x-Achse | B-065 (TOUR-07) kommt in 1.4.3 mit, vor B-062, damit die Kopplung gleich auf beiden Achsen entsteht | TOUR-07, B-065 |
| Fügestellen bei Lücke | bei räumlicher Lücke zwischen zwei Teilen bekommen beide Enden einen Querstrich | B-131 |
| Kopplung im PDF | nein, festgehaltene Position nur am Bildschirm | B-062 |
| v1.5 | nur noch B-125 (Bereich „Fahrten“ mit Karte, zuerst Artboard) und B-130; am 25.10.2026 nach v1.8 verschoben (10.16, 10.17) | B-125, B-130 |
| Serie in „Rekorde“ | filtert wie ein Kalendertag, als Zeitraum mit Chip | B-130 |
| v1.6 | Ähnliche Strecken (B-116 bis B-121) und weitere Rekorde (B-122), von v1.5 verschoben; ersetzt „Release v1.5“ in 10.12; am 25.10.2026 weiter nach v1.7 verschoben (10.17) | Backlog |

### 10.16 Profil und mehrere Bikes (25.10.2026, für v1.5)
Anlass: Erste Tester haben mehr als ein eBike mit Smart System und wollen sie getrennt auswerten. Die Reihenfolge ändert sich dadurch: v1.5 Profil und Bikes, danach (siehe 10.17) v1.6 GPX-Import, v1.7 Ähnliche Strecken und weitere Rekorde, v1.8 Fahrten mit Karte.
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Umfang | ein lokales Profil mit Körperdaten, mehrere Bikes je Profil; mehrere Fahrer und Profilwechsel bleiben später | PROF-01, PROF-03, B-073, B-086 |
| Körperdaten | Gewicht, Größe, Geburtsjahr (Alter je Fahrt), Geschlecht männlich / weiblich / keine Angabe; alle optional | PROF-01, B-074 |
| Kalorien „mit Profil“ | Arbeit ÷ Wirkungsgrad plus Grundumsatz über die Fahrtdauer (Mifflin-St Jeor); Standard bleibt „aus Arbeit“; Abgleich mit Flow-App-Werten in V-01 | SET-06, 3.4, B-067 |
| Zuordnung | neue Fahrten an das aktive Bike, nachträglich einzeln oder per Mehrfachauswahl (⌘Z); keine Unterordner, keine Rückfrage beim Import | PROF-03, B-135 |
| Aktives Bike | Stern im Profil und Menü „Import für“ in der Werkzeugleiste | B-134, B-135 |
| Bike-Daten | Name, Farbe, Art (Fahrrad, Mountainbike, Rennrad, Gravelbike; dazu Schalter E-Bike), Foto, Hersteller, Modell, Antrieb, Akku (Wh), Gewicht (nur Info), Kaufdatum, km-Startwert; Foto nur im Editor und in der Profil-Kachel, sonst das Symbol der Art | B-074, B-134 |
| Ort | Eintrag „Profil“ in der Seitenleiste | Kap. 6, B-134 |
| Filter | je Bereich (Fahrten, Auswertung, Karte, Highlights), gemerkt; Ziele zählen über alle Bikes; ersetzt „Filter Bike/Fahrer“ in 10.11 | AGG-05, B-110, B-137 |
| Entfernen | Bike archivieren, Fahrten bleiben zugeordnet, Bike bleibt in den Filtern | B-134 |
| Anzeige | Symbol in der Listenzeile ab 2 Bikes, Menü im Tour-Detail, Zeile im Vergleich, Name im PDF der Fahrt und im GPX | B-135, B-136 |
| Umstieg und Erststart | Standard-Bike heißt „Mein eBike“, einmaliger Hinweis nach dem Update; Assistent mit Schritt „Erstes Bike“ | ONB-01, B-138 |
| Folgen für v1.7 und v1.8 | Der Chip „Ähnlich wie …“ kommt in die heutige Fahrtenliste; B-125 führt später alle Filter einschließlich Bike und Ähnlichkeit zusammen | B-118, B-125 |

### 10.17 GPX-Import (25.10.2026, für v1.6)
Anlass: Die Zielgruppe wächst, wenn auch Fahrten anderer Bikes und Radcomputer, die eher GPX als FIT ausgeben, importiert werden. Fokus und Optik bleiben Bosch/Flow. Als eigene Version nach 1.5, weil GPX auf Bikes und dem erweiterten Datenmodell aufbaut.
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Quellen | GPX 1.0/1.1 mit Position, Höhe, Zeit; Erweiterungen Leistung, Trittfrequenz, Puls, Temperatur; Export → Import verlustfrei; keine Routen und Wegpunkte | 3.2, IMP-04, B-140 |
| Mehrere Tracks | eine Fahrt je Datei mit Lücken, an verschiedenen Tagen getrennt | B-140 |
| Summen | aus dem Track berechnet und als „geschätzt“ gekennzeichnet; Startwerte (Nils, 25.10.2026): Pause ab 30 s Lücke, Stillstand unter 0,8 m/s, Höhe Median über 5 Punkte, Schwelle 3 m für Anstieg/Abstieg; Bosch-FIT bleibt Wahrheitsquelle (3.3) | 3.2, B-142 |
| Abtastrate | Originalpunkte behalten, Geschwindigkeit aus Abstand/Zeit, Leistung und Trittfrequenz leer | B-141, B-142 |
| Puls, Temperatur | nur speichern, Anzeige später | IDEA-27, B-141 |
| Duplikate | Erkennung Start ±60 s, Strecke ±10 % (geändert am 25.10.2026 von ±5 %: die Bosch-FIT-Strecke liegt ca. 4,9 % über dem GPS-Pfad), bestätigt über die vereinfachte Route (B-104), Treffer nur im selben Bike (Gruppenfahrt, Vorschlag aus V-11); FIT da → GPX anhängen ohne Rückfrage; GPX da → bei der FIT nachfragen, im Ordner aktualisieren; GPX + GPX wie IMP-02 | IMP-02, IMP-04, B-143 |
| Überwachter Ordner | GPX wird wie FIT importiert (ändert 10.8) | IMP-05, B-144 |
| Bike | Sheet beim manuellen Import, im Ordner das aktive Bike | B-135, B-144 |
| Anzeige | Quellen-Symbol, „–“ für fehlende Werte, Info „geschätzt“, Filter nach Quelle in Liste, Auswertung, Karte | B-145 |
| Ohne Leistung | Rekorde, Highlights, Ziele zählen, wo Daten da sind; Kalorien „–“, CO₂ aus der Strecke; Auswertung und Karte alle Fahrten, Ø-Leistung und Trends nur mit Leistung („n von m“); im Vergleich leere Zeilen | ADV-R, ADV-J, ADV-Z, AGG, B-146 |
| Datenmodell | optionale Felder für Puls, Temperatur, Quellenart, Kennzeichen „geschätzt“ und Zusatzquelle legt B-074 (v1.5) schon an, damit nur eine Migration nötig ist (entschieden von Nils am 25.10.2026); Parser und Anzeige folgen in v1.6 | B-074, B-141 |
| Reihenfolge | 1.5 Profil und Bikes → 1.6 GPX-Import → 1.7 Ähnliche Strecken und Rekorde → 1.8 Fahrten mit Karte | Backlog |

### 10.18 Bosch-Daten (25.10.2026, für v1.9)
Anlass: Wunsch von Nils, Motordaten einer Strecke über das offizielle Bosch-Portal zu laden, wie es die App „EBikeData“ im App Store macht. Recherche: [RECHERCHE-BOSCH-DEVELOPER-PORTAL.md](RECHERCHE-BOSCH-DEVELOPER-PORTAL.md). Ein Portal namens „Developer Portal“ gibt es öffentlich nicht; gemeint ist das Data-Act-Portal von Bosch (Registrierung als Datenempfänger, OAuth, Freigabe im Bosch eBike Manager). **Ergebnis der Recherche nach den amtlichen Spezifikationen:** Die offizielle API liefert **keine Motordaten je Fahrt**. **Nils hat am 25.10.2026 Option B gewählt:** Version 1.9 heißt **„Bosch-Daten“**. Der Plan steht unter dem Vorbehalt des Spikes V-12 (Bedingungen für Datenempfänger).
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Kap. 9 und V-03 | Nur der **offizielle** Data-Act-Weg kommt in den Umfang; die inoffizielle App-API (Client `one-bike-app`) bleibt gestrichen. V-03 bleibt erledigt, mit Nachtrag | Kap. 9, V-03, 3.5 |
| Umfang | **Bike, Akku und Wartung** (Ladezyklen, abgegebene Energie, Betriebsstunden gesamt und mit Motor, fällige Wartung, Komponenten); **Zusatzfelder je Fahrt** (Titel von Bosch, Kilometerstand zu Beginn, Kalorien und CO₂ von Bosch, Puls); **Fahrten ohne Datei importieren** (Altbestand und laufend). **Entfallen:** Modi je Fahrt, Energieanteil, Motorleistung, Akkustand (nicht in der API), damit MOT-07, MOT-08, MOT-10 und B-154, B-155, B-157 | MOT-09, MOT-13, MOT-14, B-156, B-158, B-159 |
| Machbarkeit | **Spike V-12 vor allen Stories** (Nils; Wattspur und Claude melden sich nirgends an): Bedingungen für Datenempfänger, Punktzahl der Spur, Rückwirkung, Verhalten ohne Smartphone, Schlüsselbund mit ad-hoc signiertem Build, Zuordnung an echten Paaren. Die Spezifikationen sind gelesen. Fällt das Ergebnis negativ aus, entfällt 1.9 | V-12, Kap. 8 Nr. 5 |
| Zusammenspiel mit FIT/GPX | FIT bleibt Wahrheitsquelle, Rangfolge **FIT vor GPX vor Bosch**. Die Bosch-Fahrt wird zugeordnet (Start, Strecke, Route wie IMP-04) und liefert Zusatzfelder; ohne Zuordnung wird sie **zum Anlegen angeboten**; eine später importierte Datei **ersetzt** die Bosch-Fahrt (Titel, Notizen, Bike bleiben); `boschActivityId` verhindert, dass gelöschte Fahrten wieder angeboten werden (Annahme von Claude, im Mockup B-147 zu bestätigen) | 3.5, MOT-05, MOT-13, B-151, B-158 |
| Anlegen | Summen aus der Zusammenfassung (von Bosch), Zeitreihe aus der Spur mit **geschätzter Zeit** (Spur hat keinen Zeitstempel), gekennzeichnet „geschätzt“; Anlegen **nach Bestätigung** (Altbestand: Angebot, laufend: Hinweis mit Knopf), Einstellung „automatisch anlegen“ (Standard aus) (Annahme von Claude, im Mockup B-147 zu bestätigen) | MOT-13, B-158 |
| Service-Daten | **Entschieden mit Nils am 25.10.2026: bleibt als Kann in 1.9, abhängig vom Ergebnis in V-12.** Das Digital Service Book (v2) liefert Inspektionen, Software-Updates, Akkumessungen und Händlerberichte mit Statistik je Modus, **nur je Bike und nur nach Händlerbesuch bzw. Update**; als **Kann** (MOT-15, B-160), nur mit echten Einträgen aus V-12 | MOT-15, B-160 |
| Client | **Jeder Nutzer legt seinen eigenen Client an** (öffentlicher Client, ohne Secret) und trägt die Client-ID ein; Redirect mit eigenem Schema (bei EBikeData belegt); kein Geheimnis im Repo, kein Backend; ein gemeinsamer Client erst nach V-12 und nur, wenn die Bedingungen es erlauben | MOT-02, NFR-20, B-149 |
| Anmeldung und Tokens | Systembrowser (SingleKey ID), Authorization Code Grant; Tokens (auch der Offline-Token, 180 Tage) im Schlüsselbund; `ebike-rider-id` im Token prüfen; „Abmelden“ löscht sie und fragt, ob die abgerufenen Daten bleiben | MOT-01, MOT-12, B-149 |
| Zeitpunkt | nach jedem Import im Hintergrund (nur bei geöffneter App, kein Hintergrunddienst) plus Knopf; noch nicht veröffentlichte Fahrten später erneut | MOT-03, B-152 |
| Altbestand | einmaliges Angebot nach der ersten Anmeldung (abgleichen und neu importieren) mit Fortschritt, gedrosselt, abbrechbar, fortsetzbar | MOT-04, B-153 |
| Fehler und Netz | leise beim automatischen Abruf, Dialog mit Anleitung nur bei Knopfdruck; Wattspur bleibt ohne Konto und ohne Netz voll nutzbar | MOT-11, B-152 |
| Ort in der Oberfläche | Reiter „Bosch-Konto“ in den Einstellungen, Abschnitt „Von Bosch“ im Tour-Detail, Akku, Antrieb und Wartung im Profil, Hinweis und Angebot zum Import (Altbestand, neue Fahrten), Kennzeichnung der Bosch-Fahrten in der Liste, Protokoll im Import-Protokoll; kein eigener Seitenleisten-Eintrag | Kap. 6, B-147, B-149 bis B-159 |
| Speicherung und Export | Original der Antwort archivieren (wie IMP-07), Felder an `Ride` und `Bike`, Quelle „bosch“; Anzeige auch im PDF der Fahrt; Fahrten aus Bosch-Daten werden wie GPX-Fahrten exportiert (geschätzte Zeiten gekennzeichnet); die Zusatzfelder **nicht** im GPX-Export und nicht in der Beispielfahrt | MOT-06, MOT-14, B-150 |
| Netz und Datenschutz | NFR-01 um den optionalen Abruf erweitert; neu NFR-20; Hinweise im Info-Fenster und im Handbuch; keine Telemetrie | NFR-01, NFR-20, MOT-12 |
| Marken | Keine Bosch-Logos oder -Assets (NFR-09); Modi erscheinen im Profil mit der Reichweite und, falls nur Kennungen vorliegen, beschreibend; Prüfung der Schreibweise im Spike | NFR-09, B-147 |
| Zeitplan | Spike jetzt, Stories ab 1.9 nach 1.8, Release 1.9.0 am Ende; 1.9 hängt an Bosch (Freigabe, Bedingungen) und ist die einzige Version, die an einer fremden Zusage hängt | Backlog |
| Live Data (Bluetooth) | **nicht im Umfang von 1.9:** nur während der Fahrt und nur an ein mitlaufendes Zubehör, ohne Motorleistung, Smartphone laut Bosch nicht im Umfang; als IDEA-32 in den Pool | IDEA-32, Recherche |
| Fahrt nachfahren | Wunsch von Nils nach den EBikeData-Screenshots: kommt in den Ideen-Pool (IDEA-31, P-31), bewusst **nach 1.9**; keine Aufnahme in den Plan 1.5 bis 1.9 | IDEA-31, P-31 |
| Voraussetzungen | 1.5 (Bikes für die Zuordnung API-Bike ↔ Wattspur-Bike) und 1.6 (Duplikaterkennung nach Start, Strecke und Route, Quelle und Kennzeichen „geschätzt“ aus dem GPX-Import werden wiederverwendet) | B-141, B-143, B-151 |

### 10.19 Ähnliche Strecken und weitere Rekorde: Umsetzung (26.10.2026, für v1.7)
Entschieden mit Nils am 26.10.2026 auf Grundlage des Plans für 1.7 (ergänzt 10.12).
| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Schnitt in Releases | **1.7.0:** Ähnlichkeit finden, filtern, vergleichen, Verlauf über die Treffer und die vier neuen Rekorde. **1.7.1:** Strecken-Gruppen (eigene Migration) | B-116 bis B-120, B-122 / B-121 |
| Berechnung | Anteil der Route innerhalb 50 m der anderen in beide Richtungen, der kleinere Wert zählt; Raster-Index (50-m-Zellen) für die Vorauswahl, Ergebnisse nur im Speicher, keine gespeicherten Paarwerte. Ein `RouteIndex` existierte bisher nicht (er stand nur im Plan von 1.4) und entsteht in B-116 | ROUTE-01, ROUTE-08 |
| Richtung | Gleiche Richtung heißt: Start- und Zielbereich passen zusammen (Toleranz **200 m**); bei Rundfahrten (Start nahe Ziel) zählt zusätzlich der Umlaufsinn. Nach der ersten Messung an Beispieldaten nachjustieren | ROUTE-01, ROUTE-04 |
| Welche Fahrten zählen | Ohne Beispielfahrt, Papierkorb, Teile zusammengefügter Fahrten und Fahrten ohne GPS; GPX-Fahrten zählen mit; über alle Bikes, der Bike-Filter schränkt zusätzlich ein. Im Verlauf zählen Werte nur von Fahrten, die sie haben („n von m Fahrten“) | ROUTE-03, ROUTE-06 |
| Gruppen | Die Gruppe speichert Name, Schwelle, Gegenrichtung ja/nein und die **Bezugsroute**; die **Mitgliedschaft wird berechnet**, nicht gespeichert. Hin- und Rückweg sind getrennte Gruppen, der Schalter „Auch Gegenrichtung“ holt die Gegenrichtung dazu. Wattspur schlägt Gruppen ab 3 ähnlichen Fahrten vor und legt nichts automatisch an. Keine neue Rubrik in der Seitenleiste: Gruppen als Menü am Ähnlich-Chip, Name im Tour-Detail | ROUTE-07 |
| Rekorde | Vier neue Arten (höchste Leistung, höchste Trittfrequenz, höchste Geschwindigkeit, beste 1-Minuten-Leistung), auch als „Neuer Rekord“ beim Import. Die Maximalwerte nimmt Wattspur aus der Datei; Geschwindigkeit zählt auch aus GPX (5-s-Fenster), Leistung, Trittfrequenz und 1-Minuten-Leistung nur, wo die Datei sie enthält. Die 1-Minuten-Leistung wird beim Import berechnet und mit der Fahrt gespeichert, für den Bestand im Hintergrund nachgetragen | ADV-R3, ADV-R2 |
| Oberfläche der Liste | Der Filter „Ähnlich wie“ lebt in `ContentView` (bleibt beim Öffnen einer Fahrt und beim Wechsel der Rubrik) und gilt nur in der Fahrtenliste, nicht in den Listen neben Karte und Analyse. Der Index aller Routen wird beim ersten Suchen im Hintergrund gebaut. Ein Rücksprung-Knopf ist nicht nötig, weil die Liste neben dem Detail stehen bleibt. Die Regler-Schwelle der Einstellungen gilt als Anfangswert eines neuen Filters | ROUTE-02, ROUTE-03 |
| Datenschutz | Alles lokal; Routen und Gruppen-Namen kommen weder in den Diagnosebericht noch in PDF- oder GPX-Export. Testdaten nur Beispielfahrt, anonymisierte Varianten oder synthetische Routen (NFR-01, NFR-12) | NFR-01 |
| Mit in 1.7 | B-161 (Papierkorb-Knopf) und B-174 (Bike-Symbol in der Liste) als eigene PRs vor dem Release; B-175 (gemeinsame Bike-Auswahl, vorher B-159) und B-067 bleiben draußen | Backlog |
