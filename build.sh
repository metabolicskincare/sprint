#!/bin/bash
# Builds Sprint.app. No Xcode project and no package dependencies — the compiler
# produces one binary and this script wraps it in a normal application bundle.
set -euo pipefail
cd "$(dirname "$0")"
source ./toolchain.sh

APP="Sprint"
BUNDLE="dist/$APP.app"

echo "Compiling…"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
xcrun swiftc -O "${SWIFTC_COMMON[@]}" "${CC_FLAGS[@]+"${CC_FLAGS[@]}"}" \
    Sources/Core/*.swift Sources/App/*.swift \
    -o "$BUNDLE/Contents/MacOS/$APP"

cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "  (unsigned — fine for running locally)"

echo "Built $BUNDLE"
echo "Open it with:  open \"$PWD/$BUNDLE\""
