// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/data.dart';
import '../../src/rust/api/project.dart';

class DataTablePanel extends StatefulWidget {
  const DataTablePanel({super.key});

  @override
  State<DataTablePanel> createState() => _DataTablePanelState();
}

class _DataTablePanelState extends State<DataTablePanel> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  int? _editingRow;
  int? _editingCol;

  final Set<int> _selectedRows = {};
  final Set<int> _selectedCols = {};

  final TextEditingController _editController = TextEditingController();
  final FocusNode _tableFocus = FocusNode();

  bool _isMouseDown = false;

  @override
  void initState() {
    super.initState();
    ProjectState.instance.isTableEditable.addListener(_onEditStateChanged);
  }

  void _onEditStateChanged() {
    if (!ProjectState.instance.isTableEditable.value) {
      setState(() {
        _selectedRows.clear();
        _selectedCols.clear();
        _editingRow = null;
        _editingCol = null;
      });
    }
  }

  @override
  void dispose() {
    ProjectState.instance.isTableEditable.removeListener(_onEditStateChanged);
    _horizontalController.dispose();
    _verticalController.dispose();
    _editController.dispose();
    _tableFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Paste handler
  // ---------------------------------------------------------------------------

  bool _isPasting = false;

  Future<void> _handlePaste() async {
    if (_isPasting) return;
    _isPasting = true;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
        _isPasting = false;
        return;
    }
    ProjectState.instance.handlePaste(data.text!, displayName: 'Pasted Table');
    _isPasting = false;
  }

  // ---------------------------------------------------------------------------
  // Selection helpers
  // ---------------------------------------------------------------------------

  void _selectAll(int rowCount, int colCount) {
    setState(() {
      _selectedRows.addAll(List.generate(rowCount, (i) => i));
      _selectedCols.addAll(List.generate(colCount, (i) => i));
    });
  }

  void _startRowSelection(int rowIndex) {
    setState(() {
      _selectedRows.clear();
      _selectedCols.clear();
      _selectedRows.add(rowIndex);
    });
  }

  void _continueRowSelection(int rowIndex) {
    if (_isMouseDown) setState(() => _selectedRows.add(rowIndex));
  }

  void _startColSelection(int colIndex) {
    setState(() {
      _selectedRows.clear();
      _selectedCols.clear();
      _selectedCols.add(colIndex);
    });
  }

  void _continueColSelection(int colIndex) {
    if (_isMouseDown) setState(() => _selectedCols.add(colIndex));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _isMouseDown = true,
      onPointerUp: (_) => _isMouseDown = false,
      onPointerCancel: (_) => _isMouseDown = false,
      child: GestureDetector(
        onTap: () => _tableFocus.requestFocus(),
        child: Focus(
          focusNode: _tableFocus,
          onKeyEvent: (node, event) {
            // Ctrl+V paste
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyV &&
                HardwareKeyboard.instance.isControlPressed) {
              _handlePaste();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ValueListenableBuilder<DTODataTable?>(
            valueListenable: ProjectState.instance.activeTable,
            builder: (context, tableData, child) {
              if (tableData == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final int rowCount = tableData.columns.isNotEmpty
                  ? tableData.columns.first.data.length
                  : 0;
              final int colCount = tableData.columns.length;

              // Empty state: show hint
              if (rowCount == 0) {
                return _buildEmptyState(tableData, colCount);
              }

              return ValueListenableBuilder<bool>(
                valueListenable: ProjectState.instance.isTableEditable,
                builder: (context, isEditable, child) {
                  return Container(
                    color: PrimeTheme.panelBackground,
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 40 + (colCount * 100.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderRow(tableData, rowCount, colCount),
                              const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: PrimeTheme.borderSide),
                              Expanded(
                                child: Scrollbar(
                                  controller: _verticalController,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _verticalController,
                                    itemCount: rowCount,
                                    itemBuilder: (context, rowIndex) {
                                      final isRowSelected =
                                          _selectedRows.contains(rowIndex);
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: PrimeTheme.borderSide
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _buildRowIndexCell(
                                                rowIndex, isRowSelected),
                                            for (int ci = 0;
                                                ci < colCount;
                                                ci++)
                                              _buildDataCell(tableData,
                                                  rowIndex, ci, isEditable, isRowSelected),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state widget
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(DTODataTable tableData, int colCount) {
    return Container(
      color: PrimeTheme.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Keep the header visible even when empty
          Container(
            color: PrimeTheme.backgroundDark.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                _buildFixedHeaderCell('#', 40, 0, colCount),
                for (int i = 0; i < colCount; i++)
                  _buildInteractiveHeaderCell(tableData, i, 100),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
          // Hint area
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.content_paste_rounded,
                    size: 36,
                    color: PrimeTheme.textSecondary.withOpacity(0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paste data to begin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: PrimeTheme.textSecondary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ctrl + V',
                    style: TextStyle(
                      fontSize: 12,
                      color: PrimeTheme.primaryAccent.withOpacity(0.55),
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header widgets
  // ---------------------------------------------------------------------------

  Widget _buildHeaderRow(DTODataTable tableData, int rowCount, int colCount) {
    return Container(
      color: PrimeTheme.backgroundDark.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _buildFixedHeaderCell('#', 40, rowCount, colCount),
          for (int i = 0; i < colCount; i++)
            _buildInteractiveHeaderCell(tableData, i, 100),
        ],
      ),
    );
  }

  Widget _buildFixedHeaderCell(
      String text, double width, int rowCount, int colCount) {
    return GestureDetector(
      onTap: () => _selectAll(rowCount, colCount),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: PrimeTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveHeaderCell(
      DTODataTable tableData, int columnIndex, double width) {
    final col = tableData.columns[columnIndex];
    final isColSelected = _selectedCols.contains(columnIndex);

    Color roleColor = PrimeTheme.textPrimary;
    switch (col.role) {
      case DTOColumnRole.x:
        roleColor = Colors.blueAccent;
        break;
      case DTOColumnRole.y:
        roleColor = Colors.greenAccent;
        break;
      case DTOColumnRole.xError:
        roleColor = Colors.purpleAccent;
        break;
      case DTOColumnRole.yError:
        roleColor = Colors.orangeAccent;
        break;
      case DTOColumnRole.text:
        roleColor = Colors.grey;
        break;
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isColSelected
            ? PrimeTheme.primaryAccent.withOpacity(0.2)
            : Colors.transparent,
        border: Border(
          right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Listener(
              onPointerDown: (_) => _startColSelection(columnIndex),
              child: MouseRegion(
                onEnter: (_) => _continueColSelection(columnIndex),
                child: Container(
                  color: Colors.transparent,
                  padding:
                      const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        col.name,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: PrimeTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '[${col.role.name}]',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: roleColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<DTOColumnRole>(
            tooltip: 'Change Column Role',
            icon: const Icon(Icons.arrow_drop_down,
                size: 16, color: PrimeTheme.textSecondary),
            color: PrimeTheme.backgroundDark,
            elevation: 8,
            offset: const Offset(0, 30),
            onSelected: (DTOColumnRole newRole) {
                final newColumns = List<DTODataColumn>.from(tableData.columns);
                newColumns[columnIndex] = DTODataColumn(
                  name: col.name,
                  role: newRole,
                  data: col.data,
                );
                saveTable(tableId: tableData.id, columns: newColumns);
                final updated = getTable(tableId: tableData.id);
                ProjectState.instance.updateTable(updated);
              },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<DTOColumnRole>>[
              const PopupMenuItem<DTOColumnRole>(
                  value: DTOColumnRole.x,
                  child: Text('Set as X',
                      style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(
                  value: DTOColumnRole.y,
                  child: Text('Set as Y',
                      style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(
                  value: DTOColumnRole.xError,
                  child: Text('Set as X Error',
                      style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(
                  value: DTOColumnRole.yError,
                  child: Text('Set as Y Error',
                      style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(
                  value: DTOColumnRole.text,
                  child: Text('Set as Text',
                      style: TextStyle(color: PrimeTheme.textPrimary))),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row index cell
  // ---------------------------------------------------------------------------

  Widget _buildRowIndexCell(int rowIndex, bool isRowSelected) {
    return Listener(
      onPointerDown: (_) => _startRowSelection(rowIndex),
      child: MouseRegion(
        onEnter: (_) => _continueRowSelection(rowIndex),
        child: Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isRowSelected
                ? PrimeTheme.primaryAccent.withOpacity(0.2)
                : Colors.transparent,
            border: Border(
              right:
                  BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
            ),
          ),
          child: Text(
            '${rowIndex + 1}',
            style: const TextStyle(
                fontSize: 12, color: PrimeTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Data cell — NaN-aware display, backspace-to-clear
  // ---------------------------------------------------------------------------

  Widget _buildDataCell(DTODataTable tableData, int rowIndex, int colIndex,
      bool isEditable, bool isRowSelected) {
    final double rawValue = tableData.columns[colIndex].data[rowIndex];
    // NaN = empty cell sentinel
    final bool isEmpty = rawValue.isNaN;
    final bool isEditing =
        _editingRow == rowIndex && _editingCol == colIndex;
    final bool isColSelected = _selectedCols.contains(colIndex);
    final bool isHighlighted = isRowSelected || isColSelected;

    // Display string: empty for NaN, fixed-3 for numbers
    final String displayText = isEmpty ? '' : rawValue.toStringAsFixed(3);

    return GestureDetector(
      onTap: () {
        if (!isEditable) return;
        // Commit any in-progress edit before starting a new one
        if (_editingRow != null && _editingCol != null) {
          _commitEdit(tableData, _editingRow!, _editingCol!, _editController.text);
        }
        _editController.text = displayText;
        _editController.selection = TextSelection(
            baseOffset: 0, extentOffset: _editController.text.length);
        setState(() {
          _editingRow = rowIndex;
          _editingCol = colIndex;
        });
      },
      child: Container(
        width: 100,
        padding:
            const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isEditing
              ? PrimeTheme.backgroundDark
              : (isHighlighted
                  ? PrimeTheme.primaryAccent.withOpacity(0.2)
                  : Colors.transparent),
          border: Border(
            right:
                BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
          ),
        ),
        child: isEditing
            ? TextFormField(
                controller: _editController,
                autofocus: true,
                style: const TextStyle(
                    fontSize: 12, color: PrimeTheme.primaryAccent),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                onFieldSubmitted: (newValue) =>
                    _commitEdit(tableData, rowIndex, colIndex, newValue),
                onTapOutside: (_) {
                  if (_editingRow != null && _editingCol != null) {
                    _commitEdit(tableData, _editingRow!, _editingCol!, _editController.text);
                  }
                },
              )
            : Text(
                displayText,
                style: TextStyle(
                  fontSize: 12,
                  color: isEmpty
                      ? PrimeTheme.textSecondary.withOpacity(0.3)
                      : PrimeTheme.textPrimary,
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Commit edit: parse value, write NaN on empty/backspace, update state
  // ---------------------------------------------------------------------------

  void _commitEdit(DTODataTable tableData, int rowIndex, int colIndex,
      String newValue) {
    final trimmed = newValue.trim();
    final double parsed =
        trimmed.isEmpty ? double.nan : (double.tryParse(trimmed) ?? double.nan);

    final newData =
        Float64List.fromList(tableData.columns[colIndex].data.toList());
    newData[rowIndex] = parsed;

    final newColumns = List<DTODataColumn>.from(tableData.columns);
    newColumns[colIndex] = DTODataColumn(
      name: tableData.columns[colIndex].name,
      role: tableData.columns[colIndex].role,
      data: newData,
    );

    saveTable(tableId: tableData.id, columns: newColumns);
    final updated = getTable(tableId: tableData.id);
    ProjectState.instance.updateTable(updated);
    setState(() {
      _editingRow = null;
      _editingCol = null;
    });
  }
}
