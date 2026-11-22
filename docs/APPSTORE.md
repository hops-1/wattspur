# Wattspur im App Store

Stand: 22.11.2026 (1.6.4 (45) ist gewählt, eingereicht wird erst nach bestandenem Test im Auto: CarPlay ist am 22.11. geprüft, offen sind Auto-Start und die Punkte D.3, D.4 und F. 1.0 (26) kam am 16.11.2026 mit Rückfragen zurück und war nie im Store). Diese Anleitung erklärt, wie die App für iPhone und iPad von TestFlight in den App Store kommt: was schon da ist, welche Version es wird, was Nils in App Store Connect macht und was Claude vorbereitet.

Für TestFlight siehe `docs/learning/32-testflight.md`, für den Mac `docs/RELEASE.md`.

## Kurz gesagt

TestFlight und App Store nutzen **denselben Build**. Ein Build, der auf TestFlight läuft, kann ohne neuen Upload zur Prüfung für den App Store eingereicht werden. Neu sind vor allem die **Produktseite** (Texte, Screenshots, Kategorie, Altersfreigabe) und die **App-Prüfung** durch Apple. Die ist strenger als die Beta-Prüfung und dauert meist ein bis zwei Tage.

Der Weg jetzt:

1. Claude: Texte, Bildschirmfotos, Drehbuch, Checkliste (22.11.2026).
2. Nils: PR mergen lassen, Teil A und C des Videos aufnehmen.
3. Nils: Test im Auto, dabei Teil B des Videos.
4. Nils: App Store Connect nach der Checkliste unten ausfüllen und einreichen.
5. Nils: nach der Freigabe von Hand veröffentlichen.

## Welche Version

**Entscheidung Nils 22.11.2026: 1.6.4 (45), erst nach bestandenem Test im Auto.**

| Version | Dafür | Dagegen |
|---|---|---|
| **1.6.4 (45)** | CarPlay (B-340, B-327), Namensvorschlag (B-368), alle Fixes | Testfahrt am 22.11.2026: CarPlay bestanden, Auto-Start noch nicht geprüft |
| 1.6.3 (44) | Gemeinsame Texte, sonst wie 1.6.2 | Kein notiertes Testergebnis, kein CarPlay |
| 1.6.2 (43) | Letzte im Auto geprüfte Version (lange Fahrt ohne Abbruch, B-363 bis B-366) | Kein CarPlay, kein Namensvorschlag |
| 1.0 (26) | Schon einmal eingereicht | Ohne iPad, Auto-Start und viele Fixes |

Fällt der Test durch (`TESTANLEITUNG-1.6.4.md`, Abschnitt F), entscheidet Nils: Fix als 1.6.5 oder zurück auf 1.6.2 (43). Bei 1.6.2 müssen CarPlay und Namensvorschlag aus Texten, Hinweisen und Video wieder heraus.

## Was schon da ist

