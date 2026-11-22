# Testanleitung iPhone 1.6.4

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Neu sind CarPlay (B-340, B-327) und der Namensvorschlag für jede Aufnahme (B-368). Der Mac bleibt 1.10.4. Kein neues CloudKit-Feld.

Am besten im Nugget mit CarPlay. Fahre nur, wenn es sicher ist; tippe in CarPlay nur im Stand oder lass die Beifahrerin tippen.

## 0. Vorher

- Am iPhone **1.6.4 (45)** aus TestFlight.
- Das iPhone mit dem Auto verbinden (Kabel oder drahtlos).

## A. CarPlay erscheint (B-340)

1. Auf dem Bildschirm im Auto steht **Wattspur** mit dem App-Symbol.
2. Ein Tipp öffnet die Tafel „Wattspur“ mit **Fahrzeug** und den Knöpfen **Fahrt starten** und **Fahrzeug wechseln**.

## B. Fahrzeug und Start (B-327)

1. Unter **Fahrzeug** steht das Gerät, das auch das iPhone nehmen würde, z. B. „Nugget“.
2. **Fahrzeug wechseln** zeigt deine Autos und Motorräder, danach Auto und Motorrad ohne Gerät, je mit Symbol. Ein Tipp wählt und geht zurück; die Tafel zeigt das neue Fahrzeug.
3. **Fahrt starten:** Die Tafel zeigt Tempo, Zeit, Strecke und **Querbeschleunigung**. Am iPhone läuft dieselbe Aufnahme mit demselben Gerät.
4. Beim Fahren kommen die Werte etwa alle 5 Sekunden neu, nicht jede Sekunde.

## C. Pause und Ende (B-327)

1. **Pause:** oben steht „Pause“, der Knopf heißt **Weiter**. Am iPhone ist die Aufnahme auch angehalten.
2. **Weiter:** Die Fahrt läuft weiter.
3. **Ende:** Es kommt „Fahrt beenden und sichern?“. **Abbrechen** lässt die Fahrt weiterlaufen.
4. **Ende › Sichern:** Die Tafel zeigt wieder **Fahrt starten**. Am iPhone steht die Fahrt in der Liste, mit dem Gerät aus B und einem Namen wie in D. Eine Mitteilung „Fahrt gesichert“ kommt.
5. Eine Fahrt am **iPhone** beenden: CarPlay zeigt kurz danach wieder **Fahrt starten**.

## D. Name der Fahrt (B-368)

1. Eine Fahrt von A nach B am iPhone mit **Stopp** beenden. Das Blatt „Fahrt sichern“ zeigt zuerst „Fahrt am …“, nach etwa einer Sekunde „Startort – Zielort – 14:32“ mit deiner Startzeit.
2. Eine Runde (Start und Ziel im selben Ort): „Reinheim Rundfahrt – 14:32“.
3. Tippe schnell einen eigenen Namen, bevor der Vorschlag kommt: Dein Name bleibt.
4. Eine Fahrt, die von selbst endet (Auto-Start) oder in CarPlay endet, hat denselben Namen.
5. Im Flugmodus beenden: Der Name bleibt „Fahrt am …“.

## E. Auto-Start mit CarPlay

1. Mit Auto-Start an: Beim Verbinden steht in CarPlay **Bereit** mit „Wartet, bis das Fahrzeug fährt“.
2. **Abbrechen** beendet „Bereit“ ohne Fahrt.
3. Beim Losfahren wechselt die Tafel auf Tempo, Zeit und Strecke.
