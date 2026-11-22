# 37 – CarPlay und der Name einer Fahrt

Storys: B-340, B-327 und B-368 (iOS 1.6.4, 22.11.2026). Regeln: [ARCHITECTURE](../ARCHITECTURE.md), Regel 6 und 8.

## Was gemacht wurde
- **Berechtigung:** `com.apple.developer.carplay-driving-task` steht nur in `iOS/Wattspur-iOS-iCloud.entitlements`, also nur in Builds mit Developer-Account. Die automatische Signierung (`-allowProvisioningUpdates`) holt ein Profil mit der Berechtigung; ein eigenes Profil ist nicht nötig.
- **Eine zweite Szene:** `Config/iOS-Info.plist` nennt die CarPlay-Szene (`CPTemplateApplicationSceneSessionRoleApplication`) mit `CarPlaySceneDelegate`. Die Fenster-Szene von SwiftUI läuft weiter wie vorher.
- **Die Tafel:** `CPInformationTemplate` mit bis zu drei Knöpfen, `CPListTemplate` für das Fahrzeug, `CPAlertTemplate` für die Rückfrage beim Ende.
- **Die Werte im Kit:** `DrivingPanel` rechnet Zustand, Tempo, Zeit, Strecke und Seitenwert und entscheidet, ob die Tafel neu geschrieben wird. `RideRoute` sagt, ob eine Fahrt von A nach B ging oder eine Runde war.
- **Ein Name für jede Aufnahme:** `RideNaming` in der App macht daraus „Darmstadt – Frankfurt – 14:32“ oder „Reinheim Rundfahrt – 14:32“, für das Blatt, das Auto-Ende und CarPlay.

## Was die Story gelernt hat
- **CarPlay lässt sich erst mit der Freigabe testen.** Seit iOS 27 läuft eine CarPlay-App nur mit Berechtigung und Profil auf einem angeschlossenen iPhone. Darum kam erst der Antrag (B-338), dann die Berechtigung (B-340), dann die Oberfläche.
- **Eine Driving-Task-App soll ruhig sein.** Apple erwartet keine ständig neuen Werte. Ein Timer prüft jede Sekunde, aber die Tafel ändert sich höchstens alle 5 s; ein neuer Zustand (Start, Pause, Ende) zeigt sich sofort.
- **Im Auto tippt niemand Namen.** Darum sichert das Ende in CarPlay ohne Blatt, und der Name kommt aus Orten und Zeit. Daraus wurde der Wunsch, denselben Namen für jede Aufnahme vorzuschlagen.
- **Ein Vorschlag darf nichts überschreiben.** Die Orte kommen erst nach etwa einer Sekunde. Das Blatt ersetzt nur den Platzhalter, nie einen getippten Namen.

## Warum so
- **Die Orte im Kit, die Wörter in der App:** „Rundfahrt“ ist ein Text und gehört in den String-Katalog (Regel 8). Das Kit gibt nur zurück, welcher Fall es ist (`RideRoute`), und hat dafür Tests ohne Netz.
- **Ein Recorder für beide Bildschirme:** CarPlay bekommt dieselbe Instanz wie das iPhone (`CarPlaySceneDelegate.recorder`). So kann es keine zwei Aufnahmen geben.

## Swift-Konzepte
- **Szenen-Manifest:** Mit `UIApplicationSupportsMultipleScenes` und einer eigenen Rolle bekommt eine SwiftUI-App eine zweite Szene mit UIKit-Delegate.
- **`MainActor.assumeIsolated`:** Ein `Timer` auf dem Main Run Loop ruft seinen Block auf dem Hauptthread auf; so darf er Code des `@MainActor` aufrufen, ohne `Task`.
- **Enum mit Werten statt Text:** `RideRoute.oneWay(from:to:)`, `.roundTrip`, `.start` beschreibt den Fall; erst die App macht daraus Wörter.

## Selbst nachprüfen
1. `swift test --no-parallel --filter "DrivingPanel|RideRoute"` im Paket – alle Tests grün.
2. `codesign -d --entitlements - <App im Archiv>` – zeigt `com.apple.developer.carplay-driving-task`.
