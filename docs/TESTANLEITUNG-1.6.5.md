# Testanleitung iPhone 1.6.5

Für Nils. Jeder Punkt bekommt ✓ oder ✗, bei ✗ eine kurze Notiz. Neu: Die Aufnahme überlastet das iPhone nicht mehr (B-369), der Auto-Start nimmt Auto oder Motorrad, und „Fahrt beenden“ geht auch gesperrt (B-370).

Fahre nur, wenn es sicher ist. Prüfe und notiere nur im Stand, oder lass es die Begleitung tun.

## 0. Vorher

1. **Build:** **1.6.5** aus TestFlight ist installiert. *Mehr › Über Wattspur* zeigt die Nummer, oben notieren. Mit 1.6.4 (45) gilt die Liste nicht.
2. **Bibliothek:** Mit deiner echten Bibliothek testen: Der Fehler wuchs mit der Zahl der Fahrten.
3. **Einstellungen merken:** Standort, Auto-Start und „Startet mit“ notieren, um sie am Schluss zurückzustellen.
4. **Automationen:** Beide eingerichtet („Fahrt starten“ ohne Gerät, „Fahrt beenden“): **Automation** an, **Benachrichtigen** an, **Vor dem Ausführen bestätigen** aus.

## A. Am Schreibtisch (15 Minuten)

1. **Start, Pause, Weiter:** Aufnahme starten. Knöpfe und Anzeige stimmen sofort.
2. **Hintergrund:** 3 Minuten eine andere App, dann zurück: Zeit, Strecke und Linie sind sofort aktuell.
3. **Pause von außen:** In der Live-Aktivität pausieren, Wattspur öffnen: „Pausiert“ steht da.
4. **Abbruch:** Wattspur während der Aufnahme im App-Umschalter beenden, öffnen, „Aufnahme fortsetzen“: Sie läuft weiter.
5. **Querformat:** iPhone drehen, dann Stopp: Das Fenster zum Sichern steht neben der Leiste.
6. **Eigener Name:** Beim Sichern sofort einen Namen tippen, bevor der Vorschlag kommt: Dein Name bleibt.
7. **Übersicht:** Highlights, Ziele und „Fahrt starten mit …“ stimmen. Ein Ziel ändern: Die Kachel folgt. Ein anderes Gerät wählen: Der Knopf folgt.
8. **Geräte und Fahrten:** „Archivieren“, die Zahl der Fahrten je Gerät und das Aufteilen einer zusammengeführten Fahrt stimmen.
9. **Startet mit:** *Mehr › Aufnahme*: „CarPlay“ gibt es nur bei Auto und Motorrad, nicht bei Rädern.

## B. Rad (mindestens 45 Minuten, Flow vorn, Wattspur im Hintergrund, Podcast an, Höhenfarben an)

1. **iPhone bleibt flott:** Navigation und Wechsel zwischen Apps hängen nicht, der Podcast läuft durch.
2. **Spur:** Beim Öffnen von Wattspur ist die Spur sofort da und **nirgends grau**. „Höhe“ zeigt einen Wert.
3. **Wattspur vorn:** Danach 10 Minuten mit Wattspur vorn: Es bleibt flott.
4. **Akku:** Stand am Anfang und am Ende in die Notizen schreiben, dazu ob der Halter geladen hat.
5. **Sichern:** Die Fahrt steht beim Rad, mit voller Strecke und Höhe.

## C. Auto mit CarPlay, Start von Hand (Automationen aus)

1. **App beendet, gesperrt:** Wattspur beenden, iPhone sperren, in CarPlay **Fahrt starten**: Tempo und Strecke laufen. Am Anfang der Spur fehlt nichts.
2. **App im Hintergrund, gesperrt:** Dasselbe mit Wattspur im Hintergrund: Die Live-Aktivität erscheint.
3. **Lange Fahrt:** **Mindestens 45 Minuten**, Navigation vorn: kein Hänger, Tempo und Strecke laufen weiter.
4. **Querbeschleunigung:** CarPlay zeigt sie, das Gerät ist das Auto.
5. **Pause und Weiter:** In CarPlay tippen: Das iPhone zeigt denselben Zustand.
6. **Ende:** „Abbrechen“ lässt weiterlaufen. „Sichern“ sichert mit voller Spur, Höhe, Auto und Namen.
7. **Ohne Standort:** Standort auf „Nie“, starten und beenden: kein Absturz, keine leere Fahrt, das iPhone meldet den fehlenden Zugriff. Danach zurückstellen.

