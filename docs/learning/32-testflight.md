# 32 – TestFlight: die iPhone-App für Nils und Freunde

Story: B-219 (iOS 0.3, Plan vom 2.11.2026, REQUIREMENTS 10.22). Vorbereitet, solange der Developer-Account noch geprüft wird; die Schritte in App Store Connect gehen erst danach.

## Worum es geht
Bis iOS 0.2 kam die App mit der kostenlosen Apple-ID per Kabel aufs iPhone (Kapitel 30). Das hat zwei Grenzen: Die App läuft nach **7 Tagen** ab, und Freunde müssten ihr iPhone an Nils' Mac anschließen. **TestFlight** ist Apples Weg für Testversionen: Nils lädt ein Archiv in **App Store Connect** hoch, Tester installieren es mit der App *TestFlight* aus dem App Store. Eine Testversion läuft **90 Tage**, danach braucht es eine neue.

- **Interne Tester:** Mitglieder des eigenen Teams in App Store Connect, hier nur Nils. Ohne Prüfung durch Apple, die Version ist wenige Minuten nach dem Hochladen da.
- **Externe Tester:** alle anderen, bis zu 10.000, per E-Mail-Einladung oder öffentlichem Link. Die **erste** Version einer neuen App-Version (zum Beispiel 0.3.0) geht durch die **Beta-App-Prüfung** von Apple, meist in einem Tag. Weitere Builds derselben Version brauchen sie oft nicht.

## Einmalig: App in App Store Connect anlegen
Voraussetzung: Der Developer-Account ist aktiv, und Xcode kennt ihn (Xcode › Settings › Accounts).

