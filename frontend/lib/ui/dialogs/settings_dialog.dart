// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/state.dart';
import '../../core/theme.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ValueListenableBuilder<String>(
        valueListenable: ProjectState.instance.activeTheme,
        builder: (context, currentTheme, _) {
          return Container(
            width: 580,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: PrimeTheme.panelBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PrimeTheme.borderSide),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context),

                Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.palette_outlined,
                          title: 'APPEARANCE & THEME',
                          subtitle:
                              'Choose your workspace color theme. Canvas, inspector, and tables adapt immediately.',
                        ),
                        const SizedBox(height: 14),

                        // Theme cards
                        _ThemeOptionCard(
                          themeId: 'primeplot',
                          title: 'PrimePlot',
                          tag: 'SIGNATURE',
                          description: 'Signature bluish-slate dark palette designed for scientific data inspection.',
                          accentColor: primeplotTokens.primaryAccent,
                          panelColor: primeplotTokens.panelBackground,
                          canvasColor: primeplotTokens.canvasBackground,
                          textColor: primeplotTokens.textPrimary,
                          isSelected: currentTheme == 'primeplot',
                          onTap: () => ProjectState.instance.setTheme('primeplot'),
                        ),
                        const SizedBox(height: 10),

                        _ThemeOptionCard(
                          themeId: 'dark',
                          title: 'Dark',
                          description: 'Neutral charcoal dark palette with high contrast and blue accents.',
                          accentColor: darkTokens.primaryAccent,
                          panelColor: darkTokens.panelBackground,
                          canvasColor: darkTokens.canvasBackground,
                          textColor: darkTokens.textPrimary,
                          isSelected: currentTheme == 'dark',
                          onTap: () => ProjectState.instance.setTheme('dark'),
                        ),
                        const SizedBox(height: 10),

                        _ThemeOptionCard(
                          themeId: 'light',
                          title: 'Light',
                          tag: 'PAPER / PRINT',
                          description: 'Crisp white publication-ready light theme for paper figures and export.',
                          accentColor: lightTokens.primaryAccent,
                          panelColor: lightTokens.panelBackground,
                          canvasColor: lightTokens.canvasBackground,
                          textColor: lightTokens.textPrimary,
                          isSelected: currentTheme == 'light',
                          onTap: () => ProjectState.instance.setTheme('light'),
                        ),

                        const SizedBox(height: 20),
                        _buildSectionHeader(
                          icon: Icons.auto_awesome_mosaic_outlined,
                          title: 'CANVAS PREVIEW',
                          subtitle:
                              'Canvas background, axes, and grid lines automatically sync with your selected theme.',
                        ),
                      ],
                    ),
                  ),
                ),

                Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),

                // Footer
                _buildFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.settings,
            size: 18,
            color: PrimeTheme.primaryAccent,
          ),
          const SizedBox(width: 10),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PrimeTheme.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: PrimeTheme.textSecondary,
            hoverColor: Colors.white12,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: PrimeTheme.primaryAccent),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: PrimeTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: PrimeTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: PrimeTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            'Preferences are saved automatically.',
            style: TextStyle(
              fontSize: 11.5,
              color: PrimeTheme.textSecondary,
            ),
          ),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: PrimeTheme.primaryAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatefulWidget {
  final String themeId;
  final String title;
  final String? tag;
  final String description;
  final Color accentColor;
  final Color panelColor;
  final Color canvasColor;
  final Color textColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.themeId,
    required this.title,
    this.tag,
    required this.description,
    required this.accentColor,
    required this.panelColor,
    required this.canvasColor,
    required this.textColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThemeOptionCard> createState() => _ThemeOptionCardState();
}

class _ThemeOptionCardState extends State<_ThemeOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isSelected
        ? PrimeTheme.primaryAccent
        : (_isHovered
            ? PrimeTheme.textSecondary.withValues(alpha: 0.5)
            : PrimeTheme.borderSide);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? PrimeTheme.primaryAccent.withValues(alpha: 0.08)
                : PrimeTheme.searchBarBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Mini theme swatch preview
              Container(
                width: 48,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.canvasColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: widget.accentColor.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 5,
                      width: 22,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.panelColor,
                            border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          height: 2,
                          width: 14,
                          color: widget.textColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Title, tag & description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PrimeTheme.textPrimary,
                          ),
                        ),
                        if (widget.tag != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: widget.accentColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              widget.tag!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: widget.accentColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: PrimeTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection checkmark or radio dot
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? PrimeTheme.primaryAccent
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? PrimeTheme.primaryAccent
                        : PrimeTheme.textSecondary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
