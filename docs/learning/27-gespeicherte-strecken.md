# 27 – Gespeicherte Strecken, Backup der Mediathek und Hilfe-Menü

Stories: B-121, P-22 (IDEA-22), B-084 (Plan: REQUIREMENTS.md 10.19, Plan 1.7.1)

## Was gebaut wurde
- **`RouteGrouping`** (Core, `Ride/RouteGrouping.swift`): rechnet zwei Dinge auf dem `RouteIndex` aus 1.7.0. *Mitgliedschaft:* welche Fahrt zu welcher gespeicherten Strecke gehört (bei mehreren die bestpassende). *Vorschläge:* Fahrten ohne Strecke, gleiche Richtung, ab drei Fahrten; die „mittlere“ Fahrt (höchste mittlere Ähnlichkeit zu den anderen) wird die Bezugsfahrt.
- **`RouteGroup`** (Kit, `@Model`) und **`RouteGroupService`**: Name, Schwelle, Gegenrichtung und eine **Kopie der Bezugsroute**. Anlegen, Umbenennen, Schwelle ändern und Auflösen laufen über die Bibliothek und lassen sich mit ⌘Z zurücknehmen. Das war die **Migration 2**: nur eine neue Tabelle.
- **Oberfläche (App):** Hinweis über der Liste („Wohl dieselbe Strecke“), Fenster „Strecke speichern“, die Strecke als Filter mit demselben Chip wie „Ähnlich wie“ (Regler und Richtung speichern in die Strecke), Menü ⋯, Abschnitt „Gespeicherte Strecken“ im Filter-Menü, Zeile „Strecke“ im Tour-Detail, Trefferzahl am Knopf, Hinweis nach dem Import.
- **`LibraryBackup`** (Kit): sichert die Mediathek als Ordner (SQLite-Datei, Anhänge-Ordner, `manifest.json`) und stellt sie wieder her; die App zeigt es im Fenster „Mediathek-Backup“.
- **Hilfe-Menü:** Handbuch, Import-Anleitung, FAQ und Versionshinweise, je nach Sprache der App.
- **Tests:** Vorschläge an synthetischen Straßen (Minimum, zwei Strecken, hin und zurück, Umweg, mittlere Fahrt, Reihenfolge, Last mit 1 000 Fahrten), Dienst mit ⌘Z, Migration (eine Datei im Stand von 1.7.0 öffnet mit dem neuen Schema), Backup auf echten Dateien (Sicherung, beschädigte Datei, neueres Format, Austausch beim Start).

## Warum so
- **Mitgliedschaft berechnen statt speichern:** Wer zu einer Strecke gehört, folgt aus den Routen. Speichert man es je Fahrt, kann es veralten (neue Fahrt, geänderte Schwelle, gelöschte Fahrt) und braucht Pflege. So gibt es nichts zu pflegen, und eine neue Fahrt gehört von selbst dazu.
- **Die Bezugsroute kopieren:** Die Strecke soll bleiben, auch wenn die Fahrt, aus der sie entstand, gelöscht wird.
- **Hin und zurück getrennt:** Ein Pendelweg hat zwei Richtungen mit gleicher Form. Der Schalter „Beide Richtungen“ holt die zweite dazu.
- **Eine Anfrage je Gruppe statt je Fahrt:** Die Vorschläge fragen den Index nur für den Anfang einer Gruppe und für ihre Bezugsfahrt. 1 000 Fahrten in 40 Strecken brauchen so wenige Sekunden im Debug-Build.
- **Ein Index für alles:** Suche und Vorschläge teilen sich einen Task, der den Index einmal baut. Ein zweiter Index hätte den Speicher verdoppelt.
- **Regler speichern beim Loslassen:** Während des Ziehens ändert sich nur die Ansicht; erst beim Loslassen wird die Strecke geschrieben. Sonst entstünde bei jedem Schritt ein Rückgängig-Schritt.
- **Backup mit SQLites eigener Funktion:** Die Datenbank läuft, während die App offen ist. Eine Datei zu kopieren wäre mitten in einer Änderung falsch; SQLites Backup liefert einen stimmigen Stand.
- **Wiederherstellen beim nächsten Start:** Eine offene Datenbank lässt sich nicht austauschen. Die App legt die Sicherung bereit und tauscht sie ein, bevor der Container öffnet. Die alte Mediathek bleibt in einem Ordner daneben, damit nichts verloren geht.
- **Hinweise sind Zustand, nicht Ereignis:** Der Hinweis „neue Fahrt auf deiner Strecke“ vergleicht die Mitgliedschaft vor und nach der Berechnung und meldet nur Fahrten, die seit dem Start der App importiert wurden und auf einer schon bekannten Strecke liegen.

## Swift-Konzepte
- `Task.detached` und `async let`-freie Zusammenarbeit: Ein `Task` baut den Index, mehrere Aufrufer warten mit `await task.value` auf dasselbe Ergebnis.
- Rückgängig mit `UndoManager`: Jede Änderung registriert ihren Gegenschritt (`registerUndo`); beim Rückgängigmachen registriert dieser wieder den Weg zurück (Wiederholen).
- SwiftData-Migration: Ein neues `@Model` mit Standardwerten ist eine **leichte Migration**; bestehende Tabellen bleiben unverändert. Ein Test öffnet eine Datei mit den alten Modellen und dann mit den neuen.
- **Zeitüberlauf beim Typprüfen:** Eine sehr lange Kette von View-Modifiern (`.onChange`, `.sheet`, `.alert` …) kann den Compiler auf einem langsameren Rechner über die Zeitgrenze bringen. Abhilfe: die Kette in mehrere Teilansichten (`private var …: some View`) zerlegen.
- `NSAlert` und `NSOpenPanel` aus SwiftUI: AppKit-Dialoge, wenn SwiftUI keinen passenden Dialog bietet.

**Begriffe, die oft vorkommen**
- **Leichte Migration:** SwiftData ergänzt Tabellen und Spalten selbst, wenn sie neu sind und Standardwerte haben. Das Umbenennen oder Löschen von Feldern braucht dagegen eine Anleitung.
- **Externer Speicher:** Große Werte (`@Attribute(.externalStorage)`) liegen nicht in der Datenbankdatei, sondern als Dateien in einem Ordner daneben. Ein Backup muss beides mitnehmen.
