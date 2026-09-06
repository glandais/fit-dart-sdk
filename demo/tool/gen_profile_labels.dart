// Regenerates demo/lib/src/profile_labels.dart from the SDK sources next door.
//
//     dart run tool/gen_profile_labels.dart      (from the demo directory)
//
// The typed accessors the SDK generates already carry the mapping this demo
// needs — `Sport? get sport` says field 5 of `session` is a `sport`, and
// `Sport` says 2 is `cycling`. The Kotlin SDK ships the same mapping as data
// (its JS surface has no typed accessors to read it off), the Dart one has no
// reason to: only a demo that renders *every* message generically wants it, and
// that is this program's output rather than part of the package.
//
// So the source of truth stays the generated SDK, and a profile bump means
// running this again — check.yml does it and fails on a diff.

import 'dart:io';

void main(List<String> args) {
  final packageRoot = Directory.current.path.endsWith('demo')
      ? Directory.current.parent
      : Directory.current;
  final sdk = Directory('${packageRoot.path}/lib/src');
  if (!sdk.existsSync()) {
    stderr.writeln('run this from the demo directory of fit-dart-sdk');
    exitCode = 1;
    return;
  }

  final mesgNums = _readMesgNums(File('${sdk.path}/profile.dart'));
  final fieldTypes = <int, Map<String, String>>{};
  final usedTypes = <String>{};

  final messageFiles = Directory('${sdk.path}/messages')
      .listSync()
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in messageFiles) {
    final entry = _readMessage(file, mesgNums);
    if (entry == null) continue;
    fieldTypes[entry.mesgNum] = entry.types;
    usedTypes.addAll(entry.types.values);
  }

  final typeValues = <String, Map<int, String>>{};
  for (final type in usedTypes) {
    if (type == _dateTimeType || type == _boolType) continue;
    final values = _readEnum(sdk, type);
    if (values != null) typeValues[type] = values;
  }

  final out = File('lib/src/profile_labels.dart');
  out.writeAsStringSync(_render(fieldTypes, typeValues,
      _profileVersion(File('${sdk.path}/profile.dart'))));
  stdout.writeln('${out.path}: ${fieldTypes.length} messages, '
      '${fieldTypes.values.fold<int>(0, (sum, m) => sum + m.length)} named fields, '
      '${typeValues.length} types, '
      '${typeValues.values.fold<int>(0, (sum, m) => sum + m.length)} values');
}

/// Marker types: not profile enums, but the two conversions the demo applies on
/// top of them.
const String _dateTimeType = 'DateTime';
const String _boolType = 'bool';

/// Return types that carry no naming of their own.
const Set<String> _plainTypes = {'int', 'double', 'String', 'num', 'Object'};

class _Message {
  _Message(this.mesgNum, this.types);
  final int mesgNum;
  final Map<String, String> types;
}

/// `static const int record = 20;` from profile.dart's `MesgNum`.
Map<String, int> _readMesgNums(File profile) {
  final source = profile.readAsStringSync();
  final start = source.indexOf('abstract final class MesgNum {');
  final end = source.indexOf('\n}', start);
  final result = <String, int>{};
  for (final match in RegExp(r'static const int (\w+) =\s*(\d+);')
      .allMatches(source.substring(start, end))) {
    result[match.group(1)!] = int.parse(match.group(2)!);
  }
  return result;
}

