import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../decoded_file.dart';
import '../field_values.dart';
import '../theme.dart';
import 'panel.dart';

/// Record fields over the file, one line each.
///
/// Every series is scaled to its own range: they share an X axis — the record
/// index — and never a Y one, because heart rate and altitude have nothing
/// comparable about them.
class SeriesChart extends StatelessWidget {
  const SeriesChart({super.key, required this.series});

  final List<Series> series;

  @override
  Widget build(BuildContext context) {
    final active = series.where((item) => item.enabled).toList();
    if (active.isEmpty) {
      return PlaceholderText(
        series.isEmpty
            ? 'No record messages in this file'
            : 'Pick a series above',
      );
    }
    return CustomPaint(
      painter: _ChartPainter(active, DemoColors.of(context)),
      size: Size.infinite,
    );
  }
}

/// One button per available series, coloured when it is on the chart.
class SeriesToggles extends StatelessWidget {
  const SeriesToggles(
      {super.key, required this.series, required this.onChanged});

  final List<Series> series;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        for (final item in series)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                item.enabled = !item.enabled;
                onChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: item.enabled
                        ? colors.chartColor(item.colorIndex)
                        : colors.line,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.enabled
                            ? colors.chartColor(item.colorIndex)
                            : colors.inkSoft.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: item.enabled
                            ? colors.chartColor(item.colorIndex)
                            : colors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.series, this.colors);

  final List<Series> series;
  final DemoColors colors;

  static const EdgeInsets _pad = EdgeInsets.fromLTRB(12, 12, 12, 22);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Size(
      size.width - _pad.horizontal,
      size.height - _pad.vertical,
    );

    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (var line = 0; line <= 4; line++) {
      final y = _pad.top + plot.height * line / 4;
      canvas.drawLine(
          Offset(_pad.left, y), Offset(_pad.left + plot.width, y), grid);
    }

    for (final item in series) {
      final min = item.min;
      final span = math.max(item.max - min, 1e-9);

      final path = Path();
      var drawing = false;
      for (var i = 0; i < item.values.length; i++) {
        final value = item.values[i];
        if (value == null) {
          // A gap in the data is a gap in the line, not a straight segment
          // across it.
          drawing = false;
          continue;
        }
        final x =
            _pad.left + plot.width * i / math.max(item.values.length - 1, 1);
        final y = _pad.top + plot.height - (value - min) / span * plot.height;
        if (drawing) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          drawing = true;
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = colors.chartColor(item.colorIndex),
      );
    }

    // The legend goes over the plot on a panel-coloured strip: the lines run the
    // full width, so anywhere else costs the chart room it needs. After every
    // line, so that no series is drawn through another's label.
    for (var index = 0; index < series.length; index++) {
      final item = series[index];
      final label =
          '${item.label}: ${formatNumber(item.min)}–${formatNumber(item.max)}'
          '${item.units.isEmpty ? '' : ' ${item.units}'}';
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: 11, color: colors.chartColor(item.colorIndex)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final origin = Offset(_pad.left + 6, _pad.top + 3 + 16.0 * index);
      canvas.drawRect(
        Rect.fromLTWH(origin.dx - 4, origin.dy - 2, painter.width + 8,
            painter.height + 3),
        Paint()..color = colors.panel.withValues(alpha: 0.88),
      );
      painter.paint(canvas, origin);
    }

    _axisLabel(canvas, 'record 0', Offset(_pad.left, size.height - 14), false);
    _axisLabel(
      canvas,
      'record ${formatCount(series.first.values.length - 1)}',
      Offset(_pad.left + plot.width, size.height - 14),
      true,
    );
  }

  void _axisLabel(Canvas canvas, String text, Offset at, bool alignRight) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(fontSize: 11, color: colors.inkSoft)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, alignRight ? at.translate(-painter.width, 0) : at);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
