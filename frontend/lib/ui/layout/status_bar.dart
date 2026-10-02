// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Slim 20px status bar: file name + dirty star, node count, live cursor
//! coordinates (mirrors the viewport crosshair readout).

import 'package:flutter/material.dart';

import '../../core/state.dart';
import '../../core/theme.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  static String _fmt(double v) {
    final a = v.abs();
    if (a != 0 && (a >= 10000 || a < 0.001)) {
      return v.toStringAsExponential(2);
    }
    return v.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final st = ProjectState.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        st.projectTree,
        st.currentFilePath,
        st.isDirty,
        st.cursorCoords,
      ]),
      builder: (context, _) {
        final file = st.displayFileName;
        final dirty = st.isDirty.value ? ' *' : '';
        final coords = st.cursorCoords.value;
        final coordText = coords == null
            ? 'X: —   Y: —'
            : 'X: ${_fmt(coords.dx)}   Y: ${_fmt(coords.dy)}';
        final style = TextStyle(
          fontSize: 11,
          color: PrimeTheme.textSecondary,
        );
        return Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PrimeTheme.titleBarBackground,
            border: Border(
              top: BorderSide(color: PrimeTheme.borderSide),
            ),
          ),
          child: Row(
            children: [
              Text('$file$dirty', style: style),
              const SizedBox(width: 12),
              Text('${st.nodeCount} nodes', style: style),
              const Spacer(),
              Text(
                coordText,
                style: TextStyle(
                  fontSize: 11,
                  color: PrimeTheme.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
