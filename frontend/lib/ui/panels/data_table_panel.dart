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
  
  // Track which cell is being edited: (row, col)
  int? _editingRow;
  int? _editingCol;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DTODataTable?>(
      valueListenable: ProjectState.instance.activeTable,
      builder: (context, tableData, child) {
        if (tableData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final int rowCount = tableData.columns.isNotEmpty ? tableData.columns.first.data.length : 0;

        return ValueListenableBuilder<bool>(
          valueListenable: ProjectState.instance.isTableEditable,
          builder: (context, isEditable, child) {
            // Reset edit state if locked
            if (!isEditable && (_editingRow != null || _editingCol != null)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() { _editingRow = null; _editingCol = null; });
              });
            }

            return Container(
              color: PrimeTheme.panelBackground,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 40 + (tableData.columns.length * 100.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table Header
                        Container(
                          color: PrimeTheme.backgroundDark.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              _buildFixedHeaderCell('#', 40),
                              for (int i = 0; i < tableData.columns.length; i++)
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
                                final isSelected = rowIndex == 0;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Row index column
                                      Container(
                                        width: 40,
                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
                                          ),
                                        ),
                                        child: Text(
                                          '${rowIndex + 1}',
                                          style: const TextStyle(fontSize: 12, color: PrimeTheme.textSecondary),
                                        ),
                                      ),
                                      // Data columns
                                      for (int colIndex = 0; colIndex < tableData.columns.length; colIndex++)
                                        _buildDataCell(tableData, rowIndex, colIndex, isEditable),
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
    );
  }

  Widget _buildDataCell(DTODataTable tableData, int rowIndex, int colIndex, bool isEditable) {
    final double value = tableData.columns[colIndex].data[rowIndex];
    final bool isEditing = _editingRow == rowIndex && _editingCol == colIndex;

    return GestureDetector(
      onTap: () {
        if (isEditable) {
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
          color: isEditing ? PrimeTheme.backgroundDark : Colors.transparent,
          border: Border(
            right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
          ),
        ),
        child: isEditing 
            ? TextFormField(
                initialValue: value.toString(),
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
                    // Update table data
                    final newTable = DTODataTable(
                      id: tableData.id,
                      name: tableData.name,
                      columns: List.from(tableData.columns),
                    );
                    
                    // Create new data list for the column to ensure UI reactivity
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

  Widget _buildFixedHeaderCell(String text, double width) {
    return Container(
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
    );
  }

  Widget _buildInteractiveHeaderCell(DTODataTable tableData, int columnIndex, double width) {
    final col = tableData.columns[columnIndex];
    
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
        border: Border(
          right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
        ),
      ),
      child: PopupMenuButton<DTOColumnRole>(
        tooltip: 'Change Column Role',
        color: PrimeTheme.panelBackground,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
    );
  }
}
