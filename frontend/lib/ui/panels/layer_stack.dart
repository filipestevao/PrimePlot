import 'package:flutter/material.dart';
import '../../core/theme.dart';

class LayerStack extends StatelessWidget {
  const LayerStack({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy layer data based on mockup
    final layers = [
      {'icon': Icons.straighten, 'name': 'Axis', 'visible': true},
      {'icon': Icons.scatter_plot, 'name': 'Data Series A (Scatter)', 'visible': true},
      {'icon': Icons.show_chart, 'name': 'Linear Fit A', 'visible': true},
      {'icon': Icons.timeline, 'name': 'Data Series B (Line)', 'visible': true},
      {'icon': Icons.north_east, 'name': 'Annotation 1 (Arrow)', 'visible': true},
      {'icon': Icons.list, 'name': 'Legend', 'visible': false},
    ];

    return Container(
      color: PrimeTheme.panelBackground,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: layers.length,
        itemBuilder: (context, index) {
          final layer = layers[index];
          final bool isVisible = layer['visible'] as bool;
          final bool isSelected = index == 2; // Mocking 'Linear Fit A' as selected

          return Container(
            color: isSelected ? PrimeTheme.primaryAccent.withOpacity(0.15) : Colors.transparent,
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              leading: Icon(
                layer['icon'] as IconData,
                size: 16,
                color: isSelected ? PrimeTheme.primaryAccent : PrimeTheme.textSecondary,
              ),
              title: Text(
                layer['name'] as String,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? PrimeTheme.primaryAccent : PrimeTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              trailing: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: isVisible ? PrimeTheme.textSecondary : PrimeTheme.textSecondary.withOpacity(0.3),
              ),
              onTap: () {
                // Future: Select layer
              },
            ),
          );
        },
      ),
    );
  }
}
