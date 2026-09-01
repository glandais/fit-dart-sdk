/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('typed accessors read and write the same fields as the untyped API', () {
    final mesg = RecordMesg()..heartRate = 140;

    expect(mesg.getFieldValue(RecordMesg.heartRateFieldNum), 140);
    expect(
        mesg.getField(RecordMesg.heartRateFieldNum)?.fieldName, 'heart_rate');

    mesg.setFieldValue(RecordMesg.heartRateFieldNum, 150);
    expect(mesg.heartRate, 150);
  });

  test('an unset field reads as null', () {
    final mesg = RecordMesg();
    expect(mesg.heartRate, isNull);
    expect(mesg.hasField(RecordMesg.heartRateFieldNum), isFalse);
    expect(mesg.getField(RecordMesg.heartRateFieldNum), isNull);
  });

  test('a scaled field surfaces in its real units', () {
    final mesg = RecordMesg()..speed = 5.5;
    expect(mesg.speed, 5.5);
    // Stored raw at the profile's scale of 1000.
    expect(mesg.getField(RecordMesg.speedFieldNum)?.getRawValue(), 5500);
  });

  test('enum fields round-trip through their profile type', () {
    final session = SessionMesg()..sport = Sport.cycling;
    expect(session.sport, Sport.cycling);
    expect(
        session.getFieldValue(SessionMesg.sportFieldNum), Sport.cycling.value);
  });

  test('an unknown enum value reads as invalid', () {
    final session = SessionMesg()
      ..setFieldValue(SessionMesg.sportFieldNum, 200);
    expect(session.sport, Sport.invalid);
  });

  test('timestamps cross the FIT epoch', () {
    final when = DateTime.utc(2021, 7, 20, 21, 11, 20);
    final mesg = RecordMesg()..timestamp = when;

    expect(mesg.timestamp, when);
    expect(
      mesg.getFieldValue(RecordMesg.timestampFieldNum),
      when.millisecondsSinceEpoch ~/ 1000 - Fit.epochOffsetSeconds,
    );
  });

  test('a device uptime is not a wall-clock time', () {
    // Below the threshold a timestamp is seconds since power-on, which cannot
    // become a DateTime.
    final mesg = RecordMesg()
      ..setFieldValue(RecordMesg.timestampFieldNum, 1000);
    expect(mesg.timestamp, isNull);
    expect(FitDateTime.isSystemTime(1000), isTrue);
  });

  test('array fields are indexed and counted', () {
    final hrv = HrvMesg()
      ..setTime(0, 0.5)
      ..setTime(1, 0.75);

    expect(hrv.numTime, 2);
    expect(hrv.getTime(0), 0.5);
    expect(hrv.getTime(1), 0.75);
    expect(hrv.time, <double?>[0.5, 0.75]);
  });

  test('assigning an array field replaces every value', () {
    final hrv = HrvMesg()
      ..setTime(0, 0.5)
      ..setTime(1, 0.75)
      ..setTime(2, 1.0);
    hrv.time = <double?>[0.25];

    expect(hrv.numTime, 1);
    expect(hrv.time, <double?>[0.25]);

    hrv.time = null;
    expect(hrv.numTime, 0);
    expect(hrv.time, isNull);
  });

  test('a subfield reads only when its reference field selects it', () {
    final event = EventMesg()
      ..event = Event.rearGearChange
      ..setGearChangeData(0x01020304);

    expect(event.gearChangeData, 0x01020304);
    expect(event.data, 0x01020304);

    // A different reference value deselects it.
    final other = EventMesg()
      ..event = Event.timer
      ..data = 7;
    expect(other.gearChangeData, isNull);
    expect(other.data, 7);
  });

  test('setting a subfield whose reference field is absent is refused', () {
    final event = EventMesg();
    expect(() => event.setGearChangeData(1), throwsA(isA<FitFieldException>()));
  });

  test('the active subfield index is reported', () {
    final event = EventMesg()
      ..event = Event.rearGearChange
      ..setGearChangeData(1);
    expect(event.getActiveSubFieldIndex(EventMesg.dataFieldNum),
        isNot(Mesg.mainField));

    // event.timer selects the timer_trigger subfield, so the reference value
    // that means "no subfield" has to be one no subfield maps: a field with no
    // subfields at all always reports the main field.
    final record = RecordMesg()..heartRate = 140;
    expect(record.getActiveSubFieldIndex(RecordMesg.heartRateFieldNum),
        Mesg.mainField);
  });

  test('copying a message carries its populated fields only', () {
    final original = RecordMesg()
      ..heartRate = 140
      ..cadence = 90;
    original
        .setField(Field('speed', RecordMesg.speedFieldNum, BaseType.uint16));

    final copy = RecordMesg.from(original);
    expect(copy.heartRate, 140);
    expect(copy.cadence, 90);
    expect(copy.hasField(RecordMesg.speedFieldNum), isFalse);
  });

  test('mutating a copy leaves the original intact', () {
    final original = RecordMesg()..heartRate = 140;
    final copy = RecordMesg.from(original)..heartRate = 150;

    expect(original.heartRate, 140);
    expect(copy.heartRate, 150);
  });

  test('mutating the original leaves an earlier copy intact', () {
    final original = RecordMesg()..heartRate = 140;
    final copy = RecordMesg.from(original);
    original.heartRate = 150;

    expect(copy.heartRate, 140);
  });

  test('a message knows its own identity', () {
    final mesg = RecordMesg();
    expect(mesg.mesgName, 'record');
    expect(mesg.globalMesgNum, MesgNum.record);
    expect(mesg.toString(), contains('record'));
  });

  test('removeExpandedFields drops only synthesised fields', () {
    final mesg = RecordMesg()..heartRate = 140;
    final expanded = Field('speed', RecordMesg.speedFieldNum, BaseType.uint16)
      ..setValue(5000);
    expanded.isExpandedField = true;
    mesg.setField(expanded);

    mesg.removeExpandedFields();
    expect(mesg.heartRate, 140);
    expect(mesg.hasField(RecordMesg.speedFieldNum), isFalse);
  });

  test('FitMessages sorts by type and keeps file order within a type', () {
    final messages = FitMessages()
      ..add(RecordMesg()..heartRate = 1)
      ..add(SessionMesg()..sport = Sport.running)
      ..add(RecordMesg()..heartRate = 2)
      ..add(Mesg('unknown', 0xFFFE));

    expect(messages.recordMesgs.map((m) => m.heartRate).toList(), <int?>[1, 2]);
    expect(messages.sessionMesgs.single.sport, Sport.running);
    expect(messages.unknownMesgs.length, 1);
    expect(messages.length, 4);
    expect(messages.all().length, 4);
  });

  test('the message lists are read-only views', () {
    final messages = FitMessages()..add(RecordMesg());
    expect(
        () => messages.recordMesgs.add(RecordMesg()), throwsUnsupportedError);
  });

  test('writing under a definition that declares an absent field is refused',
      () {
    // A definition record is a promise about the exact byte layout of the
    // records that follow it; skipping a declared field would shift every byte
    // after it rather than merely losing that field.
    final mesg = RecordMesg()..heartRate = 140;
    final definition = MesgDefinition(0, MesgNum.record, Endianness.little,
        const [FieldDefinition(RecordMesg.cadenceFieldNum, 1, 2)]);

    expect(() => mesg.write(ByteWriter(), definition),
        throwsA(isA<FitFieldException>()));
  });

  test('writing under a matching definition emits the declared byte count', () {
    final mesg = RecordMesg()
      ..heartRate = 140
      ..cadence = 90;
    final definition = MesgDefinition.of(mesg, 0);

    final writer = ByteWriter();
    mesg.write(writer, definition);
    // One record header byte plus the declared payload.
    expect(writer.size, 1 + definition.messageSize);
  });

  test('an unprofiled field number infers its type from the value', () {
    final mesg = RecordMesg()..setFieldValue(250, 42);
    expect(mesg.getField(250)?.baseType, BaseType.sint64);
    expect(mesg.getFieldValue(250), 42);

    expect(() => RecordMesg().setFieldValue(250, DateTime.now()),
        throwsA(isA<FitFieldException>()));
  });
}
