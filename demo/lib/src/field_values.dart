import 'package:fit_dart_sdk/fit_dart_sdk.dart';

import 'profile_labels.dart';

/// One field of one decoded message, as the table and the JSON export see it.
class FieldValue {
  const FieldValue({
    required this.name,
    required this.units,
    required this.value,
    required this.developer,
  });

  /// Profile name of the field, or of the subfield the message activates —
  /// `event.data` reads as `gear_change_data` on a rear gear change. `fieldN`
  /// for a field the profile does not know.
  final String name;

  final String units;

  /// A single value, or a [List] of them for a repeated field. Names, instants
  /// and booleans in place of the raw numbers wherever the profile says so.
  final Object? value;

  final bool developer;
}

/// Every field of [mesg] that holds a value, in the order the file stored them.
List<FieldValue> fieldValuesOf(Mesg mesg) {
  final values = <FieldValue>[];

  for (final field in mesg.fieldList) {
    if (!field.hasValues) continue;
    // The active subfield decides both the name and the meaning: reading
    // `event.data` as anything but its active subfield gives a number under the
    // wrong interpretation.
    final name = field.fieldName == _unknownName
        ? 'field${field.fieldNum}'
        : field.nameOf(activeSelector, mesg);
    final type = profileTypeOf(mesg.globalMesgNum, name);
    values.add(FieldValue(
      name: name,
      units: field.unitsOf(activeSelector, mesg),
      value: _collect(
        field.numValues,
        (index) => _labelled(mesg.getFieldValue(field.fieldNum, index), type),
      ),
      developer: false,
    ));
  }

  for (final field in mesg.developerFieldList) {
    if (!field.hasValues) continue;
    values.add(FieldValue(
      name: field.fieldName,
      units: field.units,
      // A developer field carries no profile type: its values are numbers and
      // strings, and the field description says what they mean.
      value: _collect(field.numValues, field.getValue),
      developer: true,
    ));
  }

  return values;
}

/// What the profile says a field is measured in, for a chart axis or a column
/// header. Empty when the field has no units, or is not in the profile.
String unitsOfField(int mesgNum, int fieldNum) =>
    Factory.createField(mesgNum, fieldNum)?.units ?? '';

/// A single value on its own, several as a list — the shape of the field.
Object? _collect(int count, Object? Function(int) valueAt) => count == 1
    ? valueAt(0)
    : [for (var index = 0; index < count; index++) valueAt(index)];

/// The raw value under the reading its profile type gives it.
Object? _labelled(Object? value, String? type) {
  if (value == null || type == null || value is! int) return value;
  return switch (type) {
    // A date_time counts seconds, and its named values (`min`) mark a threshold
    // rather than an instant.
    dateTimeType => FitDateTime.toDateTime(value) ?? value,
    boolType => value != 0,
    _ => profileValueName(type, value) ?? value,
  };
}

/// What [Factory] names a message or field the profile does not know.
const String _unknownName = Factory.unknownName;

/// [value] as one line of text.
String formatValue(Object? value) {
  if (value == null) return '';
  if (value is List) return value.map(formatValue).join(', ');
  if (value is DateTime) return formatDateTime(value);
  if (value is double) return formatNumber(value);
  return '$value';
}

/// Trailing zeros dropped: a scaled field divides out to 3.4000000000000004 as
/// often as to 3.4, and neither is worth eleven digits in a table cell.
String formatNumber(double value) {
  if (!value.isFinite) return '$value';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return '${value.toInt()}';
  }
  return value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatDateTime(DateTime value) => value
    .toUtc()
    .toIso8601String()
    .replaceFirst('T', ' ')
    .replaceFirst('.000Z', 'Z');

/// Thousands separated, for the counts the page shows.
String formatCount(int value) {
  final digits = '$value';
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// A value ready for `jsonEncode`: an instant as text, everything else as it is.
Object? jsonValue(Object? value) {
  if (value is DateTime) return formatDateTime(value);
  if (value is List) return value.map(jsonValue).toList();
  return value;
}
