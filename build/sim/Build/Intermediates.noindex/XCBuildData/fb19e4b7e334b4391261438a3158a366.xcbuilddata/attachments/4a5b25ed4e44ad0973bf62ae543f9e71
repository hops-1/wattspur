#!/bin/sh
COMMIT=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ -n "$(git -C "$SRCROOT" status --porcelain 2>/dev/null)" ]; then COMMIT="${COMMIT}-dirty"; fi
mkdir -p "$DERIVED_FILE_DIR"
echo "#define WATTSPUR_GIT_COMMIT $COMMIT" > "$DERIVED_FILE_DIR/WattspurGitInfo.h"

