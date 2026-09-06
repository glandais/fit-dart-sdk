import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// What the decoder could not make sense of.
///
/// A panel rather than a dialog: `decode` never throws, so a problem is a note
/// about part of the file, not the end of it — everything read before is on the
/// page already.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.errors});

  final List<FitError> errors;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.dangerBackground,
        border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
        borderRadius: panelRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${errors.length} ${errors.length == 1 ? 'problem' : 'problems'} — '
            'everything decoded before it is still shown',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.danger),
          ),
          const SizedBox(height: 6),
          for (final error in errors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                error.bytePosition >= 0
                    ? '${error.message} (byte ${error.bytePosition})'
                    : error.message,
                style: TextStyle(fontSize: 13, color: colors.danger),
              ),
            ),
        ],
      ),
    );
  }
}
