// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';

import '../../core/state.dart';
import '../../core/theme.dart';
import 'data_table_panel.dart';

class CollapsibleDataPanel extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const CollapsibleDataPanel({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: PrimeTheme.panelBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: PrimeTheme.borderSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DataPanelHeader(isCollapsed: isCollapsed, onToggle: onToggle),
          if (!isCollapsed)
            const Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(7.0)),
                child: DataTablePanel(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataPanelHeader extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _DataPanelHeader({required this.isCollapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(7.0)),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: const BoxDecoration(
          color: PrimeTheme.tabBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(7.0)),
          border: Border(bottom: BorderSide(color: PrimeTheme.borderSide)),
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: isCollapsed ? 0.0 : 0.25,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: const Icon(
                Icons.chevron_right,
                size: 18,
                color: PrimeTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Data',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PrimeTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: ProjectState.instance.tableDisplayName,
                builder: (context, tableName, child) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: _DataTab(label: tableName),
                  );
                },
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: ProjectState.instance.isTableEditable,
              builder: (context, isEditable, child) {
                return IconButton(
                  tooltip: isEditable ? 'Lock editing' : 'Unlock editing',
                  icon: Icon(
                    isEditable ? Icons.lock_open : Icons.lock,
                    size: 14,
                    color: isEditable
                        ? PrimeTheme.primaryAccent
                        : PrimeTheme.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  splashRadius: 16,
                  onPressed: ProjectState.instance.toggleTableEditMode,
                );
              },
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Table Options',
              icon: const Icon(
                Icons.more_horiz,
                size: 16,
                color: PrimeTheme.textSecondary,
              ),
              color: PrimeTheme.backgroundDark,
              elevation: 8,
              offset: const Offset(0, 30),
              onSelected: (String choice) {
                if (choice == 'new') {
                  ProjectState.instance.newTable();
                } else if (choice == 'clear') {
                  ProjectState.instance.clearTableData();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'new',
                  child: Text(
                    'New table',
                    style: TextStyle(color: PrimeTheme.textPrimary),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Text(
                    'Clean all data',
                    style: TextStyle(color: PrimeTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DataTab extends StatelessWidget {
  final String label;

  const _DataTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PrimeTheme.panelBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: PrimeTheme.borderSide),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: PrimeTheme.textPrimary,
        ),
      ),
    );
  }
}
