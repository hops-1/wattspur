#!/bin/bash
# Builds an ad-hoc signed Wattspur.app and packs it into a DMG for testers (B-046, NFR-18).
#
#   scripts/build-dmg.sh            → dist/Wattspur-<version>-<build>.dmg
#
# Without a developer account the app is signed ad hoc ("-") and not notarized,
# so Gatekeeper asks once on the tester's Mac; "Read Me First.txt" in the DMG and
# the user guide explain "Open Anyway".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)"
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
xcodebuild archive \
    -project Wattspur.xcodeproj -scheme Wattspur -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$WORK/Wattspur.xcarchive" \
    -derivedDataPath "$ROOT/.build/xcode-release" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    -quiet

APP="$WORK/Wattspur.xcarchive/Products/Applications/Wattspur.app"

echo "==> Checking the signature"
codesign --verify --deep --strict "$APP"
codesign --display --verbose=2 "$APP" 2>&1 | grep -E '^(Identifier|Signature|Runtime|TeamIdentifier)' || true

echo "==> Building the disk image"
ditto "$APP" "$WORK/stage/Wattspur.app"
ln -s /Applications "$WORK/stage/Applications"
cp "$ROOT/scripts/dmg-read-me-first.txt" "$WORK/stage/Read Me First.txt"
rm -f "$DIST/$NAME.dmg"
hdiutil create -quiet -volname "Wattspur $VERSION" -srcfolder "$WORK/stage" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DIST/$NAME.dmg"

shasum -a 256 "$DIST/$NAME.dmg" | tee "$DIST/$NAME.dmg.sha256"
echo "==> Done: dist/$NAME.dmg"
