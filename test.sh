#!/bin/bash
# Runs the unit tests. They're a plain executable rather than an XCTest bundle
# because the Command Line Tools don't ship XCTest.
set -euo pipefail
cd "$(dirname "$0")"
source ./toolchain.sh

echo "Compiling tests…"
xcrun swiftc "${SWIFTC_COMMON[@]}" "${CC_FLAGS[@]+"${CC_FLAGS[@]}"}" \
    Sources/Core/*.swift Tests/Harness.swift Tests/unit/*.swift Tests/main.swift \
    -o "$BUILD/sprint-tests"

"$BUILD/sprint-tests"
