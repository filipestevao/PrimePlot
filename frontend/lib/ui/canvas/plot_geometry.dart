// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Shared plot geometry: margins, axis transforms, resolved viewport limits,
//! and data<->screen mapping + navigation math (zoom / pan / autoscale).
//!
//! The painter (`plot_canvas.dart`) and the interaction layer
//! (`plot_viewport.dart`) both build on this so gestures map exactly to
//! what is painted. Limits are resolved in *transformed* space (log/sqrt
//! aware); values written back to Rust `GraphProperties` are raw data values.

import 'dart:math' as math;
import 'dart:ui';

import '../../src/rust/api/properties.dart';

// Must match the painter layout in `plot_canvas.dart`.
const double kPlotMarginLeft = 60.0;
const double kPlotMarginBottom = 44.0;
const double kPlotMarginTop = 24.0;
const double kPlotMarginRight = 24.0;

enum PlotAxisScale { linear, log, sqrt }

PlotAxisScale plotAxisScale(String? scale) {
  final normalized = (scale ?? '').toLowerCase();
  if (normalized.contains('log')) return PlotAxisScale.log;
  if (normalized.contains('sqrt') || normalized.contains('square root')) {
    return PlotAxisScale.sqrt;
  }
  return PlotAxisScale.linear;
}

double? transformValue(double value, PlotAxisScale scale) {
  switch (scale) {
    case PlotAxisScale.linear:
      return value.isFinite ? value : null;
    case PlotAxisScale.log:
      return value > 0 && value.isFinite ? math.log(value) / math.ln10 : null;
    case PlotAxisScale.sqrt:
      return value >= 0 && value.isFinite ? math.sqrt(value) : null;
  }
}

double inverseTransformValue(double value, PlotAxisScale scale) {
  switch (scale) {
    case PlotAxisScale.linear:
      return value;
    case PlotAxisScale.log:
      return math.pow(10, value).toDouble();
    case PlotAxisScale.sqrt:
      return value * value;
  }
}

/// Resolved viewport limits in *transformed* space.
class PlotView {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final PlotAxisScale xScale;
  final PlotAxisScale yScale;

  const PlotView({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xScale,
    required this.yScale,
  });

  double get spanX => maxX - minX;
  double get spanY => maxY - minY;

  Rect plotRect(Size size) {
    return Rect.fromLTWH(
      kPlotMarginLeft,
      kPlotMarginTop,
      size.width - kPlotMarginLeft - kPlotMarginRight,
      size.height - kPlotMarginTop - kPlotMarginBottom,
    );
  }
}

