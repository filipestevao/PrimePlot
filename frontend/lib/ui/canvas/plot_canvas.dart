// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/latex_symbols.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/data.dart';
import '../../src/rust/api/functions.dart';
import '../../src/rust/api/project.dart';
import '../../src/rust/api/properties.dart';
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

String _formatTick(double value) {
  final abs = value.abs();
  if (abs != 0 && (abs >= 10000 || abs < 0.001)) {
    return value.toStringAsExponential(1);
  }
  if (abs >= 100) return value.toStringAsFixed(0);
  if (abs >= 10) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
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
      ]),
      builder: (context, _) {
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

            // Selection scope: a selected table/function isolates its own
            // curve(s); graph (or other) selection shows the whole plot.
            final st = ProjectState.instance;
            final plotId = st.activePlotId;
            final root = st.projectTree.value;
            final selectedId = st.selectedProjectNodeId.value;
            final selectedNode = (root != null && selectedId != null)
                ? st.findNodeById(root, selectedId)
                : null;
            final selectDataset =
                selectedNode?.nodeType == NodeType.dataset;
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
              return const Center(
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
                            markerColor: '#FFFFFF',
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
                            markerColor: '#FFFFFF',
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
                    final nodeId = ProjectState.instance.selectedProjectNodeId.value;
                    if (nodeId != null && graphProps != null) {
                      final s = ProjectState.instance;
                      if (s.getLatexMode(nodeId, 'xLabel')) latexFields.add('xLabel');
                      if (s.getLatexMode(nodeId, 'yLabel')) latexFields.add('yLabel');
                      for (final tid in tableIds) {
                        if (s.getLatexMode(tid, 'legendDisplayName')) {
                          latexFields.add('legendDisplayName_$tid');
                        }
                      }
                    }
                    final hasLatexLabels = latexFields.contains('xLabel') || latexFields.contains('yLabel');

                    Widget baseCanvas;
                    if (hasLatexLabels && graphProps != null) {
                      final gp = graphProps;
                      baseCanvas = LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(constraints.maxWidth, constraints.maxHeight);
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
                                ),
                                child: Container(),
                              ),
                              ..._buildLatexOverlays(gp, size, latexFields),
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
                        ),
                        child: Container(),
                      );
                    }

                    Widget canvas = PlotViewport(
                      xSeries: seriesX,
                      ySeries: seriesY,
                      graphProps: graphProps,
                      plotId: ProjectState.instance.activePlotId,
                      child: baseCanvas,
                    );

                    if (graphProps?.aspectRatio != null) {
                      canvas = Center(
                        child: AspectRatio(
                          aspectRatio: graphProps!.aspectRatio!,
                          child: canvas,
                        ),
                      );
                    }

                    return ClipRRect(child: canvas);
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
  ) {
    const marginLeft = kPlotMarginLeft;
    const marginBottom = kPlotMarginBottom;
    const marginTop = kPlotMarginTop;
    const marginRight = kPlotMarginRight;

    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: PrimeTheme.textPrimary,
    );

    final overlays = <Widget>[];

    if (latexFields.contains('xLabel')) {
      overlays.add(
        Positioned(
          left: marginLeft,
          right: marginRight,
          bottom: 20,
          child: Center(
            child: RichText(
              text: TextSpan(
                children: buildLatexSpans(
                  graphProps.xLabel,
                  style: labelStyle,
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
          left: 0,
          width: marginLeft,
          top: marginTop,
          bottom: marginBottom,
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: RichText(
                text: TextSpan(
                  children: buildLatexSpans(
                    graphProps.yLabel,
                    style: labelStyle,
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

  _MultiSeriesPlotPainter({
    required this.xSeries,
    required this.ySeries,
    required this.graphProps,
    required this.tableProps,
    required this.tableNames,
    this.latexFields = const {},
    this.tableIds = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (xSeries.isEmpty || ySeries.isEmpty) return;

    // Limits resolved in transformed space (shared with viewport gestures).
    final resolved = resolvePlotView(
      xSeries: xSeries,
      ySeries: ySeries,
      graphProps: graphProps,
    );
    if (resolved == null) return;

    final xScale = resolved.xScale;
    final yScale = resolved.yScale;
    var minX = resolved.minX;
    var maxX = resolved.maxX;
    var minY = resolved.minY;
    var maxY = resolved.maxY;

    const marginLeft = kPlotMarginLeft;
    const marginBottom = kPlotMarginBottom;
    const marginTop = kPlotMarginTop;
    const marginRight = kPlotMarginRight;
    final plotWidth = size.width - marginLeft - marginRight;
    final plotHeight = size.height - marginTop - marginBottom;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final showGrid = graphProps?.showGrid ?? true;
    final showXAxis = graphProps?.xVisible ?? true;
    final showYAxis = graphProps?.yVisible ?? true;
    final paintAxis = Paint()
      ..color = PrimeTheme.textSecondary
      ..strokeWidth = 1.5;
    final paintGrid = Paint()
      ..color = PrimeTheme.textSecondary.withValues(alpha: 0.2)
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
      const ticks = 5;
      const textStyle = TextStyle(
        color: PrimeTheme.textSecondary,
        fontSize: 10,
      );
      final bottom = size.height - marginBottom;
      final right = size.width - marginRight;

      for (var i = 0; i <= ticks; i++) {
        final t = i / ticks;
        final screenX = marginLeft + plotWidth * t;
        final screenY = marginTop + plotHeight - plotHeight * t;

        if (showGrid) {
          canvas.drawLine(
            Offset(screenX, bottom),
            Offset(screenX, marginTop),
            paintGrid,
          );
          canvas.drawLine(
            Offset(marginLeft, screenY),
            Offset(right, screenY),
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
            text: TextSpan(text: _formatTick(rawX), style: textStyle),
            textDirection: TextDirection.ltr,
          );
          label.layout();
          label.paint(canvas, Offset(screenX - label.width / 2, bottom + 10));
        }

        if (showYAxis) {
          canvas.drawLine(
            Offset(marginLeft - 5, screenY),
            Offset(marginLeft, screenY),
            paintAxis,
          );
          final rawY = inverseTransformValue(minY + (maxY - minY) * t, yScale);
          final label = TextPainter(
            text: TextSpan(text: _formatTick(rawY), style: textStyle),
            textDirection: TextDirection.ltr,
          );
          label.layout();
          label.paint(
            canvas,
            Offset(marginLeft - label.width - 10, screenY - label.height / 2),
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

      if (showXAxis && !latexFields.contains('xLabel')) {
        final title = TextPainter(
          text: TextSpan(
            text: graphProps?.xLabel ?? 'X',
            style: const TextStyle(
              color: PrimeTheme.textPrimary,
              fontSize: 12,
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
            size.height - 20,
          ),
        );
      }

      if (showYAxis && !latexFields.contains('yLabel')) {
        final title = TextPainter(
          text: TextSpan(
            text: graphProps?.yLabel ?? 'Y',
            style: const TextStyle(
              color: PrimeTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        title.layout();
        canvas.save();
        canvas.translate(20, marginTop + plotHeight / 2 + title.width / 2);
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
      final lineColor = props != null
          ? _parseColor(props.lineColor, const Color(0xFF1F77B4))
          : const Color(0xFF1F77B4);
      final markerColor = props != null
          ? _parseColor(props.markerColor, Colors.white)
          : Colors.white;
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = props?.lineThickness ?? 2.5
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
          ..color = markerColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        final markerStroke = Paint()
          ..color = markerColor
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

    _drawLegend(canvas, size, marginTop, marginRight);
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

  void _drawLegend(
    Canvas canvas,
    Size size,
    double marginTop,
    double marginRight,
  ) {
    if (!(graphProps?.showLegend ?? true)) return;

    final entries = <_LegendEntry>[];
    for (var i = 0; i < tableProps.length; i++) {
      if (i >= xSeries.length || xSeries[i].isEmpty) continue;
      final props = tableProps[i];
      if (!props.lineVisible && !props.markerVisible) continue;
      final rawName = props.legendDisplayName.trim();
      final tableName = i < tableNames.length
          ? tableNames[i]
          : 'Series ${i + 1}';
      var entryName = rawName.isEmpty || rawName == 'Series' ? tableName : rawName;
      if (i < tableIds.length && latexFields.contains('legendDisplayName_${tableIds[i]}')) {
        entryName = substituteSymbols(entryName);
      }
      entries.add(
        _LegendEntry(
          name: entryName,
          lineColor: _parseColor(props.lineColor, const Color(0xFF1F77B4)),
          markerColor: _parseColor(props.markerColor, Colors.white),
          lineStyle: props.lineStyle,
          markerType: props.markerType,
          showLine: props.lineVisible,
          showMarker: props.markerVisible,
        ),
      );
    }
    if (entries.isEmpty) return;

    const textStyle = TextStyle(color: PrimeTheme.textPrimary, fontSize: 11);
    const padding = 8.0;
    const rowHeight = 20.0;
    const swatchWidth = 28.0;
    var maxTextWidth = 0.0;
    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(text: entry.name, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      maxTextWidth = math.max(maxTextWidth, painter.width);
    }

    final legendWidth = padding * 3 + swatchWidth + maxTextWidth;
    final legendHeight = padding * 2 + rowHeight * entries.length;
    final position = (graphProps?.legendPosition ?? 'Top Right').toLowerCase();
    final left = position.contains('left')
        ? 72.0
        : size.width - marginRight - legendWidth;
    final top = position.contains('bottom')
        ? size.height - 56.0 - legendHeight
        : marginTop + 8.0;
    final rect = Rect.fromLTWH(left, top, legendWidth, legendHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = PrimeTheme.panelBackground.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = PrimeTheme.borderSide
        ..style = PaintingStyle.stroke,
    );

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final y = top + padding + rowHeight * i + rowHeight / 2;
      final linePaint = Paint()
        ..color = entry.lineColor
        ..strokeWidth = 2
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

class _LegendEntry {
  final String name;
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
