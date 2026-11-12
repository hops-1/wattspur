# Kartenstile im App Store: Anfrage an die Betreiber (V-18)

Stand: 12.11.2026. **Entscheidung Nils (12.11.2026): Weg A, die Betreiber fragen.** Die OSM-Kartenstile (OpenStreetMap, CyclOSM, OpenTopoMap) bleiben in der App. Apple-Karten bleiben die Voreinstellung.

Diese Seite erklärt, was die Regeln heute sagen, an wen Nils schreibt und was drinsteht. Die Briefe unten sind fertig zum Kopieren. **Claude schickt nichts ab:** Absender ist Nils, mit seiner eigenen Adresse.

## Was die Regeln heute sagen

Neu gelesen am 12.11.2026.

| Betreiber | Regel für Apps | Erlaubnis nötig? | Kontakt |
|---|---|---|---|
| **OpenStreetMap** (`tile.openstreetmap.org`, OSMF, Operations Working Group) | [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/): Apps aus dem Store sind erlaubt mit einem eigenen, festen User-Agent (App-Name, gern Kontakt). Nur Kacheln, die gerade zu sehen sind; kein Vorausladen, kein Offline, Cache-Header beachten, Quellenangabe sichtbar. Bei zu viel Last kann der Server die App ohne Vorwarnung sperren. | Nein, nicht ausdrücklich. Frühere Fassungen verlangten eine Erlaubnis für „eine verbreitete App“; die heutige nicht mehr. Fragen ist trotzdem höflich und schützt vor einer Sperre. | E-Mail `operations@osmfoundation.org` |
| **OpenTopoMap** (Stefan Erhardt) | [opentopomap.org/about](https://opentopomap.org/about): Einbinden in Webseiten und Apps erlaubt, solange der Server nicht überlastet wird; keine Massendownloads, keine Garantie. Lizenz CC-BY-SA, auch kommerziell. Die Betreiber freuen sich über eine kurze Info, wie die Karte genutzt wird. | Nein, aber eine kurze Info ist erwünscht. | E-Mail `stefan@opentopomap.org` (aus dem Impressum). Antwort nicht sicher, sie schreiben, dass sie nicht jede Mail beantworten können. |
| **CyclOSM** (Kacheln von OpenStreetMap France) | [cyclosm.org](https://www.cyclosm.org/): „fair use“, mit Verweis auf die Regeln der OSMF. Keine eigenen Zahlen. | Nicht ausdrücklich. | Öffentlich: [GitHub-Issues von CyclOSM](https://github.com/cyclosm/cyclosm-cartocss-style/issues). Eine E-Mail-Adresse für den Kachelserver von OSM France steht nirgends; vor dem Senden auf openstreetmap.fr nach einem Kontakt schauen. Ein Issue ist **öffentlich** und zeigt Nils' GitHub-Namen. |

## Was Wattspur schon richtig macht

Geprüft im Code (`WattspurMap/MapTiles.swift`, `WattspurCore/Map/TileSource.swift`):

- Eigener User-Agent: `Wattspur/<Version> (+https://github.com/hops-1/wattspur)`.
- Nur Kacheln, die auf dem Bildschirm sind, nie vorausgeladen, kein Offline-Paket.
- Cache auf der Platte (300 MB), er folgt den Cache-Headern der Server (`useProtocolCachePolicy`).
- Quellenangabe auf jeder Karte.
- Apple-Karten sind Voreinstellung. Die OSM-Stile muss man selbst unter *Mehr › Karten* wählen.

## Wie es weitergeht

1. Nils schickt die zwei E-Mails (OSMF, OpenTopoMap) und, wenn er will, das Issue bei CyclOSM.
2. **Wartet nicht auf die Antwort.** Die heutigen Regeln erlauben die Nutzung, wenn die App sie einhält. Die Einreichung im Store muss nicht warten.
3. Sagt ein Betreiber Nein oder bittet um weniger Last: Claude blendet diesen einen Stil im App-Store-Build aus (Rückfall auf Apple-Karten, wie Weg B, aber nur für diesen Stil). Das ist klein, siehe B-313 in `docs/APPSTORE.md`.
4. Antworten hier unten eintragen (Datum, wer, was).

## Brief an die OSMF (Englisch)

**An:** operations@osmfoundation.org
**Betreff:** Tile usage by the iPhone app "Wattspur" (App Store)

> Hello,
>
> I am the developer of Wattspur, a small free app for e-bike and motorcycle rides (macOS and iPhone, source on GitHub: https://github.com/hops-1/wattspur). The iPhone app is about to go from TestFlight to the App Store, and I would like to make sure our use of tile.openstreetmap.org is fine with you.
>
> How the app uses your tiles:
> - Apple Maps is the default. The OpenStreetMap style is an option that users pick themselves in the settings.
> - Only tiles that are on screen are loaded, never prefetched, no offline download.
> - The app caches tiles on disk and honours your Cache-Control headers.
> - User-Agent: "Wattspur/<version> (+https://github.com/hops-1/wattspur)", stable, with the project URL as contact.
> - "© OpenStreetMap contributors" is shown on every map.
>
> Expected use: today a few testers. After the release I expect a few hundred users at most in the first year, and only some of them will choose the OpenStreetMap style.
>
> If you would like us to change anything, or if there is a limit we should stay under, please let me know. If the load ever becomes a problem, I can switch the style off in an update.
>
> Thank you for running the tile servers.
>
> Best regards,
> Nils Wiese

## Brief an OpenTopoMap (Deutsch)

**An:** stefan@opentopomap.org
**Betreff:** OpenTopoMap in der iPhone-App „Wattspur“

> Hallo Stefan,
>
> ich entwickle Wattspur, eine kleine kostenlose App für Fahrten mit E-Bike und Motorrad (Mac und iPhone, Quellcode auf GitHub: https://github.com/hops-1/wattspur). OpenTopoMap ist dort einer der Kartenstile, vor allem wegen der Höhenlinien. Die iPhone-App kommt demnächst von TestFlight in den App Store. Auf eurer Seite steht, dass ihr euch über eine kurze Info freut, deshalb schreibe ich.
>
> So nutzt die App eure Kacheln:
> - Voreinstellung sind Apple-Karten. OpenTopoMap wählt man selbst in den Einstellungen.
> - Nur Kacheln, die gerade zu sehen sind, nichts vorausgeladen, kein Offline-Download.
> - Ein Cache auf dem Gerät, der euren Cache-Headern folgt.
> - Eigener User-Agent: „Wattspur/<Version> (+https://github.com/hops-1/wattspur)“.
> - Die Quellenangabe „Map data: © OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)“ steht auf jeder Karte.
>
> Ich rechne im ersten Jahr mit höchstens einigen hundert Nutzern, von denen nur ein Teil OpenTopoMap wählt. Wenn ihr etwas anders haben wollt oder eine Grenze nennt, passe ich die App an. Wird die Last zu groß, kann ich den Stil per Update abschalten.
>
> Danke für die schöne Karte!
>
> Viele Grüße
> Nils Wiese

## Issue bei CyclOSM (Englisch, öffentlich)

**Wo:** https://github.com/cyclosm/cyclosm-cartocss-style/issues › New issue
**Titel:** Using the CyclOSM tiles (OSM France) in an iPhone app on the App Store

> Hello,
>
> Wattspur (https://github.com/hops-1/wattspur) is a small free app for e-bike rides on macOS and iPhone. CyclOSM is one of its map styles, loaded from `{a,b,c}.tile-cyclosm.openstreetmap.fr/cyclosm`. The iPhone app is about to go to the App Store, and I would like to check that this is fine with the tile server at OpenStreetMap France, or where I should ask instead.
>
> Apple Maps is the default; CyclOSM is an option users pick themselves. Only tiles on screen are loaded (no prefetching, no offline download), the app caches tiles and honours the cache headers, its User-Agent is "Wattspur/<version> (+https://github.com/hops-1/wattspur)", and "© OpenStreetMap contributors · CyclOSM · Tiles OpenStreetMap France" is shown on the map. I expect a few hundred users at most in the first year.
>
> If you would rather the app didn't use the tiles, or want it to stay under a limit, just say so and I will change it.
>
> Thanks for CyclOSM!

## Antworten

| Datum | Betreiber | Antwort | Folge |
|---|---|---|---|
| | | | |
