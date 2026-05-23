import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/data.dart';

class PlotCanvas extends StatelessWidget {
  const PlotCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DTODataTable?>(
      valueListenable: ProjectState.instance.activeTable,
      builder: (context, tableData, child) {
        if (tableData == null ||
            tableData.columns.length < 2 ||
            tableData.columns.first.data.isEmpty) {
          return const Center(
            child: Text(
              'No data available to plot.',
              style: TextStyle(color: PrimeTheme.textSecondary),
            ),
          );
        }

        // Find X and Y columns
        DTODataColumn? xCol;
        DTODataColumn? yCol;

        for (var col in tableData.columns) {
          if (col.role == DTOColumnRole.x && xCol == null) xCol = col;
          if (col.role == DTOColumnRole.y && yCol == null) yCol = col;
        }

        // Fallback to first two columns if roles not assigned
        xCol ??= tableData.columns[0];
        yCol ??= tableData.columns[1];

        return ValueListenableBuilder<List<LayerItem>>(
          valueListenable: ProjectState.instance.layers,
          builder: (context, layers, child) {
            return ValueListenableBuilder<PlotProperties>(
              valueListenable: ProjectState.instance.plotProperties,
              builder: (context, props, child) {
                // Build NaN-free paired lists for the painter.
                final xRaw = xCol!.data;
                final yRaw = yCol!.data;
                final List<double> xClean = [];
                final List<double> yClean = [];
                final len = math.min(xRaw.length, yRaw.length);
                for (int i = 0; i < len; i++) {
                  if (!xRaw[i].isNaN && !yRaw[i].isNaN) {
                    xClean.add(xRaw[i]);
                    yClean.add(yRaw[i]);
                  }
                }

                Widget canvas = CustomPaint(
                  painter: _ScientificPlotPainter(
                      xClean, yClean, layers, props),
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
        
        if (props.showGrid) {
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
        
        if (props.showGrid) {
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
