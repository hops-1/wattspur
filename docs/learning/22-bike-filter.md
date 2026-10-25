# 22 – Der Bike-Filter je Bereich

Stories: B-137 (übernimmt B-110), Mockup B-133, Modell Notiz 18

## Was gebaut wurde
- **`BikeFilter` im Kit** (`Store/BikeFilter.swift`): „alle Bikes“ oder ein Bike. Er ist `RawRepresentable` mit einem Text (leer = alle, sonst die Bike-Id), damit `@AppStorage` ihn je Bereich merken kann: `bikeFilter.rides`, `.analysis`, `.map`, `.highlights`. `resolved(knownBikeIDs:)` macht daraus „alle“, wenn es weniger als zwei Bikes gibt oder das Bike nicht mehr existiert.
- **Fahrten:** Im Menü „Sortieren und Filtern“ der Liste steht der Eintrag „Bike“. Die Kopfzeile zeigt dann „12 von 114 Fahrten“, die Filter-Marke nennt den Bike-Namen, „Zurücksetzen“ setzt auch ihn zurück. Die Listen neben der Karte und der Auswertung zeigen ohnehin nur deren Fahrten.
- **Auswertung, Karte, Highlights:** Ein Knopf „Bike: Alle Bikes ▾“ in der Kopfzeile neben dem Zeitraum (`BikeFilterMenu`). Karte: `MapFilter.bike` im Kit (übernimmt B-110). Highlights: Jahr und Rekorde folgen dem Filter; im Reiter „Ziele“ steht statt des Knopfs „Ziele zählen alle Bikes“, und die Ziele rechnen mit den Fahrten aller Bikes.
- **Archivierte Bikes** stehen im Filter unter „Archiviert“.
- **Tests** (`BikeFilterTests.swift`, 7): Speichern und Lesen, Zulassen, `resolved`, `MapFilter` mit Bike, echte Fahrten auf zwei Bikes für Liste und Karte.

## Warum so
- **Eine Wahl je Bereich:** Auswertung nach Gravel, Karte aller Fahrten: das sind zwei verschiedene Fragen. Deshalb teilen die Bereiche den Filter nicht.
- **Handverlesene Fahrten ignorieren den Filter:** Wer in der Liste Fahrten markiert und „Auswerten“ oder „Auf der Karte zeigen“ wählt, will genau diese sehen, auch wenn sie auf verschiedenen Bikes liegen.
- **Ziele zählen alle Bikes:** Ein Jahresziel von 12 000 Höhenmetern gilt für den Fahrer, nicht für ein Rad.
- **Unsichtbarer Filter darf nicht wirken:** Wer ein Bike archiviert und nur noch eines übrig hat, sieht den Knopf nicht mehr. Ein früher gewählter Filter dürfte dann nicht still Fahrten ausblenden; `resolved` erledigt das an einer Stelle.
- **Zwischenspeicher der Karte:** `MapCache` rechnet die Karte nur neu, wenn sich etwas Wichtiges geändert hat. Filter und Bike jeder Fahrt gehören in den Schlüssel, sonst bliebe die Karte nach „Bike zuweisen“ alt.

## Swift-Konzepte
- `enum` mit Rohwert-Protokoll, aber ohne `case`-Rohwerte: `RawRepresentable` von Hand.
- `@AppStorage` mit eigenem Typ; `Picker` mit `Section` im Menü.
- Ein Filter an einer Stelle (`isOnBike`), in vier Bereichen benutzt.
