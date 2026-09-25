// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'prime_text_field.dart';

/// A desktop numeric input field supporting optional "Auto" state and step nudging.
class PrimeNumberField extends StatefulWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? prefixText;
  final String autoLabel;
  final bool allowAuto;
  final bool showStepper;
  final double step;
  final double? min;
  final double? max;
  final int precision;

  /// Explicit reset target (e.g. a domain default). Takes precedence over
  /// the Auto reset; the button hides while the value already equals it.
  final double? resetValue;

  const PrimeNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.prefixText,
    this.autoLabel = 'Auto',
    this.allowAuto = false,
    this.showStepper = true,
    this.step = 0.5,
    this.min,
    this.max,
    this.precision = 2,
    this.resetValue,
  });

  @override
  State<PrimeNumberField> createState() => _PrimeNumberFieldState();
}

class _PrimeNumberFieldState extends State<PrimeNumberField> {
  static String _format(double? v, int precision) {
    if (v == null) return '';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(precision).replaceAll(RegExp(r'\.?0+$'), '');
  }

  void _onTextSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || (widget.allowAuto && trimmed.toLowerCase() == widget.autoLabel.toLowerCase())) {
      if (widget.allowAuto) {
        widget.onChanged(null);
      } else {
        widget.onChanged(widget.min ?? 0.0);
      }
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed != null) {
      var clamped = parsed;
      if (widget.min != null && clamped < widget.min!) clamped = widget.min!;
      if (widget.max != null && clamped > widget.max!) clamped = widget.max!;
      widget.onChanged(clamped);
    } else {
      // Revert
      widget.onChanged(widget.value);
    }
  }

  void _nudge(double delta) {
    final current = widget.value ?? 0.0;
    var next = current + delta;
    if (widget.min != null && next < widget.min!) next = widget.min!;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = widget.allowAuto && widget.value == null;

    final suffixWidgets = <Widget>[];

    // Reset button: explicit default wins; otherwise Auto when allowed.
    // Hidden while the value already equals the reset target.
    final double? resetTarget;
    final String resetTip;
    if (widget.resetValue != null) {
      resetTarget = widget.resetValue;
      resetTip = 'Reset to default';
    } else if (widget.allowAuto) {
      resetTarget = null;
      resetTip = 'Reset to ${widget.autoLabel}';
    } else {
      resetTarget = null;
      resetTip = '';
    }
    final showReset =
        (widget.resetValue != null || widget.allowAuto) &&
        widget.value != resetTarget;
    if (showReset) {
      suffixWidgets.add(
        Tooltip(
          message: resetTip,
          child: InkWell(
            onTap: () => widget.onChanged(resetTarget),
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Icon(
                Icons.restart_alt,
                size: 13,
                color: PrimeTheme.primaryAccent.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      );
    }

    // Up/Down stepper nudging
    if (widget.showStepper) {
      suffixWidgets.add(
        SizedBox(
          width: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => _nudge(widget.step),
                child: Icon(Icons.arrow_drop_up, size: 11, color: PrimeTheme.textSecondary),
              ),
              InkWell(
                onTap: () => _nudge(-widget.step),
                child: Icon(Icons.arrow_drop_down, size: 11, color: PrimeTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return PrimeTextField(
      value: isAuto ? '' : _format(widget.value, widget.precision),
      hintText: widget.allowAuto ? widget.autoLabel : '',
      prefix: widget.prefixText != null
          ? Text(
              widget.prefixText!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: PrimeTheme.textSecondary,
              ),
            )
          : null,
      suffix: suffixWidgets.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: suffixWidgets,
            )
          : null,
      onChanged: _onTextSubmitted,
    );
  }
}
