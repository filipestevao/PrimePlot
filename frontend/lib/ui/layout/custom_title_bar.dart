import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32.0,
      color: PrimeTheme.titleBarBackground,
      child: Row(
        children: [
          // Drag area for the window
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                windowManager.startDragging();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PrimePlot',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: PrimeTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Window Controls
          const WindowButtons(),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.minimize, size: 16, color: PrimeTheme.textPrimary),
          onPressed: () => windowManager.minimize(),
          hoverColor: Colors.white12,
          splashRadius: 16,
        ),
        IconButton(
          icon: const Icon(Icons.crop_square, size: 16, color: PrimeTheme.textPrimary),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          hoverColor: Colors.white12,
          splashRadius: 16,
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: PrimeTheme.textPrimary),
          onPressed: () => windowManager.close(),
          hoverColor: Colors.red.withOpacity(0.8),
          splashRadius: 16,
        ),
      ],
    );
  }
}
