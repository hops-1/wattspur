# Testanleitung iPhone 1.6.3 und Mac 1.10.4

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Das ist ein kleines Release ohne neue Funktion: Mac und iPad teilen sich jetzt die Texte und Formate von Analyse, Vergleich und Highlights (B-355). Kein neues CloudKit-Feld.

Nur mit Demo-Daten oder eigenen Testdateien prüfen.

## 0. Vorher

- Am iPhone und iPad **1.6.3 (44)** aus TestFlight.
- Am Mac **1.10.4** aus dem notarisierten DMG, geöffnet aus `/Applications`.

## A. Vergleich (S-18)

1. Am iPad zwei Fahrten mit verschiedener Fahrzeit vergleichen (Fahrten › Auswählen, zwei antippen). Fahrzeit, Gesamtdauer und Pause stehen mit Sekunden, z. B. „00:48:36“, wie am Mac.
2. Dasselbe mit offener Seitenleiste (schmale Spalte). Die Zahlen bleiben in einer Zeile; sie dürfen etwas kleiner werden.
3. Die Abweichung steht wie am Mac, z. B. „+47 min · +96 %“.
4. In der Fahrtenliste und bei der Aufnahme am iPhone bleibt die kurze Dauer, z. B. „0:49“.

## B. Analyse und Highlights (S-17, S-19)

1. Am iPad und am Mac dieselbe Auswertung öffnen, z. B. **Jahr**. Überschrift („2026“), Unterzeile („… Fahrten · Vergleich mit 2025“), Fahrzeit („… Std., … Min.“) und „kein Vergleichswert“ lesen sich gleich.
2. **Highlights › Jahr** und **Rekorde** am iPad und am Mac: Titel, Werte („19,5 km“, „0:49 h“) und Daten („26. Apr.“) lesen sich gleich.
3. **Ziele:** Zeitraum und Einheit („Diese Woche“, „Kilometer“) lesen sich gleich.

## C. PDF (S-22)

1. Am iPhone das PDF einer Fahrt teilen. Die letzte Zeile lautet „Erstellt mit Wattspur am … um …. Kalorien und CO₂ sind Schätzwerte.“, wie am Mac.
2. Dasselbe beim PDF des Vergleichs und der Highlights.

## D. Mac

1. **Über Wattspur** zeigt 1.10.4.
2. Auswertung, Vergleich und Highlights sehen aus wie in 1.10.3.
