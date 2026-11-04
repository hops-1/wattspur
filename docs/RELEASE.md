# Release-Anleitung (Mac)

So entsteht eine neue Version der Mac-App als DMG. Es gibt zwei Wege:

- **Ad hoc** (bis 1.8.2, und immer, wenn kein Developer-Account eingerichtet ist): Die App ist ad hoc signiert und nicht notarisiert. Beim ersten Öffnen fragt macOS einmal nach („Dennoch öffnen“), „Read Me First.txt“ in der DMG erklärt das. iCloud-Sync gibt es auf diesem Weg nicht.
- **Developer ID** (ab 1.8.3, B-215): Die App ist mit Developer ID signiert, App und DMG sind von Apple notarisiert und „gestapelt“ (der Nachweis der Notarisierung steckt in der Datei). macOS öffnet sie ohne Rückfrage, und der Sync über iCloud (B-072) ist möglich.

Welcher Weg genommen wird, steht in der ignorierten Datei `Config/Local.xcconfig`. Das Skript ist dasselbe: `scripts/build-dmg.sh`.

## 1. Version vorbereiten (beide Wege)

1. `MARKETING_VERSION` in `project.yml` erhöhen (Semantic Versioning).
2. In `CHANGELOG.md` den Abschnitt `[Unreleased]` in `[x.y.z] – Datum` umbenennen, mit einem Satz darüber, was die Version bringt.
3. Den Release-Commit über einen PR auf `main` bringen; der Check `local-ci` muss grün sein (`scripts/ci-local.sh`).
4. `main` auschecken und sicherstellen, dass nichts uncommittet ist (sonst zeigt „Über Wattspur“ den Commit mit `-dirty`).

## 2. Einmalig für den Developer-ID-Weg

Nur nötig, wenn der bezahlte Developer-Account aktiv ist. Nichts davon kommt ins Repository.

