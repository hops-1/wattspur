# Spike V-14: iCloud-Ordner und GPS-Aufnahme auf dem iPhone

Stand: 2.11.2026 · Vorarbeit für iOS 0.2 (B-208 bis B-213, Requirements 10.21)

## Frage
1. Kann die iPhone-App den Ordner `Wattspur Import` in iCloud Drive **ohne iCloud-Berechtigung**
   (kostenlose Apple-ID, „Personal Team“) wählen, sich merken, lesen und beschreiben?
   Wie schnell sieht der Mac eine neue Datei?
2. Nimmt `CLLocationUpdate.liveUpdates(.fitness)` mit `CLBackgroundActivitySession` bei gesperrtem
   Bildschirm eine ganze Fahrt auf? Punktabstand, Genauigkeit, Lücken, Akku.
3. Läuft beides mit dem Personal Team?

## Wie geprüft wird
Die App hatte dafür im Tab *Mehr* einen Test-Bereich (mit B-211 entfernt; die GPS-Werte zeigt jetzt die echte Aufnahme):
- **Ordner:** „Ordner wählen …“ (`fileImporter` mit `.folder`), Lesezeichen in `UserDefaults`;
  „Testdatei schreiben“ legt `iPhone/Test/Write Test.txt` mit Uhrzeit an (über `NSFileCoordinator`),
  „Testdatei lesen“ liest sie zurück, „Ordner auflisten“ zeigt den Inhalt und wie viele Dateien
  noch nicht geladen sind (`.…icloud`). Der Mac-Import schaut nur direkt in den Ordner, Unterordner
  wie `iPhone/` lässt er in Ruhe.
- **GPS:** „GPS-Test starten“ zeichnet auf, schreibt jeden Punkt sofort in eine CSV und zeigt
  Dauer, Punkte (davon im Hintergrund), Sekunden je Punkt, Ø Genauigkeit, Lücken über 10 s
  (außer bei Stillstand), Strecke und Akku vorher/nachher. Danach „CSV im Ordner sichern“
  (nach `iPhone/Test/`) und „Als GPX an den Mac geben“ (direkt in `Wattspur Import`, mit
  `creator="Wattspur iOS"`: Der Mac importiert sie wie jede GPX).

Ablauf auf dem iPhone:
1. App wie in `docs/learning/30-ios-app.md` aufs iPhone bringen.
2. *Mehr* → „Ordner wählen …“ → iCloud Drive → `Wattspur Import` → „Öffnen“.
3. „Testdatei schreiben“, Uhrzeit merken, am Mac im Finder schauen, wann `iPhone/Test/Write Test.txt` erscheint.
4. App ganz schließen (nach oben wischen), neu öffnen, „Testdatei lesen“: klappt es ohne neue Ordnerwahl?
5. „GPS-Test starten“, Standort „Beim Verwenden der App erlauben“, Bildschirm sperren, ca. 30 Minuten fahren.
6. „GPS-Test beenden“, Bildschirmfoto der Werte, „CSV im Ordner sichern“, „Als GPX an den Mac geben“.
7. Am Mac: Erscheint die Fahrt in Wattspur?

## Ergebnis
Test auf Nils' iPhone am 2.11.2026 (App mit kostenloser Apple-ID signiert). Ordner und Kurztest am Nachmittag; GPS mit zwei Autofahrten am Abend (7:31 min und 33:04 min, Bildschirm gesperrt, App mit B-211/B-212).

| Frage | Ergebnis |
|---|---|
| Ordner wählen ohne iCloud-Berechtigung | ✅ klappt mit `fileImporter`, ohne iCloud-Berechtigung im Profil |
| Nach Neustart ohne neue Wahl lesbar | ✅ App ganz geschlossen und neu geöffnet, Testdatei ohne neue Ordnerwahl gelesen („Written on the iPhone at 2.11.2026, 16:14:31“) |
| Zeit bis die Testdatei am Mac erscheint | ✅ kam am Mac an (`iPhone/Test/Write Test.txt`); Dauer nicht gestoppt |
| Am Mac als Fahrt | ✅ „GPS-Test 2026-11-02 16-19“ in der Liste, Quelle GPX, Bike „Cube One22“ aus der Einstellung „Import für“ (keine Rückfrage), Fahrzeit 20 s von 31 s, Ø 2,6 km/h. GPS-Höhe springt zwischen 169 und 184 m im Stand: Für Anstieg aus iPhone-Aufnahmen braucht B-211 einen Höhenfilter |
| GPS bei gesperrtem Bildschirm | ✅ lief bei gesperrtem Bildschirm durch, auch rund 25 Minuten Stillstand (geparkt) ohne Abbruch |
| Sekunden je Punkt, Ø Genauigkeit | ✅ etwa 1 Punkt je Sekunde (451 Punkte in 7:31 min, 1665 in 33:04 min). Die Genauigkeit steht nicht in der GPX; Punkte über 30 m werden schon in der App verworfen |
| Lücken über 10 s | ✅ keine bei Rad-Tempo. Nur zwei Lücken (23 s und 80 s) auf der Schnellstraße über 100 km/h: Der Sprungfilter (`RideRecording.maxSpeed`) verwirft solche Punkte absichtlich, danach geht die Spur normal weiter |
| Akku für 30 Minuten | ◐ 54 % → 36 % über den ganzen Abend (rund 40 min Aufnahme plus sonstige Nutzung); ein Wert nur für die Aufnahme fehlt noch, eine längere Radtour wird ihn zeigen |
| GPX vom iPhone am Mac importiert | ✅ Beide Autofahrten wurden am Mac importiert, mit dem Bike aus der Datei („Moped“, `wattspur:bike`) und `creator="Wattspur iOS"`; der Mac schrieb den Stand fürs iPhone 40 s nach der Datei neu. Kurztest (38 s, 25 Punkte, `creator="Wattspur iOS"`). Die Datei wartete erst auf dem iPhone (*Dateien*: „Warten“, nicht hochgeladen, vermutlich Mobilfunk ohne Erlaubnis für iCloud Drive). Im WLAN war sie rund 1:45 min später am Mac, der Mac hat sie sofort importiert und nach `Importiert/` verschoben. Folgerung für B-212: Upload-Stand anzeigen (`ubiquitousItemIsUploaded`), „wartet auf iCloud“ vor „wartet auf den Mac“ |

## Entscheidung
2.11.2026: **Austausch über den iCloud-Ordner wie geplant.** Ordnerzugriff, Schreiben, Lesen nach Neustart und der Import am Mac haben auf Nils’ iPhone geklappt; Nils hat mit B-178/B-208 weitermachen lassen. Die lange Fahrt mit gesperrtem Bildschirm (GPS im Hintergrund, Akku) prüft Nils mit der echten Aufnahme (B-211) und trägt sie hier nach.

2.11.2026 abends: Die GPS-Fragen sind mit zwei Autofahrten beantwortet, V-14 ist damit erledigt. Offen bleibt nur ein genauer Akkuwert für eine lange Radtour.
