# GPX-Dateien importieren

Neben den FIT-Dateien der Bosch eBike Flow App liest Wattspur **GPX-Dateien**: Fahrten von anderen Bikes, aus Apps wie komoot oder Strava, von Radcomputern und aus dem GPX-Export der Flow-App. GPX ist das Format, das fast jedes Gerät schreiben kann, so kommen auch Fahrten anderer Bikes in Wattspur.

Eine GPX-Datei enthält Positionen, Höhe und Zeit, manchmal auch Leistung, Trittfrequenz, Puls und Temperatur. Sie enthält **keine Summen**, deshalb rechnet Wattspur sie aus dem Track aus und kennzeichnet sie als geschätzt. Für eine Bosch-Fahrt bleibt die FIT-Datei die bessere Quelle: Ihre Summen hat der Antrieb gemessen.

## Was Wattspur liest
- **GPX 1.0 und 1.1** mit einem **Track** (`trk`), dessen Punkte eine Zeit haben. Mehrere Tracks oder Segmente in einer Datei werden **eine Fahrt**; eine Lücke ab 30 Sekunden teilt die Fahrt in Teile mit einer Pause dazwischen.
- **Leistung, Trittfrequenz, Puls und Temperatur**, wenn die Datei sie hat, in den Erweiterungen, die Garmin, Strava und komoot benutzen. Leistung und Trittfrequenz erscheinen in den Diagrammen. Puls und Temperatur werden gespeichert, aber noch nicht angezeigt.
- **Nicht importiert:** Routen (`rte`) und Wegpunkte (`wpt`), denn sie enthalten keine Aufzeichnung. Eine Datei ohne Zeiten sagt das im Import-Protokoll.
- Eine **GPX, die du aus Wattspur exportiert hast**, kommt so zurück, wie sie hinausging.
- Sehr große Dateien (über 200 MB oder 5 Millionen Punkte) werden abgelehnt, ebenso abgeschnittene Dateien und solche, deren Zeiten rückwärts laufen.

## Importieren
GPX-Dateien importierst du wie FIT-Dateien, siehe [Fahrten importieren](03-importing.md): auf die Fahrtenliste oder das Import-Fenster ziehen, auf **+** klicken (⌘O) oder in den überwachten Ordner legen.

**Für welches Bike?** Eine GPX-Datei sagt nicht, auf welchem Bike sie gefahren wurde. Hast du zwei oder mehr Bikes, fragt ein Blatt danach, wenn du GPX-Dateien von Hand hineinziehst; das aktive Bike ist vorgewählt. Mit einem Bike und im überwachten Ordner geht die Fahrt an das aktive Bike (siehe [Profil und Bikes](07-profile-and-bikes.md)). Später änderst du es mit **Bike zuweisen**.

## Was Wattspur berechnet
Weil die Datei keine Summen hat, rechnet Wattspur sie aus den Punkten aus. Die Fahrt trägt die Kennzeichnung **≈ Summen geschätzt**; ein Klick darauf zeigt die kurze Erklärung.

| Wert | Wie |
|---|---|
| Fahrzeit | Die Zeit in Bewegung. Eine Lücke ab 30 s zwischen zwei Punkten ist eine Pause. Eine Geschwindigkeit unter 0,8 m/s (gemessen über 5 Sekunden um den Punkt) zählt als Stillstand |
| Strecke | Entlang des Tracks in Bewegung; das kleine Zittern eines GPS im Stand zählt nichts |
| Ø Geschw. | Strecke ÷ Fahrzeit |
| Max. Geschw. | Das schnellste Stück von mindestens 5 Sekunden, ein einzelner falscher Punkt setzt sie also nicht |
| Anstieg, Abstieg | Aus der Höhe nach dem Glätten (Median über 5 Punkte); ein Anstieg zählt ab 3 m |

Auffällige Punkte werden weggelassen, zum Beispiel ein Sprung von mehr als 150 km/h, der auch das Dreifache der Geschwindigkeit davor ist. Eine Motorradfahrt mit 160 km/h bleibt vollständig.

Bei einer Testfahrt stimmte die berechnete Fahrzeit auf 1 % mit der Bosch-FIT überein. Die Strecke kann einige Prozent kürzer sein als der Bosch-Wert, weil Bosch sie am Rad misst und der GPS-Pfad Kurven abschneidet. **Der Anstieg kann deutlich abweichen:** Antrieb und GPS-Gerät messen die Höhe auf unterschiedliche Weise. Brauchst du Werte, die zur Flow-App passen, nimm die Bosch-FIT.

## Dieselbe Fahrt als FIT und als GPX
Du kannst eine Fahrt doppelt haben, als Bosch-FIT und als GPX, zum Beispiel aus der Flow-App und aus komoot. Wattspur erkennt das, wenn der **Start** innerhalb von 60 Sekunden liegt, die **Strecke** innerhalb von 10 % und die **Route** dieselbe ist. Das wird nur **auf demselben Bike** geprüft; die Datei eines Freundes von derselben Tour auf einem anderen Bike bleibt also eine eigene Fahrt.

