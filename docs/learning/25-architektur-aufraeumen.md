# 25 – Architektur aufräumen (1.6.1)

Stories: B-162 … B-169 (Auslöser: der Sicherheitscheck von 1.6.0 und der Architekturbericht danach)

## Was gebaut wurde
- **Sicherheits-Fix:** Fünf Abstürze im FIT-Import (Überlauf beim Zeitstempel, negative Seriennummer, Summe der Leistung, Zeitachse, NaN in der Distanz) und ein sechster in den Diagrammen. Sechs Regressionstests mit handgebauten FIT-Dateien (`FITHostileInputTests`).
- **Eine geteilte `RideLibrary`** in der Environment statt 26 eigener Instanzen; das Rückgängig-Machen gehört zum Fenster (`using(_:)`).
- **Schreibzugriffe aus den Views:** Ziele und Speichern laufen über die Bibliothek.
- **Zwei Module:** `WattspurCore` (rein) und `WattspurKit` (Store). Der Compiler zeigt jetzt jede Rückwärts-Abhängigkeit.
- **Sechs Dienste** hinter der Bibliothek.
- **Große Views** in Ordnern, **Einstellungsschlüssel** an einem Ort, **Start** ohne Wartung vor dem ersten Fenster, **Ordner-Import** liest im Hintergrund.

## Warum so
- **Das Store-Modul behält den Namen `WattspurKit`.** SwiftData ordnet gespeicherte Daten den Klassen zu; ein anderes Modul für `Ride` & Co. wäre ein Risiko für bestehende Bibliotheken. Der Schnitt läuft deshalb andersherum: Das Neue (ohne SwiftData) bekommt den neuen Namen.
- **`@_exported import WattspurCore`** in einer Datei, damit die App nur `WattspurKit` importiert und keine 60 Dateien anfassen musste.
- **Brücken statt Rückimporte:** Core-Dateien hatten `extension Ride { … }`. Diese Brücken stehen jetzt gesammelt in `Store/RideBridges.swift`. Wer ein reines Ding aus einem `Ride` braucht, schreibt dort die Umrechnung; der reine Code bleibt unabhängig.
- **Dienste als Structs aus einer Umgebung:** Sie haben keinen eigenen Zustand. Beim Rückgängig-Machen werden sie neu gebaut, ohne dass ein Dienst auf die Fassade zeigt. Abhängigkeiten laufen nur in eine Richtung.
- **Fassade statt Umbau der 26 Aufrufstellen:** Verhalten und Aufrufe bleiben, die Verschiebung ist sicher; die Fassade kann später schrumpfen.
- **Wartung nach dem ersten Fenster, aber nicht „im Hintergrund“:** Der `ModelContext` ist nicht `Sendable`. Ehrlicher Gewinn: Das Fenster erscheint zuerst. Echtes Hintergrundlaufen bräuchte einen `ModelActor`.

## Swift-Konzepte
- Mehrere Targets in einem Paket, `@_exported import`, Zugriffsebenen (`public`, `package`, `internal`) über Modulgrenzen, `@testable import` pro Modul.
- Protokoll mit `init` und Erweiterung (`LibraryService`), Structs mit `@MainActor`, Rückgängig mit `registerUndo(withTarget:)`.
- Typisierte Schlüssel statt Zeichenketten (`SettingsKey`).
- `Task.detached` für das Lesen großer Dateien, `async` Tests.
- Sichere Arithmetik: `&+`, `UInt64(exactly:)`, `isFinite`-Prüfungen statt Abstürzen.
