# Install Wattspur

Wattspur comes as a disk image (`Wattspur-<version>-<build>.dmg`); get the latest version from [Releases](https://github.com/hops-1/wattspur/releases/latest). From version 1.8.3 it is signed with Developer ID and notarized by Apple, so it opens without a question. Older versions are not notarized; macOS asks once before their first start (see below).

## Install
1. Open the DMG with a double-click.
2. Drag **Wattspur** onto the **Applications** folder in the same window.
3. Eject the disk image (in the Finder sidebar, or drag it to the Trash).

## Open it the first time (versions up to 1.8.2)
Wattspur 1.8.3 and newer open directly: double-click, done. The steps below are only for older versions.

1. Open Wattspur from the Applications folder.
   macOS says that “Wattspur” could not be verified. Click **Done**, not “Move to Trash”.
2. Open **System Settings › Privacy & Security** and scroll down to **Security**.
3. Next to “Wattspur was blocked to protect your Mac”, click **Open Anyway**.
4. Confirm with your password or Touch ID, then click **Open Anyway** once more.

You only need to do this once. After that Wattspur opens like any other app.

> Since macOS 15, right-click › Open no longer skips this check. The way through System Settings is the only one.

## Update
Download the new DMG and drag Wattspur onto the Applications folder again. Choose **Replace**. Your rides and settings stay. macOS may ask once more as described above. What is new is listed in the [changelog](../../../CHANGELOG.md).

## Uninstall
1. Quit Wattspur and drag it from Applications to the Trash.
2. Your rides are stored in `~/Library/Containers/io.github.hops-1.wattspur`. Delete that folder too if you want to remove them. Files in your import folder in iCloud Drive are not touched.

---
Next: [First launch](02-first-launch.md)
