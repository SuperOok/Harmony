#!/bin/zsh
# Runs the rule tests and prints a report. No Xcode project, no simulator —
# storey one from `docs/pruefverfahren.md` needs neither.
#
#   tools/tests.sh            summary, plus any failure
#   tools/tests.sh -v         every test case by name
cd "${0:A:h}/.."

OUT=$(cd HarmonyRules && swift test 2>&1)
STATUS=$?

# Multibyte characters do not work in a bracket expression here, so the
# marks are matched by alternation.
if [[ "$1" == "-v" ]]; then
  print -r -- "$OUT" | grep -E '^(✔|✘) Test "' | sort
else
  # The run's own summary comes further down; without this it
  # would appear twice on a failure.
  print -r -- "$OUT" | grep -E '^✘' | grep -v 'Test run with' || true
fi

if ! print -r -- "$OUT" | grep -E 'Test run with'; then
  print -r -- "$OUT" | tail -25
fi
exit $STATUS
