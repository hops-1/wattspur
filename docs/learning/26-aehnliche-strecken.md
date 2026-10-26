# 26 – Ähnliche Strecken, Verlauf und weitere Rekorde

Stories: B-116 bis B-120, B-122 (Plan: REQUIREMENTS.md 10.19)

## Was gebaut wurde
- **`RouteSignature`** (Kit/Core, `Ride/RouteSignature.swift`): Eine vereinfachte Route wird alle 10 m neu abgetastet und in ein Raster aus 50-m-Zellen einsortiert. Sie merkt sich Start, Ziel, Länge und den Umlaufsinn (Vorzeichen der Fläche, die die Route umschließt).
- **`RouteSimilarity`**: Die Ähnlichkeit zweier Routen ist der Anteil der einen, der höchstens 50 m von der anderen entfernt liegt, in beide Richtungen geprüft; der kleinere Wert zählt. Dazu die Richtung: gleiche, umgekehrte oder keine (Start und Ziel höchstens 200 m auseinander; bei Rundfahrten entscheidet der Umlaufsinn).
- **`RouteIndex`**: ein Raster der Erde, das sich merkt, welche Route durch welche Zelle läuft. Eine Suche vergleicht nur Routen, die genug Zellen teilen, und bricht den genauen Vergleich ab, sobald die Schwelle nicht mehr erreichbar ist. 1 000 künstliche Fahrten: eine Anfrage in rund 60 ms.
- **`PeakPower`** und die **beste 1-Minuten-Leistung**: ein Fenster von 60 Sekunden über der Leistung, gespeichert an der Fahrt (`bestPower1Min`) und für den Bestand im Hintergrund nachgetragen. Dazu vier neue Rekorde (Höchstgeschwindigkeit, höchste Leistung, höchste Trittfrequenz, beste Minute).
- **`RouteSimilarityStore`** (App): baut den Index beim ersten Suchen im Hintergrund und beantwortet Anfragen, ohne die Oberfläche zu blockieren. `SimilarRidesFilter` lebt in `ContentView`, `SimilarRidesBar` ist der Chip mit Regler.
- **`RouteHistory`** (Kit/Core) und **`RouteHistoryView`** (App): Fahrzeit, Tempo, Leistung und Trittfrequenz über die Zeit, beste und letzte Fahrt markiert. Das Diagramm ist aus `TrendCard` als allgemeines **`TrendChart`** herausgelöst.
- **Tests:** Ähnlichkeit an synthetischen Routen (Pendelstrecke hin und zurück, Umweg, Teilstrecke, Rundfahrt in beide Richtungen, Rauschen, Versatz) und an aufgezeichneten Touren (Bosch-FIT, Bosch-GPX und komoot derselben Tour), Index gegen die lineare Referenz, Lasttest, beste Minute mit Lücken, `RouteHistory`.

## Warum so
- **Anteil statt Abstand:** `RouteMatch` (Duplikate) fragt „liegt diese Fahrt auf dieser?“ mit Median und 95-%-Wert. Für „dieselbe Strecke“ ist „wie viel der Strecke liegt auf der anderen?“ die verständlichere Zahl, und sie lässt sich als Prozent zeigen und mit einem Regler verändern.
- **Der kleinere Anteil zählt:** Sonst wäre eine kurze Fahrt, die ganz auf einer langen liegt, ihr „100 % ähnlich“.
- **Richtung getrennt:** Hin- und Rückweg haben dieselbe Form. Wer nur den Hinweg sucht, soll den Rückweg nicht bekommen; wer beide will, schaltet „Beide Richtungen“ ein.
- **Raster statt Vergleich aller Paare:** Tausend Fahrten ergeben eine halbe Million Paare. Das Raster schlägt zuerst die wenigen Kandidaten vor, der genaue Vergleich entscheidet.
- **Nichts speichern:** Die Treffer lassen sich aus den Routen jederzeit berechnen. Es gibt keine Paarwerte, die veralten können, und keine neue Tabelle in der Bibliothek; die Gruppen in 1.7.1 speichern nur die Bezugsroute.
- **Index erst beim ersten Suchen:** Wer die Funktion nie benutzt, zahlt nichts. Danach ändert sich der Index nur, wenn sich Routen ändern (ein Hash über die Fahrten entscheidet).
- **Beste Minute speichern, nicht rechnen:** Dafür müsste jede Fahrt ihre Sekunden-Zeitreihe laden. Der Wert wird einmal beim Import berechnet und für alte Fahrten im Hintergrund nachgetragen (`peakPowerVersion`, wie bei der vereinfachten Route).
- **Zwei Auswahlen im Bereich Fahrten:** Ohne markierte Fahrt zeigt die rechte Seite den Verlauf, mit markierter Fahrt das Tour-Detail. Der Knopf „Zurück zum Verlauf“ verbindet beide.

## Swift-Konzepte
- Werttypen und `Sendable`: Index und Signaturen sind `struct`s, deshalb darf der Index in einer `Task.detached` gebaut und danach wieder auf dem Hauptthread abgelegt werden.
- `@Observable` mit `@ObservationIgnored` für Zwischenspeicher, die die Oberfläche nicht beobachten soll.
- Tasks abbrechen: Jede neue Anfrage bricht die laufende ab; nur das Ergebnis der letzten schreibt.
- Ein Optional-Binding in SwiftUI: `Binding($optional)` packt bei jedem Lesen neu aus und stürzt ab, wenn der Wert beim Ausblenden schon `nil` ist. Besser `Binding(get:set:)` mit dem zuletzt bekannten Wert.
- Swift Charts: `PointMark` mit eigenem Symbol (Stern, Ring) und `chartOverlay`, um einen Klick dem nächsten Punkt zuzuordnen.
