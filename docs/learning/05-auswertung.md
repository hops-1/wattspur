# 05 – Auswertung: Summen, gewichtete Mittel, Balken und Trends

Stories: B-030 … B-034 (AGG-01 … AGG-04, TREND-01, TREND-02, LIST-06)

## Was gebaut wurde
- Seitenleisten-Eintrag **Auswertung** (vorher ausgegraut mit „v0.2“). Die Ansicht nutzt die ganze Fensterbreite, die Fahrtenliste ist dort ausgeblendet.
- Oben die **Zeitraum-Auswahl** Woche · Monat · Jahr · Frei · Alles. Woche, Monat und Jahr lassen sich mit ‹ › (auch ⌘← / ⌘→) zurückblättern, „Frei“ zeigt zwei Datumsfelder.
- **Summen**: Fahrten, Strecke, Fahrzeit, Anstieg, Arbeit, Kalorien, CO₂ und Ø Strecke je Fahrt, jeweils mit Veränderung zum Vorzeitraum.
- **Durchschnitte**: Geschwindigkeit, Leistung und Trittfrequenz nach Fahrzeit gewichtet, dazu Ø Fahrzeit je Fahrt.
- **Balkendiagramm**: Strecke, Fahrzeit oder Anstieg je Tag, Woche, Monat oder Jahr. Ein Klick (oder Hover) auf einen Balken zeigt Wert, Anzahl Fahrten und die Veränderung zum Balken davor.
- **Trends**: Ø Leistung, Ø Trittfrequenz und Ø Geschwindigkeit je Fahrt als Punkte, dazu ein gleitendes Mittel über 5 Fahrten.
- **Mehrfachauswahl**: In „Fahrten“ mit ⌘- oder ⇧-Klick mehrere Fahrten wählen. Rechts erscheint „3 Fahrten ausgewählt“ mit dem Knopf „Ausgewählte Fahrten auswerten“ (⌘⇧A). Die Auswertung zeigt dann genau diese Fahrten, ein Chip mit ✕ führt zurück zur Zeitraum-Auswertung.

## Warum so
- **Rechnen im Kit, Zeichnen in der App.** Alle Formeln liegen in `WattspurKit/Analysis/RideAnalysis.swift` und arbeiten auf `RideFigures`, einem einfachen Wertetyp mit den Zahlen einer Fahrt. So laufen die Tests ohne SwiftData und ohne Oberfläche (`RideAnalysisTests`, 9 Tests).
- **Gewichtete Mittel** (Requirements 3.3): Eine 2-Stunden-Fahrt soll mehr zählen als eine 10-Minuten-Fahrt. Formel: Σ(Ø-Wert × Fahrzeit) / Σ Fahrzeit. Fahrten ohne den Wert (z. B. keine Trittfrequenz) fallen aus Zähler *und* Nenner heraus. Bei der Geschwindigkeit ergibt das genau Gesamtstrecke / Gesamtfahrzeit.
- **Vorzeitraum = ganzer Vorzeitraum** (deine Entscheidung): Oktober bis heute wird mit dem ganzen September verglichen. Am Monatsanfang sehen die Prozente deshalb oft negativ aus. Bei „Frei“ ist der Vorzeitraum gleich lang und liegt direkt davor; bei „Alles“ und bei einer Auswahl gibt es keinen Vergleich.
- **`RidePeriod` wiederverwendet**: `AnalysisPeriod` verschiebt nur das „jetzt“ um `offset` Wochen/Monate/Jahre und fragt dann `RidePeriod.thisWeek` usw. So gelten in Liste und Auswertung dieselben Wochengrenzen (Montag als Wochenanfang je nach Region).
- **Leere Balken zählen mit**: `RideAnalysis.buckets` legt jeden Tag/jede Woche im Zeitraum an, auch ohne Fahrt. Sonst rücken die Balken zusammen und Lücken wären unsichtbar.
- **Gleitendes Mittel nachlaufend** (nur Fahrten bis einschließlich der aktuellen): So verändert eine neue Fahrt nie rückwirkend ältere Punkte. Am Anfang mittelt es über weniger als 5 Fahrten.
- **Farbe nie allein** (NFR-16): Veränderungen haben Pfeil und Vorzeichen („▲ +12 %“), Blau ist nur Zusatz. Rückgänge sind grau statt rot, weil weniger km nicht automatisch „schlecht“ ist.

## Swift-Konzepte
- **Wertetypen (`struct`) für Berechnungen**: `RideAggregate`, `RideBucket`, `TrendPoint` sind `Sendable` und `Equatable`. Das macht Tests mit `#expect(a == b)` einfach.
- **Closures als Parameter**: `weightedAverage(rides) { $0.averagePower.map(Double.init) }` – die Funktion weiß nicht, welcher Wert gemittelt wird; das sagt die Closure.
- **`Calendar.dateInterval(of:for:)`** liefert für ein Datum die umgebende Woche/den Monat. Damit stimmen Zeitumstellung und Monatslängen automatisch.
- **Swift Charts**: `BarMark(x: .value(…, datum, unit: .month))` zeichnet Balken über die ganze Monatsbreite; `.chartXSelection(value:)` liefert das Datum unter der Maus. Für Trends liegen `PointMark` und `LineMark` im selben `Chart`.
- **Auswahl in Listen**: `List(selection:)` mit `Set<UUID>` statt `UUID?` erlaubt Mehrfachauswahl, ohne sonst etwas zu ändern.
- **Initialisierer-Falle**: In einem `init` darf eine Closure `self` erst nutzen, wenn alle Eigenschaften gesetzt sind. Deshalb rechnet `AnalysisModel.init` erst mit lokalen Konstanten und weist am Ende zu.
- **Plural im String-Katalog**: „1 Fahrt · Vergleich mit 2025“ / „5 Fahrten · …“ über Plural-Varianten; Platzhalter mit Position (`%1$lld`, `%2$@`), damit die Reihenfolge im Deutschen frei bleibt.

## Zum Ausprobieren
- Mehrere Fahrten importieren, dann Auswertung → „Monat“ → mit ‹ zurückblättern.
- Im Balkendiagramm „Woche“ wählen und über die Balken fahren: Die Zeile darüber zeigt Wert und Veränderung.
- In „Fahrten“ drei Fahrten mit ⌘-Klick wählen → „Ausgewählte Fahrten auswerten“.
