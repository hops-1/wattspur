# 30 – iOS-App 0.1: eigenes Target, Übersicht mit Kacheln, aufs iPhone

Stories: B-204, B-205, B-206, B-207 (iOS 0.1, Plan vom 2.11.2026, REQUIREMENTS 10.21)

## Was gebaut wurde
- **Target `Wattspur iOS`** in `project.yml`, neben der Mac-App im selben Projekt:
  - nur iPhone, ab iOS 26, Produktname „Wattspur“, Bundle-ID `io.github.hops-1.wattspur.ios`
  - eigene Versionsnummern: 0.1.0 (die Mac-App bleibt bei 1.x)
  - Quellen in `iOS/`, Texte in `iOS/Localizable.xcstrings` (EN/DE), eigenes Schema `Wattspur iOS`
  - aus `App/` nur Ressourcen: das Icon `Wattspur.icon` und die Beispielfahrt `SampleRide.fit`
- **Übersicht (Design C):** ein `TabView` mit dem Tab *Übersicht*.
  - Kacheln „Diese Woche“ (km) und „Dieser Monat“ (Fahrten)
  - Kachel „Letzte Fahrt“ mit Mini-Karte, Name, Datum, Strecke, Fahrzeit und Anstieg
  - Ein Tipp öffnet ein einfaches Detail mit größerer Karte und den Kennzahlen.
  - Unten stehen Version und Commit, wie im Mac-Fenster „Über“.
- **Im Paket neu:** `RidePeriodTotals` (Summen für Woche und Monat nach dem Kalender des Geräts) mit Tests. `AppInfo` (Version, Commit) ist aus der Mac-App nach `WattspurCore` umgezogen, damit beide Apps es nutzen.
- **Checks (B-206):**
  - `scripts/ci-local.sh` baut die iPhone-App zusätzlich für den Simulator, ohne Signierung.
  - `scripts/check-architecture.sh` prüft, dass `iOS/` kein `AppKit` importiert und das Target aus `App/` nur Ressourcen nimmt.
  - Die Kit-Tests liefen einmal im iOS-Simulator (Ergebnis unten).
- **Anleitung „Wattspur aufs iPhone“** (B-207): unten in dieser Notiz.

## Warum so
- **Ein Repository, zwei Targets, ein Paket.** Die Logik liegt schon in `WattspurCore` und `WattspurKit`, die beide iOS 26 nennen. Die iPhone-App bekommt nur eine eigene Oberfläche. Würde sie Dateien aus `App/` mitbenutzen, hinge sie an AppKit und an Mac-Fenstern. Deshalb gilt: Gemeinsames wandert ins Paket, nie per Kopie (ARCHITECTURE.md, Regel 6).
- **Die Beispielfahrt ohne Datenbank.** Für 0.1 reicht es, die FIT-Datei mit `FITRideImporter` zu lesen. Das zeigt, dass FIT-Leser und Auswertung auf iOS laufen, ohne schon eine SwiftData-Bibliothek fürs iPhone zu planen. Die Daten vom Mac kommen in 0.2 über den iCloud-Ordner (B-178, B-208, B-209).
- **Summen der Beispielfahrt.** Die Beispielfahrt ist Wochen alt. Mit dem heutigen Datum stünden in beiden Kacheln Nullen. In 0.1 zählen sie deshalb Woche und Monat der Beispielfahrt, mit dem Hinweis „Beispieldaten“ darunter. Mit echten Daten (B-214) gilt der heutige Tag.
- **Team-ID nicht im Repository.** Das Repo soll öffentlich bleiben können, und die Team-ID ist persönlich. Sie steht nur in `Config/Local.xcconfig`, die Git ignoriert. Ohne die Datei baut das Projekt trotzdem für den Simulator, also auch auf einem fremden Mac.
- **Kein iOS-Build auf GitHub.** Die kostenlosen macOS-Minuten reichen schon für die Mac-App knapp. Gebaut wird die iPhone-App mit `scripts/ci-local.sh` auf dem eigenen Mac.

