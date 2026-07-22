// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
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
class _GraphInspector extends StatefulWidget {
  final String nodeId;
  const _GraphInspector({required this.nodeId});
  @override
  State<_GraphInspector> createState() => _GraphInspectorState();
}

class _GraphInspectorState extends State<_GraphInspector> {
  final _xMinCtrl = TextEditingController();
  final _xMaxCtrl = TextEditingController();
  final _yMinCtrl = TextEditingController();
  final _yMaxCtrl = TextEditingController();
  final _xMinFocus = FocusNode();
  final _xMaxFocus = FocusNode();
  final _yMinFocus = FocusNode();
  final _yMaxFocus = FocusNode();
  GraphProperties? _props;

  @override
  void initState() {
    super.initState();
    _xMinFocus.addListener(_onXMinFocusChange);
    _xMaxFocus.addListener(_onXMaxFocusChange);
    _yMinFocus.addListener(_onYMinFocusChange);
    _yMaxFocus.addListener(_onYMaxFocusChange);
  }

  @override
  void dispose() {
    for (final c in [_xMinCtrl, _xMaxCtrl, _yMinCtrl, _yMaxCtrl]) { c.dispose(); }
    for (final f in [_xMinFocus, _xMaxFocus, _yMinFocus, _yMaxFocus]) { f.dispose(); }
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }

  double? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _onXMinFocusChange() {
    if (_xMinFocus.hasFocus) return;
    final p = _props;
    if (p == null) return;
    final v = _parse(_xMinCtrl.text);
    if (_xMinCtrl.text.trim().isNotEmpty && v == null) {
      _xMinCtrl.text = _fmt(p.xMin);
      return;
    }
    if (v == p.xMin) return;
    ProjectState.instance.updateGraphProperties(widget.nodeId, GraphProperties(
      xMin: v, xMax: p.xMax, yMin: p.yMin, yMax: p.yMax,
      xVisible: p.xVisible, yVisible: p.yVisible,
      xScale: p.xScale, yScale: p.yScale,
      xLabel: p.xLabel, yLabel: p.yLabel,
      aspectRatio: p.aspectRatio,
      showGrid: p.showGrid, showLegend: p.showLegend,
      legendPosition: p.legendPosition,
    ));
  }

  void _onXMaxFocusChange() {
    if (_xMaxFocus.hasFocus) return;
    final p = _props;
    if (p == null) return;
    final v = _parse(_xMaxCtrl.text);
    if (_xMaxCtrl.text.trim().isNotEmpty && v == null) {
      _xMaxCtrl.text = _fmt(p.xMax);
      return;
    }
    if (v == p.xMax) return;
    ProjectState.instance.updateGraphProperties(widget.nodeId, GraphProperties(
      xMin: p.xMin, xMax: v, yMin: p.yMin, yMax: p.yMax,
      xVisible: p.xVisible, yVisible: p.yVisible,
      xScale: p.xScale, yScale: p.yScale,
      xLabel: p.xLabel, yLabel: p.yLabel,
      aspectRatio: p.aspectRatio,
      showGrid: p.showGrid, showLegend: p.showLegend,
      legendPosition: p.legendPosition,
    ));
  }

  void _onYMinFocusChange() {
    if (_yMinFocus.hasFocus) return;
    final p = _props;
    if (p == null) return;
    final v = _parse(_yMinCtrl.text);
    if (_yMinCtrl.text.trim().isNotEmpty && v == null) {
      _yMinCtrl.text = _fmt(p.yMin);
      return;
    }
    if (v == p.yMin) return;
    ProjectState.instance.updateGraphProperties(widget.nodeId, GraphProperties(
      xMin: p.xMin, xMax: p.xMax, yMin: v, yMax: p.yMax,
      xVisible: p.xVisible, yVisible: p.yVisible,
      xScale: p.xScale, yScale: p.yScale,
      xLabel: p.xLabel, yLabel: p.yLabel,
      aspectRatio: p.aspectRatio,
      showGrid: p.showGrid, showLegend: p.showLegend,
      legendPosition: p.legendPosition,
    ));
  }

