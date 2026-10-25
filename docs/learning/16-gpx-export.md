# 16 – GPX-Export

Story: B-112 (IMP-09), Entscheidungen in REQUIREMENTS.md 10.10

## Was gebaut wurde
- **Als GPX exportieren …** im Tour-Detail neben „PDF exportieren“ und im Kontextmenü der Liste. Ein Sichern-Dialog fragt nach dem Ort, der Dateiname ist der Name der Fahrt.
- Die Datei ist GPX 1.1: ein Track mit Position, Höhe und Zeit (UTC) jeder Sekunde, dazu Leistung und Trittfrequenz als Erweiterung.
- Eine zusammengefügte Fahrt bekommt ein Segment (`<trkseg>`) je Teil, jedes mit den echten Zeiten seines Teils.
- **Im Kit** `GPXWriter.swift` mit 5 Tests, darunter eine Rundreise: Die Tests lesen die Datei mit `XMLParser` wieder ein und vergleichen Punkte, Zeiten und Werte.

## Warum so
- **Erweiterungen wie Garmin und Strava:** GPX selbst kennt keine Leistung und keine Trittfrequenz. Die verbreitetste Schreibweise ist `<power>` direkt in `<extensions>` und die Trittfrequenz als `gpxtpx:cad` (Garmin TrackPointExtension v2). komoot, Strava, Garmin Connect und GPXSee lesen das; andere Programme überspringen unbekannte Erweiterungen.
- **Nur gemessene Trittfrequenz:** Für die Diagramme hält Wattspur den letzten Wert, bis ein neuer kommt (Req. 3.3). In eine Datei, die andere Programme auswerten, gehören nur echte Messwerte (`cadenceMeasured`).
- **Segment je Teil:** Zwischen zwei Teilen einer zusammengefügten Fahrt liegt eine Lücke, oft über Nacht. In einem einzigen Segment würden Programme eine gerade Linie über die Lücke ziehen und eine riesige Pause zählen.
- **Zeiten aus den Teilen:** Die Zeitreihe der zusammengefügten Fahrt ist über Tage hinweg gestaucht (nur Fahrzeiten zählen, siehe Notiz 11). Für echte Zeitstempel nimmt der Export deshalb die Teile mit ihrem eigenen Start.
- **UTC:** GPX schreibt Zeiten in UTC mit „Z“. Die Zeitzone der Fahrt rechnet das Zielprogramm selbst aus der Position aus.

## Swift-Konzepte
- **XML als Text statt `XMLDocument`:** Das Format ist klein und fest. Mit String-Bausteinen bleibt der Writer plattformunabhängig (`XMLDocument` gibt es auf iOS nicht). Dafür muss `escape(_:)` die fünf Sonderzeichen `& < > " '` im Namen ersetzen.
- **`String(format: "%.7f")`:** Ohne Locale schreibt `String(format:)` immer einen Dezimalpunkt. `formatted()` würde auf einem deutschen Mac ein Komma setzen, und die Datei wäre kaputt.
- **`Date.ISO8601FormatStyle`** mit der Zeitzone UTC ergibt „2026-10-18T12:12:13Z“.
- **`XMLParser` mit `shouldProcessNamespaces`:** Im Test meldet der Parser Elemente mit ihrem Namespace. So prüft der Test, dass `cad` wirklich im Garmin-Namespace steht, nicht nur so heißt.
- **Rekursion über Teile:** `gpxSegments` ruft sich für jeden Teil auf. Ein Teil ist selbst keine zusammengefügte Fahrt, also endet die Rekursion nach einer Stufe.
