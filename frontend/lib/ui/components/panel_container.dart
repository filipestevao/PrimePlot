import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PanelContainer extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final List<Widget>? actions;

  const PanelContainer({
    super.key,
    required this.title,
    this.icon,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4.0), // Space around the panel to show the background
      decoration: BoxDecoration(
        color: PrimeTheme.panelBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: PrimeTheme.borderSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Header
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: const BoxDecoration(
              color: PrimeTheme.tabBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7.0)),
              border: Border(bottom: BorderSide(color: PrimeTheme.borderSide)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: PrimeTheme.textSecondary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PrimeTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (actions != null) ...actions!,
                if (actions == null) ...[
                  const Icon(Icons.more_horiz, size: 16, color: PrimeTheme.textSecondary),
                  const SizedBox(width: 8),
                  const Icon(Icons.close, size: 14, color: PrimeTheme.textSecondary),
                ],
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7.0)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
