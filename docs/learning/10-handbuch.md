# 10 – Benutzerhandbuch und Demo-Modus für Screenshots

Story: B-080 (DOC-01, DOC-02, DOC-03, DOC-05, NFR-12)

## Was gebaut wurde
- **Handbuch** unter `docs/user-guide/`: je sechs Seiten auf Englisch (`en/`) und Deutsch (`de/`), dazu eine Einstiegsseite mit beiden Sprachen.
  - Installation mit Gatekeeper, erster Start und Beispielfahrt, Import (Export aus der Flow-App, überwachter Ordner, Protokoll), Ansichten mit Tastaturkürzeln.
  - Kennzahlen: welcher Wert von Bosch kommt und welcher berechnet wird, mit Formel.
  - FAQ.
  - GitHub zeigt die Markdown-Dateien direkt an. Die Links zwischen den Seiten sind relativ, so funktionieren sie auch später mit GitHub Pages (DOC-07).
- **Screenshots** (`docs/user-guide/images/en|de/`): Hauptfenster, Assistent, Import-Fenster und Einstellungen, jeweils in beiden Sprachen. Sie zeigen ausschließlich die anonymisierte Beispielfahrt.
- **Demo-Modus** (`App/DemoMode.swift`, nur Debug-Builds): Mit `-WattspurDemo YES` öffnet Wattspur eine leere Bibliothek im Arbeitsspeicher und lädt nur die Beispielfahrt.
  - `-WattspurDemoWindow settings|importLog|profile` öffnet zusätzlich ein Fenster, `-WattspurDemoSection analysis` die Auswertung.

## Warum so
- **Keine Bosch-Screenshots** (NFR-12): Die Bildschirme der Flow-App sind fremdes Urheberrecht. Die Export-Schritte stehen deshalb als nummerierter Text mit den genauen Menünamen im Handbuch, und ein Hinweis erklärt, warum es keine Bilder gibt.
- **Demo-Modus statt echter Bibliothek**: Screenshots aus der echten Bibliothek würden echte Routen zeigen, also Wohnort und Wege. Im Demo-Modus gibt es nur die anonymisierte Beispielfahrt. Weil die Bibliothek nur im Arbeitsspeicher liegt, bleibt die echte Datenbank unberührt.
- **Startargumente überdecken Einstellungen**: `-setupCompleted YES -watchFolderEnabled NO -watchFolderBookmark ""` setzen die gespeicherten Werte nur für diesen Start außer Kraft. So erscheint weder der Assistent noch der echte Ordnerpfad, und nichts wird überschrieben.
- **`#if DEBUG`**: Der Demo-Modus ist im Release-Build und damit im DMG gar nicht enthalten.

## Konzepte
- **Argument-Domäne von `UserDefaults`**: Ein Startargument der Form `-schlüssel wert` hat Vorrang vor allem, was gespeichert ist. Gelesen wird er wie jede Einstellung (`UserDefaults.standard.bool(forKey:)`, auch über `@AppStorage`), geschrieben wird dabei nichts.
- **`ModelConfiguration(isStoredInMemoryOnly: true)`**: ein SwiftData-Speicher nur im Arbeitsspeicher, genau wie in den Tests.
- **`openSettings` / `openWindow`** aus der Umgebung öffnen das Einstellungsfenster und benannte Fenster aus dem Code.
- **Fenster-Screenshot ohne Bedienung**:
  - Ein kleines Swift-Skript holt mit `CGWindowListCopyWindowInfo` die Fenster-ID, danach nimmt `screencapture -l <ID> -o` genau dieses Fenster auf, ohne Schatten.
  - MapKit zeichnet nur in sichtbaren Fenstern. Deshalb startet das Skript die App mit `open -a`, und sie holt sich im Demo-Modus selbst nach vorn.
  - Weil die App dabei den Fokus bekommt, solange niemand tippen.

## Screenshots neu machen
```bash
xcodegen generate && xcodebuild -scheme Wattspur -configuration Debug -derivedDataPath .build/xcode build
open -n -a .build/xcode/Build/Products/Debug/Wattspur.app --args \
  -WattspurDemo YES -setupCompleted YES -watchFolderEnabled NO -watchFolderBookmark "" \
  -AppleLanguages "(de)" -AppleLocale de_DE
```
Für den Assistenten `-setupCompleted NO`, für ein anderes Fenster `-WattspurDemoWindow settings`. Danach das Fenster mit `screencapture -l <ID> -o bild.png` aufnehmen und auf höchstens 1600 px Breite verkleinern (`sips -Z 1600`).
