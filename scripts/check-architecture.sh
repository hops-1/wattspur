#!/bin/bash
# Checks the layer rules of docs/ARCHITECTURE.md that the compiler cannot: WattspurCore must not
# import SwiftData, SwiftUI, AppKit or MapKit; WattspurMap only MapKit and Core Graphics, no UI of one platform (the compiler already forbids what the target does not
# depend on, but a new import line in Core would make the target depend on the system framework).
# The iPhone app (iOS/) must not import AppKit and must take nothing from App/ but resources (B-206);
# the widgets must not import SwiftData; the package holds no texts for the user (rule 8); the apps
# write the library only through RideLibrary (rule 4) and the package saves through LibrarySave (rule 10).
set -euo pipefail
cd "$(dirname "$0")/.."

# An import line in any Swift 6 form: attributes (@preconcurrency, @testable), an access level
# (public import), or a single declaration (import struct SwiftUI.Color) (R-05).
import_of() {
    printf '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]+((struct|class|enum|protocol|typealias|func|var|let)[[:space:]]+)?(%s)([[:space:].]|$)' "$1"
}
UI_AND_DATA='SwiftData|SwiftUI|AppKit|UIKit|MapKit|Charts'

# The patterns themselves, so a change to them cannot quietly let lines through.
self_test() {
    local pattern
    pattern=$(import_of "$UI_AND_DATA")
    for line in 'import SwiftData' 'public import SwiftData' '@preconcurrency import SwiftUI' \
                'import struct SwiftUI.Color' '  @testable internal import MapKit'; do
        echo "$line" | grep -qE "$pattern" || { echo "architecture: self-test missed: $line" >&2; exit 1; }
    done
    for line in 'import Foundation' 'import SwiftDataExtras' '// import SwiftUI later' 'let importSwiftUI = 1'; do
        if echo "$line" | grep -qE "$pattern"; then echo "architecture: self-test matched: $line" >&2; exit 1; fi
    done
}
self_test

CORE="Packages/WattspurKit/Sources/WattspurCore"
if grep -rnE "$(import_of "$UI_AND_DATA")" "$CORE"; then
    echo "architecture: WattspurCore must not import UI or persistence frameworks (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
# The maps of both apps (B-186): MapKit and Core Graphics, but nothing of one platform's UI, so the
# iPhone can use them; and no SwiftUI or SwiftData, the apps add the views.
MAP="Packages/WattspurKit/Sources/WattspurMap"
if grep -rnE "$(import_of 'AppKit|UIKit|SwiftUI|SwiftData|Charts')" "$MAP"; then
    echo "architecture: WattspurMap must not import AppKit, UIKit, SwiftUI or SwiftData; the apps add the views (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
if grep -rnE '\b(NS|UI)(Color|Image|Appearance|BezierPath|EdgeInsets|View|Event|GraphicsContext|Font)\b' "$MAP"; then
    echo "architecture: WattspurMap must not use AppKit or UIKit types (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
# Rule 8: no texts for the user in the package; each app words them and keeps the translations (R-48).
if grep -rnE 'String\(localized|LocalizedStringKey|LocalizedStringResource' Packages/WattspurKit/Sources; then
    echo "architecture: the package must not hold texts for the user; word them in the app (see docs/ARCHITECTURE.md, rule 8)" >&2
    exit 1
fi
IOS="iOS iOSShared iOSWidgets"
if grep -rnE "$(import_of AppKit)" $IOS; then
    echo "architecture: the iPhone app must not import AppKit (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
# The widget extension reads the snapshot the app writes, never the library itself (R-06).
if grep -rnE "$(import_of SwiftData)" iOSWidgets iOSShared; then
    echo "architecture: the widgets and the code shared with them must not import SwiftData (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi

# Sources of the targets "Wattspur iOS" and "Wattspur Widgets" in project.yml: from App/ only single
# resource files (sample ride, icon), never Swift files or the whole folder; in both forms,
# "- path: App/..." and the short "- App/..." (R-06). Shared code belongs in the package.
APP_PATHS=$(awk '
    /^  (Wattspur iOS|Wattspur Widgets):/ { inside = 1; next }
    inside && /^  [^ ]/ { inside = 0 }
    inside && /^[^ ]/ { inside = 0 }
    inside && /^[[:space:]]*- (path: )?App(\/|[[:space:]]*$)/ { sub(/^[[:space:]]*- (path: )?/, ""); print }
' project.yml)
for path in $APP_PATHS; do
    case "$path" in
        App/*.fit|App/*.icon) ;;
        *)
            echo "architecture: an iPhone target uses $path from App/; only resources are allowed, shared code goes into the package (see docs/ARCHITECTURE.md)" >&2
            exit 1 ;;
    esac
done

# Rule 4: the apps change the library only through RideLibrary, never through a model context of
# their own. DemoMode.swift fills a separate demo library for screenshots and may (B-259).
if grep -rnE '([Cc]ontext|mainContext)\.(save|insert|delete)\(|modelContext' App iOS iOSShared iOSWidgets \
        | grep -v '^App/DemoMode\.swift:'; then
    echo "architecture: the apps write the library only through RideLibrary (see docs/ARCHITECTURE.md, rule 4)" >&2
    exit 1
fi
# Rule 10: the package saves only through LibrarySave, which reports a failed save (R-31, B-259).
if grep -rnE '[Cc]ontext\.save\(' Packages/WattspurKit/Sources | grep -v '/Store/LibrarySave\.swift:'; then
    echo "architecture: save the library with LibrarySave.save(_:), not context.save() (see docs/ARCHITECTURE.md, rule 10)" >&2
    exit 1
fi

echo "architecture: ok"
