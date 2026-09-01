/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('a profile message comes back with its name and every field', () {
    final mesg = Factory.createMesg(MesgNum.record);
    expect(mesg.mesgName, 'record');
    expect(mesg.globalMesgNum, MesgNum.record);
    expect(mesg.fieldList, isNotEmpty);
    expect(mesg.getField(RecordMesg.heartRateFieldNum), isNotNull);
    // Metadata only: nothing is populated.
    expect(mesg.fieldList.every((f) => !f.hasValues), isTrue);
  });

  test('an unknown message number yields an empty message', () {
    expect(Factory.isKnownMesg(0xFFFE), isFalse);
    final mesg = Factory.createMesg(0xFFFE);
    expect(mesg.mesgName, Factory.unknownName);
    expect(mesg.fieldList, isEmpty);
  });

  test('fields carry their profile metadata', () {
    final speed =
        Factory.createField(MesgNum.record, RecordMesg.speedFieldNum)!;
    expect(speed.fieldName, 'speed');
    expect(speed.baseType, BaseType.uint16);
    expect(speed.scale, 1000.0);
    expect(speed.offset, 0.0);
    expect(speed.units, 'm/s');
  });

  test('an unknown field number yields null', () {
    expect(Factory.createField(MesgNum.record, 254), isNull);
    expect(Factory.createField(0xFFFE, 0), isNull);
  });

  test('every call returns a fresh field', () {
    final a =
        Factory.createField(MesgNum.record, RecordMesg.heartRateFieldNum)!;
    final b =
        Factory.createField(MesgNum.record, RecordMesg.heartRateFieldNum)!;
    a.setValue(140);
    expect(b.hasValues, isFalse);
    expect(identical(a, b), isFalse);
  });

  test('a default field takes its type from the file', () {
    final field = Factory.createDefaultField(200, BaseType.sint16);
    expect(field.fieldName, Factory.unknownName);
    expect(field.fieldNum, 200);
    expect(field.baseType, BaseType.sint16);
    expect(field.scale, Fit.fieldDefaultScale);
  });

  test('components and subfields survive into the created field', () {
    final data = Factory.createField(MesgNum.event, EventMesg.dataFieldNum)!;
    expect(data.hasSubFields, isTrue);
    expect(
      data.subFields.map((s) => s.name),
      contains('gear_change_data'),
    );

    final gearChange = data.getSubFieldNamed('gear_change_data')!;
    expect(gearChange.hasComponents, isTrue);
    expect(
        gearChange.components.map((c) => c.bits).toList(), <int>[8, 8, 8, 8]);
  });

  test('an accumulating component is flagged as such', () {
    final field = Factory.createField(
        MesgNum.record, RecordMesg.compressedSpeedDistanceFieldNum)!;
    expect(field.hasComponents, isTrue);
    final distance = field.components
        .firstWhere((c) => c.fieldNum == RecordMesg.distanceFieldNum);
    expect(distance.accumulate, isTrue);
    expect(distance.bits, 12);
  });

  test('the profile version is scaled the way the file header scales it', () {
    // The minor version runs past 100, so a factor of 100 would fold it into the
    // major version and make 21.205 indistinguishable from 23.5.
    expect(Profile.version, Fit.profileVersion);
    expect(
      Profile.version,
      Profile.versionMajor * Fit.profileVersionScale + Profile.versionMinor,
    );
  });

  test('MesgNum constants match the generated classes', () {
    expect(RecordMesg().globalMesgNum, MesgNum.record);
    expect(SessionMesg().globalMesgNum, MesgNum.session);
    expect(FileIdMesg().globalMesgNum, MesgNum.fileId);
    expect(Factory.mesgName(MesgNum.record), 'record');
    expect(Factory.mesgName(MesgNum.fileId), 'file_id');
  });

  test('typed() wraps a message in its generated class', () {
    final raw = Mesg('record', MesgNum.record)
      ..setFieldValue(RecordMesg.heartRateFieldNum, 140);
    final typed = Factory.typed(raw);
    expect(typed, isA<RecordMesg>());
    expect((typed as RecordMesg).heartRate, 140);
    expect(Factory.typed(Mesg('unknown', 0xFFFE)), isA<Mesg>());
  });
}
