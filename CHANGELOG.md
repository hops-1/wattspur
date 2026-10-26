# Changelog

All notable changes to Wattspur are listed here, newest first.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).
Every DMG handed out to testers corresponds to one entry below.

## [Unreleased]

### Added
- **More records:** top speed, highest power, highest cadence and **best 1-minute power** (the highest average power you held for 60 seconds without a break) join the records in Highlights. They have no minimum distance. The values come from the file's maximum; power, cadence and the best minute need a file with power values, so many GPX files do not count for them. The ride detail marks a record in Details, and the notice after an import names the new ones too. Rides you already have get their best minute in the background after the update; your library is not changed otherwise (B-122, ADV-R3).

### Changed
- **Bike symbol:** in the ride list, menus, filters and the comparison, the small bike symbol is drawn larger, with a stronger line and tint, so the rider and the wheels are easier to see (B-174).
- Internal: the groundwork for similar routes (B-116): a route can be compared with others (the share that lies within 50 m of the other route, both ways, and whether it runs the same way), and an index finds the similar rides among a thousand in well under a second. Nothing to see yet; the list gets its filter in a later step.

### Fixed
- **Trash:** **Empty Trash…** now sits in the header of the trash instead of the title bar, where it reached into the sidebar. **Restore** is a small button with a symbol (also in the context menu), so the name and the figures of a ride no longer wrap onto several lines (B-161).

## [1.6.2] – 2026-10-25

Wattspur tells you when a new version is out.

### Added
- **Update notice:** once a day Wattspur asks GitHub whether a newer version has been released and, if so, shows a banner at the top of the window with a link to the release page. **Later** hides that version; a still newer one shows again. **Wattspur › Check for Updates…** asks right away, and **Settings › General › Check for new versions** switches the daily check off. Only the public release list is read; nothing about you or your rides is sent. The app is not updated by itself: you download the DMG and replace the app (B-172).

## [1.6.1] – 2026-10-25

Security fix for damaged FIT files, a tidier foundation, and two small improvements to the ride page.

### Fixed
- **A damaged or deliberately crafted FIT file could crash Wattspur** while importing or when its ride was opened: five cases are fixed (a time stamp near the end of the range, a negative serial number, huge power values, an extreme start time, and numbers that are not numbers in the distance). Such a file now imports with the bad values left out, or is reported as unreadable. The crash could come back at every launch when the file sat in the watched folder. A review of the 1.6.0 code found no way to run code through a file; all five were crashes only.
- The charts of a ride no longer crash if its records start before the ride's start time.

### Changed
- Ride details: the map with the track stays in view at the top and only the part below it scrolls, so the spot you point at in a chart is always visible on the map. The map is a little shorter in small windows.
- Ride map: the red (new) and blue (ridden before) lines are now equally wide; before, red looked heavier at most zoom levels.
- Internal: the code is split into a part that reads files and calculates (`WattspurCore`, without database or screen code) and the part that stores rides (`WattspurKit`); the ride library hands its work to six small services; one library is shared by all windows; big views (Highlights, Analysis, Comparison) are split into folders; all settings keys are in one place with their old values.
- The watched folder reads files in the background, and the housekeeping at launch (empty the old trash, read outdated rides again, trim the import log) now starts after the first window is shown.

## [1.6.0] – 2026-10-25

GPX import: rides from other bikes, apps and bike computers, next to your Bosch rides.

