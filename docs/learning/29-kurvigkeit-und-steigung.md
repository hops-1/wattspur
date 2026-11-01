# 29 – Steigung, Lastenrad, Kurvigkeit und kurvige Straßen

Stories: B-200, B-201, B-180 bis B-183, B-202, V-13 (Recherche: [SPIKE-KURVEN.md](../SPIKE-KURVEN.md))

## Was gebaut wurde
- **Steigung an einer Stelle** (`RideTrack.grade(atDistanceKm:window:)`, Core): Höhenunterschied auf den 100 m rund um den Zeiger, aus der verbundenen Höhenlinie. Das Höhendiagramm zeigt sie neben Strecke und Höhe, VoiceOver liest sie vor.
- **Stärkste Steigung und stärkstes Gefälle** (`RideTrack.steepestGrades()`): das steilste Stück von 100 m, alle 10 m geprüft. Beides wird mit der Fahrt gespeichert und ist ein Rekord (B-202).
- **Bike-Art Lastenrad** (`BikeKind.cargo`): nur Name und Symbol, keine Rechnung.
- **Kurvigkeit einer Fahrt** (`CurvatureAnalyzer`, Core): Radius durch drei Punkte, nach dem Verfahren von roadcurvature.com sortiert in enge, sanfte und gerade Stücke (Gewicht 2, 1, 0); der Wert je Kilometer steht in den Details, färbt die Route auf der Karte ein, ist ein Rekord und eine Sortierung.
- **`TrackFigures`**: Kurvigkeit, stärkste Steigung und stärkstes Gefälle werden zusammen gerechnet und gespeichert (vier neue Spalten an `Ride`, mit Version und Nachrechnen im Hintergrund wie bei der besten Minute).
- **Kurvige Straßen** (B-182, B-183): `ZipArchive` und ein KML-Leser lesen die KMZ-Datei einer Region, `CurvyRegion` ist ein eigenes kompaktes Dateiformat, `CurvyRoadLibrary` verwaltet die Dateien, und die Ebene zeichnet die Straßen auf der Karte der Fahrt, dem Vergleich und der Karte aller Fahrten, mit Tooltip.

