// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';

class PropertyInspector extends StatefulWidget {
  const PropertyInspector({super.key});
  @override
  State<PropertyInspector> createState() => _PropertyInspectorState();
}

class _PropertyInspectorState extends State<PropertyInspector> {
  final _xMinCtrl = TextEditingController();
  final _xMaxCtrl = TextEditingController();
  final _yMinCtrl = TextEditingController();
  final _yMaxCtrl = TextEditingController();
  final _xMinFocus = FocusNode();
  final _xMaxFocus = FocusNode();
  final _yMinFocus = FocusNode();
  final _yMaxFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncCtrlsFromProps();
    ProjectState.instance.plotProperties.addListener(_onPropsChanged);
    _xMinFocus.addListener(() => _onFocusChange(_xMinFocus, _xMinCtrl, (v) => _commit(_xMinCtrl, v, (p, n) => p.copyWith(xMin: () => n))));
    _xMaxFocus.addListener(() => _onFocusChange(_xMaxFocus, _xMaxCtrl, (v) => _commit(_xMaxCtrl, v, (p, n) => p.copyWith(xMax: () => n))));
    _yMinFocus.addListener(() => _onFocusChange(_yMinFocus, _yMinCtrl, (v) => _commit(_yMinCtrl, v, (p, n) => p.copyWith(yMin: () => n))));
    _yMaxFocus.addListener(() => _onFocusChange(_yMaxFocus, _yMaxCtrl, (v) => _commit(_yMaxCtrl, v, (p, n) => p.copyWith(yMax: () => n))));
  }

  @override
  void dispose() {
    ProjectState.instance.plotProperties.removeListener(_onPropsChanged);
    _xMinCtrl.dispose();
    _xMaxCtrl.dispose();
    _yMinCtrl.dispose();
    _yMaxCtrl.dispose();
    _xMinFocus.dispose();
    _xMaxFocus.dispose();
    _yMinFocus.dispose();
    _yMaxFocus.dispose();
    super.dispose();
  }

  void _syncCtrlsFromProps() {
    final p = ProjectState.instance.plotProperties.value;
    _xMinCtrl.text = p.xMin?.toString() ?? '';
    _xMaxCtrl.text = p.xMax?.toString() ?? '';
    _yMinCtrl.text = p.yMin?.toString() ?? '';
    _yMaxCtrl.text = p.yMax?.toString() ?? '';
  }

  void _onPropsChanged() {
    if (!_xMinFocus.hasFocus) _xMinCtrl.text = ProjectState.instance.plotProperties.value.xMin?.toString() ?? '';
    if (!_xMaxFocus.hasFocus) _xMaxCtrl.text = ProjectState.instance.plotProperties.value.xMax?.toString() ?? '';
    if (!_yMinFocus.hasFocus) _yMinCtrl.text = ProjectState.instance.plotProperties.value.yMin?.toString() ?? '';
    if (!_yMaxFocus.hasFocus) _yMaxCtrl.text = ProjectState.instance.plotProperties.value.yMax?.toString() ?? '';
  }

  void _onFocusChange(FocusNode fn, TextEditingController ctrl, void Function(double?) setter) {
    if (!fn.hasFocus) {
      setter(ctrl.text.trim().isEmpty ? null : double.tryParse(ctrl.text));
    }
  }

  void _commit(TextEditingController ctrl, double? val, PlotProperties Function(PlotProperties, double?) update) {
    final props = ProjectState.instance.plotProperties.value;
    ProjectState.instance.updatePlotProperties(update(props, val));
    ctrl.text = val?.toString() ?? '';
  }

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
          Expanded(
            child: ValueListenableBuilder<PlotProperties>(
              valueListenable: ProjectState.instance.plotProperties,
              builder: (context, props, child) {
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSectionHeader('Axes'),
                    const SizedBox(height: 12),
                    _buildAxisRangeProperty(
                      'X-Axis',
                      _xMinCtrl, _xMinFocus,
                      _xMaxCtrl, _xMaxFocus,
                    ),
                    const SizedBox(height: 16),
                    _buildAxisRangeProperty(
                      'Y-Axis',
                      _yMinCtrl, _yMinFocus,
                      _yMaxCtrl, _yMaxFocus,
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader('Labels'),
                    const SizedBox(height: 12),
                    _buildTextProperty('X-Axis Label', props.xAxisLabel, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(xAxisLabel: val));
                    }),
                    const SizedBox(height: 16),
                    _buildTextProperty('Y-Axis Label', props.yAxisLabel, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(yAxisLabel: val));
                    }),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Aspect Ratio'),
                    const SizedBox(height: 12),
                    _buildDropdownProperty(
                      'Aspect Ratio',
                      props.aspectRatio,
                      {
                        null: 'Free',
                        1.0: '1:1',
                        1.5: '3:2',
                        1.3333: '4:3',
                        1.7777: '16:9',
                      },
                      (val) {
                        ProjectState.instance.updatePlotProperties(props.copyWith(aspectRatio: () => val));
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Appearance'),
                    const SizedBox(height: 12),
                    _buildColorProperty(context, 'Line Color', props),
                    const SizedBox(height: 16),
                    _buildSliderProperty(context, 'Thickness', props.lineThickness, 1.0, 10.0, (val) {
                      ProjectState.instance.updatePlotProperties(props.copyWith(lineThickness: val));
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

  Widget _buildAxisRangeProperty(
    String label,
    TextEditingController minCtrl, FocusNode minFocus,
    TextEditingController maxCtrl, FocusNode maxFocus,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildNumberField(minCtrl, minFocus)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('-', style: TextStyle(color: PrimeTheme.textSecondary)),
            ),
            Expanded(child: _buildNumberField(maxCtrl, maxFocus)),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberField(TextEditingController controller, FocusNode focusNode) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          hintText: 'Auto',
          hintStyle: TextStyle(fontSize: 12, color: PrimeTheme.textSecondary.withValues(alpha: 0.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          filled: true,
          fillColor: PrimeTheme.backgroundDark.withValues(alpha: 0.5),
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

  Widget _buildDropdownProperty(String label, double? value, Map<double?, String> options, ValueChanged<double?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        Container(
          height: 30, // Increased height
          padding: const EdgeInsets.symmetric(horizontal: 12), // Increased padding
          decoration: BoxDecoration(
            color: PrimeTheme.backgroundDark,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: PrimeTheme.borderSide),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<double?>(
              value: value,
              icon: const Icon(Icons.arrow_drop_down, size: 18, color: PrimeTheme.textSecondary), // Slightly larger icon
              dropdownColor: PrimeTheme.backgroundDark,
              style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
              onChanged: onChanged,
              items: options.entries.map((entry) {
                return DropdownMenuItem<double?>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
