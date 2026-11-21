#!/bin/bash
# Line coverage of the package, per module and in total, over all test bundles (S-33).
# `swift test --show-codecov-path` exports only the first test bundle (WattspurCore), which reads
# too good; this script asks llvm-cov with every bundle at once.
#   scripts/coverage.sh            run the tests with coverage, then report
#   scripts/coverage.sh --no-run   report on the last coverage run
set -euo pipefail
cd "$(dirname "$0")/../Packages/WattspurKit"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [ "${1:-}" != "--no-run" ]; then
    swift test --no-parallel --enable-code-coverage >/dev/null
fi

BIN=$(swift build --show-bin-path 2>/dev/null)
PROFDATA="$BIN/codecov/default.profdata"
[ -f "$PROFDATA" ] || { echo "coverage: no $PROFDATA, run without --no-run first" >&2; exit 1; }

OBJECTS=()
for bundle in "$BIN"/*Tests.xctest; do
    name=$(basename "$bundle" .xctest)
    binary="$bundle/Contents/MacOS/$name"
    [ -f "$binary" ] || binary="$bundle"
    if [ ${#OBJECTS[@]} -eq 0 ]; then OBJECTS+=("$binary"); else OBJECTS+=("-object" "$binary"); fi
done
[ ${#OBJECTS[@]} -gt 0 ] || { echo "coverage: no test bundles in $BIN" >&2; exit 1; }

# One line per source file: covered and total lines; summed per module under Sources/.
xcrun llvm-cov export -summary-only -instr-profile "$PROFDATA" "${OBJECTS[@]}" \
    | /usr/bin/python3 -c '
import json, sys, collections
files = json.load(sys.stdin)["data"][0]["files"]
modules = collections.OrderedDict()
for f in files:
    path = f["filename"]
    if "/Sources/" not in path:
        continue
    module = path.split("/Sources/", 1)[1].split("/", 1)[0]
    lines = f["summary"]["lines"]
    covered, count = modules.get(module, (0, 0))
    modules[module] = (covered + lines["covered"], count + lines["count"])
total_covered = sum(c for c, _ in modules.values())
total_count = sum(n for _, n in modules.values())
for module, (covered, count) in sorted(modules.items()):
    print(f"{module:20} {100 * covered / count:5.1f} %  ({count - covered} of {count} lines not covered)")
label = "total"
print(f"{label:20} {100 * total_covered / total_count:5.1f} %  ({total_count - total_covered} of {total_count} lines not covered)")
'
