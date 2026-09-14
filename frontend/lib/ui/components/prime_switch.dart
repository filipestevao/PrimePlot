// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A compact, desktop-oriented toggle switch designed for high-density inspectors.
class PrimeSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;

  const PrimeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  @override
  State<PrimeSwitch> createState() => _PrimeSwitchState();
}

class _PrimeSwitchState extends State<PrimeSwitch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const double width = 34.0;
    const double height = 18.0;
    const double thumbSize = 14.0;
    const double padding = 2.0;

    final Color activeColor = PrimeTheme.primaryAccent;
    final Color inactiveTrack = PrimeTheme.borderSide;
    final Color hoveredBorder = PrimeTheme.primaryAccent.withValues(alpha: 0.5);

    final Widget switchWidget = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: widget.value ? activeColor : inactiveTrack,
            border: Border.all(
              color: _isHovered
                  ? (widget.value ? Colors.white.withValues(alpha: 0.4) : hoveredBorder)
                  : (widget.value ? activeColor : PrimeTheme.borderSide),
              width: 1.0,
            ),
            boxShadow: widget.value && _isHovered
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: thumbSize,
              height: thumbSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: switchWidget);
    }
    return switchWidget;
  }
}