## Warum so
- **Erst ein Versuch (V-13):** Bevor Code entstand, hat ein Spike geklärt, was roadcurvature.com anbietet und was die Daten enthalten. `c_300` enthält `c_1000` vollständig, deshalb reicht eine Datei je Region. Das Verfahren ist nach der Beschreibung selbst geschrieben, nicht aus dem GPL-Code übernommen.
- **GPS zittert, der Kreis durch drei Punkte reagiert darauf:** Auf einer geraden Strecke ergibt Rauschen von 3 m bei schwacher Glättung rund 580 Kurven je Kilometer. Deshalb wird die Spur auf 10-m-Schritte gebracht und gaußsch geglättet, und der Radius nimmt Punkte im Abstand von 30 m. Ein Test mit Rauschen hält das fest (heute etwa 18 je Kilometer).
- **Echte Fahrten bleiben hoch, und das ist richtig:** Auch bei starker Glättung liegen gewöhnliche Fahrten bei 200 bis 270 je Kilometer, weil das Abbiegen an Kreuzungen und schlängelnde Wege mitzählen. Die Skala von Fahrten ist nicht die der Straßen von roadcurvature.
- **Grenzen aus Daten, nicht aus dem Bauch:** Erst standen „kurvig“ und „sehr kurvig“ bei 60 und 200 und waren fast immer „sehr kurvig“. Heute stehen sie bei 190 und 270, gewählt aus einer echten Bibliothek mit 156 Fahrten ab 10 km (Median 202, 90 % unter 251, höchster Wert 373).
- **Kurze Fahrten werden nicht bewertet:** Eine Fahrt von 3,9 km mit vielen sanften Wellen kam auf 357 je Kilometer, fast so viel wie die kurvigste. Wenige Kreuzungen wiegen auf kurzer Strecke zu schwer. Das Wort, die Zeile in den Details, der Rekord und die Sortierung (`ratedCurvature`) gelten deshalb erst ab 10 km; ein fester Schnitt ist einfacher zu erklären als eine gleitende Gewichtung.
- **Gespeicherte Werte tragen eine Version:** Nach der Änderung der Glättung erhöhte `TrackFigures.version` die Zahl, und alle Fahrten wurden beim nächsten Start nachgerechnet. Ohne Version hätten alte Fahrten den alten Wert behalten.
- **Steigung über 100 m statt zwischen Punkten:** Einzelne Höhenwerte zittern um Meter; auf 4 m Abstand ergäbe das ±25 %. Über 100 m bleibt die Steigung ruhig. Für die stärkste Stelle zählen nur volle Fenster, damit der Rand der Fahrt keinen Rekord erzeugt.
- **Ohne fremde Bibliothek lesen:** KMZ ist ein ZIP mit KML. Ein eigenes `ZipArchive` entpackt es mit dem Framework `Compression`, `XMLParser` liest das KML als Strom aus einer Temporärdatei. Grenzen (600 MB, 200 000 Straßen, 5 Mio. Punkte) schützen vor Dateien, die den Speicher füllen würden. Autobahnen werden weggelassen.
- **Ein eigenes Dateiformat:** Gelesen wird einmal beim Import; danach liegt die Region in einem kompakten Format mit `Float32`-Koordinaten (Kennung „WCRV“) im Ordner der App. Das Starten bleibt schnell und die Dateien klein.
- **Nur zeichnen, was man sieht:** Eine Region hat Zehntausende Straßen. Der Renderer zeichnet pro Kachel nur die, die sie schneiden, und die Ebene erscheint erst ab etwa Landkreis-Größe (höchstens 90 m je Bildschirmpunkt).
- **Die Straßen liegen außerhalb der Datenbank:** Sie gehören nicht zu den Fahrten und lassen sich bei roadcurvature.com jederzeit neu laden. Das Backup der Mediathek enthält sie deshalb nicht; das steht im Handbuch.
- **Quellenangabe immer sichtbar:** Die Daten sind © OpenStreetMap contributors und roadcurvature.com; die Angabe steht unten rechts auf jeder Karte mit Ebene. Im PDF fehlt die Ebene noch.

## Swift-Konzepte
- **Faltung mit einem Gauß-Kern:** Jeder geglättete Punkt ist die gewichtete Summe seiner Nachbarn; die Gewichte folgen einer Glockenkurve, deren Breite (σ) die Stärke bestimmt.
- **`Compression`-Framework:** `compression_stream` entpackt Raw-Deflate-Daten stückweise; ein ZIP-Eintrag lässt sich so ohne Bibliothek lesen.
- **`XMLParser` mit Delegate:** liest eine XML-Datei als Strom, ohne sie ganz in den Speicher zu laden; der Delegate bekommt Anfang, Text und Ende jedes Elements.
- **`MKOverlay` und `MKOverlayRenderer`:** das Overlay nennt seinen Bereich (`boundingMapRect`), der Renderer zeichnet in `draw(_:zoomScale:in:)` nur den angefragten Ausschnitt.
- **`@unchecked Sendable`** für ein unveränderliches Objekt (`CurvyRoadSet`), das Threads gefahrlos teilen, auch wenn der Compiler das nicht selbst beweisen kann.

**Begriffe, die oft vorkommen**
- **Umkreisradius:** der Radius des Kreises, der durch drei Punkte läuft. Je enger die Kurve, desto kleiner der Radius; auf einer Geraden ist er unendlich.
- **Kurvigkeit (nach roadcurvature):** Summe aus Länge × Gewicht über die Stücke einer Strecke. 300 entspricht etwa 150 m enger oder 300 m sanfter Kurven.
- **KMZ / KML:** KML beschreibt Orte und Linien als XML; KMZ ist ein ZIP mit einer KML-Datei darin.
