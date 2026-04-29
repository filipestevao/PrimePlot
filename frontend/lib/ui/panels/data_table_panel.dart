import 'package:flutter/material.dart';
import '../../core/theme.dart';

class DataTablePanel extends StatelessWidget {
  const DataTablePanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Generate some mock data matching the mockup
    final columns = ['X', 'Y1', 'Y2', 'Status'];
    final rows = List.generate(21, (index) {
      return [
        index.toString(),
        (132.39 + index * 0.4).toStringAsFixed(2),
        '0.033',
        index % 3 == 0 ? 'Low' : 'Sample'
      ];
    });

    return Container(
      color: PrimeTheme.panelBackground,
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
                for (var col in columns) _buildHeaderCell(col, 80),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
          
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final isSelected = index == 0; // Mocking first row selected
                return Container(
                  color: isSelected ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent,
                  child: Row(
                    children: [
                      // Row index column
                      Container(
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 12, color: PrimeTheme.textSecondary),
                        ),
                      ),
                      // Data columns
                      for (var cell in rows[index])
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                          alignment: Alignment.centerLeft,
                          decoration: isSelected 
                              ? BoxDecoration(border: Border.all(color: PrimeTheme.primaryAccent, width: 1))
                              : null,
                          child: Text(
                            cell,
                            style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      alignment: text == '#' ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: PrimeTheme.textPrimary,
        ),
      ),
    );
  }
}
