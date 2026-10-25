# 08 – App-Icon und DMG für Freunde

Story: B-046 (NFR-09, NFR-18)

## Was gebaut wurde
- **App-Icon** (`App/Wattspur.icon`): Eine GPS-Spur beginnt am Startpunkt und knickt zum Blitz ab, also „Watt“ und „Spur“ in einem Strich. Die Farbe läuft von hellem Pfirsich (Strecke) zu Orange (Leistung), dahinter liegen angedeutete Höhenlinien auf Dunkelblau. Das Motiv ist eigen, ohne Bosch-Marken (NFR-09). Die Entwürfe liegen auf dem Design-Canvas unter „v1.0“.
- **Build-Skript** (`scripts/build-dmg.sh`): ein Befehl von der Quelle bis zum fertigen DMG.
  - Es erzeugt das Projekt mit xcodegen und baut ein Release-Archiv mit `xcodebuild archive`.
  - Es prüft die Signatur und packt die App mit `hdiutil` in `dist/Wattspur-<Version>-<Build>.dmg`, dazu eine SHA-256-Prüfsumme.
  - Im DMG liegen die App, eine Verknüpfung auf „Programme“ zum Hineinziehen und `Read Me First.txt` (Englisch und Deutsch) mit der Gatekeeper-Anleitung.
- **Build-Nummer** = Anzahl der Commits (`git rev-list --count HEAD`). So hat jedes DMG eine höhere Nummer, ohne dass man sie von Hand pflegen muss. Die Version (`MARKETING_VERSION`) steht weiter in `project.yml`.

## Warum so
- **Icon Composer statt PNG-Satz**: Seit macOS 26 bestehen Icons aus Ebenen (Hintergrund, Spur, Startpunkt). Das System legt daraus den Liquid-Glass-Effekt an und erzeugt die Varianten Dunkel, Getönt und Klar selbst. Ein klassisches `AppIcon.appiconset` würde macOS 26 in einen grauen Rahmen setzen. Die `.icon`-Datei ist ein Ordner mit `icon.json` und SVG-Ebenen, lässt sich mit Git gut vergleichen und im Icon Composer aus Xcode öffnen.
- **Ad-hoc-Signatur** (`CODE_SIGN_IDENTITY: "-"`): Ohne Developer-Account (99 €/Jahr) kann man nicht notarisieren. Ad hoc signiert läuft die App mit Sandbox, und die Bookmarks auf den Import-Ordner funktionieren. Gatekeeper fragt aber beim ersten Öffnen nach.
- **„Dennoch öffnen“**: Seit macOS 15 reicht Rechtsklick › Öffnen nicht mehr. Der Weg führt einmalig über Systemeinstellungen › Datenschutz & Sicherheit. Die Anleitung steht im DMG und folgt im Handbuch (B-080).
- **`hdiutil` statt eines DMG-Werkzeugs**: Das ist im System enthalten und braucht keine Abhängigkeit. Ein schickes DMG-Fenster mit Hintergrundbild wäre möglich, ist für Freunde aber nicht nötig.

## Konzepte
- **Archiv** (`.xcarchive`): ein Release-Build mit allem, was zum Verteilen gehört. Daraus wird die App kopiert.
- **`codesign --verify --deep --strict`**: prüft, ob die Signatur zur App passt. `--display` zeigt `Signature=adhoc`.
- **`spctl -a`** zeigt, was Gatekeeper sagt. Bei ad-hoc signierten Apps lautet die Antwort „rejected“, bis man einmal „Dennoch öffnen“ gewählt hat.
- **xcodegen `type: file`**: Ohne diese Angabe würde xcodegen in den `.icon`-Ordner hineinschauen und die SVGs einzeln ins Projekt legen. Mit `type: file` bleibt er ein Dokument, das `actool` zu `Assets.car` und `Wattspur.icns` kompiliert. `ASSETCATALOG_COMPILER_APPICON_NAME: Wattspur` verbindet beides.

## Zum Ausprobieren
1. `scripts/build-dmg.sh` ausführen und `dist/Wattspur-…dmg` öffnen.
2. Das Icon in Xcode öffnen: `App/Wattspur.icon` mit Icon Composer, dort Dunkel und Getönt ansehen.
3. Vorschau ohne Xcode: `ictool App/Wattspur.icon --export-image --output-file icon.png --platform macOS --rendition Dark --width 512 --height 512 --scale 1` (ictool liegt in `Icon Composer.app/Contents/Executables`).
