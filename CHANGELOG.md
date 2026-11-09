# Changelog

All notable changes to Wattspur are listed here, newest first.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).
Every DMG handed out to testers corresponds to one entry below.

## [Unreleased]

### Changed

- **Ride list on the Mac:** much quicker with many rides. Filtering, sorting and the record stars are only worked out again when the rides, the search or a filter change, not on every click (B-270, R-61). Measured with demo rides: about 10 ms instead of 180 ms per update with 300 rides.

### Fixed

- **A library that does not open** no longer makes Wattspur stop at every start, on the Mac and on the iPhone. Instead a window explains what happened and offers a way out: show the backups (and restore one on the Mac), create a diagnostics report, or start with an empty library. Nothing is deleted: the old library moves into a folder “Damaged Library” beside it; with iCloud, the synced rides come back (B-264, R-41).

## [1.8.7] – 2026-11-09

A release that checks and tidies the code before the next big steps: no new features, but 51 fixes from a review of the whole app, most of them for Mac and iPhone working on the same library over iCloud. Nothing changes in how Wattspur looks or works, except that these errors are gone.

### Changed

- **Road surface:** new limits from three test rides on an e-bike, checked against OpenStreetMap and against what was ridden: smooth below 0.4 g, uneven up to 0.6 g, rough above (before 0.1 g and 0.25 g, so normal asphalt counted as uneven). The roughness is now averaged over 10 seconds before it gets a colour, so a manhole cover or a kerb no longer makes a rough spot. Asphalt and even paving stones are smooth, forest tracks rough. This works for all rides at once; nothing is calculated again. In German the bands are now „eben“, „uneben“ and „rau“ (B-248, B-261, V-16).
- **Road surface colours:** uneven is now yellow-orange and rough a clear red, instead of the earthy amber and brown (B-276).

### Fixed

- **Empty map tiles (Mac):** with CyclOSM and OpenTopoMap, parts of the map could stay empty after zooming until another layer was switched. These servers take up to a few seconds for new tiles; the map now draws them as soon as they arrive, and a tile that failed is tried once more (B-282).
- **Curves and new paths (Mac):** with “Curves” on, the map drew the new paths in red on top, so tight curves and new paths looked alike. Now curves hide the new paths, as lean angle and surface do (B-278).
- **Smoother:** moving the pointer over the charts on the Mac no longer builds a list of the whole ride each time, and the ascent shown while recording on the iPhone counts only the current stretch again.
- **The open ride changes (Mac):** after “Update” with the Bosch file, an attached GPX or a change from the iPhone, the ride detail showed the old map, charts and lean angle until another ride was chosen. Now it updates, and long rides open without a pause.
- **Two imports in a row:** a second file opened while Wattspur still asked about the first (the bike, or what to do with a ride already there) replaced that question, and the first file was left undecided. Now the second waits for the answer.
- **Importing a ride that is in the trash:** the file was taken as “already there”, and the ride stayed in the trash until it was deleted for good. Now it comes back, and the import log says so.
- **Files still being written (Mac, watched folder):** a large file or one on a slow network could be read half and moved to “Failed”. Now the folder waits until the file has not changed for a few seconds.
- **Files that cannot be read:** the import log now says that the file could not be read, instead of blaming a broken FIT file.
- **When saving fails:** if the library could not be saved, for example with a full disk, the change was gone after the next start without a word. Now Mac and iPhone say so.
- **Restoring a backup with sync on (Mac):** the dialog now says that iCloud brings back what changed since the backup, and that sync should be turned off first to get the backup as it is.
- **Sync status:** when iOS stopped the app in the middle of a sync, “Syncing …” could stay for the rest of the session, and doubles were merged only at the next launch. Both now give up after a few minutes.
- **Backup before sync (Mac):** a fresh backup is now made each time sync is turned on, not only the first time.
- **Rides over several days:** with two parts on a later day, the second one lay a whole day too far back in the charts, and the total time was too long. This was so for merged rides and for GPX files with several parts. GPX rides are read again once in the background after the update.
- **Start after an update:** when a new version reads the ride files better, the rides are now read again in the background, a few at a time, instead of all at once while the app waits.
- **⌘Z after a sync (Mac):** undoing a step for a ride, a bike or a saved route that was deleted in the meantime on the iPhone could make the app quit. Now the step does nothing.
- **Mac and iPhone with different versions:** stored values (overview map, best minute, curviness and steepest climb) from a newer app were calculated back by an older one and sent back over iCloud. Now an older app leaves them as they are.
- **The same file on Mac and iPhone:** when iCloud merged the two copies, the changes made to the newer one were lost: its name, its bike, that it was taken out of the trash, an attached GPX. Now they stay; where both copies were changed, the older one wins.
- **Two bikes with the same name:** iCloud no longer merges them into one. Only the default bike each device makes for itself, or two bikes with the same serial number, become one.
- **iPhone recording twice:** a recording saved on the iPhone and its GPX imported on the Mac before iCloud had brought it showed up twice. The clean-up after a sync now finds such doubles too and keeps the one imported first.
- **Lean angle kept with the Bosch file:** when the Bosch FIT of a ride recorded with the iPhone came in, Wattspur took the Bosch values and dropped the lean angle, acceleration and road surface of the recording; only heart rate and temperature stayed. Now they stay too, also when a GPX is attached to a Bosch ride. Rides updated before keep missing them.

