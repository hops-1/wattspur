# 15 – Tipp zur Mehrfachauswahl

Story: B-113 (Tester-Feedback zum Tourenvergleich), Mockup „⌘-click hint“ auf dem Design-Canvas

## Was gebaut wurde
- Unter der Fahrtenliste steht ein dezenter Tipp: „⌘-Klick markiert mehrere Fahrten – zum Auswerten, Vergleichen oder Zusammenfügen.“ Mit ✕ lässt er sich ausblenden.
- In der leeren Detailansicht („Wähle eine Fahrt“) steht derselbe Hinweis als Beschreibung.
- Sobald einmal zwei oder mehr Fahrten markiert waren, verschwinden beide für immer.

## Warum so
- Ein Tester fand den Vergleich erst, als er zufällig ⌘-Klick ausprobierte. Mac-Nutzer kennen das aus dem Finder, erwarten es in einer App aber nicht unbedingt.
- **Einmal reicht:** Wer es einmal gemacht hat, braucht den Tipp nicht mehr. Ein dauerhafter Hinweis würde zum Rauschen.
- **Dezent:** graue Schrift, kleine Fläche unten, kein Fenster, das den Weg versperrt.

## Swift-Konzepte
- **`@AppStorage` an zwei Stellen mit demselben Schlüssel:** `ContentView` setzt den Wert, wenn die Auswahl zwei oder mehr Fahrten enthält; `RideListView` liest ihn. Beide Ansichten aktualisieren sich, weil `@AppStorage` die UserDefaults beobachtet. Der Schlüssel steht einmal als `MultiSelectTip.storageKey`, damit sich kein Tippfehler einschleicht.
- **`ContentUnavailableView` mit eigener Beschreibung:** Die Variante mit `label:` und `description:` erlaubt, den Text nur unter einer Bedingung zu zeigen.
