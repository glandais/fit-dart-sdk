"""Diffs two message dumps field by field.

Exits non-zero on a real divergence. Two classes are recognised as the Python
decoder describing the same data differently and reported separately — see
tool/README.md:

  - an all-invalid float32 field, which fit-python-sdk surfaces as NaN and this
    SDK drops, as it drops an all-invalid field of any other base type;
  - a developer field whose field_description carries no name, which
    fit-python-sdk keys by index and this SDK names 'unknown'.
"""

import json
import sys

TOL = 2e-6
ABSENT = "<absent>"


def same(a, b):
    """Numeric equality within a rounding-noise tolerance.

    Both dumps round to six decimals, and Python rounds a tie to even where Dart
    rounds it away from zero, so an exact .5 at that digit prints differently
    from an identical underlying value.
    """
    if isinstance(a, dict) and isinstance(b, dict):
        return set(a) == set(b) and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if (
        isinstance(a, (int, float))
        and isinstance(b, (int, float))
        and not isinstance(a, bool)
        and not isinstance(b, bool)
    ):
        return abs(a - b) <= TOL * max(1.0, abs(a), abs(b))
    return a == b


def is_expected(key, va, vb):
    if va == "NaN" and vb == ABSENT:
        return "all-invalid float dropped"
    if key == "developer_fields" and isinstance(va, dict) and isinstance(vb, dict):
        # Same values, one keyed by index where the other names it 'unknown'.
        if sorted(map(repr, va.values())) == sorted(map(repr, vb.values())):
            return "unnamed developer field labelled differently"
    return None


def main(py_path, dart_path, label):
    a = [json.loads(line) for line in open(py_path)]
    b = [json.loads(line) for line in open(dart_path)]

    real = 0
    expected = 0
    values = 0

    if len(a) != len(b):
        print(f"{label}: MESSAGE COUNT py={len(a)} dart={len(b)}")
        real += 1

    for i, (pa, pb) in enumerate(zip(a, b)):
        if pa["n"] != pb["n"]:
            print(f"{label}[{i}]: mesg num py={pa['n']} dart={pb['n']}")
            real += 1
            continue
        for k in sorted(set(pa["f"]) | set(pb["f"])):
            values += 1
            va = pa["f"].get(k, ABSENT)
            vb = pb["f"].get(k, ABSENT)
            if same(va, vb):
                continue
            why = is_expected(k, va, vb)
            if why:
                expected += 1
                continue
            real += 1
            if real <= 25:
                print(f"{label}[{i}] mesg {pa['n']} field {k}: py={va!r} dart={vb!r}")

    print(
        f"{label}: {len(a)} messages, {values} values, "
        f"{real} divergences, {expected} expected differences"
    )
    return 1 if real else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2], sys.argv[3]))
