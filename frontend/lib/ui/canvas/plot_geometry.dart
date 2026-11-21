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
    (graphProps?.titleFontSize ?? 12.0).clamp(6.0, 48.0);

/// Single source for tick-number sizing.
double axisTickSize(GraphProperties? graphProps) =>
    (graphProps?.tickFontSize ?? 10.0).clamp(6.0, 40.0);

/// Number of grid intervals on an axis; `None` keeps the historical 5.
int axisIntervalCount(int? divisions) => (divisions ?? 5).clamp(1, 50);

const List<double> _niceStepCandidates = [1.0, 1.5, 2.0, 2.5, 5.0, 10.0];

/// Integer steps in sqrt space keep raw ticks at perfect squares whenever
/// the visible range starts on one (0, 1, 4, 9, ...).
const List<double> _sqrtStepCandidates = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0];

double _niceStep(
  double min,
  double max,
  int targetIntervals, {
  List<double> candidates = _niceStepCandidates,
}) {
  final span = max - min;
  final target = targetIntervals.clamp(1, 50);
  final rough = span / target;
  final exponent = (math.log(rough) / math.ln10).floor();
  final magnitude = math.pow(10.0, exponent.toDouble()).toDouble();
  if (!magnitude.isFinite || magnitude <= 0) return rough;

  // Prefer the candidate whose generated tick count is closest to the
  // requested number of intervals plus both endpoints. Ties use the finer
  // step, which favors 15/25/150/2500-style ticks over 20/50/200/5000.
  final desiredTicks = target + 1;
  var bestStep = magnitude;
  var bestScore = double.infinity;
  for (final candidate in candidates) {
    final step = candidate * magnitude;
    final first = (min / step).ceil() * step;
    final last = (max / step).floor() * step;
    final count = last + step * 1e-9 < first
        ? 0
        : ((last - first) / step).round() + 1;
    final score = (count - desiredTicks).abs().toDouble();
    if (score < bestScore - 1e-9 ||
        (score == bestScore && step < bestStep)) {
      bestStep = step;
      bestScore = score;
    }
  }
  return bestStep;
}

/// Nice major tick values within the raw data range [min, max].
///
/// Linear and square-root axes choose nice intervals in transformed space.
/// Log axes use powers of ten, falling back to 1/2/5 sub-decade marks when
/// the visible span is narrow. The returned values are raw data coordinates,
/// ready for [formatTickLabel] and [dataToScreen].
List<double> computeNiceTicks(
  double min,
  double max, {
  int targetIntervals = 5,
  String scale = 'Linear',
}) {
  if (!min.isFinite || !max.isFinite || max <= min) {
    return min.isFinite ? <double>[min] : const <double>[];
  }

  final axisScale = plotAxisScale(scale);
  if (axisScale == PlotAxisScale.log) {
    return _computeNiceTicksLog(min, max, targetIntervals);
  }
  return _computeNiceTicksTransformed(
    min,
    max,
    targetIntervals,
    axisScale,
  );
}

List<double> _computeNiceTicksTransformed(
  double min,
  double max,
  int targetIntervals,
  PlotAxisScale axisScale,
) {
  final tMin = transformValue(min, axisScale);
  final tMax = transformValue(max, axisScale);
  if (tMin == null ||
      tMax == null ||
      !tMin.isFinite ||
      !tMax.isFinite ||
      tMax <= tMin) {
    return <double>[min, max];
  }

  final step = _niceStep(
    tMin,
    tMax,
    targetIntervals,
    candidates: axisScale == PlotAxisScale.sqrt
        ? _sqrtStepCandidates
        : _niceStepCandidates,
  );
  if (!step.isFinite || step <= 0) return <double>[min, max];

  final first = (tMin / step).ceil() * step;
  final epsilon = step * 1e-9;
  final ticks = <double>[];
  var previous = double.negativeInfinity;
  for (var i = 0; i < 200; i++) {
    final t = first + step * i;
    if (t > tMax + epsilon) break;
    // At very large magnitudes a small step can round to no progress.
    if (t <= previous) break;
    previous = t;
    var raw = inverseTransformValue(t, axisScale);
    if (axisScale == PlotAxisScale.sqrt) raw = _snapSqrtTick(raw);
    if (raw.isFinite) ticks.add(raw);
  }
  return ticks.isEmpty ? <double>[min, max] : ticks;
}

