# CarPlay: Recherche und Antrag bei Apple (V-20, B-338)

Stand: 20.11.2026. Gelesen: Apples Entwickler-Doku zu CarPlay („Driving task“, „Preparing your iOS app for CarPlay development“, „Building your app's initial CarPlay interface“, „Testing your app in CarPlay Simulator“, `CPInformationTemplate`) und Beiträge im Entwicklerforum. Das große PDF „CarPlay App Programming Guide“ ließ sich nicht automatisch lesen (über 10 MB). **Claude schickt nichts ab:** Den Antrag stellt Nils mit seinem Konto.

## Ergebnis in Kürze

| Frage | Antwort |
|---|---|
| Kategorie | **Driving Task** („Fahraufgabe“). Apple: Apps, die Fahrzeugdaten zeigen, Checklisten für die Fahrt führen, Straßeninfos geben „oder andere Aufgaben, die keine häufigen Updates brauchen“. |
| Berechtigung | `com.apple.developer.carplay-driving-task` (Boolean). Je App nur **eine** CarPlay-Kategorie. |
| Vorlagen | Erlaubt: `CPInformationTemplate`, `CPListTemplate`, `CPGridTemplate`, `CPTabBarTemplate`, `CPActionSheetTemplate`, `CPAlertTemplate`, `CPPointOfInterestTemplate`, `CPVoiceControlTemplate`. **Nicht erlaubt:** Karte, „Now Playing“, Suche, Kontakte. Also keine Karte mit der Spur, wie schon geplant. |
| Tiefe | Unter der Start-Vorlage noch 1 weitere (bis iOS 26.3) bzw. 2 weitere (ab iOS 26.4). Für Wattspur reicht: Start-Vorlage mit Werten und Knöpfen, darüber eine Liste zur Fahrzeugwahl. |
| `CPInformationTemplate` | Eine Liste von Feldern (Titel und Wert) und **bis zu drei Knöpfe**. Passt genau: Tempo, Zeit, Strecke, Querbeschleunigung bzw. Schräglage; Knöpfe Start/Pause/Ende. |
| Live-Werte | **Risiko.** Eine feste Grenze für Updates nennt Apple nicht. Die Beschreibung „keine häufigen Updates“ spricht aber gegen Werte, die sich jede Sekunde ändern. Vorschlag: die Tafel nur alle 5 s neu schreiben (die vorhandene Vorlage ändern, keine neue zeigen). Das steht so auch im Antrag. |
| Antrag | Formular unter [developer.apple.com/contact/carplay](https://developer.apple.com/contact/carplay): Angaben zur Organisation, Art der App wählen, Bedingungen (CarPlay Entitlement Addendum) annehmen. Apple prüft nach eigenen Kriterien; die Dauer ist offen (im Forum: Tage bis Monate, manchmal keine Antwort). |
| Nach der Freigabe | Im Portal unter *Identifiers › App ID* die CarPlay-Fähigkeit an, ein **manuelles** Profil für die App-ID anlegen, in Xcode dieses Profil wählen (automatische Signierung geht für CarPlay nicht) und die Fähigkeit hinzufügen. Das ist B-340. |
| Testen | **Erst nach der Freigabe.** Ab iOS 27 läuft CarPlay nur auf einem angeschlossenen iPhone mit der App „CarPlay Simulator“ (aus den „Additional Tools for Xcode“), und iOS zeigt die App in CarPlay nur mit Berechtigung und passendem Profil. Hier ist Xcode 27.2 installiert. Der alte Weg über den iOS-Simulator (*I/O › External Displays › CarPlay*) fällt damit weg. |
| Im Code | `Info.plist`: in `UIApplicationSceneManifest` eine zweite Szene `CPTemplateApplicationSceneSessionRoleApplication` mit `UISceneClassName` = `CPTemplateApplicationScene` und einem eigenen `CPTemplateApplicationSceneDelegate`. Die Start-Vorlage in `templateApplicationScene(_:didConnect:)` setzen, schnell. |

## Was das für den Plan heißt

- **B-327 wartet auf die Freigabe.** Ohne Freigabe kann niemand die CarPlay-Ansicht starten, auch nicht im Simulator. Code, den niemand ausprobieren kann, baut Claude nicht auf Vorrat. Darum: zuerst Auto-Start (B-311, B-339), CarPlay (B-327 mit B-340) erst, wenn Apple Ja gesagt hat.
- Kommt die Freigabe nicht rechtzeitig, erscheint 1.6 ohne CarPlay, und CarPlay kommt als 1.6.1. Das hat Nils schon so entschieden.
- **Live-Werte alle 5 s** statt jede Sekunde, damit es zu „keine häufigen Updates“ passt. Sagt Apple trotzdem Nein, bleibt nur: Start, Pause, Ende und Fahrzeugwahl ohne Tafel.

## Schritte für Nils (B-338)

1. [developer.apple.com/contact/carplay](https://developer.apple.com/contact/carplay) öffnen und mit dem Entwicklerkonto anmelden.
2. Als Art der App **Driving Task** wählen.
3. Die Felder mit dem Text unten füllen (Englisch, Apple liest Englisch).
4. Das CarPlay Entitlement Addendum lesen und annehmen.
5. Absenden. Datum im Backlog bei B-338 eintragen (oder Claude sagen). Antwortet Apple, die Antwort ebenso.

## Text für das Formular

Die Felder können anders heißen. Dann den passenden Absatz nehmen.

**App name:** Wattspur – Ride Tracker (iPhone, Bundle ID `io.github.hops-1.wattspur.ios`,)

**What does your app do?**

> Wattspur records and analyses rides by car, motorcycle and e-bike. The driver mounts the iPhone, starts a recording, and afterwards sees route, speed, elevation and lateral acceleration (car) or lean angle (motorcycle). Rides sync to the Mac app over iCloud. There is no account and no server; all data stays on the user's devices.

**What will the CarPlay app do?**

> A small driving-task app for the recording only:
> - Start, pause and end the ride recording without touching the iPhone.
> - Choose the vehicle for the ride from the user's own vehicles (one list).
> - One information screen with a few values of the current trip: elapsed time, distance, speed and lateral acceleration (car) or lean angle (motorcycle). The values refresh every few seconds, not continuously.
>
> No map, no route display, no ride list, no browsing, no text input. It uses only CPInformationTemplate (values and up to three buttons) and CPListTemplate (vehicle choice). The recording is the same as on the iPhone; ending it in CarPlay also ends it on the iPhone and the other way round.

**Why does this help while driving?**

> Today the driver has to reach for the mounted iPhone to start or end a recording. With CarPlay this is one tap on the car's screen, or happens automatically through a Shortcuts automation when CarPlay connects. This reduces handling of the phone while driving.

**Target release:** the next version of Wattspur for iPhone (1.6 or 1.6.1).
