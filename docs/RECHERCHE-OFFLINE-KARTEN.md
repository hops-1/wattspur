# Recherche: Offline-Karten am iPhone

Backlog-Aufgabe **V-17**, Voraussetzung für **B-303** (Offline-Karte beim Start der Aufnahme anbieten).
Stand der Recherche: 11.11.2026. Grundlage sind öffentliche Seiten der Anbieter. Einiges davon kommt nur aus Berichten Dritter; das ist unten markiert. Das ist keine Rechtsberatung.

## Kurzfassung

- **Die heutigen Server gehen nicht.** OpenStreetMap, CyclOSM und OpenTopoMap verbieten es, Gebiete vorab herunterzuladen ([RECHERCHE-KARTEN.md](RECHERCHE-KARTEN.md)).
- **Apple geht nicht.** Die Karten-App von Apple kann offline arbeiten. Fremde Apps bekommen diese Daten aber nicht. MapKit hat keine Schnittstelle zum Herunterladen.
- **Rasterkacheln sind für 250 km zu groß.** Bis Zoomstufe 15 wären das etwa 8 GB, bis Stufe 14 etwa 2 GB (Rechnung unten).
- **Empfehlung: eine offene Vektorkarte (Protomaps, angezeigt mit MapLibre) auf eigenem Speicher.** Der Radius von 50 km braucht etwa 30 MB, 250 km etwa 0,7 bis 1 GB. Für die Daten fällt keine Lizenzgebühr an. Der Speicher kostet wenige Euro im Monat. Die Kosten für die App: eine zweite Kartentechnik, aber nur für die Karte bei der Aufnahme (Entscheidung Nils).
- **Wenn es schnell gehen soll und Geld kosten darf:** Thunderforest. Ab dem Tarif „Small Business“ ist das Herunterladen ganzer Gebiete erlaubt. MapKit bleibt, wie es ist. Weil das Rasterkacheln sind, gehen aber nur rund 100 km sinnvoll, nicht 250 km.

## Wie groß ist ein Gebiet?

Diese Rechnung ist für Deutschland gemacht (Breite 50°). Bei Zoomstufe 14 ist eine Kachel dort etwa 1,6 × 1,6 km groß, bei Stufe 15 etwa 0,8 × 0,8 km. Alle Stufen darüber zusammen kosten noch einmal ein Drittel dazu.

| Radius | Fläche | Raster bis z14 | Raster bis z15 | Vektor (Protomaps) |
|---|---|---|---|---|
| 50 km | 7 900 km² | ≈ 4 000 Kacheln, ≈ 85 MB | ≈ 17 000 Kacheln, ≈ 340 MB | ≈ 30 MB |
| 100 km | 31 000 km² | ≈ 17 000 Kacheln, ≈ 340 MB | ≈ 1,4 GB | ≈ 120 MB |
| 250 km | 196 000 km² | ≈ 2,1 GB | ≈ 8 GB | ≈ 0,7 bis 1 GB |

Für Rasterkacheln ist der Wert etwa 20 KB je Kachel geschätzt; auf dem Land sind es weniger. Für den Vektorwert sind etwa 4 KB je km² in Mitteleuropa geschätzt; in der Stadt ist es mehr, auf dem Land weniger. Beides ist noch an einem echten Auszug zu messen.

## Die Möglichkeiten

### A) Protomaps-Vektorkarte auf eigenem Speicher (Empfehlung)

- **Daten:** Protomaps baut jeden Tag die ganze Welt als eine einzige Datei (PMTiles, gut 120 GB). Lizenz: ODbL als „Produced Work“. Pflicht ist die Quellenangabe „© OpenStreetMap“.
- **Regeln:** Protomaps bittet darum, die Datei auf eigenen Speicher zu kopieren und nicht direkt von ihrem Build-Server zu laden. Die Adressen dort ändern sich, und ältere Builds werden gelöscht.
- **Speicher:** zum Beispiel Cloudflare R2. Der Speicher kostet etwa 1,5 Cent je GB und Monat, Herunterladen ist frei. Für die ganze Welt sind das etwa 2 $ im Monat. Ein Auszug nur für Europa wäre kleiner. Einen Vertrag muss Nils abschließen.
- **Ausschnitt am iPhone:** PMTiles ist so gebaut, dass man nur einzelne Teile der Datei laden kann. Die App lädt das Verzeichnis und dann nur die Kacheln im Kreis. Einen Server mit Programmen braucht es dafür nicht.
- **Anzeige:** MapLibre Native für iOS (BSD-Lizenz, Swift Package). Neu wäre das nur in der Karte bei der Aufnahme. Route, Standort und Kurven müssen dort neu gezeichnet werden. Ob MapLibre PMTiles direkt lesen kann oder ob die App die Kacheln in einen eigenen Offline-Speicher schreibt, prüft ein kurzer Spike.
- **Aussehen:** Protomaps bringt Stile mit (hell, dunkel, „grayscale“). Höhenlinien wie bei OpenTopoMap und Radwege wie bei CyclOSM gibt es dort nicht.
- **Aufwand:** groß (L). Dafür ist es dauerhaft günstig und hängt an keinem Anbieter.

