# Wattspur

Lokale Auswerte-App für eBike-Fahrten aus der Bosch eBike Flow App (FIT/GPX-Export). Zuerst für macOS, später für iOS. Gebaut mit SwiftUI.

## Dokumentation
- [Benutzerhandbuch](docs/user-guide/README.md) (Englisch und Deutsch): Installation, erster Start, Import, Ansichten, Kennzahlen, FAQ
- [Requirements](docs/REQUIREMENTS.md): Ziele, Datengrundlage, funktionale und nicht-funktionale Anforderungen
- [Backlog](docs/BACKLOG.md): Stories nach Meilensteinen M0–M5
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

Lokale CI, wenn GitHubs macOS-Runner nicht verfügbar sind (Freiminuten aufgebraucht): dieselben Schritte wie der Workflow plus Release-Build, das Ergebnis erscheint als Check „local-ci“ im Pull Request. Der Commit muss gepusht sein.

```bash
scripts/ci-local.sh
```

Falls `xcode-select` noch auf die Command Line Tools zeigt: Befehlen `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` voranstellen.

## Status
v1.4 fertig: v1.0 (Freunde-Version mit Icon, DMG, Beispielfahrt, Barrierefreiheit, [Handbuch](docs/user-guide/README.md)), v1.1 (Fahrten zusammenfügen, Widerrufen), v1.2 (Tourenvergleich, PDF-Export), v1.3 (Highlights, GPX-Export) und jetzt die Karte aller Fahrten (Linien-Heatmap und Wärmekarte, Fahrten an einer Stelle, Summen des Ausschnitts, neue Wege, Routen-Vorschau in der Liste). Details im [Changelog](CHANGELOG.md), Lern-Notizen in [docs/learning](docs/learning/README.md). Nächstes Thema: v1.5 ähnliche Strecken und ein Bereich „Fahrten“ mit Karte.

## Lizenz
Code: [MIT](LICENSE) · Dokumentation: [CC BY 4.0](docs/LICENSE.md) · © 2026 Nils Wiese

Wattspur ist kein Produkt der Robert Bosch GmbH und steht in keiner Verbindung zu ihr. Bosch und eBike Flow sind Marken ihrer jeweiligen Inhaber.