/// Snaps floating-point noise in `t²` back to the nearest integer while
/// leaving genuinely fractional ticks (e.g. 2.25) untouched.
double _snapSqrtTick(double value) {
  if (!value.isFinite) return value;
  final rounded = value.roundToDouble();
  final tolerance = 1e-9 * math.max(1.0, value.abs());
  return (value - rounded).abs() <= tolerance ? rounded : value;
}

List<double> _computeNiceTicksLog(
  double min,
  double max,
  int targetIntervals,
) {
  if (min <= 0 || max <= min) return <double>[min, max];

  final target = targetIntervals.clamp(1, 50);
  final logMin = math.log(min) / math.ln10;
  final logMax = math.log(max) / math.ln10;
  final decMin = logMin.floor();
  final decMax = logMax.ceil();
  final decades = decMax - decMin;
  final epsilon = 1e-9;

  if (decades >= 4) {
    // Wide ranges: powers of ten, thinned to the requested density.
    final skip = math.max(1, (decades / target).round());
    final ticks = <double>[];
    for (var d = decMin; d <= decMax; d += skip) {
      final value = math.pow(10.0, d.toDouble()).toDouble();
      if (value >= min * (1 - epsilon) && value <= max * (1 + epsilon)) {
        ticks.add(value);
      }
    }
    // Preserve the top decade when the skip lands short of it.
    final top = math.pow(10.0, decMax.toDouble()).toDouble();
    if (top >= min * (1 - epsilon) &&
        top <= max * (1 + epsilon) &&
        (ticks.isEmpty || ticks.last < top * (1 - epsilon))) {
      ticks.add(top);
    }
    return ticks.isEmpty ? <double>[min, max] : ticks;
  }

  // Narrow ranges: 1/2/5 marks inside each decade.
  final candidates = <double>[];
  for (var d = decMin; d <= decMax; d++) {
    final base = math.pow(10.0, d.toDouble()).toDouble();
    for (final multiplier in const [1.0, 2.0, 5.0]) {
      final value = base * multiplier;
      if (value >= min * (1 - epsilon) && value <= max * (1 + epsilon)) {
        candidates.add(value);
      }
    }
  }
  if (candidates.isEmpty) return <double>[min, max];
  return _thinTicks(candidates, target);
}

/// Thins a sorted tick list to roughly [targetIntervals] intervals while
/// always keeping both endpoints. The small slack avoids dropping a single
/// useful 1/2/5 mark when the candidate set is only marginally too dense.
List<double> _thinTicks(List<double> ticks, int targetIntervals) {
  if (ticks.length <= 2) return ticks;
  final maxTicks = math.max(2, targetIntervals + 2);
  if (ticks.length <= maxTicks) return ticks;

  final result = <double>[];
  for (var i = 0; i < maxTicks; i++) {
    final index = ((ticks.length - 1) * i / (maxTicks - 1)).round();
    final value = ticks[index];
    if (result.isEmpty || value != result.last) result.add(value);
  }
  return result;
}

