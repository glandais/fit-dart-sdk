/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('every base type is reachable from its wire id', () {
    for (final type in BaseType.values) {
      expect(BaseType.fromId(type.id), type);
    }
    expect(BaseType.fromId(0x1F), isNull);
  });

  test('invalid sentinels round-trip through isValid', () {
    for (final type in BaseType.values) {
      expect(type.isValid(type.invalidValue()), isFalse,
          reason: '$type should read its own sentinel as invalid');
      expect(type.isInvalid(null), isTrue);
    }
  });

  test('invalid bytes are as wide as the type', () {
    for (final type in BaseType.values) {
      if (type == BaseType.string) {
        expect(type.invalidBytes(), <int>[0]);
        continue;
      }
      expect(type.invalidBytes().length, type.size, reason: '$type');
    }
    expect(BaseType.uint8.invalidBytes(), <int>[0xFF]);
    expect(BaseType.sint16.invalidBytes(), <int>[0xFF, 0x7F]);
    expect(BaseType.uint16z.invalidBytes(), <int>[0, 0]);
  });

  test('the float invalid is all ones, not the canonical NaN', () {
    // Both are quiet NaNs, but only the all-ones pattern survives a
    // decode/encode round trip: writing a canonical NaN back out would emit
    // 0x7FC00000 where the file held 0xFFFFFFFF.
    expect(BaseType.float32.invalidBytes(), <int>[0xFF, 0xFF, 0xFF, 0xFF]);
    expect(BaseType.float64.invalidBytes(), List<int>.filled(8, 0xFF));

    // Reading those bytes back gives a NaN, which isValid rejects.
    final reader = ByteReader(BaseType.float32.invalidBytes());
    expect(BaseType.float32.isValid(reader.readFloat32()), isFalse);
  });

  test('the z types reserve zero rather than their maximum', () {
    expect(BaseType.uint8z.invalidValue(), 0);
    expect(BaseType.uint16z.invalidValue(), 0);
    expect(BaseType.uint32z.invalidValue(), 0);
    expect(BaseType.uint64z.invalidValue(), 0);
    expect(BaseType.uint8z.isValid(0), isFalse);
    expect(BaseType.uint8z.isValid(255), isTrue);
  });

  test('correctRangeAndType boxes values as the type\'s Dart type', () {
    expect(BaseType.uint8.correctRangeAndType(3.7), 4);
    expect(BaseType.sint8.correctRangeAndType(-3.2), -3);
    expect(BaseType.float32.correctRangeAndType(1), 1.0);
    expect(BaseType.float64.correctRangeAndType(1), 1.0);
    expect(BaseType.string.correctRangeAndType(42), '42');
  });

  test('out-of-range values become the invalid sentinel', () {
    expect(BaseType.uint8.correctRangeAndType(256), 255);
    expect(BaseType.uint8.correctRangeAndType(-1), 255);
    expect(BaseType.sint8.correctRangeAndType(128), 127);
    expect(BaseType.uint16.correctRangeAndType(70000), 65535);
    expect(BaseType.uint8.correctRangeAndType(double.nan), 255);
    expect(BaseType.uint8.correctRangeAndType(double.infinity), 255);
  });

  test('64-bit values keep every bit', () {
    const big = 0x0123456789ABCDEF;
    expect(BaseType.sint64.correctRangeAndType(big), big);
    expect(BaseType.uint64.correctRangeAndType(-1), -1);
    // Not routed through a double, which has 53 bits of mantissa.
    expect(BaseType.sint64.correctRangeAndType(9007199254740993),
        9007199254740993);
  });

  test('float32 storage is narrowed to float32 precision', () {
    // So that what is stored is what a decode of the same file would have
    // produced, and a re-encode reproduces it exactly.
    final stored = BaseType.float32.correctRangeAndType(0.1) as double;
    final writer = ByteWriter()..writeFloat32(0.1);
    expect(stored, ByteReader(writer.toBytes()).readFloat32());
  });

  test('base types are classified for scaling and sign extension', () {
    expect(BaseType.fitEnum.isNumeric, isFalse);
    expect(BaseType.string.isNumeric, isFalse);
    expect(BaseType.uint8.isNumeric, isTrue);

    expect(BaseType.float32.isFloatingPoint, isTrue);
    expect(BaseType.float64.isFloatingPoint, isTrue);
    expect(BaseType.uint32.isFloatingPoint, isFalse);

    expect(BaseType.sint8.isSignedInteger, isTrue);
    expect(BaseType.sint16.isSignedInteger, isTrue);
    expect(BaseType.sint32.isSignedInteger, isTrue);
    expect(BaseType.sint64.isSignedInteger, isTrue);
    expect(BaseType.uint8.isSignedInteger, isFalse);
    expect(BaseType.float32.isSignedInteger, isFalse);
  });

  test('a boxed value maps back to the widest base type that holds it', () {
    // Dart has one integer type and one floating-point type, so this can only
    // answer with the widest of each; it is consulted only for a field the
    // profile does not declare.
    expect(BaseType.of('abc'), BaseType.string);
    expect(BaseType.of(true), BaseType.uint8);
    expect(BaseType.of(1.5), BaseType.float64);
    expect(BaseType.of(42), BaseType.sint64);
    expect(BaseType.of(null), isNull);
    expect(BaseType.of(DateTime.now()), isNull);
  });

  test('a string longer than a FIT field is not a valid value', () {
    expect(BaseType.string.isValid('a' * Fit.stringMaxByteCount), isTrue);
    expect(
        BaseType.string.isValid('a' * (Fit.stringMaxByteCount + 1)), isFalse);
    expect(BaseType.string.isValid(''), isFalse);
  });
}
