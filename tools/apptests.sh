#!/bin/zsh
# Runs the app-layer tests — the target `HarmonyTests`: the bridge to the
# engine, the event log, the saved game, the session, the reasoning. They run
# in the simulator with the app as host, but need no interface and take
# seconds once built.
#
#   tools/apptests.sh              the reference device, an iPhone 15 Pro Max
#   tools/apptests.sh <UDID>       some other simulator
#
# See `tools/uitests.sh` for why the device is given by id.
cd "${0:A:h}/.."

DEVICE="${1:-B8A0EE28-2A5D-4C5D-8094-9C4463BD17A1}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT=$(xcodebuild test \
        -project Harmony.xcodeproj \
        -scheme Harmony \
        -destination "platform=iOS Simulator,id=$DEVICE" \
        -only-testing:HarmonyTests 2>&1)
STATUS=$?

print -r -- "$OUT" | grep -E '^✘' | grep -v 'Test run with' || true
print -r -- "$OUT" | grep -E 'Test run with'
print -r -- "$OUT" | grep -E "^.*: error:" || true

if (( STATUS != 0 )); then
  print -r -- "$OUT" | tail -25
fi
exit $STATUS
