# Recherche: Bosch-Daten über das offizielle Portal (Data Act)

Planung der Version **1.9**, Entscheidungen in [REQUIREMENTS.md](REQUIREMENTS.md) Kap. 10.18, Stories im Abschnitt „v1.9“ von [BACKLOG.md](BACKLOG.md), Prüfaufgabe **V-12**.
Stand der Recherche: 25.10.2026. Es wurden keine Konten angelegt, keine Anmeldedaten eingegeben und nichts bei Bosch abgerufen; alle Aussagen stammen aus öffentlichen Seiten, aus App-Store-Beschreibungen und aus dem Quellcode bzw. den Beschreibungen von Community-Projekten. Bosch-Seiten wurden über einen Textabruf gelesen; PDF-Dokumente (Bedingungen, Anhang 1) ließen sich nicht abrufen. **Nachtrag 25.10.2026:** Nils hat EBikeData mit seinem eigenen Konto ausprobiert und Screenshots geliefert; sie sind im Abschnitt „Auswertung der EBikeData-Screenshots“ ausgewertet (die Bilder selbst liegen nicht im Repo).

**Kennzeichnung:** ✔ = auf einer offiziellen Bosch-Seite belegt · ◐ = nur von einem Community-Projekt oder der EBikeData-Beschreibung berichtet · ✘ = nicht belegt, Annahme.

## Kurzfassung

