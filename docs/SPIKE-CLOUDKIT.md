# Spike: CloudKit mit echten Daten

Backlog-Aufgabe **V-15**, Voraussetzung für **B-216** bis **B-220** (iOS 0.3) und Mac 1.8.4.
Stand: 4.11.2026. Getestet von Nils und Claude mit einer **Kopie** der echten Bibliothek von Nils (84 Fahrten mit Zeitreihen, Routen, Originaldateien und Fotos) im **Development**-Container `iCloud.io.github.hops-1.wattspur`. Geräte: Mac mit einer Debug-Version von Wattspur, iPhone 13 mit einer Debug-Version von Wattspur iOS. Die Production-Umgebung blieb unberührt.

## Kurzfassung

- **Die Zeitreihen bleiben externer Speicher (`@Attribute(.externalStorage)`).** `Ride.samplesData`, `SourceFile.data` und die Fotos sind es schon. CloudKit überträgt sie als eigene Dateien (`CKAsset`). Ein getrennter Weg für die Zeitreihen ist nicht nötig.
- **Erstes Hochladen:** 84 Fahrten in etwa **80 s** (41 Pakete, keine Fehler). Das Schema in Development hat der Mac dabei selbst angelegt.
- **Erstes Herunterladen auf ein leeres iPhone:** vollständig. Während des Imports zeigte die Liste kurz **141 statt 84** Fahrten. Teile zusammengefügter Fahrten und Fahrten im Papierkorb kamen vor ihren Verknüpfungen an. Seit dem Neuladen bei Änderungen aus iCloud stimmt die Liste von selbst.
- **Laufzeit einer Änderung:** Mac → iPhone etwa **30 s** (Umbenennen). iPhone → Mac etwa **30 s bis 1 min** (neue Aufnahme). Es braucht dafür keine Bedienung am anderen Gerät.
- **Löschen** geht in beide Richtungen. Die andere Seite zieht von selbst nach.
- **Ohne Netz** nimmt das iPhone normal auf und speichert die Fahrt. Sobald wieder Netz da ist, kommt sie etwa 1 min später am Mac an.
- **iCloud für Wattspur ausgeschaltet:** iOS **löscht die lokale Kopie** auf dem iPhone. Das ist Apples Verhalten bei `NSPersistentCloudKitContainer`, die Daten gehören zum iCloud-Konto. Die Liste zeigt dann nur noch Fahrten, die danach entstanden sind. Nach dem Einschalten ist nach etwa 1 min alles wieder da, auch die neue Fahrt. Diese kommt etwa 30 s später am Mac an.
- **iCloud-Speicher voll:** nicht nachgestellt, denn dazu müsste der echte Speicher von Nils voll sein. Laut Apple bleiben die Änderungen lokal und werden später wiederholt, wie ohne Netz. Die App zeigt dazu bisher **keinen Hinweis** (→ B-220).
- **Doppelte Fahrer, Räder und Ziele:** CloudKit kennt keine eindeutigen Schlüssel. Ein frisches iPhone legt seinen eigenen Fahrer und sein Rad „Mein eBike“ an. Nach dem ersten Sync stehen sie neben denen vom Mac. Das Zusammenführen dafür ist im Kit fertig (`SyncMergeService`) und muss noch in beide Apps.

## Messungen

| Was | Ergebnis |
|---|---|
| Erstes Hochladen vom Mac | Start 07:31:51, erste Pakete ab 07:31:57, 41 Pakete bis 07:33:11, keine CloudKit-Fehler (zwei harmlose `134417` beim Start: Anfrage vor der Initialisierung) |
| Erstes Herunterladen aufs iPhone | 84 von 84 Fahrten, nach dem Import gleich wie am Mac |
| Umbenennen am Mac | nach ca. 30 s auf dem iPhone |
| Aufnahme auf dem iPhone | erscheint am Mac ohne Bedienung, als GPX-Fahrt; die FIT aus der Flow-App ergänzt sie danach über den überwachten Ordner („automatisch aktualisiert“, Quelle „Bosch-FIT · GPX angehängt“) |
| Löschen am Mac / am iPhone | die andere Seite zieht nach |
| Aufnahme im Flugmodus | bleibt auf dem iPhone, erscheint ca. 1 min nach dem Einschalten des Netzes am Mac |
| iCloud für Wattspur aus | lokale Kopie auf dem iPhone weg, neue Aufnahme bleibt; nach dem Einschalten ca. 1 min bis alles zurück, Mac ca. 30 s später |
| Größe in iCloud | **691 MB** für „Wattspur“ (iPhone, Einstellungen › iCloud, 4.11.2026, 21:50), bei 86 Fahrten rund 8 MB je Fahrt. Der Ordner `Wattspur Import` in iCloud Drive hat nur 16 MB, der Rest ist CloudKit. Die Bibliothek auf dem Mac ist dagegen nur **117 MB** groß (`default.store` 24,3 MB, `-wal` 3,9 MB, `.default_SUPPORT` mit Zeitreihen, Dateien und Fotos 89,2 MB). In iCloud liegt also rund das **Sechsfache**, Ursache noch offen (Reste früherer Tests in Development? alte Fassungen geänderter Dateien?) |