/// The profile types of one message's fields, keyed by the profile field name.
///
/// Read off the typed accessors: their return type *is* the profile type, so a
/// field whose values have no names (a plain `int`) simply produces no entry.
/// Subfield accessors name their subfield in a [NamedSelector], and that name
/// is what the decoder reports for the field when the subfield is active — so
/// it is the key here too.
_Message? _readMessage(File file, Map<String, int> mesgNums) {
  final source = file.readAsStringSync();

  final mesg =
      RegExp(r"super\('([a-z0-9_]+)', MesgNum\.(\w+)\)").firstMatch(source);
  if (mesg == null) return null;
  final mesgNum = mesgNums[mesg.group(2)!];
  if (mesgNum == null) return null;

  // `static const int sportFieldNum = 5;`
  final fieldNumOf = <String, int>{};
  for (final match in RegExp(r'static const int (\w+)FieldNum = (\d+);')
      .allMatches(source)) {
    fieldNumOf[match.group(1)!] = int.parse(match.group(2)!);
  }

  // `fields[5] = Field('sport', 5, ...)` in the prototype: field number to the
  // name the profile gives it, which is the name a decoded Mesg reports.
  final nameOf = <int, String>{};
  for (final match
      in RegExp(r"Field\(\s*'([a-z0-9_]+)',\s*(\d+),").allMatches(source)) {
    nameOf.putIfAbsent(int.parse(match.group(2)!), () => match.group(1)!);
  }

  final types = <String, String>{};
  // dart format puts a blank line between members, and no blank line inside an
  // accessor body, so this splits the class into one chunk per member.
  for (final chunk in source.split('\n\n')) {
    final getter =
        RegExp(r'\n  ([A-Za-z_][\w<>?]*) get \w+').firstMatch('\n$chunk');
    if (getter == null) continue;

    var type = getter.group(1)!.replaceAll('?', '');
    // A repeated field reads as a list of the same profile type.
    final list = RegExp(r'^List<(\w+)\??>$').firstMatch(type);
    if (list != null) type = list.group(1)!;
    if (_plainTypes.contains(type)) continue;

    final field = RegExp(r'\b(\w+)FieldNum\b').firstMatch(chunk);
    if (field == null) continue;
    final fieldNum = fieldNumOf[field.group(1)!];
    if (fieldNum == null) continue;

    final subField =
        RegExp(r"NamedSelector\('([a-z0-9_]+)'\)").firstMatch(chunk);
    final key = subField != null ? subField.group(1)! : nameOf[fieldNum];
    if (key == null) continue;
    types[key] = type;
  }

  return _Message(mesgNum, types);
}

/// `running(1),` from one generated profile type.
///
/// Returns null for the types the generator writes as a class of constants
/// rather than an enum — a bit mask or a scalar with named thresholds, whose
/// values are meaningful outside the list and so must stay numbers.
Map<int, String>? _readEnum(Directory sdk, String type) {
  // The generator prefixed two profile types to keep them out of dart:core's
  // way (`file` -> FitFile, `mesg_num` -> FitMesgNum), so a type whose own name
  // finds no file is tried again without the prefix. fit_base_unit, whose
  // profile name really does start with `fit_`, is found by the first attempt.
  var file = File('${sdk.path}/types/${_snake(type)}.dart');
  if (!file.existsSync() && type.startsWith('Fit')) {
    file = File('${sdk.path}/types/${_snake(type.substring(3))}.dart');
  }
  if (!file.existsSync()) return null;
  final source = file.readAsStringSync();
  final start = source.indexOf('enum $type {');
  if (start < 0) return null;
  final end = source.indexOf('  const $type(', start);

  final values = <int, String>{};
  final body = source.substring(start, end);
  for (final match in RegExp(r'^  ([A-Za-z_$][\w$]*)\((0x[0-9a-fA-F]+|-?\d+)\)',
          multiLine: true)
      .allMatches(body)) {
    // `invalid` is the SDK's fallback for a value the profile does not name,
    // not a profile value: labelling a raw number with it would claim the file
    // says something it does not.
    if (match.group(1) == 'invalid') continue;
    // A profile value name may start with a digit ($3WayCalfRaise); the leading
    // `$` is what makes it a legal Dart identifier, not part of the name.
    final name = match.group(1)!.replaceFirst(RegExp(r'^\$'), '');
    // First name wins, as the profile may give one value two names.
    values.putIfAbsent(int.parse(match.group(2)!), () => name);
  }
  return values.isEmpty ? null : values;
}

String _profileVersion(File profile) {
  final source = profile.readAsStringSync();
  int of(String name) => int.parse(
      RegExp('static const int $name = (\\d+);').firstMatch(source)!.group(1)!);
  return '${of('versionMajor')}.${of('versionMinor')}.${of('versionBuild')}';
}

