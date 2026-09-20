#!/bin/zsh
# Counts the move space — the number `docs/04-architektur.md` estimates and
# leaves to the walking skeleton to measure. Neither a test nor a check: it
# answers "how big is this", not "is this right".
#
#   tools/messe-verzweigung.sh
#
# The result belongs in `docs/06-durchstich.md` whenever it shifts.
#
# **Release, not debug.** Unoptimised Swift runs six to eight times slower
# here, and this script's numbers went into the document as if they were the
# engine's. See `docs/06-durchstich.md`, *Die Hälfte lag am Bau*.
cd "${0:A:h}/.."
exec swift run -c release --package-path HarmonyRules HarmonyMeasure "$@"