| Thema | Stand |
|---|---|
| Developer-Account, App „Wattspur“ in App Store Connect | ✓ angelegt (B-219). „Wattspur“ allein war im Store schon vergeben; Name im Store: „Wattspur - Touren Tracking“ (DE) und „Wattspur - Ride Tracker“ (EN), Entscheidung Nils 15.11.2026 |
| Bundle-IDs | ✓ App `io.github.hops-1.wattspur.ios`, Widgets `….ios.widgets`, Teilen `….ios.share` |
| Version und Build | ✓ in `Config/iOS.xcconfig`, für alle drei Targets gleich |
| Upload | ✓ Archiv und Export aus Xcode (Organizer) bzw. `xcodebuild archive` + `-exportArchive` (`method = app-store-connect`) |
| App-Icon | ✓ `App/Wattspur.icon` (Icon Composer), auch für den Store |
| Mindestversion | iOS 26.0, iPhone und iPad (`TARGETED_DEVICE_FAMILY = 1,2`). Das iPad nimmt nicht auf (B-293) |
| Exportkontrolle | ✓ `ITSAppUsesNonExemptEncryption = NO` (nur HTTPS und CloudKit) |
| Kategorie | – im Build nur beim Mac (`healthcare-fitness`); fürs iPhone wählt Nils sie in App Store Connect |
| Berechtigungstexte | ✓ Standort beim Verwenden (nie „Immer“, auch nicht für Auto-Start Stufe 1), Bewegung & Fitness (EN in `project.yml`, DE in `iOS/InfoPlist.xcstrings`) |
| Hintergrund | ✓ `UIBackgroundModes`: `location` (Aufnahme bei gesperrtem Bildschirm), `remote-notification` (stiller Push von CloudKit) |
| Live-Aktivität, Widget, Teilen-Erweiterung | ✓ eingebettet, App Group `group.io.github.hops-1.wattspur` |
| Health | – Wattspur liest Apple Health noch nicht (B-075). Kein HealthKit-Text nötig. Kommt Health, braucht es neue Texte und neue Datenschutzangaben |
| Datenschutzerklärung | ✓ `docs/PRIVACY.md` DE/EN, URL `https://github.com/hops-1/wattspur/blob/main/docs/PRIVACY.md` |
| App-Datenschutz („Nutrition Label“) | ✓ „Keine Daten erhoben“, schon für TestFlight eingetragen, bleibt mit 1.6.4 so. Die Ortssuche bei Apple (MapKit, Zeitzone am Mac, Ortsname am iPhone) ändert das nicht: Die Punkte gehen an Apple, nicht an den Entwickler oder einen Partner (geprüft 21.11.2026, S-47) |
| CloudKit | ✓ Schema in Production |
| Test-Werkzeuge | ✓ verschwinden im App-Store-Build von selbst (`BuildChannel.showsTestTools()`, B-298), zum Beispiel „Rohdaten der Bewegung“ |
| Beispielfahrt | ✓ anonymisiert; Prüfer sehen ohne eigene Daten etwas |

## Was fehlt

### Im Code und in den Texten (Claude)

1. ✓ **Privacy Manifest** (B-313): `PrivacyInfo.xcprivacy` in `iOS/`, `iOSWidgets/` und `iOSShare/`, XcodeGen nimmt sie als Ressource auf. Kein Tracking, keine erhobenen Daten. Gründe: App `UserDefaults` `CA92.1` und `1C8F.1` (App Group), Gerätelaufzeit `35F9.1` (Zeitstempel der Bewegungssensoren, `MotionRecorder`), Datei-Zeitstempel `3B52.1` (vom Benutzer gewählter Ordner, `FolderImport`); Widgets und Teilen-Erweiterung `UserDefaults` `1C8F.1`. Offen: nach dem nächsten Upload prüfen, ob Apple eine Warnmail (ITMS-91053) schickt.
2. ✓ **Datenschutzerklärung:** `docs/PRIVACY.md` nennt die OSM-Kartenstile (12.11.2026), dazu iPad, Standort in „Bereit“, Bewegungssensoren, Mitteilungen und die Voreinstellung von iCloud (22.11.2026).
3. ✓ **Support-Seite** `docs/SUPPORT.md` (DE/EN). URL für App Store Connect: `https://github.com/hops-1/wattspur/blob/main/docs/SUPPORT.md`
4. ✓ **Texte für die Produktseite** DE und EN in `docs/appstore/metadata/` (siehe unten).
5. ✓ **Screenshots** DE/EN mit `scripts/appstore-screenshots.sh` (B-317, siehe unten).
6. **Handbuch:** Kapitel 9 („iPhone und iCloud“) und die README nennen nur TestFlight. Nach der Freigabe: Link in den App Store.

### Zu klären (Recherche)