/// `SubSport` to `sub_sport`, the file name the generator gives a profile type.
String _snake(String name) => name
    .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '_${m.group(1)}')
    .replaceAllMapped(
        RegExp(r'(?<=[A-Z])([A-Z][a-z])'), (m) => '_${m.group(1)}')
    .toLowerCase();

String _render(
  Map<int, Map<String, String>> fieldTypes,
  Map<String, Map<int, String>> typeValues,
  String profileVersion,
) {
  final buffer = StringBuffer()
    ..writeln(
        '// GENERATED by tool/gen_profile_labels.dart from the fit_dart_sdk sources.')
    ..writeln(
        '// Profile $profileVersion. Do not edit; regenerate after a profile bump.')
    ..writeln('''
//
// The part of the FIT profile a generic message table needs and the typed API
// does not: which profile type each field carries, and what each value of those
// types is called. `SessionMesg.sport` returns `Sport.cycling` already — this is
// the same knowledge for code that only ever sees a [Mesg] and a field name.
//
// Stored as text rather than as map literals: ~2000 field entries and ~4000
// value entries would be a lot of constant tables to build at startup for data
// most runs read a handful of. Parsed into maps on first use instead.
//
// Line formats (profile names are [a-z0-9_], so the separators cannot occur in
// them):
//
//     fields: "<globalMesgNum>|<field_name>=<Type>,<sub_field_name>=<Type>,"
//     values: "<Type>|<value>=<value_name>,<value>=<value_name>,"

/// The profile type of [fieldName] on message [mesgNum], or null when the field
/// holds a plain number or string and so has no named values.
///
/// [fieldName] is the name a decoded field reports, which for a field with an
/// active subfield is the subfield's.
String? profileTypeOf(int mesgNum, String fieldName) =>
    _fieldTypes[mesgNum]?[fieldName];

/// What the profile calls [value] of type [type], or null when the type does
/// not name that exact value.
///
/// Only exact matches resolve. FIT bit-mask types name individual bits, and a
/// value combining two of them means both rather than the one that happens to
/// compare equal, so it is left as a number instead of being mislabelled.
String? profileValueName(String type, int value) => _typeValues[type]?[value];

/// A `date_time` or `local_date_time` field: seconds the demo renders as an
/// instant.
const String dateTimeType = 'DateTime';

/// A field the profile declares as a boolean.
const String boolType = 'bool';

final Map<int, Map<String, String>> _fieldTypes = {
  for (final line in _fieldTypeLines)
    int.parse(line.substring(0, line.indexOf('|'))):
        _entries(line, (key) => key),
};

final Map<String, Map<int, String>> _typeValues = {
  for (final line in _typeValueLines)
    line.substring(0, line.indexOf('|')): _entries(line, int.parse),
};

/// `"<head>|a=1,b=2,"` after the bar, as a map keyed by [key] of each name.
Map<K, String> _entries<K>(String line, K Function(String) key) {
  final result = <K, String>{};
  var from = line.indexOf('|') + 1;
  while (from < line.length) {
    final equals = line.indexOf('=', from);
    final comma = line.indexOf(',', equals);
    result[key(line.substring(from, equals))] =
        line.substring(equals + 1, comma);
    from = comma + 1;
  }
  return result;
}
''');

  void lines(String name, Iterable<String> values) {
    buffer.writeln('const List<String> $name = [');
    for (final value in values) {
      buffer.writeln("  '$value',");
    }
    buffer.writeln('];');
    buffer.writeln();
  }

  lines(
    '_fieldTypeLines',
    fieldTypes.entries.where((entry) => entry.value.isNotEmpty).map((entry) =>
        '${entry.key}|${entry.value.entries.map((f) => '${f.key}=${f.value},').join()}'),
  );
  lines(
    '_typeValueLines',
    typeValues.entries.map((entry) =>
        '${entry.key}|${entry.value.entries.map((v) => '${v.key}=${v.value},').join()}'),
  );

  return buffer.toString();
}
