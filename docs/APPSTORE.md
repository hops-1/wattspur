# Wattspur im App Store

Stand: 12.11.2026 (iPhone 0.7.1 (25) auf TestFlight). Diese Anleitung erklärt, wie die iPhone-App von TestFlight in den App Store kommt: was schon da ist, was fehlt, was Nils in App Store Connect macht und was Claude im Code vorbereitet.

Für TestFlight siehe `docs/learning/32-testflight.md`, für den Mac `docs/RELEASE.md`.

## Kurz gesagt

TestFlight und App Store nutzen **denselben Build**. Ein Build, der auf TestFlight läuft, kann ohne neuen Upload zur Prüfung für den App Store eingereicht werden. Neu sind vor allem die **Produktseite** (Texte, Screenshots, Kategorie, Altersfreigabe) und die **App-Prüfung** durch Apple. Die ist strenger als die Beta-Prüfung und dauert meist ein bis zwei Tage.

Der Weg in fünf Schritten:

1. Claude: Lücken im Code schließen (vor allem Privacy Manifest, siehe unten).
2. Claude: Texte DE/EN und Screenshots vorbereiten.
3. Nils: Produktseite in App Store Connect ausfüllen.
4. Nils: Build wählen und zur Prüfung einreichen.
5. Nils: nach der Freigabe veröffentlichen (am besten von Hand).

## Was schon da ist

| Thema | Stand |
|---|---|
| Developer-Account, App „Wattspur“ in App Store Connect | ✓ angelegt (B-219), Name damit reserviert |
| Bundle-IDs | ✓ App `io.github.hops-1.wattspur.ios`, Widgets `….ios.widgets`, Teilen `….ios.share` |
| Version und Build | ✓ in `Config/iOS.xcconfig`, für alle drei Targets gleich |
| Upload | ✓ Archiv und Export aus Xcode (Organizer) bzw. `xcodebuild archive` + `-exportArchive` (`method = app-store-connect`) |
| App-Icon | ✓ `App/Wattspur.icon` (Icon Composer), auch für den Store |
| Mindestversion | iOS 26.0, nur iPhone (`TARGETED_DEVICE_FAMILY = 1`) |
| Exportkontrolle | ✓ `ITSAppUsesNonExemptEncryption = NO` (nur HTTPS und CloudKit) |
| Kategorie | – im Build nur beim Mac (`healthcare-fitness`); fürs iPhone wählt Nils sie in App Store Connect |
| Berechtigungstexte | ✓ Standort beim Verwenden, Bewegung & Fitness (EN in `project.yml`, DE in `iOS/InfoPlist.xcstrings`) |
| Hintergrund | ✓ `UIBackgroundModes`: `location` (Aufnahme bei gesperrtem Bildschirm), `remote-notification` (stiller Push von CloudKit) |
| Live-Aktivität, Widget, Teilen-Erweiterung | ✓ eingebettet, App Group `group.io.github.hops-1.wattspur` |
| Health | – Wattspur liest Apple Health noch nicht (B-075). Kein HealthKit-Text nötig. Kommt Health, braucht es neue Texte und neue Datenschutzangaben |
| Datenschutzerklärung | ✓ `docs/PRIVACY.md` DE/EN, URL `https://github.com/hops-1/wattspur/blob/main/docs/PRIVACY.md` |
| App-Datenschutz („Nutrition Label“) | ✓ „Keine Daten erhoben“, schon für TestFlight eingetragen |
| CloudKit | ✓ Schema in Production |
| Test-Werkzeuge | ✓ verschwinden im App-Store-Build von selbst (`BuildChannel.showsTestTools()`, B-298), zum Beispiel „Rohdaten der Bewegung“ |
| Beispielfahrt | ✓ anonymisiert; Prüfer sehen ohne eigene Daten etwas |

## Was fehlt

### Im Code und in den Texten (Claude)