7. ✓ **Kartenkacheln im App Store** (V-19): **Entscheidung Nils 12.11.2026: Weg A, die Betreiber fragen.** Die OSM-Stile bleiben, Apple-Karten bleiben Voreinstellung. Neu gelesen: Die heutigen Regeln von OpenStreetMap erlauben Store-Apps mit eigenem User-Agent, OpenTopoMap erlaubt Apps und freut sich über eine Info, CyclOSM gilt „fair use“. Wattspur hält die Regeln ein. Briefe und Kontakte: `docs/appstore/KARTEN-ANFRAGE.md`. Die Einreichung wartet nicht auf die Antworten; sagt ein Betreiber Nein, wird nur dieser Stil im Store-Build ausgeblendet (B-315).

### In App Store Connect (Nils)

8. **Händlerstatus (EU, Digital Services Act).** Ohne Angabe ist die App in der EU nicht zu sehen. Ort: Checkliste, Punkt 2. Zur Wahl:
   - „Kein Händler“: für eine kostenlose App ohne Einnahmen meist passend. Es wird keine Adresse gezeigt.
   - „Händler“: Adresse, Telefon und E-Mail werden in der EU **öffentlich** auf der Produktseite gezeigt.
   Achtung: Mit dem In-App-Kauf (B-304) wird Wattspur sehr wahrscheinlich ein Händler-Angebot. Das ist eine Entscheidung von Nils; im Zweifel rechtlich prüfen.
9. **Produktseite, Altersfreigabe, Medizinprodukt, Preis, Prüfhinweise, Video** (Checkliste unten).

### Entscheidungen für Nils

- ✓ **Versionsnummer:** Die erste Store-Version ist ein eigenes kleines Release, **iPhone 1.0** (Build 26, 15.11.2026). Danach geht es mit 1.1 (Sportarten, mit Mac 1.9) weiter, siehe `BACKLOG.md`; Fehler aus der Prüfung kommen als 1.0.x. Die Mac-Nummer (1.8.x) bleibt davon unberührt.
- ✓ **Kartenstile im Store:** A, Betreiber fragen (Punkt 7).
- ✓ **Version für den Store** (22.11.2026): 1.6.4 (45) nach Test im Auto, siehe oben. Sie ersetzt 1.0 (26).
- ✓ **Links** (22.11.2026): Marketing-URL leer, die Beschreibung nennt die Support-Seite, die Support-Seite hat keine Spendenlinks. Auf GitHub bleiben sie.
- **Händler oder nicht** (Punkt 8). Auch Spenden können dabei zählen; im Zweifel rechtlich prüfen.
- **Länder:** alle oder erst Deutschland, Österreich, Schweiz. Die Texte gibt es DE und EN, die App ist DE und EN lokalisiert; Vorschlag: alle Länder.

## Checkliste für Nils

