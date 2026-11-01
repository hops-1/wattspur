# Spike: Daten von roadcurvature.com für Wattspur

Backlog-Aufgabe **V-13**, Voraussetzung für **B-182** und **B-183** (Ebene „Kurvige Straßen“).
Stand: 31.10.2026. Geladen am selben Tag mit Freigabe von Nils: `hessen.c_300.kmz` und `hessen.c_1000.kmz` von `kml.roadcurvature.com/europe/germany/`. Die Dateien liegen nicht im Repository.

## Kurzfassung

- **Das Einlesen ist unkritisch.** Hessen `c_300` (85,7 MB KML, 14 049 Straßen, 704 320 Punkte) liest `XMLParser` im Streaming in **0,54 s**, `c_1000` in 0,2 s (Messung mit `-O` auf diesem Mac, nur Zählen, ohne Speichern).
- **`c_300` enthält `c_1000` vollständig** (alle 1 137 Straßen von `c_1000` stehen auch in `c_300`, mit gleicher Kurvigkeit). Für die Ebene reicht **eine** Datei je Region: `c_300`; die Farbstufe (ab 300 orange, ab 1000 rot) folgt aus dem Wert. `c_1000.curves` (einzelne Kurven) wird nicht gebraucht.
- **KMZ entpacken ohne Fremdbibliothek:** ZIP mit zwei Einträgen (`<region>/doc.kml`, Methode *deflate*, und `images/legend.png`). Wattspur ist **sandboxed**; ein Aufruf von `ditto` per `Process` ist deshalb keine Grundlage. Stattdessen ein kleiner eigener ZIP-Leser (zentrales Verzeichnis lesen, *stored* und *deflate*) mit dem Framework `Compression` (`COMPRESSION_ZLIB` liest rohes Deflate). Das läuft auch auf iOS.
- **Größen:** Hessen gepackt 10,0 MB (`c_300`) und 3,7 MB (`c_1000`), entpackt 85,7 und 27,6 MB. Bayern gepackt 27 MB, entpackt voraussichtlich über 250 MB: das KML wird nicht im Speicher gehalten, sondern in eine temporäre Datei entpackt und von dort gelesen.
- **Darstellung:** 14 049 Linien mit 704 000 Punkten bleiben als Datenbestand klein (rund 6 MB als Binärdatei mit `Float`-Koordinaten); gezeichnet wird nur, was im sichtbaren Ausschnitt liegt (Begrenzungsrahmen je Linie), und erst ab Zoom auf Landkreis-Ebene.
- **Frische:** Die Dateien tragen den Stand **22.11.2024**; die Daten sind also fast zwei Jahre alt.

## Ergebnis des Umsetzens (B-182)

Mit dem fertigen Leser (`ZipArchive`, `CurvyRoads.read`, Regionsdatei) an den echten Dateien, `-O`, auf diesem Mac:

| Datei | Straßen | Punkte | Lesen mit Entpacken | Regionsdatei |
|---|---|---|---|---|
| `hessen.c_300.kmz` | 13 844 | 697 615 | 1,8 s | 6,0 MB |
| `hessen.c_1000.kmz` | 1 135 | 282 167 | 0,7 s | 2,3 MB |

Gegenüber dem Zählen oben fehlen 205 Straßen: Autobahnen und Auffahrten (`motorway`, `motorway_link`) lässt der Leser aus. Die Regionsdatei hält `Float`-Koordinaten (rund einen halben Meter genau) und lädt in 0,03 s.

## Aufbau der KML-Datei

```
<Document>
  <description>… © OpenStreetMap contributors, ODbL …</description>
  <Style id="paved435"> … Linienfarbe und -breite je Stufe … </Style> (viele)
  <ScreenOverlay> … legend.png … </ScreenOverlay>
  <Folder><name>Roads</name>
    <Placemark>
      <styleUrl>#paved435</styleUrl>            paved | unpaved | unknown + Stufe
      <name>Nibelungenstraße (B 47)</name>
      <description><![CDATA[ … Curvature: 8878.77<br/>Distance: 20.45 km<br/>Type: primary<br/>Surface: asphalt, unknown<br/> … ]]></description>
      <LineString><coordinates>8.618522,49.682062 8.618644,49.682138 …</coordinates></LineString>
    </Placemark>
```

- Je Straße **eine** `LineString` (keine `MultiGeometry`), bis 1 134 Punkte; Koordinaten **`Länge,Breite`**, Leerzeichen zwischen den Punkten, keine Höhe.
- Kurvigkeit und Länge stehen **nur im Text** der Beschreibung (`Curvature: …`, `Distance: … km`), die Straßenklasse als `Type: …`, der Belag als `Surface: …`. Der Stil sagt nur Belag und Stufe aus.
- `<description>` enthält Tabellen und Links zu OSM und JOSM; sie werden nicht übernommen.
- Hessen `c_300`: Kurvigkeit 300 bis 8 879, davon 12 912 Straßen zwischen 300 und 1000 und 1 137 ab 1000; Belag 8 855 *paved*, 4 997 *unknown*, 197 *unpaved*; Gesamtlänge 16 791 km.
- Klassen (`Type`): vor allem `residential` (7 643), `service` (2 137), `tertiary` (1 275), `unclassified` (897), `secondary` (816), `motorway_link` (204), `primary` (138). **Für Radfahrer unbrauchbar sind `motorway` und `motorway_link`;** sie werden beim Import ausgelassen.
- Umfang Hessen: Länge 7,77 bis 10,25 Grad, Breite 49,39 bis 51,66 Grad.

## Folgerungen für B-182 und B-183

1. Eine Region ist eine `c_300`-Datei; Import ersetzt die Region mit gleichem Namen.
2. Gespeichert wird je Straße: Name, Kurvigkeit, Länge, Linie und Begrenzungsrahmen, in einer eigenen Binärdatei im Application-Support-Ordner (nicht in SwiftData, die Datenmenge ist Referenzmaterial, kein Fahrtbestand).
3. Grenzen beim Einlesen: entpackt höchstens 600 MB, höchstens 5 Millionen Punkte und 200 000 Straßen; fremde KML-Dateien (ohne `Curvature:` im Text) werden abgewiesen.
4. Quellenangabe auf der Karte und im PDF: „© OpenStreetMap-Mitwirkende, roadcurvature.com“ (ODbL, Share-Alike deshalb: Daten nicht mitliefern, der Nutzer lädt sie selbst).
