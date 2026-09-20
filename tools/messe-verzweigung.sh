#!/bin/zsh
# Counts the move space — the number `docs/04-architektur.md` estimates and
# leaves to the walking skeleton to measure. Neither a test nor a check: it
# answers "how big is this", not "is this right".
#
#   tools/messe-verzweigung.sh
#
# The result belongs in `docs/06-durchstich.md` whenever it shifts.
cd "${0:A:h}/.."
exec swift run --package-path HarmonyRules HarmonyMeasure "$@"
