# 21 – Das Bike anzeigen: Liste, Vergleich, PDF, GPX

Stories: B-136 (Mockup B-133, Modell Notiz 18, Zuordnen Notiz 20, PROF-03)

## Was gebaut wurde
- **Listenzeile:** Am Ende der zweiten Zeile steht das runde Symbol des Bikes in seiner Farbe, ab zwei Bikes (`RideRow.showsBike`). In der markierten Zeile ist es hell auf dem Akzentgrund: `RideRowBike` liest dafür `backgroundProminence`. Ein Tooltip nennt den Namen; VoiceOver liest „Bike: Gravel“ als Teil der Zeile.
- **Vergleich:** Unter den Spaltenköpfen steht eine Zeile „Bike“ mit Symbol und Name je Fahrt (`ComparisonTable.showsBike`), auch im PDF des Vergleichs.
- **PDF der Fahrt:** Unter dem Datum steht „Bike: Mein eBike · Bosch Performance Line CX“ mit dem Symbol.
- **GPX:** Der Name steht als `<desc>` im `<metadata>` und im Track (`GPXWriter.document(…, description:)` im Kit). Die Reihenfolge der Elemente folgt GPX 1.1 (Name, Beschreibung, Zeit bzw. Typ); der Text wird maskiert, ohne Beschreibung bleibt die Datei wie zuvor.
- **Tests:** `GPXDescriptionTests` (4) prüfen die Reihenfolge, das Maskieren, den Wegfall und dass die Datei ohne Beschreibung unverändert ist.

## Warum so
- **Symbole erst ab zwei Bikes:** Wer nur ein Bike hat, sieht in jeder Zeile dasselbe Zeichen; das wäre nur Rauschen. PDF und GPX nennen das Bike dagegen immer, weil sie weitergegeben werden und der Empfänger nicht weiß, ob es noch weitere Bikes gibt.
- **Chip am Zeilenende statt am Anfang:** Vorn steht schon die Routen-Vorschau; ein zweites Zeichen daneben würde die Zeile unruhig machen.
- **Farbe plus Symbol plus Name:** Die Farbe allein genügt nicht (Farbfehlsicht, VoiceOver). Die Art steckt im Symbol, der Name im Tooltip und im VoiceOver-Label.
- **Beschreibung doppelt im GPX:** Manche Programme lesen `<metadata><desc>`, andere die Beschreibung des Tracks. Beides kostet ein paar Byte.

## Swift-Konzepte
- `@Environment(\.backgroundProminence)`: ob eine Zeile auf dem Auswahl-Hintergrund steht.
- Default-Parameter (`description: String? = nil`), damit alte Aufrufer unverändert bleiben.
- `accessibilityElement(children: .ignore)` plus `accessibilityLabel` für ein Symbol, das allein stehen muss.
