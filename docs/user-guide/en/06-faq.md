# FAQ and troubleshooting

### macOS says Wattspur cannot be opened or could not be verified
That is expected for a free app without Apple notarization. Allow it once in **System Settings › Privacy & Security › Open Anyway**, step by step in [Install Wattspur](01-installation.md#open-it-the-first-time).

### A ride from my iPhone does not show up
- Is Wattspur open? The folder is watched only while the app runs; otherwise the ride is imported at the next start.
- Did you save the **FIT** file (or a GPX) into **iCloud Drive › Wattspur Import**?
- Has iCloud finished uploading on the iPhone? In the Finder, a cloud symbol next to the file means it is not on the Mac yet. Wattspur requests the download and imports the file on the next pass, at the latest after five minutes.
- Check **Settings › Import**: is watching switched on, and is the right folder chosen?

### The import failed
Open the import window (⌥⌘L) and choose **Needs attention**. Every entry says what went wrong. A file from the watched folder is in its **Failed** subfolder.
- *The file could not be read:* the file is damaged or incomplete, often because a download or copy was interrupted. Export the ride again from the Flow app.
- *Extension “fit 2” – probably a Finder copy:* the Finder added a number to the name. Rename the file so it ends in `.fit` and add it again.
- *File type not supported:* only FIT and GPX files are imported, for example not TCX. Export the ride as FIT or GPX instead.
- *GPX: no times, only a route or waypoints, cut off:* the message in the import log says which. A route plan from komoot has no times and no recording; export the **recorded ride** instead. See [Importing GPX files](08-importing-gpx.md#what-wattspur-reads).

If a file keeps failing, create a diagnostics file (**Help › Create Diagnostics…**, include the file) and send it to the developer.

### The values differ from the Flow app
Ride time, distance, speeds, power, cadence and ascent come straight from the file Bosch wrote and should match exactly. If they do not, please send a diagnostics file.
Calories and CO₂ are estimates, see [Metrics](05-metrics.md). Small differences are possible there.

### Why does a GPX ride say “≈ Totals estimated”?
A GPX file has no totals. Wattspur calculates ride time, distance, speed and ascent from the track, so they can differ from the values of a Bosch ride. Import the same ride as a Bosch FIT and **Update** it to get the Bosch values, see [Importing GPX files](08-importing-gpx.md#the-same-ride-as-fit-and-as-gpx).

### Why are calories or power a dash for a GPX ride?
The file has no power. Without it there is no work and no calories. Wattspur shows a dash instead of 0, and does not count the ride in sums that need power. **CO₂ saved** comes from the distance and is always there.

### I imported a GPX file and a Bosch ride appeared twice, or not at all
Wattspur compares start (±60 s), distance (±10 %) and route, only on the same bike. If the same ride is on two bikes it counts as two rides; assign the right bike with **Right-click › Assign Bike**. A GPX for a Bosch ride is attached, so no second ride appears; look for the **+GPX** symbol.

### The date or time of a ride is wrong
Wattspur shows the start time in the time zone of the start location. It looks the time zone up once with Apple Maps; without internet it uses the time zone of your Mac until it can look it up.

### Why is there no route for the first and last few hundred metres?
Only for the **sample ride**: its start and finish are removed so that nobody can find the place where the original ride began. Your own rides are shown completely.

### Why is this ride (not) similar?
Wattspur compares the routes: a ride is similar if at least as much of its route as the slider says (default 90 %) lies within 50 m of the other route, checked both ways. If a ride you expect is missing, try this:
- **Lower the slider**, for example to 85 %: a detour or an inaccurate GPS track quickly costs a few per cent.
- Switch on **Both directions** if the ride went the other way round (the way back).
- Check whether the ride **starts or ends elsewhere** (more than 200 m off): then it is a part of the route and does not count as the same route.
- The bike, source and period filters and the search of the list hide results; the chip says so (“12 of 15”).
- A ride without GPS has no route, and neither does one whose route Wattspur is still preparing (that happens in the background shortly after launch).
- The sample ride, rides in the trash and the parts of a merged ride do not count.

If the list shows a ride you do not expect, go the other way: raise the slider until it disappears.

### Where are my rides stored? Is anything uploaded?
Everything stays on your Mac, in `~/Library/Containers/io.github.hops-1.wattspur`. Wattspur has no account and sends no data about you or your rides. It only goes online to load map tiles, to look up time zones with Apple Maps, and to ask GitHub once a day whether a new version is out (see below).

### How do I find out about a new version?
Wattspur asks GitHub once a day whether a newer version has been released. If so, a banner at the top of the window says so; **View on GitHub** opens the release page, where you download the DMG and replace the app in Applications. **Later** hides that version until a newer one comes out. **Wattspur › Check for Updates…** asks right away. Only the public release list is read, nothing about you is sent. To switch it off: **Settings › General › Check for new versions**. Wattspur does not install updates by itself.

### How do I switch the language?
Wattspur follows the language of macOS. For Wattspur only: **System Settings › General › Language & Region › Applications**, add Wattspur and choose English or German.

### A ride is on the wrong bike
Bosch exports carry no bike identifier, so new rides go to the **active bike** (the star in the profile). Move a ride with **Right-click › Assign Bike**, or from the bike next to its title in the ride detail; ⌘Z takes it back. See [Profile and bikes](07-profile-and-bikes.md).

### How do I start from scratch?
Quit Wattspur and delete the folder `~/Library/Containers/io.github.hops-1.wattspur`. At the next start Wattspur is empty and the setup assistant appears again. Your files in the import folder stay; move them from **Imported** back into the import folder if you want to import them again.
