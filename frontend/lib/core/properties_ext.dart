// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import '../src/rust/api/properties.dart';

extension GraphPropertiesExt on GraphProperties {
  GraphProperties copyWith({
    double? Function()? xMin,
    double? Function()? xMax,
    double? Function()? yMin,
    double? Function()? yMax,
    bool? xVisible,
    bool? yVisible,
    String? xScale,
    String? yScale,
    String? xLabel,
    String? yLabel,
    double? Function()? aspectRatio,
    bool? showGrid,
    bool? showLegend,
    String? legendPosition,
    double? titleFontSize,
    double? tickFontSize,
    double? titlePadding,
    double? titlePaddingY,
    bool? showBorder,
    String? Function()? gridColor,
    String? Function()? axisColor,
    String? Function()? backgroundColor,
    String? Function()? labelColor,
    bool? xLabelLatex,
    bool? yLabelLatex,
  }) {
    return GraphProperties(
      xMin: xMin != null ? xMin() : this.xMin,
      xMax: xMax != null ? xMax() : this.xMax,
      yMin: yMin != null ? yMin() : this.yMin,
      yMax: yMax != null ? yMax() : this.yMax,
      xVisible: xVisible ?? this.xVisible,
      yVisible: yVisible ?? this.yVisible,
      xScale: xScale ?? this.xScale,
      yScale: yScale ?? this.yScale,
      xLabel: xLabel ?? this.xLabel,
      yLabel: yLabel ?? this.yLabel,
      aspectRatio: aspectRatio != null ? aspectRatio() : this.aspectRatio,
      showGrid: showGrid ?? this.showGrid,
      showLegend: showLegend ?? this.showLegend,
      legendPosition: legendPosition ?? this.legendPosition,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      tickFontSize: tickFontSize ?? this.tickFontSize,
      titlePadding: titlePadding ?? this.titlePadding,
      titlePaddingY: titlePaddingY ?? this.titlePaddingY,
      showBorder: showBorder ?? this.showBorder,
      gridColor: gridColor != null ? gridColor() : this.gridColor,
      axisColor: axisColor != null ? axisColor() : this.axisColor,
      backgroundColor: backgroundColor != null
          ? backgroundColor()
          : this.backgroundColor,
      labelColor: labelColor != null ? labelColor() : this.labelColor,
      xLabelLatex: xLabelLatex ?? this.xLabelLatex,
      yLabelLatex: yLabelLatex ?? this.yLabelLatex,
    );
  }
}

extension TablePropertiesExt on TableProperties {
  TableProperties copyWith({
    String? legendDisplayName,
    String? lineStyle,
    double? lineThickness,
    bool? lineVisible,
    String? markerType,
    bool? markerVisible,
    String? lineColor,
    String? markerColor,
    bool? legendLatex,
  }) {
    return TableProperties(
      legendDisplayName: legendDisplayName ?? this.legendDisplayName,
      lineStyle: lineStyle ?? this.lineStyle,
      lineThickness: lineThickness ?? this.lineThickness,
      lineVisible: lineVisible ?? this.lineVisible,
      markerType: markerType ?? this.markerType,
      markerVisible: markerVisible ?? this.markerVisible,
      lineColor: lineColor ?? this.lineColor,
      markerColor: markerColor ?? this.markerColor,
      legendLatex: legendLatex ?? this.legendLatex,
    );
  }
}

extension FunctionPropertiesExt on FunctionProperties {
  FunctionProperties copyWith({
    String? equation,
    String? legendDisplayName,
    double? Function()? xMin,
    double? Function()? xMax,
    BigInt? numSamples,
    String? lineColor,
    double? lineThickness,
    String? lineStyle,
    bool? legendLatex,
  }) {
    return FunctionProperties(
      equation: equation ?? this.equation,
      legendDisplayName: legendDisplayName ?? this.legendDisplayName,
      xMin: xMin != null ? xMin() : this.xMin,
      xMax: xMax != null ? xMax() : this.xMax,
      numSamples: numSamples ?? this.numSamples,
      lineColor: lineColor ?? this.lineColor,
      lineThickness: lineThickness ?? this.lineThickness,
      lineStyle: lineStyle ?? this.lineStyle,
      legendLatex: legendLatex ?? this.legendLatex,
    );
  }
}
