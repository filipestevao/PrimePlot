// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/project.dart';
import '../../src/rust/api/properties.dart';
import '../../src/rust/api/palettes.dart';
import '../../src/rust/api/functions.dart';
import '../components/latex_text_field.dart';
import '../components/prime_color_picker.dart';
import '../components/prime_number_field.dart';
import '../components/prime_select.dart';
import '../components/prime_switch.dart';
import '../components/prime_text_field.dart';
import '../components/property_row.dart';
import '../components/property_section.dart';

extension GraphPropertiesExt on GraphProperties {
  GraphProperties copyWith({
    double? Function()? xMin,
    double? Function()? xMax,
    double? Function()? yMin,
    double? Function()? yMax,
    bool? xVisible,
    bool? yVisible,
    String? xScale,
    String? yScale,
    String? xLabel,
    String? yLabel,
    double? Function()? aspectRatio,
    bool? showGrid,
    bool? showLegend,
    String? legendPosition,
  }) {
    return GraphProperties(
      xMin: xMin != null ? xMin() : this.xMin,
      xMax: xMax != null ? xMax() : this.xMax,
      yMin: yMin != null ? yMin() : this.yMin,
      yMax: yMax != null ? yMax() : this.yMax,
      xVisible: xVisible ?? this.xVisible,
      yVisible: yVisible ?? this.yVisible,
      xScale: xScale ?? this.xScale,
      yScale: yScale ?? this.yScale,
      xLabel: xLabel ?? this.xLabel,
      yLabel: yLabel ?? this.yLabel,
      aspectRatio: aspectRatio != null ? aspectRatio() : this.aspectRatio,
      showGrid: showGrid ?? this.showGrid,
      showLegend: showLegend ?? this.showLegend,
      legendPosition: legendPosition ?? this.legendPosition,
    );
  }
}

extension TablePropertiesExt on TableProperties {
  TableProperties copyWith({
    String? legendDisplayName,
    String? lineStyle,
    double? lineThickness,
    bool? lineVisible,
    String? markerType,
    bool? markerVisible,
    String? lineColor,
    String? markerColor,
  }) {
    return TableProperties(
      legendDisplayName: legendDisplayName ?? this.legendDisplayName,
      lineStyle: lineStyle ?? this.lineStyle,
      lineThickness: lineThickness ?? this.lineThickness,
      lineVisible: lineVisible ?? this.lineVisible,
      markerType: markerType ?? this.markerType,
      markerVisible: markerVisible ?? this.markerVisible,
      lineColor: lineColor ?? this.lineColor,
      markerColor: markerColor ?? this.markerColor,
    );
  }
}

