# Testanleitung iPhone 0.7.0 + Mac 1.8.12 „Sichern und Teilen“

Für Nils, nach dem Release. Die Punkte prüfen, was am Simulator nicht ging. Ergebnis je Punkt: ✓, ✗ mit kurzer Notiz oder Screenshot.

**Wichtig:** Nicht mit der echten Bibliothek zurückholen. Die TestFlight-App und das DMG sprechen mit der **Production**-Umgebung von iCloud. Den Probelauf mit Sync (Teil C) deshalb mit Builds aus Xcode im **Development**-Container machen.

## A. Teilen an Wattspur (iPhone, TestFlight 0.7.0, B-301)

Teilen schadet der Bibliothek nicht; das geht auch mit der echten.

1. **Flow:** eine Fahrt als FIT teilen. Steht **Wattspur** in der Reihe der Apps? Öffnet sich Wattspur von selbst und importiert die Fahrt? Wenn nicht: kommt „Öffne Wattspur, um sie zu importieren“, und holt die App die Datei beim Öffnen ab?
2. **Mehrere Dateien:** in der Dateien-App zwei oder drei GPX-Dateien wählen, *Teilen › Wattspur*. Kommt am Ende eine Zusammenfassung („2 neu …“)?
3. **komoot, gefahrene Tour:** als GPX exportieren und an Wattspur teilen. Wird sie eine Fahrt? Mit Puls, wenn eine Uhr dabei war?
4. **komoot, geplante Tour:** als GPX an Wattspur teilen. Erwartet: „Das ist eine geplante Route, keine Fahrt“ mit dem Hinweis, die Tour nach dem Fahren noch einmal zu exportieren.
5. **komoot, Link:** eine Tour als Link teilen. Erwartet: „Wattspur braucht die Datei, nicht den Link“ mit dem Hinweis für komoot.
6. **Strava:** einen Link teilen (erwartet: Hinweis für Strava). Dann eine Aktivität im Browser als GPX exportieren und an Wattspur teilen: Kommen Puls, Trittfrequenz und Leistung, wenn die Aktivität sie hat?
7. **Garmin Connect:** eine Aktivität als GPX oder FIT exportieren und an Wattspur teilen.
8. **Gegenprobe:** ein Foto teilen. Wattspur darf dort **nicht** in der Reihe stehen.
9. **Während einer Aufnahme:** eine Datei teilen. Erwartet: Wattspur importiert erst nach der Aufnahme. Danach die App einmal schließen und öffnen: kommt die Datei?

Danach die Ergebnisse in die Liste im Handbuch eintragen (Kapitel 9, „Teilen an Wattspur aus anderen Apps“, DE und EN).

## B. Sicherung am iPhone (TestFlight 0.7.0, B-302)

Sichern geht auch mit der echten Bibliothek. Das **Zurückholen** nur auf einem Testgerät oder mit einer Test-Apple-ID.

1. *Mehr › iCloud & Bibliothek › Bibliothek sichern …*: in iCloud Drive sichern. Liegt dort ein Ordner „Wattspur Backup …“?
2. Dieselbe Sicherung am Mac 1.8.12 mit *Ablage › Backup wiederherstellen …* öffnen: zeigt der Mac Datum und Zahl der Fahrten? (Nur bis zur Bestätigung, wenn es die echte Bibliothek ist.)
3. Automatische Sicherung einschalten. Am nächsten Tag nach mehr als einer Woche seit der letzten Sicherung: legt die App beim Öffnen selbst eine an?

## C. Zurückholen mit Sync (B-265, Builds aus Xcode, Development-Container)

Mit einer Test-Bibliothek auf iPhone und Mac, beide mit Sync an.

1. Am iPhone eine Sicherung machen.
2. Danach am Mac eine Fahrt umbenennen und eine löschen; am iPhone eine Fahrt importieren. Warten, bis beide gleich sind.
3. Am iPhone die Sicherung zurückholen. Der Bestätigungstext muss sagen, dass die Fahrten in iCloud und auf allen Geräten ersetzt werden. App schließen und öffnen.
4. Erwartet am iPhone: „Sicherung zurückgeholt“ mit dem Satz zu iCloud; der Stand der Sicherung ist da (Name zurück, gelöschte Fahrt zurück, importierte Fahrt weg).
5. Erwartet am Mac nach ein paar Minuten: derselbe Stand. Es kommt **nichts** Altes zurück.
6. Dasselbe einmal anders herum: am Mac zurückholen, am iPhone prüfen.
7. Während einer Aufnahme ist „Sicherung zurückholen …“ am iPhone gesperrt.

## D. Mac 1.8.12 (DMG)

1. Das DMG öffnet ohne Rückfrage (notarisiert). „Über Wattspur“ zeigt 1.8.12.
2. Eine geplante komoot-Tour als GPX importieren. Erwartet: in der Zusammenfassung und im Import-Protokoll „Das ist eine geplante Route, keine Fahrt“, nicht „Datei konnte nicht gelesen werden“.
3. Sync läuft wie vorher: eine Fahrt am iPhone aufnehmen, sie erscheint am Mac.

## Ergebnis

Hier eintragen oder an Claude schicken. Ein ✗ wird ein eigener Backlog-Punkt; B-265 und B-301 kommen auf ☑, wenn C und A durch sind.

**A (Nils, 11.11.2026, iPhone 0.7.0 (20)):** A1 ✓, A2 ✓, A3 ✓, A4 ✓, A5 ✓, A6 nicht geprüft (kein Strava), A7 nicht geprüft (kein Garmin Connect), A8 ✓, A9 ✓. Dazu der Fehler B-305 (eine Bosch-Fahrt über zwei Aufnahmen), mit Build 20 behoben und geprüft.

**B1 (Nils, 11.11.2026, Build 20):** ✗ – nach der Ordnerwahl passierte nichts. Behoben in Build 21 (auch „Sicherung zurückholen“ war betroffen); im Simulator geprüft: Sicherung angelegt, Rückfrage beim Zurückholen kommt.

**B (Nils, 11.11.2026, Build 21):** B1 ✓. B2 ✗ – die Sicherung lag noch nicht ganz in iCloud Drive am Mac; das Zurückholen hing und setzte dann eine unvollständige Sicherung ein (B-306, behoben in Mac 1.8.13 und iPhone 0.7.0 (22)). B3 beobachtet Nils in den nächsten Tagen. **B2 nur noch mit einer Test-Bibliothek wiederholen, nicht mit der echten.**
