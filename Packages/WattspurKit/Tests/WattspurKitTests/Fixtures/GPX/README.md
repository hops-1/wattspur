# GPX-Testdateien (V-11, B-140 bis B-143)

Herkunft, Zweck und erwartete Ergebnisse stehen in `docs/SPIKE-GPX-FORMATE.md`, Kapitel „Testdateien“.

- `pair-*`, `bosch-flow-*`, `bmw-*`: Auszüge echter Fahrten (Bosch Flow, komoot, BMW Motorrad Connected), mit festem Versatz verschoben, Zeiten um ganze Wochen, Namen ersetzt (NFR-12, V-05). Ganze Touren (`pair-*`) sind an Start und Ende um 500 m gekürzt; die Auszüge stammen aus der Mitte von Fahrten. Der Versatz steht nicht im Repo.
- `pair-tour1-bosch-flow.fit` und `.gpx`/`pair-tour1-komoot.gpx`: dieselbe Fahrt aus drei Quellen, mit demselben Versatz (in GPX stehen die gekürzten Punkte mit ihrer Zeit auf dem ersten bzw. letzten gezeigten Punkt). `pair-tour2-bosch-flow.fit`/`.gpx`: zweites Paar, gleicher Versatz.
- `garmin-*`, `strava-*`: selbst erzeugt nach Schema bzw. Drittquellen, **nicht** nach einer echten Datei.
- Übrige Dateien: selbst erzeugt (Fehlerfälle, Zeitformate, Stillstand), keine fremden Daten.