extension FunctionPropertiesExt on FunctionProperties {
  FunctionProperties copyWith({
    String? equation,
    String? legendDisplayName,
    double? Function()? xMin,
    double? Function()? xMax,
    BigInt? numSamples,
    String? lineColor,
    double? lineThickness,
    String? lineStyle,
  }) {
    return FunctionProperties(
      equation: equation ?? this.equation,
      legendDisplayName: legendDisplayName ?? this.legendDisplayName,
      xMin: xMin != null ? xMin() : this.xMin,
      xMax: xMax != null ? xMax() : this.xMax,
      numSamples: numSamples ?? this.numSamples,
      lineColor: lineColor ?? this.lineColor,
      lineThickness: lineThickness ?? this.lineThickness,
      lineStyle: lineStyle ?? this.lineStyle,
    );
  }
}

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
              child: Text(
                'No selection',
                style: TextStyle(color: PrimeTheme.textSecondary, fontSize: 12),
              ),
            );
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
          padding: const EdgeInsets.all(10.0),
          children: [
            PropertySection(
              title: 'Folder Information',
              icon: Icons.folder,
              children: [
                PropertyRow(
                  label: 'Description',
                  child: PrimeTextField(
                    value: props.information,
                    hintText: 'Notes or description...',
                    maxLines: 4,
                    onChanged: (val) {
                      ProjectState.instance.updateFolderProperties(
                        nodeId,
                        FolderProperties(information: val),
                      );
                    },
                  ),
                ),
              ],
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

        String? equationError;
        try {
          validateFunctionExpression(expr: props.equation);
        } catch (e) {
          equationError = e.toString().replaceFirst('Exception: ', '');
        }

        return ListView(
          padding: const EdgeInsets.all(10.0),
          children: [
            // Section 1: Identification
            PropertySection(
              title: 'Identification',
              icon: Icons.label,
              children: [
                PropertyRow(
                  label: 'Display Name',
                  child: _buildLatexField(
                    'Display Name',
                    'legendDisplayName',
                    props.legendDisplayName,
                    (val) => ProjectState.instance.updateFunctionProperties(
                      nodeId,
                      props.copyWith(legendDisplayName: val),
                    ),
                  ),
                ),
              ],
            ),

            // Section 2: Definition
            PropertySection(
              title: 'Function Definition',
              icon: Icons.functions,
              children: [
                PropertyRow(
                  label: 'Equation',
                  child: PrimeTextField(
                    value: props.equation,
                    hintText: 'f(x) = sin(x)',
                    onChanged: (val) {
                      ProjectState.instance.updateFunctionProperties(
                        nodeId,
                        props.copyWith(equation: val),
                      );
                    },
                  ),
                ),
                if (equationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 13,
                          color: Color(0xFFF87171),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            equationError,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFF87171),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Section 3: Domain (local override; Auto follows the data
            // envelope, or [-10, 10] with no datasets — never the viewport)
            PropertySection(
              title: 'Domain',
              icon: Icons.horizontal_rule,
              children: [
                PropertyRow(
                  label: 'X Range',
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimeNumberField(
                          value: props.xMin,
                          prefixText: 'Min: ',
                          allowAuto: true,
                          onChanged: (val) {
                            ProjectState.instance.updateFunctionProperties(
                              nodeId,
                              props.copyWith(xMin: () => val),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: PrimeNumberField(
                          value: props.xMax,
                          prefixText: 'Max: ',
                          allowAuto: true,
                          onChanged: (val) {
                            ProjectState.instance.updateFunctionProperties(
                              nodeId,
                              props.copyWith(xMax: () => val),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'Samples',
                  child: PrimeNumberField(
                    value: props.numSamples.toDouble(),
                    step: 500,
                    min: 10,
                    max: 100000,
                    precision: 0,
                    onChanged: (val) {
                      if (val != null) {
                        ProjectState.instance.updateFunctionProperties(
                          nodeId,
                          props.copyWith(
                            numSamples: BigInt.from(val.round()),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            // Section 4: Line Style
            PropertySection(
              title: 'Line Style',
              icon: Icons.timeline,
              children: [
                PropertyRow(
                  label: 'Line Pattern',
                  child: PrimeSelect<String>(
                    value: props.lineStyle,
                    options: const {
                      'Solid': 'Solid (────)',
                      'Dashed': 'Dashed (── ──)',
                      'Dotted': 'Dotted (••••)',
                      'Dash-Dot': 'Dash-Dot (── • ──)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateFunctionProperties(
                        nodeId,
                        props.copyWith(lineStyle: val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Line Color',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeColorPicker(
                      hexColor: props.lineColor,
                      label: 'Line Color',
                      onChanged: (c) {
                        ProjectState.instance.updateFunctionProperties(
                          nodeId,
                          props.copyWith(lineColor: c),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Thickness',
                  child: Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: PrimeTheme.primaryAccent,
                            inactiveTrackColor: PrimeTheme.borderSide,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: props.lineThickness.clamp(0.5, 10.0),
                            min: 0.5,
                            max: 10.0,
                            onChanged: (val) {
                              ProjectState.instance.updateFunctionProperties(
                                nodeId,
                                props.copyWith(lineThickness: val),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 58,
                        child: PrimeNumberField(
                          value: props.lineThickness,
                          step: 0.5,
                          min: 0.5,
                          max: 20.0,
                          precision: 1,
                          onChanged: (val) {
                            if (val != null) {
                              ProjectState.instance.updateFunctionProperties(
                                nodeId,
                                props.copyWith(lineThickness: val),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLatexField(
    String label,
    String field,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final state = ProjectState.instance;
    final useLatex = state.getLatexMode(nodeId, field);
    return LatexTextField(
      label: label,
      value: value,
      onChanged: onChanged,
      useLatex: useLatex,
      onLatexToggle: () => state.toggleLatexMode(nodeId, field),
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
          padding: const EdgeInsets.all(10.0),
          children: [
            PropertySection(
              title: 'Shape Settings',
              icon: Icons.category,
              children: [
                PropertyRow(
                  label: 'Shape Type',
                  child: PrimeSelect<String>(
                    value: props.shapeType,
                    options: const {
                      'Rectangle': 'Rectangle',
                      'Ellipse': 'Ellipse',
                      'Line': 'Line',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateShapeProperties(
                        nodeId,
                        ShapeProperties(shapeType: val),
                      );
                    },
                  ),
                ),
              ],
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
          padding: const EdgeInsets.all(10.0),
          children: [
            // Section 1: Axes & Scales
            PropertySection(
              title: 'Axes & Scales',
              icon: Icons.stacked_line_chart,
              children: [
                PropertyRow(
                  label: 'X Range',
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimeNumberField(
                          value: props.xMin,
                          prefixText: 'Min: ',
                          allowAuto: true,
                          onChanged: (val) {
                            ProjectState.instance.updateGraphProperties(
                              nodeId,
                              props.copyWith(xMin: () => val),
                              isHomeUpdate: true,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: PrimeNumberField(
                          value: props.xMax,
                          prefixText: 'Max: ',
                          allowAuto: true,
                          onChanged: (val) {
                            ProjectState.instance.updateGraphProperties(
                              nodeId,
                              props.copyWith(xMax: () => val),
                              isHomeUpdate: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'X Visible',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.xVisible,
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(xVisible: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'X Scale',
                  child: PrimeSelect<String>(
                    value: props.xScale,
                    options: const {
                      'Linear': 'Linear',
                      'Log': 'Logarithmic (Log10)',
                      'Sqrt': 'Square Root (√x)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(xScale: val),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(height: 1, thickness: 0.5, color: PrimeTheme.borderSide),
                const SizedBox(height: 6),
                PropertyRow(
                  label: 'Y Range',
                  child: Row(
                    children: [
                      Expanded(
                        child: PrimeNumberField(
                          value: props.yMin,
                          prefixText: 'Min: ',
                          allowAuto: true,
                          onChanged: (val) {
                            ProjectState.instance.updateGraphProperties(
                              nodeId,
                              props.copyWith(yMin: () => val),
                              isHomeUpdate: true,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: PrimeNumberField(
                          value: props.yMax,
                          prefixText: 'Max: ',
                          allowAuto: true,
                          onChanged: (val) {
                            ProjectState.instance.updateGraphProperties(
                              nodeId,
                              props.copyWith(yMax: () => val),
                              isHomeUpdate: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'Y Visible',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.yVisible,
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(yVisible: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Y Scale',
                  child: PrimeSelect<String>(
                    value: props.yScale,
                    options: const {
                      'Linear': 'Linear',
                      'Log': 'Logarithmic (Log10)',
                      'Sqrt': 'Square Root (√y)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(yScale: val),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Section 2: Labels & Titles
            PropertySection(
              title: 'Labels & Titles',
              icon: Icons.subtitles,
              children: [
                PropertyRow(
                  label: 'X-Axis Label',
                  child: _buildLatexField(
                    'X-Axis Label',
                    'xLabel',
                    props.xLabel,
                    (val) => ProjectState.instance.updateGraphProperties(
                      nodeId,
                      props.copyWith(xLabel: val),
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Y-Axis Label',
                  child: _buildLatexField(
                    'Y-Axis Label',
                    'yLabel',
                    props.yLabel,
                    (val) => ProjectState.instance.updateGraphProperties(
                      nodeId,
                      props.copyWith(yLabel: val),
                    ),
                  ),
                ),
              ],
            ),

            // Section 3: Settings & Grid
            PropertySection(
              title: 'Viewport & Grid',
              icon: Icons.grid_view,
              children: [
                PropertyRow(
                  label: 'Show Grid',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.showGrid,
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(showGrid: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Aspect Ratio',
                  child: PrimeSelect<double?>(
                    value: props.aspectRatio,
                    options: {
                      null: 'Free (Adaptive)',
                      1.0: '1:1 (Square)',
                      1.5: '3:2 (Standard)',
                      1.3333: '4:3 (Classic)',
                      1.7777: '16:9 (Widescreen)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(aspectRatio: () => val),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Section 4: Legend
            PropertySection(
              title: 'Legend',
              icon: Icons.legend_toggle,
              children: [
                PropertyRow(
                  label: 'Show Legend',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.showLegend,
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(showLegend: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Position',
                  child: PrimeSelect<String>(
                    value: props.legendPosition,
                    options: const {
                      'Top Left': 'Top Left',
                      'Top Right': 'Top Right',
                      'Bottom Left': 'Bottom Left',
                      'Bottom Right': 'Bottom Right',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(legendPosition: val),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Section 5: Palette — re-align curve order to a color sequence.
            PropertySection(
              title: 'Palette',
              icon: Icons.palette,
              children: [
                for (final name in listPalettes())
                  _PaletteButton(graphId: nodeId, paletteName: name),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLatexField(
    String label,
    String field,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final state = ProjectState.instance;
    final useLatex = state.getLatexMode(nodeId, field);
    return LatexTextField(
      label: label,
      value: value,
      onChanged: onChanged,
      useLatex: useLatex,
      onLatexToggle: () => state.toggleLatexMode(nodeId, field),
    );
  }
}

/// One palette row: swatch dots + name. Tap re-aligns this graph's curves
/// (in tree order) to the palette sequence, overwriting per-curve colors.
class _PaletteButton extends StatelessWidget {
  final String graphId;
  final String paletteName;
  const _PaletteButton({required this.graphId, required this.paletteName});

  static Color _hex(String hex) {
    var h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    if (v == null) return const Color(0xFF808080);
    return Color(v);
  }

  @override
  Widget build(BuildContext context) {
    List<String> hexes = const [];
    try {
      hexes = paletteColors(palette: paletteName);
    } catch (_) {
      // Leave dots empty; tap will surface the error.
    }
    final dots = hexes.take(6).map((h) => _hex(h)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            final err = ProjectState.instance.applyPalette(
              graphId,
              paletteName,
            );
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Palette failed: $err',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF7F1D1D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: PrimeTheme.searchBarBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PrimeTheme.borderSide),
            ),
            child: Row(
              children: [
                for (var i = 0; i < dots.length; i++)
                  Container(
                    width: 12,
                    height: 12,
                    margin: EdgeInsets.only(
                      right: i == dots.length - 1 ? 0 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: dots[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  paletteName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrimeTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Table (Curve) Inspector
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
          padding: const EdgeInsets.all(10.0),
          children: [
            // Section 1: Identification
            PropertySection(
              title: 'Identification',
              icon: Icons.label,
              children: [
                PropertyRow(
                  label: 'Display Name',
                  child: _buildLatexField(
                    'Display Name',
                    'legendDisplayName',
                    props.legendDisplayName,
                    (val) => ProjectState.instance.updateTableProperties(
                      nodeId,
                      props.copyWith(legendDisplayName: val),
                    ),
                  ),
                ),
              ],
            ),

            // Section 2: Line Style
            PropertySection(
              title: 'Line Style',
              icon: Icons.timeline,
              children: [
                PropertyRow(
                  label: 'Line Visible',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.lineVisible,
                      onChanged: (val) {
                        ProjectState.instance.updateTableProperties(
                          nodeId,
                          props.copyWith(lineVisible: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Line Pattern',
                  child: PrimeSelect<String>(
                    value: props.lineStyle,
                    options: const {
                      'Full': 'Solid (Full)',
                      'Dashed': 'Dashed (── ──)',
                      'Dotted': 'Dotted (••••)',
                      'Dash-Dot': 'Dash-Dot (── • ──)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateTableProperties(
                        nodeId,
                        props.copyWith(lineStyle: val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Line Color',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeColorPicker(
                      hexColor: props.lineColor,
                      label: 'Line Color',
                      onChanged: (c) {
                        ProjectState.instance.updateTableProperties(
                          nodeId,
                          props.copyWith(lineColor: c),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Thickness',
                  child: Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: PrimeTheme.primaryAccent,
                            inactiveTrackColor: PrimeTheme.borderSide,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: props.lineThickness.clamp(0.5, 10.0),
                            min: 0.5,
                            max: 10.0,
                            onChanged: (val) {
                              ProjectState.instance.updateTableProperties(
                                nodeId,
                                props.copyWith(lineThickness: val),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 58,
                        child: PrimeNumberField(
                          value: props.lineThickness,
                          step: 0.5,
                          min: 0.5,
                          max: 20.0,
                          precision: 1,
                          onChanged: (val) {
                            if (val != null) {
                              ProjectState.instance.updateTableProperties(
                                nodeId,
                                props.copyWith(lineThickness: val),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Section 3: Markers
            PropertySection(
              title: 'Markers',
              icon: Icons.scatter_plot,
              children: [
                PropertyRow(
                  label: 'Marker Visible',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.markerVisible,
                      onChanged: (val) {
                        ProjectState.instance.updateTableProperties(
                          nodeId,
                          props.copyWith(markerVisible: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Marker Shape',
                  child: PrimeSelect<String>(
                    value: props.markerType,
                    options: const {
                      'Circle': 'Circle (●)',
                      'Square': 'Square (■)',
                      'Cross': 'Cross (+)',
                      'X': 'X Marker (×)',
                      'Triangle up': 'Triangle Up (▲)',
                      'Triangle down': 'Triangle Down (▼)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateTableProperties(
                        nodeId,
                        props.copyWith(markerType: val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Marker Color',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeColorPicker(
                      hexColor: props.markerColor,
                      label: 'Marker Color',
                      onChanged: (c) {
                        ProjectState.instance.updateTableProperties(
                          nodeId,
                          props.copyWith(markerColor: c),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLatexField(
    String label,
    String field,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final state = ProjectState.instance;
    final useLatex = state.getLatexMode(nodeId, field);
    return LatexTextField(
      label: label,
      value: value,
      onChanged: onChanged,
      useLatex: useLatex,
      onLatexToggle: () => state.toggleLatexMode(nodeId, field),
    );
  }
}
