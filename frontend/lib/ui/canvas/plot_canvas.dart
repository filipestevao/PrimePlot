import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PlotCanvas extends StatelessWidget {
  const PlotCanvas({super.key});

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
                painter: _ScientificPlotPainter(),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.memory, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 6),
                  Text('Rust Engine Active', style: TextStyle(fontSize: 11, color: PrimeTheme.textSecondary)),
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

    // 3. Draw a premium dummy curve (e.g. simulated Lorentzian/Gaussian peak for XRD)
    final curvePaint = Paint()
      ..color = PrimeTheme.primaryAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = PrimeTheme.primaryAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final path = Path();
    bool first = true;
    
    final xStart = step;
    final xEnd = size.width;
    final yBase = size.height - step;

    for (double x = xStart; x <= xEnd; x += 2.0) {
      // Simulate an X-ray diffraction peak
      final normalizedX = (x - xStart) / (xEnd - xStart) * 100.0;
      
      // A mixture of two peaks
      final peak1 = 80.0 * exp(-pow(normalizedX - 30.0, 2) / 10.0);
      final peak2 = 40.0 * exp(-pow(normalizedX - 60.0, 2) / 20.0);
      final noise = (Random().nextDouble() - 0.5) * 2.0;
      
      final y = yBase - (peak1 + peak2 + noise) * (size.height * 0.005);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw glow then sharp line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; // Static for now
}
