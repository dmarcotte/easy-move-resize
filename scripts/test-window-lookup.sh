#!/bin/sh
# Simulated window lookup checks; needs macOS Command Line Tools. Nothing real is moved.
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/emr-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$test_dir/modules" \
    -include Cocoa/Cocoa.h -include QuartzCore/QuartzCore.h \
    -framework Cocoa -framework ApplicationServices -framework QuartzCore \
    easy-move-resizeTests/EMRWindowLookupRegression.m \
    easy-move-resize/EMRPreferences.m easy-move-resize/EMRMoveResize.m \
    -o "$test_dir/window-lookup-tests"
"$test_dir/window-lookup-tests"
