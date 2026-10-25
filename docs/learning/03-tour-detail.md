# 03 – Tour-Detail: Karte, Diagramme, Formatierung

## Was
`RideDetailView` zeigt Titel, Karte (`RideMapView`), Kennzahlen, aufklappbare Details und vier Diagramme (`RideChartsView`).

## Daten vorbereiten (`Ride/RideSeries.swift`)
- **Diagramme**: 3000 Punkte sind mehr, als ein 800-pt-Diagramm darstellen kann. `chartPoints` teilt die Strecke in 400 gleich lange Abschnitte und mittelt darin. Ergebnis: ruhige Linien und flüssiges Zeichnen.
- **Karte**: `route` dünnt auf höchstens 1500 Punkte aus, Start und Ziel bleiben erhalten.
- Beides passiert einmal pro Fahrt in `.task(id: ride.id)`, nicht bei jedem Neuzeichnen.

## Karte (MapKit für SwiftUI)
- `Map { MapPolyline(...) Annotation(...) }`: Inhalte werden wie Views beschrieben.
- Die Route ist zweimal gezeichnet, weiß und breit darunter, farbig darüber. So hebt sie sich von jeder Karte ab.
- Liegen Start und Ziel näher als 100 m beieinander, gilt die Fahrt als Rundfahrt mit einem gemeinsamen Punkt „Start & Ziel“.
- Der Kartentyp liegt in `@AppStorage("mapType")`, bleibt also über Neustarts erhalten.

## Diagramme (Swift Charts)
- `Chart(points) { AreaMark(...); LineMark(...) }` beschreibt die Diagrammteile; Achsen und Raster erzeugt Swift Charts.
- **Fehler aus dem Review:** `AreaMark(y:)` füllt immer bis 0. Beim Höhenprofil beginnt die Achse aber bei ~130 m, also ragte die Fläche unter das Diagramm. Die Lösung `AreaMark(yStart: unterkante, yEnd: wert)` und `.chartPlotStyle { $0.clipped() }`.
- Farben passen sich an Hell/Dunkel an (`Color.adaptive` mit `NSColor`-Provider).
- Swift Charts liefert VoiceOver-„Audio Graphs“ automatisch mit (NFR-16).

## Formatierung (`App/RideFormat.swift`)
Zahlen und Daten nie selbst zusammenbauen, sondern über **FormatStyle**: `(19.543).formatted(.number.precision(.fractionLength(1)))` ergibt „19.5“ auf Englisch und „19,5“ auf Deutsch. `Duration.seconds(2916).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2)))` ergibt „00:48:36“.

## Swift-Konzepte
- **KeyPaths** (`\.altitude`, `\.speedKmh`): Ein `ChartCard` funktioniert für jede Kennzahl, weil man ihm sagt, *welches* Feld es zeigen soll.
- **`@Query` mit dynamischem Filter** im `init` von `RideDetailView`: lädt genau die eine Fahrt und reagiert auf Umbenennen.
- **`.overlay(alignment:)`**: Der Kartentyp-Umschalter schwebt oben rechts über der Karte.