- **Eine GPX für eine Bosch-Fahrt** wird ohne Rückfrage **angehängt**. Puls und Temperatur aus der GPX kommen zur Fahrt hinzu, die Bosch-Werte bleiben, wie sie sind. Ein Hinweis unten sagt „GPX an … angehängt“, mit **Anzeigen**. Die Fahrt bekommt das Symbol **+GPX**.
- **Eine Bosch-FIT für eine GPX-Fahrt** fragt „Diese Fahrt ist schon vorhanden“ mit **Überspringen**, **Als neue Fahrt** und **Aktualisieren**. Aktualisieren übernimmt die Bosch-Werte (die Summen sind dann nicht mehr geschätzt) und behält Namen, Notizen, Bike und Markierungen. Die GPX bleibt als zusätzliche Quelle, ihr Puls bleibt erhalten.
- **Eine zweite GPX-Datei** zu einer Fahrt, die schon eine GPX-Fahrt ist oder eine GPX angehängt hat, stellt dieselbe Frage.
- **Im überwachten Ordner** fragt nichts: Eine GPX für eine Bosch-Fahrt wird angehängt, eine Bosch-FIT für eine GPX-Fahrt aktualisiert sie („automatisch aktualisiert“ im Import-Protokoll), und zwei GPX-Dateien derselben Fahrt werden übersprungen und im Protokoll vermerkt.

Wattspur überschreibt die Bosch-Werte nie mit denen einer GPX-Datei.

## So siehst du GPX-Fahrten
- **Quellen-Symbol** in der Fahrtenliste: **GPX** für eine Fahrt aus einer GPX-Datei, **+GPX** für eine Bosch-Fahrt mit angehängter GPX. Eine Bosch-FIT allein hat keins. VoiceOver liest „Quelle: GPX-Datei“.
- **Tour-Detail:** Eine Zeile unter dem Titel nennt die Quelle und die Datei, **≈ Summen geschätzt** erklärt die Schätzung. Ein kleines ≈ steht bei Fahrzeit, Strecke, Ø Geschwindigkeit und Anstieg.
- **Ein Strich statt 0:** Was die Datei nicht enthält, steht als „–“ mit „Nicht in der Datei“: Leistung, Trittfrequenz, manchmal der Anstieg. Ein Diagramm ohne Daten sagt „Diese Datei enthält keine Leistungsdaten“. **Kalorien** zeigen einen Strich, weil sie Leistung brauchen („Braucht Leistung“); die **CO₂-Einsparung** wird aus der Strecke berechnet und ist immer da.
- **Nach Quelle filtern:** Sobald es eine GPX-Fahrt gibt, haben Fahrten, Auswertung, Karte und Highlights eine Auswahl **Quelle**: **Alle Quellen**, **Bosch-FIT** (auch Fahrten mit angehängter GPX) oder **GPX**. Jeder Bereich merkt sich seine eigene Wahl, wie beim Bike-Filter. Ziele zählen immer alle Quellen. „Dein Jahr“ über der Fahrtenliste folgt dem Bike- und Quellenfilter der Liste, und der Jahresrückblick öffnet sich mit ihnen.
- **Import-Protokoll:** das Symbol neben dem Dateinamen, der Zustand **Angehängt** und ein Filter **FIT | GPX**.

## Auswertung, Rekorde und Vergleich ohne Leistung
Viele GPX-Dateien haben keine Leistung. Wattspur rechnet dann mit dem, was da ist, und sagt, für wie viele Fahrten das gilt:
- Arbeit und Kalorien summieren **nur die Fahrten mit Leistung**; ohne eine solche Fahrt siehst du einen Strich. Strecke, Fahrzeit und CO₂ zählen jede Fahrt.
- Unter einem Wert, den nur ein Teil der Fahrten hat, steht eine Zeile wie **9 von 12 Fahrten** (Anstieg, Arbeit, Kalorien, Ø Leistung und Trittfrequenz in der Auswertung; der Anstieg im Jahresrückblick und bei einem Anstiegsziel; der Durchschnitt im Vergleich).
- Durchschnitte von Leistung und Trittfrequenz sind nach Fahrzeit gewichtet, über die Fahrten, die den Wert haben.
- Eine Fahrt ohne Leistung oder Anstieg hält dafür **keinen Rekord**; die längste Fahrt kann sie trotzdem sein.
- Im Vergleich bleiben Arbeit und Kalorien einer Fahrt ohne Leistung leer und ziehen den Durchschnitt nicht herunter.

Einzelheiten stehen unter [Kennzahlen](05-metrics.md#werte-aus-einer-gpx-datei).

---
Weiter: [Ansichten](04-views.md) · [Fragen](06-faq.md)