### iPhone app 0.5.2 (TestFlight, build 11)

The same fixes for what Mac and iPhone share (sync, import, saving, rides over several days, versions), and these for the iPhone:

- **Crash during sync:** with a ride changed on the Mac, the iPhone could quit while iCloud brought the change (TestFlight build 9). It no longer reads the time series of every ride to see what changed (B-276).
- **Screen stays on while recording:** with Wattspur in front, the screen no longer dims and locks during a ride (B-276).
- **Saving a ride after a crash:** if “End and Save” of an unfinished ride failed, the ride was deleted without a word. Now the app says why and keeps the recording.
- **Full storage while recording:** the app no longer quits in the middle of a ride; it goes on and shows that the ride is not backed up any more.
- **A recording of a ride already there:** it was dropped without a word when the same tour was already there as GPX. Now it updates that ride, which keeps its name and gets the lean angle and road surface.
- **Height while recording:** in town or in a forest, where the GPS height is never better than about 15 m, a recording had no height at all. Now the best of the rougher GPS heights set the level after 20 seconds. When the barometer drops out for a few seconds, the height no longer jumps to the GPS value and back, which counted as ascent.
- **Turning sync off on the iPhone:** the iPhone then showed the old folder of iOS 0.2 instead of its own rides; without a folder it showed none, and recordings did not become rides. Now the rides stay on the iPhone; only users of the folder way keep the folder. The change takes effect the next time Wattspur opens, so the sync really stops.
- **Live Activity:** a ride started with Siri while the app was closed could lose its Live Activity right away, with no Pause button on the Lock Screen. And where distances are in miles, the speed now shows in mph too.
- **Map of the last ride:** after a new ride, the map in “Last Ride” kept showing the place of the ride before, with the new track at the edge. The same happened when the Mac brought the Bosch file for a recording. Now it shows the whole ride in both cases (B-275, B-279).
- **A ride the Mac changed:** map and charts stayed old until the app was restarted. Now they show the new ride.
- **Faster on the iPhone:** the tour detail reads a ride once instead of four times, and the list is no longer rebuilt after each of the iPhone's own uploads to iCloud.
- **Opening a file on the iPhone:** if Wattspur could not keep its copy, the file was gone without a word. Now it stays and the app says why.

## [1.8.6] – 2026-11-06

Rides recorded with the iPhone app 0.5.1 bring lean angle, acceleration and how rough the road was. The Mac shows them in the ride detail, next to the iPhone. The values are a first version: the limits are checked against real test rides on a motorcycle and an e-bike and may still change.

### Added

