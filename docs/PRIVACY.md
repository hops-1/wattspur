# Datenschutz · Privacy

Stand: 22. November 2026 · Gilt für Wattspur für Mac, iPhone und iPad.

## Deutsch

**Kurz:** Wattspur schickt keine Daten an den Entwickler. Deine Fahrten liegen auf deinen Geräten und, solange der Sync an ist, in deinem eigenen iCloud-Konto. Am iPhone und iPad ist er bei einer neuen Installation an, am Mac schaltest du ihn ein. Nur für Karten, Orte und Updates fragt die App Dienste im Internet (siehe *Verbindungen ins Internet*).

**Welche Daten Wattspur verarbeitet**
- Fahrten aus FIT- und GPX-Dateien und aus der GPS-Aufnahme auf dem iPhone: Zeit, Strecke, Route (Standorte), Höhe, Tempo und, wenn vorhanden, Leistung, Trittfrequenz und Puls.
- Dein Profil, wenn du es ausfüllst: Name, Gewicht, Größe, Geburtsjahr, Geschlecht, Foto; dazu Bikes, Ziele und gespeicherte Strecken.

**Wo die Daten liegen**
- Auf deinem Mac, iPhone oder iPad, in der Mediathek von Wattspur.
- Solange *Mit iCloud synchronisieren* an ist (am iPhone und iPad die Voreinstellung, abschaltbar unter „iCloud & Bibliothek“): zusätzlich in der privaten CloudKit-Datenbank deines iCloud-Kontos. Diese Datenbank gehört dir; der Entwickler hat keinen Zugriff darauf. Für iCloud gilt die Datenschutzrichtlinie von Apple.
- Wenn du einen iCloud-Drive-Ordner für den Import wählst, liegen dort die Dateien, die du selbst hineinlegst.

**Standort**
Das iPhone fragt nach dem Standort nur für die GPS-Aufnahme, und nur „beim Verwenden der App“, nie „Immer“. Es nutzt ihn vom Start bis zum Ende der Aufnahme, auch bei gesperrtem Bildschirm und wenn du in CarPlay startest. Beim Auto-Start (aus als Standard, über eine Automation, die du selbst anlegst) liest Wattspur den Standort schon in „Bereit“, um das Losfahren zu erkennen. Zur Fahrt gehören erst die Punkte ab dem Losfahren. Du kannst die Erlaubnis jederzeit in den iOS-Einstellungen entziehen. Das iPad nimmt keine Fahrten auf.

**Bewegung und Fitness**
Für die Höhe der Aufnahme fragt das iPhone einmal nach „Bewegung & Fitness“: Wattspur liest dann während der Aufnahme den Luftdruck-Sensor. Außerdem liest es während der Aufnahme und in „Bereit“ die Bewegungssensoren, für Beschleunigung, Schräglage und Belag. Gespeichert werden nur die Werte, die zur Fahrt gehören. Sie bleiben wie alle Fahrtdaten bei dir. Ohne Barometer nimmt Wattspur die Höhe aus dem GPS.

**Mitteilungen**
Wenn du den Auto-Start einschaltest, fragt das iPhone nach Mitteilungen. Wattspur meldet damit nur eine von selbst gesicherte Fahrt. Die Mitteilung entsteht auf dem iPhone, ohne Server.

**Rohdaten der Bewegung (nur in Testversionen)**
Mit dem Schalter *Rohdaten der Bewegung mitschreiben* in „Mehr“ (aus als Standard) schreibt die Aufnahme zusätzlich Beschleunigung, Drehung und Lage des iPhones und die GPS-Punkte in eine Datei auf dem iPhone (Dateien-App, „Auf meinem iPhone › Wattspur › Bewegung“). Die Datei wird nicht synchronisiert und verlässt das iPhone nur, wenn du sie selbst teilst.

**Diagnose der Aufnahme**
Jede Aufnahme schreibt einmal pro Minute eine Zeile in eine Datei auf dem iPhone (Dateien-App, „Auf meinem iPhone › Wattspur › Diagnose“): Uhrzeit, ob die App sichtbar war, Anzahl und Verzögerung der GPS-Punkte, fehlende Barometerwerte, Last, Speicher, Wärmezustand und Stromsparmodus. Orte, Höhen und Namen stehen nicht darin. Es bleiben die letzten zehn Dateien. Sie werden nicht synchronisiert und gehen nur an andere, wenn du sie selbst teilst.

**Verbindungen ins Internet**
- Karten: Wattspur lädt Kartenkacheln von Apple (MapKit) und, je nach gewähltem Kartenstil (Mac und iPhone), von OpenStreetMap, CyclOSM oder OpenTopoMap. Dabei gehen der Kartenausschnitt und deine IP-Adresse an den jeweiligen Server, keine Fahrten.
- Updates (Mac): Einmal am Tag fragt Wattspur bei GitHub, ob es eine neue Version gibt, wenn du das nicht ausgeschaltet hast. Dabei wird nichts über dich oder deine Fahrten gesendet.
- Orte und Zeitzonen: Für die Zeitzone einer importierten Fahrt (Mac, mit dem Startpunkt) und den vorgeschlagenen Namen einer Aufnahme (iPhone, mit Start- und Endpunkt) schickt Wattspur nur diese Punkte an den Kartendienst von Apple. Es gilt die Datenschutzrichtlinie von Apple. Die übrige Fahrt geht nicht mit.
- Links: Links wie „Wattspur auf GitHub“ oder „Unterstützen“ (Buy me a coffee, Mac) öffnen den Browser. Wattspur sendet dabei nichts. Was auf diesen Seiten passiert, regeln GitHub und Buy me a coffee.

