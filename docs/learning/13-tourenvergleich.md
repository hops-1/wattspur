# 13 – Tourenvergleich

Stories: B-098 bis B-103 (CMP-01 bis CMP-06), Mockup B-099 („Compare“ auf dem Design-Canvas)

## Was gebaut wurde
- **Einstieg:** Bei 2 bis 4 markierten Fahrten steht in der Mehrfachauswahl der Knopf **Vergleichen** (⇧⌘C), im Kontextmenü „… Fahrten vergleichen“. Bei 5 oder mehr ist der Knopf deaktiviert, darunter steht der Grund.
- **Vergleich rechts neben der Liste:** Die markierte Auswahl ist der Vergleich. ⌘-Klick fügt hinzu, ✕ hebt die Markierung auf, ↗ zeigt nur diese Fahrt, „Fertig“ (Esc) führt zur Auswahl zurück.
- **Reihenfolge:** Karte, Diagramme, Tabelle (Wunsch von Nils beim Testen, 21.10.2026). Die Karte zeigt alle Routen, jede in Farbe und Strichart ihrer Spalte, mit ihrer Form am Start.
- **Tabelle:** eine Spalte je Fahrt, Zeilen in sechs Gruppen. ★ plus getönte Zelle für den besten Wert. Ein Schalter zeigt die Abweichung vom Schnitt und eine Spalte „Ø deiner Fahrten“.
- **Diagramme:** Höhe, Geschwindigkeit, Trittfrequenz und Leistung übereinander, jede Fahrt mit Farbe, Strichart und Form. Über jedem Diagramm stehen die Bosch-Durchschnitte je Fahrt; bei der Höhe stattdessen Anstieg, Abstieg und die steilste Stelle (`RideSeries.steepestGradient`, über mindestens 100 m, damit das Höhenrauschen keine Spitzen erzeugt).
- **PDF-Export überall:** `PDFExport.swift` enthält Seitenaufteilung, Kartenbild, Vorschau/Sichern und den Knopf `PDFExportButton`. Vergleich (`ComparisonPDF.swift`) und Tour-Detail (`RidePDF.swift`) stellen nur noch ihre Seiten zusammen; Highlights und Karte nutzen das später genauso.
- **PDF-Export im Vergleich** (`ComparisonPDF.swift`, ⇧⌘E): Ein Klick öffnet das PDF in Vorschau (aus einem eigenen temporären Ordner, damit ein noch offenes PDF nie überschrieben wird); das Menü daneben bietet „Als PDF sichern …“. Seite 1 mit Karte und Diagrammen, danach die Tabelle, A4 hochkant, immer hell.
- **Rechnen im Kit** (`RideComparison.swift`, 12 Tests): `ComparisonMetric` kennt Wert, Gruppe, „besser“-Richtung und Mittelung jeder Kennzahl.

## Warum so
- **Die Auswahl ist der Vergleich:** kein zweiter Zustand, der mit der Liste auseinanderlaufen kann. Hinzufügen und Entfernen (CMP-06) sind damit einfach Markieren.
- **Stern nur, wo „besser“ eindeutig ist:** Mehr Strecke oder mehr Kalorien sind nicht besser, nur anders. Nils hat vier Kennzahlen festgelegt: Ø Geschwindigkeit, Ø Leistung, Ø Leistung über die Fahrzeit (mehr) und Pausen (weniger). Gleichstand ergibt mehrere Sterne; sind alle gleich, gibt es keinen.
- **Schnitt wie in der Auswertung:** Summen und Höchstwerte als Mittel je Fahrt, Ø-Werte nach Fahrzeit gewichtet, Werte pro km nach Strecke. Ohne Gewichtung würde eine 5-Minuten-Fahrt den Ø-Wert genauso stark ziehen wie eine Tagestour.
- **Rollanteil ohne Zeitreihe:** Bosch bildet die Ø Leistung nur über Sekunden mit Treten, die Arbeit ist die Summe aller Sekunden. Arbeit ÷ Ø Leistung ergibt also die Sekunden mit Treten. Bei der Beispielfahrt: 18,8 % gegenüber 17,9 % beim Auszählen der Samples. Dafür muss nicht für jede Fahrt die Zeitreihe dekodiert werden, und es braucht kein neues Feld im Datenmodell. Bei zusammengefügten Fahrten werden die Sekunden der Teile addiert, weil die Ø Leistung der zusammengefügten Fahrt nur ein gewichtetes Mittel ist.
- **Farbe nie allein (NFR-16):** Blau, Orange, Türkis und Violett unterscheiden sich auch bei Rot-Grün-Schwäche in der Helligkeit. Zusätzlich hat jede Fahrt eine eigene Strichart und Form. Der beste Wert hat einen Stern und fetten Text, nicht nur eine Tönung.

## Swift-Konzepte
- **`enum` mit `CaseIterable` als Tabellenbeschreibung:** Jede Zeile ist ein Fall von `ComparisonMetric`. Die Tabelle läuft über `ComparisonGroup.allCases` und `group.metrics`; kommt eine Kennzahl dazu, zwingt `switch` den Compiler, Wert, Titel, Einheit und Gruppe zu ergänzen.
- **`switch` als Ausdruck mit Closures:** In `average(over:)` liefert `let weight: (ComparisonFigures) -> Double? = switch self { … }` je nach Kennzahl eine andere Gewichtsfunktion.
- **Werte statt Datenbank-Objekte:** `ComparisonFigures` ist ein einfaches `struct`. Die Tests brauchen dafür kein SwiftData; nur `Ride.comparisonFigures` übersetzt.
- **Swift Charts mit mehreren Linien:** `LineMark(…, series: .value("Ride", index))` trennt die Linien. Farbe und Strichart kommen pro Linie aus `ComparisonStyle`.
- **Audio Graph mit mehreren Reihen:** `ComparisonChartDescriptor` gibt VoiceOver eine Datenreihe je Fahrt.
- **Karte mit mehreren Linien:** Je Fahrt zwei `MapPolyline` (weißer Rand, darüber die farbige, gestrichelte Linie). `.id(rides.map(\.id))` erzeugt die Karte neu, wenn sich die Fahrten ändern; so passt `.automatic` den Ausschnitt wieder an alle Routen an.
- **PDF mit `ImageRenderer`:** SwiftUI-Ansichten werden mit `ImageRenderer` in einen PDF-Kontext (`CGContext` mit `mediaBox`) gezeichnet. Die Ansicht wird 900 pt breit gelegt, auf die A4-Breite skaliert und bei Bedarf auf mehrere Seiten verteilt: je Seite verschiebt `translateBy` den sichtbaren Ausschnitt, `clip` schneidet den Rand ab. Eine MapKit-Karte lässt sich so nicht zeichnen; dafür liefert `MKMapSnapshotter` ein Kartenbild, auf das die Routen mit `NSBezierPath` gemalt werden (`snapshot.point(for:)` rechnet Koordinaten in Bildpunkte um).
- **`.task(id:)`:** Die Zeitreihen werden nur neu geladen, wenn sich die verglichenen Fahrten ändern; bereits geladene bleiben im `@State`-Wörterbuch.
