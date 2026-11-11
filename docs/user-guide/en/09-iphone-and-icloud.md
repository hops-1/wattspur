# iPhone and iCloud

From Wattspur 1.8.4 on, Wattspur also runs on the iPhone, first for testers on TestFlight. The Mac and the iPhone share **one library** over iCloud: what you record on the iPhone is on the Mac shortly after, and what you import on the Mac shows on the iPhone. The iCloud is your own. There is no Wattspur server and no Wattspur account.

## Getting Wattspur onto the iPhone
1. You get an invitation to **TestFlight** by email or as a link.
2. Get the **TestFlight** app from the App Store and open the invitation in it.
3. Tap **Install** next to Wattspur.

## Turning sync on
**On the Mac:** **Wattspur › Settings › iCloud › Sync with iCloud**. Each time, Wattspur first saves a backup of your library beside it. Sync starts the next time you open Wattspur. The first upload takes a few minutes, depending on how much there is.

**On the iPhone:** **More › iCloud & Library › Sync with iCloud** is already on in a new installation. After the first sync your rides from the Mac are there.

The Mac and the iPhone have to be signed in to iCloud with the same Apple Account.

**What syncs:** rides with their time series, routes and original files, bikes, profile, goals, saved routes and the trash. Your settings and the watched folder stay on each device.

**How fast:** a change reaches the other device after 30 seconds to about a minute. Without a network the iPhone records as usual. The ride reaches the Mac once there is a network again.

## The tab “More”
From 0.6.2 on, **More** is a list like the iOS Settings. Each row opens a page of its own:
- **Profile** (at the top, with photo and name): your data for the calories. You set it on the Mac under **Profile**; with iCloud it comes to the iPhone. Editing it on the iPhone comes with a later version.
- **Recording:** the vehicle, e-bike or motorcycle.
- **Maps:** the map style for every map.
- **iCloud & Library:** sync on or off, when it last synced, hints when something is wrong.
- **Trash:** deleted rides, for 30 days.
- **Help & Handbook:** this handbook and what is new in each version.
- **About Wattspur:** version, map sources and privacy.
- **Test Tools:** only in builds from TestFlight.

In landscape the list is on the left and the chosen page on the right.

## The same rider and bike twice
A new iPhone first makes its own rider and its own “My eBike”. After the first sync, Wattspur merges them with those of the Mac, on both devices. The older one always stays, usually the Mac's. The same holds for goals and for a file you imported on both devices.

## Is everything synced?
- **On the Mac:** **Settings › iCloud** shows “On. Last synced … ago.”
- **On the iPhone:** **More › iCloud & Library › Last synced**.

Short delays are normal and get no message. You see a hint when:
- the device is not signed in to iCloud, or iCloud is off for Wattspur,
- your iCloud storage is full,
- there has been no connection for two minutes.

On the iPhone a warning also shows while changes still wait for the upload.

## Careful when turning it off
If you turn iCloud off for Wattspur on the iPhone (**Settings › your name › iCloud**) or sign out of iCloud, iOS deletes the copy on the iPhone. Your rides stay in iCloud and on the Mac and come back once it is on again. A ride that was not uploaded yet may be lost, though. So turn it off only when **Last synced** shows no warning.

## Without iCloud
If you do not want to use iCloud, or your storage is full and you do not want a larger plan, turn off **More › iCloud & Library › Sync with iCloud** on the iPhone. It takes effect the next time Wattspur opens. The rides then stay on the iPhone, and new recordings too. To get a ride to the Mac, send it with **Share GPX**, e.g. by AirDrop, and import it there like any other file.

**The folder exchange has ended:** up to the iPhone app 0.5 and Wattspur 1.8.9, the iPhone could also show the rides the Mac wrote into the folder “Wattspur Import”. With the iPhone app 0.6 and Wattspur 1.8.10 this way is gone. If you used it, the iPhone tells you once; turn on sync with iCloud on both, and your rides from the Mac come to the iPhone. A subfolder “iPhone” left in the import folder is no longer used; you can delete it.

## Looking at a ride
Tap a ride in the list. The map is at the top, the charts right below it.
- **Swipe:** with iCloud, each measure has a page of its own: speed, power, cadence, heart rate and elevation. Only what the ride has gets a page. The dots below show where you are. Each page names the maximum and the average; elevation names the ascent and the descent.
- **Touch, hold and move:** a line marks the spot. At the top you then see the distance and the value there, for example “0.4 km · 25.2 km/h”. A dot on the map shows where that was. When you let go, the line and the dot disappear.

## Editing a ride
The pencil at the top right of a ride's detail changes its **name** and its **bike**. With iCloud the Mac gets the change too. Without iCloud it stays on the iPhone.

