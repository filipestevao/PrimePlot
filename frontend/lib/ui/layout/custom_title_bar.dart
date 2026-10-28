// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../components/prime_icon.dart';
import '../components/prime_search_bar.dart';

/// Maximize/restore toggle shared by the title-bar double-click and the
/// window-control button. Explicit handler — no dependence on the window
/// manager's own double-click behavior.
Future<void> _toggleMaximize() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52.0, // Taller to match the mockup
      color: PrimeTheme.titleBarBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Menu & Brand
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.menu, size: 20, color: PrimeTheme.textSecondary),
                  splashRadius: 20,
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
                const SizedBox(width: 8),
                const PrimeIcon(size: 20),
                const SizedBox(width: 8),
                Text(
                  ProjectState.instance.appVersion.isEmpty
                      ? 'PrimePlot'
                      : 'PrimePlot ${ProjectState.instance.appVersion}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PrimeTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                // Current file + dirty star, e.g. "— my_exp.primeplot *".
                ListenableBuilder(
                  listenable: Listenable.merge([
                    ProjectState.instance.currentFilePath,
                    ProjectState.instance.isDirty,
                  ]),
                  builder: (context, _) {
                    final name = ProjectState.instance.displayFileName;
                    final dirty = ProjectState.instance.isDirty.value;
                    final version = ProjectState.instance.appVersion;
                    final brand = version.isEmpty
                        ? 'PrimePlot'
                        : 'PrimePlot $version';
                    final title = '— $name${dirty ? ' *' : ''}';
                    // Mirror into the OS/taskbar title (fire-and-forget).
                    windowManager.setTitle('$brand $title');
                    return Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: PrimeTheme.textSecondary.withValues(alpha: 0.8),
                        letterSpacing: 0.2,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Left Flexible Drag Area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: Container(),
            ),
          ),

          // Center: Undo/Redo + command search cluster
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HistoryButton(isRedo: false),
              const SizedBox(width: 4),
              _HistoryButton(isRedo: true),
              const SizedBox(width: 12),
              const PrimeSearchBar(),
            ],
          ),

          // Right Flexible Drag Area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: Container(),
            ),
          ),

          // Right: Window Controls
          const WindowButtons(),
        ],
      ),
    );
  }
}

/// Undo / redo title-bar button driven by history availability.
class _HistoryButton extends StatelessWidget {
  final bool isRedo;
  const _HistoryButton({required this.isRedo});

  @override
  Widget build(BuildContext context) {
    final st = ProjectState.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: isRedo ? st.canRedo : st.canUndo,
      builder: (context, can, _) {
        final color = can
            ? PrimeTheme.textSecondary
            : PrimeTheme.textSecondary.withValues(alpha: 0.3);
        return Tooltip(
          message: isRedo ? 'Redo (Ctrl+Y)' : 'Undo (Ctrl+Z)',
          child: InkWell(
            onTap: can
                ? () {
                    final err =
                        isRedo ? st.redo() : st.undo();
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err,
                              style:
                                  const TextStyle(fontSize: 12)),
                          backgroundColor: const Color(0xFF7F1D1D),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                isRedo ? Icons.redo : Icons.undo,
                size: 16,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class WindowButtons extends StatelessWidget {  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildButton(Icons.remove, () => windowManager.minimize()),
        _buildButton(Icons.crop_square, _toggleMaximize),
        // Routes through MainLayout's onWindowClose, which prompts to save
        // when dirty before destroying the window.
        _buildButton(
          Icons.close,
          () => windowManager.close(),
          hoverColor: Colors.red.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onPressed, {Color? hoverColor}) {
    return SizedBox(
      width: 46,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: hoverColor ?? Colors.white12,
          child: Icon(icon, size: 16, color: PrimeTheme.textSecondary),
        ),
      ),
    );
  }
}
