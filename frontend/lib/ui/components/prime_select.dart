// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A modern, compact desktop dropdown selector.
class PrimeSelect<T> extends StatefulWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final double height;
  final String? tooltip;

  const PrimeSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = 28.0,
    this.tooltip,
  });

  @override
  State<PrimeSelect<T>> createState() => _PrimeSelectState<T>();
}

class _PrimeSelectState<T> extends State<PrimeSelect<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = _isHovered
        ? PrimeTheme.textSecondary.withValues(alpha: 0.5)
        : PrimeTheme.borderSide;

    final Widget selectBox = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: PrimeTheme.searchBarBackground,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: widget.options.containsKey(widget.value) ? widget.value : null,
            isDense: true,
            isExpanded: true,
            dropdownColor: PrimeTheme.panelBackground,
            icon: Icon(Icons.arrow_drop_down, color: PrimeTheme.textSecondary, size: 16),
            style: TextStyle(
              fontSize: 12,
              color: PrimeTheme.textPrimary,
              fontFamily: 'Inter',
            ),
            borderRadius: BorderRadius.circular(6.0),
            items: widget.options.entries.map((entry) {
              final isSelected = entry.key == widget.value;
              return DropdownMenuItem<T>(
                value: entry.key,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? PrimeTheme.primaryAccent : PrimeTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check, size: 14, color: PrimeTheme.primaryAccent),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null || widget.options.containsKey(null)) {
                widget.onChanged(v as T);
              }
            },
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: selectBox);
    }
    return selectBox;
  }
}