### Added
- **Import GPX files** by drag and drop, with **+** (⌘O) or from the watched folder (GPX 1.0 and 1.1; komoot, Strava, bike computers, Bosch's own GPX and Wattspur's export). Power, cadence, heart rate and temperature are read when the file has them; a file with several tracks or segments becomes one ride. Routes and waypoints are not imported, and a track needs times; a file that cannot be read says why in the import log (IMP-04, B-140).
- **Totals from the track:** ride time without stops (a gap of 30 s or more is a pause, speed below 0.8 m/s is standing), distance, average and top speed, and ascent and descent from smoothed elevation (climbs count from 3 m). The ride is marked **≈ Totals estimated**, with a short explanation (B-142).
- **Which bike?** When you drop GPX files by hand and have two or more bikes, a sheet asks for the bike, because a GPX file does not say it; the active bike is preselected. In the watched folder the active bike gets the ride (B-144).
- **The same ride as Bosch FIT and GPX:** Wattspur recognises it by start (±60 s), distance (±10 %) and route, only on the same bike, so a friend's file of the same tour stays a ride of its own. A GPX for a Bosch ride is **attached** without asking: heart rate and temperature are added, the Bosch values stay, a notice says so. A Bosch FIT for a GPX ride, or a second GPX file, asks what to do: **Skip**, **As new ride** or **Update**; updating takes the Bosch values and keeps name, notes and bike. In the watched folder the FIT updates the GPX ride by itself; two GPX files of one ride are skipped and noted in the log (IMP-02, B-143, B-144).
- **Source symbol** in the ride list: **GPX** for rides from a GPX file, **+GPX** for a Bosch ride with a GPX attached; a Bosch FIT alone has none. The ride detail names the source and the file (B-145).
- **Filter by source** (all sources, Bosch FIT including attached GPX, GPX) in Rides, Analysis, Map and Highlights, each remembering its own choice; it appears once there is a GPX ride. Goals count all sources. The import log has a filter FIT | GPX and the state **Attached** (B-144, B-145).
- **Missing values:** a dash with “Not in the file” instead of 0 for power, cadence, ascent and work; calories show a dash without power (“Needs power data”); CO₂ is calculated from the distance. Charts without data say so instead of staying empty (B-145).
- **“9 of 12 rides”** under a figure that only some rides have (ascent, work, calories, average power and cadence in the analysis, ascent in the year in review and in an ascent goal, the average in the comparison). Sums and averages use the rides that have the value; in the comparison, work and calories of a ride without power are empty and no longer pull the average down (B-146).
- Debug builds: the launch argument `-WattspurDemoImport "/path/a.fit,/path/b.gpx"` puts files into the demo library without touching your own rides.

### Changed
- **“Your year”** above the ride list follows the bike filter and the source filter of the list, and the year in review opens with the same filters; before, it always counted all rides (B-145).
- The note “CO₂ saved” now says “Calculated from the distance” instead of “Estimated from your pedal power” (B-145).
- Texts that said GPX files are not imported (setup assistant, Settings › Import, About, the empty map) were updated.
- Internal: heart rate and temperature are stored in the time series but not shown yet.

## [1.5.0] – 2026-10-25

Profile and several bikes: each ride belongs to a bike, and every area can look at one bike on its own.

### Added
- **Profile** in the sidebar (⌘6) instead of a small window: your name, photo and body data (weight, height, year of birth, sex; all optional and only stored, for a calorie estimate “with profile” in a later version), and your **bikes** as tiles with photo, type, drive unit and battery, distance, rides and last ride (B-134, PROF-01, PROF-03).
- **Several bikes:** name, color, type (bicycle, mountain bike, road bike, gravel bike), switch **E-bike**, photo, manufacturer, model, drive unit, battery, weight, purchase date and starting mileage. A bike is archived instead of deleted: its rides stay assigned and it stays in the filters, but it leaves the Import menu (B-074, B-134).
- **Active bike and “Import for”:** new rides, also from the watched folder, go to the active bike (the star in the profile). From two bikes on, a menu **Import for ● Bike** above the ride list switches it (B-135).
- **Assign Bike:** in the context menu of the list, for several selected rides and in the ride detail; a note at the bottom of the window with **Undo** (⌘Z). A merged ride moves with its parts and belongs to the bike of its first part (B-135).
- **The bike where you look at a ride:** its symbol in the ride list (from two bikes on), a row **Bike** in the comparison and its PDF, “Bike: name · drive unit” in the ride PDF and the bike's name as the description in an exported GPX file (B-136).
- **Bike filter** in Rides, Analysis, Map and Highlights, each remembering its own choice. In Highlights the year and the records follow it, **goals always count all bikes**. Archived bikes are listed under “Archived”. The map of all rides can now be limited to one bike (B-137, B-110).
- **After the update,** a note at the top of the window asks you once to set up your bikes; the setup assistant has a new step **Your first bike** (name, color, body data to skip) (B-138).

### Changed
- **Calories now follow the Flow app** (V-01): work × 0.97 plus 64 kcal per hour of ride time, instead of work × 1.125. Six rides with the kcal shown in Flow (7 minutes to 4:50 hours) are reproduced within 4 kcal; the old factor was up to 7 % too low on long rides with little power. Flow has no body data, so this part does not depend on your profile. The mode “with profile”, which is not offered yet, is prepared with work ÷ 25 % efficiency (factor 0.956) plus the basal metabolic rate over the ride time. Calories of existing rides change accordingly.
- All rides from earlier versions now belong to one bike named “Mein eBike” (“My eBike”); rename it in the profile.
- “Edit Profile…” in the settings opens the profile in the main window.
- Internal: the calorie mode “with profile” (basal metabolic rate on top of the pedal power) is built, but not offered yet (B-067). The model also has fields for a later GPX import (source kind, heart rate and temperature in the time series, an attached extra source); nothing in the app uses them yet (B-074).

