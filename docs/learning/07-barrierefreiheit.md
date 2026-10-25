# 07 – Barrierefreiheit: VoiceOver, Audio Graphs, Tastatur, Kontraste

Story: B-025 (NFR-16)

## Was geprüft und gebaut wurde
- **Audio Graphs** (`App/ChartAccessibility.swift`): Alle Diagramme geben VoiceOver eine Beschreibung ihrer Achsen und Datenreihen. VoiceOver kann ein Diagramm dann als Ton abspielen, der mit den Werten steigt und fällt, und Punkt für Punkt vorlesen.
  - Tour-Detail: Höhe, Geschwindigkeit, Trittfrequenz und Leistung über die Strecke. Gelesen werden höchstens etwa 200 Punkte, damit das Durchblättern erträglich bleibt.
  - Auswertung: das Balkendiagramm mit dem Zeitraum als Kategorie und je Trend zwei Reihen, „Je Fahrt“ und „Ø 5 Fahrten“.
- **VoiceOver-Beschriftungen**:
  - Eine Zeile der Fahrtenliste ist ein einziges Element mit Name, Datum, Zeit, Strecke und Tempo.
  - Die Knöpfe der Seitenleiste haben auch im Symbolmodus einen Namen. Der Papierkorb sagt zusätzlich, wie viele Fahrten darin liegen.
  - Die Max- und Ø-Werte über den Tour-Diagrammen werden als Paar gelesen, also zum Beispiel „Max 54,5 km/h“.
- **Tastatur**:
  - ⌘1, ⌘2 und ⌘3 wechseln zwischen Fahrten, Auswertung und Papierkorb.
  - Das Balkendiagramm lässt sich mit Tab fokussieren, dann wählen ← und → den Balken. Bisher ging das nur mit der Maus.
- **Kontraste**:
  - Nicht gewählte Balken hatten nur 1,5 : 1 gegen den Hintergrund. Die neue Farbe `chartInactive` erreicht hell 3,6 : 1 und dunkel 4,0 : 1. WCAG verlangt für Grafiken mindestens 3 : 1.
  - Die vier Kennzahl-Farben liegen hell zwischen 4,9 und 5,5 : 1 und dunkel zwischen 6,1 und 7,1 : 1.
- **Farbe nie allein**: Die Änderung zum Vorzeitraum zeigt Pfeil und Vorzeichen, das gab es schon. Neu: Nur der Pfeil ist eingefärbt, die Zahl steht in normaler Textfarbe, denn die Akzentfarbe hätte als kleiner Text nur 4,0 : 1 erreicht (WCAG: 4,5 : 1). Start und Ziel auf der Karte haben eine Beschriftung.

## Warum so
- **Audio Graphs statt nur einer Zusammenfassung**: Ein Text wie „Leistung von 80 bis 460 W“ sagt nichts über den Verlauf, also wo der Anstieg war. Den hört man im Audio Graph sofort. Das Trenddiagramm behält zusätzlich seinen kurzen Text („12 Fahrten, gleitendes Mittel von 128 auf 141 W“).
- **⌘1 bis ⌘3**: Die Seitenleiste ist eine eigene Ansicht (siehe 04). Ihre Knöpfe erreicht man mit Tab nur, wenn in den Systemeinstellungen „Tastaturnavigation“ eingeschaltet ist. Kurzbefehle funktionieren immer und sind auf dem Mac üblich, Mail und Finder machen es genauso.
- **Höchstens 200 Punkte**: Eine Fahrt hat etwa 3 000 Sekundenwerte. Für das Hören des Verlaufs reicht jeder 15. Wert, und beim Weiterblättern muss man dann nicht 3 000-mal tippen.

## Swift-Konzepte
- **`AXChartDescriptorRepresentable`** (Framework `Accessibility`): ein Protokoll mit `makeChartDescriptor()`. Darin baut man einen `AXChartDescriptor` aus Achsen (`AXNumericDataAxisDescriptor`, `AXCategoricalDataAxisDescriptor`) und Reihen (`AXDataSeriesDescriptor` mit `AXDataPoint`). SwiftUI hängt ihn mit `.accessibilityChartDescriptor(_:)` an das Diagramm.
- **`LocalizedStringResource`** statt `LocalizedStringKey`: Ein Titel wird hier zweimal gebraucht, als `Text(title)` und als echter `String` für VoiceOver (`String(localized: title)`). Aus einem `LocalizedStringKey` kommt man nicht an den übersetzten Text, aus einer Resource schon.
- **`.focusable()` + `.onKeyPress(.leftArrow)`**: Damit kann eine beliebige Ansicht den Tastaturfokus bekommen und auf Tasten reagieren. Gibt die Funktion `.ignored` zurück, landet der Tastendruck beim Nächsten in der Kette, zum Beispiel am Rand des Diagramms.
- **`.accessibilityElement(children: .combine)`**: macht aus mehreren Texten ein VoiceOver-Element.

## Zum Ausprobieren
1. VoiceOver mit ⌘F5 einschalten (oder dreimal Touch ID drücken).
2. In der Fahrtenliste mit ⌃⌥→ durch die Zeilen gehen: Jede Zeile wird als ein Satz gelesen.
3. In einer Fahrt auf ein Diagramm gehen und ⌃⌥⇧A drücken. Das öffnet das Diagramm-Menü mit „Audio-Grafik abspielen“.
4. In der Auswertung das Balkendiagramm mit Tab fokussieren und mit ← und → den Balken wechseln. Die Zeile darüber zeigt den gewählten Zeitraum.
5. ⌘1, ⌘2 und ⌘3 drücken, auch bei eingeklappter Seitenleiste.
