// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:frontend/src/rust/frb_generated.dart';
import 'core/state.dart';
import 'core/theme.dart';
import 'ui/layout/main_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Rust backend
  await RustLib.init();
  
  // Initialize saved preferences (theme, etc.)
  ProjectState.instance.initTheme();

  // Load the app version once for the title bar / About dialog.
  try {
    final info = await PackageInfo.fromPlatform();
    ProjectState.instance.appVersion = info.version;
  } catch (_) {
    // Title bar falls back to unversioned brand.
  }

  // Load the initial project snapshot once (guarded: MainLayout remounts
  // on theme switch and must not reset live state).
  ProjectState.instance.loadInitialData();

  // Initialize Window Manager for Frameless Desktop Window
  await windowManager.ensureInitialized();

  // Use the bundled branding icon for the window/taskbar. Windows needs the
  // multi-resolution ICO; Linux's GTK backend loads the PNG.
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.setIcon(
      Platform.isWindows
          ? 'assets/branding/app-icon.ico'
          : 'assets/branding/app-icon.png',
    );
  }

  // Never shrink into overflow territory (compositor hint; MainLayout's
  // onWindowResize clamps at runtime as a backstop).
  await windowManager.setMinimumSize(kMinWindowSize);

  // Always start maximized: every compositor (Xorg, Wayland, Windows,
  // macOS) honors this natively — no size negotiation, no centering races.
  WindowOptions windowOptions = const WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });

  runApp(const PrimePlotApp());
}

class PrimePlotApp extends StatelessWidget {
  const PrimePlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ProjectState.instance.activeTheme,
        ProjectState.instance.decimalSeparator,
        ProjectState.instance.useThousands,
      ]),
      builder: (context, _) {
        final themeId = ProjectState.instance.activeTheme.value;
        final sep = ProjectState.instance.decimalSeparator.value;
        final grp = ProjectState.instance.useThousands.value ? 'g' : '';
        return MaterialApp(
          title: 'PrimePlot',
          debugShowCheckedModeBanner: false,
          theme: PrimeTheme.themeDataFor(themeId),
          // Keyed by theme + number format: const widgets below would otherwise
          // compare equal and skip rebuilding, leaving panels stale.
          // Remount resets pane sizes/collapsed flags — acceptable on an
          // explicit settings change; project data lives in singletons + Rust.
          home: MainLayout(key: ValueKey('${themeId}_$sep$grp')),
        );
      },
    );
  }
}