## [1.4.3] – 2026-10-25

Small wishes from testing 1.4.1: merging suggested after an import, the joins of merged rides, charts over distance or time, and charts and map linked.

### Added
- **Charts and map linked** in the ride detail: hover a chart and all four charts show a line and the value at that spot, and a dot marks it on the map; hover the route and the dot and the lines follow. A click holds the spot (pin next to the value), another click or Esc lets go. It works on both axes and is not in the PDF. VoiceOver announces the spot when it is held (B-062, TOUR-06).
- **Distance or Time on the x axis** of the charts in the ride detail, with a switch above them; the choice is remembered and the ride PDF follows it. Time runs from the start as h:mm; pauses and gaps stay empty instead of being joined by a line. The comparison keeps the distance (B-065, TOUR-07).
- **Joins of merged rides:** a fine line in each chart and a short black tick across the route on the map where two parts meet, also in the ride PDF. If there is a gap in space between the parts, both ends get a tick; over time a pause is framed by two lines (B-131).
- **Merging suggested after an import:** when new rides and rides already in the library, on the same day, follow each other closely (a gap up to 60 minutes by default, the end near the start of the next), a hint above the list says “2 rides from 15 Oct probably belong together” with **Merge** and **Not Now**. The import log shows the same line with a button. Nothing is merged without your click. **Settings › Import › Merging** sets the gap (off, 15, 30, 60 or 120 minutes) (B-096, LIST-10).

### Fixed
- The map of all rides and the maps in the PDFs no longer show places and areas such as “Naturpark Harz”: the filter now sits on the map configuration, which had overridden it (B-132).

## [1.4.2] – 2026-10-24

Fixes from testing 1.4.1: PDF maps, new paths on the ride's map, a way back from Highlights.

