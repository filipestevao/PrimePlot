// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
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
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) {
        String hexInput = widget.hexColor;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeColor = _parse(hexInput);
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AcademicPalettes.tab10.map((c) {
                        return _swatchTile(c, activeColor, () {
                          final h = _toHex(c);
                          widget.onChanged(h);
                          Navigator.pop(ctx);
                        });
                      }).toList(),
                    ),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AcademicPalettes.colorBrewerSet1.map((c) {
                        return _swatchTile(c, activeColor, () {
                          final h = _toHex(c);
                          widget.onChanged(h);
                          Navigator.pop(ctx);
                        });
                      }).toList(),
                    ),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AcademicPalettes.neonScientific.map((c) {
                        return _swatchTile(c, activeColor, () {
                          final h = _toHex(c);
                          widget.onChanged(h);
                          Navigator.pop(ctx);
                        });
                      }).toList(),
                    ),
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

  Widget _swatchTile(Color color, Color selectedColor, VoidCallback onTap) {
    final isSelected = color.toARGB32() == selectedColor.toARGB32();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 24,
        height: 24,
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
