// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/project.dart';
import '../../src/rust/api/properties.dart';

class PropertyInspector extends StatefulWidget {
  const PropertyInspector({super.key});
  @override
  State<PropertyInspector> createState() => _PropertyInspectorState();
}

class _PropertyInspectorState extends State<PropertyInspector> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: PrimeTheme.panelBackground,
      child: ValueListenableBuilder<String?>(
        valueListenable: ProjectState.instance.selectedProjectNodeId,
        builder: (context, selectedId, child) {
          if (selectedId == null) {
            return const Center(
                child: Text('No selection',
                    style: TextStyle(color: PrimeTheme.textSecondary)));
          }
          final root = ProjectState.instance.projectTree.value;
          if (root == null) return const SizedBox.shrink();
          final node = ProjectState.instance.findNodeById(root, selectedId);
          if (node == null) return const SizedBox.shrink();

          switch (node.nodeType) {
            case NodeType.folder:
              return _FolderInspector(nodeId: selectedId);
            case NodeType.plot:
              return _GraphInspector(nodeId: selectedId);
            case NodeType.dataset:
              return _TableInspector(nodeId: selectedId);
            case NodeType.function:
              return _FunctionInspector(nodeId: selectedId);
            case NodeType.shape:
              return _ShapeInspector(nodeId: selectedId);
          }
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Folder Inspector
// -----------------------------------------------------------------------------
class _FolderInspector extends StatelessWidget {
  final String nodeId;
  const _FolderInspector({required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FolderProperties?>(
      valueListenable: ProjectState.instance.activeFolderProps,
      builder: (context, props, child) {
        if (props == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Information'),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: props.information)
                ..selection = TextSelection.collapsed(offset: props.information.length),
              style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
                isDense: true,
              ),
              onChanged: (val) {
                ProjectState.instance.updateFolderProperties(
                    nodeId, FolderProperties(information: val));
              },
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Function Inspector
// -----------------------------------------------------------------------------
class _FunctionInspector extends StatelessWidget {
  final String nodeId;
  const _FunctionInspector({required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FunctionProperties?>(
      valueListenable: ProjectState.instance.activeFunctionProps,
      builder: (context, props, child) {
        if (props == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Equation'),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: props.equation)
                ..selection = TextSelection.collapsed(offset: props.equation.length),
              style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
                isDense: true,
              ),
              onChanged: (val) {
                ProjectState.instance.updateFunctionProperties(
                    nodeId, FunctionProperties(equation: val));
              },
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Shape Inspector
// -----------------------------------------------------------------------------
class _ShapeInspector extends StatelessWidget {
  final String nodeId;
  const _ShapeInspector({required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShapeProperties?>(
      valueListenable: ProjectState.instance.activeShapeProps,
      builder: (context, props, child) {
        if (props == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Shape'),
            const SizedBox(height: 12),
            _buildDropdownProperty(
              'Type',
              props.shapeType,
              {'Rectangle': 'Rectangle', 'Ellipse': 'Ellipse', 'Line': 'Line'},
              (val) {
                ProjectState.instance.updateShapeProperties(
                    nodeId, ShapeProperties(shapeType: val));
              },
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Graph Inspector
// -----------------------------------------------------------------------------
class _GraphInspector extends StatelessWidget {
  final String nodeId;
  const _GraphInspector({required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GraphProperties?>(
      valueListenable: ProjectState.instance.activeGraphProps,
      builder: (context, props, child) {
        if (props == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Axes Range'),
            const SizedBox(height: 12),
            _buildAxisRangeProperty(
              'X-Axis',
              props.xMin,
              props.xMax,
              (min, max) {
                ProjectState.instance.updateGraphProperties(
                    nodeId,
                    GraphProperties(
                        xMin: min,
                        xMax: max,
                        yMin: props.yMin,
                        yMax: props.yMax,
                        xVisible: props.xVisible,
                        yVisible: props.yVisible,
                        xScale: props.xScale,
                        yScale: props.yScale,
                        xLabel: props.xLabel,
                        yLabel: props.yLabel,
                        aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid,
                        showLegend: props.showLegend,
                        legendPosition: props.legendPosition));
              },
            ),
            const SizedBox(height: 12),
            _buildAxisRangeProperty(
              'Y-Axis',
              props.yMin,
              props.yMax,
              (min, max) {
                ProjectState.instance.updateGraphProperties(
                    nodeId,
                    GraphProperties(
                        xMin: props.xMin,
                        xMax: props.xMax,
                        yMin: min,
                        yMax: max,
                        xVisible: props.xVisible,
                        yVisible: props.yVisible,
                        xScale: props.xScale,
                        yScale: props.yScale,
                        xLabel: props.xLabel,
                        yLabel: props.yLabel,
                        aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid,
                        showLegend: props.showLegend,
                        legendPosition: props.legendPosition));
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Labels'),
            const SizedBox(height: 12),
            _buildTextProperty('X-Axis Label', props.xLabel, (val) {
              ProjectState.instance.updateGraphProperties(
                  nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: val, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 12),
            _buildTextProperty('Y-Axis Label', props.yLabel, (val) {
              ProjectState.instance.updateGraphProperties(
                  nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: val, aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 24),
            _buildSectionHeader('Settings'),
            const SizedBox(height: 12),
            _buildDropdownProperty(
              'Aspect Ratio',
              props.aspectRatio,
              {null: 'Free', 1.0: '1:1', 1.5: '3:2', 1.3333: '4:3', 1.7777: '16:9'},
              (val) {
                ProjectState.instance.updateGraphProperties(
                  nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: val,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
              },
            ),
            const SizedBox(height: 12),
            _buildSwitchProperty('Show Grid', props.showGrid, (val) {
              ProjectState.instance.updateGraphProperties(
                  nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: val, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
          ],
        );
      },
    );
  }

  Widget _buildAxisRangeProperty(
      String label, double? minVal, double? maxVal, Function(double?, double?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: TextEditingController(text: minVal?.toString() ?? '')
                    ..selection = TextSelection.collapsed(offset: (minVal?.toString() ?? '').length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Auto',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onChanged: (val) {
                    final d = val.trim().isEmpty ? null : double.tryParse(val);
                    onChanged(d, maxVal);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('-', style: TextStyle(color: PrimeTheme.textSecondary)),
            ),
            Expanded(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: TextEditingController(text: maxVal?.toString() ?? '')
                    ..selection = TextSelection.collapsed(offset: (maxVal?.toString() ?? '').length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Auto',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onChanged: (val) {
                    final d = val.trim().isEmpty ? null : double.tryParse(val);
                    onChanged(minVal, d);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Table Inspector
// -----------------------------------------------------------------------------
class _TableInspector extends StatelessWidget {
  final String nodeId;
  const _TableInspector({required this.nodeId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TableProperties?>(
      valueListenable: ProjectState.instance.activeTableProps,
      builder: (context, props, child) {
        if (props == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Legend'),
            const SizedBox(height: 12),
            _buildTextProperty('Display Name', props.legendDisplayName, (val) {
              ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: val, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: props.markerColor));
            }),
            const SizedBox(height: 24),
            _buildSectionHeader('Appearance'),
            const SizedBox(height: 12),
            _buildDropdownProperty(
              'Line Style',
              props.lineStyle,
              {'Full': 'Full', 'Dashed': 'Dashed', 'Dotted': 'Dotted'},
              (val) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: val, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: props.markerColor));
              },
            ),
            const SizedBox(height: 12),
            _buildColorPropertyHex(context, 'Line Color', props.lineColor, (c) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: props.markerVisible,
                        lineColor: c, markerColor: props.markerColor));
            }),
            const SizedBox(height: 16),
            _buildSliderProperty(context, 'Line Thickness', props.lineThickness, 1.0, 10.0, (val) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: val,
                        lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: props.markerColor));
            }),
            const SizedBox(height: 24),
            _buildDropdownProperty(
              'Marker Type',
              props.markerType,
              {'Circle': 'Circle', 'Square': 'Square', 'Triangle': 'Triangle', 'None': 'None'},
              (val) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: val, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: props.markerColor));
              },
            ),
            const SizedBox(height: 12),
            _buildColorPropertyHex(context, 'Marker Color', props.markerColor, (c) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: c));
            }),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Common Builders
// -----------------------------------------------------------------------------

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

Widget _buildTextProperty(String label, String value, ValueChanged<String> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
      const SizedBox(height: 6),
      SizedBox(
        height: 28,
        child: TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
          style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

Widget _buildDropdownProperty<T>(
    String label, T value, Map<T, String> options, ValueChanged<T> onChanged) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
      Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: PrimeTheme.backgroundDark,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: PrimeTheme.borderSide),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            dropdownColor: PrimeTheme.backgroundDark,
            icon: const Icon(Icons.arrow_drop_down, color: PrimeTheme.textSecondary, size: 16),
            style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
            onChanged: (v) {
              if (v != null || options.containsKey(null)) {
                onChanged(v as T);
              }
            },
            items: options.entries.map((e) {
              return DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
          ),
        ),
      ),
    ],
  );
}

Widget _buildSwitchProperty(String label, bool value, ValueChanged<bool> onChanged) {
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
        ),
      ),
    ],
  );
}

Widget _buildColorPropertyHex(BuildContext context, String label, String hexColor, ValueChanged<String> onChanged) {
  Color color = Colors.white;
  try {
    color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (e) {
    // fallback
  }
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
      InkWell(
        onTap: () {
          // simple color picker mock - extending this is for future stages
          final colors = ['#00C3FF', '#FF5252', '#69F0AE', '#FFD740', '#E040FB', '#FFFFFF'];
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: PrimeTheme.panelBackground,
              title: const Text('Select Color', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 14)),
              content: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((c) => InkWell(
                  onTap: () {
                    onChanged(c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(color: hexColor == c ? Colors.white : Colors.transparent, width: 2),
                    ),
                  ),
                )).toList(),
              ),
            ),
          );
        },
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
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
