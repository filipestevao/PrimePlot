// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/data.dart';

class PlotCanvas extends StatelessWidget {
  const PlotCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to multi-table list first; fallback to legacy single table.
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

        final bool hasData = tables.isNotEmpty
            ? tables.any((t) => t.columns.length >= 2 && t.columns.first.data.isNotEmpty)
            : primaryTable != null && primaryTable.columns.length >= 2 && primaryTable.columns.first.data.isNotEmpty;

        if (primaryTable == null || !hasData) {
          return const Center(
            child: Text(
              'No data available to plot.',
              style: TextStyle(color: PrimeTheme.textSecondary),
            ),
          );
        }

        return ValueListenableBuilder<List<LayerItem>>(
          valueListenable: ProjectState.instance.layers,
          builder: (context, layers, child) {
            return ValueListenableBuilder<PlotProperties>(
              valueListenable: ProjectState.instance.plotProperties,
              builder: (context, props, child) {
                // For multi-table plotting, we will draw each table's first two
                // columns as a separate series. Build cleaned series list.
                final List<List<double>> seriesX = [];
                final List<List<double>> seriesY = [];

                final List<DTODataTable> toPlot = tables.isNotEmpty ? tables : [primaryTable!];

                for (var tableData in toPlot) {
                  DTODataColumn? xCol;
                  DTODataColumn? yCol;
                  for (var col in tableData.columns) {
                    if (col.role == DTOColumnRole.x && xCol == null) xCol = col;
                    if (col.role == DTOColumnRole.y && yCol == null) yCol = col;
                  }
                  xCol ??= tableData.columns[0];
                  yCol ??= tableData.columns.length > 1 ? tableData.columns[1] : tableData.columns[0];

                  final xRaw = xCol.data;
                  final yRaw = yCol.data;
                  final xClean = <double>[];
                  final yClean = <double>[];
                  final len = math.min(xRaw.length, yRaw.length);
                  for (int i = 0; i < len; i++) {
                    if (!xRaw[i].isNaN && !yRaw[i].isNaN) {
                      xClean.add(xRaw[i]);
                      yClean.add(yRaw[i]);
                    }
                  }

                  seriesX.add(xClean);
                  seriesY.add(yClean);
                }

                Widget canvas = CustomPaint(
                  painter: _MultiSeriesPlotPainter(seriesX, seriesY, layers, props),
                  child: Container(),
                );

                if (props.aspectRatio != null) {
                  canvas = Center(
                    child: AspectRatio(
                      aspectRatio: props.aspectRatio!,
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
  }
}

/// Painter that supports multiple series. Uses color palette per series index.
class _MultiSeriesPlotPainter extends CustomPainter {
  final List<List<double>> xSeries;
  final List<List<double>> ySeries;
  final List<LayerItem> layers;
  final PlotProperties props;

  _MultiSeriesPlotPainter(this.xSeries, this.ySeries, this.layers, this.props);

  static const List<Color> _palette = [
    Color(0xFF00C3FF),
    Color(0xFFFF8A00),
    Color(0xFF7C4DFF),
    Color(0xFF4CAF50),
    Color(0xFFE91E63),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // If no series, nothing to draw
    if (xSeries.isEmpty || ySeries.isEmpty) return;

    // For bounds calculation, combine all series
    final combinedX = <double>[];
    final combinedY = <double>[];
    for (int s = 0; s < xSeries.length; s++) {
      combinedX.addAll(xSeries[s]);
      combinedY.addAll(ySeries[s]);
    }
    if (combinedX.isEmpty || combinedY.isEmpty) return;

    // Compute bounds
    double minX = combinedX.first;
    double maxX = combinedX.first;
    double minY = combinedY.first;
    double maxY = combinedY.first;
    for (int i = 1; i < combinedX.length; i++) {
      if (combinedX[i] < minX) minX = combinedX[i];
      if (combinedX[i] > maxX) maxX = combinedX[i];
    }
    for (int i = 1; i < combinedY.length; i++) {
      if (combinedY[i] < minY) minY = combinedY[i];
      if (combinedY[i] > maxY) maxY = combinedY[i];
    }

    final xRange = maxX - minX;
    final yRange = maxY - minY;
    final padX = xRange == 0 ? 10.0 : 0.0;
    final padY = yRange == 0 ? 10.0 : 0.0;
    minX -= padX;
    maxX += padX;
    minY -= padY;
    maxY += padY;

    // Override with user-defined axis ranges if set
    if (props.xMin != null) minX = props.xMin!;
    if (props.xMax != null) maxX = props.xMax!;
    if (props.yMin != null) minY = props.yMin!;
    if (props.yMax != null) maxY = props.yMax!;

    // Guard against degenerate ranges after override
    if (maxX <= minX) maxX = minX + 1;
    if (maxY <= minY) maxY = minY + 1;

    final bool showGrid = layers.any((l) => l.id == 'grid' && l.isVisible);

    // Reuse axis/grid drawing and other helpers from previous painter.
    // Keep colors per series and draw in order with same layer controls.

    // Create paint instances for axis/grid same as before
    final paintAxis = Paint()..color = PrimeTheme.textSecondary..strokeWidth = 1.5;
    final paintGrid = Paint()..color = PrimeTheme.textSecondary.withOpacity(0.2)..strokeWidth = 1.0;

    const marginLeft = 60.0;
    const marginBottom = 40.0;
    const marginTop = 20.0;
    const marginRight = 20.0;
    final plotWidth = size.width - marginLeft - marginRight;
    final plotHeight = size.height - marginTop - marginBottom;

    Offset mapToScreen(double x, double y) {
      final screenX = marginLeft + ((x - minX) / (maxX - minX)) * plotWidth;
      final screenY = marginTop + plotHeight - (((y - minY) / (maxY - minY)) * plotHeight);
      return Offset(screenX, screenY);
    }

    void drawAxis() {
      canvas.drawLine(Offset(marginLeft, marginTop), Offset(marginLeft, size.height - marginBottom), paintAxis);
      canvas.drawLine(Offset(marginLeft, size.height - marginBottom), Offset(size.width - marginRight, size.height - marginBottom), paintAxis);
      const int ticks = 5;
      const textStyle = TextStyle(color: PrimeTheme.textSecondary, fontSize: 10);
      for (int i = 0; i <= ticks; i++) {
        final xVal = minX + (maxX - minX) * (i / ticks);
        final screenX = marginLeft + plotWidth * (i / ticks);
        if (showGrid) {
          canvas.drawLine(Offset(screenX, size.height - marginBottom), Offset(screenX, marginTop), paintGrid);
        }
        canvas.drawLine(Offset(screenX, size.height - marginBottom), Offset(screenX, size.height - marginBottom + 5), paintAxis);
        final xLabel = TextPainter(text: TextSpan(text: xVal.toStringAsFixed(1), style: textStyle), textDirection: TextDirection.ltr);
        xLabel.layout();
        xLabel.paint(canvas, Offset(screenX - xLabel.width / 2, size.height - marginBottom + 10));

        final yVal = minY + (maxY - minY) * (i / ticks);
        final screenY = marginTop + plotHeight - plotHeight * (i / ticks);
        if (showGrid) {
          canvas.drawLine(Offset(marginLeft, screenY), Offset(size.width - marginRight, screenY), paintGrid);
        }
        canvas.drawLine(Offset(marginLeft - 5, screenY), Offset(marginLeft, screenY), paintAxis);
        final yLabel = TextPainter(text: TextSpan(text: yVal.toStringAsFixed(1), style: textStyle), textDirection: TextDirection.ltr);
        yLabel.layout();
        yLabel.paint(canvas, Offset(marginLeft - yLabel.width - 10, screenY - yLabel.height / 2));
      }
      final xTitle = TextPainter(text: TextSpan(text: props.xAxisLabel, style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      xTitle.layout();
      xTitle.paint(canvas, Offset(marginLeft + plotWidth / 2 - xTitle.width / 2, size.height - 20));
      final yTitle = TextPainter(text: TextSpan(text: props.yAxisLabel, style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      yTitle.layout();
      canvas.save();
      canvas.translate(20, marginTop + plotHeight / 2 + yTitle.width / 2);
      canvas.rotate(-math.pi / 2);
      yTitle.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Draw layers: axis first if enabled
    for (int i = layers.length - 1; i >= 0; i--) {
      final layer = layers[i];
      if (!layer.isVisible) continue;
      if (layer.id == 'axis') {
        drawAxis();
      }
    }

    // Draw series lines and scatter according to layer toggles
    final showLine = layers.any((l) => l.id == 'line_a' && l.isVisible);
    final showScatter = layers.any((l) => l.id == 'scatter_a' && l.isVisible);

    for (int s = 0; s < xSeries.length; s++) {
      final xs = xSeries[s];
      final ys = ySeries[s];
      if (xs.isEmpty || ys.isEmpty) continue;
      final paintLine = Paint()..color = _palette[s % _palette.length]..strokeWidth = props.lineThickness..style = PaintingStyle.stroke..isAntiAlias = true;
      final paintPoint = Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true;
      final paintPointBorder = Paint()..color = _palette[s % _palette.length]..strokeWidth = 2..style = PaintingStyle.stroke..isAntiAlias = true;

      final len = math.min(xs.length, ys.length);
      if (showLine && len > 0) {
        final path = Path();
        final first = mapToScreen(xs[0], ys[0]);
        path.moveTo(first.dx, first.dy);
        for (int i = 1; i < len; i++) {
          final p = mapToScreen(xs[i], ys[i]);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paintLine);
      }

      if (showScatter && len > 0) {
        for (int i = 0; i < len; i++) {
          final p = mapToScreen(xs[i], ys[i]);
          canvas.drawCircle(p, 4, paintPoint);
          canvas.drawCircle(p, 4, paintPointBorder);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiSeriesPlotPainter oldDelegate) {
    if (layers != oldDelegate.layers) return true;
    if (props != oldDelegate.props) return true;
    if (xSeries.length != oldDelegate.xSeries.length) return true;
    for (int s = 0; s < xSeries.length; s++) {
      final xs = xSeries[s];
      final ys = ySeries[s];
      final oxs = oldDelegate.xSeries[s];
      final oys = oldDelegate.ySeries[s];
      if (xs.length != oxs.length || ys.length != oys.length) return true;
      for (int i = 0; i < xs.length; i++) {
        if (xs[i] != oxs[i] || ys[i] != oys[i]) return true;
      }
    }
    return false;
  }
}

class _ScientificPlotPainter extends CustomPainter {
  final List<double> xData;
  final List<double> yData;
  final List<LayerItem> layers;
  final PlotProperties props;

  _ScientificPlotPainter(this.xData, this.yData, this.layers, this.props);

  @override
  void paint(Canvas canvas, Size size) {
    if (xData.isEmpty || yData.isEmpty) return;

    final length = math.min(xData.length, yData.length);

    // Find min and max
    double minX = xData[0];
    double maxX = xData[0];
    double minY = yData[0];
    double maxY = yData[0];

    for (int i = 1; i < length; i++) {
      if (xData[i] < minX) minX = xData[i];
      if (xData[i] > maxX) maxX = xData[i];
      if (yData[i] < minY) minY = yData[i];
      if (yData[i] > maxY) maxY = yData[i];
    }

    // Add some padding to bounds (10%)
    final xRange = maxX - minX;
    final yRange = maxY - minY;
    
    // Handle edge case of flat lines
    final padX = xRange == 0 ? 10.0 : xRange * 0.1;
    final padY = yRange == 0 ? 10.0 : yRange * 0.1;

    minX -= padX;
    maxX += padX;
    minY -= padY;
    maxY += padY;

    // Override with user-defined axis ranges if set
    if (props.xMin != null) minX = props.xMin!;
    if (props.xMax != null) maxX = props.xMax!;
    if (props.yMin != null) minY = props.yMin!;
    if (props.yMax != null) maxY = props.yMax!;

    // Guard against degenerate ranges after override
    if (maxX <= minX) maxX = minX + 1;
    if (maxY <= minY) maxY = minY + 1;

    final bool showGrid = layers.any((l) => l.id == 'grid' && l.isVisible);

    final paintAxis = Paint()
      ..color = PrimeTheme.textSecondary
      ..strokeWidth = 1.5;

    final paintLine = Paint()
      ..color = props.lineColor
      ..strokeWidth = props.lineThickness
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final paintPoint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
      
    final paintPointBorder = Paint()
      ..color = props.lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final paintGrid = Paint()
      ..color = PrimeTheme.textSecondary.withOpacity(0.2)
      ..strokeWidth = 1.0;

    // Define plotting area margins
    const marginLeft = 60.0;
    const marginBottom = 40.0;
    const marginTop = 20.0;
    const marginRight = 20.0;

    final plotWidth = size.width - marginLeft - marginRight;
    final plotHeight = size.height - marginTop - marginBottom;

    // Helper to map data to screen coordinates
    Offset mapToScreen(double x, double y) {
      final screenX = marginLeft + ((x - minX) / (maxX - minX)) * plotWidth;
      // Invert Y because canvas Y is top-down
      final screenY = marginTop + plotHeight - (((y - minY) / (maxY - minY)) * plotHeight);
      return Offset(screenX, screenY);
    }

    void drawAxis() {
      // Draw Grid and Axis lines
      canvas.drawLine(
        Offset(marginLeft, marginTop),
        Offset(marginLeft, size.height - marginBottom),
        paintAxis,
      ); // Y-axis
      canvas.drawLine(
        Offset(marginLeft, size.height - marginBottom),
        Offset(size.width - marginRight, size.height - marginBottom),
        paintAxis,
      ); // X-axis

      // Draw simple grid lines and labels (5 ticks per axis)
      const int ticks = 5;
      const textStyle = TextStyle(color: PrimeTheme.textSecondary, fontSize: 10);

      for (int i = 0; i <= ticks; i++) {
        // X-axis ticks
        final xVal = minX + (maxX - minX) * (i / ticks);
        final screenX = marginLeft + plotWidth * (i / ticks);
        
        if (showGrid) {
          canvas.drawLine(
            Offset(screenX, size.height - marginBottom),
            Offset(screenX, marginTop),
            paintGrid,
          );
        }

        canvas.drawLine(
          Offset(screenX, size.height - marginBottom),
          Offset(screenX, size.height - marginBottom + 5),
          paintAxis,
        );
        
        final xLabel = TextPainter(
          text: TextSpan(text: xVal.toStringAsFixed(1), style: textStyle),
          textDirection: TextDirection.ltr,
        );
        xLabel.layout();
        xLabel.paint(canvas, Offset(screenX - xLabel.width / 2, size.height - marginBottom + 10));

        // Y-axis ticks
        final yVal = minY + (maxY - minY) * (i / ticks);
        final screenY = marginTop + plotHeight - plotHeight * (i / ticks);
        
        if (showGrid) {
          canvas.drawLine(
            Offset(marginLeft, screenY),
            Offset(size.width - marginRight, screenY),
            paintGrid,
          );
        }

        canvas.drawLine(
          Offset(marginLeft - 5, screenY),
          Offset(marginLeft, screenY),
          paintAxis,
        );
        
        final yLabel = TextPainter(
          text: TextSpan(text: yVal.toStringAsFixed(1), style: textStyle),
          textDirection: TextDirection.ltr,
        );
        yLabel.layout();
        yLabel.paint(canvas, Offset(marginLeft - yLabel.width - 10, screenY - yLabel.height / 2));
      }

      // Draw axis titles
      final xTitle = TextPainter(
        text: TextSpan(text: props.xAxisLabel, style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      xTitle.layout();
      xTitle.paint(canvas, Offset(marginLeft + plotWidth / 2 - xTitle.width / 2, size.height - 20));

      final yTitle = TextPainter(
        text: TextSpan(text: props.yAxisLabel, style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      yTitle.layout();
      
      canvas.save();
      canvas.translate(20, marginTop + plotHeight / 2 + yTitle.width / 2);
      canvas.rotate(-math.pi / 2);
      yTitle.paint(canvas, Offset.zero);
      canvas.restore();
    }

    void drawLine() {
      if (length > 0) {
        final path = Path();
        final firstPoint = mapToScreen(xData[0], yData[0]);
        path.moveTo(firstPoint.dx, firstPoint.dy);

        for (int i = 1; i < length; i++) {
          final point = mapToScreen(xData[i], yData[i]);
          path.lineTo(point.dx, point.dy);
        }

        // Draw connecting lines
        canvas.drawPath(path, paintLine);
      }
    }

    void drawScatter() {
      if (length > 0) {
        for (int i = 0; i < length; i++) {
          final point = mapToScreen(xData[i], yData[i]);
          canvas.drawCircle(point, 4, paintPoint);
          canvas.drawCircle(point, 4, paintPointBorder);
        }
      }
    }

    // Draw layers from bottom to top (reverse order of the list)
    for (int i = layers.length - 1; i >= 0; i--) {
      final layer = layers[i];
      if (!layer.isVisible) continue;

      switch (layer.id) {
        case 'axis':
          drawAxis();
          break;
        case 'line_a':
          drawLine();
          break;
        case 'scatter_a':
          drawScatter();
          break;
        default:
          // Ignore unsupported mock layers
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScientificPlotPainter oldDelegate) {
    if (layers != oldDelegate.layers) return true;
    if (props != oldDelegate.props) return true;
    if (xData.length != oldDelegate.xData.length) return true;
    for (int i = 0; i < xData.length; i++) {
      if (xData[i] != oldDelegate.xData[i] || yData[i] != oldDelegate.yData[i]) {
        return true;
      }
    }
    return false;
  }
}
