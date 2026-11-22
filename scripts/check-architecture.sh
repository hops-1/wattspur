#!/bin/bash
# Checks the rules of docs/ARCHITECTURE.md that the compiler cannot:
# - WattspurCore imports none of SwiftData, SwiftUI, AppKit, UIKit, MapKit, Charts (the compiler only
#   forbids what the target does not depend on; a new import line would add the dependency).
# - WattspurMap: MapKit and Core Graphics only, no AppKit/UIKit/SwiftUI/SwiftData/Charts and no
#   NS…/UI… types of one platform's UI (rule 12).
# - WattspurSymbols: SwiftUI shapes only, no other UI or data framework and no texts (rule 13).
# - The package holds no texts for the user (rule 8).
# - The iPhone app, its widgets and its share extension (iOS*/): no AppKit, nothing from App/ but
#   resources (B-206); the extensions import no SwiftData (R-06).
# - Shared/ (texts and formats of both apps, B-355): SwiftUI, Charts, Foundation and the Kit only,
#   never AppKit or UIKit, and not the RideFormat of one app (rule 6).
# - No file name stands in both App/ and iOS/, except a short list with reasons (rule 15).
# - The apps write the library only through RideLibrary, no model context of their own (rule 4);
#   the package saves only through LibrarySave (rule 10).
# - The three iPhone targets take their settings from Config/iOS.xcconfig, and the versions stand
#   only in the two xcconfig files (rule 11).
# - No build products, no Config/Local.xcconfig and no team ID in the repository (S-49, S-50).
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
# Every NS…/UI… type except the few of Foundation and Core Data the overlays need (S-12); a new
# Foundation type goes into this list, a type of AppKit or UIKit belongs in the apps.
MAP_ALLOWED='NSObject|NSObjectProtocol|NSManagedObject[A-Za-z]*|NSMutableData|NSError|NSString|UIKit'
if grep -rnoE '\b(NS|UI)[A-Z][A-Za-z0-9]*' "$MAP" | grep -vE ":($MAP_ALLOWED)\$"; then
    echo "architecture: WattspurMap must not use AppKit or UIKit types (see docs/ARCHITECTURE.md, rule 12)" >&2
    exit 1
fi
# The drawn symbols (B-342): SwiftUI shapes only, so the iPhone, the Mac and the widgets all use them.
SYMBOLS="Packages/WattspurKit/Sources/WattspurSymbols"
if grep -rnE "$(import_of 'AppKit|UIKit|SwiftData|MapKit|Charts')" "$SYMBOLS"; then
    echo "architecture: WattspurSymbols must hold SwiftUI shapes only, no AppKit, UIKit, SwiftData or MapKit (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
# No texts either (rule 13): Text("…") and Label("…") turn a literal into a LocalizedStringKey
# silently, so the check for rule 8 below would not see it (S-13).
if grep -rnE '\b(Text|Label)\(' "$SYMBOLS"; then
    echo "architecture: WattspurSymbols must not hold texts, no Text( or Label( (see docs/ARCHITECTURE.md, rule 13)" >&2
    exit 1
fi
# Rule 8: no texts for the user in the package; each app words them and keeps the translations (R-48).
if grep -rnE 'String\(localized|LocalizedStringKey|LocalizedStringResource' Packages/WattspurKit/Sources; then
    echo "architecture: the package must not hold texts for the user; word them in the app (see docs/ARCHITECTURE.md, rule 8)" >&2
    exit 1
fi
IOS="iOS iOSShared iOSWidgets iOSShare"
if grep -rnE "$(import_of AppKit)" $IOS; then
    echo "architecture: the iPhone app must not import AppKit (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi
# The extensions read what the app writes, never the library itself (R-06): the widgets the
# snapshot, the share extension nothing; it only hands files to the app (B-301).
if grep -rnE "$(import_of SwiftData)" iOSWidgets iOSShared iOSShare; then
    echo "architecture: the extensions and the code shared with them must not import SwiftData (see docs/ARCHITECTURE.md)" >&2
    exit 1
fi

