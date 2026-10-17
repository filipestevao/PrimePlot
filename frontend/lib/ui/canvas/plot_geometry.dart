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

import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../src/rust/api/properties.dart';

// Fallback layout before any data resolves (viewport overlay with no view).
const double kPlotMarginLeft = 60.0;
const double kPlotMarginBottom = 44.0;
const double kPlotMarginTop = 24.0;
const double kPlotMarginRight = 24.0;

/// Gap between an axis line and its tick-number labels (painter and margin
/// measurement must agree).
const double kAxisLabelGap = 10.0;

/// Breathing room between an axis title and the canvas edge.
const double kAxisTitlePad = 6.0;

/// Single source for axis-title sizing, shared by the painter, the LaTeX
/// overlay, and the margin computation.
double axisTitleSize(GraphProperties? graphProps) =>
    (graphProps?.titleFontSize ?? 12.0).clamp(6.0, 32.0);

/// Single source for tick-number sizing.
double axisTickSize(GraphProperties? graphProps) =>
    (graphProps?.tickFontSize ?? 10.0).clamp(6.0, 28.0);

/// Axis tick label under the active locale (same rules as the painter).
String formatTickLabel(double value) {
  final abs = value.abs();
  String dotted;
  if (abs != 0 && (abs >= 10000 || abs < 0.001)) {
    dotted = value.toStringAsExponential(1);
  } else if (abs >= 100) {
    dotted = value.toStringAsFixed(0);
  } else if (abs >= 10) {
    dotted = value.toStringAsFixed(1);
  } else {
    dotted = value.toStringAsFixed(2);
  }
  return groupDotted(dotted);
}

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

/// Resolved canvas margins in logical pixels.
///
/// Tick numbers keep a fixed [kAxisLabelGap] band next to their axis; each
/// title sits `max(band, gap)` away from the axis so it never overlaps the
/// numbers, and the margin grows to fit it (titles never clip). The title
/// gaps come from `GraphProperties.titlePadding` (X) and `titlePaddingY` (Y).
class PlotMargins {
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Distance from the X axis line to the top of the X title box.
  final double xTitleTop;

  /// Distance from the Y axis line to the right edge of the Y title box.
  final double yTitleFromAxis;

  const PlotMargins({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.xTitleTop,
    required this.yTitleFromAxis,
  });

  /// Pre-data layout matching the historical fixed margins.
  static const fallback = PlotMargins(
    left: kPlotMarginLeft,
    top: kPlotMarginTop,
    right: kPlotMarginRight,
    bottom: kPlotMarginBottom,
    xTitleTop: 24.0,
    yTitleFromAxis: 42.0,
  );

  @override
  bool operator ==(Object other) {
    return other is PlotMargins &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.xTitleTop == xTitleTop &&
        other.yTitleFromAxis == yTitleFromAxis;
  }

  @override
  int get hashCode =>
      Object.hash(left, top, right, bottom, xTitleTop, yTitleFromAxis);
}

Size _measureTickText(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return Size(painter.width, painter.height);
}

/// Resolves the canvas margins for the current fonts and title gaps.
PlotMargins computePlotMargins(
  GraphProperties? graphProps, {
  required double minY,
  required double maxY,
  required PlotAxisScale yScale,
}) {
  final titleLineHeight = _measureTickText(
    'Hg',
    TextStyle(fontSize: axisTitleSize(graphProps), fontWeight: FontWeight.bold),
  ).height;

  final fallback = PlotMargins.fallback;
  var bottom = fallback.bottom;
  var xTitleTop = fallback.xTitleTop;
  if (graphProps?.xVisible ?? true) {
    final tickLineHeight = _measureTickText(
      'Hg',
      TextStyle(fontSize: axisTickSize(graphProps)),
    ).height;
    final bandX = kAxisLabelGap + tickLineHeight;
    final gapX = (graphProps?.titlePadding ?? 20.0).clamp(0.0, 80.0);
    xTitleTop = math.max(bandX, gapX);
    bottom = xTitleTop + titleLineHeight + kAxisTitlePad;
  }

  var left = fallback.left;
  var yTitleFromAxis = fallback.yTitleFromAxis;
  if (graphProps?.yVisible ?? true) {
    final tickStyle = TextStyle(fontSize: axisTickSize(graphProps));
    var tickWidth = 0.0;
    const ticks = 5;
    for (var i = 0; i <= ticks; i++) {
      final rawY = inverseTransformValue(
        minY + (maxY - minY) * i / ticks,
        yScale,
      );
      final width = _measureTickText(formatTickLabel(rawY), tickStyle).width;
      if (width > tickWidth) tickWidth = width;
    }
    final bandY = kAxisLabelGap + tickWidth;
    final gapY = (graphProps?.titlePaddingY ?? 20.0).clamp(0.0, 80.0);
    yTitleFromAxis = math.max(bandY, gapY) + titleLineHeight;
    left = yTitleFromAxis + kAxisTitlePad;
  }

  return PlotMargins(
    left: left,
    top: kPlotMarginTop,
    right: kPlotMarginRight,
    bottom: bottom,
    xTitleTop: xTitleTop,
    yTitleFromAxis: yTitleFromAxis,
  );
}

/// Resolved viewport limits in *transformed* space.
class PlotView {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final PlotAxisScale xScale;
  final PlotAxisScale yScale;
  final PlotMargins margins;

  const PlotView({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xScale,
    required this.yScale,
    required this.margins,
  });

  double get spanX => maxX - minX;
  double get spanY => maxY - minY;

  Rect plotRect(Size size) {
    return Rect.fromLTWH(
      margins.left,
      margins.top,
      size.width - margins.left - margins.right,
      size.height - margins.top - margins.bottom,
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
    margins: computePlotMargins(
      graphProps,
      minY: minY,
      maxY: maxY,
      yScale: yScale,
    ),
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
