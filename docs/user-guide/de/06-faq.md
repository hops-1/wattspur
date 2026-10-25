# Fragen und Fehlerbehebung

### macOS sagt, Wattspur könne nicht geöffnet oder überprüft werden
Das ist bei einer kostenlosen App ohne Notarisierung durch Apple normal. Erlaube sie einmal unter **Systemeinstellungen › Datenschutz & Sicherheit › Dennoch öffnen**, Schritt für Schritt unter [Wattspur installieren](01-installation.md#das-erste-öffnen).

### Eine Fahrt vom iPhone taucht nicht auf
- Ist Wattspur geöffnet? Der Ordner wird nur beobachtet, solange die App läuft. Sonst kommt die Fahrt beim nächsten Start.
- Hast du die **FIT**-Datei (oder eine GPX) in **iCloud Drive › Wattspur Import** gesichert?
- Ist der Upload am iPhone fertig? Ein Wolkensymbol neben der Datei im Finder heißt: Sie ist noch nicht auf dem Mac. Wattspur fordert sie an und importiert sie beim nächsten Durchlauf, spätestens nach fünf Minuten.
- Prüfe **Einstellungen › Import**: Ist die Überwachung eingeschaltet und der richtige Ordner gewählt?

### Der Import ist fehlgeschlagen
Öffne das Import-Fenster (⌥⌘L) und wähle **Zu prüfen**. Jeder Eintrag sagt, was schiefging. Eine Datei aus dem überwachten Ordner liegt in dessen Unterordner **Fehlerhaft**.
- *Die Datei konnte nicht gelesen werden:* Die Datei ist beschädigt oder unvollständig, oft weil ein Download oder Kopiervorgang abgebrochen ist. Exportiere die Fahrt noch einmal aus der Flow-App.
- *Endung „fit 2“ – vermutlich eine Finder-Kopie:* Der Finder hat eine Zahl an den Namen gehängt. Benenne die Datei so um, dass sie auf `.fit` endet, und füge sie erneut hinzu.
- *Dateityp wird nicht unterstützt:* Nur FIT- und GPX-Dateien werden importiert, zum Beispiel keine TCX. Exportiere die Fahrt stattdessen als FIT oder GPX.
- *GPX: keine Zeiten, nur Route oder Wegpunkte, abgeschnitten:* Die Meldung im Import-Protokoll sagt, was es ist. Ein Routenplan von komoot hat keine Zeiten und keine Aufzeichnung; exportiere stattdessen die **gefahrene Tour**. Siehe [GPX-Dateien importieren](08-importing-gpx.md#was-wattspur-liest).

Scheitert eine Datei immer wieder, erstelle eine Diagnose (**Hilfe › Diagnose erstellen …**, Datei beilegen) und schicke sie dem Entwickler.

### Die Werte weichen von der Flow-App ab
Fahrzeit, Strecke, Geschwindigkeiten, Leistung, Trittfrequenz und Anstieg stammen direkt aus der Datei, die Bosch geschrieben hat, und sollten genau übereinstimmen. Wenn nicht, schicke bitte eine Diagnose.
Kalorien und CO₂ sind Schätzungen, siehe [Kennzahlen](05-metrics.md). Dort sind kleine Abweichungen möglich.

### Warum steht bei einer GPX-Fahrt „≈ Summen geschätzt“?
Eine GPX-Datei hat keine Summen. Wattspur berechnet Fahrzeit, Strecke, Geschwindigkeit und Anstieg aus dem Track, deshalb können sie von den Werten einer Bosch-Fahrt abweichen. Importiere dieselbe Fahrt als Bosch-FIT und wähle **Aktualisieren**, um die Bosch-Werte zu bekommen, siehe [GPX-Dateien importieren](08-importing-gpx.md#dieselbe-fahrt-als-fit-und-als-gpx).

### Warum sind Kalorien oder Leistung bei einer GPX-Fahrt ein Strich?
Die Datei hat keine Leistung. Ohne sie gibt es keine Arbeit und keine Kalorien. Wattspur zeigt einen Strich statt 0 und zählt die Fahrt nicht in Summen, die Leistung brauchen. Die **CO₂-Einsparung** kommt aus der Strecke und ist immer da.

### Ich habe eine GPX-Datei importiert, und eine Bosch-Fahrt erschien doppelt oder gar nicht
Wattspur vergleicht Start (±60 s), Strecke (±10 %) und Route, nur auf demselben Bike. Liegt dieselbe Fahrt auf zwei Bikes, zählt sie als zwei Fahrten; weise das richtige Bike mit **Rechtsklick › Bike zuweisen** zu. Eine GPX für eine Bosch-Fahrt wird angehängt, es entsteht also keine zweite Fahrt; achte auf das Symbol **+GPX**.

### Datum oder Uhrzeit einer Fahrt stimmen nicht
Wattspur zeigt die Startzeit in der Zeitzone des Startorts. Die Zeitzone wird einmal über Apple Karten nachgeschlagen. Ohne Internet gilt die Zeitzone deines Macs, bis die Abfrage klappt.

### Warum fehlt die Route auf den ersten und letzten paar hundert Metern?
Nur bei der **Beispielfahrt**: Start und Ziel sind entfernt, damit niemand den Ort findet, an dem die echte Fahrt begann. Deine eigenen Fahrten werden vollständig gezeigt.

### Wo liegen meine Fahrten? Wird etwas hochgeladen?
Alles bleibt auf deinem Mac, in `~/Library/Containers/io.github.hops-1.wattspur`. Wattspur hat kein Konto und sendet keine Daten über dich oder deine Fahrten. Ins Internet geht die App nur für Kartenkacheln, das Nachschlagen der Zeitzone über Apple Karten und die tägliche Frage bei GitHub, ob es eine neue Version gibt (siehe unten).

### Woher weiß ich, dass es eine neue Version gibt?
Wattspur fragt einmal am Tag bei GitHub nach, ob eine neuere Version erschienen ist. Wenn ja, steht oben im Fenster ein Hinweis; **Auf GitHub ansehen** öffnet die Release-Seite, dort lädst du das DMG und ersetzt die App im Ordner „Programme“. **Später** blendet diese Version aus, bis eine neuere erscheint. **Wattspur › Nach Updates suchen …** fragt sofort nach. Gelesen wird nur die öffentliche Liste der Releases, über dich wird nichts gesendet. Abschalten: **Einstellungen › Allgemein › Nach neuen Versionen suchen**. Wattspur installiert Updates nicht selbst.

### Wie stelle ich die Sprache um?
Wattspur folgt der Sprache von macOS. Nur für Wattspur: **Systemeinstellungen › Allgemein › Sprache & Region › Apps**, Wattspur hinzufügen und Deutsch oder Englisch wählen.

### Eine Fahrt liegt auf dem falschen Bike
Bosch-Exporte enthalten keine Bike-Kennung, neue Fahrten gehen deshalb an das **aktive Bike** (der Stern im Profil). Eine Fahrt verschiebst du mit **Rechtsklick › Bike zuweisen** oder über das Bike neben dem Titel im Tour-Detail; ⌘Z nimmt es zurück. Siehe [Profil und Bikes](07-profile-and-bikes.md).

### Wie fange ich von vorn an?
Wattspur beenden und den Ordner `~/Library/Containers/io.github.hops-1.wattspur` löschen. Beim nächsten Start ist Wattspur leer, und der Einrichtungsassistent erscheint wieder. Deine Dateien im Import-Ordner bleiben. Verschiebe sie aus **Importiert** zurück in den Import-Ordner, wenn du sie neu importieren willst.
