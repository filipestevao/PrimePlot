// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

const _desktopFileName = 'com.primeplot.frontend.desktop';
const _iconFileName = 'com.primeplot.frontend.png';

/// Registers the portable Linux bundle with the user's desktop so the taskbar
/// icon can be resolved by application id on Wayland. Only the bundle folder
/// is required: the launcher entry and icon are read from its `share/` tree.
Future<void> ensureLinuxDesktopIntegration() async {
  if (!Platform.isLinux) return;

  try {
    final bundleDir = File(Platform.resolvedExecutable).parent;
    final desktopTemplate = File(
      '${bundleDir.path}/share/applications/$_desktopFileName',
    );
    final bundleIcon = File(
      '${bundleDir.path}/share/icons/hicolor/512x512/apps/$_iconFileName',
    );
    if (!await desktopTemplate.exists() || !await bundleIcon.exists()) {
      return;
    }

    final dataHome = _xdgDataHome();
    if (dataHome == null) return;

    final appsDir = Directory('$dataHome/applications');
    final iconDir = Directory('$dataHome/icons/hicolor/512x512/apps');
    final installedDesktop = File('${appsDir.path}/$_desktopFileName');
    final installedIcon = File('${iconDir.path}/$_iconFileName');

    var changed = false;
    final iconBytes = await bundleIcon.readAsBytes();
    if (!await _sameBytes(installedIcon, iconBytes)) {
      await iconDir.create(recursive: true);
      await installedIcon.writeAsBytes(iconBytes, flush: true);
      changed = true;
    }

    final template = await desktopTemplate.readAsString();
    final desktop = template.replaceFirst(
      RegExp(r'^Exec=.*$', multiLine: true),
      'Exec=${_quoteExec(Platform.resolvedExecutable)}',
    );
    if (!await installedDesktop.exists() ||
        await installedDesktop.readAsString() != desktop) {
      await appsDir.create(recursive: true);
      await installedDesktop.writeAsString(desktop, flush: true);
      changed = true;
    }

    if (changed) {
      unawaited(_refreshDesktopCaches(dataHome));
    }
  } catch (error) {
    debugPrint('Linux desktop integration skipped: $error');
  }
}

String? _xdgDataHome() {
  final xdg = Platform.environment['XDG_DATA_HOME'];
  if (xdg != null && xdg.startsWith('/') && xdg.isNotEmpty) return xdg;
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  return '$home/.local/share';
}

String _quoteExec(String path) {
  final escaped = path
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$')
      .replaceAll('`', r'\`')
      .replaceAll('%', '%%');
  return '"$escaped"';
}

Future<bool> _sameBytes(File file, List<int> expected) async {
  if (!await file.exists()) return false;
  return listEquals(await file.readAsBytes(), expected);
}

Future<void> _refreshDesktopCaches(String dataHome) async {
  final commands = <List<String>>[
    ['update-desktop-database', '$dataHome/applications'],
    ['gtk-update-icon-cache', '-f', '-t', '$dataHome/icons/hicolor'],
    ['kbuildsycoca6'],
    ['kbuildsycoca5'],
  ];
  for (final command in commands) {
    try {
      await Process.run(command.first, command.sublist(1))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Optional cache refreshers are not available everywhere.
    }
  }
}
