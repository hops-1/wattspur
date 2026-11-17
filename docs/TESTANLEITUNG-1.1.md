# Testanleitung iPhone 1.1 + Mac 1.9 „Sportarten, Teil 1: Geräte und Auto“

Für Nils, vor dem Release. Ergebnis je Punkt: ✓, oder ✗ mit kurzer Notiz oder Screenshot. Die Stories: B-284, B-310, B-287, B-299, B-290, B-286.

Die Tests gehen mit der echten Bibliothek. Nur Teil F (Sicherung zurückholen) machst du bitte mit einer Kopie: Mach vorher eine Sicherung.

## 0. Vorher (nur Nils)

1. **CloudKit-Schema, Development:** Starte am Mac den Debug-Build einmal mit `-WattspurInitCloudKitSchema YES` (Xcode › Scheme › Arguments). Danach steht `CD_sportRawValue` am Typ `CD_Ride` im **Development**-Schema (CloudKit Console).
2. **CloudKit-Schema, Production:** In der CloudKit Console **Deploy Schema Changes…** nach Production. TestFlight und die notarisierte Mac-App nutzen Production. Ohne diesen Schritt kommt eine Fahrt mit Auto oder Motorrad *ohne Gerät* nicht über iCloud auf das andere Gerät.
3. **Builds:** Am iPhone **1.1 (27)** aus TestFlight, am Mac **1.9** aus dem DMG (`dist/Wattspur-1.9-…dmg`). Beide Geräte brauchen die neuen Versionen: Ältere lesen ein Auto als Fahrrad.

## A. Geräte am Mac (B-284)

1. **Profil › Bike hinzufügen**, Art **Auto**, Name z. B. „Nugget“, mit Foto, Kilometerstand, Hersteller und Modell. Erwartet: Bei **Auto** verschwinden der Schalter **E-Bike**, Antrieb und Akku. Das Symbol ist ein Auto.
2. Ein zweites Auto oder ein Motorrad anlegen. Beide stehen im Profil.
3. Eine alte Autofahrt (9./10.11.) in der Liste auf **Nugget** legen. Erwartet:
   - Sie steht weiter in der Liste und auf der Karte.
   - Summen, Auswertung, Highlights, Rekorde, Ziele und CO₂ zählen sie **nicht**.
   - Mit dem Filter auf **Nugget** zeigt die Auswertung nur ihre Werte.
4. Tour-Detail dieser Fahrt: Bei **CO₂ gespart** steht „Nicht beim Auto“.

## B. Querbeschleunigung (B-287)

Mit der Fahrt aus A.3:

1. **Mac, Tour-Detail:**
   - Statt „Max. Schräglage“ stehen **Max. Querbeschl. links / rechts** in g. Die 21° vom 10.11. sind jetzt etwa **0,38 g**.
   - Das Diagramm heißt **Querbeschleunigung**, mit der Achse in g.
   - Die Karte ist in Stufen von 0,1 g eingefärbt, die Legende sagt „0,0–0,1 g“ bis „0,4 g +“.
2. **iPhone, Tour-Detail:** dieselben Kacheln. Das Karussell hat die Seite **Querbeschleunigung**. Das Menü der Karte heißt **Querbeschleunigung**, die Legende zeigt g.
3. Eine Motorradfahrt bleibt bei **Schräglage** in Grad.
4. **0–100 km/h** steht bei der Autofahrt, wenn sie aus dem Stand auf 100 kam.

## C. Neue Autofahrt am iPhone (B-286, B-287)

1. **Übersicht:** Unter **Fahrt starten** steht klein „mit … ▾“. Tippen öffnet **Womit fährst du?** mit deinen Bikes, Fahrzeugen und darunter **Auto** und **Motorrad** ohne Gerät.
2. **Nugget** wählen. Die Aufnahme startet sofort. Erwartet:
   - Unter Tempo und Höhe steht ein Balken **Querbeschleunigung**, der in Kurven nach links oder rechts ausschlägt.
   - Die Live-Aktivität auf dem Sperrbildschirm zeigt ein **Auto**-Symbol.
