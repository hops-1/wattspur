#!/bin/bash
# Local CI: runs the steps of .github/workflows/ci.yml on this Mac and reports the
# result as the commit status "local-ci", which shows next to the GitHub checks in
# the pull request. For when GitHub's macOS runners are not available (free minutes
# used up, or "job was not acquired by Runner"). Costs no Actions minutes.
#
#   scripts/ci-local.sh          # checks HEAD; it must be committed and pushed
#
# Same steps as GitHub, plus a Release build (the DMG is built in Release).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [ -n "$(git status --porcelain)" ]; then
    echo "Uncommitted changes: commit them first, so the status belongs to what was tested." >&2
    exit 1
fi
SHA=$(git rev-parse HEAD)
git fetch -q origin
if [ -z "$(git branch -r --contains "$SHA")" ]; then
    echo "Commit ${SHA:0:7} is not on GitHub yet: push it first." >&2
    exit 1
fi
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

status() {
    gh api -X POST "repos/$REPO/statuses/$SHA" -f state="$1" -f context=local-ci \
        -f description="$2" >/dev/null
}

STEP=""
trap 'status failure "Failed: $STEP"; echo "local-ci: failed at $STEP" >&2' ERR

TOOLCHAIN="$(xcodebuild -version | head -1), macOS $(sw_vers -productVersion)"
status pending "Running ($TOOLCHAIN)"

STEP="WattspurKit tests"
echo "== $STEP"
(cd Packages/WattspurKit && swift test)

STEP="Generate Xcode project"
echo "== $STEP"
xcodegen generate

for CONFIG in Debug Release; do
    STEP="$CONFIG build"
    echo "== $STEP"
    xcodebuild -project Wattspur.xcodeproj -scheme Wattspur -configuration "$CONFIG" \
        -destination 'platform=macOS' -derivedDataPath .build/xcode build -quiet
done

status success "Kit tests, Debug and Release build ($TOOLCHAIN)"
echo "local-ci: passed for ${SHA:0:7}"
