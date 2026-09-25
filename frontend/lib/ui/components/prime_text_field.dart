// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

/// A sleek, dark-themed desktop text box with crisp borders, focus rings, and suffix actions.
class PrimeTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final Widget? prefix;
  final Widget? suffix;
  final TextAlign textAlign;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final double height;
  final bool readOnly;
  final int? maxLines;

  const PrimeTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.prefix,
    this.suffix,
    this.textAlign = TextAlign.start,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.height = 28.0,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  State<PrimeTextField> createState() => _PrimeTextFieldState();
}

class _PrimeTextFieldState extends State<PrimeTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isHovered = false;
  late String _initialValue;

  @override
  void initState() {
    super.initState();
    _initialValue = widget.value;
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
    if (!_focusNode.hasFocus) {
      if (_controller.text != widget.value) {
        widget.onChanged(_controller.text);
      }
    }
  }

  @override
  void didUpdateWidget(PrimeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.value) {
      _controller.text = widget.value;
      _initialValue = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Revert to initial value on Escape
        _controller.text = _initialValue;
        widget.onChanged(_initialValue);
        _focusNode.unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFocus = _focusNode.hasFocus;
    final bool isSingleLine = widget.maxLines == 1;

    final Color borderColor = hasFocus
        ? PrimeTheme.primaryAccent
        : (_isHovered ? PrimeTheme.textSecondary.withValues(alpha: 0.5) : PrimeTheme.borderSide);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKey,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isSingleLine ? widget.height : null,
          decoration: BoxDecoration(
            color: PrimeTheme.searchBarBackground,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: hasFocus
                ? [
                    BoxShadow(
                      color: PrimeTheme.primaryAccent.withValues(alpha: 0.25),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.prefix != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: widget.prefix!,
                  ),
                ],
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: widget.textAlign,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  readOnly: widget.readOnly,
                  maxLines: widget.maxLines,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: PrimeTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: PrimeTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  onSubmitted: (val) {
                    widget.onChanged(val);
                    widget.onSubmitted?.call(val);
                  },
                ),
              ),
              if (widget.suffix != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: widget.suffix!,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