- **Lean, acceleration and braking:** for a ride recorded with the iPhone app 0.5.1, the key figures get a third row: **Max. Lean Left**, **Max. Lean Right**, **Max. Acceleration** and **Max. Braking** in g. Below it the best time from a standstill to 100 km/h on a motorcycle, to 25 km/h on any other bike (B-247).
- **Lean angle chart:** under the other charts, around 0: lean to the left goes up, to the right down. Hover over it and it says, for example, “1.4 km · 27° right”, and the map shows the spot. Each slice of the chart keeps its strongest lean, so a left and a right curve do not cancel out (B-247).
- **Map by lean angle:** the route is coloured from green (upright) through yellow, orange and red to purple (40° and more), with a legend. A button at the top left of the map turns it on and off; it is on by default. While it is on, the new stretches step back so they do not hide the colours (B-247).
- **Road surface:** the figure **Uneven Surface** says how much of the distance was uneven or rough. A third button on the map colours the route by surface: grey smooth, yellow uneven, brown rough. Only one colouring at a time: curves, lean angle or surface (B-248).

Rides without these values look as before.

### iPhone app 0.5.1 (TestFlight, 2026-11-06)

- **Motion sensors while recording:** with each GPS point the iPhone now stores the lean angle, the acceleration along the way and how much the road shook. The lean angle comes from the speed and how fast the bike turns, so it does not matter how the iPhone sits in the mount or the pocket. It counts from 10 km/h. Uses the permission Motion & Fitness, which the barometer already asks for. The values go into the GPX of the recording (`wattspur:lean`, `wattspur:accel`, `wattspur:rough`); other programs ignore them (B-245, B-248).
- **In the ride detail:** tiles for the strongest lean to the left and right, the strongest acceleration and braking, the best time from a standstill (0–100 km/h on a motorcycle, 0–25 km/h on any other bike) and the share of uneven surface. A carousel page **Lean Angle**. The map colours the track by lean angle or, with the switch at the top, by surface; Wattspur remembers the choice (B-246, B-248).
- **For testing:** **More › Test › Record Raw Motion** also writes the raw motion data and every GPS point into a file in the Files app (“On My iPhone › Wattspur › Bewegung”), about 20 MB per hour. Off by default (V-16).
- **Build 7:** the app no longer crashes when a recording starts with the raw motion data turned on.

## [1.8.5] – 2026-11-05

The ride list on the Mac gets a distance filter that works the same as on the iPhone. Together with it comes the iPhone app 0.5.0 for riding: landscape for the handlebar mount, search and filters, the recording on the Lock Screen, a widget and Siri.

### Added

- **Distance filter:** the filter menu of the ride list has **Distance** with the same steps as the iPhone: under 10 km, 10–25 km, 25–50 km and over 50 km. The chip above the list names it, for example “10–25 km”, and ✕ resets it with the other filters. Search, bike, period and distance now follow the same rule on the Mac and the iPhone, so both find the same rides (B-244, B-222).

### Changed

- **Import shared with the iPhone:** the steps of a manual import (the question about the bike, the comparison with a ride that is already there, the summary) now come from the same code on the Mac and the iPhone. Nothing changes in how it looks on the Mac (B-188).

### iPhone app 0.5.0 (TestFlight, 2026-11-05)

- **Landscape:** most handlebar mounts hold the iPhone sideways. Wattspur now works in landscape too. While recording, the map fills the screen, with a glass bar on the left: speed large, average, distance, time, height and ascent, Pause and Stop. The tab bar sits at the bottom left. The overview shows the last ride and the week, month, year and all rides side by side. Rides shows the list on the left and the chosen ride on the right. More has two columns. Whoever does not want landscape turns on the orientation lock of iOS (B-243).
- **Search and filters:** above the ride list there is a search field for the name and menus for **Period**, **Distance** and, from two bikes on, **Bike**, with the number of hits (“2 of 40 rides”) and ✕ to reset. A tap on **This Week**, **This Month** or **This Year** in the overview opens the rides of that period (B-222).
- **On the Lock Screen:** while recording, the Lock Screen and the Dynamic Island show the time, distance and speed, with a button for Pause and Resume. Stop stays in the app, where you name the ride (B-223).
- **Widget “This Week”:** for the Home Screen, small or medium. It shows the kilometres and rides of the week, one bar per day and, in the medium size, the last ride. It has the same numbers as the overview and starts at zero on Monday by itself (B-224).
- **Shortcuts and Siri:** “Start a ride with Wattspur”, “End the ride in Wattspur”, “How far did I ride this week in Wattspur” and “Open my last ride in Wattspur”, in German too. They also work as actions in the Shortcuts app. Ending a ride opens **Save Ride**, as Stop does (B-225).
- **More room:** Overview, Rides and More no longer have a title at the top; the tab bar says where you are.

