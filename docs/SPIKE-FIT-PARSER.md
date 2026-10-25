# Spike B-002: FIT-Parser – Garmin FIT SDK oder eigener Decoder?

Stand: 19.10.2026 · Entscheidungsgrundlage für NFR-19

## Ergebnis in einem Satz
**Empfehlung: eigener Decoder** in `WattspurKit`. Er ist schon umgesetzt, besteht den Referenztest und hat keine Lizenzrisiken. Das Garmin-SDK bleibt eine Option für später, falls wir sehr viele FIT-Varianten (z. B. Garmin-Geräte, PROF-04) unterstützen wollen.

## Kandidat 1: Eigener Decoder (umgesetzt)
- Dateien: `Packages/WattspurKit/Sources/WattspurKit/FIT/` (ca. 350 Zeilen)
- Unterstützt: Datei-Header (12/14 Byte), Definitions- und Datennachrichten, Little/Big Endian, alle 17 Basistypen inkl. Ungültig-Markern, Arrays, Compressed-Timestamp-Header, Developer-Felder (werden übersprungen), CRC-Prüfung
- Tests (Swift Testing, 14 Tests, alle grün):
  - Beispielfahrt: alle 5 805 Nachrichten, Summen **exakt** wie in der Flow-App (B-005)
  - Robustheit: falsche Prüfsumme, abgeschnittene Dateien, Datenmüll, beschädigte Bytes → saubere Fehler statt Absturz (NFR-11)
  - CRC gegen Referenzwert
- Was er nicht kann: Feldnamen und Skalierungen aus dem vollständigen FIT-Profil, also nur die Felder, die Wattspur braucht (`FITProfile.swift`). Neue Felder müssen von Hand ergänzt werden.

## Kandidat 2: Garmin FIT Swift SDK
- Repo: `github.com/garmin/fit-swift-sdk`, offiziell, gepflegt (letzte Änderung 06.10.2026), Swift Package, macOS 12+/iOS 14+, Abhängigkeit `swift-collections`
- Vorteil: vollständiges Profil (alle Nachrichten und Felder, Skalierung, Komponenten), künftige Profilversionen kostenlos
- **Lizenz: proprietäre „FIT Protocol License Agreement“**, keine Open-Source-Lizenz. Auszüge (sinngemäß):
  - Nutzung nur für eigene Zwecke, nicht übertragbar und nicht unterlizenzierbar
  - Weitergabe bzw. Veröffentlichung der „Licensed Technology“ an Dritte untersagt, außer wie im Vertrag erlaubt
  - Verbot, das SDK oder Ableitungen unter einer Lizenz zu verbreiten, die Offenlegung des Quellcodes oder Änderungsrechte für andere verlangt
  - Das SDK gilt als vertrauliche Information von Garmin
- Folge: Für eine spätere Veröffentlichung von Wattspur auf GitHub (Open Source) und als DMG ist das ein Risiko bzw. bräuchte eine rechtliche Prüfung. Durch das Benutzen stimmt man der Lizenz zu.
- **Nicht ausprobiert:** Das SDK habe ich nicht heruntergeladen und nicht eingebunden, weil das bereits als Zustimmung zur Lizenz gilt. Das wäre deine Entscheidung.

## Vergleich

| Kriterium (NFR-19) | Eigener Decoder | Garmin SDK |
|---|---|---|
| Vollständigkeit | nur benötigte Felder | vollständiges Profil |
| Robustheit fremder Dateien | getestet (Fehler statt Absturz) | vermutlich gut, nicht getestet |
| Lizenz / GitHub-Veröffentlichung | frei (eigener Code) | proprietär, Risiko |
| Größe / Abhängigkeiten | klein, keine | größer, + swift-collections |
| Wartung | neue Felder selbst ergänzen | Updates von Garmin |
| Lerneffekt | hoch (Binärformat verstanden) | gering |

## Nachtrag 20.10.2026: Keine stabile Bike-Kennung in Bosch-Exporten
Geprüft an 23 Exporten desselben Bikes (Januar bis Oktober 2026):
- Jede Datei enthält nur `file_id` (type 4, manufacturer 137 = Bosch, product 0, time_created), `session`, `lap`, `record` und `activity`. Kein `device_info`, keine Firmware-Versionen, keine Developer-Felder.
- `file_id.serial_number` ist bei **jedem Export ein anderer Wert**, also keine Seriennummer des Bikes.
- Die GPX-Exporte enthalten nur den Tournamen.

Folge: Wattspur ordnet jede Fahrt dem einen Standard-Bike zu (Requirements Kap. 7). Die Seriennummer bleibt nur als Metadatum an der Fahrt (`Ride.deviceSerialNumber`). Überzählige Bikes aus früheren Versionen (eins je Fahrt) werden beim App-Start zusammengeführt. Mehrere Bikes werden später manuell zugeordnet (PROF-03, B-074).

## Entscheidung
Eigener Decoder, vorbehaltlich deiner Zustimmung. Neu bewerten, wenn generische FIT-Dateien anderer Geräte importiert werden sollen (B-076).
