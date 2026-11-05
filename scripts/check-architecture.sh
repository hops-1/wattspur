#!/bin/bash
# Checks the layer rules of docs/ARCHITECTURE.md that the compiler cannot: WattspurCore must not
# import SwiftData, SwiftUI, AppKit or MapKit (the compiler already forbids what the target does not
# depend on, but a new import line in Core would make the target depend on the system framework).
# The iPhone app (iOS/) must not import AppKit and must take nothing from App/ but resources (B-206).
set -euo pipefail
cd "$(dirname "$0")/.."

CORE="Packages/WattspurKit/Sources/WattspurCore"
if grep -rnE '^import (SwiftData|SwiftUI|AppKit|UIKit|MapKit|Charts)' "$CORE"; then
    echo "architecture: WattspurCore must not import UI or persistence frameworks (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
IOS="iOS iOSShared iOSWidgets"
if grep -rnE '^import AppKit' $IOS; then
    echo "architecture: the iPhone app must not import AppKit (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi

# Sources of the target "Wattspur iOS" in project.yml: from App/ only single resource files
# (sample ride, icon), never Swift files or the whole folder. Shared code belongs in the package.
APP_PATHS=$(awk '
    /^  Wattspur iOS:/ { inside = 1; next }
    inside && /^  [^ ]/ { inside = 0 }
    inside && /^[^ ]/ { inside = 0 }
    inside && /- path: App/ { sub(/.*- path: /, ""); print }
' project.yml)
for path in $APP_PATHS; do
    case "$path" in
        App/*.fit|App/*.icon) ;;
        *)
            echo "architecture: the iPhone app uses $path from App/; only resources are allowed, shared code goes into the package (see docs/ARCHITECTURE.md)" >&2
            exit 1 ;;
    esac
done

echo "architecture: ok"
