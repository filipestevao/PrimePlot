// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'prime_text_field.dart';

/// A desktop text field featuring an integrated, glowing LaTeX formatting badge.
class LatexTextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool useLatex;
  final VoidCallback onLatexToggle;
  final int? maxLines;
  final String? tooltip;
  final bool showLabelAbove;

  const LatexTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.useLatex,
    required this.onLatexToggle,
    this.maxLines = 1,
    this.tooltip,
    this.showLabelAbove = false,
  });

  @override
  Widget build(BuildContext context) {
    final suffixBadge = Tooltip(
      message: useLatex ? 'LaTeX enabled (click to disable)' : 'Click to enable LaTeX formatting',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onLatexToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: useLatex ? PrimeTheme.primaryAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: useLatex
                    ? PrimeTheme.primaryAccent
                    : PrimeTheme.textSecondary.withValues(alpha: 0.4),
                width: 1.0,
              ),
              boxShadow: useLatex
                  ? [
                      BoxShadow(
                        color: PrimeTheme.primaryAccent.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              r'$',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: useLatex ? Colors.white : PrimeTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );

    final inputField = PrimeTextField(
      value: value,
      onChanged: onChanged,
      maxLines: maxLines,
      suffix: suffixBadge,
      hintText: useLatex ? r'e.g. \alpha + \beta_0' : 'Enter text...',
    );

    if (showLabelAbove) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: PrimeTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          inputField,
        ],
      );
    }

    return inputField;
  }
}