### iPhone app 0.4.0 (TestFlight, 2026-11-05)

The iPhone gets the ride detail of the Mac: charts to swipe, linked to the map, editing, and rides from the Flow app. The Mac app has no visible change; its import now shares its steps with the iPhone (B-188) and comes with the next Mac version.


- **Edit a ride:** the pencil at the top right of a ride's detail changes its name and its bike. With iCloud, the Mac gets the change too (B-240).
- **Charts to swipe:** with iCloud, the detail of a ride shows speed, power, cadence, heart rate and elevation, one chart per page with dots below, each with its maximum and average. Only what the ride has gets a page. Without iCloud the elevation profile stays (B-090, B-241).
- **Chart and map together:** touch and hold a chart, then move the finger: a line marks the spot, the chart shows the distance and the value there, and the map shows the spot as a dot. The charts now sit right below the map, so both fit on the screen (B-221).
- **Rides from the Flow app:** share a FIT from the Flow app (or open a FIT or GPX in the Files app) with Wattspur. With iCloud it becomes a ride on the iPhone, with power and cadence, and reaches the Mac; Wattspur asks the same questions as the Mac about the bike, a ride that is already there, or the Bosch file of a ride you recorded. Without iCloud the file goes into the folder “Wattspur Import” for the Mac (B-071, B-188).
- **Height from the barometer:** a recording now takes the height from the iPhone's air pressure sensor, at the level of the GPS height. It jitters much less than GPS alone, so the ascent comes closer to Bosch. The iPhone asks once for Motion & Fitness; without it the GPS height is used as before (B-235).
- **Build 3 (fixes from the first test):** the charts end at the end of the ride instead of a rounded distance (30.7 km no longer runs to 40 km). A recording has no height in its first seconds until the GPS level is found, so the start no longer jumps by a few metres and counts as climb (B-090, B-235).
- **Build 4 (from a test with stairs):** a recording begins its track only with a position accurate to 10 m (after 30 s at the latest), and the screen says “GPS is getting more accurate …” until then; at a standstill the GPS had jumped by 54 m in the first 6 s, with up to 87 km/h. The first height waits for the barometer instead of the GPS. The GPX of a recording now carries the accuracy of each point (`wattspur:accuracy`, metres); other programs ignore it. The file types FIT and GPX have German names (B-235, B-071).

## [1.8.4] – 2026-11-05

Wattspur syncs your library with the Wattspur app on the iPhone over iCloud: one library on both, in your own iCloud account. Together with it comes the iPhone app 0.3.0 for testers on TestFlight.

### Added

- **Sync with iCloud:** **Settings › iCloud › Sync with iCloud** now works. Rides with their time series, routes and original files, bikes, profile, goals, saved routes and the trash go into the private database of your own iCloud account, the same on the Mac and the iPhone. A change reaches the other device after 30 s to 1 min. The first time, Wattspur saves a backup of the library beside it; sync starts at the next start of Wattspur. There is no Wattspur server and no Wattspur account (B-072, B-216, V-15).
- **Sync status:** the tab **Settings › iCloud** says when the library last synced, and gives a hint when the Mac is not signed in to iCloud, when iCloud is off for Wattspur, when the iCloud storage is full, or when there has been no connection for two minutes. Short delays get no message (B-220).
- **Motorcycle:** a new bike type. Its rides stay in the list, on the map and on the bike's tile, but count in no totals, highlights, records, comparison averages or goals, and save no CO₂. With the bike filter set to the motorcycle, the analysis and the highlights show its own figures, still without CO₂ (B-239).

