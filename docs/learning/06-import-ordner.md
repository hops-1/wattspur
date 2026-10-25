# 06 – Überwachter Ordner, Import-Protokoll, Einstellungen, Einrichtung

Stories: B-040, B-041, B-042, B-044, B-027, B-029, B-049 (IMP-05, IMP-06, SET-01, SET-02, SET-07, ONB-01, ONB-03, ACC-01)

## Was gebaut wurde
- **Überwachter Ordner** (`App/FolderWatcher.swift`, Kit: `Import/FolderImport.swift`): Wattspur schaut beim Start und bei jeder Änderung in den gewählten Ordner, standardmäßig `iCloud Drive › Wattspur Import`.
  - Neue FIT-Dateien werden importiert und wandern nach `Importiert/`.
  - Duplikate werden übersprungen und ebenfalls nach `Importiert/` verschoben.
  - Unlesbare Dateien wandern nach `Fehlerhaft/`.
  - GPX und andere Typen bleiben liegen und stehen einmal im Protokoll.
  - Noch nicht heruntergeladene iCloud-Dateien werden angefordert und beim nächsten Durchlauf importiert.
- **Import-Protokoll** (`App/ImportLogView.swift`, Kit: `Store/ImportRecord.swift`): ein eigenes Fenster (⌥⌘L, Knopf neben „+“ in der Liste), das auch nach einem Neustart erhalten bleibt.
  - Oben: Ablagefläche zum Hineinziehen und die Karte für den überwachten Ordner.
  - Darunter alle Einträge, Filter „Zu prüfen“ und „Im Finder zeigen“ für fehlerhafte Dateien.
  - Nicht unterstützte Dateien stehen in **einer** aufklappbaren Zeile, so wie beim Bugfix für die Import-Meldung.
  - Einträge älter als 90 Tage werden beim Start entfernt.
- **Einstellungen** (⌘,, `App/SettingsView.swift`): Reiter Allgemein (Sprache-Hinweis, Standard-Kartentyp, Profil, Einrichtungsassistent), Import (Ordner, Schalter, Status, Regeln) und Berechnung (Platzhalter für v1.x).
- **Einrichtungsassistent** (`App/SetupAssistantView.swift`): vier Schritte beim ersten Start – Name, Import-Ordner, Anleitung zum Export aus der Flow-App, Zusammenfassung. Er lässt sich in den Einstellungen wieder aufrufen.
- **Profil** (`App/ProfileView.swift`): Name, Bike-Name und ein paar Zahlen; erreichbar unten in der Seitenleiste.

## Warum so
- **Sandbox und Bookmarks** (NFR-05): Eine Sandbox-App darf nur Ordner lesen, die der Nutzer selbst ausgewählt hat. Damit diese Erlaubnis einen Neustart übersteht, speichert Wattspur ein *security-scoped bookmark*. Das ist eine Art Schlüssel zum Ordner, abgelegt in den `UserDefaults`. Beim Start wird er aufgelöst, und `startAccessingSecurityScopedResource()` öffnet die Tür.
- **iCloud-Ordner anlegen**: Den Ordner `Wattspur Import` darf die App nicht einfach selbst erzeugen. Deshalb öffnet der Assistent einen Auswahldialog direkt in iCloud Drive. Du bestätigst den Ort, und Wattspur legt darin den Unterordner an.
- **Eigenes Zuhause**: In der Sandbox zeigt `homeDirectoryForCurrentUser` in den App-Container. Den echten Benutzerordner liefert `getpwuid(getuid())`.
- **Ordner beobachten**: `DispatchSource.makeFileSystemObjectSource` meldet, wenn sich der Ordner ändert. Mehrere Meldungen kurz hintereinander werden zu einem Durchlauf zusammengefasst (1,5 s warten). Zusätzlich gibt es alle 5 Minuten eine Sicherheitsprüfung, weil iCloud fertige Downloads nicht immer meldet.
- **Logik im Kit, Fenster in der App**: `FolderImport` arbeitet mit einem normalen Ordner-URL und dem `FileManager`. Die Tests legen dafür einen Ordner im Temp-Verzeichnis an (`FolderImportTests`, 5 Tests).
- **Protokoll als SwiftData-Modell** (`ImportRecord`): Es ist CloudKit-fähig wie die anderen Modelle (Standardwerte, keine `unique`-Felder). Ergebnis und Quelle stehen als Text (`outcomeRaw`, `sourceRaw`) im Modell, weil SwiftData mit einfachen Typen am robustesten ist. Swift-`enum`s machen sie im Code bequem.
- **Unterordner-Namen** kommen aus dem String-Katalog (`folder.imported` → „Importiert“). Wechselst du die Sprache, entstehen neue Unterordner mit dem anderen Namen. Das ist harmlos, weil Unterordner nie importiert werden.

## Swift-Konzepte
- **`@Observable` + `@Environment`**: `FolderWatcher` gibt es einmal pro App. Es wird in `WattspurApp` angelegt und an alle Fenster weitergereicht. Ändert sich `lastChecked`, zeichnen sich nur die Ansichten neu, die den Wert lesen.
- **`@Bindable`**: Damit wird aus einem Objekt aus der Umgebung ein Binding für einen `Toggle` (`$watcher.isEnabled`).
- **`didSet`**: Beim Umschalten von `isEnabled` startet bzw. stoppt die Überwachung automatisch.
- **`Task` mit `sleep` und Abbruch**: Für das Zusammenfassen von Ereignissen wird die alte Aufgabe abgebrochen (`cancel()`) und eine neue gestartet.
- **Mehrere Szenen**: `Settings { … }` erzeugt das Standard-Einstellungsfenster mit ⌘,. `Window(…, id:)` öffnet Fenster über `openWindow(id:)`.
- **`@Query` mit Prädikat im `init`**: Der Status „heute N Fahrten importiert“ fragt nur die Einträge von heute ab.

## Zum Ausprobieren
1. App starten: Der Assistent erscheint. Namen eingeben, „iCloud Drive › Wattspur Import“ wählen und den Ort bestätigen.
2. Eine FIT-Datei und eine GPX-Datei in den Ordner legen (im Finder oder am iPhone über „In Dateien sichern“).
3. Kurz danach ist die Fahrt in der Liste. Die FIT-Datei liegt in `Importiert/`, die GPX-Datei bleibt liegen.
4. ⌥⌘L öffnet das Protokoll; dort stehen beide Dateien.
