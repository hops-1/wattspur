# iPhone und iCloud

Ab Wattspur 1.8.4 gibt es Wattspur auch auf dem iPhone, zuerst für Tester über TestFlight. Mac und iPhone teilen sich über iCloud **eine Mediathek**: Was du am iPhone aufnimmst, ist kurz darauf am Mac, und was du am Mac importierst, siehst du am iPhone. Das iCloud ist dein eigenes. Es gibt keinen Wattspur-Server und kein Wattspur-Konto.

## Wattspur aufs iPhone bringen
1. Du bekommst eine Einladung zu **TestFlight** per E-Mail oder als Link.
2. Lade die App **TestFlight** aus dem App Store und öffne darin die Einladung.
3. Tippe bei Wattspur auf **Installieren**.

## Sync einschalten
**Am Mac:** **Wattspur › Einstellungen › iCloud › Mit iCloud synchronisieren**. Jedes Mal legt Wattspur vorher eine Sicherung deiner Mediathek daneben an. Der Sync beginnt beim nächsten Start von Wattspur. Das erste Hochladen dauert je nach Menge ein paar Minuten.

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
Wenn du iCloud nicht nutzen willst, oder dein Speicher voll ist und du kein größeres Abo möchtest, schalte am iPhone **Mehr › Mit iCloud synchronisieren** aus. Das gilt ab dem nächsten Öffnen von Wattspur. Die Fahrten bleiben dann auf dem iPhone, neue Aufnahmen auch:
- **Per AirDrop:** Eine Aufnahme schickst du mit **GPX teilen** an den Mac und importierst sie dort wie jede andere Datei.
- **Über einen Ordner:** nur, wenn du die iPhone-App schon vor 0.5 mit einem Ordner genutzt hast. **Dieser Weg endet mit der iPhone-App 0.6 und Wattspur 1.8.9;** schalte bis dahin den Sync mit iCloud ein. „GPX teilen“ bleibt. Am Mac schaltest du **Einstellungen › Import › Fahrten für das iPhone bereitstellen** ein. Das iPhone zeigt dann die Fahrten, die der Mac in den Ordner schreibt, und legt neue Aufnahmen als GPX dort ab.

Am Mac lässt du **Mit iCloud synchronisieren** dann aus.

## Eine Fahrt ansehen
Tippe in der Liste auf eine Fahrt. Oben steht die Karte, direkt darunter die Diagramme.
- **Wischen:** Mit iCloud hat jede Messgröße eine eigene Seite: Tempo, Leistung, Trittfrequenz, Puls und Höhe. Es gibt nur Seiten für Werte, die die Fahrt hat. Die Punkte unten zeigen, wo du bist. Jede Seite nennt das Maximum und den Durchschnitt, bei der Höhe den Anstieg und den Abstieg.
- **Finger halten und ziehen:** Eine Linie markiert die Stelle. Oben steht dann die Strecke und der Wert an dieser Stelle, z. B. „0,4 km · 25,2 km/h“. Auf der Karte zeigt ein Punkt, wo das war. Lässt du los, verschwinden Linie und Punkt.
- Ohne iCloud zeigt die Fahrt wie bisher das Höhenprofil.

## Eine Fahrt bearbeiten
Mit dem Stift oben rechts in der Detailansicht änderst du den **Namen** und das **Bike** einer Fahrt. Mit iCloud kommt die Änderung auch am Mac an. Ohne iCloud bearbeitest du Fahrten am Mac.

## Fahrten aus der Flow-App
Die Bosch-Datei einer Fahrt hat mehr Werte als eine GPS-Aufnahme, z. B. Leistung und Trittfrequenz. So kommt sie auf das iPhone:
1. Öffne in der **Flow-App** die Fahrt und teile sie als **FIT**-Datei.
2. Wähle im Teilen-Menü **Wattspur**. Eine FIT- oder GPX-Datei in der **Dateien-App** kannst du ebenso mit Wattspur öffnen.

