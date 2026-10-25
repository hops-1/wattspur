# 20 – Fahrten einem Bike zuordnen

Stories: B-135 (Mockup B-133, Datenmodell Notiz 18, Profil Notiz 19, PROF-03)

## Was gebaut wurde
- **Im Kit** (`RideLibrary+Bikes.swift`): `assign(_:to:)` hängt Fahrten in einem Schritt an ein Bike und meldet, wie viele sich geändert haben. Ein ⌘Z stellt jede Fahrt auf ihr voriges Bike zurück, ⇧⌘Z wiederholt. Eine zusammengefügte Fahrt nimmt ihre Teile mit, damit das Bike nach dem Trennen dasselbe bleibt.
- **Menü „Import für ● Bike ▾“** (`ImportBikeMenu` in `BikeMenus.swift`) über der Fahrtenliste, ab zwei Bikes. Es setzt das aktive Bike des Profils, damit Stern und Menü immer dasselbe zeigen. Es gilt für den manuellen Import (Knopf „+“, Drag & Drop) und für den überwachten iCloud-Ordner, denn beide gehen über `importFile`, das an das aktive Bike hängt.
- **„Bike zuweisen ▸“** im Kontextmenü der Liste (eine oder mehrere Fahrten) und als Knopf in der Ansicht der Mehrfachauswahl; **Bike-Menü im Kopf des Tour-Details** (`RideBikeMenu`).
- **Hinweiszeile** unten im Fenster: „2 Fahrten wurden „Gravel“ zugewiesen.“ mit „Rückgängig ⌘Z“; sie verschwindet nach 10 Sekunden und wird VoiceOver angesagt.
- **Zusammenfügen:** Eine zusammengefügte Fahrt gehört zum Bike ihres ersten Teils (`merge` tat das schon, jetzt mit Test).

## Warum so
- **Aktives Bike und „Import für“ sind dasselbe:** Ein zweiter Wert „Bike für den Import“ neben dem Stern im Profil hätte sich widersprechen können. Eine Quelle der Wahrheit, zwei Stellen zum Ändern.
- **Menü erst ab zwei Bikes:** Wer nur ein Bike hat, sieht nichts Neues.
- **Rückgängig mit demselben Muster wie Umbenennen und Papierkorb:** `setBikes` merkt sich die früheren Bikes und registriert als Gegenschritt wieder sich selbst; so ergibt sich Wiederholen von allein.
- **Menü-Symbole als Bild:** Ein Eintrag in einem `Menu` nimmt nur ein Bild, keine eigene View. `ImageRenderer` macht aus dem runden Bike-Symbol ein `NSImage` (`isTemplate = false`, sonst färbt macOS es einfarbig).

## Swift-Konzepte
- `ImageRenderer`, `Picker` mit `.inline` im `Menu` (Häkchen am gewählten Eintrag).
- `@Observable` für die Hinweiszeile, per `.environment` an das Fenster gereicht.
- Generische View mit `@ViewBuilder`-Label (`BikeAssignMenu`).
- `UndoManager`: `registerUndo` braucht bei `groupsByEvent = false` eine offene Gruppe; im Test deshalb `begin`/`endUndoGrouping`.
