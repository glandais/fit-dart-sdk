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
  test('a single field accumulates each value', () {
    final accumulator = Accumulator()..create(0, 0, 0);

    expect(accumulator.accumulate(0, 0, 1, 8), 1);
    expect(accumulator.accumulate(0, 0, 2, 8), 2);
    expect(accumulator.accumulate(0, 0, 4, 8), 4);
    expect(accumulator.accumulate(0, 0, 5, 8), 5);
  });

  test('fields accumulate independently of each other', () {
    final accumulator = Accumulator()..create(0, 0, 250);
    expect(accumulator.accumulate(0, 0, 254, 8), 254);

    accumulator.create(1, 1, 0);
    expect(accumulator.accumulate(1, 1, 2, 8), 2);

    // Interleaving the other field did not disturb this one's running total.
    expect(accumulator.accumulate(0, 0, 0, 8), 256);
  });

  test('counter rollover keeps the running total monotonic', () {
    final accumulator = Accumulator()..create(0, 0, 0);

    expect(accumulator.accumulate(0, 0, 254, 8), 254);
    expect(accumulator.accumulate(0, 0, 255, 8), 255);
    // The 8-bit counter wrapped to 0; the accumulated value must not.
    expect(accumulator.accumulate(0, 0, 0, 8), 256);
    expect(accumulator.accumulate(0, 0, 3, 8), 259);
  });

  test('accumulating an unseen field seeds it from its first sample', () {
    // FIT counters are relative, so treating the first one as a delta from zero
    // would invent distance that was never travelled.
    final accumulator = Accumulator();
    expect(accumulator.accumulate(20, 5, 100, 16), 100);
    expect(accumulator.accumulate(20, 5, 110, 16), 110);
  });

  test('the accumulator itself is sentinel-agnostic', () {
    // Recognising the all-ones invalid pattern is the expansion layer's job —
    // Mesg never feeds a sentinel in, which the decode-level test below pins
    // down.
    final accumulator = Accumulator()..create(0, 0, 100);
    const bits = 8;
    const allOnes = (1 << bits) - 1;
    expect(accumulator.accumulate(0, 0, allOnes, bits), 255);
    expect(accumulator.accumulate(0, 0, 10, bits), 266);
  });

  test('an invalid accumulated component does not corrupt the running total',
      () {
    // An all-ones accumulated component carries no sample: it must neither reach
    // the destination field as a value nor feed the running total, so the next
    // real sample's delta is computed against the last real one.
    //
    // This is a deliberate divergence from fit-python-sdk, whose
    // _expand_components folds the sentinel into the accumulator before testing
    // invalidity — there, the record after the invalid one inherits a total
    // corrupted by the sentinel.
    //
    // record.compressed_speed_distance is the natural case: a 3-byte field
    // packing 12 bits of speed and 12 accumulated bits of distance, where the
    // distance bits can be all-ones while the field as a whole stays valid.
    List<int> compressed(int speedRaw, int distanceRaw) => <int>[
          speedRaw & 0xFF,
          ((speedRaw >> 8) & 0x0F) | ((distanceRaw & 0x0F) << 4),
          (distanceRaw >> 4) & 0xFF,
        ];

    final body = ByteWriter()
      // Definition, local 0: record (20), one field: compressed_speed_distance
      // (8), 3 bytes of BYTE.
      ..writeByte(0x40)
      ..writeByte(0)
      ..writeByte(Endianness.little.value)
      ..writeUint16(20)
      ..writeByte(1)
      ..writeByte(8)
      ..writeByte(3)
      ..writeByte(BaseType.byte.id);
    // Distance raw is in 1/16 m: 16 = 1 m, then the sentinel, then 32 = 2 m.
    for (final distanceRaw in const [16, 0xFFF, 32]) {
      body.writeByte(0);
      body.writeBytes(compressed(0, distanceRaw));
    }

    final result = FitDecoder(TestData.fileOf(body.toBytes())).decode();
    expect(result.errors, isEmpty);

    // 1 m, no sample, then 2 m — not the 255.94 m and 258 m that accumulating
    // the sentinel would produce.
    expect(
      result.messages.recordMesgs.map((m) => m.distance).toList(),
      <double?>[1.0, null, 2.0],
    );
  });
}
