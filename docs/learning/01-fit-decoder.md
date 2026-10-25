# 01 – FIT-Dateien lesen

## Was
Ein eigener Decoder (`FIT/FITDecoder.swift`) liest die Bosch-Exporte, ein Importer (`Import/RideImporter.swift`) macht daraus eine Fahrt mit Summen und einer Zeitreihe.

## Wie eine FIT-Datei aufgebaut ist
1. **Header** (14 Byte): Kennung `.FIT`, Protokoll- und Profilversion, Länge der Daten.
2. **Nachrichten**, jeweils mit 1 Byte Kopf:
   - **Definitionsnachricht**: „Lokaler Typ 3 bedeutet ab jetzt: Nachricht *record*, Felder 253 (4 Byte), 0 (4 Byte), …“. Sie beschreibt nur das Layout.
   - **Datennachricht**: nur die rohen Bytes in genau diesem Layout. Das spart Platz, weil die Feldnamen nicht jedes Mal mitgeschickt werden.
   - **Compressed Timestamp**: eine Datennachricht, deren Zeitstempel als 5-Bit-Versatz im Kopfbyte steckt.
3. **CRC** (2 Byte): Prüfsumme über alles davor. Ist sie falsch, ist die Datei beschädigt.

Werte sind **roh und skaliert gespeichert**, z. B. Geschwindigkeit in mm/s (÷ 1000 = m/s), Höhe als (Wert ÷ 5) − 500 m, Position in „Semicircles“ (× 180 / 2³¹ = Grad). Jeder Typ hat einen **Ungültig-Wert** (z. B. `0xFFFF`), der „keine Messung“ bedeutet.

## Bosch-Besonderheiten
- GPS und Sensorwerte kommen in **getrennten** `record`-Nachrichten, die nur den Zeitstempel teilen. `mergeRecords` legt sie pro Sekunde zusammen.
- Trittfrequenz ist nur in jedem dritten Datensatz. Für Diagramme wird der letzte Wert gehalten (`cadence`), für Statistiken zählen nur echte Messungen (`cadenceMeasured`).
- Summen (Strecke, Ø-Werte, Anstieg) übernehmen wir 1:1 aus der `session`, damit alles zur Flow-App passt.
- Die Arbeit (kJ) wird über alle Roh-Datensätze summiert, auch doppelte Sekunden. Nur so kommen exakt die 360 kcal der Flow-App heraus.

## Swift-Konzepte
- **`struct` statt `class`** für Werte wie `RideSample`: Kopien sind unabhängig, nichts ändert sich „hinterrücks“.
- **`Sendable`**: Der Typ darf gefahrlos zwischen Threads weitergegeben werden. Swift 6 prüft das beim Kompilieren (*strict concurrency*).
- **`enum` mit zugeordneten Werten** (`FITValue.unsigned(UInt64)`, `.string(String)` …) modelliert „einer von mehreren Typen“.
- **Typisierte Fehler**: `func decode(_:) throws(FITDecodingError)` sagt genau, welche Fehler kommen können, z. B. `.checksumMismatch` oder `.truncated(offset:)`.
- **`inout`** beim `ByteReader`: Die Funktion darf die Lese-Position des Aufrufers weiterschieben.
- **Bit-Operationen** (`header & 0x80`, `>> 5`): Einzelne Bits des Kopfbytes tragen Bedeutung.

## Tests
`FITDecoderTests` und `FITRideImporterTests` prüfen die Beispielfahrt gegen die Werte aus deinem Screenshot (2916 s, 19 543 m, 135 W …) und die Robustheit: falsche Prüfsumme, abgeschnittene Datei, Datenmüll. Sie dürfen nie zum Absturz führen, sondern nur zu einem sauberen Fehler.

## Nachtrag: Datei eines Testers mit Flow+ (B-045, V-02)
- **Format:** Der Export aus der Flow-App mit Flow+-Abo ist genauso aufgebaut wie deine eigenen Dateien.
  - Gleicher Dateikopf (Protokoll 2.0, Profil 21.67).
  - Dieselben fünf Nachrichtentypen mit denselben Feldern.
  - Keine Entwicklerfelder: Akku, Motorleistung oder Unterstützungsmodus stehen auch mit Abo nicht in der Datei.
- **Robustheit:** Die Fahrt hat 101 km, 10 h und 39 655 Records. Sie wird in 36 ms gelesen, und die Summen stimmen mit der `session` überein.
- **Ø Leistung bei Bosch:** Bosch mittelt nur über die Sekunden mit Leistung > 0.
  - Das passt bei beiden Fahrten genau: 135 W bei Reinheim, 153 W gegenüber 154 W bei der Tester-Fahrt.
  - Bei der Tester-Fahrt sind 62 % der Werte 0, er ist also viel gerollt.
  - Die Arbeit (Σ Leistung × 1 s) ist deshalb deutlich kleiner als Ø Leistung × Fahrzeit: 1 117 kJ statt rund 3 100 kJ. Wattspur rechnet das richtig, das Handbuch erklärt es jetzt unter „Kennzahlen“.
- **GPX** enthält nur Position, Höhe und Zeit, weder Leistung noch Trittfrequenz.
