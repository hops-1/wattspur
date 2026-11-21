# Testanleitung iPhone 1.6 „Im Auto“

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Die Stories: B-311, B-339, B-341, dazu B-323. CarPlay (B-327) ist nicht dabei; es kommt erst nach der Freigabe durch Apple.

Kein neues CloudKit-Feld. Neue Einstellungen je iPhone, nicht synchronisiert: Auto-Start, „Startet mit“ je Gerät, Ende bei Trennung, Ende nach Stillstand und die Minuten. Der Mac bleibt bei 1.10.2.

Bitte nur fahren, wenn es passt, und nichts während der Fahrt am iPhone einstellen.

## 0. Vorher

- Am iPhone **1.6 (39)** aus TestFlight.
- Ein Auto mit CarPlay (z. B. Nugget) und, wenn möglich, das Motorrad mit Headset.

## A. Einstellen (B-311, B-339)

1. **Mehr › Aufnahme**: Schalter **Auto-Start** einschalten. iOS fragt, ob Wattspur Mitteilungen senden darf: **Erlauben**.
2. Unter **Startet mit**: beim Auto **CarPlay** wählen. Fürs Motorrad das iPhone mit dem Headset verbinden; dann erscheint sein Name in der Liste, ihn beim Motorrad wählen.
3. **Jetzt verbunden** zeigt die Verbindung, die gerade da ist.
4. Unter **Ende**: **Bei Trennung** und **Nach Stillstand** an, **Stillstand 10 min**.

## B. Automationen anlegen

Wie in der Anleitung unten auf der Seite:

1. **Kurzbefehle › Automation › +**, **CarPlay**, **Verbindet**, **Sofort ausführen**, Aktion **Wattspur › Fahrt starten**, das Feld **Gerät leer lassen**.
2. Zweite Automation: **CarPlay**, **Trennt**, **Sofort ausführen**, Aktion **Wattspur › Fahrt beenden**.
3. Dasselbe mit **Bluetooth** und dem Headset fürs Motorrad.

## C. Bereit und Losfahren (B-311)

1. Ins Auto, CarPlay verbindet: Wattspur kommt nach vorn mit **Bereit** und der Sanduhr. Auf dem Sperrbildschirm steht **Bereit** mit **Abbrechen**.
2. Losfahren: ab etwa 10 km/h wird aus „Bereit“ die Fahrt. Die Zeit beginnt bei 0:00, nicht beim Einsteigen.
3. Das Gerät stimmt (Nugget, nicht das Rad der letzten Fahrt).
4. **Abbrechen** (einmal im Stand probieren): Die Aufnahme schließt ohne Frage, es gibt keine Fahrt.
5. Stehen lassen, ohne loszufahren: Nach 10 min endet „Bereit“ von selbst.

## D. Ende und Sichern (B-339)

1. Ankommen, Motor aus, CarPlay trennt: Die Fahrt wird **ohne Frage gesichert**. Es kommt die Mitteilung **Fahrt gesichert** mit Name und Strecke.
2. Der Name sind die Orte von Start und Ziel, z. B. „Reinheim – Darmstadt“. Bei einer Runde steht nur ein Ort.
3. Die Mitteilung antippen: Die Fahrt öffnet sich.
4. Ohne Trennung (z. B. CarPlay bleibt an, oder „Bei Trennung“ aus): Nach 10 min Stillstand endet und sichert die Fahrt von selbst.
5. Eine Fahrt unter 500 m (z. B. nur umparken) wird **nicht** gesichert.
6. Motorrad mit Headset: dasselbe wie oben; die Fahrt zeigt die Schräglage.

## E. Siri mit Gerät (B-323)

1. „Starte eine Fahrt mit Nugget in Wattspur“: Die Aufnahme startet mit Nugget, sofort, ohne „Bereit“.
2. Dasselbe mit einem Bike und mit „Auto“.

## F. Wie vorher

1. **Fahrt starten** in der Übersicht startet sofort, ohne „Bereit“, auch mit Auto-Start an.
2. **Auto-Start aus**: Die Automation „Fahrt starten“ startet wie vor 1.6 sofort, „Fahrt beenden“ öffnet **Fahrt speichern**.

## G. Ruhigeres Tempo (B-341)

Braucht einen Build nach 1.6 (39).

1. Mit dem eBike aufnehmen und das Tempo in Wattspur neben der Bosch-Anzeige ansehen, auf gleichmäßiger Fahrt.
2. Dasselbe im Wald: Das Tempo springt weniger als in 1.6 (39), es kommt aber weiter jede Sekunde neu.
3. Anhalten: Nach etwa 2 s steht 0.
4. Ist es noch zu unruhig oder zu träge? Kurz notieren, dann passe ich die 2 s an.
