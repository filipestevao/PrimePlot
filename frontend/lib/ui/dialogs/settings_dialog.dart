// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/number_format.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../components/prime_switch.dart';
import '../components/shortcut_map.dart';

enum _SettingsTab {
  appearance('Appearance', Icons.palette_outlined),
  dataLocale('Data & Locale', Icons.language_outlined),
  keyboard('Keyboard', Icons.keyboard_outlined),
  advanced('Advanced', Icons.tune_outlined);

  final String label;
  final IconData icon;
  const _SettingsTab(this.label, this.icon);
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsTab _tab = _SettingsTab.appearance;

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
            width: 640,
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

                // Content: sidebar + tab body.
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 148,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              for (final t in _SettingsTab.values)
                                _SidebarEntry(
                                  tab: t,
                                  selected: _tab == t,
                                  onTap: () =>
                                      setState(() => _tab = t),
                                ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: PrimeTheme.borderSide,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _tabBody(currentTheme),
                        ),
                      ),
                    ],
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

  Widget _tabBody(String currentTheme) {
    switch (_tab) {
      case _SettingsTab.appearance:
        return _appearanceTab(currentTheme);
      case _SettingsTab.dataLocale:
        return _dataLocaleTab();
      case _SettingsTab.keyboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.keyboard_outlined,
              title: 'KEYBOARD SHORTCUTS',
              subtitle:
                  'Every shortcut, also available at any time with Ctrl + / or ?. Single-key shortcuts pause while typing.',
            ),
            const SizedBox(height: 14),
            const ShortcutMap(),
          ],
        );
      case _SettingsTab.advanced:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.tune_outlined,
              title: 'ADVANCED',
              subtitle: 'Power settings land here in a future update.',
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing here yet.',
              style: TextStyle(
                fontSize: 12,
                color: PrimeTheme.textSecondary,
              ),
            ),
          ],
        );
    }
  }

  Widget _appearanceTab(String currentTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.palette_outlined,
          title: 'APPEARANCE & THEME',
          subtitle:
              'Choose your workspace color theme. Canvas, inspector, and tables adapt immediately.',
        ),
        const SizedBox(height: 14),
        _ThemeOptionCard(
          themeId: 'primeplot',
          title: 'PrimePlot',
          description: 'Bluish-slate dark interface — the PrimePlot look.',
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
          description: 'Crisp white theme for figures and print.',
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
    );
  }

  Widget _dataLocaleTab() {
    final st = ProjectState.instance;
    return ListenableBuilder(
      listenable:
          Listenable.merge([st.decimalSeparator, st.useThousands]),
      builder: (context, _) {
        final sep = st.decimalSeparator.value;
        final grouped = st.useThousands.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.language_outlined,
              title: 'DATA & LOCALE',
              subtitle:
                  'Decimal separator for tables, readouts, and statistics. Input always accepts both. Export follows the European convention (comma pairs with semicolons).',
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '.', label: Text('1.5 (dot)')),
                ButtonSegment(value: ',', label: Text('1,5 (comma)')),
              ],
              selected: {sep},
              // No checkmark: it resizes the selected segment on every tap.
              showSelectedIcon: false,
              onSelectionChanged: (selected) =>
                  ProjectState.instance.setDecimalSeparator(selected.first),
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(120, 34),
                foregroundColor: PrimeTheme.textPrimary,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: PrimeTheme.primaryAccent,
                side: BorderSide(color: PrimeTheme.borderSide),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sample: ${formatNumber(1234567.891, precision: 1)}',
              style: TextStyle(
                fontSize: 12,
                color: PrimeTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thousands separator${grouped ? (sep == ',' ? ' (.)' : ' (,)') : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: PrimeTheme.textPrimary,
                    ),
                  ),
                ),
                PrimeSwitch(
                  value: grouped,
                  onChanged: (v) =>
                      ProjectState.instance.setThousandsSeparator(v),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Display only — files export ungrouped so they stay machine-readable.',
              style: TextStyle(
                fontSize: 11,
                color: PrimeTheme.textSecondary,
              ),
            ),
          ],
        );
      },
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

class _SidebarEntry extends StatelessWidget {
  final _SettingsTab tab;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarEntry({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? PrimeTheme.primaryAccent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                tab.icon,
                size: 15,
                color: selected
                    ? PrimeTheme.primaryAccent
                    : PrimeTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? PrimeTheme.primaryAccent
                        : PrimeTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatefulWidget {
  final String themeId;
  final String title;
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

              // Title & description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PrimeTheme.textPrimary,
                      ),
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