**Mit iCloud** wird daraus eine Fahrt auf dem iPhone, und sie kommt auch an den Mac. Wattspur stellt dieselben Fragen wie am Mac:
- **Welches Bike?** Eine GPX-Datei sagt nicht, zu welchem Bike sie gehört. Bei zwei oder mehr Bikes fragt Wattspur.
- **Schon in der Bibliothek:** Hast du die Fahrt auch mit dem iPhone aufgenommen, kannst du **Bosch-Werte übernehmen**, **Beide behalten** oder **Überspringen**. Wattspur zeigt dazu Start, Strecke und Zeit von beiden.
- Eine GPX-Datei zu einer Bosch-Fahrt hängt Wattspur an die Fahrt an. Die Bosch-Werte bleiben.
- **Eine Tour in mehreren Bosch-Teilen:** Die Flow-App teilt eine Tour mit langen Pausen in mehrere Fahrten, das iPhone nimmt sie als eine auf. Liegen die Bosch-Fahrten ganz in der Zeit deiner Aufnahme und ergeben zusammen ihre Strecke, fügt Wattspur sie zu einer Fahrt zusammen. Sie bekommt Name und Bike der Aufnahme und deren Puls, Schräglage und Belag. Die Aufnahme selbst kommt in den Papierkorb, dort kannst du sie wiederherstellen. Es ist egal, welche Datei zuletzt kommt. Hast du die Teile schon früher importiert, lege eine ihrer FIT-Dateien noch einmal ab.

**Ohne iCloud** legt das iPhone die Datei in den Ordner „Wattspur Import“. Der Mac importiert sie von dort wie jede andere Datei.

## Höhe beim Aufnehmen
Wattspur misst die Höhe beim Aufnehmen mit dem **Barometer** des iPhones, also über den Luftdruck. Das ist viel ruhiger als die GPS-Höhe allein, deshalb liegt der Anstieg näher an dem von Bosch. Die Höhe über dem Meer kommt weiter vom GPS: Wattspur gleicht beide laufend ab. So stört auch eine Wetteränderung während der Fahrt nicht.

Beim ersten Aufnehmen fragt das iPhone einmal nach **Bewegung & Fitness**. Erlaubst du das nicht, nimmt Wattspur die GPS-Höhe wie bisher. Ändern kannst du das unter **Einstellungen › Datenschutz & Sicherheit › Bewegung & Fitness**.

## Schräglage, Beschleunigung und Belag
Ab 0.5.1 liest das iPhone beim Aufnehmen auch seine Bewegungssensoren, mit derselben Freigabe **Bewegung & Fitness** wie das Barometer. Im Tour-Detail stehen dann Kacheln für die größte Schräglage links und rechts, die stärkste Beschleunigung und Bremsung, die beste Zeit aus dem Stand und den Anteil unebenen Belags. Im Karussell gibt es die Seite **Schräglage**. Die Karte färbt die Spur nach Schräglage; mit dem Umschalter oben auf der Karte wechselst du zu **Belag**. Wie die Werte entstehen, steht unter [Kennzahlen](05-metrics.md). Am Mac siehst du dieselben Werte im Tour-Detail.

Für Tests gibt es unter **Mehr › Test** den Schalter **Rohdaten der Bewegung mitschreiben**. Ist er an, legt jede Aufnahme zusätzlich eine Datei in der Dateien-App ab (**Auf meinem iPhone › Wattspur › Bewegung**), etwa 20 MB pro Stunde. Normalerweise bleibt er aus.

## Unterwegs: Fahrtrichtung, Höhe und Profil
- **Karte in Fahrtrichtung:** Der Knopf unten rechts auf der Karte der Aufnahme wechselt zwischen **Norden oben** und **Fahrtrichtung oben**, wie in einer Navi-App. Die Richtung kommt aus der GPS-Bewegung, nicht vom Kompass, der in der Tasche falsch zeigt. Im Stand und unter etwa 7 km/h dreht sich die Karte nicht.
- **Spur nach Höhe:** Der Knopf mit dem Berg darüber färbt die bisher gefahrene Spur von Blau (tief) bis Rot (hoch); die Skala wächst mit den Höhen, die du schon gefahren bist. Im Tour-Detail wählst du über der Karte zwischen **Schräglage**, **Belag**, **Höhe** und **Einfarbig**, je nachdem, was die Fahrt hat.
- **Profil während der Fahrt:** Wische die Werte unter der Karte zur Seite (im Querformat die Werte in der Leiste links). Dort wächst das Profil der bisherigen Fahrt mit; oben wählst du **Höhe** oder **Tempo**.

Wattspur merkt sich alle drei Einstellungen.

