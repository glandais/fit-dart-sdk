/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  /// The definition record of [TestData.fitFileShort], header byte consumed.
  MesgDefinition readFixtureDefinition() {
    final reader = ByteReader(TestData.fitFileShort, 14);
    return MesgDefinition.read(reader, reader.readByte());
  }

  test('reads the layout of a real definition record', () {
    final definition = readFixtureDefinition();

    expect(definition.localMesgNum, 0);
    expect(definition.globalMesgNum, MesgNum.fileId);
    expect(definition.endianness, Endianness.little);
    expect(definition.numFields, 4);
    expect(definition.numDeveloperFields, 0);

    expect(definition.fieldDefinitions[0].num, 0);
    expect(definition.fieldDefinitions[0].size, 1);
    expect(definition.fieldDefinitions[0].baseType, BaseType.fitEnum);
    expect(definition.fieldDefinitions[1].baseType, BaseType.uint16);
    expect(definition.fieldDefinitions[2].baseType, BaseType.uint32);
    expect(definition.fieldDefinitions[3].baseType, BaseType.string);
  });

  test('message size is the sum of the field widths', () {
    expect(readFixtureDefinition().messageSize, 17);
  });

  test('a written definition reproduces the original bytes', () {
    final writer = ByteWriter();
    readFixtureDefinition().write(writer);
    expect(writer.toBytes(), TestData.fitFileShort.sublist(14, 32));
  });

  test('field counts are derived from the width and base type', () {
    expect(FieldDefinition(0, 8, BaseType.uint16.id).count, 4);
    expect(FieldDefinition(0, 1, BaseType.uint8.id).count, 1);
    expect(FieldDefinition.ofBaseType(0, 12, BaseType.float32).count, 3);
  });

  test('an unknown type byte yields no base type', () {
    const definition = FieldDefinition(0, 4, 0x1F);
    expect(definition.baseType, isNull);
    expect(definition.count, 0);
  });

  test('layout equality ignores the local number it is bound to', () {
    final a = MesgDefinition(
        0, MesgNum.record, Endianness.little, const [FieldDefinition(3, 1, 2)]);
    final b = MesgDefinition(
        7, MesgNum.record, Endianness.little, const [FieldDefinition(3, 1, 2)]);

    expect(a.hasSameLayout(b), isTrue);
    expect(a == b, isFalse);
  });

  test('layout equality accounts for the architecture', () {
    // Two definitions listing the same fields under different architectures
    // decode differently, so an encoder must emit a fresh definition record.
    final little = MesgDefinition(
        0, MesgNum.record, Endianness.little, const [FieldDefinition(3, 1, 2)]);
    final big = MesgDefinition(
        0, MesgNum.record, Endianness.big, const [FieldDefinition(3, 1, 2)]);

    expect(little.hasSameLayout(big), isFalse);
  });

  test('a definition derived from a message covers its populated fields', () {
    final mesg = RecordMesg()
      ..heartRate = 140
      ..cadence = 90;

    final definition = MesgDefinition.of(mesg, 3);
    expect(definition.localMesgNum, 3);
    expect(definition.globalMesgNum, MesgNum.record);
    expect(definition.numFields, 2);
    expect(
      definition.fieldDefinitions.map((f) => f.num).toList(),
      <int>[RecordMesg.heartRateFieldNum, RecordMesg.cadenceFieldNum],
    );
    expect(definition.messageSize, 2);
  });

  test('a definition survives a write/read round trip', () {
    final original = MesgDefinition.of(
      RecordMesg()
        ..heartRate = 140
        ..speed = 5.0,
      5,
    );

    final writer = ByteWriter();
    original.write(writer);
    final reader = ByteReader(writer.toBytes());
    final roundTripped = MesgDefinition.read(reader, reader.readByte());

    expect(roundTripped.localMesgNum, original.localMesgNum);
    expect(roundTripped.hasSameLayout(original), isTrue);
  });

  test('a big-endian definition survives a write/read round trip', () {
    final original = MesgDefinition.of(
      RecordMesg()..heartRate = 140,
      2,
      Endianness.big,
    );

    final writer = ByteWriter();
    original.write(writer);
    final reader = ByteReader(writer.toBytes());
    final roundTripped = MesgDefinition.read(reader, reader.readByte());

    expect(roundTripped.endianness, Endianness.big);
    expect(roundTripped.globalMesgNum, MesgNum.record);
    expect(roundTripped.hasSameLayout(original), isTrue);
  });

  test('an unknown architecture byte is a format error', () {
    final writer = ByteWriter()
      ..writeByte(0x40)
      ..writeByte(0)
      ..writeByte(9) // neither 0 nor 1
      ..writeUint16(20)
      ..writeByte(0);
    final reader = ByteReader(writer.toBytes());
    final header = reader.readByte();
    expect(() => MesgDefinition.read(reader, header),
        throwsA(isA<FitFormatException>()));
  });
}
