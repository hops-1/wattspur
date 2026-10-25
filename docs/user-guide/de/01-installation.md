# Wattspur installieren

Wattspur kommt als Disk-Image (`Wattspur-<Version>-<Build>.dmg`). Es ist ein kostenloses Hobbyprojekt und nicht von Apple notarisiert, deshalb fragt macOS vor dem ersten Start einmal nach.

## Installieren
1. Das DMG mit einem Doppelklick öffnen.
2. **Wattspur** im selben Fenster auf den Ordner **Programme** ziehen.
3. Das Disk-Image auswerfen (in der Finder-Seitenleiste oder in den Papierkorb ziehen).

## Das erste Öffnen
1. Wattspur aus dem Ordner „Programme“ öffnen.
   macOS meldet, dass „Wattspur“ nicht überprüft werden konnte. Auf **Fertig** klicken, nicht auf „In den Papierkorb legen“.
2. **Systemeinstellungen › Datenschutz & Sicherheit** öffnen und nach unten zu **Sicherheit** scrollen.
3. Neben „Wattspur wurde blockiert, um deinen Mac zu schützen“ auf **Dennoch öffnen** klicken.
4. Mit Passwort oder Touch ID bestätigen und noch einmal **Dennoch öffnen** wählen.

Das ist nur einmal nötig. Danach startet Wattspur wie jede andere App.

> Seit macOS 15 überspringt Rechtsklick › Öffnen diese Prüfung nicht mehr. Der Weg über die Systemeinstellungen ist der einzige.

## Aktualisieren
Das neue DMG laden und Wattspur wieder auf den Ordner „Programme“ ziehen. **Ersetzen** wählen. Fahrten und Einstellungen bleiben erhalten. macOS fragt eventuell noch einmal wie oben beschrieben. Was neu ist, steht im [Changelog](../../../CHANGELOG.md) (Englisch).

## Deinstallieren
1. Wattspur beenden und aus „Programme“ in den Papierkorb ziehen.
2. Deine Fahrten liegen in `~/Library/Containers/io.github.hops-1.wattspur`. Diesen Ordner ebenfalls löschen, wenn sie weg sollen. Dateien in deinem Import-Ordner in iCloud Drive bleiben unberührt.

---
Weiter: [Erster Start](02-first-launch.md)