/// Minor tick positions between adjacent [majorTicks].
///
/// Returns `subdivisions - 1` evenly spaced interior positions per interval,
/// in the same coordinate space as [majorTicks] (screen pixels when used by
/// the painter). When [start] and [end] are supplied, partial intervals at
/// the visible edges are filled too, using the adjacent major spacing. This
/// keeps minor ticks present when the data range starts/ends between nice
/// major ticks. Positions are sorted when edge bounds are supplied.
List<double> computeMinorTicks(
  List<double> majorTicks,
  int subdivisions, {
  double? start,
  double? end,
}) {
  if (subdivisions <= 1 || majorTicks.length < 2) return const <double>[];
  final count = subdivisions.clamp(2, 50);
  final minor = <double>[];
  for (var i = 0; i < majorTicks.length - 1; i++) {
    final intervalStart = majorTicks[i];
    final intervalEnd = majorTicks[i + 1];
    if (!intervalStart.isFinite ||
        !intervalEnd.isFinite ||
        intervalEnd == intervalStart) {
      continue;
    }
    for (var j = 1; j < count; j++) {
      minor.add(intervalStart + (intervalEnd - intervalStart) * j / count);
    }
  }

  if (start == null || end == null) return minor;

  final ordered = majorTicks.where((tick) => tick.isFinite).toList()..sort();
  if (ordered.length < 2) return minor;
  final lower = math.min(start, end);
  final upper = math.max(start, end);
  final leadingInterval = ordered[1] - ordered[0];
  final trailingInterval = ordered.last - ordered[ordered.length - 2];
  if (!leadingInterval.isFinite ||
      leadingInterval <= 0 ||
      !trailingInterval.isFinite ||
      trailingInterval <= 0) {
    return minor;
  }

  // Fill the partial interval before the first major tick.
  var previous = ordered.first - leadingInterval;
  final leadingStep = leadingInterval / count;
  for (
    var guard = 0;
    previous + leadingInterval > lower && guard < 1000;
    guard++
  ) {
    for (var j = 1; j < count; j++) {
      final position = previous + leadingStep * j;
      if (position >= lower && position < ordered.first) {
        minor.add(position);
      }
    }
    previous -= leadingInterval;
  }

  // Fill the partial interval after the last major tick.
  var next = ordered.last + trailingInterval;
  final trailingStep = trailingInterval / count;
  for (
    var guard = 0;
    next - trailingInterval < upper && guard < 1000;
    guard++
  ) {
    for (var j = 1; j < count; j++) {
      final position = next - trailingInterval + trailingStep * j;
      if (position > ordered.last && position <= upper) {
        minor.add(position);
      }
    }
    next += trailingInterval;
  }

  minor.sort();
  final unique = <double>[];
  for (final position in minor) {
    if (unique.isEmpty || (position - unique.last).abs() > 1e-9) {
      unique.add(position);
    }
  }
  return unique;
}

/// Minor tick values for a logarithmic axis.
///
/// Log minor ticks live at 2..9 within each decade, not at evenly spaced
/// screen positions. [subdivisions] controls how many of those natural marks
/// are kept: 9 keeps all eight, while coarser settings pick marks closest to
/// evenly spaced positions in log space. [start] and [end] extend the marks
/// into partially visible decades.
List<double> computeMinorTicksLog(
  List<double> majorTicks,
  int subdivisions, {
  double? start,
  double? end,
}) {
  if (subdivisions <= 1 || majorTicks.length < 2) return const <double>[];

  final lower = start ?? majorTicks.reduce(math.min);
  final upper = end ?? majorTicks.reduce(math.max);
  if (!lower.isFinite ||
      !upper.isFinite ||
      lower <= 0 ||
      upper <= lower) {
    return const <double>[];
  }

  final multipliers = _logMinorMultipliers(subdivisions);
  final decMin = (math.log(lower) / math.ln10).floor();
  final decMax = (math.log(upper) / math.ln10).floor();
  final epsilon = 1e-9;
  final minor = <double>[];
  for (var d = decMin; d <= decMax; d++) {
    final base = math.pow(10.0, d.toDouble()).toDouble();
    for (final multiplier in multipliers) {
      final value = base * multiplier;
      if (value >= lower * (1 - epsilon) &&
          value <= upper * (1 + epsilon)) {
        minor.add(value);
      }
    }
  }

  minor.sort();
  final unique = <double>[];
  for (final value in minor) {
    if (unique.isEmpty || (value - unique.last).abs() > 1e-9) {
      unique.add(value);
    }
  }
  return unique;
}

/// Picks the natural 2..9 log marks closest to evenly spaced positions
/// between 1 and 10. `subdivisions = 9` returns all eight marks.
List<int> _logMinorMultipliers(int subdivisions) {
  const all = [2, 3, 4, 5, 6, 7, 8, 9];
  final count = (subdivisions - 1).clamp(1, all.length);
  if (count >= all.length) return all;

  final result = <int>[];
  for (var i = 1; i <= count; i++) {
    final target = math.pow(10.0, i / (count + 1)).toDouble();
    var best = all.first;
    var bestDistance = double.infinity;
    for (final multiplier in all) {
      if (result.contains(multiplier)) continue;
      final distance =
          (math.log(multiplier) - math.log(target)).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = multiplier;
      }
    }
    result.add(best);
  }
  result.sort();
  return result;
}

