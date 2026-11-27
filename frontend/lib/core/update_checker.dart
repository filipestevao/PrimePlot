// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String _releasesPage =
    'https://github.com/filipestevao/PrimePlot/releases';
// All current PrimePlot releases are marked prerelease, and GitHub's
// `/releases/latest` endpoint ignores those (404). Read the list instead and
// pick the highest non-draft tag.
const String _releasesApi =
    'https://api.github.com/repos/filipestevao/PrimePlot/releases?per_page=20';

/// Guards against duplicate checks when the shell remounts (theme changes).
bool _startupCheckStarted = false;

/// Checks GitHub for a newer release and shows a dialog when one is found.
///
/// Runs at most once per process. Network failures and rate limits are
/// silently ignored so startup is never blocked.
Future<void> checkForUpdates(
  BuildContext context,
  String currentVersion,
) async {
  if (_startupCheckStarted) return;
  _startupCheckStarted = true;

  try {
    final response = await http
        .get(
          Uri.parse(_releasesApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'PrimePlot',
          },
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    if (data is! List) return;
    String? latestTag;
    for (final release in data) {
      if (release is! Map<String, dynamic>) continue;
      if (release['draft'] == true) continue;
      final tag = release['tag_name'];
      if (tag is! String || tag.trim().isEmpty) continue;
      if (latestTag == null || _isNewer(tag, latestTag)) {
        latestTag = tag;
      }
    }
    if (latestTag == null) return;
    final latest = _normalizeVersion(latestTag);
    if (latest.isEmpty || !_isNewer(latest, currentVersion)) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(
          'PrimePlot $latest is available (you have $currentVersion).\n\n'
          'Visit the releases page to download the latest version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse(_releasesPage),
                mode: LaunchMode.externalApplication,
              ).ignore();
            },
            child: const Text('View Releases'),
          ),
        ],
      ),
    );
  } catch (_) {
    // Silently ignore: network errors must never block the app.
  }
}

String _normalizeVersion(String tag) {
  final stripped = tag.trim().replaceFirst(RegExp(r'^[vV]'), '');
  return stripped.split(RegExp(r'[+-]')).first.trim();
}

bool _isNewer(String latest, String current) {
  final l = _parseVersion(latest);
  final c = _parseVersion(current);
  final length = l.length > c.length ? l.length : c.length;
  for (var i = 0; i < length; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv > cv) return true;
    if (lv < cv) return false;
  }
  return false;
}

List<int> _parseVersion(String version) {
  return _normalizeVersion(
    version,
  ).split('.').map((part) => int.tryParse(part) ?? 0).toList();
}