## Swift-Konzepte
- **xcodegen mit zwei Plattformen:** Unter `targets` steht ein zweites `type: application` mit `platform: iOS`. `configFiles` hängt eine `.xcconfig` an das Target. Ein YAML-Anker (`&gitCommitScript`, `*gitCommitScript`) teilt das Pre-Build-Script zwischen beiden Apps.
- **`#include?` in xcconfig:** Das Fragezeichen bindet `Local.xcconfig` nur ein, wenn es die Datei gibt. Ohne Fragezeichen bricht der Build ab, wenn sie fehlt.
- **Bedingte Build-Einstellung:** `CODE_SIGN_IDENTITY[sdk=iphonesimulator*] = -` signiert für den Simulator nur „zum lokalen Starten“, dafür braucht es kein Team.
- **Liquid Glass:** `.glassEffect(.regular, in: .rect(cornerRadius: 24))` gibt einer Fläche das Glas von iOS 26. `.interactive()` lässt sie beim Tippen reagieren.
- **SwiftUI-Karte:** `Map(initialPosition:interactionModes:)` mit `MapPolyline`. Mit leeren `interactionModes` und `allowsHitTesting(false)` wird die Karte zum Bild, und der Tipp landet beim `NavigationLink` darum herum.
- **Dynamische Farbe:** `Color(UIColor { traits in … })` wählt das Magenta je nach hell oder dunkel (#C2187A, #FF4FAE).
- **Dynamic Type:** `@Environment(\.dynamicTypeSize)` und `isAccessibilitySize`. Bei sehr großer Schrift stellt `AnyLayout` die beiden Kacheln untereinander statt nebeneinander. `ViewThatFits` stapelt die drei Kennzahlen, wenn sie nicht in eine Zeile passen.
- **VoiceOver:** `.accessibilityElement(children: .combine)` liest eine Kachel als einen Satz. Die Mini-Karte ist ausgeblendet (`accessibilityHidden`), weil sie nichts sagt, was nicht schon als Text dasteht.
- **Kalender:** `Calendar.dateInterval(of: .weekOfYear, for:)` beachtet den Wochenbeginn (`firstWeekday`) und die Zeitzone: In Deutschland beginnt die Woche am Montag, in den USA am Sonntag. Die Tests prüfen beides.

## Kit-Tests im iOS-Simulator (B-206)
Einmal von Hand, nicht in `ci-local.sh` (dauert länger und braucht ein Simulator-Gerät):

```bash
cd Packages/WattspurKit
xcodebuild test -scheme WattspurKit-Package -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -parallel-testing-enabled NO
```

**Ergebnis am 2.11.2026** (Xcode 27.2, iPhone 18 Pro mit iOS 27.2): `TEST SUCCEEDED`. Beide Test-Targets laufen ohne Änderung durch, mit 231 und 257 Tests, auch die SwiftData-Tests mit In-Memory-Bibliothek. Eine Abweichung ohne Folgen: Der Test „Data that is no image gives nothing“ (`PhotoScaler`) schreibt unter iOS eine Fehlerzeile von `CGImageSourceCreateThumbnailAtIndex` ins Protokoll. Er erwartet genau dieses Scheitern (`nil`) und besteht. Sonst gab es keine Unterschiede zum Mac.

## Anleitung: Wattspur aufs iPhone (B-207)
Mit einer kostenlosen Apple-ID, ohne bezahlten Developer-Account. Einmal einrichten, danach reicht Schritt 5.

**1. Apple-ID in Xcode anmelden.**
- Xcode › Einstellungen › *Apple Accounts* › „+“ › Apple-ID, anmelden.
- Danach steht dort ein Team „Dein Name (Personal Team)“.

**2. Zertifikat anlegen und Team-ID herausfinden.**
- Die Team-ID steckt im Entwickler-Zertifikat. Das gibt es anfangs noch nicht, also zuerst anlegen, ohne etwas zu bauen:
  - Xcode › Einstellungen › *Apple Accounts* › die Apple-ID wählen › *Manage Certificates…*
  - Unten links „+“ › *Apple Development*, dann *Done*.
  - Im Schlüsselbund liegt jetzt ein Zertifikat „Apple Development: …“.
- Die Team-ID ist das Feld `OU` des Zertifikats, zehn Zeichen aus Großbuchstaben und Ziffern:
  ```bash
  security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
  ```
- Ein anderer Weg führt über das Projekt: In Xcode beim Target *Wattspur iOS* unter *Signing & Capabilities* das Personal Team wählen, dann steht die ID unter *Build Settings › Development Team*. `xcodegen generate` überschreibt diese Wahl aber wieder, deshalb gehört sie in die Datei aus Schritt 3.

**3. Team eintragen.**
```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```
- In `Config/Local.xcconfig` die Zeile `DEVELOPMENT_TEAM = …` mit der eigenen Team-ID füllen.
- Danach `xcodegen generate`.
- Die Datei gilt je Checkout: Ein neuer Git-Worktree braucht seine eigene Kopie.

**4. iPhone vorbereiten.**
- iPhone mit dem Kabel an den Mac anschließen, entsperren, „Diesem Computer vertrauen?“ bestätigen.
- **Entwicklermodus einschalten:** Einstellungen › Datenschutz & Sicherheit › *Entwicklermodus* einschalten. Der Schalter erscheint erst, wenn Xcode das iPhone einmal gesehen hat. Das iPhone startet neu und fragt danach noch einmal nach.

**5. Bauen und installieren.**
- In Xcode das Schema *Wattspur iOS* wählen, als Ziel das iPhone, dann ⌘R.
- Beim ersten Mal registriert Xcode die Bundle-ID für das Personal Team und legt ein Profil an.
- Nach dem ersten Mal geht es auch ohne Kabel: Xcode › Window › *Devices and Simulators*, beim iPhone *Connect via network*.

**6. Dem Entwickler vertrauen.**
- Beim ersten Start meldet das iPhone „Nicht vertrauenswürdiger Entwickler“.
- Einstellungen › Allgemein › *VPN & Geräteverwaltung* › unter „Entwickler-App“ die eigene Apple-ID › *Vertrauen*.
- Danach startet die App.

**Grenzen der kostenlosen Apple-ID**
- **7 Tage:** Das Profil läuft nach sieben Tagen ab. Dann startet die App nicht mehr, bis sie aus Xcode neu installiert ist (Schritt 5). Die Daten der App bleiben dabei erhalten, solange man sie nicht löscht.
- **3 Apps:** Auf einem Gerät können höchstens drei selbst signierte Apps gleichzeitig installiert sein. Für eine vierte muss eine andere weg.
- **Bundle-IDs:** Es gibt nur eine begrenzte Zahl neuer App-IDs je Woche. Für Wattspur reicht eine.
- **Keine iCloud-Dienste:** kein CloudKit und kein TestFlight. Darum geht der Austausch in 0.2 über den iCloud-Ordner (V-14 klärt, ob das ohne Berechtigung klappt).

**Wenn es hakt**
- *„Signing for "Wattspur iOS" requires a development team“:* `Config/Local.xcconfig` fehlt oder ist leer, oder `xcodegen generate` wurde danach nicht ausgeführt.
- *„Failed to register bundle identifier“:* Die Bundle-ID ist bei einem anderen Team schon vergeben. Dann in `project.yml` beim Target *Wattspur iOS* eine eigene setzen, z. B. `io.github.<name>.wattspur.ios`, und diese Änderung nicht committen. In `Local.xcconfig` wirkt sie nicht, weil die Einstellung im Target Vorrang vor der xcconfig hat.
- *Das iPhone erscheint nicht in Xcode:* entsperren, Kabel neu stecken, „Vertrauen“ bestätigen, Entwicklermodus prüfen.