### B) Thunderforest (Raster, kommerziell)

- Laut den Bedingungen ist es ab dem Tarif „Small Business“ erlaubt, Gebiete vorab zu laden. Die Kacheln dürfen auf dem Gerät länger liegen, als die Server sagen. Weitergeben an andere ist verboten. Die Quellenangabe muss bleiben.
- Der Stil „OpenCycleMap“ zeigt Radwege und Höhenlinien.
- Die App bleibt bei MapKit. `CachingTileOverlay` liest die Kacheln dann aus einem eigenen Ordner. Der Aufwand ist mittel (M).
- Nachteile: Es kostet monatlich (Preis bei Thunderforest nachsehen), die App braucht einen API-Schlüssel, und es sind Rasterkacheln. Der Schieber müsste dann bei etwa 100 km enden.

### C) MapTiler

- Das neue mobile SDK (September 2026) soll Offline-Pakete bekommen, sie sind aber noch nicht fertig. Offline-Nutzung läuft laut Berichten Dritter über Enterprise-Angebote auf Anfrage.
- **Heute nicht empfohlen.** In einem halben Jahr neu ansehen.

### D) Mapbox

- Kann offline, aber die heruntergeladenen Kacheln werden bezahlt. Offline-Gebiete darf man nicht weitergeben. Dazu kommen ein eigenes SDK und ein Konto. Es passt nicht zu einer kleinen App ohne Einnahmen.

### E) OpenFreeMap

- Freie Vektorkacheln ohne Schlüssel. Die Bedingungen sagen nichts über Offline-Nutzung oder Herunterladen. Ohne eine Antwort des Betreibers ist das zu unsicher. Es gibt die Daten auch als Datei für den eigenen Server, aber die ist größer und schwerer zu betreiben als PMTiles.

## Entscheidung

Nils, 11.11.2026: Offline-Karten werden eine Bezahl-Funktion, ein **Einmalkauf** (B-304). Ein Einmalkauf verträgt keine Kosten je Nutzer und Monat. Darum gilt **Möglichkeit A** (Protomaps auf eigenem Speicher). Ein Gebiet bis 50 km ist ohne Kauf frei, also etwa 30 MB je Nutzer.

## Offene Fragen an Nils

1. Legst du ein Konto bei einem Speicher-Anbieter an, zum Beispiel Cloudflare R2? Die Zugangsdaten bleiben bei dir.
2. Reicht ein Auszug für Europa? Er ist kleiner und billiger, deckt aber Reisen außerhalb Europas nicht ab.

## Quellen

- [Tile Usage Policy der OSM Foundation](https://operations.osmfoundation.org/policies/tiles/)
- [Apple Developer Forums: Offline Maps for App via MapKit](https://developer.apple.com/forums/thread/765857)
- [Protomaps: Basemap Downloads](https://docs.protomaps.com/basemaps/downloads), [Getting Started](https://docs.protomaps.com/guide/getting-started), [Blog: Open Core to Open Source](https://protomaps.com/blog/open-core-to-open-source/)
- [MapLibre Native für iOS (Swift Package)](https://swiftpackageregistry.com/maplibre/maplibre-gl-native-distribution)
- [Thunderforest: Terms](https://www.thunderforest.com/terms/), [Pricing](https://thunderforest.com/pricing)
- [MapTiler: SDK for Mobile (September 2026)](https://www.maptiler.com/news/2026/09/maptiler-sdk-for-mobile-native-maps-for-ios-and-android/), [G2: MapTiler Pricing](https://www.g2.com/products/maptiler/pricing) (Dritte)
- [Mapbox: Offline (iOS)](https://docs.mapbox.com/ios/legacy/maps/guides/offline/), [Pricing](https://docs.mapbox.com/ios/legacy/maps/guides/pricing/)
- [OpenFreeMap: Terms of Service](https://openfreemap.org/tos/), [Projekt](https://openfreemap.org)