### Added
- **Back to Highlights** (⌘[) above the rides you open from the calendar or a record in Highlights, also when several rides are selected; it returns to the same tab and year (B-128).

### Fixed
- A click on the map of all rides beside every route now also clears the selection in the list, so no ride stays highlighted in dark blue, also on the heat map. With **Only selected rides** on, the selection stays, because it is what the map shows (B-129).
- New paths sometimes did not show on a ride's map: the whole route was blue although the ride had new stretches. The ride's map now draws the route and the new stretches itself, in a fixed order, so the new stretches always lie on top (B-127).
- The routes in the PDF exports were drawn upside down on the map snapshot (north and south swapped), so they did not match the map under them. This affected the map of all rides (lines and heat map) and the maps in the ride and comparison PDFs. They now sit where the rides really went (B-126).

## [1.4.1] – 2026-10-22

### Fixed
- The new stretches of a ride were missing on its map although the legend and the figure “New paths” were shown: when the new paths were ready before the route had loaded, the blue route was drawn over them. They now always lie on top.

## [1.4.0] – 2026-10-22

All your rides on one map: heat lines or a heat map, the rides at a spot, the totals of the visible area, and the paths you had never ridden before.

### Added
- **New paths** in the ride detail: the share and kilometres of a ride where none of your earlier rides had passed (50 m grid), with the new stretches drawn wider in orange on its map. Also in the map's info card and as a tile for the visible area (B-115, part of IDEA-12).
- Click a route on the map: a popover lists the rides that pass there (name, date, km, newest first) and selects them all in the list with one click. Click one to make it stand out on the map with its key figures and **Open in Ride Detail** (B-109, MAP-05).
- **Heat map** on the map: **Lines | Heat Map** next to the title colours areas of about 16 pt by how many different rides pass there, in fixed steps 1, 2–4, 5–9, 10–19 and 20+ from blue to red, the same for every period, with a legend; also in the PDF (B-108, MAP-04b).
- Map and Analysis show the ride list on the left, like Rides, but only with the rides in the visible area of the map or in the analysis. The selection is the same as under Rides; a selected ride stands out on the map. Double-click a ride there (or right-click › Open in Ride Detail) to open it; **Back to Map** or **Back to Analysis** (⌘[) above the ride detail returns (B-123, B-124).
- **Map** (⌘5) replaces the teaser from 1.2: all your rides on one map. Each ride is a translucent line, so routes you ride often become wider and stronger; a legend shows how often. Filter by week, month, year, a custom period or all, or show only the rides selected in the list (one to four of them in the comparison's colours and dashes). Rides without GPS are named below the title. Below the map, tiles add up the rides in the visible area – rides, distance, ride time, ascent and average speed of whole rides – and **Show in Analysis** opens exactly these rides; the other way round, **Show on Map** in the analysis shows its rides on the map. The map keeps its area and zoom when you switch to another section and back. **Export PDF** saves the visible area with the tiles (B-106, B-107, B-114, AGG-05, AGG-06, MAP-04a).
- Every ride in the list shows its route as a small line on the left, with a green dot at the start; a merged ride shows one line per part, a ride without GPS a symbol. Drawn without map tiles, so the list stays fast (B-064, LIST-02).

### Removed
- The “coming soon” page for Map and the “soon” label in the sidebar.

## [1.3.0] – 2026-10-22

Highlights of your cycling year, records and goals, and GPX export.

### Added
- **Highlights** (⌘4) replace the teaser from 1.2, with three tabs, each with **Export PDF** at the top left (B-050 … B-053):
  - **Year:** distance, rides, ride time, ascent and CO₂ saved with the change against the year before; a calendar of your riding days (darker = more kilometres, click a day to show its rides); kilometres per month; the records of the year. ⌘← and ⌘→ switch years (ADV-J1).
  - **Records:** longest ride, longest ride time, most ascent, highest average speed and power (from 5 km on) and the longest streak of riding days, each with its ride (ADV-R1).
  - **Goals:** kilometres, rides or ascent per week, month or year, with progress, what is left, whether you are on track, and the last periods (ADV-Z1).
- **Your year** above the ride list: kilometres and rides of the current year with a bar per month; a click opens the year in review (LIST-04).
- **Export as GPX…** next to Export PDF in the ride detail and in the list's context menu: saves the track as GPX 1.1 with time (UTC), elevation, power and cadence, e.g. for komoot or a navigation device. A merged ride gets one segment per part (B-112, IMP-09).
- A quiet tip below the ride list and in the empty detail view explains that ⌘-click selects several rides to analyze, compare or merge them. It goes away after the first multiple selection or with ✕ (B-113, tester feedback).
- **New record** notice after any import, also from the watched folder, naming the record and the value it beat; the import log notes it too. Rides that hold a record get ★ in the list and a badge on the key figure in the ride detail (ADV-R2).

### Removed
- The “coming soon” page for Highlights; Map keeps its teaser until 1.4.

## [1.2.0] – 2026-10-21

Compare rides, PDF export, and a look at what comes next.

### Added
- Export a ride as PDF: **Export PDF** at the top left of the ride detail (⇧⌘E) opens the map, key figures, details and charts on A4 in Preview; its menu also offers saving (P-20).
- Compare 2 to 4 rides side by side: select them and click **Compare** (⇧⌘C) or right-click › Compare … Rides. A map shows all routes, each in its own colour and dash. A table shows every figure plus values per km, the coasting share and the average power over the ride time; ★ marks the best value where more or less is clearly better. A switch shows the difference from your average ride. Elevation, speed, cadence and power are drawn on top of each other, each ride with its own colour, dash and marker, with the averages of each ride above the chart, and ascent, descent and the steepest climb for elevation. ⌘-click adds a ride, ✕ removes one. **Export PDF** opens the comparison on A4 in Preview or saves it (B-098 … B-103, CMP-01 … CMP-07).
- The sidebar shows what is coming next: **Highlights** (⌘4) for version 1.3 and **Map** (⌘5) for version 1.4, marked “soon”. They describe the feature and show no data yet (B-111).

### Changed
- User guide: explains that Bosch averages power only over the time you pedal, and why work is therefore lower than average power × ride time.

## [1.1.0] – 2026-10-21

Merge rides, working undo, and deleting several rides at once.

### Added
- Merge rides: select two or more rides that do not overlap in time and choose “Merge … Rides…” from the context menu or “Merge…” next to the selection. A dialog shows the parts on a timeline, the name and the resulting totals. The originals are kept inside the merged ride with their files, so it can be split again and re-read after a parser update (B-095, LIST-09).

### Fixed
- Deleting several selected rides moved only one of them to the trash. Now all selected rides go, with one confirmation and one undo (⌘Z).
- ⌘Z did nothing: the library had an undo manager of its own that the Edit menu never reached. Now ⌘Z and ⇧⌘Z undo and redo renaming, moving to the trash, restoring, merging and splitting rides.

## [1.0.0] – 2026-10-20

The version for friends: app icon, DMG, sample ride, accessibility and a user guide.

### Added
- This changelog (B-081).
- App icon in the macOS 26 style: a trail that turns into a lightning bolt (B-046).
- `scripts/build-dmg.sh` builds an ad-hoc signed DMG for testers, with a “Read Me First” note on opening the app the first time (B-046).
- VoiceOver can play every chart as an Audio Graph and step through its values (B-025).
- ⌘1, ⌘2 and ⌘3 switch between Rides, Analysis and Trash; the bar chart in the analysis works with Tab and the arrow keys (B-025).
- User guide in English and German under `docs/user-guide/`: installation, first launch, importing, views, metrics and FAQ (B-080).
- Optional sample ride in the setup assistant and in Settings › General: an anonymized real ride to try Wattspur out. It is marked “Sample”, does not count in totals or the analysis and can be removed with one click (B-028).
- `swift run anonymize-fit` makes a FIT export safe to share: moves the route, hides 500 m at the start and the end, shifts the date and clears serial numbers, while keeping all totals (V-05).

### Changed
- Clearer VoiceOver labels for the sidebar and the ride list; stronger contrast for bars that are not selected and for the change versus the previous period (B-025).

## [0.3.0] – 2026-10-20

Import without effort, profile and settings.

### Added
- Watched import folder `Wattspur Import` in iCloud Drive (or any folder you choose), kept across launches with a security-scoped bookmark. New FIT files are imported automatically, also at app start; imported files move to `Imported/`, broken ones to `Failed/` (`Importiert/` and `Fehlerhaft/` in German) (B-040).
- Import log with understandable error messages for every file (B-041).
- Setup assistant on first launch: profile name, import folder, and how to export rides from the Bosch eBike Flow app (B-027).
- Local rider profile with name and optional avatar (B-049).
- Empty views explain what to do and offer an import action (B-029).
- Settings window: map type, import folder, language (B-042).
- Trash view: restore rides, empty the trash, rides are deleted for good after 30 days (B-023).
- Rides remember the parser version and are re-read from the original file after a parser update; your names and trash state are kept (B-024).

### Changed
- German translation completed and reviewed (B-044).
- The import notice is shorter, so it can always be closed.

## [0.2.0] – 2026-10-20

Analysis across rides.

### Added
- “Analysis” section with a period picker, totals and weighted averages (B-030).
- Selecting several rides in the list opens the analysis for exactly those rides (B-031).
- Bar charts per week, month or year (B-032).
- Trend charts for average power, cadence and speed per ride with a moving average (B-033).
- Change versus the previous period (± %) per week or month (B-034).

### Changed
- All rides share one default bike instead of creating a bike per ride.

## [0.1.0] – 2026-10-20

Foundation: import, ride list and ride detail.

### Added
- Own FIT decoder for exports of the Bosch eBike Flow app; the totals of the FIT session are used as the source of truth (B-002 … B-005).
- Local time of a ride from the time zone of its start coordinate (B-006).
- Import by drag and drop or file dialog, duplicate detection with skip/update, ride name taken from the file name, original files copied into the library (B-010 … B-013).
- Mac-style window with its own collapsible sidebar, toolbar and detail area (B-021).
- Ride list with name, moving time, distance, average speed and relative date; search, sorting and period filter; rename, move to trash with undo (B-014, B-015, B-022).
- Ride detail: map with route, start and finish and switchable map type; metrics grid; charts for altitude, speed, cadence and power; extra metrics such as pause time, work and altitude range; calories and CO₂ as estimates (B-016 … B-020).
- About window and “Create Diagnostics” menu command (B-094, B-026).
- English and German localization via a string catalog (B-008).
- CI with GitHub Actions: WattspurKit tests and app build (B-009).

[Unreleased]: https://github.com/hops-1/wattspur/compare/v1.4.3...HEAD
[1.4.3]: https://github.com/hops-1/wattspur/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/hops-1/wattspur/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/hops-1/wattspur/compare/v1.4...v1.4.1
[1.4.0]: https://github.com/hops-1/wattspur/compare/v1.3...v1.4
[1.3.0]: https://github.com/hops-1/wattspur/compare/v1.2...v1.3
[1.2.0]: https://github.com/hops-1/wattspur/compare/v1.1...v1.2
[1.1.0]: https://github.com/hops-1/wattspur/compare/v1.0...v1.1
[1.0.0]: https://github.com/hops-1/wattspur/compare/v0.3...v1.0
[0.3.0]: https://github.com/hops-1/wattspur/compare/v0.2...v0.3
[0.2.0]: https://github.com/hops-1/wattspur/compare/v0.1...v0.2
[0.1.0]: https://github.com/hops-1/wattspur/releases/tag/v0.1
