# Design: Sportarten – Rad, Fahrzeuge, Laufen

Stand: 10.11.2026 · Entwurf, abgestimmt mit Nils · Stories B-284 bis B-290 in `BACKLOG.md`

**Entwurf als Bild:** [Wattspur Sportarten](https://claude.ai/artifact/BkrDViNS6kxEBnzDn5W9bv). Er zeigt vier Mac-Fenster und sechs iPhone-Bildschirme. Am Mac und in der iPhone-Übersicht lässt sich der Umschalter anklicken.

## Warum

Nils hat zwei Fahrten im Ford Transit Nugget aufgenommen (9.11. und 10.11.2026). Die „Schräglage“ zeigte bis zu 21°. Das ist richtig gerechnet, aber im Auto ist der Wert die Querbeschleunigung (21° entsprechen 0,39 g). Der Wagen selbst neigte sich nur 3 bis 5°.

Daraus folgt: Wattspur soll mehr als Fahrräder kennen. Autos und Motorräder sind Fahrzeuge, Laufen kommt später dazu. Jede Sportart bekommt eigene Werte, Summen und Rekorde. Am Mac und am iPhone bekommt jede Sportart eine eigene Rubrik.

## Entscheidungen von Nils (10.11.2026)

- Am Mac kommt ein **Umschalter oben in der Seitenleiste**: Rad · Fahrzeuge · Laufen.
- **Laufschuhe werden wie Bikes geführt**, mit Kilometerstand je Paar.
- **Autos und Motorräder sind eigene Geräte.** Man kann mehrere anlegen, zum Beispiel „Nugget“ und „Zweitwagen“.
- **Fahrten mit Auto oder Motorrad zählen nicht** zu den Rad-Summen, Rad-Rekorden und zum CO₂.

## 1. Begriffe

| Sportart | Geräte (heute „Bikes“) |
|---|---|
| **Rad** | Fahrrad, Mountainbike, Rennrad, Gravel, Lastenrad, jeweils mit oder ohne Motor (E-Bike) |
| **Fahrzeuge** | Auto (neu), Motorrad |
| **Laufen** | Laufschuh (neu) |

Ein **Gerät** ist, was heute ein Bike ist: Es hat Name, Art, Farbe, Foto, Kilometerstand, Hersteller und Modell. Das Feld „E-Bike“ gibt es nur beim Rad.

## 2. Datenmodell (CloudKit: nur Ergänzungen)

- `BikeKind` bekommt die neuen Rohwerte `car` und `runningShoe`.
- Neu ist `BikeKind.sport` mit den Werten `.cycling`, `.vehicle` und `.running`. Aus `isMotorized` wird `sport == .vehicle`.
- `Ride` bekommt das neue optionale Feld `sportRawValue`. Es gilt für Fahrten **ohne Gerät**, also für den schnellen Start mit „Auto“ oder „Motorrad“.
- Die Sportart einer Fahrt ist: `bike?.kind.sport ?? sport ?? .cycling`.
- Die Tabelle `Bike` bleibt. Ein neuer Name ist im Code nicht nötig, in der App heißt sie „Geräte“.
- **Bekannte Grenze:** Ältere Versionen lesen `car` und `runningShoe` als Fahrrad. Solche Fahrten zählen dort zum Rad. Im Handbuch steht darum eine Mindestversion für alle Geräte.

## 3. Mac

**Umschalter.** Ein Segment-Feld oben in der Seitenleiste mit Symbol und Name: Rad, Fahrzeuge, Laufen.
- Er erscheint erst, wenn es Geräte oder Fahrten von mehr als einer Sportart gibt. Wer nur Rad fährt, sieht nichts Neues.
- Die Wahl bleibt beim nächsten Start erhalten.
- Bei schmaler Seitenleiste (nur Symbole) stehen die drei Symbole untereinander.

**Bereiche.** Fahrten, Analyse, Highlights und Karte zeigen nur die gewählte Sportart. Papierkorb und Profil gelten für alle.

**Kennzahlen und Begriffe je Sportart**

| | Rad | Fahrzeuge | Laufen |
|---|---|---|---|
| Liste heißt | Fahrten | Fahrten | Läufe |
| Filter | Alle Bikes | Alle Fahrzeuge | Alle Schuhe |
| Kacheln im Detail | Strecke, Fahrzeit, Ø Leistung, Trittfrequenz, CO₂ gespart | Strecke, Fahrzeit, Max. Tempo, Querbeschleunigung (Auto) bzw. Schräglage (Motorrad) links/rechts, 0 auf 100 km/h | Distanz, Zeit, Ø Pace, Schritte, Schrittfrequenz |
| Karte einfärben nach | Tempo, Höhe, Leistung … | Tempo, Höhe, Querbeschleunigung bzw. Schräglage, Belag | Pace, Höhe |
| Rekorde | wie heute | Max. Tempo, 0 auf 100 km/h, längste Fahrt | 5 km, 10 km, Halbmarathon, längster Lauf |
| CO₂ | ja | nein | nein |

**Profil.** Die Geräte stehen in drei Gruppen: Bikes, Fahrzeuge und Schuhe. Jede Gruppe hat eigene Summen und einen eigenen Knopf „+ Hinzufügen“.

## 4. iPhone

**Tabs.** Die vier Tabs bleiben: Übersicht, Fahrten, Karte, Mehr. Neue Tabs kommen nicht dazu.

**Umschalter.**
- Eine Kapsel oben links mit Symbol und Name, zum Beispiel „Rad ▾“. Sie sieht aus wie „Alle Zeiten“ auf der Karte.
- Sie ist ein Menü und kein Segment-Feld, damit sie auch auf schmalen iPhones passt.
- Sie steht in Übersicht, Fahrten und Karte. Die Wahl gilt für alle drei Tabs.
- Jedes Gerät merkt sich die Wahl selbst; sie wird nicht synchronisiert.
- Sie erscheint erst ab der zweiten Sportart.

**Übersicht.**

| | Rad | Fahrzeuge | Laufen |
|---|---|---|---|
| Kachel 1 | Diese Woche (km) | Diese Woche (km) | Diese Woche (km) |
| Kachel 2 | Dieser Monat (Fahrten) | Fahrzeit | Ø Pace |
| Karte | Letzte Fahrt | Letzte Fahrt | Letzter Lauf |
| Knopf | Fahrt starten | Fahrt starten | Lauf starten |

**Start der Aufnahme.**
- Ein Tipp auf den Knopf startet sofort mit dem zuletzt genutzten Gerät dieser Sportart.
- Darunter steht klein „mit Nugget ▾“. Ein Tipp darauf öffnet das Blatt „Womit fährst du?“. Dort stehen die Geräte in den Gruppen Bikes, Fahrzeuge und Schuhe, darunter „Ohne Gerät“ mit Auto und Motorrad für den schnellen Start.
- Die Wahl wird gemerkt und beim Sichern vorbelegt.
- Siri und Kurzbefehle bekommen den Parameter „mit Gerät“, zum Beispiel „Starte Fahrt mit Nugget“.

**Während der Aufnahme.**

| Sportart | Groß | Dazu |
|---|---|---|
| Rad | Tempo | wie heute |
| Motorrad | Tempo | Schräglage links/rechts |
| Auto | Tempo | Querbeschleunigung als Balken, 0,5 g links bis 0,5 g rechts |
| Laufen | Pace (min/km) | Distanz, Zeit, Schritte |

Live-Aktivität und Sperrbildschirm zeigen dieselben Werte.

**Fahrten, Detail, Karte.**
- Die Liste zeigt nur die gewählte Sportart, mit dem Symbol des Geräts.
- Das Karussell im Detail hat Seiten je Sportart:
  - Rad: Tempo, Höhe, Leistung, Puls;
  - Fahrzeuge: Tempo, Höhe, Querbeschleunigung bzw. Schräglage, Rütteln;
  - Laufen: Pace, Höhe, Schrittfrequenz, Puls.
- Die Karte aller Fahrten und die Wärmekarte zeigen nur die gewählte Sportart.

**Profil › Geräte (neu).** Die Geräte stehen im Profil am iPhone (B-299); „Mehr“ ist eine Liste mit Rubriken (B-298). Bikes, Fahrzeuge und Schuhe lassen sich auch am iPhone anlegen und bearbeiten, mit Name, Art, Farbe, Foto und Kilometerstand. Die Einstellung „E-Bike oder Motorrad“ fällt weg.

**Widget.** „Diese Woche“ zeigt das Rad. Beim Bearbeiten des Widgets kann man die Sportart wählen.

## 5. Was wohin zählt

- Jede Sportart hat eigene Summen, Kacheln, Rekorde und Highlights.
- Fahrzeuge und Laufen zählen **nie** zu den Rad-Summen, Rad-Rekorden oder zum CO₂. Das gilt auch für Fahrten ohne Gerät.
- Der Kilometerstand eines Geräts zählt nur seine eigenen Fahrten.

## 6. Messwerte

- **Querbeschleunigung (Auto):** Die App nutzt dieselbe Rechnung wie bei der Schräglage (`MotionFusion`: v · ω / g) und zeigt das Ergebnis in g statt als Winkel. Eine neue Aufnahme ist nicht nötig, alte Fahrten lassen sich umrechnen.
- **Gedrehtes iPhone:** Ändert sich die Richtung der Schwerkraft schnell, weil das iPhone in der Halterung gedreht wird, zählen die Werte nicht. Am 9.11. ergab so ein Moment 17° auf gerader Strecke. Das gilt für alle Sportarten.
- **Laufen:** Schritte und Schrittfrequenz kommen aus dem Schrittzähler (`CMPedometer`), die Pace aus dem GPS. Die Grenze für GPS-Sprünge liegt bei 30 km/h.

## 7. Offen für später

- Kalorien beim Laufen nach Gewicht und Puls;
- Läufe aus der Apple Watch übernehmen (B-230);
- eine Ansicht „Alle Sportarten“ am Mac, zum Beispiel für einen Jahresrückblick;
- weitere Sportarten wie Wandern oder Inliner. Das Modell lässt das zu.
