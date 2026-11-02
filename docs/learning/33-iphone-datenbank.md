# 33 – Eigene Datenbank auf dem iPhone, hinter einem Schalter

Stories: B-216, B-217 (iOS 0.3, Plan vom 2.11.2026). Vorbereitet, solange der Developer-Account noch geprüft wird.

## Was gebaut wurde
- **`PhoneDatabase` im Kit:** dieselben SwiftData-Modelle wie am Mac, auf dem iPhone. Es liefert die Fahrten im Austauschformat (`RideExchange`), macht aus einer Aufnahme eine Fahrt und kennt den Papierkorb.
- **Ein Schalter beim Bauen:** `WATTSPUR_IOS_DATABASE` in `Config/iOS.xcconfig`. `folder` (Standard) verhält sich wie iOS 0.2. `local` nutzt die eigene Datenbank ohne iCloud, `icloud` mit Sync (erst mit Account). Der Wert steht als `WattspurDatabase` in der Info.plist, die App liest ihn beim Start.
- **Aufnahme wird Fahrt:** Nach *Sichern* geht die GPX, die das iPhone ohnehin schreibt, durch den Import aus dem Kit. Das Kit rechnet Strecke, Zeiten und Route auf dem iPhone, erkennt Doppel und übernimmt das Bike aus der Datei.
- **Löschen (B-217):** In *Fahrten* nach links wischen, im Tour-Detail der Papierkorb-Knopf mit Rückfrage. Unter *Mehr › Papierkorb* nach rechts wischen stellt eine Fahrt wieder her, nach links löscht sie endgültig, *Leeren* löscht alle. Nach 30 Tagen räumt der Start auf.

## Warum so
- **Hinter einem Schalter, nicht sofort für alle:** Ohne iCloud wäre die neue Datenbank leer. Die Fahrten vom Mac kommen erst mit dem Sync. Bis dahin bleibt Nils' iPhone bei 0.2, und der neue Weg lässt sich trotzdem schon im Simulator ausprobieren.
- **Der Schalter steckt im Build, nicht in den Einstellungen:** `icloud` geht nur mit dem passenden Entitlement. Eine Einstellung in der App könnte das nicht prüfen, ein Build schon.
- **Dasselbe Format für die Ansichten:** Übersicht, Liste und Tour-Detail zeigen schon `RideExchange`-Werte aus dem Stand vom Mac. `PhoneDatabase.snapshot` liefert genau diese Werte aus SwiftData. So mussten die Ansichten kaum geändert werden.
- **Die GPX als Zwischenschritt:** Der Import am Mac kann GPX vom iPhone schon (B-213). Aus der Aufnahme direkt eine `Ride` zu bauen wäre ein zweiter Weg mit eigenen Fehlern.

## Swift-Konzepte
- **Build-Einstellung in der Info.plist:** `$(WATTSPUR_IOS_DATABASE)` in `Config/iOS-Info.plist` wird beim Bauen ersetzt; `Bundle.main.object(forInfoDictionaryKey:)` liest es.
- **`ModelConfiguration(cloudKitDatabase:)`:** `.none` für lokal, `.private("iCloud.…")` für Sync, beides aus `LibrarySync`. Wichtig: Ohne Angabe gilt `.automatic`, und das würde mit Entitlement von selbst synchronisieren.
- **`swipeActions(edge:)`:** Knöpfe zum Wischen in einer `List`; ein ganzer Wisch löst den ersten Knopf aus.

## Ausprobieren im Simulator
1. In `Config/Local.xcconfig` die Zeile `WATTSPUR_IOS_DATABASE = local` eintragen.
2. `xcodegen generate`, dann das Schema *Wattspur iOS* auf einem Simulator starten.
3. Im Simulator unter *Features › Location* eine Strecke wählen (zum Beispiel „City Bicycle Ride“), *Fahrt starten*, nach einer Minute *Stopp* und *Sichern*.
4. Die Fahrt steht in *Übersicht* und *Fahrten*. Löschen, unter *Mehr › Papierkorb* wiederherstellen.

Die Zeile wieder entfernen, bevor du die App aufs eigene iPhone spielst: Dort zeigt `local` keine Fahrten vom Mac.