### Changed

- **The same rider and bike twice:** a new iPhone makes its own rider and its own “My eBike”. After the first sync, Wattspur merges them with those of the Mac, at every start and after each change from iCloud; the oldest stays, so both devices keep the same ones. The same holds for goals and for the same export imported on both devices (B-216).
- **Rides for the iPhone:** with sync on, the iPhone has the library itself, so **Settings › Import › Provide rides for the iPhone** is hidden while it is off. It stays for an iPhone without iCloud (B-218).
- **Profile:** with sync on, the profile says that profile and rides stay on your devices and in your own iCloud, no longer “on this Mac”.

### iPhone app 0.3.0 (TestFlight)

- **One library with the Mac** over iCloud: rides recorded on the iPhone reach the Mac by themselves, rides from the Mac show on the iPhone, and deleting works on both sides. **More › Sync with iCloud** turns it off; without iCloud the iPhone works as in 0.2, through a folder the Mac watches (also in Dropbox or OneDrive) (B-216, B-218).
- **Sync status** in **More**: when it last synced, and hints for no iCloud, full storage and no connection; a warning while changes still wait for the upload (B-220).
- **Share GPX:** a ride can be shared as GPX from its detail (top right) or the list (touch and hold), e.g. by AirDrop to the Mac; the bike goes with it (B-238).
- **Motorcycle:** **More › Recording › Vehicle** keeps speeds up to 300 km/h instead of 100 km/h, so a motorcycle ride has no gaps (B-239).

## [1.8.3] – 2026-11-04

The first version signed with Developer ID and notarized by Apple: macOS opens it without the “could not be verified” question. It also brings the hint on the wheel circumference, the setting for the iPhone app, and better ride matching and ascent.

### Added

- **Hint on the wheel circumference:** the tile of a bike in Profile shows a hint when the wheel sensor of its Bosch rides measures at least 2 % more or less than GPS, e.g. “The wheel sensor measures 3.7 % more than GPS. Check the wheel circumference in the Flow app.” Wattspur compares only sections with good GPS, over the newest 20 Bosch rides, and does not change any value (B-237).
- **Rides for the iPhone:** new setting **Import › iPhone: Provide rides for the iPhone** (off by default). Wattspur then writes the rides with their key figures and simplified routes into the subfolder “iPhone” of the import folder, at most once a minute, for the Wattspur app on the iPhone. The format is stable and described in `docs/reference/data-exchange.md` (B-178, B-208).
- **iCloud settings (in preparation):** a new tab **Settings › iCloud** with the switch **Sync with iCloud**, off by default. Turning it on the first time saves a backup of the library beside it first. Sync itself is not finished yet and comes with Wattspur 1.8.4; until then the switch has no effect and the tab says so (B-072).
- **Rides recorded with the iPhone:** a GPX from the Wattspur app on the iPhone goes to the bike chosen there, without the question “Which bike?”, and the ride detail shows “Source: iPhone” (B-213).

### Changed

- **Signed and notarized:** the app is signed with Developer ID and Apple notarized the DMG, so Gatekeeper no longer asks before the first start. The Hardened Runtime is on, the sandbox stays on (B-215, NFR-18).
- **Ascent of GPX rides:** a climb now counts from 2 m instead of 3 m. On three tours compared with the Bosch FIT, Wattspur counted 7 to 18 % too little before and 2 to 10 % now (on 3.11.2026: 421 m instead of 400 m, Bosch 431 m). GPX rides already in the library are calculated again at the next start (B-234).

### Fixed

- **iPhone recordings:** the GPX of a recording now keeps the time of each point to the millisecond. Before, two points within one second got the same time; one was dropped on import, and the speed chart showed single spikes of up to twice the real speed (B-233).
- **The same ride as Bosch FIT and iPhone GPX:** a recording started earlier or stopped later than the one in the Flow app was imported as a second ride, and the tour counted twice. Wattspur now also recognises the same ride when the times overlap for at least 80 % of the shorter one; as before, a GPX is attached to the Bosch ride, and a Bosch FIT for a GPX ride offers to take the Bosch values (B-232).

