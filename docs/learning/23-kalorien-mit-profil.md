# 23 – Kalorien: wie Flow und „mit Profil“

Stories: B-067 (Abgleich mit V-01 erledigt am 25.10.2026), SET-06, PROF-01, REQUIREMENTS.md 3.4 und 10.16

## Was gebaut wurde
- **`CalorieModel` im Kit** (`Ride/CalorieModel.swift`): Modus (`CalorieMode`: „aus Arbeit“ ist der Standard, „mit Profil“), Faktor für „mit Profil“ (kcal je kJ Arbeit, 0,956 = 25 % Wirkungsgrad) und die Körperdaten (`BodyProfile`).
  - „Aus Arbeit“ bildet die Flow-App nach: Arbeit × 0,97 **plus** 64 kcal je Stunde Fahrzeit, ohne Körperdaten (`flowFactor`, `flowKilocaloriesPerHour`).
  - „Mit Profil“: Arbeit × 0,956 **plus** Grundumsatz × Fahrzeit. Der Grundumsatz nach Mifflin-St Jeor ist 10 × kg + 6,25 × cm − 5 × Alter + 5 (männlich) bzw. − 161 (weiblich); bei „keine Angabe“ der Mittelwert, − 78. Das Alter ist das Fahrtjahr minus das Geburtsjahr, nie unter 0.
  - Fehlt Gewicht, Größe oder Geburtsjahr, gilt „aus Arbeit“; `fallbackFields` nennt, was fehlt.
- **Überall dasselbe Modell:** `RideAggregate`, `RideComparison` und die Kennzahlen der Fahrt bekommen es statt eines bloßen Faktors (`calories:`); ohne Angabe bleibt alles wie vorher. `ComparisonFigures` kennt dafür das Startdatum.
- **Einstellungen › Berechnung:** Auswahl „Aus deiner Tretleistung (Standard)“ oder „Mit Profil“; bei fehlenden Angaben ein Hinweis mit „Profil bearbeiten …“.
- **Anzeige:** Das Info-Zeichen neben Kalorien in Auswertung, Tour-Detail (auch PDF) und Vergleich sagt, woraus die Zahl besteht, auch wenn „mit Profil“ mangels Daten zurückfällt.
- **Tests** (`CalorieModelTests.swift`, 13): Grundumsatz für alle drei Geschlechter, Alter je Fahrt, Grenzfälle, Rückfall, Summen und Vergleich.

## Abgleich mit Flow (V-01)
Die FIT-Dateien enthalten keinen Kalorienwert; Referenz waren sechs Flow-Screenshots (7 Minuten bis 4:50 Stunden, 32 bis 1 312 kJ). Der Faktor kcal ÷ kJ ist nicht konstant (1,126 bis 1,207), er steigt bei geringer Durchschnittsleistung. Eine Anpassung kcal = 0,97 × kJ + 64 kcal/h × Fahrzeit trifft alle sechs auf ≤ 3 kcal (Flow rundet auf ganze kcal); mit der Gesamtzeit statt der Fahrzeit passt es nicht. Die Flow-App hat keine Körperdaten im Profil, der Zeitanteil ist also ein fester Wert und kein Grundumsatz des Fahrers. Deshalb bildet „aus Arbeit“ das nach, und „mit Profil“ ist eine eigene Schätzung mit 25 % Wirkungsgrad (Faktor 1,125 würde den Grundumsatz doppelt zählen). Der Test `flowValues` hält die sechs Werte fest. Offen: Ob der Zeitanteil an der Zeit oder an der Strecke hängt, ist mit sechs Fahrten ähnlicher Geschwindigkeit nicht endgültig getrennt; zwei langsame Fahrten mit Flow-Wert würden das klären.

## In 1.5.0 nicht freigeschaltet
Nils hat entschieden, dass „mit Profil“ erst nach dem Abgleich erscheint. `CalorieMode.withProfileAvailable` (in `App/CalorieSettings.swift`) steht deshalb auf `false`: Die Einstellung zeigt wieder den Platzhalter „Kommt in einer späteren Version“, und `CalorieModel(mode:rider:)` rechnet immer „aus Arbeit“, auch wenn in den Einstellungen etwas anderes gespeichert wäre. Der Kit-Code und seine Tests bleiben. Die Körperdaten im Profil sind weiter da, werden aber nur gespeichert; die Texte sagen das.

## Warum so
- **Ein Modell statt eines Faktors:** Die Kalorien einer Fahrt hängen jetzt von Datum, Dauer und Körperdaten ab. Ein einzelner Faktor reicht dafür nicht mehr; ein Wert `CalorieModel` wandert durch alle Berechnungen und hält Formel und Rückfall an einer Stelle.
- **Rückfall statt Fehler:** Ein Nutzer, der „mit Profil“ wählt, aber noch kein Gewicht eingetragen hat, bekommt trotzdem eine Zahl und einen klaren Hinweis, was fehlt.
- **Alter aus dem Geburtsjahr:** Nur das Jahr ist bekannt; ein Jahr Unterschied ändert den Grundumsatz um 5 kcal pro Tag, also bei einer Stunde Fahrt um gut 0,2 kcal. Genauer wäre vorgetäuscht.
