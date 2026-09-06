import 'package:flutter/material.dart';

import '../decoded_file.dart';
import '../field_values.dart';
import '../theme.dart';

/// What the file says about itself, read through the typed accessors.
class SummaryCards extends StatelessWidget {
  const SummaryCards({super.key, required this.file});

  final DecodedFile file;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final card in _cardsOf(file))
          Container(
            constraints: const BoxConstraints(minWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: colors.panel,
              border: Border.all(color: colors.line),
              borderRadius: panelRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: colors.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card {
  const _Card(this.label, this.value);
  final String label;
  final String value;
}

List<_Card> _cardsOf(DecodedFile file) {
  final fileId = file.result.messages.fileIdMesgs.firstOrNull;
  final session = file.result.messages.sessionMesgs.firstOrNull;
  final cards = <_Card>[];

  // A zero is never interesting here: FIT writes 0 for "unset" in every field
  // this summarises — product id, ascent, calories — so a `PRODUCT 0` card
  // would be noise.
  void add(String label, Object? value) {
    if (value == null || value == 0 || value == '') return;
    cards.add(_Card(label, value is String ? value : formatValue(value)));
  }

  add('File type', fileId?.type?.name);
  add('Manufacturer', fileId?.manufacturer?.name);
  add('Product',
      fileId?.garminProduct?.name ?? fileId?.productName ?? fileId?.product);
  add('Created', fileId?.timeCreated);
  add('Sport', session?.sport?.name);
  add('Distance', _distance(session?.totalDistance));
  add('Moving time', _duration(session?.totalTimerTime));
  add('Ascent',
      session?.totalAscent == null ? null : '${session!.totalAscent} m');
  add('Avg HR',
      session?.avgHeartRate == null ? null : '${session!.avgHeartRate} bpm');
  add('Avg power', session?.avgPower == null ? null : '${session!.avgPower} W');
  add('Calories', session?.totalCalories);
  add('Messages', formatCount(file.result.mesgs.length));
  add('Message types', formatCount(file.byType.length));
  add('Decoded in', '${file.elapsed.inMilliseconds} ms');

  return cards;
}

String? _distance(double? metres) {
  if (metres == null) return null;
  return metres >= 1000
      ? '${(metres / 1000).toStringAsFixed(2)} km'
      : '${metres.round()} m';
}

String? _duration(double? seconds) {
  if (seconds == null) return null;
  final total = seconds.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final rest = total % 60;
  String pad(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${pad(minutes)}:${pad(rest)}'
      : '$minutes:${pad(rest)}';
}
