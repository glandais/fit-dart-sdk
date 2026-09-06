import 'package:flutter/material.dart';

/// The demo's palette, in both schemes, and the small set of colours the
/// painters read.
///
/// The same values the fit-kotlin-sdk demo uses, so the two pages look like one
/// family. No web font and no CDN: the page is a static artefact on GitHub
/// Pages and must work offline and behind a strict CSP.
class DemoColors extends ThemeExtension<DemoColors> {
  const DemoColors({
    required this.background,
    required this.panel,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.dangerBackground,
    required this.chart,
  });

  static const DemoColors light = DemoColors(
    background: Color(0xFFF6F7F9),
    panel: Color(0xFFFFFFFF),
    ink: Color(0xFF16191D),
    inkSoft: Color(0xFF5B6570),
    line: Color(0xFFE2E6EA),
    accent: Color(0xFF0B6BCB),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    dangerBackground: Color(0xFFFDECEA),
    chart: [
      Color(0xFF0B6BCB),
      Color(0xFF1F9D55),
      Color(0xFFC2410C),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
    ],
  );

  static const DemoColors dark = DemoColors(
    background: Color(0xFF0F1216),
    panel: Color(0xFF171B21),
    ink: Color(0xFFE8ECF1),
    inkSoft: Color(0xFF9AA4B0),
    line: Color(0xFF262C35),
    accent: Color(0xFF58A6FF),
    onAccent: Color(0xFF08111D),
    danger: Color(0xFFFF8A80),
    dangerBackground: Color(0xFF2A1614),
    chart: [
      Color(0xFF58A6FF),
      Color(0xFF3FB950),
      Color(0xFFFF8C42),
      Color(0xFFBC8CFF),
      Color(0xFF2DD4BF),
    ],
  );

  final Color background;
  final Color panel;
  final Color ink;
  final Color inkSoft;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color dangerBackground;

  /// One colour per chart series, in the order the series are found.
  final List<Color> chart;

  Color chartColor(int index) => chart[index % chart.length];

  static DemoColors of(BuildContext context) =>
      Theme.of(context).extension<DemoColors>()!;

  @override
  DemoColors copyWith() => this;

  @override
  DemoColors lerp(ThemeExtension<DemoColors>? other, double t) =>
      t < 0.5 ? this : (other as DemoColors? ?? this);
}

ThemeData demoTheme(Brightness brightness) {
  final colors =
      brightness == Brightness.dark ? DemoColors.dark : DemoColors.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
    ).copyWith(
      surface: colors.background,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      error: colors.danger,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: colors.background,
    dividerColor: colors.line,
    extensions: [colors],
    // System fonts throughout: nothing is downloaded at page load.
    textTheme: base.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
      fontFamilyFallback: const [
        'system-ui',
        'Segoe UI',
        'Roboto',
        'Helvetica',
        'Arial'
      ],
    ).copyWith(),
  );
}

/// Radius the panels, cards and pills share.
const BorderRadius panelRadius = BorderRadius.all(Radius.circular(12));
