# Recherche: Altbestand von 128 Fahrten aus der Bosch eBike Flow App

Backlog-Aufgabe **V-03**, Entscheidung **#5** in [REQUIREMENTS.md](REQUIREMENTS.md) Kap. 8.
Stand der Recherche: 19.10.2026. Es wurden keine Konten angelegt und keine Anmeldedaten verwendet; alle Aussagen stammen aus öffentlichen Quellen und dem Quellcode eines Community-Projekts.

## Kurzfassung

- **Bosch bietet keinen offiziellen Massenexport.** Die Flow-App exportiert FIT bzw. GPX nur pro Fahrt (Statistik → Fahrt → „…“ → Herunterladen). Für das Smart System gibt es kein Webportal mit Export wie früher bei eBike Connect.
- **Strava, komoot und Apple Health helfen beim Altbestand nicht.** Die Flow-App überträgt laut Bosch-Hilfe jede Fahrt automatisch *nach dem Ende der Fahrt*. Von einer Nachübertragung älterer Fahrten steht dort nichts, und Forenberichte sprechen dagegen. Für neue Fahrten wäre Strava aber eine brauchbare Massenquelle.
- **Der einzige Weg zu allen 128 Fahrten auf einmal ist die (inoffizielle) Bosch-Fahrten-API.** Die Flow-App nutzt sie selbst. Das Open-Source-Projekt **bosch-flow-mcp** (GPLv3, aktiv gepflegt) zeigt, wie man sie mit der eigenen Anmeldung anspricht. Sie liefert pro Fahrt die Zusammenfassung und eine Punktreihe mit **GPS, Geschwindigkeit, Höhe, Trittfrequenz und Fahrerleistung**.
- **DSGVO- und Data-Act-Auskunft** sind rechtlich möglich, aber langsam (bis zu 1 bzw. 3 Monate), Format und Detailtiefe sind offen. Als Backup oder Ergänzung sinnvoll, nicht als Hauptweg.

