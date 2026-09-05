#!/bin/bash
# Builds Sprint and packages it for download. There's no Xcode project and no
# package dependencies: the compiler produces one binary and this script wraps
# it in a normal application bundle.
set -euo pipefail
cd "$(dirname "$0")"
source ./toolchain.sh

APP="Sprint"
DIST="dist"
# Everything a downloader gets lives in this folder: the app itself, and the
# guide that explains how to use it.
FOLDER="$DIST/$APP"
BUNDLE="$FOLDER/$APP.app"

rm -rf "$FOLDER"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

# Build for both Apple Silicon and Intel and stitch the two together, so the app
# runs on any Mac rather than only the kind it was built on.
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
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "  (unsigned, which is fine for running locally)"

cp "Samples/Start Here.md" "$FOLDER/Start Here.md"

# The zip attached to a GitHub release.
rm -f "$DIST/$APP.zip"
ditto -c -k --sequesterRsrc --keepParent "$FOLDER" "$DIST/$APP.zip"

echo "Built $BUNDLE ($(lipo -archs "$BUNDLE/Contents/MacOS/$APP"))"
echo "Packaged $DIST/$APP.zip"
echo "Open it with:  open \"$PWD/$BUNDLE\""
