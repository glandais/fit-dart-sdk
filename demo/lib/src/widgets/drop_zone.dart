import 'package:flutter/material.dart';

import '../theme.dart';

/// The landing target: drop a file on it, or use either button.
class DropZone extends StatelessWidget {
  const DropZone({
    super.key,
    required this.dragging,
    required this.busy,
    required this.status,
    required this.statusIsError,
    required this.onChoose,
    required this.onSample,
  });

  final bool dragging;
  final bool busy;
  final String status;
  final bool statusIsError;
  final VoidCallback onChoose;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: dragging ? colors.accent.withValues(alpha: 0.06) : colors.panel,
        border: Border.all(
          color: dragging ? colors.accent : colors.line,
          width: dragging ? 2 : 1,
          style: BorderStyle.solid,
        ),
        borderRadius: panelRadius,
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Drop a '),
                TextSpan(
                  text: '.fit',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, color: colors.ink),
                ),
                const TextSpan(text: ' file here'),
              ],
            ),
            style: TextStyle(fontSize: 17, color: colors.ink),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: busy ? null : onChoose,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
                child: const Text('Choose a file'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onSample,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.line),
                ),
                child: const Text('Sample activity'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.inkSoft),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: statusIsError ? colors.danger : colors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
