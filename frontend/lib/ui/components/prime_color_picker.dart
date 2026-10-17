// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../src/rust/api/user_palettes.dart';
import 'prime_text_field.dart';

/// Standard academic and scientific palettes for PrimePlot curves.
class AcademicPalettes {
  static const List<Color> tab10 = [
    Color(0xFF1F77B4), // Blue
    Color(0xFFFF7F0E), // Orange
    Color(0xFF2CA02C), // Green
    Color(0xFFD62728), // Red
    Color(0xFF9467BD), // Purple
    Color(0xFF8C564B), // Brown
    Color(0xFFE377C2), // Pink
    Color(0xFF7F7F7F), // Gray
    Color(0xFFBCBD22), // Olive
    Color(0xFF17BECF), // Cyan
  ];

  static const List<Color> colorBrewerSet1 = [
    Color(0xFFE41A1C),
    Color(0xFF377EB8),
    Color(0xFF4DAF4A),
    Color(0xFF984EA3),
    Color(0xFFFF7F00),
    Color(0xFFFFFF33),
    Color(0xFFA65628),
    Color(0xFFF781BF),
  ];

  static const List<Color> neonScientific = [
    Color(0xFF00C3FF), // Default PrimePlot Cyan
    Color(0xFFFF5252), // Bright Coral
    Color(0xFF69F0AE), // Mint Green
    Color(0xFFFFD740), // Gold
    Color(0xFFE040FB), // Magenta
    Color(0xFFFFFFFF), // Pure White
    Color(0xFF90A4AE), // Cool Slate
    Color(0xFFFF6E40), // Deep Orange
  ];
}

/// A compact desktop color swatch button with academic palette quick-picker.
class PrimeColorPicker extends StatefulWidget {
  final String hexColor;
  final ValueChanged<String> onChanged;
  final String label;

  const PrimeColorPicker({
    super.key,
    required this.hexColor,
    required this.onChanged,
    this.label = 'Color',
  });

  @override
  State<PrimeColorPicker> createState() => _PrimeColorPickerState();
}

class _PrimeColorPickerState extends State<PrimeColorPicker> {
  bool _isHovered = false;

  Color _parse(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF00C3FF);
  }

  String _toHex(Color c) {
    final a = (c.a * 255).round();
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    if (a == 255) {
      return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
    }
    return '#${a.toRadixString(16).padLeft(2, '0')}${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  void _showPaletteDialog(BuildContext context, Color currentColor) {
    List<String> recents;
    try {
      recents = listRecentColors();
    } catch (_) {
      recents = const [];
    }
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) {
        String hexInput = widget.hexColor;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeColor = _parse(hexInput);
            void pick(Color c) {
              final h = _toHex(c);
              widget.onChanged(h);
              _rememberColor(h);
              Navigator.pop(ctx);
            }
            return Dialog(
              backgroundColor: PrimeTheme.panelBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: BorderSide(color: PrimeTheme.borderSide),
              ),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select ${widget.label}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PrimeTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: PrimeTheme.borderSide),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ACADEMIC PALETTE (Tab10)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: PrimeTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _swatchRow(AcademicPalettes.tab10, activeColor, pick),
                    const SizedBox(height: 12),
                    Text(
                      'COLORBREWER (Set 1)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: PrimeTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _swatchRow(AcademicPalettes.colorBrewerSet1, activeColor, pick),
                    const SizedBox(height: 12),
                    Text(
                      'SCIENTIFIC NEON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: PrimeTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _swatchRow(AcademicPalettes.neonScientific, activeColor, pick),
                    const SizedBox(height: 12),
                    Text(
                      'CUSTOM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: PrimeTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _pickCustomColor(ctx, activeColor),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: const SweepGradient(
                                  colors: [
                                    Color(0xFFFF0000),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00FF00),
                                    Color(0xFF00FFFF),
                                    Color(0xFF0000FF),
                                    Color(0xFFFF00FF),
                                    Color(0xFFFF0000),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: PrimeTheme.borderSide),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pick from color wheel…',
                              style: TextStyle(
                                fontSize: 11,
                                color: PrimeTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (recents.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'RECENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: PrimeTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _swatchRow(recents.map(_parse).toList(), activeColor, pick),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Hex:', style: TextStyle(fontSize: 11, color: PrimeTheme.textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PrimeTextField(
                            value: widget.hexColor,
                            hintText: '#00C3FF',
                            onChanged: (val) {
                              if (val.trim().isNotEmpty) {
                                widget.onChanged(val.trim());
                                setModalState(() => hexInput = val.trim());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Recent picks are user-level (prefs dir), shared by every picker.
  void _rememberColor(String hex) {
    try {
      pushRecentColor(color: hex);
    } catch (_) {
      // Recents are a convenience; failing to record must never block a pick.
    }
  }

  /// Wheel dialog for a free-form color; applies and closes the palette
  /// dialog on confirm, mirroring a swatch tap.
  Future<void> _pickCustomColor(BuildContext paletteCtx, Color currentColor) async {
    var picked = currentColor;
    final applied = await showDialog<Color>(
      context: paletteCtx,
      barrierColor: Colors.black45,
      builder: (wheelCtx) {
        return StatefulBuilder(
          builder: (context, setWheelState) {
            return Dialog(
              backgroundColor: PrimeTheme.panelBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: BorderSide(color: PrimeTheme.borderSide),
              ),
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Color',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PrimeTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ColorPicker(
                      color: picked,
                      onColorChanged: (c) => setWheelState(() => picked = c),
                      pickersEnabled: const {ColorPickerType.wheel: true},
                      enableOpacity: false,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(wheelCtx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(wheelCtx, picked),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (applied == null) return;
    final hex = _toHex(applied);
    widget.onChanged(hex);
    _rememberColor(hex);
    if (paletteCtx.mounted) Navigator.pop(paletteCtx);
  }

  /// One line of swatches that always fits: sizes shrink (never wrap) when
  /// the dialog is narrower than the fixed 24px tiles plus gaps.
  Widget _swatchRow(
    List<Color> colors,
    Color selectedColor,
    ValueChanged<Color> onPick,
  ) {
    const gap = 6.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = colors.length;
        if (n == 0) return const SizedBox.shrink();
        var size = ((constraints.maxWidth - gap * (n - 1)) / n).clamp(8.0, 24.0);
        size = (size * 100).floorToDouble() / 100;
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _swatchTile(
                colors[i],
                selectedColor,
                () => onPick(colors[i]),
                size: size,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _swatchTile(
    Color color,
    Color selectedColor,
    VoidCallback onTap, {
    double size = 24,
  }) {
    final isSelected = color.toARGB32() == selectedColor.toARGB32();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.white : PrimeTheme.borderSide,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _parse(widget.hexColor);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _showPaletteDialog(context, color),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: _isHovered ? Colors.white : PrimeTheme.borderSide,
              width: 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
