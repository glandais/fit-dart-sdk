"""Dumps a FIT file as JSONL, one line per message in file order.

The reference side of the cross-check: the same shape tool/dump_fit.dart
produces, so tool/compare_dumps.py can diff the two field by field. Point
FIT_PYTHON_SDK at a checkout of garmin/fit-python-sdk, or run from one.

    FIT_PYTHON_SDK=../fit-python-sdk python3 tool/dump_fit.py in.fit out.jsonl
"""

import json, math, os, sys

sys.path.insert(0, os.environ.get("FIT_PYTHON_SDK", "../fit-python-sdk"))

from garmin_fit_sdk import Decoder, Stream

def norm(v):
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, float):
        if math.isnan(v):
            return "NaN"
        return round(v, 6)
    if isinstance(v, (bytes, bytearray)):
        return list(v)
    if isinstance(v, tuple):
        v = list(v)
    if isinstance(v, list):
        return [norm(x) for x in v]
    return v

out = []
# fit-python-sdk stamps its own bookkeeping onto decoded messages: a 'key' on
# every field_description (its index in that list) and a 'developer_fields'
# sub-dict keyed by the same number. Neither is a FIT field. Rewrite the
# sub-dict to be keyed by the declared field name, which is what the Dart dump
# emits, and drop 'key'.
desc_name_by_key = {}

def listener(mesg_num, mesg):
    fields = {}
    for k, v in mesg.items():
        if k == "key":
            continue
        if k == "developer_fields":
            fields["developer_fields"] = {
                str(desc_name_by_key.get(dk) or dk): norm(dv) for dk, dv in v.items()
            }
            continue
        fields[str(k)] = norm(v)
    if mesg_num == 206 and "key" in mesg:
        desc_name_by_key[mesg["key"]] = mesg.get("field_name")
    out.append({"n": mesg_num, "f": fields})

stream = Stream.from_file(sys.argv[1])
decoder = Decoder(stream)
messages, errors = decoder.read(
    apply_scale_and_offset=True,
    convert_datetimes_to_dates=False,
    convert_types_to_strings=False,
    enable_crc_check=True,
    expand_sub_fields=True,
    expand_components=True,
    merge_heart_rates=False,
    mesg_listener=listener,
)
if errors:
    print("PY ERRORS:", errors, file=sys.stderr)
with open(sys.argv[2], "w") as f:
    for m in out:
        f.write(json.dumps(m, sort_keys=True) + "\n")
print(f"{len(out)} messages", file=sys.stderr)
