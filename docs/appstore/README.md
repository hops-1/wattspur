# Texte für die Produktseite im App Store

Hier stehen die Texte für App Store Connect, eine Datei pro Feld, auf Deutsch (`de-DE`) und Englisch (`en-US`). Nils kopiert sie beim Ausfüllen der Produktseite (siehe `docs/APPSTORE.md`). Der Aufbau ist derselbe wie bei `fastlane deliver`, falls das Hochladen später automatisch gehen soll.

| Datei | Feld in App Store Connect | Grenze |
|---|---|---|
| `name.txt` | Name | 30 Zeichen |
| `subtitle.txt` | Untertitel | 30 Zeichen |
| `promotional_text.txt` | Werbetext (änderbar ohne neue Version) | 170 Zeichen |
| `description.txt` | Beschreibung | 4000 Zeichen |
| `keywords.txt` | Schlüsselwörter, mit Komma, ohne Leerzeichen | 100 Zeichen |
| `support_url.txt` | Support-URL | |
| `marketing_url.txt` | Marketing-URL (freiwillig). **Leer heißt: Feld leer lassen** (Entscheidung Nils 22.11.2026, siehe unten) | |
| `privacy_url.txt` | URL der Datenschutzrichtlinie (unter *App-Datenschutz*) | |
| `review_information/notes.txt` | Hinweise für die App-Prüfung (Englisch) | 4000 Bytes |

„Neuigkeiten“ gibt es bei der ersten Version im Store nicht, auch nicht bei 1.6.4, weil 1.0 nie veröffentlicht wurde; ab der zweiten kommt der Text aus dem Abschnitt der Version in den Neuigkeiten der App.

Prüfen nach jeder Änderung:

```bash
scripts/check-appstore-texts.sh
```

Das Skript prüft die Längen, Leerzeichen bei den Schlüsselwörtern und Namen anderer Marken darin (Richtlinie 2.3.7: Bosch, Strava, komoot und so weiter gehören nicht in die Schlüsselwörter).

Regeln für die Texte:
- Nur nennen, was der Build wirklich kann. Kein „bald“, keine Preise, keine anderen Plattformen außer dem eigenen Mac.
- Keine Links auf Seiten mit Spendenlinks (Richtlinie 3.1.1): Die Beschreibung nennt `docs/SUPPORT.md`, nicht die Startseite auf GitHub, und `docs/SUPPORT.md` bleibt ohne Spendenlinks.
- Entfernungen nicht in Meilen versprechen: Die App zeigt immer km.
- Die OSM-Kartenstile nicht nennen, solange V-19 (Karten im Store) nicht entschieden ist.
- Wörter aus Name und Untertitel nicht in den Schlüsselwörtern wiederholen; Apple findet sie ohnehin.

## Video für die App-Prüfung

Die Quelle des Drehbuchs ist `REVIEW-VIDEO.html`. Word und PDF kommen nach `dist/` (nicht im Repository):

```bash
scripts/review-video-docs.py
```

Das Skript braucht nur Python 3 und Google Chrome. `textutil` taugt dafür nicht: Es verliert in Word alle Tabellen.

## Screenshots

```bash
scripts/appstore-screenshots.sh            # de-DE und en-US
scripts/appstore-screenshots.sh de-DE      # eine Sprache
```

Ergebnis in `dist/appstore-screenshots/<Sprache>/` (nicht im Repository), als JPEG, weil Apple keinen Alphakanal annimmt, 1320 × 2868 Pixel, das ist die Größe 6,9 Zoll, die App Store Connect verlangt; kleinere iPhones nimmt Apple daraus. Mit `--ipad` kommen die Bilder für das iPad 13 Zoll (2064 × 2752, Pflicht, weil die App auf dem iPad läuft) nach `dist/appstore-screenshots-ipad/`. Nur Demo-Daten aus der anonymisierten Beispielfahrt, keine echten Fahrten (NFR-12). In App Store Connect in dieser Reihenfolge hochladen: iPhone 01 bis 05, iPad 01 bis 03. Für CarPlay gibt es dort keine eigenen Bilder.