## Rides from the Flow app
The Bosch file of a ride has more values than a GPS recording, such as power and cadence. This is how it gets onto the iPhone:
1. In the **Flow app**, open the ride and share it as a **FIT** file.
2. Choose **Wattspur** in the share menu. You can also open a FIT or GPX file in the **Files** app with Wattspur.

**With iCloud** it becomes a ride on the iPhone and reaches the Mac too. Wattspur asks the same questions as the Mac:
- **Which bike?** A GPX file does not say which bike it belongs to. With two bikes or more, Wattspur asks.
- **Already in the library:** if you recorded the ride with the iPhone too, you can choose **Use the Bosch Values**, **Keep Both** or **Skip**. Wattspur shows the start, distance and time of both.
- A GPX file for a Bosch ride is attached to the ride. The Bosch values stay.
- **One tour in several Bosch parts:** the Flow app splits a tour with long pauses into several rides, the iPhone records it as one. When the Bosch rides lie wholly inside the time of your recording and add up to its distance, Wattspur merges them into one ride. It gets the recording's name and bike and its heart rate, lean angle and surface. The recording itself goes to the trash, where you can restore it. It does not matter which file comes last. If you imported the parts earlier, drop one of their FIT files once more.

**Without iCloud** it becomes a ride on the iPhone only.

## FIT and GPX from the Files app
From 0.6.2 on, Wattspur also takes files that are already in the Files app, without a Mac:
- **Choose files:** in **Rides** the **+** button beside the search, or **More › iCloud & Library › Import Files …**. You can choose several FIT and GPX files at once, also from iCloud Drive and other providers.
- **Folder “Import”:** put files into **On My iPhone › Wattspur › Import** in the Files app. Wattspur reads them the next time it opens. Afterwards they are in **Importiert**, or in **Fehler** if a file cannot be read.

The same questions as above apply: which bike, what happens to a ride that is already there, and a Bosch file completes your recording with power, cadence and heart rate. With many files Wattspur shows at the top how far it is, and a summary at the end, for example “12 new, 3 completed, 1 duplicate”.

## Backing up the library
From 0.7.0 on, the iPhone backs up the whole library too, in the same format as the Mac (**File › Library Backup…**). You find it under **More › iCloud & Library › Backup**.
- **Back Up Library …:** choose a folder, for example in iCloud Drive, under **On My iPhone** or on a USB stick. Wattspur creates a folder “Wattspur Backup …” there and says “Backed Up” with the place.
- **Restore Backup …:** choose a backup folder. Wattspur shows the date, the version and the number of rides and asks you to confirm. Then close Wattspur in the app switcher and open it again: the backup replaces the library. The old library stays in a folder “Library Before Restore …”. With **Sync with iCloud** on, the backup also replaces the rides in iCloud and on the Mac; Wattspur tells you so first. The Mac shows the same state after a few minutes. If the restore fails, your library stays as it was, and Wattspur tells you what to do. Restoring is not possible during a recording.
- **Back Up Automatically:** with the switch on, Wattspur backs up when it opens, if the last backup is older than a week and nothing is being recorded. The backup goes into the folder you chose last, so back up once by hand. Wattspur keeps the newest three automatic backups there and deletes only its own. If the folder is gone, a notice shows below the switch.

A backup from the iPhone restores on the Mac, and the other way round. What a backup holds is described in [Data exchange](../../reference/data-exchange.md).

## Height while recording
While recording, Wattspur measures the height with the iPhone's **barometer**, from the air pressure. That is much calmer than the GPS height alone, so the ascent comes closer to Bosch. The height above sea level still comes from the GPS: Wattspur keeps matching the two. So a change in the weather during the ride does not get in the way either.

The first time you record, the iPhone asks once for **Motion & Fitness**. If you do not allow it, Wattspur uses the GPS height as before. You can change it in **Settings › Privacy & Security › Motion & Fitness**.

## Lean angle, acceleration and surface
From 0.5.1 on, the iPhone also reads its motion sensors while recording, with the same permission **Motion & Fitness** as the barometer. The ride detail then has tiles for the strongest lean to the left and right, the strongest acceleration and braking, the best time from a standstill and the share of uneven surface. The carousel has the page **Lean Angle**. The map colours the track by lean angle; the switch at the top of the map changes to **Surface**. How the values come about is under [Metrics](05-metrics.md). The Mac shows the same values in the ride detail.

For tests, **More › Test Tools** has the switch **Record Raw Motion**. When it is on, every recording also puts a file into the Files app (**On My iPhone › Wattspur › Bewegung**), about 20 MB per hour. Normally it stays off. The test tools are only in builds from TestFlight.

