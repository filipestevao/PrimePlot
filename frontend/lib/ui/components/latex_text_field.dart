// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class LatexTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool useLatex;
  final VoidCallback onLatexToggle;
  final int? maxLines;
  final String? tooltip;

  const LatexTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.useLatex,
    required this.onLatexToggle,
    this.maxLines = 1,
    this.tooltip,
  });

  @override
  State<LatexTextField> createState() => _LatexTextFieldState();
}

class _LatexTextFieldState extends State<LatexTextField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(LatexTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final singleLine = widget.maxLines == null || widget.maxLines == 1;
    final enabled = widget.useLatex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
            ),
            const Spacer(),
            Tooltip(
              message: widget.tooltip ??
                  (enabled ? 'Disable LaTeX formatting' : 'Enable LaTeX formatting'),
              child: InkWell(
                onTap: widget.onLatexToggle,
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: enabled ? PrimeTheme.primaryAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: enabled
                          ? PrimeTheme.primaryAccent
                          : PrimeTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      r'$$',
                      style: TextStyle(
                        fontSize: 10,
                        color: enabled ? Colors.white : PrimeTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: singleLine ? 28 : null,
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            maxLines: widget.maxLines,
            style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: singleLine
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 0)
                  : const EdgeInsets.all(8),
              isDense: singleLine,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}
