# 28 – Kartenstile, Kalendertag als Filter und Austauschformate

Stories: B-061, B-130, B-177 (Plan: REQUIREMENTS.md 10.20, Recherche: [RECHERCHE-KARTEN.md](../RECHERCHE-KARTEN.md))

## Was gebaut wurde
- **`TileSource`** und **`TileMath`** (Core, `Map/`): drei Kachelserver (OpenStreetMap, CyclOSM, OpenTopoMap) mit Adresse, höchstem Zoom und Quellenangabe; dazu die Rechnung in Web Mercator: welche Kachel einen Punkt enthält, welcher Zoom zu einer Bildbreite passt, welche Kacheln einen Ausschnitt bedecken und wo ein Punkt im Bild liegt.
- **Kacheln auf der Karte** (App, `MapTiles.swift`): `CachingTileOverlay` ersetzt Apples Karte durch die Kacheln, `TileLoader` lädt sie mit eigenem User-Agent über einen Cache auf der Platte, `MutedTileRenderer` zeichnet sie heller. `MKMapView.show(_:)` stellt Kartentyp und Kacheln für alle drei Karten an einer Stelle ein.
- **Fenster „Karte anpassen“** (`MapCustomizePopover.swift`, `MapStyleThumbnail.swift`): die Kartentypen als gezeichnete Bildchen nach dem Vorbild komoot; auf der Karte aller Fahrten auch Linien und Wärmekarte, die sich mit einem zweiten Klick ausblenden lassen.
- **Vergleichskarte** als `MKMapView` statt SwiftUI-`Map`, damit sie Kacheln zeigen kann.
- **PDF mit Kacheln** (`MapBackdrop.swift`): Das Kartenbild unter den Routen kommt entweder von Apples Schnappschuss oder wird aus Kacheln zusammengesetzt.
- **Kalendertag als Filter** (`RideDayFilter` im Core, Chip in der Liste): Ein Tag oder eine Serie aus den Highlights zeigt nur diese Fahrten.
- **Austauschformate** (`docs/reference/`): Referenzseite zu GPX-Export und Backup, ein Python-Skript und ein Test, der die Seite mit einem frischen Backup vergleicht.

## Warum so
- **Erst die Regeln, dann der Code:** Freie Kachelserver werden von Freiwilligen betrieben. Wer sie nutzt, nennt sich (User-Agent), zeigt die Quelle, hält sich an die Cache-Zeiten und lädt nichts auf Vorrat. Deshalb kam die Recherche (V-04) vor dem ersten PR, und es gibt bewusst keinen Offline-Download.
- **Die Rechnung ins Kit:** Kachelnummern und Positionen sind reine Mathematik und lassen sich ohne Oberfläche testen. Die App braucht sie zweimal: einmal nur für die Adresse, einmal für das PDF.
- **Das PDF setzt die Kacheln selbst zusammen:** `MKMapSnapshotter` zeichnet nur Apples Karte, keine Overlays. Die Kacheln kommen deshalb über denselben Lader und Cache wie die Karte, und die Position der Routen rechnet `TileMath` von oben gezählt, wie die PDFs zeichnen. Fehlt eine Kachel, nimmt das PDF lieber Apples Karte als ein Bild mit Löchern.
- **Kacheln über den Beschriftungen:** Apple zeichnet seine Ortsnamen über der Ebene „über den Straßen“, auch wenn Kacheln die Karte ersetzen. So standen Orte doppelt da (gefunden beim Test). Kacheln und eigene Overlays liegen bei OSM-Stilen deshalb über den Beschriftungen.
- **Heller zeichnen:** Die OSM-Karten sind farbiger als Apples gedämpfte Karte; die Routen gingen darin unter. Ein Schleier im Renderer nimmt Farbe heraus, ohne die Kacheln zu verändern, und das PDF nimmt dieselben Werte.
- **Bildchen zeichnen statt fotografieren:** Gezeichnete Bildchen sind in jeder Größe scharf, passen zu hell und dunkel und brauchen weder Netz noch Lizenz.
- **Ausblenden ist ein eigener Schalter:** „Fahrten zeigen“ ist getrennt von „Linien oder Wärmekarte“ gespeichert. So bleibt die Wahl erhalten, und eine markierte Fahrt kann trotzdem erscheinen (Wunsch beim Test).
- **Einpassen, wenn Routen da sind:** Der Vergleich lädt die Routen erst nach dem ersten Aufbau. Die Karte passt sich deshalb an, sobald sich ändert, *welche Fahrten eine Route haben*, nicht nur, welche Fahrten verglichen werden.
- **Tagesfilter über den anderen Filtern:** Wer einen Tag im Kalender anklickt, will dessen Fahrten sehen. Stünde die Liste auf „Monat“ oder einem anderen Bike, fehlten sonst Fahrten.
- **Doku, die sich selbst prüft:** Das Schema der Datenbank erzeugt SwiftData. Ein Test legt ein Backup an und vergleicht die Seite in beide Richtungen; eine neue Spalte ohne Doku fällt sofort auf.

## Swift-Konzepte
- **`MKTileOverlay` als Unterklasse:** `url(forTilePath:)` liefert die Adresse, `loadTile(at:result:)` lädt selbst (hier mit `async`/`await` in einem `Task`) und kann über dem höchsten Zoom den passenden Teil einer gröberen Kachel vergrößern. `canReplaceMapContent` ersetzt Apples Karte.
- **`URLCache` mit eigenem Ordner** und `.useProtocolCachePolicy`: Die Server sagen per HTTP, wie lange eine Kachel gilt. Ohne Netz liefert `.returnCacheDataDontLoad` eine schon gesehene Kachel.
- **`withTaskGroup`** lädt die Kacheln eines PDF-Bildes parallel; `reduce(into:)` sammelt die Ergebnisse.
- **SwiftUI `Canvas`** zeichnet mit `GraphicsContext` Pfade, Strichmuster, Verläufe und Weichzeichner, ganz ohne Bilddateien.
- **Mischmodus `.saturation`:** Eine graue Fläche in diesem Modus nimmt den Farben darunter die Sättigung, ohne die Helligkeit zu ändern.
- **`Date.IntervalFormatStyle`** schreibt Zeiträume lokalisiert („3.–9. Okt.“, „Oct 3 – 9“), ohne eigenes Format.
- **Absturzberichte lesen:** Die Kit-Tests stürzten im parallelen Lauf ab. Der Bericht unter `~/Library/Logs/DiagnosticReports` zeigte den Autosave-Timer von SwiftData, der nach dem Freigeben des Containers feuerte. Tests, die selbst speichern, schalten `autosaveEnabled` deshalb aus.

**Begriffe, die oft vorkommen**
- **Kachel (Tile):** ein Bild von 256 × 256 Pixeln. Bei Zoom z ist die Welt 2^z × 2^z Kacheln groß; jede hat eine Adresse aus Zoom, Spalte und Zeile.
- **Web Mercator:** die Projektion fast aller Online-Karten. Die Welt ist ein Quadrat, Norden oben; Positionen darin sind linear, deshalb lässt sich ein Punkt einfach in ein Bild umrechnen.
- **Schummerung:** Schatten, die ein Licht von Nordwesten auf das Gelände wirft, damit Berge und Täler plastisch wirken.
