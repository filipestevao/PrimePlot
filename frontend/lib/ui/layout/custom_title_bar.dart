// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme.dart';

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
                  icon: const Icon(Icons.menu, size: 20, color: PrimeTheme.textSecondary),
                  splashRadius: 20,
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
                const SizedBox(width: 16),
                const Icon(Icons.pie_chart, size: 20, color: PrimeTheme.primaryAccent), // Placeholder logo
                const SizedBox(width: 8),
                const Text(
                  'PrimePlot',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PrimeTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Left Flexible Drag Area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
              child: Container(),
            ),
          ),

          // Center: Search Bar
          Container(
            width: 300,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: PrimeTheme.searchBarBackground,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: PrimeTheme.borderSide),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Type command or search... (Ctrl + F)',
                    style: TextStyle(fontSize: 12, color: PrimeTheme.textSecondary.withOpacity(0.7)),
                  ),
                ),
                Icon(Icons.search, size: 16, color: PrimeTheme.textSecondary),
              ],
            ),
          ),

          // Right Flexible Drag Area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
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

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildButton(Icons.remove, () => windowManager.minimize()),
        _buildButton(Icons.crop_square, () async {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        }),
        _buildButton(Icons.close, () => exit(0), hoverColor: Colors.red.withOpacity(0.8)),
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
