// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A standard two-column desktop inspector property row.
class PropertyRow extends StatelessWidget {
  final String label;
  final Widget child;
  final String? tooltip;
  final double labelWidth;
  final EdgeInsetsGeometry padding;

  const PropertyRow({
    super.key,
    required this.label,
    required this.child,
    this.tooltip,
    this.labelWidth = 105.0,
    this.padding = const EdgeInsets.symmetric(vertical: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    Widget labelWidget = SizedBox(
      width: labelWidth,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: PrimeTheme.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (tooltip != null) {
      labelWidget = Tooltip(message: tooltip!, child: labelWidget);
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          labelWidget,
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
