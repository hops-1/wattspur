# 19 – Bereich „Profil“ und Bike-Editor

Stories: B-134 (Mockup B-133, Datenmodell siehe Notiz 18, ACC-01, PROF-01, PROF-03)

## Was gebaut wurde
- **Abschnitt „Profil“ in der Seitenleiste** (⌘6, `AppSection.profile`): Der Eintrag unten zeigt Avatar und Name und öffnet den Bereich im Hauptfenster. Das alte kleine Profil-Fenster ist weg; „Profil bearbeiten …“ in den Einstellungen schickt eine Nachricht (`Notification.Name.showProfile`), und das Hauptfenster springt in den Bereich.
- **Kopf** (`ProfileView.swift`): Avatar mit Foto oder Anfangsbuchstabe, Name, Gewicht, Größe, Geburtsjahr, Geschlecht. Alles freiwillig; unplausible Zahlen (Gewicht 7 kg, Geburtsjahr 2040) speichert die App nicht (`ProfileInput` im Kit).
- **Bike-Kacheln** in einem anpassbaren Raster: Foto oder farbiges Symbol, Name, Stern für das aktive Bike, Art · Antrieb · Akku, Strecke (mit Startwert), Fahrten, letzte Fahrt, „Bearbeiten …“. Archivierte Bikes stehen in einem Aufklapper mit „Wiederherstellen“.
- **Bike-Editor** (`BikeEditorView.swift`) als Blatt: Foto, Name, Farbe, Art (Fahrrad, Mountainbike, Rennrad, Gravelbike), Schalter E-Bike, Hersteller, Modell, Antrieb, Akku, Gewicht, Kaufdatum, km-Startwert, „Als aktives Bike festlegen“ und Archivieren. Gearbeitet wird an einer Kopie (`BikeDraft`), erst „Sichern“ schreibt ins Bike.
- **Symbole** (`BikeAppearance.swift`): Die vier Arten und das E-Bike-Zeichen sind als SwiftUI-`Shape` gezeichnet, in der Farbe des Bikes; `BikeChip` ist der runde Grund dazu.
- **Fotos** (`PhotoScaler` im Kit): Ein gewähltes Foto wird vor dem Speichern auf 1 000 Pixel (Bike) bzw. 512 Pixel (Profil) an der langen Kante verkleinert und als JPEG abgelegt.
- **Demo-Modus:** `-WattspurDemoSection profile`, `-WattspurDemoBikes YES` und `-WattspurDemoEditor new|edit` für Screenshots.

## Warum so
- **Eigener Bereich statt Fenster:** Das Profil ist jetzt etwas, in das man oft schaut (Bikes, Kennzahlen). Ein Bereich in der Seitenleiste ist schneller zu erreichen und zeigt sich wie die anderen Bereiche.
- **Entwurf statt direktes Schreiben:** Beim Tippen im Namensfeld wäre jede Taste ein Speichern, und „Abbrechen“ ließe sich nicht umsetzen. Der Entwurf ist ein einfacher `struct`, den man vergleichen und verwerfen kann.
- **Ungültige Eingaben fallen weg:** Das Feld speichert `nil`, wenn der Wert nicht im Bereich liegt. Das ist ehrlicher als einen falschen Wert zu behalten, und die Kalorienrechnung (B-067) fällt bei fehlenden Werten ohnehin auf „aus Arbeit“ zurück.
- **Archivieren statt Löschen** im Editor: Ein gelöschtes Bike ließe seine Fahrten ohne Bike zurück. Das letzte offene Bike lässt sich nicht archivieren, weil neue Fahrten immer ein Ziel brauchen.
- **Symbole selbst gezeichnet:** SF Symbols hat kein Gravelbike und kein Mountainbike mit E-Bike-Zusatz. Eine `Shape` skaliert sauber, nimmt jede Farbe an und braucht keine Bilddateien.

## Swift-Konzepte
- `@Bindable` für Felder eines `@Model`; `Binding(get:set:)` als Filter vor dem Speichern.
- `TextField(value:format:)` mit optionalem Wert; `fileImporter` mit security-scoped URL.
- `Shape` mit eigenem `path(in:)`; adaptive Farbe über `NSColor(name:dynamicProvider:)`.
- `sheet(item:)` mit einem `Identifiable`-Enum (`BikeEditorTarget`).
