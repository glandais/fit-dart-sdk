// Dumps a FIT file as JSONL, one line per message in file order, in the same
// shape tools/dump_py.py produces from fit-python-sdk. Cross-check only.
import 'dart:convert';
import 'dart:io';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';

Object? norm(Object? v) {
  if (v is double) {
    if (v.isNaN) return 'NaN';
    return (v * 1000000).round() / 1000000;
  }
  return v;
}

void main(List<String> args) {
  final bytes = File(args[0]).readAsBytesSync();
  final result = FitDecoder(bytes).decode(const DecodeOptions(
    includeUnknownData: true,
    mergeHeartRates: false,
  ));
  if (result.errors.isNotEmpty) {
    stderr.writeln('DART ERRORS: ${result.errors}');
  }
  final sink = File(args[1]).openWrite();
  for (final mesg in result.mesgs) {
    final fields = <String, Object?>{};
    void put(FieldBase field) {
      final key =
          field.fieldName == 'unknown' ? '${field.fieldNum}' : field.fieldName;
      if (field.numValues == 1) {
        fields[key] = norm(field.getValue());
      } else {
        fields[key] = [
          for (var i = 0; i < field.numValues; i++) norm(field.getValue(i)),
        ];
      }
    }

    mesg.fieldList.forEach(put);
    // fit-python-sdk, with expand_sub_fields on, adds the active subfield's own
    // name alongside the field's. Mirror that so the two dumps line up; the SDK
    // itself exposes subfields through the generated accessors instead.
    for (final field in mesg.fieldList) {
      final index = mesg.getActiveSubFieldIndex(field.fieldNum);
      if (index == Mesg.mainField) continue;
      final subField = field.subFields[index];
      if (field.numValues == 1) {
        fields[subField.name] = norm(field.getValueWith(0, subField));
      } else {
        fields[subField.name] = [
          for (var i = 0; i < field.numValues; i++)
            norm(field.getValueWith(i, subField)),
        ];
      }
    }
    if (mesg.developerFieldList.isNotEmpty) {
      final dev = <String, Object?>{};
      for (final field in mesg.developerFieldList) {
        dev[field.fieldName] = field.numValues == 1
            ? norm(field.getValue())
            : [
                for (var i = 0; i < field.numValues; i++)
                  norm(field.getValue(i))
              ];
      }
      fields['developer_fields'] = dev;
    }
    sink.write('${jsonEncode({
          'f': Map.fromEntries(
              fields.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
          'n': mesg.globalMesgNum,
        })}\n');
  }
  sink.close();
  stderr.writeln('${result.mesgs.length} messages');
}