3. **Gedrehtes iPhone:** Auf gerader Strecke das iPhone in der Halterung einmal drehen (hoch und quer). Danach im Tour-Detail: An dieser Stelle **keine** Spitze der Querbeschleunigung. Kurven zeigen weiter ihren Wert. Wenn eine Kurve fehlt oder das Drehen doch zählt: Stelle und Uhrzeit notieren.
4. **Sichern:** Das Gerät ist schon **Nugget**. Sichern. Erwartet:
   - Die Fahrt hat das Auto-Symbol.
   - Sie zählt nicht in **Diese Woche** (Übersicht und Widget).
   - Am Mac kommt sie über iCloud mit **Nugget**.
5. Nächster Start mit einem Tipp auf **Fahrt starten** (ohne „mit … ▾“): Er nimmt wieder **Nugget**.
6. Einmal **Auto ohne Gerät** wählen, kurz fahren, sichern. Beim Sichern steht „Auto, ohne Gerät“. Erwartet:
   - Die Fahrt hat **kein** Bike.
   - Sie zählt nicht zum Rad, auch nicht am Mac.
   - Sie zeigt die Querbeschleunigung.
7. Danach wieder ein Rad wählen und kurz mit dem Rad fahren. Erwartet: kein Balken; die Fahrt zählt zum Rad.
8. **Mehr** hat keine Seite **Aufnahme** mehr.

## D. Siri und Kurzbefehle (B-286)

1. „Starte eine Fahrt mit Nugget in Wattspur“ → die Aufnahme startet mit dem Auto-Symbol.
2. „Starte eine Fahrt mit Wattspur“ → mit dem Gerät der letzten Aufnahme.
3. App **Kurzbefehle**: Die Aktion **Fahrt starten** hat ein Feld **Gerät** mit deinen Geräten und Auto/Motorrad ohne Gerät. In deiner CarPlay-Automation dort **Nugget** wählen und einmal im Auto probieren.

## E. Profil und Geräte am iPhone (B-299, B-290)

1. **Mehr › Profil:** Name, Foto und die Angaben für die Kalorien wie am Mac.
2. **Bearbeiten:** Gewicht ändern und sichern. Erwartet: Am Mac steht kurz darauf dasselbe Gewicht. Ein Gewicht von 7 kg wird nicht gespeichert.
3. Darunter die Kacheln **Rad** und **Fahrzeuge** mit Strecke, Fahrten, Fahrzeit, längster Fahrt und Höchsttempo. Die Autofahrten stehen nur bei **Fahrzeuge**. Die Rad-Summe ist gleich wie in der Übersicht und am Mac.
4. **Geräte:** Bikes und Fahrzeuge in Gruppen, mit Kilometern. Ein Tipp öffnet eins.
5. **Gerät hinzufügen › Motorrad**, Name „Test“. Sichern. Erwartet: Es steht im Profil, am Mac kommt es über iCloud.
6. „Test“ öffnen, **Bearbeiten**: Farbe und Kilometer vor Wattspur ändern, sichern. Dann **Archivieren**. Erwartet: Es steht als „Archiviert“, am Mac ebenso. Danach am Mac löschen oder archiviert lassen.

## F. Sicherung (B-310)

1. **Sichern:** Am Mac **Ablage › Mediathek-Backup › Sichern …**. Erwartet: Das Backup enthält das Auto **Nugget** mit seinen Fahrten (z. B. „Testfahrt Auto“ vom 17.11.) und das Motorrad „Test“ aus E.5. Sag Claude, wo das Backup liegt: Claude prüft eine Kopie davon, ohne deine Bibliothek anzufassen. Die Fahrt ohne Gerät aus C.6 kommt erst mit dem späteren Test dazu.
2. **Zurückholen:** Ein altes Backup von vor 1.9 (z. B. vom 12.11.) **auf einer Kopie** zurückholen. Erwartet: Es geht ohne Fehler, die Fahrten sind Rad, Motorrad-Bikes bleiben Motorrad.
3. **GPX:** Eine Autofahrt (z. B. „Testfahrt Auto“) als GPX exportieren (Mac) oder teilen (iPhone). Die Datei mit TextEdit öffnen und nach `<type>` suchen. Erwartet: `<type>driving</type>`, nicht `cycling`. (komoot fragt beim Import selbst nach der Sportart und legt eine geplante Tour an, darum taugt es für diesen Test nicht.)

