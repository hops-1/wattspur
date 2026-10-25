# Kennzahlen: woher jeder Wert kommt

Wattspur zeigt zwei Arten von Werten:
- **Von Bosch:** die Summen, die dein Antrieb in die FIT-Datei geschrieben hat (die *session*). Wattspur übernimmt sie unverändert, sie stimmen also mit der Flow-App überein.
- **Von Wattspur berechnet:** Werte, die nicht in der Datei stehen. Schätzwerte sind mit ⓘ markiert.

## Werte aus der Bosch-Datei
| Wert | Bedeutung |
|---|---|
| Fahrzeit | Zeit in Bewegung, ohne Pausen |
| Gesamtdauer | Vom Start bis zum Ziel, mit Pausen |
| Strecke | Gesamtstrecke |
| Ø Geschw., Max. Geschw. | Durchschnitt in Bewegung, Höchstgeschwindigkeit |
| Ø Leistung, Max. Leistung | Deine eigene Tretleistung in Watt, ohne Motor. Bosch mittelt nur über die Sekunden, in denen du trittst; Rollen senkt den Durchschnitt nicht |
| Ø Trittfreq., Max. Trittfreq. | Kurbelumdrehungen pro Minute |
| Anstieg, Abstieg | Gefahrene Höhenmeter bergauf und bergab |

## Von Wattspur berechnete Werte
| Wert | Wie |
|---|---|
| Pausen | Gesamtdauer − Fahrzeit |
| Arbeit | Deine Tretleistung über die Fahrt aufsummiert: Σ Leistung × 1 s, in Kilojoule. Enthält die Datei eine Gesamtarbeit, wird diese verwendet. Weil Rollen hier mit 0 W zählt, im Bosch-Durchschnitt aber nicht, ist die Arbeit meist kleiner als Ø Leistung × Fahrzeit, bei Fahrten mit viel Rollen deutlich |
| Höhe min.–max. | Tiefster und höchster Punkt der Aufzeichnung |
| Kalorien ⓘ | Wie in der Flow-App: Arbeit (kJ) × 0,97 plus 64 kcal je Stunde Fahrzeit. Der Körper setzt etwa ein Viertel der verbrauchten Energie in Tretarbeit um; der Zeitanteil steht für alles, was er nebenbei verbraucht. Die Flow-App hat keine Körperdaten, der Anteil ist dort ein fester Wert. Sechs Fahrten mit dem Flow-Wert werden auf wenige kcal genau getroffen. Ein Modus „Mit Profil“ mit deinen Körperdaten ist für eine spätere Version vorbereitet |
| CO₂-Einsparung ⓘ | Strecke (km) × 0,159 kg: so viel hätte ein durchschnittliches Auto auf derselben Strecke ausgestoßen |

Die Faktoren für Kalorien und CO₂ sind Annahmen, geprüft an wenigen Fahrten. Sie können sich in späteren Versionen ändern; der Changelog sagt dann Bescheid.

