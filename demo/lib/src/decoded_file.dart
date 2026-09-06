import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:flutter/foundation.dart';

import 'field_values.dart';

/// One decoded FIT file, plus everything the page draws from it.
///
/// Derived once here rather than in the widgets: the track and the series are a
/// pass over every record message, and rebuilding them on each frame of a
/// window resize would be felt.
class DecodedFile {
  DecodedFile._({
    required this.name,
    required this.bytes,
    required this.result,
    required this.elapsed,
    required this.byType,
    required this.track,
    required this.series,
  });

  /// Decodes [bytes], yielding to the event loop as it goes.
  ///
  /// `decodeAsync` rather than `decode`: a large activity is tens of thousands
  /// of messages, and the synchronous decode would hold the UI isolate long
  /// enough to drop frames. `Isolate.run` — the other way out — does not exist
  /// on the web, which is the platform this demo runs on.
  static Future<DecodedFile> decode(
    String name,
    Uint8List bytes, {
    bool includeUnknownData = false,
  }) async {
    final started = DateTime.now();
    final result = await FitDecoder(bytes).decodeAsync(
      options: DecodeOptions(includeUnknownData: includeUnknownData),
      // Larger than the default: on the web a yield costs a whole frame, and a
      // file this demo can decode in one go should not pay for eight of them.
      // Big enough to still break up an activity of tens of thousands of
      // messages, which is what the yielding is for.
      chunkSize: 4096,
    );
    final elapsed = DateTime.now().difference(started);

    return DecodedFile._(
      name: name,
      bytes: bytes,
      result: result,
      elapsed: elapsed,
      byType: _groupByType(result.mesgs),
      track: _trackOf(result),
      series: _seriesOf(result),
    );
  }

  final String name;
  final Uint8List bytes;
  final DecodeResult result;
  final Duration elapsed;

  /// Messages by profile name, the most numerous type first.
  final Map<String, List<Mesg>> byType;

  final List<TrackPoint> track;
  final List<Series> series;

  /// Messages by type, ordered by how many there are of each: the type list
  /// then opens on the type that says the most about the file.
  static Map<String, List<Mesg>> _groupByType(List<Mesg> mesgs) {
    final byType = <String, List<Mesg>>{};
    for (final mesg in mesgs) {
      byType.putIfAbsent(mesg.mesgName, () => <Mesg>[]).add(mesg);
    }
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Map.fromEntries(entries);
  }

  static List<TrackPoint> _trackOf(DecodeResult result) {
    final points = <TrackPoint>[];
    for (final record in result.messages.recordMesgs) {
      final lat = record.positionLat;
      final lon = record.positionLong;
      if (lat != null && lon != null) {
        points.add(TrackPoint(
          lon * _semicirclesToDegrees,
          lat * _semicirclesToDegrees,
        ));
      }
    }
    return points;
  }

  static List<Series> _seriesOf(DecodeResult result) {
    final records = result.messages.recordMesgs;
    final series = <Series>[];
    for (final spec in _seriesSpecs) {
      // The enhanced field where the file has one: it is the same quantity at a
      // wider range, and a file carrying both stores the truth in the enhanced
      // one.
      final field = spec.fieldNums.firstWhere(
        (fieldNum) =>
            records.any((mesg) => mesg.doubleFieldValue(fieldNum) != null),
        orElse: () => -1,
      );
      if (field < 0) continue;

      series.add(Series(
        label: spec.label,
        colorIndex: series.length,
        units: unitsOfField(MesgNum.record, field),
        values: [
          for (final mesg in records) mesg.doubleFieldValue(field),
        ],
        // Three lines is what fits on the chart before it reads as a tangle;
        // the rest are a click away.
        enabled: series.length < 3,
      ));
    }
    return series;
  }
}

const double _semicirclesToDegrees = 180 / 2147483648;

@immutable
class TrackPoint {
  const TrackPoint(this.lon, this.lat);
  final double lon;
  final double lat;
}

/// One line on the chart: a record field over the file, with its own range.
class Series {
  Series({
    required this.label,
    required this.colorIndex,
    required this.units,
    required this.values,
    required this.enabled,
  });

  final String label;
  final int colorIndex;
  final String units;

  /// One entry per record message, null where that record had no such field.
  final List<double?> values;

  bool enabled;

  double get min => values.whereType<double>().reduce((a, b) => a < b ? a : b);
  double get max => values.whereType<double>().reduce((a, b) => a > b ? a : b);
}

class _SeriesSpec {
  const _SeriesSpec(this.label, this.fieldNums);
  final String label;
  final List<int> fieldNums;
}

const List<_SeriesSpec> _seriesSpecs = [
  _SeriesSpec('Altitude', [
    RecordMesg.enhancedAltitudeFieldNum,
    RecordMesg.altitudeFieldNum,
  ]),
  _SeriesSpec('Speed', [
    RecordMesg.enhancedSpeedFieldNum,
    RecordMesg.speedFieldNum,
  ]),
  _SeriesSpec('Heart rate', [RecordMesg.heartRateFieldNum]),
  _SeriesSpec('Cadence', [RecordMesg.cadenceFieldNum]),
  _SeriesSpec('Power', [RecordMesg.powerFieldNum]),
];
