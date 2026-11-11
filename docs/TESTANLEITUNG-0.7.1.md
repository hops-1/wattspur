# Testanleitung iPhone 0.7.1 + Mac 1.8.15 „Lücken im Track“

Für Nils, nach dem Release. Ergebnis je Punkt: ✓, ✗ mit kurzer Notiz oder Screenshot. Alles geht mit der echten Bibliothek: Es wird nichts zurückgeholt, nur neu gezeichnet.

## A. Alte Fahrten (Mac 1.8.15, iPhone 0.7.1)

1. Nach dem Update eine Fahrt öffnen, die über mehrere Tage oder Teile zusammengefügt ist. Die Linie hat wie vorher je Teil ein eigenes Stück.
2. Gibt es eine Fahrt mit einer Lücke (Zug, Auto, GPS lange weg): Die gerade Linie über die Lücke ist weg, im Tour-Detail, in der Karte aller Fahrten, in der Heatmap und in der Vorschau in der Liste.
3. Die Strecke dieser Fahrt ist gleich wie vorher (die Lücke zählte beim Import schon nicht mit).

## B. Neue Aufnahme mit Zug (iPhone 0.7.1)

1. Aufnahme starten, ein Stück fahren, in den Zug steigen. Die Aufnahme **laufen lassen**.
2. Nach dem Aussteigen weiterfahren, dann sichern.
3. Erwartet: zwei Linien ohne Verbindung über die Zugstrecke; die Strecke ohne die Zugfahrt.
4. Dasselbe einmal mit **Pause** im Zug. Erwartet: ebenso.
5. Die Fahrt als GPX teilen und in einer anderen App öffnen (z. B. komoot): Auch dort keine Linie über die Lücke.

## C. PDF und Vergleich (Mac 1.8.15)

1. Von der Fahrt aus B ein PDF machen: keine Linie über die Lücke.
2. Die Fahrt mit einer anderen vergleichen: auf der Karte ebenso.

## Antwort im Issue #164 (Entwurf)

Erst schicken, wenn Nils den Text freigegeben hat und Mac 1.8.15 und iPhone 0.7.1 erschienen sind.

> Danke für den Hinweis und das Lob!
>
> Ab **Mac 1.8.15** und **iPhone 0.7.1** (TestFlight) zieht Wattspur keine Linie mehr über eine Lücke: Liegen zwei Positionen nacheinander mehr als 2 km auseinander, hört die Linie auf und beginnt am nächsten Punkt neu, so wie du es vorgeschlagen hast. Das gilt für alle Karten, das PDF und den GPX-Export (dort ein neuer Abschnitt). Die Lücke zählt nicht zur Strecke. Alte Fahrten werden nach dem Update einmal neu gezeichnet.
>
> Läuft die Aufnahme am iPhone im Zug weiter, geht sie nach dem Aussteigen in einem neuen Abschnitt weiter, ohne die Zugfahrt mitzuzählen.
>
> Wenn es bei dir noch nicht passt, schreib gern hier weiter.

## Ergebnis

Hier eintragen oder an Claude schicken. Ein ✗ wird ein eigener Backlog-Punkt.
