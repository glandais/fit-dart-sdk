/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:typed_data';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

import 'test_fixtures.dart';

/// Decode → encode → decode over the real fixtures.
///
/// The decode is deliberately raw: component expansion off, unknown data kept,
/// heart rates unmerged. Each of those transforms the message stream, and what
/// is being checked here is that what came off the wire goes back onto it.
void main() {
  DecodeResult decodeRaw(Uint8List bytes) =>
      FitDecoder(bytes).decode(const DecodeOptions(
        expandComponents: false,
        includeUnknownData: true,
        mergeHeartRates: false,
      ));

  Uint8List reEncode(Uint8List original) {
    final result = decodeRaw(original);
    final header = FileHeader.read(ByteReader(original));
    final encoder = FitEncoder(
      protocolVersionByte: header.protocolVersionByte,
      profileVersion: header.profileVersion,
    );
    // No registerDeveloperField here: the developer_data_id and
    // field_description messages that declared those fields are themselves in
    // result.mesgs, and writing them back in place is what keeps the
    // declarations where the producer put them. Registering as well would
    // duplicate them.
    encoder.writeAll(result.mesgs);
    return encoder.close();
  }

  test('a file with gear change data re-encodes to identical bytes', () {
    // The strictest check available: same field order, same local message
    // numbers, same definition records, same header.
    expect(reEncode(TestFixtures.withGearChangeData),
        TestFixtures.withGearChangeData);
  });

  test('a recorded activity round-trips', () {
    final original = decodeRaw(TestFixtures.activity);
    final again = decodeRaw(reEncode(TestFixtures.activity));

    expect(again.errors, isEmpty);
    expect(again.mesgs.length, original.mesgs.length);
    for (var i = 0; i < original.mesgs.length; i++) {
      expect(again.mesgs[i], original.mesgs[i], reason: 'message $i');
    }
  });

  test('a file with developer fields round-trips them', () {
    final original = decodeRaw(TestFixtures.activityDevFields);
    final again = decodeRaw(reEncode(TestFixtures.activityDevFields));

    expect(again.errors, isEmpty);
    expect(again.messages.developerFieldDescriptions.length,
        original.messages.developerFieldDescriptions.length);

    final originalRecord = original.messages.recordMesgs.first;
    final againRecord = again.messages.recordMesgs.first;
    expect(againRecord.developerFieldList.length,
        originalRecord.developerFieldList.length);
    for (var i = 0; i < originalRecord.developerFieldList.length; i++) {
      expect(againRecord.developerFieldList[i].getValue(),
          originalRecord.developerFieldList[i].getValue());
    }
  });

  test('a file with heart rate messages round-trips', () {
    final original = decodeRaw(TestFixtures.hrmPluginTestActivity);
    final again = decodeRaw(reEncode(TestFixtures.hrmPluginTestActivity));

    expect(again.errors, isEmpty);
    expect(again.messages.hrMesgs.length, original.messages.hrMesgs.length);
    expect(again.mesgs.length, original.mesgs.length);
  });

  test('re-encoding stays within a few percent of the original size', () {
    for (final original in <Uint8List>[
      TestFixtures.activity,
      TestFixtures.activityDevFields,
      TestFixtures.withGearChangeData,
      TestFixtures.hrmPluginTestActivity,
    ]) {
      final again = reEncode(original);
      expect(again.length, lessThan((original.length * 1.05).round()));
    }
  });

  test('the header is reproduced when it is preserved', () {
    final original = FileHeader.read(ByteReader(TestFixtures.activity));
    final again = FileHeader.read(ByteReader(reEncode(TestFixtures.activity)));

    expect(again.protocolVersionByte, original.protocolVersionByte);
    expect(again.profileVersion, original.profileVersion);
    expect(again.headerSize, original.headerSize);
  });

  test('a re-encoded file passes its own integrity check', () {
    for (final original in <Uint8List>[
      TestFixtures.activity,
      TestFixtures.withGearChangeData,
      TestFixtures.hrMesgTestActivity,
    ]) {
      expect(FitDecoder(reEncode(original)).checkIntegrity(), isTrue);
    }
  });
}
