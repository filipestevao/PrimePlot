import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PropertyInspector extends StatefulWidget {
  const PropertyInspector({super.key});

  @override
  State<PropertyInspector> createState() => _PropertyInspectorState();
}

class _PropertyInspectorState extends State<PropertyInspector> {
  bool _showGrid = true;
  double _lineThickness = 2.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PrimeTheme.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'PROPERTY INSPECTOR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: PrimeTheme.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionHeader('Appearance'),
                const SizedBox(height: 12),
                _buildColorProperty('Line Color', PrimeTheme.primaryAccent),
                const SizedBox(height: 16),
                _buildSliderProperty('Thickness', _lineThickness, 1.0, 10.0, (val) {
                  setState(() => _lineThickness = val);
                }),
                const SizedBox(height: 24),
                
                _buildSectionHeader('Axes & Grid'),
                const SizedBox(height: 12),
                _buildToggleProperty('Show Grid', _showGrid, (val) {
                  setState(() => _showGrid = val);
                }),
                const SizedBox(height: 16),
                _buildTextProperty('X-Axis Label', '2Theta (deg)'),
                const SizedBox(height: 16),
                _buildTextProperty('Y-Axis Label', 'Intensity (a.u.)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: PrimeTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildColorProperty(String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: PrimeTheme.borderSide),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderProperty(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
            Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: PrimeTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: PrimeTheme.primaryAccent,
            inactiveTrackColor: PrimeTheme.borderSide,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleProperty(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: PrimeTheme.primaryAccent,
            activeTrackColor: PrimeTheme.primaryAccent.withOpacity(0.3),
            inactiveThumbColor: PrimeTheme.textSecondary,
            inactiveTrackColor: PrimeTheme.backgroundDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTextProperty(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: PrimeTheme.backgroundDark,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: PrimeTheme.borderSide),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
