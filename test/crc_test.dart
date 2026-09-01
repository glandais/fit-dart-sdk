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
  test('incremental update matches the file\'s recorded CRC', () {
    final crc = Crc();
    for (var i = 0; i < TestData.fitFileShort.length - 2; i++) {
      crc.updateByte(TestData.fitFileShort[i]);
    }
    expect(crc.value, TestData.fitFileShortCrc);
  });

  test('one-shot calculation matches the file\'s recorded CRC', () {
    expect(
      Crc.calculate(TestData.fitFileShort, 0, TestData.fitFileShort.length - 2),
      TestData.fitFileShortCrc,
    );
  });

  test('CRC of no bytes is zero', () {
    expect(Crc.calculate(TestData.bytes(const [])), 0);
    expect(Crc().value, 0);
  });

  test('reset returns the calculator to its initial state', () {
    final crc = Crc()..update(TestData.fitFileShort);
    crc.reset();
    expect(crc.value, 0);
  });

  test('range update checksums exactly the requested slice', () {
    final whole = Crc()..update(TestData.fitFileShort, 0, 14);
    expect(whole.value, Crc.calculate(TestData.fitFileShort, 0, 14));
  });
}
