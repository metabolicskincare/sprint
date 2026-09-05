#!/bin/bash
# Builds Sprint.app. No Xcode project and no package dependencies — the compiler
# produces one binary and this script wraps it in a normal application bundle.
set -euo pipefail
cd "$(dirname "$0")"
source ./toolchain.sh

APP="Sprint"
BUNDLE="dist/$APP.app"

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

# Build for both Apple Silicon and Intel and stitch the two into one universal
# binary, so the app runs on any Mac rather than only the kind it was built on.
for ARCH in arm64 x86_64; do
    echo "Compiling for $ARCH…"
    xcrun swiftc -O -target "$ARCH-apple-macosx14.0" -sdk "$SDK" \
        "${CC_FLAGS[@]+"${CC_FLAGS[@]}"}" \
        Sources/Core/*.swift Sources/App/*.swift \
        -o "$BUILD/$APP-$ARCH"
done

lipo -create -output "$BUNDLE/Contents/MacOS/$APP" "$BUILD/$APP-arm64" "$BUILD/$APP-x86_64"

cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "  (unsigned — fine for running locally)"

echo "Built $BUNDLE ($(lipo -archs "$BUNDLE/Contents/MacOS/$APP"))"
echo "Open it with:  open \"$PWD/$BUNDLE\""