1. **Team-ID** steht in [developer.apple.com › Account › Membership](https://developer.apple.com/account) (zehn Zeichen). Eintragen in `Config/Local.xcconfig` als `DEVELOPMENT_TEAM = …` (Vorlage: `Config/Local.xcconfig.example`).
2. **Zertifikat „Developer ID Application“** anlegen: Xcode › Settings › Accounts › Team › „Manage Certificates…“ › `+` › „Developer ID Application“. Es landet im Schlüsselbund. Prüfen:
   ```bash
   security find-identity -v -p codesigning
   ```
3. **iCloud-Container** `iCloud.io.github.hops-1.wattspur` anlegen: developer.apple.com › Certificates, Identifiers & Profiles › Identifiers › `+` › iCloud Containers. Danach bei der App-ID `io.github.hops-1.wattspur` (und `io.github.hops-1.wattspur.ios` fürs iPhone) unter „Capabilities“ iCloud mit CloudKit einschalten und den Container zuordnen. Xcode kann die App-ID mit „Automatically manage signing“ auch selbst anlegen.
4. **Passwort für die Notarisierung** in den Schlüsselbund: Unter [account.apple.com](https://account.apple.com) › Anmeldung und Sicherheit › App-spezifische Passwörter ein Passwort „wattspur-notary“ erzeugen, dann:
   ```bash
   xcrun notarytool store-credentials wattspur-notary --apple-id DEINE_APPLE_ID --team-id DEINE_TEAM_ID
   ```
   `notarytool` fragt das Passwort ab und legt es im Schlüsselbund ab. In Dateien steht nur der Name `wattspur-notary`.
5. **`Config/Local.xcconfig` ergänzen** (die Zeilen stehen auskommentiert in der Vorlage):
   ```
   WATTSPUR_MAC_SIGN_STYLE = Automatic
   WATTSPUR_MAC_SIGN_IDENTITY = Apple Development
   WATTSPUR_MAC_ENTITLEMENTS = App/Wattspur-iCloud.entitlements
   WATTSPUR_MAC_DISTRIBUTION = developer-id
   WATTSPUR_NOTARY_PROFILE = wattspur-notary
   ```
   Die ersten drei gelten auch für „Run“ in Xcode: Die App läuft dann mit Apple-Development-Signatur und darf den iCloud-Container (Development-Umgebung) nutzen. Die letzten zwei gelten nur für das DMG-Skript.
6. Prüfen, ob alles da ist (baut nichts, sendet nichts an Apple außer einer Abfrage der Notarisierungs-Historie):
   ```bash
   scripts/build-dmg.sh --check
   ```

## 3. DMG bauen

```bash
scripts/build-dmg.sh
```

**Ad hoc:** Archiv → Signatur prüfen → DMG mit „Read Me First.txt“ (`scripts/dmg-read-me-first.txt`).

**Developer ID:**
1. Archiv mit automatischer Signierung (`-allowProvisioningUpdates`, Xcode holt das Profil selbst).
2. Export mit `method = developer-id` und `iCloudContainerEnvironment = Production`: Die verteilte App spricht mit der Production-Umgebung von CloudKit.
3. App als ZIP an `notarytool` senden, auf das Ergebnis warten, `stapler staple` auf die App.
4. DMG aus der gestapelten App, mit der kürzeren „Read Me First.txt“ (`scripts/dmg-read-me-first-notarized.txt`).
5. DMG mit Developer ID signieren, notarisieren und stapeln.
6. `spctl` prüft App und DMG so, wie Gatekeeper es auf einem fremden Mac tut.

Lehnt Apple die Notarisierung ab, druckt das Skript das Protokoll von Apple (`notarytool log`) und bricht ab. Häufige Gründe: Hardened Runtime fehlt (ist in `project.yml` an), ein Teil ist nicht mit Developer ID signiert, oder es fehlt der Zeitstempel.

Ergebnis: `dist/Wattspur-<Version>-<Build>.dmg` und die Prüfsumme `.sha256`.

## 3a. Hardened Runtime und Entitlements (NFR-18)

Apple notarisiert nur Code mit Hardened Runtime, Developer-ID-Signatur und sicherem Zeitstempel. Geprüft für Wattspur:

- `ENABLE_HARDENED_RUNTIME: YES` steht in `project.yml`; das Skript bricht nach dem Export ab, wenn `codesign` das Flag `runtime` oder den Zeitstempel nicht zeigt.
- `App/Wattspur.entitlements` und `App/Wattspur-iCloud.entitlements` enthalten nur App Sandbox, Dateizugriff (vom Benutzer gewählt, Bookmarks) und Netzwerk-Client. Keine Hardened-Runtime-Ausnahmen nötig (kein JIT, keine unsignierten Speicherseiten, keine `DYLD_*`-Variablen, keine Bibliotheksvalidierung-Ausnahme), weil die App keinen fremden Code lädt.
- Die iCloud-Variante ergänzt iCloud/CloudKit und `aps-environment`; der Export mit Developer ID setzt `aps-environment` auf `production` (siehe `ExportOptions.plist` im Skript). iCloud braucht ein Provisioning-Profil, das Xcode über `-allowProvisioningUpdates` holt.
- Die Sandbox ist mit Notarisierung verträglich und bleibt an.
- Falls später Sparkle (B-173) oder ein Framework von Dritten dazukommt: alle eingebetteten Binaries müssen ebenfalls mit Developer ID und Runtime signiert sein, sonst lehnt Apple ab.

Nicht auf diesem Mac geprüft (kein Zertifikat): die tatsächliche Signatur und die Antwort von Apple. Das zeigt erst der erste echte Lauf.

## 3b. Release-Workflow in CI

`.github/workflows/release.yml` läuft **nur von Hand** (`workflow_dispatch`), nie bei Push oder PR, damit keine macOS-Minuten ohne Absicht verbraucht werden. Die Secrets legst du selbst unter Settings › Secrets and variables › Actions an; im Repository steht nichts davon:

| Secret | Inhalt |
|---|---|
| `DEVELOPER_ID_CERT_P12` | Developer-ID-Zertifikat samt privatem Schlüssel als .p12, base64-kodiert |
| `DEVELOPER_ID_CERT_PASSWORD` | Passwort der .p12 |
| `APPLE_TEAM_ID` | Team-ID |
| `APPLE_ID` | Apple-ID für `notarytool` |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-spezifisches Passwort |

Der Workflow legt einen temporären Schlüsselbund an, speichert das notarytool-Profil und ruft `scripts/build-dmg.sh` auf. Er ist ungetestet, bis die Secrets existieren. iCloud braucht ein Provisioning-Profil mit Xcode-Konto; in CI ist deshalb vorerst der lokale Weg der verlässliche.

## 4. Vor dem ersten Sync-Release: Schema nach Production

Nur einmal, vor 1.8.4 (Sync), und danach bei jeder Modelländerung:

1. `CloudKitSchemaTests` muss grün sein (B-189).
2. Die App mit Development-Signatur einmal mit eingeschaltetem Sync starten: SwiftData legt das Schema im Development-Container an.
3. In der [CloudKit Console](https://icloud.developer.apple.com) › Container `iCloud.io.github.hops-1.wattspur` › Schema „Deploy Schema Changes…“ nach Production.

Danach lässt sich das Modell nur noch **erweitern** (neue Felder und Typen), nicht mehr umbauen: Felder umbenennen, löschen oder ihren Typ ändern geht nicht mehr.

## 5. Veröffentlichen

1. Tag setzen: `git tag v1.8.3 && git push origin v1.8.3`.
2. Release auf GitHub mit dem Abschnitt aus dem Changelog und dem DMG samt `.sha256`:
   ```bash
   gh release create v1.8.3 dist/Wattspur-1.8.3-*.dmg dist/Wattspur-1.8.3-*.dmg.sha256 --title "Wattspur 1.8.3" --notes-file <Abschnitt>
   ```
3. Ab der ersten notarisierten Version: Im Handbuch (`docs/user-guide/*/01-installation.md`) und in der README gilt der Gatekeeper-Schritt nur noch für Versionen bis 1.8.2.

## Siehe auch

- `docs/learning/08-icon-dmg.md`: wie das DMG aufgebaut ist.
- `docs/learning/32-testflight.md`: die iPhone-App über TestFlight (B-219).
- NFR-18 in `docs/REQUIREMENTS.md`: warum bis 1.8.2 ad hoc.
