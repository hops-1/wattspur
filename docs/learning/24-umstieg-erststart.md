# 24 – Umstieg auf 1.5 und Erststart mit dem ersten Bike

Stories: B-138 (Mockup B-133, Datenmodell Notiz 18, Profil Notiz 19)

## Was gebaut wurde
- **Hinweis nach dem Update** (`BikesHint.swift`): Wer Wattspur schon vor 1.5 benutzt hat, sieht einmal oben im Fenster „Neu in 1.5: Lege deine Bikes an“ mit „Zum Profil“ und „Später“. Er ist kein Dialog, damit er beim Import nicht stört. Er verschwindet für immer mit „Später“, mit „Zum Profil“ oder wenn man das Profil von selbst besucht (`@AppStorage("bikesHintDone")`).
- **Assistent, neuer Schritt 2 „Erstes Bike“:** Name und Farbe des ersten Bikes, darunter aufklappbar die Körperdaten (freiwillig, überspringbar). Aus 4 werden 5 Schritte. Beim Verlassen des Schritts gehen die Werte in die Bibliothek: `RideLibrary.configureActiveBike(name:color:)` und `setBodyData(…)` im Kit.
- **Erneut durchlaufen** (Einstellungen › Einrichtung wiederholen): Der Schritt zeigt, was gespeichert ist, statt leer zu starten.
- **Zusammenfassung:** „Bike“ steht jetzt neben Profil und Import-Ordner.
- **Farbwahl:** `BikeColorPicker` ist aus dem Bike-Editor herausgezogen, damit Editor und Assistent dasselbe zeigen.
- **Tests** (`FirstBikeTests`, 4): Name und Farbe, leerer Name, kein Bike vorhanden, Körperdaten speichern und unplausible Werte verwerfen.

## Warum so
- **Neue Nutzer bekommen den Hinweis nicht:** Wer die Einrichtung durchläuft, hat sein erstes Bike gerade benannt; `finish()` setzt deshalb `bikesHintDone`. Der Hinweis gilt nur für Bibliotheken aus der Zeit davor.
- **Banner statt Dialog:** Ein Dialog beim Start unterbricht, auch wenn man eigentlich eine Fahrt importieren will. Der Banner lässt sich ignorieren und bleibt trotzdem, bis man ihn wegschickt.
- **Nichts wird beim Update angelegt, was der Nutzer sehen müsste:** Das Bike „Mein eBike“ gibt es schon seit dem Umstieg (B-074); der Hinweis erklärt es nur.

## Swift-Konzepte
- `@AppStorage` als einmaliger Merker; `overlay(alignment: .top)` mit Übergang.
- Zustand aus gespeicherten Werten laden (`onAppear`) statt mit Standardwerten zu beginnen.
- `DisclosureGroup` mit eigener Beschriftung (`HStack` statt der veralteten Text-Addition).
