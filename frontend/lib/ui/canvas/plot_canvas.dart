// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/latex_symbols.dart';
import '../../core/number_format.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/data.dart';
import '../../src/rust/api/functions.dart';
import '../../src/rust/api/project.dart';
import '../../src/rust/api/properties.dart';
import '../../src/rust/api/transforms.dart';
import 'plot_geometry.dart';
import 'plot_viewport.dart';

Color _parseColor(String value, Color fallback) {
  final trimmed = value.trim();
  final rgb = RegExp(
    r'^rgb\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (rgb != null) {
    return Color.fromARGB(
      255,
      int.parse(rgb.group(1)!).clamp(0, 255),
      int.parse(rgb.group(2)!).clamp(0, 255),
      int.parse(rgb.group(3)!).clamp(0, 255),
    );
  }

  var hex = trimmed.replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return fallback;

  try {
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Chart area (inner plot rect) background; default publication white.
Color _chartBackground(GraphProperties? gp) =>
    _parseColor(gp?.backgroundColor ?? '#FFFFFF', const Color(0xFFFFFFFF));

/// Unified axis label color (titles + tick numbers). An explicit override
/// wins; otherwise auto-contrast against the chart page: black on light
/// pages (the white default), white on dark pages.
Color _chartLabelColor(GraphProperties? gp) {
  final override = gp?.labelColor;
  if (override != null) return _parseColor(override, const Color(0xFF000000));
  return _chartBackground(gp).computeLuminance() > 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}

/// Legend text size in logical pixels (inspector range).
double _legendFontSize(GraphProperties? gp) =>
    (gp?.legendFontSize ?? 11.0).clamp(8.0, 24.0);

/// Legend box geometry for the current font size; shared by the painter
/// (drawing) and the canvas (outside-legend margin reservation) so the two
/// can never disagree.
class _LegendLayout {
  final double padding;
  final double rowHeight;
  final double swatchWidth;
  final double boxWidth;
  final double boxHeight;

  const _LegendLayout({
    required this.padding,
    required this.rowHeight,
    required this.swatchWidth,
    required this.boxWidth,
    required this.boxHeight,
  });
}

_LegendLayout _legendLayout(List<String> names, double fontSize) {
  final padding = fontSize * 0.75;
  final rowHeight = fontSize * 1.8;
  final swatchWidth = fontSize * 2.5;
  var maxTextWidth = 0.0;
  final style = TextStyle(fontSize: fontSize);
  for (final name in names) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTextWidth = math.max(maxTextWidth, painter.width);
  }
  return _LegendLayout(
    padding: padding,
    rowHeight: rowHeight,
    swatchWidth: swatchWidth,
    boxWidth: padding * 3 + swatchWidth + maxTextWidth,
    boxHeight: padding * 2 + rowHeight * names.length,
  );
}

bool _legendSeriesVisible(
  int index,
  List<List<double>> xSeries,
  TableProperties props,
) {
  if (index >= xSeries.length || xSeries[index].isEmpty) return false;
  return props.lineVisible || props.markerVisible;
}

String _legendSeriesName(
  int index,
  TableProperties props,
  List<String> tableNames,
  List<String> tableIds,
  Set<String> latexFields,
) {
  final rawName = props.legendDisplayName.trim();
  final tableName = index < tableNames.length
      ? tableNames[index]
      : 'Series ${index + 1}';
  var name = rawName.isEmpty || rawName == 'Series' ? tableName : rawName;
  if (index < tableIds.length &&
      latexFields.contains('legendDisplayName_${tableIds[index]}')) {
    name = substituteSymbols(name);
  }
  return name;
}

/// Right margin reserved by an `Outside Right` legend; 0 otherwise (and for
/// the in-plot positions). Must match the painter's reservation.
double _legendReservedRight(
  GraphProperties? gp,
  List<String> names,
  double fontSize,
) {
  if (!(gp?.showLegend ?? true)) return 0;
  if ((gp?.legendPosition ?? '').trim().toLowerCase() != 'outside right') {
    return 0;
  }
  if (names.isEmpty) return 0;
  final layout = _legendLayout(names, fontSize);
  return layout.boxWidth + layout.padding * 2;
}

class PlotCanvas extends StatelessWidget {
  const PlotCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    // Canvas also tracks the project tree so newly added Function nodes
    // appear without requiring a reselection.
    return ListenableBuilder(
      listenable: Listenable.merge([
        ProjectState.instance.refreshCanvas,
        ProjectState.instance.projectTree,
        ProjectState.instance.exportTransparent,
        ProjectState.instance.isolateActiveCurve,
        ProjectState.instance.selectedProjectNodeId,
        ProjectState.instance.decimalSeparator,
        ProjectState.instance.useThousands,
      ]),
      builder: (context, _) {
        final transparent = ProjectState.instance.exportTransparent.value;
        // Locale fingerprint: forces painter repaint on separator/grouping
        // changes even when every data value is identical.
        final formatKey =
            '${ProjectState.instance.decimalSeparator.value}_${ProjectState.instance.useThousands.value}';
        return ValueListenableBuilder<List<DTODataTable>>(
          valueListenable: ProjectState.instance.activeTables,
          builder: (context, tables, child) {
            DTODataTable? primaryTable;
            if (tables.isEmpty) {
              primaryTable = ProjectState.instance.activeTable.value;
            } else {
              primaryTable = tables.firstWhere(
                (t) => t.columns.length >= 2 && t.columns.first.data.isNotEmpty,
                orElse: () => tables.first,
              );
            }

            // Selection scope: a selected dataset previews all sibling
            // curves of its graph (the selected one highlighted); function
            // selection isolates that function; graph selection shows the
            // whole plot.
            final st = ProjectState.instance;
            final plotId = st.activePlotId;
            final root = st.projectTree.value;
            final selectedId = st.selectedProjectNodeId.value;
            final selectedNode = (root != null && selectedId != null)
                ? st.findNodeById(root, selectedId)
                : null;
            final selectDataset =
                selectedNode?.nodeType == NodeType.dataset;
            final activeTableId = selectDataset ? selectedId : null;
            final selectFunction =
                selectedNode?.nodeType == NodeType.function;
            final plotNode = (root != null && plotId != null)
                ? st.findNodeById(root, plotId)
                : null;
            final functionNodes = plotNode == null || selectDataset
                ? const <ProjectNode>[]
                : plotNode.children.where((c) {
                    if (c.nodeType != NodeType.function) return false;
                    if (selectFunction) return c.id == selectedId;
                    return true;
                  }).toList();

            final toPlotScoped = selectFunction
                ? const <DTODataTable>[]
                : (tables.isNotEmpty
                      ? tables
                      : (primaryTable != null
                            ? [primaryTable]
                            : const <DTODataTable>[]));
            final scopedHasTabular = toPlotScoped.any(
              (t) => t.columns.length >= 2 && t.columns.first.data.isNotEmpty,
            );

            if (!scopedHasTabular && functionNodes.isEmpty) {
              return Center(
                child: Text(
                  'No data available to plot.',
                  style: TextStyle(color: PrimeTheme.textSecondary),
                ),
              );
            }

            return ValueListenableBuilder<GraphProperties?>(
              valueListenable: ProjectState.instance.activeGraphProps,
              builder: (context, graphProps, child) {
                return ValueListenableBuilder<TableProperties?>(
                  valueListenable: ProjectState.instance.activeTableProps,
                  builder: (context, _, child) {
                    final seriesX = <List<double>>[];
                    final seriesY = <List<double>>[];
                    final tableProps = <TableProperties>[];
                    final tableNames = <String>[];
                    final toPlot = toPlotScoped;

                    for (final tableData in toPlot) {
                      DTODataColumn? xCol;
                      DTODataColumn? yCol;
                      for (final col in tableData.columns) {
                        if (col.role == DTOColumnRole.x && xCol == null) xCol = col;
                        if (col.role == DTOColumnRole.y && yCol == null) yCol = col;
                      }
                      xCol ??= tableData.columns[0];
                      yCol ??= tableData.columns.length > 1
                          ? tableData.columns[1]
                          : tableData.columns[0];

                      final xClean = <double>[];
                      final yClean = <double>[];
                      final len = math.min(xCol.data.length, yCol.data.length);
                      for (var i = 0; i < len; i++) {
                        if (!xCol.data[i].isNaN && !yCol.data[i].isNaN) {
                          xClean.add(xCol.data[i]);
                          yClean.add(yCol.data[i]);
                        }
                      }

                      seriesX.add(xClean);
                      seriesY.add(yClean);
                      tableNames.add(tableData.name);

                      try {
                        tableProps.add(getTableProperties(nodeId: tableData.id));
                      } catch (_) {
                        tableProps.add(
                          TableProperties(
                            legendDisplayName: tableData.name,
                            lineStyle: 'Full',
                            lineThickness: 2.5,
                            lineVisible: true,
                            markerType: 'Circle',
                            markerVisible: false,
                            lineColor: '#1F77B4',
                            markerColor: '#000000',
                            legendLatex: false,
                          ),
                        );
                      }
                    }

                    // Analytical `f(x)` curves, sampled live over the view
                    // range (explicit graph limits, else tabular envelope,
                    // else [-10, 10]). Local per-function domain overrides
                    // apply inside Rust. Broken equations are skipped here;
                    // the Function inspector surfaces the error.
                    final functionIds = <String>[];
                    {
                      var lo = -10.0;
                      var hi = 10.0;
                      var fMin = double.infinity;
                      var fMax = double.negativeInfinity;
                      for (final xs in seriesX) {
                        for (final x in xs) {
                          if (x.isFinite) {
                            if (x < fMin) fMin = x;
                            if (x > fMax) fMax = x;
                          }
                        }
                      }
                      if (fMin.isFinite && fMax.isFinite && fMax > fMin) {
                        lo = fMin;
                        hi = fMax;
                      }
                      final gxMin = graphProps?.xMin;
                      final gxMax = graphProps?.xMax;
                      if (gxMin != null &&
                          gxMax != null &&
                          gxMin.isFinite &&
                          gxMax.isFinite &&
                          gxMax > gxMin) {
                        lo = gxMin;
                        hi = gxMax;
                      }
                      for (final fn in functionNodes) {
                        FunctionProperties fprops;
                        try {
                          fprops = getFunctionProperties(nodeId: fn.id);
                        } catch (_) {
                          continue;
                        }
                        List<Point2D> pts;
                        try {
                          pts = getFunctionCurveData(
                            nodeId: fn.id,
                            viewportXMin: lo,
                            viewportXMax: hi,
                          );
                        } catch (_) {
                          continue;
                        }
                        if (pts.isEmpty) continue;
                        seriesX.add([for (final p in pts) p.x]);
                        seriesY.add([for (final p in pts) p.y]);
                        functionIds.add(fn.id);
                        tableProps.add(
                          TableProperties(
                            // Empty/"Series" falls back to the node name in
                            // the legend, mirroring Table curves.
                            legendDisplayName: fprops.legendDisplayName,
                            lineStyle: fprops.lineStyle,
                            lineThickness: fprops.lineThickness,
                            lineVisible: true,
                            markerType: 'None',
                            markerVisible: false,
                            lineColor: fprops.lineColor,
                            markerColor: '#000000',
                            legendLatex: fprops.legendLatex,
                          ),
                        );
                        tableNames.add(fn.name);
                      }
                    }

                    final tableIds = [
                      ...toPlot.map((t) => t.id),
                      // Sampled function ids, aligned with the appended
                      // series, so legend LaTeX toggles resolve like tables.
                      ...functionIds,
                    ];
                    final latexFields = <String>{};
                    final s = ProjectState.instance;
                    final graphNodeId = plotId;
                    if (graphNodeId != null && graphProps != null) {
                      if (s.getLatexMode(graphNodeId, 'xLabel')) {
                        latexFields.add('xLabel');
                      }
                      if (s.getLatexMode(graphNodeId, 'yLabel')) {
                        latexFields.add('yLabel');
                      }
                    }
                    for (final tid in tableIds) {
                      if (s.getLatexMode(tid, 'legendDisplayName')) {
                        latexFields.add('legendDisplayName_$tid');
                      }
                    }
                    final hasLatexLabels = latexFields.contains('xLabel') || latexFields.contains('yLabel');
                    final legendNames = <String>[
                      for (var i = 0; i < tableProps.length; i++)
                        if (_legendSeriesVisible(i, seriesX, tableProps[i]))
                          _legendSeriesName(
                            i,
                            tableProps[i],
                            tableNames,
                            tableIds,
                            latexFields,
                          ),
                    ];
                    final legendReserved = _legendReservedRight(
                      graphProps,
                      legendNames,
                      _legendFontSize(graphProps),
                    );

                    Widget baseCanvas;
                    if (hasLatexLabels && graphProps != null) {
                      final gp = graphProps;
                      baseCanvas = LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(constraints.maxWidth, constraints.maxHeight);
                          final margins =
                              resolvePlotView(
                                xSeries: seriesX,
                                ySeries: seriesY,
                                graphProps: gp,
                                legendReservedRight: legendReserved,
                              )?.margins ??
                              PlotMargins.fallback;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                painter: _MultiSeriesPlotPainter(
                                  xSeries: seriesX,
                                  ySeries: seriesY,
                                  graphProps: gp,
                                  tableProps: tableProps,
                                  tableNames: tableNames,
                                  latexFields: latexFields,
                                  tableIds: tableIds,
                                  formatKey: formatKey,
                                  transparentBackground: transparent,
                                  activeTableId: activeTableId,
                                  legendReservedRight: legendReserved,
                                ),
                                child: Container(),
                              ),
                              ..._buildLatexOverlays(gp, size, latexFields, margins),
                            ],
                          );
                        },
                      );
                    } else {
                      baseCanvas = CustomPaint(
                        painter: _MultiSeriesPlotPainter(
                          xSeries: seriesX,
                          ySeries: seriesY,
                          graphProps: graphProps,
                          tableProps: tableProps,
                          tableNames: tableNames,
                          latexFields: latexFields,
                          tableIds: tableIds,
                          formatKey: formatKey,
                          transparentBackground: transparent,
                          activeTableId: activeTableId,
                          legendReservedRight: legendReserved,
                        ),
                        child: Container(),
                      );
                    }

                    Widget canvas = PlotViewport(
                      xSeries: seriesX,
                      ySeries: seriesY,
                      graphProps: graphProps,
                      plotId: ProjectState.instance.activePlotId,
                      legendReservedRight: legendReserved,
                      child: RepaintBoundary(
                        key: ProjectState.instance.canvasCaptureKey,
                        child: baseCanvas,
                      ),
                    );

                    if (graphProps?.aspectRatio != null) {
                      canvas = Center(
                        child: AspectRatio(
                          aspectRatio: graphProps!.aspectRatio!,
                          child: canvas,
                        ),
                      );
                    }

                    return ClipRRect(
                      child: Stack(
                        children: [
                          canvas,
                          // Curve visibility toggle — only meaningful with a
                          // dataset selected (it targets that curve).
                          if (activeTableId != null)
                            Positioned(
                              top: 6,
                              right: 38,
                              child: ValueListenableBuilder<bool>(
                                valueListenable:
                                    ProjectState.instance.isolateActiveCurve,
                                builder: (context, isolate, _) {
                                  return Tooltip(
                                    message: isolate
                                        ? 'Show all curves (highlight selected)'
                                        : 'Isolate selected curve',
                                    child: InkWell(
                                      onTap: () => ProjectState.instance
                                          .toggleIsolateActiveCurve(),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: PrimeTheme.panelBackground
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isolate
                                                ? PrimeTheme.primaryAccent
                                                : PrimeTheme.borderSide,
                                          ),
                                        ),
                                        child: Icon(
                                          isolate
                                              ? Icons.filter_1
                                              : Icons.layers,
                                          size: 14,
                                          color: isolate
                                              ? PrimeTheme.primaryAccent
                                              : PrimeTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          // Statistics toggle (σ button + S hotkey). Export
                          // lives in the Graph header ··· menu.
                          Positioned(
                            top: 6,
                            right: 6,
                            child: ValueListenableBuilder<bool>(
                              valueListenable:
                                  ProjectState.instance.showStatsHud,
                              builder: (context, show, _) {
                                return Tooltip(
                                  message: show
                                      ? 'Hide series statistics (S)'
                                      : 'Show series statistics (S)',
                                  child: InkWell(
                                    onTap: () => ProjectState.instance
                                        .showStatsHud
                                        .value = !show,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: PrimeTheme.panelBackground
                                            .withValues(alpha: 0.9),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        border: Border.all(
                                          color: show
                                              ? PrimeTheme.primaryAccent
                                              : PrimeTheme.borderSide,
                                        ),
                                      ),
                                      child: Text(
                                        'σ',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: show
                                              ? PrimeTheme.primaryAccent
                                              : PrimeTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                ProjectState.instance.showStatsHud,
                            builder: (context, show, _) {
                              if (!show) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                top: 38,
                                right: 6,
                                child: _StatsPanel(
                                  graphId: ProjectState.instance.activePlotId,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildLatexOverlays(
    GraphProperties graphProps,
    Size size,
    Set<String> latexFields,
    PlotMargins margins,
  ) {
    // Identical style AND metrics to the painter's titles: the overlay box
    // coincides exactly with the painted text box, so `$` toggles glyphs
    // without moving them.
    final labelStyle = TextStyle(
      fontSize: axisTitleSize(graphProps),
      fontWeight: FontWeight.bold,
      color: _chartLabelColor(graphProps),
    );
    final textH = TextPainter(
      text: TextSpan(text: 'Hg', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final overlays = <Widget>[];

    if (latexFields.contains('xLabel')) {
      overlays.add(
        Positioned(
          left: margins.left,
          right: margins.right,
          top: size.height - margins.bottom + margins.xTitleTop,
          height: textH.height,
          child: Center(
            // RichText gets unbounded width inside the (possibly narrow)
            // overlay strip so a title never wraps; it paints outside the
            // box instead.
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: buildLatexSpans(
                    graphProps.xLabel,
                    style: labelStyle,
                    forceLatex: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (latexFields.contains('yLabel')) {
      overlays.add(
        Positioned(
          // Same strip as the painter's rotated title: [axis - gap - lineH].
          left: margins.left - margins.yTitleFromAxis,
          width: textH.height,
          top: margins.top,
          bottom: margins.bottom,
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    children: buildLatexSpans(
                      graphProps.yLabel,
                      style: labelStyle,
                      forceLatex: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return overlays;
  }
}

class _MultiSeriesPlotPainter extends CustomPainter {
  final List<List<double>> xSeries;
  final List<List<double>> ySeries;
  final GraphProperties? graphProps;
  final List<TableProperties> tableProps;
  final List<String> tableNames;
  final Set<String> latexFields;
  final List<String> tableIds;

  /// Locale fingerprint (`<sep>_<grouping>`): forces repaint when number
  /// formatting changes even if all data is identical.
  final String formatKey;

  /// True skips the page fill (transparent figure export).
  final bool transparentBackground;

  /// Selected dataset's table id (when a dataset is selected): its curve is
  /// highlighted (full color, +0.75px stroke) and siblings are dimmed to
  /// 45% alpha for preview. Null = render everything normally.
  final String? activeTableId;

  /// Right-margin space reserved for an `Outside Right` legend; computed by
  /// the canvas from the same layout helper the legend drawing uses.
  final double legendReservedRight;

  _MultiSeriesPlotPainter({
    required this.xSeries,
    required this.ySeries,
    required this.graphProps,
    required this.tableProps,
    required this.tableNames,
    this.latexFields = const {},
    this.tableIds = const [],
    this.formatKey = '._false',
    this.transparentBackground = false,
    this.activeTableId,
    this.legendReservedRight = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (xSeries.isEmpty || ySeries.isEmpty) return;

    // Limits resolved in transformed space (shared with viewport gestures).
    final resolved = resolvePlotView(
      xSeries: xSeries,
      ySeries: ySeries,
      graphProps: graphProps,
      legendReservedRight: legendReservedRight,
    );
    if (resolved == null) return;

    final xScale = resolved.xScale;
    final yScale = resolved.yScale;
    var minX = resolved.minX;
    var maxX = resolved.maxX;
    var minY = resolved.minY;
    var maxY = resolved.maxY;

    final margins = resolved.margins;
    final marginLeft = margins.left;
    final marginBottom = margins.bottom;
    final marginTop = margins.top;
    final marginRight = margins.right;
    final plotWidth = size.width - marginLeft - marginRight;
    final plotHeight = size.height - marginTop - marginBottom;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Chart page: the whole canvas area (plot rect + axis/title margins)
    // shares one background — white by default. Transparent exports skip
    // the fill entirely.
    if (!transparentBackground) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _chartBackground(graphProps),
      );
    }

    final showGrid = graphProps?.showGrid ?? true;
    final showXAxis = graphProps?.xVisible ?? true;
    final showYAxis = graphProps?.yVisible ?? true;
    final titleSize = axisTitleSize(graphProps);
    final tickSize = axisTickSize(graphProps);
    final axisBase = PrimeTheme.canvasAxis;
    final gridBase = PrimeTheme.canvasGrid;
    final axisOverride = graphProps?.axisColor;
    final gridOverride = graphProps?.gridColor;
    final paintAxis = Paint()
      ..color = axisOverride != null
          ? _parseColor(axisOverride, axisBase)
          : axisBase
      ..strokeWidth = 1.5;
    final paintGrid = Paint()
      ..color = (gridOverride != null
              ? _parseColor(gridOverride, gridBase)
              : gridBase)
          .withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    Offset? mapToScreen(double x, double y) {
      final tx = transformValue(x, xScale);
      final ty = transformValue(y, yScale);
      if (tx == null || ty == null) return null;
      final screenX = marginLeft + ((tx - minX) / (maxX - minX)) * plotWidth;
      final screenY =
          marginTop + plotHeight - (((ty - minY) / (maxY - minY)) * plotHeight);
      if (!screenX.isFinite || !screenY.isFinite) return null;
      return Offset(screenX, screenY);
    }

    void drawAxisAndGrid() {
      final labelColor = _chartLabelColor(graphProps);
      final textStyle = TextStyle(
        color: labelColor,
        fontSize: tickSize,
      );
      final bottom = size.height - marginBottom;
      final right = size.width - marginRight;
      final xIntervals = axisIntervalCount(graphProps?.xDivisions);
      final yIntervals = axisIntervalCount(graphProps?.yDivisions);

      for (var i = 0; i <= xIntervals; i++) {
        final t = i / xIntervals;
        final screenX = marginLeft + plotWidth * t;

        if (showGrid) {
          canvas.drawLine(
            Offset(screenX, bottom),
            Offset(screenX, marginTop),
            paintGrid,
          );
        }

        if (showXAxis) {
          canvas.drawLine(
            Offset(screenX, bottom),
            Offset(screenX, bottom + 5),
            paintAxis,
          );
          final rawX = inverseTransformValue(minX + (maxX - minX) * t, xScale);
          final label = TextPainter(
            text: TextSpan(
              text: formatTickLabel(rawX, graphProps: graphProps),
              style: textStyle,
            ),
            textDirection: TextDirection.ltr,
          );
          label.layout();
          label.paint(
            canvas,
            Offset(screenX - label.width / 2, bottom + kAxisLabelGap),
          );
        }
      }

      for (var i = 0; i <= yIntervals; i++) {
        final t = i / yIntervals;
        final screenY = marginTop + plotHeight - plotHeight * t;

        if (showGrid) {
          canvas.drawLine(
            Offset(marginLeft, screenY),
            Offset(right, screenY),
            paintGrid,
          );
        }

        if (showYAxis) {
          canvas.drawLine(
            Offset(marginLeft - 5, screenY),
            Offset(marginLeft, screenY),
            paintAxis,
          );
          final rawY = inverseTransformValue(minY + (maxY - minY) * t, yScale);
          final label = TextPainter(
            text: TextSpan(
              text: formatTickLabel(rawY, graphProps: graphProps),
              style: textStyle,
            ),
            textDirection: TextDirection.ltr,
          );
          label.layout();
          label.paint(
            canvas,
            Offset(
              marginLeft - label.width - kAxisLabelGap,
              screenY - label.height / 2,
            ),
          );
        }
      }

      if (showYAxis) {
        canvas.drawLine(
          Offset(marginLeft, marginTop),
          Offset(marginLeft, bottom),
          paintAxis,
        );
      }
      if (showXAxis) {
        canvas.drawLine(
          Offset(marginLeft, bottom),
          Offset(right, bottom),
          paintAxis,
        );
      }
      if (graphProps?.showBorder ?? false) {
        canvas.drawRect(
          Rect.fromLTWH(marginLeft, marginTop, plotWidth, plotHeight),
          Paint()
            ..color = paintAxis.color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }

      if (showXAxis && !latexFields.contains('xLabel')) {
        final title = TextPainter(
          text: TextSpan(
            text: graphProps?.xLabel ?? 'X',
            style: TextStyle(
              color: labelColor,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        title.layout();
        title.paint(
          canvas,
          Offset(
            marginLeft + plotWidth / 2 - title.width / 2,
            size.height - marginBottom + margins.xTitleTop,
          ),
        );
      }

      if (showYAxis && !latexFields.contains('yLabel')) {
        final title = TextPainter(
          text: TextSpan(
            text: graphProps?.yLabel ?? 'Y',
            style: TextStyle(
              color: labelColor,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        title.layout();
        canvas.save();
        canvas.translate(
          marginLeft - margins.yTitleFromAxis,
          marginTop + plotHeight / 2 + title.width / 2,
        );
        canvas.rotate(-math.pi / 2);
        title.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    drawAxisAndGrid();

    // Axes act as boundaries: curves/markers never paint outside the plot.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(marginLeft, marginTop, plotWidth, plotHeight),
    );

    for (var s = 0; s < xSeries.length; s++) {
      final xs = xSeries[s];
      final ys = ySeries[s];
      if (xs.isEmpty || ys.isEmpty) continue;

      final props = s < tableProps.length ? tableProps[s] : null;
      // Selection highlight: with a dataset selected, its curve draws
      // prominently; the previewed siblings recede to 45% alpha.
      final seriesId = s < tableIds.length ? tableIds[s] : null;
      final isActive = activeTableId != null && seriesId == activeTableId;
      final dimmed = activeTableId != null && !isActive;
      final lineColor = props != null
          ? _parseColor(props.lineColor, const Color(0xFF1F77B4))
          : const Color(0xFF1F77B4);
      final markerColor = props != null
          ? _parseColor(props.markerColor, Colors.black)
          : Colors.black;
      final linePaint = Paint()
        ..color = dimmed ? lineColor.withValues(alpha: 0.45) : lineColor
        ..strokeWidth =
            (props?.lineThickness ?? 2.5) + (isActive ? 0.75 : 0.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final len = math.min(xs.length, ys.length);
      if (props?.lineVisible ?? true) {
        var segment = <Offset>[];
        for (var i = 0; i < len; i++) {
          final point = mapToScreen(xs[i], ys[i]);
          if (point == null) {
            _drawStyledPath(
              canvas,
              segment,
              linePaint,
              props?.lineStyle ?? 'Full',
            );
            segment = <Offset>[];
          } else {
            segment.add(point);
          }
        }
        _drawStyledPath(canvas, segment, linePaint, props?.lineStyle ?? 'Full');
      }

      if (props?.markerVisible ?? false) {
        final markerPaint = Paint()
          ..color = dimmed
              ? markerColor.withValues(alpha: 0.45)
              : markerColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        final markerStroke = Paint()
          ..color = dimmed
              ? markerColor.withValues(alpha: 0.45)
              : markerColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        for (var i = 0; i < len; i++) {
          final point = mapToScreen(xs[i], ys[i]);
          if (point != null) {
            _drawMarker(
              canvas,
              point,
              props?.markerType ?? 'Circle',
              markerPaint,
              markerStroke,
            );
          }
        }
      }
    }

    canvas.restore();

    _drawLegend(canvas, size, margins);
  }

  void _drawStyledPath(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    String style,
  ) {
    if (points.length < 2) return;
    final normalized = style.toLowerCase();
    if (normalized == 'full' || normalized == 'solid') {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
      return;
    }

    final pattern = normalized.contains('dot') && normalized.contains('dash')
        ? const [12.0, 6.0, 2.0, 6.0]
        : normalized.contains('dot')
        ? const [2.0, 6.0]
        : const [12.0, 8.0];

    for (var i = 0; i < points.length - 1; i++) {
      _drawPatternSegment(canvas, points[i], points[i + 1], paint, pattern);
    }
  }

  void _drawPatternSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    List<double> pattern,
  ) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    var travelled = 0.0;
    var patternIndex = 0;
    var draw = true;

    while (travelled < distance) {
      final length = pattern[patternIndex % pattern.length];
      final next = math.min(travelled + length, distance);
      if (draw) {
        canvas.drawLine(
          start + direction * travelled,
          start + direction * next,
          paint,
        );
      }
      travelled = next;
      patternIndex++;
      draw = !draw;
    }
  }

  void _drawMarker(
    Canvas canvas,
    Offset point,
    String type,
    Paint fill,
    Paint stroke,
  ) {
    const radius = 4.0;
    final normalized = type.toLowerCase();
    if (normalized == 'none') return;

    if (normalized.contains('square')) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: radius * 2, height: radius * 2),
        fill,
      );
      return;
    }
    if (normalized == 'cross') {
      canvas.drawLine(
        point.translate(-radius, 0),
        point.translate(radius, 0),
        stroke,
      );
      canvas.drawLine(
        point.translate(0, -radius),
        point.translate(0, radius),
        stroke,
      );
      return;
    }
    if (normalized == 'x') {
      canvas.drawLine(
        point.translate(-radius, -radius),
        point.translate(radius, radius),
        stroke,
      );
      canvas.drawLine(
        point.translate(-radius, radius),
        point.translate(radius, -radius),
        stroke,
      );
      return;
    }
    if (normalized.contains('triangle')) {
      final down = normalized.contains('down');
      final path = Path()
        ..moveTo(point.dx, point.dy + (down ? radius : -radius))
        ..lineTo(point.dx - radius, point.dy + (down ? -radius : radius))
        ..lineTo(point.dx + radius, point.dy + (down ? -radius : radius))
        ..close();
      canvas.drawPath(path, fill);
      return;
    }

    canvas.drawCircle(point, radius, fill);
  }

  void _drawLegend(Canvas canvas, Size size, PlotMargins margins) {
    if (!(graphProps?.showLegend ?? true)) return;

    final entries = <_LegendEntry>[];
    for (var i = 0; i < tableProps.length; i++) {
      if (!_legendSeriesVisible(i, xSeries, tableProps[i])) continue;
      final props = tableProps[i];
      entries.add(
        _LegendEntry(
          name: _legendSeriesName(
            i,
            props,
            tableNames,
            tableIds,
            latexFields,
          ),
          lineColor: _parseColor(props.lineColor, const Color(0xFF1F77B4)),
          markerColor: _parseColor(props.markerColor, Colors.black),
          lineStyle: props.lineStyle,
          markerType: props.markerType,
          showLine: props.lineVisible,
          showMarker: props.markerVisible,
        ),
      );
    }
    if (entries.isEmpty) return;

    final fontSize = _legendFontSize(graphProps);
    final layout = _legendLayout(
      [for (final e in entries) e.name],
      fontSize,
    );
    final padding = layout.padding;
    final rowHeight = layout.rowHeight;
    final swatchWidth = layout.swatchWidth;
    final legendWidth = layout.boxWidth;
    final legendHeight = layout.boxHeight;

    final position = (graphProps?.legendPosition ?? 'Top Right')
        .trim()
        .toLowerCase();
    final outside = position.contains('outside');
    final double left;
    final double top;
    if (outside) {
      // Painted in the right margin strip reserved by `legendReservedRight`.
      left = size.width - padding - legendWidth;
      top = margins.top;
    } else {
      left = position.contains('left')
          ? margins.left + 12.0
          : size.width - margins.right - legendWidth;
      top = position.contains('bottom')
          ? size.height - margins.bottom - 12.0 - legendHeight
          : margins.top + 8.0;
    }
    final rect = Rect.fromLTWH(left, top, legendWidth, legendHeight);

    // Background fill: theme panel by default. Opacity 0 (or an alpha-zero
    // override such as #00000000) skips the fill so curves show through.
    final opacity = (graphProps?.legendOpacity ?? 0.9).clamp(0.0, 1.0);
    final bgOverride = graphProps?.legendBackgroundColor;
    final bgColor = bgOverride != null
        ? _parseColor(bgOverride, PrimeTheme.panelBackground)
        : PrimeTheme.panelBackground;
    final fillAlpha = opacity * bgColor.a;
    if (fillAlpha > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = bgColor.withValues(alpha: fillAlpha),
      );
    }

    if (graphProps?.legendShowBorder ?? true) {
      final borderOverride = graphProps?.legendBorderColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = borderOverride != null
              ? _parseColor(borderOverride, PrimeTheme.borderSide)
              : PrimeTheme.borderSide
          ..style = PaintingStyle.stroke,
      );
    }

    // Text contrasts with whatever is actually behind it: the panel/override
    // color when the fill is visible, the chart page when it is not.
    final Color textColor;
    if (fillAlpha > 0) {
      textColor = bgOverride != null
          ? (bgColor.computeLuminance() > 0.5
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF))
          : PrimeTheme.textPrimary;
    } else {
      textColor = _chartLabelColor(graphProps);
    }
    final textStyle = TextStyle(color: textColor, fontSize: fontSize);

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final y = top + padding + rowHeight * i + rowHeight / 2;
      final linePaint = Paint()
        ..color = entry.lineColor
        ..strokeWidth = math.max(1.5, fontSize * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      if (entry.showLine) {
        _drawStyledPath(
          canvas,
          [Offset(left + padding, y), Offset(left + padding + swatchWidth, y)],
          linePaint,
          entry.lineStyle,
        );
      }
      if (entry.showMarker) {
        final markerPaint = Paint()
          ..color = entry.markerColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        final markerStroke = Paint()
          ..color = entry.markerColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        _drawMarker(
          canvas,
          Offset(left + padding + swatchWidth / 2, y),
          entry.markerType,
          markerPaint,
          markerStroke,
        );
      }
      final text = TextPainter(
        text: TextSpan(text: entry.name, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(left + padding * 2 + swatchWidth, y - text.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MultiSeriesPlotPainter oldDelegate) {
    if (graphProps != oldDelegate.graphProps) return true;
    if (formatKey != oldDelegate.formatKey) return true;
    if (transparentBackground != oldDelegate.transparentBackground) {
      return true;
    }
    if (activeTableId != oldDelegate.activeTableId) return true;
    if (tableProps.length != oldDelegate.tableProps.length) return true;
    if (tableNames.length != oldDelegate.tableNames.length) return true;
    for (var i = 0; i < tableProps.length; i++) {
      if (tableProps[i] != oldDelegate.tableProps[i]) return true;
    }
    for (var i = 0; i < tableNames.length; i++) {
      if (tableNames[i] != oldDelegate.tableNames[i]) return true;
    }
    if (xSeries.length != oldDelegate.xSeries.length) return true;
    for (var s = 0; s < xSeries.length; s++) {
      final xs = xSeries[s];
      final ys = ySeries[s];
      final oxs = oldDelegate.xSeries[s];
      final oys = oldDelegate.ySeries[s];
      if (xs.length != oxs.length || ys.length != oys.length) return true;
      for (var i = 0; i < xs.length; i++) {
        if (xs[i] != oxs[i] || ys[i] != oys[i]) return true;
      }
    }
    if (latexFields.length != oldDelegate.latexFields.length) return true;
    if (!latexFields.containsAll(oldDelegate.latexFields)) return true;
    if (tableIds.length != oldDelegate.tableIds.length) return true;
    for (var i = 0; i < tableIds.length; i++) {
      if (tableIds[i] != oldDelegate.tableIds[i]) return true;
    }
    return false;
  }
}

/// Live per-series extents (top-right overlay, toggled by σ / S).
/// Recomputed from Rust on every canvas rebuild, so it tracks edits.
class _StatsPanel extends StatelessWidget {
  final String? graphId;
  const _StatsPanel({required this.graphId});

  static String _fmt(double v) {
    if (!v.isFinite) return '—';
    final a = v.abs();
    if (a != 0 && (a >= 100000 || a < 0.001)) {
      return groupDotted(v.toStringAsExponential(1));
    }
    return formatNumber(v);
  }

  @override
  Widget build(BuildContext context) {
    List<SeriesStatistics> entries = const [];
    if (graphId != null) {
      try {
        entries = getGraphStatistics(graphId: graphId!);
      } catch (_) {
        entries = const [];
      }
    }
    return IgnorePointer(
      child: Container(
        width: 216,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: PrimeTheme.panelBackground.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: PrimeTheme.borderSide),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SERIES STATISTICS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: PrimeTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              Text(
                'No plottable series.',
                style: TextStyle(
                  fontSize: 11,
                  color: PrimeTheme.textSecondary,
                ),
              ),
            for (final e in entries) ...[
              Text(
                e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PrimeTheme.textPrimary,
                ),
              ),
              Text(
                'X [${_fmt(e.minX)}, ${_fmt(e.maxX)}]  '
                'Y [${_fmt(e.minY)}, ${_fmt(e.maxY)}]  n=${e.nPoints}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: PrimeTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendEntry {  final String name;
  final Color lineColor;
  final Color markerColor;
  final String lineStyle;
  final String markerType;
  final bool showLine;
  final bool showMarker;

  const _LegendEntry({
    required this.name,
    required this.lineColor,
    required this.markerColor,
    required this.lineStyle,
    required this.markerType,
    required this.showLine,
    required this.showMarker,
  });
}
