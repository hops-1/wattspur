# iPhone und iCloud

Ab Wattspur 1.8.4 gibt es Wattspur auch auf dem iPhone, zuerst für Tester über TestFlight. Mac und iPhone teilen sich über iCloud **eine Mediathek**: Was du am iPhone aufnimmst, ist kurz darauf am Mac, und was du am Mac importierst, siehst du am iPhone. Das iCloud ist dein eigenes. Es gibt keinen Wattspur-Server und kein Wattspur-Konto.

## Wattspur aufs iPhone bringen
1. Du bekommst eine Einladung zu **TestFlight** per E-Mail oder als Link.
2. Lade die App **TestFlight** aus dem App Store und öffne darin die Einladung.
3. Tippe bei Wattspur auf **Installieren**.

## Sync einschalten
**Am Mac:** **Wattspur › Einstellungen › iCloud › Mit iCloud synchronisieren**. Beim ersten Mal legt Wattspur vorher eine Sicherung deiner Mediathek daneben an. Der Sync beginnt beim nächsten Start von Wattspur. Das erste Hochladen dauert je nach Menge ein paar Minuten.

**Am iPhone:** **Mehr › Mit iCloud synchronisieren** ist bei einer neuen Installation schon an. Nach dem ersten Abgleich sind deine Fahrten vom Mac da.

Mac und iPhone müssen mit demselben Apple Account bei iCloud angemeldet sein.

**Was synchronisiert wird:** Fahrten mit Zeitreihen, Routen und Originaldateien, Bikes, Profil, Ziele, gespeicherte Strecken und der Papierkorb. Deine Einstellungen und der überwachte Ordner bleiben auf jedem Gerät für sich.

**Wie schnell:** Eine Änderung ist nach 30 Sekunden bis etwa einer Minute auf dem anderen Gerät. Ohne Netz nimmt das iPhone normal auf. Die Fahrt kommt an den Mac, sobald wieder Netz da ist.

## Doppelte Fahrer und Bikes
Ein neues iPhone legt zuerst seinen eigenen Fahrer und sein eigenes „Mein eBike“ an. Nach dem ersten Abgleich führt Wattspur sie mit denen vom Mac zusammen, auf beiden Geräten. Es bleibt immer der ältere Eintrag, also meist der vom Mac. Dasselbe gilt für Ziele und für eine Datei, die du an beiden Geräten importiert hast.

## Ist alles synchronisiert?
- **Am Mac:** **Einstellungen › iCloud** zeigt „An. Zuletzt synchronisiert vor …“.
- **Am iPhone:** **Mehr › iCloud › Zuletzt synchronisiert**.

Kurze Verzögerungen sind normal und bekommen keine Meldung. Einen Hinweis siehst du, wenn:
- das Gerät nicht bei iCloud angemeldet ist oder iCloud für Wattspur aus ist,
- dein iCloud-Speicher voll ist,
- seit zwei Minuten keine Verbindung besteht.

Am iPhone steht zusätzlich eine Warnung, solange Änderungen noch auf den Upload warten.

## Vorsicht beim Ausschalten
Schaltest du am iPhone iCloud für Wattspur aus (**Einstellungen › dein Name › iCloud**) oder meldest dich von iCloud ab, löscht iOS die Kopie auf dem iPhone. Deine Fahrten bleiben in iCloud und am Mac und kommen nach dem Einschalten zurück. Eine Fahrt, die noch nicht hochgeladen war, kann dabei aber verloren gehen. Schalte deshalb erst aus, wenn bei **Zuletzt synchronisiert** keine Warnung steht.

## Ohne iCloud
Wenn du iCloud nicht nutzen willst, oder dein Speicher voll ist und du kein größeres Abo möchtest, schalte am iPhone **Mehr › Mit iCloud synchronisieren** aus. Dann arbeitet das iPhone wie vor 1.8.4:
- **Über einen Ordner:** Am Mac schaltest du **Einstellungen › Import › Fahrten für das iPhone bereitstellen** ein. Das iPhone zeigt dann die Fahrten, die der Mac in den Ordner schreibt, und legt neue Aufnahmen als GPX dort ab. Der Ordner kann in iCloud Drive liegen, aber auch bei Dropbox oder OneDrive, solange der Mac ihn beobachtet.
- **Per AirDrop:** Eine Aufnahme schickst du mit **GPX teilen** an den Mac und importierst sie dort wie jede andere Datei.

Am Mac lässt du **Mit iCloud synchronisieren** dann aus.

## Eine Fahrt als GPX teilen
In der Detailansicht einer Fahrt oben rechts, oder in der Liste mit langem Druck auf die Fahrt: **GPX teilen**. Die Datei enthält die ganze Spur mit Zeit und Höhe, dazu das Bike. Du kannst sie per AirDrop an den Mac schicken, in die Dateien-App legen oder in komoot öffnen. Fahrten ohne GPS lassen sich nicht teilen.

## Motorrad
Beim Aufnehmen lässt Wattspur Punkte weg, die eine unmögliche Geschwindigkeit ergeben würden. So fallen GPS-Sprünge heraus. Beim E-Bike liegt die Grenze bei 100 km/h. Wer mit dem Motorrad aufnimmt, stellt **Mehr › Aufnahme › Fahrzeug › Motorrad** ein. Dann gilt eine Grenze von 300 km/h.

Damit Motorradfahrten nicht in die Summen deiner Fahrräder fallen, lege dafür im Profil ein Bike mit der Art **Motorrad** an (siehe [Profil und Bikes](07-profile-and-bikes.md)).

---
Weiter: [Fragen](06-faq.md) · [Inhalt](README.md)
