// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/data.dart';
import '../../src/rust/api/project.dart';
import '../components/prime_select.dart';

class DataTablePanel extends StatefulWidget {
  const DataTablePanel({super.key});

  @override
  State<DataTablePanel> createState() => _DataTablePanelState();
}

class _DataTablePanelState extends State<DataTablePanel> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  // Fixed layout widths: the scroll content budgets index + data columns
  // + the trailing add-column button, so growing the table never overflows.
  static const double _indexColWidth = 40.0;
  static const double _dataColWidth = 100.0;
  static const double _addColWidth = 36.0;

  int? _editingRow;
  int? _editingCol;
  int? _renamingCol;

  final Set<int> _selectedRows = {};
  final Set<int> _selectedCols = {};

  final TextEditingController _editController = TextEditingController();
  final TextEditingController _renameController = TextEditingController();
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
        _renamingCol = null;
      });
    }
  }

  @override
  void dispose() {
    ProjectState.instance.isTableEditable.removeListener(_onEditStateChanged);
    _horizontalController.dispose();
    _verticalController.dispose();
    _editController.dispose();
    _renameController.dispose();
    _tableFocus.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: error ? const Color(0xFF7F1D1D) : const Color(0xFF1C2331),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
  }

  /// Compact role badge text: X, Y, ±X, ±Y, T.
  static String _roleBadge(DTOColumnRole role) {
    switch (role) {
      case DTOColumnRole.x:
        return 'X';
      case DTOColumnRole.y:
        return 'Y';
      case DTOColumnRole.xError:
        return '±X';
      case DTOColumnRole.yError:
        return '±Y';
      case DTOColumnRole.text:
        return 'T';
    }
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
                return Center(
                  child: Text(
                    'No table selected.',
                    style: TextStyle(color: PrimeTheme.textSecondary),
                  ),
                );
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
                          width: _indexColWidth +
                              (colCount * _dataColWidth) +
                              _addColWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderRow(tableData, rowCount, colCount),
                              Divider(
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
                                                  .withValues(alpha: 0.5),
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
            color: PrimeTheme.backgroundDark.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                _buildFixedHeaderCell('#', _indexColWidth, 0, colCount),
                for (int i = 0; i < colCount; i++)
                  _buildInteractiveHeaderCell(tableData, i, _dataColWidth),
                _buildAddColumnButton(tableData),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
          // Hint area
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.content_paste_rounded,
                    size: 36,
                    color: PrimeTheme.textSecondary.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paste data to begin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: PrimeTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ctrl + V',
                    style: TextStyle(
                      fontSize: 12,
                      color: PrimeTheme.primaryAccent.withValues(alpha: 0.55),
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
      color: PrimeTheme.backgroundDark.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _buildFixedHeaderCell('#', _indexColWidth, rowCount, colCount),
          for (int i = 0; i < colCount; i++)
            _buildInteractiveHeaderCell(tableData, i, _dataColWidth),
          _buildAddColumnButton(tableData),
        ],
      ),
    );
  }

  Widget _buildAddColumnButton(DTODataTable tableData) {
    return Tooltip(
      message: 'Add column',
      child: SizedBox(
        width: _addColWidth,
        child: InkWell(
          onTap: () => _showAddColumnDialog(tableData),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Center(
              child:
                  Icon(Icons.add, size: 16, color: PrimeTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddColumnDialog(DTODataTable tableData) async {
    String name = 'Col ${tableData.columns.length + 1}';
    DTOColumnRole role = tableData.columns.any((c) => c.role == DTOColumnRole.x)
        ? DTOColumnRole.y
        : DTOColumnRole.x;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: PrimeTheme.panelBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: PrimeTheme.borderSide),
          ),
          title: Text(
            'Add column',
            style: TextStyle(fontSize: 14, color: PrimeTheme.textPrimary),
          ),
          content: StatefulBuilder(
            builder: (ctx, setDialogState) {
              return SizedBox(
                width: 260,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 11,
                        color: PrimeTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(text: name),
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: PrimeTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: PrimeTheme.searchBarBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: PrimeTheme.borderSide,
                          ),
                        ),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Role',
                      style: TextStyle(
                        fontSize: 11,
                        color: PrimeTheme.textSecondary,
                      ),
                    ),
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
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: PrimeTheme.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (result != true || !mounted) return;
    final err = ProjectState.instance.addTableColumn(
      tableData.id,
      name,
      role,
    );
    if (err != null) _snack('Add column failed: $err', error: true);
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
            right: BorderSide(color: PrimeTheme.borderSide.withValues(alpha: 0.5)),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
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
    final isRenaming = _renamingCol == columnIndex;

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
            ? PrimeTheme.primaryAccent.withValues(alpha: 0.2)
            : Colors.transparent,
        border: Border(
          right: BorderSide(color: PrimeTheme.borderSide.withValues(alpha: 0.5)),
        ),
      ),
      child: Listener(
        onPointerDown: (_) => _startColSelection(columnIndex),
        child: MouseRegion(
          onEnter: (_) => _continueColSelection(columnIndex),
          child: GestureDetector(
            onSecondaryTapDown: (details) => _showColumnMenu(
              details.globalPosition,
              tableData,
              columnIndex,
            ),
            onDoubleTap: () {
              _renameController.text = col.name;
              setState(() => _renamingCol = columnIndex);
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(
                  left: 12.0, right: 8.0, top: 4.0, bottom: 4.0),
              child: isRenaming
                  ? TextField(
                      controller: _renameController,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: PrimeTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (v) =>
                          _commitRename(tableData, columnIndex, v),
                      onTapOutside: (_) => _commitRename(
                        tableData,
                        columnIndex,
                        _renameController.text,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          col.name,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: PrimeTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '[${_roleBadge(col.role)}]',
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
    );
  }

  void _commitRename(DTODataTable tableData, int columnIndex, String value) {
    if (_renamingCol != columnIndex) return;
    setState(() => _renamingCol = null);
    final err = ProjectState.instance.renameTableColumn(
      tableData.id,
      columnIndex,
      value,
    );
    if (err != null) _snack('Rename failed: $err', error: true);
  }

  Future<void> _showColumnMenu(
    Offset position,
    DTODataTable tableData,
    int columnIndex,
  ) async {
    final colCount = tableData.columns.length;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: PrimeTheme.backgroundDark,
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          child: Text('Rename',
              style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 12)),
        ),
        const PopupMenuDivider(height: 8),
        for (final role in DTOColumnRole.values)
          PopupMenuItem<String>(
            value: 'role_${role.name}',
            child: Text('Role: ${_roleBadge(role)} — ${_roleName(role)}',
                style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 12)),
          ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'left',
          enabled: columnIndex > 0,
          child: Text('Move Left',
              style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 12)),
        ),
        PopupMenuItem<String>(
          value: 'right',
          enabled: columnIndex < colCount - 1,
          child: Text('Move Right',
              style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 12)),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete Column',
              style: TextStyle(color: const Color(0xFFF87171), fontSize: 12)),
        ),
      ],
    );
    if (choice == null || !mounted) return;
    final st = ProjectState.instance;
    String? err;
    switch (choice) {
      case 'rename':
        _renameController.text = tableData.columns[columnIndex].name;
        setState(() => _renamingCol = columnIndex);
        return;
      case 'role_x':
        err = st.setTableColumnRole(tableData.id, columnIndex, DTOColumnRole.x);
        break;
      case 'role_y':
        err = st.setTableColumnRole(tableData.id, columnIndex, DTOColumnRole.y);
        break;
      case 'role_xError':
        err = st.setTableColumnRole(
            tableData.id, columnIndex, DTOColumnRole.xError);
        break;
      case 'role_yError':
        err = st.setTableColumnRole(
            tableData.id, columnIndex, DTOColumnRole.yError);
        break;
      case 'role_text':
        err = st.setTableColumnRole(
            tableData.id, columnIndex, DTOColumnRole.text);
        break;
      case 'left':
        err = st.moveTableColumn(tableData.id, columnIndex, columnIndex - 1);
        break;
      case 'right':
        err = st.moveTableColumn(tableData.id, columnIndex, columnIndex + 1);
        break;
      case 'delete':
        err = st.removeTableColumn(tableData.id, columnIndex);
        break;
    }
    if (err != null) _snack('Column action failed: $err', error: true);
  }

  static String _roleName(DTOColumnRole role) {
    switch (role) {
      case DTOColumnRole.x:
        return 'X axis';
      case DTOColumnRole.y:
        return 'Y series';
      case DTOColumnRole.xError:
        return 'X error';
      case DTOColumnRole.yError:
        return 'Y error';
      case DTOColumnRole.text:
        return 'Text';
    }
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
          width: _indexColWidth,
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isRowSelected
                ? PrimeTheme.primaryAccent.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border(
              right:
                  BorderSide(color: PrimeTheme.borderSide.withValues(alpha: 0.5)),
            ),
          ),
          child: Text(
            '${rowIndex + 1}',
            style: TextStyle(
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
        width: _dataColWidth,
        padding:
            const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isEditing
              ? PrimeTheme.backgroundDark
              : (isHighlighted
                  ? PrimeTheme.primaryAccent.withValues(alpha: 0.2)
                  : Colors.transparent),
          border: Border(
            right:
                BorderSide(color: PrimeTheme.borderSide.withValues(alpha: 0.5)),
          ),
        ),
        child: isEditing
            ? TextFormField(
                controller: _editController,
                autofocus: true,
                style: TextStyle(
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
                      ? PrimeTheme.textSecondary.withValues(alpha: 0.3)
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