# Shared/ is compiled into the Mac and the iPhone app (B-355): only frameworks of both platforms and
# the Kit, and none of the formats of one app (the Mac's duration has seconds, the iPhone's not).
SHARED_ALLOWED=$(import_of 'SwiftUI|Charts|Foundation|WattspurKit|WattspurCore')
if grep -rnE "$(import_of '[A-Za-z_][A-Za-z0-9_]*')" Shared | grep -vE "^[^:]+:[0-9]+:${SHARED_ALLOWED#^}"; then
    echo "architecture: Shared/ imports only SwiftUI, Charts, Foundation and the Kit, no AppKit or UIKit (see docs/ARCHITECTURE.md, rule 6)" >&2
    exit 1
fi
if grep -rnwE 'RideFormat|NS[A-Z][A-Za-z]*|UI[A-Z][A-Za-z]*' Shared | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'; then
    echo "architecture: Shared/ must not use an app's RideFormat or AppKit/UIKit types; use ValueFormat (see docs/ARCHITECTURE.md, rule 6)" >&2
    exit 1
fi

# Rule 15: a file name in both App/ and iOS/ is usually a copy that drifts apart (S-18). Shared code
# goes into Shared/ or the package. Allowed, because each platform needs its own, different file:
# - WattspurApp.swift: the entry point of each app;
# - Localizable.xcstrings: one string catalog per app;
# - RideFormat.swift: the formats of lists and recording (the iPhone's duration without seconds);
# - RidePDF.swift: drawn with AppKit on the Mac, UIKit on the iPhone;
# - HighlightsView.swift, LibraryErrorView.swift, TrashView.swift: different views per platform;
# - SampleRide.swift: loaded into SwiftData on the Mac, into the exchange format on the iPhone.
SAME_NAME_ALLOWED='WattspurApp.swift|Localizable.xcstrings|RideFormat.swift|RidePDF.swift|HighlightsView.swift|LibraryErrorView.swift|TrashView.swift|SampleRide.swift'
SAME_NAMES=$(comm -12 <(find App -type f | sed 's#.*/##' | sort -u) <(find iOS -type f | sed 's#.*/##' | sort -u) \
    | grep -vxE "$SAME_NAME_ALLOWED" || true)
if [ -n "$SAME_NAMES" ]; then
    echo "$SAME_NAMES"
    echo "architecture: these file names stand in both App/ and iOS/; move the shared part to Shared/ or rename (see docs/ARCHITECTURE.md, rule 15)" >&2
    exit 1
fi

