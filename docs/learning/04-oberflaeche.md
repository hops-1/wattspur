# 04 – Fensteraufbau, Seitenleiste, Liste, Lokalisierung

## Fensteraufbau: warum keine NavigationSplitView mehr
Apples `NavigationSplitView` liefert Seitenleiste, Liste und Detail fertig. Zwei Wünsche aus deinem Review waren damit aber nicht machbar:
1. **Symbolmodus**: Die System-Seitenleiste hat eine Mindestbreite und kann sich nur ganz ausblenden.
2. **Spaltenbreiten**: macOS merkt sich alte Breiten und ignorierte unsere Mindestbreiten, die Liste wurde zu schmal.

Deshalb gibt es jetzt ein eigenes Layout (`ContentView`): `HStack { SidebarRail | Liste | Detail }` mit eigenen Trennern (`ColumnResizeHandle`, ein `DragGesture`). Die Seitenleiste rastet beim Zusammenschieben unter 130 pt in den Symbolmodus ein. Breiten und Modus liegen in `@AppStorage`.

**Lehre**: Fertige Komponenten bringen viel geschenkt mit, passen aber nicht zu jedem Wunsch. Erst ausprobieren, dann gezielt ersetzen.

## Fenster-Knöpfe (Ampel)
Ohne Symbolleiste setzt macOS die drei Knöpfe ganz an den oberen Rand. Ein unsichtbares Symbolleisten-Element hält die normale Höhe, dann stehen sie mit Abstand im Panel. Die kompakte Leiste ist mit 84 pt genau so breit, dass links und rechts gleich viel Luft bleibt.

## Liste: Suche, Sortierung, Zeitraum (B-022)
- Logik im Kit (`Ride/RideQuery.swift`): `RidePeriod` (diese Woche, dieser Monat …) und `RideSortOrder`, mit Tests. Die Auswertung in v0.2 nutzt dieselben Zeiträume.
- Nach Datum sortiert gruppiert die Liste nach Monaten, sonst zeigt sie eine flache Liste.
- `@AppStorage` funktioniert direkt mit `enum`s, die `String` als `RawValue` haben.

## Duplikat-Nachfrage (B-011)
`importFiles` merkt sich zu jeder Datei ihre URL. Gibt es Duplikate, erscheint ein `confirmationDialog` mit den Namen. „Aktualisieren“ ruft `RideLibrary.update(_:withFileAt:)` auf. Weil die Datei aus dem Dateidialog kommt, muss der Zugriff erneut freigeschaltet werden (`startAccessingSecurityScopedResource`, Sandbox).

## Zeitzone (B-006)
Bosch schreibt die „lokale“ Zeit fälschlich in UTC. `TimeZoneResolver` fragt einmalig per `MKReverseGeocodingRequest` die Zeitzone des Startpunkts ab und speichert sie (`Ride.timeZoneIdentifier`). Angezeigt wird dann mit `Date.FormatStyle(…, timeZone:)`. Ohne Internet bleibt die Zeitzone des Macs, beim nächsten Start versucht es die App erneut.

## Lokalisierung (B-008)
- Alle Texte stehen in `App/Localizable.xcstrings` (String-Katalog), Englisch als Ausgangssprache, Deutsch als Übersetzung.
- `Text("Rides")` ist automatisch übersetzbar, weil das Literal als `LocalizedStringKey` gilt. **Falle:** `Text(isLoop ? "Start & finish" : "Start")` ist ein normaler `String` und wird *nicht* übersetzt. Deshalb steht dort `if isLoop { Text("…") } else { Text("…") }`.
- Mehrzahl über Plural-Varianten im Katalog: „1 Fahrt insgesamt“ / „5 Fahrten insgesamt“.
- Prüfung: Der Build legt alle gefundenen Texte in `.stringsdata`-Dateien ab. Ein Abgleich mit dem Katalog zeigt fehlende und überflüssige Einträge.
