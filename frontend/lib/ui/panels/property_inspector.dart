import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';

class PropertyInspector extends StatelessWidget {
  const PropertyInspector({super.key});

  void _showColorPicker(BuildContext context, PlotProperties props) {
    final colors = [
      PrimeTheme.primaryAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.amber,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.tealAccent,
      Colors.white,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PrimeTheme.panelBackground,
        title: const Text('Select Line Color', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 14)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) => InkWell(
            onTap: () {
              ProjectState.instance.updatePlotProperties(props.copyWith(lineColor: c));
              Navigator.pop(ctx);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: props.lineColor == c ? Colors.white : Colors.transparent, width: 2),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

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
            child: ValueListenableBuilder<PlotProperties>(
              valueListenable: ProjectState.instance.plotProperties,
              builder: (context, props, child) {
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSectionHeader('Appearance'),
                    const SizedBox(height: 12),
                    _buildColorProperty(context, 'Line Color', props),
                    const SizedBox(height: 16),
                    _buildSliderProperty(context, 'Thickness', props.lineThickness, 1.0, 10.0, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(lineThickness: val));
                    }),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader('Axes & Grid'),
                    const SizedBox(height: 12),
                    _buildToggleProperty('Show Grid', props.showGrid, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(showGrid: val));
                    }),
                    const SizedBox(height: 16),
                    _buildTextProperty('X-Axis Label', props.xAxisLabel, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(xAxisLabel: val));
                    }),
                    const SizedBox(height: 16),
                    _buildTextProperty('Y-Axis Label', props.yAxisLabel, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(yAxisLabel: val));
                    }),
                  ],
                );
              }
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

  Widget _buildColorProperty(BuildContext context, String label, PlotProperties props) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        InkWell(
          onTap: () => _showColorPicker(context, props),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: props.lineColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PrimeTheme.borderSide),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderProperty(BuildContext context, String label, double value, double min, double max, ValueChanged<double> onChanged) {
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

  Widget _buildTextProperty(String label, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: TextField(
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
            style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
            onChanged: onChanged,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              filled: true,
              fillColor: PrimeTheme.backgroundDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: PrimeTheme.borderSide),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: PrimeTheme.borderSide),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: PrimeTheme.primaryAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
