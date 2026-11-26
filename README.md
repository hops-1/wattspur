# Wattspur

Auswerte-App für Fahrten mit dem eBike, Rad, Auto und Motorrad, für Mac, iPhone und iPad: Fahrten aus der Bosch eBike Flow App (FIT-Export), GPX-Dateien von anderen Bikes, Apps und Radcomputern und eigene Aufnahmen mit dem iPhone. Alles bleibt auf deinen Geräten und, wenn du den Sync einschaltest, in deinem eigenen iCloud-Konto; ohne Konto bei Wattspur und ohne Telemetrie. Gebaut mit SwiftUI.

## Was Wattspur kann
- **Import** per Drag & Drop, Dialog oder überwachtem Ordner: Bosch-FIT mit allen Werten der Flow App, GPX 1.0/1.1 (komoot, Strava, Radcomputer) mit geschätzten Summen. Dieselbe Fahrt als FIT und GPX wird erkannt und zusammengeführt.
- **Fahrten:** Detail mit Karte und verknüpften Diagrammen (Höhe, Geschwindigkeit, Leistung, Trittfrequenz), Fahrten zusammenfügen, Tourenvergleich, PDF- und GPX-Export.
- **Auswertung** nach Zeitraum oder Auswahl, **Highlights** mit Jahresrückblick, Rekorden und Zielen, **Karte aller Fahrten** mit Heatmap und neuen Wegen.
- **Profil und mehrere Geräte:** jede Fahrt gehört zu einem Gerät (Bikes, E-Scooter, Autos, Motorräder), jede Ansicht lässt sich nach Gerät und Quelle filtern. Fahrzeuge stehen in einer eigenen Rubrik und nicht in den Rad-Summen.
- **iPhone und iPad:** Aufnahme mit Karte, Live-Aktivität und Siri, Auto-Start im Auto über eine Kurzbefehl-Automation, Übersicht mit Highlights, Karte aller Fahrten; am iPad dazu Analyse, Highlights und Vergleich wie am Mac. Sync mit dem Mac über das eigene iCloud-Konto.

## Download
**iPhone und iPad:** ab iOS 26, über TestFlight; Version 1.5 ist die Version für den App Store. Neue Versionen kommen zuerst in TestFlight.

**Mac:** die neueste Version als DMG unter [Releases](https://github.com/hops-1/wattspur/releases/latest), für macOS 26 oder neuer. Ab v1.8.3 ist die App mit Developer ID signiert und von Apple notarisiert und öffnet ohne Rückfrage. Bei Versionen bis v1.8.2 (nicht notarisiert) meldet macOS beim ersten Öffnen, dass die App nicht überprüft werden konnte. Dann unter Systemeinstellungen › Datenschutz & Sicherheit „Dennoch öffnen“ wählen, das ist nur einmal nötig. Schritt für Schritt steht es in „Read Me First.txt“ in der DMG und im [Handbuch](docs/user-guide/README.md).

## Dokumentation
- [Benutzerhandbuch](docs/user-guide/README.md) (Englisch und Deutsch): Installation, erster Start, Import, Ansichten, Kennzahlen, FAQ
- [Requirements](docs/REQUIREMENTS.md): Ziele, Datengrundlage, funktionale und nicht-funktionale Anforderungen
- [Backlog](docs/BACKLOG.md): Stories je Version, Ideen und offene Punkte
- [Changelog](CHANGELOG.md): Änderungen je Version (Englisch)
- [Namens-Brainstorming](docs/NAMEN.md)

## Referenzmaterial (nur lokal, nicht im Repo)
- `docs/reference/bosch-flow-screenshots/`: UI-Vorlage aus der Flow-App
- `docs/reference/sample-data/`: Beispielfahrt „Reinheim Rundfahrt“ (FIT + GPX), zugleich Referenztest für die Berechnungen

## Entwicklung
Voraussetzungen: Xcode 27 (macOS 26+), [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate          # erzeugt Wattspur.xcodeproj aus project.yml
open Wattspur.xcodeproj
```

Kern-Tests (Parser, Berechnungen) ohne Xcode-Projekt:

```bash
cd Packages/WattspurKit && swift test
```

DMG für Tester (ad-hoc signiert, Anleitung zum ersten Öffnen liegt bei):

```bash
scripts/build-dmg.sh       # → dist/Wattspur-<Version>-<Build>.dmg (ad hoc oder Developer ID, siehe docs/RELEASE.md)
```

Lokale CI: dieselben Schritte wie der Workflow plus Release-Build, das Ergebnis erscheint als Check „local-ci“ im Pull Request. Der Commit muss gepusht sein.

```bash
scripts/ci-local.sh
```

Falls `xcode-select` noch auf die Command Line Tools zeigt: Befehlen `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` voranstellen.

## Status
**Mac: v1.10.5** (24.11.2026): robuster, ohne sichtbare Änderung: ein Lesefehler der Bibliothek legt keine Fahrt doppelt an und steht im Diagnosebericht. Davor: v1.10.4 (dieselben Texte wie das iPad), v1.10.3 (Funde aus dem Review zu Architektur und Sicherheit, [Bericht](docs/REVIEW-1.6.2.md)), v1.10.2 (dieselbe Logik wie das iPad, E-Scooter), v1.10 (Umschalter Rad · Fahrzeuge in der Seitenleiste), v1.9 (Sportarten: Autos und Motorräder als Geräte, Querbeschleunigung), v1.8.x (Kartenstile, Sync mit dem iPhone über iCloud, erste notarisierte Version, Sichern und Teilen), v1.0 bis v1.7 (Import, Auswertung, Highlights, Karte aller Fahrten, ähnliche Strecken).

**iPhone und iPad: 1.5** (Highlights am iPhone, Trennen, PDF, Herkunftsfilter) ist die Version für den App Store; in TestFlight ist **1.6.10**: CarPlay mit Start, Pause, Ende und Live-Werten (1.6.4), Auto-Start über CarPlay oder Bluetooth (1.6), Aufnahme ohne Überlastung (1.6.5), dazu robuster: Teilen großer GPX-Dateien (1.6.6), kein Abbruch mehr beim Fotografieren während der Aufnahme (1.6.7), weniger Speicher und kein Warten auf die Bibliothek (1.6.8), die Aufnahme läuft nach einem Abbruch durch iOS von selbst weiter (1.6.9), die Kachel in CarPlay zeigt Zeit, Strecke und Tempo (1.6.10).

**Als Nächstes:** geplante Touren und Navigation (B-372 ff.). Details im [Changelog](CHANGELOG.md) und im [Backlog](docs/BACKLOG.md), Lern-Notizen in [docs/learning](docs/learning/README.md).

## Unterstützen
Wattspur ist kostenlos, ohne Werbung und ohne Konto. Die Entwicklung kostet trotzdem Geld, zum Beispiel für den Apple Developer Account und Lizenzen. Wer diese Kosten mittragen möchte, kann das über [GitHub Sponsors](https://github.com/sponsors/hops-1) oder [Buy me a coffee](https://buymeacoffee.com/hops1). Danke!

## Lizenz
Code: [MIT](LICENSE) · Dokumentation: [CC BY 4.0](docs/LICENSE.md) · © 2026 Nils Wiese

Wattspur ist kein Produkt der Robert Bosch GmbH und steht in keiner Verbindung zu ihr. Bosch und eBike Flow sind Marken ihrer jeweiligen Inhaber.