1. **App-ID:** developer.apple.com › Certificates, Identifiers & Profiles › Identifiers. `io.github.hops-1.wattspur.ios` mit der Capability **iCloud (CloudKit)** und dem Container `iCloud.io.github.hops-1.wattspur`, dazu **Push Notifications** (CloudKit meldet Änderungen per stiller Push-Nachricht). Mit „Automatically manage signing“ in Xcode entsteht die App-ID beim ersten Archiv von selbst; die Capabilities kommen mit den Entitlements (B-216).
2. **App anlegen:** [appstoreconnect.apple.com](https://appstoreconnect.apple.com) › Apps › `+` › Neue App.
   - Plattform: iOS
   - Name: **Wattspur** (muss im App Store frei sein; sonst zum Beispiel „Wattspur – eBike-Fahrten“)
   - Primäre Sprache: Deutsch
   - Bundle-ID: `io.github.hops-1.wattspur.ios`
   - SKU: `wattspur-ios` (nur intern, frei wählbar)
   - Zugriff: Voller Zugriff
3. **App-Datenschutz** ausfüllen (Texte unten) und die URL zur Datenschutzerklärung eintragen.
4. **TestFlight › Testinformationen:** Beschreibung der Beta, E-Mail für Feedback, Hinweise zum Testen (Texte unten).

## Jede Version: Archiv hochladen
1. `MARKETING_VERSION` des Targets *Wattspur iOS* in `project.yml` setzen (zum Beispiel `0.3.0`). Die Build-Nummer (`CURRENT_PROJECT_VERSION`) muss je Upload steigen; App Store Connect lehnt eine schon benutzte Nummer ab.
2. `xcodegen generate`, dann in Xcode das Schema **Wattspur iOS** und als Ziel **Any iOS Device (arm64)** wählen.
3. **Product › Archive.** Danach öffnet sich der Organizer.
4. **Distribute App › TestFlight & App Store › Distribute.** Xcode signiert mit dem Distribution-Zertifikat (legt es beim ersten Mal selbst an) und lädt hoch.
5. Nach 5 bis 30 Minuten erscheint der Build in App Store Connect unter *TestFlight*, zuerst als „Wird verarbeitet“.
6. **Exportvorschriften:** Wattspur nutzt Verschlüsselung nur über Apples Schnittstellen (HTTPS, CloudKit). Dafür steht `ITSAppUsesNonExemptEncryption = NO` in den Build-Einstellungen, die Frage kommt dann nicht bei jedem Build.

Ohne Xcode-Oberfläche geht dasselbe mit `xcodebuild archive` und `xcodebuild -exportArchive` mit `method = app-store-connect` und `destination = upload`. Für ein paar Builds im Monat ist der Organizer einfacher.

## Tester einladen
- **Intern (Nils):** TestFlight › Interne Tests › `+` Gruppe „Nils“ › Tester hinzufügen. Auf dem iPhone die App *TestFlight* installieren, mit derselben Apple-ID anmelden, Wattspur installieren.
- **Extern (Freunde):** TestFlight › Externe Tests › `+` Gruppe „Freunde“ › Build hinzufügen › „Zur Prüfung einreichen“. Danach Tester per E-Mail einladen oder einen **öffentlichen Link** erzeugen und weitergeben.
- Die Kabel-Installation aus Kapitel 30 braucht es dann nicht mehr. Sie geht weiter, kollidiert aber mit der TestFlight-Version, weil beide dieselbe Bundle-ID haben: Erst die eine löschen, dann die andere installieren. Die Fahrten liegen ab iOS 0.3 in iCloud und kommen nach dem Wechsel zurück.

## Texte für App Store Connect

### App-Datenschutz („Datenschutzangaben“)
Apple fragt, welche Daten **erhoben** werden. „Erhoben“ heißt bei Apple: Die Daten verlassen das Gerät so, dass der Entwickler oder Dritte länger an sie herankommen, als für die Anfrage nötig. Bei Wattspur ist das nicht so:

- Die Fahrten (mit GPS-Route, Tempo, Leistung, Puls, Trittfrequenz) bleiben auf dem Gerät und, wenn der Sync an ist, in der **privaten Datenbank des eigenen iCloud-Kontos**. Auf diese Datenbank hat nur der Nutzer Zugriff; Nils als Entwickler sieht sie nicht, auch nicht in der CloudKit Console.
- Es gibt keinen eigenen Server, kein Konto bei Wattspur, keine Werbung, keine Analyse und kein Tracking.
- Kartenkacheln laden Apple (MapKit) bzw. auf dem Mac die Kartenserver aus den Kartenstilen; dabei geht nur der Kartenausschnitt hinaus, keine Fahrt.

**Antwort in App Store Connect:** „Nein, wir erheben keine Daten von dieser App“ → Label **„Keine Daten erhoben“** („Data Not Collected“).

Kommt später etwas dazu, das Daten vom Gerät an Nils oder Dritte schickt (zum Beispiel Absturzberichte über einen eigenen Dienst, ein Webserver für B-088 oder Teilen mit Freunden über B-231), müssen die Angaben neu geprüft werden. Absturzberichte und Feedback über TestFlight selbst zählen nicht, die laufen über Apple.

### Datenschutzerklärung
App Store Connect verlangt eine URL zur Datenschutzerklärung, auch für externe Tests. Der Text steht in `docs/PRIVACY.md` (Deutsch und Englisch). URL:
`https://github.com/hops-1/wattspur/blob/main/docs/PRIVACY.md`

### Hinweistexte für die Berechtigungen
Diese Sätze zeigt iOS, wenn Wattspur fragt. Sie stehen in `project.yml` und `iOS/InfoPlist.xcstrings`:

| Berechtigung | Text (EN) | Text (DE) |
|---|---|---|
| Standort beim Verwenden | Wattspur records your ride with GPS, also while the screen is locked. | Wattspur zeichnet deine Fahrt per GPS auf, auch bei gesperrtem Bildschirm. |
| Bewegung & Fitness (ab iOS 0.4, B-235) | Wattspur measures the height of your ride with the barometer, for a more exact ascent. | Wattspur misst die Höhe deiner Fahrt mit dem Barometer, für einen genaueren Anstieg. |

Fitnessdaten aus Apple Health liest Wattspur noch nicht (B-075). Kommt das, braucht es `NSHealthShareUsageDescription`, etwa: „Wattspur liest Puls und Fahrten aus Health, um sie neben deinen E-Bike-Fahrten zu zeigen. Die Daten bleiben auf deinem iPhone und in deinem iCloud-Konto.“

### Beschreibung der Beta (TestFlight › Testinformationen)
> Wattspur zeigt deine E-Bike-Fahrten auf dem iPhone: Übersicht der Woche, alle Fahrten mit Karte und Höhenprofil, und eine eigene GPS-Aufnahme. Mit der Mac-App teilt sie eine Datenbank in deinem eigenen iCloud-Konto: Fahrten, die du am Mac importierst, erscheinen auf dem iPhone und umgekehrt. Es gibt keinen Wattspur-Server und kein Konto.

### Was zu testen ist
> Bitte probiere: eine Fahrt aufnehmen (auch mit gesperrtem Bildschirm), sie danach in der Liste und am Mac wiederfinden, eine Fahrt löschen und wiederherstellen. Für den Sync musst du am iPhone und am Mac mit derselben Apple-ID in iCloud angemeldet sein. Feedback gern über „Feedback senden“ in TestFlight oder einen Screenshot.

### Für die Beta-App-Prüfung (Hinweise an Apple)
> No sign-in required. The app works without any data: without rides the overview shows an anonymized sample ride. GPS recording starts with the button "Start Ride" on the overview. Sync uses the user's private CloudKit database only; there is no server of our own.

## Warum so
- **TestFlight statt Ad-hoc-Verteilung:** Ad hoc müsste Nils jede UDID der Freunde eintragen (höchstens 100 Geräte im Jahr) und neue Profile verteilen. TestFlight braucht nur eine E-Mail-Adresse oder einen Link.
- **„Keine Daten erhoben“ ist ehrlich, weil CloudKit privat ist.** Die private Datenbank gehört dem Nutzer und zählt gegen seinen iCloud-Speicher, nicht gegen den von Nils. Das ist auch der Grund, warum der Sync für Freunde nichts kostet.
- **Kein eigener Webserver** (Entscheidung 2.11.2026): Damit fällt eine Datenschutzerklärung mit Auftragsverarbeitung, Löschfristen und Kontolöschung weg (B-088).

## Was erst mit dem aktiven Account geht
- App-ID mit iCloud-Capability, App in App Store Connect, erster Upload, Gruppen „Nils“ und „Freunde“, Beta-App-Prüfung.
- Prüfen, ob der Name „Wattspur“ im App Store frei ist.
