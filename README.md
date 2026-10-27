# Wattspur

Lokale Auswerte-App für eBike-Fahrten auf dem Mac: Fahrten aus der Bosch eBike Flow App (FIT-Export) und GPX-Dateien von anderen Bikes, Apps und Radcomputern. Alles bleibt auf deinem Rechner, ohne Konto und ohne Telemetrie. Gebaut mit SwiftUI, zuerst für macOS, später für iOS.

## Was Wattspur kann
- **Import** per Drag & Drop, Dialog oder überwachtem Ordner: Bosch-FIT mit allen Werten der Flow App, GPX 1.0/1.1 (komoot, Strava, Radcomputer) mit geschätzten Summen. Dieselbe Fahrt als FIT und GPX wird erkannt und zusammengeführt.
- **Fahrten:** Detail mit Karte und verknüpften Diagrammen (Höhe, Geschwindigkeit, Leistung, Trittfrequenz), Fahrten zusammenfügen, Tourenvergleich, PDF- und GPX-Export.
- **Auswertung** nach Zeitraum oder Auswahl, **Highlights** mit Jahresrückblick, Rekorden und Zielen, **Karte aller Fahrten** mit Heatmap und neuen Wegen.
- **Profil und mehrere Bikes:** jede Fahrt gehört zu einem Bike, jede Ansicht lässt sich nach Bike und Quelle filtern.

## Download
Die neueste Version als DMG unter [Releases](https://github.com/hops-1/wattspur/releases/latest), für macOS 26 oder neuer. Wattspur ist ein Hobbyprojekt und nicht von Apple notarisiert: Beim ersten Öffnen meldet macOS, dass die App nicht überprüft werden konnte. Dann unter Systemeinstellungen › Datenschutz & Sicherheit „Dennoch öffnen“ wählen, das ist nur einmal nötig. Schritt für Schritt steht es in „Read Me First.txt“ in der DMG und im [Handbuch](docs/user-guide/README.md).

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
scripts/build-dmg.sh       # → dist/Wattspur-<Version>-<Build>.dmg
```

Lokale CI: dieselben Schritte wie der Workflow plus Release-Build, das Ergebnis erscheint als Check „local-ci“ im Pull Request. Der Commit muss gepusht sein.

```bash
scripts/ci-local.sh
```

Falls `xcode-select` noch auf die Command Line Tools zeigt: Befehlen `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` voranstellen.

## Status
**Aktuell: v1.7.1** (gespeicherte Strecken: wiederkehrende Strecken erkennen, benennen und als Filter nutzen; Mediathek-Backup; Hilfe-Menü). Davor: v1.7.0 (ähnliche Strecken: Fahrten auf derselben Strecke finden, filtern, vergleichen und im Verlauf ansehen, dazu vier weitere Rekorde), v1.6.2 (Update-Hinweis), v1.6.1 (Sicherheits-Fix für beschädigte FIT-Dateien und ein aufgeräumter Unterbau), v1.6 mit GPX-Import (Fahrten anderer Bikes, Apps und Radcomputer neben den Bosch-Fahrten), v1.0 (erste Version für Freunde mit DMG, Beispielfahrt, Barrierefreiheit und [Handbuch](docs/user-guide/README.md)), v1.1 (Fahrten zusammenfügen), v1.2 (Tourenvergleich, PDF-Export), v1.3 (Highlights, GPX-Export), v1.4 (Karte aller Fahrten), v1.5 (Profil und mehrere Bikes). Details im [Changelog](CHANGELOG.md), Lern-Notizen in [docs/learning](docs/learning/README.md).

Als Nächstes: v1.8 Kartenstile mit OpenStreetMap, CyclOSM und OpenTopoMap (mit Höhenlinien), v1.9 Daten direkt von Bosch (siehe [Backlog](docs/BACKLOG.md)).

## Lizenz
Code: [MIT](LICENSE) · Dokumentation: [CC BY 4.0](docs/LICENSE.md) · © 2026 Nils Wiese

Wattspur ist kein Produkt der Robert Bosch GmbH und steht in keiner Verbindung zu ihr. Bosch und eBike Flow sind Marken ihrer jeweiligen Inhaber.
