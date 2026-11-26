# Testanleitung iPhone 1.6.11

Für Nils. Jeder Punkt bekommt ✓, oder ✗ mit einer kurzen Notiz oder einem Screenshot. Das Release bringt zwei Dinge: Uhrzeit und Akku in der Aufnahme quer (B-388) und den Fix für den Absturz beim Start unter iOS 27 (B-389). Der Mac bleibt 1.10.5. Die Punkte aus `TESTANLEITUNG-1.6.10.md` gelten weiter.

Am Rad und im Auto nur im Stand prüfen.

## 0. Vorher

- Am iPhone **1.6.11 (52)** aus TestFlight. *Mehr › Über Wattspur* zeigt die Nummer.

## A. Uhrzeit und Akku quer (B-388)

1. **Quer:** Eine Fahrt starten und das iPhone quer drehen. Oben rechts steht eine kleine Kapsel mit der Uhrzeit und dem Akku-Symbol, ohne Prozentzahl. Darunter sitzt der Knopf für den Kartenstil und lässt sich antippen.
2. **Uhrzeit:** Sie springt zur vollen Minute weiter und stimmt mit der Uhr des iPhones überein.
3. **Laden:** Ladekabel anstecken: Ein grüner Blitz erscheint neben dem Akku. Kabel ab: Der Blitz verschwindet.
4. **Hochkant:** Zurückdrehen. Die Kapsel ist weg, iOS zeigt Uhrzeit und Akku oben selbst. Sonst sieht alles aus wie bisher.
5. **Pause und Bereit:** In der Pause und bei „Bereit“ (Auto-Start) steht die Kapsel quer genauso da.
6. **Am Lenker (wenn es passt):** In der Halterung bei einer Fahrt kurz draufschauen. Ist die Kapsel gut zu lesen?

## B. Kein Absturz beim Start (B-389)

1. Wattspur ganz schließen (im App-Umschalter wegwischen).
2. Den Kurzbefehl **Fahrt starten** auslösen und das iPhone dabei mehrmals zwischen hochkant und quer drehen. Erwartet: Wattspur öffnet sich, die Aufnahme läuft, kein Absturz.
3. Das drei- bis fünfmal wiederholen, auch mit Wattspur direkt vom Home-Bildschirm. Die Testfahrten danach beenden und verwerfen.
4. In den nächsten Tagen: Stürzt Wattspur doch ab, bitte das iPhone an den Mac hängen. Claude holt den Bericht und prüft, ob es derselbe Absturz ist.
