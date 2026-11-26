# Testanleitung iPhone 1.6.10

Für Nils. Jeder Punkt bekommt ✓, oder ✗ mit einer kurzen Notiz oder einem Screenshot. Das Release bringt eine Sache: Die Kachel von Wattspur im CarPlay-Dashboard zeigt Fahrzeit, Strecke und Tempo (B-387). Der Mac bleibt 1.10.5. Die Punkte aus `TESTANLEITUNG-1.6.9.md` gelten weiter, vor allem Teil B im Auto.

Im Auto nur im Stand prüfen.

## 0. Vorher

- Am iPhone **1.6.10 (51)** aus TestFlight. *Mehr › Über Wattspur* zeigt die Nummer.

## A. Kachel in CarPlay (B-387)

Geht im Auto oder am Mac im CarPlay Simulator (Device Hub, iPhone am Kabel).

1. **Fahrt:** Eine Fahrt starten. Die Kachel „Wattspur“ im Dashboard zeigt das Symbol des Fahrzeugs, die Fahrzeit, die Strecke und das Tempo. Die Zeit zählt jede Sekunde weiter.
2. **Pause:** Am iPhone **Pause** tippen. Auf der Kachel steht **Pausiert**. Mit **Weiter** verschwindet das Wort wieder.
3. **Bereit:** Eine Fahrt per Auto-Start beginnen lassen und noch nicht losfahren. Die Kachel zeigt die Sanduhr, **Bereit** und den Hinweis „Die Fahrt beginnt, wenn du losfährst.“
4. **Tipp:** Ein kurzer Tipp auf die Kachel tut weiter nichts. So macht es Apple.
5. **Sperrbildschirm:** Die Live-Aktivität am iPhone sieht aus wie bisher, mit den Knöpfen **Pause** und **Abbrechen**.

## B. Apple Watch (optional)

1. Mit einer Fahrt am iPhone auf der Apple Watch den Smart Stack öffnen (Digital Crown drehen). Erscheint Wattspur dort, zeigt die Kachel dieselben Werte wie in CarPlay.
