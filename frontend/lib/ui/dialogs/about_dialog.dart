// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! About dialog: version, license viewer, build info. Opened from the
//! hamburger drawer (no Material `showAboutDialog` — custom Prime styling).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme.dart';

class PrimeAboutDialog extends StatelessWidget {
  const PrimeAboutDialog({super.key});

  Future<String> _licenseText() async {
    try {
      return await rootBundle.loadString('assets/LICENSE.txt');
    } catch (_) {
      return 'License file not bundled with this build.';
    }
  }

  void _showLicense(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: PrimeTheme.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: PrimeTheme.borderSide),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 640, maxHeight: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    Text(
                      'GNU General Public License v3.0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PrimeTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: PrimeTheme.textSecondary,
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(
                  height: 1, thickness: 1, color: PrimeTheme.borderSide),
              Expanded(
                child: FutureBuilder<String>(
                  future: _licenseText(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: SelectableText(
                        snap.data!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: PrimeTheme.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: PrimeTheme.panelBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PrimeTheme.borderSide),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PrimeTheme.primaryAccent
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pie_chart,
                      size: 26,
                      color: PrimeTheme.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PrimePlot',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: PrimeTheme.textPrimary,
                          ),
                        ),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (ctx, snap) {
                            final v = snap.hasData
                                ? 'v${snap.data!.version} '
                                    '(build ${snap.data!.buildNumber})'
                                : '…';
                            return Text(
                              v,
                              style: TextStyle(
                                fontSize: 12,
                                color: PrimeTheme.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: PrimeTheme.textSecondary,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'High-performance scientific desktop plotting application — '
                'plot, customize, and export publication-quality figures.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: PrimeTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Divider(
                  height: 1, thickness: 1, color: PrimeTheme.borderSide),
              const SizedBox(height: 14),
              _infoRow('License', 'GPL-3.0-only'),
              const SizedBox(height: 6),
              _infoRow('Copyright', '© 2026 Filipe Estevão'),
              const SizedBox(height: 6),
              _infoRow('Dart runtime', Platform.version.split(' ').first),
              const SizedBox(height: 6),
              _infoRow('Rust core',
                  '0.1.0 (data_engine · plot_bridge · core_math)'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLicense(context),
                  icon: const Icon(Icons.description_outlined, size: 15),
                  label: const Text('View License',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PrimeTheme.primaryAccent,
                    side: BorderSide(
                        color: PrimeTheme.primaryAccent
                            .withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, color: PrimeTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11.5, color: PrimeTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
