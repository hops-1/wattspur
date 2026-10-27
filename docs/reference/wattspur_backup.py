#!/usr/bin/env python3
"""Read a Wattspur backup folder with Python's standard library only (B-177).

The database inside a backup is Wattspur's internal storage and may change with
any version; see data-exchange.md next to this file. This script is an example,
tested against the version it ships with.

    python3 wattspur_backup.py BACKUP                 rides as CSV
    python3 wattspur_backup.py BACKUP --samples ID    one ride's time series as CSV
    python3 wattspur_backup.py BACKUP --original ID   one ride's original file (FIT or GPX)
"""

import argparse
import csv
import datetime
import json
import pathlib
import plistlib
import sqlite3
import sys
import uuid

# Dates are seconds since 1 January 2001, 00:00 UTC.
REFERENCE_DATE = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)
SAMPLE_KEYS = ["time", "latitude", "longitude", "altitude", "distance", "speed",
               "power", "cadence", "cadenceMeasured", "heartRate", "temperature"]


def open_backup(folder):
    """The manifest and a read-only connection to the database."""
    manifest = json.loads((folder / "manifest.json").read_text())
    if manifest.get("format", 0) > 1:
        print(f"note: backup format {manifest['format']} is newer than this script knows", file=sys.stderr)
    database = (folder / "default.store").resolve()
    connection = sqlite3.connect(f"{database.as_uri()}?mode=ro&immutable=1", uri=True)
    return manifest, connection


def date(value):
    return None if value is None else REFERENCE_DATE + datetime.timedelta(seconds=value)


def external(folder, value):
    """The bytes of a column marked external: inline after 0x01, or a file named after 0x02."""
    if value is None or len(value) == 0:
        return None
    if value[0] == 1:
        return bytes(value[1:])
    if value[0] == 2:
        name = bytes(value[1:]).rstrip(b"\0").decode("utf-8")
        return (folder / ".default_SUPPORT" / "_EXTERNAL_DATA" / name).read_bytes()
    raise ValueError(f"unknown storage marker {value[0]}")


def counted_rides(connection):
    """Rides as Wattspur counts them: not in the trash, not the sample, not a part of a merged ride."""
    return connection.execute("""
        SELECT r.Z_PK, r.ZID, r.ZNAME, r.ZSTARTDATE, r.ZTIMEZONEIDENTIFIER, r.ZDISTANCE, r.ZTIMERTIME,
               r.ZTOTALASCENT, r.ZAVERAGEPOWER, r.ZSOURCEFORMAT, b.ZNAME
        FROM ZRIDE r LEFT JOIN ZBIKE b ON b.Z_PK = r.ZBIKE
        WHERE r.ZDELETEDAT IS NULL AND r.ZISSAMPLE = 0 AND r.ZMERGEDINTO IS NULL
        ORDER BY r.ZSTARTDATE""").fetchall()


def find_ride(connection, prefix):
    """The ride whose UUID starts with `prefix` (dashes and case ignored)."""
    wanted = prefix.replace("-", "").upper()
    rows = [row for row in connection.execute("SELECT Z_PK, ZID, ZSAMPLESDATA, ZSOURCEFILE FROM ZRIDE")
            if row[1] is not None and uuid.UUID(bytes=row[1]).hex.upper().startswith(wanted)]
    if len(rows) != 1:
        sys.exit(f"{len(rows)} rides match {prefix!r}; give more characters of the id")
    return rows[0]


def write_rides(connection, out):
    writer = csv.writer(out)
    writer.writerow(["id", "name", "start_utc", "time_zone", "distance_km", "ride_time_min",
                     "ascent_m", "average_power_w", "source", "bike"])
    for _, ride_id, name, start, zone, distance, timer, ascent, power, source, bike in counted_rides(connection):
        writer.writerow([uuid.UUID(bytes=ride_id), name, date(start).isoformat(), zone or "",
                         round((distance or 0) / 1000, 2), round((timer or 0) / 60, 1),
                         ascent if ascent is not None else "", power if power is not None else "",
                         source, bike or ""])


def write_samples(folder, connection, prefix, out):
    _, _, samples_data, _ = find_ride(connection, prefix)
    data = external(folder, samples_data)
    samples = plistlib.loads(data) if data else []
    writer = csv.DictWriter(out, fieldnames=SAMPLE_KEYS, extrasaction="ignore")
    writer.writeheader()
    for sample in samples:
        writer.writerow(sample)


def write_original(folder, connection, prefix, out):
    _, _, _, source_file = find_ride(connection, prefix)
    row = connection.execute("SELECT ZFILENAME, ZDATA FROM ZSOURCEFILE WHERE Z_PK = ?", (source_file,)).fetchone()
    if row is None or row[1] is None:
        sys.exit("this ride has no original file (a merged ride keeps the files in its parts)")
    print(f"original file: {row[0]}", file=sys.stderr)
    out.write(external(folder, row[1]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("backup", type=pathlib.Path, help="the folder 'Wattspur Backup …'")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--samples", metavar="ID", help="time series of the ride with this id")
    group.add_argument("--original", metavar="ID", help="original file of the ride with this id")
    args = parser.parse_args()

    manifest, connection = open_backup(args.backup)
    print(f"backup of {manifest['createdAt']}, Wattspur {manifest['appVersion']}", file=sys.stderr)
    if args.samples:
        write_samples(args.backup, connection, args.samples, sys.stdout)
    elif args.original:
        write_original(args.backup, connection, args.original, sys.stdout.buffer)
    else:
        write_rides(connection, sys.stdout)


if __name__ == "__main__":
    main()
