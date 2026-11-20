// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Persisted geometry of the main window.
///
/// [maximized] is authoritative. [bounds] is the last restored (non-maximized)
/// rectangle, kept so unmaximizing and the next launch return to the same
/// size and position.
@immutable
class WindowState {
  const WindowState({required this.maximized, this.bounds});

  /// First launch keeps PrimePlot's historical always-maximized startup.
  static const WindowState initial = WindowState(maximized: true);

  final bool maximized;
  final Rect? bounds;

  Map<String, Object?> toJson() => {
    'maximized': maximized,
    if (bounds != null)
      'bounds': <String, double>{
        'x': bounds!.left,
        'y': bounds!.top,
        'width': bounds!.width,
        'height': bounds!.height,
      },
  };

  /// Returns null when [value] is not a usable state document.
  static WindowState? fromJson(Object? value) {
    if (value is! Map) return null;
    final maximized = value['maximized'];
    if (maximized is! bool) return null;

    Rect? bounds;
    final rawBounds = value['bounds'];
    if (rawBounds is Map) {
      final x = rawBounds['x'];
      final y = rawBounds['y'];
      final width = rawBounds['width'];
      final height = rawBounds['height'];
      if (x is num && y is num && width is num && height is num) {
        final rect = Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          width.toDouble(),
          height.toDouble(),
        );
        if (rect.left.isFinite &&
            rect.top.isFinite &&
            rect.width.isFinite &&
            rect.height.isFinite &&
            rect.width > 0 &&
            rect.height > 0) {
          bounds = rect;
        }
      }
    }
    return WindowState(maximized: maximized, bounds: bounds);
  }

  @override
  bool operator ==(Object other) =>
      other is WindowState &&
      other.maximized == maximized &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(maximized, bounds);
}

/// Small JSON store next to the Rust-owned `prefs.json`.
///
/// Window geometry is pure shell state, so it stays out of `AppPreferences`
/// and does not require a Rust/FRB round trip on every resize event.
class WindowStateStore {
  WindowStateStore({String? path}) : _path = path ?? _defaultPath();

  final String _path;

  String get path => _path;

  static String _defaultPath() {
    final env = Platform.environment;
    final xdg = env['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return _join(_join(xdg, 'primeplot'), 'window_state.json');
    }
    final appData = env['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return _join(_join(appData, 'primeplot'), 'window_state.json');
    }
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      return _join(
        _join(_join(home, '.config'), 'primeplot'),
        'window_state.json',
      );
    }
    return _join('.primeplot', 'window_state.json');
  }

  static String _join(String dir, String name) =>
      '$dir${Platform.pathSeparator}$name';

  WindowState read() {
    try {
      final file = File(_path);
      if (!file.existsSync()) return WindowState.initial;
      return WindowState.fromJson(jsonDecode(file.readAsStringSync())) ??
          WindowState.initial;
    } catch (e) {
      debugPrint('Error reading window state: $e');
      return WindowState.initial;
    }
  }

  void write(WindowState state) {
    try {
      final file = File(_path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(state.toJson()), flush: true);
    } catch (e) {
      debugPrint('Error saving window state: $e');
    }
  }
}

/// Loads, applies, and tracks the main window's maximize/restore state.
class WindowStateController with WindowListener {
  WindowStateController._() : _store = WindowStateStore();

  static final WindowStateController instance = WindowStateController._();

  final WindowStateStore _store;

  WindowState _state = WindowState.initial;
  Timer? _saveTimer;
  bool _tracking = false;

  WindowState get state => _state;

  /// Reads the saved state before the window is shown.
  WindowState load() {
    _state = _store.read();
    return _state;
  }

  /// Applies [state] while the window is still hidden.
  Future<void> applyInitial(WindowState state) async {
    _state = state;

    try {
      // Restore the normal rectangle before maximizing so unmaximizing later
      // returns to the saved size instead of the platform default.
      if (!state.maximized && await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }
    } catch (e) {
      debugPrint('Error restoring window mode: $e');
    }

    final bounds = state.bounds;
    if (bounds != null) {
      try {
        await windowManager.setBounds(bounds);
      } catch (e) {
        debugPrint('Error restoring window bounds: $e');
      }
    }

    if (state.maximized) {
      try {
        await windowManager.maximize();
      } catch (e) {
        debugPrint('Error maximizing window: $e');
      }
    }
  }

  /// Starts persisting user changes. Call only after [applyInitial] so
  /// startup events cannot overwrite the saved state.
  void startTracking() {
    if (_tracking) return;
    _tracking = true;
    windowManager.addListener(this);
  }

  /// Re-applies the desired state after the platform has shown the window.
  Future<void> reassert() async {
    try {
      if (_state.maximized) {
        if (!await windowManager.isMaximized()) {
          await windowManager.maximize();
        }
      } else if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }
    } catch (e) {
      debugPrint('Error reasserting window state: $e');
    }
  }

  /// Captures the live geometry before the window is destroyed.
  Future<void> captureAndSave() async {
    _saveTimer?.cancel();
    await _capture();
  }

  Future<void> _capture() async {
    try {
      // A minimized window reports neither its maximized flag nor a usable
      // rectangle, so keep the last visible state.
      if (await windowManager.isMinimized()) {
        _store.write(_state);
        return;
      }

      final maximized = await windowManager.isMaximized();
      Rect? bounds = _state.bounds;
      if (!maximized) {
        bounds = await windowManager.getBounds();
      }
      _state = WindowState(maximized: maximized, bounds: bounds);
      _store.write(_state);
    } catch (e) {
      debugPrint('Error saving window state: $e');
    }
  }

  void _scheduleCapture([Duration delay = const Duration(milliseconds: 500)]) {
    if (!_tracking) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(delay, _capture);
  }

  @override
  void onWindowMaximize() {
    _state = WindowState(maximized: true, bounds: _state.bounds);
    _store.write(_state);
  }

  @override
  void onWindowUnmaximize() {
    _state = WindowState(maximized: false, bounds: _state.bounds);
    _store.write(_state);
    // The restored rectangle is only final once the transition completes.
    _scheduleCapture(const Duration(milliseconds: 100));
  }

  @override
  void onWindowResize() => _scheduleCapture();

  @override
  void onWindowMove() => _scheduleCapture();

  @override
  void onWindowResized() => _scheduleCapture(const Duration(milliseconds: 50));

  @override
  void onWindowMoved() => _scheduleCapture(const Duration(milliseconds: 50));

  @override
  void onWindowClose() {
    // MainLayout owns the close sequence; persist the last known state
    // synchronously in case the process exits before an async write lands.
    _saveTimer?.cancel();
    _store.write(_state);
  }

  void dispose() {
    _saveTimer?.cancel();
    if (_tracking) {
      windowManager.removeListener(this);
      _tracking = false;
    }
  }
}
