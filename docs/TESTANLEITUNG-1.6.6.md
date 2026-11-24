# Testanleitung iPhone 1.6.6 und Mac 1.10.5

Für Nils. Jeder Punkt bekommt ✓, oder ✗ mit einer kurzen Notiz oder einem Screenshot. Das Release ist klein und bringt keine neue Funktion: Es enthält den Rest aus dem Review 1.6.2 (B-353 bis B-361) und den Fix für die Kachel in CarPlay aus dem Test von 1.6.5 (B-379). Kein neues CloudKit-Feld.

Prüfe nur mit Demo-Daten oder eigenen Testdateien. Im Auto nur im Stand prüfen.

## 0. Vorher

- Am iPhone und iPad **1.6.6 (47)** aus TestFlight. *Mehr › Über Wattspur* zeigt die Nummer.
- Am Mac **1.10.5** aus dem notarisierten DMG, geöffnet aus `/Applications`.

## A. CarPlay: die Kachel öffnet die App (B-379)

1. Im Auto eine Fahrt starten, am iPhone oder in CarPlay. Im CarPlay-Dashboard erscheint die Kachel „Wattspur“ mit der Strecke.
2. **Tipp auf die Kachel:** Wattspur öffnet sich in CarPlay und zeigt die Tafel mit Tempo, Zeit und Strecke.
3. In Wattspur **Ende** tippen, dann in der Frage auf **Abbrechen**. Zurück zum Dashboard, wieder auf die Kachel tippen: Die Tafel erscheint.
4. **Am iPhone:** Tipp auf die Live-Aktivität im Sperrbildschirm. Wattspur öffnet sich mit der Aufnahme wie bisher. Kein Import, kein anderer Tab.

## B. Teilen großer GPX-Dateien (B-361)

1. In der Dateien-App 5 GPX-Dateien mit je etwa 50 MB auswählen (lange Aufzeichnungen, z. B. aus einem Radcomputer).
2. **Teilen › Wattspur.** Die Erweiterung schließt sich ohne Fehler.
3. Wattspur öffnen: Alle 5 Fahrten werden importiert.
4. Dasselbe mit einer FIT-Datei und einer GPX-Datei zusammen: Beide kommen an.

## C. Import und Bibliothek (B-354)

1. Am iPhone eine FIT-Datei importieren, danach dieselbe Datei noch einmal. Der zweite Import meldet „Schon vorhanden“, die Fahrt steht nur einmal da.
2. Am Mac **Hilfe › Diagnose erstellen …**: Der Bericht hat eine Zeile „Failed reads of the library (since launch)“ mit „–“.

## D. Highlights am Mac und iPad (B-356)

1. **Highlights › Jahr** am Mac und am iPad: Die Heatmap beginnt am 1. Januar in der richtigen Wochentags-Zeile, die Monatsnamen stehen über der Woche mit dem Monatsersten.
2. **Rekorde:** Ein Rekord aus einer Fahrt der letzten 7 Tage trägt „Neu“, ältere nicht. Am Mac und am iPad gleich.
3. Ein Jahr mit 29. Februar (z. B. 2024, falls Fahrten da sind): Der Tag ist in der Heatmap da.

## E. Karte ohne Netz (B-360)

1. Am iPhone eine Fahrt mit Karte öffnen und etwas zoomen, dann den Flugmodus einschalten.
2. Die schon geladenen Kacheln bleiben, an neuen Stellen ist die Karte leer statt mit einer Fehlerseite.

## F. Mac

1. **Über Wattspur** zeigt 1.10.5.
2. Import, Highlights und Karte sehen aus wie in 1.10.4.