# Sources of the targets "Wattspur iOS", "Wattspur Widgets" and "Wattspur Share" in project.yml: from App/ only single
# resource files (sample ride, icon), never Swift files or the whole folder; in both forms,
# "- path: App/..." and the short "- App/..." (R-06). Shared code belongs in the package.
APP_PATHS=$(awk '
    /^  (Wattspur iOS|Wattspur Widgets|Wattspur Share):/ { inside = 1; next }
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
if grep -rnE '([Cc]ontext|mainContext)\.(save|insert|delete)\(|modelContext' App iOS iOSShared iOSWidgets iOSShare \
        | grep -v '^App/DemoMode\.swift:'; then
    echo "architecture: the apps write the library only through RideLibrary (see docs/ARCHITECTURE.md, rule 4)" >&2
    exit 1
fi
# ... whatever the context is called: no new ModelContext( in the apps either (S-11).
if grep -rnE '\bModelContext\(' App iOS iOSShared iOSWidgets iOSShare | grep -v '^App/DemoMode\.swift:'; then
    echo "architecture: the apps must not make a ModelContext of their own; they write through RideLibrary (see docs/ARCHITECTURE.md, rule 4)" >&2
    exit 1
fi
# Rule 10: the package saves only through LibrarySave, which reports a failed save (R-31, B-259).
# Any .save() without arguments, whatever the context is called (S-02). Exceptions:
# - LibrarySave.swift itself;
# - LibraryBackup+Rewrite.swift: writes the copy of the library through Core Data in batches and
#   throws on a failed save (`try target.save()`), so nothing is lost silently;
# - RideLibrary's `goals.save()`: GoalService.save() saves through LibrarySave.
if grep -rnE '\.save\(\)' Packages/WattspurKit/Sources \
        | grep -vE '/Store/(LibrarySave|LibraryBackup\+Rewrite)\.swift:' \
        | grep -vE '/Store/RideLibrary\.swift:[0-9]+:.*\{ goals\.save\(\) \}' \
        | grep -vE ':[0-9]+:[[:space:]]*((public|internal|private|fileprivate|package)[[:space:]]+)?func save\(\)'; then
    echo "architecture: save the library with LibrarySave.save(_:), not context.save() (see docs/ARCHITECTURE.md, rule 10)" >&2
    exit 1
fi

# Rule 11: the three iPhone targets take version and signing from Config/iOS.xcconfig, so app and
# extensions keep one version (R-04, S-09). awk prints the target names whose configFiles differ.
WRONG_CONFIG=$(awk '
    /^targets:/ { targets = 1; next }
    /^[^ #]/ { targets = 0 }
    targets && /^  [^ #]/ {
        if (name != "" && ok < 2) print name
        name = ""; ok = 0
        if ($0 ~ /^  (Wattspur iOS|Wattspur Widgets|Wattspur Share):/) { name = $0; sub(/^  /, "", name); sub(/:.*/, "", name) }
        next
    }
    targets && name != "" && /^      (Debug|Release): Config\/iOS\.xcconfig[[:space:]]*$/ { ok++ }
    END { if (name != "" && ok < 2) print name }
' project.yml)
FOUND_TARGETS=$(awk '/^targets:/ { t = 1; next } /^[^ #]/ { t = 0 } t && /^  (Wattspur iOS|Wattspur Widgets|Wattspur Share):/' project.yml | wc -l | tr -d ' ')
if [ -n "$WRONG_CONFIG" ] || [ "$FOUND_TARGETS" != 3 ]; then
    echo "architecture: the iPhone targets must use Config/iOS.xcconfig for Debug and Release${WRONG_CONFIG:+: $(echo $WRONG_CONFIG)} (see docs/ARCHITECTURE.md, rule 11)" >&2
    exit 1
fi
if git grep -nE 'MARKETING_VERSION[[:space:]]*[:=]' -- project.yml '*.xcconfig' '*.pbxproj' '*.plist' \
        | grep -vE '^Config/(Mac|iOS)\.xcconfig:'; then
    echo "architecture: MARKETING_VERSION stands only in Config/Mac.xcconfig and Config/iOS.xcconfig (see docs/ARCHITECTURE.md, rule 11)" >&2
    exit 1
fi

# No build products and nothing personal in the repository (S-49, S-50). Only file names are
# printed, never the content, so a team ID found does not end up in the CI log.
TRACKED_BUILD=$(git ls-files | grep -E '(^|/)(build|\.build|DerivedData)/|\.xcent$|^Config/Local\.xcconfig$' || true)
if [ -n "$TRACKED_BUILD" ]; then
    echo "$TRACKED_BUILD" | head -20
    echo "architecture: build products, *.xcent or Config/Local.xcconfig are in git; remove them with git rm --cached (see .gitignore)" >&2
    exit 1
fi
# A team ID is ten letters or digits after DEVELOPMENT_TEAM (xcconfig "=", project.yml ":"). Only the
# placeholder ABCDE12345 in Config/Local.xcconfig.example is allowed.
TEAM_SET='DEVELOPMENT_TEAM["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Z0-9]{10}([^A-Za-z0-9]|$)'
TEAM_FILES=$( { git grep -lE "$TEAM_SET" -- ':!Config/Local.xcconfig.example' || true
                git grep -hE "$TEAM_SET" -- Config/Local.xcconfig.example | grep -qvE '=[[:space:]]*ABCDE12345\b' \
                    && echo Config/Local.xcconfig.example || true; } )
# The real team, if this Mac has one, must not stand anywhere in the tracked files either.
if [ -f Config/Local.xcconfig ]; then
    REAL_TEAM=$(sed -nE 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*([A-Z0-9]{10}).*/\1/p' Config/Local.xcconfig | tail -1)
    if [ -n "$REAL_TEAM" ] && [ "$REAL_TEAM" != ABCDE12345 ]; then
        TEAM_FILES="$TEAM_FILES
$(git grep -lF "$REAL_TEAM" || true)"
    fi
fi
TEAM_FILES=$(echo "$TEAM_FILES" | sed '/^$/d' | sort -u)
if [ -n "$TEAM_FILES" ]; then
    echo "$TEAM_FILES"
    echo "architecture: these files hold a team ID; it belongs only in the ignored Config/Local.xcconfig" >&2
    exit 1
fi

echo "architecture: ok"
