# 34 – Weiterentwickeln mit lokalen Modellen (Ollama)

Keine Story, nur Recherche (5.11.2026). Frage von Nils: Kann ich Wattspur auch mit einem Modell auf meinem eigenen Mac weiterbauen, statt nur mit Claude?

**Kurz gesagt:** Ja, für kleine Aufgaben. Für große Stories bleibt Claude deutlich besser. Am einfachsten ist **Claude Code mit einem lokalen Modell über Ollama**. Dann gelten alle Regeln des Projekts weiter.

## Dein Mac
- Apple M4 mit **24 GB** Speicher. Ollama 0.40 ist schon installiert.
- Der Grafikteil darf davon etwa **16 GB** nutzen. Der Rest gehört macOS, Xcode und dem Simulator.
- Faustregel: Ein Modell sollte **höchstens etwa 15 GB** groß sein. Sonst wird es sehr langsam, oder der Mac muss auslagern.
- Deine jetzigen Modelle (`llama3.2:3b`, `qwen2.5-coder:1.5b-base`) sind zu klein für das Arbeiten am Projekt. Für Vorschläge beim Tippen reichen sie.

## Welche Werkzeuge gehen mit Ollama?

| Werkzeug | Wie es läuft | Für Wattspur |
|---|---|---|
| **Claude Code** | Ollama spricht seit Version 0.14 dieselbe Sprache wie Claude. Start mit `ollama launch claude`. | **Erste Wahl.** Gleiche Bedienung, gleiche Regeln, gleiches Gedächtnis. |
| **OpenCode** | Programm im Terminal, ähnlich wie Claude Code. `ollama launch opencode`. | Gute zweite Wahl. Liest die Regeln aus `AGENTS.md`. |
| **Cline** (VS Code) | Erweiterung in VS Code. `ollama launch cline`. | Geht, braucht aber VS Code. Regeln in `.clinerules/` oder `AGENTS.md`. |
| **Continue** (VS Code) | Erweiterung, vor allem Chat und Vorschläge beim Tippen. | Gut für Vorschläge beim Tippen, schwächer als Agent. Regeln in `.continue/rules/`. |
| **Aider** | Programm im Terminal, macht nach jeder Änderung einen Commit. | Geht, arbeitet aber anders (eigene Commits). Regeln mit `--read AGENTS.md`. |
| **Xcode** | *Einstellungen › Intelligence › Anbieter hinzufügen › Lokal gehostet*, Port `11434`. | Gut für Fragen und kleine Änderungen in einer Datei. Kein richtiger Agent mit lokalem Modell. |
| Codex, Qwen Code, Droid und weitere | Alle über `ollama launch`. | Möglich, aber kein Vorteil gegenüber Claude Code. |

## Welche Modelle passen?
Ein Modell für dieses Projekt muss **Werkzeuge aufrufen** können (Dateien lesen, Befehle starten). Sonst kann es nur chatten.

| Modell | Größe | Einschätzung |
|---|---|---|
| `gpt-oss:20b` | 14 GB | **Zum Start.** Ruft Werkzeuge zuverlässig auf und passt gut in 24 GB. |
| `devstral-small-2:24b` | 15 GB | Für Programmier-Agenten gebaut. Passt gerade noch. Etwas langsamer. |
| `mimo-v2.6:9b` | 7 GB | Klein und schnell. Für einfache Aufgaben und wenn Xcode nebenher baut. |
| `qwen3-coder:30b`, `qwen3.8:27b` | 18–19 GB | Stärker, aber **zu groß für deinen Mac**. Erst ab 32 GB sinnvoll. |

Neue Modelle kommen jeden Monat. Probier eines mit einer kleinen Aufgabe aus, bevor du dich festlegst.

**Achtung bei `:cloud`:** Modelle mit `:cloud` im Namen laufen bei Ollama im Internet, nicht auf deinem Mac. Dein Code verlässt dann den Mac. Das ist schnell und stark, aber nicht mehr „lokal“.

## Was schlechter geht als mit Claude
- **Großes Projekt:** Wattspur hat viele Dateien. Ein lokales Modell kann sich nur einen Teil merken. Bei langen Aufgaben vergisst es den Anfang.
- **Werkzeuge:** Kleine Modelle rufen Werkzeuge öfter falsch auf. Oder sie hören mittendrin auf.
- **Swift 6:** Das Projekt prüft Nebenläufigkeit streng (`SWIFT_STRICT_CONCURRENCY: complete`). Damit tun sich kleine Modelle schwer. Typisch sind Fehler mit `@MainActor` und `Sendable`.
- **Neue Apple-Technik:** iOS 26 und Liquid Glass sind neuer als das Wissen vieler Modelle. Sie erfinden dann Funktionen, die es nicht gibt.
- **xcodegen und Xcode-Builds:** Das Modell muss nach Änderungen an `project.yml` an `xcodegen generate` denken. Ein Build dauert lange und braucht Speicher. Modell und Xcode streiten sich dann um die 24 GB.
- **Regeln einhalten:** Deutsche Doku, englischer Code, Worktrees, kein GitHub Actions: Ein kleines Modell vergisst so etwas öfter. Lies die Commits genau.
- **Tempo:** Lokal ist deutlich langsamer als Claude. Eine Aufgabe dauert schnell 5- bis 10-mal so lang.

