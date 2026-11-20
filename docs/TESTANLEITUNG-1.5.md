# Testanleitung iPhone und iPad 1.5 „abrunden“

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Die Stories: B-228, B-334 bis B-337.

Kein neues CloudKit-Feld. Neue Einstellung je Gerät, nicht synchronisiert: der Schalter „Abweichung vom Schnitt“ am iPad. Der Mac bleibt bei 1.10.2.

## 0. Vorher

- Am iPhone und am iPad **1.5 (37)** aus TestFlight, am Mac weiter **1.10.2**.
- Warten, bis die Fahrten über iCloud da sind.
- Offen aus 1.4: der Test nach `TESTANLEITUNG-1.4.md`, wenn noch nicht fertig.

## A. Highlights am iPhone (B-228)

1. **Übersicht:** Unter „Fahrt starten“ steht die Kachel **Highlights**. Ohne Ziel zeigt sie „Jahr, Rekorde und Ziele“ und die Zahl deiner Rekorde, mit Ziel das nächste Ziel und einen Balken.
2. Quer (in der Halterung): Die Kachel steht links unter der letzten Fahrt.
3. Kachel antippen. **Jahr:** drei Kacheln je Reihe, darunter der Kalender der Fahrtage, ohne zu scrollen. Der Kalender lässt sich zur Seite schieben und zeigt zuerst die letzten Wochen. Ein Tag öffnet seine Fahrt.
4. Die Pfeile wechseln das Jahr. Kilometer je Monat und Rekorde des Jahres stehen darunter.
5. **Rekorde:** dieselben Werte wie am Mac. Ein Rekord öffnet seine Fahrt.
6. **Ziele:** **+** legt ein Ziel an, der Stift ändert es. Das Ziel erscheint nach dem Sync am Mac und am iPad.
7. **Rad** und **Fahrzeuge** umschalten: Die Highlights folgen der Sportart.

## B. Vergleich: Abweichung vom Schnitt (B-334, iPad)

1. **Fahrten › Auswählen**, zwei Fahrten antippen.
2. Schalter **Abweichung vom Schnitt** einschalten: Unter jedem Wert steht z. B. „+157 m · +90 %“. Die Zahlen stimmen mit dem Mac überein.
3. Ausschalten: Die Zeilen sind weg. Die Wahl bleibt beim nächsten Start.

## C. Fahrt trennen (B-335, iPhone und iPad)

1. Am iPad zwei Fahrten desselben Tages **zusammenfügen**.
2. Die neue Fahrt öffnen: Knopf **In Originalfahrten trennen**. Es kommt die Frage „In die Originalfahrten trennen?“.
3. Bestätigen: Die beiden Originalfahrten stehen wieder einzeln in der Liste, mit Name und Werten wie vorher.
4. Noch einmal zusammenfügen und am **iPhone** in der Liste mit langem Druck trennen.
5. Eine normale Fahrt hat den Knopf nicht.
6. Nach dem Sync sieht der Mac dasselbe.

## D. PDF teilen (B-336)

1. **Highlights › Jahr › PDF teilen** (iPad und iPhone): zwei Seiten, zuerst Kacheln, Kalender und Monate, dann die Rekorde des Jahres. Der Kalender passt ganz auf die Seite.
2. **Rekorde** und **Ziele** teilen je eine Seite. Ohne Ziele fehlt der Knopf bei Ziele.
3. **Vergleich › PDF teilen** (iPad): Seite 1 Titel und Karte mit allen Linien, Seite 2 die Tabelle. Mit eingeschalteter Abweichung steht sie auch im PDF.
4. Die PDFs in Dateien sichern und öffnen. Helles Blatt, nichts abgeschnitten.

## E. Herkunftsfilter (B-337, iPhone und iPad)

1. **Fahrten:** Das Menü **Quelle** erscheint nur, wenn es eine GPX-Fahrt gibt (Import oder Aufnahme am iPhone).
2. **Bosch-FIT:** nur Fahrten aus Flow, auch die mit angehängter GPX.
3. **GPX (auch Aufnahmen):** importierte GPX-Dateien und deine Aufnahmen vom iPhone.
4. Die Zahl „x von y Fahrten“ stimmt. ✕ setzt auch die Quelle zurück.

## F. Mac unverändert

1. Am Mac **1.10.2**: Highlights, Vergleich und der Quellfilter in der Liste wie vorher.
