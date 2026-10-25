# 12 – Teaser in der Seitenleiste

Story: B-111 (Kap. 6 der Requirements)

## Was gebaut wurde
- Zwei neue Einträge in der Seitenleiste: **Highlights** (Pokal, ⌘4) und **Karte** (⌘5), jeweils mit einem kleinen Hinweis „bald“.
- Ein Klick öffnet `ComingSoonView`: Symbol, Titel, „Kommt in Version 1.3“ bzw. „1.4“, ein Satz zur Idee, drei Punkte, was kommt, und ein Knopf dorthin, wo man bis dahin nachsehen kann (Auswertung bzw. Fahrten).
- Der Papierkorb behält ⌘3, damit sich bekannte Kürzel nicht ändern.

## Warum so
- **Keine Fake-Daten:** Eine Vorschau mit erfundenen Zahlen sähe aus wie die echte Funktion und würde Fragen auslösen („Warum stimmt mein Rekord nicht?“). Die Platzhalter-Ansicht beschreibt nur.
- **Volle Breite wie die Auswertung:** Highlights und Karte sind eigene Bereiche, keine Detailansicht einer Fahrt. Deshalb ersetzt die Ansicht Liste und Detail.
- **Barrierefreiheit:** VoiceOver liest „Highlights, Kommt bald“; der Hinweis „bald“ ist Text, keine Farbe. Das große Symbol ist ausgeblendet (`accessibilityHidden`), weil der Titel dasselbe sagt.

## Swift-Konzepte
- **`enum` mit zugehörigen Texten:** `ComingSoonView.Feature` hat zwei Fälle; berechnete Eigenschaften mit `switch` liefern Symbol, Titel und Texte. Ein neuer Fall zwingt den Compiler, an jeder Stelle einen Text zu verlangen.
- **`LocalizedStringKey`:** Die Texte stehen auf Englisch im Code und werden über den String-Katalog übersetzt. Weil sie als `LocalizedStringKey` (nicht `String`) übergeben werden, findet Xcode sie beim Build und trägt sie in den Katalog ein.
- **Standardwerte für Parameter:** Die Hilfsfunktion `row(…)` der Seitenleiste bekam `comingSoon: Bool = false`; bestehende Aufrufe bleiben unverändert.
