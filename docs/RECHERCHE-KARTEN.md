# Recherche: Kartenstile aus OpenStreetMap für Wattspur

Backlog-Aufgabe **V-04**, Voraussetzung für **B-061** (MAP-02, NFR-08). Entscheidung in [REQUIREMENTS.md](REQUIREMENTS.md) Kap. 10.20.
Stand der Recherche: 27.10.2026, aus den öffentlichen Nutzungsbedingungen der Anbieter.

## Kurzfassung

- **Ja, Wattspur darf OpenStreetMap, CyclOSM und OpenTopoMap nutzen.** Alle drei erlauben Apps das interaktive Ansehen ihrer Kacheln ohne Schlüssel und ohne Gebühr, wenn die App sich an ein paar Regeln hält.
- **Höhenlinien und Schummerung gibt es nur bei OpenTopoMap.** OpenStreetMap Standard hat kein Relief. Apple MapKit bietet über die Schnittstelle keinen Stil mit Höhenlinien.
- **Pflichten für die App:** eigener User-Agent, sichtbare Quellenangabe auf der Karte (und im PDF), Cache nach den HTTP-Headern, **kein** Vorabladen und keine Offline-Pakete.
- **Grenzen:** keine Verfügbarkeitsgarantie, die Server können Apps sperren, die sich nicht an die Regeln halten oder zu viel laden. Für einen kleinen Kreis von Nutzern ist das unkritisch; für den App Store mit vielen Nutzern wäre ein kommerzieller Anbieter (z. B. MapTiler, Thunderforest) neu zu prüfen.

## Die Anbieter im Einzelnen

### OpenStreetMap Standard (`tile.openstreetmap.org`)
Quelle: [Tile Usage Policy der OSM Foundation](https://operations.osmfoundation.org/policies/tiles/).
- Erlaubt: interaktives Ansehen, nur die Kacheln des sichtbaren Ausschnitts, dazu zwischengespeicherte Kacheln.
- User-Agent: eindeutig, mit App-Namen, gern mit Kontakt-URL; die Versionsnummer darf sich ändern. Allgemeine Bibliotheks-Kennungen werden gesperrt.
- Quellenangabe: „© OpenStreetMap contributors“ deutlich auf der Karte, üblicherweise unten rechts, nicht hinter einem Schalter.
- Cache: `Cache-Control`, `Expires` und `ETag` beachten; wo das nicht geht, mindestens 7 Tage halten.
- Verboten: Vorabladen, Gebiete herunterladen, Offline-Funktionen, HTTP statt HTTPS.
- Kein Relief.

### OpenTopoMap (`{a,b,c}.tile.opentopomap.org`)
Quelle: [opentopomap.org/about](https://opentopomap.org/about).
- Lizenz CC-BY-SA, Nutzung frei, auch kommerziell, solange der Server nicht überlastet wird (z. B. durch Massen-Downloads). Keine Verfügbarkeitsgarantie.
- Quellenangabe deutlich sichtbar: „Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | Kartendarstellung: © OpenTopoMap (CC-BY-SA)“.
- Die Betreiber freuen sich über eine kurze Nachricht, wo die Karte genutzt wird (Aufgabe für Nils, keine Pflicht).
- Höhenlinien und Schummerung sind eingebaut. Höchste Zoomstufe 17.

### CyclOSM (`{a,b,c}.tile-cyclosm.openstreetmap.fr/cyclosm`)
Quelle: [cyclosm.org](https://cyclosm.org/).
- Server von OpenStreetMap France, „fair use“; es gelten sinngemäß die OSM-Regeln oben.
- Quellenangabe: „© OpenStreetMap contributors · CyclOSM · Kacheln von OpenStreetMap France“.
- Die Adresse hat sich in der Vergangenheit geändert; sie steht deshalb an genau einer Stelle im Code (`TileSource`).

## Folgen für die Umsetzung (B-061)

| Regel | Umsetzung in Wattspur |
|---|---|
| User-Agent | `Wattspur/<Version> (+Projektseite auf GitHub)` an jeder Kachelanfrage |
| Quellenangabe | Etikett unten rechts auf jeder Karte mit diesen Kacheln, auch im PDF; nicht abschaltbar |
| Cache | eigener `URLCache` auf der Platte, Standard-Policy beachtet die Header |
| Kein Vorabladen | nur Kacheln des sichtbaren Ausschnitts bzw. des PDF-Ausschnitts; kein Offline-Paket (MAP-03 bleibt für diese Server ausgeschlossen) |
| Zoom | höchste Stufe je Anbieter, darüber vergrößert MapKit die letzte Stufe |
| Ohne Netz | schon gesehene Kacheln aus dem Cache; PDF fällt ohne Kacheln auf Apple Standard zurück |
