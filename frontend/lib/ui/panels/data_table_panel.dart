import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/data.dart';

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

  bool _isMouseDown = false;

  @override
  void initState() {
    super.initState();
    ProjectState.instance.isTableEditable.addListener(_onEditStateChanged);
  }

  void _onEditStateChanged() {
    // When table is locked, clear selections and edits
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
    super.dispose();
  }

  void _selectAll(int rowCount, int colCount) {
    setState(() {
      _selectedRows.clear();
      _selectedCols.clear();
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
    if (_isMouseDown) {
      setState(() {
        _selectedRows.add(rowIndex);
      });
    }
  }

  void _startColSelection(int colIndex) {
    setState(() {
      _selectedRows.clear();
      _selectedCols.clear();
      _selectedCols.add(colIndex);
    });
  }

  void _continueColSelection(int colIndex) {
    if (_isMouseDown) {
      setState(() {
        _selectedCols.add(colIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _isMouseDown = true,
      onPointerUp: (_) => _isMouseDown = false,
      onPointerCancel: (_) => _isMouseDown = false,
      child: ValueListenableBuilder<DTODataTable?>(
        valueListenable: ProjectState.instance.activeTable,
        builder: (context, tableData, child) {
          if (tableData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final int rowCount = tableData.columns.isNotEmpty ? tableData.columns.first.data.length : 0;
          final int colCount = tableData.columns.length;

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
                          // Table Header
                          Container(
                            color: PrimeTheme.backgroundDark.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                _buildFixedHeaderCell('#', 40, rowCount, colCount),
                                for (int i = 0; i < colCount; i++)
                                  _buildInteractiveHeaderCell(tableData, i, 100),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
                          
                          // Table Body
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _verticalController,
                                itemCount: rowCount,
                                itemBuilder: (context, rowIndex) {
                                  final isRowSelected = _selectedRows.contains(rowIndex);
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Row index column
                                        Listener(
                                          onPointerDown: (_) => _startRowSelection(rowIndex),
                                          child: MouseRegion(
                                            onEnter: (_) => _continueRowSelection(rowIndex),
                                            child: Container(
                                              width: 40,
                                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: isRowSelected ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent,
                                                border: Border(
                                                  right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
                                                ),
                                              ),
                                              child: Text(
                                                '${rowIndex + 1}',
                                                style: const TextStyle(fontSize: 12, color: PrimeTheme.textSecondary),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Data columns
                                        for (int colIndex = 0; colIndex < colCount; colIndex++)
                                          _buildDataCell(tableData, rowIndex, colIndex, isEditable, isRowSelected),
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
            }
          );
        }
      ),
    );
  }

  Widget _buildDataCell(DTODataTable tableData, int rowIndex, int colIndex, bool isEditable, bool isRowSelected) {
    final double value = tableData.columns[colIndex].data[rowIndex];
    final bool isEditing = _editingRow == rowIndex && _editingCol == colIndex;
    final bool isColSelected = _selectedCols.contains(colIndex);
    
    // Highlight if either row or col is selected
    final bool isHighlighted = isRowSelected || isColSelected;

    return GestureDetector(
      onTap: () {
        if (isEditable) {
          _editController.text = value.toString();
          // Select all text
          _editController.selection = TextSelection(baseOffset: 0, extentOffset: _editController.text.length);
          setState(() {
            _editingRow = rowIndex;
            _editingCol = colIndex;
          });
        }
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isEditing 
            ? PrimeTheme.backgroundDark 
            : (isHighlighted ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent),
          border: Border(
            right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
          ),
        ),
        child: isEditing 
            ? TextFormField(
                controller: _editController,
                autofocus: true,
                style: const TextStyle(fontSize: 12, color: PrimeTheme.primaryAccent),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onFieldSubmitted: (newValue) {
                  final parsed = double.tryParse(newValue);
                  if (parsed != null) {
                    final newTable = DTODataTable(
                      id: tableData.id,
                      name: tableData.name,
                      columns: List.from(tableData.columns),
                    );
                    
                    final newData = Float64List.fromList(newTable.columns[colIndex].data);
                    newData[rowIndex] = parsed;
                    
                    newTable.columns[colIndex] = DTODataColumn(
                      name: newTable.columns[colIndex].name,
                      role: newTable.columns[colIndex].role,
                      data: newData,
                    );

                    ProjectState.instance.updateTable(newTable);
                  }
                  setState(() {
                    _editingRow = null;
                    _editingCol = null;
                  });
                },
              )
            : Text(
                value.toStringAsFixed(3),
                style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
              ),
      ),
    );
  }

  Widget _buildFixedHeaderCell(String text, double width, int rowCount, int colCount) {
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

  Widget _buildInteractiveHeaderCell(DTODataTable tableData, int columnIndex, double width) {
    final col = tableData.columns[columnIndex];
    final isColSelected = _selectedCols.contains(columnIndex);
    
    Color roleColor = PrimeTheme.textPrimary;
    switch (col.role) {
      case DTOColumnRole.x: roleColor = Colors.blueAccent; break;
      case DTOColumnRole.y: roleColor = Colors.greenAccent; break;
      case DTOColumnRole.xError: roleColor = Colors.purpleAccent; break;
      case DTOColumnRole.yError: roleColor = Colors.orangeAccent; break;
      case DTOColumnRole.text: roleColor = Colors.grey; break;
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isColSelected ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent,
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
                  color: Colors.transparent, // required for mouse events
                  padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        col.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PrimeTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '[${col.role.name}]',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<DTOColumnRole>(
            tooltip: 'Change Column Role',
            icon: const Icon(Icons.arrow_drop_down, size: 16, color: PrimeTheme.textSecondary),
            color: PrimeTheme.backgroundDark,
            elevation: 8,
            offset: const Offset(0, 30),
            onSelected: (DTOColumnRole newRole) {
              final newTable = DTODataTable(
                id: tableData.id,
                name: tableData.name,
                columns: List.from(tableData.columns),
              );
              newTable.columns[columnIndex] = DTODataColumn(
                name: col.name,
                role: newRole,
                data: col.data,
              );
              ProjectState.instance.updateTable(newTable);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<DTOColumnRole>>[
              const PopupMenuItem<DTOColumnRole>(value: DTOColumnRole.x, child: Text('Set as X', style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(value: DTOColumnRole.y, child: Text('Set as Y', style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(value: DTOColumnRole.xError, child: Text('Set as X Error', style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(value: DTOColumnRole.yError, child: Text('Set as Y Error', style: TextStyle(color: PrimeTheme.textPrimary))),
              const PopupMenuItem<DTOColumnRole>(value: DTOColumnRole.text, child: Text('Set as Text', style: TextStyle(color: PrimeTheme.textPrimary))),
            ],
          ),
        ],
      ),
    );
  }
}
