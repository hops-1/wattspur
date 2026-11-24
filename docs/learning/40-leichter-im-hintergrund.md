# 40 – Leichter im Hintergrund

Stories: B-381 und B-382 (iOS 1.6.8, 24.11.2026), die Folgen aus dem Abbruch bei der Radtour mit 1.6.6 (B-380, [Lern-Notiz 39](39-kein-neuladen-bei-aufnahme.md)). Regeln: [ARCHITECTURE](../ARCHITECTURE.md), Regel 16.

## Was gemacht wurde
- **Lesen in einem Schritt (B-381):** `LibraryReading` liest alles, was die Bildschirme des iPhones zeigen, und gibt nur Werte zurück. Vorher waren es zehn einzelne Abrufe und ein weiterer je zusammengelegter Fahrt.
- **Lesen im Hintergrund (B-381):** `LibraryReader` ist ein `@ModelActor` mit eigenem `ModelContext`. Er liest, wenn iCloud, der Sync-Abgleich oder die Rückkehr der App es verlangen. Der Haupt-Thread setzt nur das Ergebnis. Ein Zähler sorgt dafür, dass ein altes Ergebnis kein neueres überschreibt.
- **Messen statt raten (B-382):** Im Simulator mit 240 Demo-Fahrten und einer simulierten Strecke, gemessen mit `footprint`. Die Liste braucht 41 MB, eine Karte rund 50 MB mehr. Die Aufnahme selbst wächst kaum.
- **Karte im Hintergrund abbauen (B-382):** Die Karte der Aufnahme verschwindet, solange die App im Hintergrund ist. Der Zoom liegt außerhalb der Karte und kommt mit ihr zurück. Im Simulator: 47 MB statt 97 MB.
- **Nichts unter der Aufnahme (B-382):** Solange die Aufnahme den Bildschirm deckt, sind die Tabs nicht aufgebaut.

## Was die Stories gelernt haben
- **Die erste Vermutung war falsch.** Ich hatte die Fahrten der Bibliothek im Speicher vermutet. Die Messung zeigte die Karten. Erst messen, dann ändern.
- **Der Simulator zeigt nicht alles.** Am iPhone liegen die Kartenkacheln im Grafikspeicher, den `footprint` im Simulator nicht mitzählt. Darum braucht es noch die Messung am Gerät.
- **Sofort oder im Hintergrund ist eine Frage für den Nutzer.** Nach der eigenen Aktion will der Fahrer das Ergebnis gleich sehen, darum bleibt dieses Lesen sofort. Was von außen kommt, darf ein paar Sekunden dauern.

## Swift-Konzepte
- **`@ModelActor`:** ein Actor mit eigenem `ModelContext` auf demselben `ModelContainer`. Modell-Objekte dürfen den Actor nicht verlassen, nur `Sendable`-Werte.
- **`footprint` und `heap`:** Werkzeuge von macOS, die den Speicher eines Prozesses zeigen, auch eines Simulator-Prozesses.
- **`scenePhase`:** zeigt, ob die App vorn, inaktiv oder im Hintergrund ist. Eine Ansicht kann damit Teile abbauen.

## Selbst nachprüfen
1. `swift test --filter LibraryReading` im Paket `WattspurKit`: 3 Tests grün.
2. `scripts/check-architecture.sh` meldet „architecture: ok“.
