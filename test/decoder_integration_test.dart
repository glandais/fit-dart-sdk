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

void main() {
  test('a recorded activity decodes without errors', () {
    final result = FitDecoder(TestFixtures.activity).decode();

    expect(result.errors, isEmpty);
    expect(result.mesgs, hasLength(3611));
    expect(result.messages.recordMesgs, hasLength(3601));
    expect(result.messages.fileIdMesgs, hasLength(1));
    expect(result.messages.sessionMesgs, hasLength(1));
  });

  test('integrity and detection agree on a real file', () {
    final decoder = FitDecoder(TestFixtures.activity);
    expect(decoder.isFit(), isTrue);
    expect(decoder.checkIntegrity(), isTrue);
  });

  test('sessions carry their sport and totals', () {
    final session =
        FitDecoder(TestFixtures.activity).decode().messages.sessionMesgs.single;
    expect(session.sport, isNotNull);
    expect(session.totalElapsedTime, greaterThan(0));
    expect(session.startTime, isNotNull);
  });

  test('records carry timestamps in file order', () {
    final records =
        FitDecoder(TestFixtures.activity).decode().messages.recordMesgs;
    final timestamps = records.map((r) => r.timestamp).toList();
    expect(timestamps.every((t) => t != null), isTrue);
    for (var i = 1; i < timestamps.length; i++) {
      expect(timestamps[i]!.isBefore(timestamps[i - 1]!), isFalse);
    }
  });

  test('scaled fields decode into their units', () {
    final record = FitDecoder(TestFixtures.withGearChangeData)
        .decode()
        .messages
        .recordMesgs
        .first;
    // altitude is stored as uint16 scaled by 5 with an offset of 500.
    expect(record.altitude, closeTo(1028.8, 0.001));
  });

  test('the streaming API sees the same messages as the result API', () {
    final eager = FitDecoder(TestFixtures.activity)
        .decode(const DecodeOptions(mergeHeartRates: false));
    final lazy = FitDecoder(TestFixtures.activity).asIterable().toList();
    expect(lazy.length, eager.mesgs.length);
    expect(
        lazy.whereType<RecordMesg>().length, eager.messages.recordMesgs.length);
  });

  test('the stream API sees the same messages', () async {
    final streamed = await FitDecoder(TestFixtures.activity).stream().length;
    expect(streamed, 3611);
  });

  test('decodeAsync matches decode on a real file', () async {
    final sync = FitDecoder(TestFixtures.activity).decode();
    final async = await FitDecoder(TestFixtures.activity).decodeAsync();
    expect(async.mesgs.length, sync.mesgs.length);
    expect(async.messages.recordMesgs.length, sync.messages.recordMesgs.length);
  });

  test('developer fields are declared and read back', () {
    final result = FitDecoder(TestFixtures.activity).decode();

    expect(result.messages.developerFieldDescriptions, hasLength(2));
    final names = result.messages.developerFieldDescriptions
        .map((d) => d.fieldName)
        .toList();
    expect(names, contains('Doughnuts Earned'));
    expect(names, contains('Heart Rate'));

    final record = result.messages.recordMesgs.first;
    expect(record.developerFieldList, isNotEmpty);
    expect(record.developerFieldList.first.getValue(), isNotNull);
  });

  test('a developer field keeps the declaring application\'s identity', () {
    final result = FitDecoder(TestFixtures.activity).decode();
    final description = result.messages.developerFieldDescriptions.first;
    expect(description.applicationId, hasLength(16));
    expect(description.developerDataIndex, 0);

    final field = result.messages.recordMesgs.first.developerFieldList.first;
    expect(field.key.applicationId, description.applicationId);
  });

  test('subfields resolve against their reference field', () {
    final events = FitDecoder(TestFixtures.withGearChangeData)
        .decode()
        .messages
        .eventMesgs;

    final gearChanges =
        events.where((e) => e.event == Event.rearGearChange).toList();
    expect(gearChanges, isNotEmpty);
    for (final event in gearChanges) {
      expect(event.gearChangeData, isNotNull);
      expect(event.rearGearNum, isNotNull);
    }

    // A timer event's data field means something else entirely.
    final timers = events.where((e) => e.event == Event.timer).toList();
    expect(timers, isNotEmpty);
    expect(timers.first.gearChangeData, isNull);
  });

  test('heart rates are merged into records by default', () {
    final merged = FitDecoder(TestFixtures.hrmPluginTestActivity).decode();
    final unmerged = FitDecoder(TestFixtures.hrmPluginTestActivity)
        .decode(const DecodeOptions(mergeHeartRates: false));

    expect(merged.messages.hrMesgs, isNotEmpty);

    final mergedWithHr =
        merged.messages.recordMesgs.where((r) => r.heartRate != null).length;
    final unmergedWithHr =
        unmerged.messages.recordMesgs.where((r) => r.heartRate != null).length;
    expect(mergedWithHr, greaterThan(unmergedWithHr));
  });

  test('component expansion can be turned off', () {
    final expanded = FitDecoder(TestFixtures.activity).decode();
    final raw = FitDecoder(TestFixtures.activity)
        .decode(const DecodeOptions(expandComponents: false));

    final expandedFields = expanded.messages.recordMesgs.first.fieldList.length;
    final rawFields = raw.messages.recordMesgs.first.fieldList.length;
    expect(expandedFields, greaterThanOrEqualTo(rawFields));
  });

  test('unknown messages are dropped unless asked for', () {
    final without = FitDecoder(TestFixtures.activityDevFields).decode();
    final with_ = FitDecoder(TestFixtures.activityDevFields)
        .decode(const DecodeOptions(includeUnknownData: true));

    expect(without.messages.unknownMesgs, isEmpty);
    expect(with_.mesgs.length, greaterThanOrEqualTo(without.mesgs.length));
  });

  test('every fixture decodes cleanly', () {
    for (final bytes in <Uint8List>[
      TestFixtures.activity,
      TestFixtures.activityDevFields,
      TestFixtures.withGearChangeData,
      TestFixtures.hrmPluginTestActivity,
      TestFixtures.hrMesgTestActivity,
    ]) {
      final result = FitDecoder(bytes).decode();
      expect(result.errors, isEmpty);
      expect(result.mesgs, isNotEmpty);
    }
  });
}
