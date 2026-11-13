#!/bin/bash
# App Store screenshots of the iPhone app (B-315): German and English, 6.9" (1320 × 2868, iPhone 17 Pro
# Max), from demo rides only (copies of the anonymized sample ride, NFR-12). Never touches a real
# library: it builds Debug, uses its own simulator "Wattspur Screenshots" and erases it first.
#
#   scripts/appstore-screenshots.sh            # all languages, into dist/appstore-screenshots/
#   scripts/appstore-screenshots.sh de-DE      # one language
#
# The debug launch arguments it uses are in iOS/WattspurApp.swift (WattspurDemoRecent, -Tab, -OpenLast, -Record).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

DEVICE_NAME="Wattspur Screenshots"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
BUNDLE_ID="io.github.hops-1.wattspur.ios"
OUT=dist/appstore-screenshots
BUILD=${TMPDIR:-/tmp}/wattspur-screenshots-build
LOCALES=${*:-de-DE en-US}
# A ride along a public street (Straße des 17. Juni, Berlin) for the recording screen; nobody's home.
ROUTE="52.5145,13.3501 52.5150,13.3600 52.5155,13.3700 52.5163,13.3777 52.5163,13.3900"

echo "== Build (Debug, simulator)"
xcodegen generate --quiet
xcodebuild -project Wattspur.xcodeproj -scheme "Wattspur iOS" -configuration Debug \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$BUILD" \
    CODE_SIGNING_ALLOWED=NO build -quiet
APP="$BUILD/Build/Products/Debug-iphonesimulator/Wattspur.app"

DEVICE=$(xcrun simctl list devices -j | /usr/bin/python3 -c "
import json, sys
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == '$DEVICE_NAME' and d['isAvailable']: print(d['udid']); sys.exit()")
if [ -z "$DEVICE" ]; then
    RUNTIME=$(xcrun simctl list runtimes -j | /usr/bin/python3 -c "
import json, sys
print([r['identifier'] for r in json.load(sys.stdin)['runtimes'] if r['platform'] == 'iOS' and r['isAvailable']
       and any(t['identifier'] == '$DEVICE_TYPE' for t in r.get('supportedDeviceTypes', []))][-1])")
    DEVICE=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")
fi

# Starts the app with these extra launch arguments, waits, takes the screenshot.
shot() {
    local file=$1 wait=$2; shift 2
    xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
    # Metric in every language: the rides are European, and miles would mix with metres (heights).
    xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -AppleLanguages "($LANG_CODE)" -AppleLocale "$LOCALE_CODE" \
        -AppleMetricUnits YES -AppleMeasurementUnits Centimeters -WattspurDemoRecent 14 "$@" >/dev/null
    sleep "$wait"
    xcrun simctl io "$DEVICE" screenshot --type=png "$OUT/$LOCALE/$file.png" >/dev/null 2>&1
    echo "   $LOCALE/$file.png"
}

for LOCALE in $LOCALES; do
    LANG_CODE=${LOCALE%%-*}
    LOCALE_CODE=${LOCALE/-/_}
    echo "== $LOCALE"
    mkdir -p "$OUT/$LOCALE"
    rm -f "$OUT/$LOCALE"/*.png
    # A fresh device for each language: no rides but the demo copies, no unfinished recording.
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
    xcrun simctl erase "$DEVICE"
    xcrun simctl boot "$DEVICE"
    xcrun simctl bootstatus "$DEVICE" -b >/dev/null
    xcrun simctl status_bar "$DEVICE" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    xcrun simctl install "$DEVICE" "$APP"
    xcrun simctl privacy "$DEVICE" grant location "$BUNDLE_ID"
    xcrun simctl privacy "$DEVICE" grant motion "$BUNDLE_ID"
    xcrun simctl location "$DEVICE" set 52.5145,13.3501

    # The first start imports the demo rides; give it time, the later starts find them.
    shot 01-overview 12
    shot 02-ride 8 -WattspurDemoOpenLast YES
    shot 03-map 10 -WattspurDemoTab map
    shot 04-rides 6 -WattspurDemoTab rides
    # The recording last: it leaves an unfinished ride behind.
    xcrun simctl location "$DEVICE" start --speed=6 $ROUTE
    shot 05-recording 75 -WattspurDemoRecord YES
    xcrun simctl location "$DEVICE" clear
    xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
done

xcrun simctl status_bar "$DEVICE" clear || true
xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true

# Apple takes 1320 × 2868 for 6.9" (portrait).
for f in "$OUT"/*/*.png; do
    size=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}')
    [ "$size" = "1320 2868 " ] || { echo "wrong size: $f ($size)"; exit 1; }
done
echo "Screenshots: $OUT"
