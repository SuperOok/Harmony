#!/bin/zsh
# Overnight series of 2026-10-05: what the animal cards give and which
# settings help with them. Humans at the table beat Harmony mostly in the
# animal cards (docs/ideen-vorgemerkt.md, "Echte Partien"); this tests the
# levers that touch the cards and records, per card, how often it was open,
# taken, finished and what it paid (block "Karten" of HarmonyMatch).
#
#   tools/nachtlauf-karten.sh [Ausgabeordner]
#
# One run after the other, each on all cores; ordered by what is worth most,
# so a night cut short still leaves the first blocks. About 13 hours in all.
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

# 1. The weight of the animal cards' prospects: more of it, paired, per side.
run 1-tierkarten15-A --plaetze standard,standard+tierkarten=1.5 --partien 24 --seite a
run 1-tierkarten15-B --plaetze standard,standard+tierkarten=1.5 --partien 24 --seite b

# 2. Per-card statistics of the standard, with the corrected Eisfuchs. New
#    deals (start value 2), many of them: 32 cards need many hands.
run 2-karten-A --plaetze standard,standard --partien 40 --seite a --startwert 2
run 2-karten-B --plaetze standard,standard --partien 40 --seite b --startwert 2

# 3. Still more weight on the cards.
run 3-tierkarten20-A --plaetze standard,standard+tierkarten=2.0 --partien 24 --seite a
run 3-tierkarten20-B --plaetze standard,standard+tierkarten=2.0 --partien 24 --seite b

# 4. The landscape outlook below 1.0 (1.5 hurt on both sides).
run 4-landschaften07-A --plaetze standard,standard+landschaften=0.7 --partien 24 --seite a
run 4-landschaften07-B --plaetze standard,standard+landschaften=0.7 --partien 24 --seite b

# 5. A higher price for a free card space: fewer, better cards?
run 5-preis15-A --plaetze standard,standard+preis=15 --partien 20 --seite a
run 5-preis15-B --plaetze standard,standard+preis=15 --partien 20 --seite b

# 6. The cube after the next one, two steps deep (depth 2 was never measured).
run 6-folgetiefe2-A --plaetze standard,standard+folgetiefe=2 --partien 20 --seite a
run 6-folgetiefe2-B --plaetze standard,standard+folgetiefe=2 --partien 20 --seite b

print "$(date '+%F %T')  ALLES FERTIG" >> "$PROGRESS"
