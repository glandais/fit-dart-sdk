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
  test('reads the fields of a real header', () {
    final header = FileHeader.read(ByteReader(TestData.fitFileShort));

    expect(header.headerSize, 14);
    expect(header.protocolVersion, ProtocolVersion.v2_0);
    expect(header.profileVersion, 0x088B);
    expect(header.dataSize, 0x24);
    expect(header.dataType, FileHeader.fitDataType);
    expect(header.hasCrc, isTrue);
    expect(header.isValid, isTrue);
  });

  test('a zeroed header is not valid', () {
    final header =
        FileHeader.read(ByteReader(TestData.fitFileShortInvalidHeader));
    expect(header.isValid, isFalse);
  });

  test('the header CRC covers the first twelve bytes only', () {
    final header = FileHeader.read(ByteReader(TestData.fitFileShort));
    final recorded = header.headerCrc;

    header.updateCrc();
    expect(header.headerCrc, recorded);
    expect(header.headerCrc, Crc.calculate(TestData.fitFileShort, 0, 12));
  });

  test('the twelve-byte form omits the CRC', () {
    final header =
        FileHeader(headerSize: Fit.headerWithoutCrcSize, dataSize: 100);
    expect(header.hasCrc, isFalse);
    expect(header.isValid, isTrue);
    expect(header.toBytes().length, 12);
  });

  test('a written header reads back identically', () {
    final header = FileHeader(dataSize: 0x1234)..updateCrc();

    final writer = ByteWriter();
    header.write(writer);
    final bytes = writer.toBytes();
    expect(bytes.length, 14);

    final roundTripped = FileHeader.read(ByteReader(bytes));
    expect(roundTripped.headerSize, header.headerSize);
    expect(roundTripped.protocolVersion, header.protocolVersion);
    expect(roundTripped.profileVersion, header.profileVersion);
    expect(roundTripped.dataSize, header.dataSize);
    expect(roundTripped.dataType, header.dataType);
    expect(roundTripped.headerCrc, header.headerCrc);
  });

  test('the fixture header serialises back to its original bytes', () {
    final header = FileHeader.read(ByteReader(TestData.fitFileShort));
    expect(header.toBytes(), TestData.fitFileShort.sublist(0, 14));
  });

  test('defaults match the profile this SDK was generated from', () {
    final header = FileHeader();
    expect(header.protocolVersion, ProtocolVersion.v2_0);
    expect(header.profileVersion, Fit.profileVersion);
    expect(header.dataSize, 0);
  });

  test('the raw protocol byte is kept as the producer wrote it', () {
    // The byte packs a major version in its high nibble and a minor in its low
    // one, so producers write values the enum does not name; narrowing it would
    // silently rewrite such a file's header.
    final header = FileHeader(protocolVersionByte: 0x21);
    expect(header.protocolVersion, ProtocolVersion.invalid);
    expect(header.protocolVersionMajor, 2);
    expect(header.protocolVersionMinor, 1);
    expect(header.toBytes()[1], 0x21);
  });
}
