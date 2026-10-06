// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';

import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/data.dart';
import '../components/prime_number_field.dart';
import '../components/prime_select.dart';
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
        decoration: BoxDecoration(
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
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: PrimeTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
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
              icon: Icon(
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
                } else if (choice == 'resize') {
                  final t = ProjectState.instance.activeTable.value;
                  if (t != null) showResizeTableDialog(context, t);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'new',
                  child: Text(
                    'New table',
                    style: TextStyle(color: PrimeTheme.textPrimary),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'resize',
                  child: Text(
                    'Resize table…',
                    style: TextStyle(color: PrimeTheme.textPrimary),
                  ),
                ),
                PopupMenuItem<String>(
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: PrimeTheme.textPrimary,
        ),
      ),
    );
  }
}

/// Table resize dialog: rows/columns to append (single undo step).
/// New columns take `role` (default Y, or X when the table has none).
void showResizeTableDialog(BuildContext context, DTODataTable table) {
  var rows = 10.0;
  var cols = 1.0;
  var role = table.columns.any((c) => c.role == DTOColumnRole.x)
      ? DTOColumnRole.y
      : DTOColumnRole.x;

  void snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor:
            error ? const Color(0xFF7F1D1D) : const Color(0xFF1C2331),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: PrimeTheme.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: PrimeTheme.borderSide),
        ),
        title: Text(
          'Resize table',
          style: TextStyle(fontSize: 14, color: PrimeTheme.textPrimary),
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rows to add',
                      style: TextStyle(
                          fontSize: 11, color: PrimeTheme.textSecondary)),
                  const SizedBox(height: 4),
                  PrimeNumberField(
                    value: rows,
                    step: 10,
                    min: 1,
                    max: 100000,
                    precision: 0,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => rows = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('Columns to add',
                      style: TextStyle(
                          fontSize: 11, color: PrimeTheme.textSecondary)),
                  const SizedBox(height: 4),
                  PrimeNumberField(
                    value: cols,
                    step: 1,
                    min: 0,
                    max: 100,
                    precision: 0,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => cols = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('New column role',
                      style: TextStyle(
                          fontSize: 11, color: PrimeTheme.textSecondary)),
                  const SizedBox(height: 4),
                  PrimeSelect<DTOColumnRole>(
                    value: role,
                    options: const {
                      DTOColumnRole.x: 'X — horizontal axis',
                      DTOColumnRole.y: 'Y — data series',
                      DTOColumnRole.xError: '±X — horizontal error',
                      DTOColumnRole.yError: '±Y — vertical error',
                      DTOColumnRole.text: 'T — text / label',
                    },
                    onChanged: (v) => setDialogState(() => role = v),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: PrimeTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final st = ProjectState.instance;
              String? err;
              final nCols = cols.round();
              if (nCols > 0) {
                err = st.addTableColumns(table.id, nCols, role);
              }
              err ??= st.addTableRows(table.id, rows.round());
              Navigator.pop(ctx);
              if (err != null) snack('Resize failed: $err', error: true);
            },
            child: const Text('Resize'),
          ),
        ],
      );
    },
  );
}
