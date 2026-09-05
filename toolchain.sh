# Shared compiler setup for build.sh and test.sh.
#
# This machine has the Command Line Tools rather than full Xcode, and its
# install has a stale file in it: an old
#   /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
# still declares `module SwiftBridging`, which the current bridging.modulemap in
# the same folder also declares. clang refuses to build any Objective-C module
# while both are present, which breaks every import of Foundation or SwiftUI.
#
# That file is owned by root, so instead of deleting it we hide it behind an
# empty file using a clang virtual filesystem overlay. Reinstalling the Command
# Line Tools (or installing Xcode) removes the need for this, and the check
# below turns itself off automatically once that happens.

SDK="$(xcrun --show-sdk-path)"
TARGET="$(uname -m)-apple-macosx14.0"
BUILD=".build"
mkdir -p "$BUILD"

CC_FLAGS=()
STALE="/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap"
if [ -f "$STALE" ] && [ -f "$(dirname "$STALE")/bridging.modulemap" ] \
   && grep -q "module SwiftBridging" "$STALE"; then
    : > "$BUILD/empty.modulemap"
    cat > "$BUILD/overlay.yaml" <<EOF
{
  "version": 0,
  "case-sensitive": false,
  "use-external-names": false,
  "roots": [
    { "name": "$STALE", "type": "file",
      "external-contents": "$PWD/$BUILD/empty.modulemap" }
  ]
}
EOF
    CC_FLAGS=(-Xcc -ivfsoverlay -Xcc "$PWD/$BUILD/overlay.yaml")
fi

SWIFTC_COMMON=(-target "$TARGET" -sdk "$SDK")
