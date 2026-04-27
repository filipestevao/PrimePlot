import 'package:flutter/material.dart';
import 'package:frontend/src/rust/frb_generated.dart';
import 'package:frontend/src/rust/api/simple.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const PrimePlotApp());
}

class PrimePlotApp extends StatelessWidget {
  const PrimePlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrimePlot',
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text('PrimePlot Backend Connected!'),
        ),
      ),
    );
  }
}
