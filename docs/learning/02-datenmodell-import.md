# 02 – Datenmodell, Import, Duplikate, Papierkorb

## Was
- `Store/Models.swift`: die gespeicherten Typen `Ride`, `Rider`, `Bike`, `SourceFile`.
- `Store/RideLibrary.swift`: Importieren, Duplikate erkennen, Umbenennen, Papierkorb, Neu-Auswertung.

## SwiftData in drei Sätzen
- `@Model` vor einer Klasse macht sie speicherbar. SwiftData legt dafür eine SQLite-Datenbank im App-Container an.
- Ein `ModelContext` ist die „Arbeitsfläche“: einfügen (`insert`), ändern (einfach Eigenschaften setzen), löschen (`delete`), dann `save()`.
- In SwiftUI lädt `@Query` passende Objekte und aktualisiert die Ansicht automatisch, wenn sich die Daten ändern.

## Warum das Modell so aussieht
- **CloudKit-tauglich von Anfang an** (Req. Kap. 7): keine `@Attribute(.unique)`, alles optional oder mit Standardwert, Beziehungen optional. So kann ein späterer iCloud-Sync ohne Umbau kommen.
- **Große Daten extern** (`@Attribute(.externalStorage)`): Die Zeitreihe (~3000 Punkte) und die Original-FIT liegen als eigene Dateien neben der Datenbank, die Datenbank selbst bleibt schnell.
- **Originaldatei behalten**: Wird der Parser verbessert, liest `reparseOutdatedRides()` alle Fahrten mit älterer `parserVersion` neu ein. Dein Name „Test Fahrt“ bleibt dabei erhalten.
- **Fahrer und Bike** existieren schon, auch wenn es vorerst nur je eins gibt. Das Bike wird über die Seriennummer aus der FIT-Datei erkannt.

## Duplikate
1. Bosch hängt eine UUID an den Dateinamen (`…-5e1f0c2a-7b3d-….fit`). `parseFileName` trennt Titel und UUID, mit einem **Regex-Literal** (`/^(.*?)-([0-9a-fA-F]{8}-…)$/`).
2. Gibt es keine UUID, gilt: gleiche Startzeit (±1 s) und gleiche Strecke (±1 m).
3. Beim erneuten Import fragt die App: überspringen oder aktualisieren (B-011).

## Papierkorb
Löschen setzt nur `deletedAt`. Die Liste zeigt per `#Predicate { $0.deletedAt == nil }` nur aktive Fahrten. Nach 30 Tagen löscht `purgeTrash()` endgültig, die Originaldatei per `deleteRule: .cascade` gleich mit.

## Swift-Konzepte
- **`@MainActor`** an `RideLibrary`: alles läuft auf dem Haupt-Thread, wie es der `ModelContext` der Oberfläche verlangt.
- **`#Predicate`** ist ein Makro: Der Swift-Ausdruck wird zur Datenbank-Abfrage übersetzt.
- **Protokolle** (`RideImporter`, `CalorieEstimator`) beschreiben Fähigkeiten. Weitere Formate (GPX, Apple Health) kommen als neue Typen dazu, ohne den Rest zu ändern.
- **Tests mit In-Memory-Datenbank** (`ModelConfiguration(isStoredInMemoryOnly: true)`): echte SwiftData-Logik, aber nichts landet auf der Platte.

## Nachtrag: mehrere Fahrten löschen (Bugfix nach v1.0)
- **Fehler:** Bei mehreren markierten Fahrten landete nur eine im Papierkorb.
  - Das Kontextmenü hing an jeder einzelnen Zeile und kannte nur die angeklickte Fahrt.
  - Bei der Löschtaste las die Schleife bei jeder Fahrt die Auswahl neu, während sie Einträge aus genau dieser Auswahl entfernte.
- **Lösung:**
  - `.contextMenu(forSelectionType: UUID.self)` an der `List` gibt dem Menü die ganze Auswahl, wenn die angeklickte Zeile dazugehört, sonst nur diese Zeile.
  - Die Fahrten werden zuerst eingesammelt, danach wird die Auswahl geändert.
  - `RideLibrary.moveToTrash(_ rides: [Ride])` speichert einmal, also holt ein einziges ⌘Z alle zurück.
  - Ab zwei Fahrten fragt ein `confirmationDialog` nach. Bei einer Fahrt reicht ⌘Z.
