# iPhone and iCloud

From Wattspur 1.8.4 on, Wattspur also runs on the iPhone, first for testers on TestFlight. The Mac and the iPhone share **one library** over iCloud: what you record on the iPhone is on the Mac shortly after, and what you import on the Mac shows on the iPhone. The iCloud is your own. There is no Wattspur server and no Wattspur account.

## Getting Wattspur onto the iPhone
1. You get an invitation to **TestFlight** by email or as a link.
2. Get the **TestFlight** app from the App Store and open the invitation in it.
3. Tap **Install** next to Wattspur.

## Turning sync on
**On the Mac:** **Wattspur › Settings › iCloud › Sync with iCloud**. The first time, Wattspur saves a backup of your library beside it first. Sync starts the next time you open Wattspur. The first upload takes a few minutes, depending on how much there is.

**On the iPhone:** **More › Sync with iCloud** is already on in a new installation. After the first sync your rides from the Mac are there.

The Mac and the iPhone have to be signed in to iCloud with the same Apple Account.

**What syncs:** rides with their time series, routes and original files, bikes, profile, goals, saved routes and the trash. Your settings and the watched folder stay on each device.

**How fast:** a change reaches the other device after 30 seconds to about a minute. Without a network the iPhone records as usual. The ride reaches the Mac once there is a network again.

## The same rider and bike twice
A new iPhone first makes its own rider and its own “My eBike”. After the first sync, Wattspur merges them with those of the Mac, on both devices. The older one always stays, usually the Mac's. The same holds for goals and for a file you imported on both devices.

## Is everything synced?
- **On the Mac:** **Settings › iCloud** shows “On. Last synced … ago.”
- **On the iPhone:** **More › iCloud › Last synced**.

Short delays are normal and get no message. You see a hint when:
- the device is not signed in to iCloud, or iCloud is off for Wattspur,
- your iCloud storage is full,
- there has been no connection for two minutes.

On the iPhone a warning also shows while changes still wait for the upload.

## Careful when turning it off
If you turn iCloud off for Wattspur on the iPhone (**Settings › your name › iCloud**) or sign out of iCloud, iOS deletes the copy on the iPhone. Your rides stay in iCloud and on the Mac and come back once it is on again. A ride that was not uploaded yet may be lost, though. So turn it off only when **Last synced** shows no warning.

## Without iCloud
If you do not want to use iCloud, or your storage is full and you do not want a larger plan, turn off **More › Sync with iCloud** on the iPhone. The iPhone then works as before 1.8.4:
- **Through a folder:** on the Mac, turn on **Settings › Import › Provide rides for the iPhone**. The iPhone then shows the rides the Mac writes into the folder, and puts new recordings there as GPX. The folder can be in iCloud Drive, but also in Dropbox or OneDrive, as long as the Mac watches it.
- **By AirDrop:** send a recording to the Mac with **Share GPX** and import it there like any other file.

On the Mac, leave **Sync with iCloud** off then.

## Sharing a ride as GPX
At the top right of a ride's detail, or by touching and holding a ride in the list: **Share GPX**. The file holds the whole track with time and altitude, and the bike. You can AirDrop it to the Mac, save it in the Files app or open it in komoot. Rides without GPS cannot be shared.

## Motorcycle
While recording, Wattspur leaves out points that would mean an impossible speed. That removes GPS jumps. For an e-bike the limit is 100 km/h. If you record on a motorcycle, choose **More › Recording › Vehicle › Motorcycle**. The limit is then 300 km/h.

So that motorcycle rides do not count in the totals of your bicycles, add a bike of the type **Motorcycle** in Profile (see [Profile and Bikes](07-profile-and-bikes.md)).

---
Next: [FAQ](06-faq.md) · [Contents](README.md)