1. ✓ **Privacy Manifest** (B-311): `PrivacyInfo.xcprivacy` in `iOS/`, `iOSWidgets/` und `iOSShare/`, XcodeGen nimmt sie als Ressource auf. Kein Tracking, keine erhobenen Daten. Gründe: App `UserDefaults` `CA92.1` und `1C8F.1` (App Group), Gerätelaufzeit `35F9.1` (Zeitstempel der Bewegungssensoren, `MotionRecorder`), Datei-Zeitstempel `3B52.1` (vom Benutzer gewählter Ordner, `FolderImport`); Widgets und Teilen-Erweiterung `UserDefaults` `1C8F.1`. Offen: nach dem nächsten Upload prüfen, ob Apple eine Warnmail (ITMS-91053) schickt.
2. ✓ **Datenschutzerklärung:** `docs/PRIVACY.md` nennt die OSM-Kartenstile jetzt für Mac und iPhone (Stand 12.11.2026).
3. ✓ **Support-Seite** `docs/SUPPORT.md` (DE/EN). URL für App Store Connect: `https://github.com/hops-1/wattspur/blob/main/docs/SUPPORT.md`
4. **Texte für die Produktseite** DE und EN (Entwurf unten): Name, Untertitel, Werbetext, Beschreibung, Schlüsselwörter, Neuigkeiten.
5. **Screenshots** (siehe unten).
6. **Handbuch:** Kapitel 9 („iPhone und iCloud“) und die README nennen nur TestFlight. Nach der Freigabe: Link in den App Store.

### Zu klären (Recherche)

7. ✓ **Kartenkacheln im App Store** (V-18): **Entscheidung Nils 12.11.2026: Weg A, die Betreiber fragen.** Die OSM-Stile bleiben, Apple-Karten bleiben Voreinstellung. Neu gelesen: Die heutigen Regeln von OpenStreetMap erlauben Store-Apps mit eigenem User-Agent, OpenTopoMap erlaubt Apps und freut sich über eine Info, CyclOSM gilt „fair use“. Wattspur hält die Regeln ein. Briefe und Kontakte: `docs/appstore/KARTEN-ANFRAGE.md`. Die Einreichung wartet nicht auf die Antworten; sagt ein Betreiber Nein, wird nur dieser Stil im Store-Build ausgeblendet (B-313).

### In App Store Connect (Nils)

8. **Händlerstatus (EU, Digital Services Act).** Ohne Angabe ist die App in der EU nicht zu sehen. Unter *Business* (bzw. *Geschäft*) › Händlerstatus wählen:
   - „Kein Händler“: für eine kostenlose App ohne Einnahmen meist passend. Es wird keine Adresse gezeigt.
   - „Händler“: Adresse, Telefon und E-Mail werden in der EU **öffentlich** auf der Produktseite gezeigt.
   Achtung: Mit dem In-App-Kauf (B-304) wird Wattspur sehr wahrscheinlich ein Händler-Angebot. Das ist eine Entscheidung von Nils; im Zweifel rechtlich prüfen.
9. **Produktseite, Altersfreigabe, Preis, Prüfhinweise** (Schritte unten).

### Entscheidungen für Nils

- **Versionsnummer:** Der Store nimmt auch 0.7.1. Vorschlag: Die erste Store-Version ist ein eigenes kleines Release mit den Lücken von oben, als **iPhone 1.0** (zeigt „fertig“), danach geht es normal weiter. Alternative: mit der nächsten geplanten Version (0.8, Sportarten) in den Store. Die Mac-Nummer (1.8.x) bleibt davon unberührt.
- ✓ **Kartenstile im Store:** A, Betreiber fragen (Punkt 7).
- **Händler oder nicht** (Punkt 8).
- **Länder:** alle oder erst Deutschland, Österreich, Schweiz. Die Texte gibt es DE und EN, die App ist DE und EN lokalisiert; Vorschlag: alle Länder.

## Schritte für Nils in App Store Connect