## On the road: direction, elevation and profile
- **Map in the direction of travel:** the button at the bottom right of the recording map switches between **north up** and **direction of travel up**, like a navigation app. The direction comes from the GPS movement, not from the compass, which is wrong in a pocket. Standing still and below about 7 km/h the map does not turn.
- **Track by elevation:** the mountain button above it colours the track so far from blue (low) to red (high); the scale grows with the heights you have ridden. In the ride detail, the pink button at the top left of the map chooses between **Lean Angle**, **Surface**, **Elevation** and **Plain**, depending on what the ride has. The legend sits small at the bottom left; tap it to fold it to its colours, tap again for the values.
- **Profile while riding:** swipe the figures below the map aside (in landscape, the figures in the bar on the left). The profile of the ride so far grows there; choose **Altitude** or **Speed** at the top.

Wattspur remembers all three settings.

## Map styles
From 0.6 on, the iPhone has the map styles of the Mac: Apple's **Standard**, **Satellite** and **Hybrid**, and **OpenStreetMap**, **CyclOSM** (for cyclists, with cycle paths in blue) and **OpenTopoMap** (contour lines and hill shading). Choose the style with the layers button at the top right of a ride's map and of the recording map, or under **More › Maps › Map Style**. It counts for every map, including the recording, and Wattspur remembers it.

The OpenStreetMap styles come from servers run by volunteers. Wattspur loads only the tiles on screen and keeps them for a while, so areas you have seen also show without a network. In an area you have not seen, the route shows on a plain ground. The **credit** of the map stays at the bottom right; in the ride's map, tap it to read the licence.

## Map of all rides
The tab **Map** shows all your rides on one map.
- **Lines** or **Heat Map** (in the layers button, above the map styles): the heat map colours each area by how many rides pass there, from blue (one ride) to red (20 and more).
- **Period** (calendar button) and **Bike** (only from two bikes on) choose which rides show. At the top right, the layers button chooses the map style.
- Below the buttons you see how many rides it is and how far, for example “84 rides · 1,520 km”.
- **Tap a route:** a list shows the rides there, and they stand out on the map. Tap one to open it.

Wattspur remembers the choices. The map shows where you ride, and so where you live. Think before you share a screenshot of it.

## Sharing a ride as GPX
At the top right of a ride's detail, or by touching and holding a ride in the list: **Share GPX**. The file holds the whole track with time and altitude, and the bike. You can AirDrop it to the Mac, save it in the Files app or open it in komoot. Rides without GPS cannot be shared.

## In the handlebar mount (landscape)
Most handlebar mounts hold the iPhone sideways. Wattspur works in landscape too:
- **While recording** the map fills the screen. On the left a bar shows the speed large, with the average, distance, time, height and ascent below it, and Pause and Stop at the bottom.
- **The tab bar** sits at the bottom left, in every section.
- **Overview:** the last ride on the left, the week, month, year and all rides on the right.
- **Rides:** the list on the left, the chosen ride on the right.

If you do not want the screen to turn, switch on the orientation lock in the Control Center.

## Finding rides
Above the ride list:
- **Search** for a name, for example “Michelstadt”. Upper and lower case do not matter.
- **Period:** this week, this month, this year, the last 30 or 365 days, or all rides.
- **Distance:** under 10 km, 10–25 km, 25–50 km or over 50 km.
- **Bike:** only from two bikes on.

Below it you see how many rides match, for example “2 of 40 rides”. ✕ resets everything. A tap on **This Week**, **This Month** or **This Year** in the overview opens the rides of that period. The Mac uses the same rules, so both find the same rides.

## The recording on the Lock Screen
While you record, the **Lock Screen** shows the time, distance and speed. The button there pauses the ride and resumes it. On iPhones with the **Dynamic Island** the distance shows next to the camera; touch and hold it for more. To stop, open Wattspur: you name the ride and save it there.

## Widget “This Week”
1. Touch and hold an empty spot on the Home Screen.
2. Tap **Edit › Add Widget** and choose **Wattspur**.
3. Choose the small or the medium size.

The widget shows the kilometres and rides of this week, with one bar per day. The medium size also shows your last ride. The numbers are the same as in the overview. On Monday the widget starts at zero by itself.

## Shortcuts and Siri
Say for example:
- “Start a ride with Wattspur”
- “End the ride in Wattspur”: Wattspur opens **Save Ride**, as Stop does.
- “How far did I ride this week in Wattspur”
- “Open my last ride in Wattspur”

On an iPhone set to German, the German sentences apply, for example „Starte eine Fahrt mit Wattspur“. You also find these four as actions in the **Shortcuts** app, for example for an automation when you connect to the bike's holder.

## Motorcycle
While recording, Wattspur leaves out points that would mean an impossible speed. That removes GPS jumps. For an e-bike the limit is 100 km/h. If you record on a motorcycle, choose **More › Recording › Vehicle › Motorcycle**. The limit is then 300 km/h.

So that motorcycle rides do not count in the totals of your bicycles, add a bike of the type **Motorcycle** in Profile (see [Profile and Bikes](07-profile-and-bikes.md)).

---
Next: [FAQ](06-faq.md) · [Contents](README.md)