**Gut geeignet** sind: eine Funktion erklären lassen, einen Test schreiben, einen Text übersetzen, einen kleinen Fehler mit klarer Fehlermeldung beheben, eine Lern-Notiz entwerfen.

## Wie die Regeln mitkommen
Heute stehen die Projektregeln an zwei Stellen:
- im **Gedächtnis von Claude Code** (außerhalb des Repos, unter `~/.claude/projects/…/memory/`), zum Beispiel: eigener Worktree, `scripts/ci-local.sh` statt GitHub Actions, Tests mit `--no-parallel`;
- im Repo: Definition of Done in [`docs/BACKLOG.md`](../BACKLOG.md), [`.gitignore`](../../.gitignore) (keine echten `.fit`- und `.gpx`-Dateien), [`scripts/ci-local.sh`](../../scripts/ci-local.sh), [`project.yml`](../../project.yml).

Eine `CLAUDE.md` gibt es im Repo noch nicht.

**Mit Claude Code und Ollama** bleibt alles wie gewohnt. Das Gedächtnis hängt am Ordner, nicht am Modell.

**Andere Werkzeuge** sehen das Gedächtnis von Claude nicht. Darum lohnt sich eine Datei **`AGENTS.md`** im Repo. Die meisten Werkzeuge lesen sie von selbst (OpenCode, Codex, Cline). Für die anderen:
- Aider: in `.aider.conf.yml` die Zeile `read: AGENTS.md`.
- Continue: eine Datei in `.continue/rules/`, die auf `AGENTS.md` verweist.
- Claude Code: eine `CLAUDE.md` mit der Zeile `@AGENTS.md`.

So stehen die Regeln nur an einer Stelle. Ein Entwurf:

```markdown
# Rules for coding agents (Wattspur)
- Docs in German, simple short sentences. Code, comments and commits in English.
- Work in your own git worktree, never in the main checkout.
- Do not use GitHub Actions minutes. Run scripts/ci-local.sh after push.
- After changing project.yml run `xcodegen generate`.
- Tests: `swift test --no-parallel` in Packages/WattspurKit, with DEVELOPER_DIR set to Xcode.
- Swift 6 with strict concurrency. Fix warnings, do not silence them.
- Never commit real ride files (.fit, .gpx) or Config/Local.xcconfig.
- Each story gets a note in docs/learning/ (what, why, Swift concepts).
- Merge pull requests with a merge commit, never rebase. Merge only after Nils says OK.
```

## Einrichten: so gehst du vor
1. **Ollama aktualisieren:** Ollama-App öffnen, *Nach Updates suchen*. Du brauchst mindestens 0.14, du hast 0.40.
2. **Modell laden** (14 GB, einmalig):
   ```bash
   ollama pull gpt-oss:20b
   ```
3. **Mehr Kontext einstellen:** Claude Code braucht viel Platz für Anweisungen. Ollama-App › *Einstellungen* › *Kontextlänge* auf **64k** stellen. Ohne App im Terminal:
   ```bash
   launchctl setenv OLLAMA_CONTEXT_LENGTH 65536
   ```
   Danach Ollama neu starten. Wird der Mac zu langsam, nimm 32k.
4. **Claude Code mit dem lokalen Modell starten,** im Ordner eines Worktrees:
   ```bash
   ollama launch claude --model gpt-oss:20b
   ```
   Das stellt die Verbindung ein und startet Claude Code. Mit `/status` siehst du, welches Modell gerade antwortet. Danach mit `claude` wie gewohnt starten. Antwortet dann noch Ollama, steht die Adresse `localhost:11434` in deinen Claude-Einstellungen: dort entfernen.
5. **Klein anfangen:** zum Beispiel „Erkläre mir `RideExchange`“ oder „Schreib einen Test für …“. Danach selbst prüfen:
   ```bash
   scripts/ci-local.sh
   ```
6. **Optional in Xcode:** *Einstellungen › Intelligence › Anbieter hinzufügen › Lokal gehostet*, Port `11434`. Dann im Chat-Fenster von Xcode das Modell wählen.

## Mein Rat
- **Beides zusammen nutzen.** Große Stories, Swift-6-Fehler und Releases mit Claude. Kleine, klare Aufgaben lokal.
- **Lokal ist gut, wenn** kein Internet da ist, das Kontingent von Claude aufgebraucht ist oder Code den Mac nicht verlassen soll.
- **Immer prüfen:** `scripts/ci-local.sh` laufen lassen und den Diff lesen, bevor du mergst.
- **Mit mehr Speicher** (32 GB oder mehr) würden `qwen3-coder:30b` und `qwen3.8:27b` gut laufen. Die sind spürbar besser.

## Quellen
- Ollama: [Claude Code mit Ollama](https://docs.ollama.com/integrations/claude-code), [Anthropic-kompatible Schnittstelle](https://docs.ollama.com/api/anthropic-compatibility), [Xcode](https://docs.ollama.com/integrations/xcode.md)
- Modelle: [ollama.com/library](https://ollama.com/library) (Größen vom 5.11.2026)
- Xcode 27 und lokale Modelle: [Blake Crosley, „Xcode 27 Went Agentic“](https://blakecrosley.com/blog/xcode-27-coding-agents)
