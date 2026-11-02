#!/bin/bash
# Builds Wattspur.app and packs it into a DMG for testers (B-046, NFR-18, B-215).
#
#   scripts/build-dmg.sh            → dist/Wattspur-<version>-<build>.dmg
#   scripts/build-dmg.sh --check    → only says which way it would sign and what is missing
#
# Two ways, chosen in the ignored Config/Local.xcconfig (template: Local.xcconfig.example):
# - Ad hoc (default, without a developer account): signed with "-" and not notarized, so Gatekeeper
#   asks once on the tester's Mac; "Read Me First.txt" in the DMG and the user guide explain "Open Anyway".
# - Developer ID (WATTSPUR_MAC_DISTRIBUTION = developer-id): exported with Developer ID, app and DMG
#   notarized with notarytool and stapled. The notary password lives in the keychain under
#   WATTSPUR_NOTARY_PROFILE (xcrun notarytool store-credentials), never in a file. Steps: docs/RELEASE.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

CHECK_ONLY=false
[ "${1:-}" = "--check" ] && CHECK_ONLY=true

# A value from Config/Local.xcconfig, the last line that sets it; empty if the file or the line is missing.
setting() {
    [ -f Config/Local.xcconfig ] || return 0
    sed -n "s|^[[:space:]]*$1[[:space:]]*=[[:space:]]*\(.*\)$|\1|p" Config/Local.xcconfig | tail -1 | sed 's/[[:space:]]*$//'
}
DISTRIBUTION="$(setting WATTSPUR_MAC_DISTRIBUTION)"
TEAM="$(setting DEVELOPMENT_TEAM)"
NOTARY_PROFILE="$(setting WATTSPUR_NOTARY_PROFILE)"
ENTITLEMENTS="$(setting WATTSPUR_MAC_ENTITLEMENTS)"

case "$DISTRIBUTION" in
    "") MODE=adhoc ;;
    developer-id) MODE=developer-id ;;
    *) echo "error: WATTSPUR_MAC_DISTRIBUTION = '$DISTRIBUTION' in Config/Local.xcconfig; use developer-id or remove the line." >&2; exit 1 ;;
esac

# The Developer ID certificate of the team in the keychain, e.g. "Developer ID Application: Name (ABCDE12345)".
developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n "s/.*\"\(Developer ID Application: .*(${TEAM})\)\"$/\1/p" | head -1
}

# Everything the Developer ID way needs; prints each missing piece and fails if one is missing.
check_developer_id() {
    local missing=0
    if [ -z "$TEAM" ]; then
        echo "  missing: DEVELOPMENT_TEAM in Config/Local.xcconfig" >&2; missing=1
    elif [ -z "$(developer_id_identity)" ]; then
        echo "  missing: certificate “Developer ID Application: … ($TEAM)” in the keychain (Xcode › Settings › Accounts › Manage Certificates)" >&2; missing=1
    fi
    if [ -z "$NOTARY_PROFILE" ]; then
        echo "  missing: WATTSPUR_NOTARY_PROFILE in Config/Local.xcconfig" >&2; missing=1
    elif ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "  missing: keychain profile “$NOTARY_PROFILE” for notarytool (xcrun notarytool store-credentials $NOTARY_PROFILE …)" >&2; missing=1
    fi
    if [ "$ENTITLEMENTS" != "App/Wattspur-iCloud.entitlements" ]; then
        echo "  note: WATTSPUR_MAC_ENTITLEMENTS is not App/Wattspur-iCloud.entitlements, so the app has no iCloud sync" >&2
    fi
    return $missing
}

if [ "$MODE" = adhoc ]; then
    echo "==> Signing: ad hoc, not notarized (no WATTSPUR_MAC_DISTRIBUTION in Config/Local.xcconfig)"
else
    echo "==> Signing: Developer ID for team $TEAM, notarized with profile “$NOTARY_PROFILE”"
    if ! check_developer_id; then
        echo "error: the Developer ID way is not ready (see above). Remove WATTSPUR_MAC_DISTRIBUTION for an ad-hoc DMG." >&2
        exit 1
    fi
fi
if $CHECK_ONLY; then
    echo "==> Check passed"
    exit 0
fi

VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml | head -1)"
# The build number counts the commits, so every DMG gets a higher one. The public
# repository started without the 217 commits of the private one (V-05); they are
# added, so 1.6.0 continues above the testers' 1.5.0 (build 179).
ARCHIVED_COMMITS=217
BUILD="$((ARCHIVED_COMMITS + $(git rev-list --count HEAD)))"
NAME="Wattspur-${VERSION}-${BUILD}"
WORK="$ROOT/.build/dmg"
DIST="$ROOT/dist"

if [ -n "$(git status --porcelain)" ]; then
    echo "warning: uncommitted changes – the About window will show the commit as '-dirty'." >&2
fi

echo "==> Wattspur $VERSION ($BUILD)"
rm -rf "$WORK"
mkdir -p "$WORK/stage" "$DIST"

echo "==> Generating the Xcode project"
xcodegen generate --quiet

echo "==> Archiving (Release)"
ARCHIVE_SIGNING=()
if [ "$MODE" = adhoc ]; then
    # Ad hoc even if Local.xcconfig names a team or the iCloud entitlements for development.
    ARCHIVE_SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=App/Wattspur.entitlements)
else
    ARCHIVE_SIGNING=(-allowProvisioningUpdates)
fi
xcodebuild archive \
    -project Wattspur.xcodeproj -scheme Wattspur -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$WORK/Wattspur.xcarchive" \
    -derivedDataPath "$ROOT/.build/xcode-release" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    "${ARCHIVE_SIGNING[@]}" \
    -quiet

if [ "$MODE" = adhoc ]; then
    APP="$WORK/Wattspur.xcarchive/Products/Applications/Wattspur.app"
else
    echo "==> Exporting with Developer ID"
    cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>iCloudContainerEnvironment</key>
    <string>Production</string>
</dict>
</plist>
PLIST
    xcodebuild -exportArchive -archivePath "$WORK/Wattspur.xcarchive" \
        -exportPath "$WORK/export" -exportOptionsPlist "$WORK/ExportOptions.plist" \
        -allowProvisioningUpdates -quiet
    APP="$WORK/export/Wattspur.app"
fi

echo "==> Checking the signature"
codesign --verify --deep --strict "$APP"
codesign --display --verbose=2 "$APP" 2>&1 | grep -E '^(Identifier|Authority|Signature|Runtime|TeamIdentifier)' || true

# Sends a file to Apple's notary service, waits for the answer and staples the ticket to `staple`.
notarize() {
    local file="$1" staple="$2"
    echo "==> Notarizing $(basename "$file") (takes a few minutes)"
    if ! xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json \
            > "$WORK/notary.json"; then
        cat "$WORK/notary.json" >&2
        exit 1
    fi
    local id status
    id="$(sed -n 's/.*"id" *: *"\([^"]*\)".*/\1/p' "$WORK/notary.json" | head -1)"
    status="$(sed -n 's/.*"status" *: *"\([^"]*\)".*/\1/p' "$WORK/notary.json" | head -1)"
    if [ "$status" != "Accepted" ]; then
        echo "error: notarization $status. Apple's log:" >&2
        xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
        exit 1
    fi
    xcrun stapler staple "$staple"
    xcrun stapler validate "$staple"
}

if [ "$MODE" = developer-id ]; then
    ditto -c -k --keepParent "$APP" "$WORK/Wattspur.zip"
    notarize "$WORK/Wattspur.zip" "$APP"
    spctl --assess --type execute --verbose=2 "$APP"
fi

echo "==> Building the disk image"
ditto "$APP" "$WORK/stage/Wattspur.app"
ln -s /Applications "$WORK/stage/Applications"
if [ "$MODE" = adhoc ]; then
    cp "$ROOT/scripts/dmg-read-me-first.txt" "$WORK/stage/Read Me First.txt"
else
    cp "$ROOT/scripts/dmg-read-me-first-notarized.txt" "$WORK/stage/Read Me First.txt"
fi
rm -f "$DIST/$NAME.dmg"
hdiutil create -quiet -volname "Wattspur $VERSION" -srcfolder "$WORK/stage" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DIST/$NAME.dmg"

if [ "$MODE" = developer-id ]; then
    codesign --sign "$(developer_id_identity)" --timestamp "$DIST/$NAME.dmg"
    notarize "$DIST/$NAME.dmg" "$DIST/$NAME.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DIST/$NAME.dmg"
fi

shasum -a 256 "$DIST/$NAME.dmg" | tee "$DIST/$NAME.dmg.sha256"
echo "==> Done: dist/$NAME.dmg"
