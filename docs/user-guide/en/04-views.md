# Views

The window has three parts: the sidebar on the left, the ride list in the middle and the details on the right. Drag the sidebar narrower to see only its icons, or use the button at its top (⌃⌘S).

![Main window](../images/en/main.png)

## Rides
- **Your year** above the list shows the kilometres and rides of the current year with a small bar per month. Click it to open the year in review in [Highlights](#highlights). It follows the bike and source filter of the list.
- Rides are grouped by month, newest first. Each row shows the route as a small line on the left (green dot = start, one line per part of a merged ride), plus the name, the date, the ride time, the distance and the average speed. ★ marks a ride that holds a record. A small **GPX** marks a ride from a GPX file, **+GPX** a Bosch ride with a GPX attached; a Bosch FIT alone has no symbol.
- **Search** by name in the field above the list.
- **Sort and filter** with the button next to the search field: sort by date, distance, ride time, ascent or average power; show this week, this month, this year, the last 30 or 365 days, or all rides. From two bikes on you can also show one bike, and once you have a GPX ride, one source: all sources, Bosch FIT (including attached GPX) or GPX.
- **Rename** a ride with a right-click › Rename….
- **Show Similar Rides** (right-click) filters the list to the rides on the same route, see [Similar rides](#similar-rides).
- **Export as GPX…** (right-click) saves the route of a ride, see [Ride detail](#ride-detail).
- **Delete** rides with the Delete key or right-click › Move to Trash. This works for all selected rides; for more than one, Wattspur asks first. ⌘Z brings them back.
- **Merge rides** that belong together, e.g. a ride recorded in two parts because of a coffee break: select them, then right-click › Merge … Rides…, or click **Merge…** next to the selection. Rides that overlap in time cannot be merged. A pause on the same day counts as a pause; across days only the riding times count. The merged ride shows “2 parts” in the list; **Split** above its details brings the original rides back.
- **Merging suggested:** after an import, a hint above the list says when rides on the same day probably belong together (“2 rides from 15 Oct probably belong together”): **Merge** opens the merge dialog, **Not Now** hides the hint. The import log shows the same line with a button. Wattspur never merges by itself. **Settings › Import › Merging** sets the longest gap between the rides, or switches the hint off.
- **Several rides:** select them with ⌘-click or ⇧-click. Until you have done this once, a tip below the list reminds you; ✕ hides it. Wattspur shows their total distance and time, and **Analyze Selected Rides** (⇧⌘A) opens the analysis for exactly these rides.
- **Compare rides:** select 2 to 4 rides and click **Compare** (⇧⌘C) or right-click › Compare … Rides. See [Comparing rides](#comparing-rides) below.

## Similar rides
A commute or a favourite loop: Wattspur finds the rides that took the same way.
- **Start:** right-click a ride › **Show Similar Rides**, or the **Similar Rides** button in the ride detail. This works for rides with a route; the sample ride, rides in the trash and the parts of a merged ride do not count.
- **The list** then shows only the rides on this route, and every row says how similar it is (“97 %”). The ride you asked about stands on top with a target symbol (the reference ride). ⇄ marks a ride in the opposite direction.
- **The chip** above the list names the reference ride and the number of rides (“12 of 15” when the bike, source or period filter or the search hide some). In it:
  - **Similarity:** the slider from 80 to 99 %. The higher, the more exactly a ride has to follow the route. Where the slider starts is set under **Settings › General › Similar rides** (default 90 %).
  - **Both directions** adds rides that took the same route the other way round, for example the way home from work.
  - **Most similar** or **Newest** first.
  - ✕ removes the filter. It stays when you open a ride or switch sections.
- **Compare and analyze:** select 2 to 4 results and click **Compare** ([Comparing rides](#comparing-rides)), or select as many as you like and click **Analyze Selected Rides**.
- **History:** as long as the filter is on and no ride is selected, the right side shows how the rides on this route develop: ride time, average speed, average power or average cadence over time. Each ride is a dot, the line is the average of the last five rides. The best ride has a ★ (the shortest for ride time, otherwise the highest value), the latest ride a ring. Below are best, latest (with how it differs from the average) and average. If some rides lack the value, for example power in GPX files, “9 of 12 rides” says so. A click on a dot opens the ride, **Back to History** (⌘[) returns, and **Analyze These Rides** opens the analysis with all rides on the route. The history takes all results at the chosen similarity, whatever the other filters of the list say.
- What Wattspur means by “similar” is explained under [Metrics](05-metrics.md#similar-rides).

## Comparing rides
The comparison shows 2 to 4 rides side by side, next to the list. The rides selected in the list **are** the comparison: ⌘-click another ride to add it, ✕ above a column removes it, and ↗ shows only that ride. **Done** (Esc) returns to the selection.
- **Map:** all routes on one map, each in the colour and dash pattern of its column, with its marker at the start. Switch between Standard, Satellite and Hybrid at the top right.
- **Charts:** elevation, speed, cadence and power of all rides on top of each other, over the distance. Each ride has its own colour, dash pattern and marker, so the lines can be told apart without colour too. Above each chart are the Bosch averages of each ride; for elevation, the ascent, the descent and the steepest climb instead.
- **Table:** every value of the ride detail, plus values that make rides of different length comparable: calories, ascent and work per km, the coasting share and the average power over the whole ride time. See [Metrics](05-metrics.md#comparing-rides).
- **Best value:** ★ and a tinted cell mark the best value of a row, but only where more or less is clearly better: average speed, average power and power over ride time (more is better), and paused time (less is better). All other rows are neutral.
- **Difference from Average:** the switch at the top adds the difference to your average ride under each value, for example “+2.1 km/h · +9 %”, and a column with the average.
- **Export PDF** at the top left (⇧⌘E) opens the comparison as a PDF in Preview, ready to print or share; the arrow next to it offers **Save as PDF…**. The PDF is A4: the map with all routes and the charts on the first page, then the table, as currently shown (with or without the difference from average).
- The sample ride can be compared but never counts towards the average. A merged ride is one ride.

## Ride detail
- **Map** with the route, the start (green) and the finish (red). Switch between Standard, Satellite and Hybrid at the top right. The default is set in Settings.
- **Key figures:** ride time, distance, average speed, ascent, average power, average cadence, calories and CO₂ saved. Values with ⓘ are estimates, see [Metrics](05-metrics.md). In a ride from a GPX file a small ≈ marks ride time, distance, average speed and ascent (calculated from the track, see [Importing GPX files](08-importing-gpx.md)), and what the file lacks shows as “–” with “Not in the file”.
- **New paths:** how much of the ride ran where you had never ridden before, for example “23 % · 4.5 km”. On the map these stretches are wider and orange. See [Metrics](05-metrics.md#map).
- **Back to Map**, **Back to Analysis** or **Back to Highlights** (⌘[) appears at the top when you opened the ride from there; from Highlights also above several selected rides, back to the same tab and year.
- **Details** (click to fold): total time, paused time, descent, top speed, maximum power and cadence, work and the elevation range.
- **Charts** of elevation, speed, cadence and power, each with its maximum and average. The switch above them chooses what runs along the bottom: **Distance** or **Time** (ride time since the start, as h:mm). Wattspur remembers the choice. Pauses stay empty on the time axis.
  - **Charts and map linked:** hover a chart and a line with the value at that spot appears in all four charts, and a dot on the map shows where it is. Hover the route on the map and the lines follow. A click holds the spot (pin next to the value); another click or Esc lets go. The PDF does not show it.
  - **Joins:** in a merged ride, a fine line in each chart and a short black tick across the route on the map show where two parts meet (also in the PDF). If the parts do not meet, both ends get a tick; on the time axis a pause is framed by two lines.
- **Records:** if the ride holds a record, a line above the key figures names it with the next best value, and the key figure gets a ★ Record badge. **All Records** opens Highlights › Records. The badge stays only as long as the ride holds the record.
- **Export PDF** at the top left (⇧⌘E) opens the ride as a PDF in Preview: map, key figures and details on the first page, the charts on the second. The arrow next to it offers **Save as PDF…**.
- **Export as GPX…** next to it saves the route as a GPX file (GPX 1.1) for komoot, a navigation device or another app: position, elevation and time of every second, plus power and cadence in the extensions that Garmin and Strava use. A merged ride keeps one segment per part, so no straight line is drawn across the gap. The sample ride exports its moved route.

## Analysis
Choose **Analysis** in the sidebar (⌘2). The ride list on the left shows only the rides in the analysis.
- **Show on Map** next to the heading shows exactly these rides on the [map](#map).
- **Period** at the top: week, month, year, a custom range or all rides. ⌘← and ⌘→ step to the previous and next period.
- **Totals:** rides, distance, ride time, ascent, work, calories, CO₂ saved and distance per ride. If only some of the rides have a value (for example power in GPX files), a line such as “9 of 12 rides” says so. Below each value is the change against the previous period, for example “▲ +12 % vs September”.
- **Averages:** speed, power and cadence, weighted by ride time, so a long ride counts more than a short one.
- **Bar chart:** distance, ride time or ascent per day, week, month or year. Click a bar, or select the chart with Tab and use ← and →, to see its values.
- **Trends:** average power, cadence and speed of each ride, with a line for the average of the last five rides.

## Highlights
Choose **Highlights** in the sidebar (⌘4). Three tabs at the top; each has **Export PDF** at the top left (⇧⌘E), which opens the tab as a PDF in Preview or saves it.
- **Year:** distance, rides, ride time, ascent and CO₂ saved of a year, with the change against the year before. The arrows at the top (⌘← and ⌘→) switch years. Below:
  - **Riding days:** a calendar with one square per day, from Monday to Sunday; the darker, the more kilometres (under 10, 10–25, 25–50, 50 km and more). Point at a day to see its distance; click it to show its rides in the list.
  - **Kilometres per month** as bars; the best month is darker.
  - **Records this year.**
- **Records:** your best values across all rides: longest ride, longest ride time, most ascent, highest average speed, highest average power, longest streak of riding days, and top speed, highest power, highest cadence and best 1-minute power. Click a card to show the ride. “New” marks a record set by a ride imported in the last 7 days. See [Metrics](05-metrics.md#highlights).
- **Goals:** kilometres, rides or ascent per week (Monday to Sunday), month or year. **Add Goal…** sets one; each period and metric has at most one goal. Each card shows how far you are, what is left and whether you are on track (at least as far as the time that has passed), and small bars for the last periods. ✎ changes or deletes a goal.
- **New record after an import:** when an imported ride beats one of your records, a notice at the top of the window names it and the value it beat; **Show Ride** opens it. This works for every import, also from the watched folder. The import log notes it too.
- Rides without power or ascent hold no record for them. The year shows “9 of 12 rides” under the ascent when not every ride has it; an ascent goal says so too.
- The sample ride never counts; a merged ride is one ride.

## Map
Choose **Map** in the sidebar (⌘5): all your rides on one map. The ride list on the left shows only the rides in the visible area and follows panning and zooming. A ride selected there is drawn in blue; double-click opens it.
- **Period** at the top, as in the analysis: week, month, year, a custom range or all rides.
- **Only selected rides:** shows the rides selected in the list; 1 to 4 of them in the comparison's colours and dashes.
- **Lines | Heat Map** next to the title:
  - **Lines:** each ride is a translucent line; where you ride often, the routes become stronger and wider. The legend shows what 1, 5, 20 and 60 rides look like.
  - **Heat map:** colours small areas by how many different rides pass there, in fixed steps 1, 2–4, 5–9, 10–19 and 20+ from blue to red.
- **Click a route** to see the rides that pass there, with **Select all in the list**. Click one of them to make it stand out and see its key figures with **Open in Ride Detail**. Esc or a click beside every route closes it; that click also clears the selection in the list, unless **Only selected rides** is on.
- **Below the map:** rides, distance, ride time, ascent, average speed and new paths of the rides in the visible area. Whole rides count with their totals, even if only part of them is visible. **Show in Analysis** analyses exactly these rides.
- **Show all rides** (arrows at the top right) fits the map to all rides; the map type is next to it. The map keeps its area when you switch to another section and back.
- **Export PDF** (⇧⌘E) opens the visible area with the tiles and the legend as a PDF.
- The line below the title names rides without GPS (for example on a trainer). The sample ride appears only when you select it.
- With a GPX ride in the library, a **Source** choice next to the bike filter shows only Bosch or only GPX rides.
- The map shows where you ride, and so where you live. Think before you share a PDF of it.

## Trash
Rides you delete stay in the trash for 30 days. **Restore** puts a ride back into the list. **Empty Trash…** deletes all rides in the trash for good, including their original files.

## Profile and settings
- **Profile** (bottom of the sidebar, ⌘6): your name and body data and your bikes, see [Profile and bikes](07-profile-and-bikes.md).
- **Settings** (⌘,):
  - **General:** language (Wattspur follows macOS), default map type, profile, setup assistant, sample ride.
  - **Import:** watched folder, switching it on and off, status and rules, and when Wattspur suggests merging rides.
  - **Calculation:** reserved for later versions.

## Keyboard
| Keys | Action |
|---|---|
| ⌘1, ⌘2, ⌘3 | Rides, Analysis, Trash |
| ⌘4, ⌘5, ⌘6 | Highlights, Map, Profile |
| ⌘[ | Back to the map, the analysis, Highlights or the history (in the ride detail) |
| ⌘← / ⌘→ | Previous / next year in Highlights › Year |
| ⌘O | Import rides |
| ⌥⌘L | Import window and log |
| ⇧⌘A | Analyze the selected rides |
| ⇧⌘C | Compare the selected rides (2 to 4) |
| ⇧⌘E | Open the ride, the comparison, the Highlights tab or the map as PDF in Preview |
| ⌘← / ⌘→ | Previous / next period in the analysis |
| ⌃⌘S | Collapse or expand the sidebar |
| Delete, ⌘Z | Move to trash, undo |
| ⌘, | Settings |

## Accessibility
- Every key figure and button has a VoiceOver label.
- VoiceOver can play every chart as an **Audio Graph**: on a chart, press VO-Shift-A (⌃⌥⇧A) and choose “Play Audio Graph”, or step through the values. When you hold a spot on the charts and the map with a click, VoiceOver announces it with its values.
- Changes are shown with an arrow and a sign, never by colour alone.

## Help
- **Help › Create Diagnostics…** saves a text file with the import log and the versions of Wattspur and macOS, and optionally a file that failed to import. Nothing is sent anywhere; you decide whom to give the file.
- **Wattspur › About Wattspur** shows the version, the build and the licence.

---
Next: [Metrics](05-metrics.md)
