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
| Development zurückgesetzt (22:07) | Mac meldet „Zone Not Found“, setzt den Sync-Stand zurück (`ZoneDeleted`), behält seine Daten und lädt neu hoch; iPhone-App vorher gelöscht und frisch installiert (sonst hätte auch das iPhone alles erneut hochgeladen) |
| Frisches iPhone | ganze Bibliothek nach ca. **10 s** da, 85 Fahrten wie am Mac (zwei Fahrten vom 4.11. inzwischen zusammengefügt) |
| Größe in iCloud | Einstellungen › iCloud zeigt für „Wattspur“ **691 MB** (4.11.2026, 21:50, Production noch leer) und **690,7 MB** (5.11.2026, 5:55, Production gefüllt). Gemessen mit `-WattspurMeasureCloudKit YES` (5.11.2026) liegen in iCloud aber nur: **Production ca. 79 MB** (195 Fahrten 53,2 MB, 147 Originaldateien 25,0 MB, Räder 0,2 MB, Rest klein) und **Development ca. 57 MB** (201 Fahrten, 28 Originaldateien). Das sind rund **0,4 MB je Fahrt**, weniger als die 117 MB der Bibliothek auf dem Mac. Die Zahl in den Einstellungen folgt dem Inhalt nicht (über Nacht kamen 79 MB dazu, sie blieb gleich); vermutlich zählt Apple gelöschte Daten (Reset von Development, gelöschte Doppel) noch eine Weile mit. Nachmessen in einigen Tagen |

## Entscheidung: externer Speicher

Die Frage aus V-15 war, ob die Zeitreihen über `@Attribute(.externalStorage)` laufen können oder einen eigenen Weg brauchen. Sie bleiben, wie sie sind:

- Das Hochladen der ganzen Bibliothek dauert gut eine Minute, das ist nur einmal pro Gerät nötig.
- Eine einzelne Fahrt mit Zeitreihe braucht Sekunden, sichtbar wird sie nach 30 s bis 1 min. Die Wartezeit liegt bei CloudKit, nicht an der Größe.
- Ein eigener Weg (z. B. Dateien in iCloud Drive) brächte einen zweiten Sync mit eigenen Fehlerfällen.
- **Größe geklärt (5.11.2026):** Gemessen sind rund 0,4 MB je Fahrt in iCloud, die kostenlosen 5 GB reichen also für über 10.000 Fahrten. Der Mirror speichert die meisten Zeitreihen und Originaldateien direkt im Eintrag; nur große Werte (6 Zeitreihen, 1 Datei) gehen als `CKAsset`. Packen der Zeitreihen oder ein Sync ohne Originaldateien ist nicht nötig. Messen: Debug-Build mit `-WattspurMeasureCloudKit YES` starten, er listet je Eintragstyp Anzahl und Bytes und beendet sich; er liest nur. Für Production braucht der Debug-Build `com.apple.developer.icloud-container-environment = Production` in einer Kopie der Entitlements (`CODE_SIGN_ENTITLEMENTS=…`).

## Was daraus folgt

1. **Zusammenführen in die Apps einbauen** (B-216): `RideLibrary.mergeSyncDuplicates()` beim Start und nach Änderungen aus iCloud aufrufen, auf Mac und iPhone. Beide Geräte wählen dieselben Datensätze (ältestes `createdAt`, dann `id`), so wird nichts doppelt gelöscht.
2. **Sync-Status** (B-220): Hinweise für „iCloud für Wattspur aus“ („Neue Fahrten bleiben nur auf diesem iPhone“), „Speicher voll“ und „kein Netz“, dazu „Zuletzt synchronisiert: …“. Kurze Verzögerungen bis etwa 1 min sind normal und bekommen keine Meldung.
3. **Vorsicht beim Ausschalten:** Eine Aufnahme, die beim Ausschalten von iCloud noch nicht hochgeladen war, wird vermutlich mit der lokalen Kopie gelöscht. Am Mac passiert beim Abmelden von iCloud wahrscheinlich dasselbe. Das ist **nicht getestet**, mit der echten Bibliothek wird es auch nicht ausprobiert. Die Sicherung vor dem ersten Sync (P-22) bleibt deshalb Pflicht. Der Hinweis in B-220 soll sagen, ob noch etwas auf den Upload wartet.
4. **Schema nach Production** erst mit dem OK von Nils, danach TestFlight (B-219).

## Nebenbefunde

- **1.8.3:** Die notarisierte Version trägt das iCloud-Entitlement, der Schalter „Mit iCloud synchronisieren“ ist darum bedienbar. Gegen Production gibt es noch kein Schema, Uploads scheitern, die Daten bleiben lokal. Entscheidung Nils: bleibt so bis 1.8.4.
- **Strecke beim Aufnehmen auf dem iPhone:** Fahrt am 4.11.2026, 19:01 (Roßdorf–Reinheim): Die GPS-Spuren von Wattspur und Flow-App sind gleich lang (10,75 km). Wattspur zeigt aber 10,86 km, also 1 % mehr. `RideRecording` zählt Schritte ab 5 m und damit auch GPS-Zittern. Das ist kein Sync-Thema. **Nachgemessen 5.11.2026 (B-242):** An der Fahrt vom 3.11. morgens ist die iPhone-Spur in derselben Zeit nicht länger als die von Bosch; das Plus kommt vom früheren Start und späteren Stopp der Aufnahme, nicht vom Zittern. Keine Änderung nötig.
- **Radumfang in der Flow-App:** Mit 2260 mm zählt das Rad 0,8 % weniger als die GPS-Spur. Etwa 2280 mm passen zu beiden Fahrten vom 4.11.2026.

## Testaufbau

- Debug-Builds starten mit `-WattspurSpikeLibrary YES -WattspurSpikeSync YES`. Die Mac-App kopiert dann die Bibliothek einmal nach `…/Spike/default.store` und synchronisiert nur diese Kopie. Die Einstellungen liegen in einer eigenen Suite (`io.github.hops-1.wattspur.spike`), damit Debug und Release (gleiche Bundle-ID) sich nicht in die Quere kommen (`App/SpikeLibrary.swift`, nur `#if DEBUG`).
- Das iPhone läuft mit `WATTSPUR_IOS_DATABASE = icloud` und `iOS/Wattspur-iOS-iCloud.entitlements` aus der lokalen, nicht eingecheckten `Config/Local.xcconfig`.
- Die echten Fahrtdateien liegen nicht im Repository.
- **Schema vor dem Deploy vervollständigen:** CloudKit legt in Development einen Typ oder ein Feld erst an, wenn ein Eintrag mit Wert dafür hochgeladen wird. Die erste Deploy-Liste (4.11.2026) hatte deshalb kein `CD_Goal`. Ein Debug-Build mit `-WattspurInitCloudKitSchema YES` ruft `initializeCloudKitSchema()` auf einem leeren eigenen Speicher auf, legt so alle Typen mit allen Feldern an und beendet sich. Erst danach „Deploy Schema Changes“ in der CloudKit Console, denn Production kann später nichts mehr hinzufügen.
