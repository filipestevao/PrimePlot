// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/data.dart';
import '../../src/rust/api/properties.dart';

Color _parseHexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

class PlotCanvas extends StatelessWidget {
  const PlotCanvas({super.key});

  @override
  Widget build(BuildContext context) {
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

        return ValueListenableBuilder<GraphProperties?>(
          valueListenable: ProjectState.instance.activeGraphProps,
          builder: (context, graphProps, child) {
            final List<List<double>> seriesX = [];
            final List<List<double>> seriesY = [];
            final List<TableProperties> tablePropsList = [];

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

              try {
                tablePropsList.add(getTableProperties(nodeId: tableData.id));
              } catch (_) {
                tablePropsList.add(TableProperties(
                  legendDisplayName: tableData.name,
                  lineStyle: 'solid',
                  lineThickness: 2.0,
                  lineVisible: true,
                  markerType: 'circle',
                  markerVisible: true,
                  lineColor: '#00C3FF',
                  markerColor: '#00C3FF',
                ));
              }
            }

            Widget canvas = CustomPaint(
              painter: _MultiSeriesPlotPainter(seriesX, seriesY, graphProps, tablePropsList),
              child: Container(),
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
  }
}

/// Painter that supports multiple series. Uses per-table properties for styling.
class _MultiSeriesPlotPainter extends CustomPainter {
  final List<List<double>> xSeries;
  final List<List<double>> ySeries;
  final GraphProperties? graphProps;
  final List<TableProperties> tablePropsList;

  _MultiSeriesPlotPainter(this.xSeries, this.ySeries, this.graphProps, this.tablePropsList);

  @override
  void paint(Canvas canvas, Size size) {
    if (xSeries.isEmpty || ySeries.isEmpty) return;

    final combinedX = <double>[];
    final combinedY = <double>[];
    for (int s = 0; s < xSeries.length; s++) {
      combinedX.addAll(xSeries[s]);
      combinedY.addAll(ySeries[s]);
    }
    if (combinedX.isEmpty || combinedY.isEmpty) return;

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

    if (graphProps?.xMin != null) minX = graphProps!.xMin!;
    if (graphProps?.xMax != null) maxX = graphProps!.xMax!;
    if (graphProps?.yMin != null) minY = graphProps!.yMin!;
    if (graphProps?.yMax != null) maxY = graphProps!.yMax!;

    if (maxX <= minX) maxX = minX + 1;
    if (maxY <= minY) maxY = minY + 1;

    final bool showGrid = graphProps?.showGrid ?? true;
    final bool showAxis = (graphProps?.xVisible ?? true) || (graphProps?.yVisible ?? true);

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
      final xTitle = TextPainter(text: TextSpan(text: graphProps?.xLabel ?? 'X', style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      xTitle.layout();
      xTitle.paint(canvas, Offset(marginLeft + plotWidth / 2 - xTitle.width / 2, size.height - 20));
      final yTitle = TextPainter(text: TextSpan(text: graphProps?.yLabel ?? 'Y', style: const TextStyle(color: PrimeTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      yTitle.layout();
      canvas.save();
      canvas.translate(20, marginTop + plotHeight / 2 + yTitle.width / 2);
      canvas.rotate(-math.pi / 2);
      yTitle.paint(canvas, Offset.zero);
      canvas.restore();
    }

    if (showAxis) drawAxis();

    for (int s = 0; s < xSeries.length; s++) {
      final xs = xSeries[s];
      final ys = ySeries[s];
      if (xs.isEmpty || ys.isEmpty) continue;

      final tp = s < tablePropsList.length ? tablePropsList[s] : null;
      final lineVisible = tp?.lineVisible ?? true;
      final markerVisible = tp?.markerVisible ?? true;
      final lineColor = tp != null ? _parseHexColor(tp.lineColor) : const Color(0xFF00C3FF);
      final lineThickness = tp?.lineThickness ?? 2.0;

      final paintLine = Paint()..color = lineColor..strokeWidth = lineThickness..style = PaintingStyle.stroke..isAntiAlias = true;
      final paintPoint = Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true;
      final paintPointBorder = Paint()..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke..isAntiAlias = true;

      final len = math.min(xs.length, ys.length);
      if (lineVisible && len > 0) {
        final path = Path();
        final first = mapToScreen(xs[0], ys[0]);
        path.moveTo(first.dx, first.dy);
        for (int i = 1; i < len; i++) {
          final p = mapToScreen(xs[i], ys[i]);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paintLine);
      }

      if (markerVisible && len > 0) {
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
    if (graphProps != oldDelegate.graphProps) return true;
    if (tablePropsList.length != oldDelegate.tablePropsList.length) return true;
    for (int i = 0; i < tablePropsList.length; i++) {
      if (tablePropsList[i] != oldDelegate.tablePropsList[i]) return true;
    }
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