## Werte aus einer GPX-Datei
Eine GPX-Datei hat Positionen, Höhe und Zeit, aber keine Summen. Wattspur berechnet sie aus dem Track und kennzeichnet die Fahrt mit **≈ Summen geschätzt**. Einzelheiten und Grenzen stehen unter [GPX-Dateien importieren](08-importing-gpx.md#was-wattspur-berechnet).
| Wert | Wie |
|---|---|
| Fahrzeit ≈ | Die Zeit in Bewegung: Lücken ab 30 s sind Pausen, eine Geschwindigkeit unter 0,8 m/s (über ±5 s) ist Stillstand |
| Strecke ≈ | Entlang des Tracks in Bewegung; GPS-Zittern im Stand zählt nichts |
| Ø Geschw. ≈, Max. Geschw. ≈ | Strecke ÷ Fahrzeit; das schnellste Stück von mindestens 5 s |
| Anstieg ≈, Abstieg ≈ | Aus der Höhe, geglättet mit einem Median über 5 Punkte; ein Anstieg zählt ab 3 m |
| Leistung, Trittfrequenz | Nur, wenn die Datei sie hat, sonst ein Strich. Die Arbeit ist die Summe der Leistung; ohne Leistung gibt es keine Arbeit |
| Kalorien | Brauchen Leistung (Arbeit); ohne sie ein Strich |
| CO₂-Einsparung ⓘ | Aus der Strecke, wie bei jeder Fahrt |

Summen über mehrere Fahrten nehmen die Fahrten, die einen Wert haben, und sagen, wie viele das sind („9 von 12 Fahrten“). Bosch-Werte ersetzen geschätzte, wenn du eine GPX-Fahrt aus der Bosch-FIT aktualisierst.

## Die Auswertung
| Wert | Wie |
|---|---|
| Summen | Über alle Fahrten im Zeitraum. Die Beispielfahrt zählt nur, wenn du sie in der Liste ausdrücklich auswählst |
| Durchschnitte (Tempo, Leistung, Trittfrequenz) | Gewichtet nach Fahrzeit: Eine zweistündige Fahrt zählt viermal so viel wie eine halbstündige. Das ergibt dasselbe, als wären alle Fahrten eine einzige lange Fahrt |
| Ø je Fahrt | Summe geteilt durch die Zahl der Fahrten |
| Veränderung (▲ / ▼ %) | Im Vergleich zum Zeitraum davor: der vorigen Woche, dem vorigen Monat oder Jahr, bei einem freien Zeitraum einem gleich langen Zeitraum davor. „Alles“ hat keinen Vergleich |
| Trends | Der Durchschnitt jeder Fahrt als Punkt, das Mittel der letzten fünf Fahrten als Linie |

## Fahrten vergleichen
| Wert | Wie |
|---|---|
| Kalorien pro km ⓘ, Arbeit pro km, Anstieg pro km | Der Wert geteilt durch die Strecke in km |
| Rollanteil | Anteil der Fahrzeit ohne Tretleistung: 1 − (Arbeit ÷ Ø Leistung) ÷ Fahrzeit. Bosch bildet die Ø Leistung nur über die Sekunden mit Tretleistung; Arbeit ÷ Ø Leistung ergibt also ihre Anzahl. Bei der Beispielfahrt sind das 19 %, höchstens einen Punkt neben dem Auszählen der Sekunden |
| Ø Leistung über die Fahrzeit | Arbeit ÷ Fahrzeit: wie der Bosch-Wert, aber Rollen zählt mit 0 W. Zeigt, wie viel du über die ganze Fahrt getreten hast |
| Steilste Stelle | Die stärkste Steigung über mindestens 100 m der Fahrt, aus der aufgezeichneten Höhe. Kürzere Stücke zählen nicht, weil die Höhe von Sekunde zu Sekunde um ein bis zwei Meter springt |
| Schnitt (Abweichung vom Schnitt) | Deine typische Fahrt: das Mittel je Fahrt über alle Fahrten, ohne Beispielfahrt und Papierkorb. Ø-Werte (Geschwindigkeit, Leistung, Trittfrequenz, Leistung über die Fahrzeit, Rollanteil) sind nach Fahrzeit gewichtet, Werte pro km nach Strecke |

## Highlights
| Wert | Wie |
|---|---|
| Rekorde | Aus den Bosch-Summen jeder Fahrt. Bei Gleichstand behält die frühere Fahrt den Rekord. Ø Geschwindigkeit und Ø Leistung zählen nur bei Fahrten ab 5 km, damit eine kurze Fahrt bergab keinen Rekord setzt |
| Längste Serie | Aufeinanderfolgende Kalendertage mit mindestens einer Fahrt, nach dem Ortsdatum am Start der Fahrt. Zwei Fahrten an einem Tag zählen als ein Tag; ein Tag ohne Fahrt beendet die Serie; ein einzelner Tag ist keine Serie |
| Jahr | Fahrten gehören zu Jahr und Monat ihres Ortsdatums am Start. Die Veränderung zum Vorjahr vergleicht die Strecke |
| Ziele | Die Summe der Fahrten, die im Zeitraum begonnen haben. Wochen laufen von Montag bis Sonntag. „Im Plan“ heißt: das Ziel ist mindestens so weit wie der verstrichene Anteil des Zeitraums |
| Zählt nicht | Die Beispielfahrt, Fahrten im Papierkorb und die Teile einer zusammengefügten Fahrt (die zusammengefügte Fahrt zählt als eine Fahrt) |

## Karte
| Wert | Wie |
|---|---|
| Fahrten auf der Karte | Wie in der Auswertung: ohne Beispielfahrt (außer markiert), ohne Papierkorb; eine zusammengefügte Fahrt ist eine Fahrt. Die Route ist auf 5 m genau vereinfacht |
| Kacheln unter der Karte | Ganze Fahrten, deren Route den sichtbaren Ausschnitt berührt, mit ihren Bosch-Summen; Ø Geschwindigkeit nach Fahrzeit gewichtet |
| Wärmekarte | Anzahl verschiedener Fahrten je Fläche von etwa 16 pt; jede Fahrt zählt je Fläche einmal. Feste Stufen 1, 2–4, 5–9, 10–19, 20+ |
| Neue Wege | Anteil der Strecke in 50-m-Feldern, durch die vorher noch keine deiner Fahrten lief. Abweichungen bis 10 m (GPS) zählen als bekannt; ein Weg 50 m daneben ist neu. Die km sind dieser Anteil der Bosch-Strecke. Hin und zurück auf einer neuen Straße zählt beides als neu |

## Rundung
Wattspur zeigt die Strecke auf 0,1 km und das Tempo auf 0,1 km/h genau, Leistung, Trittfrequenz und Höhenmeter als ganze Zahlen. Summen in der Auswertung werden aus den genauen Werten berechnet und erst am Ende gerundet. Sie können deshalb um 0,1 von einer Summe der gerundeten Werte abweichen.

---
Weiter: [Fragen und Fehlerbehebung](06-faq.md)
