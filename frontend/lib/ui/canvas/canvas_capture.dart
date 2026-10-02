// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Figure capture: renders the exportable canvas (RepaintBoundary, without
//! crosshair/marquee overlays) to PNG bytes at a chosen pixel ratio and
//! background. The background mode is applied transiently and restored.

import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';

import '../../core/state.dart';

Future<Uint8List?> captureCanvasPng({
  required double pixelRatio,
  required CanvasExportBackground background,
}) async {
  final st = ProjectState.instance;
  final prev = st.exportBackground.value;
  st.exportBackground.value = background;
  try {
    // Let the repaint with the export background land first.
    await Future.delayed(const Duration(milliseconds: 150));
    final obj = st.canvasCaptureKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    st.exportBackground.value = prev;
  }
}
