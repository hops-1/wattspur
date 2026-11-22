# 36 – Gemeinsame Texte für Mac und iPad

Story: B-355 (iOS 1.6.3 + Mac 1.10.4, 22.11.2026), aus den Funden S-17, S-18, S-19 und S-22 im [Review 1.6.2](../REVIEW-1.6.2.md). Regeln: [ARCHITECTURE](../ARCHITECTURE.md), Regel 6 und 15.

## Was gemacht wurde
- **Ein Ordner `Shared/` für beide Apps.** Darin stehen die Texte und Formate von Analyse, Vergleich und Highlights, der Hinweis bei Speicherfehlern, der Import-Bericht und die Schlusszeile der PDFs. `project.yml` nimmt den Ordner in die Mac-App und die iPhone/iPad-App auf, nicht in die Erweiterungen.
- **Die Kopien am iPhone sind weg:** `AnalysisTexts`, `CompareTexts`, `HighlightTexts`, eine zweite `SaveFailureAlert.swift` und die Hälfte von `ImportReport+Text.swift`, zusammen rund 350 Zeilen.
- **Zwei neue Prüfungen** in `scripts/check-architecture.sh`: `Shared/` importiert nur SwiftUI, Charts, Foundation und das Kit; und kein Dateiname steht in `App/` und `iOS/` zugleich, außer einer kurzen Liste mit Grund (Regel 15).

## Was die Story gelernt hat
- **Zwei Regeln können sich widersprechen.** Logik gehört ins Kit (Regel 6), Texte gehören nicht ins Kit (Regel 8). Für Texte, die beide Apps gleich zeigen, gab es keinen Ort, also wurden sie kopiert. Eine dritte Stelle neben Kit und App löst den Widerspruch.
- **Kopien laufen auseinander, auch wenn sie gleich anfangen.** Der Vergleich rief in beiden Apps `RideFormat.duration` auf. Der Name war gleich, die Funktion nicht: am Mac mit Sekunden, am iPhone ohne. Darum nutzt `Shared/` eigene Helfer (`ValueFormat`) und nie das `RideFormat` einer App; die Prüfung verbietet es.
- **Gleiche Dateinamen sind ein gutes Warnzeichen.** Fast jede Kopie hieß in beiden Apps gleich. Eine Prüfung auf doppelte Namen ist billig und findet die nächste Kopie, bevor sie auseinanderläuft.
- **Längere Texte brauchen Platz.** „00:48:36“ ist länger als „0:48“ und brach in der schmalen Spalte am iPad mitten in der Zahl um. Eine Zeile mit etwas Verkleinern hilft.

## Warum so
- **Ein Ordner statt eines Moduls im Paket:** Ein Modul müsste seine Texte selbst übersetzen und würde Regel 8 brechen. Ein Ordner wird in jede App einkompiliert; Xcode sammelt die Texte in den String-Katalog der jeweiligen App.
- **Mac-Format als Maßstab:** Der Mac war zuerst da und ist die Vorlage für das iPad (B-328). Am iPhone bleiben Listen und Aufnahme bei der kurzen Dauer, weil dort wenig Platz ist.

## Swift-Konzepte
- **Target-Mitgliedschaft:** Eine Swift-Datei kann zu mehreren Targets gehören. Sie wird dann je Target einmal übersetzt und sieht dort die Typen dieser App.
- **`String(localized:)` und `LocalizedStringKey`:** Der Text ist zugleich der Schlüssel im String-Katalog. Steht derselbe Text in beiden Katalogen, sieht er in beiden Apps gleich aus.
- **`.lineLimit(1)` mit `.minimumScaleFactor(0.6)`:** Ein Text bleibt in einer Zeile und wird bis auf 60 % kleiner, bevor er abgeschnitten wird.

## Selbst nachprüfen
1. `scripts/check-architecture.sh` – meldet „architecture: ok“.
2. `git grep -n "func hoursMinutes"` – genau ein Treffer, in `Shared/AnalysisFormat.swift`.
