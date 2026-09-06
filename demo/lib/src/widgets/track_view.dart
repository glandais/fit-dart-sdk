import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../decoded_file.dart';
import '../theme.dart';
import 'panel.dart';

/// The GPS track, drawn flat.
///
/// No map tiles: the page fetches nothing, which is the point of the demo, and
/// the shape of a ride is legible without one.
class TrackView extends StatelessWidget {
  const TrackView({super.key, required this.points});

  final List<TrackPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const PlaceholderText('No GPS positions in this file');
    }
    return CustomPaint(
      painter: _TrackPainter(points, DemoColors.of(context)),
      size: Size.infinite,
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.points, this.colors);

  final List<TrackPoint> points;
  final DemoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    var minLon = points.first.lon, maxLon = points.first.lon;
    var minLat = points.first.lat, maxLat = points.first.lat;
    for (final point in points) {
      minLon = math.min(minLon, point.lon);
      maxLon = math.max(maxLon, point.lon);
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
    }

    // A degree of longitude shrinks with latitude; without this the track comes
    // out stretched sideways everywhere but the equator.
    final midLat = ((minLat + maxLat) / 2) * math.pi / 180;
    final spanX = math.max((maxLon - minLon) * math.cos(midLat), 1e-9);
    final spanY = math.max(maxLat - minLat, 1e-9);

    const pad = 16.0;
    final scale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    Offset at(TrackPoint point) => Offset(
          offsetX + (point.lon - minLon) * math.cos(midLat) * scale,
          size.height - (offsetY + (point.lat - minLat) * scale),
        );

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = at(point);
      path.lineTo(offset.dx, offset.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = colors.chartColor(0),
    );

    canvas.drawCircle(
        at(points.first), 4, Paint()..color = colors.chartColor(1));
    canvas.drawCircle(
        at(points.last), 4, Paint()..color = colors.chartColor(2));
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.points != points || old.colors != colors;
}