  void _onYMaxFocusChange() {
    if (_yMaxFocus.hasFocus) return;
    final p = _props;
    if (p == null) return;
    final v = _parse(_yMaxCtrl.text);
    if (_yMaxCtrl.text.trim().isNotEmpty && v == null) {
      _yMaxCtrl.text = _fmt(p.yMax);
      return;
    }
    if (v == p.yMax) return;
    ProjectState.instance.updateGraphProperties(widget.nodeId, GraphProperties(
      xMin: p.xMin, xMax: p.xMax, yMin: p.yMin, yMax: v,
      xVisible: p.xVisible, yVisible: p.yVisible,
      xScale: p.xScale, yScale: p.yScale,
      xLabel: p.xLabel, yLabel: p.yLabel,
      aspectRatio: p.aspectRatio,
      showGrid: p.showGrid, showLegend: p.showLegend,
      legendPosition: p.legendPosition,
    ));
  }

  void _syncFromProps(GraphProperties p) {
    if (!_xMinFocus.hasFocus && _xMinCtrl.text != _fmt(p.xMin)) _xMinCtrl.text = _fmt(p.xMin);
    if (!_xMaxFocus.hasFocus && _xMaxCtrl.text != _fmt(p.xMax)) _xMaxCtrl.text = _fmt(p.xMax);
    if (!_yMinFocus.hasFocus && _yMinCtrl.text != _fmt(p.yMin)) _yMinCtrl.text = _fmt(p.yMin);
    if (!_yMaxFocus.hasFocus && _yMaxCtrl.text != _fmt(p.yMax)) _yMaxCtrl.text = _fmt(p.yMax);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GraphProperties?>(
      valueListenable: ProjectState.instance.activeGraphProps,
      builder: (context, props, child) {
        if (props == null) return const SizedBox.shrink();
        _props = props;
        _syncFromProps(props);
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Axes'),
            const SizedBox(height: 12),
            _buildAxisRangeProperty(
              'X-Axis', _xMinCtrl, _xMaxCtrl, _xMinFocus, _xMaxFocus,
            ),
            const SizedBox(height: 8),
            _buildSwitchProperty('X-Axis Visible', props.xVisible, (val) {
              ProjectState.instance.updateGraphProperties(
                widget.nodeId, GraphProperties(
                      xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                      xVisible: val, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                      xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                      showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 8),
            _buildDropdownProperty(
              'X-Axis Scale',
              props.xScale,
              {'Linear': 'Linear', 'Log': 'Log', 'Sqrt': 'Sqrt'},
              (val) {
                ProjectState.instance.updateGraphProperties(
                  widget.nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: val, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
              },
            ),
            const SizedBox(height: 12),
            _buildAxisRangeProperty(
              'Y-Axis', _yMinCtrl, _yMaxCtrl, _yMinFocus, _yMaxFocus,
            ),
            const SizedBox(height: 8),
            _buildSwitchProperty('Y-Axis Visible', props.yVisible, (val) {
              ProjectState.instance.updateGraphProperties(
                widget.nodeId, GraphProperties(
                      xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                      xVisible: props.xVisible, yVisible: val, xScale: props.xScale, yScale: props.yScale,
                      xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                      showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 8),
            _buildDropdownProperty(
              'Y-Axis Scale',
              props.yScale,
              {'Linear': 'Linear', 'Log': 'Log', 'Sqrt': 'Sqrt'},
              (val) {
                ProjectState.instance.updateGraphProperties(
                  widget.nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: val,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Labels'),
            const SizedBox(height: 12),
            _buildTextProperty('X-Axis Label', props.xLabel, (val) {
              ProjectState.instance.updateGraphProperties(
                  widget.nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: val, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 12),
            _buildTextProperty('Y-Axis Label', props.yLabel, (val) {
              ProjectState.instance.updateGraphProperties(
                  widget.nodeId, GraphProperties(
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
                  widget.nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: val,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: props.legendPosition));
              },
            ),
            const SizedBox(height: 12),
            _buildSwitchProperty('Show Grid', props.showGrid, (val) {
              ProjectState.instance.updateGraphProperties(
                  widget.nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: val, showLegend: props.showLegend, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 24),
            _buildSectionHeader('Legend'),
            const SizedBox(height: 12),
            _buildSwitchProperty('Show Legend', props.showLegend, (val) {
              ProjectState.instance.updateGraphProperties(
                widget.nodeId, GraphProperties(
                      xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                      xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                      xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                      showGrid: props.showGrid, showLegend: val, legendPosition: props.legendPosition));
            }),
            const SizedBox(height: 12),
            _buildDropdownProperty(
              'Position',
              props.legendPosition,
              {'Top Left': 'Top Left', 'Top Right': 'Top Right', 'Bottom Left': 'Bottom Left', 'Bottom Right': 'Bottom Right'},
              (val) {
                ProjectState.instance.updateGraphProperties(
                  widget.nodeId, GraphProperties(
                        xMin: props.xMin, xMax: props.xMax, yMin: props.yMin, yMax: props.yMax,
                        xVisible: props.xVisible, yVisible: props.yVisible, xScale: props.xScale, yScale: props.yScale,
                        xLabel: props.xLabel, yLabel: props.yLabel, aspectRatio: props.aspectRatio,
                        showGrid: props.showGrid, showLegend: props.showLegend, legendPosition: val));
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAxisRangeProperty(
    String label,
    TextEditingController minCtrl,
    TextEditingController maxCtrl,
    FocusNode minFocus,
    FocusNode maxFocus,
  ) {
    Widget field(TextEditingController ctrl, FocusNode focus) {
      return SizedBox(
        height: 28,
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Auto',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PrimeTheme.textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: field(minCtrl, minFocus)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('-', style: TextStyle(color: PrimeTheme.textSecondary)),
            ),
            Expanded(child: field(maxCtrl, maxFocus)),
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
              {'Full': 'Full', 'Dashed': 'Dashed', 'Dotted': 'Dotted', 'Dash-Dot': 'Dash-Dot'},
              (val) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: val, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: props.markerColor));
              },
            ),
            const SizedBox(height: 8),
            _buildSwitchProperty('Line Visible', props.lineVisible, (val) {
              ProjectState.instance.updateTableProperties(
                nodeId, TableProperties(
                      legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                      lineVisible: val, markerType: props.markerType, markerVisible: props.markerVisible,
                      lineColor: props.lineColor, markerColor: props.markerColor));
            }),
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
              {'Circle': 'Circle', 'Square': 'Square', 'Cross': 'Cross', 'X': 'X', 'Triangle up': 'Triangle up', 'Triangle down': 'Triangle down'},
              (val) {
                ProjectState.instance.updateTableProperties(
                  nodeId, TableProperties(
                        legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                        lineVisible: props.lineVisible, markerType: val, markerVisible: props.markerVisible,
                        lineColor: props.lineColor, markerColor: props.markerColor));
              },
            ),
            const SizedBox(height: 8),
            _buildSwitchProperty('Marker Visible', props.markerVisible, (val) {
              ProjectState.instance.updateTableProperties(
                nodeId, TableProperties(
                      legendDisplayName: props.legendDisplayName, lineStyle: props.lineStyle, lineThickness: props.lineThickness,
                      lineVisible: props.lineVisible, markerType: props.markerType, markerVisible: val,
                      lineColor: props.lineColor, markerColor: props.markerColor));
            }),
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

final Map<ColorSwatch<Object>, String> _customSwatches = <ColorSwatch<Object>, String>{
  ColorTools.createPrimarySwatch(const Color(0xFF00C3FF)): 'Cyan',
  ColorTools.createPrimarySwatch(const Color(0xFFFF5252)): 'Red',
  ColorTools.createPrimarySwatch(const Color(0xFF69F0AE)): 'Green',
  ColorTools.createPrimarySwatch(const Color(0xFFFFD740)): 'Yellow',
  ColorTools.createPrimarySwatch(const Color(0xFFE040FB)): 'Purple',
  ColorTools.createPrimarySwatch(const Color(0xFFFFFFFF)): 'White',
  ColorTools.createPrimarySwatch(const Color(0xFF90A4AE)): 'Grey',
  ColorTools.createPrimarySwatch(const Color(0xFFFF6E40)): 'Orange',
};

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
        onTap: () async {
          final Color picked = await showColorPickerDialog(
            context,
            color,
            title: Text('Select $label',
                style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 16)),
            width: 40,
            height: 40,
            borderRadius: 20,
            spacing: 5,
            runSpacing: 5,
            enableOpacity: true,
            wheelDiameter: 180,
            showColorCode: true,
            colorCodeReadOnly: false,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
              ColorPickerType.both: false,
              ColorPickerType.bw: false,
            },
            customColorSwatchesAndNames: _customSwatches,
            actionButtons: const ColorPickerActionButtons(
              okButton: false,
              closeButton: false,
            ),
            constraints: const BoxConstraints(
              minHeight: 460,
              minWidth: 420,
              maxWidth: 420,
            ),
          );
          if (picked.toARGB32() != color.toARGB32()) {
            final int argb = picked.toARGB32();
            final String hexStr = (argb & 0xFF000000) == 0xFF000000
                ? '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                : '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
            onChanged(hexStr);
          }
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
