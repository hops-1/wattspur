# Importing GPX files

Besides the FIT files of the Bosch eBike Flow app, Wattspur reads **GPX files**: rides from other bikes, from apps such as komoot or Strava, from bike computers, and from the GPX export of the Flow app. GPX is the format almost every device can write, so this is how rides from other bikes get into Wattspur.

A GPX file holds positions, altitude and time, sometimes also power, cadence, heart rate and temperature. It holds **no totals**, so Wattspur calculates them from the track and marks them as estimated. A Bosch FIT file stays the better source for a Bosch ride: the totals in it are the ones the drive unit measured.

## What Wattspur reads
- **GPX 1.0 and 1.1** with a **track** (`trk`) that has a time for its points. Several tracks or segments in one file become **one ride**; a gap of 30 seconds or more splits the ride into parts with a pause between them.
- **Power, cadence, heart rate and temperature** when the file has them, in the extensions that Garmin, Strava and komoot use. Power and cadence show in the charts. Heart rate and temperature are stored, but not shown yet.
- **Not imported:** routes (`rte`) and waypoints (`wpt`), because they hold no recording. A file without times says so in the import log.
- A **GPX you exported from Wattspur** comes back as it went out.
- Very large files (over 200 MB or 5 million points) are refused, and so are files that are cut off or whose times run backwards.

## Importing
Import GPX files the same way as FIT files, see [Importing rides](03-importing.md): drag them onto the ride list or the import window, click **+** (⌘O), or save them in the watched folder.

**Which bike?** A GPX file does not say which bike it was ridden on. If you have two or more bikes, a sheet asks when you drop GPX files by hand; the active bike is preselected. With one bike, or in the watched folder, the ride goes to the active bike (see [Profile and bikes](07-profile-and-bikes.md)). You can change it later with **Assign Bike**.

## What Wattspur calculates
Because the file has no totals, Wattspur works them out from the points. The ride is marked **≈ Totals estimated**; click it for the short explanation.

| Value | How |
|---|---|
| Ride time | The time in motion. A gap of 30 s or more between two points is a pause. Speed below 0.8 m/s (measured over 5 seconds around the point) counts as standing still |
| Distance | Along the track while moving; the small wobble of a GPS at a standstill adds nothing |
| Avg speed | Distance ÷ ride time |
| Top speed | The fastest stretch of at least 5 seconds, so a single odd point does not set it |
| Ascent, Descent | From the altitude after smoothing (median over 5 points); a climb counts from 3 m |

Odd points are left out, for example a jump of more than 150 km/h that is also three times the speed before it. A ride on a motorcycle at 160 km/h stays complete.

On a test ride the calculated ride time matched the Bosch FIT within 1 %. The distance can be a few per cent shorter than the Bosch value, because Bosch measures it at the wheel and the GPS path cuts corners. **Ascent can differ noticeably:** the drive unit and a GPS device measure altitude in different ways. Use a Bosch FIT for figures that must match the Flow app.

## The same ride as FIT and as GPX
You may have a ride twice, as Bosch FIT and as GPX, for example from the Flow app and from komoot. Wattspur recognises it when the **start** is within 60 seconds, the **distance** within 10 % and the **route** is the same. This is checked only **on the same bike**, so a friend's file of the same tour on another bike stays a ride of its own.

- **A GPX for a Bosch ride** is **attached** without a question. Heart rate and temperature from the GPX are added to the ride; the Bosch values stay as they are. A notice at the bottom says “GPX attached to …” with **Show**. The ride gets the symbol **+GPX**.
- **A Bosch FIT for a GPX ride** asks “This ride already exists” with **Skip**, **As new ride** and **Update**. Update takes the Bosch values (the totals are no longer estimated) and keeps your name, notes, bike and flags. The GPX stays as an additional source, and its heart rate is kept.
- **A second GPX file** of a ride that is a GPX ride already, or that has a GPX attached, asks the same question.
- **In the watched folder** nothing asks: a GPX for a Bosch ride is attached, a Bosch FIT for a GPX ride updates it (“updated automatically” in the import log), and two GPX files of one ride are skipped and noted in the log.

Wattspur never overwrites the Bosch values with those of a GPX file.

## How you see GPX rides
- **Source symbol** in the ride list: **GPX** for a ride from a GPX file, **+GPX** for a Bosch ride with a GPX attached. A Bosch FIT alone has none. VoiceOver reads “Source: GPX file”.
- **Ride detail:** a line under the title names the source and the file, and **≈ Totals estimated** explains the estimate. A small ≈ sits next to ride time, distance, average speed and ascent.
- **A dash instead of 0:** what the file does not hold shows as “–” with “Not in the file”: power, cadence, sometimes ascent. A chart without data says “This file contains no power data”. **Calories** show a dash, because they need power (“Needs power data”); **CO₂ saved** is calculated from the distance and is always there.
- **Filter by source:** once there is a GPX ride, Rides, Analysis, Map and Highlights have a **Source** choice: **All sources**, **Bosch FIT** (including rides with an attached GPX) or **GPX**. Each area remembers its own choice, like the bike filter. Goals always count all sources. “Your year” above the ride list follows the bike and source filter of the list, and the year in review opens with them.
- **Import log:** the symbol next to the file name, the state **Attached** and a filter **FIT | GPX**.

## Analysis, records and comparison without power
Many GPX files have no power. Wattspur then calculates with what is there and says how many rides that is:
- Work and calories add up **only the rides with power**; with none you see a dash. Distance, ride time and CO₂ count every ride.
- Under a figure that only some rides have, a line like **9 of 12 rides** shows (ascent, work, calories, average power and cadence in the analysis; the ascent in the year in review and in an ascent goal; the average in the comparison).
- Averages of power and cadence are weighted by ride time over the rides that have the value.
- A ride without power or ascent holds **no record** for them; it can still be the longest ride.
- In the comparison, work and calories of a ride without power stay empty and do not pull the average down.

See [Metrics](05-metrics.md#values-from-a-gpx-file) for the details.

---
Next: [Views](04-views.md) · [FAQ](06-faq.md)
