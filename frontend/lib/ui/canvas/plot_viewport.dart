// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Interactive canvas viewport: wheel zoom at cursor, left-drag box zoom,
//! right/middle-drag grab-pan, dashed crosshair + live coordinate readout,
//! double-click autoscale (envelope + 5% margin).
//!
//! Navigation writes explicit limits into Rust `GraphProperties` (SSOT)
//! via `ProjectState.updateGraphProperties`, so views persist and the
//! dirty star lights up. Hover/marquee state stays local ephemeral UI.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/properties.dart';
import '../panels/property_inspector.dart' show GraphPropertiesExt;
import 'plot_geometry.dart';

class PlotViewport extends StatefulWidget {
  final List<List<double>> xSeries;
  final List<List<double>> ySeries;
  final GraphProperties? graphProps;
  final String? plotId;
  final Widget child;

  const PlotViewport({
    super.key,
    required this.xSeries,
    required this.ySeries,
    required this.graphProps,
    required this.plotId,
    required this.child,
  });

  @override
  State<PlotViewport> createState() => _PlotViewportState();
}

class _PlotViewportState extends State<PlotViewport> {
  Offset? _hover;
  bool _panning = false;
  Offset? _panLast;
  Offset? _marqueeStart;
  Rect? _marquee;

  bool get _canNavigate =>
      widget.plotId != null && widget.graphProps != null;

  PlotView? _resolve() {
    return resolvePlotView(
      xSeries: widget.xSeries,
      ySeries: widget.ySeries,
      graphProps: widget.graphProps,
    );
  }