## [1.8.2] – 2026-11-02

A small follow-up: commutes that start a little off are found again, and the steepest-grade records no longer jump on GPX files without a barometer.

### Fixed

- **Steepest climb and descent:** the records no longer jump on GPX files without a barometer, where the altitude jitters by metres. The altitude is smoothed before the calculation and grades above 30 % do not count; the grade in the chart stays as it was. Rides are calculated again in the background at the first start (B-203).
- **Similar rides:** a commute that started a few hundred metres off (another place to park, a recording started late) was missing from the similar rides and from saved routes. Start and end of a ride may now lie 200 m apart, or 2 % of its length if that is more (about 510 m for 25 km); up to 10 km nothing changes (B-184).

## [1.8.1] – 2026-11-01

Wattspur shows the grade in the elevation chart, rates how curvy your rides are, and can draw the curvy roads of a state on its maps.

### Added

- **Grade in the elevation chart:** pointing at the elevation chart now shows the grade next to distance and height, such as “9.2 km · 168 m · ↗ 4 %”. It is taken over 100 m around the pointer, so the jitter of single GPS points does not make it jump; VoiceOver reads it too (B-200).
- **Cargo bike:** a new bike type with its own symbol, a long john with the box in front. It only changes the name and the symbol, no calculation (B-201).
- **Curviness of a ride:** the ride details show how curvy the ride was, with a word and a number per kilometre (from 10 km). A button on the map colours the route by curve (tight red, gentle amber, straight grey), **Curviest ride** is a new record, and the ride list can be sorted by it. Older rides are calculated in the background at the first start (B-180, B-181).
- **Curvy roads on the maps:** **File › Import Curvy Roads…** reads the KMZ file of a state from roadcurvature.com (the “c_300” one). **Customize Map › Layers** then shows its curvy roads below your route on the map of a ride, the comparison and the map of all rides, from the size of a district on, with their name and curvature in a tooltip. Wattspur loads no data by itself; the data is © OpenStreetMap contributors (B-182, B-183).
- **Steepest climb and descent:** two new records in **Highlights › Records** and two figures in the ride details, from the grade over 100 m (B-202).

## [1.8.0] – 2026-10-28

Wattspur shows your rides on OpenStreetMap too, including a topographic map with contour lines.

### Added

- **Map styles:** besides Apple's Standard, Satellite and Hybrid, every map (ride detail, comparison, map of all rides) can show **OpenStreetMap**, **CyclOSM** (drawn for cyclists) or **OpenTopoMap** (contour lines and hill shading). The styles are drawn a little paler so the routes stand out, and the credit of each map stays at the bottom right. They come from the OpenStreetMap community's servers: areas you have seen are kept for a while and also show offline; Wattspur never downloads areas in advance. **Settings › General** sets the style new maps start with (B-061).
- **Customize Map:** a button at the top right of each map opens a window with the map types as small pictures, after komoot's. On the map of all rides it also holds **Lines** and **Heat Map**, which used to sit next to the title; a second click on the chosen one hides the rides and leaves only the map, while a ride selected in the list still shows in blue (B-061).
- **PDFs with map styles:** the PDF of a ride, a comparison and the map shows the same style as the screen, with the credit; without a connection it falls back to Apple's standard map (B-061).
- **A day from the calendar as a filter:** clicking a day in **Highlights › Riding days**, or a record or streak, now shows only those rides under **Rides**, with a chip such as “15 Oct ✕” or “3–9 Oct ✕”. ✕ or **Back to Highlights** shows all rides again. While the chip is there, the list's period, bike and source do not hide any of these rides (B-130).
- **Data exchange:** a [reference page](docs/reference/data-exchange.md) describes the GPX export and the backup folder: the manifest, every table and column of the database, how dates, ids and large data are stored, with SQL examples and a small Python script that lists your rides as CSV and writes a ride's time series or original file. The database is Wattspur's internal storage and may change; the manifest, the original files and GPX stay. The FAQ links to it (B-177).

