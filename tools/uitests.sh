#!/bin/zsh
# Runs the interface tests — storey three from `docs/pruefverfahren.md`.
# Unlike the rule tests these need a simulator and take about a minute.
#
#   tools/uitests.sh              the reference device, an iPhone 15 Pro Max
#   tools/uitests.sh <UDID>       some other simulator
#
# `xcrun simctl list devices available` shows the UDIDs. Device names are
# not unique — there are two iPhone 15 Pro Max, and the iOS 17 one cannot
# load the app at all, so the destination is given by id and never by name.
cd "${0:A:h}/.."

# The reference device of `docs/05-ui.md`: 430 × 932 points, iOS 27.
DEVICE="${1:-B8A0EE28-2A5D-4C5D-8094-9C4463BD17A1}"

# xcode-select points at the Command Line Tools on this machine, where
# xcodebuild refuses to run. Overriding it per call keeps that a local
# matter rather than a system-wide change needing a password.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT=$(xcodebuild test \
        -project Harmony.xcodeproj \
        -scheme Harmony \
        -destination "platform=iOS Simulator,id=$DEVICE" 2>&1)
STATUS=$?

print -r -- "$OUT" | grep -E "^Test Case .* (passed|failed)" | sort
print -r -- "$OUT" | grep -E "^.*: error:" || true

if (( STATUS != 0 )); then
  print -r -- "$OUT" | tail -25
fi
exit $STATUS
