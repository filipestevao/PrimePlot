// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../core/properties_ext.dart';
import '../../src/rust/api/project.dart';
import '../../src/rust/api/properties.dart';
import '../../src/rust/api/palettes.dart';
import '../../src/rust/api/user_palettes.dart';
import '../../src/rust/api/functions.dart';
import '../components/latex_text_field.dart';
import '../components/prime_color_picker.dart';
import '../components/prime_number_field.dart';
import '../components/prime_select.dart';
import '../components/prime_switch.dart';
import '../components/prime_text_field.dart';
import '../components/property_row.dart';
import '../components/property_section.dart';

/// Min/Max field pair: side-by-side on wide panes, stacked vertically when
/// narrow (prevents Row overflow at small window sizes).
class _MinMaxPair extends StatelessWidget {
  final Widget minField;
  final Widget maxField;
  const _MinMaxPair({required this.minField, required this.maxField});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 150) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              minField,
              const SizedBox(height: 4),
              maxField,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: minField),
            const SizedBox(width: 6),
            Expanded(child: maxField),
          ],
        );
      },
    );
  }
}

class PropertyInspector extends StatefulWidget {  const PropertyInspector({super.key});
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
            return Center(
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

            // Section 3: Domain (explicit range, defaults -10/10)
            PropertySection(
              title: 'Domain',
              icon: Icons.horizontal_rule,
              children: [
                PropertyRow(
                  label: 'X Range',
                  child: _MinMaxPair(
                    minField: PrimeNumberField(
                      value: props.xMin,
                      prefixText: 'Min: ',
                      resetValue: -10.0,
                      onChanged: (val) {
                        ProjectState.instance.updateFunctionProperties(
                          nodeId,
                          props.copyWith(xMin: () => val),
                        );
                      },
                    ),
                    maxField: PrimeNumberField(
                      value: props.xMax,
                      prefixText: 'Max: ',
                      resetValue: 10.0,
                      onChanged: (val) {
                        ProjectState.instance.updateFunctionProperties(
                          nodeId,
                          props.copyWith(xMax: () => val),
                        );
                      },
                    ),
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
    return ValueListenableBuilder<int>(
      valueListenable: state.refreshCanvas,
      builder: (context, _, child) {
        final useLatex = state.getLatexMode(nodeId, field);
        return LatexTextField(
          label: label,
          value: value,
          onChanged: onChanged,
          useLatex: useLatex,
          onLatexToggle: () => state.toggleLatexMode(nodeId, field),
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
                  child: _MinMaxPair(
                    minField: PrimeNumberField(
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
                    maxField: PrimeNumberField(
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
                Divider(height: 1, thickness: 0.5, color: PrimeTheme.borderSide),
                const SizedBox(height: 6),
                PropertyRow(
                  label: 'Y Range',
                  child: _MinMaxPair(
                    minField: PrimeNumberField(
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
                    maxField: PrimeNumberField(
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
                PropertyRow(
                  label: 'Axis Labels Color',
                  child: _ThemeColorRow(
                    value: props.labelColor,
                    label: 'Axis Labels Color',
                    fallback: _autoLabelHexFor(props.backgroundColor),
                    resetTooltip: 'Auto (black/white by page)',
                    presets: const [
                      '#0F172A',
                      '#000000',
                      '#64748B',
                      '#FFFFFF',
                    ],
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(labelColor: () => val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Title Size',
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
                            value: props.titleFontSize.clamp(8.0, 40.0),
                            min: 8.0,
                            max: 40.0,
                            onChanged: (val) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(titleFontSize: val),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 58,
                        child: PrimeNumberField(
                          value: props.titleFontSize,
                          step: 0.5,
                          min: 8.0,
                          max: 40.0,
                          precision: 1,
                          onChanged: (val) {
                            if (val != null) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(titleFontSize: val),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'Numbers Size',
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
                            value: props.tickFontSize.clamp(6.0, 18.0),
                            min: 6.0,
                            max: 18.0,
                            onChanged: (val) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(tickFontSize: val),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 58,
                        child: PrimeNumberField(
                          value: props.tickFontSize,
                          step: 0.5,
                          min: 6.0,
                          max: 18.0,
                          precision: 1,
                          onChanged: (val) {
                            if (val != null) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(tickFontSize: val),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'Number Format',
                  child: PrimeSelect<String>(
                    value: props.numberNotation,
                    options: const {
                      'Auto': 'Auto (Smart)',
                      'Decimal': 'Decimal (Fixed)',
                      'Scientific': 'Scientific (1eX)',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(numberNotation: val),
                      );
                    },
                  ),
                ),
                if (props.numberNotation.toLowerCase() == 'auto')
                  PropertyRow(
                    label: 'Exp. Threshold',
                    child: PrimeSelect<int>(
                      value: props.scientificThreshold,
                      options: const {
                        4: '10⁴ (10,000)',
                        5: '10⁵ (100,000)',
                        6: '10⁶ (1M)',
                        7: '10⁷ (10M)',
                        8: '10⁸ (100M)',
                      },
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(scientificThreshold: val),
                        );
                      },
                    ),
                  ),
                PropertyRow(
                  label: 'X Title Gap',
                  child: PrimeNumberField(
                    value: props.titlePadding,
                    step: 1.0,
                    min: 0.0,
                    max: 80.0,
                    precision: 0,
                    onChanged: (val) {
                      if (val != null) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(titlePadding: val),
                        );
                      }
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Y Title Gap',
                  child: PrimeNumberField(
                    value: props.titlePaddingY,
                    step: 1.0,
                    min: 0.0,
                    max: 80.0,
                    precision: 0,
                    onChanged: (val) {
                      if (val != null) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(titlePaddingY: val),
                        );
                      }
                    },
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
                  label: 'X Divisions',
                  child: PrimeNumberField(
                    value: props.xDivisions?.toDouble(),
                    allowAuto: true,
                    autoLabel: 'Auto (5)',
                    step: 1.0,
                    min: 1.0,
                    max: 30.0,
                    precision: 0,
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(
                          xDivisions: () => val?.round(),
                        ),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Y Divisions',
                  child: PrimeNumberField(
                    value: props.yDivisions?.toDouble(),
                    allowAuto: true,
                    autoLabel: 'Auto (5)',
                    step: 1.0,
                    min: 1.0,
                    max: 30.0,
                    precision: 0,
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(
                          yDivisions: () => val?.round(),
                        ),
                      );
                    },
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
                PropertyRow(
                  label: 'Show Border',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.showBorder,
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(showBorder: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Chart Background',
                  child: _ThemeColorRow(
                    value: props.backgroundColor,
                    label: 'Chart Background',
                    fallback: '#FFFFFF',
                    resetTooltip: 'Default white',
                    presets: const [
                      '#FFFFFF',
                      '#F8FAFC',
                      '#E2E8F0',
                      '#000000',
                    ],
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(backgroundColor: () => val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Grid Color',
                  child: _ThemeColorRow(
                    value: props.gridColor,
                    label: 'Grid Color',
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(gridColor: () => val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Axes Color',
                  child: _ThemeColorRow(
                    value: props.axisColor,
                    label: 'Axes Color',
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(axisColor: () => val),
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
                      'Outside Right': 'Outside Right',
                    },
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(legendPosition: val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Text Size',
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
                            value: props.legendFontSize.clamp(8.0, 24.0),
                            min: 8.0,
                            max: 24.0,
                            onChanged: (val) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(legendFontSize: val),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 58,
                        child: PrimeNumberField(
                          value: props.legendFontSize,
                          step: 0.5,
                          min: 8.0,
                          max: 24.0,
                          precision: 1,
                          onChanged: (val) {
                            if (val != null) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(legendFontSize: val),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'Opacity',
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
                            value: props.legendOpacity.clamp(0.0, 1.0),
                            min: 0.0,
                            max: 1.0,
                            onChanged: (val) {
                              ProjectState.instance.updateGraphProperties(
                                nodeId,
                                props.copyWith(legendOpacity: val),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 38,
                        child: Text(
                          '${(props.legendOpacity * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            color: PrimeTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PropertyRow(
                  label: 'Show Border',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimeSwitch(
                      value: props.legendShowBorder,
                      onChanged: (val) {
                        ProjectState.instance.updateGraphProperties(
                          nodeId,
                          props.copyWith(legendShowBorder: val),
                        );
                      },
                    ),
                  ),
                ),
                PropertyRow(
                  label: 'Border Color',
                  child: _ThemeColorRow(
                    value: props.legendBorderColor,
                    label: 'Legend Border',
                    fallback: _colorHex(PrimeTheme.borderSide),
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(legendBorderColor: () => val),
                      );
                    },
                  ),
                ),
                PropertyRow(
                  label: 'Background',
                  child: _ThemeColorRow(
                    value: props.legendBackgroundColor,
                    label: 'Legend Background',
                    fallback: _colorHex(PrimeTheme.panelBackground),
                    resetTooltip: 'Match theme panel',
                    presets: const ['#FFFFFF', '#000000', '#00000000'],
                    onChanged: (val) {
                      ProjectState.instance.updateGraphProperties(
                        nodeId,
                        props.copyWith(legendBackgroundColor: () => val),
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
                _PaletteSection(graphId: nodeId),
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
    return ValueListenableBuilder<int>(
      valueListenable: state.refreshCanvas,
      builder: (context, _, child) {
        final useLatex = state.getLatexMode(nodeId, field);
        return LatexTextField(
          label: label,
          value: value,
          onChanged: onChanged,
          useLatex: useLatex,
          onLatexToggle: () => state.toggleLatexMode(nodeId, field),
        );
      },
    );
  }
}

/// Color picker with a "follow theme" reset: a null value renders the
/// theme token and shows no reset affordance.
class _ThemeColorRow extends StatelessWidget {
  final String? value;
  final String label;
  final ValueChanged<String?> onChanged;

  /// Swatch color shown when [value] is null (the resolved default).
  final String fallback;

  /// Tooltip of the reset (↺) button.
  final String resetTooltip;

  /// Optional quick-pick swatches in the picker dialog.
  final List<String>? presets;

  const _ThemeColorRow({
    required this.value,
    required this.label,
    required this.onChanged,
    this.fallback = '#808080',
    this.resetTooltip = 'Follow theme',
    this.presets,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PrimeColorPicker(
          hexColor: value ?? fallback,
          label: label,
          presets: presets,
          onChanged: (c) => onChanged(c),
        ),
        if (value != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: resetTooltip,
            child: InkWell(
              onTap: () => onChanged(null),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.restart_alt,
                  size: 13,
                  color: PrimeTheme.primaryAccent.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hex color from a stored `#RRGGBB`/`#AARRGGBB` string.
Color _paletteHexColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return const Color(0xFF808080);
  return Color(v);
}

/// Hex of a theme token (for color-picker swatch fallbacks).
String _colorHex(Color c) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Hex of the auto axis label color given the chart page background —
/// mirrors the painter: black on light pages, white on dark ones.
String _autoLabelHexFor(String? backgroundHex) {
  final bg = _paletteHexColor(backgroundHex ?? '#FFFFFF');
  final v = bg.computeLuminance() > 0.5 ? 0x000000 : 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

const _paletteFileType = XTypeGroup(
  label: 'Palette JSON',
  extensions: ['json'],
);

void _paletteSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 12)),
      backgroundColor: error ? const Color(0xFF7F1D1D) : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String _paletteFileName(String name) {
  final safe = name.replaceAll(RegExp(r'[^\w\- ]'), '_').trim();
  return safe.isEmpty ? 'palette' : safe;
}

/// Palette list + user-palette actions (save current, import; delete and
/// export per custom row). Owns the list so CRUD refreshes immediately.
class _PaletteSection extends StatefulWidget {
  final String graphId;
  const _PaletteSection({required this.graphId});

  @override
  State<_PaletteSection> createState() => _PaletteSectionState();
}

class _PaletteSectionState extends State<_PaletteSection> {
  List<PaletteInfo> _infos = const [];

  @override
  void initState() {
    super.initState();
    _infos = _loadInfos();
  }

  List<PaletteInfo> _loadInfos() {
    try {
      return listPaletteInfos();
    } catch (_) {
      return const [];
    }
  }

  void _reload() {
    final infos = _loadInfos();
    if (mounted) setState(() => _infos = infos);
  }

  void _apply(String name) {
    final err = ProjectState.instance.applyPalette(widget.graphId, name);
    if (err != null && mounted) {
      _paletteSnack(context, 'Palette failed: $err', error: true);
    }
  }

  Future<void> _confirmDelete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PrimeTheme.panelBackground,
        title: const Text('Delete Palette'),
        content: Text(
          'Delete palette "$name"? Curves already colored with it keep '
          'their colors.',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      deleteUserPalette(name: name);
      _reload();
      if (mounted) _paletteSnack(context, 'Palette "$name" deleted');
    } catch (e) {
      if (mounted) _paletteSnack(context, 'Delete failed: $e', error: true);
    }
  }

  Future<void> _export(String name) async {
    try {
      final loc = await getSaveLocation(
        suggestedName: '${_paletteFileName(name)}.json',
        acceptedTypeGroups: const [_paletteFileType],
      );
      final path = loc?.path;
      if (path == null || path.isEmpty) return;
      exportUserPalette(name: name, path: path);
      if (mounted) _paletteSnack(context, 'Exported "$name" to $path');
    } catch (e) {
      if (mounted) _paletteSnack(context, 'Export failed: $e', error: true);
    }
  }

  Future<void> _import() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [_paletteFileType]);
      final path = file?.path;
      if (path == null || path.isEmpty) return;
      final name = importUserPalette(path: path);
      _reload();
      if (mounted) _paletteSnack(context, 'Imported palette "$name"');
    } catch (e) {
      if (mounted) _paletteSnack(context, 'Import failed: $e', error: true);
    }
  }

  Future<void> _saveCurrent() async {
    List<String> colors;
    try {
      colors = graphCurveColors(graphId: widget.graphId);
    } catch (e) {
      _paletteSnack(context, 'Save failed: $e', error: true);
      return;
    }
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _SavePaletteDialog(colors: colors),
    );
    if (name == null || !mounted) return;
    try {
      createUserPalette(name: name, colors: colors);
      _reload();
      if (mounted) _paletteSnack(context, 'Palette "$name" saved');
    } catch (e) {
      if (mounted) _paletteSnack(context, 'Save failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final builtins = _infos.where((p) => p.builtin);
    final customs = _infos.where((p) => !p.builtin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final info in builtins)
          _PaletteRow(info: info, onApply: () => _apply(info.name)),
        for (final info in customs)
          _PaletteRow(
            info: info,
            onApply: () => _apply(info.name),
            onDelete: () => _confirmDelete(info.name),
            onExport: () => _export(info.name),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                Icons.bookmark_add_outlined,
                'Save current…',
                _saveCurrent,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _actionButton(Icons.file_open_outlined, 'Import…', _import),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: PrimeTheme.searchBarBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: PrimeTheme.borderSide),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: PrimeTheme.textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: PrimeTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One palette row: swatch dots + name. Tap re-aligns this graph's curves
/// (in tree order) to the palette sequence, overwriting per-curve colors.
/// Dots size themselves so all colors fit one line at any pane width.
class _PaletteRow extends StatelessWidget {
  final PaletteInfo info;
  final VoidCallback onApply;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;

  const _PaletteRow({
    required this.info,
    required this.onApply,
    this.onDelete,
    this.onExport,
  });

  static const _dotGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final dots = info.colors.map(_paletteHexColor).toList();
    final nameStyle = TextStyle(fontSize: 12, color: PrimeTheme.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onApply,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: PrimeTheme.searchBarBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PrimeTheme.borderSide),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final n = dots.length;
                final painter = TextPainter(
                  text: TextSpan(text: info.name, style: nameStyle),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                )..layout();
                final nameWidth = math.min(
                  painter.width,
                  constraints.maxWidth * 0.4,
                );
                final iconCount =
                    (onExport != null ? 1 : 0) + (onDelete != null ? 1 : 0);
                final reserved = 8.0 + iconCount * 22.0 + nameWidth;
                final dotArea = constraints.maxWidth - reserved;
                final diameter = n == 0
                    ? 12.0
                    : ((dotArea - _dotGap * (n - 1)) / n).clamp(7.0, 12.0);
                return Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Container(
                        width: diameter,
                        height: diameter,
                        margin: EdgeInsets.only(
                          right: i == n - 1 ? 0 : _dotGap,
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
                    Expanded(
                      child: Text(
                        info.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                    ),
                    if (onExport != null)
                      _rowIcon(Icons.ios_share, 'Export palette', onExport!),
                    if (onDelete != null)
                      _rowIcon(
                        Icons.delete_outline,
                        'Delete palette',
                        onDelete!,
                        danger: true,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowIcon(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: danger
                ? Colors.redAccent.withValues(alpha: 0.8)
                : PrimeTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Name prompt for "Save current as palette…": previews the graph's present
/// curve colors and gates Save on the 2–12 colors the backend accepts.
class _SavePaletteDialog extends StatefulWidget {
  final List<String> colors;
  const _SavePaletteDialog({required this.colors});

  @override
  State<_SavePaletteDialog> createState() => _SavePaletteDialogState();
}

class _SavePaletteDialogState extends State<_SavePaletteDialog> {
  String _name = '';
  bool _nameError = false;

  bool get _validCount =>
      widget.colors.length >= 2 && widget.colors.length <= 12;

  void _submit() {
    FocusScope.of(context).unfocus();
    final name = _name.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PrimeTheme.panelBackground,
      title: const Text('Save as Palette'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final h in widget.colors)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _paletteHexColor(h),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            PrimeTextField(
              value: '',
              hintText: 'Palette name',
              onChanged: (v) => setState(() {
                _name = v;
                _nameError = false;
              }),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 6),
            Text(
              _nameError
                  ? 'Enter a palette name.'
                  : _validCount
                  ? '${widget.colors.length} curve colors, in tree order.'
                  : 'Needs 2–12 curve colors (graph has '
                        '${widget.colors.length}).',
              style: TextStyle(
                fontSize: 10,
                color: (_validCount && !_nameError)
                    ? PrimeTheme.textSecondary
                    : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _validCount ? _submit : null,
          child: const Text('Save'),
        ),
      ],
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
    return ValueListenableBuilder<int>(
      valueListenable: state.refreshCanvas,
      builder: (context, _, child) {
        final useLatex = state.getLatexMode(nodeId, field);
        return LatexTextField(
          label: label,
          value: value,
          onChanged: onChanged,
          useLatex: useLatex,
          onLatexToggle: () => state.toggleLatexMode(nodeId, field),
        );
      },
    );
  }
}
