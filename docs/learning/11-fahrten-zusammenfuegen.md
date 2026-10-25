# 11 – Fahrten zusammenfügen und wieder trennen

Story: B-095 (LIST-09)

## Was gebaut wurde
- **Zusammenfügen:** Zwei oder mehr markierte Fahrten werden zu einer.
  - Aufruf über Rechtsklick › „… Fahrten zusammenfügen …“ oder den Knopf „Zusammenfügen …“ in der Mehrfachauswahl.
  - Ein Dialog zeigt die Teile auf einem Zeitstrahl, ein Namensfeld (vorbelegt mit der ersten Fahrt) und die Summen der neuen Fahrt.
- **Trennen:** Über den Details einer zusammengefügten Fahrt steht ein Hinweis mit dem Knopf „Trennen“; im Kontextmenü heißt es „In Originalfahrten trennen“.
- **Rechnen** (`RideMerge` in WattspurKit, ohne Datenbank, gut testbar):
  - Fahrzeit, Strecke, Anstieg, Abstieg und Arbeit werden addiert, Höchstwerte übernommen.
  - Ø-Geschwindigkeit = Gesamtstrecke / Fahrzeit.
  - Ø-Leistung und Ø-Trittfrequenz sind nach Fahrzeit gewichtet.
  - Lücke am selben Tag = Pause: Die Gesamtdauer reicht vom ersten Start bis zum letzten Ende, die Zeitreihe läuft in echter Uhrzeit weiter.
  - Über mehrere Tage zählen nur die eigenen Zeiten der Teile; die Zeitreihe geht direkt nach dem vorigen Teil weiter.
  - Fahrten, die sich überschneiden, werden abgelehnt, ebenso die Beispielfahrt.

## Warum so
- **Bosch bleibt Wahrheitsquelle:** Die Summen kommen aus den `session`-Werten der Teile, nicht aus der Zeitreihe. Bei Ø-Leistung und Ø-Trittfrequenz lässt Bosch Nullwerte weg; das gewichtete Mittel ist deshalb eine gute Näherung, aber nicht genau der Wert, den Bosch für eine lange Fahrt zeigen würde.
- **Die Originale leben weiter, als Teile:** Statt sie zu löschen oder in den Papierkorb zu legen, hängen sie an der neuen Fahrt (`mergedInto`) und behalten ihre FIT-Datei. Das löst drei Dinge auf einmal:
  - Nach einem Parser-Update (NFR-17) werden die Teile neu gelesen und die zusammengefügte Fahrt aus ihnen neu berechnet. Sie selbst hat keine eigene Datei.
  - Wird eine Originaldatei erneut importiert, erkennt die Duplikat-Prüfung den Teil. „Aktualisieren“ frischt den Teil auf und rechnet die zusammengefügte Fahrt neu.
  - Trennen ist einfach: Verbindung lösen, die zusammengefügte Fahrt löschen.
- **Zusammengefügtes erneut zusammenfügen** löst die alte Fahrt in ihre Teile auf. So gibt es nie Teile von Teilen.
- **Papierkorb:** Die zusammengefügte Fahrt wandert als Ganzes in den Papierkorb. Wird sie endgültig gelöscht, gehen die Teile samt Dateien mit (`deleteRule: .cascade`).
- **⌘Z mit eigenen Gegenschritten:** `RideLibrary` registriert zu jeder Aktion den Gegenschritt beim UndoManager des Fensters: Zusammenfügen ↔ Trennen, Papierkorb ↔ Wiederherstellen, Umbenennen ↔ alter Name.
  - Das eingebaute Undo von SwiftData (`modelContext.undoManager`) hat sich nicht bewährt. Eine Simulation im Test zeigte: Papierkorb und Wiederherstellen ließen sich nicht rückgängig machen, und nach dem Rückgängigmachen des Zusammenfügens zeigten die Teile noch auf die gelöschte Fahrt und blieben unsichtbar.
  - Vorher hing an der Datenbank ein eigener `UndoManager()`, den das Menü „Widerrufen“ nie erreicht hat. ⌘Z wirkt nur über den UndoManager des Fensters (`@Environment(\.undoManager)`).
  - Ein Sheet ist unter macOS ein eigenes Fenster; der Dialog bekommt deshalb den UndoManager des Hauptfensters übergeben.

## Konzepte
- **Selbstbeziehung in SwiftData:** `Ride.mergedInto: Ride?` und `Ride.parts: [Ride]?` zeigen auf denselben Typ. `@Relationship(deleteRule: .cascade, inverse: \Ride.mergedInto)` auf einer Seite genügt.
  - Beide Seiten sind optional, ohne `unique`: so bleibt das Modell CloudKit-fähig, und die bestehende Datenbank wird automatisch (leichtgewichtig) migriert.
- **Teile ausblenden per `#Predicate`:** Listen, Auswertung und Profil fragen `$0.mergedInto == nil` ab. Die Abfrage läuft in der Datenbank, nicht in Swift.
- **Typisierte Fehler** (`throws(RideMerge.MergeError)`): Der Aufrufer weiß genau, welche Fehler kommen können. Im Dialog wird daraus mit `Swift.Result { () throws(RideMerge.MergeError) in … }` ein Wert, aus dem die passende Meldung entsteht.
- **Reine Funktion + dünne Datenbankschicht:** `RideMerge.merge` rechnet nur mit Werten (`Part` → `Result`). `RideLibrary.merge` holt die Werte aus den Fahrten, schreibt das Ergebnis und kümmert sich um die Beziehungen. So lassen sich die Rechenregeln ohne Datenbank testen.
- **`registerUndo(withTarget:handler:)`:** Was der Handler beim Rückgängigmachen seinerseits registriert, landet automatisch als „Wiederholen“ (⇧⌘Z) auf dem Stapel. Deshalb genügt ein Gegenschritt pro Aktion.
- **Undo im Test:** Ohne Ereignisschleife landet alles in einer Gruppe. Mit `groupsByEvent = false` und `beginUndoGrouping()`/`endUndoGrouping()` pro Schritt verhält sich der Test wie die App, ein Klick pro Gruppe.
- **`.sheet(item:)`** mit einem kleinen `Identifiable`-Wert (`MergeCandidates`) öffnet denselben Dialog aus der Liste und aus der Mehrfachauswahl.

## Ausprobieren ohne echte Fahrten
`-WattspurDemoRides 2` lädt im Demo-Modus zwei Kopien der Beispielfahrt als normale Fahrten, je eine Woche auseinander:
```bash
open -n .build/xcode/Build/Products/Debug/Wattspur.app --args \
  -WattspurDemo YES -setupCompleted YES -watchFolderEnabled NO -watchFolderBookmark "" -WattspurDemoRides 2
```

## Bewusst (noch) nicht
- Die Diagramme laufen über die Strecke; eine Pause ist dort ein Punkt, kein grauer Bereich wie im Entwurf. Sichtbar wird sie erst mit der Zeit-Achse (B-065).
- Kein automatischer Vorschlag, welche Fahrten zusammengehören (B-096).
