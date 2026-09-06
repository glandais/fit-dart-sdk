import 'dart:math' as math;

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:flutter/material.dart';

import '../field_values.dart';
import '../theme.dart';

/// Every decoded message, by type, exactly as the file stored it.
///
/// Generic on purpose: this is the untyped [Mesg] view the SDK is built on, so
/// a message the demo has never heard of renders like any other.
class MessageTable extends StatelessWidget {
  const MessageTable({
    super.key,
    required this.byType,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, List<Mesg>> byType;
  final String selected;
  final ValueChanged<String> onSelect;

  /// Past this the table is a data dump rather than a view of the file, and the
  /// JSON download is the better answer.
  static const int maxRows = 500;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 460,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final table = _Table(
            name: selected,
            mesgs: byType[selected] ?? const [],
          );
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                    height: 44,
                    child: _TypeList(
                        byType: byType,
                        selected: selected,
                        onSelect: onSelect,
                        horizontal: true)),
                const SizedBox(height: 12),
                Expanded(child: table),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 200,
                child: _TypeList(
                    byType: byType,
                    selected: selected,
                    onSelect: onSelect,
                    horizontal: false),
              ),
              const SizedBox(width: 16),
              Expanded(child: table),
            ],
          );
        },
      ),
    );
  }
}

class _TypeList extends StatelessWidget {
  const _TypeList({
    required this.byType,
    required this.selected,
    required this.onSelect,
    required this.horizontal,
  });

  final Map<String, List<Mesg>> byType;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    final names = byType.keys.toList();

    Widget entry(String name) {
      final on = name == selected;
      return Padding(
        padding: horizontal
            ? const EdgeInsets.only(right: 6)
            : const EdgeInsets.only(bottom: 4, right: 4),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onSelect(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: on ? colors.accent.withValues(alpha: 0.12) : null,
                border: Border.all(color: on ? colors.accent : colors.line),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Row(
                mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: on ? colors.accent : colors.ink,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCount(byType[name]!.length),
                    style: TextStyle(fontSize: 12, color: colors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (horizontal) {
      return ListView(
        scrollDirection: Axis.horizontal,
        children: [for (final name in names) entry(name)],
      );
    }
    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (context, index) => entry(names[index]),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.name, required this.mesgs});

  final String name;
  final List<Mesg> mesgs;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    final rows = mesgs.take(MessageTable.maxRows).toList();

    // Column order follows first appearance, which is the producer's field
    // order — the order the bytes are in.
    final columns = <String, _Column>{};
    for (final mesg in mesgs) {
      for (final field in fieldValuesOf(mesg)) {
        columns.putIfAbsent(
          field.developer ? '${field.name} *' : field.name,
          () => _Column(
            label: field.developer ? '${field.name} *' : field.name,
            units: field.units,
          ),
        );
      }
    }

    // Only the rows on screen are measured and rendered; the columns come from
    // every message, so a field that appears once still gets a column.
    final cells = [
      for (final mesg in rows)
        {
          for (final field in fieldValuesOf(mesg))
            (field.developer ? '${field.name} *' : field.name):
                formatValue(field.value),
        },
    ];

    for (final column in columns.values) {
      var widest = column.label.length + column.units.length;
      for (final row in cells) {
        widest = math.max(widest, (row[column.label] ?? '').length);
      }
      column.width = (widest * 7.4 + 24).clamp(72.0, 240.0);
    }

    final width = 56 +
        columns.values.fold<double>(0, (sum, column) => sum + column.width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatCount(mesgs.length)} × $name, ${columns.length} fields'
          '${rows.length < mesgs.length ? ' — showing the first ${MessageTable.maxRows}' : ''}'
          '${columns.keys.any((key) => key.endsWith(' *')) ? ' (* developer field)' : ''}',
          style: TextStyle(fontSize: 12.5, color: colors.inkSoft),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.line),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    Container(
                      color: colors.background,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          _cell('#', 56, colors.inkSoft,
                              alignRight: true, bold: true),
                          for (final column in columns.values)
                            SizedBox(
                              width: column.width,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text.rich(
                                  TextSpan(
                                    text: column.label,
                                    children: column.units.isEmpty
                                        ? null
                                        : [
                                            TextSpan(
                                              text: '  ${column.units}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                color: colors.inkSoft,
                                              ),
                                            ),
                                          ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.line),
                    Expanded(
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemExtent: 28,
                        itemBuilder: (context, index) {
                          final row = cells[index];
                          return Container(
                            color: index.isOdd
                                ? colors.background.withValues(alpha: 0.5)
                                : null,
                            child: Row(
                              children: [
                                _cell(
                                  '${rows[index].decoderMesgIndex}',
                                  56,
                                  colors.inkSoft,
                                  alignRight: true,
                                ),
                                for (final column in columns.values)
                                  _cell(row[column.label] ?? '', column.width,
                                      colors.ink),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(
    String text,
    double width,
    Color color, {
    bool alignRight = false,
    bool bold = false,
  }) =>
      SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment:
                alignRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      );
}

class _Column {
  _Column({required this.label, required this.units});
  final String label;
  final String units;
  double width = 100;
}