## D. Auto-Start (Automationen an, iPhone gesperrt)

1. **Auto statt Rad:** Vorher zuletzt das Rad benutzen. CarPlay verbinden: **Bereit** kommt ohne Entsperren, die Live-Aktivität zeigt ein **Auto**.
2. **Start trotz Zeitlimit:** „Zeitlimit für Kurzbefehl überschritten“ darf kommen (bekannt), die Fahrt läuft trotzdem.
3. **Bereit in CarPlay:** Die Tafel zeigt „Bereit“. **Abbrechen** beendet ohne Fahrt.
4. **Losfahren:** Ab 10 km/h wechselt die Tafel auf Tempo, Zeit, Strecke und **Querbeschleunigung**. Die Live-Aktivität läuft mit.
5. **Über 100 km/h:** Wo es erlaubt und sicher ist: Die Strecke wächst weiter, die Spur hat keine Lücke.
6. **Ende beim Trennen:** Ohne Entsperren: **kein** „request to open … failed“. Nach kurzer Zeit kommt „Fahrt gesichert“.
7. **Gesicherte Fahrt:** Sie steht bei den Fahrzeugen mit Auto, Namen, ganzer Spur und Höhe, nicht beim Radfahren.
8. **App beendet:** Wattspur beenden, iPhone sperren, verbinden, losfahren: Die Fahrt wird ganz aufgenommen.
9. **Ohne Zuordnung:** „Startet mit“ beim Auto auf „Nichts“: Es wird trotzdem das zuletzt genutzte Auto oder Motorrad, kein Rad.
10. **Entsperrt:** Einmal mit entsperrtem iPhone verbinden und trennen: dasselbe Ergebnis, beim Trennen kein Fehler.

## E. Kurzbefehle und Siri

1. **Start mit Gerät:** „Starte eine Fahrt mit ‹Rad› in Wattspur“ bei entsperrtem iPhone: Aufnahme mit diesem Rad, ohne „Bereit“.
2. **Ende von Hand, entsperrt:** „Fahrt beenden“ für eine selbst gestartete Fahrt: Das Fenster „Fahrt sichern“ geht auf.
3. **Ende von Hand, gesperrt:** Dasselbe gesperrt: kein Fehler. Nach dem Entsperren und Öffnen steht „Fahrt sichern“ da.
4. **Motorrad, wenn möglich:** Auto-Start mit dem Headset: Motorrad als Gerät, Schräglage, Ende beim Trennen. Sonst „nicht getestet“ notieren.

## F. Danach

1. **Keine Berichte:** *Analysedaten*: kein neues `Wattspur.cpu_resource…` und kein Absturz `Wattspur…`.
2. **Protokolle:** *Dateien › Auf meinem iPhone › Wattspur › Diagnose*: die Dateien von B, C und D an Claude geben. Sie enthalten keine Orte.
3. **Werte:** `cpu_percent` unter 15, wenn `visible` 0 ist. `memory_mb` unter 350 ohne stetigen Anstieg. `max_delay_s` unter 2, außer beim Start. `no_barometer` nach der ersten Minute fast 0. (Prüft Claude.)
4. **Zurückstellen:** Standort, Auto-Start und „Startet mit“ wie vorher.

**Bestanden:** alle Punkte von A bis F ✓, nur „Motorrad“ darf offen bleiben. **Nicht bestanden:** ein Hänger, ein Absturz, eine Lücke in Spur oder Höhe, ein Rad statt Auto oder eine Fehlermeldung bei „Fahrt beenden“. Erst danach entscheidet Nils über den App Store.
