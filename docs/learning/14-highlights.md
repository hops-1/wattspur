# 14 – Highlights: Jahr, Rekorde, Ziele

Stories: B-050 bis B-053 (ADV-J1, ADV-R1, ADV-R2, ADV-Z1, LIST-04), Mockups „Highlights“ und „RecordHints“ auf dem Design-Canvas, Entscheidungen in REQUIREMENTS.md 10.10

## Was gebaut wurde
- **Seitenleisten-Eintrag „Highlights“ (⌘4)** ersetzt den Teaser aus B-111. Drei Reiter, jeder mit „PDF exportieren“ oben links:
  - **Jahr:** fünf Kacheln (Strecke, Fahrten, Fahrzeit, Anstieg, CO₂) mit Vergleich zum Vorjahr, Kalender der Fahrtage, Kilometer je Monat und die Rekorde des Jahres. ⌘← / ⌘→ wechseln das Jahr.
  - **Rekorde:** sechs Karten; ein Klick zeigt die Fahrt (bei der Serie alle ihre Fahrten) in der Liste.
  - **Ziele:** Karten mit Fortschrittsbalken, Rest, „im Plan“ und kleinen Balken für die letzten Zeiträume; Blatt zum Anlegen, Ändern und Löschen.
- **Jahreskachel „Dein Jahr“** über der Fahrtenliste, ein Klick öffnet den Jahresrückblick.
- **Hinweis „Neuer Rekord“** oben im Fenster nach jedem Import, dazu ein Eintrag im Import-Protokoll. Rekordhalter bekommen ★ in der Liste und ein Abzeichen an der Kennzahl im Tour-Detail.
- **Rechnen im Kit** (`Highlights.swift`, `RecordCheck.swift`, 16 Tests): `RideRecords`, `YearReview`, `HeatLevel`, `GoalProgress` und das Modell `Goal`.

## Warum so
- **Ortsdatum statt Mac-Datum:** Eine Fahrt um 23:30 in Lissabon gehört zum Lissabonner Tag, auch wenn der Mac auf Berlin steht. `HighlightRide.localStartDate(in:)` verschiebt den Zeitpunkt um den Unterschied der beiden Zeitzonen; danach rechnet ein normaler `Calendar` mit Tagen, Monaten und Jahren.
- **Serie nach Kalendertagen:** Jeder Tag bekommt eine Nummer (Tage seit 1970). Dann ist eine Serie einfach eine Folge von Nummern ohne Lücke. Ein einzelner Tag ist keine Serie, sonst stünde bei jedem neuen Nutzer „Längste Serie: 1 Tag“.
- **Ø-Rekorde erst ab 5 km:** Sonst gewinnt eine 800-m-Fahrt bergab die höchste Ø Geschwindigkeit.
- **Gleichstand bleibt beim Ersten:** Wer den Wert zuerst erreicht hat, hält den Rekord. So springt das Abzeichen nicht zwischen Fahrten hin und her.
- **Neuer Rekord nur, wenn es einen alten gab:** Beim allerersten Import wäre sonst jeder Wert ein „neuer Rekord“.
- **Ein Prüfpunkt für alle Importwege:** Manueller Import, Drag & Drop und der überwachte Ordner schreiben alle einen `ImportRecord`. `ContentView` beobachtet nur das neueste davon (`@Query` mit `.onChange`) und prüft alle Einträge seit dem letzten Prüfzeitpunkt (`recordsCheckedUntil` in den UserDefaults). Beim ersten Start mit v1.3 beginnt die Prüfung „jetzt“, damit alte Importe nicht als neue Rekorde erscheinen.
- **Ziele in SwiftData, nicht in UserDefaults:** Sie sollen später mit iCloud zum iPhone. Deshalb CloudKit-tauglich: Standardwerte für alle Felder, keine `unique`-Einschränkung. „Je Zeitraum und Kennzahl höchstens ein Ziel“ prüft die App (`Goal.freeCombinations`), nicht die Datenbank.
- **Barrierefreiheit:** Der Kalender ist für VoiceOver ein Element mit Zusammenfassung („52 Fahrtage. Am meisten am 2. Mai mit 101,6 km“); die Monatsbalken haben einen Audio Graph. Das Abzeichen „Rekord“ hat Text in der Primärfarbe auf getöntem Grund (Kontrast), der Stern trägt die Akzentfarbe.

## Swift-Konzepte
- **Werte statt Datenbank-Objekte, wieder:** `HighlightRide` hält `RideFigures`, die Zeitzone und die ID. Alles Rechnen läuft darauf; die Tests brauchen kein SwiftData. Nur `RecordCheck` arbeitet mit dem `ModelContext` und hat dafür einen Test mit einer Bibliothek im Speicher.
- **`reduce(into:)` mit Tupel:** In `newRecords(importedAfter:)` teilt ein Durchlauf die Fahrten in „neu importiert“ und „schon da“.
- **Berechnete Eigenschaften mit `get`/`set` im `@Model`:** `Goal.metric` liest und schreibt `metricRawValue`. Gespeichert wird nur der `String`, die App arbeitet mit dem `enum`.
- **`ViewThatFits`:** Der Kalender probiert drei Größen der Kästchen und nimmt die erste, die in die Breite passt; die letzte Stufe scrollt waagerecht.
- **`.task(id:)` als Zeitgeber:** Der Rekord-Hinweis verschwindet nach 20 Sekunden. Kommt vorher ein neuer Hinweis, startet die Aufgabe mit der neuen ID neu.
- **`AccessibilityNotification.Announcement`:** VoiceOver liest den Hinweis vor, auch wenn der Fokus woanders ist.
- **Typgeprüfte Prädikate:** Ein `#Predicate` mit drei Bedingungen brachte den Compiler an seine Grenze („unable to type-check in reasonable time“). Zwei Bedingungen im Prädikat, die dritte (`countsInStatistics`) danach im Code, löst das.