## Ergebnis

Hier eintragen oder an Claude schicken. Ein ✗ wird ein eigener Backlog-Punkt. B-287 wird ☑, wenn B.1–B.2 und C.3 passen.

| Teil | Ergebnis | Datum, Notiz |
|---|---|---|
| 0 | ✓ | 16.11.2026: Schema in Production; Mac 1.9 (773), iPhone 1.1 (27) in TestFlight |
| A | ✓ | 16.11.2026, Mac 1.9 (773) |
| B.1 | ✓ | 16.11.2026, Mac |
| B.2–B.4 | offen | iPhone 1.1 erst nach Nils' Video für Apple |
| C.1–C.3 | ✓ / ✗ | 17.11.2026, zwei Fahrten „Testfahrt Auto“: Werte folgen dem GPS, Drehen an der Ampel ohne falschen Ausschlag (nur im Stand gedreht); ✗ bei 85 km/h zu hoch → B-319; ✗ Kachel und Karte → B-320; „Ohne Gerät“ → B-321 |
| C.4–D | offen | |
| E | ✓ | 17.11.2026, iPhone 1.1 (27): Profil, Gewicht, Kacheln, Geräte, Motorrad „Test“ anlegen, bearbeiten, archivieren; jeweils über iCloud am Mac angekommen |
| F.1 | ✓ | 17.11.2026, Backup 22:04 von Mac 1.9 (773): 96 Fahrten, Nugget (Auto) mit beiden „Testfahrt Auto“, „Test Motorrad“ archiviert, Profil; von Claude auf einer Kopie geprüft |
| F.2 | ✓ | 17.11.2026, Mac 1.9 (773): Backup vom 12.11. ohne Fehler zurückgeholt (auf der echten Bibliothek, nicht auf einer Kopie), danach Backup 22:04 ebenso ohne Fehler zurück |
| F.3 | ✓ | 17.11.2026, Mac 1.9 (773): „Testfahrt Auto“ als GPX mit `<type>driving</type>` und `wattspur:bike` (Nugget); Beschreibung noch „Bike: Nugget“, ab Mac 1.9.1 „Fahrzeug: Nugget“ (B-321) |
| B-319–B-321 | umgesetzt, offen | iPhone 1.1.1 und Mac 1.9.1: Auto-Querbeschleunigung bei 85 km/h, Kachel, „Fahrzeugart“ mit Fahrrad, „Fahrzeug“ statt „Bike“ am Mac |

**Vorsicht beim Mac-Test:** Öffne Wattspur aus **Programme** und prüfe unter **Über Wattspur** die Version. Am 16.11. öffnete macOS stattdessen einen alten Debug-Build (1.1.0). Er setzte die Bibliothek auf seinen alten Stand zurück. Dadurch fehlten Bikes, Fotos und Profil, und iCloud gab das an das iPhone weiter. Zurückgeholt aus der Sicherung vom 11.11.

---

## Text für TestFlight › „Was testen“ (Build 1.1 (27))

> Neu in 1.1: Geräte und Auto.
>
> • Unter „Fahrt starten“ wählst du mit „mit … ▾“, womit du fährst: ein Bike, ein Fahrzeug, oder Auto bzw. Motorrad ohne Gerät. Ein Tipp nimmt das Gerät der letzten Fahrt.
> • Im Auto zeigt die Aufnahme die Querbeschleunigung als Balken, das Tour-Detail statt der Schräglage die Querbeschleunigung in g, auch für alte Autofahrten.
> • Fahrten mit Auto oder Motorrad zählen nicht zu den Rad-Summen und zum CO₂.
> • Mehr › Profil: Angaben für die Kalorien am iPhone bearbeiten, Summen je Sportart, Geräte anlegen und bearbeiten.
> • Siri: „Starte eine Fahrt mit ‹Gerät› in Wattspur“.
>
> Bitte prüfen: eine Autofahrt mit dem iPhone in der Halterung, und einmal das iPhone dort drehen – das darf keine Kurve ergeben. Mac und iPhone brauchen beide die neue Version (Mac 1.9).
