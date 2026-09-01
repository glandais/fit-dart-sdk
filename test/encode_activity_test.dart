/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:typed_data';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

/// Builds and decodes back a complete activity file, the way the Cookbook's
/// "Encode Activity" recipe does: file_id, then a start event, a run of records,
/// a stop event, a lap, a session and an activity summary.
void main() {
  final start = DateTime.utc(2024, 3, 17, 8, 0, 0);
  const recordCount = 300;

  Uint8List buildActivity() => encodeFit((encoder) {
        encoder.write(FileIdMesg()
          ..type = FitFile.activity
          ..manufacturer = Manufacturer.development
          ..product = 0
          ..serialNumber = 1234
          ..timeCreated = start);

        encoder.write(DeviceInfoMesg()
          ..deviceIndex = DeviceIndexValues.creator
          ..manufacturer = Manufacturer.development
          ..serialNumber = 1234
          ..softwareVersion = 1.0
          ..timestamp = start);

        encoder.write(EventMesg()
          ..timestamp = start
          ..event = Event.timer
          ..eventType = EventType.start);

        for (var i = 0; i < recordCount; i++) {
          encoder.write(RecordMesg()
            ..timestamp = start.add(Duration(seconds: i))
            ..distance = i * 3.0
            ..speed = 3.0
            ..heartRate = 120 + (i % 40)
            ..cadence = 80 + (i % 10));
        }

        final end = start.add(const Duration(seconds: recordCount));

        encoder.write(EventMesg()
          ..timestamp = end
          ..event = Event.timer
          ..eventType = EventType.stop);

        encoder.write(LapMesg()
          ..timestamp = end
          ..startTime = start
          ..totalElapsedTime = recordCount.toDouble()
          ..totalTimerTime = recordCount.toDouble()
          ..totalDistance = recordCount * 3.0
          ..messageIndex = 0
          ..event = Event.lap
          ..eventType = EventType.stop);

        encoder.write(SessionMesg()
          ..timestamp = end
          ..startTime = start
          ..totalElapsedTime = recordCount.toDouble()
          ..totalTimerTime = recordCount.toDouble()
          ..totalDistance = recordCount * 3.0
          ..messageIndex = 0
          ..firstLapIndex = 0
          ..numLaps = 1
          ..sport = Sport.running
          ..subSport = SubSport.generic
          ..event = Event.session
          ..eventType = EventType.stop);

        encoder.write(ActivityMesg()
          ..timestamp = end
          ..numSessions = 1
          ..localTimestamp = end
          ..totalTimerTime = recordCount.toDouble()
          ..type = Activity.manual
          ..event = Event.activity
          ..eventType = EventType.stop);
      });

  test('an encoded activity decodes back to what was written', () {
    final result = FitDecoder(buildActivity()).decode();

    expect(result.errors, isEmpty);
    expect(result.messages.fileIdMesgs.single.type, FitFile.activity);
    expect(result.messages.recordMesgs, hasLength(recordCount));
    expect(result.messages.lapMesgs, hasLength(1));
    expect(result.messages.sessionMesgs, hasLength(1));
    expect(result.messages.activityMesgs, hasLength(1));
    expect(result.messages.eventMesgs, hasLength(2));

    final session = result.messages.sessionMesgs.single;
    expect(session.sport, Sport.running);
    expect(session.totalDistance, recordCount * 3.0);
    expect(session.totalElapsedTime, recordCount.toDouble());
    expect(session.startTime, start);
  });

  test('records keep their values and order', () {
    final records = FitDecoder(buildActivity()).decode().messages.recordMesgs;

    for (var i = 0; i < recordCount; i++) {
      expect(records[i].timestamp, start.add(Duration(seconds: i)));
      expect(records[i].distance, i * 3.0);
      expect(records[i].heartRate, 120 + (i % 40));
      expect(records[i].cadence, 80 + (i % 10));
      expect(records[i].speed, 3.0);
    }
  });

  test('the encoded file is self-consistent', () {
    final bytes = buildActivity();
    final decoder = FitDecoder(bytes);
    expect(decoder.isFit(), isTrue);
    expect(decoder.checkIntegrity(), isTrue);

    final header = FileHeader.read(ByteReader(bytes));
    expect(header.dataSize, bytes.length - Fit.headerWithCrcSize - Fit.crcSize);
    expect(header.profileVersion, Fit.profileVersion);
  });

  test('re-encoding the decoded activity produces the same bytes', () {
    final original = buildActivity();
    final result = FitDecoder(original).decode(const DecodeOptions(
      expandComponents: false,
      includeUnknownData: true,
      mergeHeartRates: false,
    ));
    final again = encodeFit((e) => e.writeAll(result.mesgs));
    expect(again, original);
  });
}
