// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'package:frontend/src/rust/frb_generated.dart';
import 'core/theme.dart';
import 'ui/layout/main_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Rust backend
  await RustLib.init();
  
  // Initialize Window Manager for Frameless Desktop Window
  await windowManager.ensureInitialized();

  final display = await screenRetriever.getPrimaryDisplay();
  final logicalW = display.size.width;
  final logicalH = display.size.height;

  final willFit = logicalW >= 1800 && logicalH >= 1024;

  WindowOptions windowOptions = WindowOptions(
    size: willFit ? const Size(1800, 1024) : const Size(1280, 720),
    center: willFit,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    if (!willFit) await windowManager.maximize();
  });

  runApp(const PrimePlotApp());
}

class PrimePlotApp extends StatelessWidget {
  const PrimePlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrimePlot',
      debugShowCheckedModeBanner: false,
      theme: PrimeTheme.darkTheme,
      home: const MainLayout(),
    );
  }
}
