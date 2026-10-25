#!/bin/bash
# Checks the layer rules of docs/ARCHITECTURE.md that the compiler cannot: WattspurCore must not
# import SwiftData, SwiftUI, AppKit or MapKit (the compiler already forbids what the target does not
# depend on, but a new import line in Core would make the target depend on the system framework).
set -euo pipefail
cd "$(dirname "$0")/.."

CORE="Packages/WattspurKit/Sources/WattspurCore"
if grep -rnE '^import (SwiftData|SwiftUI|AppKit|UIKit|MapKit|Charts)' "$CORE"; then
    echo "architecture: WattspurCore must not import UI or persistence frameworks (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
echo "architecture: ok"
