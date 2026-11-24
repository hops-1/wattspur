# Testanleitung iPhone 1.6.9

Für Nils. Jeder Punkt bekommt ✓, oder ✗ mit einer kurzen Notiz oder einem Screenshot. Das Release bringt zwei Dinge aus der Autofahrt vom 24.11.2026: Beendet iOS Wattspur während der Fahrt, läuft die Aufnahme von selbst weiter (B-383). Die Kachel in CarPlay öffnet nichts, das Widget „Diese Woche“ schon (B-384). Der Mac bleibt 1.10.5. Die Punkte aus `TESTANLEITUNG-1.6.8.md` gelten weiter.

Im Auto und am Rad nur im Stand prüfen.

## 0. Vorher

- Am iPhone **1.6.9 (50)** aus TestFlight. *Mehr › Über Wattspur* zeigt die Nummer.

## A. Weiter nach einem Abbruch (B-383)

Das geht zu Hause, ohne zu fahren. Wegwischen ist nicht ganz dasselbe wie ein Abbruch durch iOS, zeigt aber, was beim nächsten Start passiert.

1. Eine Fahrt starten (**Fahrt starten**, nicht Auto-Start). 1 Minute warten.
2. Wattspur im App-Umschalter nach oben wegwischen.
3. Nach 1 bis 2 Minuten Wattspur wieder öffnen: Es kommt keine Frage „Nicht beendete Fahrt“. Die Aufnahme läuft, die Zeit zählt weiter.
4. iPhone sperren: Es gibt genau **eine** Live-Aktivität von Wattspur, und sie zählt weiter.
5. Noch einmal wegwischen und **länger als 15 Minuten** warten. Beim Öffnen kommt wieder keine Frage, die Aufnahme läuft. iOS startet Wattspur nach dem Wegwischen gleich im Hintergrund neu, darum wird die Fahrt nie 15 Minuten alt. In *Dateien › Auf meinem iPhone › Wattspur › Diagnose* steht in der neuesten Datei: „continued after the app was ended; in the background 3 s after launch: yes; gap: …“. Die Lücke ist nur wenige Sekunden lang. Die Frage „Nicht beendete Fahrt“ kommt nur, wenn iOS Wattspur nicht neu startet, zum Beispiel wenn das iPhone aus war.
6. Die Testfahrt danach beenden und verwerfen.

Läuft eine Automation „Fahrt beenden“ während des Tests, beendet sie die Fahrt. Beim Öffnen wartet dann „Fahrt sichern“. Das ist kein Fehler.

## B. Im Auto mit CarPlay (B-383, B-384)

1. **Kachel im Dashboard:** Während einer Aufnahme ein kurzer Tipp auf die Kachel „Wattspur“. Erwartet: Es passiert nichts, so macht es Apple. Langes Drücken zeigt Apples Menü „Für diese Fahrt löschen“; dort **Abbrechen** wählen.
2. **Widget:** Am iPhone unter *Einstellungen › Allgemein › CarPlay* beim Auto das Widget **Diese Woche** von Wattspur hinzufügen. In CarPlay links vom Dashboard darauf tippen: Wattspur öffnet sich in CarPlay mit seiner Tafel.
3. **Nicht beendete Fahrt in CarPlay (optional):** Eine Fahrt starten, das iPhone ausschalten und über 15 Minuten warten. Dann einschalten, aber Wattspur nicht öffnen, und ins Auto. CarPlay zeigt „Nicht beendete Fahrt“ mit der Strecke und nur **Aufnahme fortsetzen**, kein „Fahrt starten“. Startet iOS Wattspur nach dem Einschalten von selbst, läuft die Fahrt stattdessen weiter. Auch das ist richtig.
4. **Der echte Fall (wenn er passiert):** Eine Fahrt mit Navigation, Podcast und Kamera wie am 24.11. Stockt der Podcast und war Wattspur kurz weg, läuft die Aufnahme trotzdem weiter. Danach in *Dateien › Auf meinem iPhone › Wattspur › Diagnose* die neueste Datei öffnen. Steht dort eine Zeile „continued after the app was ended …“, bitte die Zeile notieren. Sie sagt, ob iOS Wattspur im Hintergrund neu gestartet hat, und wie lang die Lücke war.

## C. Auto-Start nach einem Abbruch (B-383, optional)

1. Eine Fahrt per Auto-Start beginnen lassen und losfahren.
2. Im Stand Wattspur wegwischen und gleich wieder öffnen: Die Fahrt läuft weiter.
3. Am Ziel aussteigen: Die Fahrt endet wie bisher von selbst und wird gesichert.

## D. Speicher (für Claude, optional)

Wenn iOS Wattspur unterwegs wieder beendet: das iPhone danach an den Mac hängen. Claude holt die Speicherberichte und prüft, ob die Fahrt ohne Zutun weiterlief.
