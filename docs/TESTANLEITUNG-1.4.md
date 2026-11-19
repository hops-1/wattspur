# Testanleitung iPhone und iPad 1.4 „iPad 2“ und Mac 1.10.2

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Die Stories: B-328, B-294 bis B-297.

Kein neues CloudKit-Feld: Ziele und zusammengefügte Fahrten gibt es im Schema schon. Neue Einstellungen gelten je Gerät und werden nicht synchronisiert: Zeitraum, Balken und Gerätefilter der Auswertung, Teil und Gerätefilter der Highlights.

Getestet wird am WLAN-iPad (iPad 8). Am iPad gibt es weiter keine Aufnahme (B-293).

## 0. Vorher

- Am iPad und am iPhone **1.4 (34)** aus TestFlight, am Mac **1.10.2** als DMG.
- Die Mediathek kommt über iCloud aufs iPad. Warten, bis die Fahrten da sind.
- Offen aus 1.3: der Test nach `TESTANLEITUNG-1.3.md`, wenn noch nicht fertig.

## A. Texte am iPad (B-328)

1. **Einstellungen:** Die Zeile **iCloud & Bibliothek** zeigt rechts **Dieses iPad** (ohne iCloud) oder **iCloud**.
2. **Einstellungen › iCloud & Bibliothek:** Unter „Dateien importieren …“ steht „Auf meinem iPad › Wattspur › Import“, bei der Sicherung „Auf meinem iPad“ und „von diesem iPad“.
3. **Einstellungen › Hilfe & Handbuch:** Der erste Link heißt **Wattspur auf dem iPad**, mit dem Symbol eines iPad.
4. Am **iPhone** steht überall weiter „iPhone“.

## B. Mac sieht aus wie vorher (B-294)

1. Am Mac **Auswertung**: Summen, Balken und Trends wie in 1.10.1. Zeitraum und Balken (Strecke, Fahrzeit, Anstieg) sind noch so eingestellt wie vorher.
2. **Highlights**: Jahr, Rekorde und Ziele wie vorher.
3. Zwei Fahrten mit ⌘-Klick wählen und **Vergleichen**: Linien, Strichart und Symbole je Fahrt wie vorher.

## C. iPad: Auswertung (B-295)

1. In der Seitenleiste nach **Karte** die Zeile **Auswertung**.
2. Oben **Woche · Monat · Jahr · Frei · Alles**, daneben die Pfeile. Die Zahlen stimmen mit dem Mac überein, für denselben Zeitraum und dieselbe Sportart.
3. **Rad** und **Fahrzeuge** in der Seitenleiste wechseln: Bei Fahrzeugen fehlen Arbeit, Kalorien, CO₂, Leistung und Trittfrequenz.
4. Ab zwei Rädern: Der Gerätefilter zeigt nur die Fahrten des gewählten Rads.
5. Einen Balken antippen: Darüber stehen sein Zeitraum, der Wert und der Vergleich zum Balken davor.

## D. iPad: Highlights (B-295)

1. In der Seitenleiste **Highlights** (Pokal).
2. **Jahr:** Kacheln, Kalender der Fahrtage, Kilometer je Monat, Rekorde des Jahres. Die Pfeile wechseln das Jahr. Ein Tag im Kalender öffnet seine Fahrt.
3. **Rekorde:** dieselben Werte wie am Mac. Ein Rekord öffnet seine Fahrt.
4. **Ziele:** **Ziel hinzufügen …** legt ein Ziel an. Der Stift ändert es, „Ziel löschen“ entfernt es. Das Ziel erscheint nach dem Sync auch am Mac.

## E. iPad: Vergleichen und Zusammenfügen (B-296)

1. **Fahrten**, über der Liste **Auswählen**. Zwei Fahrten antippen: Rechts stehen „2 Fahrten im Vergleich“, die Karte mit beiden Linien, das Diagramm und die Tabelle mit ★ und „Ø deiner Fahrten“.
2. Eine dritte und vierte Fahrt antippen: Der Vergleich wächst mit. Bei der fünften steht ein Hinweis, Zusammenfügen geht weiter.
3. **Zusammenfügen …** bei zwei Fahrten desselben Tages: Name und Summen stimmen. Nach **Zusammenfügen** steht in der Liste eine Fahrt mit der Summe. Am Mac lässt sie sich wieder trennen.
4. **Fertig** oder **Abbrechen** beendet das Auswählen.

## F. iPad: Drag & Drop und PDF (B-297)

1. Wattspur und die Dateien-App im **Split View**. Eine FIT- oder GPX-Datei auf die Fahrtenliste ziehen: Die Liste bekommt einen Rahmen, die Fahrt wird importiert (mit denselben Fragen wie bei „Dateien importieren …“).
2. In einer Fahrt der Teilen-Knopf: **GPX teilen** und **PDF teilen**. Das PDF hat eine Seite mit Name, Datum, Gerät, Karte, Kennzahlen, Tempo und Höhe.
3. Am **iPhone** teilt der Knopf weiter direkt die GPX-Datei.

## G. Papierkorb und Geräte am iPad (B-297)

1. **Papierkorb:** Eine Fahrt in den Papierkorb legen, zurückholen, endgültig löschen.
2. **Profil:** Ein Gerät hinzufügen und bearbeiten, wie am iPhone.
