# Testanleitung iPhone und iPad 1.3 „iPad 1“

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Die Stories: B-291, B-292.

Kein neues CloudKit-Feld: Das Schema bleibt, wie es ist. Die Einstellungen fürs iPad (Seitenleiste auf Symbolen, Ansicht der Diagramme) gelten je Gerät und werden nicht synchronisiert.

Am iPad gibt es noch keine Aufnahme (B-293, ohne Version). Getestet wird am WLAN-iPad (iPad 8, iPadOS 26.7.3).

## 0. Vorher

- Am iPad und am iPhone **1.3 (33)** aus TestFlight. Der Mac bleibt **1.10.1**.
- Die Mediathek kommt über iCloud aufs iPad. Warten, bis die Fahrten da sind.

## A. iPad: Seitenleiste (B-292)

1. Links die Seitenleiste: oben **Rad · Fahrzeuge**, dann **Mediathek** mit Übersicht, Fahrten, Karte, Papierkorb, darunter **Profil** und **Einstellungen**.
2. Der Knopf oben rechts in der Leiste klappt sie auf die Symbole zusammen und wieder auf. Die App beenden und neu öffnen: Die Wahl bleibt.
3. **Einstellungen** öffnet die Liste der Rubriken. Jede Rubrik öffnet sich, **Zurück** führt zur Liste.
4. **Rad** und **Fahrzeuge** wechseln: Übersicht, Fahrten und Karte zeigen nur die Fahrten der Sportart.

## B. iPad: Übersicht (B-292)

1. **Quer:** links die letzte Fahrt mit großer Karte, rechts die vier Kacheln. Mit auf- und mit zugeklappter Leiste.
2. **Hochkant:** oben die letzte Fahrt mit großer Karte, darunter die vier Kacheln in zwei Reihen. Kein Text steht Buchstabe für Buchstabe untereinander.
3. Eine Kachel antippen: Die Fahrten öffnen sich mit dem Zeitraum als Filter.
4. Kein Knopf **Fahrt starten**.

## C. iPad: Fahrten und Fahrt (B-292)

1. Links die Liste, rechts die Fahrt. Eine andere Fahrt antippen: Rechts wechselt die Fahrt.
2. Die Filter über der Liste sind ganz zu sehen. Passen sie nicht in eine Zeile, stehen sie in einer zweiten (etwa mit einem Rad wie „Cube One22“ als Filter).
3. In der Fahrt bleiben Kopf und Karte oben stehen. Nur die Diagramme und Kacheln darunter scrollen.
4. **Einstellungen › Ansicht:** **Gestapelt** zeigt die Diagramme wie am iPhone zum Wischen, **Untereinander** alle wie am Mac.

## D. iPad: Karte und schmales Fenster (B-291, B-292)

1. **Karte** zeigt alle Fahrten der Sportart.
2. **Split View** oder Stage Manager: Wattspur schmal neben einer anderen App. Erwartet: die Tabs des iPhone. Wieder breit: die Seitenleiste.
3. Siri: „Starte eine Fahrt in Wattspur“ sagt am iPad, dass das iPad noch nicht aufnimmt.

## E. iPhone: unverändert

1. Übersicht, Fahrten, Karte und Aufnahme wie in 1.2 (30). Die Filter über der Fahrtenliste scrollen weiter zur Seite.
