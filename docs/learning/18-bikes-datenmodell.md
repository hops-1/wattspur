# 18 – Mehrere Bikes: Datenmodell

Stories: B-074 (Plan in BACKLOG.md „v1.5“, Entscheidungen in REQUIREMENTS.md 10.16, PROF-01, PROF-03)

## Was gebaut wurde
- **`Bike` erweitert** (`Models.swift`): Art (`BikeKind`: Fahrrad, Mountainbike, Rennrad, Gravelbike), `isEbike`, Farbe (`BikeColor`), Foto, Hersteller, Modell, Antrieb, Akku in Wh, Gewicht, Kaufdatum, km-Startwert, `isArchived`, `sortOrder`, `createdAt` und die Beziehung zum `Rider`.
- **`Rider` erweitert:** Gewicht, Größe, Geburtsjahr, Geschlecht (`RiderSex`), Foto, die Liste der Bikes und `activeBikeID`.
- **Aktives Bike** (`RideLibrary+Bikes.swift`): `activeBike()` liefert das Bike, an das neue Fahrten gehen. `setActiveBike(_:)` legt es fest, `makeBike(…)`, `archive(_:)`, `unarchive(_:)` verwalten die Bikes. Der Import (`importFile`) hängt jede neue Fahrt an das aktive Bike.
- **Kennzahlen** (`BikeProfile.swift`): `BikeStatistics` zählt Fahrten, Strecke (mit Startwert) sowie erste und letzte Fahrt. Papierkorb, Beispielfahrt und Teile zusammengefügter Fahrten zählen nicht, wie in allen anderen Summen.
- **Umstieg:** `prepareBikes()` läuft bei jedem Start und ist ein Nullsummenspiel, wenn nichts zu tun ist. Eine Bibliothek aus 1.4 bekommt ein Bike „Mein eBike“ (lokalisiert über `defaultBikeName`), das dem Profil gehört und aktiv ist. Alle Fahrten bleiben darauf.
- **Felder für den GPX-Import** (Vorgabe von Nils vom 25.10.2026, nur Modell, kein Parser; B-141 in v1.6): `Ride.sourceFormat` hat festgelegte Werte `fit` und `gpx` (`RideSource`, `Ride.source`), dazu `summaryEstimatedFromGPS` (Standard `false`) und die optionale Zusatzquelle `attachedSourceName` / `attachedSourceFormat`. `RideSample` bekommt `heartRate` und `temperature`, beide optional.
- **Tests** (`BikeTests.swift`, 21; `SourceDataTests.swift`, 9): Standardwerte, Rohwert-Rückfall, alle Felder nach dem Speichern, Reihenfolge, aktives Bike beim Import, Archivieren (auch das aktive und das letzte Bike), Kennzahlen mit allen Ausnahmen, Umstieg aus einer alten Bibliothek, Namen und Reihenfolge, `mergeBikes` lässt Profil-Bikes in Ruhe.

## Warum so
- **Aktives Bike als Id statt Beziehung:** Zwei Beziehungen zwischen `Rider` und `Bike` (alle Bikes, aktives Bike) brauchen zwei eindeutige Gegenstücke, und CloudKit verlangt zu jeder Beziehung eines. Eine einfache `UUID` ist robust: Ist das Bike weg oder archiviert, nimmt `activeBike()` das nächste.
- **Enums als Text gespeichert:** Wie bei `Goal` steht der Rohwert (`kindRawValue`) im Modell, die Eigenschaft `kind` wandelt um und fällt bei einem unbekannten Wert auf den Standard zurück. So kann eine spätere Version eine Art ergänzen, ohne dass eine ältere App abstürzt.
- **Alle neuen Felder mit Standardwert oder optional:** SwiftData ergänzt sie beim Öffnen einer alten Bibliothek selbst (leichte Migration), und CloudKit erlaubt später keine Pflichtfelder. Das Foto liegt als `externalStorage`, damit große Bilder nicht in der Datenbankzeile stehen.
- **Start bei jedem Launch statt einmalig:** `prepareBikes()` merkt sich nichts. Es prüft den Zustand und ändert nur, was fehlt. Das ist einfacher als ein Merker und heilt auch halbfertige Zustände, etwa nach einem Absturz.
- **`mergeBikes` nur für Altlasten:** Früher legte jeder Import ein Bike je Seriennummer an; `mergeBikes` fasste sie zusammen. Mit mehreren echten Bikes dürfte es nichts mehr zusammenfassen. Deshalb fasst es jetzt nur noch Bikes **mit** Seriennummer an; im Profil angelegte Bikes haben nie eine.
- **Position vor der Beziehung:** Setzt man `bike.rider`, trägt SwiftData das neue Bike sofort in den Kontext ein. Wer die nächste Position danach aus den vorhandenen Bikes berechnet, zählt sich selbst mit. Der Test „Positionen“ hat das gefunden.

- **Zeitreihe bleibt Byte für Byte gleich:** Die synthetisierte `Codable`-Umsetzung schreibt ein `nil` gar nicht und liest ein fehlendes Feld als `nil`. Gespeicherte Fahrten lassen sich also weiter lesen, und neue Fahrten ohne Puls und Temperatur sehen im Speicher aus wie vorher. Ein Test vergleicht die Schlüssel mit einer Kopie des alten Typs.

## Swift-Konzepte
- `@Model`, `@Relationship(inverse:)`, `@Attribute(.externalStorage)`.
- `enum` mit Rohwert und `CaseIterable`; Rückfall mit `?? .standard`.
- `extension RideLibrary` in eigener Datei; `throws(ArchiveError)` mit getipptem Fehler.
- `@discardableResult` für Funktionen, deren Ergebnis oft egal ist.
