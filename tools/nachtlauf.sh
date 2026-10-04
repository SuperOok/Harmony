#!/bin/zsh
# Overnight series of HarmonyMatch runs on the question why side B scores
# so much more than side A (docs/stand.md, 2026-10-03). One run after the
# other, each on all cores; every run writes its own log and protocol into
# the output folder. Ordered by what is worth most, so a night cut short
# still leaves the first blocks.
#
#   tools/nachtlauf.sh [Ausgabeordner]
#
# Runs a copy of the built binary, so rebuilding while it runs is harmless.
# Build first: swift build -c release --product HarmonyMatch --package-path HarmonyRules
cd "${0:A:h}/.."

OUT=${1:-messungen/nacht-$(date +%Y-%m-%d)}
mkdir -p "$OUT/bin"
cp HarmonyRules/.build/release/HarmonyMatch "$OUT/bin/"
cp -R HarmonyRules/.build/release/HarmonyRules_HarmonyRules.bundle "$OUT/bin/"
BIN="$OUT/bin/HarmonyMatch"
PROGRESS="$OUT/fortschritt.txt"

run() {
  local name=$1; shift
  print "$(date '+%F %T')  start  $name  ($*)" >> "$PROGRESS"
  "$BIN" "$@" --protokoll "$OUT/$name.jsonl" -v > "$OUT/$name.log" 2>&1
  print "$(date '+%F %T')  fertig $name  (Rückgabe $?)" >> "$PROGRESS"
}

# 1. Baseline without any search weights: what the board gives by itself.
run 1-gierig-2-A   --plaetze gierig,gierig --partien 8  --seite a
run 1-gierig-2-B   --plaetze gierig,gierig --partien 8  --seite b

# 2. The same engine on all seats, per side and player count: where the
#    gap between the sides sits (landscapes, game length, water).
run 2-standard-2-A --plaetze standard,standard --partien 16 --seite a
run 2-standard-2-B --plaetze standard,standard --partien 16 --seite b
run 3-standard-3-A --plaetze standard,standard,standard --partien 8 --seite a
run 3-standard-3-B --plaetze standard,standard,standard --partien 8 --seite b

# 3. Is the landscape outlook (river, islands) too weak? Paired, per side.
run 4-landschaften-A --plaetze standard,standard+landschaften=1.5 --partien 16 --seite a
run 4-landschaften-B --plaetze standard,standard+landschaften=1.5 --partien 16 --seite b

# 4. Does the end forecast end the game too early? Paired, per side.
run 5-vorhersage-A --plaetze standard,ohne-vorhersage --partien 16 --seite a
run 5-vorhersage-B --plaetze standard,ohne-vorhersage --partien 16 --seite b

# 5. Four players, where the bag may end the game before the board does.
run 6-standard-4-A --plaetze standard,standard,standard,standard --partien 4 --seite a
run 6-standard-4-B --plaetze standard,standard,standard,standard --partien 4 --seite b

print "$(date '+%F %T')  ALLES FERTIG" >> "$PROGRESS"