  Size? _boxSize() {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null || size.width <= 0 || size.height <= 0) return null;
    return size;
  }

  void _write(RawLimits raw) {
    final id = widget.plotId;
    final gp = widget.graphProps;
    if (id == null || gp == null || !raw.isValid) return;
    ProjectState.instance.updateGraphProperties(
      id,
      gp.copyWith(
        xMin: () => raw.xMin,
        xMax: () => raw.xMax,
        yMin: () => raw.yMin,
        yMax: () => raw.yMax,
      ),
    );
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_canNavigate) return;
    final view = _resolve();
    final size = _boxSize();
    if (view == null || size == null) return;
    final delta = event.scrollDelta.dy != 0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0 || !delta.isFinite) return;
    final raw = zoomAtCursor(
      view: view,
      cursor: event.localPosition,
      size: size,
      factor: math.pow(1.0015, delta).toDouble(),
    );
    if (raw != null) _write(raw);
  }

  void _onDown(PointerDownEvent event) {
    if (!_canNavigate) return;
    // Left button starts a marquee box zoom; right/middle buttons pan.
    if ((event.buttons & kPrimaryMouseButton) != 0) {
      setState(() {
        _marqueeStart = event.localPosition;
        _marquee = Rect.fromPoints(event.localPosition, event.localPosition);
      });
      return;
    }
    if ((event.buttons & (kSecondaryMouseButton | kMiddleMouseButton)) != 0) {
      setState(() {
        _panning = true;
        _panLast = event.localPosition;
        _hover = event.localPosition;
      });
    }
  }

  void _onMove(PointerMoveEvent event) {
    setState(() => _hover = event.localPosition);
    if (_marqueeStart != null) {
      setState(() {
        _marquee = Rect.fromPoints(_marqueeStart!, event.localPosition);
      });
      return;
    }
    if (!_panning || !_canNavigate) return;
    final last = _panLast;
    _panLast = event.localPosition;
    if (last == null) return;
    final view = _resolve();
    final size = _boxSize();
    if (view == null || size == null) return;
    final raw = panByPixels(
      view: view,
      delta: event.localPosition - last,
      size: size,
    );
    if (raw != null) _write(raw);
  }

  void _onUp(PointerUpEvent event) {
    if (_marqueeStart != null) {
      _applyMarquee(event.localPosition);
    }
    setState(() {
      _panning = false;
      _panLast = null;
      _marqueeStart = null;
      _marquee = null;
      _hover = event.localPosition;
    });
  }

  void _onCancel(PointerCancelEvent event) {
    setState(() {
      _panning = false;
      _panLast = null;
      _marqueeStart = null;
      _marquee = null;
    });
  }

  void _applyMarquee(Offset end) {
    final start = _marqueeStart;
    if (start == null || !_canNavigate) return;
    final rect = Rect.fromPoints(start, end);
    if (rect.width < 8 || rect.height < 8) return; // treat as plain click
    final view = _resolve();
    final size = _boxSize();
    if (view == null || size == null) return;
    final a = screenToData(rect.topLeft, size, view);
    final b = screenToData(rect.bottomRight, size, view);
    if (a == null || b == null) return;
    final raw = RawLimits(
      xMin: math.min(a.dx, b.dx),
      xMax: math.max(a.dx, b.dx),
      yMin: math.min(a.dy, b.dy),
      yMax: math.max(a.dy, b.dy),
    );
    if (raw.isValid && raw.xMax > raw.xMin && raw.yMax > raw.yMin) {
      _write(raw);
    }
  }

  /// Double-click returns to the inspector-defined home ranges
  /// (or Auto when the user never set any). No-op when already home.
  void _autoscale() {
    final id = widget.plotId;
    final gp = widget.graphProps;
    if (id == null || gp == null) return;
    final st = ProjectState.instance;
    final home = st.homeViewFor(id, gp);
    if (home.matches(gp)) return;
    st.updateGraphProperties(
      id,
      gp.copyWith(
        xMin: () => home.xMin,
        xMax: () => home.xMax,
        yMin: () => home.yMin,
        yMax: () => home.yMax,
      ),
    );
  }

  static String _fmt(double v) {
    final a = v.abs();
    if (a != 0 && (a >= 10000 || a < 0.001)) {
      return v.toStringAsExponential(2);
    }
    return v.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final view = _resolve();
        final data = (_hover != null && view != null)
            ? screenToData(_hover!, size, view)
            : null;

        return MouseRegion(
          // Crosshair hints left-drag box zoom; grabber while right-panning.
          cursor: _panning
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.precise,
          onHover: (e) => setState(() => _hover = e.localPosition),
          onExit: (_) => setState(() => _hover = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _autoscale,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _onScroll,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onCancel,
              child: Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ViewportOverlay(
                        hover: _hover,
                        marquee: _marquee,
                      ),
                    ),
                  ),
                  // Readout lives in the top margin strip, above the axes,
                  // so it never covers data.
                  if (data != null)
                    Positioned(
                      left: 8,
                      top: 2,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: PrimeTheme.panelBackground.withValues(
                              alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: PrimeTheme.borderSide),
                          ),
                          child: Text(
                            'X: ${_fmt(data.dx)}   Y: ${_fmt(data.dy)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: PrimeTheme.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ViewportOverlay extends CustomPainter {
  final Offset? hover;
  final Rect? marquee;

  const _ViewportOverlay({required this.hover, required this.marquee});

  void _dashLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (p2 - p1).distance;
    if (total <= 0) return;
    final dir = (p2 - p1) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final next = math.min(travelled + dash, total);
      canvas.drawLine(p1 + dir * travelled, p1 + dir * next, paint);
      travelled = next + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      kPlotMarginLeft,
      kPlotMarginTop,
      size.width - kPlotMarginLeft - kPlotMarginRight,
      size.height - kPlotMarginTop - kPlotMarginBottom,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final h = hover;
    if (h != null &&
        h.dx >= rect.left &&
        h.dx <= rect.right &&
        h.dy >= rect.top &&
        h.dy <= rect.bottom) {
      final paint = Paint()
        ..color = PrimeTheme.textSecondary.withValues(alpha: 0.5)
        ..strokeWidth = 1.0;
      _dashLine(canvas, Offset(h.dx, rect.top), Offset(h.dx, rect.bottom), paint);
      _dashLine(canvas, Offset(rect.left, h.dy), Offset(rect.right, h.dy), paint);
    }

    final m = marquee;
    if (m != null && m.width >= 2 && m.height >= 2) {
      canvas.drawRect(
        m,
        Paint()..color = PrimeTheme.primaryAccent.withValues(alpha: 0.12),
      );
      canvas.drawRect(
        m,
        Paint()
          ..color = PrimeTheme.primaryAccent
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ViewportOverlay old) {
    return hover != old.hover || marquee != old.marquee;
  }
}
