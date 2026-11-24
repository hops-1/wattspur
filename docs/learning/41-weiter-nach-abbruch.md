# 41 – Weiter nach dem Abbruch

Stories: B-383 und B-384 (iOS 1.6.9, 24.11.2026), aus der Autofahrt von Nils mit 1.6.8 (CarPlay, Google Maps, Podcasts, Kamera). Davor: [Lern-Notiz 40](40-leichter-im-hintergrund.md).

## Was gemacht wurde
- **Befund aus den Speicherberichten:** iOS schreibt bei Speichermangel einen `JetsamEvent`. Er nennt jeden Prozess mit Speicher, Stufe und Grund. Wattspur belegte nur 54 und 68 MB und wurde trotzdem beendet (`vm-pageshortage`). Es lief im Hintergrund in Stufe 40, die Navigation vorn in CarPlay und die Ton-App in Stufe 100.
- **Entscheidung im Kern (B-383):** `UnfinishedRecording` sagt beim Start, was mit einer nicht beendeten Aufnahme passiert. Bis 15 Minuten nach dem letzten Eintrag läuft sie weiter. Ist sie älter, fragt die App. War sie noch „Bereit“, wird sie verworfen.
- **Weiter beim Start (B-383):** Der `Recorder` setzt die Fahrt schon in seinem `init` fort, vor jeder Ansicht. So startet er die Ortsabfrage auch dann sofort, wenn iOS die App im Hintergrund neu startet. Eine Pause kommt nicht dazu; eine Lücke über 2 km wird wie bisher ein neues Stück.
- **Live-Aktivität übernehmen (B-383):** Die Live-Aktivität der Fahrt überlebt den Abbruch. Die App übernimmt sie, statt sie zu beenden. Eine neue dürfte sie im Hintergrund gar nicht starten.
- **Auto-Start merken (B-383):** `RideRecording.startedReady` hält fest, dass die Fahrt mit „Bereit“ begann. Nach einem Abbruch endet sie darum weiter von selbst.
- **CarPlay (B-383):** Für eine nicht beendete Fahrt zeigt CarPlay nur **Aufnahme fortsetzen**. „Fahrt starten“ hätte sie verworfen.
- **Die Kachel in CarPlay (B-384):** Erst die Doku gelesen, dann im CarPlay Simulator geprüft, mit dem iPhone am Kabel. Ein Tipp auf die Kachel öffnet nichts, mit und ohne Link. Ein Tipp auf das Widget „Diese Woche“ öffnet Wattspur in CarPlay. Der Link aus B-379 ist wieder weg, Handbuch und FAQ erklären es.

## Was die Stories gelernt haben
- **Weniger Speicher schützt nicht vor jedem Abbruch.** iOS beendet Apps nach Stufen, nicht nach Größe. Eine App, die im Hintergrund aufnimmt, steht tiefer als die Navigation vorn. Wichtig ist darum, dass die Fahrt einen Abbruch übersteht.
- **Apple sagt, was beim Neustart zu tun ist.** Eine App, die Orte empfängt, soll die Ortsabfrage beim Start sofort wieder einschalten. Im Simulator startete iOS die App nach `kill -9` schon eine Sekunde später im Hintergrund neu.
- **Erst prüfen, dann bauen.** Der Fix B-379 beruhte auf einer Vermutung und wirkte im Auto nicht. Der CarPlay Simulator mit dem echten iPhone hätte das in fünf Minuten gezeigt.

## Swift-Konzepte
- **`CLServiceSession` und `CLBackgroundActivitySession`:** Sie halten die Ortsabfrage am Leben. Nach einem Abbruch müssen beide beim Start neu angelegt werden.
- **`Activity<…>.activities`:** die Live-Aktivitäten der App, auch die aus einem früheren Start. Man kann sie übernehmen und weiter aktualisieren.
- **Optionales Feld in einem `Codable`-Typ:** `storedStartedReady` ist optional. Ältere gespeicherte Aufnahmen lassen sich so weiter lesen.

## Selbst nachprüfen
1. `swift test --no-parallel --filter UnfinishedRecording` im Paket `WattspurKit`: 7 Tests grün.
2. Im Simulator eine Demo-Aufnahme starten (`-WattspurDemoRecord YES`, Strecke mit `simctl location start`). Den Prozess mit `kill -9` beenden: Die Aufnahme läuft ohne Frage weiter, und in `Documents/Diagnose` steht die Zeile „continued after the app was ended“.