- **Entscheidung Nils (25.10.2026): Option B, 1.9 heißt „Bosch-Daten“** (Bike, Akku, Wartung, Zusatzfelder, Import von Fahrten ohne Datei).
- **Ergebnis nach den amtlichen Spezifikationen (Nils, 25.10.2026):** Die offizielle Data-Act-API liefert **keine Motordaten je Fahrt**: weder Unterstützungsmodi noch Energieanteil, Motorleistung oder Akkustand. Sie liefert Bike-, Akku- und Wartungsdaten, Zusammenfassungen und eine Spur (ohne Zeitstempel je Punkt) von Fahrten, die mit der Flow-App aufgezeichnet wurden. Einzelheiten im Abschnitt „Offizielle Spezifikation: Activity Records API“. **Die Aussagen weiter unten zu Modi und Energieanteil (◐) stammen aus Community-Beschreibungen der inoffiziellen API und gelten für die offizielle API nicht.**
- **Ein „Bosch eBike Developer Portal“ unter diesem Namen habe ich nicht gefunden.** Der offizielle Weg für Privatpersonen und kleine Apps ist das **Data-Act-Portal** ([portal.bosch-ebike.com/data-act](https://portal.bosch-ebike.com/data-act), „Partner Portal“) ✔. Die App EBikeData nennt es „Bosch eBike Portal“ und „offizielle Data-Act-API“ ◐. Für Unternehmen gibt es zusätzlich die „Connected Biking Plattform“ (Cloud API für die Flow-App mit einer **Activity Records API**) mit Kontaktaufnahme statt Selbstregistrierung ✔; sie ist für Wattspur nicht gemeint.
- **Der Zugang ist offiziell, kostenlos (keine Kosten genannt) und für Privatpersonen gedacht.** Ablauf ✔: mit SingleKey ID im Data-Act-Portal als **Datenempfänger** registrieren, die „Bedingungen für Datenempfänger“ annehmen, einen **Client** anlegen (Name, Login-URL, Empfänger-URL); danach die Daten im **Flow-Portal** („Datenfreigabe an sich selbst“) für diesen Client freigeben. Bosch schreibt ausdrücklich: Wer sich die Daten selbst freigeben will, muss sich zuerst als Datenempfänger registrieren.
- **Bosch muss den Client freigeben** ◐: Community-Berichte nennen „Stunden bis einige Tage“, ein Nutzer wartete rund acht Tage ohne E-Mail; bis dahin zeigt das Portal „Invalid request“. Die Freigabe jedes Bikes in der Flow-App bzw. im Flow-Portal ist zusätzlich nötig.
- **Nur EU, nur Smart System** ✔/◐: Die Data-Act-Informationen gelten ausdrücklich nur für Nutzer in der EU ✔; Konten außerhalb der EU liefern nichts ◐. Bikes mit Classic Line oder Active Line (ohne Smart System) werden von EBikeData nicht unterstützt ◐; die ältere Plattform „BES2“ liefert nur einen reduzierten Datensatz ◐.
- **Was pro Fahrt kommt** ◐: Zusammenfassung mit Strecke, Dauer, Ø/Max-Geschwindigkeit, Trittfrequenz, Fahrerleistung, Kalorien, Höhenmeter, **Aufteilung der Unterstützungsmodi in Metern**, **Anteil Fahrer- gegenüber Motorenergie**, CO₂, Brems-/ABS-Ereignisse; dazu eine GPS-Spur mit Strecke, Geschwindigkeit, Höhe, Trittfrequenz und Fahrerleistung, nach einer Beschreibung mit **nur etwa 500 Punkten je Fahrt** (zum Vergleich: FIT hat etwa 2 Datensätze je Sekunde).
- **Was nicht belegt ist:** **Motorleistung als Zeitreihe** und **Akkustand als Zeitreihe**. Nirgends als Feld genannt; ein Community-Projekt schreibt sogar, Bosch liefere keinen Ladestand und der Stand gelte nur zum Zeitpunkt der letzten Synchronisierung ◐. Auch EBikeData zeigt keine Motor- oder Akkukurve, sondern Höhe, Geschwindigkeit, Trittfrequenz und Fahrerleistung.
- **Was zusätzlich zu den Fahrten kommt** ◐: Bike-Profil mit Antrieb, Kilometerstand, Betriebsstunden, Akku (Ladezyklen, abgegebene Energie, Gesundheit), Komponenten mit Seriennummern, Servicehistorie. **Die echte Bike-Antwort (Nils) enthält davon keine Gesundheit, keine Kapazität und keine Servicehistorie** (nur ein leeres Feld „serviceDue“). **Durch Screenshots von Nils bestätigt** (Abschnitt „Auswertung der EBikeData-Screenshots“): Antrieb, Kilometerstand, Betriebsstunden gesamt und mit Motor, Ladezyklen am Bike und extern, abgegebene Energie, Akkukapazität, Komponenten, Modus-Kennungen. **Nicht bestätigt:** die Modus-Aufteilung je Fahrt und der Energieanteil (in EBikeData nicht vorhanden).
- **Echte Antworten (Nils, „API Abfrage“ in EBikeData):** Bike-Abfrage und Fahrtenliste sind belegt (Abschnitt „Echte Antworten der API“). Die **Fahrtenzusammenfassung enthält keine Modi und keinen Energieanteil**, nur Strecke, Zeiten mit Zeitzone, Kilometerstand, Geschwindigkeit, Trittfrequenz, Fahrerleistung, Anstieg, Kalorien, CO₂ und den Titel von Bosch. Ob ein Detail-Endpunkt mehr liefert, ist offen und entscheidet über 1.9.
- **Live Data Interface (Bluetooth, PDF von Bosch, V1.0 vom 01.05.2026):** nur während der Fahrt, an ein mitlaufendes Zubehör, mit Akkustand in Prozent, Fahrerleistung, Geschwindigkeit und Trittfrequenz, **ohne Motorleistung und ohne Unterstützungsstufe**; ein Smartphone ist laut Bosch **nicht im Umfang**. Kein Weg für 1.9.
- **Offene Hauptrisiken:** (1) Die **Bedingungen für Datenempfänger** konnte ich nicht lesen. Sie entscheiden über Weitergabe der App an Freunde, App Store, Speicherung. (2) Welche **Redirect-URI** für eine Mac-App erlaubt ist, ist unbekannt. (3) Ob die **offizielle** API wirklich die Modus-Aufteilung und eine Spur liefert, ist nur aus Community-Beschreibungen abgeleitet, die zum Teil die inoffizielle App-API beschreiben.

**Empfehlung:** Version 1.9 bleibt im Plan, aber **zuerst ein Spike (V-12)** mit Nils' eigener Registrierung. Erst danach werden Umfang und Größen der Stories festgezurrt. Wattspur bleibt ohne Konto voll nutzbar; der Abruf ist optional, und **jeder Nutzer legt seinen eigenen Client an**. Details siehe [Empfehlung](#empfehlung).

## Einordnung zur früheren Entscheidung (Kap. 9, V-03)

[RECHERCHE-ALTBESTAND.md](RECHERCHE-ALTBESTAND.md) bewertete drei Wege: die **inoffizielle** App-API (Option B, im zweiten Review gestrichen), die **Data-Act-API** (Option C, „sauberster Weg, aber der aufwendigste“) und die DSGVO-Auskunft (Option D). Die Streichung betraf Option B. Option C ist genau das, was hier betrachtet wird; ihr Umfang war damals „öffentlich nicht dokumentiert“. Das ist es weiterhin nicht (Anhang 1 und die Bedingungen blieben unlesbar), aber es gibt jetzt eine fertige Drittanbieter-App (EBikeData) und mehrere offene Projekte, die den Weg belegen.

Vorschlag, den Nils am 25.10.2026 angenommen hat: Kap. 9 streicht nur den **inoffiziellen** Weg ausdrücklich weiter; die Data-Act-API kommt in den Umfang (10.18). V-03 bleibt erledigt, mit Verweis auf 1.9.

## Der offizielle Weg im Einzelnen

### Registrierung und Rollen ✔
- **Data-Act-Portal** ([portal.bosch-ebike.com/data-act](https://portal.bosch-ebike.com/data-act)): Anmeldung mit SingleKey ID (Nutzer der älteren eBike-Connect-Welt haben einen eigenen Login), Annahme der „Bedingungen für Datenempfänger“, dann Anlage von „Client-Anwendungen“ mit Name, Login-URL und Empfänger-URL.
- **Flow-Portal** ([flow.bosch-ebike.com/data-act](https://flow.bosch-ebike.com/data-act)): Der Fahrer gibt seine Daten für einen registrierten Datenempfänger frei, auch für sich selbst.
- Rechtsgrundlage: EU Data Act (Verordnung (EU) 2023/2854), Bosch-Seite [bosch-ebike.com/en/data-act](https://www.bosch-ebike.com/en/data-act). Dort verlinkt Bosch die Dokumente „Terms of Use für Datenzugang und Datennutzung für Datenempfänger“ und einen „User Guide: Retrieving Your eBike Data“ (beide nicht abrufbar) sowie den **Anhang 1** (Datentypen, geschätzter Umfang, Erfassungshäufigkeit, Speicherdauer, Geschäftsgeheimnisse). Die Inhalte stehen nicht auf der Seite.
- **Kosten:** keine genannt ✔ (nicht ausgeschlossen). EBikeData ist kostenlos ◐; die Registrierung wird dort „kostenlos“ genannt.

### Client und Anmeldung ◐ (aus Community-Projekten)
- Die API-Anmeldung ist **OAuth 2.0 (Authorization Code)** über Bosch Identity & Access Management (**amtlich** in der Spezifikation, siehe „Offizielle Spezifikation“); PKCE für öffentliche Clients berichten Community-Projekte ◐ (in der Spezifikation nicht erwähnt). Scope `offline_access` für die Token-Erneuerung; Sitzungen laufen laut einem Projekt bis zu 30 Tage ◐, **laut Spezifikation läuft ein Offline-Token nie ab, solange er mindestens alle 180 Tage zum Erneuern benutzt wird ✔** ([clementdevos/bosch-ebike-smartsystem-stats](https://github.com/clementdevos/bosch-ebike-smartsystem-stats)).
- Die Client-ID hat die Form `euda-…`; „Confidential client“ wird **ausgeschaltet** angelegt, also ein öffentlicher Client ohne Secret ([Xunil99/ha-bosch-ebike](https://github.com/Xunil99/ha-bosch-ebike)). Ein Nutzer löste „Invalid request“, indem er den Client ohne diesen Haken neu anlegte ([Home-Assistant-Forum](https://community.home-assistant.io/t/new-integration-bosch-ebike-smart-system-data-act-api-track-your-rides-in-home-assistant/995410)).
- **Redirect-URI:** Die Projekte tragen eigene Adressen ein: `https://my.home-assistant.io/redirect/oauth`, `https://localhost:8080/callback`, `http://localhost:4200`. Die Adresse muss im Portal exakt stimmen, sonst „Invalid parameter: redirect_uri“. Ob eine **benutzerdefinierte Schema-Adresse** (`wattspur://…`) oder ein Loopback mit freiem Port erlaubt ist, ist ✘ offen. **Nachtrag (Portal, Reiter „Client application“ in Nils' Konto, ✔ gesehen): Der Client von EBikeData trägt ein benutzerdefiniertes Schema als Redirect-URI und als Login-URL (Muster `app-name://callback`).** Ein eigenes Schema wird vom Portal also **akzeptiert**; ob jedes Schema oder nur dieses Muster erlaubt ist und ob Loopback-Adressen gehen, bleibt ✘. Das Formular nennt: Name der Client-Anwendung (wird dem Fahrer bei der Zustimmung gezeigt), Login-URL, Redirect-URI(s) und den Schalter „Confidential client“; nach dem Anlegen erscheint die Client-ID (`euda-…`).
- **Freigabe des Clients durch Bosch:** Stunden bis Tage, in einem Fall rund acht ◐. **Freigabe je Bike:** ohne sie liefert die API 403; die Freigabe braucht einige Minuten ◐.
- Die Basis-Adresse der API ist `api.bosch-ebike.com`; Pfade wie `/activity/smart-system/v1/activities` und `…/activities/{id}/details` nennt [bosch-flow-mcp](https://github.com/partymola/bosch-flow-mcp) (aus [RECHERCHE-ALTBESTAND.md](RECHERCHE-ALTBESTAND.md)); eine offizielle Spezifikation habe ich nicht gefunden ✘.
- **Ratenbegrenzung:** in der Doku der Fahrten und Bikes nirgends dokumentiert ✘; **im Digital Service Book API belegt** (`429`, im Beispiel 100 Anfragen je 60 s, siehe unten). Die Home-Assistant-Integration fragt alle 10 bis 30 Minuten ab, ein anderes Projekt drosselt Detailabrufe über eine Parallelitätsgrenze.

### Daten ◐
| Daten | Quelle | Anmerkung |
|---|---|---|
| Fahrten-Zusammenfassung: Strecke, Dauer, Ø/Max-Geschwindigkeit, Ø/Max Trittfrequenz, Ø/Max Fahrerleistung, Kalorien, Anstieg/Abstieg, Titel, Datum, Start-Kilometerstand | HA-Integration, bosch-flow-mcp, EBikeData | entspricht im Kern dem FIT-Export |
| **Aufteilung der Unterstützungsmodi** (Meter je Modus), **Anteil Fahrer- vs. Motorenergie**, CO₂, Brems- und ABS-Ereignisse | bosch-flow-mcp, Stats-Projekt („assist level breakdown“) | neu gegenüber dem FIT-Export; ob die **offizielle** API sie liefert, ist im Spike zu prüfen |
| GPS-Spur mit Strecke, Geschwindigkeit, Höhe, Trittfrequenz, Fahrerleistung | bosch-flow-mcp („ca. 500 Punkte pro Fahrt“), EBikeData | gröber als FIT; „nicht alle Fahrten enthalten eine Spur“; bei BES2 nur Summen |
| Herzfrequenz | HA-Integration (optional), bosch-flow-mcp („fehlt meist“) | EBikeData holt sie aus Apple Health |
| Bike-Profil: Antrieb, Kilometerstand, Betriebsstunden, Komponenten mit Seriennummern, Servicehistorie | EBikeData, HA-Integration | |
| Akku: Ladezyklen, abgegebene Energie (Lebensdauer), Gesundheit | EBikeData, bosch-flow-mcp | **Ladestand nur zum Zeitpunkt der letzten Synchronisierung**; Verlauf nur durch eigenes Mitschreiben |
| Reichweite je Modus | EBikeData („Unterstützungsmodi inklusive Reichweitenschätzung“), HA-Integration | Schätzung, keine Messung |
| Motorleistung als Zeitreihe, Akkustand als Zeitreihe, Unterstützungsstufe pro Sekunde | – | ✘ nirgends belegt |

Eine Fahrt erscheint erst, wenn die Flow-App sie hochgeladen hat ◐. Die **Live Data Interface** ([Bosch](https://www.bosch-ebike.com/en/business/live-data-interface), kostenlos, per Bluetooth am Rad) nennt Geschwindigkeit, Akku-Ladestand, Fahrerleistung, Trittfrequenz; sie ist Echtzeit, also **kein** Weg für nachträgliche Auswertung am Mac ✔ (Einzelheiten im Abschnitt „Live Data Interface“ weiter unten, nach dem PDF von Bosch).

## So macht es EBikeData

[EBikeData](https://apps.apple.com/us/app/ebikedata/id6760475380) (Volker Hauffe, iOS/iPadOS 17.6+, macOS 14.6+ auf Apple Silicon, kostenlos, Version 1.1.3 vom 17. Juni) ◐ aus der App-Store-Beschreibung:
- „Visualisiert die Daten über die **offizielle Data-Act-API**“; kostenlose Registrierung im Bosch eBike Portal, **die App führt durch den Prozess**; zusätzlich Freigabe im Flow-Portal. Nur Smart-System-Bikes.
- Zeigt Karte (nach Geschwindigkeit eingefärbt), Höhenprofil, Geschwindigkeit, Trittfrequenz und Leistung, Wetter, Statistik und Rekorde, Fahrrad-Profil mit Antrieb, Betriebszeit, Modi mit Reichweitenschätzung, Akkugesundheit (Ladezyklen, abgegebene Energie), Komponenten und Wartungsplan; Fotos über die Aufnahmezeit; Puls aus Apple Health.
- Datenschutz: „Daten bleiben zwischen dir und den Bosch-Servern, kein Backend eines Dritten, keine Konten, kein Tracking“; App-Store-Angabe „keine Daten erfasst“ (von Apple nicht geprüft).
- Ob jeder Nutzer einen **eigenen Client** anlegt oder die App einen gemeinsamen nutzt, geht aus der Beschreibung nicht eindeutig hervor ✘; „Registrierung im Bosch eBike Portal, die App führt dich durch“ und die Freigabe „für diese App“ sprechen für einen eigenen Client je Nutzer (Schluss, nicht belegt).
- Wichtig für den Plan: EBikeData ist im App Store veröffentlicht. Die Data-Act-API verbietet eine veröffentlichte Drittanbieter-App also nicht grundsätzlich ◐.

Eine Motor- oder Akkukurve zeigt auch EBikeData nicht; aus der offiziellen API belegt sind Bike-, Akku-, Antriebs- und Wartungsdaten sowie Zusammenfassung und Spur der Fahrten; **Unterstützungsmodi je Fahrt und Energieanteil des Motors kommen dort nicht vor** (Spezifikation). Die Screenshots von Nils (nächster Abschnitt) bestätigen den Bike- und Akkuteil, aber nicht die Modus-Aufteilung je Fahrt.

## Auswertung der EBikeData-Screenshots (Nils, 25.10.2026)

Nils hat EBikeData mit seinem eigenen Bosch-Konto ausprobiert und sechs Screenshots geliefert (Reiter Dashboard, Touren, Tour-Detail, Statistiken und zweimal Bike). Sie liegen **nicht im Repo**: Es sind fremde Oberflächen (NFR-12) und sie zeigen Seriennummern, die hier nicht festgehalten werden. Ein Screenshot zeigt nur, **was die App anzeigt**, nicht, was Bosch liefert. Deshalb steht in der Spalte „Herkunft“, was nach dem Bild und der App-Beschreibung am wahrscheinlichsten ist.

**Kennzeichnung hier:** ◆ = in einer **echten Antwort** gesehen (Nils, „API Abfrage“ in EBikeData, siehe unten) · ▣ = im Screenshot zu sehen und fast sicher aus der API (sonst nicht zu berechnen) · ◐ = zu sehen, Herkunft offen (API oder Berechnung der App) · ✘ = im Screenshot nicht zu sehen.

### Je Bike (Reiter „Bike“ und Dashboard)
| Feld in der App | Beispielwert | Herkunft | Nutzen für Wattspur |
|---|---|---|---|
| Antrieb: Modell | „Performance Line CX“ | ▣ | Name des Antriebs je Bike |
| Kilometerstand | 2294,2 km | ▣ | Gesamtstand des Antriebs; bei Bikes ohne Fahrten in Wattspur ein Abgleich mit der Summe der Fahrten |
| Betriebsstunden gesamt und „davon mit Motor“ | 396 h, davon 64 h | ▣ | neu: Motorlaufzeit; im FIT-Export nicht enthalten |
| Max. Unterstützung (Geschwindigkeit) und Schiebehilfe | 27,4 km/h, 4 km/h | ▣ | Einstellungen des Antriebs; Feld `maximumAssistanceSpeed` ◆: bis zu dieser Geschwindigkeit unterstützt der Motor (Abregelgrenze), Einheit ✘ nicht genannt (km/h nach Anzeige) |
| Seriennummer Antrieb | – | ▣ | **nicht übernehmen** (Datenschutz); Bike-Kennung der API reicht für die Zuordnung (MOT-05) |
| Akku: Modell und Kapazität | „PowerTube 800“, 800 Wh | ◐ | das Modell steht in der Antwort, **die Kapazität nicht** (◆); die App liest sie vermutlich aus dem Modellnamen oder lässt sie eintragen |
| Ladezyklen gesamt, „am Bike“ und „extern“ geladen | 22,8 (21,9 und 0,8) | ▣ | neu: Akkunutzung, Ladezyklen als Dezimalzahl (Teilzyklen) |
| Gelieferte Energie (Lebensdauer) | 17 012 Wh | ▣ | neu: Energie, die der Akku abgegeben hat; mit Kapazität ergibt sich die Zahl der Vollzyklen |
| Seriennummer Akku | – | ▣ | **nicht übernehmen** |
| Komponenten | Fernbedienung „Purion 200“ | ◆ | in der Antwort nur Fernbedienung (`remoteControl`), Antrieb und Akkus; Display, Ladegerät u. a. sind hier nicht aufgeführt (bei diesem Bike) |
| „Kalkulierte Reichweite“ je Modus | 47, 34, 36, 28 km | ◆ | **kommt von Bosch** (`reachableRange` je Modus in der Antwort); Einheit und Rechenweg ✘ nicht genannt |
| Namen der Modi | Codes wie „A100ECOP38“, „A100GAAAF0“, „A100G0AUTO“, „A100MSPIC8“, dazu „Aus“ | ▣ | **Wichtig:** Die App zeigt **Codes statt Klartext**; zwei enthalten erkennbar „ECO“ und „AUTO“. Die Antwort enthält nur diese Kennungen (Feld `name`, ◆), keinen Anzeigenamen; Wattspur müsste sie auf Anzeigenamen abbilden. Bosch-Namen nur beschreibend (NFR-09). Die Abbildung ist im Spike zu klären |
| „Akkuverbrauchs-Korrektur“ (Regler, Faktor) | +0 % | App | Die App rechnet den Akkuverbrauch **selbst** und gleicht ihn per Faktor an die Anzeige am Bike an. Das spricht dafür, dass die API **keinen** fertigen Verbrauch in Prozent je Fahrt liefert. Wattspur übernimmt das nicht |

### Je Fahrt (Dashboard, Touren, Tour-Detail, Statistiken)
| Feld in der App | Beispielwert | Herkunft | Nutzen für Wattspur |
|---|---|---|---|
| Liste: Titel, Datum und Uhrzeit, Strecke, Dauer, Ø-Geschwindigkeit | z. B. 13,0 km, 33 min, 23,4 km/h | ▣ | deckt sich mit dem FIT-Export |
| Titel „Fahrt A bis B“ oder „Ort Rundfahrt“ | – | ◆ | **Titel kommt von Bosch** (`title` in der Fahrt). Der Titel ist in der App umbenennbar (Stift) |
| Zeitraum „14:12 – 15:08“ neben Dauer „48 min“ | – | ◆ | Start und Ende (56 min) gegen **Fahrzeit** (48 min): Bosch liefert `startTime`, `endTime` und `durationWithoutStops` getrennt; die „Dauer“ der App ist die Fahrzeit ohne Stopps |
| Höhenmeter | 166 m | ▣ | wie im FIT-Export |
| Max-Geschwindigkeit | 54,5 km/h | ▣ | wie im FIT-Export |
| Ø-Trittfrequenz | 60 rpm | ▣ | wie im FIT-Export |
| Ø-Leistung | 135 W | ◆ | **Fahrerleistung** (`riderPower.average`); Motorleistung ist damit **nicht** gemeint (✘ unbelegt) |
| Kalorien | 360 kcal | ◆ | `caloriesBurned` **von Bosch**; Wattspur rechnet selbst (B-067), ein Vergleich wäre möglich |
| Temperatur, Wetter, Wind | 11 °C, bewölkt, 11 km/h | ◐ | **sehr wahrscheinlich Wetterdienst der App**, nicht Bosch (die Zeitreihe „Wind“ im Geschwindigkeitsdiagramm genauso). Nicht übernehmen |
| Karte mit Spur | blau (erstes Bild), grün–gelb–rot (Dashboard, Tour-Detail im Nachtrag) | ▣ | Spur aus der API (grob). Farbe **nach Geschwindigkeit** auf dem Abschnitt (Nils, Nachtrag); die Schwellen lassen sich nicht ablesen. Eine Einfärbung nach **Modus** gibt es nicht |
| Diagramme Höhe, Geschwindigkeit, Trittfrequenz, Leistung über die Strecke | etwa 100 bis 400 Punkte je Diagramm | ▣ | bestätigt die **Spur der API als Zeitreihe** mit Höhe, Geschwindigkeit, Trittfrequenz und Fahrerleistung (grob, über km, nicht 1 Hz). Nichts davon ist neu gegenüber FIT |
| Unterstützungsmodus je Fahrt (Meter je Modus) | – | ✘ | **in EBikeData nicht vorhanden** (Nils, Nachtrag: unter „Leistung“ kommt nichts mehr; Tour-Detail, Dashboard und Statistik zeigen keinen Modus-Anteil). Das heißt nicht, dass die API ihn nicht liefert, nur dass die App ihn nicht nutzt |
| Energieanteil Fahrer gegen Motor | – | ✘ | in EBikeData nicht vorhanden (gleiche Einschränkung) |
| Motorleistung und Akkustand als Zeitreihe | – | ✘ | **nicht vorhanden**, auch nicht als Diagramm |
| Fahrt nachfahren („Abspielen“ oben rechts an der Karte) | Vollbildkarte mit 2D, 3D, Satellit, Marker, Schieberegler (7:43 von 45:23), Anzeige von Zeit, Geschwindigkeit, Strecke, Höhe | App | reine Darstellung der Spur auf Apple Karten; kein Bosch-Feld. Kein Teil von 1.9, als **IDEA-31 / P-31** nach 1.9 in den Ideen-Pool aufgenommen |
| Fotos zur Fahrt | Hinweis „Fotozugriff nicht erlaubt“ unter den Diagrammen | App | Fotos aus der Mediathek über die Aufnahmezeit (laut Beschreibung); nicht von Bosch |
| Statistiken (Touren, Gesamt-km, Höhenmeter, Rekorde, Wochen und Monate) | 130 Touren, 2220 km, 21 618 m | App | von der App aus den Fahrten gerechnet; Wattspur hat das schon (ADV) |
| Rekord „Höchste Ø-Leistung“ | 181 W | App | aus der Fahrerleistung gerechnet |
| Eintrag „API Debug“ (Entwicklerbereich) | „Zeigt rohe API-Antworten und erkennt automatisch neue Datenfelder von Bosch“ | ▣ | Hinweis, dass Bosch **Felder nachträglich ergänzt**. Das stützt das Vorgehen aus 10.18: Original der Antwort unverändert archivieren und neu auswerten (NFR-17) |
| „Abmelden“ | – | ▣ | entspricht MOT-12 |

### Was sich daraus ergibt
1. **Bike und Akku sind bestätigt** (Antrieb, Kilometerstand, Betriebsstunden gesamt und mit Motor, Ladezyklen am Bike und extern, abgegebene Energie, Kapazität, Komponenten). Das ist sicherer als der Rest und gibt B-156 und MOT-09 eine Grundlage; sie werden um **Betriebsstunden „mit Motor“**, **Ladezyklen am Bike und extern** und die **Akkukapazität** erweitert.
2. **Die Modus-Aufteilung je Fahrt und der Energieanteil bleiben unbestätigt.** EBikeData zeigt sie nicht (von Nils nach dem Scrollen im Tour-Detail bestätigt), also belegt auch die App sie nicht; die einzigen Hinweise bleiben die Community-Beschreibungen der **inoffiziellen** API (bosch-flow-mcp, Stats-Projekt) ◐. Das ist der Kern des Plans (MOT-07, MOT-08, B-154, B-155). **V-12 muss diese Felder zuerst prüfen**; ohne sie schrumpft 1.9 auf Bike- und Akkudaten (MOT-09), und es ist zu entscheiden, ob das noch ein eigenes Release trägt.
3. **Modus-Codes statt Namen:** Wattspur braucht, falls die API Kennungen liefert, eine eigene Abbildung auf Anzeigenamen und einen Rückfall („Modus A100…“) für unbekannte Codes.
4. **Keine Zeitreihe für Motor oder Akku** in EBikeData; die Diagramme sind Höhe, Geschwindigkeit, Trittfrequenz, Fahrerleistung. B-157 (MOT-10) bleibt bedingt, mit geringer Erwartung.
5. **Nicht übernehmen:** Wetter, Temperatur, Wind, Kalorien, Akkuverbrauchs-Korrektur und Statistiken stammen aus der App; Seriennummern gehören nicht ins Repo und nicht in Exporte (NFR-12, NFR-20).
6. **Verlauf (Altbestand):** EBikeData zeigt 130 Touren mit einer Statistik ab Januar 2026 und einem Rekord vom 2. Mai 2026. Fahrten sind also **mindestens 10 Monate rückwirkend** abrufbar ◐. **Aber:** Das Bike wurde laut Antwort am 15.01.2026 angelegt (`createdAt` ◆); der Beginn im Januar kann also schlicht der Anlagezeitpunkt sein. Ob Bosch **vor** dem Anlegen oder vor dem Start des Data Act Fahrten hält, ist ✘ offen (V-12; älteste Fahrt). Die 12-Monats-Summe (2220 km) liegt unter dem Kilometerstand des Antriebs (2294 km); Fahrten ohne Spur oder ältere Fahrten erklären den Unterschied vermutlich.
7. **Spike-Liste (V-12) wird um diese Felder ergänzt:** der Detail-Abruf einer Fahrt (Spur, Modi, Energieanteil), Modus-Kennungen und ihre Namen, größtes `limit` und Ratenbegrenzung, `startOdometer` gegen die FIT-Datei, `serviceDue` bei einem Bike mit fälliger Wartung. Erledigt durch die echten Antworten: Titel (Bosch), Fahrzeit gegen Dauer, Kapazität und Gesundheit (nicht in der Antwort), „Max. Unterstützung“, Komponentenliste.

## Echte Antworten der API (Nils, EBikeData „API Abfrage“, 25.10.2026)

In EBikeData gibt es im Entwicklerbereich die Ansicht „API Abfrage“ mit den rohen Antworten. Nils hat zwei davon eingefügt (Kategorie „Bike“ und Kategorie „Touren“, jeweils Status 200); die dritte Kategorie „Letzte Tour (Details)“ lieferte **dieselbe Antwort wie „Touren“** (gleiche Fahrt, gleiche Felder, keine Spur, keine Modi), also keinen Detail-Endpunkt. Das sind die **ersten echten Antworten** in dieser Recherche; alles davor stammt aus Beschreibungen und Bildern. Mit ◆ ist gekennzeichnet, was **in einer echten Antwort steht**. Einschränkung: Es ist die Anzeige der App, ob sie die Antwort unverändert zeigt, ist ✘ nicht belegt (der Text sieht nach unverändertem JSON von Bosch aus). Seriennummern, Kennungen und genaue Zeitpunkte aus den Antworten werden **nicht** ins Repo übernommen (NFR-12, NFR-20); die Werte unten sind gerundet oder erfunden.

### 1. Bike
Aufbau: `{ "bikes": [ … ] }`, je Bike ein Objekt. Der Pfad dieser Abfrage steht nicht in der Einfügung ✘.

| Feld | Typ und Einheit | Bedeutung und Nutzen |
|---|---|---|
| `id` | UUID | Kennung des Bikes; dieselbe steht als `bikeId` in den Fahrten ◆ → damit ist die Zuordnung API-Bike ↔ Wattspur-Bike (MOT-05) eindeutig, einmal je Bike |
| `createdAt` | Zeitpunkt (UTC) | ✔ laut Spezifikation: „Datum, an dem die Cloud-API die ersten Bike-Daten aus der Flow-App erhielt“; **vor diesem Tag gibt es in der API vermutlich keine Fahrten** |
| `language`, `oemModelId` | Text, Zahl | Sprache des Kontos; Kennung des Modells beim Hersteller (Bedeutung ✘) |
| `batteries[]` | **Liste** | mehrere Akkus je Bike möglich (Dual Battery), das Modell von Wattspur muss eine Liste tragen |
| `batteries[].chargeCycles` | `onBike`, `offBike`, `total`, Dezimalzahl | Ladezyklen am Bike und extern, als Teilzyklen |
| `batteries[].deliveredWhOverLifetime` | Wh | abgegebene Energie über die Lebensdauer |
| `batteries[].productName`, `partNumber`, `serialNumber` | Text | Modell („PowerTube 800“); **Seriennummer nicht übernehmen**; **keine Kapazität, keine Gesundheit, kein Ladestand** |
| `driveUnit.productName`, `partNumber`, `serialNumber` | Text | Antrieb („Performance Line CX“); Seriennummer nicht übernehmen |
| `driveUnit.odometer` | **Meter** (2 294 220 = 2294,2 km) | Kilometerstand des Antriebs |
| `driveUnit.powerOnTime` | `total`, `withMotorSupport`, **Stunden** ✔ | Betriebszeit gesamt und mit Motorunterstützung |
| `driveUnit.maximumAssistanceSpeed` | Zahl (27,4), **km/h** ✔ | Geschwindigkeit, bis zu der unterstützt wird (Abregelgrenze) |
| `driveUnit.rearWheelCircumferenceUser` | Zahl (≈ 2 362), **mm** ✔ | vom Nutzer eingestellter Radumfang; wirkt auf die Geschwindigkeit |
| `driveUnit.walkAssistConfiguration` | `isEnabled`, `maximumSpeed` | Schiebehilfe an/aus und Höchstgeschwindigkeit |
| `driveUnit.activeAssistModes[]` | `name` (Text), `reachableRange` (Zahl) | aktive Modi mit der von Bosch gelieferten Reichweite je Modus. **Die echte Antwort weicht von der Spezifikation ab:** Spezifikation ✔ nennt genau 4 Modi („Eco, Tour, eMTB, Turbo“ im Beispiel) und die Reichweite in **Metern** (Beispiel 60 000); die echte Antwort hat 5 Einträge („0“ = Aus plus vier Codes wie `A100ECOP38`) und Werte um 30 bis 50, die EBikeData als **Kilometer** zeigt. Einheit und Namen **nicht verlassen**: Anzeigenamen kommen nicht von der API |
| `remoteControl` | Modell, Teilenummer, Seriennummer | Bedieneinheit („Purion 200“) |
| `serviceDue` | Objekt mit `date` (UTC) und `odometer` (Meter) ✔ | fällige Wartung nach Datum und Kilometerstand; bei diesem Bike leer. Nutzbar für Wattspurs Wartungsidee (IDEA-02) |

**Fehlt in der echten Antwort von Nils, steht aber in der Spezifikation (optional):** `oemId`, `antiLockBrakeSystems[]` (ABS), `connectModule`, `headUnit` (Display, z. B. „Kiox 300“); diese Komponenten hat das Bike von Nils nicht. **Fehlt auch in der Spezifikation der Bike-Antwort:** Akkukapazität, Akkugesundheit, Ladestand, Firmware, Servicehistorie, Name des Bikes (Kapazität, Gesundheit, Updates und Wartungshistorie stehen teilweise im **Digital Service Book**, siehe unten). Die Kapazität („800 Wh“) kommt in EBikeData also aus dem Modellnamen oder von Hand.

### 2. Touren (Zusammenfassungen)
Pfad ◆: `GET https://api.bosch-ebike.com/activity/smart-system/v1/activities?limit=…&offset=…`. Die Antwort kommt **seitenweise** mit `pagination` (`limit`, `offset`, `total`) und `links` (`first`, `last`, `next`, `self`). Gesehen wurde nur `limit=1`; das größte erlaubte `limit` ist ✘ offen. Neueste Fahrt zuerst (`offset=0` ist die letzte Fahrt), `total` = 130 entspricht den 130 Touren der App.

| Feld | Typ und Einheit | Bedeutung und Nutzen |
|---|---|---|
| `id`, `bikeId` | UUID | Kennung der Fahrt und des Bikes |
| `title` | Text („Fahrt A bis B“) | **Titel kommt von Bosch**, nicht von der App; Vorschlag für den Namen einer Fahrt ohne eigenen Namen |
| `startTime`, `endTime` | UTC, mit „Z“ | Start und Ende; Ende minus Start ist die **Gesamtdauer** |
| `timeZone` | IANA-Name („Europe/Berlin“) | **Zeitzone ist mitgeliefert**: Start 16:22 UTC wird als 18:22 Ortszeit angezeigt ◆. Das nimmt dem Abgleich mit der FIT-Fahrt (MOT-05) das Raten |
| `durationWithoutStops` | Sekunden (2 004 = 33 min) | Fahrzeit ohne Stopps; das ist die „Dauer“ der App, Start bis Ende ist länger (34,5 min) |
| `distance` | **Meter** (13 003) | Strecke |
| `startOdometer` | Meter | Kilometerstand des Antriebs zu Beginn; Start plus Strecke ergibt bei der letzten Fahrt den Kilometerstand des Bikes bis auf 4 m ◆ → eine **Kette der Kilometerstände**, die sich zum Abgleichen eignet (Prüfung gegen die FIT-Datei im Spike) |
| `speed` | `average`, `maximum`, km/h | wie im FIT-Export |
| `cadence`, `riderPower` | `average`, `maximum` (rpm, W) | **Fahrerleistung**, nicht Motorleistung ◆ |
| `elevation` | `gain`, `loss` (m) | Anstieg und Abstieg |
| `caloriesBurned` | Zahl (kcal) | Kalorien **von Bosch** (nicht von der App berechnet) |
| `co2Emissions` | `produced`, `carEquivalent` | Gramm vermutlich (✘ Einheit nicht genannt): erzeugt gegen Auto-Äquivalent |
| `tricks` | `jumps`, `manuals`, `stoppies`, `wheelies` mit Zählern | Funktionen für Mountainbikes, hier alle 0; für Wattspur ohne Nutzen |

**Fehlt in der Zusammenfassung:** Unterstützungsmodi je Fahrt, Energieanteil von Fahrer und Motor, Brems- und ABS-Ereignisse, GPS-Spur, Zeitreihen, Wetter, Akkustand. Wetter, Temperatur und Wind in EBikeData stammen also tatsächlich von der App.

### Was sich daraus ergibt
1. **Der Pfad der Fahrten ist bestätigt** (`/activity/smart-system/v1/activities`); er stimmte mit der Angabe von bosch-flow-mcp überein.
2. **Die Zusammenfassung bringt gegenüber dem FIT-Export fast nichts:** Neu sind der Titel von Bosch, `startOdometer`, CO₂ und Kalorien von Bosch. **Den Mehrwert von 1.9 müsste ein Detail-Endpunkt liefern** (Modi je Fahrt, Energieanteil, Spur), dessen Antwort bisher niemand gesehen hat ✘. Die Kategorie „Letzte Tour (Details)“ der App zeigt nur dieselbe Zusammenfassung; die Karte und die Diagramme der App brauchen aber eine Spur, die also über einen weiteren Abruf kommt, der in „API Abfrage“ nicht auftaucht (✘). Ohne diese Antwort bleibt die Modus-Aufteilung unbelegt; sie gehört an den Anfang von V-12 (Pfad vermutlich `…/activities/{id}/details`, nach bosch-flow-mcp ◐).
3. **Die Zuordnung wird einfacher:** `timeZone` ist mitgeliefert, `bikeId` ist eine UUID, und `startOdometer` taugt als zusätzliches Merkmal, falls die FIT-Datei einen Kilometerstand trägt (✘ im Spike prüfen). Gruppenfahrten sind damit trotzdem nicht ausgeschlossen.
4. **Einheiten:** Meter und Sekunden, nicht Kilometer und Minuten (`distance`, `odometer`, `startOdometer`, `durationWithoutStops`); für Leistung, Trittfrequenz und Geschwindigkeit gelten die üblichen Einheiten. Der Parser prüft sie mit Tests an aufgezeichneten Antworten (B-148).
5. **Bike-Daten in Wattspur:** MOT-09 und B-156 streichen **Gesundheit** und **Kapazität** als Felder der API; die Kapazität kommt aus dem Modellnamen oder von Hand (Pflege durch den Nutzer). Dazu Radumfang, Modi mit Reichweite, fällige Wartung (`serviceDue`) und die Komponenten (Antrieb, Akkus, Bedieneinheit, Display, ABS, ConnectModule) ohne Seriennummern.
6. **Altbestand:** `total` und die Seiten erlauben, alle Fahrten eines Kontos durchzugehen; Ratenbegrenzung und größtes `limit` ✘ offen. `createdAt` ist laut Spezifikation der Tag, an dem die Cloud erstmals Daten des Bikes aus der Flow-App bekam; **ältere Fahrten sind in der API nicht zu erwarten** (✔ aus der Spezifikation geschlossen, Prüfung an einem älteren Bike im Spike).

## Offizielle Spezifikation: eBike Profile API (Smart System) v1.4.0 (Nils, Export aus dem Portal, 25.10.2026)

Nils hat im Portal unter „API documentation“ die **eBike Profile API (Smart System)** als OpenAPI-Datei exportiert (3.0.4, Version 1.4.0; als Text eingefügt und als YAML-Datei geliefert). Die beiden Fassungen sind **inhaltlich gleich** (Version, Pfade, Felder, Beispiele, Bereiche und Fehler stimmen in den Stichproben überein); die YAML-Datei wiederholt nur Server und Sicherheitsangaben bei jedem Pfad und ordnet die Abschnitte anders. Das ist die erste **amtliche** Spezifikation in dieser Recherche (✔; gekennzeichnet mit „Spezifikation“). Die Dateien liegen bei Nils in den Downloads, nicht im Repo (Urheberrecht von Bosch; hier nur Sachverhalte).

### Umfang ✔
- **Basis:** `https://api.bosch-ebike.com/bike-profile/smart-system/v1`. Zwei Abrufe, beide `GET`: **`/bikes`** (alle Bikes des Nutzers) und **`/bikes/{bikeId}`** (ein Bike). Mehr enthält diese Spezifikation nicht: keine Fahrten, keine Spur, keine Modus-Aufteilung.
- **Bereich (Scope):** `bike-profile:bikes:read` (nur lesen), optional `offline_access`.
- **Anmeldung:** OAuth 2.0 Authorization Code über **Bosch Identity & Access Management**, Adressen `p9.authz.bosch.com/auth/realms/obc/protocol/openid-connect/{auth,token}`; die Erneuerung läuft über dieselbe Token-Adresse. Ein **Offline-Token** läuft nie ab, solange er mindestens alle **180 Tage** zum Erneuern benutzt wird; die App muss ihn sicher aufbewahren (Schlüsselbund, NFR-20). PKCE, Client-Typ und Redirect stehen **nicht** in der Spezifikation ✘.
- **Zwischenspeicher:** `/bikes/{bikeId}` kennt `ETag` und `If-None-Match`; unverändert gibt es `304 Not Modified`. Das spart Abrufe und passt zu „Knopf plus Abruf nach dem Import“ (B-152).
- **Fehler:** `application/problem+json` nach RFC 7807 mit `type`, `title`, `status`, `detail`, **`requestId`**: `400` (ungültige Kennung), `401` (`no-authentication-provided`, `jwt-expired`, `malformed-jwt`, `unknown-issuer`), `403` (`access-denied`, `insufficient-privileges` = Bereich fehlt), `404` (Bike nicht gefunden). „Wegen verteilter Architektur können Antworten **ohne** das Problem-Schema kommen“ (5xx). Ratenbegrenzung (`429`) steht hier nicht ✘.
- **Test:** Im Portal steht ein **Mock-Server** (Stoplight, ohne Zugangsdaten); er liefert nur die Beispiele der Spezifikation. Er ist für Tests des Kits denkbar (B-148), aber **nicht repräsentativ**, siehe unten. Aufgerufen habe ich ihn nicht.

### Felder und Einheiten ✔ (Spezifikation)
| Feld | Einheit und Hinweise |
|---|---|
| `id` (UUID), `createdAt`, `language`, `oemId` (max. 30 Zeichen), `oemModelId` (max. 200) | `createdAt`: Tag, an dem die Cloud erstmals Bike-Daten aus der Flow-App erhielt |
| `serviceDue` | `date` (UTC) und `odometer` (Meter): Wartung fällig |
| `driveUnit.odometer` | **Meter** |
| `driveUnit.rearWheelCircumferenceUser` | **mm** |
| `driveUnit.maximumAssistanceSpeed`, `walkAssistConfiguration.maximumSpeed` | **km/h** |
| `driveUnit.powerOnTime` | **Stunden** (`total`, `withMotorSupport`, ganze Zahlen) |
| `driveUnit.activeAssistModes[]` | `name` (max. 20 Zeichen) und `reachableRange`; **genau 4 Einträge**, vom schwächsten zum stärksten Modus; Reichweite in **Metern** |
| `batteries[]` | `deliveredWhOverLifetime` (Wh, ganze Zahl), `chargeCycles.total/onBike/offBike` (volle Zyklen, Dezimalzahl); **keine Kapazität, keine Gesundheit** |
| `remoteControl`, `headUnit`, `connectModule`, `antiLockBrakeSystems[]` | je Modell, Teilenummer, Seriennummer (25 Zeichen) |
| Pflichtfelder | `id`, `createdAt`, `driveUnit`, `remoteControl`, `batteries`; alles andere **optional** |

### Abweichungen zwischen Spezifikation und echter Antwort (Nils)
1. **Modi:** Die Spezifikation nennt 4 Einträge mit Namen („Eco“, „Tour“, „eMTB“, „Turbo“); die echte Antwort hat **5 Einträge** (der erste „0“) und **Codes** wie `A100ECOP38`.
2. **Reichweite:** Spezifikation **Meter** (Beispiel 60 000), echte Antwort **47 bis 28**, in EBikeData als **Kilometer** angezeigt.
3. **Der Mock-Server und die Beispiele der Spezifikation stimmen also nicht mit der Wirklichkeit überein.** Ein Parser nach der Spezifikation würde falsche Einheiten und eine falsche Zahl an Modi annehmen. Konsequenz: **Tests für B-148 nur mit echten, anonymisierten Antworten aus V-12**; Parser tolerant bei Anzahl und Namen der Modi; Einheit der Reichweite im Spike klären (Kilometer oder Meter).

### Was sich daraus ergibt
1. **Die Spezifikation bestätigt den Bike-Teil von MOT-09** und liefert die Einheiten. Neu in den Plan: **fällige Wartung** (`serviceDue`), Display, ABS und ConnectModule als Komponenten (soweit vorhanden), `oemId`.
2. **Für 1.9 fehlt der entscheidende Teil weiter:** die **Activity Records API** (Fahrten). Im Menü des Portals stehen dazu mehrere Schnittstellen („Activity Records API“, „Digital Service Book API“, „Bike Pass API“, „eBike Registration API“ und weitere, auch für Händler und Partner). **Welche davon ein privater Datenempfänger nutzen darf, ist ✘ offen**; die Liste sieht nach dem ganzen Katalog der Cloud-API von Bosch aus (mit COBI und Diagnose), nicht nach einer Auswahl für Privatpersonen.
3. **Die Datenlage im Portal hat einen Namen:** Das Verzeichnis heißt „cloud-api-euda-specs“; „EUDA“ steht vermutlich für EU Data Act.
4. **Token-Laufzeit:** Der Offline-Token verfällt nach 180 Tagen ohne Erneuerung; Wattspur erneuert bei jedem Abruf und zeigt andernfalls „Neu anmelden“ (MOT-11).
5. **Fehlerbehandlung:** `requestId` in das Import-Protokoll schreiben (hilft bei Bosch-Anfragen); `403` nach `insufficient-privileges` und `access-denied` trennen; `401` mit `jwt-expired` einmal erneuern.

## Offizielle Spezifikation: Activity Records API (Smart System) v1.4.0 und Textseiten des Portals (Nils, 25.10.2026)

Nils hat auch die **Activity Records API** als YAML exportiert (OpenAPI 3.0.4, Version 1.4.0) und die Textseiten **Authentication, Pagination, Error responses und FAQ** eingefügt. Damit liegt die gesamte Doku vor, die ein privater Datenempfänger für Fahrten und Bikes braucht (✔ amtlich). Die Dateien liegen bei Nils, nicht im Repo; hier stehen nur Sachverhalte.

### Umfang ✔
Die API „erlaubt Fahrern, vergangene Aktivitäten abzufragen, die mit der **eBike-Flow-App** aufgezeichnet wurden“, und liefert eine Zusammenfassung sowie Details. Basis `https://api.bosch-ebike.com/activity/smart-system/v1`, **zwei Abrufe, beide `GET`**:
- **`/activities`** (Bereich `activity:summaries:read`): Zusammenfassungen. Parameter `offset` (ab 0), `limit` (**1 bis 100, Standard 20**) und `sort` (`startTime`, `title`, `distance`, `durationWithoutStops`; Standard `-startTime`, ein `-` davor sortiert absteigend). Antwort mit `pagination` (`total`, `offset`, `limit`), `activitySummaries[]` und `links` (`self`, `first`, `prev`, `next`, `last`).
- **`/activities/{activityId}/details`** (Bereich `activity:details:read`): ein Feld `activityDetails[]` mit den Punkten der Fahrt; Fehler `400`, `401`, `403`, `404`, `500`.

### Zusammenfassung einer Fahrt ✔ (Einheiten laut Spezifikation)
| Feld | Einheit und Hinweise |
|---|---|
| `id`, `bikeId` | UUID; `bikeId` ist die `id` aus der Bike-Antwort |
| `startTime`, `endTime` | UTC |
| `timeZone` | IANA-Name **der Startposition** |
| `durationWithoutStops` | Sekunden, „Dauer in Bewegung“ |
| `title` | optional |
| `startOdometer`, `distance` | Meter; `distance` ist die Differenz des Kilometerstands |
| `speed`, `cadence`, `riderPower` | `average` und `maximum` (km/h, rpm, W); **Fahrerleistung** |
| `elevation` | `gain`, `loss` in m, „nur mit Mobile verfügbar“ (die Höhe kommt vom Smartphone) |
| `caloriesBurned` | optional, Zahl |
| `co2Emissions` | optional, `produced` und `carEquivalent` in **Gramm** |
| `heartRate` | optional, `average` und `maximum` in bpm |
| `tricks` | Sprünge, Wheelies, Manuals, Stoppies mit Zählern und Höchstwerten (Mountainbike), für Wattspur ohne Nutzen |

Pflichtfelder: `id`, `startTime`, `endTime`, `timeZone`, `durationWithoutStops`, `bikeId`, `startOdometer`, `speed`, `distance`, `cadence`, `riderPower`, `elevation`.

### Detail einer Fahrt ✔
Je Punkt: `distance` (Meter ab Start), `altitude` (m über Meer, WGS84), `speed` (km/h), `cadence` (rpm), `latitude`, `longitude` (WGS84), `riderPower` (W) und optional `heartRate` (bpm). **Es gibt keinen Zeitstempel je Punkt.** Die Zahl der Punkte nennt die Spezifikation nicht (Community: etwa 500 ◐); das Beispiel enthält Punkte, die sich um wenige Meter unterscheiden.

### Was die offizielle API **nicht** enthält ✔ (Spezifikation und Textseiten)
**Keine Unterstützungsmodi je Fahrt, kein Energieanteil von Fahrer und Motor, keine Motorleistung, keinen Akkustand oder -verbrauch, keine Brems- oder ABS-Ereignisse, kein Wetter, keinen Zeitstempel je Punkt.** Die Community-Hinweise darauf (bosch-flow-mcp, Stats-Projekt, „assist level breakdown“, „Fahrer- gegen Motorenergie“) stammen aus der **inoffiziellen** App-API, nicht aus dieser. Auch die Menüs im Portal zeigen dafür keine Schnittstelle für Privatpersonen (die übrigen Einträge sind Händler-, Diagnose- und Partner-APIs ✘ nicht gelesen).

### Textseiten des Portals ✔
- **Anmeldung:** Nur der **Authorization Code Grant** ist unterstützt (kein PKCE-Hinweis ✘). Endpunkte `…/auth` und `…/token` (Erneuerung auch dort). Den Bereich weist Bosch dem Client automatisch zu; **nur `offline_access` kann man selbst anfordern** (ein Token, der nie verfällt, solange er mindestens alle 180 Tage erneuert wird). Für „eBike System 2“ ist `kc_idp_hint=ebike-connect` nötig, **für Smart System nicht**.
- **Zustimmung widerrufen:** Der Datenempfänger löscht seine Token, oder der Fahrer widerruft bei Bosch; dann funktionieren alle Refresh-Token nicht mehr. Die App muss das **ruhig** abfangen und zum erneuten Anmelden führen (MOT-11).
- **Identität:** Zwei Ebenen, SingleKey ID und **eBike Rider ID**. Der übliche Claim `sub` gilt **nicht**; maßgeblich sind `bosch-id` und, für Smart System, **`ebike-rider-id`**. Ein Token wird auch ausgestellt, wenn der Nutzer sich bei Bosch eBike Systems nie angemeldet hat; fehlt `ebike-rider-id`, ist er nicht angemeldet. **Die App prüft den Claim** und sagt das klar (kein „Fehler“).
- **Zustimmung je Bike:** Der Fahrer muss im **Bosch eBike Manager** (Flow-Portal) die Weitergabe **je Bike** erlauben.
- **Seiten:** `limit` und `offset`; die Antwort liefert fertige `links`, die **verwendet werden sollen**, statt URLs selbst zu bauen.
- **Fehler:** `application/problem+json` (RFC 7807) mit `requestId`; die Spezifikation nennt bei `401` und `403` zusätzlich `text/plain` („JWT is expired“, „JWT verification fails“, „RBAC: access denied“), der Parser muss beides können.
- **FAQ:** Nur `GET` (alles ist **nur lesend**), Domain `api.bosch-ebike.com`, **TLS 1.2 oder höher**, Version nur als Hauptversion in der URL (`/v1`), Aufbau `/<api-name>/<ebike-system>/<version>/<resource>`. Hilfe nur über die Seite zum Data Act. **Eine Ratenbegrenzung steht in diesen beiden Spezifikationen und auf den Textseiten nicht** ✘; das Digital Service Book API nennt sie (`429`, Beispiel 100 Anfragen je 60 s).

### Was sich daraus ergibt
1. **Der Kern von Version 1.9 entfällt: „Motordaten einer Strecke“ gibt die offizielle API nicht her.** Es gibt keine Modi, keinen Energieanteil, keine Motorleistung und keinen Akkustand je Fahrt, auch nicht als Zeitreihe (kein Zeitstempel). Damit entfallen **MOT-07, MOT-08, MOT-10** und die Stories **B-154, B-155, B-157**. Das war die Frage des Spikes V-12 an erster Stelle; die Spezifikation beantwortet sie **negativ**.
2. **Was die API liefert und Wattspur bisher nicht hat:** (a) **Bike-, Akku- und Wartungsdaten** (Ladezyklen am Bike und extern, abgegebene Energie, Betriebsstunden mit Motor, fällige Wartung, Komponenten; MOT-09, B-156); (b) **Zusatzfelder je Fahrt**: Titel von Bosch, Kilometerstand zu Beginn (`startOdometer`), Kalorien und CO₂ von Bosch, Puls (Mittel, Maximum); (c) **Fahrten ohne Datei**, vor allem der **Altbestand**: Zusammenfassung plus Spur mit Höhe, Geschwindigkeit, Trittfrequenz und Fahrerleistung ergeben eine Fahrt mit Strecke, Zeiten, Summen und Spur, **ohne Zeitstempel je Punkt** (die Zeit je Punkt wäre aus Strecke und Geschwindigkeit zu schätzen, wie bei GPX „geschätzt“, v1.6). Fahrten sind nur da, wenn sie mit der **Flow-App** aufgezeichnet wurden.
3. **Neuer Zuschnitt (Entscheidung Nils, 25.10.2026: Option B):** 1.9 wird von „Motordaten“ zu **„Bosch-Daten“**: Bike, Akku und Wartung, Zusatzfelder je Fahrt und **Fahrten ohne Datei importieren** (Altbestand und laufend). Verworfen: A (ohne Import), C (1.9 streichen). Der Import löst den Altbestand (V-03), den sonst nichts löst. Siehe Backlog, REQUIREMENTS.md 10.18.
4. **Der Spike V-12 schrumpft:** offen sind nur noch die **Bedingungen für Datenempfänger** (Weitergabe an Freunde, App Store), die tatsächliche **Punktzahl** der Spur, wie weit zurück Fahrten abrufbar sind, **Verhalten mit Fahrten ohne Smartphone-Höhe** (`elevation` nur mit Mobile), Schlüsselbund mit ad-hoc signiertem Build und der Abgleich an echten Paaren (nur nötig, wenn die Fahrt auch als Datei vorliegt).
5. **Der Redirect mit eigenem Schema** ist belegt (siehe oben); **PKCE** wird nicht erwähnt: Das Portal hat für den Client den Schalter „Confidential client“, ohne Geheimnis ist der Client öffentlich.
6. **IDEA-08 (geschätzter Motoranteil)** bleibt als Wattspur-eigene Schätzung aus Fahrphysik denkbar; die Bosch-API liefert dafür **keine** Vergleichswerte.

## Digital Service Book API (Smart System) v2.0.3 (Nils, 25.10.2026)

Nils hat die **Digital Service Book API** (v2, OpenAPI 3.0.3) exportiert und gefragt, ob sich daraus noch etwas für das Bike ergibt. **Ja, einiges, aber nur für das Bike, nicht je Fahrt, und nur, wenn dazu Einträge vorliegen.** Die Datei liegt bei Nils, nicht im Repo (Sachverhalte nur). Hinweis im Portal: **v1 ist veraltet**, v2 ist der Ersatz.

### Umfang ✔
- Basis `https://api.bosch-ebike.com/service-book/smart-system/v2`, **ein Abruf**: `GET /service-records?bikeId=<UUID>` (die Kennung des Bikes aus der Bike-Antwort ist Pflicht). Die Antwort ist `serviceRecords[]` und **leer, wenn nichts vorliegt**. Zugriffsbereich: nur `offline_access` (keine eigenen Lesebereiche).
- Ein Eintrag hat `id`, `type`, `attributes` mit `bikeId`, `createdAt`, `odometerValue` (Meter), `bikeDealer` (Name, Straße, Ort) und `details`. Je nach `type` ist **genau ein** Unterobjekt gefüllt.
- **Ratenbegrenzung** (bei diesem API belegt): `429` mit den Kopfzeilen `X-RateLimit-Limit`, `-Remaining` und `-Reset`; im Beispiel **100 Anfragen je 60 Sekunden** (Eimer von 100, Auffüllung 100 je Minute). Ob dieselben Werte für die anderen APIs gelten, ist ✘ offen.
- Fehler wie bisher (`application/problem+json`, bei `401` und `403` auch reiner Text).

### Eintragstypen ✔ (Spezifikation) und was Wattspur davon hätte
| Typ | Inhalt | Nutzen für Wattspur |
|---|---|---|
| `SOFTWARE_UPDATE` | wer aktualisiert hat (Händlerwerkzeug oder **Flow-App** iOS/Android), erzwungen oder nicht, je Komponente Produktcode, Teilenummer, **Versionen vorher und nachher** (Software, Bootloader), Hinweise zur Version; je **Modus** Kennung, Anzeigename, aktiv ja/nein und Version | **Verlauf der Updates** je Bike (Datum, Komponenten, Versionen); ordnet die Modus-Kennungen (z. B. `A100…`) Anzeigenamen zu, **wenn** ein Update die Modi enthielt (✘ nicht gesehen). Entsteht auch ohne Händler, wenn die Flow-App aktualisiert |
| `INSPECTION` | Inspektion beim Händler: je Komponente eine Prüfliste mit Ergebnis (nicht geprüft, in Ordnung, nicht in Ordnung, repariert) | **Wartungshistorie**: Datum, Händler, Kilometerstand; Grundlage für „Inspektion zuletzt bei km X“ (IDEA-02) |
| `BBP_MEASUREMENT` | **Messung des Akkus** beim Händler: volle Ladezyklen, **gemessene Kapazität in Wh, Nennkapazität in Wh, gemessene Kapazität in Prozent** (also Akkugesundheit), am Bike oder extern gemessen | **Akkugesundheit und Nennkapazität** (löst die Lücke „Kapazität und Gesundheit fehlen“ der Bike-Antwort, aber nur für gemessene Akkus) |
| `CUSTOMER_REPORT` | **Kundenbericht** des Händlerwerkzeugs (Bosch Diagnosis Tool 3): Bike-Daten, **Unterstützungsmodi mit Kennung, Kurz- und Langname, Stärke, vom Nutzer angepasste Werte** (Beschleunigung, Unterstützungsstufe, Höchstgeschwindigkeit, Drehmoment, Leistung), **Statistik je Modus: Strecke in Metern und Energie in Wh**, Komponenten mit vielen Datenpunkten und Zuständen (z. B. gestohlen, zurückgerufen), **nächste Wartung** nach Tagen und Metern | **Modus-Anteile je Bike** (Strecke und Energie je Modus, **kumuliert zum Zeitpunkt des Berichts**), Modi mit Namen und Stärke, nächste Wartung. **Das ist die einzige Quelle für Modus- und Energiewerte**, aber nur als **Momentaufnahme je Händlerbesuch**, nicht je Fahrt |
| `ACTUATOR_TEST` | Funktionstests je Komponente (Tasten, LEDs, Sensoren) mit Ergebnis | für Wattspur ohne Nutzen |
| `BIKE_ID_CHANGE` | Tausch von Antrieb oder Bedieneinheit mit neuer Bike-Kennung | **wichtig für die Zuordnung**: Die Kennung eines Bikes kann sich nach einem Tausch ändern; Wattspur muss mit einer neuen Kennung rechnen (MOT-05) |

### Was sich daraus ergibt
1. **Es gibt Modus- und Energiewerte, aber nicht je Fahrt:** Der Kundenbericht liefert Strecke und Energie je Modus **über die Lebensdauer des Bikes** (Stand des Berichts). Zwei Berichte ergeben den Verbrauch je Modus in der Zwischenzeit. Das setzt einen **Händlerbesuch** voraus; ohne Bericht bleibt es leer. **Für Nils ist offen, ob es solche Einträge gibt** (Abfrage mit eigenem Client im Spike V-12).
2. **Akkugesundheit und Kapazität:** nur nach einer Messung beim Händler; sonst weiter nur Ladezyklen und abgegebene Energie.
3. **Wartung:** Die Bike-Antwort kennt nur `serviceDue` (Datum, Kilometerstand); das Service Book ergänzt Händler, Inspektionen und die nächste Wartung nach Tagen und Metern.
4. **Software-Verlauf:** Für Bikes, die über die Flow-App aktualisiert werden, sind Einträge auch ohne Händler möglich ✘ (nicht gesehen).
5. **Datenschutz:** Händlername und -ort sind Daten der Händlerbeziehung; sie bleiben lokal (MOT-12) und gehören nicht in Diagnose oder Export.
6. **Entscheidung Nils (25.10.2026):** ein Bereich „Verlauf und Service“ im Profil bleibt als **Kann** in 1.9 (MOT-15, B-160), **abhängig vom Ergebnis in V-12** (echte Einträge für Nils' Bike). Er gehört nicht zum festen Umfang.

## Live Data Interface (Bluetooth) und Dokumentation im Portal (Nils, 25.10.2026)

Nils hat zwei Quellen genannt: die **API-Dokumentation im Data-Act-Portal** (Operationen wie `list-bikes` in der Gruppe „Smart System Bike Profile“) und das PDF **„The smart system – Live Data Interface“, V1.0 vom 01.05.2026** (26 Seiten, von mir gelesen, die Kopie liegt bei Nils in den Downloads, nicht im Repo).

### API-Dokumentation im Portal (teilweise von Nils gesichert)
Die Seite liegt **hinter der Anmeldung** (ohne Konto „Unauthorized“); ich melde mich bei Bosch nicht an. Nils hat ihren Inhalt gesichert: den **Export der eBike Profile API** (Abschnitt „Offizielle Spezifikation“, als Text und als YAML-Datei) und Bildschirmfotos der Seite. **Noch zu sichern (Nils):** die **Activity Records API** (Fahrten, vermutlich mit dem Detail-Abruf) per „Export“, die Texte „Introduction“, „Authentication“, „Pagination“, „Error responses“ und „FAQ“ (Ratenbegrenzung, Seitengrößen) und der Reiter „Client application“ (zulässige Redirect-Adresse). Optional: die Digital Service Book API und die Bike Pass API, falls sie für Privatpersonen freigeschaltet sind. **Stand zum Lesen im Browser-Fenster (Nils hat sich dort selbst angemeldet):** Der Inhalt der Doku liegt in einem **eingebetteten Fenster von einem anderen Server** (cloud-api-docs…connected-biking.cloud, Stoplight) und lässt sich weder als Text auslesen noch bedienen; Klicks im Menü kamen nicht an. Gelesen habe ich nur die Einleitung („Getting access“ in drei Schritten): (1) im **Partner Portal** eine OAuth2-Client-Anwendung anlegen, (2) im **Bosch eBike manager** (Flow-Portal) gibt der Dateneigner den Zugriff **je Gerät** für diese Client-Anwendung frei, (3) ein gültiges OpenID-Connect-Zugriffstoken (JWT) mit dem **Authorization-Code-Ablauf** holen. Hinweis im Portal: Version v1 der **Digital Service Book API** ist veraltet, v2 ist der Ersatz. Die **Activity Records API** konnte ich so nicht lesen; Nils muss sie über „Export“ sichern.

### Live Data Interface ✔ (offizielles PDF)
- **Was es ist:** Bluetooth Low Energy (GATT), die Daten des Bikes **live** an ein Zubehör. Kostenlos, ohne Registrierung, ohne Schlüssel (Kap. 3.2); verfügbar ab der Steuerungssoftware v19, dort noch als **„experimental“** gekennzeichnet; Voraussetzung ist eine Smart-System-Fernbedienung (BRC).
- **Daten:** Geschwindigkeit (1/100 km/h), Trittfrequenz, **Fahrerleistung**, Umgebungshelligkeit, **Akkustand in Prozent**, Uhrzeit (UTC), Kilometerstand (Meter), Lichtzustand, Systemsperre, Ladegerät angeschlossen, Lichtreserve, Diagnosegerät angeschlossen, „Bike steht“. **Keine Motorleistung, keine Unterstützungsstufe, keine Ladezyklen.** Der Akkustand ist nur live da; fällt der Akku weg, bleibt der letzte Wert stehen, ohne Hinweis (Kap. 2.2.3.2).
- **Rollen, wichtig:** Das **Bike ist der GATT-Server und GAP-Central**, das **Zubehör** muss **GAP-Peripheral** sein, mit „Service Solicitation“ werben, Pairing mit Bonding und einen MTU von mindestens 247 Bytes aushandeln. Bosch schreibt selbst: Das Profil ist **für eigene Zubehör-Hardware** gemacht; Smartphone-Betriebssysteme schränken die Peripheral-Rolle ein, **„Smartphone support is not in scope“** (Kap. 2.1.5). Ob ein iPhone oder Mac die Rolle trotzdem erfüllen kann, ist ✘ offen (eigene Einschätzung, nicht geprüft: CoreBluetooth kann auf iOS nur einen Teil der Werbedaten setzen).
- **Format:** Protocol Buffers (`ebike_live_data.proto`, Apache-2.0, im PDF abgedruckt); Basis-UUID `0000xxxx-eaa2-11e9-81b4-2a2ae2dbcce4`, Dienst `eb20`, Merkmal `eb21`. Neue Felder können später dazukommen.
- **Nutzungsbedingungen (Kap. 3):** kostenlos, nicht ausschließlich, nicht übertragbar, ohne Unterlizenz, „zur Entwicklung, Prüfung und zum Angebot von Produkten und Diensten, die mit dem smart system kompatibel sind“; Datenschutz liegt allein beim Nutzer, Bosch und Nutzer sind getrennte Verantwortliche; deutsches Recht, Gerichtsstand Stuttgart; Bosch darf die Schnittstelle jederzeit ändern. **Diese Bedingungen gelten nur für das Live Data Interface, nicht für die Data-Act-API** (deren Bedingungen sind weiter ✘ unbekannt).

### Folgerung für Wattspur
1. **Kein Weg für 1.9.** Die Live-Daten gibt es nur **während** der Fahrt und nur an ein Gerät, das **mitläuft**. Wattspur importiert nach der Fahrt am Mac; es hat nichts zum Mitschreiben dabei. Es gibt keine nachträgliche Abfrage.
2. **Sie sind aber der einzige belegte Weg zu einem Akkustand als Zeitreihe** (nicht zur Motorleistung). Dafür müsste ein Gerät auf der Fahrt den Akkustand mit Zeitstempel mitschreiben und später an Wattspur geben, am ehesten eine iOS-App (B-070) oder ein kleines Zubehör. Das ist ein **eigenes Projekt**, kein Teil des Plans, und es hängt an der offenen Frage, ob ein Smartphone die Zubehör-Rolle überhaupt erfüllt. Als Idee im Pool: **IDEA-31 bleibt die Wiedergabe, IDEA-32 ist das Mitschreiben** (siehe Anforderungen, Kap. 4.12).
3. **Marken, Recht:** Das PDF trägt Bosch-Marken und ein Urheberrecht; Wattspur zitiert nur Sachverhalte, keine Seiten, keine Logos (NFR-09, NFR-12). Die `.proto`-Datei steht unter Apache-2.0 und dürfte nur mit Lizenzhinweis übernommen werden; sie wird für Wattspur nicht gebraucht.

## Rechtliches und Datenschutz

- **Nutzungsbedingungen:** ✘ nicht gelesen. Zu klären (Nils liest sie bei der Registrierung im Spike V-12): Darf eine verbreitete App (DMG an Freunde, GitHub, später App Store) Daten abrufen und lokal speichern? Gilt jede Person als eigener Datenempfänger? Gibt es Vorgaben zur Weitergabe, Löschung, zu Marken und Logos?
- **Marken:** NFR-09 und NFR-12 bleiben: keine Bosch-Logos oder -Assets. Die Namen der Unterstützungsmodi (Eco, Tour, eMTB, Turbo) sind Produktbezeichnungen und werden nur beschreibend verwendet; Prüfung im Spike.
- **DSGVO (Einschätzung, keine Rechtsberatung, nicht an einer Quelle belegt):** Wattspur sammelt nichts, es gibt kein Backend; die Daten gehen vom Nutzer direkt von Bosch auf seinen Mac. Wattspur-Betreiber sind damit voraussichtlich kein Verantwortlicher für diese Daten; die Datenschutzhinweise im Info-Fenster und im Handbuch müssen den optionalen Abruf trotzdem ehrlich beschreiben (was abgerufen wird, wo es liegt, wie man abmeldet und löscht).
- **Tokens:** im Schlüsselbund, nie in der SwiftData-Datenbank und nicht im Repo. Eine Client-ID eines **öffentlichen** PKCE-Clients ist kein Geheimnis; ein Client-Secret gibt es bei dieser Art Client nicht ◐.
- **Ad-hoc signierte App und Schlüsselbund** (eigene Kenntnis, nicht geprüft): Eine ad-hoc signierte Sandbox-App hat keine Team-ID; Schlüsselbund-Zugriff und Abfragen nach einem Update können sich anders verhalten (V-10 prüfte nur Gatekeeper und Ordnerzugriff). Prüfpunkt im Spike mit einem Testbuild bei einem Freund.

## Folgen für Wattspur

1. **Netz:** NFR-01 („Netz nur für Kartenkacheln und das Online-Handbuch“) wird erweitert: Netz auch für den **optionalen** Bosch-Abruf; ohne Konto bleibt alles wie bisher, keine Telemetrie.
2. **Kein Backend, kein Geheimnis im Repo:** öffentlicher PKCE-Client, Client-ID je Nutzer, Redirect über den Systembrowser. Ein gemeinsamer Client von Nils für alle wäre nur nach den Bedingungen denkbar (er wäre dann Datenempfänger für Dritte).
3. **Quelle der Wahrheit bleibt die FIT-Datei** (Kap. 3.3), Rangfolge FIT vor GPX vor Bosch. Die API-Fahrt wird einer vorhandenen Fahrt zugeordnet (Start, Strecke, Route wie IMP-04) und liefert Zusatzfelder. Die Spur der API ist **kein Ersatz für eine vorhandene Datei**, aber die Quelle für Fahrten ohne Datei (Option B, MOT-13); eine später importierte Datei ersetzt die Bosch-Fahrt.
4. **Zuordnung API-Bike ↔ Wattspur-Bike:** die API nennt eine Bike-ID ◐, die Wattspur-Bikes (v1.5) tragen keine Kennung. Zuordnung manuell, einmal je Bike.
5. **Altbestand:** Wie weit zurück Bosch Fahrten hält, ist ✘ offen; die Spezifikation nennt als Beginn den Tag, an dem die Cloud erstmals Daten des Bikes aus der Flow-App erhielt (`createdAt`). Mit **Option B** löst die Data-Act-API das Altbestandsproblem aus V-03 auch für Fahrten **ohne Datei**: Sie werden aus Zusammenfassung und Spur angelegt (Zeit je Punkt geschätzt).

## Empfehlung

**Stand nach den Spezifikationen (25.10.2026):** Die Punkte 1 bis 4 gelten mit zwei Änderungen. Erstens ist die Frage nach Modi und Energieanteil **beantwortet (nein)**, V-12 prüft nur noch die Bedingungen, die Punktzahl der Spur, den Verlauf und die technischen Punkte. Zweitens wird der Umfang von 1.9 neu gefasst: **„Bosch-Daten“ statt „Motordaten“**, mit der Option, **Fahrten ohne Datei** (Altbestand) aus Zusammenfassung und Spur zu importieren. **Nils hat am 25.10.2026 Option B gewählt** (Backlog, Abschnitt v1.9).

1. **Spike V-12** (Nils registriert sich selbst, Wattspur und ich melden nichts an): Registrierung als Datenempfänger, Bedingungen lesen und die wichtigsten Punkte notieren, Client anlegen (öffentlich, ohne Secret), Redirect-Möglichkeiten für Mac-Apps prüfen, Freigabe abwarten und messen, Antworten der Endpunkte für 2 bis 3 Fahrten (darunter die Beispielfahrt „Reinheim Rundfahrt“ und die älteste Fahrt) als JSON sichern und anonymisieren. Ergebnis als `docs/SPIKE-BOSCH-DATA-ACT-API.md`. Das Ziel ist ein Ja/Nein je Datenfeld, die tatsächliche Punktzahl der Spur, die Zuordnung zur FIT-Fahrt und die Frage, ob eine Mac-App den Redirect nutzen darf.
2. Danach die Stories von 1.9 (B-147 bis B-159) nachschärfen. Ohne Zusage oder bei unzumutbaren Bedingungen entfällt die Version; der übrige Plan ist davon nicht berührt.
3. **Handbuch:** ein Kapitel „Bosch-Daten abrufen“ mit Registrierung Schritt für Schritt (Text, keine Screenshots der Bosch-Portale aus Urheberrechtsgründen, NFR-12).
4. Parallel läuft die DSGVO-Auskunft (V-07) weiter: Enthält sie Akku- oder Modusdaten, wird sie zur Ergänzung für Fahrten ohne Data-Act-Zugang.

## Offene Punkte
- **API-Dokumentation im Portal:** vollständig gesichert (eBike Profile API, Activity Records API, Authentication, Pagination, Error responses, FAQ). Offen bleiben nur die Bedingungen für Datenempfänger und die Auskunft des Portals zu Ratenbegrenzung (nirgends genannt).
- Inhalt der **Bedingungen für Datenempfänger** und des **Anhangs 1** (PDF auf der Bosch-Seite).
- **Punktzahl und Auflösung der Spur** in der Antwort des Detail-Abrufs (die Spezifikation nennt sie nicht), **Ratenbegrenzung** (nirgends dokumentiert), Verhalten von `elevation` und `heartRate` bei Fahrten ohne Smartphone.
- Zulässiger **Redirect** für Mac-Apps: ein benutzerdefiniertes Schema wie `wattspur://callback` ist für den Client von EBikeData eingetragen und damit sehr wahrscheinlich möglich ✔; Prüfung mit einem eigenen Client im Spike (V-12), auch Loopback und Universal Link ✘.
- ~~Ob die offizielle API Unterstützungsmodi je Fahrt und den Energieanteil liefert~~ → **Nein** (Spezifikation, 25.10.2026).
- Dauer der **Clientfreigabe** in der Praxis und ob sie je Person nötig ist.
- Wie weit zurück **Fahrten** abrufbar sind und ob Bosch **Fahrten nachträglich** ändert.
- Verhalten von **Schlüsselbund** und Anmeldung mit ad-hoc signiertem Build.

## Quellen
- Bosch: [Live Data Interface (PDF, V1.0, 01.05.2026)](https://www.bosch-ebike.com/fileadmin/EBC/Service/Downloads/LiveData/20260501_LiveDataInterface_V1_28042026.pdf), [Data Act (EN)](https://www.bosch-ebike.com/en/data-act), [Data Act (US)](https://www.bosch-ebike.com/us/data-act), [Data Act (DE)](https://www.bosch-ebike.com/de/data-act), [Data-Act-Portal](https://portal.bosch-ebike.com/data-act), [Connected Biking Plattform](https://www.bosch-ebike.com/us/company/industry-solutions/cloud-api-ebike-sdk), [Live Data Interface](https://www.bosch-ebike.com/en/business/live-data-interface)
- App: [EBikeData im App Store](https://apps.apple.com/us/app/ebikedata/id6760475380)
- Community (nicht von Bosch, inoffiziell gepflegt): [bosch-flow-mcp](https://github.com/partymola/bosch-flow-mcp) ([glama.ai](https://glama.ai/mcp/servers/partymola/bosch-flow-mcp)), [ha-bosch-ebike](https://github.com/Xunil99/ha-bosch-ebike), [bosch-ebike-smartsystem-stats](https://github.com/clementdevos/bosch-ebike-smartsystem-stats), [Home-Assistant-Forum](https://community.home-assistant.io/t/new-integration-bosch-ebike-smart-system-data-act-api-track-your-rides-in-home-assistant/995410)
