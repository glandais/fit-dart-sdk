# tool — the cross-check against fit-python-sdk

Hand-written, and the only directory under this package that regeneration does
not own. Nothing here ships in the published package.

`cross_check.sh` decodes all five fixtures twice — once with this SDK, once with
[`garmin/fit-python-sdk`](https://github.com/garmin/fit-python-sdk) — and diffs
every field of every message. It is what backs the correctness claim in the
README: the expected values come from Garmin's own decoder, not from a baseline
this package recorded of itself.

```sh
FIT_PYTHON_SDK=../fit-python-sdk tool/cross_check.sh
```

| | |
|---|---|
| `dump_fit.dart` | Decodes a `.fit` file with this SDK into JSONL, one line per message in file order. |
| `dump_fit.py` | The same, with `fit-python-sdk`. Strips that decoder's own bookkeeping (the `key` it stamps on every `field_description`, and the `developer_fields` sub-dict keyed by it) so the two dumps are comparable. |
| `compare_dumps.py` | Diffs two dumps field by field, with a rounding tolerance — both sides round to six decimals and disagree on how to break a tie at that digit. |

Both dumps decode with component expansion and subfield expansion on, unknown
data kept, and heart-rate merging off, which is the widest surface the two
decoders share.

## The differences that remain, and why

Five, over 140,257 values. All are the Python decoder describing the same data
differently, not a decoding disagreement:

- **4 ×** a `float32` field whose every value is the invalid sentinel.
  `fit-python-sdk` surfaces it as `NaN`; this SDK drops the field, which is what
  it does for an all-invalid field of every other base type. "Absent" and
  "invalid" are the same thing through this API by design.
- **1 ×** a developer field whose `field_description` carries no name.
  `fit-python-sdk` keys it by its index; this SDK names it `unknown`.