String _formatDecimalTick(double value) {
  final abs = value.abs();
  final int decimals;
  if (abs >= 100) {
    decimals = 0;
  } else if (abs >= 10) {
    decimals = 1;
  } else if (abs >= 1) {
    decimals = 2;
  } else if (abs >= 0.1) {
    decimals = 3;
  } else if (abs >= 0.01) {
    decimals = 4;
  } else if (abs >= 0.001) {
    decimals = 5;
  } else if (abs == 0) {
    decimals = 0;
  } else {
    // Decimal mode is explicit: keep enough places to show the value
    // instead of collapsing tiny ticks to 0.000.
    decimals = (-(math.log(abs) / math.ln10).floor() + 3).clamp(0, 20);
  }
  var s = value.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return groupDotted(s);
}

/// Compact scientific notation: `1e5`, `2.5e6`, `1.2e-4` (no `+`, no
/// redundant mantissa zeros).
String _formatScientificTick(double value) {
  if (!value.isFinite || value == 0) return _formatDecimalTick(value);
  final dotted = value.toStringAsExponential(2);
  final eIndex = dotted.indexOf('e');
  var mantissa = dotted.substring(0, eIndex);
  var exponent = dotted.substring(eIndex + 1);
  if (mantissa.contains('.')) {
    mantissa = mantissa.replaceAll(RegExp(r'0+$'), '');
    mantissa = mantissa.replaceAll(RegExp(r'\.$'), '');
  }
  final negative = exponent.startsWith('-');
  exponent = exponent.replaceAll(RegExp(r'^[+-]'), '');
  exponent = exponent.replaceAll(RegExp(r'^0+(?=\d)'), '');
  return groupDotted('${mantissa}e${negative ? '-' : ''}$exponent');
}

/// Axis tick label under the active locale and the graph's notation mode
/// (`Auto`, `Decimal`, `Scientific`). Auto keeps readable decimals through
/// `10^threshold - 1` (100,000 by default) and switches to scientific only
/// at the configured power of ten or below 0.001.
String formatTickLabel(double value, {GraphProperties? graphProps}) {
  final mode = (graphProps?.numberNotation ?? 'Auto').trim().toLowerCase();
  if (mode.startsWith('decimal')) return _formatDecimalTick(value);
  if (mode.startsWith('scientific')) return _formatScientificTick(value);

  final abs = value.abs();
  final threshold = (graphProps?.scientificThreshold ?? 5).clamp(1, 12);
  final upper = math.pow(10.0, threshold.toDouble()).toDouble();
  if (abs != 0 && (abs >= upper || abs < 0.001)) {
    return _formatScientificTick(value);
  }
  return _formatDecimalTick(value);
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
/// [legendReservedRight] widens the right margin when the legend renders
/// outside the plot rect (`Outside Right` position).
PlotMargins computePlotMargins(
  GraphProperties? graphProps, {
  required double minY,
  required double maxY,
  required PlotAxisScale yScale,
  double legendReservedRight = 0.0,
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
    void measureTick(double rawY) {
      final width = _measureTickText(
        formatTickLabel(rawY, graphProps: graphProps),
        tickStyle,
      ).width;
      if (width > tickWidth) tickWidth = width;
    }

    final rawMinY = inverseTransformValue(minY, yScale);
    final rawMaxY = inverseTransformValue(maxY, yScale);
    final ticks = computeNiceTicks(
      rawMinY,
      rawMaxY,
      targetIntervals: axisIntervalCount(graphProps?.yDivisions),
      scale: graphProps?.yScale ?? 'Linear',
    );
    for (final rawY in ticks) {
      measureTick(rawY);
    }
    final bandY = kAxisLabelGap + tickWidth;
    final gapY = (graphProps?.titlePaddingY ?? 20.0).clamp(0.0, 80.0);
    yTitleFromAxis = math.max(bandY, gapY) + titleLineHeight;
    left = yTitleFromAxis + kAxisTitlePad;
  }

  return PlotMargins(
    left: left,
    top: kPlotMarginTop,
    right: math.max(kPlotMarginRight, legendReservedRight),
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
/// [legendReservedRight] must match the painter so gestures map exactly to
/// what is painted when the legend sits outside the plot rect.
PlotView? resolvePlotView({
  required List<List<double>> xSeries,
  required List<List<double>> ySeries,
  required GraphProperties? graphProps,
  double legendReservedRight = 0.0,
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
      legendReservedRight: legendReservedRight,
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
