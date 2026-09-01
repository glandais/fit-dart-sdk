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
  test('multi-byte values honour the requested endianness', () {
    final bytes = TestData.bytes(const [1, 2, 3, 4, 5, 6, 7, 8]);

    expect(ByteReader(bytes).readUint16(Endianness.little), 0x0201);
    expect(ByteReader(bytes).readUint16(Endianness.big), 0x0102);
    expect(ByteReader(bytes).readUint32(Endianness.little), 0x04030201);
    expect(ByteReader(bytes).readUint32(Endianness.big), 0x01020304);
    expect(ByteReader(bytes).readInt64(Endianness.little), 0x0807060504030201);
    expect(ByteReader(bytes).readInt64(Endianness.big), 0x0102030405060708);
  });

  test('signed reads preserve the sign bit', () {
    expect(ByteReader(TestData.bytes(const [0xFF])).readInt8(), -1);
    expect(ByteReader(TestData.bytes(const [0xFF, 0xFF])).readInt16(), -1);
    expect(
      ByteReader(TestData.bytes(const [0xFF, 0xFF, 0xFF, 0xFF])).readInt32(),
      -1,
    );
  });

  test('a uint64 above 2^63 comes back as the int sharing its bit pattern', () {
    final writer = ByteWriter()..writeUint64(-1);
    expect(ByteReader(writer.toBytes()).readUint64(), -1);
  });

  test('floats are read from their bit pattern', () {
    final writer = ByteWriter()
      ..writeFloat32(3.5)
      ..writeFloat64(-1.25);
    final reader = ByteReader(writer.toBytes());
    expect(reader.readFloat32(), 3.5);
    expect(reader.readFloat64(), -1.25);
  });

  test('strings stop at their NUL terminator', () {
    final reader = ByteReader(TestData.bytes(const [0x61, 0x62, 0x63, 0x00]));
    expect(reader.readString(4), 'abc');
    expect(reader.position, 4);
  });

  test('position tracks every read', () {
    final reader = ByteReader(TestData.fitFileShort);
    expect(reader.position, 0);
    expect(reader.bytesAvailable, TestData.fitFileShort.length);

    reader.readByte();
    expect(reader.position, 1);

    reader.skip(3);
    expect(reader.position, 4);

    reader.seek(0);
    expect(reader.position, 0);

    reader.reset();
    expect(reader.position, 0);
  });

  test('peek does not consume', () {
    final reader = ByteReader(TestData.fitFileShort);
    expect(reader.peekByte(), 0x0E);
    expect(reader.position, 0);
    expect(reader.readByte(), 0x0E);
    expect(reader.position, 1);
  });

  test('reading past the end fails rather than returning garbage', () {
    final reader = ByteReader(TestData.bytes(const [1, 2]));
    reader.readUint16();
    expect(reader.hasBytesAvailable, isFalse);
    expect(reader.readByte, throwsA(isA<FitFormatException>()));
    expect(() => reader.readBytes(1), throwsA(isA<FitFormatException>()));
    expect(() => reader.skip(1), throwsA(isA<FitFormatException>()));
    expect(() => reader.seek(99), throwsA(isA<FitFormatException>()));
  });

  test('an attached CRC checksums exactly what was consumed', () {
    final reader = ByteReader(TestData.fitFileShort)..crc = Crc();
    reader.skip(TestData.fitFileShort.length - 2);
    expect(reader.crc?.value, TestData.fitFileShortCrc);
  });

  test('slice copies without moving the cursor', () {
    final reader = ByteReader(TestData.fitFileShort)..skip(4);
    expect(reader.slice(0, 2), TestData.bytes(const [0x0E, 0x20]));
    expect(reader.position, 4);
  });

  test('indexing reads without consuming', () {
    final reader = ByteReader(TestData.fitFileShort);
    expect(reader[8], 0x2E);
    expect(reader.position, 0);
    expect(reader.hasBytesAvailable, isTrue);
  });

  test('readBytes hands back a copy, not a view of the file', () {
    final source = TestData.bytes(const [1, 2, 3, 4]);
    final slice = ByteReader(source).readBytes(2);
    slice[0] = 99;
    expect(source[0], 1);
  });
}