**Empfehlung:** Altbestand einmalig über die Fahrten-API holen, mit einem kleinen Exportskript nach dem Muster von bosch-flow-mcp. Das Skript schreibt pro Fahrt eine JSON-Datei mit den Rohdaten. Wattspur bekommt dafür einen eigenen `RideImporter` („Bosch-API-JSON“). Für neue Fahrten bleibt der Einzelexport mit Ordnerüberwachung der Standard. Details siehe [Empfehlung](#empfehlung).

## Übersicht der Optionen

| # | Option | Alle 128 auf einmal? | Leistung / Trittfrequenz? | Aufwand | Risiko |
|---|---|---|---|---|---|
| A | Einzelexport FIT aus der Flow-App (Fallback) | nein, 128 × manuell | ja (FIT, 1-Hz-Datensätze) | hoch an Handarbeit (≈ 1–2 h), kein Code | keins |
| B | Inoffizielle Fahrten-API (bosch-flow-mcp o. ä.) | **ja** | **ja** (Punktreihe + Zusammenfassung) | mittel: einmalige Anmeldung, Skript, eigener Importer | API undokumentiert, kann sich ändern; AGB-Grauzone |
| C | EU Data Act (Bosch-Partnerportal, eigener Client) | ja, als API | vermutlich ja, nicht bestätigt | hoch: Registrierung als Datenempfänger, eigener OAuth-Client | offizieller Weg, aber Umfang für Fahrten unklar |
| D | DSGVO-Auskunft (Art. 15/20) | ja, als Paket | unklar | gering (eine Anfrage), aber Wartezeit | Format unbekannt, evtl. nur Zusammenfassungen |
| E | Strava-Sync + Strava-Massenexport | **nur für Fahrten nach dem Verbinden** | ja, laut Nutzerberichten | gering | hilft beim Altbestand nicht |
| F | Apple Health | nur neue Fahrten | Workout-Zusammenfassung, keine Leistungsreihe gesichert | gering | hilft beim Altbestand nicht |
| G | komoot | nur neue Fahrten | nein (komoot zeigt Route, Zeit, Höhe) | gering | hilft beim Altbestand nicht |

## Die Optionen im Einzelnen

### A – Einzelexport aus der Flow-App (Fallback)
- Weg: Statistik → Fahrt öffnen → Menü „…“ → FIT oder GPX herunterladen ([Bosch-Hilfe, GPX-Export](https://help.bosch-ebike.com/au/help-center/asset-asf-00128)). FIT gibt es seit dem App-Update 05/2023 ([Bosch News](https://www.bosch-ebike.com/au/news/update-for-the-ebike-flow-app-05/2023)).
- Datenumfang: wie die Beispieldatei in `reference/sample-data/` – Leistung, Trittfrequenz, Geschwindigkeit, Höhe, GPS. Herzfrequenz fehlt laut Nutzern teilweise, selbst wenn sie aufgezeichnet wurde ([eMTB-Forum, Flow 1.34](https://www.emtbforums.com/posts/679634/)).
- Aufwand: 128 Fahrten × (öffnen, exportieren, speichern) ≈ 30–60 s pro Fahrt. Mit Ordnerüberwachung (Wattspur) zumindest ohne Nacharbeit beim Import.
- Vorteil: genau das Format, das Wattspur ohnehin liest. Keine Grauzone.

### B – Inoffizielle Fahrten-API (empfohlen für den Altbestand)
Die Flow-App holt ihre Fahrten aus einer Bosch-Cloud. Das Community-Projekt [partymola/bosch-flow-mcp](https://github.com/partymola/bosch-flow-mcp) (GPLv3, Python 3.13, angelegt 04/2026, letzter Push 17.10.2026) spricht diese Schnittstelle an. Aus dem Quellcode (`config.py`, `tools/activity_tools.py`):

- **Anmeldung:** Bosch-Keycloak (`p9.authz.bosch.com`, Realm `obc`) mit dem öffentlichen App-Client `one-bike-app` und PKCE. Man meldet sich im Browser mit der eigenen SingleKey ID an. Weil die Weiterleitung auf ein iOS-Schema zeigt (`onebikeapp-ios://…`), muss man die Rückgabe-URL einmal aus den Browser-Entwicklerwerkzeugen kopieren. Danach wird das Token per `offline_access` automatisch erneuert. Es werden keine API-Schlüssel gebraucht.
- **Fahrtenliste:** `GET https://obc-rider-activity.prod.connected-biking.cloud/v1/activity?size=200` – bei 128 Fahrten eine einzige Anfrage. Felder je Fahrt u. a.: Start/Ende, Zeitzone, Dauer ohne Pausen, Strecke, Ø/max. Geschwindigkeit, **Ø/max. Trittfrequenz**, **Ø/max. Fahrerleistung**, Ø/max. Puls, Höhenmeter auf/ab, Kalorien, Anteil Fahrerenergie, Nutzung der Unterstützungsmodi, CO₂, Brems- und ABS-Ereignisse, Kilometerstand bei Start, Bike-ID.
- **Fahrtdetails:** `GET …/v1/activity/{id}/detail` – Punktreihe mit kumulierter Strecke (m), Geschwindigkeit (km/h), Höhe (m), **Trittfrequenz (U/min)**, **Fahrerleistung (W)**, Breite/Länge, Puls (meist leer). Die Abtastrate ist nicht dokumentiert; das muss ein Probeabruf zeigen.
- **Nicht enthalten:** keine fertigen FIT/GPX-Dateien; das Projekt speichert nichts von den Fahrten, sondern liest live. Ein Export-Skript müsste die JSON-Antworten selbst ablegen.
- **Risiken:** undokumentierte Schnittstelle, kann sich jederzeit ändern (das Projekt sagt das selbst). Nutzung des App-Clients außerhalb der App ist eine AGB-Grauzone; es werden aber nur eigene Daten gelesen. Ratenbegrenzung (HTTP 429) ist möglich, also Anfragen drosseln.
- Weitere Hinweise auf das Projekt: [glama.ai](https://glama.ai/mcp/servers/partymola/bosch-flow-mcp), [PyPI/Socket](https://socket.dev/pypi/package/bosch-flow-mcp). Eine ältere Aussage der [Homey-Community](https://community.homey.app/t/154269), die Bosch-API gebe keine Einzelfahrten heraus, ist damit überholt.

Aufwand: Skript mit ca. 100 Zeilen (Anmeldung, Liste, 128 Detailabrufe, JSON speichern) – ein halber Tag. Dazu ein Wattspur-Importer für das JSON-Format (Abbildung auf das bestehende Fahrtmodell, Quelle „Bosch-API“) – 1–2 Tage.

### C – EU Data Act (offizieller API-Weg)
- Seit 12.09.2025 gilt der EU Data Act. Bosch beschreibt den Ablauf auf [bosch-ebike.com/de/data-act](https://www.bosch-ebike.com/de/data-act): Wer Daten erhalten will (auch für sich selbst), registriert sich im [Partnerportal](https://portal.bosch-ebike.com/data-act) als Datenempfänger, akzeptiert die Bedingungen und legt einen eigenen OAuth-Client an. Als Nutzer gibt man die Daten dann im [Flow-Portal](https://flow.bosch-ebike.com/data-act) für diesen Client frei. Hinweis von Bosch: „Wenn Du Dir selbst Deine Daten freigeben möchtest, registriere Dich bitte zuerst als Datenempfänger.“
- API: `https://api.bosch-ebike.com`, laut bosch-flow-mcp u. a. mit `/activity/smart-system/v1/activities` und `…/activities/{id}/details`. Ob diese Endpunkte für Privatpersonen freigeschaltet werden und welche Felder sie liefern, ist öffentlich nicht dokumentiert. Die Datenübersicht („Anhang 1“) verlinkt Bosch, ihr Inhalt ließ sich bei der Recherche nicht abrufen.
- Bewertung: der sauberste Weg, aber der aufwendigste. Lohnt sich, wenn Wattspur später dauerhaft und offiziell synchronisieren soll (z. B. als Importer für neue Fahrten). Für den einmaligen Altbestand zu schwer.

### D – DSGVO-Auskunft / Datenübertragbarkeit
- Anspruch auf Auskunft (Art. 15) und Herausgabe in maschinenlesbarem Format (Art. 20) gegenüber Bosch eBike Systems (Robert Bosch GmbH). Kontakt laut Datenschutzhinweisen der Flow-App (Profil → Rechtliches); eine öffentliche Seite mit Ablauf oder Format fand sich nicht.
- Frist: 1 Monat, verlängerbar um bis zu 2 Monate (Art. 12 Abs. 3).
- Datenumfang: unbekannt. Typisch sind JSON- oder CSV-Pakete; ob sie die Punktreihen mit Leistung und Trittfrequenz enthalten oder nur Zusammenfassungen, lässt sich vorab nicht sagen.
- Bewertung: kostet nur eine E-Mail und kann parallel laufen. Gut als zweite Quelle, um Option B zu prüfen, aber kein verlässlicher Hauptweg.

### E – Strava
- Verbindung: Flow-App → Einstellungen → Verbundene Dienste → Strava; danach wird jede Fahrt nach dem Ende automatisch übertragen ([Bosch-Hilfe Strava](https://help.bosch-ebike.com/au/help-center/asset-asf-00702?pos=1)). Die Integration kam mit Flow 1.26 ([bikebiz](https://bikebiz.com/bosch-releases-ebike-flow-app-1-26-update-and-adds-strava-integration/), [heise](https://heise.de/-10343892)).
- Datenumfang: laut Nutzern Geschwindigkeit, Leistung, Trittfrequenz und GPS ([eMTB-Forum](https://emtbforums.com/threads/bosch-bikes-how-do-you-record-your-rides-on-strava.40288)). Eine offizielle Feldliste gibt es nicht. Ein älterer Beitrag nennt die Strava-Daten „schlecht“ ([eMTB-Forum](https://emtbforums.com/threads/bosch-ebike-connect-data-or-lack-thereof.23752/post-329760)).
- **Altbestand:** Bosch beschreibt nur die Übertragung nach dem Fahrtende. Nutzer berichten, dass ältere Fahrten nicht nachgeladen werden und man sie per GPX/FIT von Hand zu Strava hochladen muss ([eMTB-Forum](https://emtbforums.com/threads/bosch-flow-strava-will-not-sync.37239/post-528310)). Damit wäre der Umweg über Strava *mehr* Arbeit als Option A.
- Massenexport: Strava → Einstellungen → Mein Konto → „Konto herunterladen“; Link per E-Mail nach einigen Stunden ([Strava-Support](https://support.strava.com/hc/en-us/articles/216918437-Exporting-your-Data-and-Bulk-Export)). Das ZIP enthält `activities.csv` und im Ordner `activities/` die **Originaldateien** (`.fit`, `.fit.gz`, `.gpx`, `.gpx.gz`) ([fit2gpx-Doku](https://fit2gpx.readthedocs.io/en/stable/_sources/index.rst.txt), [strava-local-heatmap-tool](https://github.com/roboes/strava-local-heatmap-tool)).
- Bewertung: für den Altbestand ungeeignet. Für die Zukunft eine gute zweite Quelle: Ein späterer Wattspur-Importer „Strava-Export“ müsste nur `.fit.gz` entpacken.

### F – Apple Health
- Verbindung über Verbundene Dienste in der Flow-App, danach automatische Übertragung jeder Fahrt ([Bosch-Hilfe Apple Health](https://www.bosch-ebike.com/en/help-center/asset-asf-00183)). Altbestand: kein Hinweis auf Nachübertragung.
- Datenumfang: Workout (Radfahren) mit Dauer, Strecke, Energie, ggf. Route und Puls. Ob Leistung und Trittfrequenz als Reihe ankommen, ist nicht belegt. Die Dritt-App [Flow Sync](https://apps.apple.com/app/id6759534006) importiert genau deshalb Bosch-FIT-Dateien in Apple Health.
- Bewertung: für den Altbestand ungeeignet; als spätere Quelle (Entscheidung #6) eher für Puls interessant.

### G – komoot
- Automatische Übertragung neuer Fahrten als „Gemachte Touren“; Trennen lässt bereits übertragene Fahrten unberührt ([Bosch-Hilfe komoot](https://www.bosch-ebike.com/en/help-center/asset-asf-00697), [komoot-Support](https://support.komoot.com/hc/articles/10350954148250)).
- komoot hat keinen Massenexport mit Leistungs- und Trittfrequenzdaten. Ungeeignet.

## Empfehlung

1. **Altbestand über Option B holen** (einmalig, mit eigener Anmeldung des Nutzers):
   - Kleines Skript (Python oder Swift-CLI) nach dem Muster von bosch-flow-mcp: Anmeldung per PKCE, `GET /v1/activity?size=200`, dann für jede Fahrt `GET /v1/activity/{id}/detail` mit Pause zwischen den Abrufen.
   - Je Fahrt eine Datei `bosch-api/<id>.json` mit Zusammenfassung und Punktreihe ablegen (Rohdaten unverändert, damit nichts verloren geht).
   - Vorher an **einer** Fahrt prüfen, ob Punktreihe und FIT-Export übereinstimmen (Abtastrate, Leistung, Trittfrequenz, Höhe). Dafür eignet sich die Beispielfahrt „Reinheim Rundfahrt“ (18.10.2026) in `reference/sample-data/`.
   - Wattspur bekommt einen `RideImporter` „Bosch-API-JSON“; Quelle der Fahrt = „Bosch-API“. Dubletten zur FIT-Datei über Startzeit erkennen.
2. **Parallel eine DSGVO-Auskunft stellen** (Option D). Kostet nichts und zeigt, ob Bosch ein offizielles Paket mit Punktreihen liefert. Wenn ja, kann es Option B später ersetzen oder absichern.
3. **Für neue Fahrten** bleibt es beim Einzelexport mit Ordnerüberwachung (MVP). Optional Strava verbinden, damit künftige Fahrten zusätzlich gesichert sind und später per Strava-Massenexport geholt werden können.
4. **Wenn Option B scheitert** (Schnittstelle geändert, Anmeldung klappt nicht): Fallback Option A – 128 FIT-Dateien einzeln exportieren. Das ist lästig, aber in ein bis zwei Stunden erledigt und liefert das bekannte Format.

Daraus folgende Backlog-Punkte (Vorschlag, noch nicht eingetragen):
- Exportskript für die Bosch-Fahrten-API (Altbestand), inkl. Abgleich mit einer FIT-Datei.
- `RideImporter` für Bosch-API-JSON.
- DSGVO-Auskunft bei Bosch stellen und Ergebnis dokumentieren.

## Offene Punkte
- Abtastrate der API-Punktreihe und ob Zeitstempel pro Punkt enthalten sind. Legende und Testdaten von bosch-flow-mcp zeigen nur die Schlüssel `s, v, h, c, p, lat, lon, r` – **keine Zeit pro Punkt**. Falls das stimmt, müsste der Importer die Zeitachse aus Start/Ende und der Punktzahl rekonstruieren (bei konstanter Abtastrate machbar, Pausen werden dann ungenau). Das klärt erst ein Probeabruf im Vergleich zur FIT-Datei.
- Inhalt von Bosch' Data-Act-Anhang 1 (Datenkategorien für Fahrten).
- Format und Inhalt einer DSGVO-Auskunft von Bosch.