**Was Wattspur nicht tut**
Kein Konto bei Wattspur, kein eigener Server, keine Werbung, keine Analyse, kein Tracking, keine Weitergabe außer den Anfragen oben.

**Löschen**
Fahrten löschst du in der App (Papierkorb, nach 30 Tagen endgültig). Mit der App löschst du die lokale Mediathek. Daten in iCloud löschst du in den iCloud-Einstellungen deines Geräts (*iCloud › Speicher verwalten › Wattspur*).

**Kontakt**
Nils Wiese, über die Issues auf GitHub: https://github.com/hops-1/wattspur/issues

## English

**In short:** Wattspur sends no data to the developer. Your rides stay on your devices and, while sync is on, in your own iCloud account. On iPhone and iPad it is on in a new installation; on the Mac you turn it on. Only for maps, places and updates does the app ask services on the internet (see *Connections to the internet*).

**What Wattspur processes**
- Rides from FIT and GPX files and from GPS recording on the iPhone: time, distance, route (locations), altitude, speed and, if present, power, cadence and heart rate.
- Your profile, if you fill it in: name, weight, height, year of birth, sex, photo; also bikes, goals and saved routes.

**Where the data is kept**
- On your Mac, iPhone or iPad, in Wattspur's library.
- While *Sync with iCloud* is on (the default on iPhone and iPad; turn it off under "iCloud & Library"): also in the private CloudKit database of your iCloud account. That database belongs to you; the developer cannot access it. Apple's privacy policy applies to iCloud.
- If you choose an iCloud Drive folder for importing, it holds the files you put there yourself.

**Location**
The iPhone asks for your location only for GPS recording, and only "while using the app", never "always". It uses it from the start to the end of a recording, also with the screen locked and when you start in CarPlay. With Auto-Start (off by default, through an automation you create yourself) Wattspur already reads the location while "Ready", to notice when you drive off. Only the points from then on belong to the ride. You can withdraw the permission at any time in the iOS settings. The iPad does not record rides.

**Motion & Fitness**
For the height of a recording the iPhone asks once for "Motion & Fitness": Wattspur then reads the air pressure sensor while recording. It also reads the motion sensors while recording and while "Ready", for acceleration, lean angle and road surface. Only the values that belong to the ride are saved. They stay with you like all ride data. Without the barometer Wattspur takes the height from GPS.

**Notifications**
When you turn on Auto-Start, the iPhone asks to allow notifications. Wattspur uses them only to report a ride it saved by itself. The notification is made on the iPhone, without a server.

**Raw motion data (test versions only)**
With the switch *Record Raw Motion* in "More" (off by default) a recording also writes the iPhone's acceleration, rotation and attitude and the GPS points into a file on the iPhone (Files app, "On My iPhone › Wattspur › Bewegung"). The file is not synced and leaves the iPhone only if you share it yourself.

**Recording diagnostics**
Every recording writes one line a minute into a file on the iPhone (Files app, "On My iPhone › Wattspur › Diagnose"): the time, whether the app was visible, the number and delay of GPS points, missing barometer values, load, memory, thermal state and Low Power Mode. It holds no places, heights or names. The last ten files are kept. They are not synced and reach others only if you share them yourself.

**Connections to the internet**
- Maps: Wattspur loads map tiles from Apple (MapKit) and, depending on the map style (Mac and iPhone), from OpenStreetMap, CyclOSM or OpenTopoMap. The server receives the map area and your IP address, no rides.
- Updates (Mac): once a day Wattspur asks GitHub whether a new version is out, unless you turned that off. Nothing about you or your rides is sent.
- Places and time zones: for the time zone of an imported ride (Mac, with its start point) and the suggested name of a recording (iPhone, with its start and end point) Wattspur sends only these points to Apple's map service. Apple's privacy policy applies. The rest of the ride is not sent.
- Links: links such as "Wattspur on GitHub" or "Sponsor" (Buy Me a Coffee, Mac) open the browser. Wattspur sends nothing. What happens on those pages is up to GitHub and Buy Me a Coffee.

**What Wattspur does not do**
No Wattspur account, no server of its own, no ads, no analytics, no tracking, no sharing beyond the requests above.

**Deleting**
You delete rides in the app (trash, final after 30 days). Deleting the app deletes the local library. Data in iCloud is deleted in your device's iCloud settings (*iCloud › Manage Storage › Wattspur*).

**Contact**
Nils Wiese, through the issues on GitHub: https://github.com/hops-1/wattspur/issues
