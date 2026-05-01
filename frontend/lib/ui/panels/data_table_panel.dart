import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../src/rust/api/data.dart';

class DataTablePanel extends StatefulWidget {
  const DataTablePanel({super.key});

  @override
  State<DataTablePanel> createState() => _DataTablePanelState();
}

class _DataTablePanelState extends State<DataTablePanel> {
  DTODataTable? _tableData;
  int _rowCount = 0;
  
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tableData = getInitialTableData();
    if (_tableData!.columns.isNotEmpty) {
      _rowCount = _tableData!.columns.first.data.length;
    }
  }
  
  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tableData == null) {
      return const Center(child: CircularProgressIndicator());
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
            // Approximate total width: index column + data columns
            width: 40 + (_tableData!.columns.length * 100.0),
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
                      for (int i = 0; i < _tableData!.columns.length; i++)
                        _buildInteractiveHeaderCell(i, 100),
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
                      itemCount: _rowCount,
                      itemBuilder: (context, index) {
                        final isSelected = index == 0; // Mocking first row selected
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
                                  '${index + 1}',
                                  style: const TextStyle(fontSize: 12, color: PrimeTheme.textSecondary),
                                ),
                              ),
                              // Data columns
                              for (var col in _tableData!.columns)
                                Container(
                                  width: 100,
                                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
                                    ),
                                  ),
                                  child: Text(
                                    col.data[index].toStringAsFixed(3),
                                    style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
                                  ),
                                ),
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

  Widget _buildInteractiveHeaderCell(int columnIndex, double width) {
    final col = _tableData!.columns[columnIndex];
    
    // Determine color based on role for visual feedback
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
        border: Border(
          right: BorderSide(color: PrimeTheme.borderSide.withOpacity(0.5)),
        ),
      ),
      child: PopupMenuButton<DTOColumnRole>(
        tooltip: 'Change Column Role',
        color: PrimeTheme.panelBackground,
        offset: const Offset(0, 30),
        onSelected: (DTOColumnRole newRole) {
          setState(() {
            // Dart objects generated by flutter_rust_bridge are usually immutable 
            // if we use Freezed or similar, but default classes have final fields.
            // We'll create a new column object.
            _tableData!.columns[columnIndex] = DTODataColumn(
              name: col.name,
              role: newRole,
              data: col.data,
            );
          });
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<DTOColumnRole>>[
          const PopupMenuItem<DTOColumnRole>(
            value: DTOColumnRole.x,
            child: Text('Set as X', style: TextStyle(color: PrimeTheme.textPrimary)),
          ),
          const PopupMenuItem<DTOColumnRole>(
            value: DTOColumnRole.y,
            child: Text('Set as Y', style: TextStyle(color: PrimeTheme.textPrimary)),
          ),
          const PopupMenuItem<DTOColumnRole>(
            value: DTOColumnRole.xError,
            child: Text('Set as X Error', style: TextStyle(color: PrimeTheme.textPrimary)),
          ),
          const PopupMenuItem<DTOColumnRole>(
            value: DTOColumnRole.yError,
            child: Text('Set as Y Error', style: TextStyle(color: PrimeTheme.textPrimary)),
          ),
          const PopupMenuItem<DTOColumnRole>(
            value: DTOColumnRole.text,
            child: Text('Set as Text', style: TextStyle(color: PrimeTheme.textPrimary)),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                col.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: PrimeTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '[${col.role.name}]',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
