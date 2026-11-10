# Design: Wattspur auf dem iPad

Stand: 10.11.2026 · Entwurf, abgestimmt mit Nils · Stories B-291 bis B-297 in `BACKLOG.md`

## Warum

Nils wünscht sich eine iPad-App (10.11.2026). Sie soll alles können, was die Mac-App kann, und dazu GPS-Aufnahmen machen wie das iPhone. Viele Leute haben im Fahrzeug ein iPad, besonders im Camper.

## Entscheidungen von Nils (10.11.2026)

- Das iPad kommt **in Stufen**:
  - **iPad 1:** die iPhone-App im iPad-Layout, mit GPS-Aufnahme;
  - **iPad 2:** die Funktionen der Mac-App.
- Das iPad kommt **nach den Sportarten** (B-284 bis B-290, `DESIGN-SPORTARTEN.md`). So bekommt es den Umschalter für die Sportart gleich mit, und die Seitenleiste wird nur einmal gebaut.

## Weg: eine App für iPhone und iPad

- Es gibt kein eigenes iPad-Target und kein Mac Catalyst.
  - Das Target `Wattspur iOS` und die Widgets bekommen die Gerätefamilie „1,2“. Heute steht dort „1“ (`project.yml`).
  - Die Mac-App bleibt wie sie ist. 22 ihrer 81 Dateien nutzen AppKit, das iPad kann sie also nicht direkt übernehmen.
- Gemeinsam genutzt werden die Pakete:
  - `WattspurCore`;
  - `WattspurKit` mit Speicher, iCloud-Sync und dem gemeinsamen Import (B-188);
  - `WattspurMap` mit den Karten ohne AppKit (B-186).

## Layout

**Kompaktes Format** (iPhone, oder iPad im schmalen Split View): wie heute, mit vier Tabs.

**Weites Format** (iPad im Vollbild oder als großes Fenster): eine `NavigationSplitView` wie am Mac.
- **Seitenleiste:**
  - oben der Umschalter Rad · Fahrzeuge · Laufen (wie B-288 am Mac);
  - darunter Übersicht, Fahrten, Karte, ab iPad 2 auch Analyse und Highlights;
  - unten Profil (mit den Geräten, B-299), Papierkorb und die Rubriken aus „Mehr“ (B-298).
- **Liste und Detail** stehen nebeneinander, wie am Mac.
- **Detail:** Statt des Karussells zeigt das iPad alle Diagramme in einer Spalte unter der Karte. Dafür ist genug Platz.
- **Übersicht:** Die Kacheln stehen in einem Raster, „Fahrt starten“ bleibt groß.
- Die Ansichten des iPhone werden wiederverwendet. Nur die Anordnung ist neu.
- Das iPad unterstützt alle Ausrichtungen, Split View und Stage Manager.

## GPS-Aufnahme auf dem iPad

- **Nur iPads mit Mobilfunk (Wi-Fi + Cellular) haben einen GPS-Empfänger.** Ein reines WLAN-iPad ortet sich nur grob über WLAN, und unterwegs meist gar nicht.
- Die App prüft darum vor dem Start die Genauigkeit des Standorts:
  - Ist sie gut genug, startet die Aufnahme wie am iPhone.
  - Ist sie schlecht, zeigt die App einen klaren Hinweis: „Dieses iPad hat vermutlich kein GPS. Die Strecke wird ungenau.“ Man kann trotzdem starten.
- Im Handbuch steht, welche iPads geeignet sind.
- **Aufnahme-Ansicht für die Halterung:** im Querformat mit großer Karte, die Werte stehen in einer Spalte rechts daneben. Im Hochformat sieht sie aus wie am iPhone.
- Live-Aktivität und Sperrbildschirm funktionieren wie am iPhone.
- Ist das iPad fest montiert, zeigen die Bewegungssensoren Schräglage oder Querbeschleunigung (B-287).
- Typischer Fall: ein Camper mit iPad am Armaturenbrett, also die Sportart Fahrzeuge mit dem Gerät „Nugget“.

## iPad 2: Funktionen der Mac-App

- **Erst die Logik ins Kit (B-294):** Analyse (`App/Analysis`), Highlights (`App/Highlights`) und Vergleich (`App/Compare`) kommen ohne AppKit ins Paket, mit Tests. So wurde es auch bei den Karten gemacht (B-186).
  - Die Mac-App nutzt danach dieselbe Logik und sieht aus wie vorher. Das prüfen Bilder vorher und nachher.
  - Das deckt auch den Kit-Teil von B-228 (Highlights auf dem iPhone) ab.
- **Dann die Oberflächen in SwiftUI fürs iPad:**
  - Analyse und Highlights mit Swift Charts (B-295);
  - Vergleich und Zusammenführen (B-296);
  - Import, Papierkorb und Export (B-297).
- **Import:** FIT- und GPX-Dateien kommen über die Dateien-App, über „Teilen“ aus anderen Apps und über Drag & Drop. Die App nutzt dafür den gemeinsamen Import (B-188).
- **Export:** PDF und GPX gibt es über das Teilen-Menü.
- **Geräte bearbeiten:** wie am iPhone (B-290).

## Nicht geplant

- eine eigene App nur fürs iPad;
- Mac Catalyst;
- Apple Pencil;
- eine Tastatur-Bedienung über die Standard-Kurzbefehle von iPadOS hinaus.
