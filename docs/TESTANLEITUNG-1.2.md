# Testanleitung iPhone 1.2 + Mac 1.10 „Sportarten, Teil 2: Rubriken“

Für Nils. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Die Stories: B-288, B-289, dazu die Reste aus 1.1.1 (B-323, B.4, B-319).

Kein neues CloudKit-Feld: Das Schema bleibt, wie es ist. Die Wahl der Sportart ist eine Einstellung je Gerät und wird nicht synchronisiert.

## 0. Vorher

- Am iPhone **1.2 (30)** aus TestFlight, am Mac **1.10.1** aus dem DMG (vorher 1.2 (29) und 1.10).

## A. Mac: Umschalter (B-288)

Ergebnis: alles ✓ (Nils, 18.11.2026, Mac 1.10.1).

1. Oben in der Seitenleiste steht **Rad · Fahrzeuge**. Mit nur Fahrrädern steht er nicht da. ✓ (am 18.11. im Demo-Modus geprüft)
2. **Fahrzeuge** wählen. Erwartet:
   - Die Liste zeigt nur Fahrten mit Auto oder Motorrad, auch solche ohne Gerät.
   - Der Gerätefilter heißt **Alle Fahrzeuge** und bietet nur Fahrzeuge an.
   - Auswertung, Highlights und Karte zeigen nur Fahrzeug-Fahrten.
3. **Rekorde bei Fahrzeugen:** nur Strecke, Dauer, Höhenmeter, Ø Tempo, Höchsttempo und Kurvigkeit. Keine Leistung, keine Serie.
4. **Tour-Detail einer Autofahrt:** eine Zeile **Höchsttempo**; keine Leistung, Trittfrequenz, Kalorien und kein CO₂.
5. Zurück auf **Rad**: alles wie vor 1.10. Die Ziele zählen nur Rad.
6. Die App beenden und neu öffnen: Die Wahl bleibt.

## B. iPhone: Kapsel (B-289)

Ergebnis: alles ✓ (Nils, 18.11.2026, iPhone 1.2 (30)).

1. **Übersicht:** oben die Kapsel **Rad ▾**. **Fahrzeuge** wählen. Erwartet: Kacheln, letzte Fahrt und „Alle Fahrten“ nur mit Fahrzeugen, Auto-Symbol auf den Kacheln.
2. **Fahrten:** die Kapsel steht als Erstes in der Filterleiste. Der Gerätefilter bietet nur Fahrzeuge.
3. **Karte:** die Kapsel zeigt nur das Symbol. Die Karte zeigt nur die Fahrten der Sportart.
4. Die Wahl gilt in allen drei Tabs gleich.

## C. iPhone: Aufnahme, Sperrbildschirm, Widget (B-289)

Ergebnis: alles ✓ (Nils, 18.11.2026, iPhone 1.2 (30)).

1. **Aufnahme mit dem Rad:** Die Punkte unter den Kacheln verdecken nichts. ✓ (am 18.11. im Simulator geprüft)
2. **Aufnahme mit Nugget**, Bildschirm sperren: Die Live-Aktivität zeigt die **Querbeschleunigung** in g. Mit Motorrad: die **Schräglage** in Grad. In der Pause steht dort nichts.
3. **Widget:** lange drücken › **Widget bearbeiten** › Sportart **Fahrzeuge**. Erwartet: die Woche und die letzte Fahrt der Fahrzeuge, mit Auto-Symbol. Ein zweites Widget mit **Rad** zeigt die Räder.

## D. Reste aus 1.1.1

1. **B-323 Siri:** „Starte eine Fahrt mit Nugget in Wattspur“ startet mit Nugget, ebenso mit einem Bike und mit „Auto“.
2. **B.4 0 auf 100:** Eine Autofahrt mit Sprint aus dem Stand zeigt die Zeit im Tour-Detail.
3. **B-319:** Eine Fahrt bei 80 bis 100 km/h in gleichmäßigen Kurven. Die Aufnahme bitte schicken, Claude wertet sie aus.

## E. Korrekturen aus dem Test vom 18.11. (iPhone 1.2 (30), Mac 1.10.1)

1. **B-324 Gerät beim Start:** Oben **Fahrzeuge** wählen, dann **Fahrt starten**: Ein Fahrzeug ist vorausgewählt (Nugget). Mit **Rad** ein Rad.
2. **B-325 iPhone drehen im Auto:** Während der Fahrt ein- oder zweimal zwischen hoch und quer drehen. In der Fahrt danach keine Spitze der Querbeschleunigung an diesen Stellen. Die GPX bitte schicken.
3. **B-325 Legende quer:** In der Aufnahme quer: Die Höhen-Legende steht neben dem Balken, nicht darunter.
4. **B-326 Mac-Karte:** Im Bereich **Karte** zwischen **Rad** und **Fahrzeuge** wechseln: Karte, Kacheln und Liste daneben zeigen nur die Fahrten der Sportart.
