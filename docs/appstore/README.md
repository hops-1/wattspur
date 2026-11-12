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
| `marketing_url.txt` | Marketing-URL (freiwillig) | |
| `privacy_url.txt` | URL der Datenschutzrichtlinie (unter *App-Datenschutz*) | |
| `review_information/notes.txt` | Hinweise für die App-Prüfung (Englisch) | 4000 Zeichen |

„Neuigkeiten“ gibt es bei der ersten Version im Store nicht; ab der zweiten kommt der Text aus dem Abschnitt der Version in den Neuigkeiten der App.

Prüfen nach jeder Änderung:

```bash
scripts/check-appstore-texts.sh
```

Das Skript prüft die Längen, Leerzeichen bei den Schlüsselwörtern und Namen anderer Marken darin (Richtlinie 2.3.7: Bosch, Strava, komoot und so weiter gehören nicht in die Schlüsselwörter).

Regeln für die Texte:
- Nur nennen, was der Build wirklich kann. Kein „bald“, keine Preise, keine anderen Plattformen außer dem eigenen Mac.
- Die OSM-Kartenstile nicht nennen, solange V-18 (Karten im Store) nicht entschieden ist.
- Wörter aus Name und Untertitel nicht in den Schlüsselwörtern wiederholen; Apple findet sie ohnehin.
