# Lern-Notizen

Zu jeder Story steht hier kurz: **was** gebaut wurde, **warum** so und **welche Swift-Konzepte** dahinterstecken (Definition of Done, Backlog). Die Notizen sind zum Verstehen gedacht, nicht als Referenz-Doku.

| # | Thema | Stories |
|---|---|---|
| [01](01-fit-decoder.md) | FIT-Dateien lesen: Binärformat, Decoder, Tests | B-002, B-004, B-005 |
| [02](02-datenmodell-import.md) | Datenmodell mit SwiftData, Import, Duplikate, Papierkorb | B-003, B-007, B-010 … B-015, B-024 |
| [03](03-tour-detail.md) | Tour-Detail: Karte, Diagramme, Formatierung | B-016 … B-020 |
| [04](04-oberflaeche.md) | Fensteraufbau, eigene Seitenleiste, Liste, Lokalisierung | B-008, B-011, B-021, B-022, B-006 |
| [05](05-auswertung.md) | Auswertung: Summen, gewichtete Mittel, Balken, Trends, Mehrfachauswahl | B-030 … B-034 |
| [06](06-import-ordner.md) | Überwachter Ordner, Import-Protokoll, Einstellungen, Einrichtungsassistent, Profil | B-040 … B-044, B-027, B-029, B-049 |
| [07](07-barrierefreiheit.md) | Barrierefreiheit: VoiceOver, Audio Graphs, Tastatur, Kontraste | B-025 |
| [08](08-icon-dmg.md) | App-Icon (Icon Composer) und ad-hoc signiertes DMG | B-046 |
| [09](09-beispielfahrt.md) | Beispielfahrt: FIT-Datei anonymisieren und mitliefern | B-028, V-05 |
| [10](10-handbuch.md) | Benutzerhandbuch EN/DE und Demo-Modus für Screenshots | B-080 |
| [11](11-fahrten-zusammenfuegen.md) | Fahrten zusammenfügen und wieder trennen: Selbstbeziehung in SwiftData, Summen aus Teilen | B-095 |
| [12](12-teaser-seitenleiste.md) | Teaser in der Seitenleiste: neue Bereiche ankündigen, ohne Daten vorzutäuschen | B-111 |
| [13](13-tourenvergleich.md) | Tourenvergleich: Kennzahlen als `enum`, bester Wert, gewichteter Schnitt, Diagramme übereinander | B-098 … B-103 |
| [14](14-highlights.md) | Highlights: Ortsdatum, Serie, Rekorde, Hinweis nach jedem Import, Ziele in SwiftData | B-050 … B-053 |
| [15](15-tipp-mehrfachauswahl.md) | Tipp zur Mehrfachauswahl: einmal zeigen, dann für immer weg (`@AppStorage`) | B-113 |
| [16](16-gpx-export.md) | GPX-Export: XML von Hand schreiben, Erweiterungen, Segmente je Teil, Rundreise im Test | B-112 |
| [17](17-karte-aller-fahrten.md) | Karte aller Fahrten: Routen vereinfachen, kompakt speichern, Vorschau in der Liste, eigene MapKit-Zeichnung, Kacheln für den Ausschnitt | B-104, B-064, B-106, B-107, B-114 |
| [18](18-bikes-datenmodell.md) | Mehrere Bikes: Datenmodell, aktives Bike, Kennzahlen, Umstieg aus 1.4 | B-074 |
| [19](19-bereich-profil.md) | Bereich „Profil“: Kacheln, Bike-Editor, selbst gezeichnete Symbole, Foto verkleinern | B-134 |
| [20](20-bike-zuordnen.md) | Fahrten einem Bike zuordnen: Menü „Import für“, Zuweisen mit ⌘Z, Bike im Tour-Detail | B-135 |
| [21](21-bike-anzeige.md) | Das Bike zeigen: Symbol in der Liste, Zeile im Vergleich, PDF, `<desc>` im GPX | B-136 |
| [22](22-bike-filter.md) | Bike-Filter je Bereich: gemerkt, Ziele über alle Bikes, Karte (B-110) | B-137, B-110 |
| [23](23-kalorien-mit-profil.md) | Kalorien „mit Profil“: Grundumsatz nach Mifflin-St Jeor, Rückfall, Einstellung (Gerüst) | B-067 |
| [24](24-umstieg-erststart.md) | Umstieg auf 1.5: Hinweis nach dem Update, Schritt „Erstes Bike“ im Assistenten | B-138 |
| [25](25-architektur-aufraeumen.md) | Architektur aufräumen: Sicherheits-Fix, zwei Module, Dienste, geteilte Bibliothek, Einstellungen, Start | B-162 … B-169 |
| [26](26-aehnliche-strecken.md) | Ähnliche Strecken: Rasterindex, Ähnlichkeit in beide Richtungen, Suche im Hintergrund, Verlauf, beste Minute | B-116 … B-120, B-122 |
| [27](27-gespeicherte-strecken.md) | Gespeicherte Strecken: berechnete Mitgliedschaft, Migration mit neuer Tabelle, Mediathek-Backup, Hilfe-Menü | B-121, P-22, B-084 |

**Begriffe, die oft vorkommen**
- **Swift Package (`WattspurKit`)**: ein eigenständiges Code-Modul ohne Oberfläche. Es lässt sich mit `swift test` allein testen und später unverändert in der iOS-App nutzen.
- **SwiftUI**: Oberflächen werden beschrieben („so soll es aussehen“), nicht Schritt für Schritt gezeichnet. Ändern sich Daten, zeichnet SwiftUI die betroffenen Teile neu.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`): das moderne Test-Framework von Apple.
