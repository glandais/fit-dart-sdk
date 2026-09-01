#!/bin/sh
# Decodes every fixture with this SDK and with garmin/fit-python-sdk, then diffs
# the two field by field. The strongest correctness evidence this package has:
# nothing here is a baseline it recorded of itself.
#
#   FIT_PYTHON_SDK=../fit-python-sdk tool/cross_check.sh
#
# Point FIT_PYTHON_SDK at a checkout of garmin/fit-python-sdk (default
# ../fit-python-sdk). Needs python3 and the Dart SDK; nothing has to be
# installed.
set -eu

FIT_PYTHON_SDK="${FIT_PYTHON_SDK:-../fit-python-sdk}"
export FIT_PYTHON_SDK
OUT="${TMPDIR:-/tmp}/fit-cross-check"
mkdir -p "$OUT"

status=0
for name in Activity ActivityDevFields WithGearChangeData HrmPluginTestActivity HrMesgTestActivity; do
  python3 tool/dump_fit.py "test/data/$name.fit" "$OUT/py_$name.jsonl" 2>/dev/null
  dart run tool/dump_fit.dart "test/data/$name.fit" "$OUT/dart_$name.jsonl" 2>/dev/null
  python3 tool/compare_dumps.py "$OUT/py_$name.jsonl" "$OUT/dart_$name.jsonl" "$name" || status=1
done
exit $status
