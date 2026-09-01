/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:typed_data';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  Uint8List minimalFile() => encodeFit((encoder) {
        encoder.write(FileIdMesg()
          ..type = FitFile.activity
          ..manufacturer = Manufacturer.development
          ..serialNumber = 1234
          ..timeCreated = DateTime.utc(2024, 1, 1));
      });

  test('an encoded file is a valid FIT file', () {
    final bytes = minimalFile();
    expect(FitDecoder(bytes).isFit(), isTrue);
    expect(FitDecoder(bytes).checkIntegrity(), isTrue);
  });

  test('the header records the size of what follows it', () {
    final bytes = minimalFile();
    final header = FileHeader.read(ByteReader(bytes));
    expect(header.headerSize, Fit.headerWithCrcSize);
    expect(
      header.dataSize,
      bytes.length - Fit.headerWithCrcSize - Fit.crcSize,
    );
  });

  test('an encoded file carries a valid header CRC', () {
    final bytes = minimalFile();
    final header = FileHeader.read(ByteReader(bytes));
    expect(header.headerCrc, Crc.calculate(bytes, 0, 12));
  });

  test('what is written is what decodes', () {
    final when = DateTime.utc(2024, 1, 1);
    final result = FitDecoder(minimalFile()).decode();

    expect(result.errors, isEmpty);
    final fileId = result.messages.fileIdMesgs.single;
    expect(fileId.type, FitFile.activity);
    expect(fileId.manufacturer, Manufacturer.development);
    expect(fileId.serialNumber, 1234);
    expect(fileId.timeCreated, when);
  });

  test('a repeated layout is defined only once', () {
    final one = encodeFit((e) => e.write(RecordMesg()..heartRate = 140));
    final two = encodeFit((e) => e
      ..write(RecordMesg()..heartRate = 140)
      ..write(RecordMesg()..heartRate = 150));

    // The second record costs its payload, not another definition record.
    expect(two.length - one.length, 2);
  });

  test('a changed layout emits a fresh definition', () {
    final same = encodeFit((e) => e
      ..write(RecordMesg()..heartRate = 140)
      ..write(RecordMesg()..heartRate = 150));
    final changed = encodeFit((e) => e
      ..write(RecordMesg()..heartRate = 140)
      ..write(RecordMesg()..cadence = 90));

    expect(changed.length, greaterThan(same.length));
  });

  test('every base type survives a round trip', () {
    // On a message number the profile does not know, so that every field keeps
    // the base type declared here rather than the one the profile assigns.
    final mesg = Mesg(Factory.unknownName, 0xFFFE);
    var fieldNum = 0;
    final expected = <int, Object?>{};
    for (final type in BaseType.values) {
      if (type == BaseType.string) continue;
      final field = Field('f$fieldNum', fieldNum, type);
      final value = type.isFloatingPoint ? 1.5 : 7;
      field.setValue(value);
      mesg.setField(field);
      expected[fieldNum] = field.getRawValue();
      fieldNum++;
    }

    final decoded = FitDecoder(encodeFit((e) => e.write(mesg)))
        .decode(const DecodeOptions(includeUnknownData: true))
        .messages
        .unknownMesgs
        .single;

    expected.forEach((fieldNum, value) {
      expect(decoded.getField(fieldNum)?.getRawValue(), value,
          reason: 'field \$fieldNum');
    });
  });

  test('strings survive a round trip', () {
    final bytes =
        encodeFit((e) => e.write(FileIdMesg()..productName = 'héllo'));
    final decoded = FitDecoder(bytes).decode().messages.fileIdMesgs.single;
    expect(decoded.productName, 'héllo');
  });

  test('an array field survives a round trip', () {
    final bytes =
        encodeFit((e) => e.write(HrvMesg()..time = <double?>[0.5, 0.75]));
    final decoded = FitDecoder(bytes).decode().messages.hrvMesgs.single;
    expect(decoded.time, <double?>[0.5, 0.75]);
  });

  test('an absent field is not written at all', () {
    final bytes = encodeFit((e) => e.write(RecordMesg()..heartRate = 140));
    final decoded = FitDecoder(bytes).decode().messages.recordMesgs.single;
    expect(decoded.fieldList, hasLength(1));
    expect(decoded.cadence, isNull);
  });

  test('many messages encode and decode', () {
    final bytes = encodeFit((e) {
      for (var i = 0; i < 1000; i++) {
        e.write(RecordMesg()..heartRate = 100 + (i % 60));
      }
    });
    final decoded = FitDecoder(bytes).decode();
    expect(decoded.errors, isEmpty);
    expect(decoded.messages.recordMesgs, hasLength(1000));
    expect(decoded.messages.recordMesgs.last.heartRate, 100 + (999 % 60));
  });

  test('an encoder cannot be used after closing', () {
    final encoder = FitEncoder()..write(FileIdMesg());
    encoder.close();
    expect(() => encoder.write(RecordMesg()), throwsStateError);
    expect(encoder.close, throwsStateError);
  });

  test('the message count tracks what was written', () {
    final encoder = FitEncoder();
    expect(encoder.mesgCount, 0);
    encoder.write(FileIdMesg());
    expect(encoder.mesgCount, 1);
    encoder.writeAll(<Mesg>[RecordMesg(), RecordMesg()]);
    expect(encoder.mesgCount, 3);
  });

  test('a big-endian file round-trips', () {
    final bytes = encodeFit(
      (e) => e.write(RecordMesg()
        ..heartRate = 140
        ..speed = 5.5),
      endianness: Endianness.big,
    );

    final decoded = FitDecoder(bytes).decode();
    expect(decoded.errors, isEmpty);
    final record = decoded.messages.recordMesgs.single;
    expect(record.heartRate, 140);
    expect(record.speed, 5.5);
  });

  test('big- and little-endian encodings decode identically', () {
    Uint8List build(Endianness endianness) => encodeFit(
          (e) => e.write(SessionMesg()
            ..sport = Sport.cycling
            ..totalDistance = 42195.0),
          endianness: endianness,
        );

    final little = FitDecoder(build(Endianness.little)).decode();
    final big = FitDecoder(build(Endianness.big)).decode();

    expect(big.messages.sessionMesgs.single.sport,
        little.messages.sessionMesgs.single.sport);
    expect(big.messages.sessionMesgs.single.totalDistance,
        little.messages.sessionMesgs.single.totalDistance);
  });

  test('encoding is deterministic', () {
    Uint8List build() => encodeFit((e) => e
      ..write(FileIdMesg()
        ..type = FitFile.activity
        ..timeCreated = DateTime.utc(2024, 1, 1))
      ..write(RecordMesg()..heartRate = 140));

    expect(build(), build());
  });

  test('a registered developer field round-trips', () {
    final description = DeveloperFieldDescription(
      developerDataIndex: 0,
      fieldDefinitionNumber: 0,
      fieldName: 'Doughnuts Earned',
      baseType: BaseType.float32,
      units: 'doughnuts',
      applicationId: List<int>.filled(16, 3),
      applicationVersion: 110,
    );

    final bytes = encodeFit((e) {
      e.registerDeveloperField(description);
      final record = RecordMesg()..heartRate = 140;
      record.setDeveloperField(description.createField()..setValue(3.5));
      e.write(record);
    });

    final result = FitDecoder(bytes).decode();
    expect(result.errors, isEmpty);
    expect(result.messages.developerFieldDescriptions, hasLength(1));

    final record = result.messages.recordMesgs.single;
    expect(record.heartRate, 140);
    final devField = record.developerFieldList.single;
    expect(devField.fieldName, 'Doughnuts Earned');
    expect(devField.units, 'doughnuts');
    expect(devField.getValue(), 3.5);
    expect(devField.applicationId, List<int>.filled(16, 3));
  });

  test('an application announces its index only once', () {
    DeveloperFieldDescription describe(int fieldNum) =>
        DeveloperFieldDescription(
          developerDataIndex: 0,
          fieldDefinitionNumber: fieldNum,
          fieldName: 'field $fieldNum',
          baseType: BaseType.uint8,
          applicationId: List<int>.filled(16, 1),
        );

    final bytes = encodeFit((e) => e
      ..registerDeveloperField(describe(0))
      ..registerDeveloperField(describe(1)));

    final result = FitDecoder(bytes).decode();
    expect(result.messages.developerDataIdMesgs, hasLength(1));
    expect(result.messages.fieldDescriptionMesgs, hasLength(2));
  });
}
