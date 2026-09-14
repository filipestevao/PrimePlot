// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A collapsible accordion section card for the Property Inspector.
class PropertySection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Widget? trailing;

  const PropertySection({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.initiallyExpanded = true,
    this.trailing,
  });

  @override
  State<PropertySection> createState() => _PropertySectionState();
}

class _PropertySectionState extends State<PropertySection> {
  late bool _isExpanded;
  bool _isHeaderHovered = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: PrimeTheme.panelBackground,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: PrimeTheme.borderSide, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHeaderHovered = true),
            onExit: (_) => setState(() => _isHeaderHovered = false),
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                decoration: BoxDecoration(
                  color: _isHeaderHovered
                      ? PrimeTheme.tabBackground
                      : PrimeTheme.tabBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(5.0),
                    bottom: Radius.circular(_isExpanded ? 0.0 : 5.0),
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: PrimeTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 13, color: PrimeTheme.primaryAccent),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: PrimeTheme.textPrimary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
              ),
            ),
          ),
          // Collapsible Body
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 10.0),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: PrimeTheme.borderSide, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}
