/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('bits come out least significant first across a byte array', () {
    final stream = BitStream(const <Object?>[0xAA, 0xFF], BaseType.uint8);
    const expected = [0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1];

    for (var index = 0; index < expected.length; index++) {
      expect(stream.hasBitsAvailable, isTrue);
      expect(stream.bitsAvailable, expected.length - index);
      expect(stream.readBits(1), expected[index]);
    }
    expect(stream.hasBitsAvailable, isFalse);
  });

  test('a multi-byte value is read little-endian', () {
    final stream = BitStream.of(0xAAFF, BaseType.uint16);
    const expected = [1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1];
    for (final bit in expected) {
      expect(stream.readBits(1), bit);
    }
  });

  test('reads split across nibbles and values', () {
    expect(BitStream.of(0xAB, BaseType.uint8).readBits(8), 0xAB);

    final nibbles = BitStream.of(0xAB, BaseType.uint8);
    expect(nibbles.readBits(4), 0xB);
    expect(nibbles.readBits(4), 0xA);

    // Two 8-bit values read as one 16-bit quantity.
    expect(
      BitStream(const <Object?>[0xAA, 0xCB], BaseType.uint8).readBits(16),
      0xCBAA,
    );

    // Four 8-bit values read as one 32-bit quantity.
    expect(
      BitStream(const <Object?>[0xAA, 0xCB, 0xDE, 0xFF], BaseType.uint8)
          .readBits(32),
      0xFFDECBAA,
    );
  });

  test('signed reads sign-extend from the requested width', () {
    // 12 bits of all ones is -1, not 4095, when the destination is signed.
    expect(BitStream.of(0x0FFF, BaseType.uint16).readBits(12, true), -1);
    expect(BitStream.of(0x0FFF, BaseType.uint16).readBits(12), 4095);
  });

  test('a full-width 64-bit value survives unchanged', () {
    expect(
      BitStream.of(0xABCDEF0123456789, BaseType.uint64).readBits(64),
      0xABCDEF0123456789,
    );
  });

  test('a float unpacks from its own bit layout, not a double\'s', () {
    // 1.5f is 0x3FC00000; read as 32 bits it must be exactly that, which it is
    // only if the stream sized the value by its base type rather than by Dart's
    // one floating-point type.
    expect(BitStream.of(1.5, BaseType.float32).readBits(32), 0x3FC00000);
  });

  test('reading past the end fails', () {
    final stream = BitStream.of(0xAA, BaseType.uint8)..readBits(8);
    expect(() => stream.readBits(1), throwsA(isA<FitFormatException>()));
  });

  test('an out-of-range width is rejected', () {
    final stream = BitStream.of(0xAA, BaseType.uint8);
    expect(() => stream.readBits(0), throwsArgumentError);
    expect(() => stream.readBits(65), throwsArgumentError);
  });

  test('reset rewinds to the start', () {
    final stream = BitStream.of(0xAB, BaseType.uint8);
    expect(stream.readBits(4), 0xB);
    stream.reset();
    expect(stream.bitsAvailable, 8);
    expect(stream.readBits(8), 0xAB);
  });
}
