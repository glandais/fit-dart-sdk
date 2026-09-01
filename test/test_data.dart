/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:typed_data';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';

/// FIT byte sequences shared by the tests, annotated with their record
/// structure.
///
/// These are the same fixtures the Swift, Kotlin and JavaScript SDKs use, so a
/// behaviour change here shows up as a difference against those SDKs rather than
/// as a silently rebaselined expectation.
abstract final class TestData {
  static Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  /// A complete one-message file: file_id with type, manufacturer, serial and a
  /// string.
  static final Uint8List fitFileShort = bytes(const [
    // header, 14 bytes
    0x0E, 0x20, 0x8B, 0x08, 0x24, 0x00, 0x00, 0x00, 0x2E, 0x46, 0x49, 0x54,
    0x8E, 0xA3,
    // definition, 18 bytes
    0x40, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x01, 0x02, 0x84,
    0x04, 0x04, 0x86, 0x08, 0x0A, 0x07,
    // data, 18 bytes
    0x00, 0x04, 0x01, 0x00, 0x00, 0xCA, 0x9A, 0x3B, 0x61, 0x62, 0x63, 0x64,
    0x65, 0x66, 0x67, 0x68, 0x69, 0x00,
    // file CRC
    0x5D, 0xF2,
  ]);

  /// CRC over everything in [fitFileShort] but its trailing CRC.
  static const int fitFileShortCrc = 0xF25D;

  /// [fitFileShort] with its header zeroed out.
  static final Uint8List fitFileShortInvalidHeader =
      Uint8List.fromList(fitFileShort)..fillRange(0, 14, 0);

  /// [fitFileShort] with the file CRC corrupted.
  static final Uint8List fitFileShortInvalidCrc = () {
    final copy = Uint8List.fromList(fitFileShort);
    copy[copy.length - 1] = (copy[copy.length - 1] + 1) & 0xFF;
    return copy;
  }();

  /// [fitFileShort] with its *header* CRC corrupted and its file CRC put back.
  ///
  /// Recomputing the trailing CRC matters: it covers the header too, so a file
  /// with only the header CRC touched would otherwise fail on the file CRC and
  /// prove nothing about the header check.
  static final Uint8List fitFileShortInvalidHeaderCrc = () {
    final copy = Uint8List.fromList(fitFileShort);
    copy[12] = (copy[12] + 1) & 0xFF;
    return withFileCrc(copy);
  }();

  /// [fitFileShort] with an unfilled (0x0000) header CRC, which FIT allows.
  static final Uint8List fitFileShortUnsetHeaderCrc = () {
    final copy = Uint8List.fromList(fitFileShort);
    copy[12] = 0;
    copy[13] = 0;
    return withFileCrc(copy);
  }();

  /// [fitFileShort] rewritten with the 12-byte header form, which has no header
  /// CRC.
  static final Uint8List fitFileShortShortHeader = () {
    final copy = Uint8List.fromList(<int>[
      ...fitFileShort.sublist(0, 12),
      ...fitFileShort.sublist(14),
    ]);
    copy[0] = 12;
    return withFileCrc(copy);
  }();

  /// The records of [fitFileShort] with no header and no CRC.
  static final Uint8List fitFileShortDataOnly =
      Uint8List.fromList(fitFileShort.sublist(14, fitFileShort.length - 2));

  /// Replaces the last two bytes of [value] with the CRC over everything before
  /// them.
  static Uint8List withFileCrc(Uint8List value) {
    final crc = Crc.calculate(value, 0, value.length - Fit.crcSize);
    value[value.length - 2] = crc & 0xFF;
    value[value.length - 1] = (crc >> 8) & 0xFF;
    return value;
  }

  /// Wraps [records] in a valid 14-byte header and a trailing file CRC.
  static Uint8List fileOf(Uint8List records) {
    final header = FileHeader(dataSize: records.length)..updateCrc();
    final writer = ByteWriter()
      ..writeBytes(header.toBytes())
      ..writeBytes(records);
    writer.writeUint16(writer.crc());
    return writer.toBytes();
  }
}