/// Raw data-space limits, ready to write into Rust `GraphProperties`.
class RawLimits {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  const RawLimits({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  bool get isValid =>
      xMin.isFinite && xMax.isFinite && yMin.isFinite && yMax.isFinite;
}

/// Mirrors the painter: envelope of finite transformed points, overridden by
/// explicit Rust limits. Returns null when there is nothing finite to show.
PlotView? resolvePlotView({
  required List<List<double>> xSeries,
  required List<List<double>> ySeries,
  required GraphProperties? graphProps,
}) {
  final xScale = plotAxisScale(graphProps?.xScale);
  final yScale = plotAxisScale(graphProps?.yScale);
  final combinedX = <double>[];
  final combinedY = <double>[];

  for (var s = 0; s < xSeries.length; s++) {
    final len = math.min(xSeries[s].length, ySeries[s].length);
    for (var i = 0; i < len; i++) {
      final tx = transformValue(xSeries[s][i], xScale);
      final ty = transformValue(ySeries[s][i], yScale);
      if (tx != null && ty != null) {
        combinedX.add(tx);
        combinedY.add(ty);
      }
    }
  }
  if (combinedX.isEmpty || combinedY.isEmpty) return null;

  var minX = combinedX.reduce(math.min);
  var maxX = combinedX.reduce(math.max);
  var minY = combinedY.reduce(math.min);
  var maxY = combinedY.reduce(math.max);

  final overrideXMin = graphProps?.xMin != null
      ? transformValue(graphProps!.xMin!, xScale)
      : null;
  final overrideXMax = graphProps?.xMax != null
      ? transformValue(graphProps!.xMax!, xScale)
      : null;
  final overrideYMin = graphProps?.yMin != null
      ? transformValue(graphProps!.yMin!, yScale)
      : null;
  final overrideYMax = graphProps?.yMax != null
      ? transformValue(graphProps!.yMax!, yScale)
      : null;
  if (overrideXMin != null) minX = overrideXMin;
  if (overrideXMax != null) maxX = overrideXMax;
  if (overrideYMin != null) minY = overrideYMin;
  if (overrideYMax != null) maxY = overrideYMax;

  if (maxX <= minX) maxX = minX + 1;
  if (maxY <= minY) maxY = minY + 1;

  return PlotView(
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    xScale: xScale,
    yScale: yScale,
  );
}

Offset _clampToPlot(Offset pos, Rect rect) {
  return Offset(
    pos.dx.clamp(rect.left, rect.right),
    pos.dy.clamp(rect.top, rect.bottom),
  );
}

/// Screen pixels → raw data coordinates (cursor position clamped to plot).
/// Returns null when the view is degenerate or values don't map finitely.
Offset? screenToData(Offset pos, Size size, PlotView view) {
  final rect = view.plotRect(size);
  if (rect.width <= 0 || rect.height <= 0) return null;
  final c = _clampToPlot(pos, rect);
  final tx = view.minX + (c.dx - rect.left) / rect.width * view.spanX;
  final ty = view.minY + (rect.bottom - c.dy) / rect.height * view.spanY;
  final x = inverseTransformValue(tx, view.xScale);
  final y = inverseTransformValue(ty, view.yScale);
  if (!x.isFinite || !y.isFinite) return null;
  return Offset(x, y);
}

/// Raw data coordinates → screen pixels. Null when unmappable.
Offset? dataToScreen(double x, double y, Size size, PlotView view) {
  final rect = view.plotRect(size);
  if (rect.width <= 0 || rect.height <= 0) return null;
  final tx = transformValue(x, view.xScale);
  final ty = transformValue(y, view.yScale);
  if (tx == null || ty == null) return null;
  final sx = rect.left + (tx - view.minX) / view.spanX * rect.width;
  final sy = rect.bottom - (ty - view.minY) / view.spanY * rect.height;
  if (!sx.isFinite || !sy.isFinite) return null;
  return Offset(sx, sy);
}

/// Zoom keeping the data under [cursor] fixed. `factor > 1` zooms out.
RawLimits? zoomAtCursor({
  required PlotView view,
  required Offset cursor,
  required Size size,
  required double factor,
}) {
  if (!factor.isFinite || factor <= 0) return null;
  final f = factor.clamp(1e-3, 1e3);
  final rect = view.plotRect(size);
  if (rect.width <= 0 || rect.height <= 0) return null;
  final c = _clampToPlot(cursor, rect);
  final tx = view.minX + (c.dx - rect.left) / rect.width * view.spanX;
  final ty = view.minY + (rect.bottom - c.dy) / rect.height * view.spanY;

  final nMinX = tx - (tx - view.minX) * f;
  final nMaxX = tx + (view.maxX - tx) * f;
  final nMinY = ty - (ty - view.minY) * f;
  final nMaxY = ty + (view.maxY - ty) * f;
  if (nMaxX - nMinX < 1e-12 || nMaxY - nMinY < 1e-12) return null;

  final raw = RawLimits(
    xMin: inverseTransformValue(nMinX, view.xScale),
    xMax: inverseTransformValue(nMaxX, view.xScale),
    yMin: inverseTransformValue(nMinY, view.yScale),
    yMax: inverseTransformValue(nMaxY, view.yScale),
  );
  return raw.isValid ? raw : null;
}

/// Grab-pan: content follows the cursor.
RawLimits? panByPixels({
  required PlotView view,
  required Offset delta,
  required Size size,
}) {
  final rect = view.plotRect(size);
  if (rect.width <= 0 || rect.height <= 0) return null;
  if (!delta.dx.isFinite || !delta.dy.isFinite) return null;
  final nMinX = view.minX - delta.dx / rect.width * view.spanX;
  final nMaxX = view.maxX - delta.dx / rect.width * view.spanX;
  final nMinY = view.minY + delta.dy / rect.height * view.spanY;
  final nMaxY = view.maxY + delta.dy / rect.height * view.spanY;

  final raw = RawLimits(
    xMin: inverseTransformValue(nMinX, view.xScale),
    xMax: inverseTransformValue(nMaxX, view.xScale),
    yMin: inverseTransformValue(nMinY, view.yScale),
    yMax: inverseTransformValue(nMaxY, view.yScale),
  );
  return raw.isValid ? raw : null;
}

/// Envelope of [visible] series plus a 5% margin, as raw data limits.
/// Returns null when no visible series holds finite points.
RawLimits? autoscaleLimits({
  required List<List<double>> xSeries,
  required List<List<double>> ySeries,
  required List<bool> visible,
  required GraphProperties? graphProps,
}) {
  final xScale = plotAxisScale(graphProps?.xScale);
  final yScale = plotAxisScale(graphProps?.yScale);
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;

  for (var s = 0; s < xSeries.length && s < ySeries.length; s++) {
    if (s < visible.length && !visible[s]) continue;
    final len = math.min(xSeries[s].length, ySeries[s].length);
    for (var i = 0; i < len; i++) {
      final tx = transformValue(xSeries[s][i], xScale);
      final ty = transformValue(ySeries[s][i], yScale);
      if (tx == null || ty == null) continue;
      if (tx < minX) minX = tx;
      if (tx > maxX) maxX = tx;
      if (ty < minY) minY = ty;
      if (ty > maxY) maxY = ty;
    }
  }
  if (minX.isInfinite || maxX.isInfinite || minY.isInfinite || maxY.isInfinite) {
    return null;
  }

  // Degenerate span guard, then 5% breathing room on each side.
  if (maxX <= minX) {
    final half = minX.abs() > 0 ? minX.abs() * 0.05 : 0.5;
    minX -= half;
    maxX += half;
  }
  if (maxY <= minY) {
    final half = minY.abs() > 0 ? minY.abs() * 0.05 : 0.5;
    minY -= half;
    maxY += half;
  }
  final spanX = maxX - minX;
  final spanY = maxY - minY;
  minX -= spanX * 0.05;
  maxX += spanX * 0.05;
  minY -= spanY * 0.05;
  maxY += spanY * 0.05;

  final raw = RawLimits(
    xMin: inverseTransformValue(minX, xScale),
    xMax: inverseTransformValue(maxX, xScale),
    yMin: inverseTransformValue(minY, yScale),
    yMax: inverseTransformValue(maxY, yScale),
  );
  return raw.isValid ? raw : null;
}
