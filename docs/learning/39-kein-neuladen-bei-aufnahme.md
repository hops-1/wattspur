# 39 – Kein Neuladen während der Aufnahme

Story: B-380 (iOS 1.6.7, 24.11.2026), ein Fehler aus der Radtour von Nils mit 1.6.6. Regeln: [ARCHITECTURE](../ARCHITECTURE.md), Regel 16.

## Was passiert war
- Um 16:20 holte iCloud eine Änderung. Eine Sekunde später las Wattspur die ganze Bibliothek neu, im Haupt-Thread.
- Um 16:21 öffnete Nils die Kamera. Sie belegte über 600 MB, und das iPhone 13 lagerte nur noch aus. Das Neuladen dauerte über 10 Sekunden.
- Beim Wechsel in den Hintergrund muss eine App in 10 Sekunden antworten. Wattspur antwortete nicht, und iOS beendete die App (Code `0x8BADF00D`, „ate bad food“). Danach startete iOS die App neu, und die Aufnahme lief weiter.

## Was gemacht wurde
- `ReloadHold` im Kit merkt sich, ob ein Neuladen gerade warten muss. Während einer Aufnahme warten das Neuladen nach iCloud und das beim Zurückkommen der App. Am Ende der Aufnahme folgt ein einziges.
- Was der Fahrer selbst tut, lädt weiter sofort, zum Beispiel Speichern.

## Was die Story gelernt hat
- **Ein Absturzbericht nennt die Stelle, das Protokoll den Auslöser.** Der Bericht zeigte `PhoneLibrary.reload()`. Erst das Protokoll aus dem sysdiagnose zeigte, dass ein Import von iCloud den Anlass gab.
- **Langsam wird es erst unter Druck.** Ohne Kamera dauert das Neuladen nur kurz. Erst wenn der Speicher voll ist, wird es zur Falle. Darum gehört schwere Arbeit nicht in den Haupt-Thread, auch wenn sie im Test schnell ist.
- **Kälte macht die Akkuanzeige unruhig.** Bei 8 °C sprang die Anzeige zwischen 21 und 32 %. Das kam von der Kälte und dem Kabel, nicht von der App.

## Swift-Konzepte
- **Watchdog `0x8BADF00D`:** iOS beendet eine App, deren Haupt-Thread bei einem Szenenwechsel zu lange nicht antwortet.
- **`onChange(of:initial:)` mit einem eigenen `Equatable`-Wert:** fasst zwei Werte zusammen, hier Aufnahme und Bibliothek.

## Selbst nachprüfen
1. `swift test --filter ReloadHold` im Paket `WattspurKit`: 4 Tests grün.
2. `scripts/check-architecture.sh` meldet „architecture: ok“.
