# Spike V-16 – Bewegungssensoren

Stand: 5.11.2026 · Teil von iOS 0.5.1 + Mac 1.8.6 „Beschleunigung und Schräglage“ (siehe `BACKLOG.md`).

## Frage
Kann Wattspur aus den Sensoren des iPhones die Schräglage, das Beschleunigen und Bremsen und das Rütteln der Straße so gut bestimmen, dass es sich zeigen lohnt? Beim Motorrad und, als Versuch, beim E-Bike.

## Testversion
- Schalter „Rohdaten der Bewegung mitschreiben“ in „Mehr“, Bereich „Test“ (aus als Standard).
- Ist er an, schreibt jede Aufnahme zusätzlich eine CSV-Datei: `Bewegung JJJJ-MM-TT HH-MM-SS.csv` in den Dokumenten der App. Die Dateien-App zeigt sie unter „Auf meinem iPhone › Wattspur › Bewegung“.
- Inhalt (Spalten siehe `MotionRawLog` im Kit), die Zeit immer in Sekunden seit 1970:
  - `m`: 50-mal pro Sekunde `CMDeviceMotion` mit `xArbitraryCorrectedZVertical`: Lage als Quaternion, Schwerkraft und Beschleunigung (ohne Schwerkraft) in g, Drehrate in rad/s, alles im Bezug des iPhones.
  - `g`: jedes GPS-Update, auch in der Pause und auch die Punkte, die die Aufnahme verwirft: Ort, Höhe, Genauigkeit, Tempo in m/s, Kurs in Grad.
  - `b`: Akkustand (0 bis 1), jede Minute.
  - `e`: Start, Fahrzeug, Pause, Weiter, Stopp.
- Etwa 20 MB pro Stunde. Die Datei wird nicht synchronisiert und gehört nicht zur Fahrt.

## Testfahrten
1. **Motorrad (Tester, Anleitung in [TESTANLEITUNG-MOTORRAD.md](TESTANLEITUNG-MOTORRAD.md)):** Fahrzeug „Motorrad“, Schalter an, iPhone fest in der Halterung, BMW Motorrad Connected läuft mit. 30–60 Minuten mit Kurven links und rechts, einmal zügig aus dem Stand beschleunigen, einmal kräftig bremsen. Wenn möglich ein Stück mit dem iPhone in der Jackentasche (Uhrzeit merken). Danach: Bildschirmfoto der BMW-Auswertung (größte Schräglage links und rechts).
2. **E-Bike (Nils):** Fahrzeug „E-Bike“, iPhone am Lenker, gern ein Stück Kopfsteinpflaster oder Schotter.
3. Die Dateien per AirDrop an den Mac, in einen Ordner **außerhalb** des Projekts. Persönliche Fahrten kommen nie ins Repository.

## Auswertung (geplant)
- **Schräglage:** Drehrate um die Senkrechte = Drehrate projiziert auf die Schwerkraft; tan(Schräglage) = v · ω / g mit v vom GPS. Vergleich mit BMW Motorrad Connected.
- **Längs und quer:** Ableitung des GPS-Tempos, verglichen mit der Beschleunigung längs des Kurses; welche Glättung das Brummen des Motors entfernt.
- **Rütteln (B-248):** Stärke der Erschütterung nach Abzug von Kurven und Bremsen; lassen sich glatter Asphalt, Pflaster und Schotter trennen? Grenzen in `RideMotion.SurfaceBand`, Ergebnis unten.
- Halterung gegen Tasche, Akku pro Stunde, läuft es bei gesperrtem Bildschirm ohne Lücken.

## Ergebnis

### Rütteln auf dem E-Bike (Testfahrten vom 7.11.2026)

Zwei Fahrten von Nils mit dem E-Bike, iPhone in der Halterung am Lenker, quer und nach vorn geneigt: vormittags 37 km (Anstieg über den Teutoburger Wald mit Waldwegen, dann Straßen und Feldwege), nachmittags rund 50 km in drei Teilen (vor allem Straßen und Radwege). Die Rohdaten (50 Messungen pro Sekunde) sind vollständig, auch während der Pausen. Die Werte wurden je Sekunde mit derselben Rechnung wie `MotionFusion` neu berechnet und jede Sekunde dem nächsten Weg in OpenStreetMap zugeordnet (höchstens 12 m entfernt, kein anderer Belag ähnlich nah), rund 5 900 Sekunden vormittags und 6 000 nachmittags.

| Belag laut OpenStreetMap | Rütteln (Median) |
|---|---|
| Asphalt (Straße, Radweg) | 0,10–0,17 g |
| Wassergebundene Rad- und Fußwege (`compacted`) | 0,20–0,25 g |
| Pflaster (`paving_stones`) | 0,30 g |
| Forstwege am Teuto (`compacted`, `grade3`) und Erdwege (`ground`) | 0,63–0,76 g |

- **Grenzen:** eben unter **0,20 g**, uneben ab 0,20 g, rau ab **0,45 g**. Die alten Grenzen (0,10 / 0,25 g) trafen OpenStreetMap nur zu 26 %: auch normaler Asphalt galt als uneben.
- **Befestigt gegen unbefestigt** trennt das Rütteln gut (bei 0,36 g stimmen 95 % der Sekunden der Vormittagsfahrt).
- **Schotter gegen Gelände trennt es nicht:** OpenStreetMap nennt grobe Forstwege und glatte Radwege beide `compacted`. Die Klassen beschreiben darum, wie es sich fährt, nicht den Belag.
- Geprüft und verworfen: schnelles oder seitliches Rütteln statt des senkrechten, Rütteln im Verhältnis zum Tempo, längere Zeitfenster. Keines trennt besser. Die Frequenz liegt überall bei 13–15 Hz (Rahmen des Rads) und hilft nicht. Auf Asphalt hängt das Rütteln kaum vom Tempo ab.
- **Offen:** andere Räder und Reifen, iPhone in der Tasche, Motorrad.

Schräglage, Beschleunigung, Akku: noch offen.