### Changed

- **Comparison map:** the map in the comparison works like the other maps now: it can show all map styles, zooms to the compared routes once they are loaded, and names a ride when you point at its marker.

### Fixed

- Internal: a test of the library could crash the whole test run now and then, because SwiftData's autosave fired after its database was closed.

## [1.7.1] – 2026-10-26

Wattspur saves the routes you ride again and again, and it can back up your library.

### Added

- **Saved routes:** Wattspur notices when three or more rides ride the same route in the same direction and offers **Save as Route…** above the ride list (**Not Now** keeps it away). A saved route has a name, a similarity and an option for the other direction; rides on it, now and later, belong to it without anything being stored per ride. The route is a filter of the ride list with the same chip as “Similar to” (slider and direction are saved with the route), shows the history of its rides, and can be renamed or dissolved from the chip’s **⋯** menu (⌘Z works). The filter menu lists the saved routes, by name. The ride detail names the route a ride is on (“Route: …”, a click lists its rides), the **Similar Rides** button shows how many other rides are on the route, and after an import a note says when a new ride landed on a saved route. The library gets one new table for this (B-121).
- **Library backup:** **File › Library Backup…** saves the whole library (rides, bikes, goals, notes) as a folder and restores it from one. A backup is made while the app runs; a restore replaces the library the next time you open Wattspur and keeps the old library in a folder beside it. After the restart a note says which backup came back (P-22).
- **Help menu:** *Help* now opens the handbook online (⌘?, in the language of the app), the chapters on importing and on questions and troubleshooting, and the release notes. The empty ride list links to the export guide (B-084).

## [1.7.0] – 2026-10-26

Wattspur finds rides on the same route and shows how you ride them over time, and it keeps more records.

### Added
- **Similar rides:** right-click a ride › **Show Similar Rides** (or **Similar Rides** in the ride detail) and the list shows only the rides on the same route, with the share in per cent in every row. A chip above the list names the ride and the number of rides; its slider (80–99 %) says how alike a route has to be, **Both directions** adds the way back (marked ⇄), and the order is most similar or newest first. Select two to four rides in the result and compare them as usual. **Settings › General › Similar rides** sets where the slider starts (90 %). A route counts as the same when at least that share of it lies within 50 m of the other; start and end have to fit within 200 m for the same direction. Sample ride, trash and the parts of merged rides are left out (B-118, B-119).
- **History of a route:** while **Similar to** is on and no ride is selected, the right side shows how the rides on the route develop: ride time, average speed, power or cadence over time (a dot per ride, the 5-ride average as a line), the best ride marked with a star and the latest with a ring, plus best, latest and average with how the latest differs from the average. Rides without a value (for example no power in a GPX file) are left out of that chart and counted: “9 of 12 rides have this value”. A click on a point opens the ride; **Back to History** (⌘[) returns. **Analyze These Rides** opens the analysis with all rides on the route (B-120).
- **More records:** top speed, highest power, highest cadence and **best 1-minute power** (the highest average power you held for 60 seconds without a break) join the records in Highlights. They have no minimum distance. The values come from the file's maximum; power, cadence and the best minute need a file with power values, so many GPX files do not count for them. The ride detail marks a record in Details, and the notice after an import names the new ones too. Rides you already have get their best minute in the background after the update; your library is not changed otherwise (B-122, ADV-R3).

### Changed
- **Bike symbol:** in the ride list, menus, filters and the comparison, the small bike symbol is drawn larger, with a stronger line and tint, so the rider and the wheels are easier to see (B-174).
- Internal: the groundwork for similar routes (B-116): a route can be compared with others (the share that lies within 50 m of the other route, both ways, and whether it runs the same way), and an index finds the similar rides among a thousand in well under a second.

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

[Unreleased]: https://github.com/hops-1/wattspur/compare/v1.8.4...HEAD
[1.8.4]: https://github.com/hops-1/wattspur/compare/v1.8.3...v1.8.4
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