## Entscheidung: externer Speicher

Die Frage aus V-15 war, ob die Zeitreihen über `@Attribute(.externalStorage)` laufen können oder einen eigenen Weg brauchen. Sie bleiben, wie sie sind:

- Das Hochladen der ganzen Bibliothek dauert gut eine Minute, das ist nur einmal pro Gerät nötig.
- Eine einzelne Fahrt mit Zeitreihe braucht Sekunden, sichtbar wird sie nach 30 s bis 1 min. Die Wartezeit liegt bei CloudKit, nicht an der Größe.
- Ein eigener Weg (z. B. Dateien in iCloud Drive) brächte einen zweiten Sync mit eigenen Fehlerfällen.
- **Vorbehalt Größe:** Mit rund 8 MB je Fahrt wären 600 Fahrten mehr als die 5 GB, die iCloud kostenlos bietet. Bevor das Schema nach Production geht, wird geklärt, wie sich die 691 MB aufteilen (iCloud Drive gegen CloudKit, Zeitreihen gegen Originaldateien und Fotos). Ist CloudKit der große Teil, werden die Zeitreihen gepackt oder die Originaldateien nicht mehr mitsynchronisiert. Der externe Speicher bleibt in beiden Fällen.

## Was daraus folgt

1. **Zusammenführen in die Apps einbauen** (B-216): `RideLibrary.mergeSyncDuplicates()` beim Start und nach Änderungen aus iCloud aufrufen, auf Mac und iPhone. Beide Geräte wählen dieselben Datensätze (ältestes `createdAt`, dann `id`), so wird nichts doppelt gelöscht.
2. **Sync-Status** (B-220): Hinweise für „iCloud für Wattspur aus“ („Neue Fahrten bleiben nur auf diesem iPhone“), „Speicher voll“ und „kein Netz“, dazu „Zuletzt synchronisiert: …“. Kurze Verzögerungen bis etwa 1 min sind normal und bekommen keine Meldung.
3. **Vorsicht beim Ausschalten:** Eine Aufnahme, die beim Ausschalten von iCloud noch nicht hochgeladen war, wird vermutlich mit der lokalen Kopie gelöscht. Am Mac passiert beim Abmelden von iCloud wahrscheinlich dasselbe. Das ist **nicht getestet**, mit der echten Bibliothek wird es auch nicht ausprobiert. Die Sicherung vor dem ersten Sync (P-22) bleibt deshalb Pflicht. Der Hinweis in B-220 soll sagen, ob noch etwas auf den Upload wartet.
4. **Schema nach Production** erst mit dem OK von Nils, danach TestFlight (B-219).

## Nebenbefunde

- **1.8.3:** Die notarisierte Version trägt das iCloud-Entitlement, der Schalter „Mit iCloud synchronisieren“ ist darum bedienbar. Gegen Production gibt es noch kein Schema, Uploads scheitern, die Daten bleiben lokal. Entscheidung Nils: bleibt so bis 1.8.4.
- **Strecke beim Aufnehmen auf dem iPhone:** Fahrt am 4.11.2026, 19:01 (Roßdorf–Reinheim): Die GPS-Spuren von Wattspur und Flow-App sind gleich lang (10,75 km). Wattspur zeigt aber 10,86 km, also 1 % mehr. `RideRecording` zählt Schritte ab 5 m und damit auch GPS-Zittern. Das ist kein Sync-Thema, lässt sich aber verbessern.
- **Radumfang in der Flow-App:** Mit 2260 mm zählt das Rad 0,8 % weniger als die GPS-Spur. Etwa 2280 mm passen zu beiden Fahrten vom 4.11.2026.

## Testaufbau

- Debug-Builds starten mit `-WattspurSpikeLibrary YES -WattspurSpikeSync YES`. Die Mac-App kopiert dann die Bibliothek einmal nach `…/Spike/default.store` und synchronisiert nur diese Kopie. Die Einstellungen liegen in einer eigenen Suite (`io.github.hops-1.wattspur.spike`), damit Debug und Release (gleiche Bundle-ID) sich nicht in die Quere kommen (`App/SpikeLibrary.swift`, nur `#if DEBUG`).
- Das iPhone läuft mit `WATTSPUR_IOS_DATABASE = icloud` und `iOS/Wattspur-iOS-iCloud.entitlements` aus der lokalen, nicht eingecheckten `Config/Local.xcconfig`.
- Die echten Fahrtdateien liegen nicht im Repository.
