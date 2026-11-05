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
1. **Motorrad (Tester):** Fahrzeug „Motorrad“, Schalter an, iPhone fest in der Halterung, BMW Motorrad Connected läuft mit. 30–60 Minuten mit Kurven links und rechts, einmal zügig aus dem Stand beschleunigen, einmal kräftig bremsen. Wenn möglich ein Stück mit dem iPhone in der Jackentasche (Uhrzeit merken). Danach: Bildschirmfoto der BMW-Auswertung (größte Schräglage links und rechts).
2. **E-Bike (Nils):** Fahrzeug „E-Bike“, iPhone am Lenker, gern ein Stück Kopfsteinpflaster oder Schotter.
3. Die Dateien per AirDrop an den Mac, in einen Ordner **außerhalb** des Projekts. Persönliche Fahrten kommen nie ins Repository.

## Auswertung (geplant)
- **Schräglage:** Drehrate um die Senkrechte = Drehrate projiziert auf die Schwerkraft; tan(Schräglage) = v · ω / g mit v vom GPS. Vergleich mit BMW Motorrad Connected.
- **Längs und quer:** Ableitung des GPS-Tempos, verglichen mit der Beschleunigung längs des Kurses; welche Glättung das Brummen des Motors entfernt.
- **Rütteln (B-248):** Stärke der Erschütterung nach Abzug von Kurven und Bremsen; lassen sich glatter Asphalt, Pflaster und Schotter trennen?
- Halterung gegen Tasche, Akku pro Stunde, läuft es bei gesperrtem Bildschirm ohne Lücken.

## Ergebnis
Noch offen – folgt nach den Testfahrten.
