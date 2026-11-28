// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Commands broadcast by the Property Inspector's overflow menu.
enum SectionCommand { expandAll, collapseAll }

/// Broadcasts expand/collapse commands to every listening [PropertySection].
///
/// Commands stay available until [reset] so sections created lazily (for
/// example after a collapse shrinks the list) still receive the latest one.
/// Each section tracks [revision] to avoid replaying the same command on
/// ordinary rebuilds.
class SectionCommandNotifier extends ValueNotifier<SectionCommand?> {
  SectionCommandNotifier() : super(null);

  int _revision = 0;
  int get revision => _revision;

  void expandAll() {
    _revision++;
    value = SectionCommand.expandAll;
  }

  void collapseAll() {
    _revision++;
    value = SectionCommand.collapseAll;
  }

  /// Clears the pending command (called when the inspected node changes).
  void reset() {
    _revision++;
    value = null;
  }
}

/// A collapsible accordion section card for the Property Inspector.
class PropertySection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Widget? trailing;

  /// Optional inspector-wide expand/collapse command source.
  final SectionCommandNotifier? commandNotifier;

  const PropertySection({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.initiallyExpanded = true,
    this.trailing,
    this.commandNotifier,
  });

  @override
  State<PropertySection> createState() => _PropertySectionState();
}

class _PropertySectionState extends State<PropertySection> {
  late bool _isExpanded;
  bool _isHeaderHovered = false;
  int _appliedRevision = -1;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    final notifier = widget.commandNotifier;
    _appliedRevision = notifier?.revision ?? -1;
    final command = notifier?.value;
    if (command != null) {
      _isExpanded = command == SectionCommand.expandAll;
    }
    notifier?.addListener(_onCommand);
  }

  @override
  void didUpdateWidget(covariant PropertySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandNotifier != widget.commandNotifier) {
      oldWidget.commandNotifier?.removeListener(_onCommand);
      final notifier = widget.commandNotifier;
      _appliedRevision = notifier?.revision ?? -1;
      final command = notifier?.value;
      if (command != null) {
        _isExpanded = command == SectionCommand.expandAll;
      }
      notifier?.addListener(_onCommand);
    }
  }

  @override
  void dispose() {
    widget.commandNotifier?.removeListener(_onCommand);
    super.dispose();
  }

  void _onCommand() {
    final notifier = widget.commandNotifier;
    if (notifier == null || notifier.revision == _appliedRevision) return;
    _appliedRevision = notifier.revision;
    final command = notifier.value;
    if (command == null) return;
    setState(() {
      _isExpanded = command == SectionCommand.expandAll;
    });
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
                      child: Icon(
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
                        style: TextStyle(
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
              decoration: BoxDecoration(
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