## Eine Fahrt als GPX teilen
In der Detailansicht einer Fahrt oben rechts, oder in der Liste mit langem Druck auf die Fahrt: **GPX teilen**. Die Datei enthält die ganze Spur mit Zeit und Höhe, dazu das Bike. Du kannst sie per AirDrop an den Mac schicken, in die Dateien-App legen oder in komoot öffnen. Fahrten ohne GPS lassen sich nicht teilen.

## In der Halterung am Lenker (quer)
Die meisten Halterungen am Lenker halten das iPhone quer. Wattspur läuft auch quer:
- **Beim Aufnehmen** füllt die Karte den Bildschirm. Links zeigt eine Leiste das Tempo groß, darunter Ø, Strecke, Zeit, Höhe und Anstieg, unten Pause und Stopp.
- **Die Tab-Leiste** sitzt links unten, in allen Bereichen.
- **Übersicht:** links die letzte Fahrt, rechts Woche, Monat, Jahr und alle Fahrten.
- **Fahrten:** links die Liste, rechts die gewählte Fahrt.

Soll sich der Bildschirm nicht drehen, schalte im Kontrollzentrum die Ausrichtungssperre ein.

## Fahrten finden
Über der Liste der Fahrten:
- **Suchen** nach einem Namen, zum Beispiel „Michelstadt“. Groß und klein ist egal.
- **Zeitraum:** diese Woche, dieser Monat, dieses Jahr, die letzten 30 oder 365 Tage oder alle Fahrten.
- **Strecke:** unter 10 km, 10–25 km, 25–50 km oder über 50 km.
- **Bike:** erst ab zwei Bikes.

Darunter steht, wie viele Fahrten passen, zum Beispiel „2 von 40 Fahrten“. ✕ setzt alles zurück. Ein Tipp auf **Diese Woche**, **Dieser Monat** oder **Dieses Jahr** in der Übersicht öffnet die Fahrten dieses Zeitraums. Der Mac nutzt dieselben Regeln, beide finden also dieselben Fahrten.

## Die Aufnahme auf dem Sperrbildschirm
Während du aufnimmst, zeigt der **Sperrbildschirm** Zeit, Strecke und Tempo. Mit dem Knopf dort hältst du die Fahrt an und setzt sie fort. Auf iPhones mit **Dynamic Island** steht die Strecke neben der Kamera; halte den Finger darauf für mehr. Zum Beenden öffne Wattspur: Dort gibst du der Fahrt einen Namen und speicherst sie.

## Widget „Diese Woche“
1. Halte den Finger auf eine freie Stelle des Home-Bildschirms.
2. Tippe auf **Bearbeiten › Widget hinzufügen** und wähle **Wattspur**.
3. Wähle die kleine oder die mittlere Größe.

Das Widget zeigt die Kilometer und Fahrten dieser Woche, mit einem Balken je Tag. Die mittlere Größe zeigt dazu deine letzte Fahrt. Die Zahlen sind dieselben wie in der Übersicht. Am Montag beginnt das Widget von selbst bei null.

## Kurzbefehle und Siri
Sag zum Beispiel:
- „Starte eine Fahrt mit Wattspur“
- „Fahrt beenden mit Wattspur“: Wattspur öffnet **Fahrt speichern**, wie bei Stopp.
- „Wie viele Kilometer diese Woche in Wattspur“
- „Öffne meine letzte Fahrt in Wattspur“

Du findest die vier auch als Aktionen in der App **Kurzbefehle**, zum Beispiel für eine Automation, wenn sich das iPhone mit der Halterung verbindet.

## Motorrad
Beim Aufnehmen lässt Wattspur Punkte weg, die eine unmögliche Geschwindigkeit ergeben würden. So fallen GPS-Sprünge heraus. Beim E-Bike liegt die Grenze bei 100 km/h. Wer mit dem Motorrad aufnimmt, stellt **Mehr › Aufnahme › Fahrzeug › Motorrad** ein. Dann gilt eine Grenze von 300 km/h.

Damit Motorradfahrten nicht in die Summen deiner Fahrräder fallen, lege dafür im Profil ein Bike mit der Art **Motorrad** an (siehe [Profil und Bikes](07-profile-and-bikes.md)).

---
Weiter: [Fragen](06-faq.md) · [Inhalt](README.md)
