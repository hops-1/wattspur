#!/bin/bash
# Checks the App Store texts in docs/appstore/metadata against Apple's length limits (B-314) and
# against names of other brands in the keywords (guideline 2.3.7). Builds nothing, sends nothing.
#
#   scripts/check-appstore-texts.sh
set -euo pipefail
cd "$(dirname "$0")/../docs/appstore/metadata"
export LC_ALL=en_US.UTF-8

fail=0
# Characters without the final newline.
length() { printf '%s' "$(cat "$1")" | wc -m | tr -d ' '; }

check() {
    local file=$1 limit=$2 n
    [ -f "$file" ] || { echo "missing: $file"; fail=1; return; }
    n=$(length "$file")
    if [ "$n" -gt "$limit" ]; then
        echo "too long: $file ($n of $limit)"; fail=1
    else
        echo "ok: $file ($n of $limit)"
    fi
}

for locale in de-DE en-US; do
    check "$locale/name.txt" 30
    check "$locale/subtitle.txt" 30
    check "$locale/promotional_text.txt" 170
    check "$locale/description.txt" 4000
    check "$locale/keywords.txt" 100
    # Bytes too: umlauts may count twice in App Store Connect.
    bytes=$(printf '%s' "$(cat "$locale/keywords.txt")" | wc -c | tr -d ' ')
    [ "$bytes" -le 100 ] || echo "note: $locale/keywords.txt has $bytes bytes"
    if grep -qE ', | ,' "$locale/keywords.txt"; then
        echo "spaces around commas: $locale/keywords.txt"; fail=1
    fi
    if grep -qiE 'bosch|strava|komoot|garmin|wahoo|flow|apple' "$locale/keywords.txt"; then
        echo "other brand in keywords: $locale/keywords.txt"; fail=1
    fi
    for url in support_url marketing_url privacy_url; do
        grep -qE '^https://' "$locale/$url.txt" || { echo "not https: $locale/$url.txt"; fail=1; }
    done
done
check review_information/notes.txt 4000

[ "$fail" -eq 0 ] && echo "App Store texts: ok" || { echo "App Store texts: failed"; exit 1; }
