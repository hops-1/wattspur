# 09 – Beispielfahrt: anonymisieren und mitliefern

Stories: B-028, V-05 (ONB-02, NFR-12)

## Was gebaut wurde
- **Anonymisierer** (`Kit: FIT/FITAnonymizer.swift`): Er macht aus einer echten FIT-Datei eine, die man weitergeben kann.
  - Alle Positionen werden um einen festen Versatz verschoben.
  - Auf den ersten und letzten 500 m werden die Positionen gelöscht, damit Start und Ziel (oft die Haustür) nicht zu finden sind.
  - Positionen in Zusammenfassungs-Nachrichten (session, lap, Begrenzungsrahmen) werden gelöscht.
  - Alle Zeiten wandern um ganze Wochen.
  - Seriennummern und Entwicklerfelder werden geleert.
  - Leistung, Trittfrequenz, Tempo, Höhe und alle Bosch-Summen bleiben **unverändert**.
- **Werkzeug** `anonymize-fit` (ein zweites Ziel im Swift Package):
  ```bash
  cd Packages/WattspurKit
  swift run anonymize-fit <echt.fit> ../../App/SampleRide.fit --lat <Grad> --lon <Grad> --weeks -5
  ```
  Den Versatz wählst du selbst und schreibst ihn nirgends auf. Wer ihn kennt, könnte die Route zurückschieben; Start und Ziel bleiben aber in jedem Fall verborgen.
- **`App/SampleRide.fit`**: die anonymisierte Reinheim-Fahrt mit zufälligem Versatz, fünf Wochen früher. Sie ist die einzige FIT-Datei außer der Test-Fixture, die `.gitignore` durchlässt.
- **Modell**: `Ride.isSample` (Standardwert `false`, CloudKit-fähig).
  - `RideLibrary.importSample(data:name:)` importiert die Fahrt höchstens einmal und holt sie bei Bedarf aus dem Papierkorb zurück.
  - `removeSamples()` löscht sie endgültig, samt Originaldatei.
- **Oberfläche** (Entwurf auf dem Design-Canvas unter „v1.0“):
  - Einrichtungsassistent, letzter Schritt: Checkbox „Beispielfahrt laden“, standardmäßig aus.
  - Liste: Badge „Beispiel“. Die Fahrt wird nicht in „N Fahrten insgesamt“ gezählt.
  - Detail: Hinweisleiste mit „Beispielfahrt entfernen“ und unter der Karte ein Satz dazu, was verändert wurde.
  - Einstellungen › Allgemein: „Beispielfahrt laden“ bzw. „entfernen“.
  - Auswertung und Profil lassen die Beispielfahrt weg. Nur wenn man sie in der Liste ausdrücklich auswählt, wertet die Auswertung sie aus.

## Warum so
- **Datei patchen statt neu schreiben**: Wattspur hat nur einen Decoder, keinen Encoder. Der Anonymisierer geht den Container genauso durch wie der Decoder und merkt sich dabei, an welchem Byte jedes Feld steht. Dann überschreibt er gezielt einzelne Werte und berechnet zum Schluss die Prüfsumme neu. Die Datei bleibt so eine echte Bosch-Datei, und der Import läuft genau wie bei echten Fahrten.
- **GPS ohne eigene Distanz**: Bosch schreibt GPS und Sensoren in getrennte `record`-Nachrichten (siehe 01). Ein GPS-Record kennt seine Distanz nicht, deshalb nimmt der Anonymisierer die zuletzt gemessene Distanz aus dem Sensorstrom. Die liegt höchstens eine Sekunde zurück.
- **Ganze Wochen**: FIT spart Platz mit „komprimierten Zeitstempeln“, die nur die letzten 5 Bit (32 s) speichern. Eine Woche ist ein Vielfaches von 32 s, also bleiben diese Kurzformen richtig. Wochentag und Uhrzeit stimmen ebenfalls weiter.
- **Endgültig löschen statt Papierkorb**: Die Beispielfahrt lässt sich jederzeit neu laden, ein Papierkorb-Eintrag wäre nur Ballast.
- **Checkbox aus**: Wer die App mit eigenen Fahrten startet, braucht keine fremde Fahrt in der Liste.

## Swift-Konzepte
- **`executableTarget`** im `Package.swift`: ein kleines Kommandozeilenprogramm neben der Bibliothek. `main.swift` darf Code auf oberster Ebene enthalten, ohne `@main`.
- **Bitmuster**: `UInt32(bitPattern:)` und `Int32(bitPattern:)` deuten dieselben 4 Bytes als vorzeichenlos oder vorzeichenbehaftet. So lassen sich Koordinaten (sint32) und Zeiten (uint32) mit einer einzigen Schreibfunktion patchen.
- **Endianness**: Bosch schreibt Big Endian (höchstes Byte zuerst), die meisten Geräte Little Endian. Jede Definition sagt, welches gilt.
- **Leichte Migration**: Ein neues Feld mit Standardwert (`isSample = false`) übernimmt SwiftData beim nächsten Start ohne Migrationscode.
- **`rides.count { !$0.isSample }`**: `count(where:)` zählt direkt, ohne erst ein gefiltertes Array zu bauen.

## V-05, zweiter Teil: die Test-Fixture
- `reinheim-rundfahrt.fit` ist jetzt ebenfalls mit `anonymize-fit` erzeugt, mit eigenem Versatz (nicht derselbe wie bei `App/SampleRide.fit`, nirgends im Repo), vier Wochen früher.
- Geänderte Erwartungen: Startzeit (2026-09-20 statt 2026-10-18), Seriennummer (jetzt `nil`), weniger Samples mit Position (Start und Ende fehlen). Statt der ersten Koordinate prüft der Test jetzt, dass die erste Position erst nach etwa 500 m kommt. Eine verschobene Koordinate fest einzutragen hätte zusammen mit der alten Zahl aus der Historie den Versatz verraten.
- Die echte Seriennummer und die Bosch-Fahrt-ID im Dateinamen sind in den Tests durch erfundene Werte ersetzt.
- Die alten Dateien stehen weiter in der Git-Historie: Das öffentliche Repo deshalb ohne diese Historie anlegen.

## Zum Ausprobieren
1. Einstellungen › Allgemein › „Beispielfahrt laden“.
2. In der Liste erscheint „Beispielfahrt“ mit Badge, aber die Zahl „N Fahrten insgesamt“ ändert sich nicht.
3. Im Detail fehlen Anfang und Ende der Route auf der Karte. Die Kennzahlen sind dieselben wie bei der echten Reinheim-Fahrt.
4. „Beispielfahrt entfernen“: Die Fahrt ist weg, auch aus dem Papierkorb.