Alles unter [appstoreconnect.apple.com](https://appstoreconnect.apple.com) › Apps › Wattspur. Dauer beim ersten Mal etwa eine Stunde, dazu ein bis zwei Tage Warten auf Apple.

1. **Verträge:** *Business* › Vereinbarungen: Die Vereinbarung für kostenlose Apps ist mit der Mitgliedschaft schon akzeptiert. Den Vertrag für kostenpflichtige Apps (mit Steuer und Bank) braucht es erst für den In-App-Kauf (B-304).
2. **Händlerstatus** setzen (Punkt 8 oben).
3. **App-Informationen** (links unter *Allgemein*):
   - Name: Wattspur; Untertitel (bis 30 Zeichen) aus dem Entwurf.
   - Kategorie: primär **Gesundheit und Fitness**, sekundär **Navigation** (oder Sport).
   - Inhaltsrechte: „Ja, enthält Inhalte Dritter“ (Kartendaten von OpenStreetMap und Apple, mit Quellenangabe) und bestätigen, dass die Rechte vorliegen.
   - **Altersfreigabe:** Fragebogen ausfüllen, überall „Nein“/„Keine“ (keine Gewalt, keine Glücksspiele, kein offener Internetzugang, keine Chats, keine nutzergenerierten Inhalte für andere). Ergebnis: **4+**.
   - Lizenzvereinbarung: Standard-EULA von Apple reicht.
4. **App-Datenschutz:** steht schon („Keine Daten erhoben“). Datenschutz-URL prüfen. Optional: *Bedienungshilfen* („Accessibility Nutrition Labels“) für VoiceOver, Dynamische Schrift, Dunkelmodus angeben; nur, was wirklich getestet ist (B-170, Kapitel 7).
5. **Preise und Verfügbarkeit:** Preis **kostenlos**, Länder wählen. Vorbestellung nein.
6. **Version anlegen:** links *iOS-App* › `+ Version`, Nummer wie im Build (z. B. 1.0).
   - Screenshots für **iPhone 6,9 Zoll** hochladen (von Claude). Kleinere Größen rechnet Apple selbst.
   - Werbetext, Beschreibung, Schlüsselwörter, Support-URL, Marketing-URL (optional: GitHub-Seite) auf Deutsch eintragen; oben rechts die Sprache **Englisch** hinzufügen und dort die englischen Texte.
   - Copyright: `2026 Nils Wiese`.
   - **Build** wählen: den neuesten TestFlight-Build dieser Version.
   - **App-Prüfungsinformationen:** Anmeldung nicht nötig (Haken bei „Anmeldung erforderlich“ weg). Kontakt: Name, Telefon, E-Mail von Nils (sieht nur Apple). Hinweise: Text unten einfügen.
   - **Freigabe der Version:** „Diese Version manuell freigeben“. So kann Nils nach der Prüfung selbst den Tag wählen.
7. **Zur Prüfung einreichen** (oben rechts *Zur Prüfung hinzufügen* › *Einreichen*).
8. **Warten:** „Warten auf Prüfung“ → „In Prüfung“ → „Ausstehende Entwicklerfreigabe“. Bei Ablehnung steht der Grund unter *Nachrichten*; Claude hilft bei der Antwort.
9. **Veröffentlichen:** *Diese Version freigeben*. Nach einigen Stunden ist die App im Store. Optional „Stufenweise Veröffentlichung“ (7 Tage) für spätere Updates.

TestFlight läuft danach weiter: Neue Versionen gehen erst an Nils und Freunde, dann mit „+ Version“ in den Store.

## Schritte für Claude

1. **Privacy Manifest** für App, Widgets, Teilen-Erweiterung anlegen, in `project.yml` eintragen, mit `xcodebuild archive` prüfen, dass es im Bundle liegt. Nach dem Upload prüft Nils, ob Apple eine Warnmail schickt.
2. **`docs/PRIVACY.md`** zu den Kartenstilen am iPhone korrigieren, Datum „Stand“ setzen; **Support-Seite** anlegen.
3. **Kartenstile** nach Nils' Entscheidung (Punkt 7): bei B einen Schalter wie `BuildChannel` nutzen, der die OSM-Stile im Store-Build ausblendet; die Wahl eines Nutzers fällt dann auf Apple-Karten zurück.
4. **Texte** DE/EN als Datei `docs/appstore/` (Entwürfe unten), Längen prüfen (Untertitel 30, Werbetext 170, Schlüsselwörter 100, Beschreibung 4000 Zeichen).
5. **Screenshots:** im Simulator „iPhone 17 Pro Max“ (6,9 Zoll, 1320 × 2868 Pixel, hochkant), mit der Beispielfahrt und Demo-Fahrten (`-WattspurDemoRide YES`, `-WattspurDemoRides`), Statusleiste sauber (`xcrun simctl status_bar … override --time 9:41 --batteryLevel 100`), je Sprache 5 bis 6 Bilder: Übersicht, Fahrtenliste, Tour-Detail mit Karte und Höhenprofil, Aufnahme, Karte aller Fahrten, Widget/Live-Aktivität. Keine echten Fahrten von Nils, keine Bosch-Bildschirme (NFR-12). Als Skript, damit es bei jeder Version gleich geht.
6. **Handbuch** EN/DE und README: Installation aus dem App Store, TestFlight nur noch für Tester.
7. **Release** wie gewohnt: Version in `Config/iOS.xcconfig`, Changelog, Archiv, Upload; danach Nils.

Nichts davon reicht Claude selbst in App Store Connect ein.

## Entwürfe

### Untertitel (bis 30 Zeichen)
- DE: `Deine E-Bike-Fahrten` (20)
- EN: `Your e-bike rides` (17)

### Werbetext (bis 170 Zeichen)
- DE: Zeichne deine Fahrten per GPS auf oder importiere FIT und GPX. Karte, Höhenprofil und Wochenziel – ohne Konto, ohne Werbung, alles in deinem eigenen iCloud.
- EN: Record rides with GPS or import FIT and GPX. Map, elevation profile and weekly goal – no account, no ads, everything in your own iCloud.

### Beschreibung (Anfang)
- DE: Wattspur zeigt deine E-Bike-Fahrten übersichtlich: Strecke, Zeit, Höhenmeter, Tempo und, wenn vorhanden, Leistung, Puls und Trittfrequenz. Fahrten kommen aus der eigenen GPS-Aufnahme (auch bei gesperrtem Bildschirm, mit Live-Aktivität), aus FIT- und GPX-Dateien oder per „Teilen“ aus anderen Apps. Mit der Mac-App teilt Wattspur eine Bibliothek in deinem privaten iCloud-Konto. Es gibt kein Konto bei Wattspur, keinen Server, keine Werbung und kein Tracking.
- EN: Wattspur shows your e-bike rides at a glance: distance, time, climb, speed and, if recorded, power, heart rate and cadence. Rides come from the built-in GPS recording (also with the screen locked, with a Live Activity), from FIT and GPX files, or shared from other apps. With the Mac app, Wattspur shares one library in your private iCloud account. No Wattspur account, no server, no ads, no tracking.

### Schlüsselwörter (bis 100 Zeichen, mit Komma, ohne Leerzeichen)
- DE: `ebike,fahrrad,pedelec,gps,tracker,fit,gpx,radtour,höhenprofil,strava,flow,bosch,touren`
- EN: `ebike,bike,cycling,gps,tracker,fit,gpx,ride,elevation,route,pedelec,commute`

Markennamen anderer (Bosch, Strava, Flow) nur, wenn Wattspur sie wirklich unterstützt; sonst lehnt Apple ab (Richtlinie 2.3.7). Vor dem Einreichen prüfen.

### Hinweise für die App-Prüfung (Englisch)
> No sign-in required. Without any data the overview shows an anonymized sample ride. GPS recording starts with "Start Ride" on the overview. The app uses location in the background only while a recording runs, so the ride keeps recording with the screen locked; it shows a Live Activity during that time and stops with "Stop". Location permission is "While Using the App". Motion & Fitness is used for the barometer height of a recording. FIT and GPX files can be imported with "+" in "Rides" or shared to Wattspur from other apps (any GPX file with a track works). Sync uses the user's private CloudKit database only; there is no server of our own and no data is collected.

Die Begründung des Hintergrund-Standorts ist wichtig: Apple prüft `UIBackgroundModes = location` genau (Richtlinie 2.5.4). Wattspur fragt nur „beim Verwenden“ und nimmt nur zwischen Start und Stopp auf; das passt.

## Häufige Gründe für eine Ablehnung (und wie Wattspur dasteht)

| Richtlinie | Thema | Wattspur |
|---|---|---|
| 2.1 | App unvollständig, Absturz, Platzhalter | Beispielfahrt zeigt etwas ohne Daten; Test-Werkzeuge im Store-Build aus |
| 2.3 | Screenshots oder Texte passen nicht zur App | Screenshots aus der echten App, Beschreibung ohne Versprechen von später |
| 2.5.4 | Hintergrund-Standort ohne klaren Zweck | Nur während der Aufnahme, Live-Aktivität, Hinweis an Prüfer |
| 5.1.1 | Datenschutz-URL fehlt, Berechtigungstexte unklar | URL da, Texte erklären den Zweck |
| 5.1.2 | Datenangaben falsch | „Keine Daten erhoben“, stimmt solange kein eigener Dienst dazukommt |
| ITMS-91053 | Privacy Manifest fehlt | ✓ angelegt, nach dem Upload prüfen |

## Vorschlag für Backlog-Stories

Höchste Nummern am 12.11.2026: B-310 und V-17. Die Nummern unten sind nur ein Vorschlag; vor dem Eintragen mit dem dann aktuellen Backlog abgleichen (die Planung für iPhone 0.8 kann neue Nummern vergeben).

| Vorschlag | Story | Größe | Wer |
|---|---|---|---|
| B-311 | **Privacy Manifest** für App, Widgets, Teilen-Erweiterung. Fertig, wenn: die drei `PrivacyInfo.xcprivacy` im Archiv liegen und ein Upload ohne Warnmail von Apple durchgeht | S | Claude |
| B-312 | **Datenschutz und Support:** `PRIVACY.md` zu den Kartenstilen am iPhone, Support-Seite DE/EN. Fertig, wenn: beide URLs in App Store Connect funktionieren | S | Claude |
| V-18 | **Kartenkacheln im App Store:** Regeln von OSM, CyclOSM, OpenTopoMap für eine Store-App nachlesen, Entscheidung A/B/C mit Nils (Ergebnis in `RECHERCHE-KARTEN.md`) | S | Claude + Nils |
| B-313 | **Kartenstile im Store-Build** nach V-18: nur nötig, wenn ein Betreiber Nein sagt; dann diesen Stil im Store-Build ausblenden, Rückfall auf Apple-Karten | S | Claude |
| B-314 | **Produktseite DE/EN:** Untertitel, Werbetext, Beschreibung, Schlüsselwörter, Neuigkeiten, Prüfhinweise. Fertig, wenn: die Texte in `docs/appstore/` stehen und die Längen passen | S | Claude |
| B-315 | **Screenshots 6,9 Zoll DE/EN** per Skript aus dem Simulator mit Demo-Daten | M | Claude |
| B-316 | **Erste Einreichung im App Store:** Händlerstatus, App-Informationen, Altersfreigabe, Preis, Version, Einreichen, manuelle Freigabe; Handbuch und README mit Link in den Store. Fertig, wenn: Wattspur im App Store zu finden ist | S | Nils (+ Claude fürs Handbuch) |

Vorschlag für die Reihenfolge: V-18 und B-311 zuerst (die einzigen echten Hürden), dann B-312 bis B-315, dann B-316 mit dem nächsten iPhone-Release. Der In-App-Kauf (B-304) ist für den Store **nicht** nötig und kann später kommen.

## Warum so

- **Erst TestFlight, dann Store:** Der Build ist schon geprüft und bei Nils und Freunden gelaufen. Der Store braucht keinen anderen Build, nur mehr Angaben.
- **Manuelle Freigabe:** Nils entscheidet, wann die App erscheint, zum Beispiel zusammen mit dem passenden Mac-DMG.
- **Kostenlos ohne In-App-Kauf zuerst:** Kein Vertrag für kostenpflichtige Apps, keine Steuer- und Bankangaben, und „Kein Händler“ bleibt möglich.
- **Privacy Manifest jetzt:** Es ist klein, aber ohne es kann Apple den Upload ablehnen. Das will man nicht erst am Tag der Einreichung merken.
