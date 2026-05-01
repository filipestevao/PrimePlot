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

  @override
  void initState() {
    super.initState();
    _tableData = getInitialTableData();
    if (_tableData!.columns.isNotEmpty) {
      _rowCount = _tableData!.columns.first.data.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tableData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: PrimeTheme.panelBackground,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
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
                      _buildHeaderCell('#', 40),
                      for (var col in _tableData!.columns)
                        _buildHeaderCell('${col.name}\n[${col.role.name}]', 100),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
                
                // Table Body
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
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

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      alignment: text == '#' ? Alignment.center : Alignment.centerLeft,
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
}
