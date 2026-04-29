import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../src/rust/api/data.dart';

class PlotCanvas extends StatefulWidget {
  const PlotCanvas({super.key});

  @override
  State<PlotCanvas> createState() => _PlotCanvasState();
}

class _PlotCanvasState extends State<PlotCanvas> {
  List<Point2D> _rustData = [];

  @override
  void initState() {
    super.initState();
    // Fetch 2000 data points synchronously from the Rust core_math engine
    _rustData = getMockScientificData(numPoints: BigInt.from(2000));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PrimeTheme.backgroundDark, // Slightly darker than panels for contrast
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          // The actual drawing canvas
          Positioned.fill(
            child: ClipRect(
              child: CustomPaint(
                painter: _ScientificPlotPainter(_rustData),
              ),
            ),
          ),
          // Floating Toolbar / Status indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: PrimeTheme.panelBackground.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: PrimeTheme.borderSide),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory, size: 14, color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  Text('Rust Engine Active: ${_rustData.length} pts', 
                       style: const TextStyle(fontSize: 11, color: PrimeTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScientificPlotPainter extends CustomPainter {
  final List<Point2D> data;

  _ScientificPlotPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid
    final gridPaint = Paint()
      ..color = PrimeTheme.borderSide.withOpacity(0.3)
      ..strokeWidth = 1.0;
    
    const double step = 50.0;
    
    // Vertical grid lines
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal grid lines
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw Axes
    final axisPaint = Paint()
      ..color = PrimeTheme.textSecondary
      ..strokeWidth = 2.0;

    // Y Axis
    canvas.drawLine(Offset(step, 0), Offset(step, size.height - step), axisPaint);
    // X Axis
    canvas.drawLine(Offset(step, size.height - step), Offset(size.width, size.height - step), axisPaint);

    // 3. Draw the real data from Rust
    if (data.isEmpty) return;

    final curvePaint = Paint()
      ..color = PrimeTheme.primaryAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = PrimeTheme.primaryAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final path = Path();
    
    final xStart = step;
    final xEnd = size.width;
    final yBase = size.height - step;

    // Find min and max X to normalize
    final minX = data.first.x;
    final maxX = data.last.x;
    final rangeX = maxX - minX;

    // We assume max Y is roughly 100 for this mock data
    const maxY = 100.0; 

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      
      // Normalize to screen coordinates
      final screenX = xStart + ((point.x - minX) / rangeX) * (xEnd - xStart);
      
      // Flip Y axis (Flutter origin is top-left)
      final screenY = yBase - (point.y / maxY) * (size.height * 0.8); // Scale to 80% of height

      if (i == 0) {
        path.moveTo(screenX, screenY);
      } else {
        path.lineTo(screenX, screenY);
      }
    }

    // Draw glow then sharp line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _ScientificPlotPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