Das kann nur Nils. Alles unter [appstoreconnect.apple.com](https://appstoreconnect.apple.com). „Wattspur ›“ heißt: *Apps › Wattspur*. Die Namen sind aus Apples englischer Hilfe. Die deutschen Namen sind nicht am Konto geprüft und können etwas anders heißen.

### A. Vor App Store Connect

- [ ] **PR mit diesen Texten mergen lassen.** Datenschutz- und Support-Seite sind erst dann öffentlich.
- [ ] **Beide Seiten ohne Anmeldung öffnen** (privates Fenster): die zwei URLs aus `docs/appstore/metadata/de-DE/`.
- [ ] **Video Teil A und C** nach dem Drehbuch (`docs/appstore/REVIEW-VIDEO.html`, dazu Word und PDF).
- [ ] **Test im Auto:** `TESTANLEITUNG-1.6.4.md`, A bis F. Abschnitt F entscheidet, ob eingereicht wird.
- [ ] **Video Teil B**, danach schneiden und Bild für Bild auf private Daten prüfen.

### B. Einmal für Konto und App

- [ ] **1. Verträge.** *Geschäft (Business) › Vereinbarungen (Agreements)*: keine offene Vereinbarung. Den Vertrag für kostenpflichtige Apps braucht es erst für B-304.
- [ ] **2. Händlerstatus.** *Geschäft (Business) › Agreements › Compliance › Digital Services Act › Complete Compliance Requirements*. Danach je App prüfen: *Wattspur › Allgemein (General) › App Compliance › Digital Services Act*. Die Wahl erklärt Punkt 8 oben.
- [ ] **3. Name und Untertitel.** *Wattspur › Allgemein › App-Informationen (App Information)*: aus `name.txt` und `subtitle.txt`, je DE und EN. Der Untertitel ist neu.
- [ ] **4. Kategorie.** Ebenda: primär **Gesundheit und Fitness**, sekundär **Navigation**.
- [ ] **5. Inhaltsrechte (Content Rights).** Ebenda: „Ja, enthält Inhalte Dritter“ (Kartendaten) und bestätigen, dass die Rechte vorliegen.
- [ ] **6. Altersfreigabe.** Ebenda › *Age Ratings › Set Up Age Ratings* bzw. *Edit*. Fragen:
  - Kindersicherung, Altersprüfung: nein.
  - Uneingeschränkter Webzugang, Inhalte von Nutzern, soziale Medien, Chat, Standort teilen mit anderen, Werbung: nein. Die Aufnahme des eigenen Standorts ist kein Teilen.
  - Reife Themen, Sexualität, Gewalt, Glücksspiel, Wettbewerbe, Lootboxen: keine.
  - Medizinische Informationen oder Behandlung: keine. Fragt Apple getrennt nach **Gesundheits- oder Wellness-Themen**, die Frage genau lesen: Wattspur zeigt Puls und geschätzte Kalorien, gibt aber keinen Rat.
  - *Age Categories and Override*: „Not Applicable“. Erwartet: **4+**.
- [ ] **7. Medizinprodukt (Pflicht bei Gesundheit und Fitness).** *Wattspur › Allgemein › App Compliance › Regulated Medical Devices › Declare*: **Nein**.
- [ ] **8. App-Datenschutz.** *Wattspur › App-Datenschutz (App Privacy)*: „Keine Daten erhoben“ bleibt. Standort und Ortssuche zählen nicht: Nichts kommt beim Entwickler an, die Punkte für den Namen gehen nur an Apples MapKit. Bei *Privacy Policy › Edit* die URL aus `privacy_url.txt`, DE und EN.
- [ ] **9. Preis.** *Wattspur › Preise und Verfügbarkeit (Pricing and Availability) › Price Schedule*: **kostenlos**.
- [ ] **10. Verfügbarkeit.** Ebenda › *App Availability*: Länder wählen (Vorschlag: alle), keine Vorbestellung. Ist *iPhone-Apps auf dem Mac* angeboten, ausschalten: Dafür gibt es die Mac-App.
- [ ] **11. Bedienungshilfen (freiwillig).** *Wattspur › App Accessibility*: leer lassen oder nur angeben, was wirklich getestet ist.

### C. Die Version

- [ ] **12. Alte Einreichung.** *Wattspur › App-Prüfung (App Review) › Submissions*: Apples Nachricht vom 16.11.2026 noch einmal lesen. Lassen sich Version oder Build nicht ändern, die alte Einreichung mit *Cancel Submission* zurückziehen.
- [ ] **13. Versionsnummer.** *Wattspur › iOS-App 1.0*, Feld *Version*: auf **1.6.4** ändern. „+ Version“ gibt es erst, wenn eine Version im Store ist. „Neuigkeiten“ gibt es darum auch noch nicht.
- [ ] **14. Bildschirmfotos.** Versionsseite › *Previews and Screenshots*: alte löschen. iPhone 6,9 Zoll aus `dist/appstore-screenshots/`, iPad 13 Zoll aus `dist/appstore-screenshots-ipad/`, je DE und EN. Verlangt die Seite noch eine Größe, Claude fragen.
- [ ] **15. Texte.** Versionsseite, je DE und EN: Werbetext, Beschreibung, Schlüsselwörter, Support-URL aus den Dateien. **Marketing-URL leeren.** Copyright `2026 Nils Wiese`.
- [ ] **16. Build.** Versionsseite › *Build*: 26 entfernen, sichern, mit „+“ **45** wählen, sichern.
- [ ] **17. Export-Compliance.** Der Build bringt die Antwort mit (`ITSAppUsesNonExemptEncryption = NO`). Steht bei *TestFlight › Build 45* trotzdem „Missing Compliance“: nur ausgenommene Verschlüsselung von Apple (HTTPS, CloudKit).
- [ ] **18. Kontakt für die Prüfung.** Versionsseite › *App Review Information › Contact Information*: Name, Telefon mit `+49`, E-Mail. Nur dort, nie ins Repository.
- [ ] **19. Demo-Zugang.** Ebenda › *Sign-In Information*: Haken „Anmeldung erforderlich“ **aus**. Es gibt kein Konto.
- [ ] **20. Hinweise.** Ebenda › *Notes*: ganz ersetzen durch `docs/appstore/metadata/review_information/notes.txt`.
- [ ] **21. Video.** Ebenda › *Attachment*: die fertige Datei. Die Hinweise sagen „attached“, also nicht ohne Video einreichen.
- [ ] **22. Veröffentlichung.** Versionsseite › *App Store Version Release*: „Release the app yourself“ (manuell).

### D. Einreichen und veröffentlichen

- [ ] **23. Apple antworten.** Ist die Nachricht noch offen: *App Review › Resolve › Reply to App Review*. Text: „Thank you. We submit version 1.6.4 (45) instead of 1.0 (26). The review notes answer your questions in order, and the screen recording is attached.“ Das Video mit *Attach File* anhängen.
- [ ] **24. Zur Prüfung einreichen.** Versionsseite oben rechts *Add for Review*, dann *Draft Submissions › Submit for Review*. Bei einer offenen Ablehnung heißt der Knopf *Resubmit to App Review*.
- [ ] **25. Warten.** „Warten auf Prüfung“ › „In Prüfung“ › „Ausstehende Entwicklerfreigabe“. Nachrichten von Apple an Claude geben.
- [ ] **26. Veröffentlichen.** Versionsseite › *Release This Version › Confirm*.
- [ ] **27. Claude Bescheid geben:** Link in Handbuch und README (Rest von B-318).

TestFlight läuft danach weiter: Neue Versionen gehen erst an Nils und Freunde, dann mit „+ Version“ in den Store.

## Schritte für Claude

1. **Privacy Manifest** für App, Widgets, Teilen-Erweiterung anlegen, in `project.yml` eintragen, mit `xcodebuild archive` prüfen, dass es im Bundle liegt. Nach dem Upload prüft Nils, ob Apple eine Warnmail schickt.
2. **`docs/PRIVACY.md`** zu den Kartenstilen am iPhone korrigieren, Datum „Stand“ setzen; **Support-Seite** anlegen.
3. **Kartenstile** nach Nils' Entscheidung (Punkt 7): bei B einen Schalter wie `BuildChannel` nutzen, der die OSM-Stile im Store-Build ausblendet; die Wahl eines Nutzers fällt dann auf Apple-Karten zurück.
4. ✓ **Texte** DE/EN in `docs/appstore/metadata/`, Längen prüft `scripts/check-appstore-texts.sh`.
5. ✓ **Screenshots:** `scripts/appstore-screenshots.sh` baut Debug, legt einen eigenen Simulator „Wattspur Screenshots“ (iPhone 17 Pro Max, 6,9 Zoll, 1320 × 2868) an, löscht ihn vor jeder Sprache und macht je Sprache fünf Bilder (mit `--ipad` drei fürs iPad 13 Zoll, 2064 × 2752, nach `dist/appstore-screenshots-ipad/`) nach `dist/appstore-screenshots/<Sprache>/`: Übersicht, Tour-Detail, Karte aller Fahrten, Fahrtenliste, Aufnahme. Daten: 14 Kopien der anonymisierten Beispielfahrt bis heute (`-WattspurDemoRecent`), mit erfundenen Namen; die Aufnahme fährt eine simulierte Strecke in Berlin. Statusleiste 9:41, metrische Einheiten in beiden Sprachen. Die Bilder kommen nicht ins Repository; das Skript macht sie bei jeder Version neu (Dauer etwa 10 Minuten). Widget und Live-Aktivität auf dem Sperrbildschirm fehlen noch; die gehen nicht per Skript.
6. **Handbuch** EN/DE und README: Installation aus dem App Store, TestFlight nur noch für Tester.
7. **Release** wie gewohnt: Version in `Config/iOS.xcconfig`, Changelog, Archiv, Upload; danach Nils.

Nichts davon reicht Claude selbst in App Store Connect ein.

## Texte für die Produktseite

Die fertigen Texte DE/EN stehen in `docs/appstore/metadata/`, eine Datei pro Feld (B-316). Was wohin gehört, steht in `docs/appstore/README.md`. Nach jeder Änderung `scripts/check-appstore-texts.sh` laufen lassen: Es prüft die Längen und Namen anderer Marken in den Schlüsselwörtern (Richtlinie 2.3.7).

Die Hinweise für die App-Prüfung (Englisch) stehen in `docs/appstore/metadata/review_information/notes.txt`.

Am 16.11.2026 hat Apple 1.0 (26) mit **2.1 „Information Needed“** zurückgegeben. Gefragt waren: Bildschirmaufnahme von einem echten iPhone ab App-Start, Zweck und Zielgruppe, Bedienung, externe Dienste, regionale Unterschiede, Rechte an Material Dritter (PR #223). `notes.txt` antwortet in dieser Reihenfolge.

Was bei 1.6.4 besondere Hinweise braucht:

- **Neue Funktionen:** Richtlinie 2.3.1 will sie genau in den Hinweisen. Für schwer Nachstellbares (CarPlay) will Apple ein Video oder die Hardware.
- **Hintergrund-Standort (2.5.4):** Wattspur fragt nur „beim Verwenden“ und nutzt den Standort nur von Start bzw. „Bereit“ bis zum Ende, mit Live-Aktivität.
- **Auto-Start Stufe 1:** Eine Automation des Nutzers öffnet die App. Es gibt keine Überwachung im Hintergrund und kein „Standort Immer“. Das ändert sich mit Stufe 2 (B-312). Dann braucht es neue Hinweise, neue Datenschutz-Texte und ein neues Video.
- **Test-Werkzeuge:** `BuildChannel` zeigt sie überall außerhalb der Production-Umgebung. Vermutlich sieht sie darum auch der Prüfer (Apple dokumentiert dessen Umgebung nicht). Die Hinweise erklären sie.
- **Link auf GitHub:** *Mehr › Über Wattspur* führt auf die Projektseite mit Sponsor-Knopf (B-362). Das bleibt ein kleines Risiko nach 3.1.1. Beanstandet Apple es, braucht es einen neuen Build ohne diesen Link.

**CarPlay (ab iOS 1.6.4, B-340, B-327):** Apple hat Wattspur am 22.11.2026 als „CarPlay Driving Task App“ freigegeben. Die Berechtigung `com.apple.developer.carplay-driving-task` steht nur in `iOS/Wattspur-iOS-iCloud.entitlements`, also nur in Builds mit dem Developer-Account. Die automatische Signierung von Xcode holt das passende Profil selbst (geprüft 22.11.2026 mit `xcodebuild archive -allowProvisioningUpdates`); ein manuelles Profil ist nicht nötig. Für die Prüfung gilt: nur Aufgaben während der Fahrt (Start, Pause, Ende, Fahrzeug, eine Tafel mit wenigen Werten), keine Karte, nichts zum Lesen, die Tafel höchstens alle 5 s neu. Der Hinweis für die Prüfer steht in `notes.txt` unter „How to use it“.

## Häufige Gründe für eine Ablehnung (und wie Wattspur dasteht)

| Richtlinie | Thema | Wattspur |
|---|---|---|
| 2.1 | App unvollständig, Absturz, Platzhalter, Angaben fehlen | Beispielfahrt in der Übersicht, Beispieldatei in den Hinweisen, Video; Test-Werkzeuge im Store aus |
| 2.3.1 | Neue Funktion nicht erklärt | CarPlay, Auto-Start und Namensvorschlag stehen in den Hinweisen |
| 2.3 | Screenshots oder Texte passen nicht zur App | Screenshots aus der echten App, Beschreibung ohne Versprechen von später |
| 2.5.4 | Hintergrund-Standort ohne klaren Zweck | Nur während Aufnahme und „Bereit“, Live-Aktivität, Hinweis an Prüfer |
| 3.1.1 | Links zu Zahlungswegen außerhalb von In-App-Käufen | Store-Links ohne Spenden; der Link auf GitHub in der App bleibt ein kleines Risiko |
| 5.1.1 | Datenschutz-URL fehlt, Berechtigungstexte unklar | URL da, Texte erklären den Zweck |
| 5.1.2 | Datenangaben falsch | „Keine Daten erhoben“, stimmt solange kein eigener Dienst dazukommt |
| CarPlay | App zeigt mehr als die Aufgabe beim Fahren | Nur Steuerung der Aufnahme und eine Tafel, Vorlagen von Apple, keine Karte |
| ITMS-91053 | Privacy Manifest fehlt | ✓ angelegt, nach dem Upload prüfen |

## Stories im Backlog

Die Stories stehen jetzt in `BACKLOG.md` unter „iOS 1.0 – App Store“. Hier standen sie zuerst als Vorschlag mit anderen Nummern; B-311, B-312 und V-18 waren dort schon für den Auto-Start vergeben. Neue Nummern (Nils 15.11.2026):

| Neu | Zuerst | Story | Stand |
|---|---|---|---|
| B-313 | B-311 | Privacy Manifest für App, Widgets, Teilen-Erweiterung | ☑ |
| B-314 | B-312 | Datenschutz und Support-Seite | ☑ |
| V-19 | V-18 | Kartenkacheln im App Store (Betreiber fragen) | ◐ |
| B-315 | B-313 | Kartenstile im Store-Build, nur bei einem Nein aus V-19 | ☐ |
| B-316 | B-314 | Produktseite DE/EN | ☑ |
| B-317 | B-315 | Screenshots 6,9 Zoll DE/EN per Skript | ☑ |
| B-318 | B-316 | Erste Einreichung im App Store, danach Link im Handbuch | ◐ |

In älteren PRs (#208 bis #211) und in Code-Kommentaren stehen noch die alten Nummern. Der In-App-Kauf (B-304) ist für den Store **nicht** nötig und kann später kommen.

## Warum so

- **Erst TestFlight, dann Store:** Der Build ist schon geprüft und bei Nils und Freunden gelaufen. Der Store braucht keinen anderen Build, nur mehr Angaben.
- **Manuelle Freigabe:** Nils entscheidet, wann die App erscheint, zum Beispiel zusammen mit dem passenden Mac-DMG.
- **Kostenlos ohne In-App-Kauf zuerst:** Kein Vertrag für kostenpflichtige Apps, keine Steuer- und Bankangaben, und „Kein Händler“ bleibt möglich.
- **Privacy Manifest jetzt:** Es ist klein, aber ohne es kann Apple den Upload ablehnen. Das will man nicht erst am Tag der Einreichung merken.
