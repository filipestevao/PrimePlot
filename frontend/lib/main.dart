import 'package:flutter/material.dart';
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

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Frameless UI
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
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
