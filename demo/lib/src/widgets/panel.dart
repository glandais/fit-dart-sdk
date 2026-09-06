import 'package:flutter/material.dart';

import '../theme.dart';

/// The card every section of the page sits in.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? title;

  /// Controls that belong to this section: the series toggles, the point count.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border.all(color: colors.line),
        borderRadius: panelRadius,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) Flexible(child: trailing!),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// The rounded outline the profile version and the GitHub link share.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = DemoColors.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14,
                color: onTap == null ? colors.inkSoft : colors.accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: onTap == null ? colors.inkSoft : colors.accent,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}

/// Centred grey text, for a canvas with nothing to draw.
class PlaceholderText extends StatelessWidget {
  const PlaceholderText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: DemoColors.of(context).inkSoft),
        ),
      );
}
