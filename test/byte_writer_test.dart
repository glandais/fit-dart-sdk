/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:typed_data';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  test('a new writer is empty', () {
    final writer = ByteWriter();
    expect(writer.isEmpty, isTrue);
    expect(writer.size, 0);
    expect(writer.toBytes(), isEmpty);
  });

  test('multi-byte values honour the requested endianness', () {
    expect((ByteWriter()..writeUint16(0x0201)).toBytes(),
        TestData.bytes(const [0x01, 0x02]));
    expect((ByteWriter()..writeUint16(0x0201, Endianness.big)).toBytes(),
        TestData.bytes(const [0x02, 0x01]));
    expect((ByteWriter()..writeUint32(0x04030201)).toBytes(),
        TestData.bytes(const [0x01, 0x02, 0x03, 0x04]));
    expect(
      (ByteWriter()..writeInt64(0x0807060504030201, Endianness.big)).toBytes(),
      TestData.bytes(const [8, 7, 6, 5, 4, 3, 2, 1]),
    );
  });

  test('strings are NUL-terminated', () {
    expect((ByteWriter()..writeString('abc')).toBytes(),
        TestData.bytes(const [0x61, 0x62, 0x63, 0x00]));
  });

  test('the buffer grows past its initial capacity', () {
    final writer = ByteWriter(2);
    for (var i = 0; i < 1000; i++) {
      writer.writeByte(0xAB);
    }
    expect(writer.size, 1000);
    expect(writer.toBytes().every((b) => b == 0xAB), isTrue);
  });

  test('replaceRange overwrites bytes in place', () {
    // This is how the encoder patches the data size into an already-written
    // header.
    final writer = ByteWriter()
      ..writeBytes(Uint8List(14))
      ..writeByte(0x42);

    writer.replaceRange(0, TestData.bytes(const [0x0E, 0x20]));
    final bytes = writer.toBytes();
    expect(bytes[0], 0x0E);
    expect(bytes[1], 0x20);
    expect(bytes[14], 0x42);
    expect(writer.size, 15);
  });

  test('replaceRange refuses to write past what was written', () {
    final writer = ByteWriter()..writeBytes(Uint8List(4));
    expect(() => writer.replaceRange(2, Uint8List(4)), throwsArgumentError);
    expect(() => writer.replaceRange(-1, Uint8List(1)), throwsArgumentError);
  });

  test('everything written reads back identically', () {
    final writer = ByteWriter()
      ..writeByte(0xFE)
      ..writeUint16(0xCAFE)
      ..writeUint32(0xDEADBEEF)
      ..writeInt64(0x0123456789ABCDEF)
      ..writeInt32(-42)
      ..writeFloat32(1.5)
      ..writeFloat64(-2.25);

    final reader = ByteReader(writer.toBytes());
    expect(reader.readByte(), 0xFE);
    expect(reader.readUint16(), 0xCAFE);
    expect(reader.readUint32(), 0xDEADBEEF);
    expect(reader.readInt64(), 0x0123456789ABCDEF);
    expect(reader.readInt32(), -42);
    expect(reader.readFloat32(), 1.5);
    expect(reader.readFloat64(), -2.25);
  });

  test('the in-place CRC matches one taken over the written bytes', () {
    final writer = ByteWriter()..writeBytes(TestData.fitFileShort);
    expect(writer.crc(), Crc.calculate(writer.toBytes()));
  });
}
